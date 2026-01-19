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
    const metrics = await adminMetricsService.getDailyHealth();

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
    const metrics = await adminMetricsService.getEngagement();

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
    const metrics = await adminMetricsService.getLearning();

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
    const metrics = await adminMetricsService.getContent();

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
    const { filter = 'all', search = '', limit = '50', offset = '0' } = req.query;

    const result = await adminMetricsService.getUsers({
      filter,
      search,
      limit: Math.min(parseInt(limit) || 50, 100),
      offset: parseInt(offset) || 0
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
// ALERTS (placeholder for future implementation)
// ============================================================================

/**
 * GET /api/admin/alerts
 *
 * Get active alerts and alert history.
 *
 * Authentication: Admin required
 */
router.get('/alerts', authenticateAdmin, async (req, res, next) => {
  try {
    // Placeholder - will be implemented with alertService
    res.json({
      success: true,
      data: {
        activeAlerts: [],
        recentAlerts: [],
        message: 'Alert system not yet implemented'
      },
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
