/**
 * JEEVibe - AI Tutor (Priya Ma'am) API Routes
 * Handles chat conversations with the AI tutor
 */

const express = require('express');
const { body, validationResult } = require('express-validator');
const { authenticateUser } = require('../middleware/auth');
const { requireFeature, checkUsageLimit } = require('../middleware/featureGate');
const { ApiError } = require('../middleware/errorHandler');
const logger = require('../utils/logger');
const {
  sendMessage,
  injectContext,
  getConversation,
  resetConversation,
  generateWelcomeMessage
} = require('../services/aiTutorService');
const { hasConversation } = require('../services/tutorConversationService');
const {
  moderateMessage,
  analyzeMessage,
  SAFE_RESPONSES
} = require('../services/contentModerationService');

const router = express.Router();

// Error codes for client handling
const ERROR_CODES = {
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  MISSING_CONTEXT_ID: 'MISSING_CONTEXT_ID',
  AI_SERVICE_ERROR: 'AI_SERVICE_ERROR',
  AI_SERVICE_BUSY: 'AI_SERVICE_BUSY',
  AI_SERVICE_UNAVAILABLE: 'AI_SERVICE_UNAVAILABLE',
  CONTEXT_NOT_FOUND: 'CONTEXT_NOT_FOUND',
  FIRESTORE_ERROR: 'FIRESTORE_ERROR',
  INTERNAL_ERROR: 'INTERNAL_ERROR'
};

/**
 * Classify and handle errors appropriately
 * Maps different error types to user-friendly ApiError responses
 */
function classifyAndHandleError(error, next) {
  // OpenAI API errors
  if (error.status) {
    if (error.status === 401) {
      return next(new ApiError(500, 'AI Service Configuration Error', ERROR_CODES.AI_SERVICE_ERROR));
    }
    if (error.status === 429) {
      return next(new ApiError(429, 'AI service is busy, please try again in a moment', ERROR_CODES.AI_SERVICE_BUSY));
    }
    if (error.status >= 500) {
      return next(new ApiError(502, 'AI service temporarily unavailable', ERROR_CODES.AI_SERVICE_UNAVAILABLE));
    }
    return next(new ApiError(error.status, error.message, ERROR_CODES.AI_SERVICE_ERROR));
  }

  // Firestore errors
  if (error.code && (error.code.startsWith('firestore/') || error.code === 'UNAVAILABLE' || error.code === 'DEADLINE_EXCEEDED')) {
    return next(new ApiError(503, 'Database temporarily unavailable, please try again', ERROR_CODES.FIRESTORE_ERROR));
  }

  // Context not found errors
  if (error.message && error.message.includes('not found for context')) {
    return next(new ApiError(404, 'The requested content was not found', ERROR_CODES.CONTEXT_NOT_FOUND));
  }

  // Validation errors from our services
  if (error.message && (error.message.includes('invalid characters') || error.message.includes('required'))) {
    return next(new ApiError(400, error.message, ERROR_CODES.VALIDATION_ERROR));
  }

  // Default: don't expose internal error details
  logger.error('Unclassified error in AI Tutor route', { error: error.message, stack: error.stack });
  return next(new ApiError(500, 'An unexpected error occurred. Please try again.', ERROR_CODES.INTERNAL_ERROR));
}

// ============================================================================
// GET /api/ai-tutor/conversation
// ============================================================================

/**
 * GET /api/ai-tutor/conversation
 *
 * Get conversation history with messages
 * Returns last 50 messages by default
 *
 * Authentication: Required
 * Tier: Ultra only (ai_tutor_enabled)
 *
 * Query params:
 * - limit: Max messages to return (default: 50, max: 100)
 *
 * Response:
 * {
 *   success: true,
 *   data: {
 *     messages: [{id, type, content, timestamp, contextType?, contextTitle?}],
 *     messageCount: number,
 *     currentContext: {type, id, title} | null,
 *     quickActions: [{id, label, prompt}]
 *   }
 * }
 */
