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
const { toIST, formatDateIST } = require('../utils/dateUtils');

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
 * Includes both daily quizzes AND initial assessment responses.
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

    const dailyData = {};

    // 1. Get completed daily quizzes
    const quizzesRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .where('status', '==', 'completed')
      .where('completed_at', '>=', cutoffTimestamp)
      .orderBy('completed_at', 'desc');

    const quizzesSnapshot = await retryFirestoreOperation(async () => {
      return await quizzesRef.get();
    });

    quizzesSnapshot.docs.forEach(doc => {
      const quiz = doc.data();
      const completedAt = quiz.completed_at?.toDate();

      if (!completedAt) return;

      // Convert to IST for correct date grouping for Indian students
      const completedAtIST = toIST(completedAt);
      const dateKey = formatDateIST(completedAtIST); // YYYY-MM-DD in IST

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
      // Use total_questions field, fallback to questions array length
      dailyData[dateKey].questions += (quiz.total_questions || quiz.questions?.length || 0);
      dailyData[dateKey].correct += (quiz.score || 0);
    });

    // 2. Get initial assessment responses (30 questions answered during onboarding)
    const assessmentRef = db.collection('assessment_responses')
      .doc(userId)
      .collection('responses')
      .where('answered_at', '>=', cutoffTimestamp);

    const assessmentSnapshot = await retryFirestoreOperation(async () => {
      return await assessmentRef.get();
    });

    if (!assessmentSnapshot.empty) {
      // Group assessment responses by date
      assessmentSnapshot.docs.forEach(doc => {
        const response = doc.data();
        const answeredAt = response.answered_at?.toDate();

        if (!answeredAt) return;

        // Convert to IST for correct date grouping
        const answeredAtIST = toIST(answeredAt);
        const dateKey = formatDateIST(answeredAtIST);

        if (!dailyData[dateKey]) {
          dailyData[dateKey] = {
            date: dateKey,
            quizzes: 0,
            questions: 0,
            correct: 0,
            accuracy: 0
          };
        }

        dailyData[dateKey].questions += 1;
        if (response.is_correct) {
          dailyData[dateKey].correct += 1;
        }
      });

      // Count assessment as 1 "quiz" for the day it was completed (if any responses exist)
      // Find the date with assessment responses and mark it
      const assessmentDates = new Set();
      assessmentSnapshot.docs.forEach(doc => {
        const response = doc.data();
        const answeredAt = response.answered_at?.toDate();
        if (answeredAt) {
          const answeredAtIST = toIST(answeredAt);
          const dateKey = formatDateIST(answeredAtIST);
          assessmentDates.add(dateKey);
        }
      });

      // Add 1 quiz count for each date that had assessment responses
      assessmentDates.forEach(dateKey => {
        if (dailyData[dateKey]) {
          dailyData[dateKey].quizzes += 1;
        }
      });
    }

    // Calculate accuracy for each day
    const trends = [];
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
// SUBJECT ACCURACY TRENDS
// ============================================================================

/**
 * Get subject-level accuracy trends over time
 *
 * @param {string} userId
 * @param {string} subject - Subject to filter by (physics, chemistry, maths/mathematics)
 * @param {number} days - Number of days to look back (default: 30)
 * @returns {Promise<Array>} Array of daily accuracy data for the subject
 */
