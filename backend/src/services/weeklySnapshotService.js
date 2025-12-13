/**
 * Weekly Snapshot Service
 * 
 * Creates weekly snapshots of theta values for trend analysis.
 * Snapshots are created every Sunday at end of week.
 * 
 * Features:
 * - Captures current theta state at end of week
 * - Calculates changes from previous week
 * - Tracks chapter improvements/declines
 * - Stores week summary statistics
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { batchUpdateQuestionStats } = require('./questionStatsService');

// ============================================================================
// WEEKLY SNAPSHOT CREATION
// ============================================================================

/**
 * Get Monday and Sunday of a given date's week
 * 
 * @param {Date} date - Any date in the week
 * @returns {Object} { weekStart: Date (Monday), weekEnd: Date (Sunday) }
 */
function getWeekBounds(date = new Date()) {
  const d = new Date(date);
  const day = d.getDay();
  const diff = d.getDate() - day + (day === 0 ? -6 : 1); // Adjust when day is Sunday
  const monday = new Date(d.setDate(diff));
  monday.setHours(0, 0, 0, 0);
  
  const sunday = new Date(monday);
  sunday.setDate(monday.getDate() + 6);
  sunday.setHours(23, 59, 59, 999);
  
  return {
    weekStart: monday,
    weekEnd: sunday
  };
}

/**
 * Format date as YYYY-MM-DD
 * 
 * @param {Date} date
 * @returns {string}
 */
function formatDate(date) {
  return date.toISOString().split('T')[0];
}

/**
 * Calculate week number since assessment
 * 
 * @param {Date} assessmentDate - Assessment completion date
 * @param {Date} currentDate - Current date
 * @returns {number} Week number (1-indexed)
 */
function calculateWeekNumber(assessmentDate, currentDate) {
  const msPerWeek = 7 * 24 * 60 * 60 * 1000;
  const diffMs = currentDate - assessmentDate;
  const weekNumber = Math.floor(diffMs / msPerWeek) + 1;
  return Math.max(1, weekNumber); // Minimum week 1
}

/**
 * Get previous week's snapshot for comparison
 * 
 * @param {string} userId
 * @param {Date} currentWeekEnd
 * @returns {Promise<Object|null>} Previous snapshot or null
 */
async function getPreviousWeekSnapshot(userId, currentWeekEnd) {
  try {
    const previousWeekEnd = new Date(currentWeekEnd);
    previousWeekEnd.setDate(previousWeekEnd.getDate() - 7);
    
    const snapshotsRef = db.collection('theta_history')
      .doc(userId)
      .collection('snapshots')
      .where('week_end', '==', formatDate(previousWeekEnd))
      .limit(1);
    
    const snapshotDocs = await retryFirestoreOperation(async () => {
      return await snapshotsRef.get();
    });
    
    if (snapshotDocs.empty) {
      return null;
    }
    
    return snapshotDocs.docs[0].data();
  } catch (error) {
    logger.error('Error fetching previous week snapshot', {
      userId,
      error: error.message
    });
    return null;
  }
}

/**
 * Calculate changes from previous week
 * 
 * @param {Object} currentState - Current theta state from user document
 * @param {Object|null} previousSnapshot - Previous week's snapshot or null
 * @returns {Object} Changes object
 */
