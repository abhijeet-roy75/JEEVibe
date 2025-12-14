/**
 * Daily Quiz Service
 * 
 * Main service for generating daily adaptive quizzes.
 * Implements two-phase learning strategy:
 * - Exploration (quizzes 0-13): Map student ability across topics
 * - Exploitation (quizzes 14+): Focus on weak areas
 * 
 * Features:
 * - Two-phase algorithm (exploration vs exploitation)
 * - Chapter-level question selection
 * - Subject interleaving
 * - Review question integration
 * - Circuit breaker recovery quizzes
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { withTimeout } = require('../utils/timeout');
const { selectQuestionsForChapters, selectAnyAvailableQuestions, getRecentQuestionIds } = require('./questionSelectionService');
const { getReviewQuestions } = require('./spacedRepetitionService');
const { checkConsecutiveFailures, generateRecoveryQuiz } = require('./circuitBreakerService');
const { formatChapterKey } = require('./thetaCalculationService');

// ============================================================================
// CONSTANTS
// ============================================================================

const QUIZ_SIZE = 10; // Questions per quiz
const EXPLORATION_PHASE_QUIZZES = 14; // Quizzes 0-13 are exploration
const REVIEW_QUESTIONS_PER_QUIZ = 1; // Number of review questions
const EXPLORATION_QUESTIONS_PER_QUIZ = 7; // Exploration questions in exploration phase
const DELIBERATE_PRACTICE_QUESTIONS_PER_QUIZ = 6; // Deliberate practice in exploitation phase
const QUIZ_GENERATION_TIMEOUT_MS = 60000; // 60 seconds timeout for quiz generation

// Subject distribution targets
const SUBJECT_DISTRIBUTION = {
  physics: 0.35,    // 35%
  chemistry: 0.30,  // 30%
  mathematics: 0.35 // 35%
};

// ============================================================================
// PHASE DETECTION
// ============================================================================

/**
 * Determine learning phase based on completed quiz count
 * 
 * @param {number} completedQuizCount
 * @returns {string} 'exploration' or 'exploitation'
 */
function getLearningPhase(completedQuizCount) {
  return completedQuizCount < EXPLORATION_PHASE_QUIZZES ? 'exploration' : 'exploitation';
}

// ============================================================================
// CHAPTER SELECTION
// ============================================================================

/**
 * Select chapters for exploration phase
 * Prioritizes chapters with fewer attempts, ensuring subject diversity
 * 
 * @param {Object} chapterThetas - Object mapping chapterKey to theta data
 * @param {number} count - Number of chapters to select
 * @returns {Array} Selected chapter keys
 */
