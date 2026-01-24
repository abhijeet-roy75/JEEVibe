/**
 * Tier Configuration Service
 *
 * Fetches and caches tier configuration from Firestore.
 * Configuration is cached with a 5-minute TTL to reduce Firestore reads.
 *
 * Tier config is stored at: tier_config/active
 */

const { db } = require('../config/firebase');
const logger = require('../utils/logger');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');

// Cache configuration
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes
let cachedConfig = null;
let cacheTimestamp = 0;

// Default tier configuration (fallback if Firestore is unavailable)
const DEFAULT_TIER_CONFIG = {
  version: '1.0.0',
  tiers: {
    free: {
      tier_id: 'free',
      display_name: 'Free',
      is_active: true,
      is_purchasable: false,
      limits: {
        snap_solve_daily: 5,
        daily_quiz_daily: 1,
        solution_history_days: 7,
        ai_tutor_enabled: false,
        ai_tutor_messages_daily: 0,
        chapter_practice_enabled: true,
        chapter_practice_per_chapter: 15,
        chapter_practice_weekly_per_subject: 1,
        mock_tests_monthly: 1,
        pyq_years_access: 2,
        offline_enabled: false,
        offline_solutions_limit: 0,
        max_devices: 1  // Single device for free tier
      },
      features: {
        analytics_access: 'basic'
      }
    },
    pro: {
      tier_id: 'pro',
      display_name: 'Pro',
      is_active: true,
      is_purchasable: true,
      limits: {
        snap_solve_daily: 10,
        daily_quiz_daily: 10,
        solution_history_days: 30,
        ai_tutor_enabled: false,
        ai_tutor_messages_daily: 0,
        chapter_practice_enabled: true,
        chapter_practice_per_chapter: 20,
        chapter_practice_weekly_per_subject: -1,
        mock_tests_monthly: 5,
        pyq_years_access: 5,
        offline_enabled: true,
        offline_solutions_limit: -1,
        max_devices: 2  // Phone + tablet for paying users
      },
      features: {
        analytics_access: 'full'
      },
      pricing: {
        monthly: {
          price: 29900,
          display_price: '299',
          per_month_price: '299',
          duration_days: 30,
          savings_percent: 0,
          badge: null
        },
        quarterly: {
          price: 74700,
          display_price: '747',
          per_month_price: '249',
          duration_days: 90,
          savings_percent: 17,
          badge: 'MOST POPULAR'
        },
        annual: {
          price: 238800,
          display_price: '2,388',
          per_month_price: '199',
          duration_days: 365,
          savings_percent: 33,
          badge: 'SAVE 33%'
        }
      }
    },
    ultra: {
      tier_id: 'ultra',
      display_name: 'Ultra',
      is_active: true,
      is_purchasable: true,
      limits: {
        // Soft caps instead of truly unlimited (-1) to prevent bot abuse
        // These are high enough that no legitimate user would hit them
        snap_solve_daily: 50,           // Was -1, now 50/day
        daily_quiz_daily: 25,           // Was -1, now 25/day
        solution_history_days: 365,     // Was -1, now 1 year
        ai_tutor_enabled: true,
        ai_tutor_messages_daily: 100,   // Was -1, now 100/day
        chapter_practice_enabled: true,
        chapter_practice_per_chapter: 50,     // Was -1, high cap
        chapter_practice_weekly_per_subject: -1,  // Keep unlimited for weekly
        mock_tests_monthly: 15,         // Was -1, now 15/month
        pyq_years_access: -1,           // Keep unlimited for PYQ years
        offline_enabled: true,
        offline_solutions_limit: -1,    // Keep unlimited for offline
        max_devices: 2  // Same as Pro
      },
      features: {
        analytics_access: 'full'
      },
      pricing: {
        monthly: {
          price: 49900,
          display_price: '499',
          per_month_price: '499',
          duration_days: 30,
          savings_percent: 0,
          badge: null
        },
        quarterly: {
          price: 119700,
          display_price: '1,197',
          per_month_price: '399',
          duration_days: 90,
          savings_percent: 20,
          badge: 'MOST POPULAR'
        },
        annual: {
          price: 358800,
          display_price: '3,588',
          per_month_price: '299',
          duration_days: 365,
          savings_percent: 40,
          badge: 'BEST VALUE'
        }
      }
    }
  }
};

/**
 * Check if cache is still valid
 * @returns {boolean}
 */
function isCacheValid() {
  return cachedConfig && (Date.now() - cacheTimestamp) < CACHE_TTL_MS;
}

/**
 * Get tier configuration from Firestore (with caching)
 * @returns {Promise<Object>} Tier configuration
 */
