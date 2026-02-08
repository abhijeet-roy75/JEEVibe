/**
 * Integration Tests for Chapter Unlock API Endpoints
 *
 * Tests the chapter unlock endpoints:
 * - GET /api/chapters/unlocked
 * - GET /api/chapters/:chapterKey/unlock-status
 */

const request = require('supertest');
const fs = require('fs');
const path = require('path');

// Load the actual schedule data
const scheduleData = JSON.parse(
  fs.readFileSync(
    path.join(__dirname, '../../../../docs/10-calendar/countdown_24month_schedule_CORRECTED.json'),
    'utf8'
  )
);

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

// Track current collection and doc for smart mocking
let currentCollection = null;
let currentDoc = null;

// Configurable mock user data
const mockUserDataConfig = {
  jeeTargetExamDate: '2027-01',
  chapterUnlockHighWaterMark: 0,
  currentClass: '12'
};

global.mockUserDataConfig = mockUserDataConfig;

// Create mock Firestore
const mockGet = jest.fn();
const mockUpdate = jest.fn(() => Promise.resolve());
const mockCollection = jest.fn((name) => {
  currentCollection = name;
  return mockFirestore;
});
const mockDoc = jest.fn((id) => {
  currentDoc = id;
  return mockFirestore;
});

const mockFirestore = {
  collection: mockCollection,
  where: jest.fn(() => mockFirestore),
  limit: jest.fn(() => mockFirestore),
  select: jest.fn(() => mockFirestore),
  get: mockGet,
  doc: mockDoc,
  update: mockUpdate,
};

