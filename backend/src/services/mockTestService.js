/**
 * Mock Test Service
 *
 * Core service for JEE Main mock test functionality.
 * Handles template loading, test sessions, scoring, and results.
 *
 * Features:
 * - Load templates with chunked questions
 * - Create user test sessions with rate limiting
 * - Real-time answer tracking
 * - JEE Main scoring (MCQ: +4/-1, NVQ: +4/0)
 * - NTA percentile lookup
 * - Post-test theta and stats updates
 *
 * @version 1.0
 * @phase Phase 1A - Backend Services
 */

const { db, admin, FieldValue } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const {
  calculateSubjectTheta,
  calculateWeightedOverallTheta
} = require('./thetaCalculationService');

// ============================================================================
// CONSTANTS
// ============================================================================

const MOCK_TEST_DURATION_SECONDS = 10800; // 3 hours
const RATE_LIMIT_MINUTES = 5; // Minimum time between test starts
const QUESTIONS_PER_CHUNK = 15;

// JEE Main Marking Scheme
const MARKING_SCHEME = {
  mcq: { correct: 4, incorrect: -1, unattempted: 0 },
  numerical: { correct: 4, incorrect: 0, unattempted: 0 } // NO negative for NVQ
};

// NTA Percentile Lookup Table (JEE Main 2026 official data)
const NTA_PERCENTILE_TABLE = [
  { minScore: 290, maxScore: 300, percentile: 99.99 },
  { minScore: 280, maxScore: 289, percentile: 99.95 },
  { minScore: 270, maxScore: 279, percentile: 99.9 },
  { minScore: 260, maxScore: 269, percentile: 99.8 },
  { minScore: 250, maxScore: 259, percentile: 99.6 },
  { minScore: 240, maxScore: 249, percentile: 99.4 },
  { minScore: 230, maxScore: 239, percentile: 99.1 },
  { minScore: 220, maxScore: 229, percentile: 98.7 },
  { minScore: 210, maxScore: 219, percentile: 98.2 },
  { minScore: 200, maxScore: 209, percentile: 97.5 },
  { minScore: 190, maxScore: 199, percentile: 96.5 },
  { minScore: 180, maxScore: 189, percentile: 95.3 },
  { minScore: 170, maxScore: 179, percentile: 93.8 },
  { minScore: 160, maxScore: 169, percentile: 92.0 },
  { minScore: 150, maxScore: 159, percentile: 89.8 },
  { minScore: 140, maxScore: 149, percentile: 87.2 },
  { minScore: 130, maxScore: 139, percentile: 84.2 },
  { minScore: 120, maxScore: 129, percentile: 80.7 },
  { minScore: 110, maxScore: 119, percentile: 76.8 },
  { minScore: 100, maxScore: 109, percentile: 72.4 },
  { minScore: 90, maxScore: 99, percentile: 67.5 },
  { minScore: 80, maxScore: 89, percentile: 62.1 },
  { minScore: 70, maxScore: 79, percentile: 56.3 },
  { minScore: 60, maxScore: 69, percentile: 50.0 },
  { minScore: 50, maxScore: 59, percentile: 43.4 },
  { minScore: 40, maxScore: 49, percentile: 36.5 },
  { minScore: 30, maxScore: 39, percentile: 29.4 },
  { minScore: 20, maxScore: 29, percentile: 22.2 },
  { minScore: 10, maxScore: 19, percentile: 15.0 },
  { minScore: 0, maxScore: 9, percentile: 8.5 },
  { minScore: -40, maxScore: -1, percentile: 3.0 }
];

// ============================================================================
// TEMPLATE MANAGEMENT
// ============================================================================

/**
 * Get all available mock test templates
 * @returns {Promise<Array>} List of active templates
 */
async function getAvailableTemplates() {
  const templatesSnapshot = await retryFirestoreOperation(async () => {
    return await db.collection('mock_test_templates')
      .where('active', '==', true)
      .get();
  });

  return templatesSnapshot.docs.map(doc => ({
    template_id: doc.id,
    ...doc.data(),
    questions: undefined // Don't include questions in list
  }));
}

/**
 * Load a template with all its questions from chunks
 * @param {string} templateId - Template ID
 * @returns {Promise<Object>} Template with questions array
 */