router.get('/conversation',
  authenticateUser,
  requireFeature('ai_tutor_enabled'),
  async (req, res, next) => {
    try {
      const userId = req.userId;
      const limit = Math.min(parseInt(req.query.limit) || 50, 100);

      logger.info('Getting AI Tutor conversation', { userId, limit, requestId: req.requestId });

      // Check if user has any conversation history
      const hasHistory = await hasConversation(userId);

      if (!hasHistory) {
        // Generate welcome message for new users
        const welcome = await generateWelcomeMessage(userId);

        return res.json({
          success: true,
          data: {
            messages: [{
              id: 'welcome',
              type: 'assistant',
              content: welcome.message,
              timestamp: new Date().toISOString()
            }],
            messageCount: 1,
            currentContext: null,
            quickActions: welcome.quickActions,
            isNewConversation: true
          },
          requestId: req.requestId
        });
      }

      const conversation = await getConversation(userId, limit);

      // Format messages for response
      const messages = conversation.messages.map(msg => ({
        id: msg.id,
        type: msg.type,
        content: msg.content,
        timestamp: msg.timestamp?.toISOString?.() || msg.timestamp,
        // Context marker fields
        contextType: msg.contextType,
        contextId: msg.contextId,
        contextTitle: msg.contextTitle
      }));

      // Get quick actions based on current context
      const { getQuickActions } = require('../prompts/ai_tutor_prompts');
      const quickActions = getQuickActions(conversation.currentContext?.type || 'general');

      res.json({
        success: true,
        data: {
          messages,
          messageCount: conversation.messageCount,
          currentContext: conversation.currentContext,
          quickActions,
          isNewConversation: false // Explicitly include for consistency
        },
        requestId: req.requestId
      });
    } catch (error) {
      logger.error('Error getting AI Tutor conversation', {
        error: error.message,
        requestId: req.requestId
      });
      classifyAndHandleError(error, next);
    }
  }
);

// ============================================================================
// POST /api/ai-tutor/inject-context
// ============================================================================

/**
 * POST /api/ai-tutor/inject-context
 *
 * Inject context into conversation (when opening from solution/quiz/analytics)
 * Adds a context marker and generates a contextual greeting
 *
 * Authentication: Required
 * Tier: Ultra only
 *
 * Request body:
 * {
 *   contextType: 'solution' | 'quiz' | 'analytics' | 'general',
 *   contextId?: string  // Required for solution and quiz
 * }
 *
 * Response:
 * {
 *   success: true,
 *   data: {
 *     greeting: string,
 *     contextMarker: {id, type, title, timestamp},
 *     quickActions: [{id, label, prompt}]
 *   }
 * }
 */
router.post('/inject-context',
  authenticateUser,
  requireFeature('ai_tutor_enabled'),
  checkUsageLimit('ai_tutor'), // Add rate limiting - context injection uses AI tokens
  [
    body('contextType')
      .isIn(['solution', 'quiz', 'chapterPractice', 'mockTest', 'analytics', 'general'])
      .withMessage('contextType must be one of: solution, quiz, chapterPractice, mockTest, analytics, general'),
    body('contextId')
      .optional()
      .isString()
      .isLength({ max: 128 })
      .withMessage('contextId must be a string with max 128 characters')
  ],
  async (req, res, next) => {
    try {
      // Validate request
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        throw new ApiError(400, 'Validation failed', ERROR_CODES.VALIDATION_ERROR, errors.array());
      }

      const userId = req.userId;
      const { contextType, contextId } = req.body;

      // Validate contextId is provided for context types that require it
      const contextTypesRequiringId = ['solution', 'quiz', 'chapterPractice', 'mockTest'];
      if (contextTypesRequiringId.includes(contextType) && !contextId) {
        throw new ApiError(400, `contextId is required for ${contextType} context`, ERROR_CODES.MISSING_CONTEXT_ID);
      }

      logger.info('Injecting AI Tutor context', {
        contextType,
        hasContextId: !!contextId,
        requestId: req.requestId
      });

      const result = await injectContext(userId, contextType, contextId);

      res.json({
        success: true,
        data: {
          greeting: result.greeting,
          contextMarker: result.contextMarker,
          quickActions: result.quickActions
        },
        usage: req.usage, // Include usage info for consistency
        requestId: req.requestId
      });
    } catch (error) {
      logger.error('Error injecting AI Tutor context', {
        contextType: req.body?.contextType,
        error: error.message,
        requestId: req.requestId
      });

      classifyAndHandleError(error, next);
    }
  }
);

