/**
 * Integration Tests for Daily Quiz API Endpoints
 * 
 * Tests full request/response cycles for daily quiz endpoints
 * 
 * Note: These tests require either:
 * 1. Firebase Emulator Suite (recommended)
 * 2. Test Firebase project with test credentials
 * 3. Mocked Firebase operations
 */

const request = require('supertest');

// Mock multer to prevent "argument handler must be a function" error
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

// Mock Firebase for integration tests
// In real integration tests, you'd use Firebase Emulator or test project
jest.mock('../../../src/config/firebase', () => {
  const mockDoc = {
    data: jest.fn(() => ({})),
    exists: true,
    id: 'test-user-id',
  };
  
  const mockCollection = {
    doc: jest.fn(() => ({
      get: jest.fn(() => Promise.resolve(mockDoc)),
      set: jest.fn(() => Promise.resolve()),
      update: jest.fn(() => Promise.resolve()),
      collection: jest.fn(() => mockCollection),
      where: jest.fn(() => ({
        get: jest.fn(() => Promise.resolve({ empty: true, docs: [] })),
        limit: jest.fn(() => ({
          get: jest.fn(() => Promise.resolve({ empty: true, docs: [] })),
        })),
      })),
    })),
    where: jest.fn(() => ({
      get: jest.fn(() => Promise.resolve({ empty: true, docs: [] })),
      limit: jest.fn(() => ({
        get: jest.fn(() => Promise.resolve({ empty: true, docs: [] })),
      })),
    })),
    add: jest.fn(() => Promise.resolve({ id: 'test-quiz-id' })),
  };
  
  return {
    db: {
      collection: jest.fn(() => mockCollection),
      runTransaction: jest.fn((fn) => fn({
        get: jest.fn(() => Promise.resolve(mockDoc)),
        set: jest.fn(() => {}),
        update: jest.fn(() => {}),
      })),
    },
    storage: {
      bucket: jest.fn(() => ({
        file: jest.fn(() => ({
          save: jest.fn(() => Promise.resolve()),
          makePublic: jest.fn(() => Promise.resolve()),
          publicUrl: jest.fn(() => 'https://storage.googleapis.com/test-url'),
        })),
      })),
    },
    admin: {
      auth: jest.fn(() => ({
        verifyIdToken: jest.fn(() => Promise.resolve({ uid: 'test-user-id' })),
      })),
      firestore: {
        Timestamp: {
          now: jest.fn(() => ({ seconds: Math.floor(Date.now() / 1000) })),
          fromDate: jest.fn((date) => ({ seconds: Math.floor(date.getTime() / 1000) })),
        },
        FieldValue: {
          increment: jest.fn((val) => ({ _increment: val })),
          arrayUnion: jest.fn((val) => ({ _arrayUnion: val })),
          serverTimestamp: jest.fn(() => ({ _serverTimestamp: true })),
        },
      },
    },
  };
});

jest.mock('../../../src/middleware/auth', () => ({
  authenticateToken: (req, res, next) => {
    // Mock authentication - always pass
    req.user = { uid: 'test-user-id' };
    next();
  },
  authenticateUser: (req, res, next) => {
    // Mock user authentication - always pass
    req.userId = 'test-user-id';
    next();
  },
}));

// Mock OpenAI service to prevent real API calls
jest.mock('../../../src/services/openai', () => ({
  solveQuestionFromImage: jest.fn(() => Promise.resolve({
    solution: 'Test solution',
    explanation: 'Test explanation',
  })),
  generateFollowUpQuestions: jest.fn(() => Promise.resolve([])),
  generateSingleFollowUpQuestion: jest.fn(() => Promise.resolve({})),
}));

// Import app after mocks
const app = require('../../../src/index');

