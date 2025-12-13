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
  onLimitReached: (req, res, options) => {
    logger.warn('Rate limit exceeded', {
      requestId: req.id || 'unknown',
      ip: req.ip,
      path: req.path,
      method: req.method,
    });
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
  onLimitReached: (req, res, options) => {
    logger.warn('Strict rate limit exceeded', {
      requestId: req.id || 'unknown',
      ip: req.ip,
      path: req.path,
      method: req.method,
    });
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
  onLimitReached: (req, res, options) => {
    logger.warn('Image processing rate limit exceeded', {
      requestId: req.id || 'unknown',
      ip: req.ip,
      path: req.path,
      method: req.method,
    });
  },
});

module.exports = {
  apiLimiter,
  strictLimiter,
  imageProcessingLimiter,
};

