/**
 * Trial Service
 *
 * Core trial lifecycle management including:
 * - Trial initialization for new users
 * - Eligibility checking (one per phone)
 * - Trial expiry handling
 * - Trial-to-paid conversion tracking
 * - Trial notifications (email and push)
 *
 * Non-blocking design: Trial failures don't block user signup
 */

const { db, admin } = require('../config/firebase');
const logger = require('../utils/logger');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const {
  areTrialsEnabled,
  getTrialDurationDays,
  getTrialTierId,
  getEligibilityRules
} = require('./trialConfigService');
const { invalidateTierCache } = require('./subscriptionService');

/**
 * Initialize trial for a new user
 * IMPORTANT: Non-blocking - don't throw errors that would fail signup
 *
 * @param {string} userId - User ID
 * @param {string} phoneNumber - User's phone number for eligibility check
 * @returns {Promise<Object>} { success, trial_data, error }
 */
async function initializeTrial(userId, phoneNumber) {
  try {
    // Check if trials are enabled
    const trialsEnabled = await areTrialsEnabled();
    if (!trialsEnabled) {
      logger.info('Trials are disabled, skipping initialization', { userId });
      return { success: false, reason: 'trials_disabled' };
    }

    // Check eligibility
    const eligibility = await checkTrialEligibility(userId, phoneNumber);
    if (!eligibility.isEligible) {
      logger.info('User not eligible for trial', {
        userId,
        reason: eligibility.reason
      });
      return { success: false, reason: eligibility.reason };
    }

    // Get trial configuration
    const durationDays = await getTrialDurationDays();
    const tierId = await getTrialTierId();

    // Calculate trial dates
    const now = admin.firestore.Timestamp.now();
    const endsAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000)
    );

    // Create trial object
    const trialData = {
      tier_id: tierId,
      started_at: now,
      ends_at: endsAt,
      is_active: true,
      notifications_sent: {},
      converted_to_paid: false,
      eligibility_phone: phoneNumber
    };

    // Update user document
    await retryFirestoreOperation(async () => {
      return await db.collection('users').doc(userId).update({
        trial: trialData,
        updated_at: now
      });
    });

    // Invalidate tier cache to force recalculation
    invalidateTierCache(userId);

    // Log analytics event
    await logTrialEvent(userId, 'trial_started', {
      tier_id: tierId,
      duration_days: durationDays,
      ends_at: endsAt.toDate().toISOString()
    });

    logger.info('Trial initialized successfully', {
      userId,
      tier_id: tierId,
      duration_days: durationDays,
      ends_at: endsAt.toDate().toISOString()
    });

    return {
      success: true,
      trial_data: trialData
    };
  } catch (error) {
    logger.error('Error initializing trial', {
      userId,
      error: error.message,
      stack: error.stack
    });

    // Return non-throwing error (don't fail signup)
    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * Check if user is eligible for trial
 *
 * @param {string} userId - User ID
 * @param {string} phoneNumber - User's phone number
 * @returns {Promise<Object>} { isEligible, reason }
 */
async function checkTrialEligibility(userId, phoneNumber) {
  try {
    const rules = await getEligibilityRules();

    // Get user document
    const userDoc = await retryFirestoreOperation(async () => {
      return await db.collection('users').doc(userId).get();
    });

    if (!userDoc.exists) {
      return { isEligible: false, reason: 'user_not_found' };
    }

    const userData = userDoc.data();

    // Check if user already has trial
    if (userData.trial) {
      logger.info('User already has trial', { userId });
      return { isEligible: false, reason: 'already_has_trial' };
    }

    // Check if user has existing subscription
    if (rules.check_existing_subscription && userData.subscription) {
      // Check if subscription is active
      const activeSub = Object.values(userData.subscription).find(sub => {
        if (!sub.end_date) return false;
        const endDate = sub.end_date?.toDate ? sub.end_date.toDate() : new Date(sub.end_date);
        return endDate > new Date();
      });

      if (activeSub) {
        logger.info('User has active subscription, not eligible for trial', { userId });
        return { isEligible: false, reason: 'has_active_subscription' };
      }
    }

    // Check one-per-phone rule
    if (rules.one_per_phone && phoneNumber) {
      const existingTrialQuery = await retryFirestoreOperation(async () => {
        return await db.collection('users')
          .where('trial.eligibility_phone', '==', phoneNumber)
          .limit(1)
          .get();
      });

      if (!existingTrialQuery.empty) {
        const existingUser = existingTrialQuery.docs[0];
        if (existingUser.id !== userId) {
          logger.info('Phone number already used for trial', {
            userId,
            phoneNumber: phoneNumber.substring(0, 5) + '***' // Partial for privacy
          });
          return { isEligible: false, reason: 'phone_already_used' };
        }
      }
    }

    // All checks passed
    return { isEligible: true };
  } catch (error) {
    logger.error('Error checking trial eligibility', {
      userId,
      error: error.message
    });

    // Fail safe: deny eligibility on errors
    return { isEligible: false, reason: 'eligibility_check_failed' };
  }
}

/**
 * Expire trial for a user
 * Called by scheduled job or manually
 *
 * @param {string} userId - User ID
 * @returns {Promise<Object>} { success, error }
 */
async function expireTrial(userId) {
  try {
    const now = admin.firestore.Timestamp.now();

    await retryFirestoreOperation(async () => {
      return await db.collection('users').doc(userId).update({
        'trial.is_active': false,
        'trial.expired_at': now,
        updated_at: now
      });
    });

    // Invalidate tier cache immediately
    invalidateTierCache(userId);

    // Log analytics event
    await logTrialEvent(userId, 'trial_expired', {
      expired_at: now.toDate().toISOString()
    });

    logger.info('Trial expired', { userId });

    return { success: true };
  } catch (error) {
    logger.error('Error expiring trial', {
      userId,
      error: error.message
    });

    return { success: false, error: error.message };
  }
}

/**
 * Async wrapper for trial expiry
 * Used by subscriptionService when detecting expired trials
 *
 * NOTE: This function now RETURNS the promise for proper awaiting
 * Caller should await this to ensure trial expiry completes
 *
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Result of expireTrial
 */
async function expireTrialAsync(userId) {
  try {
    return await expireTrial(userId);
  } catch (error) {
    logger.error('Failed to expire trial', {
      userId,
      error: error.message
    });
    throw error; // Re-throw so caller knows it failed
  }
}

/**
 * Mark trial as converted to paid subscription
 *
 * @param {string} userId - User ID
 * @param {string} subscriptionId - Razorpay subscription ID
 * @returns {Promise<Object>} { success, error }
 */
async function convertTrialToPaid(userId, subscriptionId) {
  try {
    const now = admin.firestore.Timestamp.now();

    await retryFirestoreOperation(async () => {
      return await db.collection('users').doc(userId).update({
        'trial.converted_to_paid': true,
        'trial.converted_at': now,
        'trial.subscription_id': subscriptionId,
        updated_at: now
      });
    });

    // Invalidate tier cache
    invalidateTierCache(userId);

    // Log analytics event
    await logTrialEvent(userId, 'trial_converted', {
      subscription_id: subscriptionId,
      converted_at: now.toDate().toISOString()
    });

    logger.info('Trial converted to paid', {
      userId,
      subscription_id: subscriptionId
    });

    return { success: true };
  } catch (error) {
    logger.error('Error converting trial', {
      userId,
      error: error.message
    });

    return { success: false, error: error.message };
  }
}

/**
 * Send trial notification to user
 *
 * @param {string} userId - User ID
 * @param {Object} userData - User data from Firestore
 * @param {number} daysRemaining - Days remaining in trial
 * @param {Array<string>} channels - Notification channels (email, push)
 * @returns {Promise<Object>} { success, channels_sent, error }
 */
async function sendTrialNotification(userId, userData, daysRemaining, channels = []) {
  try {
    // Check if notification already sent for this milestone
    const notificationKey = `day_${daysRemaining}`;
    if (userData.trial?.notifications_sent?.[notificationKey]) {
      logger.info('Notification already sent for milestone', {
        userId,
        days_remaining: daysRemaining
      });
      return { success: false, reason: 'already_sent' };
    }

    const channelsSent = [];
    const errors = [];

    // Send email notification
    if (channels.includes('email') && userData.email) {
      try {
        const emailResult = await sendTrialEmail(userId, userData, daysRemaining);
        if (emailResult.success) {
          channelsSent.push('email');
        } else {
          errors.push({ channel: 'email', error: emailResult.error });
        }
      } catch (error) {
        logger.error('Error sending trial email', {
          userId,
          error: error.message
        });
        errors.push({ channel: 'email', error: error.message });
      }
    }

    // Send push notification
    if (channels.includes('push') && userData.fcm_token) {
      try {
        const pushResult = await sendTrialPush(userId, userData, daysRemaining);
        if (pushResult.success) {
          channelsSent.push('push');
        } else {
          errors.push({ channel: 'push', error: pushResult.error });
        }
      } catch (error) {
        logger.error('Error sending trial push', {
          userId,
          error: error.message
        });
        errors.push({ channel: 'push', error: error.message });
      }
    }

    // Update notifications_sent in user document
    if (channelsSent.length > 0) {
      const now = admin.firestore.Timestamp.now();
      await retryFirestoreOperation(async () => {
        return await db.collection('users').doc(userId).update({
          [`trial.notifications_sent.${notificationKey}`]: {
            sent_at: now,
            channels: channelsSent
          },
          updated_at: now
        });
      });

      // Log analytics event
      await logTrialEvent(userId, 'trial_notification_sent', {
        days_remaining: daysRemaining,
        channels: channelsSent
      });
    }

    logger.info('Trial notification sent', {
      userId,
      days_remaining: daysRemaining,
      channels_sent: channelsSent,
      errors: errors.length > 0 ? errors : undefined
    });

    return {
      success: channelsSent.length > 0,
      channels_sent: channelsSent,
      errors: errors.length > 0 ? errors : undefined
    };
  } catch (error) {
    logger.error('Error sending trial notification', {
      userId,
      error: error.message
    });

    return { success: false, error: error.message };
  }
}

/**
 * Send trial email
 */
async function sendTrialEmail(userId, userData, daysRemaining) {
  const { sendTrialEmail: sendEmail } = require('./studentEmailService');
  return await sendEmail(userId, userData, daysRemaining);
}

/**
 * Send trial push notification
 */
async function sendTrialPush(userId, userData, daysRemaining) {
  if (!userData.fcm_token) {
    return { success: false, reason: 'no_fcm_token' };
  }

  try {
    const messages = {
      23: {
        title: '🎯 Week 1 Complete - Keep Going!',
        body: "You're doing great! 23 days left in your Pro trial."
      },
      5: {
        title: '⏰ Only 5 Days Left in Your Pro Trial',
        body: "Don't lose your Pro features! Upgrade for just ₹199/month."
      },
      2: {
        title: '⚠️ Trial Ending in 2 Days - Act Now!',
        body: 'Last chance to keep your 10 daily snaps and offline access.'
      },
      0: {
        title: 'Your Trial Has Ended - Special Offer Inside 🎁',
        body: 'Get 20% off with code TRIAL2PRO (valid for 7 days).'
      }
    };

    const message = messages[daysRemaining] || messages[0];

    await admin.messaging().send({
      token: userData.fcm_token,
      notification: {
        title: message.title,
        body: message.body
      },
      data: {
        type: 'trial_notification',
        days_remaining: daysRemaining.toString()
      }
    });

    logger.info('Trial push notification sent', {
      userId,
      days_remaining: daysRemaining
    });

    return { success: true };
  } catch (error) {
    logger.error('Error sending trial push', {
      userId,
      error: error.message
    });

    return { success: false, error: error.message };
  }
}

/**
 * Log trial event to analytics
 *
 * @param {string} userId - User ID
 * @param {string} eventType - Event type (trial_started, trial_expired, etc.)
 * @param {Object} data - Event data
 */
async function logTrialEvent(userId, eventType, data = {}) {
  try {
    const now = admin.firestore.Timestamp.now();

    await db.collection('trial_events').add({
      user_id: userId,
      event_type: eventType,
      timestamp: now,
      data
    });

    logger.info('Trial event logged', {
      userId,
      event_type: eventType
    });
  } catch (error) {
    logger.error('Error logging trial event', {
      userId,
      event_type: eventType,
      error: error.message
    });
    // Don't throw - logging failures shouldn't break trial operations
  }
}

/**
 * Get trial status for a user
 *
 * @param {string} userId - User ID
 * @returns {Promise<Object|null>} Trial status or null
 */
async function getTrialStatus(userId) {
  try {
    const userDoc = await retryFirestoreOperation(async () => {
      return await db.collection('users').doc(userId).get();
    });

    if (!userDoc.exists || !userDoc.data().trial) {
      return null;
    }

    const trial = userDoc.data().trial;
    const now = new Date();
    const endsAt = trial.ends_at?.toDate ? trial.ends_at.toDate() : new Date(trial.ends_at);
    const daysRemaining = Math.ceil((endsAt - now) / (1000 * 60 * 60 * 24));

    return {
      tier_id: trial.tier_id,
      started_at: trial.started_at,
      ends_at: trial.ends_at,
      is_active: trial.is_active,
      days_remaining: daysRemaining,
      converted_to_paid: trial.converted_to_paid,
      notifications_sent: trial.notifications_sent || {}
    };
  } catch (error) {
    logger.error('Error getting trial status', {
      userId,
      error: error.message
    });

    return null;
  }
}

module.exports = {
  initializeTrial,
  checkTrialEligibility,
  expireTrial,
  expireTrialAsync,
  convertTrialToPaid,
  sendTrialNotification,
  getTrialStatus,
  logTrialEvent
};