// ============================================================================
// POST /api/ai-tutor/message
// ============================================================================

/**
 * POST /api/ai-tutor/message
 *
 * Send a message to the AI tutor
 *
 * Authentication: Required
 * Tier: Ultra only
 * Usage: Counts against ai_tutor_messages_daily limit
 *
 * Request body:
 * {
 *   message: string
 * }
 *
 * Response:
 * {
 *   success: true,
 *   data: {
 *     response: string,
 *     quickActions: [{id, label, prompt}]
 *   }
 * }
 */
router.post('/message',
  authenticateUser,
  requireFeature('ai_tutor_enabled'),
  checkUsageLimit('ai_tutor'),
  [
    body('message')
      .trim()
      .notEmpty()
      .withMessage('message is required')
      .isLength({ max: 2000 })
      .withMessage('message must be 2000 characters or less')
  ],
  moderateMessage(), // Content moderation middleware
  async (req, res, next) => {
    try {
      // Validate request
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        throw new ApiError(400, 'Validation failed', ERROR_CODES.VALIDATION_ERROR, errors.array());
      }

      const userId = req.userId;
      const { message } = req.body;
      const moderationAnalysis = req.moderationAnalysis;

      logger.info('AI Tutor message received', {
        messageLength: message.length,
        flagged: moderationAnalysis?.flagged || false,
        flagSeverity: moderationAnalysis?.severity || null,
        requestId: req.requestId
      });

      // Handle high-severity flagged content with safe response
      // For high severity (self-harm, violence, abuse, explicit), return safe response immediately
      if (moderationAnalysis?.flagged && moderationAnalysis.severity === 'high') {
        logger.warn('High-severity content intercepted', {
          userId,
          categories: moderationAnalysis.categories,
          flagId: req.moderationFlagId,
          requestId: req.requestId
        });

        // Return the safe response without calling the AI
        const { getQuickActions } = require('../prompts/ai_tutor_prompts');
        return res.json({
          success: true,
          data: {
            response: moderationAnalysis.suggestedResponse || SAFE_RESPONSES.off_topic,
            quickActions: getQuickActions('general')
          },
          usage: req.usage,
          requestId: req.requestId,
          moderated: true // Flag for client to know response was moderated
        });
      }

      const result = await sendMessage(userId, message);

      res.json({
        success: true,
        data: {
          response: result.response,
          quickActions: result.quickActions
        },
        usage: req.usage, // Attached by checkUsageLimit middleware
        requestId: req.requestId
      });
    } catch (error) {
      logger.error('Error in AI Tutor message', {
        error: error.message,
        requestId: req.requestId
      });

      classifyAndHandleError(error, next);
    }
  }
);

// ============================================================================
// DELETE /api/ai-tutor/conversation
// ============================================================================

/**
 * DELETE /api/ai-tutor/conversation
 *
 * Clear conversation history and start fresh
 *
 * Authentication: Required
 * Tier: Ultra only
 *
 * Response:
 * {
 *   success: true,
 *   message: 'Conversation cleared'
 * }
 */
router.delete('/conversation',
  authenticateUser,
  requireFeature('ai_tutor_enabled'),
  async (req, res, next) => {
    try {
      const userId = req.userId;

      logger.info('Clearing AI Tutor conversation', { userId, requestId: req.requestId });

      await resetConversation(userId);

      res.json({
        success: true,
        message: 'Conversation cleared',
        requestId: req.requestId
      });
    } catch (error) {
      logger.error('Error clearing AI Tutor conversation', {
        error: error.message,
        requestId: req.requestId
      });
      classifyAndHandleError(error, next);
    }
  }
);

module.exports = router;
