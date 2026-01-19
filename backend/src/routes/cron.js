/**
 * Cron Job Routes
 * 
 * API endpoints for scheduled jobs (called by Render.com cron or external cron service)
 * 
 * Security: These endpoints should be protected by a secret token or IP whitelist
 */

const express = require('express');
const router = express.Router();
const { createWeeklySnapshotsForAllUsers } = require('../services/weeklySnapshotService');
const { sendAllDailyEmails, sendAllWeeklyEmails } = require('../services/studentEmailService');
const { runAlertChecks } = require('../services/alertService');
const logger = require('../utils/logger');

// ============================================================================
// SECURITY MIDDLEWARE
// ============================================================================

/**
 * Verify cron job request is authorized
 * Checks for secret token in header or query param
 */
function verifyCronRequest(req, res, next) {
  const cronSecret = process.env.CRON_SECRET;
  
  if (!cronSecret) {
    logger.warn('CRON_SECRET not set - cron endpoints are unprotected');
    return next();
  }
  
  const providedSecret = req.headers['x-cron-secret'] || req.query.secret;
  
  if (providedSecret !== cronSecret) {
    logger.warn('Unauthorized cron request', {
      ip: req.ip,
      path: req.path
    });
    return res.status(401).json({
      success: false,
      error: 'Unauthorized'
    });
  }
  
  next();
}

// ============================================================================
// CRON ENDPOINTS
// ============================================================================

/**
 * POST /api/cron/weekly-snapshots
 * 
 * Creates weekly theta snapshots for all users
 * Also updates question statistics for all questions
 * Called every Sunday at 23:59:59
 * 
 * Security: Requires CRON_SECRET in header or query param
 * 
 * Options (in request body):
 * - updateQuestionStats: boolean (default: true) - Whether to update question stats
 */
router.post('/weekly-snapshots', verifyCronRequest, async (req, res) => {
  try {
    const snapshotDate = req.body.date ? new Date(req.body.date) : new Date();
    const options = {
      updateQuestionStats: req.body.updateQuestionStats !== false // Default: true
    };
    
    logger.info('Weekly snapshot cron job triggered', {
      snapshotDate: snapshotDate.toISOString(),
      updateQuestionStats: options.updateQuestionStats,
      requestId: req.id
    });
    
    const results = await createWeeklySnapshotsForAllUsers(snapshotDate, options);
    
    res.json({
      success: true,
      message: 'Weekly snapshots created',
      results: {
        users: {
          total: results.total,
          created: results.created,
          errors: results.errors
        },
        questionStats: {
          updated: results.questionStatsUpdated,
          errors: results.questionStatsErrors
        }
      },
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error in weekly snapshot cron job', {
      error: error.message,
      stack: error.stack,
      requestId: req.id
    });
    
    res.status(500).json({
      success: false,
      error: 'Failed to create weekly snapshots',
      message: error.message,
      requestId: req.id
    });
  }
});

/**
 * GET /api/cron/weekly-snapshots
 * 
 * Same as POST, but for GET requests (some cron services only support GET)
 * 
 * Query params:
 * - date: Optional date string
 * - updateQuestionStats: "true" or "false" (default: "true")
 */
router.get('/weekly-snapshots', verifyCronRequest, async (req, res) => {
  try {
    const snapshotDate = req.query.date ? new Date(req.query.date) : new Date();
    const options = {
      updateQuestionStats: req.query.updateQuestionStats !== 'false' // Default: true
    };
    
    logger.info('Weekly snapshot cron job triggered (GET)', {
      snapshotDate: snapshotDate.toISOString(),
      updateQuestionStats: options.updateQuestionStats,
      requestId: req.id
    });
    
    const results = await createWeeklySnapshotsForAllUsers(snapshotDate, options);
    
    res.json({
      success: true,
      message: 'Weekly snapshots created',
      results: {
        users: {
          total: results.total,
          created: results.created,
          errors: results.errors
        },
        questionStats: {
          updated: results.questionStatsUpdated,
          errors: results.questionStatsErrors
        }
      },
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error in weekly snapshot cron job', {
      error: error.message,
      stack: error.stack,
      requestId: req.id
    });
    
    res.status(500).json({
      success: false,
      error: 'Failed to create weekly snapshots',
      message: error.message,
      requestId: req.id
    });
  }
});