async function getSubjectAccuracyTrends(userId, subject, days = 30) {
  try {
    // Normalize subject name
    const normalizedSubject = subject.toLowerCase();
    const subjectPrefix = normalizedSubject === 'mathematics' ? 'maths' : normalizedSubject;

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

    const dailyData = {};

    // Process each quiz
    for (const quizDoc of quizzesSnapshot.docs) {
      const quiz = quizDoc.data();
      const completedAt = quiz.completed_at?.toDate();

      if (!completedAt) continue;

      // Convert to IST for correct date grouping for Indian students
      const completedAtIST = toIST(completedAt);
      const dateKey = formatDateIST(completedAtIST); // YYYY-MM-DD in IST

      // Get questions from subcollection to get subject-level data
      const questionsSnapshot = await retryFirestoreOperation(async () => {
        return await quizDoc.ref.collection('questions').get();
      });

      // Count subject-specific questions
      let subjectQuestions = 0;
      let subjectCorrect = 0;

      questionsSnapshot.docs.forEach(qDoc => {
        const q = qDoc.data();
        if (!q.answered || !q.chapter_key) return;

        // Extract subject from chapter_key (format: "physics_mechanics")
        const chapterSubject = q.chapter_key.split('_')[0]?.toLowerCase();

        // Match against both 'maths' and 'mathematics'
        const isMatch = chapterSubject === subjectPrefix ||
          (normalizedSubject === 'mathematics' && chapterSubject === 'maths') ||
          (normalizedSubject === 'maths' && chapterSubject === 'mathematics');

        if (isMatch) {
          subjectQuestions++;
          if (q.is_correct) {
            subjectCorrect++;
          }
        }
      });

      // Only add to data if this quiz had questions for this subject
      if (subjectQuestions > 0) {
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
        dailyData[dateKey].questions += subjectQuestions;
        dailyData[dateKey].correct += subjectCorrect;
      }
    }

    // Calculate accuracy for each day
    const trends = [];
    for (const [date, data] of Object.entries(dailyData)) {
      data.accuracy = data.questions > 0
        ? Math.round((data.correct / data.questions) * 100)
        : 0;
      trends.push(data);
    }

    // Sort by date (ascending)
    trends.sort((a, b) => a.date.localeCompare(b.date));

    logger.info('Subject accuracy trends retrieved', {
      userId,
      subject: normalizedSubject,
      days,
      dataPoints: trends.length
    });

    return trends;
  } catch (error) {
    logger.error('Error getting subject accuracy trends', {
      userId,
      subject,
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
 * OPTIMIZED: Now uses denormalized stats from user document instead of
 * reading 1000 response documents (500 reads → 1 read = 99.8% cost reduction)
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

    // Use denormalized cumulative stats (maintained during quiz completion)
    const cumulativeStats = userData.cumulative_stats || {
      total_questions_correct: 0,
      total_questions_attempted: 0,
      overall_accuracy: 0.0
    };

    // Calculate overall accuracy from denormalized data
    const overallAccuracy = cumulativeStats.total_questions_attempted > 0
      ? cumulativeStats.total_questions_correct / cumulativeStats.total_questions_attempted
      : 0;

    // Count chapters explored and confident from theta_by_chapter
    const thetaByChapter = userData.theta_by_chapter || {};
    let chaptersExplored = 0;
    let chaptersConfident = 0;

    Object.values(thetaByChapter).forEach(chapterData => {
      if (chapterData.attempts > 0) {
        chaptersExplored++;
        // Confident = percentile >= 70
        if ((chapterData.percentile || 50) >= 70) {
          chaptersConfident++;
        }
      }
    });

    return {
      // Quiz counts (from user document)
      total_quizzes: userData.completed_quiz_count || 0,
      completed_quiz_count: userData.completed_quiz_count || 0,

      // Question counts (from denormalized stats)
      total_questions: userData.total_questions_solved || 0,
      total_questions_correct: cumulativeStats.total_questions_correct || 0,
      total_questions_attempted: cumulativeStats.total_questions_attempted || 0,

      // Time tracking (from user document)
      total_time_minutes: userData.total_time_spent_minutes || 0,

      // Accuracy (from denormalized stats)
      overall_accuracy: Math.round(overallAccuracy * 1000) / 1000,

      // Chapter progress (calculated from theta_by_chapter)
      chapters_explored: chaptersExplored,
      chapters_confident: chaptersConfident,

      // Learning phase (from user document)
      learning_phase: userData.learning_phase || 'exploration',

      // Metadata
      last_updated: cumulativeStats.last_updated || userData.last_quiz_completed_at
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
  getSubjectAccuracyTrends,
  getCumulativeStats,
  getChapterStatus
};

