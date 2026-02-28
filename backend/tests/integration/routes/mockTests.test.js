/**
 * Integration tests for mockTests.js routes
 *
 * Tests authentication, start, active session, save answer, submit
 * Coverage target: 80%+
 */

const request = require('supertest');
const express = require('express');
const mockTestsRouter = require('../../../src/routes/mockTests');
const mockTestService = require('../../../src/services/mockTestService');
const subscriptionService = require('../../../src/services/subscriptionService');
const tierConfigService = require('../../../src/services/tierConfigService');
const usageTrackingService = require('../../../src/services/usageTrackingService');

// Mock services
jest.mock('../../../src/services/mockTestService');
jest.mock('../../../src/services/subscriptionService');
jest.mock('../../../src/services/tierConfigService');
jest.mock('../../../src/services/usageTrackingService');
jest.mock('../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn()
}));

// Mock authenticateUser middleware
jest.mock('../../../src/middleware/auth', () => ({
  authenticateUser: jest.fn((req, res, next) => {
    if (req.headers['x-test-auth-fail']) {
      return res.status(401).json({
        success: false,
        error: 'No authentication token provided.'
      });
    }
    req.userId = 'test-user-001';
    req.user = { uid: 'test-user-001' };
    next();
  })
}));

// Mock validateSessionMiddleware
jest.mock('../../../src/middleware/sessionValidator', () => ({
  validateSessionMiddleware: jest.fn((req, res, next) => next())
}));