function selectChaptersForExploration(chapterThetas, count = 7) {
  // Group chapters by subject
  const chaptersBySubject = {
    physics: [],
    chemistry: [],
    mathematics: []
  };
  
  // Extract subject from chapter key (format: "subject_chapter_name")
  Object.entries(chapterThetas).forEach(([key, data]) => {
    const subject = key.split('_')[0]?.toLowerCase();
    if (subject && chaptersBySubject[subject]) {
      chaptersBySubject[subject].push({
        chapter_key: key,
        attempts: data.attempts || 0,
        theta: data.theta || 0
      });
    }
  });
  
  // Sort each subject's chapters by attempts (fewer attempts first), then by theta
  Object.keys(chaptersBySubject).forEach(subject => {
    chaptersBySubject[subject].sort((a, b) => {
      if (a.attempts !== b.attempts) {
        return a.attempts - b.attempts;
      }
      return a.theta - b.theta;
    });
  });
  
  // Select chapters ensuring subject diversity
  // Target distribution: ~35% physics, ~30% chemistry, ~35% mathematics
  const selected = [];
  const subjectTargets = {
    physics: Math.ceil(count * 0.35),
    chemistry: Math.ceil(count * 0.30),
    mathematics: Math.ceil(count * 0.35)
  };
  
  // Round-robin selection to ensure diversity
  const subjectKeys = ['physics', 'chemistry', 'mathematics'];
  let subjectIndex = 0;
  let selectedCount = 0;
  
  while (selectedCount < count) {
    let progressMade = false;
    
    // Try each subject in round-robin
    for (let i = 0; i < subjectKeys.length && selectedCount < count; i++) {
      const subject = subjectKeys[(subjectIndex + i) % subjectKeys.length];
      const subjectChapters = chaptersBySubject[subject];
      const subjectSelected = selected.filter(c => {
        const cSubject = c.split('_')[0]?.toLowerCase();
        return cSubject === subject;
      }).length;
      
      // Check if we've reached target for this subject or no more chapters available
      if (subjectSelected >= subjectTargets[subject] || subjectChapters.length === 0) {
        continue;
      }
      
      // Select the next chapter from this subject
      const nextChapter = subjectChapters.shift();
      if (nextChapter) {
        selected.push(nextChapter.chapter_key);
        selectedCount++;
        progressMade = true;
      }
    }
    
    // If no progress made, break to avoid infinite loop
    if (!progressMade) {
      break;
    }
    
    subjectIndex = (subjectIndex + 1) % subjectKeys.length;
  }
  
  // If we still need more chapters, fill from any available
  if (selectedCount < count) {
    const remaining = [];
    Object.values(chaptersBySubject).forEach(subjectChapters => {
      remaining.push(...subjectChapters);
    });
    
    remaining.sort((a, b) => {
      if (a.attempts !== b.attempts) {
        return a.attempts - b.attempts;
      }
      return a.theta - b.theta;
    });
    
    while (selectedCount < count && remaining.length > 0) {
      const nextChapter = remaining.shift();
      if (!selected.includes(nextChapter.chapter_key)) {
        selected.push(nextChapter.chapter_key);
        selectedCount++;
      }
    }
  }
  
  logger.info('Chapters selected for exploration with subject diversity', {
    selected,
    subjectDistribution: {
      physics: selected.filter(c => c.split('_')[0]?.toLowerCase() === 'physics').length,
      chemistry: selected.filter(c => c.split('_')[0]?.toLowerCase() === 'chemistry').length,
      mathematics: selected.filter(c => c.split('_')[0]?.toLowerCase() === 'mathematics').length
    }
  });
  
  return selected;
}

/**
 * Select chapters for exploitation phase (deliberate practice)
 * Prioritizes weak chapters (low theta), ensuring subject diversity
 * 
 * @param {Object} chapterThetas - Object mapping chapterKey to theta data
 * @param {number} count - Number of chapters to select
 * @returns {Array} Selected chapter keys
 */
