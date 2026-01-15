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

const router = express.Router();

/**
 * Handle OpenAI errors by mapping them to ApiError
 */
function handleOpenAIError(error, next) {
  if (error.status) {
    if (error.status === 401) {
      return next(new ApiError(500, 'AI Service Configuration Error'));
    }
    if (error.status === 429) {
      return next(new ApiError(429, 'AI service is busy, please try again in a moment'));
    }
    if (error.status >= 500) {
      return next(new ApiError(502, 'AI service temporarily unavailable'));
    }
    return next(new ApiError(error.status, error.message));
  }
  next(error);
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
          quickActions
        },
        requestId: req.requestId
      });
    } catch (error) {
      logger.error('Error getting AI Tutor conversation', {
        userId: req.userId,
        error: error.message,
        requestId: req.requestId
      });
      next(error);
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
  [
    body('contextType')
      .isIn(['solution', 'quiz', 'analytics', 'general'])
      .withMessage('contextType must be one of: solution, quiz, analytics, general'),
    body('contextId')
      .optional()
      .isString()
      .withMessage('contextId must be a string')
  ],
  async (req, res, next) => {
    try {
      // Validate request
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        throw new ApiError(400, 'Validation failed', 'VALIDATION_ERROR', errors.array());
      }

      const userId = req.userId;
      const { contextType, contextId } = req.body;

      // Validate contextId is provided for solution and quiz
      if ((contextType === 'solution' || contextType === 'quiz') && !contextId) {
        throw new ApiError(400, `contextId is required for ${contextType} context`, 'MISSING_CONTEXT_ID');
      }

      logger.info('Injecting AI Tutor context', {
        userId,
        contextType,
        contextId,
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
        requestId: req.requestId
      });
    } catch (error) {
      logger.error('Error injecting AI Tutor context', {
        userId: req.userId,
        contextType: req.body?.contextType,
        error: error.message,
        requestId: req.requestId
      });

      if (error.status) {
        return handleOpenAIError(error, next);
      }
      next(error);
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
  async (req, res, next) => {
    try {
      // Validate request
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        throw new ApiError(400, 'Validation failed', 'VALIDATION_ERROR', errors.array());
      }

      const userId = req.userId;
      const { message } = req.body;

      logger.info('AI Tutor message received', {
        userId,
        messageLength: message.length,
        requestId: req.requestId
      });

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
        userId: req.userId,
        error: error.message,
        requestId: req.requestId
      });

      if (error.status) {
        return handleOpenAIError(error, next);
      }
      next(error);
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
        userId: req.userId,
        error: error.message,
        requestId: req.requestId
      });
      next(error);
    }
  }
);

module.exports = router;
