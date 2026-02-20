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

module.exports = {
  apiLimiter,
  strictLimiter,
  imageProcessingLimiter,
  adminLimiter,
};

