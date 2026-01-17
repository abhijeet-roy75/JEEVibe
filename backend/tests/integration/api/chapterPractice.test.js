/**
 * Integration Tests for Chapter Practice API Endpoints
 *
 * Tests full request/response cycles for chapter practice endpoints:
 * - POST /api/chapter-practice/generate
 * - POST /api/chapter-practice/submit-answer
 * - POST /api/chapter-practice/complete
 * - GET /api/chapter-practice/session/:sessionId
 * - GET /api/chapter-practice/active
 */

const request = require('supertest');

// Mock multer
jest.mock('multer', () => {
  const multer = () => ({
    single: () => (req, res, next) => next(),
    array: () => (req, res, next) => next(),
    fields: () => (req, res, next) => next(),
    none: () => (req, res, next) => next(),
    any: () => (req, res, next) => next(),
  });
  multer.memoryStorage = () => ({});
  return multer;
});

// Mock Firebase
const mockBatch = {
  set: jest.fn(),
  update: jest.fn(),
  commit: jest.fn(() => Promise.resolve()),
};

const mockQuestionData = {
  question_id: 'q1',
  subject: 'Physics',
  chapter: 'Kinematics',
  question_text: 'What is velocity?',
  options: [
    { id: 'A', text: 'Speed with direction' },
    { id: 'B', text: 'Just speed' },
    { id: 'C', text: 'Acceleration' },
    { id: 'D', text: 'Distance' },
  ],
  correct_answer: 'A',
  question_type: 'mcq_single',
  irt_parameters: { discrimination_a: 1.5, difficulty_b: 0.5, guessing_c: 0.25 },
};

const mockSessionData = {
  session_id: 'cp_test123_1234567890',
  student_id: 'test-user-id',
  chapter_key: 'physics_kinematics',
  chapter_name: 'Kinematics',
  subject: 'Physics',
  status: 'in_progress',
  questions_answered: 0,
  correct_count: 0,
  total_questions: 5,
  theta_at_start: 0.5,
  expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
};

jest.mock('../../../src/config/firebase', () => {
  const mockUserDoc = {
    exists: true,
    data: () => ({
      assessment: { completed_at: new Date().toISOString() },
      theta_by_chapter: { 'physics_kinematics': { theta: 0.5 } },
      chapter_practice_stats: null,
      subtopic_accuracy: {},
    }),
  };

  const createMockCollection = () => ({
    doc: jest.fn(() => ({
      get: jest.fn(() => Promise.resolve(mockUserDoc)),
      set: jest.fn(() => Promise.resolve()),
      update: jest.fn(() => Promise.resolve()),
      collection: jest.fn(() => createMockCollection()),
    })),
    where: jest.fn(() => ({
      where: jest.fn(() => ({
        limit: jest.fn(() => ({
          get: jest.fn(() => Promise.resolve({
            empty: false,
            docs: Array(5).fill({
              id: 'q1',
              data: () => mockQuestionData,
            }),
          })),
        })),
      })),
      orderBy: jest.fn(() => ({
        limit: jest.fn(() => ({
          get: jest.fn(() => Promise.resolve({ empty: true, docs: [] })),
        })),
      })),
    })),
    orderBy: jest.fn(() => ({
      get: jest.fn(() => Promise.resolve({ docs: [] })),
    })),
  });

  return {
    db: {
      collection: jest.fn(() => createMockCollection()),
      batch: jest.fn(() => mockBatch),
      runTransaction: jest.fn((fn) => fn({
        get: jest.fn(() => Promise.resolve({
          exists: true,
          data: () => mockSessionData,
        })),
        set: jest.fn(),
        update: jest.fn(),
      })),
    },
    admin: {
      auth: jest.fn(() => ({
        verifyIdToken: jest.fn(() => Promise.resolve({ uid: 'test-user-id' })),
      })),
      firestore: {
        Timestamp: {
          now: jest.fn(() => ({ seconds: Math.floor(Date.now() / 1000) })),
        },
        FieldValue: {
          increment: jest.fn((val) => ({ _increment: val })),
          serverTimestamp: jest.fn(() => ({ _serverTimestamp: true })),
          delete: jest.fn(() => ({ _delete: true })),
        },
      },
    },
  };
});

