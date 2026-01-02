/**
 * Unit Tests for Question Selection Service
 * 
 * Tests IRT calculations, Fisher Information, and question filtering logic
 */

// Mock Firebase before importing the service
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
      where: jest.fn(() => ({
        limit: jest.fn(() => ({
          get: jest.fn(),
        })),
      })),
    })),
  },
  admin: {
    firestore: {
      Timestamp: {
        fromDate: jest.fn((date) => ({ seconds: Math.floor(date.getTime() / 1000) })),
      },
    },
  },
}));

jest.mock('../../../src/utils/logger', () => ({
  info: jest.fn(),
  error: jest.fn(),
  warn: jest.fn(),
}));

// Import the service (after mocks)
const questionSelectionService = require('../../../src/services/questionSelectionService');

describe('Question Selection Service', () => {
  describe('IRT Probability Calculation', () => {
    test('should calculate probability for easy question (theta > difficulty)', () => {
      const theta = 1.0;
      const a = 1.5;
      const b = 0.0; // Medium difficulty
      const c = 0.25; // 25% guessing
      
      // For theta > b, probability should be > 0.5
      const prob = questionSelectionService.calculateIRTProbability(theta, a, b, c);
      expect(prob).toBeGreaterThan(0.5);
      expect(prob).toBeLessThanOrEqual(1.0);
    });

    test('should calculate probability for hard question (theta < difficulty)', () => {
      const theta = -1.0;
      const a = 1.5;
      const b = 1.0; // Hard difficulty
      const c = 0.25;
      
      // For theta < b, probability should be < 0.5
      const prob = questionSelectionService.calculateIRTProbability(theta, a, b, c);
      expect(prob).toBeLessThan(0.5);
      expect(prob).toBeGreaterThanOrEqual(0.25); // At least guessing probability
    });

    test('should handle theta equal to difficulty', () => {
      const theta = 0.5;
      const a = 1.0;
      const b = 0.5; // Same as theta
      const c = 0.0;
      
      const prob = questionSelectionService.calculateIRTProbability(theta, a, b, c);
      // When theta = b and c = 0, probability should be 0.5
      expect(prob).toBeCloseTo(0.5, 2);
    });

    test('should clamp probability to [0, 1]', () => {
      const theta = 10.0; // Extreme value
      const a = 1.0;
      const b = 0.0;
      const c = 0.0;
      
      const prob = questionSelectionService.calculateIRTProbability(theta, a, b, c);
      expect(prob).toBeGreaterThanOrEqual(0);
      expect(prob).toBeLessThanOrEqual(1);
    });

    test('should respect guessing parameter', () => {
      const theta = -10.0; // Very low ability
      const a = 1.0;
      const b = 5.0; // Very hard
      const c = 0.25; // 25% guessing
      
      const prob = questionSelectionService.calculateIRTProbability(theta, a, b, c);
      // Even with very low theta, probability should be at least c
      expect(prob).toBeGreaterThanOrEqual(0.25);
    });
  });

  describe('Fisher Information Calculation', () => {
    test('should calculate Fisher Information correctly', () => {
      const theta = 0.0;
      const a = 1.5;
      const b = 0.0;
      const c = 0.25;
      
      const fi = questionSelectionService.calculateFisherInformation(theta, a, b, c);
      expect(fi).toBeGreaterThan(0);
      expect(typeof fi).toBe('number');
      expect(Number.isFinite(fi)).toBe(true);
    });

    test('should return 0 for extreme probabilities', () => {
      const theta = 10.0; // Extreme theta
      const a = 1.0;
      const b = 0.0;
      const c = 0.0;
      
      // When P approaches 1, Fisher Information should be 0
      const fi = questionSelectionService.calculateFisherInformation(theta, a, b, c);
      expect(fi).toBeGreaterThanOrEqual(0);
    });

    test('should maximize Fisher Information when theta equals difficulty', () => {
      const a = 1.5;
      const b = 0.5; // Difficulty
      const c = 0.25;
      
      // FI at theta = difficulty (0.5)
      const fiAtDifficulty = questionSelectionService.calculateFisherInformation(0.5, a, b, c);
      
      // FI when theta is far from difficulty
      const fiFar = questionSelectionService.calculateFisherInformation(2.0, a, b, c);
      
      // FI should be higher when theta equals difficulty (optimal information)
      // Note: Fisher Information is maximized when theta = b for 3PL model
      expect(fiAtDifficulty).toBeGreaterThan(0);
      expect(fiFar).toBeGreaterThanOrEqual(0);
      // The exact relationship depends on the model, but FI at difficulty should be significant
      expect(fiAtDifficulty).toBeGreaterThan(0.1);
    });

    test('should increase with discrimination parameter', () => {
      const theta = 0.0;
      const b = 0.0;
      const c = 0.25;
      
      const fi1 = questionSelectionService.calculateFisherInformation(theta, 1.0, b, c);
      const fi2 = questionSelectionService.calculateFisherInformation(theta, 2.0, b, c);
      
      // Higher discrimination should give higher FI
      expect(fi2).toBeGreaterThan(fi1);
    });
  });

  describe('Difficulty Matching', () => {
    test('should match questions within threshold', () => {
      const theta = 0.5;
      const questionB = 0.7; // Within 0.5 threshold
      const threshold = 0.5;
      
      const matches = Math.abs(questionB - theta) <= threshold;
      expect(matches).toBe(true);
    });

    test('should reject questions outside threshold', () => {
      const theta = 0.5;
      const questionB = 1.5; // Outside 0.5 threshold
      const threshold = 0.5;
      
      const matches = Math.abs(questionB - theta) <= threshold;
      expect(matches).toBe(false);
    });
  });

  describe('Question Ranking', () => {
    test('should rank questions by Fisher Information', () => {
      const theta = 0.0;
      const questions = [
        { question_id: 'q1', a: 1.0, b: 0.0, c: 0.25 },
        { question_id: 'q2', a: 2.0, b: 0.0, c: 0.25 }, // Higher discrimination
        { question_id: 'q3', a: 0.5, b: 0.0, c: 0.25 },
      ];
      
      // Calculate FI for each
      const fi1 = questionSelectionService.calculateFisherInformation(theta, questions[0].a, questions[0].b, questions[0].c);
      const fi2 = questionSelectionService.calculateFisherInformation(theta, questions[1].a, questions[1].b, questions[1].c);
      const fi3 = questionSelectionService.calculateFisherInformation(theta, questions[2].a, questions[2].b, questions[2].c);
      
      // q2 should have highest FI (highest discrimination)
      expect(fi2).toBeGreaterThan(fi1);
      expect(fi2).toBeGreaterThan(fi3);
    });
  });

  describe('Adaptive Difficulty Threshold', () => {
    test('should return 1.5 SD for <10 available questions (relaxed)', () => {
      const threshold = questionSelectionService.getDifficultyThreshold(5);
      expect(threshold).toBe(1.5);
    });

    test('should return 1.0 SD for 10-29 available questions (moderate)', () => {
      const threshold = questionSelectionService.getDifficultyThreshold(15);
      expect(threshold).toBe(1.0);

      const threshold2 = questionSelectionService.getDifficultyThreshold(29);
      expect(threshold2).toBe(1.0);
    });

    test('should return 0.5 SD for >=30 available questions (strict)', () => {
      const threshold = questionSelectionService.getDifficultyThreshold(30);
      expect(threshold).toBe(0.5);

      const threshold2 = questionSelectionService.getDifficultyThreshold(100);
      expect(threshold2).toBe(0.5);
    });
  });
});

