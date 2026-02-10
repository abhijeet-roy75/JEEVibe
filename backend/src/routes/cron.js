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
const {
  sendAllDailyEmails,
  sendAllWeeklyEmails,
  sendAllDailyMPAEmails,
  sendAllWeeklyMPAEmails
} = require('../services/studentEmailService');
const { runAlertChecks } = require('../services/alertService');
const logger = require('../utils/logger');
const { withTimeout } = require('../utils/timeout');

// Cron job timeouts (in milliseconds)
// These are generous to allow batch processing, but prevent infinite hangs
const WEEKLY_SNAPSHOT_TIMEOUT = 300000;  // 5 minutes for weekly snapshots
const EMAIL_BATCH_TIMEOUT = 180000;       // 3 minutes for email batches
const ALERT_CHECK_TIMEOUT = 60000;        // 1 minute for alert checks

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

    const results = await withTimeout(
      createWeeklySnapshotsForAllUsers(snapshotDate, options),
      WEEKLY_SNAPSHOT_TIMEOUT,
      'Weekly snapshot job timed out'
    );

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
    const isTimeout = error.message.includes('timed out');
    logger.error('Error in weekly snapshot cron job', {
      error: error.message,
      isTimeout,
      stack: error.stack,
      requestId: req.id
    });

    res.status(isTimeout ? 504 : 500).json({
      success: false,
      error: isTimeout ? 'Weekly snapshot job timed out' : 'Failed to create weekly snapshots',
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

    const results = await withTimeout(
      createWeeklySnapshotsForAllUsers(snapshotDate, options),
      WEEKLY_SNAPSHOT_TIMEOUT,
      'Weekly snapshot job timed out'
    );

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
    const isTimeout = error.message.includes('timed out');
    logger.error('Error in weekly snapshot cron job', {
      error: error.message,
      isTimeout,
      stack: error.stack,
      requestId: req.id
    });

    res.status(isTimeout ? 504 : 500).json({
      success: false,
      error: isTimeout ? 'Weekly snapshot job timed out' : 'Failed to create weekly snapshots',
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

    const results = await withTimeout(
      sendAllDailyEmails(),
      EMAIL_BATCH_TIMEOUT,
      'Daily email job timed out'
    );

    res.json({
      success: true,
      message: 'Daily emails sent',
      results,
      requestId: req.id
    });
  } catch (error) {
    const isTimeout = error.message.includes('timed out');
    logger.error('Error in daily student emails cron job', {
      error: error.message,
      isTimeout,
      stack: error.stack,
      requestId: req.id
    });

    res.status(isTimeout ? 504 : 500).json({
      success: false,
      error: isTimeout ? 'Daily email job timed out' : 'Failed to send daily emails',
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

    const results = await withTimeout(
      sendAllDailyEmails(),
      EMAIL_BATCH_TIMEOUT,
      'Daily email job timed out'
    );

    res.json({
      success: true,
      message: 'Daily emails sent',
      results,
      requestId: req.id
    });
  } catch (error) {
    const isTimeout = error.message.includes('timed out');
    logger.error('Error in daily student emails cron job', {
      error: error.message,
      isTimeout,
      stack: error.stack,
      requestId: req.id
    });

    res.status(isTimeout ? 504 : 500).json({
      success: false,
      error: isTimeout ? 'Daily email job timed out' : 'Failed to send daily emails',
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

    const results = await withTimeout(
      sendAllWeeklyEmails(),
      EMAIL_BATCH_TIMEOUT,
      'Weekly email job timed out'
    );

    res.json({
      success: true,
      message: 'Weekly emails sent',
      results,
      requestId: req.id
    });
  } catch (error) {
    const isTimeout = error.message.includes('timed out');
    logger.error('Error in weekly student emails cron job', {
      error: error.message,
      isTimeout,
      stack: error.stack,
      requestId: req.id
    });

    res.status(isTimeout ? 504 : 500).json({
      success: false,
      error: isTimeout ? 'Weekly email job timed out' : 'Failed to send weekly emails',
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

    const results = await withTimeout(
      sendAllWeeklyEmails(),
      EMAIL_BATCH_TIMEOUT,
      'Weekly email job timed out'
    );

    res.json({
      success: true,
      message: 'Weekly emails sent',
      results,
      requestId: req.id
    });
  } catch (error) {
    const isTimeout = error.message.includes('timed out');
    logger.error('Error in weekly student emails cron job', {
      error: error.message,
      isTimeout,
      stack: error.stack,
      requestId: req.id
    });

    res.status(isTimeout ? 504 : 500).json({
      success: false,
      error: isTimeout ? 'Weekly email job timed out' : 'Failed to send weekly emails',
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

    const results = await withTimeout(
      runAlertChecks(),
      ALERT_CHECK_TIMEOUT,
      'Alert check job timed out'
    );

    res.json({
      success: true,
      message: 'Alert checks complete',
      results,
      requestId: req.id
    });
  } catch (error) {
    const isTimeout = error.message.includes('timed out');
    logger.error('Error in alert check cron job', {
      error: error.message,
      isTimeout,
      stack: error.stack,
      requestId: req.id
    });

    res.status(isTimeout ? 504 : 500).json({
      success: false,
      error: isTimeout ? 'Alert check job timed out' : 'Failed to run alert checks',
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

    const results = await withTimeout(
      runAlertChecks(),
      ALERT_CHECK_TIMEOUT,
      'Alert check job timed out'
    );

    res.json({
      success: true,
      message: 'Alert checks complete',
      results,
      requestId: req.id
    });
  } catch (error) {
    const isTimeout = error.message.includes('timed out');
    logger.error('Error in alert check cron job', {
      error: error.message,
      isTimeout,
      stack: error.stack,
      requestId: req.id
    });

    res.status(isTimeout ? 504 : 500).json({
      success: false,
      error: isTimeout ? 'Alert check job timed out' : 'Failed to run alert checks',
      message: error.message,
      requestId: req.id
    });
  }
});

/**
 * POST /api/cron/process-trials
 *
 * Daily job to process active trials:
 * - Check for expired trials and downgrade users
 * - Send notifications at configured milestones (day 23, 5, 2, 0)
 *
 * Schedule: Daily at 2:00 AM IST (20:30 UTC)
 *
 * Authentication: Requires CRON_SECRET
 */
router.post('/process-trials', verifyCronRequest, async (req, res) => {
  try {
    logger.info('Trial processing job started', {
      requestId: req.id,
      source: req.headers['user-agent'] || 'unknown'
    });

    const { processAllTrials } = require('../services/trialProcessingService');

    // Run with 5-minute timeout
    const results = await withTimeout(
      processAllTrials(),
      300000, // 5 minutes
      'Trial processing timed out'
    );

    logger.info('Trial processing job completed', {
      requestId: req.id,
      results
    });

    res.json({
      success: true,
      message: 'Trial processing completed',
      results,
      requestId: req.id
    });
  } catch (error) {
    const isTimeout = error.message.includes('timed out');

    logger.error('Error in trial processing job', {
      error: error.message,
      stack: error.stack,
      requestId: req.id
    });

    res.status(isTimeout ? 504 : 500).json({
      success: false,
      error: isTimeout ? 'Trial processing timed out' : 'Failed to process trials',
      message: error.message,
      requestId: req.id
    });
  }
});

/**
 * POST /api/cron/weekly-teacher-reports
 *
 * Generates and sends weekly performance reports to all active teachers
 * Should be called every Monday at 5:30 AM IST
 *
 * Security: Requires CRON_SECRET in header or query param
 */
router.post('/weekly-teacher-reports', verifyCronRequest, async (req, res) => {
  try {
    const { sendAllWeeklyTeacherEmails } = require('../services/teacherEmailService');

    logger.info('Weekly teacher reports cron job triggered', {
      requestId: req.id
    });

    const results = await withTimeout(
      sendAllWeeklyTeacherEmails(),
      EMAIL_BATCH_TIMEOUT,
      'Teacher reports job timed out'
    );

    res.json({
      success: true,
      message: 'Weekly teacher reports sent',
      results: {
        total: results.total,
        sent: results.sent,
        skipped: results.skipped,
        errors: results.errors,
        errorDetails: results.errorDetails
      },
      requestId: req.id
    });
  } catch (error) {
    const isTimeout = error.message.includes('timed out');
    logger.error('Error in weekly teacher reports cron job', {
      error: error.message,
      isTimeout,
      stack: error.stack,
      requestId: req.id
    });

    res.status(isTimeout ? 504 : 500).json({
      success: false,
      error: isTimeout ? 'Teacher reports job timed out' : 'Failed to send teacher reports',
      message: error.message,
      requestId: req.id
    });
  }
});

// ============================================================================
// MPA EMAIL ENDPOINTS (New Weekly Reports with Pattern Analytics)
// ============================================================================

/**
 * POST /api/cron/weekly-mpa-emails
 *
 * Sends weekly MPA (Mistake Pattern Analytics) reports to all active students
 * Replaces basic weekly emails with detailed pattern analysis and ROI-prioritized issues
 * Should be called on Sunday at 6 PM IST
 */
router.post('/weekly-mpa-emails', verifyCronRequest, async (req, res) => {
  try {
    logger.info('Weekly MPA emails cron job triggered', { requestId: req.id });

    const results = await withTimeout(
      sendAllWeeklyMPAEmails(),
      EMAIL_BATCH_TIMEOUT,
      'Weekly MPA email job timed out'
    );

    res.json({
      success: true,
      message: 'Weekly MPA emails sent',
      results,
      requestId: req.id
    });
  } catch (error) {
    const isTimeout = error.message.includes('timed out');
    logger.error('Error in weekly MPA emails cron job', {
      error: error.message,
      isTimeout,
      stack: error.stack,
      requestId: req.id
    });

    res.status(isTimeout ? 504 : 500).json({
      success: false,
      error: isTimeout ? 'Weekly MPA email job timed out' : 'Failed to send weekly MPA emails',
      message: error.message,
      requestId: req.id
    });
  }
});

/**
 * GET /api/cron/weekly-mpa-emails
 *
 * Same as POST, but for GET requests
 */
router.get('/weekly-mpa-emails', verifyCronRequest, async (req, res) => {
  try {
    logger.info('Weekly MPA emails cron job triggered (GET)', { requestId: req.id });

    const results = await withTimeout(
      sendAllWeeklyMPAEmails(),
      EMAIL_BATCH_TIMEOUT,
      'Weekly MPA email job timed out'
    );

    res.json({
      success: true,
      message: 'Weekly MPA emails sent',
      results,
      requestId: req.id
    });
  } catch (error) {
    const isTimeout = error.message.includes('timed out');
    logger.error('Error in weekly MPA emails cron job', {
      error: error.message,
      isTimeout,
      stack: error.stack,
      requestId: req.id
    });

    res.status(isTimeout ? 504 : 500).json({
      success: false,
      error: isTimeout ? 'Weekly MPA email job timed out' : 'Failed to send weekly MPA emails',
      message: error.message,
      requestId: req.id
    });
  }
});

/**
 * POST /api/cron/daily-mpa-emails
 *
 * Sends daily MPA (Mistake Pattern Analytics) reports to all active students
 * Condensed version with 1 win + 1 issue from yesterday
 * Should be called at 8 AM IST daily
 */
router.post('/daily-mpa-emails', verifyCronRequest, async (req, res) => {
  try {
    logger.info('Daily MPA emails cron job triggered', { requestId: req.id });

    const results = await withTimeout(
      sendAllDailyMPAEmails(),
      EMAIL_BATCH_TIMEOUT,
      'Daily MPA email job timed out'
    );

    res.json({
      success: true,
      message: 'Daily MPA emails sent',
      results,
      requestId: req.id
    });
  } catch (error) {
    const isTimeout = error.message.includes('timed out');
    logger.error('Error in daily MPA emails cron job', {
      error: error.message,
      isTimeout,
      stack: error.stack,
      requestId: req.id
    });

    res.status(isTimeout ? 504 : 500).json({
      success: false,
      error: isTimeout ? 'Daily MPA email job timed out' : 'Failed to send daily MPA emails',
      message: error.message,
      requestId: req.id
    });
  }
});

/**
 * GET /api/cron/daily-mpa-emails
 *
 * Same as POST, but for GET requests
 */
router.get('/daily-mpa-emails', verifyCronRequest, async (req, res) => {
  try {
    logger.info('Daily MPA emails cron job triggered (GET)', { requestId: req.id });

    const results = await withTimeout(
      sendAllDailyMPAEmails(),
      EMAIL_BATCH_TIMEOUT,
      'Daily MPA email job timed out'
    );

    res.json({
      success: true,
      message: 'Daily MPA emails sent',
      results,
      requestId: req.id
    });
  } catch (error) {
    const isTimeout = error.message.includes('timed out');
    logger.error('Error in daily MPA emails cron job', {
      error: error.message,
      isTimeout,
      stack: error.stack,
      requestId: req.id
    });

    res.status(isTimeout ? 504 : 500).json({
      success: false,
      error: isTimeout ? 'Daily MPA email job timed out' : 'Failed to send daily MPA emails',
      message: error.message,
      requestId: req.id
    });
  }
});

// ============================================================================
// HEALTH CHECK
// ============================================================================

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

