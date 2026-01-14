/**
 * Email Service (Placeholder)
 *
 * Email notifications are currently disabled.
 * This file is kept for potential future use.
 */

const logger = require('../utils/logger');

/**
 * Placeholder for sending feedback email
 * Currently disabled - just logs and returns
 */
async function sendFeedbackEmail(feedbackData) {
  logger.debug('Email notifications disabled - feedback saved to Firestore only', {
    feedbackId: feedbackData.feedbackId,
  });
  return { sent: false, reason: 'Email notifications disabled' };
}

module.exports = {
  sendFeedbackEmail,
};
