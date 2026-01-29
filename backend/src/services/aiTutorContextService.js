/**
 * AI Tutor Context Service
 * Builds context objects from solutions, quizzes, and analytics data
 * for injection into AI Tutor conversation prompts
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { calculateFocusAreas, getMasteryStatus, getSubjectDisplayName, getChapterDisplayNameAsync } = require('./analyticsService');

// ID validation pattern - alphanumeric with limited special chars, max 128 chars
const VALID_ID_PATTERN = /^[a-zA-Z0-9_-]{1,128}$/;

/**
 * Validate and sanitize a document ID
 * @param {string} id - The ID to validate
 * @param {string} fieldName - Name of the field for error messages
 * @returns {string} The validated ID
 * @throws {Error} If ID is invalid
 */
function validateDocumentId(id, fieldName) {
  if (!id || typeof id !== 'string') {
    throw new Error(`${fieldName} is required and must be a string`);
  }

  const trimmedId = id.trim();

  if (!VALID_ID_PATTERN.test(trimmedId)) {
    throw new Error(`${fieldName} contains invalid characters or exceeds length limit`);
  }

  // Prevent path traversal attempts
  if (trimmedId.includes('..') || trimmedId.includes('/') || trimmedId.includes('\\')) {
    throw new Error(`${fieldName} contains invalid path characters`);
  }

  return trimmedId;
}

/**
 * Build context from a Snap & Solve solution
 * @param {string} solutionId - Solution document ID (snap ID)
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Context object for solution
 */
async function buildSolutionContext(solutionId, userId) {
  try {
    // Validate IDs to prevent injection attacks
    const validSolutionId = validateDocumentId(solutionId, 'solutionId');
    const validUserId = validateDocumentId(userId, 'userId');

    const snapRef = db.collection('users').doc(validUserId).collection('snaps').doc(validSolutionId);
    const snapDoc = await retryFirestoreOperation(() => snapRef.get());

    if (!snapDoc.exists) {
      logger.warn('Solution not found for context', { solutionId: validSolutionId });
      return null;
    }

    const snap = snapDoc.data();

    // Log metadata only (no user content for privacy)
    logger.debug('Building solution context', {
      solutionId: validSolutionId,
      hasQuestion: !!(snap.recognizedQuestion || snap.question),
      hasApproach: !!snap.solution?.approach,
      stepsCount: snap.solution?.steps?.length || 0,
      subject: snap.subject,
      topic: snap.topic
    });

    // Build context object
    // Note: priyaMaamTip uses consistent camelCase (priya_maam_tip is legacy)
    const context = {
      type: 'solution',
      contextId: validSolutionId,
      title: `${snap.topic || 'Problem'} - ${getSubjectDisplayName(snap.subject || 'General')}`,
      snapshot: {
        question: snap.recognizedQuestion || snap.question || '',
        subject: snap.subject,
        topic: snap.topic,
        difficulty: snap.difficulty,
        approach: snap.solution?.approach || '',
        steps: snap.solution?.steps || [],
        finalAnswer: snap.solution?.finalAnswer || '',
        priyaMaamTip: snap.solution?.priyaMaamTip || snap.solution?.priya_maam_tip || '',
        conceptsTested: snap.conceptsTested || []
        // Note: imageUrl removed - not needed in context and increases storage
      }
    };

    logger.info('Solution context built', {
      solutionId: validSolutionId,
      subject: snap.subject,
      topic: snap.topic
    });

    return context;
  } catch (error) {
    logger.error('Error building solution context', { error: error.message });
    throw error;
  }
}

/**
 * Build context from quiz results
 * @param {string} quizId - Quiz document ID
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Context object for quiz
 */