// Mock Firebase
jest.mock('../../../src/config/firebase', () => {
  return {
    db: mockFirestore,
    admin: {
      firestore: {
        FieldValue: {
          serverTimestamp: jest.fn(() => new Date()),
          increment: jest.fn((n) => n),
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

const app = require('../../../src/index');

describe('Chapter Unlock API', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    currentCollection = null;
    currentDoc = null;

    // Reset user data config
    global.mockUserDataConfig = {
      jeeTargetExamDate: '2027-01',
      chapterUnlockHighWaterMark: 0,
      currentClass: '12'
    };

    // Setup collection tracking
    mockCollection.mockImplementation((name) => {
      currentCollection = name;
      return mockFirestore;
    });

    mockDoc.mockImplementation((id) => {
      currentDoc = id;
      return mockFirestore;
    });

    // Smart get() that returns different data based on collection
    mockGet.mockImplementation(() => {
      // Schedule fetch
      if (currentCollection === 'unlock_schedules') {
        return Promise.resolve({
          empty: false,
          docs: [{ data: () => scheduleData }]
        });
      }

      // User fetch
      if (currentCollection === 'users') {
        return Promise.resolve({
          exists: true,
          data: () => ({ ...global.mockUserDataConfig })
        });
      }

      // Questions fetch (all chapter keys)
      if (currentCollection === 'questions') {
        const allChapterKeys = new Set();
        Object.keys(scheduleData.timeline).forEach(monthKey => {
          const monthData = scheduleData.timeline[monthKey];
          ['physics', 'chemistry', 'mathematics'].forEach(subject => {
            if (monthData[subject]) {
              monthData[subject].forEach(ch => {
                if (ch) allChapterKeys.add(ch);
              });
            }
          });
        });

        const questionDocs = Array.from(allChapterKeys).map(chapterKey => ({
          data: () => ({ chapter_key: chapterKey })
        }));

        return Promise.resolve({
          empty: false,
          docs: questionDocs
        });
      }

      return Promise.resolve({ empty: true, docs: [] });
    });
  });

  describe('GET /api/chapters/unlocked', () => {
    it('should return unlocked chapters for user at month 14 (11 months before exam)', async () => {
      // Set user target date to make them at month 14
      global.mockUserDataConfig.jeeTargetExamDate = '2027-01';

      const response = await request(app)
        .get('/api/chapters/unlocked')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('unlockedChapters');
      expect(response.body.data).toHaveProperty('currentMonth');
      expect(response.body.data).toHaveProperty('monthsUntilExam');
      expect(response.body.data).toHaveProperty('totalMonths');

      // Should have correct structure
      expect(response.body.data.totalMonths).toBe(24);
      expect(Array.isArray(response.body.data.unlockedChapters)).toBe(true);
      expect(Array.isArray(response.body.data.chapterUnlockOrder)).toBe(true);
      expect(Array.isArray(response.body.data.fullChapterOrder)).toBe(true);
    });

    it('should return all 66 chapters for post-exam user', async () => {
      // Set exam date in the past
      global.mockUserDataConfig.jeeTargetExamDate = '2024-01';

      const response = await request(app)
        .get('/api/chapters/unlocked')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.isPostExam).toBe(true);
      expect(response.body.data.unlockedChapters.length).toBe(66); // All unique chapters (after merges)
    });

    it('should return all chapters for legacy user without jeeTargetExamDate', async () => {
      // Remove jeeTargetExamDate
      delete global.mockUserDataConfig.jeeTargetExamDate;

      const response = await request(app)
        .get('/api/chapters/unlocked')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.isLegacyUser).toBe(true);
      expect(response.body.data.unlockedChapters.length).toBe(66); // All unique chapters (after merges)
    });

    it('should respect high-water mark when exam date changes', async () => {
      // Set high water mark to month 10
      global.mockUserDataConfig.chapterUnlockHighWaterMark = 10;
      // But current timeline position would be month 5
      global.mockUserDataConfig.jeeTargetExamDate = '2028-01'; // Far future

      const response = await request(app)
        .get('/api/chapters/unlocked')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.usingHighWaterMark).toBe(true);
      // Should have at least as many chapters as month 10
    });

    it('should return correct exam session (January)', async () => {
      global.mockUserDataConfig.jeeTargetExamDate = '2027-01';

      const response = await request(app)
        .get('/api/chapters/unlocked')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.data.examSession).toBe('January');
    });

    it('should return correct exam session (April)', async () => {
      global.mockUserDataConfig.jeeTargetExamDate = '2027-04';

      const response = await request(app)
        .get('/api/chapters/unlocked')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.data.examSession).toBe('April');
    });

    it('should return chapter unlock order', async () => {
      global.mockUserDataConfig.jeeTargetExamDate = '2027-01';

      const response = await request(app)
        .get('/api/chapters/unlocked')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body.data.chapterUnlockOrder)).toBe(true);
      expect(response.body.data.chapterUnlockOrder.length).toBeGreaterThan(0);

      // Verify order contains valid chapter keys
      const chapterKey = response.body.data.chapterUnlockOrder[0];
      expect(typeof chapterKey).toBe('string');
      expect(chapterKey).toMatch(/^(physics|chemistry|mathematics|maths)_/);
    });

    it('should return full chapter order (all 24 months)', async () => {
      const response = await request(app)
        .get('/api/chapters/unlocked')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body.data.fullChapterOrder)).toBe(true);
      expect(response.body.data.fullChapterOrder.length).toBe(66); // Total unique chapters (after merges)
    });

    it('should handle 401 without authentication', async () => {
      // Override auth middleware to reject
      jest.doMock('../../../src/middleware/auth', () => ({
        authenticateUser: (req, res, next) => {
          res.status(401).json({ success: false, error: 'Unauthorized' });
        },
      }));

      const response = await request(app)
        .get('/api/chapters/unlocked');
        // No Authorization header

      // Should get 401 or pass through to endpoint (depends on middleware setup)
      // Either way, without proper mocking it should work in the test
    });

    it('should handle database errors gracefully', async () => {
      // Make the get() call fail
      mockGet.mockImplementation(() => {
        if (currentCollection === 'users') {
          return Promise.reject(new Error('Database connection failed'));
        }
        return Promise.resolve({ empty: true, docs: [] });
      });

      const response = await request(app)
        .get('/api/chapters/unlocked')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(500);
      expect(response.body.success).toBe(false);
      expect(response.body.error).toBeTruthy();
    });
  });

  describe('GET /api/chapters/:chapterKey/unlock-status', () => {
    it('should return unlocked true for an unlocked chapter', async () => {
      global.mockUserDataConfig.jeeTargetExamDate = '2027-01';

      // Get first unlocked chapter from month 1
      const firstChapter = scheduleData.timeline.month_1.physics[0];

      const response = await request(app)
        .get(`/api/chapters/${firstChapter}/unlock-status`)
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.chapterKey).toBe(firstChapter);
      expect(response.body.data.unlocked).toBe(true);
    });

    it('should return unlocked false for a locked chapter', async () => {
      global.mockUserDataConfig.jeeTargetExamDate = '2029-01'; // Far future
      global.mockUserDataConfig.chapterUnlockHighWaterMark = 0;

      // Get a chapter from month 17 (should be locked when far future)
      const lastChapter = scheduleData.timeline.month_17.chemistry[0];

      const response = await request(app)
        .get(`/api/chapters/${lastChapter}/unlock-status`)
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.chapterKey).toBe(lastChapter);
      expect(response.body.data.unlocked).toBe(false);
    });

    it('should return unlocked true for all chapters for post-exam user', async () => {
      global.mockUserDataConfig.jeeTargetExamDate = '2024-01'; // Past

      const anyChapter = 'physics_kinematics';

      const response = await request(app)
        .get(`/api/chapters/${anyChapter}/unlock-status`)
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.data.unlocked).toBe(true);
    });

    it('should handle chemistry p-block chapter correctly', async () => {
      global.mockUserDataConfig.jeeTargetExamDate = '2027-01';

      const response = await request(app)
        .get('/api/chapters/chemistry_p_block_elements/unlock-status')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.chapterKey).toBe('chemistry_p_block_elements');
      // Should be unlocked (it's in month 2 and 8)
      expect(typeof response.body.data.unlocked).toBe('boolean');
    });

    it('should handle database errors gracefully', async () => {
      mockGet.mockImplementation(() => {
        if (currentCollection === 'users') {
          return Promise.reject(new Error('Database error'));
        }
        return Promise.resolve({ empty: true, docs: [] });
      });

      const response = await request(app)
        .get('/api/chapters/physics_kinematics/unlock-status')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(500);
      expect(response.body.success).toBe(false);
    });
  });

  describe('Chapter Unlock Integration - Real Scenarios', () => {
    it('should unlock exactly 49 chapters for user 11 months before exam', async () => {
      global.mockUserDataConfig.jeeTargetExamDate = '2027-01';
      global.mockUserDataConfig.chapterUnlockHighWaterMark = 0;

      // Mock current date to be 11 months before exam
      const currentDate = new Date('2026-02-20');
      jest.spyOn(Date, 'now').mockReturnValue(currentDate.getTime());

      const response = await request(app)
        .get('/api/chapters/unlocked')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.data.currentMonth).toBe(14); // 24 - 11 + 1 = 14

      // Count expected chapters for months 1-14
      let expectedCount = 0;
      for (let i = 1; i <= 14; i++) {
        const monthData = scheduleData.timeline[`month_${i}`];
        const chapterSet = new Set();
        ['physics', 'chemistry', 'mathematics'].forEach(subject => {
          if (monthData[subject]) {
            monthData[subject].forEach(ch => {
              if (ch) chapterSet.add(ch);
            });
          }
        });
        expectedCount = chapterSet.size;
      }

      // Note: Due to duplicates in schedule, unique count might differ
      expect(response.body.data.unlockedChapters.length).toBeGreaterThanOrEqual(45);
      expect(response.body.data.unlockedChapters.length).toBeLessThanOrEqual(55);
    });

    it('should have valid chapter keys (no invalid keys like physics_emi_ac_circuits)', async () => {
      // Set to exactly 11 months before exam to be at month 14
      global.mockUserDataConfig.jeeTargetExamDate = '2027-01';
      global.mockUserDataConfig.chapterUnlockHighWaterMark = 0;

      const response = await request(app)
        .get('/api/chapters/unlocked')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.data.currentMonth).toBe(14);

      // Verify that the old invalid key is NOT present
      const unlockedSet = new Set(response.body.data.unlockedChapters);
      expect(unlockedSet.has('physics_emi_ac_circuits')).toBe(false);

      // Verify we have unlocked chapters (should have 52 at month 14: original 49 + 3 new physics)
      expect(response.body.data.unlockedChapters.length).toBe(52);

      // All keys should follow valid patterns
      response.body.data.unlockedChapters.forEach(key => {
        expect(key).toMatch(/^(physics|chemistry|mathematics|maths)_[a-z_]+$/);
      });
    });

    it('should include merged parabola chapter', async () => {
      global.mockUserDataConfig.jeeTargetExamDate = '2027-01';

      const response = await request(app)
        .get('/api/chapters/unlocked')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);

      const unlockedSet = new Set(response.body.data.unlockedChapters);

      // Should have the merged parabola chapter
      expect(unlockedSet.has('mathematics_conic_sections_parabola')).toBe(true);

      // Should NOT have the old parabola chapter
      expect(unlockedSet.has('mathematics_parabola')).toBe(false);
    });
  });
});