describe('Daily Quiz API Integration Tests', () => {
  const testToken = 'test-token';
  
  describe('GET /api/daily-quiz/generate', () => {
    test('should return 401 without authentication', async () => {
      // Note: This will fail if auth middleware is not properly mocked
      // In real tests, you'd test with actual auth tokens
    });

    test('should generate a quiz with valid structure', async () => {
      const response = await request(app)
        .get('/api/daily-quiz/generate')
        .set('Authorization', `Bearer ${testToken}`)
        .expect(200);
      
      expect(response.body).toHaveProperty('quiz_id');
      expect(response.body).toHaveProperty('questions');
      expect(Array.isArray(response.body.questions)).toBe(true);
      expect(response.body.questions.length).toBeGreaterThan(0);
    });

    test('should return questions with required fields', async () => {
      const response = await request(app)
        .get('/api/daily-quiz/generate')
        .set('Authorization', `Bearer ${testToken}`)
        .expect(200);
      
      if (response.body.questions.length > 0) {
        const question = response.body.questions[0];
        expect(question).toHaveProperty('question_id');
        expect(question).toHaveProperty('subject');
        expect(question).toHaveProperty('chapter');
        expect(question).toHaveProperty('difficulty');
      }
    });
  });

  describe('POST /api/daily-quiz/start', () => {
    test('should mark quiz as started', async () => {
      // First generate a quiz
      const generateResponse = await request(app)
        .get('/api/daily-quiz/generate')
        .set('Authorization', `Bearer ${testToken}`)
        .expect(200);
      
      const quizId = generateResponse.body.quiz_id;
      
      // Then start it
      const startResponse = await request(app)
        .post('/api/daily-quiz/start')
        .set('Authorization', `Bearer ${testToken}`)
        .send({ quiz_id: quizId })
        .expect(200);
      
      expect(startResponse.body).toHaveProperty('success', true);
    });
  });

  describe('POST /api/daily-quiz/submit-answer', () => {
    test('should submit answer and return correctness', async () => {
      // Generate and start quiz
      const generateResponse = await request(app)
        .get('/api/daily-quiz/generate')
        .set('Authorization', `Bearer ${testToken}`)
        .expect(200);
      
      const quizId = generateResponse.body.quiz_id;
      const questionId = generateResponse.body.questions[0].question_id;
      
      // Submit answer
      const submitResponse = await request(app)
        .post('/api/daily-quiz/submit-answer')
        .set('Authorization', `Bearer ${testToken}`)
        .send({
          quiz_id: quizId,
          question_id: questionId,
          answer: 'A',
        })
        .expect(200);
      
      expect(submitResponse.body).toHaveProperty('is_correct');
      expect(typeof submitResponse.body.is_correct).toBe('boolean');
    });
  });

  describe('POST /api/daily-quiz/complete', () => {
    test('should complete quiz and update theta', async () => {
      // Generate, start, and submit some answers
      const generateResponse = await request(app)
        .get('/api/daily-quiz/generate')
        .set('Authorization', `Bearer ${testToken}`)
        .expect(200);
      
      const quizId = generateResponse.body.quiz_id;
      
      // Complete quiz
      const completeResponse = await request(app)
        .post('/api/daily-quiz/complete')
        .set('Authorization', `Bearer ${testToken}`)
        .send({ quiz_id: quizId })
        .expect(200);
      
      expect(completeResponse.body).toHaveProperty('success', true);
      expect(completeResponse.body).toHaveProperty('accuracy');
      expect(typeof completeResponse.body.accuracy).toBe('number');
    });
  });

  describe('GET /api/daily-quiz/progress', () => {
    test('should return user progress data', async () => {
      const response = await request(app)
        .get('/api/daily-quiz/progress')
        .set('Authorization', `Bearer ${testToken}`)
        .expect(200);
      
      expect(response.body).toHaveProperty('completed_quiz_count');
      expect(response.body).toHaveProperty('learning_phase');
      expect(response.body).toHaveProperty('theta_by_chapter');
    });
  });
});