async function buildQuizContext(quizId, userId) {
  try {
    // Validate IDs
    const validQuizId = validateDocumentId(quizId, 'quizId');
    const validUserId = validateDocumentId(userId, 'userId');

    const quizRef = db.collection('daily_quizzes').doc(validUserId).collection('quizzes').doc(validQuizId);
    const quizDoc = await retryFirestoreOperation(() => quizRef.get());

    if (!quizDoc.exists) {
      logger.warn('Quiz not found for context', { quizId: validQuizId });
      return null;
    }

    const quiz = quizDoc.data();

    // Optimized: Fetch incorrect questions directly instead of all questions
    // This reduces reads from N to min(5, incorrect_count)
    const [incorrectSnapshot, allQuestionsSnapshot] = await Promise.all([
      // Get only incorrect questions (limited to 5 for context)
      retryFirestoreOperation(() =>
        quizRef.collection('questions')
          .where('is_correct', '==', false)
          .orderBy('position', 'asc')
          .limit(5)
          .get()
      ),
      // Get aggregate stats efficiently - just count totals
      retryFirestoreOperation(() =>
        quizRef.collection('questions')
          .select('is_correct', 'subject') // Only fetch needed fields
          .get()
      )
    ]);

    // Process incorrect questions
    const incorrectQuestions = incorrectSnapshot.docs.map(doc => {
      const q = doc.data();
      return {
        position: q.position,
        question: q.question_text || `Question ${q.position}`,
        studentAnswer: q.student_answer,
        correctAnswer: q.correct_answer,
        subject: q.subject,
        chapter: q.chapter
      };
    });

    // Calculate stats from lightweight query
    const allQuestions = allQuestionsSnapshot.docs.map(doc => doc.data());
    const correctCount = allQuestions.filter(q => q.is_correct === true).length;
    const totalCount = allQuestions.length;

    const context = {
      type: 'quiz',
      contextId: validQuizId,
      title: `Daily Quiz Review (${correctCount}/${totalCount})`,
      snapshot: {
        score: correctCount,
        total: totalCount,
        accuracy: totalCount > 0 ? Math.round((correctCount / totalCount) * 100) : 0,
        completedAt: quiz.completed_at ? quiz.completed_at.toDate().toISOString() : null,
        incorrectQuestions: incorrectQuestions,
        subjectBreakdown: calculateSubjectBreakdown(allQuestions)
      }
    };

    logger.debug('Quiz context built', {
      quizId: validQuizId,
      score: correctCount,
      total: totalCount
    });

    return context;
  } catch (error) {
    logger.error('Error building quiz context', { error: error.message });
    throw error;
  }
}

/**
 * Calculate subject breakdown from quiz questions
 * @param {Array} questions - Quiz questions
 * @returns {Object} Subject-wise breakdown
 */
function calculateSubjectBreakdown(questions) {
  const breakdown = {};

  questions.forEach(q => {
    const subject = (q.subject || 'unknown').toLowerCase();
    if (!breakdown[subject]) {
      breakdown[subject] = { total: 0, correct: 0 };
    }
    breakdown[subject].total++;
    if (q.is_correct) {
      breakdown[subject].correct++;
    }
  });

  return breakdown;
}

/**
 * Build context from a chapter practice session
 * @param {string} sessionId - Chapter practice session ID (starts with cp_)
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Context object for chapter practice
 */
async function buildChapterPracticeContext(sessionId, userId) {
  try {
    // Validate IDs
    const validSessionId = validateDocumentId(sessionId, 'sessionId');
    const validUserId = validateDocumentId(userId, 'userId');

    const sessionRef = db.collection('chapter_practice_sessions')
      .doc(validUserId)
      .collection('sessions')
      .doc(validSessionId);

    const sessionDoc = await retryFirestoreOperation(() => sessionRef.get());

    if (!sessionDoc.exists) {
      logger.warn('Chapter practice session not found for context', { sessionId: validSessionId });
      return null;
    }

    const session = sessionDoc.data();

    // Fetch questions from session subcollection
    const [incorrectSnapshot, allQuestionsSnapshot] = await Promise.all([
      // Get only incorrect questions (limited to 5 for context)
      retryFirestoreOperation(() =>
        sessionRef.collection('questions')
          .where('is_correct', '==', false)
          .orderBy('position', 'asc')
          .limit(5)
          .get()
      ),
      // Get all questions for stats
      retryFirestoreOperation(() =>
        sessionRef.collection('questions')
          .where('answered', '==', true)
          .select('is_correct', 'question_text', 'position', 'student_answer', 'correct_answer')
          .get()
      )
    ]);

    // Process incorrect questions
    const incorrectQuestions = incorrectSnapshot.docs.map(doc => {
      const q = doc.data();
      return {
        position: q.position,
        question: q.question_text || `Question ${q.position}`,
        studentAnswer: q.student_answer,
        correctAnswer: q.correct_answer
      };
    });

    // Calculate stats
    const allQuestions = allQuestionsSnapshot.docs.map(doc => doc.data());
    const correctCount = allQuestions.filter(q => q.is_correct === true).length;
    const totalAnswered = allQuestions.length;
    const totalQuestions = session.total_questions || 0;

    const context = {
      type: 'chapterPractice',
      contextId: validSessionId,
      title: `${session.chapter_name} Practice - ${session.subject}`,
      snapshot: {
        chapterName: session.chapter_name,
        subject: session.subject,
        score: correctCount,
        totalAnswered: totalAnswered,
        totalQuestions: totalQuestions,
        accuracy: totalAnswered > 0 ? Math.round((correctCount / totalAnswered) * 100) : 0,
        completedAt: session.completed_at ? session.completed_at.toDate().toISOString() : null,
        status: session.status,
        incorrectQuestions: incorrectQuestions
      }
    };

    logger.debug('Chapter practice context built', {
      sessionId: validSessionId,
      chapterName: session.chapter_name,
      score: correctCount,
      totalAnswered: totalAnswered
    });

    return context;
  } catch (error) {
    logger.error('Error building chapter practice context', { error: error.message });
    throw error;
  }
}

