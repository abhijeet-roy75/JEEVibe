/**
 * Integration tests for analytics.js routes
 *
 * Tests authentication, overview, focus-areas, progress endpoints
 * Coverage target: 80%+
 */

const request = require('supertest');
const express = require('express');
const analyticsRouter = require('../../../src/routes/analytics');
const analyticsService = require('../../../src/services/analyticsService');
const progressService = require('../../../src/services/progressService');
const subscriptionService = require('../../../src/services/subscriptionService');
const { db } = require('../../../src/config/firebase');

// Mock services
jest.mock('../../../src/services/analyticsService');
jest.mock('../../../src/services/progressService');
jest.mock('../../../src/services/subscriptionService');
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

// Mock feature gate
jest.mock('../../../src/middleware/featureGate', () => ({
  getAnalyticsAccess: jest.fn((req, res, next) => {
    req.hasAnalyticsAccess = true;
    next();
  })
}));

// Mock date utils
jest.mock('../../../src/utils/dateUtils', () => ({
  getCurrentWeekIST: jest.fn(() => [
    { date: '2026-02-24', dayName: 'Mon', isToday: false, isFuture: false },
    { date: '2026-02-25', dayName: 'Tue', isToday: false, isFuture: false },
    { date: '2026-02-26', dayName: 'Wed', isToday: false, isFuture: false },
    { date: '2026-02-27', dayName: 'Thu', isToday: false, isFuture: false },
    { date: '2026-02-28', dayName: 'Fri', isToday: true, isFuture: false },
    { date: '2026-03-01', dayName: 'Sat', isToday: false, isFuture: true },
    { date: '2026-03-02', dayName: 'Sun', isToday: false, isFuture: true }
  ])
}));

