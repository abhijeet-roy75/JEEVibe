/**
 * AI Tutor Routes Test Suite
 * Tests for API endpoints: /api/ai-tutor/*
 */

const request = require('supertest');
const express = require('express');

// Mock all dependencies before requiring the router
jest.mock('../../../src/middleware/auth', () => ({
  authenticateUser: jest.fn((req, res, next) => {
    req.userId = 'user123';
    req.requestId = 'req123';
    next();
  })
}));

// Track middleware factory calls
const requireFeatureCalls = [];
const checkUsageLimitCalls = [];

jest.mock('../../../src/middleware/featureGate', () => ({
  requireFeature: jest.fn((feature) => {
    requireFeatureCalls.push(feature);
    return (req, res, next) => next();
  }),
  checkUsageLimit: jest.fn((usageType) => {
    checkUsageLimitCalls.push(usageType);
    return (req, res, next) => {
      req.usage = { used: 1, limit: 50, remaining: 49 };
      next();
    };
  })
}));

jest.mock('../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn()
}));

// Mock ApiError to work like a real error class with status
jest.mock('../../../src/middleware/errorHandler', () => ({
  ApiError: class ApiError extends Error {
    constructor(status, message, code, details) {
      super(message);
      this.status = status;
      this.code = code;
      this.details = details;
    }
  }
}));

jest.mock('../../../src/services/aiTutorService', () => ({
  sendMessage: jest.fn(),
  injectContext: jest.fn(),
  getConversation: jest.fn(),
  resetConversation: jest.fn(),
  generateWelcomeMessage: jest.fn()
}));

jest.mock('../../../src/services/tutorConversationService', () => ({
  hasConversation: jest.fn()
}));

jest.mock('../../../src/prompts/ai_tutor_prompts', () => ({
  getQuickActions: jest.fn(() => [
    { id: 'action1', label: 'Action 1', prompt: 'Prompt 1' }
  ])
}));

const { authenticateUser } = require('../../../src/middleware/auth');
const { requireFeature, checkUsageLimit } = require('../../../src/middleware/featureGate');
const logger = require('../../../src/utils/logger');
const {
  sendMessage,
  injectContext,
  getConversation,
  resetConversation,
  generateWelcomeMessage
} = require('../../../src/services/aiTutorService');
const { hasConversation } = require('../../../src/services/tutorConversationService');
const { getQuickActions } = require('../../../src/prompts/ai_tutor_prompts');

// Import router after mocks
const aiTutorRouter = require('../../../src/routes/aiTutor');

// Create Express app with router
const app = express();
app.use(express.json());
app.use('/api/ai-tutor', aiTutorRouter);

// Simple error handler for tests - MUST come after routes
app.use((err, req, res, next) => {
  res.status(err.status || 500).json({
    success: false,
    error: {
      message: err.message,
      code: err.code
    }
  });
});