/**
 * Build context from a mock test result
 * @param {string} testId - Mock test ID
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Context object for mock test
 */
async function buildMockTestContext(testId, userId) {
  try {
    // Validate IDs
    const validTestId = validateDocumentId(testId, 'testId');
    const validUserId = validateDocumentId(userId, 'userId');

    const testRef = db.collection('users')
      .doc(validUserId)
      .collection('mock_tests')
      .doc(validTestId);

    const testDoc = await retryFirestoreOperation(() => testRef.get());

    if (!testDoc.exists) {
      logger.warn('Mock test not found for context', { testId: validTestId });
      return null;
    }

    const test = testDoc.data();

    // Only build context for completed tests
    if (test.status !== 'completed') {
      logger.warn('Mock test not completed, cannot build context', {
        testId: validTestId,
        status: test.status
      });
      return null;
    }

    // Get incorrect questions (limited to 5 for context)
    const incorrectQuestions = (test.question_results || [])
      .filter(q => !q.is_correct && q.user_answer !== null)
      .slice(0, 5)
      .map(q => ({
        questionNumber: q.question_number,
        subject: q.subject,
        userAnswer: q.user_answer,
        correctAnswer: q.correct_answer,
        marksObtained: q.marks_obtained
      }));

    // Calculate subject-wise performance
    const subjectPerformance = Object.entries(test.subject_scores || {}).map(([subject, data]) => ({
      subject: getSubjectDisplayName(subject),
      score: data.score,
      maxScore: data.max_score,
      accuracy: data.max_score > 0 ? Math.round((data.score / data.max_score) * 100) : 0
    }));

    const context = {
      type: 'mockTest',
      contextId: validTestId,
      title: `${test.template_name || 'Mock Test'} Review`,
      snapshot: {
        templateName: test.template_name,
        score: test.score || 0,
        maxScore: test.max_score || 300,
        percentile: test.percentile || 0,
        accuracy: test.accuracy ? Math.round(test.accuracy * 100) : 0,
        completedAt: test.completed_at ? test.completed_at.toDate().toISOString() : null,
        timeTakenMinutes: test.time_taken_seconds ? Math.round(test.time_taken_seconds / 60) : 0,
        correctCount: test.correct_count || 0,
        incorrectCount: test.incorrect_count || 0,
        unattemptedCount: test.unattempted_count || 0,
        totalQuestions: 90, // JEE Main format
        subjectPerformance: subjectPerformance,
        incorrectQuestions: incorrectQuestions
      }
    };

    logger.debug('Mock test context built', {
      testId: validTestId,
      score: test.score,
      maxScore: test.max_score,
      percentile: test.percentile
    });

    return context;
  } catch (error) {
    logger.error('Error building mock test context', { error: error.message });
    throw error;
  }
}

/**
 * Build context from analytics/theta data
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Context object for analytics
 */
async function buildAnalyticsContext(userId) {
  try {
    const validUserId = validateDocumentId(userId, 'userId');
    const userRef = db.collection('users').doc(validUserId);
    const userDoc = await retryFirestoreOperation(() => userRef.get());

    if (!userDoc.exists) {
      logger.warn('User not found for analytics context');
      return null;
    }

    const userData = userDoc.data();
    const thetaByChapter = userData.theta_by_chapter || {};
    const thetaBySubject = userData.theta_by_subject || {};

    // Calculate focus areas
    const focusAreas = await calculateFocusAreas(thetaByChapter);

    // Get subject strengths
    const subjects = Object.entries(thetaBySubject)
      .map(([subject, data]) => ({
        subject: getSubjectDisplayName(subject),
        percentile: data.percentile || 50,
        status: getMasteryStatus(data.percentile || 50)
      }))
      .sort((a, b) => b.percentile - a.percentile);

    const context = {
      type: 'analytics',
      contextId: null,
      title: 'My Progress',
      snapshot: {
        overallPercentile: userData.overall_percentile || 50,
        overallTheta: userData.overall_theta || 0,
        subjectPerformance: subjects,
        strongestSubject: subjects[0] || null,
        weakestSubject: subjects[subjects.length - 1] || null,
        focusAreas: focusAreas.map(area => ({
          chapter: area.chapter_name,
          chapterKey: area.chapter_key,
          subject: area.subject_name,
          percentile: area.percentile,
          reason: area.reason
        })),
        totalQuizzes: userData.completed_quiz_count || 0,
        streak: userData.streak || 0
      }
    };

    return context;
  } catch (error) {
    logger.error('Error building analytics context', { error: error.message });
    throw error;
  }
}