function selectChaptersForExploitation(chapterThetas, count = 6) {
  // Group chapters by subject
  const chaptersBySubject = {
    physics: [],
    chemistry: [],
    mathematics: []
  };
  
  // Extract subject from chapter key and filter for explored chapters (>= 2 attempts)
  Object.entries(chapterThetas)
    .filter(([_, data]) => (data.attempts || 0) >= 2) // At least 2 attempts (explored)
    .forEach(([key, data]) => {
      const subject = key.split('_')[0]?.toLowerCase();
      if (subject && chaptersBySubject[subject]) {
        chaptersBySubject[subject].push({
          chapter_key: key,
          theta: data.theta || 0,
          attempts: data.attempts || 0
        });
      }
    });
  
  // Sort each subject's chapters by theta (lower = weaker = priority), then by attempts
  Object.keys(chaptersBySubject).forEach(subject => {
    chaptersBySubject[subject].sort((a, b) => {
      // Prioritize lower theta (weaker areas)
      if (Math.abs(a.theta - b.theta) > 0.1) {
        return a.theta - b.theta;
      }
      // Secondary: prioritize more attempts (more data)
      return b.attempts - a.attempts;
    });
  });
  
  // Select chapters ensuring subject diversity
  // Target distribution: ~35% physics, ~30% chemistry, ~35% mathematics
  const selected = [];
  const subjectTargets = {
    physics: Math.ceil(count * 0.35),
    chemistry: Math.ceil(count * 0.30),
    mathematics: Math.ceil(count * 0.35)
  };
  
  // Round-robin selection to ensure diversity
  const subjectKeys = ['physics', 'chemistry', 'mathematics'];
  let subjectIndex = 0;
  let selectedCount = 0;
  
  while (selectedCount < count) {
    let progressMade = false;
    
    // Try each subject in round-robin
    for (let i = 0; i < subjectKeys.length && selectedCount < count; i++) {
      const subject = subjectKeys[(subjectIndex + i) % subjectKeys.length];
      const subjectChapters = chaptersBySubject[subject];
      const subjectSelected = selected.filter(c => {
        const cSubject = c.split('_')[0]?.toLowerCase();
        return cSubject === subject;
      }).length;
      
      // Check if we've reached target for this subject or no more chapters available
      if (subjectSelected >= subjectTargets[subject] || subjectChapters.length === 0) {
        continue;
      }
      
      // Select the next chapter from this subject
      const nextChapter = subjectChapters.shift();
      if (nextChapter) {
        selected.push(nextChapter.chapter_key);
        selectedCount++;
        progressMade = true;
      }
    }
    
    // If no progress made, break to avoid infinite loop
    if (!progressMade) {
      break;
    }
    
    subjectIndex = (subjectIndex + 1) % subjectKeys.length;
  }
  
  // If we still need more chapters, fill from any available
  if (selectedCount < count) {
    const remaining = [];
    Object.values(chaptersBySubject).forEach(subjectChapters => {
      remaining.push(...subjectChapters);
    });
    
    remaining.sort((a, b) => {
      if (Math.abs(a.theta - b.theta) > 0.1) {
        return a.theta - b.theta;
      }
      return b.attempts - a.attempts;
    });
    
    while (selectedCount < count && remaining.length > 0) {
      const nextChapter = remaining.shift();
      if (!selected.includes(nextChapter.chapter_key)) {
        selected.push(nextChapter.chapter_key);
        selectedCount++;
      }
    }
  }
  
  logger.info('Chapters selected for exploitation with subject diversity', {
    selected,
    subjectDistribution: {
      physics: selected.filter(c => c.split('_')[0]?.toLowerCase() === 'physics').length,
      chemistry: selected.filter(c => c.split('_')[0]?.toLowerCase() === 'chemistry').length,
      mathematics: selected.filter(c => c.split('_')[0]?.toLowerCase() === 'mathematics').length
    }
  });
  
  return selected;
}

// ============================================================================
// SUBJECT BALANCING
// ============================================================================

/**
 * Balance questions across subjects
 * 
 * @param {Array} questions - Question documents
 * @param {Object} targets - Target distribution {physics: 0.35, ...}
 * @returns {Array} Balanced question array
 */
function balanceSubjects(questions, targets = SUBJECT_DISTRIBUTION) {
  const subjectCounts = {
    physics: 0,
    chemistry: 0,
    mathematics: 0
  };
  
  const subjectQueues = {
    physics: [],
    chemistry: [],
    mathematics: []
  };
  
  // Group questions by subject
  questions.forEach(q => {
    const subject = q.subject?.toLowerCase();
    if (subject && subjectQueues[subject]) {
      subjectQueues[subject].push(q);
      subjectCounts[subject]++;
    }
  });
  
  // Calculate target counts
  const total = questions.length;
  const targetCounts = {
    physics: Math.round(total * targets.physics),
    chemistry: Math.round(total * targets.chemistry),
    mathematics: Math.round(total * targets.mathematics)
  };
  
  // Interleave subjects
  const balanced = [];
  const used = { physics: 0, chemistry: 0, mathematics: 0 };
  
  // Safety limit to prevent infinite loops
  let iterations = 0;
  const MAX_ITERATIONS = total * 3; // Allow up to 3x total iterations
  
  while (balanced.length < total && iterations < MAX_ITERATIONS) {
    iterations++;
    let progressMade = false;
    
    // Try to add from each subject in round-robin
    for (const subject of ['physics', 'chemistry', 'mathematics']) {
      if (balanced.length >= total) break;
      if (used[subject] >= targetCounts[subject]) continue;
      if (subjectQueues[subject].length === 0) continue;
      
      // Check if we've had 3+ consecutive from same subject
      const lastThree = balanced.slice(-3);
      const sameSubjectCount = lastThree.filter(q => q.subject?.toLowerCase() === subject).length;
      
      if (sameSubjectCount >= 3) {
        continue; // Skip to avoid 3+ consecutive
      }
      
      balanced.push(subjectQueues[subject].shift());
      used[subject]++;
      progressMade = true;
    }
    
    // If no progress made in this iteration, break to avoid infinite loop
    if (!progressMade) {
      break;
    }
  }
  
  // If we're stuck or hit iteration limit, add remaining questions
  if (balanced.length < total) {
    for (const subject of ['physics', 'chemistry', 'mathematics']) {
      while (subjectQueues[subject].length > 0 && balanced.length < total) {
        balanced.push(subjectQueues[subject].shift());
      }
    }
  }
  
  // Log warning if we couldn't balance completely
  if (balanced.length < total) {
    logger.warn('Could not balance all subjects completely', {
      balanced: balanced.length,
      total,
      iterations
    });
  }
  
  return balanced;
}

