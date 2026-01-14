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
const logger = require('../utils/logger');

const { getSubscriptionStatus, grantOverride, revokeOverride } = require('../services/subscriptionService');
const { getAllUsage } = require('../services/usageTrackingService');
const { getPurchasablePlans, getTierConfig } = require('../services/tierConfigService');

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

    // Get subscription status and usage in parallel
    const [status, usage] = await Promise.all([
      getSubscriptionStatus(userId),
      getAllUsage(userId)
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
        }
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
router.post('/admin/grant-override', authenticateUser, async (req, res, next) => {
  try {
    const adminUserId = req.userId;
    const { user_id, type, tier_id, duration_days, reason } = req.body;

    // TODO: Add proper admin role check
    // For now, we'll allow any authenticated user (should be restricted in production)
    logger.warn('Override granted without admin check', { adminUserId, targetUserId: user_id });

    if (!user_id) {
      return res.status(400).json({
        success: false,
        error: 'user_id is required',
        requestId: req.id
      });
    }

    const result = await grantOverride(user_id, {
      type: type || 'beta_tester',
      tier_id: tier_id || 'ultra',
      duration_days: duration_days || 90,
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
router.post('/admin/revoke-override', authenticateUser, async (req, res, next) => {
  try {
    const adminUserId = req.userId;
    const { user_id } = req.body;

    // TODO: Add proper admin role check
    logger.warn('Override revoked without admin check', { adminUserId, targetUserId: user_id });

    if (!user_id) {
      return res.status(400).json({
        success: false,
        error: 'user_id is required',
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
