/**
 * Share Routes
 *
 * API endpoints for tracking share events:
 * - POST /api/share/log - Log a share event for analytics
 */

const express = require('express');
const { body, validationResult } = require('express-validator');
const router = express.Router();
const { db, admin } = require('../config/firebase');
const { authenticateUser } = require('../middleware/auth');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');

// Rate limiter for share logging (prevent abuse)
const rateLimit = require('express-rate-limit');
const shareLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 50, // Max 50 share logs per hour per user
  keyGenerator: (req) => req.userId || req.ip,
  message: (req) => ({
    success: false,
    error: 'Share rate limit exceeded. Please try again later.',
    requestId: req.id || 'unknown',
  }),
  standardHeaders: true,
  legacyHeaders: false,
});

/**
 * POST /api/share/log
 *
 * Log a share event for analytics tracking
 *
 * Body: {
 *   solutionId: string (required) - ID of the solution being shared
 *   shareType: string (required) - 'whatsapp' | 'copy' | 'other'
 *   subject: string (optional) - Subject of the solution
 *   topic: string (optional) - Topic of the solution
 *   timestamp: string (optional) - Client-side timestamp (ISO 8601)
 * }
 *
 * Authentication: Required
 */
router.post(
  '/log',
  authenticateUser,
  shareLimiter,
  [
    body('solutionId').isString().trim().notEmpty()
      .withMessage('solutionId is required'),
    body('shareType').isIn(['whatsapp', 'copy', 'other'])
      .withMessage('shareType must be whatsapp, copy, or other'),
    body('subject').optional().isString().trim(),
    body('topic').optional().isString().trim(),
    body('timestamp').optional().isISO8601(),
  ],
  async (req, res, next) => {
    try {
      // Validate request
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          error: {
            message: 'Validation failed',
            details: errors.array(),
            code: 'VALIDATION_ERROR',
          },
          requestId: req.id,
        });
      }

      const userId = req.userId;
      const { solutionId, shareType, subject, topic, timestamp } = req.body;

      // Prepare share event document
      const shareEvent = {
        solutionId,
        shareType,
        subject: subject || null,
        topic: topic || null,
        clientTimestamp: timestamp ? new Date(timestamp) : null,
        serverTimestamp: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Save to Firestore: share_events/{userId}/items/{auto_id}
      const shareRef = await retryFirestoreOperation(async () => {
        return await db.collection('share_events').doc(userId).collection('items').add(shareEvent);
      });

      // Update user share stats (non-blocking)
      updateUserShareStats(userId, shareType, subject).catch((err) => {
        logger.warn('Failed to update user share stats', {
          userId,
          error: err.message,
        });
      });

      logger.info('Share event logged', {
        requestId: req.id,
        shareId: shareRef.id,
        userId,
        solutionId,
        shareType,
        subject,
      });

      res.status(201).json({
        success: true,
        data: {
          shareId: shareRef.id,
          message: 'Share event logged successfully',
        },
        requestId: req.id,
      });
    } catch (error) {
      logger.error('Share event logging failed', {
        requestId: req.id,
        error: error.message,
      });
      next(error);
    }
  }
);

/**
 * Update user-level share statistics
 * Non-blocking helper function
 */
async function updateUserShareStats(userId, shareType, subject) {
  const userRef = db.collection('users').doc(userId);

  const updates = {
    'share_stats.total_shares': admin.firestore.FieldValue.increment(1),
    [`share_stats.by_type.${shareType}`]: admin.firestore.FieldValue.increment(1),
    'share_stats.last_share_at': admin.firestore.FieldValue.serverTimestamp(),
  };

  if (subject) {
    const subjectKey = subject.toLowerCase().replace(/\s+/g, '_');
    updates[`share_stats.by_subject.${subjectKey}`] =
      admin.firestore.FieldValue.increment(1);
  }

  await userRef.update(updates);
}

module.exports = router;
