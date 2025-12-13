/**
 * Circuit Breaker Service
 * 
 * Detects struggling students (5+ consecutive failures) and provides
 * confidence-building recovery quizzes.
 * 
 * Features:
 * - Detects consecutive quiz failures
 * - Generates recovery quizzes (7 easy + 2 medium + 1 review)
 * - Resets circuit breaker after successful quiz
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { selectQuestionsForChapter } = require('./questionSelectionService');
const { getReviewQuestions } = require('./spacedRepetitionService');

// ============================================================================
// CONSTANTS
// ============================================================================

const CONSECUTIVE_FAILURE_THRESHOLD = 5; // Trigger recovery after 5 failures
const RECOVERY_QUIZ_CONFIG = {
  easy: 7,
  medium: 2,
  review: 1,
  total: 10
};

// Difficulty thresholds for recovery quiz
const EASY_DIFFICULTY_MAX = 0.0; // b <= 0.0
const MEDIUM_DIFFICULTY_MAX = 0.5; // 0.0 < b <= 0.5

// ============================================================================
// FAILURE DETECTION
// ============================================================================

/**
 * Check if user has consecutive failures
 * 
 * @param {string} userId
 * @returns {Promise<Object>} { hasFailures: boolean, count: number, shouldTrigger: boolean }
 */
async function checkConsecutiveFailures(userId) {
  try {
    // Get user document
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });
    
    if (!userDoc.exists) {
      return { hasFailures: false, count: 0, shouldTrigger: false };
    }
    
    const userData = userDoc.data();
    const consecutiveFailures = userData.consecutive_failures || 0;
    const shouldTrigger = consecutiveFailures >= CONSECUTIVE_FAILURE_THRESHOLD;
    
    return {
      hasFailures: consecutiveFailures > 0,
      count: consecutiveFailures,
      shouldTrigger: shouldTrigger
    };
  } catch (error) {
    logger.error('Error checking consecutive failures', {
      userId,
      error: error.message
    });
    return { hasFailures: false, count: 0, shouldTrigger: false };
  }
}

/**
 * Update consecutive failure count
 * 
 * @param {string} userId
 * @param {boolean} quizPassed - Whether quiz was passed (accuracy >= 0.5)
 * @returns {Promise<Object>} Updated failure state
 */
async function updateFailureCount(userId, quizPassed) {
  try {
    const userRef = db.collection('users').doc(userId);
    
    if (quizPassed) {
      // Reset failure count on success
      await retryFirestoreOperation(async () => {
        return await userRef.update({
          consecutive_failures: 0,
          circuit_breaker_active: false,
          last_circuit_breaker_trigger: admin.firestore.FieldValue.delete()
        });
      });
      
      return {
        consecutive_failures: 0,
        circuit_breaker_active: false
      };
    } else {
      // Increment failure count
      const userDoc = await retryFirestoreOperation(async () => {
        return await userRef.get();
      });
      
      const currentFailures = userDoc.data()?.consecutive_failures || 0;
      const newFailures = currentFailures + 1;
      const shouldTrigger = newFailures >= CONSECUTIVE_FAILURE_THRESHOLD;
      
      const updateData = {
        consecutive_failures: newFailures
      };
      
      if (shouldTrigger) {
        updateData.circuit_breaker_active = true;
        updateData.last_circuit_breaker_trigger = admin.firestore.FieldValue.serverTimestamp();
      }
      
      await retryFirestoreOperation(async () => {
        return await userRef.update(updateData);
      });
      
      logger.info('Failure count updated', {
        userId,
        consecutive_failures: newFailures,
        circuit_breaker_active: shouldTrigger
      });
      
      return {
        consecutive_failures: newFailures,
        circuit_breaker_active: shouldTrigger
      };
    }
  } catch (error) {
    logger.error('Error updating failure count', {
      userId,
      error: error.message,
      stack: error.stack
    });
    throw error;
  }
}

// ============================================================================
// RECOVERY QUIZ GENERATION
// ============================================================================

