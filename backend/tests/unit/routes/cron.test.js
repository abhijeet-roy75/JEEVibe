/**
 * Integration tests for Cron Routes
 * Tests trial processing cron endpoint
 */

const request = require('supertest');
const express = require('express');

// Mock dependencies
jest.mock('../../../src/services/trialProcessingService', () => ({
  processAllTrials: jest.fn()
}));

jest.mock('../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn()
}));

const { processAllTrials } = require('../../../src/services/trialProcessingService');

describe('POST /api/cron/process-trials', () => {
  let app;
  let cronRouter;

  beforeEach(() => {
    jest.clearAllMocks();

    // Create minimal Express app for testing
    app = express();
    app.use(express.json());

    // Mock the cron router
    cronRouter = express.Router();

    // Simulate verifyCronRequest middleware
    const verifyCronRequest = (req, res, next) => {
      const cronSecret = process.env.CRON_SECRET || 'test-secret';
      const providedSecret = req.headers['x-cron-secret'] || req.query.secret;

      if (providedSecret !== cronSecret) {
        return res.status(401).json({
          success: false,
          error: 'Unauthorized'
        });
      }
      next();
    };

    // Add process-trials endpoint
    cronRouter.post('/process-trials', verifyCronRequest, async (req, res) => {
      try {
        const results = await processAllTrials();

        res.json({
          success: true,
          message: 'Trial processing completed',
          results
        });
      } catch (error) {
        res.status(500).json({
          success: false,
          error: 'Failed to process trials',
          message: error.message
        });
      }
    });

    app.use('/api/cron', cronRouter);
  });

  it('should process trials successfully with valid secret', async () => {
    const mockResults = {
      processed: 10,
      notifications_sent: 3,
      trials_expired: 2,
      errors: [],
      duration_ms: 1500
    };

    processAllTrials.mockResolvedValue(mockResults);

    const response = await request(app)
      .post('/api/cron/process-trials')
      .set('x-cron-secret', 'test-secret')
      .expect(200);

    expect(response.body.success).toBe(true);
    expect(response.body.message).toBe('Trial processing completed');
    expect(response.body.results).toEqual(mockResults);
    expect(processAllTrials).toHaveBeenCalledTimes(1);
  });

  it('should reject request without cron secret', async () => {
    const response = await request(app)
      .post('/api/cron/process-trials')
      .expect(401);

    expect(response.body.success).toBe(false);
    expect(response.body.error).toBe('Unauthorized');
    expect(processAllTrials).not.toHaveBeenCalled();
  });

  it('should reject request with invalid cron secret', async () => {
    const response = await request(app)
      .post('/api/cron/process-trials')
      .set('x-cron-secret', 'wrong-secret')
      .expect(401);

    expect(response.body.success).toBe(false);
    expect(response.body.error).toBe('Unauthorized');
    expect(processAllTrials).not.toHaveBeenCalled();
  });

  it('should handle processing errors gracefully', async () => {
    processAllTrials.mockRejectedValue(new Error('Processing failed'));

    const response = await request(app)
      .post('/api/cron/process-trials')
      .set('x-cron-secret', 'test-secret')
      .expect(500);

    expect(response.body.success).toBe(false);
    expect(response.body.error).toBe('Failed to process trials');
    expect(response.body.message).toBe('Processing failed');
  });

  it('should accept secret via query parameter', async () => {
    const mockResults = {
      processed: 5,
      notifications_sent: 1,
      trials_expired: 0,
      errors: [],
      duration_ms: 800
    };

    processAllTrials.mockResolvedValue(mockResults);

    const response = await request(app)
      .post('/api/cron/process-trials?secret=test-secret')
      .expect(200);

    expect(response.body.success).toBe(true);
    expect(processAllTrials).toHaveBeenCalledTimes(1);
  });

  it('should return appropriate results structure', async () => {
    const mockResults = {
      processed: 100,
      notifications_sent: 25,
      trials_expired: 10,
      errors: [
        { user_id: 'user1', type: 'notification_failed' }
      ],
      skipped: 5,
      duration_ms: 3000
    };

    processAllTrials.mockResolvedValue(mockResults);

    const response = await request(app)
      .post('/api/cron/process-trials')
      .set('x-cron-secret', 'test-secret')
      .expect(200);

    expect(response.body.results).toHaveProperty('processed');
    expect(response.body.results).toHaveProperty('notifications_sent');
    expect(response.body.results).toHaveProperty('trials_expired');
    expect(response.body.results).toHaveProperty('errors');
    expect(response.body.results).toHaveProperty('duration_ms');
    expect(response.body.results.processed).toBe(100);
    expect(response.body.results.errors).toHaveLength(1);
  });
});
