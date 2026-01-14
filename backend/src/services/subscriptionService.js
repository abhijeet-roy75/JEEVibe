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
const { getTierLimits, getTierFeatures } = require('./tierConfigService');

/**
 * Get the effective tier for a user
 * Checks override, subscription, trial, then defaults to free
 *
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Effective tier info { tier, source, expires_at, ... }
 */
async function getEffectiveTier(userId) {
  try {
    const userDoc = await retryFirestoreOperation(async () => {
      return await db.collection('users').doc(userId).get();
    });

    if (!userDoc.exists) {
      logger.warn('User not found for getEffectiveTier', { userId });
      return {
        tier: 'free',
        source: 'default',
        expires_at: null
      };
    }

    const userData = userDoc.data();
    const now = new Date();

    // 1. Check override (beta testers, promotions) - HIGHEST PRIORITY
    if (userData.subscription?.override) {
      const override = userData.subscription.override;
      const expiresAt = override.expires_at?.toDate ? override.expires_at.toDate() : new Date(override.expires_at);

      if (expiresAt > now) {
        logger.info('User has active override', {
          userId,
          tier: override.tier_id || 'ultra',
          type: override.type,
          expires_at: expiresAt.toISOString()
        });

        return {
          tier: override.tier_id || 'ultra',
          source: 'override',
          expires_at: expiresAt.toISOString(),
          override_type: override.type,
          override_reason: override.reason
        };
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

          return {
            tier: sub.tier_id,
            source: 'subscription',
            expires_at: endDate.toISOString(),
            subscription_id: subId,
            plan_type: sub.plan_type
          };
        }
      }
    }

    // 3. Check active trial
    if (userData.trial?.ends_at) {
      const trialEnd = userData.trial.ends_at?.toDate ? userData.trial.ends_at.toDate() : new Date(userData.trial.ends_at);

      if (trialEnd > now) {
        logger.info('User has active trial', {
          userId,
          ends_at: trialEnd.toISOString()
        });

        return {
          tier: 'pro',
          source: 'trial',
          expires_at: trialEnd.toISOString()
        };
      }
    }

    // 4. Default to free tier
    return {
      tier: 'free',
      source: 'default',
      expires_at: null
    };
  } catch (error) {
    logger.error('Error in getEffectiveTier', { userId, error: error.message });

    // Safe fallback to free tier
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
 * @returns {Promise<Object>} Full subscription status
 */
async function getSubscriptionStatus(userId) {
  const tierInfo = await getEffectiveTier(userId);
  const limits = await getTierLimits(tierInfo.tier);
  const features = await getTierFeatures(tierInfo.tier);

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

  // Recalculate effective tier after revoke
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
  syncUserTier
};
