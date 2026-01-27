/**
 * Spaced Repetition Service
 * 
 * Implements spaced repetition algorithm for review questions.
 * Questions are scheduled for review at increasing intervals: 1, 3, 7, 14, 30 days.
 * 
 * Features:
 * - Review interval tracking (1, 3, 7, 14, 30 days)
 * - Priority scoring for review questions
 * - Overdue question detection
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { normalizeQuestion } = require('./questionSelectionService');

// ============================================================================
// CONSTANTS
// ============================================================================

const REVIEW_INTERVALS = [1, 3, 7, 14, 30]; // Days
const MAX_REVIEW_QUESTIONS = 2; // Maximum review questions per quiz

// ============================================================================
// REVIEW INTERVAL CALCULATION
// ============================================================================

/**
 * Get next review interval based on current interval and performance
 * 
 * @param {number} currentInterval - Current interval in days
 * @param {boolean} wasCorrect - Whether last attempt was correct
 * @returns {number} Next interval in days
 */
function getNextReviewInterval(currentInterval, wasCorrect) {
  const intervals = REVIEW_INTERVALS;

  if (!wasCorrect) {
    // Reset to first interval if incorrect
    return intervals[0];
  }

  // Find current interval index
  const currentIndex = intervals.indexOf(currentInterval);

  if (currentIndex === -1) {
    // Current interval not in list, start from beginning
    return intervals[0];
  }

  if (currentIndex === intervals.length - 1) {
    // Already at max interval, stay there
    return intervals[currentIndex];
  }

  // Move to next interval
  return intervals[currentIndex + 1];
}

/**
 * Check if a question is due for review
 * 
 * @param {Date} lastAnsweredDate - Date when question was last answered
 * @param {number} reviewInterval - Review interval in days
 * @returns {boolean} True if due for review
 */
function isDueForReview(lastAnsweredDate, reviewInterval) {
  if (!lastAnsweredDate) {
    return false; // Never answered, not a review question
  }

  const now = new Date();
  const daysSinceLastAnswer = Math.floor((now - lastAnsweredDate) / (1000 * 60 * 60 * 24));

  return daysSinceLastAnswer >= reviewInterval;
}

/**
 * Calculate days overdue for review
 * 
 * @param {Date} lastAnsweredDate - Date when question was last answered
 * @param {number} reviewInterval - Review interval in days
 * @returns {number} Days overdue (0 if not overdue)
 */
function getDaysOverdue(lastAnsweredDate, reviewInterval) {
  if (!lastAnsweredDate) {
    return 0;
  }

  const now = new Date();
  const daysSinceLastAnswer = Math.floor((now - lastAnsweredDate) / (1000 * 60 * 60 * 24));
  const overdue = daysSinceLastAnswer - reviewInterval;

  return Math.max(0, overdue);
}

// ============================================================================
// REVIEW QUESTION RETRIEVAL
// ============================================================================

/**
 * Get review questions for a user
 * Questions that were answered incorrectly and are due for review
 * 
 * @param {string} userId
 * @param {number} limit - Maximum number of questions to return
 * @returns {Promise<Array>} Array of review question documents with priority scores
 */
