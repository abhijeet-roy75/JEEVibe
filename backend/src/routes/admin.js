/**
 * Admin Routes
 *
 * API endpoints for admin dashboard metrics and user management.
 * All endpoints require admin authentication.
 *
 * Endpoints:
 * - GET /api/admin/metrics/daily-health - Dashboard health metrics
 * - GET /api/admin/metrics/engagement - Engagement depth metrics
 * - GET /api/admin/metrics/learning - Learning outcomes metrics
 * - GET /api/admin/metrics/content - Content quality metrics
 * - GET /api/admin/users - User list with filters
 * - GET /api/admin/users/:userId - Single user details
 */

const express = require('express');
const router = express.Router();
const { authenticateAdmin } = require('../middleware/adminAuth');
const logger = require('../utils/logger');
const adminMetricsService = require('../services/adminMetricsService');
const { withTimeout } = require('../utils/timeout');

// Timeout for admin metrics queries (25 seconds - under Render's 30s limit)
const ADMIN_METRICS_TIMEOUT = 25000;
const { getRecentAlerts, acknowledgeAlert } = require('../services/alertService');
const {
  getFlaggedContent,
  reviewFlag,
  generateDailySummary,
  checkUserFlagThresholds,
  getModerationStats,
  getUnacknowledgedAlerts,
  acknowledgeAlert: acknowledgeModerationAlert,
  getUsersWithMostFlags
} = require('../services/contentModerationService');

// ============================================================================
// DAILY HEALTH METRICS
// ============================================================================

/**
 * GET /api/admin/metrics/daily-health
 *
 * Get daily health metrics for the main dashboard.
 * Returns: DAU, signups, completions, at-risk users, trends
 *
 * Authentication: Admin required
 */
router.get('/metrics/daily-health', authenticateAdmin, async (req, res, next) => {
  try {
    const metrics = await withTimeout(
      adminMetricsService.getDailyHealth(),
      ADMIN_METRICS_TIMEOUT,
      'Daily health metrics query timed out'
    );

    logger.info('Admin daily health metrics retrieved', {
      requestId: req.id,
      adminEmail: req.userEmail,
      dau: metrics.dau,
      newSignups: metrics.newSignups
    });

    res.json({
      success: true,
      data: metrics,
      requestId: req.id
    });
  } catch (error) {
    // Handle timeout with graceful degradation
    if (error.message.includes('timed out')) {
      logger.warn('Admin metrics timeout - returning partial data', {
        requestId: req.id,
        error: error.message
      });
      return res.status(503).json({
        success: false,
        error: {
          code: 'METRICS_TIMEOUT',
          message: 'Metrics query timed out. Please try again or use a smaller date range.'
        },
        requestId: req.id
      });
    }
    logger.error('Error fetching daily health metrics', {
      requestId: req.id,
      error: error.message
    });
    next(error);
  }
});

// ============================================================================
// ENGAGEMENT METRICS
// ============================================================================

/**
 * GET /api/admin/metrics/engagement
 *
 * Get engagement depth metrics.
 * Returns: avg quizzes/user, questions/user, session time, feature usage, streaks
 *
 * Authentication: Admin required
 */
router.get('/metrics/engagement', authenticateAdmin, async (req, res, next) => {
  try {
    const metrics = await withTimeout(
      adminMetricsService.getEngagement(),
      ADMIN_METRICS_TIMEOUT,
      'Engagement metrics query timed out'
    );

    logger.info('Admin engagement metrics retrieved', {
      requestId: req.id,
      adminEmail: req.userEmail,
      activeUsers: metrics.activeUsers
    });

    res.json({
      success: true,
      data: metrics,
      requestId: req.id
    });
  } catch (error) {
    if (error.message.includes('timed out')) {
      logger.warn('Admin engagement metrics timeout', { requestId: req.id });
      return res.status(503).json({
        success: false,
        error: { code: 'METRICS_TIMEOUT', message: 'Engagement metrics query timed out.' },
        requestId: req.id
      });
    }
    logger.error('Error fetching engagement metrics', {
      requestId: req.id,
      error: error.message
    });
    next(error);
  }
});

// ============================================================================
// LEARNING OUTCOMES METRICS
// ============================================================================

/**
 * GET /api/admin/metrics/learning
 *
 * Get learning outcomes metrics.
 * Returns: theta changes, mastery progression, focus areas
 *
 * Authentication: Admin required
 */
