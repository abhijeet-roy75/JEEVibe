/**
 * Progress Service
 * 
 * Calculates and tracks student progress across chapters and subjects.
 * Provides analytics for progress display.
 * 
 * Features:
 * - Chapter-level progress tracking
 * - Subject-level progress aggregation
 * - Accuracy trends
 * - Cumulative statistics
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');

// ============================================================================
// CHAPTER PROGRESS
// ============================================================================

/**
 * Get chapter-level progress for a user
 * 
 * @param {string} userId
 * @returns {Promise<Object>} Chapter progress data
 */
async function getChapterProgress(userId) {
  try {
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    if (!userDoc.exists) {
      throw new Error(`User ${userId} not found`);
    }

    const userData = userDoc.data();
    const thetaByChapter = userData.theta_by_chapter || {};
    const baseline = userData.assessment_baseline?.theta_by_chapter || {};

    const chapterProgress = {};

    for (const [chapterKey, currentData] of Object.entries(thetaByChapter)) {
      const baselineData = baseline[chapterKey];

      const progress = {
        chapter_key: chapterKey,
        current_theta: currentData.theta || 0,
        current_percentile: currentData.percentile || 50,
        // Redundant fields for backward compatibility
        theta: currentData.theta || 0,
        percentile: currentData.percentile || 50,
        baseline_theta: baselineData?.theta || currentData.theta || 0,
        baseline_percentile: baselineData?.percentile || currentData.percentile || 50,
        theta_change: (currentData.theta || 0) - (baselineData?.theta || currentData.theta || 0),
        percentile_change: (currentData.percentile || 50) - (baselineData?.percentile || currentData.percentile || 50),
        attempts: currentData.attempts || 0,
        accuracy: currentData.accuracy || 0,
        confidence_SE: currentData.confidence_SE || 0.6,
        status: getChapterStatus(currentData.theta || 0, currentData.percentile || 50),
        last_updated: currentData.last_updated
      };

      chapterProgress[chapterKey] = progress;
    }

    return chapterProgress;
  } catch (error) {
    logger.error('Error getting chapter progress', {
      userId,
      error: error.message
    });
    throw error;
  }
}

/**
 * Determine chapter status based on theta/percentile
 * 
 * @param {number} theta
 * @param {number} percentile
 * @returns {string} Status: 'strong', 'average', 'weak', 'untested'
 */
function getChapterStatus(theta, percentile) {
  if (percentile >= 70) return 'strong';
  if (percentile >= 40) return 'average';
  if (percentile > 0) return 'weak';
  return 'untested';
}

// ============================================================================
// SUBJECT PROGRESS
// ============================================================================

/**
 * Get subject-level progress for a user
 * 
 * @param {string} userId
 * @returns {Promise<Object>} Subject progress data
 */
async function getSubjectProgress(userId) {
  try {
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    if (!userDoc.exists) {
      throw new Error(`User ${userId} not found`);
    }

    const userData = userDoc.data();
    const thetaBySubject = userData.theta_by_subject || {};
    const subjectAccuracy = userData.subject_accuracy || {};
    const baseline = userData.assessment_baseline?.theta_by_subject || {};

    const subjectProgress = {};

    for (const [subject, currentData] of Object.entries(thetaBySubject)) {
      const baselineData = baseline[subject];
      const accuracy = subjectAccuracy[subject] || {};

      subjectProgress[subject] = {
        subject: subject,
        current_theta: currentData.theta || 0,
        current_percentile: currentData.percentile || 50,
        // Redundant fields for backward compatibility
        theta: currentData.theta || 0,
        percentile: currentData.percentile || 50,
        baseline_theta: baselineData?.theta || currentData.theta || 0,
        baseline_percentile: baselineData?.percentile || currentData.percentile || 50,
        theta_change: (currentData.theta || 0) - (baselineData?.theta || currentData.theta || 0),
        percentile_change: (currentData.percentile || 50) - (baselineData?.percentile || currentData.percentile || 50),
        accuracy: accuracy.accuracy || 0,
        correct: accuracy.correct || 0,
        total: accuracy.total || 0,
        chapters_tested: currentData.chapters_tested || 0,
        status: currentData.status || 'not_tested'
      };
    }

    return subjectProgress;
  } catch (error) {
    logger.error('Error getting subject progress', {
      userId,
      error: error.message
    });
    throw error;
  }
}

