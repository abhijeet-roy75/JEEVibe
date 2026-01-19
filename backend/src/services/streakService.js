/**
 * Streak Service
 * 
 * Tracks practice streaks and usage patterns.
 * 
 * Features:
 * - Practice streak tracking (consecutive days)
 * - Weekly patterns (Monday-Sunday)
 * - Missed days detection
 * - Cumulative practice statistics
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { getNowIST, toIST, formatDateIST, getStartOfDayIST, getEndOfDayIST, getDayOfWeekIST } = require('../utils/dateUtils');

// ============================================================================
// STREAK CALCULATION
// ============================================================================

/**
 * Update practice streak for a user
 * Called after quiz completion
 * 
 * @param {string} userId
 * @returns {Promise<Object>} Updated streak data
 */
async function updateStreak(userId) {
  try {
    const streakRef = db.collection('practice_streaks').doc(userId);
    const streakDoc = await retryFirestoreOperation(async () => {
      return await streakRef.get();
    });
    
    // Use IST for date calculations (for Indian students)
    const todayIST = getNowIST();
    const todayStr = formatDateIST(todayIST);
    const yesterdayIST = new Date(todayIST);
    yesterdayIST.setDate(yesterdayIST.getDate() - 1);
    const yesterdayStr = formatDateIST(yesterdayIST);
    
    let streakData = streakDoc.exists ? streakDoc.data() : {
      student_id: userId,
      current_streak: 0,
      longest_streak: 0,
      last_practice_date: null,
      practice_days: {},
      total_days_practiced: 0,
      total_quizzes_completed: 0,
      total_questions_answered: 0,
      total_time_spent_minutes: 0,
      weekly_stats: [],
      day_of_week_pattern: {
        monday: { practiced: false, avg_accuracy: null },
        tuesday: { practiced: false, avg_accuracy: null },
        wednesday: { practiced: false, avg_accuracy: null },
        thursday: { practiced: false, avg_accuracy: null },
        friday: { practiced: false, avg_accuracy: null },
        saturday: { practiced: false, avg_accuracy: null },
        sunday: { practiced: false, avg_accuracy: null }
      },
      last_updated: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Check if already practiced today
    if (streakData.last_practice_date === todayStr) {
      // Already updated today, return current data
      return streakData;
    }
    
    // Get today's quiz data (using IST day boundaries)
    const todayStart = getStartOfDayIST(new Date());
    const todayEnd = getEndOfDayIST(new Date());
    
    const todayQuizzesRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .where('status', '==', 'completed')
      .where('completed_at', '>=', admin.firestore.Timestamp.fromDate(todayStart))
      .where('completed_at', '<=', admin.firestore.Timestamp.fromDate(todayEnd));
    
    const todayQuizzesSnapshot = await retryFirestoreOperation(async () => {
      return await todayQuizzesRef.get();
    });
    
    const todayQuizzes = todayQuizzesSnapshot.docs.map(doc => doc.data());
    const todayQuizCount = todayQuizzes.length;
    const todayQuestions = todayQuizzes.reduce((sum, q) => sum + (q.questions?.length || 0), 0);
    const todayCorrect = todayQuizzes.reduce((sum, q) => sum + (q.score || 0), 0);
    const todayAccuracy = todayQuestions > 0 ? todayCorrect / todayQuestions : 0;
    const todayTimeMinutes = todayQuizzes.reduce((sum, q) => sum + Math.round((q.total_time_seconds || 0) / 60), 0);
    
    // Update streak
    let newStreak = streakData.current_streak || 0;
    
    if (streakData.last_practice_date === yesterdayStr) {
      // Consecutive day - increment streak
      newStreak += 1;
    } else if (streakData.last_practice_date && streakData.last_practice_date !== todayStr) {
      // Streak broken - reset to 1
      newStreak = 1;
    } else if (!streakData.last_practice_date) {
      // First practice
      newStreak = 1;
    }
    
    // Update longest streak
    const longestStreak = Math.max(streakData.longest_streak || 0, newStreak);
    
    // Update practice days
    const practiceDays = { ...(streakData.practice_days || {}) };
    practiceDays[todayStr] = {
      quizzes: todayQuizCount,
      questions: todayQuestions,
      accuracy: todayQuestions > 0 ? todayAccuracy : null,
      time_spent_minutes: todayTimeMinutes
    };
    
    // Keep only last 7 days
    const sevenDaysAgo = new Date(todayIST);
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    const sevenDaysAgoStr = formatDateIST(sevenDaysAgo);
    
    Object.keys(practiceDays).forEach(date => {
      if (date < sevenDaysAgoStr) {
        delete practiceDays[date];
      }
    });
    
    // Update day of week pattern (using IST)
    const dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    const dayOfWeek = dayNames[getDayOfWeekIST(new Date())];
    const dayPattern = { ...streakData.day_of_week_pattern };
    
    if (!dayPattern[dayOfWeek]) {
      dayPattern[dayOfWeek] = { practiced: false, avg_accuracy: null };
    }
    
    dayPattern[dayOfWeek].practiced = true;
    
    // Calculate average accuracy for this day of week
    const dayOfWeekQuizzes = await getQuizzesForDayOfWeek(userId, dayOfWeek);
    if (dayOfWeekQuizzes.length > 0) {
      const totalQ = dayOfWeekQuizzes.reduce((sum, q) => sum + (q.questions?.length || 0), 0);
      const totalC = dayOfWeekQuizzes.reduce((sum, q) => sum + (q.score || 0), 0);
      dayPattern[dayOfWeek].avg_accuracy = totalQ > 0 ? totalC / totalQ : null;
    }
    
    // Get user data for totals
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    const userData = userDoc.exists ? userDoc.data() : {};

    // Update weekly stats (Sunday = week end)
    const weeklyStats = [...(streakData.weekly_stats || [])];
    const currentWeekEnd = getWeekEnd(todayIST);

    // Check if current week already exists in stats
    const existingWeekIndex = weeklyStats.findIndex(w => w.week_end === currentWeekEnd);

    const weekData = {
      week_end: currentWeekEnd,
      days_practiced: Object.keys(practiceDays).filter(d => d >= getWeekStart(todayIST) && d <= currentWeekEnd).length,
      total_quizzes: todayQuizCount,
      total_questions: todayQuestions,
      total_correct: todayCorrect,
      avg_accuracy: todayAccuracy,
      total_time_minutes: todayTimeMinutes
    };

    if (existingWeekIndex >= 0) {
      // Update existing week
      weeklyStats[existingWeekIndex] = weekData;
    } else {
      // Add new week
      weeklyStats.push(weekData);

      // Limit to last 52 weeks (1 year of data)
      const MAX_WEEKLY_STATS = 52;
      if (weeklyStats.length > MAX_WEEKLY_STATS) {
        weeklyStats.splice(0, weeklyStats.length - MAX_WEEKLY_STATS);
      }
    }

    // Update streak document
    const updatedStreak = {
      student_id: userId,
      current_streak: newStreak,
      longest_streak: longestStreak,
      last_practice_date: todayStr,
      practice_days: practiceDays,
      total_days_practiced: (streakData.total_days_practiced || 0) + (streakData.last_practice_date !== todayStr ? 1 : 0),
      total_quizzes_completed: userData.completed_quiz_count || 0,
      total_questions_answered: userData.total_questions_solved || 0,
      total_time_spent_minutes: userData.total_time_spent_minutes || 0,
      weekly_stats: weeklyStats,
      day_of_week_pattern: dayPattern,
      last_updated: admin.firestore.FieldValue.serverTimestamp()
    };
    
    await retryFirestoreOperation(async () => {
      return await streakRef.set(updatedStreak, { merge: true });
    });
    
    logger.info('Streak updated', {
      userId,
      current_streak: newStreak,
      longest_streak: longestStreak
    });
    
    return updatedStreak;
  } catch (error) {
    logger.error('Error updating streak', {
      userId,
      error: error.message,
      stack: error.stack
    });
    throw error;
  }
}

/**
 * Get streak data for a user
 * 
 * @param {string} userId
 * @returns {Promise<Object>} Streak data
 */
async function getStreak(userId) {
  try {
    const streakRef = db.collection('practice_streaks').doc(userId);
    const streakDoc = await retryFirestoreOperation(async () => {
      return await streakRef.get();
    });
    
    if (!streakDoc.exists) {
      // Return default streak data
      return {
        student_id: userId,
        current_streak: 0,
        longest_streak: 0,
        last_practice_date: null,
        practice_days: {},
        total_days_practiced: 0,
        total_quizzes_completed: 0,
        total_questions_answered: 0,
        total_time_spent_minutes: 0
      };
    }
    
    return streakDoc.data();
  } catch (error) {
    logger.error('Error getting streak', {
      userId,
      error: error.message
    });
    throw error;
  }
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

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
 * Get day of week name (lowercase)
 *
 * @param {Date} date
 * @returns {string} 'monday', 'tuesday', etc.
 */
function getDayOfWeek(date) {
  const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  return days[date.getDay()];
}

/**
 * Get week end date (Sunday) for a given date
 *
 * @param {Date} date
 * @returns {string} YYYY-MM-DD format
 */
function getWeekEnd(date) {
  const dayOfWeek = date.getDay(); // 0 = Sunday, 6 = Saturday
  const daysUntilSunday = 7 - dayOfWeek;
  const weekEnd = new Date(date);

  if (dayOfWeek === 0) {
    // Already Sunday
    return formatDate(weekEnd);
  }

  weekEnd.setDate(weekEnd.getDate() + daysUntilSunday);
  return formatDate(weekEnd);
}

/**
 * Get week start date (Monday) for a given date
 *
 * @param {Date} date
 * @returns {string} YYYY-MM-DD format
 */
function getWeekStart(date) {
  const dayOfWeek = date.getDay(); // 0 = Sunday, 6 = Saturday
  const daysSinceMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1; // Handle Sunday
  const weekStart = new Date(date);
  weekStart.setDate(weekStart.getDate() - daysSinceMonday);
  return formatDate(weekStart);
}

/**
 * Get quizzes for a specific day of week
 * 
 * @param {string} userId
 * @param {string} dayOfWeek - 'monday', 'tuesday', etc.
 * @returns {Promise<Array>} Quizzes for that day of week
 */
async function getQuizzesForDayOfWeek(userId, dayOfWeek) {
  try {
    // Get all completed quizzes
    const quizzesRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .where('status', '==', 'completed')
      .orderBy('completed_at', 'desc')
      .limit(100); // Last 100 quizzes
    
    const snapshot = await retryFirestoreOperation(async () => {
      return await quizzesRef.get();
    });
    
    const dayQuizzes = [];
    
    snapshot.docs.forEach(doc => {
      const quiz = doc.data();
      const completedAt = quiz.completed_at?.toDate();
      
      if (completedAt && getDayOfWeek(completedAt) === dayOfWeek) {
        dayQuizzes.push(quiz);
      }
    });
    
    return dayQuizzes;
  } catch (error) {
    logger.error('Error getting quizzes for day of week', {
      userId,
      dayOfWeek,
      error: error.message
    });
    return [];
  }
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  updateStreak,
  getStreak,
  formatDate,
  getDayOfWeek
};