async function loadTemplateWithQuestions(templateId) {
  // Get template document
  const templateDoc = await retryFirestoreOperation(async () => {
    return await db.collection('mock_test_templates').doc(templateId).get();
  });

  if (!templateDoc.exists) {
    throw new Error(`Template ${templateId} not found`);
  }

  const template = templateDoc.data();

  // Load questions from chunks
  const chunksSnapshot = await retryFirestoreOperation(async () => {
    return await db.collection('mock_test_templates')
      .doc(templateId)
      .collection('question_chunks')
      .orderBy('chunk_index', 'asc')
      .get();
  });

  // Assemble questions from all chunks
  const questions = [];
  chunksSnapshot.forEach(chunkDoc => {
    const chunkData = chunkDoc.data();
    if (chunkData.questions && Array.isArray(chunkData.questions)) {
      questions.push(...chunkData.questions);
    }
  });

  logger.info('Loaded template with questions', {
    templateId,
    totalChunks: chunksSnapshot.size,
    totalQuestions: questions.length
  });

  return {
    ...template,
    template_id: templateId,
    questions
  };
}

// ============================================================================
// TEST SESSION MANAGEMENT
// ============================================================================

/**
 * Check rate limiting for mock test starts
 * @param {string} userId - User ID
 * @returns {Promise<boolean>} Whether user can start a new test
 */
async function checkRateLimit(userId) {
  const recentTestsSnapshot = await retryFirestoreOperation(async () => {
    const fiveMinutesAgo = new Date(Date.now() - RATE_LIMIT_MINUTES * 60 * 1000);
    return await db.collection('users')
      .doc(userId)
      .collection('mock_tests')
      .where('started_at', '>', fiveMinutesAgo)
      .limit(1)
      .get();
  });

  return recentTestsSnapshot.empty;
}

/**
 * Get user's mock test history
 * @param {string} userId - User ID
 * @returns {Promise<Array>} List of completed mock tests
 */
async function getUserMockTestHistory(userId) {
  const testsSnapshot = await retryFirestoreOperation(async () => {
    return await db.collection('users')
      .doc(userId)
      .collection('mock_tests')
      .orderBy('started_at', 'desc')
      .limit(20)
      .get();
  });

  return testsSnapshot.docs.map(doc => ({
    test_id: doc.id,
    ...doc.data()
  }));
}

/**
 * Get templates the user hasn't taken yet
 * @param {string} userId - User ID
 * @returns {Promise<Array>} Available template IDs
 */
async function getUnusedTemplatesForUser(userId) {
  const [allTemplates, userHistory] = await Promise.all([
    getAvailableTemplates(),
    getUserMockTestHistory(userId)
  ]);

  const usedTemplateIds = new Set(
    userHistory
      .filter(t => t.status === 'completed')
      .map(t => t.template_id)
  );

  return allTemplates.filter(t => !usedTemplateIds.has(t.template_id));
}

/**
 * Start a new mock test for a user
 * @param {string} userId - User ID
 * @param {string} templateId - Optional specific template ID
 * @returns {Promise<Object>} Test session with questions
 */
