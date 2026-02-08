/**
 * Subscription Service
 *
 * Core subscription logic including:
 * - getEffectiveTier() - Determines user's current tier
 * - Subscription status management
 * - Override handling for beta testers
 *
 * Tier Priority:
 * 1. Override (beta tester, promotional) - Highest
 * 2. Active paid subscription
 * 3. Active trial
 * 4. Default to FREE - Lowest
 */

const { db, admin } = require('../config/firebase');
const logger = require('../utils/logger');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const { getTierLimits, getTierFeatures, getTierLimitsAndFeatures } = require('./tierConfigService');

// ============================================================================
// TIER CACHE (Performance optimization)
// ============================================================================

// Cache for user tier info - { userId: { data, expiresAt } }
const tierCache = new Map();
const TIER_CACHE_TTL_MS = 60 * 1000; // 60 seconds

/**
 * Get cached tier info for a user
 * @param {string} userId
 * @returns {Object|null} Cached tier info or null if not cached/expired
 */
function getCachedTier(userId) {
  const cached = tierCache.get(userId);
  if (!cached) return null;

  if (Date.now() > cached.expiresAt) {
    tierCache.delete(userId);
    return null;
  }

  return cached.data;
}

/**
 * Set tier info in cache
 * @param {string} userId
 * @param {Object} tierInfo
 */
function setCachedTier(userId, tierInfo) {
  tierCache.set(userId, {
    data: tierInfo,
    expiresAt: Date.now() + TIER_CACHE_TTL_MS
  });
}

/**
 * Invalidate cached tier for a user
 * Call this when subscription changes (grant, revoke, purchase)
 * @param {string} userId
 */
function invalidateTierCache(userId) {
  tierCache.delete(userId);
}

/**
 * Clear all cached tiers (useful for testing)
 */
function clearTierCache() {
  tierCache.clear();
}

// ============================================================================
// TIER FUNCTIONS
// ============================================================================

/**
 * Get the effective tier for a user
 * Checks override, subscription, trial, then defaults to free
 * Uses in-memory cache with 60s TTL to reduce Firestore reads
 *
 * @param {string} userId - User ID
 * @param {Object} options - Options
 * @param {boolean} options.skipCache - Skip cache and fetch fresh (default: false)
 * @returns {Promise<Object>} Effective tier info { tier, source, expires_at, ... }
 */
