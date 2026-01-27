/**
 * Unit Tests for Progress Service (Optimized getCumulativeStats)
 *
 * Tests the optimized getCumulativeStats function that uses denormalized
 * data instead of reading 1000 response documents
 */

// Mock Firebase
jest.mock('../../../../src/config/firebase', () => ({
  db: {
    collection: jest.fn(),
  },
  admin: {
    firestore: {
      FieldValue: {
        serverTimestamp: jest.fn(() => ({ _methodName: 'FieldValue.serverTimestamp' })),
        increment: jest.fn((val) => ({ _methodName: 'FieldValue.increment', _operand: val })),
      },
      Timestamp: {
        fromDate: jest.fn((date) => ({ seconds: Math.floor(date.getTime() / 1000) })),
      },
    },
  },
}));

jest.mock('../../../../src/utils/logger', () => ({
  info: jest.fn(),
  error: jest.fn(),
  warn: jest.fn(),
}));

jest.mock('../../../../src/utils/firestoreRetry', () => ({
  retryFirestoreOperation: jest.fn((fn) => fn()),
}));

const { getCumulativeStats, getChapterStatus } = require('../../../../src/services/progressService');
const { db } = require('../../../../src/config/firebase');

describe('Progress Service - Cumulative Stats', () => {
  describe('getCumulativeStats (Optimized)', () => {
    beforeEach(() => {
      jest.clearAllMocks();
    });

    test('should return stats from denormalized cumulative_stats field', async () => {
      // Mock user document with cumulative_stats
      const mockUserDoc = {
        exists: true,
        data: () => ({
          completed_quiz_count: 10,
          total_questions_solved: 100,
          total_time_spent_minutes: 150,
          learning_phase: 'exploration',
          cumulative_stats: {
            total_questions_correct: 75,
            total_questions_attempted: 100,
            last_updated: '2026-01-01T00:00:00Z',
          },
          theta_by_chapter: {
            physics_kinematics: { attempts: 20, percentile: 85 },
            physics_laws_of_motion: { attempts: 15, percentile: 72 },
            chemistry_organic_chemistry: { attempts: 10, percentile: 60 },
            mathematics_calculus: { attempts: 25, percentile: 90 },
          },
        }),
      };

      // Mock Firestore calls
      const mockGet = jest.fn().mockResolvedValue(mockUserDoc);
      const mockDoc = jest.fn().mockReturnValue({ get: mockGet });
      const mockCollection = jest.fn().mockReturnValue({ doc: mockDoc });
      db.collection = mockCollection;

      // Call function
      const result = await getCumulativeStats('test_user_123');

      // Assertions
      expect(result).toEqual({
        total_quizzes: 10,
        completed_quiz_count: 10,
        total_questions: 100,
        total_questions_correct: 75,
        total_questions_attempted: 100,
        total_time_minutes: 150,
        overall_accuracy: 0.75, // 75/100
        chapters_explored: 4, // All 4 chapters have attempts > 0
        chapters_confident: 3, // 3 chapters have percentile >= 70
        learning_phase: 'exploration',
        last_updated: '2026-01-01T00:00:00Z',
      });

      // Verify NO additional Firestore reads (only 1 user doc read)
      expect(mockCollection).toHaveBeenCalledTimes(1);
      expect(mockCollection).toHaveBeenCalledWith('users');
      expect(mockDoc).toHaveBeenCalledWith('test_user_123');
      expect(mockGet).toHaveBeenCalledTimes(1);
    });

    test('should handle missing cumulative_stats field (default values)', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({
          completed_quiz_count: 5,
          total_questions_solved: 50,
          total_time_spent_minutes: 75,
          learning_phase: 'exploration',
          // No cumulative_stats field
          theta_by_chapter: {},
        }),
      };

      const mockGet = jest.fn().mockResolvedValue(mockUserDoc);
      const mockDoc = jest.fn().mockReturnValue({ get: mockGet });
      db.collection = jest.fn().mockReturnValue({ doc: mockDoc });

      const result = await getCumulativeStats('test_user_123');

      // Should use default values
      expect(result.total_questions_correct).toBe(0);
      expect(result.total_questions_attempted).toBe(0);
      expect(result.overall_accuracy).toBe(0.0);
    });

    test('should calculate chapters_explored correctly', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({
          completed_quiz_count: 5,
          cumulative_stats: {
            total_questions_correct: 30,
            total_questions_attempted: 50,
          },
          theta_by_chapter: {
            physics_kinematics: { attempts: 10, percentile: 60 },
            physics_laws_of_motion: { attempts: 0, percentile: 50 }, // Not explored
            chemistry_organic_chemistry: { attempts: 5, percentile: 55 },
          },
        }),
      };

      const mockGet = jest.fn().mockResolvedValue(mockUserDoc);
      const mockDoc = jest.fn().mockReturnValue({ get: mockGet });
      db.collection = jest.fn().mockReturnValue({ doc: mockDoc });

      const result = await getCumulativeStats('test_user_123');

      // Only 2 chapters have attempts > 0
      expect(result.chapters_explored).toBe(2);
    });

    test('should calculate chapters_confident correctly (percentile >= 70)', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({
          completed_quiz_count: 5,
          cumulative_stats: {
            total_questions_correct: 30,
            total_questions_attempted: 50,
          },
          theta_by_chapter: {
            physics_kinematics: { attempts: 10, percentile: 85 }, // Confident
            physics_laws_of_motion: { attempts: 5, percentile: 72 }, // Confident
            chemistry_organic_chemistry: { attempts: 8, percentile: 60 }, // Not confident
            mathematics_calculus: { attempts: 12, percentile: 90 }, // Confident
          },
        }),
      };

      const mockGet = jest.fn().mockResolvedValue(mockUserDoc);
      const mockDoc = jest.fn().mockReturnValue({ get: mockGet });
      db.collection = jest.fn().mockReturnValue({ doc: mockDoc });

      const result = await getCumulativeStats('test_user_123');

      // 3 chapters have percentile >= 70
      expect(result.chapters_confident).toBe(3);
    });

    test('should calculate overall_accuracy correctly', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({
          completed_quiz_count: 10,
          cumulative_stats: {
            total_questions_correct: 67,
            total_questions_attempted: 100,
          },
          theta_by_chapter: {},
        }),
      };

      const mockGet = jest.fn().mockResolvedValue(mockUserDoc);
      const mockDoc = jest.fn().mockReturnValue({ get: mockGet });
      db.collection = jest.fn().mockReturnValue({ doc: mockDoc });

      const result = await getCumulativeStats('test_user_123');

      // 67/100 = 0.67, rounded to 3 decimals
      expect(result.overall_accuracy).toBe(0.67);
    });

    test('should handle user not found', async () => {
      const mockUserDoc = {
        exists: false,
      };

      const mockGet = jest.fn().mockResolvedValue(mockUserDoc);
      const mockDoc = jest.fn().mockReturnValue({ get: mockGet });
      db.collection = jest.fn().mockReturnValue({ doc: mockDoc });

      await expect(getCumulativeStats('nonexistent_user')).rejects.toThrow(
        'User nonexistent_user not found'
      );
    });

    test('should handle empty theta_by_chapter', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({
          completed_quiz_count: 0,
          cumulative_stats: {
            total_questions_correct: 0,
            total_questions_attempted: 0,
          },
          theta_by_chapter: {},
        }),
      };

      const mockGet = jest.fn().mockResolvedValue(mockUserDoc);
      const mockDoc = jest.fn().mockReturnValue({ get: mockGet });
      db.collection = jest.fn().mockReturnValue({ doc: mockDoc });

      const result = await getCumulativeStats('new_user');

      expect(result.chapters_explored).toBe(0);
      expect(result.chapters_confident).toBe(0);
    });
  });

  describe('getChapterStatus', () => {
    test('should return "strong" for percentile >= 70', () => {
      expect(getChapterStatus(1.0, 85)).toBe('strong');
      expect(getChapterStatus(0.5, 70)).toBe('strong');
      expect(getChapterStatus(2.0, 98)).toBe('strong');
    });

    test('should return "average" for percentile 40-69', () => {
      expect(getChapterStatus(0.0, 50)).toBe('average');
      expect(getChapterStatus(-0.3, 40)).toBe('average');
      expect(getChapterStatus(0.3, 69)).toBe('average');
    });

    test('should return "weak" for percentile 1-39', () => {
      expect(getChapterStatus(-1.0, 30)).toBe('weak');
      expect(getChapterStatus(-0.5, 1)).toBe('weak');
      expect(getChapterStatus(-1.5, 15)).toBe('weak');
    });

    test('should return "untested" for percentile 0', () => {
      expect(getChapterStatus(0.0, 0)).toBe('untested');
    });
  });

  describe('Cost Optimization Verification', () => {
    test('should only read 1 Firestore document (not 1000)', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({
          completed_quiz_count: 10,
          cumulative_stats: {
            total_questions_correct: 75,
            total_questions_attempted: 100,
          },
          theta_by_chapter: {},
        }),
      };

      const mockGet = jest.fn().mockResolvedValue(mockUserDoc);
      const mockDoc = jest.fn().mockReturnValue({ get: mockGet });
      const mockCollection = jest.fn().mockReturnValue({ doc: mockDoc });
      db.collection = mockCollection;

      await getCumulativeStats('test_user');

      // CRITICAL: Should only call .get() ONCE (user document)
      // OLD implementation: Called .get() 1001 times (1 user + 1000 responses)
      expect(mockGet).toHaveBeenCalledTimes(1);

      // Should NOT query responses collection
      expect(mockCollection).not.toHaveBeenCalledWith('daily_quiz_responses');
    });
  });
});