// ============================================================================
// QUIZ GENERATION
// ============================================================================

/**
 * Generate daily quiz for a user
 * 
 * @param {string} userId
 * @returns {Promise<Object>} Quiz data with questions
 */
async function generateDailyQuiz(userId) {
  // Wrap in timeout to prevent long-running operations
  return await withTimeout(
    generateDailyQuizInternal(userId),
    QUIZ_GENERATION_TIMEOUT_MS,
    'Quiz generation timed out'
  );
}

async function generateDailyQuizInternal(userId) {
  try {
    logger.info('Starting quiz generation internal', { userId });
    
    // Get user data
    const userRef = db.collection('users').doc(userId);
    logger.info('Fetching user data', { userId });
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });
    
    if (!userDoc.exists) {
      throw new Error(`User ${userId} not found`);
    }
    
    const userData = userDoc.data();
    logger.info('User data fetched', { userId, hasAssessment: !!userData.assessment?.completed_at });
    
    // Check if assessment completed
    if (!userData.assessment?.completed_at) {
      throw new Error('User must complete initial assessment before daily quizzes');
    }
    
    const completedQuizCount = userData.completed_quiz_count || 0;
    const learningPhase = getLearningPhase(completedQuizCount);
    const thetaByChapter = userData.theta_by_chapter || {};
    logger.info('Learning phase determined', { userId, learningPhase, completedQuizCount, chapterCount: Object.keys(thetaByChapter).length });
    
    // Check circuit breaker
    logger.info('Checking circuit breaker', { userId });
    const failureCheck = await checkConsecutiveFailures(userId);
    logger.info('Circuit breaker check complete', { userId, shouldTrigger: failureCheck.shouldTrigger });
    
    if (failureCheck.shouldTrigger) {
      logger.info('Circuit breaker triggered, generating recovery quiz', { userId });
      return await generateRecoveryQuizWrapper(userId, thetaByChapter);
    }
    
    // Get recent question IDs to exclude
    logger.info('Getting recent question IDs', { userId });
    const excludeQuestionIds = await getRecentQuestionIds(userId);
    logger.info('Recent question IDs fetched', { userId, excludeCount: excludeQuestionIds.size });
    
    // Get review questions (1 per quiz)
    // If review questions fail (e.g., missing index), continue without them
    let reviewQuestions = [];
    try {
      logger.info('Getting review questions', { userId });
      reviewQuestions = await getReviewQuestions(userId, REVIEW_QUESTIONS_PER_QUIZ);
      reviewQuestions.forEach(q => excludeQuestionIds.add(q.question_id));
      logger.info('Review questions fetched', { userId, reviewCount: reviewQuestions.length });
    } catch (error) {
      logger.warn('Failed to get review questions, continuing without them', {
        userId,
        error: error.message
      });
      reviewQuestions = []; // Continue without review questions
    }
    
    let selectedQuestions = [];
    
    if (learningPhase === 'exploration') {
      logger.info('Exploration phase: selecting chapters', { userId });
      // Exploration phase: Map ability across topics
      const selectedChapters = selectChaptersForExploration(thetaByChapter, EXPLORATION_QUESTIONS_PER_QUIZ);
      logger.info('Chapters selected for exploration', { userId, selectedChapters, count: selectedChapters.length });
      
      if (selectedChapters.length === 0) {
        // Fallback: use all available chapters
        selectedChapters.push(...Object.keys(thetaByChapter).slice(0, EXPLORATION_QUESTIONS_PER_QUIZ));
        logger.info('Using fallback chapters', { userId, selectedChapters });
      }
      
      // Build chapter thetas map for selection
      const chapterThetasMap = {};
      selectedChapters.forEach(chapterKey => {
        const chapterData = thetaByChapter[chapterKey];
        chapterThetasMap[chapterKey] = chapterData?.theta || 0.0;
      });
      
      logger.info('Selecting exploration questions', { userId, chapterCount: Object.keys(chapterThetasMap).length, chapters: Object.keys(chapterThetasMap) });
      // Select questions for selected chapters
      const explorationQuestions = await selectQuestionsForChapters(
        chapterThetasMap,
        excludeQuestionIds,
        { questionsPerChapter: 1 }
      );
      logger.info('Exploration questions selected', { userId, questionCount: explorationQuestions.length });
      
      selectedQuestions.push(...explorationQuestions);
    } else {
      logger.info('Exploitation phase: selecting weak chapters', { userId });
      // Exploitation phase: Focus on weak areas
      const selectedChapters = selectChaptersForExploitation(thetaByChapter, DELIBERATE_PRACTICE_QUESTIONS_PER_QUIZ);
      logger.info('Weak chapters selected', { userId, selectedChapters, count: selectedChapters.length });
      
      if (selectedChapters.length === 0) {
        // Fallback: use all available chapters
        selectedChapters.push(...Object.keys(thetaByChapter).slice(0, DELIBERATE_PRACTICE_QUESTIONS_PER_QUIZ));
        logger.info('Using fallback chapters', { userId, selectedChapters });
      }
      
      const chapterThetasMap = {};
      selectedChapters.forEach(chapterKey => {
        const chapterData = thetaByChapter[chapterKey];
        chapterThetasMap[chapterKey] = chapterData?.theta || 0.0;
      });
      
      logger.info('Selecting practice questions', { userId, chapterCount: Object.keys(chapterThetasMap).length, chapters: Object.keys(chapterThetasMap) });
      const practiceQuestions = await selectQuestionsForChapters(
        chapterThetasMap,
        excludeQuestionIds,
        { questionsPerChapter: 1 }
      );
      logger.info('Practice questions selected', { userId, questionCount: practiceQuestions.length });
      
      selectedQuestions.push(...practiceQuestions);
    }
    
    // Add review questions
    reviewQuestions.forEach(q => {
      selectedQuestions.push({
        ...q,
        selection_reason: 'review',
        chapter_key: q.chapter_key || formatChapterKey(q.subject, q.chapter)
      });
    });
    
    logger.info('Processing selected questions', { userId, selectedCount: selectedQuestions.length });
    
    // Remove duplicates before balancing
    const uniqueQuestions = [];
    const seenQuestionIds = new Set();
    for (const q of selectedQuestions) {
      const questionId = q.question_id || q.id;
      if (seenQuestionIds.has(questionId)) {
        logger.warn('Duplicate question detected, removing', { 
          questionId, 
          chapterKey: q.chapter_key,
          selectionReason: q.selection_reason 
        });
        continue;
      }
      seenQuestionIds.add(questionId);
      uniqueQuestions.push(q);
    }
    selectedQuestions = uniqueQuestions;
    logger.info('Duplicates removed', { userId, uniqueCount: selectedQuestions.length });
    
    // Balance subjects and limit to QUIZ_SIZE
    logger.info('Balancing subjects', { userId });
    selectedQuestions = balanceSubjects(selectedQuestions);
    logger.info('Subjects balanced', { userId, balancedCount: selectedQuestions.length });
    selectedQuestions = selectedQuestions.slice(0, QUIZ_SIZE);
    logger.info('Questions limited to quiz size', { userId, finalCount: selectedQuestions.length });
    
    // Validate quiz size
    if (selectedQuestions.length < QUIZ_SIZE) {
      logger.warn('Insufficient questions selected for quiz', {
        userId,
        selected: selectedQuestions.length,
        required: QUIZ_SIZE,
        learningPhase,
        note: 'This may be due to limited question bank. Consider adding more questions to the database.'
      });
      
      // If we have zero questions, try fallback: get ANY available questions
      if (selectedQuestions.length === 0) {
        logger.info('No questions found from selected chapters, trying fallback: any available questions', { userId });
        
        try {
          const fallbackQuestions = await selectAnyAvailableQuestions(
            excludeQuestionIds,
            QUIZ_SIZE
          );
          
          if (fallbackQuestions.length > 0) {
            logger.info('Fallback found questions', { userId, count: fallbackQuestions.length });
            selectedQuestions = fallbackQuestions.map((q, index) => ({
              ...q,
              position: index + 1,
              selection_reason: 'fallback',
              chapter_key: q.chapter_key || formatChapterKey(q.subject, q.chapter)
            }));
          } else {
            throw new Error(
              'No questions available for quiz generation. ' +
              'This is likely due to:\n' +
              '1. Limited question bank - not all chapters have questions yet\n' +
              '2. All available questions were recently answered\n' +
              'Please ensure question bank is populated with questions for the chapters in your assessment.'
            );
          }
        } catch (fallbackError) {
          logger.error('Fallback question selection failed', {
            userId,
            error: fallbackError.message
          });
          throw new Error(
            'No questions available for quiz generation. ' +
            'This is likely due to:\n' +
            '1. Limited question bank - not all chapters have questions yet\n' +
            '2. All available questions were recently answered\n' +
            'Please ensure question bank is populated with questions for the chapters in your assessment.'
          );
        }
      } else {
        // Log that we're proceeding with partial quiz
        logger.info('Proceeding with partial quiz due to limited question bank', {
          userId,
          questionsCount: selectedQuestions.length,
          required: QUIZ_SIZE
        });
      }
    }
    
    // Assign positions
    selectedQuestions = selectedQuestions.map((q, index) => ({
      ...q,
      position: index + 1
    }));
    
    logger.info('Daily quiz generated', {
      userId,
      learningPhase,
      quizNumber: completedQuizCount + 1,
      questionsCount: selectedQuestions.length,
      exploration: selectedQuestions.filter(q => q.selection_reason === 'exploration').length,
      deliberate_practice: selectedQuestions.filter(q => q.selection_reason === 'deliberate_practice').length,
      review: selectedQuestions.filter(q => q.selection_reason === 'review').length
    });
    
    return {
      quiz_id: `quiz_${completedQuizCount + 1}_${new Date().toISOString().split('T')[0]}`,
      quiz_number: completedQuizCount + 1,
      learning_phase: learningPhase,
      questions: selectedQuestions,
      generated_at: new Date().toISOString(),
      is_recovery_quiz: false
    };
  } catch (error) {
    logger.error('Error generating daily quiz', {
      userId,
      error: error.message,
      stack: error.stack
    });
    throw error;
  }
}