/**
 * POST /api/cron/daily-student-emails
 *
 * Sends daily progress emails to all active students
 * Should be called at 8 AM IST daily
 */
router.post('/daily-student-emails', verifyCronRequest, async (req, res) => {
  try {
    logger.info('Daily student emails cron job triggered', { requestId: req.id });

    const results = await sendAllDailyEmails();

    res.json({
      success: true,
      message: 'Daily emails sent',
      results,
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error in daily student emails cron job', {
      error: error.message,
      stack: error.stack,
      requestId: req.id
    });

    res.status(500).json({
      success: false,
      error: 'Failed to send daily emails',
      message: error.message,
      requestId: req.id
    });
  }
});

/**
 * GET /api/cron/daily-student-emails
 *
 * Same as POST, but for GET requests
 */
router.get('/daily-student-emails', verifyCronRequest, async (req, res) => {
  try {
    logger.info('Daily student emails cron job triggered (GET)', { requestId: req.id });

    const results = await sendAllDailyEmails();

    res.json({
      success: true,
      message: 'Daily emails sent',
      results,
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error in daily student emails cron job', {
      error: error.message,
      stack: error.stack,
      requestId: req.id
    });

    res.status(500).json({
      success: false,
      error: 'Failed to send daily emails',
      message: error.message,
      requestId: req.id
    });
  }
});

/**
 * POST /api/cron/weekly-student-emails
 *
 * Sends weekly progress summary emails to all active students
 * Should be called on Sunday at 6 PM IST
 */
router.post('/weekly-student-emails', verifyCronRequest, async (req, res) => {
  try {
    logger.info('Weekly student emails cron job triggered', { requestId: req.id });

    const results = await sendAllWeeklyEmails();

    res.json({
      success: true,
      message: 'Weekly emails sent',
      results,
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error in weekly student emails cron job', {
      error: error.message,
      stack: error.stack,
      requestId: req.id
    });

    res.status(500).json({
      success: false,
      error: 'Failed to send weekly emails',
      message: error.message,
      requestId: req.id
    });
  }
});

/**
 * GET /api/cron/weekly-student-emails
 *
 * Same as POST, but for GET requests
 */
router.get('/weekly-student-emails', verifyCronRequest, async (req, res) => {
  try {
    logger.info('Weekly student emails cron job triggered (GET)', { requestId: req.id });

    const results = await sendAllWeeklyEmails();

    res.json({
      success: true,
      message: 'Weekly emails sent',
      results,
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error in weekly student emails cron job', {
      error: error.message,
      stack: error.stack,
      requestId: req.id
    });

    res.status(500).json({
      success: false,
      error: 'Failed to send weekly emails',
      message: error.message,
      requestId: req.id
    });
  }
});

/**
 * POST /api/cron/check-alerts
 *
 * Runs all alert checks and sends notifications for triggered alerts
 * Should be called every 6 hours or daily
 */
router.post('/check-alerts', verifyCronRequest, async (req, res) => {
  try {
    logger.info('Alert check cron job triggered', { requestId: req.id });

    const results = await runAlertChecks();

    res.json({
      success: true,
      message: 'Alert checks complete',
      results,
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error in alert check cron job', {
      error: error.message,
      stack: error.stack,
      requestId: req.id
    });

    res.status(500).json({
      success: false,
      error: 'Failed to run alert checks',
      message: error.message,
      requestId: req.id
    });
  }
});

/**
 * GET /api/cron/check-alerts
 *
 * Same as POST, but for GET requests
 */
router.get('/check-alerts', verifyCronRequest, async (req, res) => {
  try {
    logger.info('Alert check cron job triggered (GET)', { requestId: req.id });

    const results = await runAlertChecks();

    res.json({
      success: true,
      message: 'Alert checks complete',
      results,
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error in alert check cron job', {
      error: error.message,
      stack: error.stack,
      requestId: req.id
    });

    res.status(500).json({
      success: false,
      error: 'Failed to run alert checks',
      message: error.message,
      requestId: req.id
    });
  }
});

/**
 * GET /api/cron/health
 *
 * Health check for cron service
 */
router.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'Cron service is running',
    timestamp: new Date().toISOString()
  });
});

module.exports = router;

