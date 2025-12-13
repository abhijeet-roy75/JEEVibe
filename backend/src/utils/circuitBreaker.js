/**
 * Circuit Breaker for External APIs
 * 
 * Prevents cascading failures when external services are down
 * Uses opossum library
 */

const CircuitBreaker = require('opossum');
const logger = require('./logger');

/**
 * Create circuit breaker for OpenAI API calls
 */
function createOpenAICircuitBreaker(fn, options = {}) {
  const defaultOptions = {
    timeout: 60000, // 60 seconds (OpenAI can take time)
    errorThresholdPercentage: 50, // Open circuit after 50% errors
    resetTimeout: 30000, // Try again after 30 seconds
    rollingCountTimeout: 60000, // Count errors over 60 seconds
    rollingCountBuckets: 10, // 10 buckets for error counting
    name: 'OpenAI',
    ...options,
  };

  const breaker = new CircuitBreaker(fn, defaultOptions);

  // Log circuit breaker events
  breaker.on('open', () => {
    logger.error('Circuit breaker OPEN - OpenAI API unavailable');
  });

  breaker.on('halfOpen', () => {
    logger.info('Circuit breaker HALF-OPEN - Testing OpenAI API');
  });

  breaker.on('close', () => {
    logger.info('Circuit breaker CLOSED - OpenAI API operational');
  });

  breaker.on('reject', () => {
    logger.warn('Circuit breaker REJECTED - Request rejected (circuit open)');
  });

  breaker.on('timeout', () => {
    logger.warn('Circuit breaker TIMEOUT - Request timed out');
  });

  return breaker;
}

/**
 * Create circuit breaker for Firestore operations
 */
function createFirestoreCircuitBreaker(fn, options = {}) {
  const defaultOptions = {
    timeout: 10000, // 10 seconds
    errorThresholdPercentage: 50,
    resetTimeout: 30000,
    name: 'Firestore',
    ...options,
  };

  const breaker = new CircuitBreaker(fn, defaultOptions);

  breaker.on('open', () => {
    logger.error('Circuit breaker OPEN - Firestore unavailable');
  });

  breaker.on('close', () => {
    logger.info('Circuit breaker CLOSED - Firestore operational');
  });

  return breaker;
}

module.exports = {
  createOpenAICircuitBreaker,
  createFirestoreCircuitBreaker,
};

