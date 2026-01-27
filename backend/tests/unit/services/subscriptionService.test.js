/**
 * Unit Tests for Subscription Service
 *
 * Tests:
 * - getEffectiveTier priority: override > subscription > trial > free
 * - Override validation (tier_id required, expiry validation)
 * - Safe fallback to free tier on errors
 */

// Mock Firebase
const mockUserData = {
  subscription: {},
  trial: null,
};

const mockSubscriptionData = {};

jest.mock('../../../../src/config/firebase', () => {
  return {
    db: {
      collection: jest.fn(() => ({
        doc: jest.fn((docId) => ({
          get: jest.fn(() => Promise.resolve({
            exists: true,
            data: () => docId.includes('sub_') ? mockSubscriptionData : mockUserData,
          })),
          update: jest.fn(() => Promise.resolve()),
          collection: jest.fn(() => ({
            doc: jest.fn(() => ({
              get: jest.fn(() => Promise.resolve({
                exists: true,
                data: () => mockSubscriptionData,
              })),
            })),
          })),
        })),
      })),
    },
    admin: {
      firestore: {
        FieldValue: {
          serverTimestamp: jest.fn(() => ({ _serverTimestamp: true })),
          delete: jest.fn(() => ({ _delete: true })),
        },
        Timestamp: {
          fromDate: jest.fn((date) => ({
            toDate: () => date,
          })),
        },
      },
    },
  };
});

// Mock firestoreRetry
jest.mock('../../../../src/utils/firestoreRetry', () => ({
  retryFirestoreOperation: jest.fn((fn) => fn()),
}));

// Mock tierConfigService
jest.mock('../../../../src/services/tierConfigService', () => ({
  getTierLimits: jest.fn(() => Promise.resolve({
    snap_solve_daily: 5,
    daily_quiz_daily: 1,
  })),
  getTierFeatures: jest.fn(() => Promise.resolve({
    analytics_access: 'basic',
  })),
  getTierLimitsAndFeatures: jest.fn(() => Promise.resolve({
    limits: {
      snap_solve_daily: 5,
      daily_quiz_daily: 1,
    },
    features: {
      analytics_access: 'basic',
    },
  })),
}));

