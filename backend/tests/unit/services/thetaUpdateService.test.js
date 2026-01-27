/**
 * Unit Tests for Theta Update Service
 * 
 * Tests Bayesian theta updates, bounding, and standard error calculations
 */

// Mock Firebase and dependencies
jest.mock('../../../../src/config/firebase', () => ({
  db: {
    collection: jest.fn(() => ({
      doc: jest.fn(() => ({
        update: jest.fn(),
        get: jest.fn(),
      })),
    })),
  },
  admin: {
    firestore: {
      FieldValue: {
        increment: jest.fn(),
      },
    },
  },
}));

jest.mock('../../../../src/utils/logger', () => ({
  info: jest.fn(),
  error: jest.fn(),
  warn: jest.fn(),
}));

jest.mock('../../../../src/services/thetaCalculationService', () => ({
  calculateSubjectTheta: jest.fn(),
  calculateWeightedOverallTheta: jest.fn(),
}));

// Import the service
const thetaUpdateService = require('../../../../src/services/thetaUpdateService');

describe('Theta Update Service', () => {
  describe('Theta Bounding', () => {
    test('should bound theta to [-3, +3] range', () => {
      const bounded1 = thetaUpdateService.boundTheta(-5.0);
      const bounded2 = thetaUpdateService.boundTheta(5.0);
      const bounded3 = thetaUpdateService.boundTheta(0.0);
      
      expect(bounded1).toBe(-3.0);
      expect(bounded2).toBe(3.0);
      expect(bounded3).toBe(0.0);
    });

    test('should keep theta within bounds unchanged', () => {
      const theta = 1.5;
      const bounded = thetaUpdateService.boundTheta(theta);
      expect(bounded).toBe(theta);
    });
  });

  describe('Standard Error Bounding', () => {
    test('should bound SE to [0.15, 0.6] range', () => {
      const bounded1 = thetaUpdateService.boundSE(0.05); // Below floor
      const bounded2 = thetaUpdateService.boundSE(1.0); // Above ceiling
      const bounded3 = thetaUpdateService.boundSE(0.3); // Within range
      
      expect(bounded1).toBe(0.15);
      expect(bounded2).toBe(0.6);
      expect(bounded3).toBe(0.3);
    });
  });

  describe('Theta to Percentile Conversion', () => {
    test('should convert theta to percentile', () => {
      const theta = 0.0; // Average ability
      const percentile = thetaUpdateService.thetaToPercentile(theta);
      
      expect(typeof percentile).toBe('number');
      expect(percentile).toBeGreaterThanOrEqual(0);
      expect(percentile).toBeLessThanOrEqual(100);
    });

    test('should return 50th percentile for theta = 0', () => {
      const theta = 0.0;
      const percentile = thetaUpdateService.thetaToPercentile(theta);
      
      // Theta = 0 should be around 50th percentile
      expect(percentile).toBeCloseTo(50, 0);
    });

    test('should return higher percentile for positive theta', () => {
      const theta1 = 0.0;
      const theta2 = 1.0;
      
      const percentile1 = thetaUpdateService.thetaToPercentile(theta1);
      const percentile2 = thetaUpdateService.thetaToPercentile(theta2);
      
      expect(percentile2).toBeGreaterThan(percentile1);
    });

    test('should return lower percentile for negative theta', () => {
      const theta1 = 0.0;
      const theta2 = -1.0;
      
      const percentile1 = thetaUpdateService.thetaToPercentile(theta1);
      const percentile2 = thetaUpdateService.thetaToPercentile(theta2);
      
      expect(percentile2).toBeLessThan(percentile1);
    });
  });
});

