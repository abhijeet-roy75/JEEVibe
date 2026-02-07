/**
 * Chapter Unlock Service
 *
 * Implements the 24-month countdown timeline for JEE preparation.
 * Chapters unlock based on months until target exam date.
 *
 * Key Features:
 * - Countdown-based unlocking (exam-date dependent)
 * - High-water mark pattern (chapters never re-lock)
 * - Support for January and April JEE sessions
 * - Handles late joiners, exam date changes, post-exam students
 */

const { db } = require('../config/firebase');
const admin = require('firebase-admin');
const logger = require('../utils/logger');

// Cache for schedule (5-minute TTL)
let scheduleCache = null;
let scheduleCacheTimestamp = 0;
const CACHE_TTL_MS = 5 * 60 * 1000;

const TOTAL_TIMELINE_MONTHS = 24;

/**
 * Get timeline position from target exam date
 * @param {string} jeeTargetExamDate - Format: "YYYY-MM" (e.g., "2027-01" or "2027-04")
 * @param {Date} currentDate - Current date
 * @returns {Object} { currentMonth, monthsUntilExam, isPostExam, examSession }
 */
function getTimelinePosition(jeeTargetExamDate, currentDate = new Date()) {
  // Parse target (e.g., "2027-01" -> Jan 2027, "2027-04" -> April 2027)
  const [targetYear, targetMonth] = jeeTargetExamDate.split('-').map(Number);
  const examDate = new Date(targetYear, targetMonth - 1, 20); // 20th of exam month

  // Calculate months until exam
  const monthsUntilExam = Math.max(0,
    (examDate.getFullYear() - currentDate.getFullYear()) * 12 +
    (examDate.getMonth() - currentDate.getMonth())
  );

  // Timeline position (month 1 = 24 months before, month 24 = exam month)
  // For April exams, students get 3 extra months automatically (they're "further along")
  const currentMonth = Math.max(1, Math.min(TOTAL_TIMELINE_MONTHS,
    TOTAL_TIMELINE_MONTHS - monthsUntilExam + 1));

  return {
    currentMonth,        // 1-24
    monthsUntilExam,
    isPostExam: monthsUntilExam <= 0,
    examSession: targetMonth === 1 ? 'January' : 'April'
  };
}

/**
 * Get active unlock schedule (with caching)
 */
async function getActiveSchedule() {
  const now = Date.now();
  if (scheduleCache && (now - scheduleCacheTimestamp < CACHE_TTL_MS)) {
    return scheduleCache;
  }

  const snapshot = await db.collection('unlock_schedules')
    .where('type', '==', 'countdown_24month')
    .where('active', '==', true)
    .limit(1)
    .get();

  if (snapshot.empty) {
    throw new Error('No active countdown unlock schedule found');
  }

  scheduleCache = snapshot.docs[0].data();
  scheduleCacheTimestamp = now;
  return scheduleCache;
}

/**
 * Get all chapter keys (for post-exam or all_unlocked)
 */
async function getAllChapterKeys() {
  // Query distinct chapter keys from questions collection
  const snapshot = await db.collection('questions')
    .where('active', '==', true)
    .select('chapter_key')
    .get();

  const keys = new Set();
  snapshot.docs.forEach(doc => {
    const chapterKey = doc.data().chapter_key;
    if (chapterKey) {
      keys.add(chapterKey);
    }
  });

  return Array.from(keys);
}

/**
 * Get unlocked chapters for a user
 * @param {string} userId - User ID
 * @param {Date} referenceDate - Date to use (defaults to now)
 * @returns {Object} { unlockedChapterKeys, currentMonth, monthsUntilExam, isPostExam, usingHighWaterMark }
 */
