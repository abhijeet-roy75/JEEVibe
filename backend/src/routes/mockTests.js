/**
 * Mock Test Routes
 *
 * API endpoints for JEE Main mock tests:
 * - GET /api/mock-tests/available - List available templates
 * - GET /api/mock-tests/active - Get active test (with questions for resume)
 * - POST /api/mock-tests/start - Start a new mock test
 * - POST /api/mock-tests/save-answer - Save answer for a question
 * - POST /api/mock-tests/clear-answer - Clear answer for a question
 * - POST /api/mock-tests/submit - Submit test and get results
 * - POST /api/mock-tests/abandon - Abandon in-progress test
 * - GET /api/mock-tests/history - Get user's mock test history
 * - GET /api/mock-tests/:testId/results - Get detailed results
 *
 * @version 1.0
 * @phase Phase 1A - Backend Services
 */

const express = require('express');
const router = express.Router();
const { authenticateUser } = require('../middleware/auth');
const { body, param, validationResult } = require('express-validator');
const logger = require('../utils/logger');

// Services
const {
  getAvailableTemplates,
  startMockTest,
  getActiveTest,
  getActiveTestWithQuestions,
  getUserMockTestHistory,
  saveAnswer,
  clearAnswer,
  submitMockTest,
  getTestResults,
  abandonTest,
  checkRateLimit
} = require('../services/mockTestService');

const { checkFeatureAccess, getTierLimits } = require('../services/tierConfigService');
const { incrementUsage, getUsage } = require('../services/usageTrackingService');
const { getEffectiveTier } = require('../services/subscriptionService');

// ============================================================================
// VALIDATION MIDDLEWARE
// ============================================================================

const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    const firstError = errors.array()[0];
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      message: firstError.msg,
      field: firstError.path
    });
  }
  next();
};

const validateTestId = [
  body('test_id')
    .trim()
    .notEmpty().withMessage('test_id is required')
    .isString().withMessage('test_id must be a string'),
  handleValidationErrors
];

const validateSaveAnswer = [
  body('test_id')
    .trim()
    .notEmpty().withMessage('test_id is required'),
  body('question_number')
    .isInt({ min: 1, max: 90 }).withMessage('question_number must be between 1 and 90'),
  body('answer')
    .optional()
    .isString().withMessage('answer must be a string'),
  body('marked_for_review')
    .optional()
    .isBoolean().withMessage('marked_for_review must be a boolean'),
  body('time_spent_seconds')
    .optional()
    .isInt({ min: 0, max: 3600 }).withMessage('time_spent_seconds must be between 0 and 3600'),
  handleValidationErrors
];

// ============================================================================
// GET /api/mock-tests/available
// List available mock test templates
// ============================================================================

router.get('/available', authenticateUser, async (req, res) => {
  try {
    const userId = req.userId;

    // Check tier access - fetch actual user tier
    const userTierInfo = await getEffectiveTier(userId);
    const limits = await getTierLimits(userTierInfo.tier);
    const monthlyLimit = limits.mock_tests_monthly;

    console.log('[MockTest /available] userId:', userId, 'tier:', userTierInfo.tier, 'source:', userTierInfo.source, 'monthlyLimit:', monthlyLimit);

    // Get usage
    const usage = await getUsage(userId, 'mock_tests');
    console.log('[MockTest /available] usage:', JSON.stringify(usage));

    // Get available templates
    const templates = await getAvailableTemplates();

    // Get user history to show which ones they've taken
    const history = await getUserMockTestHistory(userId);
    const completedTemplateIds = new Set(
      history.filter(h => h.status === 'completed').map(h => h.template_id)
    );

    const templatesWithStatus = templates.map(t => ({
      template_id: t.template_id,
      name: t.name,
      description: t.description,
      question_count: t.question_count,
      duration_seconds: t.config?.duration_seconds || 10800,
      sections: t.sections,
      completed: completedTemplateIds.has(t.template_id),
      stats: t.stats
    }));

    res.json({
      success: true,
      data: {
        templates: templatesWithStatus,
        usage: {
          used: usage.used,
          limit: monthlyLimit,
          remaining: monthlyLimit === -1 ? -1 : Math.max(0, monthlyLimit - usage.used)
        }
      }
    });

  } catch (error) {
    logger.error('Error fetching available mock tests', {
      userId: req.userId,
      error: error.message
    });
    res.status(500).json({
      success: false,
      error: 'Failed to fetch available mock tests',
      message: error.message
    });
  }
});

