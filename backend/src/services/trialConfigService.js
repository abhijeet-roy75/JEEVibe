/**
 * Trial Configuration Service
 *
 * Fetches and caches trial configuration from Firestore.
 * Configuration is cached with a 5-minute TTL to reduce Firestore reads.
 *
 * Trial config is stored at: trial_config/active
 */

const { db } = require('../config/firebase');
const logger = require('../utils/logger');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');

// Cache configuration
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes
let cachedConfig = null;
let cacheTimestamp = 0;

// Default trial configuration (fallback if Firestore is unavailable)
const DEFAULT_TRIAL_CONFIG = {
  enabled: true,
  trial_tier_id: 'pro',
  duration_days: 30,

  eligibility: {
    one_per_phone: true,
    check_existing_subscription: true
  },

  notification_schedule: [
    {
      days_remaining: 23,
      channels: ['email'],
      template: 'trial_week_1'
    },
    {
      days_remaining: 5,
      channels: ['email', 'push'],
      template: 'trial_urgency_5'
    },
    {
      days_remaining: 2,
      channels: ['email', 'push'],
      template: 'trial_urgency_2'
    },
    {
      days_remaining: 0,
      channels: ['email', 'push', 'in_app_dialog'],
      template: 'trial_expired'
    }
  ],

  notifications: {
    email: {
      enabled: true,
      milestones: [23, 5, 2, 0]
    },
    push: {
      enabled: true,
      milestones: [5, 2, 0]
    },
    in_app_banner: {
      enabled: true,
      urgency_threshold: 5
    },
    in_app_dialog: {
      enabled: true
    }
  },

  expiry: {
    downgrade_to_tier: 'free',
    grace_period_days: 0,
    show_discount_offer: true,
    discount_code: 'TRIAL2PRO',
    discount_valid_days: 7
  },

  version: '1.0.0'
};

/**
 * Check if cache is still valid
 * @returns {boolean}
 */
function isCacheValid() {
  return cachedConfig && (Date.now() - cacheTimestamp) < CACHE_TTL_MS;
}

/**
 * Get trial configuration from Firestore (with caching)
 * @returns {Promise<Object>} Trial configuration
 */
async function getTrialConfig() {
  // Return cached config if valid
  if (isCacheValid()) {
    return cachedConfig;
  }

  try {
    const configDoc = await retryFirestoreOperation(async () => {
      return await db.collection('trial_config').doc('active').get();
    });

    if (configDoc.exists) {
      cachedConfig = configDoc.data();
      cacheTimestamp = Date.now();
      logger.info('Trial config loaded from Firestore', {
        version: cachedConfig.version,
        enabled: cachedConfig.enabled,
        trial_tier_id: cachedConfig.trial_tier_id,
        duration_days: cachedConfig.duration_days
      });
      return cachedConfig;
    }

    // Document doesn't exist, use defaults
    logger.warn('Trial config not found in Firestore, using defaults');
    cachedConfig = DEFAULT_TRIAL_CONFIG;
    cacheTimestamp = Date.now();

    // Try to create the default config in Firestore (non-blocking)
    initializeDefaultConfig().catch(err => {
      logger.warn('Failed to initialize default trial config', { error: err.message });
    });

    return cachedConfig;
  } catch (error) {
    logger.error('Error fetching trial config', { error: error.message });

    // Return cached config even if expired, or defaults
    if (cachedConfig) {
      logger.warn('Using stale cached trial config');
      return cachedConfig;
    }

    logger.warn('Using default trial config due to Firestore error');
    return DEFAULT_TRIAL_CONFIG;
  }
}

/**
 * Check if trials are currently enabled
 * @returns {Promise<boolean>}
 */
async function areTrialsEnabled() {
  const config = await getTrialConfig();
  return config.enabled === true;
}

/**
 * Get trial duration in days
 * @returns {Promise<number>}
 */
async function getTrialDurationDays() {
  const config = await getTrialConfig();
  return config.duration_days || 30;
}