/**
 * Generate recovery quiz wrapper
 * 
 * @param {string} userId
 * @param {Object} chapterThetas
 * @returns {Promise<Object>} Recovery quiz data
 */
async function generateRecoveryQuizWrapper(userId, chapterThetas) {
  const excludeQuestionIds = await getRecentQuestionIds(userId);
  
  // Build chapter thetas map
  const chapterThetasMap = {};
  Object.entries(chapterThetas).forEach(([key, data]) => {
    chapterThetasMap[key] = data.theta || 0.0;
  });
  
  const recoveryQuestions = await generateRecoveryQuiz(userId, chapterThetasMap, excludeQuestionIds);
  
  // Assign positions
  const questions = recoveryQuestions.map((q, index) => ({
    ...q,
    position: index + 1
  }));
  
  const userDoc = await retryFirestoreOperation(async () => {
    return await db.collection('users').doc(userId).get();
  });
  const completedQuizCount = userDoc.data()?.completed_quiz_count || 0;
  
  return {
    quiz_id: `quiz_${completedQuizCount + 1}_${new Date().toISOString().split('T')[0]}_recovery`,
    quiz_number: completedQuizCount + 1,
    learning_phase: 'exploitation', // Recovery quizzes are exploitation
    questions: questions,
    generated_at: new Date().toISOString(),
    is_recovery_quiz: true,
    circuit_breaker_triggered: true
  };
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  generateDailyQuiz,
  getLearningPhase,
  selectChaptersForExploration,
  selectChaptersForExploitation,
  balanceSubjects,
  QUIZ_SIZE,
  EXPLORATION_PHASE_QUIZZES
};