// ============================================================================
// GET /api/mock-tests/active
// Get active (in-progress) mock test with questions for resuming
// ============================================================================

router.get('/active', authenticateUser, async (req, res) => {
  try {
    const userId = req.userId;

    const activeTest = await getActiveTestWithQuestions(userId);

    if (!activeTest) {
      return res.json({
        success: true,
        data: null,
        message: 'No active mock test'
      });
    }

    // Calculate remaining time
    const expiresAt = activeTest.expires_at?.toDate?.() || new Date(activeTest.expires_at);
    const remainingSeconds = Math.max(0, Math.floor((expiresAt - new Date()) / 1000));

    res.json({
      success: true,
      data: {
        ...activeTest,
        time_remaining_seconds: remainingSeconds
      }
    });

  } catch (error) {
    logger.error('Error fetching active mock test', {
      userId: req.userId,
      error: error.message
    });
    res.status(500).json({
      success: false,
      error: 'Failed to fetch active mock test',
      message: error.message
    });
  }
});

// ============================================================================
// POST /api/mock-tests/start
// Start a new mock test
// ============================================================================

router.post('/start', authenticateUser, async (req, res) => {
  try {
    const userId = req.userId;
    const { template_id } = req.body;

    // Check tier access - fetch actual user tier
    const userTierInfo = await getEffectiveTier(userId);
    const limits = await getTierLimits(userTierInfo.tier);
    const monthlyLimit = limits.mock_tests_monthly;

    // Check usage
    const usage = await getUsage(userId, 'mock_tests');
    if (monthlyLimit !== -1 && usage.used >= monthlyLimit) {
      return res.status(403).json({
        success: false,
        error: 'Monthly limit reached',
        message: `You've used all ${monthlyLimit} mock tests this month. Upgrade to get more.`,
        code: 'LIMIT_REACHED'
      });
    }

    // Check rate limit
    const canStart = await checkRateLimit(userId);
    if (!canStart) {
      return res.status(429).json({
        success: false,
        error: 'Rate limited',
        message: 'Please wait 5 minutes between starting mock tests.',
        code: 'RATE_LIMITED'
      });
    }

    // Start the test
    const testSession = await startMockTest(userId, template_id);

    // Increment usage
    await incrementUsage(userId, 'mock_tests');

    logger.info('Mock test started via API', {
      userId,
      testId: testSession.test_id,
      templateId: testSession.template_id
    });

    res.json({
      success: true,
      data: testSession
    });

  } catch (error) {
    logger.error('Error starting mock test', {
      userId: req.userId,
      error: error.message
    });

    // Handle specific errors
    if (error.message.includes('active mock test')) {
      return res.status(400).json({
        success: false,
        error: 'Active test exists',
        message: error.message,
        code: 'ACTIVE_TEST_EXISTS'
      });
    }

    res.status(500).json({
      success: false,
      error: 'Failed to start mock test',
      message: error.message
    });
  }
});

// ============================================================================
// POST /api/mock-tests/save-answer
// Save answer for a question (real-time sync)
// ============================================================================

router.post('/save-answer', authenticateUser, validateSaveAnswer, async (req, res) => {
  try {
    const userId = req.userId;
    const {
      test_id,
      question_number,
      answer,
      marked_for_review = false,
      time_spent_seconds = 0
    } = req.body;

    const result = await saveAnswer(
      userId,
      test_id,
      question_number,
      answer,
      marked_for_review,
      time_spent_seconds
    );

    res.json({
      success: true,
      data: result
    });

  } catch (error) {
    logger.error('Error saving mock test answer', {
      userId: req.userId,
      testId: req.body.test_id,
      questionNumber: req.body.question_number,
      error: error.message
    });
    res.status(500).json({
      success: false,
      error: 'Failed to save answer',
      message: error.message
    });
  }
});

// ============================================================================
// POST /api/mock-tests/clear-answer
// Clear answer for a question
// ============================================================================

