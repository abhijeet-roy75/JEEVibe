/**
 * Trial Processing Service
 *
 * Daily scheduled job to process all active trials:
 * - Check for expired trials and downgrade users
 * - Send notifications at configured milestones (day 23, 5, 2, 0)
 * - Batch processing with error handling
 *
 * Run daily at 2:00 AM IST (20:30 UTC) via cron-job.org
 */

const { db, admin } = require('../config/firebase');
const logger = require('../utils/logger');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const { getNotificationSchedule } = require('./trialConfigService');
const { expireTrial, sendTrialNotification } = require('./trialService');

// Batch processing configuration
const BATCH_SIZE = 50; // Process 50 users at a time
const MAX_USERS_PER_RUN = 1000; // Safety limit
const PROCESSING_TIMEOUT_MS = 5 * 60 * 1000; // 5 minutes

/**
 * Process all active trials
 * Called by daily cron job
 *
 * @returns {Promise<Object>} Processing results
 */
async function processAllTrials() {
  const startTime = Date.now();
  const results = {
    processed: 0,
    notifications_sent: 0,
    trials_expired: 0,
    errors: [],
    skipped: 0,
    duration_ms: 0
  };

  try {
    logger.info('Starting trial processing job');

    // Get notification schedule
    const notificationSchedule = await getNotificationSchedule();
    const notificationMilestones = notificationSchedule.map(n => n.days_remaining);

    // Query all users with active trials
    const usersSnapshot = await retryFirestoreOperation(async () => {
      return await db.collection('users')
        .where('trial.is_active', '==', true)
        .limit(MAX_USERS_PER_RUN)
        .get();
    });

    if (usersSnapshot.empty) {
      logger.info('No active trials to process');
      results.duration_ms = Date.now() - startTime;
      return results;
    }

    logger.info(`Found ${usersSnapshot.size} active trials to process`);

    // Process users in batches
    const users = usersSnapshot.docs;
    const batches = [];
    for (let i = 0; i < users.length; i += BATCH_SIZE) {
      batches.push(users.slice(i, i + BATCH_SIZE));
    }

    for (const batch of batches) {
      // Check timeout
      if (Date.now() - startTime > PROCESSING_TIMEOUT_MS) {
        logger.warn('Processing timeout reached, stopping', {
          processed: results.processed,
          remaining: users.length - results.processed
        });
        break;
      }

      // Process batch in parallel
      await Promise.all(
        batch.map(userDoc =>
          processUserTrial(userDoc, notificationSchedule, notificationMilestones, results)
        )
      );
    }

    results.duration_ms = Date.now() - startTime;

    logger.info('Trial processing job completed', {
      processed: results.processed,
      notifications_sent: results.notifications_sent,
      trials_expired: results.trials_expired,
      errors: results.errors.length,
      duration_ms: results.duration_ms
    });

    return results;
  } catch (error) {
    logger.error('Error in trial processing job', {
      error: error.message,
      stack: error.stack
    });

    results.duration_ms = Date.now() - startTime;
    results.errors.push({
      type: 'job_error',
      error: error.message
    });

    return results;
  }
}

/**
 * Process a single user's trial
 *
 * @param {Object} userDoc - Firestore user document
 * @param {Array} notificationSchedule - Notification schedule from config
 * @param {Array<number>} notificationMilestones - Array of milestone days
 * @param {Object} results - Results object to update
 */
async function processUserTrial(userDoc, notificationSchedule, notificationMilestones, results) {
  const userId = userDoc.id;
  const userData = userDoc.data();

  try {
    results.processed++;

    // Validate trial data
    if (!userData.trial || !userData.trial.ends_at) {
      logger.warn('Invalid trial data', { userId });
      results.skipped++;
      return;
    }

    // Calculate days remaining
    const now = new Date();
    const endsAt = userData.trial.ends_at?.toDate
      ? userData.trial.ends_at.toDate()
      : new Date(userData.trial.ends_at);

    const daysRemaining = Math.ceil((endsAt - now) / (1000 * 60 * 60 * 24));

    logger.debug('Processing user trial', {
      userId,
      days_remaining: daysRemaining,
      ends_at: endsAt.toISOString()
    });

    // Trial has expired
    if (daysRemaining <= 0) {
      logger.info('Trial expired, expiring user', {
        userId,
        expired_days_ago: Math.abs(daysRemaining)
      });

      const expireResult = await expireTrial(userId);
      if (expireResult.success) {
        results.trials_expired++;
      } else {
        results.errors.push({
          user_id: userId,
          type: 'expire_failed',
          error: expireResult.error
        });
      }

      // Send expiry notification (day 0)
      if (notificationMilestones.includes(0)) {
        await sendTrialNotificationIfNeeded(
          userId,
          userData,
          0,
          notificationSchedule,
          results
        );
      }

      return;
    }

    // Check if we should send notification for this milestone
    if (notificationMilestones.includes(daysRemaining)) {
      await sendTrialNotificationIfNeeded(
        userId,
        userData,
        daysRemaining,
        notificationSchedule,
        results
      );
    }
  } catch (error) {
    logger.error('Error processing user trial', {
      userId,
      error: error.message,
      stack: error.stack
    });

    results.errors.push({
      user_id: userId,
      type: 'processing_error',
      error: error.message
    });
  }
}

/**
 * Send trial notification if not already sent
 *
 * @param {string} userId - User ID
 * @param {Object} userData - User data
 * @param {number} daysRemaining - Days remaining in trial
 * @param {Array} notificationSchedule - Notification schedule
 * @param {Object} results - Results object to update
 */
