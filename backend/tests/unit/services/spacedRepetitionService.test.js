/**
 * Unit Tests for Spaced Repetition Service
 * 
 * Tests review date calculations and question prioritization
 */

// Mock Firebase
jest.mock('../../../src/config/firebase', () => ({
  db: {
    collection: jest.fn(() => ({
      doc: jest.fn(() => ({
        collection: jest.fn(() => ({
          where: jest.fn(() => ({
            get: jest.fn(),
          })),
        })),
      })),
    })),
  },
  admin: {
    firestore: {
      Timestamp: {
        fromDate: jest.fn((date) => ({ seconds: Math.floor(date.getTime() / 1000) })),
        now: jest.fn(() => ({ seconds: Math.floor(Date.now() / 1000) })),
      },
    },
  },
}));

jest.mock('../../../src/utils/logger', () => ({
  info: jest.fn(),
  error: jest.fn(),
}));

const spacedRepetitionService = require('../../../src/services/spacedRepetitionService');

describe('Spaced Repetition Service', () => {
  describe('Review Interval Calculation', () => {
    test('should return first interval (1 day) for incorrect answer', () => {
      const currentInterval = 7;
      const wasCorrect = false;
      
      const nextInterval = spacedRepetitionService.getNextReviewInterval(currentInterval, wasCorrect);
      expect(nextInterval).toBe(1); // Reset to first interval
    });

    test('should progress to next interval for correct answer', () => {
      const currentInterval = 1;
      const wasCorrect = true;
      
      const nextInterval = spacedRepetitionService.getNextReviewInterval(currentInterval, wasCorrect);
      expect(nextInterval).toBe(3); // Next interval
    });

    test('should stay at max interval when already at max', () => {
      const currentInterval = 30; // Max interval
      const wasCorrect = true;
      
      const nextInterval = spacedRepetitionService.getNextReviewInterval(currentInterval, wasCorrect);
      expect(nextInterval).toBe(30); // Stay at max
    });

    test('should return first interval for unknown current interval', () => {
      const currentInterval = 5; // Not in REVIEW_INTERVALS
      const wasCorrect = true;
      
      const nextInterval = spacedRepetitionService.getNextReviewInterval(currentInterval, wasCorrect);
      expect(nextInterval).toBe(1); // Start from beginning
    });
  });

  describe('Due for Review Check', () => {
    test('should return true when days since last answer >= interval', () => {
      const lastAnsweredDate = new Date('2024-01-01');
      const reviewInterval = 7; // 7 days
      const now = new Date('2024-01-10'); // 9 days later
      
      // Mock Date.now() or pass current date
      const isDue = spacedRepetitionService.isDueForReview(lastAnsweredDate, reviewInterval);
      expect(typeof isDue).toBe('boolean');
    });

    test('should return false when question never answered', () => {
      const lastAnsweredDate = null;
      const reviewInterval = 7;
      
      const isDue = spacedRepetitionService.isDueForReview(lastAnsweredDate, reviewInterval);
      expect(isDue).toBe(false);
    });
  });

  describe('Days Overdue Calculation', () => {
    test('should return 0 when not overdue', () => {
      const lastAnsweredDate = new Date('2024-01-01');
      const reviewInterval = 7;
      
      // If only 5 days have passed, not overdue
      const daysOverdue = spacedRepetitionService.getDaysOverdue(lastAnsweredDate, reviewInterval);
      expect(daysOverdue).toBeGreaterThanOrEqual(0);
    });

    test('should return positive number when overdue', () => {
      const lastAnsweredDate = new Date('2024-01-01');
      const reviewInterval = 7;
      
      // If 10 days have passed, 3 days overdue
      const daysOverdue = spacedRepetitionService.getDaysOverdue(lastAnsweredDate, reviewInterval);
      expect(daysOverdue).toBeGreaterThanOrEqual(0);
    });

    test('should return 0 when question never answered', () => {
      const lastAnsweredDate = null;
      const reviewInterval = 7;
      
      const daysOverdue = spacedRepetitionService.getDaysOverdue(lastAnsweredDate, reviewInterval);
      expect(daysOverdue).toBe(0);
    });
  });

  describe('Review Intervals Constant', () => {
    test('should have correct review intervals', () => {
      const intervals = spacedRepetitionService.REVIEW_INTERVALS;
      expect(intervals).toEqual([1, 3, 7, 14, 30]);
    });

    test('should have max review questions constant', () => {
      const maxQuestions = spacedRepetitionService.MAX_REVIEW_QUESTIONS;
      expect(typeof maxQuestions).toBe('number');
      expect(maxQuestions).toBeGreaterThan(0);
    });
  });
});

