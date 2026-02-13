/**
 * Email Idempotency Utility
 *
 * Prevents duplicate email sending on retries.
 *
 * Created: 2026-02-13
 * Reason: Email sending should be idempotent to prevent duplicates on API retries
 *
 * Usage:
 *   const { checkEmailSent, markEmailSent } = require('../utils/emailIdempotency');
 *
 *   async function sendWelcomeEmail(userId, email) {
 *     const idempotencyKey = `welcome:${userId}`;
 *
 *     if (await checkEmailSent(idempotencyKey)) {
 *       return { success: true, alreadySent: true };
 *     }
 *
 *     await sendEmail({ to: email, ... });
 *     await markEmailSent(idempotencyKey);
 *
 *     return { success: true, alreadySent: false };
 *   }
 */

const cache = require('./cache');
const logger = require('./logger');

// Email sent tracking TTL (7 days)
// We keep track of sent emails for 7 days to handle retries
const EMAIL_SENT_TTL = 7 * 24 * 60 * 60; // 7 days in seconds

/**
 * Check if email was already sent
 *
 * @param {string} idempotencyKey - Unique key for this email (e.g., "welcome:userId", "trial-day-5:userId")
 * @returns {Promise<boolean>} True if email was already sent, false otherwise
 */
async function checkEmailSent(idempotencyKey) {
  try {
    const cacheKey = `email:sent:${idempotencyKey}`;
    const sentAt = cache.get(cacheKey);

    if (sentAt) {
      logger.info('Email idempotency: Already sent', {
        idempotencyKey,
        sentAt
      });
      return true;
    }

    return false;
  } catch (error) {
    logger.error('Error checking email idempotency', {
      idempotencyKey,
      error: error.message
    });

    // Fail-safe: If we can't check, assume it wasn't sent
    // (Better to send duplicate than to not send at all)
    return false;
  }
}

/**
 * Mark email as sent
 *
 * @param {string} idempotencyKey - Unique key for this email
 * @param {number} ttl - Optional TTL in seconds (default: 7 days)
 * @returns {Promise<void>}
 */
async function markEmailSent(idempotencyKey, ttl = EMAIL_SENT_TTL) {
  try {
    const cacheKey = `email:sent:${idempotencyKey}`;
    const sentAt = new Date().toISOString();

    cache.set(cacheKey, sentAt, ttl);

    logger.info('Email idempotency: Marked as sent', {
      idempotencyKey,
      sentAt,
      ttl
    });
  } catch (error) {
    logger.error('Error marking email as sent', {
      idempotencyKey,
      error: error.message
    });

    // Don't throw - marking failure shouldn't block email sending
  }
}

/**
 * Clear email sent status (for testing/admin operations)
 *
 * @param {string} idempotencyKey - Unique key for this email
 * @returns {Promise<void>}
 */
async function clearEmailSent(idempotencyKey) {
  try {
    const cacheKey = `email:sent:${idempotencyKey}`;
    cache.del(cacheKey);

    logger.info('Email idempotency: Cleared', { idempotencyKey });
  } catch (error) {
    logger.error('Error clearing email sent status', {
      idempotencyKey,
      error: error.message
    });
  }
}

/**
 * Generate idempotency key for common email types
 *
 * @param {string} emailType - Email type (welcome, trial_day_5, daily_progress, etc.)
 * @param {string} userId - User ID
 * @param {string} [suffix] - Optional suffix (e.g., date for daily emails)
 * @returns {string} Idempotency key
 */
function generateIdempotencyKey(emailType, userId, suffix = null) {
  if (suffix) {
    return `${emailType}:${userId}:${suffix}`;
  }
  return `${emailType}:${userId}`;
}

module.exports = {
  checkEmailSent,
  markEmailSent,
  clearEmailSent,
  generateIdempotencyKey,
  EMAIL_SENT_TTL
};
