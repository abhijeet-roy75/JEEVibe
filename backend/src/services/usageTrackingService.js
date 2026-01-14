/**
 * Usage Tracking Service
 *
 * Tracks daily usage limits per user based on their subscription tier.
 * Supports multiple usage types: snap_solve, daily_quiz, ai_tutor, etc.
 *
 * Usage is tracked in: users/{userId}/daily_usage/{date}
 * Resets at midnight IST
 */

const { db, admin } = require('../config/firebase');
const logger = require('../utils/logger');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const { getEffectiveTier } = require('./subscriptionService');
const { getTierLimits, isUnlimited } = require('./tierConfigService');

// Usage type to limit key mapping
const USAGE_TYPE_MAP = {
  snap_solve: 'snap_solve_daily',
  daily_quiz: 'daily_quiz_daily',
  ai_tutor: 'ai_tutor_messages_daily'
};

/**
 * Get the date key for today in IST timezone
 * @returns {string} Date string in YYYY-MM-DD format
 */
function getTodayDateKey() {
  // Get current time in IST (UTC+5:30)
  const now = new Date();
  const istOffset = 5.5 * 60 * 60 * 1000; // 5.5 hours in milliseconds
  const istTime = new Date(now.getTime() + istOffset);
  return istTime.toISOString().split('T')[0];
}

/**
 * Get next midnight IST timestamp
 * @returns {Date} Midnight IST timestamp
 */
function getNextMidnightIST() {
  const now = new Date();
  const istOffset = 5.5 * 60; // 5.5 hours in minutes

  // Convert to IST
  const istNow = new Date(now.getTime() + (istOffset * 60 * 1000));

  // Set to next midnight IST
  const istMidnight = new Date(istNow);
  istMidnight.setUTCHours(24 - 5, 30, 0, 0); // Next day 00:00 IST = 18:30 UTC previous day

  // If we're past midnight IST today, move to next day
  if (istMidnight <= now) {
    istMidnight.setDate(istMidnight.getDate() + 1);
  }

  return istMidnight;
}

/**
 * Get current usage for a user and usage type
 *
 * @param {string} userId - User ID
 * @param {string} usageType - Type of usage (snap_solve, daily_quiz, ai_tutor)
 * @returns {Promise<Object>} Usage info { used, limit, remaining, resets_at, is_unlimited }
 */
async function getUsage(userId, usageType) {
  const dateKey = getTodayDateKey();
  const limitKey = USAGE_TYPE_MAP[usageType] || `${usageType}_daily`;

  try {
    // Get user's tier and limits
    const tierInfo = await getEffectiveTier(userId);
    const limits = await getTierLimits(tierInfo.tier);
    const limit = limits[limitKey] ?? 0;

    // Check if unlimited
    if (isUnlimited(limit)) {
      return {
        used: 0,
        limit: -1,
        remaining: -1,
        resets_at: null,
        is_unlimited: true,
        tier: tierInfo.tier
      };
    }

    // Get current usage count
    const usageRef = db.collection('users').doc(userId).collection('daily_usage').doc(dateKey);
    const usageDoc = await retryFirestoreOperation(async () => {
      return await usageRef.get();
    });

    const usageData = usageDoc.exists ? usageDoc.data() : {};
    const used = usageData[usageType] || 0;
    const remaining = Math.max(0, limit - used);

    return {
      used,
      limit,
      remaining,
      resets_at: getNextMidnightIST().toISOString(),
      is_unlimited: false,
      tier: tierInfo.tier
    };
  } catch (error) {
    logger.error('Error getting usage', { userId, usageType, error: error.message });
    throw error;
  }
}

/**
 * Check if user can perform an action (without incrementing)
 *
 * @param {string} userId - User ID
 * @param {string} usageType - Type of usage
 * @returns {Promise<Object>} { allowed, used, limit, remaining, ... }
 */
async function canUse(userId, usageType) {
  const usage = await getUsage(userId, usageType);

  if (usage.is_unlimited) {
    return {
      allowed: true,
      ...usage
    };
  }

  return {
    allowed: usage.remaining > 0,
    ...usage
  };
}