function calculateChangesFromPrevious(currentState, previousSnapshot) {
  if (!previousSnapshot) {
    // First week - no previous data
    return {
      overall_delta: null,
      overall_percentile_delta: null,
      chapters_improved: 0,
      chapters_declined: 0,
      chapters_unchanged: 0,
      biggest_improvement: null,
      biggest_decline: null,
      subject_changes: {
        physics: { delta: null, percentile_delta: null },
        chemistry: { delta: null, percentile_delta: null },
        mathematics: { delta: null, percentile_delta: null }
      }
    };
  }
  
  const changes = {
    overall_delta: currentState.overall_theta - previousSnapshot.overall_theta,
    overall_percentile_delta: currentState.overall_percentile - previousSnapshot.overall_percentile,
    chapters_improved: 0,
    chapters_declined: 0,
    chapters_unchanged: 0,
    biggest_improvement: null,
    biggest_decline: null,
    subject_changes: {}
  };
  
  // Calculate chapter-level changes
  const chapterDeltas = [];
  const currentChapters = currentState.theta_by_chapter || {};
  const previousChapters = previousSnapshot.theta_by_chapter || {};
  
  for (const [chapterKey, currentChapter] of Object.entries(currentChapters)) {
    const previousChapter = previousChapters[chapterKey];
    
    if (!previousChapter) {
      // New chapter this week
      changes.chapters_improved++;
      chapterDeltas.push({
        chapter_key: chapterKey,
        delta: currentChapter.theta,
        percentile_delta: currentChapter.percentile
      });
    } else {
      const delta = currentChapter.theta - previousChapter.theta;
      const percentileDelta = currentChapter.percentile - previousChapter.percentile;
      
      if (delta > 0.01) { // Threshold to avoid floating point noise
        changes.chapters_improved++;
      } else if (delta < -0.01) {
        changes.chapters_declined++;
      } else {
        changes.chapters_unchanged++;
      }
      
      chapterDeltas.push({
        chapter_key: chapterKey,
        delta,
        percentile_delta: percentileDelta
      });
    }
  }
  
  // Find biggest improvement and decline
  if (chapterDeltas.length > 0) {
    const improvements = chapterDeltas.filter(c => c.delta > 0.01);
    const declines = chapterDeltas.filter(c => c.delta < -0.01);
    
    if (improvements.length > 0) {
      changes.biggest_improvement = improvements.reduce((max, curr) => 
        curr.delta > max.delta ? curr : max
      );
    }
    
    if (declines.length > 0) {
      changes.biggest_decline = declines.reduce((min, curr) => 
        curr.delta < min.delta ? curr : min
      );
    }
  }
  
  // Calculate subject-level changes
  const currentSubjects = currentState.theta_by_subject || {};
  const previousSubjects = previousSnapshot.theta_by_subject || {};
  
  for (const subject of ['physics', 'chemistry', 'mathematics']) {
    const current = currentSubjects[subject];
    const previous = previousSubjects[subject];
    
    if (current && previous) {
      changes.subject_changes[subject] = {
        delta: current.theta - previous.theta,
        percentile_delta: current.percentile - previous.percentile
      };
    } else {
      changes.subject_changes[subject] = {
        delta: null,
        percentile_delta: null
      };
    }
  }
  
  return changes;
}

/**
 * Get week summary statistics
 * 
 * @param {string} userId
 * @param {Date} weekStart
 * @param {Date} weekEnd
 * @returns {Promise<Object>} Week summary
 */
