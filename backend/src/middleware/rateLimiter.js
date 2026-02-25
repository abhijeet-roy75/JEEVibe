/**
 * Rate Limiting Middleware
 *
 * Prevents API abuse and DDoS attacks
 * Uses in-memory store (sufficient for MVP single instance)
 *
 * KEY IMPROVEMENT (2026-02-13):
 * - Rate limiting now uses userId (if authenticated) instead of just IP
 * - Prevents single account abuse across multiple devices/IPs
 * - Solves mobile NAT problem (multiple users same IP)
 */

const rateLimit = require('express-rate-limit');
const logger = require('../utils/logger');

/**
 * Get rate limit key: userId if authenticated, else IP address
 * This prevents:
 * 1. Single user abusing API from multiple devices/IPs
 * 2. Legitimate users in same network (NAT) from being grouped together
 */
const getUserKey = (req) => {
  if (req.userId) {
    return `user:${req.userId}`;
  }
  return `ip:${req.ip}`;
};

// General API rate limiter (now user-aware)
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  keyGenerator: getUserKey,
  max: (req) => {
    // Authenticated users: Higher limit (per user, not per IP)
    if (req.userId) {
      return 100;
    }
    // Anonymous/unauthenticated: Lower limit (per IP)
    return 20;
  },
  message: (req) => ({
    success: false,
    error: req.userId
      ? 'Too many requests from your account, please try again later.'
      : 'Too many requests from this IP, please try again later.',
    requestId: req.id || 'unknown',
  }),
  standardHeaders: true, // Return rate limit info in `RateLimit-*` headers
  legacyHeaders: false, // Disable `X-RateLimit-*` headers
  skipSuccessfulRequests: false,
  skipFailedRequests: false,
  handler: (req, res, next, options) => {
    logger.warn('Rate limit exceeded', {
      requestId: req.id || 'unknown',
      userId: req.userId || null,
      ip: req.ip,
      path: req.path,
      method: req.method,
      key: getUserKey(req),
    });
    // options.message is a function, call it to get the actual message object
    const message = typeof options.message === 'function' ? options.message(req) : options.message;
    res.status(options.statusCode).json(message);
  },
});

// Strict rate limiter for expensive operations (user-aware)
const strictLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  keyGenerator: getUserKey,
  max: (req) => {
    // Authenticated users: 10 per hour (per user)
    if (req.userId) {
      return 10;
    }
    // Anonymous: 5 per hour (per IP)
    return 5;
  },
  message: (req) => ({
    success: false,
    error: 'Too many requests. Please wait before trying again.',
    requestId: req.id || 'unknown',
  }),
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res, next, options) => {
    logger.warn('Strict rate limit exceeded', {
      requestId: req.id || 'unknown',
      userId: req.userId || null,
      ip: req.ip,
      path: req.path,
      method: req.method,
      key: getUserKey(req),
    });
    // options.message is a function, call it to get the actual message object
    const message = typeof options.message === 'function' ? options.message(req) : options.message;
    res.status(options.statusCode).json(message);
  },
});

// Very strict limiter for image processing (user-aware)
const imageProcessingLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  keyGenerator: getUserKey,
  max: (req) => {
    // Authenticated users: Tier-based limits handled by usageTrackingService
    // This is just a safety net to prevent extreme abuse
    if (req.userId) {
      return 50; // 50 images/hour max (even for Ultra tier)
    }
    // Anonymous: Very restrictive
    return 5;
  },
  message: (req) => ({
    success: false,
    error: 'Image processing rate limit exceeded. Please try again later.',
    requestId: req.id || 'unknown',
  }),
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res, next, options) => {
    logger.warn('Image processing rate limit exceeded', {
      requestId: req.id || 'unknown',
      userId: req.userId || null,
      ip: req.ip,
      path: req.path,
      method: req.method,
      key: getUserKey(req),
    });
    // options.message is a function, call it to get the actual message object
    const message = typeof options.message === 'function' ? options.message(req) : options.message;
    res.status(options.statusCode).json(message);
  },
});

// Admin operations rate limiter - prevent abuse of privileged endpoints
const adminLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 50, // Limit each IP to 50 admin requests per hour
  message: (req) => ({
    success: false,
    error: 'Admin operation rate limit exceeded. Please try again later.',
    code: 'ADMIN_RATE_LIMIT_EXCEEDED',
    requestId: req.id || 'unknown',
  }),
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res, next, options) => {
    logger.warn('Admin rate limit exceeded', {
      requestId: req.id || 'unknown',
      ip: req.ip,
      path: req.path,
      method: req.method,
      userId: req.userId || 'unknown',
    });
    // options.message is a function, call it to get the actual message object
    const message = typeof options.message === 'function' ? options.message(req) : options.message;
    res.status(options.statusCode).json(message);
  },
});

// Analytics rate limiter - higher limits for real-time analytics updates
// Users need to see updated analytics immediately after completing quizzes/practice
const analyticsLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  keyGenerator: getUserKey,
  max: (req) => {
    // Authenticated users: Higher limit (200 requests per 15 min)
    // This allows for ~50 page loads before hitting limit (4 calls per load reduced to 1 with batching)
    if (req.userId) {
      return 200;
    }
    // Anonymous/unauthenticated: Increased limit (100 requests per 15 min)
    // Higher than general API limiter to account for:
    // - Render.com internal health checks
    // - Session expiration with frontend still polling
    // - These requests will fail at authenticateUser middleware anyway (safe)
    return 100;
  },
  message: (req) => ({
    success: false,
    error: req.userId
      ? 'Too many analytics requests. Please try again in a moment.'
      : 'Too many requests from this IP, please try again later.',
    requestId: req.id || 'unknown',
  }),
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: false,
  skipFailedRequests: false,
  handler: (req, res, next, options) => {
    // Enhanced logging to identify source of rate limit hits
    logger.warn('Analytics rate limit exceeded', {
      requestId: req.id || 'unknown',
      userId: req.userId || null,
      ip: req.ip,
      path: req.path,
      method: req.method,
      key: getUserKey(req),
      // Additional diagnostic info
      userAgent: req.get('user-agent') || 'unknown',
      referer: req.get('referer') || 'none',
      origin: req.get('origin') || 'none',
      forwardedFor: req.get('x-forwarded-for') || 'none',
      // Help identify if it's a health check or bot
      isLikelyHealthCheck: !req.get('user-agent') || req.get('user-agent').includes('health'),
      isLikelyBot: req.get('user-agent') ? req.get('user-agent').toLowerCase().includes('bot') : false,
    });
    const message = typeof options.message === 'function' ? options.message(req) : options.message;
    res.status(options.statusCode).json(message);
  },
});

module.exports = {
  apiLimiter,
  strictLimiter,
  imageProcessingLimiter,
  adminLimiter,
  analyticsLimiter,
};