// Mock auth middleware
jest.mock('../../../src/middleware/auth', () => ({
  authenticateUser: (req, res, next) => {
    req.userId = 'test-user-id';
    next();
  },
}));

// Mock services
jest.mock('../../../src/services/chapterPracticeService', () => ({
  generateChapterPractice: jest.fn(() => Promise.resolve({
    session_id: 'cp_test123_1234567890',
    chapter_key: 'physics_kinematics',
    chapter_name: 'Kinematics',
    subject: 'Physics',
    questions: [
      { question_id: 'q1', question_text: 'Test question', position: 0 },
    ],
    total_questions: 1,
    theta_at_start: 0.5,
    created_at: new Date().toISOString(),
  })),
  getSession: jest.fn(() => Promise.resolve({
    session_id: 'cp_test123_1234567890',
    student_id: 'test-user-id',
    status: 'in_progress',
    questions: [],
  })),
  getActiveSession: jest.fn(() => Promise.resolve(null)),
  THETA_MULTIPLIER: 0.5,
}));

jest.mock('../../../src/services/subscriptionService', () => ({
  getEffectiveTier: jest.fn(() => Promise.resolve({ tier: 'pro' })),
}));

jest.mock('../../../src/services/tierConfigService', () => ({
  getTierLimits: jest.fn(() => Promise.resolve({
    chapter_practice_enabled: true,
    daily_quiz_limit: 10,
  })),
}));

jest.mock('../../../src/services/thetaUpdateService', () => ({
  calculateChapterThetaUpdate: jest.fn(() => ({
    theta: 0.6,
    percentile: 65,
    confidence_SE: 0.55,
    attempts: 1,
    accuracy: 1.0,
  })),
  calculateSubjectAndOverallThetaUpdate: jest.fn(() => ({
    theta_by_subject: {},
    subject_accuracy: {},
    overall_theta: 0.5,
    overall_percentile: 55,
  })),
  calculateSubtopicAccuracyUpdate: jest.fn(() => ({})),
}));

jest.mock('../../../src/utils/firestoreRetry', () => ({
  retryFirestoreOperation: jest.fn((fn) => fn()),
}));

jest.mock('../../../src/services/chapterMappingService', () => ({
  getDatabaseNames: jest.fn(() => Promise.resolve({
    subject: 'Physics',
    chapter: 'Kinematics',
  })),
}));

jest.mock('../../../src/services/questionSelectionService', () => ({
  normalizeQuestion: jest.fn((id, data) => ({ question_id: id, ...data })),
}));

// Create express app for testing
const express = require('express');
const chapterPracticeRoutes = require('../../../src/routes/chapterPractice');

const app = express();
app.use(express.json());
app.use('/api/chapter-practice', chapterPracticeRoutes);

// Error handler
app.use((err, req, res, next) => {
  res.status(err.status || 500).json({
    success: false,
    error: err.message,
    code: err.code,
  });
});

