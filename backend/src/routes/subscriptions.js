/**
 * Subscription Routes
 *
 * API endpoints for subscription management:
 * - GET /api/subscriptions/status - Get current subscription status
 * - GET /api/subscriptions/plans - Get available plans
 * - GET /api/subscriptions/usage - Get current usage
 *
 * Note: Payment endpoints (create-order, verify-payment) will be added in Phase 2
 */

const express = require('express');
const router = express.Router();
const { authenticateUser } = require('../middleware/auth');
const { adminLimiter } = require('../middleware/rateLimiter');
const logger = require('../utils/logger');
const { db, admin } = require('../config/firebase');

const { getSubscriptionStatus, grantOverride, revokeOverride } = require('../services/subscriptionService');
const { getAllUsage } = require('../services/usageTrackingService');
const { getPurchasablePlans, getTierConfig, forceUpdateTierConfig } = require('../services/tierConfigService');
const { getWeeklyUsage } = require('../services/weeklyChapterPracticeService');

// Admin UIDs allowed to grant overrides (should be moved to environment config)
const ADMIN_UIDS = process.env.ADMIN_UIDS ? process.env.ADMIN_UIDS.split(',') : [];

/**
 * Check if user is an admin
 * Checks: 1) UID in ADMIN_UIDS env var, 2) Firebase custom claim, 3) Firestore admin role
 * @param {string} userId - User ID to check
 * @returns {Promise<boolean>} Whether user is admin
 */
async function isAdmin(userId) {
  // Check environment variable list first (fastest)
  if (ADMIN_UIDS.includes(userId)) {
    return true;
  }

  try {
    // Check Firebase custom claims
    const userRecord = await admin.auth().getUser(userId);
    if (userRecord.customClaims?.admin === true) {
      return true;
    }

    // Check Firestore admin role as fallback
    const userDoc = await db.collection('users').doc(userId).get();
    if (userDoc.exists && userDoc.data()?.role === 'admin') {
      return true;
    }
  } catch (error) {
    logger.error('Error checking admin status', { userId, error: error.message });
  }

  return false;
}

// ============================================================================
// SUBSCRIPTION STATUS
// ============================================================================

/**
 * GET /api/subscriptions/status
 *
 * Get complete subscription status for the authenticated user.
 * Returns: tier info, limits, features, and current usage
 *
 * Authentication: Required
 */