describe('Analytics Routes', () => {
  let app;
  let mockGet;
  let mockDoc;
  let mockCollection;

  beforeAll(() => {
    app = express();
    app.use(express.json());
    app.use('/api/analytics', analyticsRouter);

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

  describe('GET /api/analytics/overview', () => {
    test('should return analytics overview for authenticated user', async () => {
      const mockOverview = {
        user: {
          uid: 'test-user-001',
          overall_theta: 0.5,
          overall_percentile: 65.5
        },
        progress: {
          quizzes_completed: 150,
          chapters_practiced: 25,
          questions_answered: 1200,
          accuracy: 68.5
        },
        subjects: {
          physics: { theta: 0.45, percentile: 62.3, accuracy: 65.2 },
          chemistry: { theta: 0.38, percentile: 55.1, accuracy: 60.8 },
          mathematics: { theta: 0.52, percentile: 68.4, accuracy: 72.1 }
        },
        focus_chapters: [
          {
            chapter: 'Laws of Motion',
            chapter_key: 'physics_laws_of_motion',
            theta: -0.2,
            percentile: 42.0,
            questions_answered: 15,
            last_practiced: '2026-02-20T10:00:00Z'
          }
        ]
      };

      analyticsService.getAnalyticsOverview.mockResolvedValue(mockOverview);

      const response = await request(app)
        .get('/api/analytics/overview')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toEqual(mockOverview);
      expect(analyticsService.getAnalyticsOverview).toHaveBeenCalledWith('test-user-001');
    });

    test('should return 401 when not authenticated', async () => {
      const response = await request(app)
        .get('/api/analytics/overview')
        .set('x-test-auth-fail', 'true')
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(analyticsService.getAnalyticsOverview).not.toHaveBeenCalled();
    });

    test('should handle empty analytics data', async () => {
      analyticsService.getAnalyticsOverview.mockResolvedValue({
        user: { uid: 'test-user-001', overall_theta: 0, overall_percentile: 50 },
        progress: { quizzes_completed: 0, chapters_practiced: 0 },
        subjects: {},
        focus_chapters: []
      });

      const response = await request(app)
        .get('/api/analytics/overview')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.progress.quizzes_completed).toBe(0);
    });

    test('should return 500 on service error', async () => {
      analyticsService.getAnalyticsOverview.mockRejectedValue(
        new Error('Failed to fetch analytics')
      );

      const response = await request(app)
        .get('/api/analytics/overview')
        .expect(500);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/analytics/dashboard', () => {
    test('should return batched dashboard data', async () => {
      const mockUserData = {
        phone_number: '+919876543210',
        first_name: 'Test',
        last_name: 'User',
        is_enrolled_in_coaching: true,
        created_at: { toDate: () => new Date('2026-01-15T10:00:00Z') }
      };

      const mockSubscription = {
        tier: 'pro',
        status: 'active'
      };

      const mockOverview = {
        user: { uid: 'test-user-001', overall_theta: 0.5 },
        progress: { quizzes_completed: 150 },
        subjects: {},
        focus_chapters: []
      };

      mockGet.mockResolvedValue({
        exists: true,
        data: () => mockUserData
      });

      subscriptionService.getSubscriptionStatus.mockResolvedValue(mockSubscription);
      analyticsService.getAnalyticsOverview.mockResolvedValue(mockOverview);
      progressService.getAccuracyTrends.mockResolvedValue([
        { date: '2026-02-28', quizzes: 5, questions: 25, correct: 18, accuracy: 72 }
      ]);

      const response = await request(app)
        .get('/api/analytics/dashboard')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.profile.phoneNumber).toBe('+919876543210');
      expect(response.body.data.subscription.tier).toBe('pro');
      expect(response.body.data.overview.progress.quizzes_completed).toBe(150);
      expect(response.body.data.weeklyActivity).toBeDefined();
      expect(response.body.data.weeklyActivity.weekData).toHaveLength(7);
    });

    test('should handle missing user data gracefully', async () => {
      mockGet.mockResolvedValue({
        exists: false
      });

      subscriptionService.getSubscriptionStatus.mockResolvedValue({ tier: 'free' });
      analyticsService.getAnalyticsOverview.mockResolvedValue({
        user: { uid: 'test-user-001' },
        progress: {},
        subjects: {},
        focus_chapters: []
      });
      progressService.getAccuracyTrends.mockResolvedValue([]);

      const response = await request(app)
        .get('/api/analytics/dashboard')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.profile.uid).toBe('test-user-001');
    });
  });

  describe('GET /api/analytics/mastery/:subject', () => {
    test('should return subject mastery details', async () => {
      const mockMastery = {
        subject: 'physics',
        overall: {
          theta: 0.45,
          percentile: 62.3,
          accuracy: 65.2,
          questions_answered: 450
        },
        chapters: [
          {
            chapter: 'Laws of Motion',
            theta: 0.5,
            percentile: 65.0,
            accuracy: 68.0,
            questions_answered: 50,
            mastery_level: 'intermediate'
          }
        ]
      };

      analyticsService.getSubjectMastery = jest.fn().mockResolvedValue(mockMastery);

      const response = await request(app)
        .get('/api/analytics/mastery/physics')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.subject).toBe('physics');
      expect(response.body.data.chapters).toHaveLength(1);
    });

    test('should validate subject parameter', async () => {
      analyticsService.getSubjectMastery = jest.fn().mockRejectedValue(
        new Error('Invalid subject')
      );

      const response = await request(app)
        .get('/api/analytics/mastery/invalid-subject')
        .expect(500);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/analytics/mastery-timeline', () => {
    test('should return mastery progression over time', async () => {
      const mockTimeline = {
        snapshots: [
          {
            date: '2026-02-01',
            overall_theta: 0.3,
            overall_percentile: 55.0,
            physics_theta: 0.25,
            chemistry_theta: 0.28,
            mathematics_theta: 0.35
          },
          {
            date: '2026-02-15',
            overall_theta: 0.45,
            overall_percentile: 62.0,
            physics_theta: 0.40,
            chemistry_theta: 0.38,
            mathematics_theta: 0.52
          }
        ]
      };

      analyticsService.getMasteryTimeline = jest.fn().mockResolvedValue(mockTimeline);

      const response = await request(app)
        .get('/api/analytics/mastery-timeline')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.snapshots).toHaveLength(2);
    });
  });

  describe('GET /api/analytics/accuracy-timeline', () => {
    test('should return accuracy progression over time', async () => {
      const mockTimeline = [
        { date: '2026-02-24', accuracy: 65.5, questions: 25 },
        { date: '2026-02-25', accuracy: 68.0, questions: 30 },
        { date: '2026-02-26', accuracy: 70.2, questions: 28 }
      ];

      progressService.getAccuracyTrends.mockResolvedValue(mockTimeline);

      const response = await request(app)
        .get('/api/analytics/accuracy-timeline?days=7')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveLength(3);
      expect(progressService.getAccuracyTrends).toHaveBeenCalledWith('test-user-001', 7);
    });

    test('should use default 30 days if parameter missing', async () => {
      progressService.getAccuracyTrends.mockResolvedValue([]);

      await request(app)
        .get('/api/analytics/accuracy-timeline')
        .expect(200);

      expect(progressService.getAccuracyTrends).toHaveBeenCalledWith('test-user-001', 30);
    });
  });

  describe('GET /api/analytics/all-chapters', () => {
    test('should return all chapters mastery status', async () => {
      const mockChapters = {
        physics: [
          { chapter: 'Laws of Motion', theta: 0.5, percentile: 65.0, is_unlocked: true },
          { chapter: 'Thermodynamics', theta: 0.3, percentile: 55.0, is_unlocked: true }
        ],
        chemistry: [
          { chapter: 'Organic Chemistry', theta: 0.4, percentile: 60.0, is_unlocked: true }
        ],
        mathematics: [
          { chapter: 'Calculus', theta: 0.6, percentile: 72.0, is_unlocked: true }
        ]
      };

      analyticsService.getAllChaptersMastery = jest.fn().mockResolvedValue(mockChapters);

      const response = await request(app)
        .get('/api/analytics/all-chapters')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.physics).toHaveLength(2);
    });
  });

  describe('GET /api/analytics/weekly-activity', () => {
    test('should return weekly activity data', async () => {
      progressService.getAccuracyTrends.mockResolvedValue([
        { date: '2026-02-28', quizzes: 5, questions: 25, correct: 18, accuracy: 72 }
      ]);

      const response = await request(app)
        .get('/api/analytics/weekly-activity')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.weekData).toHaveLength(7);
      expect(response.body.data.weekData[4].isToday).toBe(true);
      expect(response.body.data.weekData[4].quizzes).toBe(5);
    });

    test('should handle empty activity data', async () => {
      progressService.getAccuracyTrends.mockResolvedValue([]);

      const response = await request(app)
        .get('/api/analytics/weekly-activity')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.weekData).toHaveLength(7);
      expect(response.body.data.weekData.every(d => d.quizzes === 0)).toBe(true);
    });
  });

  describe('Error handling', () => {
    test('should handle service errors gracefully', async () => {
      analyticsService.getAnalyticsOverview.mockRejectedValue(
        new Error('Firestore timeout')
      );

      const response = await request(app)
        .get('/api/analytics/overview')
        .expect(500);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBeDefined();
    });

    test('should handle missing subject parameter', async () => {
      const response = await request(app)
        .get('/api/analytics/mastery/')
        .expect(404);
    });
  });
});
