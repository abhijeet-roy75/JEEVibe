/**
 * Feature Gate Middleware
 *
 * Middleware for gating features based on user's subscription tier.
 *
 * Provides:
 * - checkUsageLimit(usageType) - Check and increment usage limits
 * - requireFeature(featureName) - Require a specific feature
 * - attachTierInfo() - Attach tier info to request without blocking
 */

const { incrementUsage, canUse, getUsage } = require('../services/usageTrackingService');
const { getEffectiveTier, getFeatureAccess } = require('../services/subscriptionService');
const { getNextMidnightIST } = require('../services/usageTrackingService');
const logger = require('../utils/logger');

/**
 * Middleware to check usage limit before allowing action
 * Increments the usage counter if allowed
 *
 * @param {string} usageType - Type of usage (snap_solve, daily_quiz, ai_tutor)
 * @param {Object} options - Options
 * @param {boolean} options.incrementOnSuccess - Whether to increment on success (default: true)
 * @returns {Function} Express middleware
 */
function checkUsageLimit(usageType, options = {}) {
  const { incrementOnSuccess = true } = options;

  return async (req, res, next) => {
    try {
      const userId = req.userId;

      if (!userId) {
        return res.status(401).json({
          success: false,
          error: 'Authentication required',
          code: 'AUTH_REQUIRED'
        });
      }

      let result;

      if (incrementOnSuccess) {
        // Check and increment in one call
        result = await incrementUsage(userId, usageType);
      } else {
        // Just check without incrementing
        result = await canUse(userId, usageType);
      }

      // Attach usage info to request for response
      req.usageInfo = result;
      req.tierInfo = { tier: result.tier };

      if (!result.allowed) {
        logger.warn('Usage limit reached', {
          userId,
          usageType,
          tier: result.tier,
          used: result.used,
          limit: result.limit
        });

        return res.status(429).json({
          success: false,
          error: `Daily limit of ${result.limit} reached for ${usageType.replace('_', ' ')}`,
          code: 'LIMIT_REACHED',
          usage: {
            type: usageType,
            used: result.used,
            limit: result.limit,
            remaining: 0,
            resets_at: result.resets_at
          },
          upgrade: {
            message: result.tier === 'free'
              ? 'Upgrade to Pro for more daily usage'
              : 'Upgrade to Ultra for unlimited usage',
            current_tier: result.tier
          }
        });
      }

      next();
    } catch (error) {
      logger.error('Error in checkUsageLimit middleware', {
        usageType,
        error: error.message
      });
      next(error);
    }
  };
}

/**
 * Middleware to require a specific feature
 * Blocks request if user doesn't have the feature
 *
 * @param {string} featureName - Feature name to check
 * @returns {Function} Express middleware
 */
function requireFeature(featureName) {
  return async (req, res, next) => {
    try {
      const userId = req.userId;

      if (!userId) {
        return res.status(401).json({
          success: false,
          error: 'Authentication required',
          code: 'AUTH_REQUIRED'
        });
      }

      const tierInfo = await getEffectiveTier(userId);
      const featureValue = await getFeatureAccess(userId, featureName);

      // Attach to request
      req.tierInfo = tierInfo;
      req.featureAccess = { [featureName]: featureValue };

      // Check if feature is enabled
      let hasAccess = false;

      if (typeof featureValue === 'boolean') {
        hasAccess = featureValue;
      } else if (typeof featureValue === 'number') {
        hasAccess = featureValue > 0 || featureValue === -1;
      } else if (featureValue === 'full') {
        hasAccess = true;
      }

      if (!hasAccess) {
        logger.warn('Feature not available for tier', {
          userId,
          featureName,
          tier: tierInfo.tier
        });

        return res.status(403).json({
          success: false,
          error: `${featureName} is not available on your current plan`,
          code: 'FEATURE_NOT_AVAILABLE',
          current_tier: tierInfo.tier,
          required_tier: getRequiredTierForFeature(featureName),
          upgrade: {
            message: 'Upgrade your plan to access this feature'
          }
        });
      }

      next();
    } catch (error) {
      logger.error('Error in requireFeature middleware', {
        featureName,
        error: error.message
      });
      next(error);
    }
  };
}

/**
 * Middleware to attach tier info to request without blocking
 * Useful when you need tier info but don't want to block
 *
 * @returns {Function} Express middleware
 */
function attachTierInfo() {
  return async (req, res, next) => {
    try {
      const userId = req.userId;

      if (userId) {
        const tierInfo = await getEffectiveTier(userId);
        req.tierInfo = tierInfo;
      }

      next();
    } catch (error) {
      logger.error('Error in attachTierInfo middleware', {
        error: error.message
      });
      // Don't block, just continue without tier info
      next();
    }
  };
}

/**
 * Get analytics access level for a user
 * Returns 'basic' or 'full'
 *
 * @param {string} userId - User ID
 * @returns {Promise<string>} Access level
 */
async function getAnalyticsAccess(userId) {
  const accessLevel = await getFeatureAccess(userId, 'analytics_access');
  return accessLevel || 'basic';
}

/**
 * Helper to determine required tier for a feature
 * @param {string} featureName - Feature name
 * @returns {string} Required tier
 */
function getRequiredTierForFeature(featureName) {
  const featureTierMap = {
    'ai_tutor_enabled': 'ultra',
    'analytics_access': 'pro',
    'offline_enabled': 'pro'
  };

  return featureTierMap[featureName] || 'pro';
}

/**
 * Middleware to check usage without incrementing
 * Useful for pre-flight checks
 *
 * @param {string} usageType - Type of usage
 * @returns {Function} Express middleware
 */
function checkUsageLimitOnly(usageType) {
  return checkUsageLimit(usageType, { incrementOnSuccess: false });
}

module.exports = {
  checkUsageLimit,
  checkUsageLimitOnly,
  requireFeature,
  attachTierInfo,
  getAnalyticsAccess
};