describe('AI Tutor Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('GET /api/ai-tutor/conversation', () => {
    test('should return welcome message for new user', async () => {
      hasConversation.mockResolvedValue(false);
      generateWelcomeMessage.mockResolvedValue({
        message: "Hello! I'm Priya Ma'am!",
        quickActions: [{ id: 'tip', label: 'JEE tips', prompt: 'Give me tips' }]
      });

      const res = await request(app)
        .get('/api/ai-tutor/conversation')
        .set('Authorization', 'Bearer token');

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.isNewConversation).toBe(true);
      expect(res.body.data.messages).toHaveLength(1);
      expect(res.body.data.messages[0].type).toBe('assistant');
      expect(res.body.data.messages[0].content).toBe("Hello! I'm Priya Ma'am!");
    });

    test('should return existing conversation history', async () => {
      const mockMessages = [
        { id: '1', type: 'assistant', content: 'Hello!', timestamp: new Date() },
        { id: '2', type: 'user', content: 'Hi', timestamp: new Date() }
      ];
      hasConversation.mockResolvedValue(true);
      getConversation.mockResolvedValue({
        messages: mockMessages,
        messageCount: 2,
        currentContext: { type: 'solution', id: 'snap123', title: 'Kinematics' }
      });

      const res = await request(app)
        .get('/api/ai-tutor/conversation')
        .set('Authorization', 'Bearer token');

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.messages).toHaveLength(2);
      expect(res.body.data.messageCount).toBe(2);
      expect(res.body.data.currentContext.type).toBe('solution');
    });

    test('should respect limit query parameter', async () => {
      hasConversation.mockResolvedValue(true);
      getConversation.mockResolvedValue({
        messages: [],
        messageCount: 0,
        currentContext: null
      });

      await request(app)
        .get('/api/ai-tutor/conversation?limit=25')
        .set('Authorization', 'Bearer token');

      expect(getConversation).toHaveBeenCalledWith('user123', 25);
    });

    test('should cap limit at 100', async () => {
      hasConversation.mockResolvedValue(true);
      getConversation.mockResolvedValue({
        messages: [],
        messageCount: 0,
        currentContext: null
      });

      await request(app)
        .get('/api/ai-tutor/conversation?limit=500')
        .set('Authorization', 'Bearer token');

      expect(getConversation).toHaveBeenCalledWith('user123', 100);
    });

    test('should include quick actions in response', async () => {
      hasConversation.mockResolvedValue(true);
      getConversation.mockResolvedValue({
        messages: [],
        messageCount: 0,
        currentContext: null
      });

      const res = await request(app)
        .get('/api/ai-tutor/conversation')
        .set('Authorization', 'Bearer token');

      expect(res.body.data.quickActions).toBeDefined();
      expect(getQuickActions).toHaveBeenCalledWith('general');
    });

    test('should have requireFeature middleware applied', async () => {
      // requireFeature is called during route setup (module load)
      // We track the calls separately since jest.clearAllMocks() clears the mock counts
      expect(requireFeatureCalls).toContain('ai_tutor_enabled');
    });
  });

  describe('POST /api/ai-tutor/inject-context', () => {
    test('should inject solution context successfully', async () => {
      injectContext.mockResolvedValue({
        greeting: "I see you're working on Kinematics!",
        contextMarker: {
          id: 'marker123',
          type: 'solution',
          title: 'Kinematics - Physics',
          timestamp: new Date()
        },
        quickActions: [{ id: 'explain', label: 'Explain', prompt: 'Explain this' }]
      });

      const res = await request(app)
        .post('/api/ai-tutor/inject-context')
        .set('Authorization', 'Bearer token')
        .send({ contextType: 'solution', contextId: 'snap123' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.greeting).toContain('Kinematics');
      expect(res.body.data.contextMarker.type).toBe('solution');
      expect(injectContext).toHaveBeenCalledWith('user123', 'solution', 'snap123');
    });

    test('should inject quiz context successfully', async () => {
      injectContext.mockResolvedValue({
        greeting: "Let's review your quiz!",
        contextMarker: { id: 'marker456', type: 'quiz', title: 'Daily Quiz #5' },
        quickActions: []
      });

      const res = await request(app)
        .post('/api/ai-tutor/inject-context')
        .set('Authorization', 'Bearer token')
        .send({ contextType: 'quiz', contextId: 'quiz456' });

      expect(res.status).toBe(200);
      expect(injectContext).toHaveBeenCalledWith('user123', 'quiz', 'quiz456');
    });

    test('should inject analytics context without contextId', async () => {
      injectContext.mockResolvedValue({
        greeting: "Let's look at your progress!",
        contextMarker: { id: 'marker789', type: 'analytics', title: 'My Progress' },
        quickActions: []
      });

      const res = await request(app)
        .post('/api/ai-tutor/inject-context')
        .set('Authorization', 'Bearer token')
        .send({ contextType: 'analytics' });

      expect(res.status).toBe(200);
      expect(injectContext).toHaveBeenCalledWith('user123', 'analytics', undefined);
    });

    test('should return 400 for invalid contextType', async () => {
      const res = await request(app)
        .post('/api/ai-tutor/inject-context')
        .set('Authorization', 'Bearer token')
        .send({ contextType: 'invalid' });

      expect(res.status).toBe(400);
    });

    test('should return 400 when solution context missing contextId', async () => {
      const res = await request(app)
        .post('/api/ai-tutor/inject-context')
        .set('Authorization', 'Bearer token')
        .send({ contextType: 'solution' });

      expect(res.status).toBe(400);
    });

    test('should return 400 when quiz context missing contextId', async () => {
      const res = await request(app)
        .post('/api/ai-tutor/inject-context')
        .set('Authorization', 'Bearer token')
        .send({ contextType: 'quiz' });

      expect(res.status).toBe(400);
    });
  });

  describe('POST /api/ai-tutor/message', () => {
    test('should send message and return response', async () => {
      sendMessage.mockResolvedValue({
        response: 'Projectile motion is when an object is thrown...',
        quickActions: [{ id: 'more', label: 'Tell me more', prompt: 'More details' }]
      });

      const res = await request(app)
        .post('/api/ai-tutor/message')
        .set('Authorization', 'Bearer token')
        .send({ message: 'What is projectile motion?' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.response).toContain('Projectile motion');
      expect(res.body.data.quickActions).toBeDefined();
      expect(res.body.usage).toBeDefined();
    });

    test('should return 400 for empty message', async () => {
      const res = await request(app)
        .post('/api/ai-tutor/message')
        .set('Authorization', 'Bearer token')
        .send({ message: '' });

      // Empty string after trim becomes empty, which should fail notEmpty() validation
      expect(res.status).toBe(400);
    });

    test('should return 400 for missing message', async () => {
      const res = await request(app)
        .post('/api/ai-tutor/message')
        .set('Authorization', 'Bearer token')
        .send({});

      expect(res.status).toBe(400);
    });

    test('should return 400 for message exceeding 2000 characters', async () => {
      const longMessage = 'a'.repeat(2001);

      const res = await request(app)
        .post('/api/ai-tutor/message')
        .set('Authorization', 'Bearer token')
        .send({ message: longMessage });

      expect(res.status).toBe(400);
    });

    test('should trim whitespace from message', async () => {
      sendMessage.mockResolvedValue({
        response: 'Response',
        quickActions: []
      });

      await request(app)
        .post('/api/ai-tutor/message')
        .set('Authorization', 'Bearer token')
        .send({ message: '  What is physics?  ' });

      expect(sendMessage).toHaveBeenCalledWith('user123', 'What is physics?');
    });

    test('should have usage limit check applied', async () => {
      // checkUsageLimit is called during route setup (module load)
      expect(checkUsageLimitCalls).toContain('ai_tutor');

      sendMessage.mockResolvedValue({
        response: 'Response',
        quickActions: []
      });

      const res = await request(app)
        .post('/api/ai-tutor/message')
        .set('Authorization', 'Bearer token')
        .send({ message: 'Hello' });

      // The response should include usage data added by middleware
      expect(res.body.usage).toBeDefined();
    });
  });

  describe('DELETE /api/ai-tutor/conversation', () => {
    test('should clear conversation successfully', async () => {
      resetConversation.mockResolvedValue();

      const res = await request(app)
        .delete('/api/ai-tutor/conversation')
        .set('Authorization', 'Bearer token');

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.message).toBe('Conversation cleared');
      expect(resetConversation).toHaveBeenCalledWith('user123');
    });

    test('should handle reset errors', async () => {
      resetConversation.mockRejectedValue(new Error('Reset failed'));

      const res = await request(app)
        .delete('/api/ai-tutor/conversation')
        .set('Authorization', 'Bearer token');

      expect(res.status).toBe(500);
      expect(logger.error).toHaveBeenCalled();
    });
  });

  describe('Authentication and Feature Gating', () => {
    test('should require authentication on all endpoints', async () => {
      hasConversation.mockResolvedValue(false);
      generateWelcomeMessage.mockResolvedValue({ message: 'Hi', quickActions: [] });
      injectContext.mockResolvedValue({ greeting: 'Hi', contextMarker: {}, quickActions: [] });
      sendMessage.mockResolvedValue({ response: 'Hi', quickActions: [] });
      resetConversation.mockResolvedValue();

      // All endpoints should call authenticateUser
      await request(app).get('/api/ai-tutor/conversation');
      await request(app).post('/api/ai-tutor/inject-context').send({ contextType: 'general' });
      await request(app).post('/api/ai-tutor/message').send({ message: 'test' });
      await request(app).delete('/api/ai-tutor/conversation');

      expect(authenticateUser).toHaveBeenCalledTimes(4);
    });

    test('should have feature gating applied to routes', () => {
      // requireFeature is called during route setup (module load)
      // The router defines 4 routes that use requireFeature('ai_tutor_enabled')
      // We track calls in our array since jest.clearAllMocks() clears the mock counts
      expect(requireFeatureCalls.filter(f => f === 'ai_tutor_enabled').length).toBe(4);
    });
  });

  describe('Error Handling', () => {
    test('should handle service errors gracefully', async () => {
      getConversation.mockRejectedValue(new Error('Database error'));
      hasConversation.mockResolvedValue(true);

      const res = await request(app)
        .get('/api/ai-tutor/conversation')
        .set('Authorization', 'Bearer token');

      expect(res.status).toBe(500);
      expect(logger.error).toHaveBeenCalled();
    });

    test('should log errors with request context', async () => {
      sendMessage.mockRejectedValue(new Error('API Error'));

      await request(app)
        .post('/api/ai-tutor/message')
        .set('Authorization', 'Bearer token')
        .send({ message: 'test' });

      expect(logger.error).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          userId: 'user123',
          requestId: 'req123'
        })
      );
    });
  });
});