async function startMockTest(userId, templateId = null) {
  // Check rate limit
  const canStart = await checkRateLimit(userId);
  if (!canStart) {
    throw new Error(`Rate limited. Please wait ${RATE_LIMIT_MINUTES} minutes between tests.`);
  }

  // Check for active test
  const activeTest = await getActiveTest(userId);
  if (activeTest) {
    throw new Error('You have an active mock test. Please complete or abandon it first.');
  }

  // Select template
  let selectedTemplateId = templateId;
  if (!selectedTemplateId) {
    const unusedTemplates = await getUnusedTemplatesForUser(userId);
    if (unusedTemplates.length > 0) {
      // Pick random unused template
      const randomIndex = Math.floor(Math.random() * unusedTemplates.length);
      selectedTemplateId = unusedTemplates[randomIndex].template_id;
    } else {
      // All templates used, pick random from all
      const allTemplates = await getAvailableTemplates();
      if (allTemplates.length === 0) {
        throw new Error('No mock test templates available');
      }
      const randomIndex = Math.floor(Math.random() * allTemplates.length);
      selectedTemplateId = allTemplates[randomIndex].template_id;
    }
  }

  // Load template with questions
  const template = await loadTemplateWithQuestions(selectedTemplateId);

  // Create test session
  const testId = `MT_${userId}_${Date.now()}`;
  const now = FieldValue.serverTimestamp();
  const expiresAt = new Date(Date.now() + MOCK_TEST_DURATION_SECONDS * 1000);

  const testSession = {
    test_id: testId,
    user_id: userId,
    template_id: selectedTemplateId,
    template_name: template.name,
    status: 'in_progress',

    // Timing
    started_at: now,
    expires_at: expiresAt,
    duration_seconds: MOCK_TEST_DURATION_SECONDS,
    time_remaining_seconds: MOCK_TEST_DURATION_SECONDS,

    // Configuration
    config: template.config,
    sections: template.sections,
    question_count: template.questions.length,

    // Responses (initialized empty)
    responses: {},

    // Question states (JEE CBT style)
    question_states: initializeQuestionStates(template.questions.length),

    // Will be populated on completion
    score: null,
    percentile: null,
    subject_scores: null,
    completed_at: null
  };

  // Save test session
  await retryFirestoreOperation(async () => {
    await db.collection('users')
      .doc(userId)
      .collection('mock_tests')
      .doc(testId)
      .set(testSession);
  });

  // Increment template use count
  await retryFirestoreOperation(async () => {
    await db.collection('mock_test_templates')
      .doc(selectedTemplateId)
      .update({
        use_count: FieldValue.increment(1),
        last_used_at: now
      });
  });

  logger.info('Mock test started', {
    userId,
    testId,
    templateId: selectedTemplateId,
    questionCount: template.questions.length
  });

  // Return session with sanitized questions (no answers)
  return {
    test_id: testId,
    template_id: selectedTemplateId,
    template_name: template.name,
    started_at: new Date().toISOString(),
    expires_at: expiresAt.toISOString(),
    duration_seconds: MOCK_TEST_DURATION_SECONDS,
    sections: template.sections,
    questions: sanitizeQuestionsForClient(template.questions),
    question_states: testSession.question_states
  };
}

/**
 * Initialize question states (all start as 'not_visited')
 */
function initializeQuestionStates(count) {
  const states = {};
  for (let i = 1; i <= count; i++) {
    states[i] = 'not_visited'; // Gray in JEE CBT
  }
  return states;
}

/**
 * Remove answers and solutions from questions for client
 */
function sanitizeQuestionsForClient(questions) {
  return questions.map(q => ({
    question_number: q.question_number,
    section_index: q.section_index,
    question_id: q.question_id,
    question_type: q.question_type,
    subject: q.subject,
    chapter: q.chapter,
    question_text: q.question_text,
    question_text_html: q.question_text_html,
    image_url: q.image_url,
    options: q.options, // MCQ options (without marking correct)
    marks_correct: q.marks_correct,
    marks_incorrect: q.marks_incorrect
  }));
}

/**
 * Get user's active (in-progress) mock test
 * @param {string} userId - User ID
 * @returns {Promise<Object|null>} Active test or null
 */
async function getActiveTest(userId) {
  const activeSnapshot = await retryFirestoreOperation(async () => {
    return await db.collection('users')
      .doc(userId)
      .collection('mock_tests')
      .where('status', '==', 'in_progress')
      .limit(1)
      .get();
  });

  if (activeSnapshot.empty) {
    return null;
  }

  const testDoc = activeSnapshot.docs[0];
  const testData = testDoc.data();

  // Check if expired
  const expiresAt = testData.expires_at?.toDate?.() || new Date(testData.expires_at);
  if (new Date() > expiresAt) {
    // Auto-submit expired test
    logger.info('Auto-submitting expired mock test', { userId, testId: testDoc.id });
    await submitMockTest(userId, testDoc.id, {}, true);
    return null;
  }

  return {
    test_id: testDoc.id,
    ...testData
  };
}

/**
 * Get active test with full questions for resuming
 */
async function getActiveTestWithQuestions(userId) {
  const activeTest = await getActiveTest(userId);
  if (!activeTest) {
    return null;
  }

  // Load template questions
  const template = await loadTemplateWithQuestions(activeTest.template_id);

  return {
    ...activeTest,
    questions: sanitizeQuestionsForClient(template.questions)
  };
}

