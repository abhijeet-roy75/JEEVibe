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
    body('description').optional().isString().trim(),
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
        description: description ? description.trim() : '',
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
        feedbackId: feedbackRef.id,
        userId,
        rating,
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
      logger.error('Feedback submission failed', {
        requestId: req.id,
        error: error.message,
      });
      next(error);
    }
  }
);

/**
 * GET /api/feedback
 *
 * Get all feedback items (admin/debug endpoint)
 *
 * Query params:
 *   - limit: number (default 50, max 200)
 *   - status: string (optional, filter by status: 'new', 'reviewed', 'resolved')
 *   - rating: number (optional, filter by rating 1-5)
 *
 * Authentication: Required
 */
router.get('/', authenticateUser, async (req, res, next) => {
  try {
    const { limit = 50, status, rating } = req.query;
    const limitNum = Math.min(parseInt(limit) || 50, 200);

    let query = db.collection('feedback').orderBy('createdAt', 'desc');

    if (status) {
      query = query.where('status', '==', status);
    }

    if (rating) {
      query = query.where('rating', '==', parseInt(rating));
    }

    query = query.limit(limitNum);

    const snapshot = await retryFirestoreOperation(async () => {
      return await query.get();
    });

    const feedbackItems = [];
    snapshot.forEach((doc) => {
      const data = doc.data();
      feedbackItems.push({
        id: doc.id,
        ...data,
        createdAt: data.createdAt?.toDate?.()?.toISOString() || null,
        context: {
          ...data.context,
          submittedAt: data.context?.submittedAt?.toDate?.()?.toISOString() || null,
        },
      });
    });

    logger.info('Feedback items retrieved', {
      requestId: req.id,
      count: feedbackItems.length,
      filters: { status, rating },
    });

    res.json({
      success: true,
      data: {
        feedback: feedbackItems,
        count: feedbackItems.length,
      },
      requestId: req.id,
    });
  } catch (error) {
    logger.error('Failed to retrieve feedback', {
      requestId: req.id,
      error: error.message,
    });
    next(error);
  }
});

module.exports = router;