async function getUnlockedChapters(userId, referenceDate = new Date()) {
  // Get user data
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    throw new Error(`User ${userId} not found`);
  }

  const userData = userDoc.data();

  // Backward compatibility: users without jeeTargetExamDate get all chapters
  if (!userData.jeeTargetExamDate) {
    logger.info('User has no jeeTargetExamDate, unlocking all chapters', { userId });
    return {
      unlockedChapterKeys: await getAllChapterKeys(),
      currentMonth: TOTAL_TIMELINE_MONTHS,
      monthsUntilExam: 0,
      isPostExam: true,
      isLegacyUser: true
    };
  }

  const schedule = await getActiveSchedule();
  const position = getTimelinePosition(userData.jeeTargetExamDate, referenceDate);

  // If post-exam, unlock everything
  if (position.isPostExam) {
    return {
      unlockedChapterKeys: await getAllChapterKeys(),
      ...position
    };
  }

  // High-water mark pattern - chapters never re-lock
  const highWaterMark = userData.chapterUnlockHighWaterMark || 0;
  const currentMonthForUnlock = Math.max(position.currentMonth, highWaterMark);

  // If this is a new high, update it
  if (position.currentMonth > highWaterMark) {
    await db.collection('users').doc(userId).update({
      chapterUnlockHighWaterMark: position.currentMonth,
      chapterUnlockHighWaterMarkUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    logger.info('Updated high-water mark', {
      userId,
      oldHighWaterMark: highWaterMark,
      newHighWaterMark: position.currentMonth
    });
  }

  // Collect chapters from month 1 to currentMonthForUnlock (NOT position.currentMonth)
  const unlockedChapters = new Set();

  for (let m = 1; m <= currentMonthForUnlock; m++) {
    const monthData = schedule.timeline[`month_${m}`];
    if (!monthData) continue;

    if (monthData.all_unlocked) {
      return {
        unlockedChapterKeys: await getAllChapterKeys(),
        ...position,
        usingHighWaterMark: currentMonthForUnlock > position.currentMonth
      };
    }

    // Add chapters from each subject
    // NOTE: Empty arrays are expected - they mean "no new chapters this month"
    // Students continue mastering previously unlocked chapters
    ['physics', 'chemistry', 'mathematics'].forEach(subject => {
      if (Array.isArray(monthData[subject]) && monthData[subject].length > 0) {
        monthData[subject].forEach(ch => unlockedChapters.add(ch));
      }
      // If monthData[subject] is [] (empty), skip - no new chapters for this subject this month
    });
  }

  // Add override chapters (manually unlocked)
  if (userData.chapterUnlockOverrides) {
    Object.keys(userData.chapterUnlockOverrides).forEach(ch => {
      unlockedChapters.add(ch);
    });
  }

  logger.info('Calculated unlocked chapters', {
    userId,
    currentMonth: position.currentMonth,
    highWaterMark,
    usingHighWaterMark: currentMonthForUnlock > position.currentMonth,
    monthsUntilExam: position.monthsUntilExam,
    unlockedCount: unlockedChapters.size
  });

  return {
    unlockedChapterKeys: Array.from(unlockedChapters),
    ...position,
    usingHighWaterMark: currentMonthForUnlock > position.currentMonth
  };
}

/**
 * Check if a specific chapter is unlocked
 */
async function isChapterUnlocked(userId, chapterKey) {
  const result = await getUnlockedChapters(userId);
  return result.unlockedChapterKeys.includes(chapterKey);
}

/**
 * Add a manual chapter unlock override
 */
async function addChapterUnlockOverride(userId, chapterKey, unlockedBy, reason) {
  await db.collection('users').doc(userId).update({
    [`chapterUnlockOverrides.${chapterKey}`]: {
      unlockedAt: admin.firestore.FieldValue.serverTimestamp(),
      unlockedBy,
      reason
    }
  });

  logger.info('Added chapter unlock override', { userId, chapterKey, unlockedBy });
}

module.exports = {
  getTimelinePosition,
  getUnlockedChapters,
  isChapterUnlocked,
  addChapterUnlockOverride,
  getActiveSchedule,
  TOTAL_TIMELINE_MONTHS
};