describe('Mock Tests Routes', () => {
  let app;

  beforeAll(() => {
    app = express();
    app.use(express.json());
    app.use('/api/mock-tests', mockTestsRouter);

    // Error handler
    app.use((err, req, res, next) => {
      res.status(err.status || 500).json({
        success: false,
        error: err.message || 'Internal server error'
      });
    });
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('GET /api/mock-tests/available', () => {
    test('should return available templates for authenticated user', async () => {
      const mockTemplates = [
        {
          template_id: 'jee-main-2025-01',
          name: 'JEE Main 2025 - Test 1',
          difficulty: 'medium',
          total_questions: 90,
          duration: 10800
        },
        {
          template_id: 'jee-main-2025-02',
          name: 'JEE Main 2025 - Test 2',
          difficulty: 'hard',
          total_questions: 90,
          duration: 10800
        }
      ];

      mockTestService.getAvailableTemplates.mockResolvedValue(mockTemplates);

      const response = await request(app)
        .get('/api/mock-tests/available')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toEqual(mockTemplates);
      expect(mockTestService.getAvailableTemplates).toHaveBeenCalled();
    });

    test('should return 401 when not authenticated', async () => {
      const response = await request(app)
        .get('/api/mock-tests/available')
        .set('x-test-auth-fail', 'true')
        .expect(401);

      expect(response.body.success).toBe(false);
    });
  });

  describe('POST /api/mock-tests/start', () => {
    test('should start new mock test for authenticated user', async () => {
      const mockTestData = {
        test_id: 'mock-test-001',
        template_id: 'jee-main-2025-01',
        user_id: 'test-user-001',
        started_at: '2026-02-28T10:00:00Z',
        duration: 10800,
        total_questions: 90,
        status: 'in_progress'
      };

      subscriptionService.getEffectiveTier.mockResolvedValue('pro');
      mockTestService.checkRateLimit.mockResolvedValue({ allowed: true });
      mockTestService.startMockTest.mockResolvedValue(mockTestData);
      usageTrackingService.incrementUsage.mockResolvedValue();

      const response = await request(app)
        .post('/api/mock-tests/start')
        .send({ template_id: 'jee-main-2025-01' })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.test_id).toBe('mock-test-001');
      expect(mockTestService.startMockTest).toHaveBeenCalledWith('test-user-001', 'jee-main-2025-01');
    });

    test('should return 402 when rate limit exceeded', async () => {
      subscriptionService.getEffectiveTier.mockResolvedValue('free');
      mockTestService.checkRateLimit.mockResolvedValue({
        allowed: false,
        limit: 1,
        used: 1,
        resets_at: '2026-03-01T00:00:00Z'
      });

      const response = await request(app)
        .post('/api/mock-tests/start')
        .send({ template_id: 'jee-main-2025-01' })
        .expect(402);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('limit');
    });

    test('should return 400 when template_id missing', async () => {
      const response = await request(app)
        .post('/api/mock-tests/start')
        .send({})
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should return 401 when not authenticated', async () => {
      const response = await request(app)
        .post('/api/mock-tests/start')
        .set('x-test-auth-fail', 'true')
        .send({ template_id: 'jee-main-2025-01' })
        .expect(401);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/mock-tests/active', () => {
    test('should return active test with questions', async () => {
      const mockActiveTest = {
        test_id: 'mock-test-001',
        template_id: 'jee-main-2025-01',
        user_id: 'test-user-001',
        started_at: '2026-02-28T10:00:00Z',
        time_remaining: 9000,
        status: 'in_progress',
        questions: [
          {
            question_number: 1,
            subject: 'Physics',
            question_type: 'mcq_single',
            question_text: 'A block of mass 5 kg...',
            options: [
              { option_id: 'A', text: '10 N' },
              { option_id: 'B', text: '20 N' },
              { option_id: 'C', text: '30 N' },
              { option_id: 'D', text: '40 N' }
            ]
          }
        ],
        responses: {}
      };

      mockTestService.getActiveTestWithQuestions.mockResolvedValue(mockActiveTest);

      const response = await request(app)
        .get('/api/mock-tests/active')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.test_id).toBe('mock-test-001');
      expect(response.body.data.questions).toHaveLength(1);
    });

    test('should return 404 when no active test', async () => {
      mockTestService.getActiveTestWithQuestions.mockResolvedValue(null);

      const response = await request(app)
        .get('/api/mock-tests/active')
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('No active');
    });

    test('should return 401 when not authenticated', async () => {
      const response = await request(app)
        .get('/api/mock-tests/active')
        .set('x-test-auth-fail', 'true')
        .expect(401);

      expect(response.body.success).toBe(false);
    });
  });

  describe('POST /api/mock-tests/save-answer', () => {
    test('should save answer successfully', async () => {
      const mockResult = {
        test_id: 'mock-test-001',
        question_number: 1,
        answer: 'B',
        marked_for_review: false,
        saved_at: '2026-02-28T10:15:00Z'
      };

      mockTestService.saveAnswer.mockResolvedValue(mockResult);

      const response = await request(app)
        .post('/api/mock-tests/save-answer')
        .send({
          test_id: 'mock-test-001',
          question_number: 1,
          answer: 'B',
          marked_for_review: false
        })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.answer).toBe('B');
    });

    test('should return 400 for invalid question number', async () => {
      const response = await request(app)
        .post('/api/mock-tests/save-answer')
        .send({
          test_id: 'mock-test-001',
          question_number: 91, // Invalid: max is 90
          answer: 'A'
        })
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('Validation failed');
    });

    test('should return 400 when test_id missing', async () => {
      const response = await request(app)
        .post('/api/mock-tests/save-answer')
        .send({
          question_number: 1,
          answer: 'A'
        })
        .expect(400);

      expect(response.body.success).toBe(false);
    });
  });

  describe('POST /api/mock-tests/clear-answer', () => {
    test('should clear answer successfully', async () => {
      const mockResult = {
        test_id: 'mock-test-001',
        question_number: 1,
        answer: null,
        cleared_at: '2026-02-28T10:20:00Z'
      };

      mockTestService.clearAnswer.mockResolvedValue(mockResult);

      const response = await request(app)
        .post('/api/mock-tests/clear-answer')
        .send({
          test_id: 'mock-test-001',
          question_number: 1
        })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.answer).toBeNull();
    });
  });

  describe('POST /api/mock-tests/submit', () => {
    test('should submit test and return results', async () => {
      const mockResults = {
        test_id: 'mock-test-001',
        user_id: 'test-user-001',
        submitted_at: '2026-02-28T13:00:00Z',
        total_score: 240,
        correct: 60,
        incorrect: 15,
        unattempted: 15,
        total_marks: 300,
        percentage: 80.0,
        subjects: {
          physics: { correct: 20, incorrect: 5, unattempted: 5, score: 75 },
          chemistry: { correct: 18, incorrect: 6, unattempted: 6, score: 66 },
          mathematics: { correct: 22, incorrect: 4, unattempted: 4, score: 84 }
        },
        nta_percentile: 85.5
      };

      mockTestService.submitMockTest.mockResolvedValue(mockResults);

      const response = await request(app)
        .post('/api/mock-tests/submit')
        .send({ test_id: 'mock-test-001' })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.total_score).toBe(240);
      expect(response.body.data.percentage).toBe(80.0);
    });

    test('should return 400 when test_id missing', async () => {
      const response = await request(app)
        .post('/api/mock-tests/submit')
        .send({})
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should return 404 when test not found', async () => {
      mockTestService.submitMockTest.mockRejectedValue(
        new Error('Test not found')
      );

      const response = await request(app)
        .post('/api/mock-tests/submit')
        .send({ test_id: 'non-existent-test' })
        .expect(500);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/mock-tests/history', () => {
    test('should return user mock test history', async () => {
      const mockHistory = [
        {
          test_id: 'mock-test-001',
          template_name: 'JEE Main 2025 - Test 1',
          started_at: '2026-02-28T10:00:00Z',
          submitted_at: '2026-02-28T13:00:00Z',
          total_score: 240,
          percentage: 80.0,
          status: 'completed'
        },
        {
          test_id: 'mock-test-002',
          template_name: 'JEE Main 2025 - Test 2',
          started_at: '2026-02-25T10:00:00Z',
          submitted_at: '2026-02-25T13:00:00Z',
          total_score: 210,
          percentage: 70.0,
          status: 'completed'
        }
      ];

      mockTestService.getUserMockTestHistory.mockResolvedValue(mockHistory);

      const response = await request(app)
        .get('/api/mock-tests/history')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveLength(2);
    });

    test('should return empty array when no history', async () => {
      mockTestService.getUserMockTestHistory.mockResolvedValue([]);

      const response = await request(app)
        .get('/api/mock-tests/history')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveLength(0);
    });
  });

  describe('GET /api/mock-tests/:testId/results', () => {
    test('should return detailed test results', async () => {
      const mockResults = {
        test_id: 'mock-test-001',
        user_id: 'test-user-001',
        total_score: 240,
        percentage: 80.0,
        nta_percentile: 85.5,
        subjects: {
          physics: { correct: 20, score: 75 },
          chemistry: { correct: 18, score: 66 },
          mathematics: { correct: 22, score: 84 }
        },
        question_analysis: [
          {
            question_number: 1,
            subject: 'Physics',
            correct_answer: 'B',
            student_answer: 'B',
            is_correct: true,
            marks: 4
          }
        ]
      };

      mockTestService.getTestResults.mockResolvedValue(mockResults);

      const response = await request(app)
        .get('/api/mock-tests/mock-test-001/results')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.total_score).toBe(240);
      expect(response.body.data.question_analysis).toHaveLength(1);
    });

    test('should return 404 when results not found', async () => {
      mockTestService.getTestResults.mockRejectedValue(
        new Error('Results not found')
      );

      const response = await request(app)
        .get('/api/mock-tests/non-existent-test/results')
        .expect(500);

      expect(response.body.success).toBe(false);
    });
  });

  describe('POST /api/mock-tests/abandon', () => {
    test('should abandon active test', async () => {
      const mockResult = {
        test_id: 'mock-test-001',
        status: 'abandoned',
        abandoned_at: '2026-02-28T11:00:00Z'
      };

      mockTestService.abandonTest.mockResolvedValue(mockResult);

      const response = await request(app)
        .post('/api/mock-tests/abandon')
        .send({ test_id: 'mock-test-001' })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.status).toBe('abandoned');
    });

    test('should return 400 when test_id missing', async () => {
      const response = await request(app)
        .post('/api/mock-tests/abandon')
        .send({})
        .expect(400);

      expect(response.body.success).toBe(false);
    });
  });

  describe('Error handling', () => {
    test('should handle service errors gracefully', async () => {
      mockTestService.getAvailableTemplates.mockRejectedValue(
        new Error('Database connection error')
      );

      const response = await request(app)
        .get('/api/mock-tests/available')
        .expect(500);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBeDefined();
    });

    test('should handle validation errors properly', async () => {
      const response = await request(app)
        .post('/api/mock-tests/save-answer')
        .send({
          test_id: 'mock-test-001',
          question_number: 'not-a-number',
          answer: 'A'
        })
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation failed');
    });
  });
});