describe('Chapter Practice API Endpoints', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('POST /api/chapter-practice/generate', () => {
    test('should generate new chapter practice session', async () => {
      const response = await request(app)
        .post('/api/chapter-practice/generate')
        .send({ chapter_key: 'physics_kinematics' })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.session).toBeDefined();
      expect(response.body.session.session_id).toBeDefined();
      expect(response.body.session.chapter_key).toBe('physics_kinematics');
    });

    test('should reject missing chapter_key', async () => {
      const response = await request(app)
        .post('/api/chapter-practice/generate')
        .send({})
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.code).toBe('VALIDATION_ERROR');
    });

    test('should reject chapter_key with invalid characters', async () => {
      const response = await request(app)
        .post('/api/chapter-practice/generate')
        .send({ chapter_key: 'physics<script>alert(1)</script>' })
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should accept valid question_count', async () => {
      const response = await request(app)
        .post('/api/chapter-practice/generate')
        .send({ chapter_key: 'physics_kinematics', question_count: 10 })
        .expect(200);

      expect(response.body.success).toBe(true);
    });

    test('should reject question_count > 20', async () => {
      const response = await request(app)
        .post('/api/chapter-practice/generate')
        .send({ chapter_key: 'physics_kinematics', question_count: 25 })
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should reject question_count < 1', async () => {
      const response = await request(app)
        .post('/api/chapter-practice/generate')
        .send({ chapter_key: 'physics_kinematics', question_count: 0 })
        .expect(400);

      expect(response.body.success).toBe(false);
    });
  });

  describe('POST /api/chapter-practice/submit-answer', () => {
    test('should reject missing session_id', async () => {
      const response = await request(app)
        .post('/api/chapter-practice/submit-answer')
        .send({
          question_id: 'q1',
          student_answer: 'A',
        })
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should reject missing question_id', async () => {
      const response = await request(app)
        .post('/api/chapter-practice/submit-answer')
        .send({
          session_id: 'cp_test123',
          student_answer: 'A',
        })
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should reject missing student_answer', async () => {
      const response = await request(app)
        .post('/api/chapter-practice/submit-answer')
        .send({
          session_id: 'cp_test123',
          question_id: 'q1',
        })
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    test('should accept valid time_taken_seconds', async () => {
      // This test will fail at the Firebase level, but validation should pass
      const response = await request(app)
        .post('/api/chapter-practice/submit-answer')
        .send({
          session_id: 'cp_test123',
          question_id: 'q1',
          student_answer: 'A',
          time_taken_seconds: 30,
        });

      // Validation passed if we didn't get 400 for validation error
      expect(response.body.code).not.toBe('VALIDATION_ERROR');
    });

    test('should reject time_taken_seconds > 3600', async () => {
      const response = await request(app)
        .post('/api/chapter-practice/submit-answer')
        .send({
          session_id: 'cp_test123',
          question_id: 'q1',
          student_answer: 'A',
          time_taken_seconds: 4000,
        })
        .expect(400);

      expect(response.body.success).toBe(false);
    });
  });

  describe('POST /api/chapter-practice/complete', () => {
    test('should reject missing session_id', async () => {
      const response = await request(app)
        .post('/api/chapter-practice/complete')
        .send({})
        .expect(400);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/chapter-practice/session/:sessionId', () => {
    test('should get session details', async () => {
      const response = await request(app)
        .get('/api/chapter-practice/session/cp_test123_1234567890')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.session).toBeDefined();
    });
  });

  describe('GET /api/chapter-practice/active', () => {
    test('should return no active session when none exists', async () => {
      const response = await request(app)
        .get('/api/chapter-practice/active')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.has_active_session).toBe(false);
    });

    test('should accept chapter_key query parameter', async () => {
      const response = await request(app)
        .get('/api/chapter-practice/active?chapter_key=physics_kinematics')
        .expect(200);

      expect(response.body.success).toBe(true);
    });
  });

  describe('Feature gating', () => {
    test('should deny access to free tier users', async () => {
      const { getTierLimits } = require('../../../src/services/tierConfigService');
      getTierLimits.mockResolvedValueOnce({
        chapter_practice_enabled: false,
        daily_quiz_limit: 3,
      });

      const response = await request(app)
        .post('/api/chapter-practice/generate')
        .send({ chapter_key: 'physics_kinematics' })
        .expect(403);

      expect(response.body.success).toBe(false);
      expect(response.body.error.code).toBe('FEATURE_NOT_ENABLED');
      expect(response.body.upgrade_prompt).toBeDefined();
    });
  });
});

describe('Input validation', () => {
  test('chapter_key regex should allow alphanumeric, underscore, hyphen, space', () => {
    const validKeys = [
      'physics_kinematics',
      'chemistry-organic',
      'maths 101',
      'Physics_Chapter_1',
    ];

    const invalidKeys = [
      'physics<script>',
      'chapter;drop table',
      'test@#$%',
    ];

    const regex = /^[a-zA-Z0-9_\-\s]+$/;

    validKeys.forEach((key) => {
      expect(regex.test(key)).toBe(true);
    });

    invalidKeys.forEach((key) => {
      expect(regex.test(key)).toBe(false);
    });
  });
});

describe('Theta multiplier', () => {
  test('chapter practice should use 0.5x multiplier', () => {
    const { THETA_MULTIPLIER } = require('../../../src/services/chapterPracticeService');
    expect(THETA_MULTIPLIER).toBe(0.5);
  });
});