/**
 * Increment usage counter for a user
 * Returns whether the action was allowed
 *
 * @param {string} userId - User ID
 * @param {string} usageType - Type of usage
 * @returns {Promise<Object>} { allowed, used, limit, remaining, ... }
 */
async function incrementUsage(userId, usageType) {
  const dateKey = getTodayDateKey();
  const limitKey = USAGE_TYPE_MAP[usageType] || `${usageType}_daily`;

  try {
    // Get user's tier and limits
    const tierInfo = await getEffectiveTier(userId);
    const limits = await getTierLimits(tierInfo.tier);
    const limit = limits[limitKey] ?? 0;

    // Check if unlimited
    if (isUnlimited(limit)) {
      // Still track usage for analytics, but always allow
      await retryFirestoreOperation(async () => {
        const usageRef = db.collection('users').doc(userId).collection('daily_usage').doc(dateKey);
        await usageRef.set({
          [usageType]: admin.firestore.FieldValue.increment(1),
          last_updated: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      });

      return {
        allowed: true,
        used: 0,
        limit: -1,
        remaining: -1,
        resets_at: null,
        is_unlimited: true,
        tier: tierInfo.tier
      };
    }

    // Check and increment in transaction
    const usageRef = db.collection('users').doc(userId).collection('daily_usage').doc(dateKey);

    let result;
    await retryFirestoreOperation(async () => {
      await db.runTransaction(async (transaction) => {
        const usageDoc = await transaction.get(usageRef);
        const usageData = usageDoc.exists ? usageDoc.data() : {};
        const currentUsed = usageData[usageType] || 0;

        if (currentUsed >= limit) {
          // Limit reached, don't increment
          result = {
            allowed: false,
            used: currentUsed,
            limit,
            remaining: 0,
            resets_at: getNextMidnightIST().toISOString(),
            is_unlimited: false,
            tier: tierInfo.tier
          };
          return;
        }

        // Increment usage
        transaction.set(usageRef, {
          [usageType]: currentUsed + 1,
          last_updated: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        result = {
          allowed: true,
          used: currentUsed + 1,
          limit,
          remaining: limit - currentUsed - 1,
          resets_at: getNextMidnightIST().toISOString(),
          is_unlimited: false,
          tier: tierInfo.tier
        };
      });
    });

    logger.info('Usage incremented', {
      userId,
      usageType,
      tier: tierInfo.tier,
      allowed: result.allowed,
      used: result.used,
      limit: result.limit
    });

    return result;
  } catch (error) {
    logger.error('Error incrementing usage', { userId, usageType, error: error.message });
    throw error;
  }
}

/**
 * Get all usage types for a user for today
 *
 * @param {string} userId - User ID
 * @returns {Promise<Object>} All usage info by type
 */
async function getAllUsage(userId) {
  const [snapSolve, dailyQuiz, aiTutor] = await Promise.all([
    getUsage(userId, 'snap_solve'),
    getUsage(userId, 'daily_quiz'),
    getUsage(userId, 'ai_tutor')
  ]);

  return {
    snap_solve: snapSolve,
    daily_quiz: dailyQuiz,
    ai_tutor: aiTutor
  };
}

/**
 * Reset daily usage (for cron job at midnight IST)
 * Note: We use date-based documents, so old documents auto-expire
 * This function is mainly for cleanup/manual reset
 *
 * @param {string} userId - User ID
 */
async function resetDailyUsage(userId) {
  const dateKey = getTodayDateKey();
  const usageRef = db.collection('users').doc(userId).collection('daily_usage').doc(dateKey);

  await retryFirestoreOperation(async () => {
    await usageRef.delete();
  });

  logger.info('Daily usage reset', { userId, dateKey });
}

module.exports = {
  getUsage,
  canUse,
  incrementUsage,
  getAllUsage,
  resetDailyUsage,
  getTodayDateKey,
  getNextMidnightIST
};