router.post('/clear-answer', authenticateUser, async (req, res) => {
  try {
    const userId = req.userId;
    const { test_id, question_number } = req.body;

    if (!test_id || !question_number) {
      return res.status(400).json({
        success: false,
        error: 'test_id and question_number are required'
      });
    }

    const result = await clearAnswer(userId, test_id, question_number);

    res.json({
      success: true,
      data: result
    });

  } catch (error) {
    logger.error('Error clearing mock test answer', {
      userId: req.userId,
      error: error.message
    });
    res.status(500).json({
      success: false,
      error: 'Failed to clear answer',
      message: error.message
    });
  }
});

// ============================================================================
// POST /api/mock-tests/submit
// Submit mock test and calculate results
// ============================================================================

router.post('/submit', authenticateUser, validateTestId, async (req, res) => {
  try {
    const userId = req.userId;
    const { test_id, final_responses = {} } = req.body;

    const result = await submitMockTest(userId, test_id, final_responses, false);

    logger.info('Mock test submitted via API', {
      userId,
      testId: test_id,
      score: result.score,
      percentile: result.percentile
    });

    res.json({
      success: true,
      data: result
    });

  } catch (error) {
    logger.error('Error submitting mock test', {
      userId: req.userId,
      testId: req.body.test_id,
      error: error.message
    });

    if (error.message.includes('already submitted')) {
      return res.status(400).json({
        success: false,
        error: 'Test already submitted',
        message: error.message,
        code: 'ALREADY_SUBMITTED'
      });
    }

    res.status(500).json({
      success: false,
      error: 'Failed to submit mock test',
      message: error.message
    });
  }
});

// ============================================================================
// POST /api/mock-tests/abandon
// Abandon an in-progress test
// ============================================================================

router.post('/abandon', authenticateUser, validateTestId, async (req, res) => {
  try {
    const userId = req.userId;
    const { test_id } = req.body;

    const result = await abandonTest(userId, test_id);

    logger.info('Mock test abandoned via API', {
      userId,
      testId: test_id
    });

    res.json({
      success: true,
      data: result
    });

  } catch (error) {
    logger.error('Error abandoning mock test', {
      userId: req.userId,
      error: error.message
    });
    res.status(500).json({
      success: false,
      error: 'Failed to abandon mock test',
      message: error.message
    });
  }
});

// ============================================================================
// GET /api/mock-tests/history
// Get user's mock test history
// ============================================================================

router.get('/history', authenticateUser, async (req, res) => {
  try {
    const userId = req.userId;

    const history = await getUserMockTestHistory(userId);

    // Sanitize history (remove detailed question results for list view)
    const sanitizedHistory = history.map(test => ({
      test_id: test.test_id,
      template_id: test.template_id,
      template_name: test.template_name,
      status: test.status,
      started_at: test.started_at,
      completed_at: test.completed_at,
      score: test.score,
      max_score: test.max_score,
      percentile: test.percentile,
      accuracy: test.accuracy,
      correct_count: test.correct_count,
      incorrect_count: test.incorrect_count,
      unattempted_count: test.unattempted_count,
      time_taken_seconds: test.time_taken_seconds,
      subject_scores: test.subject_scores
    }));

    res.json({
      success: true,
      data: {
        tests: sanitizedHistory,
        total: sanitizedHistory.length
      }
    });

  } catch (error) {
    logger.error('Error fetching mock test history', {
      userId: req.userId,
      error: error.message
    });
    res.status(500).json({
      success: false,
      error: 'Failed to fetch mock test history',
      message: error.message
    });
  }
});

// ============================================================================
// GET /api/mock-tests/:testId/results
// Get detailed results for a completed test (for review)
// ============================================================================

router.get('/:testId/results', authenticateUser, async (req, res) => {
  try {
    const userId = req.userId;
    const { testId } = req.params;

    const results = await getTestResults(userId, testId);

    res.json({
      success: true,
      data: results
    });

  } catch (error) {
    logger.error('Error fetching mock test results', {
      userId: req.userId,
      testId: req.params.testId,
      error: error.message
    });

    if (error.message.includes('not found')) {
      return res.status(404).json({
        success: false,
        error: 'Test not found',
        message: error.message
      });
    }

    if (error.message.includes('not yet completed')) {
      return res.status(400).json({
        success: false,
        error: 'Test not completed',
        message: error.message
      });
    }

    res.status(500).json({
      success: false,
      error: 'Failed to fetch test results',
      message: error.message
    });
  }
});

module.exports = router;
