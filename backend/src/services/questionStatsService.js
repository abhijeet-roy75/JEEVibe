/**
 * Question Statistics Service
 * 
 * Aggregates and updates question usage statistics:
 * - times_shown: How many times question was presented
 * - times_correct: How many times answered correctly
 * - times_incorrect: How many times answered incorrectly
 * - avg_time_taken: Average time taken across all attempts
 * - accuracy_rate: Percentage of correct answers
 * 
 * Data sources:
 * - daily_quiz_responses collection (for daily quiz answers)
 * - assessment_responses collection (for assessment answers)
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');

// ============================================================================
// QUESTION STATISTICS AGGREGATION
// ============================================================================

/**
 * Update usage stats for a single question
 * 
 * @param {string} questionId
 * @returns {Promise<Object>} Updated stats
 */
async function updateQuestionStats(questionId) {
  try {
    // Aggregate from daily quiz responses
    const dailyQuizResponsesRef = db.collectionGroup('daily_quiz_responses')
      .where('question_id', '==', questionId);
    
    const dailyQuizSnapshot = await retryFirestoreOperation(async () => {
      return await dailyQuizResponsesRef.get();
    });
    
    // Aggregate from assessment responses
    const assessmentResponsesRef = db.collectionGroup('assessment_responses')
      .where('question_id', '==', questionId);
    
    const assessmentSnapshot = await retryFirestoreOperation(async () => {
      return await assessmentResponsesRef.get();
    });
    
    // Combine all responses
    const allResponses = [
      ...dailyQuizSnapshot.docs.map(doc => doc.data()),
      ...assessmentSnapshot.docs.map(doc => doc.data())
    ];
    
    // Calculate statistics
    const stats = {
      times_shown: allResponses.length,
      times_correct: allResponses.filter(r => r.is_correct === true).length,
      times_incorrect: allResponses.filter(r => r.is_correct === false).length,
      avg_time_taken: null,
      accuracy_rate: null,
      last_shown: null
    };
    
    // Calculate average time taken
    const timesWithData = allResponses
      .filter(r => r.time_taken_seconds && typeof r.time_taken_seconds === 'number')
      .map(r => r.time_taken_seconds);
    
    if (timesWithData.length > 0) {
      const sum = timesWithData.reduce((acc, time) => acc + time, 0);
      stats.avg_time_taken = Math.round(sum / timesWithData.length);
    }
    
    // Calculate accuracy rate
    if (stats.times_shown > 0) {
      stats.accuracy_rate = stats.times_correct / stats.times_shown;
    }
    
    // Get most recent response timestamp
    const timestamps = allResponses
      .filter(r => r.answered_at)
      .map(r => {
        if (r.answered_at && r.answered_at.toDate) {
          return r.answered_at.toDate();
        } else if (typeof r.answered_at === 'string') {
          return new Date(r.answered_at);
        }
        return null;
      })
      .filter(d => d !== null);
    
    if (timestamps.length > 0) {
      const mostRecent = new Date(Math.max(...timestamps.map(d => d.getTime())));
      stats.last_shown = mostRecent.toISOString();
    }
    
    // Update question document
    const questionRef = db.collection('questions').doc(questionId);
    await retryFirestoreOperation(async () => {
      return await questionRef.update({
        'usage_stats': stats
      });
    });
    
    logger.info('Question stats updated', {
      questionId,
      times_shown: stats.times_shown,
      times_correct: stats.times_correct,
      accuracy_rate: stats.accuracy_rate
    });
    
    return stats;
  } catch (error) {
    logger.error('Error updating question stats', {
      questionId,
      error: error.message,
      stack: error.stack
    });
    throw error;
  }
}

/**
 * Update usage stats for a question after answer submission
 * (Incremental update - faster than full aggregation)
 * 
 * NOTE: This is optional. Question stats are now updated weekly via cron job.
 * This function can be used for real-time updates if needed, but is not required.
 * 
 * @param {string} questionId
 * @param {boolean} isCorrect
 * @param {number} timeTakenSeconds
 * @returns {Promise<void>}
 */
async function incrementQuestionStats(questionId, isCorrect, timeTakenSeconds) {
  // This function is kept for backward compatibility but is not used by default
  // Question stats are updated weekly via cron job for better performance
  logger.debug('incrementQuestionStats called (not used - stats updated weekly)', {
    questionId
  });
  return Promise.resolve();
}

/**
 * Recalculate accuracy rate and average time for a question
 * (Called after increment to update derived fields)
 * 
 * @param {string} questionId
 * @returns {Promise<void>}
 */
async function recalculateQuestionStats(questionId) {
  try {
    const questionRef = db.collection('questions').doc(questionId);
    const questionDoc = await retryFirestoreOperation(async () => {
      return await questionRef.get();
    });
    
    if (!questionDoc.exists) {
      return;
    }
    
    const currentStats = questionDoc.data().usage_stats || {};
    const timesShown = currentStats.times_shown || 0;
    const timesCorrect = currentStats.times_correct || 0;
    
    // Calculate accuracy rate
    const accuracyRate = timesShown > 0 ? timesCorrect / timesShown : null;
    
    // For average time, we'd need to query all responses
    // For performance, we can do this in a scheduled job
    // For now, we'll update accuracy rate only
    
    await retryFirestoreOperation(async () => {
      return await questionRef.update({
        'usage_stats.accuracy_rate': accuracyRate
      });
    });
    
  } catch (error) {
    logger.error('Error recalculating question stats', {
      questionId,
      error: error.message
    });
  }
}

/**
 * Batch update stats for multiple questions
 * 
 * @param {Array<string>} questionIds
 * @returns {Promise<Object>} Summary of updates
 */
async function batchUpdateQuestionStats(questionIds) {
  const results = {
    total: questionIds.length,
    updated: 0,
    errors: 0,
    errorDetails: []
  };
  
  for (const questionId of questionIds) {
    try {
      await updateQuestionStats(questionId);
      results.updated++;
    } catch (error) {
      results.errors++;
      results.errorDetails.push({
        questionId,
        error: error.message
      });
    }
  }
  
  return results;
}

/**
 * Get question statistics (from stored usage_stats)
 * 
 * @param {string} questionId
 * @returns {Promise<Object|null>} Question stats or null
 */
async function getQuestionStats(questionId) {
  try {
    const questionRef = db.collection('questions').doc(questionId);
    const questionDoc = await retryFirestoreOperation(async () => {
      return await questionRef.get();
    });
    
    if (!questionDoc.exists) {
      return null;
    }
    
    return questionDoc.data().usage_stats || null;
  } catch (error) {
    logger.error('Error getting question stats', {
      questionId,
      error: error.message
    });
    return null;
  }
}

module.exports = {
  updateQuestionStats,
  incrementQuestionStats,
  recalculateQuestionStats,
  batchUpdateQuestionStats,
  getQuestionStats
};