router.get('/status', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;

    // Get subscription status, usage, and weekly chapter practice usage in parallel
    const [status, usage, chapterPracticeWeekly] = await Promise.all([
      getSubscriptionStatus(userId),
      getAllUsage(userId),
      getWeeklyUsage(userId)
    ]);

    logger.info('Subscription status retrieved', {
      requestId: req.id,
      userId,
      tier: status.tier,
      source: status.source
    });

    res.json({
      success: true,
      data: {
        subscription: {
          tier: status.tier,
          tier_display_name: getTierDisplayName(status.tier),
          source: status.source,
          expires_at: status.expires_at,
          ...(status.override_type && {
            override: {
              type: status.override_type,
              reason: status.override_reason
            }
          }),
          ...(status.subscription_id && {
            subscription_id: status.subscription_id,
            plan_type: status.plan_type
          })
        },
        limits: status.limits,
        features: status.features,
        usage: {
          snap_solve: {
            used: usage.snap_solve.used,
            limit: usage.snap_solve.limit,
            remaining: usage.snap_solve.remaining,
            is_unlimited: usage.snap_solve.is_unlimited,
            resets_at: usage.snap_solve.resets_at
          },
          daily_quiz: {
            used: usage.daily_quiz.used,
            limit: usage.daily_quiz.limit,
            remaining: usage.daily_quiz.remaining,
            is_unlimited: usage.daily_quiz.is_unlimited,
            resets_at: usage.daily_quiz.resets_at
          },
          ai_tutor: {
            used: usage.ai_tutor.used,
            limit: usage.ai_tutor.limit,
            remaining: usage.ai_tutor.remaining,
            is_unlimited: usage.ai_tutor.is_unlimited,
            resets_at: usage.ai_tutor.resets_at
          }
        },
        chapter_practice_weekly: chapterPracticeWeekly
      },
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// AVAILABLE PLANS
// ============================================================================

/**
 * GET /api/subscriptions/plans
 *
 * Get available subscription plans for purchase.
 *
 * Authentication: Optional (returns different info based on auth)
 */
router.get('/plans', async (req, res, next) => {
  try {
    const plans = await getPurchasablePlans();

    // Transform plans for client display
    const formattedPlans = plans.map(plan => ({
      tier_id: plan.tier_id,
      display_name: plan.display_name,
      features: formatFeaturesForDisplay(plan.limits, plan.features),
      pricing: {
        monthly: {
          price: plan.pricing.monthly.display_price,
          per_month: plan.pricing.monthly.per_month_price,
          duration_days: plan.pricing.monthly.duration_days,
          badge: plan.pricing.monthly.badge
        },
        quarterly: {
          price: plan.pricing.quarterly.display_price,
          per_month: plan.pricing.quarterly.per_month_price,
          duration_days: plan.pricing.quarterly.duration_days,
          savings_percent: plan.pricing.quarterly.savings_percent,
          badge: plan.pricing.quarterly.badge
        },
        annual: {
          price: plan.pricing.annual.display_price,
          per_month: plan.pricing.annual.per_month_price,
          duration_days: plan.pricing.annual.duration_days,
          savings_percent: plan.pricing.annual.savings_percent,
          badge: plan.pricing.annual.badge
        }
      }
    }));

    res.json({
      success: true,
      data: {
        plans: formattedPlans,
        currency: 'INR',
        currency_symbol: '₹'
      },
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// USAGE DETAILS
// ============================================================================

/**
 * GET /api/subscriptions/usage
 *
 * Get detailed usage information for the authenticated user.
 *
 * Authentication: Required
 */
router.get('/usage', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    const usage = await getAllUsage(userId);

    res.json({
      success: true,
      data: {
        usage,
        resets_at: usage.snap_solve.resets_at
      },
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// ADMIN ENDPOINTS (Protected - for internal use only)
// ============================================================================

/**
 * POST /api/subscriptions/admin/grant-override
 *
 * Grant an override (beta tester, promotional) to a user.
 * This endpoint should be protected by admin authentication in production.
 *
 * Body: {
 *   user_id: string,
 *   type: 'beta_tester' | 'promotional',
 *   tier_id: 'ultra' | 'pro',
 *   duration_days: number,
 *   reason: string
 * }
 */
router.post('/admin/grant-override', adminLimiter, authenticateUser, async (req, res, next) => {
  try {
    const adminUserId = req.userId;
    const { user_id, type, tier_id, duration_days, reason } = req.body;

    // SECURITY: Verify admin role before allowing override grant
    const adminCheck = await isAdmin(adminUserId);
    if (!adminCheck) {
      logger.warn('Unauthorized override attempt', {
        requestId: req.id,
        attemptedBy: adminUserId,
        targetUserId: user_id
      });
      return res.status(403).json({
        success: false,
        error: 'Unauthorized: Admin access required',
        code: 'ADMIN_REQUIRED',
        requestId: req.id
      });
    }

    if (!user_id) {
      return res.status(400).json({
        success: false,
        error: 'user_id is required',
        code: 'MISSING_USER_ID',
        requestId: req.id
      });
    }

    // Validate tier_id if provided
    const validTiers = ['pro', 'ultra'];
    if (tier_id && !validTiers.includes(tier_id)) {
      return res.status(400).json({
        success: false,
        error: `Invalid tier_id. Must be one of: ${validTiers.join(', ')}`,
        code: 'INVALID_TIER',
        requestId: req.id
      });
    }

    // Validate duration_days: must be positive integer between 1 and 365
    const parsedDuration = duration_days !== undefined ? parseInt(duration_days, 10) : 90;
    if (isNaN(parsedDuration) || parsedDuration < 1 || parsedDuration > 365) {
      return res.status(400).json({
        success: false,
        error: 'duration_days must be a positive integer between 1 and 365',
        code: 'INVALID_DURATION',
        requestId: req.id
      });
    }

    // Validate reason length if provided
    if (reason && reason.length > 500) {
      return res.status(400).json({
        success: false,
        error: 'reason must be 500 characters or less',
        code: 'INVALID_REASON',
        requestId: req.id
      });
    }

    const result = await grantOverride(user_id, {
      type: type || 'beta_tester',
      tier_id: tier_id || 'ultra',
      duration_days: parsedDuration,
      reason: reason || '',
      granted_by: adminUserId
    });

    logger.info('Override granted via API', {
      requestId: req.id,
      adminUserId,
      targetUserId: user_id,
      type,
      tier_id,
      duration_days
    });

    res.json({
      success: true,
      data: result,
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/subscriptions/admin/revoke-override
 *
 * Revoke an override from a user.
 *
 * Body: { user_id: string }
 */
router.post('/admin/revoke-override', adminLimiter, authenticateUser, async (req, res, next) => {
  try {
    const adminUserId = req.userId;
    const { user_id } = req.body;

    // SECURITY: Verify admin role before allowing override revoke
    const adminCheck = await isAdmin(adminUserId);
    if (!adminCheck) {
      logger.warn('Unauthorized revoke attempt', {
        requestId: req.id,
        attemptedBy: adminUserId,
        targetUserId: user_id
      });
      return res.status(403).json({
        success: false,
        error: 'Unauthorized: Admin access required',
        code: 'ADMIN_REQUIRED',
        requestId: req.id
      });
    }

    if (!user_id) {
      return res.status(400).json({
        success: false,
        error: 'user_id is required',
        code: 'MISSING_USER_ID',
        requestId: req.id
      });
    }

    const result = await revokeOverride(user_id);

    logger.info('Override revoked via API', {
      requestId: req.id,
      adminUserId,
      targetUserId: user_id
    });

    res.json({
      success: true,
      data: result,
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// ADMIN: TIER CONFIG UPDATE
// ============================================================================

/**
 * POST /api/subscriptions/admin/update-tier-config
 *
 * Force update the Firestore tier_config document with current defaults.
 * Use this after updating DEFAULT_TIER_CONFIG in code to sync Firestore.
 *
 * Authentication: Required (Admin only)
 */
router.post('/admin/update-tier-config', authenticateUser, adminLimiter, async (req, res, next) => {
  try {
    const userId = req.userId;

    // Check admin permission
    const adminStatus = await isAdmin(userId);
    if (!adminStatus) {
      logger.warn('Unauthorized tier config update attempt', { userId });
      return res.status(403).json({
        success: false,
        error: 'Admin access required',
        requestId: req.id
      });
    }

    // Force update tier config
    const result = await forceUpdateTierConfig();

    logger.info('Tier config updated by admin', {
      userId,
      requestId: req.id
    });

    res.json({
      success: true,
      data: result,
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Get display name for a tier
 * @param {string} tier - Tier ID
 * @returns {string} Display name
 */
function getTierDisplayName(tier) {
  const displayNames = {
    free: 'Free',
    pro: 'Pro',
    ultra: 'Ultra'
  };
  return displayNames[tier] || tier;
}

/**
 * Format features for display
 * @param {Object} limits - Tier limits
 * @param {Object} features - Tier features
 * @returns {Array} Formatted features
 */
function formatFeaturesForDisplay(limits, features) {
  const featureList = [];

  // Snap & Solve
  if (limits.snap_solve_daily === -1) {
    featureList.push({ name: 'Snap & Solve', value: 'Unlimited' });
  } else {
    featureList.push({ name: 'Snap & Solve', value: `${limits.snap_solve_daily}/day` });
  }

  // Daily Quiz
  if (limits.daily_quiz_daily === -1) {
    featureList.push({ name: 'Daily Quiz', value: 'Unlimited' });
  } else {
    featureList.push({ name: 'Daily Quiz', value: `${limits.daily_quiz_daily}/day` });
  }

  // Analytics
  featureList.push({
    name: 'Analytics',
    value: features.analytics_access === 'full' ? 'Full Access' : 'Basic'
  });

  // Solution History
  if (limits.solution_history_days === -1) {
    featureList.push({ name: 'Solution History', value: 'Unlimited' });
  } else {
    featureList.push({ name: 'Solution History', value: `${limits.solution_history_days} days` });
  }

  // AI Tutor
  if (limits.ai_tutor_enabled) {
    featureList.push({ name: 'AI Tutor (Priya Ma\'am)', value: 'Yes' });
  }

  // Offline Mode
  if (limits.offline_enabled) {
    featureList.push({ name: 'Offline Mode', value: 'Yes' });
  }

  return featureList;
}

module.exports = router;