/**
 * Get trial tier ID (pro or ultra)
 * @returns {Promise<string>}
 */
async function getTrialTierId() {
  const config = await getTrialConfig();
  return config.trial_tier_id || 'pro';
}

/**
 * Get eligibility rules
 * @returns {Promise<Object>}
 */
async function getEligibilityRules() {
  const config = await getTrialConfig();
  return config.eligibility || DEFAULT_TRIAL_CONFIG.eligibility;
}

/**
 * Get notification schedule
 * @returns {Promise<Array>}
 */
async function getNotificationSchedule() {
  const config = await getTrialConfig();
  return config.notification_schedule || DEFAULT_TRIAL_CONFIG.notification_schedule;
}

/**
 * Get notification settings for a specific channel
 * @param {string} channel - email, push, in_app_banner, or in_app_dialog
 * @returns {Promise<Object>}
 */
async function getNotificationSettings(channel) {
  const config = await getTrialConfig();
  return config.notifications?.[channel] || DEFAULT_TRIAL_CONFIG.notifications[channel];
}

/**
 * Get expiry configuration
 * @returns {Promise<Object>}
 */
async function getExpiryConfig() {
  const config = await getTrialConfig();
  return config.expiry || DEFAULT_TRIAL_CONFIG.expiry;
}

/**
 * Check if a specific notification channel is enabled
 * @param {string} channel - email, push, in_app_banner, or in_app_dialog
 * @returns {Promise<boolean>}
 */
async function isNotificationChannelEnabled(channel) {
  const settings = await getNotificationSettings(channel);
  return settings?.enabled === true;
}

/**
 * Get the milestones at which notifications should be sent for a channel
 * @param {string} channel - email or push
 * @returns {Promise<Array<number>>}
 */
async function getNotificationMilestones(channel) {
  const settings = await getNotificationSettings(channel);
  return settings?.milestones || [];
}

/**
 * Initialize default trial config in Firestore
 * Called when config doesn't exist
 */
async function initializeDefaultConfig() {
  try {
    const configRef = db.collection('trial_config').doc('active');
    const configDoc = await configRef.get();

    if (!configDoc.exists) {
      await configRef.set({
        ...DEFAULT_TRIAL_CONFIG,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        updated_by: 'system'
      });
      logger.info('Default trial config initialized in Firestore');
    }
  } catch (error) {
    logger.error('Failed to initialize trial config', { error: error.message });
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
  logger.info('Trial config cache invalidated');
}

/**
 * Force update trial config in Firestore with current defaults
 * Use this when DEFAULT_TRIAL_CONFIG has been updated and needs to be synced
 */
async function forceUpdateTrialConfig() {
  try {
    const configRef = db.collection('trial_config').doc('active');
    await configRef.set({
      ...DEFAULT_TRIAL_CONFIG,
      updated_at: new Date().toISOString(),
      updated_by: 'system_migration'
    }, { merge: true });

    // Invalidate cache so next request uses fresh data
    invalidateCache();

    logger.info('Trial config force updated in Firestore', {
      version: DEFAULT_TRIAL_CONFIG.version,
      enabled: DEFAULT_TRIAL_CONFIG.enabled,
      duration_days: DEFAULT_TRIAL_CONFIG.duration_days
    });

    return { success: true, message: 'Trial config updated' };
  } catch (error) {
    logger.error('Failed to force update trial config', { error: error.message });
    throw error;
  }
}

module.exports = {
  getTrialConfig,
  areTrialsEnabled,
  getTrialDurationDays,
  getTrialTierId,
  getEligibilityRules,
  getNotificationSchedule,
  getNotificationSettings,
  getExpiryConfig,
  isNotificationChannelEnabled,
  getNotificationMilestones,
  initializeDefaultConfig,
  invalidateCache,
  forceUpdateTrialConfig,
  DEFAULT_TRIAL_CONFIG
};