async function sendTrialNotificationIfNeeded(
  userId,
  userData,
  daysRemaining,
  notificationSchedule,
  results
) {
  try {
    // Find notification config for this milestone
    const notificationConfig = notificationSchedule.find(
      n => n.days_remaining === daysRemaining
    );

    if (!notificationConfig) {
      logger.warn('No notification config found for milestone', {
        userId,
        days_remaining: daysRemaining
      });
      return;
    }

    // Check if already sent
    const notificationKey = `day_${daysRemaining}`;
    if (userData.trial?.notifications_sent?.[notificationKey]) {
      logger.debug('Notification already sent for milestone', {
        userId,
        days_remaining: daysRemaining
      });
      return;
    }

    // Send notification
    logger.info('Sending trial notification', {
      userId,
      days_remaining: daysRemaining,
      channels: notificationConfig.channels
    });

    const notificationResult = await sendTrialNotification(
      userId,
      userData,
      daysRemaining,
      notificationConfig.channels
    );

    if (notificationResult.success) {
      results.notifications_sent++;
      logger.info('Trial notification sent successfully', {
        userId,
        days_remaining: daysRemaining,
        channels_sent: notificationResult.channels_sent
      });
    } else {
      logger.warn('Failed to send trial notification', {
        userId,
        days_remaining: daysRemaining,
        reason: notificationResult.reason,
        errors: notificationResult.errors
      });

      results.errors.push({
        user_id: userId,
        type: 'notification_failed',
        days_remaining: daysRemaining,
        error: notificationResult.error || notificationResult.reason
      });
    }
  } catch (error) {
    logger.error('Error sending trial notification', {
      userId,
      days_remaining: daysRemaining,
      error: error.message
    });

    results.errors.push({
      user_id: userId,
      type: 'notification_error',
      days_remaining: daysRemaining,
      error: error.message
    });
  }
}

/**
 * Process trials for specific user IDs (for testing/debugging)
 *
 * @param {Array<string>} userIds - Array of user IDs
 * @returns {Promise<Object>} Processing results
 */
async function processSpecificTrials(userIds) {
  const results = {
    processed: 0,
    notifications_sent: 0,
    trials_expired: 0,
    errors: [],
    skipped: 0,
    duration_ms: 0
  };

  const startTime = Date.now();

  try {
    logger.info('Processing specific trials', { user_ids: userIds });

    const notificationSchedule = await getNotificationSchedule();
    const notificationMilestones = notificationSchedule.map(n => n.days_remaining);

    for (const userId of userIds) {
      try {
        const userDoc = await db.collection('users').doc(userId).get();

        if (!userDoc.exists) {
          logger.warn('User not found', { userId });
          results.skipped++;
          continue;
        }

        if (!userDoc.data().trial?.is_active) {
          logger.warn('User does not have active trial', { userId });
          results.skipped++;
          continue;
        }

        await processUserTrial(userDoc, notificationSchedule, notificationMilestones, results);
      } catch (error) {
        logger.error('Error processing specific user trial', {
          userId,
          error: error.message
        });

        results.errors.push({
          user_id: userId,
          type: 'processing_error',
          error: error.message
        });
      }
    }

    results.duration_ms = Date.now() - startTime;

    logger.info('Specific trials processing completed', results);

    return results;
  } catch (error) {
    logger.error('Error processing specific trials', {
      error: error.message
    });

    results.duration_ms = Date.now() - startTime;
    results.errors.push({
      type: 'job_error',
      error: error.message
    });

    return results;
  }
}

/**
 * Get summary of upcoming trial expirations
 * Useful for monitoring and admin dashboards
 *
 * @param {number} daysAhead - Number of days to look ahead
 * @returns {Promise<Object>} Summary statistics
 */
async function getTrialExpirationSummary(daysAhead = 7) {
  try {
    const now = new Date();
    const futureDate = new Date(now.getTime() + daysAhead * 24 * 60 * 60 * 1000);

    const usersSnapshot = await retryFirestoreOperation(async () => {
      return await db.collection('users')
        .where('trial.is_active', '==', true)
        .where('trial.ends_at', '<=', admin.firestore.Timestamp.fromDate(futureDate))
        .get();
    });

    const summary = {
      total_active_trials: 0,
      expiring_soon: usersSnapshot.size,
      by_days_remaining: {}
    };

    // Count all active trials
    const allActiveSnapshot = await retryFirestoreOperation(async () => {
      return await db.collection('users')
        .where('trial.is_active', '==', true)
        .get();
    });

    summary.total_active_trials = allActiveSnapshot.size;

    // Group by days remaining
    usersSnapshot.docs.forEach(doc => {
      const userData = doc.data();
      const endsAt = userData.trial.ends_at?.toDate
        ? userData.trial.ends_at.toDate()
        : new Date(userData.trial.ends_at);

      const daysRemaining = Math.ceil((endsAt - now) / (1000 * 60 * 60 * 24));

      if (!summary.by_days_remaining[daysRemaining]) {
        summary.by_days_remaining[daysRemaining] = 0;
      }
      summary.by_days_remaining[daysRemaining]++;
    });

    logger.info('Trial expiration summary generated', summary);

    return summary;
  } catch (error) {
    logger.error('Error getting trial expiration summary', {
      error: error.message
    });

    return {
      error: error.message,
      total_active_trials: 0,
      expiring_soon: 0,
      by_days_remaining: {}
    };
  }
}

module.exports = {
  processAllTrials,
  processSpecificTrials,
  getTrialExpirationSummary
};