/**
 * Build general context (from home screen, no specific topic)
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Context object for general chat
 */
async function buildGeneralContext(userId) {
  try {
    const validUserId = validateDocumentId(userId, 'userId');
    const userRef = db.collection('users').doc(validUserId);
    const userDoc = await retryFirestoreOperation(() => userRef.get());

    if (!userDoc.exists) {
      return {
        type: 'general',
        contextId: null,
        title: 'General Chat',
        snapshot: null
      };
    }

    const userData = userDoc.data();

    return {
      type: 'general',
      contextId: null,
      title: 'General Chat',
      snapshot: {
        overallPercentile: userData.overall_percentile || 50,
        streak: userData.streak || 0,
        totalQuizzes: userData.completed_quiz_count || 0
      }
    };
  } catch (error) {
    logger.error('Error building general context', { error: error.message });
    // Return minimal context on error
    return {
      type: 'general',
      contextId: null,
      title: 'General Chat',
      snapshot: null
    };
  }
}

/**
 * Get student profile data for system prompt
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Student profile data
 */
async function getStudentProfile(userId) {
  try {
    const validUserId = validateDocumentId(userId, 'userId');
    const userRef = db.collection('users').doc(validUserId);
    const userDoc = await retryFirestoreOperation(() => userRef.get());

    if (!userDoc.exists) {
      return null;
    }

    const userData = userDoc.data();
    const thetaByChapter = userData.theta_by_chapter || {};
    const thetaBySubject = userData.theta_by_subject || {};

    // Calculate strengths (top 3 chapters)
    const strengths = Object.entries(thetaByChapter)
      .filter(([_, data]) => (data.percentile || 0) >= 70)
      .sort((a, b) => (b[1].percentile || 0) - (a[1].percentile || 0))
      .slice(0, 3)
      .map(([key, _]) => formatChapterKey(key));

    // Calculate weaknesses (bottom 3 chapters with attempts)
    const weaknesses = Object.entries(thetaByChapter)
      .filter(([_, data]) => (data.attempts || 0) > 0 && (data.percentile || 0) < 50)
      .sort((a, b) => (a[1].percentile || 0) - (b[1].percentile || 0))
      .slice(0, 3)
      .map(([key, _]) => formatChapterKey(key));

    return {
      firstName: userData.firstName || userData.first_name,
      overallTheta: userData.overall_theta,
      overallPercentile: userData.overall_percentile,
      thetaBySubject: Object.fromEntries(
        Object.entries(thetaBySubject).map(([subject, data]) => [
          subject,
          { percentile: data.percentile || 50 }
        ])
      ),
      strengths,
      weaknesses,
      streak: userData.streak || 0,
      totalQuizzes: userData.completed_quiz_count || 0
    };
  } catch (error) {
    logger.error('Error getting student profile', { error: error.message });
    return null;
  }
}

/**
 * Format chapter key to readable name
 * @param {string} chapterKey - e.g., "physics_kinematics"
 * @returns {string} Formatted name e.g., "Kinematics"
 */
function formatChapterKey(chapterKey) {
  return chapterKey
    .replace(/^(physics|chemistry|maths|mathematics)_/, '')
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

/**
 * Build context based on context type
 * @param {string} contextType - 'solution', 'quiz', 'analytics', or 'general'
 * @param {string} contextId - ID of the context item (solution/quiz ID)
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Context object
 */
async function buildContext(contextType, contextId, userId) {
  switch (contextType) {
    case 'solution':
      if (!contextId) {
        throw new Error('contextId required for solution context');
      }
      return buildSolutionContext(contextId, userId);

    case 'quiz':
      if (!contextId) {
        throw new Error('contextId required for quiz context');
      }
      return buildQuizContext(contextId, userId);

    case 'chapterPractice':
      if (!contextId) {
        throw new Error('contextId required for chapter practice context');
      }
      return buildChapterPracticeContext(contextId, userId);

    case 'mockTest':
      if (!contextId) {
        throw new Error('contextId required for mock test context');
      }
      return buildMockTestContext(contextId, userId);

    case 'analytics':
      return buildAnalyticsContext(userId);

    case 'general':
    default:
      return buildGeneralContext(userId);
  }
}

module.exports = {
  buildSolutionContext,
  buildQuizContext,
  buildChapterPracticeContext,
  buildMockTestContext,
  buildAnalyticsContext,
  buildGeneralContext,
  buildContext,
  getStudentProfile
};