async function getEffectiveTier(userId, options = {}) {
  // Check cache first (unless skipCache is true)
  if (!options.skipCache) {
    const cached = getCachedTier(userId);
    if (cached) {
      return cached;
    }
  }

  try {
    const userDoc = await retryFirestoreOperation(async () => {
      return await db.collection('users').doc(userId).get();
    });

    // Helper to cache and return result
    const cacheAndReturn = (result) => {
      setCachedTier(userId, result);
      return result;
    };

    if (!userDoc.exists) {
      logger.warn('User not found for getEffectiveTier', { userId });
      return cacheAndReturn({
        tier: 'free',
        source: 'default',
        expires_at: null
      });
    }

    const userData = userDoc.data();
    const now = new Date();

    // 1. Check override (beta testers, promotions) - HIGHEST PRIORITY
    if (userData.subscription?.override) {
      const override = userData.subscription.override;

      // SECURITY: Validate required override fields strictly
      const validTiers = ['pro', 'ultra'];
      const tier = override.tier_id;

      if (!tier || !validTiers.includes(tier)) {
        logger.warn('Invalid or missing tier_id in override, ignoring', {
          userId,
          tier_id: tier,
          override_type: override.type
        });
        // Don't use override - fall through to other checks
      } else {
        // Parse expiry date safely
        let expiresAt = null;
        try {
          if (override.expires_at?.toDate) {
            expiresAt = override.expires_at.toDate();
          } else if (override.expires_at) {
            expiresAt = new Date(override.expires_at);
          }

          // Validate the parsed date is valid
          if (!expiresAt || isNaN(expiresAt.getTime())) {
            logger.warn('Invalid expires_at in override, ignoring', { userId, expires_at: override.expires_at });
            expiresAt = null;
          }
        } catch (e) {
          logger.warn('Error parsing override expires_at', { userId, error: e.message });
          expiresAt = null;
        }

        // Only use override if expiry is valid and in the future
        if (expiresAt && expiresAt > now) {
          logger.info('User has active override', {
            userId,
            tier: tier,
            type: override.type,
            expires_at: expiresAt.toISOString()
          });

          return cacheAndReturn({
            tier: tier,
            source: 'override',
            expires_at: expiresAt.toISOString(),
            override_type: override.type,
            override_reason: override.reason
          });
        }
      }
    }

    // 2. Check active paid subscription
    if (userData.subscription?.active_subscription_id) {
      const subId = userData.subscription.active_subscription_id;

      const subDoc = await retryFirestoreOperation(async () => {
        return await db.collection('users')
          .doc(userId)
          .collection('subscriptions')
          .doc(subId)
          .get();
      });

      if (subDoc.exists) {
        const sub = subDoc.data();
        const endDate = sub.end_date?.toDate ? sub.end_date.toDate() : new Date(sub.end_date);

        if (sub.status === 'active' && endDate > now) {
          logger.info('User has active subscription', {
            userId,
            tier: sub.tier_id,
            subscription_id: subId,
            ends_at: endDate.toISOString()
          });

          return cacheAndReturn({
            tier: sub.tier_id,
            source: 'subscription',
            expires_at: endDate.toISOString(),
            subscription_id: subId,
            plan_type: sub.plan_type
          });
        }
      }
    }

    // 3. Check active trial
    if (userData.trial?.ends_at || userData.trialEndsAt) {
      // Support both old format (userData.trial.ends_at) and new format (userData.trialEndsAt)
      const trialEndTimestamp = userData.trialEndsAt || userData.trial?.ends_at;
      const trialEnd = trialEndTimestamp?.toDate ? trialEndTimestamp.toDate() : new Date(trialEndTimestamp);

      if (trialEnd > now) {
        const daysRemaining = Math.ceil((trialEnd - now) / (1000 * 60 * 60 * 24));

        // Determine tier: check subscriptionTier, then trial.tier_id, then subscriptionStatus, finally default to 'pro'
        let tierValue = 'pro';
        if (userData.subscriptionTier && ['pro', 'ultra'].includes(userData.subscriptionTier.toLowerCase())) {
          tierValue = userData.subscriptionTier.toLowerCase();
        } else if (userData.trial?.tier_id) {
          tierValue = userData.trial.tier_id;
        } else if (userData.subscriptionStatus === 'ultra_trial') {
          tierValue = 'ultra';
        }

        logger.info('User has active trial', {
          userId,
          tier: tierValue,
          ends_at: trialEnd.toISOString(),
          days_remaining: daysRemaining
        });

        return cacheAndReturn({
          tier: tierValue,
          source: 'trial',
          expires_at: trialEnd.toISOString(),
          trial_started_at: userData.trial?.started_at,
          days_remaining: daysRemaining
        });
      } else {
        // Trial expired - trigger async downgrade
        const { expireTrialAsync } = require('./trialService');
        expireTrialAsync(userId);
      }
    }

    // 4. Default to free tier
    return cacheAndReturn({
      tier: 'free',
      source: 'default',
      expires_at: null
    });
  } catch (error) {
    logger.error('Error in getEffectiveTier', { userId, error: error.message });

    // Safe fallback to free tier (don't cache errors)
    return {
      tier: 'free',
      source: 'default',
      expires_at: null,
      error: true
    };
  }
}

/**
 * Get complete subscription status for a user
 * Includes tier info, limits, features, and usage
 *
 * @param {string} userId - User ID
 * @param {Object} tierInfo - Optional pre-fetched tier info (optimization)
 * @returns {Promise<Object>} Full subscription status
 */
async function getSubscriptionStatus(userId, tierInfo = null) {
  // PERFORMANCE: Use passed tierInfo if available to avoid redundant call
  if (!tierInfo) {
    tierInfo = await getEffectiveTier(userId);
  }

  // PERFORMANCE: Use combined function to get both limits and features in one call
  const { limits, features } = await getTierLimitsAndFeatures(tierInfo.tier);

  return {
    ...tierInfo,
    limits,
    features
  };
}