/**
 * Select easy questions for recovery quiz
 * 
 * @param {string} chapterKey
 * @param {number} theta - Current theta for chapter
 * @param {Set<string>} excludeQuestionIds
 * @param {number} count
 * @returns {Promise<Array>} Easy question documents
 */
async function selectEasyQuestions(chapterKey, theta, excludeQuestionIds, count) {
  try {
    // Query questions with difficulty <= 0.0
    const parts = chapterKey.split('_');
    const subject = parts[0].charAt(0).toUpperCase() + parts[0].slice(1);
    const chapter = parts.slice(1).join(' ').replace(/_/g, ' ');
    
    const questionsRef = db.collection('questions')
      .where('subject', '==', subject)
      .where('chapter', '==', chapter)
      .where('irt_parameters.difficulty_b', '<=', EASY_DIFFICULTY_MAX)
      .orderBy('irt_parameters.difficulty_b', 'asc')
      .limit(50); // Get more candidates for filtering
    
    const snapshot = await retryFirestoreOperation(async () => {
      return await questionsRef.get();
    });
    
    let questions = snapshot.docs
      .map(doc => ({ question_id: doc.id, ...doc.data() }))
      .filter(q => !excludeQuestionIds.has(q.question_id));
    
    // Shuffle and take first N
    questions = questions.sort(() => Math.random() - 0.5).slice(0, count);
    
    return questions;
  } catch (error) {
    logger.error('Error selecting easy questions', {
      chapterKey,
      error: error.message
    });
    return [];
  }
}

/**
 * Select medium questions for recovery quiz
 * 
 * @param {string} chapterKey
 * @param {number} theta
 * @param {Set<string>} excludeQuestionIds
 * @param {number} count
 * @returns {Promise<Array>} Medium question documents
 */
async function selectMediumQuestions(chapterKey, theta, excludeQuestionIds, count) {
  try {
    const parts = chapterKey.split('_');
    const subject = parts[0].charAt(0).toUpperCase() + parts[0].slice(1);
    const chapter = parts.slice(1).join(' ').replace(/_/g, ' ');
    
    const questionsRef = db.collection('questions')
      .where('subject', '==', subject)
      .where('chapter', '==', chapter)
      .where('irt_parameters.difficulty_b', '>', EASY_DIFFICULTY_MAX)
      .where('irt_parameters.difficulty_b', '<=', MEDIUM_DIFFICULTY_MAX)
      .orderBy('irt_parameters.difficulty_b', 'asc')
      .limit(50);
    
    const snapshot = await retryFirestoreOperation(async () => {
      return await questionsRef.get();
    });
    
    let questions = snapshot.docs
      .map(doc => ({ question_id: doc.id, ...doc.data() }))
      .filter(q => !excludeQuestionIds.has(q.question_id));
    
    questions = questions.sort(() => Math.random() - 0.5).slice(0, count);
    
    return questions;
  } catch (error) {
    logger.error('Error selecting medium questions', {
      chapterKey,
      error: error.message
    });
    return [];
  }
}

/**
 * Generate recovery quiz questions
 * 
 * @param {string} userId
 * @param {Object} chapterThetas - Object mapping chapterKey to theta
 * @param {Set<string>} excludeQuestionIds - Questions to exclude
 * @returns {Promise<Array>} Recovery quiz questions
 */