// Mock logger
jest.mock('../../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const { db } = require('../../../../src/config/firebase');
const { getEffectiveTier, getSubscriptionStatus, clearTierCache } = require('../../../../src/services/subscriptionService');

describe('subscriptionService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Clear tier cache before each test to prevent test interference
    clearTierCache();
    // Reset mock user data
    mockUserData.subscription = {};
    mockUserData.trial = null;
  });

  describe('getEffectiveTier', () => {
    describe('Priority: Override', () => {
      test('returns override tier when valid override exists', async () => {
        const futureDate = new Date(Date.now() + 86400000); // Tomorrow
        mockUserData.subscription = {
          override: {
            tier_id: 'ultra',
            type: 'beta_tester',
            expires_at: { toDate: () => futureDate },
            reason: 'Beta Program',
          },
        };

        const result = await getEffectiveTier('test-user');

        expect(result.tier).toBe('ultra');
        expect(result.source).toBe('override');
        expect(result.override_type).toBe('beta_tester');
      });

      test('ignores override with missing tier_id', async () => {
        const futureDate = new Date(Date.now() + 86400000);
        mockUserData.subscription = {
          override: {
            // tier_id is missing!
            type: 'beta_tester',
            expires_at: { toDate: () => futureDate },
          },
        };

        const result = await getEffectiveTier('test-user', { skipCache: true });

        // Should fall through to default free tier
        expect(result.tier).toBe('free');
        expect(result.source).toBe('default');
      });

      test('ignores override with invalid tier_id', async () => {
        const futureDate = new Date(Date.now() + 86400000);
        mockUserData.subscription = {
          override: {
            tier_id: 'invalid_tier', // Not in ['pro', 'ultra']
            type: 'beta_tester',
            expires_at: { toDate: () => futureDate },
          },
        };

        const result = await getEffectiveTier('test-user', { skipCache: true });

        expect(result.tier).toBe('free');
        expect(result.source).toBe('default');
      });

      test('ignores expired override', async () => {
        const pastDate = new Date(Date.now() - 86400000); // Yesterday
        mockUserData.subscription = {
          override: {
            tier_id: 'ultra',
            type: 'beta_tester',
            expires_at: { toDate: () => pastDate },
          },
        };

        const result = await getEffectiveTier('test-user', { skipCache: true });

        expect(result.tier).toBe('free');
        expect(result.source).toBe('default');
      });

      test('handles invalid expires_at date gracefully', async () => {
        mockUserData.subscription = {
          override: {
            tier_id: 'ultra',
            type: 'beta_tester',
            expires_at: 'not-a-valid-date',
          },
        };

        const result = await getEffectiveTier('test-user', { skipCache: true });

        // Should fall through due to invalid date
        expect(result.tier).toBe('free');
        expect(result.source).toBe('default');
      });
    });

    describe('Priority: Subscription', () => {
      test('returns subscription tier when active subscription exists', async () => {
        const futureDate = new Date(Date.now() + 86400000);
        mockUserData.subscription = {
          active_subscription_id: 'sub_123',
        };

        // Mock subscription document
        const mockSubDoc = {
          exists: true,
          data: () => ({
            tier_id: 'pro',
            status: 'active',
            end_date: { toDate: () => futureDate },
            plan_type: 'monthly',
          }),
        };

        db.collection.mockReturnValue({
          doc: jest.fn(() => ({
            get: jest.fn(() => Promise.resolve({
              exists: true,
              data: () => mockUserData,
            })),
            collection: jest.fn(() => ({
              doc: jest.fn(() => ({
                get: jest.fn(() => Promise.resolve(mockSubDoc)),
              })),
            })),
          })),
        });

        const result = await getEffectiveTier('test-user', { skipCache: true });

        expect(result.tier).toBe('pro');
        expect(result.source).toBe('subscription');
      });
    });

    describe('Priority: Trial', () => {
      test('returns pro tier when active trial exists', async () => {
        const futureDate = new Date(Date.now() + 86400000);
        mockUserData.trial = {
          ends_at: { toDate: () => futureDate },
        };

        const result = await getEffectiveTier('test-user', { skipCache: true });

        expect(result.tier).toBe('pro');
        expect(result.source).toBe('trial');
      });

      test('ignores expired trial', async () => {
        const pastDate = new Date(Date.now() - 86400000);
        mockUserData.trial = {
          ends_at: { toDate: () => pastDate },
        };

        const result = await getEffectiveTier('test-user', { skipCache: true });

        expect(result.tier).toBe('free');
        expect(result.source).toBe('default');
      });
    });

    describe('Default: Free Tier', () => {
      test('returns free tier for user with no subscription data', async () => {
        mockUserData.subscription = {};
        mockUserData.trial = null;

        const result = await getEffectiveTier('test-user', { skipCache: true });

        expect(result.tier).toBe('free');
        expect(result.source).toBe('default');
        expect(result.expires_at).toBeNull();
      });

      test('returns free tier for non-existent user', async () => {
        db.collection.mockReturnValue({
          doc: jest.fn(() => ({
            get: jest.fn(() => Promise.resolve({
              exists: false,
            })),
          })),
        });

        const result = await getEffectiveTier('non-existent-user', { skipCache: true });

        expect(result.tier).toBe('free');
        expect(result.source).toBe('default');
      });
    });

    describe('Error Handling', () => {
      test('returns free tier on database error', async () => {
        db.collection.mockImplementation(() => {
          throw new Error('Database error');
        });

        const result = await getEffectiveTier('test-user', { skipCache: true });

        expect(result.tier).toBe('free');
        expect(result.source).toBe('default');
        expect(result.error).toBe(true);
      });
    });
  });

  describe('getSubscriptionStatus', () => {
    test('returns complete subscription status with limits and features', async () => {
      mockUserData.subscription = {};
      // Clear cache to ensure fresh fetch
      clearTierCache();

      const result = await getSubscriptionStatus('test-user');

      expect(result).toHaveProperty('tier', 'free');
      expect(result).toHaveProperty('source', 'default');
      expect(result).toHaveProperty('limits');
      expect(result).toHaveProperty('features');
    });
  });
});