// ============================================================================
// ANSWER SUBMISSION
// ============================================================================

/**
 * Save answer for a question (real-time sync)
 * @param {string} userId - User ID
 * @param {string} testId - Test ID
 * @param {number} questionNumber - Question number (1-90)
 * @param {string} answer - Student's answer
 * @param {boolean} markedForReview - Whether marked for review
 * @param {number} timeSpent - Time spent on this question (seconds)
 */
async function saveAnswer(userId, testId, questionNumber, answer, markedForReview = false, timeSpent = 0) {
  const testRef = db.collection('users').doc(userId).collection('mock_tests').doc(testId);

  // Determine question state based on answer and review flag
  let questionState;
  if (answer && markedForReview) {
    questionState = 'answered_marked'; // Purple + Green
  } else if (answer) {
    questionState = 'answered'; // Green
  } else if (markedForReview) {
    questionState = 'marked_for_review'; // Purple
  } else {
    questionState = 'not_answered'; // Red (visited but no answer)
  }

  await retryFirestoreOperation(async () => {
    await testRef.update({
      [`responses.${questionNumber}`]: {
        answer: answer || null,
        marked_for_review: markedForReview,
        time_spent_seconds: timeSpent,
        updated_at: FieldValue.serverTimestamp()
      },
      [`question_states.${questionNumber}`]: questionState
    });
  });

  return { success: true, questionState };
}

/**
 * Clear answer for a question
 */
async function clearAnswer(userId, testId, questionNumber) {
  const testRef = db.collection('users').doc(userId).collection('mock_tests').doc(testId);

  await retryFirestoreOperation(async () => {
    await testRef.update({
      [`responses.${questionNumber}`]: {
        answer: null,
        marked_for_review: false,
        time_spent_seconds: 0,
        updated_at: FieldValue.serverTimestamp()
      },
      [`question_states.${questionNumber}`]: 'not_answered'
    });
  });

  return { success: true };
}

// ============================================================================
// SCORING & SUBMISSION
// ============================================================================

/**
 * Calculate score for a set of responses
 * @param {Array} questions - Questions with correct answers
 * @param {Object} responses - User responses { questionNumber: { answer } }
 * @returns {Object} Score breakdown
 */
function calculateScore(questions, responses) {
  let totalScore = 0;
  let correct = 0;
  let incorrect = 0;
  let unattempted = 0;

  const subjectScores = {
    Physics: { score: 0, correct: 0, incorrect: 0, unattempted: 0, total: 0 },
    Chemistry: { score: 0, correct: 0, incorrect: 0, unattempted: 0, total: 0 },
    Mathematics: { score: 0, correct: 0, incorrect: 0, unattempted: 0, total: 0 }
  };

  const questionResults = [];

  for (const question of questions) {
    const qNum = question.question_number;
    const response = responses[qNum];
    const userAnswer = response?.answer;
    const correctAnswer = question.correct_answer;
    const isNumerical = question.question_type === 'numerical' || question.question_type === 'integer';
    const marking = isNumerical ? MARKING_SCHEME.numerical : MARKING_SCHEME.mcq;

    let marks = 0;
    let status = 'unattempted';

    if (!userAnswer || userAnswer === '') {
      marks = marking.unattempted;
      unattempted++;
      subjectScores[question.subject].unattempted++;
    } else if (isAnswerCorrect(userAnswer, correctAnswer, isNumerical)) {
      marks = marking.correct;
      correct++;
      status = 'correct';
      subjectScores[question.subject].correct++;
    } else {
      marks = marking.incorrect;
      incorrect++;
      status = 'incorrect';
      subjectScores[question.subject].incorrect++;
    }

    totalScore += marks;
    subjectScores[question.subject].score += marks;
    subjectScores[question.subject].total++;

    questionResults.push({
      question_number: qNum,
      question_id: question.question_id,
      subject: question.subject,
      question_type: question.question_type,
      user_answer: userAnswer,
      correct_answer: correctAnswer,
      is_correct: status === 'correct',
      marks_obtained: marks,
      time_spent: response?.time_spent_seconds || 0
    });
  }

  return {
    total_score: totalScore,
    max_score: 300,
    correct,
    incorrect,
    unattempted,
    accuracy: correct > 0 ? ((correct / (correct + incorrect)) * 100).toFixed(1) : 0,
    subject_scores: subjectScores,
    question_results: questionResults
  };
}

