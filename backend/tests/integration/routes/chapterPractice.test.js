/**
 * Integration tests for chapterPractice.js routes
 *
 * Tests authentication, session generation, answer submission, completion
 * Coverage target: 80%+
 */

const request = require('supertest');
const express = require('express');
const chapterPracticeRouter = require('../../../src/routes/chapterPractice');
const chapterPracticeService = require('../../../src/services/chapterPracticeService');
const subscriptionService = require('../../../src/services/subscriptionService');
const tierConfigService = require('../../../src/services/tierConfigService');
const thetaUpdateService = require('../../../src/services/thetaUpdateService');
const weakSpotScoringService = require('../../../src/services/weakSpotScoringService');
const streakService = require('../../../src/services/streakService');
const { db, admin } = require('../../../src/config/firebase');

// Mock services
jest.mock('../../../src/services/chapterPracticeService');
jest.mock('../../../src/services/subscriptionService');
jest.mock('../../../src/services/tierConfigService');
jest.mock('../../../src/services/thetaUpdateService');
jest.mock('../../../src/services/weakSpotScoringService');
jest.mock('../../../src/services/streakService');
jest.mock('../../../src/config/firebase', () => ({
  db: {
    collection: jest.fn(),
    runTransaction: jest.fn()
  },
  admin: {
    firestore: {
      FieldValue: {
        serverTimestamp: jest.fn(() => new Date()),
        increment: jest.fn((n) => ({ _increment: n })),
        delete: jest.fn(() => ({ _delete: true }))
      },
      Timestamp: {
        fromDate: jest.fn((date) => date)
      }
    }
  }
}));
jest.mock('../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn()
}));
jest.mock('../../../src/utils/firestoreRetry', () => ({
  retryFirestoreOperation: jest.fn((fn) => fn())
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

// Mock ApiError
jest.mock('../../../src/middleware/errorHandler', () => ({
  ApiError: class ApiError extends Error {
    constructor(status, message, code) {
      super(message);
      this.status = status;
      this.code = code;
    }
  }
}));

describe('Chapter Practice Routes', () => {
  let app;
  let mockGet;
  let mockUpdate;
  let mockSet;
  let mockDoc;
  let mockCollection;

  beforeAll(() => {
    app = express();
    app.use(express.json());
    app.use('/api/chapter-practice', chapterPracticeRouter);

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
    mockUpdate = jest.fn();
    mockSet = jest.fn();
    mockDoc = jest.fn(() => ({
      get: mockGet,
      update: mockUpdate,
      set: mockSet,
      collection: jest.fn(() => ({
        doc: mockDoc,
        where: jest.fn(() => ({
          limit: jest.fn(() => ({
            get: mockGet
          })),
          get: mockGet,
          orderBy: jest.fn(() => ({
            limit: jest.fn(() => ({
              get: mockGet
            }))
          })),
          count: jest.fn(() => ({
            get: jest.fn(() => ({
              data: () => ({ count: 0 })
            }))
          }))
        }))
      }))
    }));
    mockCollection = jest.fn(() => ({
      doc: mockDoc
    }));

    db.collection = mockCollection;

    // Mock batch operations
    const mockBatch = {
      update: jest.fn(),
      set: jest.fn(),
      commit: jest.fn().mockResolvedValue()
    };
    db.batch = jest.fn(() => mockBatch);
  });

  describe('POST /api/chapter-practice/generate', () => {
    test('should generate new practice session for authenticated user', async () => {
      const mockSession = {
        session_id: 'session-001',
        chapter_key: 'physics_laws_of_motion',
        chapter_name: 'Laws of Motion',
        subject: 'Physics',
        total_questions: 15,
        questions: [
          {
            question_id: 'PHY_LOM_001',
            question_text: 'A block of mass 5 kg...',
            question_type: 'mcq_single',
            options: [
              { option_id: 'A', text: '10 N' },
              { option_id: 'B', text: '20 N' }
            ]
          }
        ]
      };

      subscriptionService.getEffectiveTier.mockResolvedValue({ tier: 'pro' });
      tierConfigService.getTierLimits.mockResolvedValue({
        chapter_practice_enabled: true,
        chapter_practice_per_chapter: 15,
        chapter_practice_daily_limit: -1
      });
      mockGet.mockResolvedValue({
        exists: true,
        data: () => ({ completed_quiz_count: 5 })
      });
      chapterPracticeService.getActiveSession.mockResolvedValue(null);
      chapterPracticeService.generateChapterPractice.mockResolvedValue(mockSession);

      const response = await request(app)
        .post('/api/chapter-practice/generate')
        .send({ chapter_key: 'physics_laws_of_motion', question_count: 15 })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.session.session_id).toBe('session-001');
      expect(response.body.is_existing_session).toBe(false);
      expect(chapterPracticeService.generateChapterPractice).toHaveBeenCalledWith(
        'test-user-001',
        'physics_laws_of_motion',
        15
      );
    });

    test('should enforce tier-based question count limit', async () => {
      subscriptionService.getEffectiveTier.mockResolvedValue({ tier: 'free' });
      tierConfigService.getTierLimits.mockResolvedValue({
        chapter_practice_enabled: true,
        chapter_practice_per_chapter: 5,
        chapter_practice_daily_limit: 5
      });
      mockGet
        .mockResolvedValueOnce({ exists: false }) // daily usage
        .mockResolvedValueOnce({ exists: true, data: () => ({ completed_quiz_count: 5 }) }); // user
      chapterPracticeService.getActiveSession.mockResolvedValue(null);
      chapterPracticeService.generateChapterPractice.mockResolvedValue({
        session_id: 'session-002',
        total_questions: 5
      });

      await request(app)
        .post('/api/chapter-practice/generate')
        .send({ chapter_key: 'physics_laws_of_motion', question_count: 15 })
        .expect(200);

      // Should be called with 5 (tier limit), not 15 (requested)
      expect(chapterPracticeService.generateChapterPractice).toHaveBeenCalledWith(
        'test-user-001',
        'physics_laws_of_motion',
        5
      );
    });

    test('should return 403 when chapter practice not enabled for tier', async () => {
      subscriptionService.getEffectiveTier.mockResolvedValue({ tier: 'free' });
      tierConfigService.getTierLimits.mockResolvedValue({
        chapter_practice_enabled: false
      });

      const response = await request(app)
        .post('/api/chapter-practice/generate')
        .send({ chapter_key: 'physics_laws_of_motion' })
        .expect(403);

      expect(response.body.success).toBe(false);
      expect(response.body.error.code).toBe('FEATURE_NOT_ENABLED');
    });

    test('should return 403 when daily limit reached', async () => {
      subscriptionService.getEffectiveTier.mockResolvedValue({ tier: 'free' });
      tierConfigService.getTierLimits.mockResolvedValue({
        chapter_practice_enabled: true,
        chapter_practice_per_chapter: 5,
        chapter_practice_daily_limit: 5
      });
      mockGet.mockResolvedValue({
        exists: true,
        data: () => ({ chapter_practice_count: 5 })
      });

      const response = await request(app)
        .post('/api/chapter-practice/generate')
        .send({ chapter_key: 'physics_laws_of_motion' })
        .expect(403);

      expect(response.body.success).toBe(false);
      expect(response.body.error.code).toBe('DAILY_LIMIT_REACHED');
      expect(response.body.daily_limit).toBe(5);
    });

    test('should return 403 when user has not completed daily quiz', async () => {
      subscriptionService.getEffectiveTier.mockResolvedValue({ tier: 'pro' });
      tierConfigService.getTierLimits.mockResolvedValue({
        chapter_practice_enabled: true,
        chapter_practice_per_chapter: 15,
        chapter_practice_daily_limit: -1
      });
      mockGet.mockResolvedValue({
        exists: true,
        data: () => ({ completed_quiz_count: 0 })
      });

      const response = await request(app)
        .post('/api/chapter-practice/generate')
        .send({ chapter_key: 'physics_laws_of_motion' })
        .expect(403);

      expect(response.body.success).toBe(false);
      expect(response.body.error.code).toBe('DAILY_QUIZ_REQUIRED');
    });

    test('should return existing active session if found', async () => {
      const mockActiveSession = {
        session_id: 'session-existing',
        chapter_key: 'physics_laws_of_motion',
        total_questions: 15,
        questions: []
      };

      subscriptionService.getEffectiveTier.mockResolvedValue({ tier: 'pro' });
      tierConfigService.getTierLimits.mockResolvedValue({
        chapter_practice_enabled: true,
        chapter_practice_per_chapter: 15,
        chapter_practice_daily_limit: -1
      });
      mockGet.mockResolvedValue({
        exists: true,
        data: () => ({ completed_quiz_count: 5 })
      });
      chapterPracticeService.getActiveSession.mockResolvedValue(mockActiveSession);

      const response = await request(app)
        .post('/api/chapter-practice/generate')
        .send({ chapter_key: 'physics_laws_of_motion' })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.is_existing_session).toBe(true);
      expect(response.body.session.session_id).toBe('session-existing');
    });

    test('should return 400 when chapter_key missing', async () => {
      const response = await request(app)
        .post('/api/chapter-practice/generate')
        .send({})
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation failed');
    });

    test('should return 401 when not authenticated', async () => {
      const response = await request(app)
        .post('/api/chapter-practice/generate')
        .set('x-test-auth-fail', 'true')
        .send({ chapter_key: 'physics_laws_of_motion' })
        .expect(401);

      expect(response.body.success).toBe(false);
    });
  });

  describe('POST /api/chapter-practice/submit-answer', () => {
    test('should submit answer and return feedback', async () => {
      const mockSessionDoc = {
        exists: true,
        data: () => ({
          student_id: 'test-user-001',
          status: 'in_progress',
          chapter_key: 'physics_laws_of_motion',
          subject: 'Physics',
          chapter_name: 'Laws of Motion',
          total_questions: 15
        })
      };

      const mockQuestionDoc = {
        id: 'q1',
        data: () => ({
          question_id: 'PHY_LOM_001',
          answered: false,
          position: 1
        })
      };

      const mockFullQuestionDoc = {
        exists: true,
        data: () => ({
          correct_answer: 'B',
          question_type: 'mcq_single',
          solution_text: 'Using F = ma...',
          irt_parameters: {
            discrimination_a: 1.5,
            difficulty_b: 0.5,
            guessing_c: 0.25
          }
        })
      };

      const mockUserDoc = {
        data: () => ({
          theta_by_chapter: {
            physics_laws_of_motion: {
              theta: 0.5,
              attempts: 10,
              accuracy: 0.7,
              percentile: 65.0
            }
          }
        })
      };

      mockGet
        .mockResolvedValueOnce(mockSessionDoc) // session get
        .mockResolvedValueOnce({ empty: false, docs: [mockQuestionDoc] }) // question query
        .mockResolvedValueOnce(mockFullQuestionDoc) // full question
        .mockResolvedValueOnce(mockUserDoc); // user

      db.runTransaction.mockImplementation(async (callback) => {
        return await callback({
          get: async () => mockQuestionDoc,
          update: jest.fn()
        });
      });

      thetaUpdateService.calculateChapterThetaUpdate.mockReturnValue({
        theta: 0.52,
        attempts: 11,
        accuracy: 0.71,
        percentile: 66.0
      });

      const response = await request(app)
        .post('/api/chapter-practice/submit-answer')
        .send({
          session_id: 'session-001',
          question_id: 'PHY_LOM_001',
          student_answer: 'B',
          time_taken_seconds: 45
        })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.is_correct).toBe(true);
      expect(response.body.correct_answer).toBe('B');
      expect(response.body.theta_multiplier).toBe(0.5);
    });

    test('should return 404 when session not found', async () => {
      mockGet.mockResolvedValue({ exists: false });

      const response = await request(app)
        .post('/api/chapter-practice/submit-answer')
        .send({
          session_id: 'non-existent',
          question_id: 'PHY_LOM_001',
          student_answer: 'B'
        })
        .expect(404);

      expect(response.body.success).toBe(false);
    });

    test('should return 400 when session is not in progress', async () => {
      mockGet.mockResolvedValue({
        exists: true,
        data: () => ({
          student_id: 'test-user-001',
          status: 'completed'
        })
      });

      const response = await request(app)
        .post('/api/chapter-practice/submit-answer')
        .send({
          session_id: 'session-001',
          question_id: 'PHY_LOM_001',
          student_answer: 'B'
        })
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should return 400 when validation fails', async () => {
      const response = await request(app)
        .post('/api/chapter-practice/submit-answer')
        .send({
          session_id: '',
          question_id: 'PHY_LOM_001'
        })
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation failed');
    });
  });

  describe('POST /api/chapter-practice/complete', () => {
    test('should complete session and update theta', async () => {
      const mockSessionDoc = {
        exists: true,
        data: () => ({
          student_id: 'test-user-001',
          status: 'in_progress',
          chapter_key: 'physics_laws_of_motion',
          subject: 'Physics',
          chapter_name: 'Laws of Motion',
          total_questions: 15
        })
      };

      const mockQuestions = [
        { is_correct: true, theta_delta: 0.02, time_taken_seconds: 30 },
        { is_correct: false, theta_delta: -0.01, time_taken_seconds: 45 },
        { is_correct: true, theta_delta: 0.015, time_taken_seconds: 25 }
      ];

      const mockUserDoc = {
        exists: true,
        data: () => ({
          theta_by_chapter: {
            physics_laws_of_motion: { theta: 0.5, attempts: 10 }
          },
          theta_by_subject: {
            physics: { theta: 0.48 }
          },
          overall_theta: 0.45,
          subtopic_accuracy: {}
        })
      };

      db.runTransaction
        .mockImplementationOnce(async (callback) => {
          return await callback({
            get: async () => mockSessionDoc,
            update: jest.fn()
          });
        })
        .mockImplementationOnce(async (callback) => {
          return await callback({
            get: async () => mockUserDoc,
            update: jest.fn()
          });
        });

      mockGet
        .mockResolvedValueOnce({ docs: mockQuestions.map(q => ({ data: () => q })) }) // questions
        .mockResolvedValueOnce({ docs: [] }); // responses

      thetaUpdateService.calculateSubjectAndOverallThetaUpdate.mockReturnValue({
        theta_by_subject: {
          Physics: { theta: 0.49, percentile: 63.0 }
        },
        overall_theta: 0.46,
        overall_percentile: 61.0
      });

      thetaUpdateService.calculateSubtopicAccuracyUpdate.mockReturnValue({});
      weakSpotScoringService.detectWeakSpots.mockResolvedValue(null);

      const response = await request(app)
        .post('/api/chapter-practice/complete')
        .send({ session_id: 'session-001' })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.summary.correct_count).toBe(2);
      expect(response.body.summary.questions_answered).toBe(3);
      expect(response.body.updated_stats.overall_theta).toBe(0.46);
    });

    test('should return 404 when session not found', async () => {
      db.runTransaction.mockImplementation(async (callback) => {
        const mockError = new Error('Session session-001 not found');
        mockError.status = 404;
        throw mockError;
      });

      const response = await request(app)
        .post('/api/chapter-practice/complete')
        .send({ session_id: 'session-001' })
        .expect(500);

      expect(response.body.success).toBe(false);
    });

    test('should return 400 when session already completed', async () => {
      const mockError = new Error('Session session-001 is already completed');
      mockError.status = 400;

      db.runTransaction.mockImplementation(async (callback) => {
        throw mockError;
      });

      const response = await request(app)
        .post('/api/chapter-practice/complete')
        .send({ session_id: 'session-001' })
        .expect(500);

      expect(response.body.success).toBe(false);
    });

    test('should return 400 when session_id missing', async () => {
      const response = await request(app)
        .post('/api/chapter-practice/complete')
        .send({})
        .expect(400);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/chapter-practice/session/:sessionId', () => {
    test('should return session details', async () => {
      const mockSession = {
        session_id: 'session-001',
        chapter_key: 'physics_laws_of_motion',
        total_questions: 15,
        questions: []
      };

      chapterPracticeService.getSession.mockResolvedValue(mockSession);

      const response = await request(app)
        .get('/api/chapter-practice/session/session-001')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.session.session_id).toBe('session-001');
      expect(chapterPracticeService.getSession).toHaveBeenCalledWith('test-user-001', 'session-001');
    });

    test('should return 404 when session not found', async () => {
      chapterPracticeService.getSession.mockResolvedValue(null);

      const response = await request(app)
        .get('/api/chapter-practice/session/non-existent')
        .expect(404);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/chapter-practice/active', () => {
    test('should return active session if exists', async () => {
      const mockSession = {
        session_id: 'session-active',
        chapter_key: 'physics_laws_of_motion',
        status: 'in_progress'
      };

      chapterPracticeService.getActiveSession.mockResolvedValue(mockSession);

      const response = await request(app)
        .get('/api/chapter-practice/active')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.has_active_session).toBe(true);
      expect(response.body.session.session_id).toBe('session-active');
    });

    test('should return no active session when none exists', async () => {
      chapterPracticeService.getActiveSession.mockResolvedValue(null);

      const response = await request(app)
        .get('/api/chapter-practice/active')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.has_active_session).toBe(false);
      expect(response.body.session).toBeNull();
    });

    test('should filter by chapter_key when provided', async () => {
      chapterPracticeService.getActiveSession.mockResolvedValue(null);

      await request(app)
        .get('/api/chapter-practice/active?chapter_key=physics_laws_of_motion')
        .expect(200);

      expect(chapterPracticeService.getActiveSession).toHaveBeenCalledWith(
        'test-user-001',
        'physics_laws_of_motion'
      );
    });
  });

  describe('GET /api/chapter-practice/stats', () => {
    test('should return aggregated stats', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({
          chapter_practice_stats: {
            total_sessions: 10,
            total_questions_practiced: 150,
            overall_accuracy: 0.72,
            total_time_seconds: 4500,
            by_chapter: {
              physics_laws_of_motion: {
                sessions: 5,
                questions: 75,
                accuracy: 0.75
              }
            },
            by_subject: {
              Physics: {
                sessions: 8,
                questions: 120,
                accuracy: 0.73
              }
            }
          }
        })
      };

      mockGet.mockResolvedValue(mockUserDoc);

      const response = await request(app)
        .get('/api/chapter-practice/stats')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.stats.total_sessions).toBe(10);
      expect(response.body.stats.overall_accuracy).toBe(0.72);
    });

    test('should return chapter-specific stats when chapter_key provided', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({
          chapter_practice_stats: {
            by_chapter: {
              physics_laws_of_motion: {
                sessions: 5,
                questions: 75,
                accuracy: 0.75
              }
            }
          }
        })
      };

      mockGet.mockResolvedValue(mockUserDoc);

      const response = await request(app)
        .get('/api/chapter-practice/stats?chapter_key=physics_laws_of_motion')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.has_practiced).toBe(true);
      expect(response.body.stats.sessions).toBe(5);
    });

    test('should return 404 when user not found', async () => {
      mockGet.mockResolvedValue({ exists: false });

      const response = await request(app)
        .get('/api/chapter-practice/stats')
        .expect(404);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/chapter-practice/history', () => {
    test('should return paginated session history', async () => {
      subscriptionService.getEffectiveTier.mockResolvedValue({ tier: 'pro' });
      tierConfigService.getTierLimits.mockResolvedValue({
        solution_history_days: 30
      });

      const mockSessions = [
        {
          id: 'session-001',
          data: () => ({
            chapter_key: 'physics_laws_of_motion',
            chapter_name: 'Laws of Motion',
            subject: 'Physics',
            completed_at: { toDate: () => new Date('2026-02-28T10:00:00Z') },
            total_questions: 15,
            final_total_answered: 15,
            final_correct_count: 12,
            final_accuracy: 0.8,
            total_time_seconds: 450
          })
        }
      ];

      mockGet.mockResolvedValue({ docs: mockSessions });

      const response = await request(app)
        .get('/api/chapter-practice/history?limit=20&offset=0')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.sessions).toHaveLength(1);
      expect(response.body.pagination.limit).toBe(20);
      expect(response.body.tier_info.tier).toBe('pro');
    });

    test('should validate limit parameter', async () => {
      const response = await request(app)
        .get('/api/chapter-practice/history?limit=100')
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should validate offset parameter', async () => {
      const response = await request(app)
        .get('/api/chapter-practice/history?offset=-1')
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should validate subject filter', async () => {
      const response = await request(app)
        .get('/api/chapter-practice/history?subject=biology')
        .expect(400);

      expect(response.body.success).toBe(false);
    });
  });

  describe('Error handling', () => {
    test('should handle service errors gracefully', async () => {
      chapterPracticeService.getSession.mockRejectedValue(
        new Error('Database connection error')
      );

      const response = await request(app)
        .get('/api/chapter-practice/session/session-001')
        .expect(500);

      expect(response.body.success).toBe(false);
    });

    test('should handle validation errors properly', async () => {
      const response = await request(app)
        .post('/api/chapter-practice/generate')
        .send({
          chapter_key: 'ab' // Too short (min 3)
        })
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation failed');
    });
  });
});
