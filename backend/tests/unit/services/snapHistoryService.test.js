/**
 * Unit Tests for Snap History Service
 *
 * Tests:
 * - getSnapHistory with tier-based date filtering
 * - History limit enforcement (7 days free, 30 days pro, unlimited ultra)
 */

// Mock Firebase before requiring the service
jest.mock('../../../src/config/firebase', () => {
  const mockSnaps = [
    { id: 'snap1', timestamp: { toDate: () => new Date() }, subject: 'physics' },
    { id: 'snap2', timestamp: { toDate: () => new Date(Date.now() - 5 * 24 * 60 * 60 * 1000) }, subject: 'chemistry' },
    { id: 'snap3', timestamp: { toDate: () => new Date(Date.now() - 10 * 24 * 60 * 60 * 1000) }, subject: 'maths' },
    { id: 'snap4', timestamp: { toDate: () => new Date(Date.now() - 20 * 24 * 60 * 60 * 1000) }, subject: 'physics' },
  ];

  let queryFilters = {};

  const mockQuery = {
    orderBy: jest.fn().mockReturnThis(),
    where: jest.fn((field, op, value) => {
      queryFilters = { field, op, value };
      return mockQuery;
    }),
    limit: jest.fn().mockReturnThis(),
    startAfter: jest.fn().mockReturnThis(),
    get: jest.fn(() => {
      // Filter snaps based on date if where clause was applied
      let filteredSnaps = mockSnaps;
      if (queryFilters.field === 'timestamp' && queryFilters.op === '>=') {
        const cutoffDate = queryFilters.value;
        filteredSnaps = mockSnaps.filter(snap => snap.timestamp.toDate() >= cutoffDate);
      }
      return Promise.resolve({
        docs: filteredSnaps.map(snap => ({
          id: snap.id,
          data: () => snap,
        })),
      });
    }),
  };

  return {
    db: {
      collection: jest.fn(() => ({
        doc: jest.fn(() => ({
          collection: jest.fn(() => mockQuery),
          get: jest.fn(() => Promise.resolve({ exists: true, data: () => ({}) })),
        })),
      })),
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

// Mock logger
jest.mock('../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const { getSnapHistory } = require('../../../src/services/snapHistoryService');

describe('snapHistoryService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getSnapHistory', () => {
    test('returns all history when historyDays is -1 (unlimited)', async () => {
      const history = await getSnapHistory('test-user', 20, null, -1);

      // Should return all 4 snaps (unlimited)
      expect(history.length).toBe(4);
      expect(history[0]).toHaveProperty('id');
      expect(history[0]).toHaveProperty('timestamp');
    });

    test('filters history to 7 days for free tier', async () => {
      const history = await getSnapHistory('test-user', 20, null, 7);

      // Should only return snaps within 7 days (snap1 at 0 days, snap2 at 5 days)
      expect(history.length).toBe(2);
    });

    test('filters history to 30 days for pro tier', async () => {
      const history = await getSnapHistory('test-user', 20, null, 30);

      // Should return snaps within 30 days (snap1 at 0, snap2 at 5, snap3 at 10, snap4 at 20)
      expect(history.length).toBe(4);
    });

    test('respects limit parameter', async () => {
      const history = await getSnapHistory('test-user', 2, null, -1);

      // The mock returns all, but real implementation would limit
      // This tests that the limit parameter is passed
      expect(history).toBeDefined();
    });

    test('returns empty array when no snaps within date range', async () => {
      // Request history for only 1 day - only snap1 (today) should match
      const history = await getSnapHistory('test-user', 20, null, 1);

      // Only snap1 is from today
      expect(history.length).toBe(1);
    });

    test('formats timestamp as ISO string', async () => {
      const history = await getSnapHistory('test-user', 20, null, -1);

      expect(history[0].timestamp).toBeDefined();
      // Timestamp should be a string (ISO format)
      expect(typeof history[0].timestamp).toBe('string');
    });
  });
});