async function getReviewQuestions(userId, limit = MAX_REVIEW_QUESTIONS) {
  try {
    // Get all responses from daily quizzes and assessments
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 30); // Look back 30 days max

    const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

    let dailyQuizSnapshot;
    let assessmentSnapshot;

    try {
      // Query responses across all quizzes using collectionGroup
      // This is more efficient as it leverages the existing composite index
      const responsesRef = db.collectionGroup('responses')
        .where('student_id', '==', userId)
        .where('answered_at', '>=', cutoffTimestamp)
        .where('is_correct', '==', false);

      const snapshot = await retryFirestoreOperation(async () => {
        return await responsesRef.get();
      });

      // Use the snapshot for both (we don't need two separate queries if we use student_id)
      dailyQuizSnapshot = snapshot;
      assessmentSnapshot = { docs: [] }; // Assessment responses are now caught in the collectionGroup query
    } catch (queryError) {
      // Handle missing index error gracefully
      if (queryError.message && queryError.message.includes('index')) {
        logger.warn('Review questions query requires Firestore index. Skipping review questions for now.', {
          userId,
          error: queryError.message,
          note: 'Deploy firestore indexes using: firebase deploy --only firestore:indexes'
        });
        return []; // Return empty array to allow quiz generation to continue
      }
      throw queryError; // Re-throw if it's a different error
    }

    // Combine all incorrect responses
    const allResponses = [];

    dailyQuizSnapshot.docs.forEach(doc => {
      const data = doc.data();
      allResponses.push({
        question_id: data.question_id,
        answered_at: data.answered_at?.toDate(),
        chapter_key: data.chapter_key,
        review_interval: data.review_interval || REVIEW_INTERVALS[0] // Default to first interval
      });
    });

    assessmentSnapshot.docs.forEach(doc => {
      const data = doc.data();
      allResponses.push({
        question_id: data.question_id,
        answered_at: data.answered_at?.toDate(),
        chapter_key: data.chapter_key,
        review_interval: REVIEW_INTERVALS[0] // Assessment questions start at first interval
      });
    });

    // Group by question_id and get most recent incorrect answer
    const questionMap = new Map();

    allResponses.forEach(response => {
      const questionId = response.question_id;
      if (!questionId) return;

      const existing = questionMap.get(questionId);
      if (!existing || (response.answered_at > existing.answered_at)) {
        questionMap.set(questionId, response);
      }
    });

    // Filter to questions due for review and score by priority
    const reviewCandidates = [];

    for (const [questionId, response] of questionMap.entries()) {
      if (isDueForReview(response.answered_at, response.review_interval)) {
        const daysOverdue = getDaysOverdue(response.answered_at, response.review_interval);

        // Priority score: higher = more urgent
        // Factors: days overdue, review interval (shorter = more urgent)
        const priorityScore = daysOverdue * 10 + (REVIEW_INTERVALS.length - REVIEW_INTERVALS.indexOf(response.review_interval));

        reviewCandidates.push({
          question_id: questionId,
          chapter_key: response.chapter_key,
          last_answered_at: response.answered_at,
          review_interval: response.review_interval,
          days_overdue: daysOverdue,
          priority_score: priorityScore
        });
      }
    }

    // Sort by priority (descending) and limit
    reviewCandidates.sort((a, b) => b.priority_score - a.priority_score);
    const topCandidates = reviewCandidates.slice(0, limit);

    // Fetch question documents
    const questionIds = topCandidates.map(c => c.question_id);
    const questionRefs = questionIds.map(id => db.collection('questions').doc(id));

    // Check if we have any questions to fetch (getAll() requires at least 1 argument)
    if (questionRefs.length === 0) {
      logger.info('No review questions available', { userId });
      return [];
    }

    const questionDocs = await retryFirestoreOperation(async () => {
      return await db.getAll(...questionRefs);
    });

    // Combine question data with review metadata
    const reviewQuestions = questionDocs
      .filter(doc => doc.exists)
      .map((doc, index) => {
        const candidate = topCandidates[index];
        const normalized = normalizeQuestion(doc.id, doc.data());
        return {
          ...normalized,
          review_metadata: {
            last_answered_at: candidate.last_answered_at,
            review_interval: candidate.review_interval,
            days_overdue: candidate.days_overdue,
            priority_score: candidate.priority_score
          }
        };
      });

    logger.info('Review questions retrieved', {
      userId,
      total_candidates: reviewCandidates.length,
      selected: reviewQuestions.length
    });

    return reviewQuestions;
  } catch (error) {
    logger.error('Error getting review questions', {
      userId,
      error: error.message,
      stack: error.stack
    });
    return [];
  }
}

/**
 * Update review interval after question is answered
 * 
 * @param {string} userId
 * @param {string} questionId
 * @param {boolean} isCorrect - Whether answer was correct
 * @param {number} currentInterval - Current review interval (if known)
 * @returns {Promise<number>} New review interval
 */
async function updateReviewInterval(userId, questionId, isCorrect, currentInterval = null) {
  try {
    // If current interval not provided, try to find it from last response
    if (currentInterval === null) {
      // Query for last response to this question
      const responsesRef = db.collection('daily_quiz_responses')
        .doc(userId)
        .collection('responses')
        .where('question_id', '==', questionId)
        .orderBy('answered_at', 'desc')
        .limit(1);

      const snapshot = await retryFirestoreOperation(async () => {
        return await responsesRef.get();
      });

      if (!snapshot.empty) {
        const lastResponse = snapshot.docs[0].data();
        currentInterval = lastResponse.review_interval || REVIEW_INTERVALS[0];
      } else {
        currentInterval = REVIEW_INTERVALS[0];
      }
    }

    // Calculate new interval
    const newInterval = getNextReviewInterval(currentInterval, isCorrect);

    // Note: The new interval will be stored when the response is saved
    // This function just calculates it

    return newInterval;
  } catch (error) {
    logger.error('Error updating review interval', {
      userId,
      questionId,
      error: error.message
    });
    return REVIEW_INTERVALS[0]; // Default to first interval on error
  }
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  getReviewQuestions,
  updateReviewInterval,
  getNextReviewInterval,
  isDueForReview,
  getDaysOverdue,
  REVIEW_INTERVALS,
  MAX_REVIEW_QUESTIONS
};