router.get('/metrics/learning', authenticateAdmin, async (req, res, next) => {
  try {
    const metrics = await withTimeout(
      adminMetricsService.getLearning(),
      ADMIN_METRICS_TIMEOUT,
      'Learning metrics query timed out'
    );

    logger.info('Admin learning metrics retrieved', {
      requestId: req.id,
      adminEmail: req.userEmail,
      totalStudents: metrics.totalStudentsWithProgress
    });

    res.json({
      success: true,
      data: metrics,
      requestId: req.id
    });
  } catch (error) {
    if (error.message.includes('timed out')) {
      logger.warn('Admin learning metrics timeout', { requestId: req.id });
      return res.status(503).json({
        success: false,
        error: { code: 'METRICS_TIMEOUT', message: 'Learning metrics query timed out.' },
        requestId: req.id
      });
    }
    logger.error('Error fetching learning metrics', {
      requestId: req.id,
      error: error.message
    });
    next(error);
  }
});

// ============================================================================
// CONTENT QUALITY METRICS
// ============================================================================

/**
 * GET /api/admin/metrics/content
 *
 * Get content quality metrics.
 * Returns: question accuracy anomalies, time by difficulty
 *
 * Authentication: Admin required
 */
router.get('/metrics/content', authenticateAdmin, async (req, res, next) => {
  try {
    const metrics = await withTimeout(
      adminMetricsService.getContent(),
      ADMIN_METRICS_TIMEOUT,
      'Content metrics query timed out'
    );

    logger.info('Admin content metrics retrieved', {
      requestId: req.id,
      adminEmail: req.userEmail,
      totalQuestions: metrics.totalQuestionsWithStats
    });

    res.json({
      success: true,
      data: metrics,
      requestId: req.id
    });
  } catch (error) {
    if (error.message.includes('timed out')) {
      logger.warn('Admin content metrics timeout', { requestId: req.id });
      return res.status(503).json({
        success: false,
        error: { code: 'METRICS_TIMEOUT', message: 'Content metrics query timed out.' },
        requestId: req.id
      });
    }
    logger.error('Error fetching content metrics', {
      requestId: req.id,
      error: error.message
    });
    next(error);
  }
});

// ============================================================================
// USER LIST
// ============================================================================

/**
 * GET /api/admin/users
 *
 * Get paginated user list with filters.
 *
 * Query params:
 * - filter: 'all' | 'active' | 'at-risk' | 'pro' | 'ultra'
 * - search: search by name, email, phone
 * - limit: number of results (default: 50, max: 100)
 * - offset: pagination offset
 *
 * Authentication: Admin required
 */
router.get('/users', authenticateAdmin, async (req, res, next) => {
  try {
    const { filter = 'all', search = '', limit = '50', offset = '0', isEnrolledInCoaching, hasNoTeacher } = req.query;

    const result = await adminMetricsService.getUsers({
      filter,
      search,
      limit: Math.min(parseInt(limit) || 50, 100),
      offset: parseInt(offset) || 0,
      isEnrolledInCoaching: isEnrolledInCoaching === 'true',
      hasNoTeacher: hasNoTeacher === 'true'
    });

    logger.info('Admin user list retrieved', {
      requestId: req.id,
      adminEmail: req.userEmail,
      filter,
      total: result.total,
      returned: result.users.length
    });

    res.json({
      success: true,
      data: result,
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error fetching user list', {
      requestId: req.id,
      error: error.message
    });
    next(error);
  }
});

// ============================================================================
// USER DETAILS
// ============================================================================

/**
 * GET /api/admin/users/:userId
 *
 * Get detailed information for a single user.
 *
 * Authentication: Admin required
 */
router.get('/users/:userId', authenticateAdmin, async (req, res, next) => {
  try {
    const { userId } = req.params;

    const user = await adminMetricsService.getUserDetails(userId);

    logger.info('Admin user details retrieved', {
      requestId: req.id,
      adminEmail: req.userEmail,
      targetUserId: userId
    });

    res.json({
      success: true,
      data: user,
      requestId: req.id
    });
  } catch (error) {
    if (error.message === 'User not found') {
      return res.status(404).json({
        success: false,
        error: 'User not found',
        requestId: req.id
      });
    }
    logger.error('Error fetching user details', {
      requestId: req.id,
      error: error.message
    });
    next(error);
  }
});

// ============================================================================
// ALERTS
// ============================================================================

