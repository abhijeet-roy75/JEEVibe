/**
 * Integration tests for weakSpots.js routes (Cognitive Mastery)
 *
 * Tests authentication, capsule fetch, retrieval submission, weak spot listing, event logging
 * Coverage target: 80%+
 */

const request = require('supertest');
const express = require('express');
const weakSpotsRouter = require('../../../src/routes/weakSpots');
const weakSpotScoringService = require('../../../src/services/weakSpotScoringService');
const { db } = require('../../../src/config/firebase');

// Mock services
jest.mock('../../../src/services/weakSpotScoringService');
jest.mock('../../../src/config/firebase', () => ({
  db: {
    collection: jest.fn()
  }
}));
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

describe('Weak Spots Routes', () => {
  let app;
  let mockGet;
  let mockDoc;
  let mockCollection;

  beforeAll(() => {
    app = express();
    app.use(express.json());
    app.use('/api', weakSpotsRouter);

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

    // Setup Firestore mocks
    mockGet = jest.fn();
    mockDoc = jest.fn(() => ({
      get: mockGet
    }));
    mockCollection = jest.fn(() => ({
      doc: mockDoc
    }));

    db.collection = mockCollection;
  });

  describe('GET /api/capsules/:capsuleId', () => {
    test('should fetch capsule with retrieval questions', async () => {
      const mockCapsuleData = {
        atlas_node_id: 'PHY_LOM_001',
        node_name: 'Newton\'s Laws of Motion',
        core_misconception: 'Students confuse force with acceleration...',
        structural_rule: 'F = ma is the fundamental equation...',
        illustrative_example: 'Consider a block on a frictionless surface...',
        estimated_read_time: 120,
        pool_id: 'pool-001'
      };

      const mockPoolData = {
        question_ids: ['q1', 'q2', 'q3']
      };

      const mockQuestions = [
        {
          id: 'q1',
          exists: true,
          data: () => ({
            question_text: 'What is F = ma?',
            options: ['A', 'B', 'C'],
            correct_option: 'B'
          })
        },
        {
          id: 'q2',
          exists: true,
          data: () => ({
            question_text: 'Define force',
            options: ['A', 'B'],
            correct_option: 'A'
          })
        },
        {
          id: 'q3',
          exists: true,
          data: () => ({
            question_text: 'What is acceleration?',
            options: ['A', 'B', 'C', 'D'],
            correct_option: 'C'
          })
        }
      ];

      mockGet
        .mockResolvedValueOnce({ exists: true, data: () => mockCapsuleData }) // capsule
        .mockResolvedValueOnce({ exists: true, data: () => mockPoolData }) // pool
        .mockResolvedValueOnce(mockQuestions[0]) // question 1
        .mockResolvedValueOnce(mockQuestions[1]) // question 2
        .mockResolvedValueOnce(mockQuestions[2]); // question 3

      const response = await request(app)
        .get('/api/capsules/capsule-001')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.capsule.capsuleId).toBe('capsule-001');
      expect(response.body.data.capsule.nodeId).toBe('PHY_LOM_001');
      expect(response.body.data.retrievalQuestions).toHaveLength(3);
      expect(response.body.data.retrievalQuestions[0].questionId).toBe('q1');
    });

    test('should return capsule without questions if pool not found', async () => {
      const mockCapsuleData = {
        atlas_node_id: 'PHY_LOM_001',
        node_name: 'Newton\'s Laws of Motion',
        core_misconception: 'Test',
        structural_rule: 'Test',
        illustrative_example: 'Test',
        pool_id: 'pool-001'
      };

      mockGet
        .mockResolvedValueOnce({ exists: true, data: () => mockCapsuleData }) // capsule
        .mockResolvedValueOnce({ exists: false }); // pool not found

      const response = await request(app)
        .get('/api/capsules/capsule-001')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.retrievalQuestions).toEqual([]);
    });

    test('should return 404 when capsule not found', async () => {
      mockGet.mockResolvedValue({ exists: false });

      const response = await request(app)
        .get('/api/capsules/non-existent')
        .expect(404);

      expect(response.body.success).toBe(false);
    });

    test('should return 401 when not authenticated', async () => {
      const response = await request(app)
        .get('/api/capsules/capsule-001')
        .set('x-test-auth-fail', 'true')
        .expect(401);

      expect(response.body.success).toBe(false);
    });
  });

  describe('POST /api/weak-spots/retrieval', () => {
    test('should submit retrieval answers and return result', async () => {
      const mockAtlasNode = {
        atlas_node_id: 'PHY_LOM_001',
        name: 'Newton\'s Laws',
        passing_threshold: 0.67
      };

      const mockResult = {
        passed: true,
        correctCount: 2,
        totalQuestions: 3,
        newScore: 0.75,
        newNodeState: 'improving'
      };

      mockGet
        .mockResolvedValueOnce({ exists: true, id: 'PHY_LOM_001', data: () => mockAtlasNode }) // atlas node
        .mockResolvedValueOnce({ exists: true, data: () => ({ correct_option: 'B' }) }) // q1
        .mockResolvedValueOnce({ exists: true, data: () => ({ correct_option: 'A' }) }) // q2
        .mockResolvedValueOnce({ exists: true, data: () => ({ correct_option: 'C' }) }); // q3

      weakSpotScoringService.evaluateRetrieval.mockResolvedValue(mockResult);

      const response = await request(app)
        .post('/api/weak-spots/retrieval')
        .send({
          userId: 'test-user-001',
          nodeId: 'PHY_LOM_001',
          responses: [
            { questionId: 'q1', studentAnswer: 'B' },
            { questionId: 'q2', studentAnswer: 'A' },
            { questionId: 'q3', studentAnswer: 'D' }
          ]
        })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.passed).toBe(true);
      expect(response.body.data.correctCount).toBe(2);
      expect(weakSpotScoringService.evaluateRetrieval).toHaveBeenCalledWith(
        'test-user-001',
        'PHY_LOM_001',
        expect.arrayContaining([
          expect.objectContaining({ questionId: 'q1', isCorrect: true }),
          expect.objectContaining({ questionId: 'q2', isCorrect: true }),
          expect.objectContaining({ questionId: 'q3', isCorrect: false })
        ]),
        expect.objectContaining({ atlas_node_id: 'PHY_LOM_001' })
      );
    });

    test('should return 403 when userId mismatch', async () => {
      const response = await request(app)
        .post('/api/weak-spots/retrieval')
        .send({
          userId: 'other-user',
          nodeId: 'PHY_LOM_001',
          responses: [
            { questionId: 'q1', studentAnswer: 'B' }
          ]
        })
        .expect(403);

      expect(response.body.success).toBe(false);
    });

    test('should return 404 when atlas node not found', async () => {
      mockGet.mockResolvedValue({ exists: false });

      const response = await request(app)
        .post('/api/weak-spots/retrieval')
        .send({
          userId: 'test-user-001',
          nodeId: 'non-existent',
          responses: [
            { questionId: 'q1', studentAnswer: 'B' }
          ]
        })
        .expect(404);

      expect(response.body.success).toBe(false);
    });

    test('should return 400 when validation fails', async () => {
      const response = await request(app)
        .post('/api/weak-spots/retrieval')
        .send({
          userId: 'test-user-001',
          nodeId: 'PHY_LOM_001',
          responses: [] // Empty array
        })
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should return 400 when userId missing', async () => {
      const response = await request(app)
        .post('/api/weak-spots/retrieval')
        .send({
          nodeId: 'PHY_LOM_001',
          responses: [
            { questionId: 'q1', studentAnswer: 'B' }
          ]
        })
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should return 400 when nodeId missing', async () => {
      const response = await request(app)
        .post('/api/weak-spots/retrieval')
        .send({
          userId: 'test-user-001',
          responses: [
            { questionId: 'q1', studentAnswer: 'B' }
          ]
        })
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should compute isCorrect server-side', async () => {
      const mockAtlasNode = {
        atlas_node_id: 'PHY_LOM_001',
        name: 'Newton\'s Laws'
      };

      mockGet
        .mockResolvedValueOnce({ exists: true, id: 'PHY_LOM_001', data: () => mockAtlasNode })
        .mockResolvedValueOnce({ exists: true, data: () => ({ correct_option: 'B' }) })
        .mockResolvedValueOnce({ exists: true, data: () => ({ correct_option: 'A' }) });

      weakSpotScoringService.evaluateRetrieval.mockResolvedValue({
        passed: true,
        correctCount: 1,
        totalQuestions: 2
      });

      await request(app)
        .post('/api/weak-spots/retrieval')
        .send({
          userId: 'test-user-001',
          nodeId: 'PHY_LOM_001',
          responses: [
            { questionId: 'q1', studentAnswer: 'B' }, // Correct
            { questionId: 'q2', studentAnswer: 'C' }  // Incorrect
          ]
        })
        .expect(200);

      expect(weakSpotScoringService.evaluateRetrieval).toHaveBeenCalledWith(
        'test-user-001',
        'PHY_LOM_001',
        [
          expect.objectContaining({ isCorrect: true }),
          expect.objectContaining({ isCorrect: false })
        ],
        expect.any(Object)
      );
    });
  });

  describe('GET /api/weak-spots/:userId', () => {
    test('should return user weak spots', async () => {
      const mockWeakSpots = [
        {
          nodeId: 'PHY_LOM_001',
          title: 'Newton\'s Laws of Motion',
          nodeState: 'active',
          capsuleStatus: 'not_opened',
          score: 0.45,
          detectedAt: '2026-02-28T10:00:00Z'
        },
        {
          nodeId: 'CHE_THERMO_001',
          title: 'First Law of Thermodynamics',
          nodeState: 'improving',
          capsuleStatus: 'opened',
          score: 0.65,
          detectedAt: '2026-02-27T15:30:00Z'
        }
      ];

      weakSpotScoringService.getUserWeakSpots.mockResolvedValue(mockWeakSpots);

      const response = await request(app)
        .get('/api/weak-spots/test-user-001')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.weakSpots).toHaveLength(2);
      expect(response.body.data.totalCount).toBe(2);
      expect(weakSpotScoringService.getUserWeakSpots).toHaveBeenCalledWith(
        'test-user-001',
        expect.objectContaining({ nodeState: null, limit: 10 })
      );
    });

    test('should filter by nodeState when provided', async () => {
      weakSpotScoringService.getUserWeakSpots.mockResolvedValue([]);

      await request(app)
        .get('/api/weak-spots/test-user-001?nodeState=active')
        .expect(200);

      expect(weakSpotScoringService.getUserWeakSpots).toHaveBeenCalledWith(
        'test-user-001',
        expect.objectContaining({ nodeState: 'active', limit: 10 })
      );
    });

    test('should accept limit parameter', async () => {
      weakSpotScoringService.getUserWeakSpots.mockResolvedValue([]);

      await request(app)
        .get('/api/weak-spots/test-user-001?limit=20')
        .expect(200);

      expect(weakSpotScoringService.getUserWeakSpots).toHaveBeenCalledWith(
        'test-user-001',
        expect.objectContaining({ limit: 20 })
      );
    });

    test('should return 403 when userId mismatch', async () => {
      const response = await request(app)
        .get('/api/weak-spots/other-user')
        .expect(403);

      expect(response.body.success).toBe(false);
    });

    test('should return 400 for invalid nodeState', async () => {
      const response = await request(app)
        .get('/api/weak-spots/test-user-001?nodeState=invalid')
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should return 400 for invalid limit', async () => {
      const response = await request(app)
        .get('/api/weak-spots/test-user-001?limit=100')
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should return empty array when no weak spots', async () => {
      weakSpotScoringService.getUserWeakSpots.mockResolvedValue([]);

      const response = await request(app)
        .get('/api/weak-spots/test-user-001')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.weakSpots).toEqual([]);
      expect(response.body.data.totalCount).toBe(0);
    });
  });

  describe('POST /api/weak-spots/events', () => {
    test('should log engagement event successfully', async () => {
      weakSpotScoringService.logEngagementEvent.mockResolvedValue();

      const response = await request(app)
        .post('/api/weak-spots/events')
        .send({
          nodeId: 'PHY_LOM_001',
          eventType: 'capsule_opened',
          capsuleId: 'capsule-001'
        })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(weakSpotScoringService.logEngagementEvent).toHaveBeenCalledWith(
        'test-user-001',
        'PHY_LOM_001',
        'capsule_opened',
        'capsule-001'
      );
    });

    test('should log event without capsuleId', async () => {
      weakSpotScoringService.logEngagementEvent.mockResolvedValue();

      const response = await request(app)
        .post('/api/weak-spots/events')
        .send({
          nodeId: 'PHY_LOM_001',
          eventType: 'weak_spot_detected'
        })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(weakSpotScoringService.logEngagementEvent).toHaveBeenCalledWith(
        'test-user-001',
        'PHY_LOM_001',
        'weak_spot_detected',
        undefined
      );
    });

    test('should return 400 for invalid eventType', async () => {
      weakSpotScoringService.logEngagementEvent.mockRejectedValue(
        new Error('Invalid eventType: unknown_event')
      );

      const response = await request(app)
        .post('/api/weak-spots/events')
        .send({
          nodeId: 'PHY_LOM_001',
          eventType: 'unknown_event'
        })
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should return 400 when nodeId missing', async () => {
      const response = await request(app)
        .post('/api/weak-spots/events')
        .send({
          eventType: 'capsule_opened'
        })
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should return 400 when eventType missing', async () => {
      const response = await request(app)
        .post('/api/weak-spots/events')
        .send({
          nodeId: 'PHY_LOM_001'
        })
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should return 401 when not authenticated', async () => {
      const response = await request(app)
        .post('/api/weak-spots/events')
        .set('x-test-auth-fail', 'true')
        .send({
          nodeId: 'PHY_LOM_001',
          eventType: 'capsule_opened'
        })
        .expect(401);

      expect(response.body.success).toBe(false);
    });
  });

  describe('Error handling', () => {
    test('should handle service errors gracefully', async () => {
      weakSpotScoringService.getUserWeakSpots.mockRejectedValue(
        new Error('Firestore timeout')
      );

      const response = await request(app)
        .get('/api/weak-spots/test-user-001')
        .expect(500);

      expect(response.body.success).toBe(false);
    });

    test('should handle database errors on capsule fetch', async () => {
      mockGet.mockRejectedValue(new Error('Database connection error'));

      const response = await request(app)
        .get('/api/capsules/capsule-001')
        .expect(500);

      expect(response.body.success).toBe(false);
    });
  });
});
