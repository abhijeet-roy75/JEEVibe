/**
 * Integration Tests for Subscription API Endpoints
 *
 * Tests:
 * - GET /api/subscriptions/status
 * - POST /api/subscriptions/admin/grant-override (admin authorization)
 * - POST /api/subscriptions/admin/revoke-override (admin authorization)
 */

const request = require('supertest');

// Store admin status for mocking
let mockIsAdmin = false;
let mockUserId = 'test-user-id';

// Mock Firebase
jest.mock('../../../src/config/firebase', () => {
  const mockUserDoc = {
    data: jest.fn(() => ({
      subscription: { tier: 'free' },
      role: mockIsAdmin ? 'admin' : 'user',
    })),
    exists: true,
    id: 'test-user-id',
  };

  const mockCollection = {
    doc: jest.fn(() => ({
      get: jest.fn(() => Promise.resolve(mockUserDoc)),
      set: jest.fn(() => Promise.resolve()),
      update: jest.fn(() => Promise.resolve()),
      collection: jest.fn(() => mockCollection),
    })),
    where: jest.fn(() => ({
      get: jest.fn(() => Promise.resolve({ empty: true, docs: [] })),
    })),
  };

  return {
    db: {
      collection: jest.fn(() => mockCollection),
      runTransaction: jest.fn(async (callback) => callback({
        get: jest.fn(() => Promise.resolve(mockUserDoc)),
        set: jest.fn(),
      })),
    },
    admin: {
      auth: jest.fn(() => ({
        verifyIdToken: jest.fn(() => Promise.resolve({ uid: mockUserId })),
        getUser: jest.fn(() => Promise.resolve({
          uid: mockUserId,
          customClaims: mockIsAdmin ? { admin: true } : {},
        })),
      })),
      firestore: {
        Timestamp: {
          now: jest.fn(() => ({ seconds: Math.floor(Date.now() / 1000) })),
          fromDate: jest.fn((date) => ({
            toDate: () => date,
            seconds: Math.floor(date.getTime() / 1000),
          })),
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

// Mock firestoreRetry
jest.mock('../../../src/utils/firestoreRetry', () => ({
  retryFirestoreOperation: jest.fn((fn) => fn()),
}));

// Mock auth middleware to use our mock user
jest.mock('../../../src/middleware/auth', () => ({
  authenticateToken: (req, res, next) => {
    req.user = { uid: mockUserId };
    next();
  },
  authenticateUser: (req, res, next) => {
    req.userId = mockUserId;
    next();
  },
}));

// Mock tierConfigService
jest.mock('../../../src/services/tierConfigService', () => ({
  getTierLimits: jest.fn(() => Promise.resolve({
    snap_solve_daily: 5,
    daily_quiz_daily: 1,
    ai_tutor_enabled: false,
  })),
  getTierFeatures: jest.fn(() => Promise.resolve({
    analytics_access: 'basic',
  })),
  getPurchasablePlans: jest.fn(() => Promise.resolve([
    { tier_id: 'pro', name: 'Pro', monthly_price: 299 },
  ])),
  getTierConfig: jest.fn(() => Promise.resolve({
    version: '1.0.0',
    tiers: {},
  })),
}));

// Mock subscriptionService
jest.mock('../../../src/services/subscriptionService', () => ({
  getEffectiveTier: jest.fn(() => Promise.resolve({
    tier: 'free',
    source: 'default',
    expires_at: null,
  })),
  getSubscriptionStatus: jest.fn(() => Promise.resolve({
    tier: 'free',
    source: 'default',
    limits: { snap_solve_daily: 5 },
    features: { analytics_access: 'basic' },
  })),
  grantOverride: jest.fn(() => Promise.resolve({
    success: true,
    override: { tier_id: 'ultra', type: 'beta_tester' },
  })),
  revokeOverride: jest.fn(() => Promise.resolve({
    success: true,
    new_tier: { tier: 'free', source: 'default' },
  })),
}));

// Mock usageTrackingService
jest.mock('../../../src/services/usageTrackingService', () => ({
  getAllUsage: jest.fn(() => Promise.resolve({
    snap_solve: { used: 0, limit: 5, remaining: 5, is_unlimited: false, resets_at: new Date().toISOString() },
    daily_quiz: { used: 0, limit: 1, remaining: 1, is_unlimited: false, resets_at: new Date().toISOString() },
    ai_tutor: { used: 0, limit: 0, remaining: 0, is_unlimited: false, resets_at: new Date().toISOString() },
  })),
}));

// Mock weeklyChapterPracticeService
jest.mock('../../../src/services/weeklyChapterPracticeService', () => ({
  getWeeklyUsage: jest.fn(() => Promise.resolve(null)),
}));

// Mock logger
jest.mock('../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

// Import app after mocks
const express = require('express');
const subscriptionsRouter = require('../../../src/routes/subscriptions');

// Create test app
const app = express();
app.use(express.json());
app.use('/api/subscriptions', subscriptionsRouter);

// Error handler for tests
app.use((err, req, res, next) => {
  console.error('Test error:', err.message);
  res.status(500).json({ error: err.message, stack: err.stack });
});

describe('Subscription Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockIsAdmin = false;
    mockUserId = 'test-user-id';
  });

  describe('GET /api/subscriptions/status', () => {
    test('returns subscription status for authenticated user', async () => {
      const response = await request(app)
        .get('/api/subscriptions/status')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('subscription');
      expect(response.body.data.subscription).toHaveProperty('tier');
      expect(response.body.data).toHaveProperty('limits');
      expect(response.body.data).toHaveProperty('usage');
      expect(response.body.data).toHaveProperty('features');
    });
  });

  describe('POST /api/subscriptions/admin/grant-override', () => {
    test('rejects non-admin user with 403', async () => {
      mockIsAdmin = false;

      const response = await request(app)
        .post('/api/subscriptions/admin/grant-override')
        .set('Authorization', 'Bearer test-token')
        .send({
          user_id: 'target-user',
          type: 'beta_tester',
          tier_id: 'ultra',
          duration_days: 90,
        });

      expect(response.status).toBe(403);
      expect(response.body.success).toBe(false);
      expect(response.body.code).toBe('ADMIN_REQUIRED');
    });

    test('allows admin user to grant override', async () => {
      mockIsAdmin = true;

      const response = await request(app)
        .post('/api/subscriptions/admin/grant-override')
        .set('Authorization', 'Bearer test-token')
        .send({
          user_id: 'target-user',
          type: 'beta_tester',
          tier_id: 'ultra',
          duration_days: 90,
        });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
    });

    test('requires user_id parameter', async () => {
      mockIsAdmin = true;

      const response = await request(app)
        .post('/api/subscriptions/admin/grant-override')
        .set('Authorization', 'Bearer test-token')
        .send({
          type: 'beta_tester',
          tier_id: 'ultra',
        });

      expect(response.status).toBe(400);
      expect(response.body.code).toBe('MISSING_USER_ID');
    });

    test('validates tier_id parameter', async () => {
      mockIsAdmin = true;

      const response = await request(app)
        .post('/api/subscriptions/admin/grant-override')
        .set('Authorization', 'Bearer test-token')
        .send({
          user_id: 'target-user',
          tier_id: 'invalid_tier',
        });

      expect(response.status).toBe(400);
      expect(response.body.code).toBe('INVALID_TIER');
    });

    test('rejects negative duration_days', async () => {
      mockIsAdmin = true;

      const response = await request(app)
        .post('/api/subscriptions/admin/grant-override')
        .set('Authorization', 'Bearer test-token')
        .send({
          user_id: 'target-user',
          tier_id: 'ultra',
          duration_days: -30,
        });

      expect(response.status).toBe(400);
      expect(response.body.code).toBe('INVALID_DURATION');
    });

    test('rejects duration_days over 365', async () => {
      mockIsAdmin = true;

      const response = await request(app)
        .post('/api/subscriptions/admin/grant-override')
        .set('Authorization', 'Bearer test-token')
        .send({
          user_id: 'target-user',
          tier_id: 'ultra',
          duration_days: 500,
        });

      expect(response.status).toBe(400);
      expect(response.body.code).toBe('INVALID_DURATION');
    });

    test('rejects reason over 500 characters', async () => {
      mockIsAdmin = true;

      const response = await request(app)
        .post('/api/subscriptions/admin/grant-override')
        .set('Authorization', 'Bearer test-token')
        .send({
          user_id: 'target-user',
          tier_id: 'ultra',
          reason: 'a'.repeat(501),
        });

      expect(response.status).toBe(400);
      expect(response.body.code).toBe('INVALID_REASON');
    });
  });

  describe('POST /api/subscriptions/admin/revoke-override', () => {
    test('rejects non-admin user with 403', async () => {
      mockIsAdmin = false;

      const response = await request(app)
        .post('/api/subscriptions/admin/revoke-override')
        .set('Authorization', 'Bearer test-token')
        .send({
          user_id: 'target-user',
        });

      expect(response.status).toBe(403);
      expect(response.body.success).toBe(false);
      expect(response.body.code).toBe('ADMIN_REQUIRED');
    });

    test('allows admin user to revoke override', async () => {
      mockIsAdmin = true;

      const response = await request(app)
        .post('/api/subscriptions/admin/revoke-override')
        .set('Authorization', 'Bearer test-token')
        .send({
          user_id: 'target-user',
        });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
    });

    test('requires user_id parameter', async () => {
      mockIsAdmin = true;

      const response = await request(app)
        .post('/api/subscriptions/admin/revoke-override')
        .set('Authorization', 'Bearer test-token')
        .send({});

      expect(response.status).toBe(400);
      expect(response.body.code).toBe('MISSING_USER_ID');
    });
  });
});