async function getWeekSummary(userId, weekStart, weekEnd) {
  try {
    // Query quizzes completed this week
    const quizzesRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .where('completed_at', '>=', admin.firestore.Timestamp.fromDate(weekStart))
      .where('completed_at', '<=', admin.firestore.Timestamp.fromDate(weekEnd))
      .where('status', '==', 'completed');
    
    const quizzesSnapshot = await retryFirestoreOperation(async () => {
      return await quizzesRef.get();
    });
    
    const quizzes = quizzesSnapshot.docs.map(doc => doc.data());
    
    // Calculate summary
    const totalQuestions = quizzes.reduce((sum, quiz) => sum + (quiz.questions?.length || 0), 0);
    const totalCorrect = quizzes.reduce((sum, quiz) => {
      return sum + (quiz.questions?.filter(q => q.is_correct).length || 0);
    }, 0);
    const totalTime = quizzes.reduce((sum, quiz) => sum + (quiz.total_time_seconds || 0), 0);
    
    // Get chapters explored this week (from responses)
    const responsesRef = db.collection('daily_quiz_responses')
      .doc(userId)
      .collection('responses')
      .where('answered_at', '>=', admin.firestore.Timestamp.fromDate(weekStart))
      .where('answered_at', '<=', admin.firestore.Timestamp.fromDate(weekEnd));
    
    const responsesSnapshot = await retryFirestoreOperation(async () => {
      return await responsesRef.get();
    });
    
    const chaptersThisWeek = new Set();
    responsesSnapshot.docs.forEach(doc => {
      const chapterKey = doc.data().chapter_key;
      if (chapterKey) {
        chaptersThisWeek.add(chapterKey);
      }
    });
    
    // Get previous week's chapters for comparison
    const previousWeekStart = new Date(weekStart);
    previousWeekStart.setDate(previousWeekStart.getDate() - 7);
    const previousWeekEnd = new Date(weekStart);
    previousWeekEnd.setMilliseconds(previousWeekEnd.getMilliseconds() - 1);
    
    const previousResponsesRef = db.collection('daily_quiz_responses')
      .doc(userId)
      .collection('responses')
      .where('answered_at', '>=', admin.firestore.Timestamp.fromDate(previousWeekStart))
      .where('answered_at', '<=', admin.firestore.Timestamp.fromDate(previousWeekEnd));
    
    const previousResponsesSnapshot = await retryFirestoreOperation(async () => {
      return await previousResponsesRef.get();
    });
    
    const previousChapters = new Set();
    previousResponsesSnapshot.docs.forEach(doc => {
      const chapterKey = doc.data().chapter_key;
      if (chapterKey) {
        previousChapters.add(chapterKey);
      }
    });
    
    const newChapters = Array.from(chaptersThisWeek).filter(ch => !previousChapters.has(ch));
    
    return {
      questions_answered: totalQuestions,
      accuracy: totalQuestions > 0 ? totalCorrect / totalQuestions : 0,
      time_spent_minutes: Math.round(totalTime / 60),
      new_chapters_explored: newChapters.length,
      chapters_reached_confident: 0 // TODO: Calculate from chapter_attempt_counts
    };
  } catch (error) {
    logger.error('Error calculating week summary', {
      userId,
      error: error.message
    });
    return {
      questions_answered: 0,
      accuracy: 0,
      time_spent_minutes: 0,
      new_chapters_explored: 0,
      chapters_reached_confident: 0
    };
  }
}

/**
 * Create weekly snapshot for a user
 * 
 * @param {string} userId
 * @param {Date} snapshotDate - Date to create snapshot for (defaults to current date)
 * @returns {Promise<Object>} Created snapshot data
 */
