/**
 * Feedback Routes
 *
 * API endpoints for user feedback:
 * - POST /api/feedback - Submit user feedback
 * - GET /api/feedback/email-test - Test email configuration (requires auth)
 * - GET /api/feedback/email-diagnostics - Get email config status (requires auth)
 */

const express = require('express');
const { body, validationResult } = require('express-validator');
const router = express.Router();
const { db, admin } = require('../config/firebase');
const { authenticateUser } = require('../middleware/auth');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { ApiError } = require('../middleware/errorHandler');
const { sendFeedbackEmail, getEmailDiagnostics, testEmailConnection } = require('../services/emailService');

// Feature flag check
const isFeedbackEnabled = () => {
  const enabled = process.env.ENABLE_FEEDBACK_FEATURE === 'true' || process.env.ENABLE_FEEDBACK_FEATURE === '1';
  logger.debug('Feedback feature flag check', {
    envValue: process.env.ENABLE_FEEDBACK_FEATURE,
    enabled,
  });
  return enabled;
};

/**
 * GET /api/feedback/email-test
 *
 * Test email configuration (for debugging)
 * Returns diagnostic information and tests SMTP connection
 */
router.get('/email-test', authenticateUser, async (req, res) => {
  logger.info('=== EMAIL TEST ENDPOINT CALLED ===', {
    requestId: req.id,
    userId: req.userId,
  });

  try {
    // Test connection
    const testResult = await testEmailConnection();

    logger.info('Email test completed', {
      requestId: req.id,
      overallStatus: testResult.overallStatus,
    });

    res.json({
      success: testResult.overallStatus === 'PASSED',
      data: testResult,
      requestId: req.id,
    });
  } catch (error) {
    logger.error('Email test failed', {
      requestId: req.id,
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({
      success: false,
      error: {
        message: error.message,
        code: 'EMAIL_TEST_FAILED',
      },
      requestId: req.id,
    });
  }
});

/**
 * GET /api/feedback/email-diagnostics
 *
 * Get email configuration diagnostics (for debugging)
 * Does not test connection, just returns config status
 */
router.get('/email-diagnostics', authenticateUser, async (req, res) => {
  logger.info('=== EMAIL DIAGNOSTICS ENDPOINT CALLED ===', {
    requestId: req.id,
    userId: req.userId,
  });

  const diagnostics = getEmailDiagnostics();

  logger.info('Email diagnostics retrieved', {
    requestId: req.id,
    nodemailerInstalled: diagnostics.nodemailerInstalled,
    smtpUserConfigured: diagnostics.smtpUserConfigured,
    smtpPasswordConfigured: diagnostics.smtpPasswordConfigured,
    feedbackFeatureEnabled: diagnostics.feedbackFeatureEnabled,
  });

  res.json({
    success: true,
    data: diagnostics,
    requestId: req.id,
  });
});

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
    logger.info('=== FEEDBACK SUBMISSION STARTED ===', {
      requestId: req.id,
      userId: req.userId,
    });

    try {
      // Check feature flag
      if (!isFeedbackEnabled()) {
        logger.warn('Feedback feature is disabled', {
          requestId: req.id,
          envValue: process.env.ENABLE_FEEDBACK_FEATURE,
        });
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
        logger.warn('Feedback validation failed', {
          requestId: req.id,
          errors: errors.array(),
        });
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

      logger.info('Feedback validated, saving to Firestore...', {
        requestId: req.id,
        userId,
        rating,
        descriptionLength: description.length,
      });

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

      logger.info('Feedback saved to Firestore successfully', {
        requestId: req.id,
        userId,
        feedbackId: feedbackRef.id,
        rating,
      });

      // Check email configuration and attempt to send
      const smtpUser = process.env.SMTP_USER;
      const smtpPass = process.env.SMTP_PASSWORD;

      logger.info('Checking email configuration...', {
        requestId: req.id,
        feedbackId: feedbackRef.id,
        smtpUserSet: !!smtpUser,
        smtpPasswordSet: !!smtpPass,
        smtpUser: smtpUser ? `${smtpUser.substring(0, 3)}***` : '(not set)',
      });

      if (smtpUser && smtpPass) {
        logger.info('SMTP configured, initiating email send...', {
          requestId: req.id,
          feedbackId: feedbackRef.id,
        });

        // Send email (async, don't block the response)
        sendFeedbackEmail({
          feedbackId: feedbackRef.id,
          userId,
          rating,
          description,
          context,
        })
          .then((result) => {
            logger.info('Feedback email send completed', {
              requestId: req.id,
              feedbackId: feedbackRef.id,
              result,
            });
          })
          .catch((error) => {
            logger.error('=== FEEDBACK EMAIL SEND FAILED ===', {
              requestId: req.id,
              userId,
              feedbackId: feedbackRef.id,
              error: error.message,
              errorCode: error.code,
              stack: error.stack,
            });
            // Don't fail the request if email fails
          });
      } else {
        logger.warn('=== EMAIL NOTIFICATION SKIPPED - SMTP NOT CONFIGURED ===', {
          requestId: req.id,
          userId,
          feedbackId: feedbackRef.id,
          smtpUserSet: !!smtpUser,
          smtpPasswordSet: !!smtpPass,
          hint: 'Set SMTP_USER and SMTP_PASSWORD environment variables to enable email notifications',
        });
      }

      logger.info('=== FEEDBACK SUBMISSION COMPLETED ===', {
        requestId: req.id,
        feedbackId: feedbackRef.id,
        userId,
      });

      res.status(201).json({
        success: true,
        data: {
          feedbackId: feedbackRef.id,
          message: 'Feedback submitted successfully',
          emailEnabled: !!(smtpUser && smtpPass),
        },
        requestId: req.id,
      });
    } catch (error) {
      logger.error('=== FEEDBACK SUBMISSION FAILED ===', {
        requestId: req.id,
        error: error.message,
        stack: error.stack,
      });
      next(error);
    }
  }
);

module.exports = router;
