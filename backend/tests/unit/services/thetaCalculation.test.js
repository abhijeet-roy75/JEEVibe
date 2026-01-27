/**
 * Unit Tests for Theta Calculation Functions (Pure Functions)
 *
 * Tests the new pure calculation functions that enable atomic transactions:
 * - calculateChapterThetaUpdate
 * - calculateSubjectAndOverallThetaUpdate
 */

// Mock Firebase before importing the service
jest.mock('../../../../src/config/firebase', () => ({
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

jest.mock('../../../../src/utils/logger', () => ({
  info: jest.fn(),
  error: jest.fn(),
  warn: jest.fn(),
}));

// Import the service (after mocks)
const {
  calculateChapterThetaUpdate,
  calculateSubjectAndOverallThetaUpdate,
} = require('../../../../src/services/thetaUpdateService');

describe('Theta Calculation Service - Pure Functions', () => {
  describe('calculateChapterThetaUpdate', () => {
    test('should calculate theta correctly for all correct answers', () => {
      const currentChapterData = {
        theta: 0.0,
        confidence_SE: 0.6,
        attempts: 0,
        accuracy: 0.0,
      };

      const responses = [
        { questionIRT: { a: 1.5, b: 0.0, c: 0.25 }, isCorrect: true },
        { questionIRT: { a: 1.5, b: 0.5, c: 0.25 }, isCorrect: true },
        { questionIRT: { a: 1.0, b: -0.5, c: 0.25 }, isCorrect: true },
      ];

      const result = calculateChapterThetaUpdate(currentChapterData, responses);

      // Assertions
      expect(result).toHaveProperty('theta');
      expect(result).toHaveProperty('percentile');
      expect(result).toHaveProperty('confidence_SE');
      expect(result).toHaveProperty('attempts');
      expect(result).toHaveProperty('accuracy');
      expect(result).toHaveProperty('last_updated');

      // Theta should increase for correct answers
      expect(result.theta).toBeGreaterThan(0);

      // SE should decrease (more confident)
      expect(result.confidence_SE).toBeLessThan(0.6);

      // Accuracy should be 100% (stored as percentage)
      expect(result.accuracy).toBe(100);

      // Attempts should be 3
      expect(result.attempts).toBe(3);

      // Percentile should be > 50 (above average)
      expect(result.percentile).toBeGreaterThan(50);
    });

    test('should decrease theta for all incorrect answers', () => {
      const currentChapterData = {
        theta: 0.0,
        confidence_SE: 0.6,
        attempts: 0,
        accuracy: 0.0,
      };

      const responses = [
        { questionIRT: { a: 1.5, b: 0.0, c: 0.25 }, isCorrect: false },
        { questionIRT: { a: 1.5, b: -0.5, c: 0.25 }, isCorrect: false },
        { questionIRT: { a: 1.0, b: 0.5, c: 0.25 }, isCorrect: false },
      ];

      const result = calculateChapterThetaUpdate(currentChapterData, responses);

      // Theta should decrease for incorrect answers
      expect(result.theta).toBeLessThan(0);

      // Accuracy should be 0% (stored as percentage)
      expect(result.accuracy).toBe(0);

      // Percentile should be < 50 (below average)
      expect(result.percentile).toBeLessThan(50);
    });

    test('should combine with existing attempts and accuracy', () => {
      const currentChapterData = {
        theta: 1.0,
        confidence_SE: 0.4,
        attempts: 10,
        accuracy: 0.7, // 70% previous accuracy (7/10 correct)
      };

      const responses = [
        { questionIRT: { a: 1.5, b: 1.0, c: 0.25 }, isCorrect: true },
        { questionIRT: { a: 1.5, b: 1.0, c: 0.25 }, isCorrect: true },
      ];

      const result = calculateChapterThetaUpdate(currentChapterData, responses);

      // Should have 12 total attempts
      expect(result.attempts).toBe(12);

      // Weighted accuracy: (7 + 2) / 12 = 0.75 = 75% (stored as percentage)
      expect(result.accuracy).toBe(75);

      // Theta should still be positive (was 1.0, both correct)
      expect(result.theta).toBeGreaterThan(0);
    });

    test('should handle mixed correct/incorrect responses', () => {
      const currentChapterData = {
        theta: 0.0,
        confidence_SE: 0.6,
        attempts: 0,
        accuracy: 0.0,
      };

      const responses = [
        { questionIRT: { a: 1.5, b: 0.0, c: 0.25 }, isCorrect: true },
        { questionIRT: { a: 1.5, b: 0.0, c: 0.25 }, isCorrect: false },
        { questionIRT: { a: 1.5, b: 0.0, c: 0.25 }, isCorrect: true },
        { questionIRT: { a: 1.5, b: 0.0, c: 0.25 }, isCorrect: false },
      ];

      const result = calculateChapterThetaUpdate(currentChapterData, responses);

      // Accuracy should be 50% (stored as percentage)
      expect(result.accuracy).toBe(50);

      // Attempts should be 4
      expect(result.attempts).toBe(4);

      // Theta should be bounded to [-3, +3]
      expect(result.theta).toBeGreaterThanOrEqual(-3.0);
      expect(result.theta).toBeLessThanOrEqual(3.0);

      // Note: The exact theta value depends on the IRT gradient descent algorithm.
      // With learning rate 0.3 and these specific parameters, theta may vary.
      // The important thing is it's bounded and reflects the response pattern.
    });

    test('should bound theta to [-3, +3]', () => {
      const currentChapterData = {
        theta: 2.9,
        confidence_SE: 0.2,
        attempts: 100,
        accuracy: 0.95,
      };

      const responses = Array(20)
        .fill(null)
        .map(() => ({
          questionIRT: { a: 2.0, b: 2.5, c: 0.0 },
          isCorrect: true,
        }));

      const result = calculateChapterThetaUpdate(currentChapterData, responses);

      // Theta should be capped at 3.0
      expect(result.theta).toBeLessThanOrEqual(3.0);
      expect(result.theta).toBeGreaterThanOrEqual(-3.0);
    });

    test('should bound SE to [0.15, 0.6]', () => {
      const currentChapterData = {
        theta: 0.0,
        confidence_SE: 0.2,
        attempts: 100,
        accuracy: 0.5,
      };

      const responses = Array(50)
        .fill(null)
        .map(() => ({
          questionIRT: { a: 2.0, b: 0.0, c: 0.25 },
          isCorrect: true,
        }));

      const result = calculateChapterThetaUpdate(currentChapterData, responses);

      // SE should be bounded
      expect(result.confidence_SE).toBeGreaterThanOrEqual(0.15);
      expect(result.confidence_SE).toBeLessThanOrEqual(0.6);
    });

    test('should include theta_delta and se_delta metadata', () => {
      const currentChapterData = {
        theta: 1.0,
        confidence_SE: 0.5,
        attempts: 5,
        accuracy: 0.6,
      };

      const responses = [
        { questionIRT: { a: 1.5, b: 1.0, c: 0.25 }, isCorrect: true },
        { questionIRT: { a: 1.5, b: 1.0, c: 0.25 }, isCorrect: true },
      ];

      const result = calculateChapterThetaUpdate(currentChapterData, responses);

      expect(result).toHaveProperty('theta_delta');
      expect(result).toHaveProperty('se_delta');

      // Theta delta should be positive (correct answers increase theta)
      expect(result.theta_delta).toBeGreaterThan(0);

      // SE delta should be negative (more answers decrease uncertainty)
      expect(result.se_delta).toBeLessThan(0);
    });

    test('should handle empty previous attempts (new chapter)', () => {
      const currentChapterData = {
        theta: 0.0,
        confidence_SE: 0.6,
        attempts: 0,
        accuracy: 0.0,
      };

      const responses = [
        { questionIRT: { a: 1.5, b: 0.0, c: 0.25 }, isCorrect: true },
      ];

      const result = calculateChapterThetaUpdate(currentChapterData, responses);

      // Should work correctly with no previous attempts
      expect(result.attempts).toBe(1);
      expect(result.accuracy).toBe(100); // 100% (stored as percentage)
      expect(result.theta).toBeGreaterThan(0);
    });
  });

  describe('calculateSubjectAndOverallThetaUpdate', () => {
    test('should calculate subject thetas from chapter thetas', () => {
      const thetaByChapter = {
        physics_kinematics: { theta: 1.0, percentile: 84, attempts: 10, accuracy: 0.8 },
        physics_laws_of_motion: { theta: 0.5, percentile: 69, attempts: 8, accuracy: 0.7 },
        chemistry_organic_chemistry: {
          theta: -0.5,
          percentile: 31,
          attempts: 12,
          accuracy: 0.6,
        },
        mathematics_calculus: { theta: 1.5, percentile: 93, attempts: 15, accuracy: 0.9 },
      };

      const result = calculateSubjectAndOverallThetaUpdate(thetaByChapter);

      // Should have all three subjects
      expect(result.theta_by_subject).toHaveProperty('physics');
      expect(result.theta_by_subject).toHaveProperty('chemistry');
      expect(result.theta_by_subject).toHaveProperty('mathematics');

      // Should have subject accuracy
      expect(result.subject_accuracy).toHaveProperty('physics');
      expect(result.subject_accuracy).toHaveProperty('chemistry');
      expect(result.subject_accuracy).toHaveProperty('mathematics');

      // Should have overall theta
      expect(result).toHaveProperty('overall_theta');
      expect(result).toHaveProperty('overall_percentile');

      // Overall theta should be a number
      expect(typeof result.overall_theta).toBe('number');
      expect(result.overall_theta).toBeGreaterThanOrEqual(-3);
      expect(result.overall_theta).toBeLessThanOrEqual(3);
    });

    test('should calculate subject accuracy correctly', () => {
      const thetaByChapter = {
        physics_kinematics: { theta: 1.0, percentile: 84, attempts: 10, accuracy: 0.8 },
        physics_laws_of_motion: { theta: 0.5, percentile: 69, attempts: 10, accuracy: 0.6 },
        chemistry_organic_chemistry: {
          theta: -0.5,
          percentile: 31,
          attempts: 10,
          accuracy: 0.5,
        },
      };

      const result = calculateSubjectAndOverallThetaUpdate(thetaByChapter);

      // Physics accuracy: (8 + 6) / (10 + 10) = 14 / 20 = 70%
      expect(result.subject_accuracy.physics.total).toBe(20);
      expect(result.subject_accuracy.physics.correct).toBe(14);
      expect(result.subject_accuracy.physics.accuracy).toBe(70);

      // Chemistry accuracy: 5 / 10 = 50%
      expect(result.subject_accuracy.chemistry.total).toBe(10);
      expect(result.subject_accuracy.chemistry.correct).toBe(5);
      expect(result.subject_accuracy.chemistry.accuracy).toBe(50);
    });

    test('should handle empty chapter data', () => {
      const thetaByChapter = {};

      const result = calculateSubjectAndOverallThetaUpdate(thetaByChapter);

      // Should still return structure
      expect(result).toHaveProperty('theta_by_subject');
      expect(result).toHaveProperty('subject_accuracy');
      expect(result).toHaveProperty('overall_theta');
      expect(result).toHaveProperty('overall_percentile');

      // Overall theta should be 0 (no data)
      expect(result.overall_theta).toBe(0);
    });

    test('should handle single subject', () => {
      const thetaByChapter = {
        physics_kinematics: { theta: 1.0, percentile: 84, attempts: 10, accuracy: 0.8 },
        physics_laws_of_motion: { theta: 0.5, percentile: 69, attempts: 10, accuracy: 0.6 },
      };

      const result = calculateSubjectAndOverallThetaUpdate(thetaByChapter);

      // Should have physics data
      expect(result.theta_by_subject.physics).toBeDefined();

      // Chemistry and math should have default values
      expect(result.subject_accuracy.chemistry.total).toBe(0);
      expect(result.subject_accuracy.mathematics.total).toBe(0);
    });

    test('should weight chapters correctly (high-weight chapters dominate)', () => {
      // Kinematics has weight 1.0 (high importance)
      // Environmental chemistry has weight 0.3 (low importance)
      const thetaByChapter = {
        physics_kinematics: { theta: 2.0, percentile: 98, attempts: 10, accuracy: 0.95 },
        chemistry_environmental_chemistry: {
          theta: -2.0,
          percentile: 2,
          attempts: 10,
          accuracy: 0.1,
        },
      };

      const result = calculateSubjectAndOverallThetaUpdate(thetaByChapter);

      // Overall theta should be closer to high-weight chapter (physics_kinematics = 2.0)
      // than to low-weight chapter (chemistry_environmental_chemistry = -2.0)
      expect(result.overall_theta).toBeGreaterThan(0);
    });

    test('should return consistent results (regression test)', () => {
      const thetaByChapter = {
        physics_kinematics: { theta: 1.0, percentile: 84, attempts: 10, accuracy: 0.8 },
        chemistry_organic_chemistry: {
          theta: 0.5,
          percentile: 69,
          attempts: 10,
          accuracy: 0.7,
        },
        mathematics_calculus: { theta: 1.5, percentile: 93, attempts: 10, accuracy: 0.9 },
      };

      const result1 = calculateSubjectAndOverallThetaUpdate(thetaByChapter);
      const result2 = calculateSubjectAndOverallThetaUpdate(thetaByChapter);

      // Results should be identical for same input
      expect(result1.overall_theta).toBe(result2.overall_theta);
      expect(result1.overall_percentile).toBe(result2.overall_percentile);
    });
  });

  describe('Integration: Chapter -> Subject -> Overall', () => {
    test('should flow correctly from chapter calculation to subject/overall', () => {
      // Start with current data
      const currentThetaByChapter = {
        physics_kinematics: { theta: 0.5, percentile: 69, attempts: 5, accuracy: 0.6 },
      };

      // New quiz responses for kinematics
      const responses = [
        { questionIRT: { a: 1.5, b: 0.5, c: 0.25 }, isCorrect: true },
        { questionIRT: { a: 1.5, b: 0.5, c: 0.25 }, isCorrect: true },
        { questionIRT: { a: 1.5, b: 0.5, c: 0.25 }, isCorrect: true },
      ];

      // Calculate chapter update
      const chapterUpdate = calculateChapterThetaUpdate(
        currentThetaByChapter.physics_kinematics,
        responses
      );

      // Update theta_by_chapter
      const updatedThetaByChapter = {
        ...currentThetaByChapter,
        physics_kinematics: chapterUpdate,
      };

      // Calculate subject and overall
      const subjectUpdate = calculateSubjectAndOverallThetaUpdate(updatedThetaByChapter);

      // Verify flow
      expect(chapterUpdate.theta).toBeGreaterThan(0.5); // Improved from 0.5
      expect(chapterUpdate.attempts).toBe(8); // 5 + 3
      expect(chapterUpdate.accuracy).toBeGreaterThan(60); // Improved (3/3 correct) - stored as percentage

      expect(subjectUpdate.theta_by_subject.physics).toBeDefined();
      expect(subjectUpdate.overall_theta).toBeGreaterThan(0); // Positive overall
    });
  });
});