async function createWeeklySnapshot(userId, snapshotDate = new Date()) {
  try {
    // Get user document
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
      throw new Error(`User ${userId} has not completed assessment`);
    }
    
    // Get week bounds
    const { weekStart, weekEnd } = getWeekBounds(snapshotDate);
    const weekStartStr = formatDate(weekStart);
    const weekEndStr = formatDate(weekEnd);
    
    // Check if snapshot already exists for this week
    const existingSnapshotRef = db.collection('theta_history')
      .doc(userId)
      .collection('snapshots')
      .doc(`snapshot_week_${weekEndStr}`);
    
    const existingSnapshot = await retryFirestoreOperation(async () => {
      return await existingSnapshotRef.get();
    });
    
    if (existingSnapshot.exists) {
      logger.info('Weekly snapshot already exists for this week', {
        userId,
        weekEnd: weekEndStr
      });
      return existingSnapshot.data();
    }
    
    // Get previous week snapshot
    const previousSnapshot = await getPreviousWeekSnapshot(userId, weekEnd);
    
    // Calculate changes
    const changes = calculateChangesFromPrevious(userData, previousSnapshot);
    
    // Get week summary
    const weekSummary = await getWeekSummary(userId, weekStart, weekEnd);
    
    // Calculate week number
    const assessmentDate = new Date(userData.assessment.completed_at);
    const weekNumber = calculateWeekNumber(assessmentDate, weekEnd);
    
    // Count quizzes this week
    const quizzesRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .where('completed_at', '>=', admin.firestore.Timestamp.fromDate(weekStart))
      .where('completed_at', '<=', admin.firestore.Timestamp.fromDate(weekEnd))
      .where('status', '==', 'completed');
    
    const quizzesSnapshot = await retryFirestoreOperation(async () => {
      return await quizzesRef.get();
    });
    
    const quizCount = quizzesSnapshot.size;
    
    // Create snapshot data
    const snapshotData = {
      snapshot_id: `snapshot_week_${weekEndStr}`,
      student_id: userId,
      snapshot_type: 'weekly',
      week_start: weekStartStr,
      week_end: weekEndStr,
      week_number: weekNumber,
      quiz_count: quizCount,
      
      // Deep copy of current theta state
      theta_by_chapter: JSON.parse(JSON.stringify(userData.theta_by_chapter || {})),
      theta_by_subject: JSON.parse(JSON.stringify(userData.theta_by_subject || {})),
      overall_theta: userData.overall_theta || 0,
      overall_percentile: userData.overall_percentile || 50,
      
      // Changes from previous week
      changes_from_previous: changes,
      
      // Week summary
      week_summary: weekSummary,
      
      // Timestamp
      captured_at: weekEnd.toISOString()
    };
    
    // Save snapshot
    await retryFirestoreOperation(async () => {
      return await existingSnapshotRef.set(snapshotData);
    });
    
    logger.info('Weekly snapshot created', {
      userId,
      weekEnd: weekEndStr,
      weekNumber,
      quizCount
    });
    
    return snapshotData;
  } catch (error) {
    logger.error('Error creating weekly snapshot', {
      userId,
      error: error.message,
      stack: error.stack
    });
    throw error;
  }
}

/**
 * Get all unique question IDs that were answered this week
 * 
 * @param {Date} weekStart
 * @param {Date} weekEnd
 * @returns {Promise<Set<string>>} Set of question IDs
 */
async function getQuestionsAnsweredThisWeek(weekStart, weekEnd) {
  try {
    const questionIds = new Set();
    
    // Get from daily quiz responses
    const dailyQuizResponsesRef = db.collectionGroup('daily_quiz_responses')
      .where('answered_at', '>=', admin.firestore.Timestamp.fromDate(weekStart))
      .where('answered_at', '<=', admin.firestore.Timestamp.fromDate(weekEnd));
    
    const dailyQuizSnapshot = await retryFirestoreOperation(async () => {
      return await dailyQuizResponsesRef.get();
    });
    
    dailyQuizSnapshot.docs.forEach(doc => {
      const questionId = doc.data().question_id;
      if (questionId) {
        questionIds.add(questionId);
      }
    });
    
    // Get from assessment responses (if any this week - unlikely but possible)
    const assessmentResponsesRef = db.collectionGroup('assessment_responses')
      .where('answered_at', '>=', admin.firestore.Timestamp.fromDate(weekStart))
      .where('answered_at', '<=', admin.firestore.Timestamp.fromDate(weekEnd));
    
    const assessmentSnapshot = await retryFirestoreOperation(async () => {
      return await assessmentResponsesRef.get();
    });
    
    assessmentSnapshot.docs.forEach(doc => {
      const questionId = doc.data().question_id;
      if (questionId) {
        questionIds.add(questionId);
      }
    });
    
    return questionIds;
  } catch (error) {
    logger.error('Error getting questions answered this week', {
      error: error.message
    });
    return new Set();
  }
}

/**
 * Create weekly snapshots for all users who completed assessment
 * Also updates question statistics for all questions
 * (Called by scheduled job)
 * 
 * @param {Date} snapshotDate - Date to create snapshots for
 * @param {Object} options - Options for job
 * @param {boolean} options.updateQuestionStats - Whether to update question stats (default: true)
 * @returns {Promise<Object>} Summary of snapshots created
 */
