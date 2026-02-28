/**
 * Integration tests for admin.js routes
 *
 * Tests authentication, metrics endpoints, user management
 * Coverage target: 80%+
 */

const request = require('supertest');
const express = require('express');
const adminRouter = require('../../../src/routes/admin');
const adminMetricsService = require('../../../src/services/adminMetricsService');

// Mock services
jest.mock('../../../src/services/adminMetricsService');
jest.mock('../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn()
}));

// Mock authenticateAdmin middleware
jest.mock('../../../src/middleware/adminAuth', () => ({
  authenticateAdmin: jest.fn((req, res, next) => {
    // Check if the mock should reject
    if (req.headers['x-test-auth-fail']) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized - Admin access required'
      });
    }
    // Mock admin user
    req.user = {
      uid: 'admin-test-user',
      isAdmin: true
    };
    next();
  })
}));

describe('Admin Routes', () => {
  let app;

  beforeAll(() => {
    app = express();
    app.use(express.json());
    app.use('/api/admin', adminRouter);

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

  describe('GET /api/admin/metrics/daily-health', () => {
    test('should return daily health metrics for authenticated admin', async () => {
      const mockMetrics = {
        date: '2026-02-28',
        users: {
          total: 1000,
          active: 250,
          new: 15
        },
        engagement: {
          dau: 250,
          mau: 750,
          retention_7d: 65.5
        },
        revenue: {
          daily: 15000,
          monthly: 350000
        }
      };

      adminMetricsService.getDailyHealth.mockResolvedValue(mockMetrics);

      const response = await request(app)
        .get('/api/admin/metrics/daily-health')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toEqual(mockMetrics);
      expect(adminMetricsService.getDailyHealth).toHaveBeenCalledTimes(1);
    });

    test('should return 401 when not authenticated', async () => {
      const response = await request(app)
        .get('/api/admin/metrics/daily-health')
        .set('x-test-auth-fail', 'true')
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('Unauthorized');
      expect(adminMetricsService.getDailyHealth).not.toHaveBeenCalled();
    });

    test('should return 500 on service error', async () => {
      adminMetricsService.getDailyHealth.mockRejectedValue(
        new Error('Database connection error')
      );

      const response = await request(app)
        .get('/api/admin/metrics/daily-health')
        .expect(500);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBeDefined();
    });
  });

  describe('GET /api/admin/metrics/engagement', () => {
    test('should return engagement metrics for authenticated admin', async () => {
      const mockMetrics = {
        daily_quiz: {
          total_attempts: 1500,
          unique_users: 450,
          avg_per_user: 3.33
        },
        chapter_practice: {
          total_sessions: 800,
          unique_users: 320,
          avg_per_user: 2.5
        },
        snap_solve: {
          total_snaps: 600,
          unique_users: 200,
          avg_per_user: 3.0
        },
        mock_tests: {
          total_attempts: 150,
          unique_users: 100,
          completion_rate: 75.5
        }
      };

      adminMetricsService.getEngagement.mockResolvedValue(mockMetrics);

      const response = await request(app)
        .get('/api/admin/metrics/engagement')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toEqual(mockMetrics);
      expect(adminMetricsService.getEngagement).toHaveBeenCalledTimes(1);
    });

    test('should return 401 when not authenticated', async () => {
      const response = await request(app)
        .get('/api/admin/metrics/engagement')
        .set('x-test-auth-fail', 'true')
        .expect(401);

      expect(response.body.success).toBe(false);
    });

    test('should handle empty metrics data', async () => {
      adminMetricsService.getEngagement.mockResolvedValue({
        daily_quiz: { total_attempts: 0, unique_users: 0, avg_per_user: 0 },
        chapter_practice: { total_sessions: 0, unique_users: 0, avg_per_user: 0 },
        snap_solve: { total_snaps: 0, unique_users: 0, avg_per_user: 0 },
        mock_tests: { total_attempts: 0, unique_users: 0, completion_rate: 0 }
      });

      const response = await request(app)
        .get('/api/admin/metrics/engagement')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.daily_quiz.total_attempts).toBe(0);
    });
  });

  describe('GET /api/admin/metrics/learning', () => {
    test('should return learning outcomes metrics', async () => {
      const mockMetrics = {
        theta_distribution: {
          advanced: 120,
          intermediate: 450,
          beginner: 430
        },
        avg_theta: {
          physics: 0.45,
          chemistry: 0.38,
          mathematics: 0.52,
          overall: 0.45
        },
        accuracy: {
          physics: 65.5,
          chemistry: 58.3,
          mathematics: 70.2,
          overall: 64.7
        },
        progress: {
          improving: 600,
          stable: 350,
          declining: 50
        }
      };

      adminMetricsService.getLearning.mockResolvedValue(mockMetrics);

      const response = await request(app)
        .get('/api/admin/metrics/learning')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toEqual(mockMetrics);
      expect(response.body.data.avg_theta.overall).toBe(0.45);
    });

    test('should return 401 when not authenticated', async () => {
      const response = await request(app)
        .get('/api/admin/metrics/learning')
        .set('x-test-auth-fail', 'true')
        .expect(401);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/admin/metrics/content', () => {
    test('should return content quality metrics', async () => {
      const mockMetrics = {
        questions: {
          total: 5000,
          by_subject: {
            physics: 1800,
            chemistry: 1600,
            mathematics: 1600
          },
          by_difficulty: {
            easy: 1500,
            medium: 2000,
            hard: 1500
          }
        },
        irt_quality: {
          avg_discrimination: 1.35,
          calibrated_questions: 4500,
          needs_calibration: 500
        },
        usage: {
          most_used: [
            { chapter: 'Laws of Motion', count: 2500 },
            { chapter: 'Thermodynamics', count: 2200 }
          ],
          least_used: [
            { chapter: 'Surface Chemistry', count: 150 }
          ]
        }
      };

      adminMetricsService.getContent.mockResolvedValue(mockMetrics);

      const response = await request(app)
        .get('/api/admin/metrics/content')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.questions.total).toBe(5000);
      expect(response.body.data.irt_quality.avg_discrimination).toBe(1.35);
    });

    test('should return 401 when not authenticated', async () => {
      const response = await request(app)
        .get('/api/admin/metrics/content')
        .set('x-test-auth-fail', 'true')
        .expect(401);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/admin/metrics/cognitive-mastery', () => {
    test('should return cognitive mastery analytics', async () => {
      const mockMetrics = {
        summary: {
          total_weak_spots_detected: 150,
          total_capsules_opened: 80,
          total_retrievals_completed: 45,
          total_nodes_mastered: 20
        },
        by_node: [
          {
            node_id: 'PHY_LOM_001',
            title: 'Newton\'s Laws of Motion',
            detected_count: 25,
            capsule_opens: 15,
            retrieval_attempts: 10,
            mastered_count: 5
          },
          {
            node_id: 'CHE_THERMO_001',
            title: 'First Law of Thermodynamics',
            detected_count: 20,
            capsule_opens: 12,
            retrieval_attempts: 8,
            mastered_count: 3
          }
        ]
      };

      adminMetricsService.getCognitiveMasteryMetrics.mockResolvedValue(mockMetrics);

      const response = await request(app)
        .get('/api/admin/metrics/cognitive-mastery')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.summary.total_weak_spots_detected).toBe(150);
      expect(response.body.data.by_node).toHaveLength(2);
    });

    test('should call getCognitiveMasteryMetrics without parameters', async () => {
      const mockMetrics = {
        summary: { total_weak_spots_detected: 50 },
        by_node: []
      };

      adminMetricsService.getCognitiveMasteryMetrics.mockResolvedValue(mockMetrics);

      const response = await request(app)
        .get('/api/admin/metrics/cognitive-mastery')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(adminMetricsService.getCognitiveMasteryMetrics).toHaveBeenCalled();
    });

    test('should return 401 when not authenticated', async () => {
      const response = await request(app)
        .get('/api/admin/metrics/cognitive-mastery')
        .set('x-test-auth-fail', 'true')
        .expect(401);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/admin/users', () => {
    test('should return paginated user list', async () => {
      const mockUsers = {
        users: [
          {
            uid: 'user-001',
            phoneNumber: '+919876543210',
            overall_theta: 0.5,
            tier: 'pro',
            created_at: '2026-01-15T10:00:00Z'
          },
          {
            uid: 'user-002',
            phoneNumber: '+919876543211',
            overall_theta: 0.3,
            tier: 'free',
            created_at: '2026-01-20T14:30:00Z'
          }
        ],
        total: 1000,
        page: 1,
        limit: 10,
        hasMore: true
      };

      adminMetricsService.getUsers.mockResolvedValue(mockUsers);

      const response = await request(app)
        .get('/api/admin/users?page=1&limit=10')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.users).toHaveLength(2);
      expect(response.body.data.total).toBe(1000);
      expect(response.body.data.hasMore).toBe(true);
    });

    test('should accept filter parameters', async () => {
      const mockUsers = {
        users: [],
        total: 5,
        page: 1,
        limit: 10,
        hasMore: false
      };

      adminMetricsService.getUsers.mockResolvedValue(mockUsers);

      await request(app)
        .get('/api/admin/users?filter=pro&search=9876543210')
        .expect(200);

      expect(adminMetricsService.getUsers).toHaveBeenCalledWith(
        expect.objectContaining({
          filter: 'pro',
          search: '9876543210'
        })
      );
    });

    test('should return 401 when not authenticated', async () => {
      const response = await request(app)
        .get('/api/admin/users')
        .set('x-test-auth-fail', 'true')
        .expect(401);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/admin/users/:userId', () => {
    test('should return user details for valid userId', async () => {
      const mockUser = {
        uid: 'user-001',
        phoneNumber: '+919876543210',
        overall_theta: 0.5,
        overall_percentile: 65.5,
        tier: 'pro',
        subscription: {
          tier: 'pro',
          status: 'active',
          starts_at: '2026-01-01T00:00:00Z',
          ends_at: '2026-04-01T00:00:00Z'
        },
        theta_by_subject: {
          physics: { theta: 0.45, se: 0.25 },
          chemistry: { theta: 0.38, se: 0.28 },
          mathematics: { theta: 0.52, se: 0.22 }
        },
        progress: {
          quizzes_completed: 150,
          chapters_practiced: 25,
          mock_tests_taken: 5
        }
      };

      adminMetricsService.getUserDetails.mockResolvedValue(mockUser);

      const response = await request(app)
        .get('/api/admin/users/user-001')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.uid).toBe('user-001');
      expect(response.body.data.tier).toBe('pro');
    });

    test('should return 404 for non-existent user', async () => {
      adminMetricsService.getUserDetails.mockRejectedValue(
        new Error('User not found')
      );

      const response = await request(app)
        .get('/api/admin/users/non-existent-user')
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('not found');
    });

    test('should return 401 when not authenticated', async () => {
      const response = await request(app)
        .get('/api/admin/users/user-001')
        .set('x-test-auth-fail', 'true')
        .expect(401);

      expect(response.body.success).toBe(false);
    });
  });

  describe('Error handling', () => {
    test('should handle service errors with proper error messages', async () => {
      adminMetricsService.getEngagement.mockRejectedValue(
        new Error('Firestore read timeout')
      );

      const response = await request(app)
        .get('/api/admin/metrics/engagement')
        .expect(500);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBeDefined();
    });

    test('should handle missing data gracefully', async () => {
      adminMetricsService.getContent.mockResolvedValue({
        questions: { total: 0, by_subject: {}, by_difficulty: {} },
        irt_quality: { avg_discrimination: 0, calibrated_questions: 0, needs_calibration: 0 },
        usage: { most_used: [], least_used: [] }
      });

      const response = await request(app)
        .get('/api/admin/metrics/content')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.questions.total).toBe(0);
    });
  });
});
