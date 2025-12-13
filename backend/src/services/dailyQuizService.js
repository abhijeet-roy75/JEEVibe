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
const { selectQuestionsForChapters, getRecentQuestionIds } = require('./questionSelectionService');
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
const QUIZ_GENERATION_TIMEOUT_MS = 30000; // 30 seconds timeout for quiz generation

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
 * Prioritizes chapters with fewer attempts
 * 
 * @param {Object} chapterThetas - Object mapping chapterKey to theta data
 * @param {number} count - Number of chapters to select
 * @returns {Array} Selected chapter keys
 */
function selectChaptersForExploration(chapterThetas, count = 7) {
  const chapters = Object.entries(chapterThetas)
    .map(([key, data]) => ({
      chapter_key: key,
      attempts: data.attempts || 0,
      theta: data.theta || 0
    }))
    .sort((a, b) => {
      // Prioritize chapters with fewer attempts
      if (a.attempts !== b.attempts) {
        return a.attempts - b.attempts;
      }
      // Secondary: prioritize lower theta (weaker areas)
      return a.theta - b.theta;
    });
  
  return chapters.slice(0, count).map(c => c.chapter_key);
}

/**
 * Select chapters for exploitation phase (deliberate practice)
 * Prioritizes weak chapters (low theta)
 * 
 * @param {Object} chapterThetas - Object mapping chapterKey to theta data
 * @param {number} count - Number of chapters to select
 * @returns {Array} Selected chapter keys
 */
function selectChaptersForExploitation(chapterThetas, count = 6) {
  const chapters = Object.entries(chapterThetas)
    .filter(([_, data]) => (data.attempts || 0) >= 2) // At least 2 attempts (explored)
    .map(([key, data]) => ({
      chapter_key: key,
      theta: data.theta || 0,
      attempts: data.attempts || 0
    }))
    .sort((a, b) => {
      // Prioritize lower theta (weaker areas)
      if (Math.abs(a.theta - b.theta) > 0.1) {
        return a.theta - b.theta;
      }
      // Secondary: prioritize more attempts (more data)
      return b.attempts - a.attempts;
    });
  
  return chapters.slice(0, count).map(c => c.chapter_key);
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
    // Get user data
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });
    
    if (!userDoc.exists) {
      throw new Error(`User ${userId} not found`);
    }
    
    const userData = userDoc.data();
    
    // Check if assessment completed
    if (!userData.assessment?.completed_at) {
      throw new Error('User must complete initial assessment before daily quizzes');
    }
    
    const completedQuizCount = userData.completed_quiz_count || 0;
    const learningPhase = getLearningPhase(completedQuizCount);
    const thetaByChapter = userData.theta_by_chapter || {};
    
    // Check circuit breaker
    const failureCheck = await checkConsecutiveFailures(userId);
    
    if (failureCheck.shouldTrigger) {
      logger.info('Circuit breaker triggered, generating recovery quiz', { userId });
      return await generateRecoveryQuizWrapper(userId, thetaByChapter);
    }
    
    // Get recent question IDs to exclude
    const excludeQuestionIds = await getRecentQuestionIds(userId);
    
    // Get review questions (1 per quiz)
    const reviewQuestions = await getReviewQuestions(userId, REVIEW_QUESTIONS_PER_QUIZ);
    reviewQuestions.forEach(q => excludeQuestionIds.add(q.question_id));
    
    let selectedQuestions = [];
    
    if (learningPhase === 'exploration') {
      // Exploration phase: Map ability across topics
      const selectedChapters = selectChaptersForExploration(thetaByChapter, EXPLORATION_QUESTIONS_PER_QUIZ);
      
      if (selectedChapters.length === 0) {
        // Fallback: use all available chapters
        selectedChapters.push(...Object.keys(thetaByChapter).slice(0, EXPLORATION_QUESTIONS_PER_QUIZ));
      }
      
      // Build chapter thetas map for selection
      const chapterThetasMap = {};
      selectedChapters.forEach(chapterKey => {
        const chapterData = thetaByChapter[chapterKey];
        chapterThetasMap[chapterKey] = chapterData?.theta || 0.0;
      });
      
      // Select questions for selected chapters
      const explorationQuestions = await selectQuestionsForChapters(
        chapterThetasMap,
        excludeQuestionIds,
        { questionsPerChapter: 1 }
      );
      
      selectedQuestions.push(...explorationQuestions);
    } else {
      // Exploitation phase: Focus on weak areas
      const selectedChapters = selectChaptersForExploitation(thetaByChapter, DELIBERATE_PRACTICE_QUESTIONS_PER_QUIZ);
      
      if (selectedChapters.length === 0) {
        // Fallback: use all available chapters
        selectedChapters.push(...Object.keys(thetaByChapter).slice(0, DELIBERATE_PRACTICE_QUESTIONS_PER_QUIZ));
      }
      
      const chapterThetasMap = {};
      selectedChapters.forEach(chapterKey => {
        const chapterData = thetaByChapter[chapterKey];
        chapterThetasMap[chapterKey] = chapterData?.theta || 0.0;
      });
      
      const practiceQuestions = await selectQuestionsForChapters(
        chapterThetasMap,
        excludeQuestionIds,
        { questionsPerChapter: 1 }
      );
      
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
    
    // Balance subjects and limit to QUIZ_SIZE
    selectedQuestions = balanceSubjects(selectedQuestions);
    selectedQuestions = selectedQuestions.slice(0, QUIZ_SIZE);
    
    // Validate quiz size
    if (selectedQuestions.length < QUIZ_SIZE) {
      logger.warn('Insufficient questions selected for quiz', {
        userId,
        selected: selectedQuestions.length,
        required: QUIZ_SIZE,
        learningPhase
      });
      
      // For production, we should either:
      // 1. Throw error and let frontend handle
      // 2. Fill with fallback questions
      // For now, we'll proceed with available questions but log warning
      if (selectedQuestions.length === 0) {
        throw new Error('No questions available for quiz generation. Please ensure question bank is populated.');
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