async function createWeeklySnapshotsForAllUsers(snapshotDate = new Date(), options = {}) {
  const { updateQuestionStats = true } = options;
  
  try {
    // Get all users who completed assessment
    const usersRef = db.collection('users')
      .where('assessment.status', '==', 'completed');
    
    const usersSnapshot = await retryFirestoreOperation(async () => {
      return await usersRef.get();
    });
    
    const results = {
      total: usersSnapshot.size,
      created: 0,
      errors: 0,
      errorDetails: [],
      questionStatsUpdated: 0,
      questionStatsErrors: 0
    };
    
    // Create snapshot for each user
    for (const userDoc of usersSnapshot.docs) {
      try {
        await createWeeklySnapshot(userDoc.id, snapshotDate);
        results.created++;
      } catch (error) {
        results.errors++;
        results.errorDetails.push({
          userId: userDoc.id,
          error: error.message
        });
        logger.error('Error creating snapshot for user', {
          userId: userDoc.id,
          error: error.message
        });
      }
    }
    
    // Update question statistics if enabled
    if (updateQuestionStats) {
      try {
        logger.info('Starting question statistics update');
        
        // Get week bounds
        const { weekStart, weekEnd } = getWeekBounds(snapshotDate);
        
        // Get all questions answered this week
        const questionsThisWeek = await getQuestionsAnsweredThisWeek(weekStart, weekEnd);
        
        logger.info('Found questions to update', {
          count: questionsThisWeek.size
        });
        
        // For comprehensive update, we should update ALL questions that have been answered
        // (not just this week, but all questions in the system)
        // However, for performance, we can start with just this week's questions
        
        // Option 1: Update only questions answered this week (faster)
        const questionIds = Array.from(questionsThisWeek);
        
        // Option 2: Update all questions (comprehensive but slower)
        // For now, we'll update all questions to ensure accuracy
        // In production, you might want to do this less frequently (e.g., monthly)
        
        // Get all question IDs from questions collection
        const allQuestionsRef = db.collection('questions')
          .select('question_id')
          .limit(10000); // Firestore limit
        
        const allQuestionsSnapshot = await retryFirestoreOperation(async () => {
          return await allQuestionsRef.get();
        });
        
        const allQuestionIds = allQuestionsSnapshot.docs.map(doc => doc.id);
        
        logger.info('Updating statistics for all questions', {
          totalQuestions: allQuestionIds.length
        });
        
        // Batch update in chunks of 100 for better performance
        const batchSize = 100;
        for (let i = 0; i < allQuestionIds.length; i += batchSize) {
          const batch = allQuestionIds.slice(i, i + batchSize);
          const batchResults = await batchUpdateQuestionStats(batch);
          
          results.questionStatsUpdated += batchResults.updated;
          results.questionStatsErrors += batchResults.errors;
          
          logger.info('Question stats batch update progress', {
            processed: Math.min(i + batchSize, allQuestionIds.length),
            total: allQuestionIds.length,
            updated: batchResults.updated,
            errors: batchResults.errors
          });
        }
        
        logger.info('Question statistics update completed', {
          total: allQuestionIds.length,
          updated: results.questionStatsUpdated,
          errors: results.questionStatsErrors
        });
      } catch (error) {
        logger.error('Error updating question statistics', {
          error: error.message,
          stack: error.stack
        });
        results.questionStatsErrors = -1; // Indicate fatal error
      }
    }
    
    logger.info('Weekly snapshots creation completed', results);
    return results;
  } catch (error) {
    logger.error('Error creating weekly snapshots for all users', {
      error: error.message,
      stack: error.stack
    });
    throw error;
  }
}

module.exports = {
  createWeeklySnapshot,
  createWeeklySnapshotsForAllUsers,
  getWeekBounds,
  formatDate,
  calculateWeekNumber,
  getQuestionsAnsweredThisWeek
};