async function generateRecoveryQuiz(userId, chapterThetas, excludeQuestionIds) {
  try {
    const recoveryQuestions = [];
    
    // Get review questions (1)
    const reviewQuestions = await getReviewQuestions(userId, RECOVERY_QUIZ_CONFIG.review);
    reviewQuestions.forEach(q => {
      recoveryQuestions.push({
        ...q,
        selection_reason: 'review',
        difficulty_category: 'review'
      });
      excludeQuestionIds.add(q.question_id);
    });
    
    // Select chapters for easy and medium questions
    // Use chapters where student is struggling (low theta)
    const strugglingChapters = Object.entries(chapterThetas)
      .filter(([_, theta]) => theta < 0) // Below average
      .sort(([_, a], [__, b]) => a - b) // Sort by theta (lowest first)
      .slice(0, 3); // Top 3 struggling chapters
    
    if (strugglingChapters.length === 0) {
      // Fallback: use all chapters
      strugglingChapters.push(...Object.entries(chapterThetas).slice(0, 3));
    }
    
    // Distribute easy questions across struggling chapters
    const easyPerChapter = Math.ceil(RECOVERY_QUIZ_CONFIG.easy / strugglingChapters.length);
    
    for (const [chapterKey, theta] of strugglingChapters) {
      if (recoveryQuestions.length >= RECOVERY_QUIZ_CONFIG.easy + RECOVERY_QUIZ_CONFIG.medium) {
        break;
      }
      
      const needed = Math.min(
        easyPerChapter,
        RECOVERY_QUIZ_CONFIG.easy - recoveryQuestions.filter(q => q.difficulty_category === 'easy').length
      );
      
      if (needed > 0) {
        const easyQuestions = await selectEasyQuestions(chapterKey, theta, excludeQuestionIds, needed);
        easyQuestions.forEach(q => {
          recoveryQuestions.push({
            ...q,
            selection_reason: 'recovery_easy',
            difficulty_category: 'easy',
            chapter_key: chapterKey
          });
          excludeQuestionIds.add(q.question_id);
        });
      }
    }
    
    // Distribute medium questions
    const mediumPerChapter = Math.ceil(RECOVERY_QUIZ_CONFIG.medium / strugglingChapters.length);
    
    for (const [chapterKey, theta] of strugglingChapters) {
      if (recoveryQuestions.length >= RECOVERY_QUIZ_CONFIG.total) {
        break;
      }
      
      const needed = Math.min(
        mediumPerChapter,
        RECOVERY_QUIZ_CONFIG.medium - recoveryQuestions.filter(q => q.difficulty_category === 'medium').length
      );
      
      if (needed > 0) {
        const mediumQuestions = await selectMediumQuestions(chapterKey, theta, excludeQuestionIds, needed);
        mediumQuestions.forEach(q => {
          recoveryQuestions.push({
            ...q,
            selection_reason: 'recovery_medium',
            difficulty_category: 'medium',
            chapter_key: chapterKey
          });
          excludeQuestionIds.add(q.question_id);
        });
      }
    }
    
    // Validate recovery quiz has sufficient questions
    const easyCount = recoveryQuestions.filter(q => q.difficulty_category === 'easy').length;
    const mediumCount = recoveryQuestions.filter(q => q.difficulty_category === 'medium').length;
    const reviewCount = recoveryQuestions.filter(q => q.difficulty_category === 'review').length;
    const totalCount = recoveryQuestions.length;
    
    if (totalCount < RECOVERY_QUIZ_CONFIG.total) {
      logger.warn('Recovery quiz has insufficient questions', {
        userId,
        total: totalCount,
        required: RECOVERY_QUIZ_CONFIG.total,
        easy: easyCount,
        medium: mediumCount,
        review: reviewCount
      });
      
      // If we have at least some questions, proceed with what we have
      // Otherwise, throw error to trigger fallback
      if (totalCount === 0) {
        throw new Error('Could not generate recovery quiz: no questions available');
      }
    }
    
    // Shuffle questions
    recoveryQuestions.sort(() => Math.random() - 0.5);
    
    logger.info('Recovery quiz generated', {
      userId,
      total_questions: totalCount,
      easy: easyCount,
      medium: mediumCount,
      review: reviewCount,
      meets_requirement: totalCount >= RECOVERY_QUIZ_CONFIG.total
    });
    
    return recoveryQuestions;
  } catch (error) {
    logger.error('Error generating recovery quiz', {
      userId,
      error: error.message,
      stack: error.stack
    });
    throw error;
  }
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  checkConsecutiveFailures,
  updateFailureCount,
  generateRecoveryQuiz,
  CONSECUTIVE_FAILURE_THRESHOLD,
  RECOVERY_QUIZ_CONFIG
};