// ============================================================================
// ACCURACY TRENDS
// ============================================================================

/**
 * Get accuracy trends over time
 * 
 * @param {string} userId
 * @param {number} days - Number of days to look back (default: 30)
 * @returns {Promise<Array>} Array of daily accuracy data
 */
async function getAccuracyTrends(userId, days = 30) {
  try {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - days);
    const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

    // Get completed quizzes
    const quizzesRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .where('status', '==', 'completed')
      .where('completed_at', '>=', cutoffTimestamp)
      .orderBy('completed_at', 'desc');

    const quizzesSnapshot = await retryFirestoreOperation(async () => {
      return await quizzesRef.get();
    });

    const trends = [];
    const dailyData = {};

    quizzesSnapshot.docs.forEach(doc => {
      const quiz = doc.data();
      const completedAt = quiz.completed_at?.toDate();

      if (!completedAt) return;

      const dateKey = completedAt.toISOString().split('T')[0]; // YYYY-MM-DD

      if (!dailyData[dateKey]) {
        dailyData[dateKey] = {
          date: dateKey,
          quizzes: 0,
          questions: 0,
          correct: 0,
          accuracy: 0
        };
      }

      dailyData[dateKey].quizzes += 1;
      dailyData[dateKey].questions += (quiz.questions?.length || 0);
      dailyData[dateKey].correct += (quiz.score || 0);
    });

    // Calculate accuracy for each day
    for (const [date, data] of Object.entries(dailyData)) {
      data.accuracy = data.questions > 0 ? data.correct / data.questions : 0;
      trends.push(data);
    }

    // Sort by date (ascending)
    trends.sort((a, b) => a.date.localeCompare(b.date));

    return trends;
  } catch (error) {
    logger.error('Error getting accuracy trends', {
      userId,
      error: error.message
    });
    return [];
  }
}

// ============================================================================
// CUMULATIVE STATISTICS
// ============================================================================

/**
 * Get cumulative statistics for a user
 * 
 * @param {string} userId
 * @returns {Promise<Object>} Cumulative stats
 */
async function getCumulativeStats(userId) {
  try {
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    if (!userDoc.exists) {
      throw new Error(`User ${userId} not found`);
    }

    const userData = userDoc.data();

    // Get quiz count
    const quizzesRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .where('status', '==', 'completed');

    const quizzesSnapshot = await retryFirestoreOperation(async () => {
      return await quizzesRef.get();
    });

    const totalQuizzes = quizzesSnapshot.size;
    const totalQuestions = userData.total_questions_solved || 0;
    const totalTimeMinutes = userData.total_time_spent_minutes || 0;

    // Calculate overall accuracy from responses
    const responsesRef = db.collection('daily_quiz_responses')
      .doc(userId)
      .collection('responses');

    const responsesSnapshot = await retryFirestoreOperation(async () => {
      return await responsesRef.limit(1000).get(); // Sample for performance
    });

    let correctCount = 0;
    let totalCount = 0;

    responsesSnapshot.docs.forEach(doc => {
      const data = doc.data();
      if (data.is_correct !== undefined) {
        totalCount++;
        if (data.is_correct) {
          correctCount++;
        }
      }
    });

    const overallAccuracy = totalCount > 0 ? correctCount / totalCount : 0;

    return {
      total_quizzes: totalQuizzes,
      total_questions: totalQuestions,
      total_time_minutes: totalTimeMinutes,
      overall_accuracy: Math.round(overallAccuracy * 1000) / 1000,
      chapters_explored: userData.chapters_explored || 0,
      chapters_confident: userData.chapters_confident || 0,
      learning_phase: userData.learning_phase || 'exploration',
      completed_quiz_count: userData.completed_quiz_count || 0
    };
  } catch (error) {
    logger.error('Error getting cumulative stats', {
      userId,
      error: error.message
    });
    throw error;
  }
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  getChapterProgress,
  getSubjectProgress,
  getAccuracyTrends,
  getCumulativeStats,
  getChapterStatus
};