/**
 * Grant an override to a user (beta tester, promotional)
 *
 * @param {string} userId - User ID
 * @param {Object} overrideData - Override details
 * @param {string} overrideData.type - 'beta_tester' or 'promotional'
 * @param {string} overrideData.tier_id - Tier to grant (default: 'ultra')
 * @param {number} overrideData.duration_days - Duration in days
 * @param {string} overrideData.reason - Reason for grant
 * @param {string} overrideData.granted_by - Admin who granted
 * @returns {Promise<Object>} Updated subscription info
 */
async function grantOverride(userId, overrideData) {
  const {
    type = 'beta_tester',
    tier_id = 'ultra',
    duration_days = 90,
    reason = '',
    granted_by = 'admin'
  } = overrideData;

  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + duration_days);

  const override = {
    type,
    tier_id,
    granted_by,
    granted_at: admin.firestore.FieldValue.serverTimestamp(),
    expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
    reason
  };

  await retryFirestoreOperation(async () => {
    await db.collection('users').doc(userId).update({
      'subscription.override': override,
      'subscription.tier': tier_id
    });
  });

  // Invalidate tier cache so next request gets fresh data
  invalidateTierCache(userId);

  logger.info('Override granted', {
    userId,
    type,
    tier_id,
    duration_days,
    expires_at: expiresAt.toISOString()
  });

  return {
    success: true,
    override: {
      ...override,
      expires_at: expiresAt.toISOString()
    }
  };
}

/**
 * Revoke an override from a user
 *
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Result
 */
async function revokeOverride(userId) {
  await retryFirestoreOperation(async () => {
    await db.collection('users').doc(userId).update({
      'subscription.override': admin.firestore.FieldValue.delete()
    });
  });

  // Invalidate cache and recalculate effective tier
  invalidateTierCache(userId);
  const newTier = await getEffectiveTier(userId);

  await retryFirestoreOperation(async () => {
    await db.collection('users').doc(userId).update({
      'subscription.tier': newTier.tier
    });
  });

  logger.info('Override revoked', { userId, new_tier: newTier.tier });

  return {
    success: true,
    new_tier: newTier
  };
}

/**
 * Check if a user has a specific feature enabled
 *
 * @param {string} userId - User ID
 * @param {string} featureName - Feature to check
 * @returns {Promise<boolean>} True if feature is enabled
 */
async function hasFeature(userId, featureName) {
  const status = await getSubscriptionStatus(userId);

  // Handle boolean features
  if (featureName in status.limits) {
    const value = status.limits[featureName];
    // For boolean-like limits (ai_tutor_enabled, offline_enabled)
    if (typeof value === 'boolean') {
      return value;
    }
    // For numeric limits, check if > 0 or unlimited (-1)
    return value > 0 || value === -1;
  }

  // Handle string features (analytics_access)
  if (featureName in status.features) {
    return status.features[featureName] === 'full';
  }

  return false;
}

/**
 * Get feature access level
 *
 * @param {string} userId - User ID
 * @param {string} featureName - Feature to check
 * @returns {Promise<string|number|boolean>} Feature value
 */
async function getFeatureAccess(userId, featureName) {
  const status = await getSubscriptionStatus(userId);

  if (featureName in status.limits) {
    return status.limits[featureName];
  }

  if (featureName in status.features) {
    return status.features[featureName];
  }

  return null;
}

/**
 * Sync user's subscription.tier field with effective tier
 * Call this periodically or after subscription changes
 *
 * @param {string} userId - User ID
 */
async function syncUserTier(userId) {
  const effectiveTier = await getEffectiveTier(userId);

  await retryFirestoreOperation(async () => {
    await db.collection('users').doc(userId).update({
      'subscription.tier': effectiveTier.tier,
      'subscription.last_synced': admin.firestore.FieldValue.serverTimestamp()
    });
  });

  logger.info('User tier synced', { userId, tier: effectiveTier.tier });

  return effectiveTier;
}

module.exports = {
  getEffectiveTier,
  getSubscriptionStatus,
  grantOverride,
  revokeOverride,
  hasFeature,
  getFeatureAccess,
  syncUserTier,
  // Cache management (for testing and subscription changes)
  invalidateTierCache,
  clearTierCache
};
