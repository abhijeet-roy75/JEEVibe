/**
 * Unit Tests for Usage Tracking Service
 *
 * Tests:
 * - IST timezone calculation for date keys
 * - Midnight IST calculation
 * - Unlimited user handling (-1 limits)
 * - Usage increment with transaction atomicity
 */

// Mock Firebase before requiring the service
jest.mock('../../../src/config/firebase', () => {
  const mockTransaction = {
    get: jest.fn(),
    set: jest.fn(),
  };

  const mockUsageDoc = {
    exists: false,
    data: jest.fn(() => ({})),
  };

  const mockUsageRef = {
    get: jest.fn(() => Promise.resolve(mockUsageDoc)),
    set: jest.fn(() => Promise.resolve()),
  };

  const mockUserDoc = {
    exists: true,
    data: jest.fn(() => ({
      subscription: { tier: 'free' }
    })),
  };

  return {
    db: {
      collection: jest.fn(() => ({
        doc: jest.fn(() => ({
          get: jest.fn(() => Promise.resolve(mockUserDoc)),
          collection: jest.fn(() => ({
            doc: jest.fn(() => mockUsageRef),
          })),
        })),
      })),
      runTransaction: jest.fn(async (callback) => {
        mockTransaction.get.mockResolvedValue(mockUsageDoc);
        return callback(mockTransaction);
      }),
    },
    admin: {
      firestore: {
        FieldValue: {
          increment: jest.fn((val) => ({ _increment: val })),
          serverTimestamp: jest.fn(() => ({ _serverTimestamp: true })),
        },
      },
    },
  };
});

// Mock firestoreRetry
jest.mock('../../../src/utils/firestoreRetry', () => ({
  retryFirestoreOperation: jest.fn((fn) => fn()),
}));

// Mock subscriptionService
jest.mock('../../../src/services/subscriptionService', () => ({
  getEffectiveTier: jest.fn(() => Promise.resolve({
    tier: 'free',
    source: 'default',
    expires_at: null,
  })),
}));

// Mock tierConfigService
jest.mock('../../../src/services/tierConfigService', () => ({
  getTierLimits: jest.fn((tier) => {
    const limits = {
      free: { snap_solve_daily: 5, daily_quiz_daily: 1 },
      pro: { snap_solve_daily: 10, daily_quiz_daily: 10 },
      ultra: { snap_solve_daily: -1, daily_quiz_daily: -1 },
    };
    return Promise.resolve(limits[tier] || limits.free);
  }),
  isUnlimited: jest.fn((value) => value === -1),
}));