/**
 * GET /api/admin/alerts
 *
 * Get active alerts and alert history.
 *
 * Query params:
 * - limit: number of alerts to return (default: 50)
 *
 * Authentication: Admin required
 */
router.get('/alerts', authenticateAdmin, async (req, res, next) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 50, 100);
    const alerts = await getRecentAlerts(limit);

    const activeAlerts = alerts.filter(a => !a.acknowledged);
    const acknowledgedAlerts = alerts.filter(a => a.acknowledged);

    logger.info('Admin alerts retrieved', {
      requestId: req.id,
      adminEmail: req.userEmail,
      activeCount: activeAlerts.length,
      totalCount: alerts.length
    });

    res.json({
      success: true,
      data: {
        activeAlerts,
        recentAlerts: acknowledgedAlerts,
        total: alerts.length
      },
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error fetching alerts', {
      requestId: req.id,
      error: error.message
    });
    next(error);
  }
});

/**
 * POST /api/admin/alerts/:alertId/acknowledge
 *
 * Acknowledge an alert.
 *
 * Authentication: Admin required
 */
router.post('/alerts/:alertId/acknowledge', authenticateAdmin, async (req, res, next) => {
  try {
    const { alertId } = req.params;
    const result = await acknowledgeAlert(alertId);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error,
        requestId: req.id
      });
    }

    logger.info('Alert acknowledged', {
      requestId: req.id,
      adminEmail: req.userEmail,
      alertId
    });

    res.json({
      success: true,
      message: 'Alert acknowledged',
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error acknowledging alert', {
      requestId: req.id,
      error: error.message
    });
    next(error);
  }
});

// ============================================================================
// CONTENT MODERATION
// ============================================================================

/**
 * GET /api/admin/moderation/stats
 *
 * Get moderation statistics for dashboard overview.
 * Returns today's flags, weekly stats, pending items, category breakdown.
 *
 * Authentication: Admin required
 */
router.get('/moderation/stats', authenticateAdmin, async (req, res, next) => {
  try {
    const stats = await getModerationStats();

    logger.info('Admin moderation stats retrieved', {
      requestId: req.id,
      adminEmail: req.userEmail,
      todayTotal: stats.today.total,
      pendingAlerts: stats.pending.unacknowledgedAlerts
    });

    res.json({
      success: true,
      data: stats,
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error fetching moderation stats', {
      requestId: req.id,
      error: error.message
    });
    next(error);
  }
});

/**
 * GET /api/admin/moderation/alerts
 *
 * Get unacknowledged moderation alerts (high-severity items needing attention).
 *
 * Query params:
 * - limit: number of alerts to return (default: 50)
 *
 * Authentication: Admin required
 */
router.get('/moderation/alerts', authenticateAdmin, async (req, res, next) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 50, 100);
    const alerts = await getUnacknowledgedAlerts(limit);

    logger.info('Admin moderation alerts retrieved', {
      requestId: req.id,
      adminEmail: req.userEmail,
      alertCount: alerts.length
    });

    res.json({
      success: true,
      data: {
        alerts,
        total: alerts.length
      },
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error fetching moderation alerts', {
      requestId: req.id,
      error: error.message
    });
    next(error);
  }
});

/**
 * POST /api/admin/moderation/alerts/:alertId/acknowledge
 *
 * Acknowledge a moderation alert.
 *
 * Authentication: Admin required
 */
router.post('/moderation/alerts/:alertId/acknowledge', authenticateAdmin, async (req, res, next) => {
  try {
    const { alertId } = req.params;

    await acknowledgeModerationAlert(alertId, req.userEmail);

    logger.info('Moderation alert acknowledged', {
      requestId: req.id,
      adminEmail: req.userEmail,
      alertId
    });

    res.json({
      success: true,
      message: 'Alert acknowledged',
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error acknowledging moderation alert', {
      requestId: req.id,
      error: error.message
    });
    next(error);
  }
});

/**
 * GET /api/admin/moderation/users/flagged
 *
 * Get users with the most moderation flags (repeat offenders).
 *
 * Query params:
 * - limit: number of users to return (default: 20)
 *
 * Authentication: Admin required
 */
router.get('/moderation/users/flagged', authenticateAdmin, async (req, res, next) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 20, 50);
    const users = await getUsersWithMostFlags(limit);

    logger.info('Admin flagged users retrieved', {
      requestId: req.id,
      adminEmail: req.userEmail,
      userCount: users.length
    });

    res.json({
      success: true,
      data: {
        users,
        total: users.length
      },
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error fetching flagged users', {
      requestId: req.id,
      error: error.message
    });
    next(error);
  }
});