/**
 * Check if answer is correct
 * For numerical: allow small tolerance
 */
function isAnswerCorrect(userAnswer, correctAnswer, isNumerical) {
  if (isNumerical) {
    const userNum = parseFloat(userAnswer);
    const correctNum = parseFloat(correctAnswer);
    if (isNaN(userNum) || isNaN(correctNum)) {
      return userAnswer.toString().trim() === correctAnswer.toString().trim();
    }
    // Allow 0.01 tolerance for numerical answers
    return Math.abs(userNum - correctNum) < 0.01;
  }

  // MCQ: exact match (case-insensitive)
  return userAnswer.toString().trim().toUpperCase() === correctAnswer.toString().trim().toUpperCase();
}

/**
 * Look up NTA percentile based on score
 */
function lookupNTAPercentile(score) {
  for (const bracket of NTA_PERCENTILE_TABLE) {
    if (score >= bracket.minScore && score <= bracket.maxScore) {
      return bracket.percentile;
    }
  }
  // Below minimum
  return 1.0;
}

/**
 * Submit mock test and calculate results
 * @param {string} userId - User ID
 * @param {string} testId - Test ID
 * @param {Object} finalResponses - Any last-minute responses
 * @param {boolean} isAutoSubmit - Whether this is an auto-submit (timeout)
 */
async function submitMockTest(userId, testId, finalResponses = {}, isAutoSubmit = false) {
  // Get test session
  const testRef = db.collection('users').doc(userId).collection('mock_tests').doc(testId);
  const testDoc = await retryFirestoreOperation(async () => {
    return await testRef.get();
  });

  if (!testDoc.exists) {
    throw new Error('Test session not found');
  }

  const testData = testDoc.data();

  if (testData.status === 'completed') {
    throw new Error('Test already submitted');
  }

  // Merge final responses
  const allResponses = { ...testData.responses, ...finalResponses };

  // Load template with correct answers
  const template = await loadTemplateWithQuestions(testData.template_id);

  // Calculate score
  const scoreResult = calculateScore(template.questions, allResponses);

  // Look up NTA percentile
  const percentile = lookupNTAPercentile(scoreResult.total_score);

  // Calculate time taken
  const startedAt = testData.started_at?.toDate?.() || new Date(testData.started_at);
  const completedAt = new Date();
  const timeTakenSeconds = Math.floor((completedAt - startedAt) / 1000);

  // Prepare result document
  const result = {
    status: 'completed',
    completed_at: FieldValue.serverTimestamp(),
    is_auto_submit: isAutoSubmit,
    time_taken_seconds: timeTakenSeconds,

    // Scores
    score: scoreResult.total_score,
    max_score: scoreResult.max_score,
    percentile,
    accuracy: scoreResult.accuracy,

    // Breakdown
    correct_count: scoreResult.correct,
    incorrect_count: scoreResult.incorrect,
    unattempted_count: scoreResult.unattempted,

    // Subject-wise
    subject_scores: scoreResult.subject_scores,

    // Detailed results (for review)
    question_results: scoreResult.question_results,

    // Final responses
    responses: allResponses
  };

  // Update test document
  await retryFirestoreOperation(async () => {
    await testRef.update(result);
  });

  // Update user stats and theta
  await updateUserStatsFromMockTest(userId, result, template.questions);

  logger.info('Mock test submitted', {
    userId,
    testId,
    score: scoreResult.total_score,
    percentile,
    isAutoSubmit
  });

  return {
    test_id: testId,
    score: scoreResult.total_score,
    max_score: scoreResult.max_score,
    percentile,
    accuracy: scoreResult.accuracy,
    correct: scoreResult.correct,
    incorrect: scoreResult.incorrect,
    unattempted: scoreResult.unattempted,
    subject_scores: scoreResult.subject_scores,
    time_taken_seconds: timeTakenSeconds,
    is_auto_submit: isAutoSubmit
  };
}

