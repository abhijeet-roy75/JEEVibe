/**
 * Rate Limiting Middleware
 * 
 * Prevents API abuse and DDoS attacks
 * Uses in-memory store (sufficient for MVP single instance)
 */

const rateLimit = require('express-rate-limit');
const logger = require('../utils/logger');

// General API rate limiter
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: (req) => ({
    success: false,
    error: 'Too many requests from this IP, please try again later.',
    requestId: req.id || 'unknown',
  }),
  standardHeaders: true, // Return rate limit info in `RateLimit-*` headers
  legacyHeaders: false, // Disable `X-RateLimit-*` headers
  skipSuccessfulRequests: false,
  skipFailedRequests: false,
  handler: (req, res, next, options) => {
    logger.warn('Rate limit exceeded', {
      requestId: req.id || 'unknown',
      ip: req.ip,
      path: req.path,
      method: req.method,
    });
    res.status(options.statusCode).send(options.message);
  },
});

// Strict rate limiter for expensive operations
const strictLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 10, // Limit each IP to 10 requests per hour
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
      ip: req.ip,
      path: req.path,
      method: req.method,
    });
    res.status(options.statusCode).send(options.message);
  },
});

// Very strict limiter for image processing
const imageProcessingLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 20, // Limit each IP to 20 image processing requests per hour
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
      ip: req.ip,
      path: req.path,
      method: req.method,
    });
    res.status(options.statusCode).send(options.message);
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
    res.status(options.statusCode).send(options.message);
  },
});

module.exports = {
  apiLimiter,
  strictLimiter,
  imageProcessingLimiter,
  adminLimiter,
};