/**
 * GET /api/admin/moderation/flags
 *
 * Get flagged content for review.
 *
 * Query params:
 * - severity: 'high' | 'medium' | 'low' (optional filter)
 * - reviewed: 'true' | 'false' (optional filter)
 * - userId: filter by specific user
 * - limit: number of results (default: 50, max: 100)
 *
 * Authentication: Admin required
 */
router.get('/moderation/flags', authenticateAdmin, async (req, res, next) => {
  try {
    const { severity, reviewed, userId, limit = '50' } = req.query;

    const filters = {
      limit: Math.min(parseInt(limit) || 50, 100)
    };

    if (severity) filters.severity = severity;
    if (reviewed !== undefined) filters.reviewed = reviewed === 'true';
    if (userId) filters.userId = userId;

    const flags = await getFlaggedContent(filters);

    // Count by severity for dashboard
    const stats = {
      total: flags.length,
      high: flags.filter(f => f.severity === 'high').length,
      medium: flags.filter(f => f.severity === 'medium').length,
      low: flags.filter(f => f.severity === 'low').length,
      unreviewed: flags.filter(f => !f.reviewed).length
    };

    logger.info('Admin moderation flags retrieved', {
      requestId: req.id,
      adminEmail: req.userEmail,
      total: stats.total,
      unreviewed: stats.unreviewed
    });

    res.json({
      success: true,
      data: {
        flags,
        stats
      },
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error fetching moderation flags', {
      requestId: req.id,
      error: error.message
    });
    next(error);
  }
});

/**
 * POST /api/admin/moderation/flags/:flagId/review
 *
 * Mark a flag as reviewed with action taken.
 *
 * Body:
 * - action: 'dismissed' | 'warned' | 'restricted' | 'escalated'
 * - notes: optional review notes
 *
 * Authentication: Admin required
 */
router.post('/moderation/flags/:flagId/review', authenticateAdmin, async (req, res, next) => {
  try {
    const { flagId } = req.params;
    const { action, notes } = req.body;

    if (!action || !['dismissed', 'warned', 'restricted', 'escalated'].includes(action)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid action. Must be one of: dismissed, warned, restricted, escalated',
        requestId: req.id
      });
    }

    await reviewFlag(flagId, req.userEmail, action, notes || '');

    logger.info('Moderation flag reviewed', {
      requestId: req.id,
      adminEmail: req.userEmail,
      flagId,
      action
    });

    res.json({
      success: true,
      message: 'Flag reviewed successfully',
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error reviewing moderation flag', {
      requestId: req.id,
      error: error.message
    });
    next(error);
  }
});

/**
 * GET /api/admin/moderation/users/:userId/flags
 *
 * Get moderation history and thresholds for a specific user.
 *
 * Authentication: Admin required
 */
router.get('/moderation/users/:userId/flags', authenticateAdmin, async (req, res, next) => {
  try {
    const { userId } = req.params;

    const [flags, thresholds] = await Promise.all([
      getFlaggedContent({ userId, limit: 50 }),
      checkUserFlagThresholds(userId)
    ]);

    logger.info('Admin user moderation history retrieved', {
      requestId: req.id,
      adminEmail: req.userEmail,
      targetUserId: userId,
      flagCount: flags.length
    });

    res.json({
      success: true,
      data: {
        userId,
        flags,
        thresholds,
        totalFlags: flags.length
      },
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error fetching user moderation history', {
      requestId: req.id,
      error: error.message
    });
    next(error);
  }
});

/**
 * POST /api/admin/moderation/summary
 *
 * Generate daily moderation summary (can be called manually or by cron).
 *
 * Authentication: Admin required
 */
router.post('/moderation/summary', authenticateAdmin, async (req, res, next) => {
  try {
    const summary = await generateDailySummary();

    logger.info('Moderation daily summary generated', {
      requestId: req.id,
      adminEmail: req.userEmail,
      totalFlags: summary.totalFlags
    });

    res.json({
      success: true,
      data: summary,
      requestId: req.id
    });
  } catch (error) {
    logger.error('Error generating moderation summary', {
      requestId: req.id,
      error: error.message
    });
    next(error);
  }
});

module.exports = router;