// ============================================================================
// POST-TEST UPDATES
// ============================================================================

/**
 * Update user stats after mock test completion
 */
async function updateUserStatsFromMockTest(userId, result, questions) {
  const userRef = db.collection('users').doc(userId);

  try {
    // Get current user data
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    const userData = userDoc.data() || {};

    // Calculate updates
    const mockTestStats = userData.mock_test_stats || {
      total_tests: 0,
      total_score: 0,
      best_score: 0,
      best_percentile: 0,
      avg_score: 0,
      avg_percentile: 0,
      subject_accuracy: {
        Physics: { correct: 0, total: 0 },
        Chemistry: { correct: 0, total: 0 },
        Mathematics: { correct: 0, total: 0 }
      }
    };

    // Update stats
    mockTestStats.total_tests++;
    mockTestStats.total_score += result.score;
    mockTestStats.best_score = Math.max(mockTestStats.best_score, result.score);
    mockTestStats.best_percentile = Math.max(mockTestStats.best_percentile, result.percentile);
    mockTestStats.avg_score = mockTestStats.total_score / mockTestStats.total_tests;

    // Update subject accuracy
    for (const [subject, scores] of Object.entries(result.subject_scores)) {
      mockTestStats.subject_accuracy[subject].correct += scores.correct;
      mockTestStats.subject_accuracy[subject].total += scores.total;
    }

    // Update user document
    await retryFirestoreOperation(async () => {
      await userRef.update({
        mock_test_stats: mockTestStats,
        last_mock_test_at: FieldValue.serverTimestamp()
      });
    });

    // Update theta based on performance
    await updateThetaFromMockTest(userId, result, questions, userData);

    logger.info('User stats updated from mock test', {
      userId,
      totalTests: mockTestStats.total_tests,
      avgScore: mockTestStats.avg_score
    });

  } catch (error) {
    logger.error('Failed to update user stats from mock test', {
      userId,
      error: error.message
    });
    // Don't throw - stats update is not critical
  }
}

/**
 * Update theta values based on mock test performance
 * Uses chapter-level accuracy to adjust theta
 */
async function updateThetaFromMockTest(userId, result, questions, userData) {
  try {
    // Group results by chapter
    const chapterPerformance = {};

    for (const qResult of result.question_results) {
      const question = questions.find(q => q.question_number === qResult.question_number);
      if (!question?.chapter_key) continue;

      const chapterKey = question.chapter_key;
      if (!chapterPerformance[chapterKey]) {
        chapterPerformance[chapterKey] = {
          correct: 0,
          total: 0,
          difficulties: []
        };
      }

      chapterPerformance[chapterKey].total++;
      if (qResult.is_correct) {
        chapterPerformance[chapterKey].correct++;
      }

      const difficulty = question.irt_parameters?.difficulty_b || 0.9;
      chapterPerformance[chapterKey].difficulties.push(difficulty);
    }

    // Current theta data
    const thetaByChapter = userData.theta_by_chapter || {};

    // Update each chapter's theta based on performance
    for (const [chapterKey, perf] of Object.entries(chapterPerformance)) {
      if (perf.total < 2) continue; // Need at least 2 questions

      const accuracy = perf.correct / perf.total;
      const avgDifficulty = perf.difficulties.reduce((a, b) => a + b, 0) / perf.difficulties.length;

      // Current chapter theta
      const currentTheta = thetaByChapter[chapterKey]?.theta || 0;
      const currentSE = thetaByChapter[chapterKey]?.se || 0.5;
      const currentCount = thetaByChapter[chapterKey]?.questions_answered || 0;

      // Simple theta adjustment based on accuracy vs expected
      // If accuracy > 70% and avgDifficulty was at or above theta, increase theta
      // If accuracy < 50% and avgDifficulty was at or below theta, decrease theta
      let thetaDelta = 0;
      const expectedAccuracy = 0.5 + (currentTheta - avgDifficulty) * 0.1;

      if (accuracy > expectedAccuracy + 0.2) {
        thetaDelta = 0.1 * (accuracy - expectedAccuracy);
      } else if (accuracy < expectedAccuracy - 0.2) {
        thetaDelta = 0.1 * (accuracy - expectedAccuracy);
      }

      // Bound new theta
      const newTheta = Math.max(-3, Math.min(3, currentTheta + thetaDelta));
      const newSE = Math.max(0.15, currentSE * 0.95); // Reduce SE slightly

      thetaByChapter[chapterKey] = {
        theta: parseFloat(newTheta.toFixed(3)),
        se: parseFloat(newSE.toFixed(3)),
        questions_answered: currentCount + perf.total,
        last_updated: new Date().toISOString()
      };
    }

    // Recalculate subject and overall theta
    const subjectThetas = {};
    for (const subject of ['Physics', 'Chemistry', 'Mathematics']) {
      const subjectTheta = calculateSubjectTheta(thetaByChapter, subject.toLowerCase());
      subjectThetas[subject.toLowerCase()] = subjectTheta;
    }

    const overallTheta = calculateWeightedOverallTheta(subjectThetas);

    // Update user document
    const userRef = db.collection('users').doc(userId);
    await retryFirestoreOperation(async () => {
      await userRef.update({
        theta_by_chapter: thetaByChapter,
        theta_by_subject: subjectThetas,
        overall_theta: overallTheta,
        theta_updated_at: FieldValue.serverTimestamp()
      });
    });

    logger.info('Theta updated from mock test', {
      userId,
      chaptersUpdated: Object.keys(chapterPerformance).length,
      overallTheta
    });

  } catch (error) {
    logger.error('Failed to update theta from mock test', {
      userId,
      error: error.message
    });
    // Don't throw - theta update is not critical
  }
}