async function getTierConfig() {
  // Return cached config if valid
  if (isCacheValid()) {
    return cachedConfig;
  }

  try {
    const configDoc = await retryFirestoreOperation(async () => {
      return await db.collection('tier_config').doc('active').get();
    });

    if (configDoc.exists) {
      cachedConfig = configDoc.data();
      cacheTimestamp = Date.now();
      logger.info('Tier config loaded from Firestore', {
        version: cachedConfig.version,
        tiers: Object.keys(cachedConfig.tiers || {})
      });
      return cachedConfig;
    }

    // Document doesn't exist, use defaults and try to create it
    logger.warn('Tier config not found in Firestore, using defaults');
    cachedConfig = DEFAULT_TIER_CONFIG;
    cacheTimestamp = Date.now();

    // Try to create the default config in Firestore (non-blocking)
    initializeDefaultConfig().catch(err => {
      logger.warn('Failed to initialize default tier config', { error: err.message });
    });

    return cachedConfig;
  } catch (error) {
    logger.error('Error fetching tier config', { error: error.message });

    // Return cached config even if expired, or defaults
    if (cachedConfig) {
      logger.warn('Using stale cached tier config');
      return cachedConfig;
    }

    logger.warn('Using default tier config due to Firestore error');
    return DEFAULT_TIER_CONFIG;
  }
}

/**
 * Get configuration for a specific tier
 * @param {string} tierId - Tier ID (free, pro, ultra)
 * @returns {Promise<Object|null>} Tier configuration or null
 */
async function getTierById(tierId) {
  const config = await getTierConfig();
  return config.tiers?.[tierId] || null;
}

/**
 * Get limits for a specific tier
 * @param {string} tierId - Tier ID (free, pro, ultra)
 * @returns {Promise<Object>} Tier limits
 */
async function getTierLimits(tierId) {
  const tier = await getTierById(tierId);
  return tier?.limits || DEFAULT_TIER_CONFIG.tiers.free.limits;
}

/**
 * Get features for a specific tier
 * @param {string} tierId - Tier ID (free, pro, ultra)
 * @returns {Promise<Object>} Tier features
 */
async function getTierFeatures(tierId) {
  const tier = await getTierById(tierId);
  return tier?.features || DEFAULT_TIER_CONFIG.tiers.free.features;
}

/**
 * Get all purchasable plans
 * @returns {Promise<Array>} List of purchasable tiers with pricing
 */
async function getPurchasablePlans() {
  const config = await getTierConfig();
  const plans = [];

  for (const [tierId, tier] of Object.entries(config.tiers || {})) {
    if (tier.is_active && tier.is_purchasable && tier.pricing) {
      plans.push({
        tier_id: tierId,
        display_name: tier.display_name,
        limits: tier.limits,
        features: tier.features,
        pricing: tier.pricing
      });
    }
  }

  return plans;
}

/**
 * Initialize default tier config in Firestore
 * Called when config doesn't exist
 */
async function initializeDefaultConfig() {
  try {
    const configRef = db.collection('tier_config').doc('active');
    const configDoc = await configRef.get();

    if (!configDoc.exists) {
      await configRef.set({
        ...DEFAULT_TIER_CONFIG,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        updated_by: 'system'
      });
      logger.info('Default tier config initialized in Firestore');
    }
  } catch (error) {
    logger.error('Failed to initialize tier config', { error: error.message });
    throw error;
  }
}

/**
 * Force refresh the cached configuration
 * Useful after admin updates
 */
function invalidateCache() {
  cachedConfig = null;
  cacheTimestamp = 0;
  logger.info('Tier config cache invalidated');
}

/**
 * Force update tier config in Firestore with current defaults
 * Use this when DEFAULT_TIER_CONFIG has been updated and needs to be synced
 */
async function forceUpdateTierConfig() {
  try {
    const configRef = db.collection('tier_config').doc('active');
    await configRef.set({
      ...DEFAULT_TIER_CONFIG,
      updated_at: new Date().toISOString(),
      updated_by: 'system_migration'
    }, { merge: true });

    // Invalidate cache so next request uses fresh data
    invalidateCache();

    logger.info('Tier config force updated in Firestore', {
      version: DEFAULT_TIER_CONFIG.version,
      freeTierChapterPracticeEnabled: DEFAULT_TIER_CONFIG.tiers.free.limits.chapter_practice_enabled
    });

    return { success: true, message: 'Tier config updated' };
  } catch (error) {
    logger.error('Failed to force update tier config', { error: error.message });
    throw error;
  }
}

/**
 * Check if a limit value represents "unlimited"
 * @param {number} limitValue - The limit value
 * @returns {boolean} True if unlimited
 */
function isUnlimited(limitValue) {
  return limitValue === -1;
}

module.exports = {
  getTierConfig,
  getTierById,
  getTierLimits,
  getTierFeatures,
  getPurchasablePlans,
  initializeDefaultConfig,
  invalidateCache,
  forceUpdateTierConfig,
  isUnlimited,
  DEFAULT_TIER_CONFIG
};
