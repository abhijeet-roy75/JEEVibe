/**
 * In-Memory Cache Utility
 * 
 * Uses node-cache for caching API responses
 * Suitable for MVP (single instance)
 * Can be replaced with Redis later for horizontal scaling
 */

const NodeCache = require('node-cache');
const crypto = require('crypto');
const logger = require('./logger');

// Create cache instance
// stdTTL: default TTL in seconds (10 minutes)
// checkperiod: how often to check for expired keys (1 minute)
const cache = new NodeCache({
  stdTTL: 600, // 10 minutes default
  checkperiod: 60, // Check for expired keys every minute
  useClones: false, // Better performance, but be careful with object mutations
});

// Get environment prefix for cache keys (prevents collisions between environments)
const getEnvPrefix = () => {
  return process.env.NODE_ENV === 'production' ? 'prod' : 
         process.env.NODE_ENV === 'staging' ? 'staging' : 
         'dev';
};

// Cache key generators
const CacheKeys = {
  userProfile: (userId) => `${getEnvPrefix()}:user:profile:${userId}`,
  assessmentQuestions: (userId) => `${getEnvPrefix()}:assessment:questions:${userId}`,
  assessmentResults: (userId) => `${getEnvPrefix()}:assessment:results:${userId}`,
  authToken: (token) => {
    // Use SHA-256 hash instead of substring to prevent collisions
    return `${getEnvPrefix()}:auth:token:${crypto.createHash('sha256').update(token).digest('hex').substring(0, 16)}`;
  },
};

/**
 * Get value from cache
 */
function get(key) {
  try {
    if (!key || typeof key !== 'string') {
      logger.warn('Invalid cache key', { key: String(key) });
      return undefined;
    }
    const value = cache.get(key);
    if (value !== undefined) {
      logger.debug('Cache hit', { key });
    }
    return value;
  } catch (error) {
    logger.error('Cache get error', { key: String(key), error: error.message });
    return undefined;
  }
}

/**
 * Set value in cache
 * @param {string} key - Cache key
 * @param {any} value - Value to cache
 * @param {number} ttl - Time to live in seconds (optional, uses default if not provided)
 */
function set(key, value, ttl = null) {
  try {
    if (!key || typeof key !== 'string') {
      logger.warn('Invalid cache key', { key: String(key) });
      return false;
    }
    
    // Validate value size (prevent memory issues)
    const valueSize = JSON.stringify(value).length;
    if (valueSize > 10 * 1024 * 1024) { // 10MB limit
      logger.warn('Cache value too large, not caching', { key, size: valueSize });
      return false;
    }
    
    const result = ttl ? cache.set(key, value, ttl) : cache.set(key, value);
    if (result) {
      logger.debug('Cache set', { key, ttl: ttl || 'default' });
    }
    return result;
  } catch (error) {
    logger.error('Cache set error', { key: String(key), error: error.message });
    return false;
  }
}

/**
 * Delete value from cache
 */
function del(key) {
  try {
    if (!key || typeof key !== 'string') {
      logger.warn('Invalid cache key for deletion', { key: String(key) });
      return 0;
    }
    const result = cache.del(key);
    if (result > 0) {
      logger.debug('Cache deleted', { key });
    }
    return result;
  } catch (error) {
    logger.error('Cache delete error', { key: String(key), error: error.message });
    return 0;
  }
}

/**
 * Clear all cache
 */
function flush() {
  return cache.flushAll();
}

/**
 * Get cache statistics
 */
function getStats() {
  return cache.getStats();
}

module.exports = {
  cache,
  CacheKeys,
  get,
  set,
  del,
  flush,
  getStats,
};