// ============================================================================
// TEST REVIEW
// ============================================================================

/**
 * Get detailed results for a completed test
 */
async function getTestResults(userId, testId) {
  const testDoc = await retryFirestoreOperation(async () => {
    return await db.collection('users')
      .doc(userId)
      .collection('mock_tests')
      .doc(testId)
      .get();
  });

  if (!testDoc.exists) {
    throw new Error('Test not found');
  }

  const testData = testDoc.data();

  if (testData.status !== 'completed') {
    throw new Error('Test not yet completed');
  }

  // Load template for full question details (including solutions)
  const template = await loadTemplateWithQuestions(testData.template_id);

  // Merge question details with results
  const questionsWithResults = template.questions.map(q => {
    const result = testData.question_results?.find(r => r.question_number === q.question_number);
    return {
      ...q,
      user_answer: result?.user_answer || null,
      is_correct: result?.is_correct || false,
      marks_obtained: result?.marks_obtained || 0,
      time_spent: result?.time_spent || 0
    };
  });

  return {
    test_id: testId,
    template_name: testData.template_name,
    completed_at: testData.completed_at,
    time_taken_seconds: testData.time_taken_seconds,
    score: testData.score,
    max_score: testData.max_score,
    percentile: testData.percentile,
    accuracy: testData.accuracy,
    correct_count: testData.correct_count,
    incorrect_count: testData.incorrect_count,
    unattempted_count: testData.unattempted_count,
    subject_scores: testData.subject_scores,
    questions: questionsWithResults
  };
}

/**
 * Abandon an in-progress test
 */
async function abandonTest(userId, testId) {
  const testRef = db.collection('users').doc(userId).collection('mock_tests').doc(testId);

  const testDoc = await retryFirestoreOperation(async () => {
    return await testRef.get();
  });

  if (!testDoc.exists) {
    throw new Error('Test not found');
  }

  if (testDoc.data().status !== 'in_progress') {
    throw new Error('Only in-progress tests can be abandoned');
  }

  await retryFirestoreOperation(async () => {
    await testRef.update({
      status: 'abandoned',
      abandoned_at: FieldValue.serverTimestamp()
    });
  });

  logger.info('Mock test abandoned', { userId, testId });

  return { success: true };
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  // Template management
  getAvailableTemplates,
  loadTemplateWithQuestions,

  // Test sessions
  startMockTest,
  getActiveTest,
  getActiveTestWithQuestions,
  getUserMockTestHistory,

  // Answers
  saveAnswer,
  clearAnswer,

  // Submission & scoring
  submitMockTest,
  calculateScore,
  lookupNTAPercentile,

  // Results
  getTestResults,
  abandonTest,

  // Rate limiting
  checkRateLimit
};
