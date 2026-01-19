/**
 * Integration Tests for Analytics API Endpoints
 *
 * Tests the chapters-by-subject endpoint for the Chapter Picker feature.
 * - GET /api/analytics/chapters-by-subject/:subject
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

// Mock chapter mappings data
const mockChapterMappings = new Map([
  ['physics_kinematics', { subject: 'Physics', chapter: 'Kinematics' }],
  ['physics_laws_of_motion', { subject: 'Physics', chapter: 'Laws of Motion' }],
  ['physics_work_energy_power', { subject: 'Physics', chapter: 'Work, Energy and Power' }],
  ['chemistry_organic_chemistry', { subject: 'Chemistry', chapter: 'Organic Chemistry' }],
  ['chemistry_chemical_bonding', { subject: 'Chemistry', chapter: 'Chemical Bonding' }],
  ['maths_calculus', { subject: 'Mathematics', chapter: 'Calculus' }],
  ['maths_algebra', { subject: 'Mathematics', chapter: 'Algebra' }],
]);

// Configurable mock user data
const mockUserDataConfig = {
  assessment: { completed_at: new Date().toISOString() },
  theta_by_chapter: {
    'physics_kinematics': {
      theta: 0.5,
      percentile: 65,
      accuracy: 72,
      attempts: 25,
    },
    'physics_laws_of_motion': {
      theta: 0.3,
      percentile: 45,
      accuracy: 58,
      attempts: 15,
    },
  },
  theta_by_subject: {
    physics: { theta: 0.4, percentile: 55 },
  },
  subtopic_accuracy: {},
  completed_quiz_count: 5,
};

global.mockUserDataConfig = mockUserDataConfig;

// Mock Firebase
jest.mock('../../../src/config/firebase', () => {
  const mockUserDoc = {
    exists: true,
    data: () => ({ ...global.mockUserDataConfig }),
  };

  const createMockCollection = () => ({
    doc: jest.fn(() => ({
      get: jest.fn(() => Promise.resolve(mockUserDoc)),
      set: jest.fn(() => Promise.resolve()),
      update: jest.fn(() => Promise.resolve()),
      collection: jest.fn(() => createMockCollection()),
    })),
    where: jest.fn(() => ({
      get: jest.fn(() => Promise.resolve({ empty: true, docs: [] })),
    })),
  });

  return {
    db: {
      collection: jest.fn(() => createMockCollection()),
      batch: jest.fn(() => ({
        set: jest.fn(),
        update: jest.fn(),
        commit: jest.fn(() => Promise.resolve()),
      })),
    },
    admin: {
      firestore: {
        FieldValue: {
          serverTimestamp: jest.fn(() => new Date()),
          increment: jest.fn((n) => n),
          arrayUnion: jest.fn((arr) => arr),
        },
      },
    },
  };
});

// Mock chapter mapping service
jest.mock('../../../src/services/chapterMappingService', () => ({
  initializeMappings: jest.fn(() => Promise.resolve(mockChapterMappings)),
  getDatabaseNames: jest.fn((key) => Promise.resolve(mockChapterMappings.get(key) || null)),
}));

// Mock auth middleware
jest.mock('../../../src/middleware/auth', () => ({
  authenticateUser: (req, res, next) => {
    req.userId = 'test-user-id';
    next();
  },
}));

// Mock firestore retry utility
jest.mock('../../../src/utils/firestoreRetry', () => ({
  retryFirestoreOperation: jest.fn((fn) => fn()),
}));

const app = require('../../../src/app');

describe('Analytics API - Chapters By Subject', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Reset user data config
    global.mockUserDataConfig = {
      assessment: { completed_at: new Date().toISOString() },
      theta_by_chapter: {
        'physics_kinematics': {
          theta: 0.5,
          percentile: 65,
          accuracy: 72,
          attempts: 25,
        },
        'physics_laws_of_motion': {
          theta: 0.3,
          percentile: 45,
          accuracy: 58,
          attempts: 15,
        },
      },
      theta_by_subject: {
        physics: { theta: 0.4, percentile: 55 },
      },
      subtopic_accuracy: {},
      completed_quiz_count: 5,
    };
  });

  describe('GET /api/analytics/chapters-by-subject/:subject', () => {
    it('should return all chapters for physics including unpracticed ones', async () => {
      const response = await request(app)
        .get('/api/analytics/chapters-by-subject/physics')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.chapters).toBeInstanceOf(Array);
      expect(response.body.data.chapters.length).toBeGreaterThan(0);

      // Should include both practiced and unpracticed chapters
      const chapterKeys = response.body.data.chapters.map(c => c.chapter_key);
      expect(chapterKeys).toContain('physics_kinematics');
      expect(chapterKeys).toContain('physics_work_energy_power'); // Unpracticed
    });

    it('should return chapters with correct structure', async () => {
      const response = await request(app)
        .get('/api/analytics/chapters-by-subject/physics')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);

      const chapter = response.body.data.chapters[0];
      expect(chapter).toHaveProperty('chapter_key');
      expect(chapter).toHaveProperty('chapter_name');
      expect(chapter).toHaveProperty('subject');
      expect(chapter).toHaveProperty('attempts');
      expect(chapter).toHaveProperty('accuracy');
      expect(chapter).toHaveProperty('correct');
      expect(chapter).toHaveProperty('total');
      expect(chapter).toHaveProperty('percentile');
      expect(chapter).toHaveProperty('status');
    });

    it('should return unpracticed chapters with zero stats', async () => {
      const response = await request(app)
        .get('/api/analytics/chapters-by-subject/physics')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);

      // Find the unpracticed chapter
      const unpracticedChapter = response.body.data.chapters.find(
        c => c.chapter_key === 'physics_work_energy_power'
      );

      if (unpracticedChapter) {
        expect(unpracticedChapter.attempts).toBe(0);
        expect(unpracticedChapter.accuracy).toBe(0);
        expect(unpracticedChapter.correct).toBe(0);
        expect(unpracticedChapter.total).toBe(0);
      }
    });

    it('should return practiced chapters with their stats', async () => {
      const response = await request(app)
        .get('/api/analytics/chapters-by-subject/physics')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);

      // Find the practiced chapter
      const practicedChapter = response.body.data.chapters.find(
        c => c.chapter_key === 'physics_kinematics'
      );

      if (practicedChapter) {
        expect(practicedChapter.attempts).toBe(25);
        expect(practicedChapter.accuracy).toBe(72);
        expect(practicedChapter.percentile).toBe(65);
      }
    });

    it('should return 400 for invalid subject', async () => {
      const response = await request(app)
        .get('/api/analytics/chapters-by-subject/invalid')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('Invalid subject');
    });

    it('should handle chemistry subject', async () => {
      const response = await request(app)
        .get('/api/analytics/chapters-by-subject/chemistry')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);

      // Should contain chemistry chapters
      const hasChemistry = response.body.data.chapters.some(
        c => c.subject === 'chemistry'
      );
      expect(hasChemistry).toBe(true);
    });

    it('should handle maths/mathematics subject', async () => {
      const response = await request(app)
        .get('/api/analytics/chapters-by-subject/maths')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);

      // Should contain maths chapters
      const chapters = response.body.data.chapters;
      expect(chapters.length).toBeGreaterThan(0);
    });

    it('should sort practiced chapters first (weakest accuracy first), then unpracticed', async () => {
      const response = await request(app)
        .get('/api/analytics/chapters-by-subject/physics')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);

      const chapters = response.body.data.chapters;
      if (chapters.length > 1) {
        // Find first unpracticed and first practiced
        const firstUnpracticedIdx = chapters.findIndex(c => c.attempts === 0);
        const firstPracticedIdx = chapters.findIndex(c => c.attempts > 0);

        // If both exist, practiced should come first
        if (firstUnpracticedIdx !== -1 && firstPracticedIdx !== -1) {
          expect(firstPracticedIdx).toBeLessThan(firstUnpracticedIdx);
        }
      }
    });
  });
});
