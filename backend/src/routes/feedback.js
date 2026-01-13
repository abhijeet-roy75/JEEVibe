/**
 * Feedback Routes
 * 
 * API endpoints for user feedback:
 * - POST /api/feedback - Submit user feedback
 */

const express = require('express');
const { body, validationResult } = require('express-validator');
const router = express.Router();
const { db, admin } = require('../config/firebase');
const { authenticateUser } = require('../middleware/auth');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { ApiError } = require('../middleware/errorHandler');
const { sendFeedbackEmail } = require('../services/emailService');

// Feature flag check
const isFeedbackEnabled = () => {
  return process.env.ENABLE_FEEDBACK_FEATURE === 'true' || process.env.ENABLE_FEEDBACK_FEATURE === '1';
};

/**
 * POST /api/feedback
 * 
 * Submit user feedback
 * 
 * Body: {
 *   rating: number (1-5),
 *   description: string,
 *   context: {
 *     currentScreen: string,
 *     userId: string,
 *     userProfile: object,
 *     appVersion: string,
 *     deviceModel: string,
 *     osVersion: string,
 *     timestamp: string,
 *     recentActivity: array
 *   }
 * }
 * 
 * Authentication: Required (Bearer token in Authorization header)
 */
router.post(
  '/',
  authenticateUser,
  [
    body('rating').isInt({ min: 1, max: 5 }).withMessage('Rating must be between 1 and 5'),
    body('description').isString().trim().notEmpty().withMessage('Description is required'),
    body('context').isObject().withMessage('Context is required'),
  ],
  async (req, res, next) => {
    try {
      // Check feature flag
      if (!isFeedbackEnabled()) {
        return res.status(503).json({
          success: false,
          error: {
            message: 'Feedback feature is currently disabled',
            code: 'FEATURE_DISABLED',
          },
          requestId: req.id,
        });
      }

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
      const { rating, description, context } = req.body;

      // Prepare feedback document
      const feedbackData = {
        userId,
        rating,
        description: description.trim(),
        context: {
          ...context,
          submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        status: 'new',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      const feedbackRef = await retryFirestoreOperation(async () => {
        return await db.collection('feedback').add(feedbackData);
      });

      logger.info('Feedback submitted', {
        requestId: req.id,
        userId,
        feedbackId: feedbackRef.id,
        rating,
      });

      // Send email notification (async, don't wait for it)
      sendFeedbackEmail({
        feedbackId: feedbackRef.id,
        userId,
        rating,
        description,
        context,
      }).catch((error) => {
        logger.error('Failed to send feedback email', {
          requestId: req.id,
          userId,
          feedbackId: feedbackRef.id,
          error: error.message,
        });
        // Don't fail the request if email fails
      });

      res.status(201).json({
        success: true,
        data: {
          feedbackId: feedbackRef.id,
          message: 'Feedback submitted successfully',
        },
        requestId: req.id,
      });
    } catch (error) {
      next(error);
    }
  }
);

module.exports = router;