// Mock logger
jest.mock('../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const { getTodayDateKey, getNextMidnightIST, getUsage, canUse, incrementUsage } = require('../../../src/services/usageTrackingService');
const { getEffectiveTier } = require('../../../src/services/subscriptionService');
const { getTierLimits, isUnlimited } = require('../../../src/services/tierConfigService');

describe('usageTrackingService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getTodayDateKey', () => {
    test('returns YYYY-MM-DD format', () => {
      const dateKey = getTodayDateKey();
      expect(dateKey).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    });

    test('returns date in IST timezone', () => {
      const dateKey = getTodayDateKey();

      // Get expected IST date using the same method
      const formatter = new Intl.DateTimeFormat('en-CA', {
        timeZone: 'Asia/Kolkata',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit'
      });
      const expectedDate = formatter.format(new Date());

      expect(dateKey).toBe(expectedDate);
    });

    test('handles timezone edge cases near midnight', () => {
      // This test verifies the IST calculation doesn't break
      const dateKey = getTodayDateKey();
      const parts = dateKey.split('-');

      expect(parts).toHaveLength(3);
      expect(Number(parts[0])).toBeGreaterThanOrEqual(2020);
      expect(Number(parts[1])).toBeGreaterThanOrEqual(1);
      expect(Number(parts[1])).toBeLessThanOrEqual(12);
      expect(Number(parts[2])).toBeGreaterThanOrEqual(1);
      expect(Number(parts[2])).toBeLessThanOrEqual(31);
    });
  });

  describe('getNextMidnightIST', () => {
    test('returns a Date object', () => {
      const midnight = getNextMidnightIST();
      expect(midnight).toBeInstanceOf(Date);
    });

    test('returns a future timestamp', () => {
      const midnight = getNextMidnightIST();
      const now = new Date();

      // Midnight should be within 24 hours from now
      const diffMs = midnight.getTime() - now.getTime();
      expect(diffMs).toBeGreaterThan(0);
      expect(diffMs).toBeLessThanOrEqual(24 * 60 * 60 * 1000);
    });

    test('returns 18:30 UTC (midnight IST)', () => {
      const midnight = getNextMidnightIST();

      // Midnight IST should be at 18:30 UTC
      expect(midnight.getUTCHours()).toBe(18);
      expect(midnight.getUTCMinutes()).toBe(30);
      expect(midnight.getUTCSeconds()).toBe(0);
    });
  });

  describe('getUsage', () => {
    test('returns usage info for free tier', async () => {
      getEffectiveTier.mockResolvedValue({ tier: 'free', source: 'default' });
      getTierLimits.mockResolvedValue({ snap_solve_daily: 5, daily_quiz_daily: 1 });

      const usage = await getUsage('test-user', 'snap_solve');

      expect(usage).toHaveProperty('used');
      expect(usage).toHaveProperty('limit', 5);
      expect(usage).toHaveProperty('remaining');
      expect(usage).toHaveProperty('is_unlimited', false);
      expect(usage).toHaveProperty('tier', 'free');
    });

    test('returns unlimited for ultra tier', async () => {
      getEffectiveTier.mockResolvedValue({ tier: 'ultra', source: 'override' });
      getTierLimits.mockResolvedValue({ snap_solve_daily: -1, daily_quiz_daily: -1 });
      isUnlimited.mockReturnValue(true);

      const usage = await getUsage('test-user', 'snap_solve');

      expect(usage.is_unlimited).toBe(true);
      expect(usage.limit).toBe(-1);
      expect(usage.remaining).toBe(-1);
      expect(usage.resets_at).toBeNull();
    });
  });

  describe('canUse', () => {
    test('returns allowed=true for user with remaining usage', async () => {
      getEffectiveTier.mockResolvedValue({ tier: 'free', source: 'default' });
      getTierLimits.mockResolvedValue({ snap_solve_daily: 5, daily_quiz_daily: 1 });
      isUnlimited.mockReturnValue(false);

      const result = await canUse('test-user', 'snap_solve');

      expect(result.allowed).toBe(true);
      expect(result.remaining).toBeGreaterThan(0);
    });

    test('returns allowed=true for unlimited users', async () => {
      getEffectiveTier.mockResolvedValue({ tier: 'ultra', source: 'override' });
      getTierLimits.mockResolvedValue({ snap_solve_daily: -1, daily_quiz_daily: -1 });
      isUnlimited.mockReturnValue(true);

      const result = await canUse('test-user', 'snap_solve');

      expect(result.allowed).toBe(true);
      expect(result.is_unlimited).toBe(true);
    });
  });

  describe('incrementUsage', () => {
    test('increments usage for limited users', async () => {
      getEffectiveTier.mockResolvedValue({ tier: 'free', source: 'default' });
      getTierLimits.mockResolvedValue({ snap_solve_daily: 5, daily_quiz_daily: 1 });
      isUnlimited.mockReturnValue(false);

      const result = await incrementUsage('test-user', 'snap_solve');

      expect(result.allowed).toBe(true);
      expect(result.used).toBe(1);
    });

    test('tracks usage for unlimited users but always allows', async () => {
      getEffectiveTier.mockResolvedValue({ tier: 'ultra', source: 'override' });
      getTierLimits.mockResolvedValue({ snap_solve_daily: -1, daily_quiz_daily: -1 });
      isUnlimited.mockReturnValue(true);

      const result = await incrementUsage('test-user', 'snap_solve');

      expect(result.allowed).toBe(true);
      expect(result.is_unlimited).toBe(true);
      expect(result.limit).toBe(-1);
    });

    test('rejects increment when limit reached', async () => {
      const { db } = require('../../../src/config/firebase');

      // Mock transaction to return usage at limit
      db.runTransaction.mockImplementation(async (callback) => {
        const mockTxn = {
          get: jest.fn(() => Promise.resolve({
            exists: true,
            data: () => ({ snap_solve: 5 }), // At limit
          })),
          set: jest.fn(),
        };
        return callback(mockTxn);
      });

      getEffectiveTier.mockResolvedValue({ tier: 'free', source: 'default' });
      getTierLimits.mockResolvedValue({ snap_solve_daily: 5, daily_quiz_daily: 1 });
      isUnlimited.mockReturnValue(false);

      const result = await incrementUsage('test-user', 'snap_solve');

      expect(result.allowed).toBe(false);
      expect(result.used).toBe(5);
      expect(result.remaining).toBe(0);
    });
  });

  describe('decrementUsage', () => {
    test('decrements usage for rollback', async () => {
      const { db } = require('../../../src/config/firebase');
      const { decrementUsage } = require('../../../src/services/usageTrackingService');

      // Mock transaction to return usage > 0
      db.runTransaction.mockImplementation(async (callback) => {
        const mockTxn = {
          get: jest.fn(() => Promise.resolve({
            exists: true,
            data: () => ({ snap_solve: 3 }),
          })),
          set: jest.fn(),
        };
        return callback(mockTxn);
      });

      const result = await decrementUsage('test-user', 'snap_solve');

      expect(result).toBe(true);
    });

    test('does not decrement below zero', async () => {
      const { db } = require('../../../src/config/firebase');
      const { decrementUsage } = require('../../../src/services/usageTrackingService');

      // Mock transaction to return usage = 0
      db.runTransaction.mockImplementation(async (callback) => {
        const mockTxn = {
          get: jest.fn(() => Promise.resolve({
            exists: true,
            data: () => ({ snap_solve: 0 }),
          })),
          set: jest.fn(),
        };
        return callback(mockTxn);
      });

      const result = await decrementUsage('test-user', 'snap_solve');

      // Should still return true (operation completed) but not decrement
      expect(result).toBe(true);
    });
  });
});
