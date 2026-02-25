/**
 * Conditional Authentication Middleware
 *
 * Attempts to authenticate requests but doesn't block unauthenticated ones.
 * Sets req.userId if a valid token is present, otherwise leaves it undefined.
 *
 * PURPOSE: Used BEFORE rate limiting to enable user-based rate limits while
 * still allowing unauthenticated requests to proceed (they'll be blocked later
 * by authenticateUser middleware on protected routes).
 *
 * IMPORTANT: This runs BEFORE rate limiting, so rate limiter can access req.userId
 */

const { admin } = require('../config/firebase');
const logger = require('../utils/logger');
const Sentry = require('@sentry/node');

/**
 * Exempt routes that should NOT attempt authentication
 * These are public endpoints or system endpoints that don't use auth
 */
const EXEMPT_ROUTES = [
  '/api/health',           // Health check (monitoring)
  '/api/cron/',            // Scheduled tasks (system)
  '/api/share/',           // Public share links (no auth)
  '/api/auth/session',     // Session creation (auth happens here)
];

/**
 * Check if a route is exempt from authentication
 */
function isExemptRoute(path) {
  return EXEMPT_ROUTES.some(exemptPath => {
    if (exemptPath.endsWith('/')) {
      return path.startsWith(exemptPath);
    }
    return path === exemptPath;
  });
}

/**
 * Conditional authentication middleware
 *
 * Behavior:
 * - If route is exempt → skip authentication, continue
 * - If Authorization header present → verify token, set req.userId if valid
 * - If no header or invalid token → log (don't block), continue
 * - Protected routes will be blocked later by authenticateUser middleware
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @param {Function} next - Express next middleware
 */
async function conditionalAuth(req, res, next) {
  // Skip exempt routes
  if (isExemptRoute(req.path)) {
    return next();
  }

  try {
    // Extract token from Authorization header
    const authHeader = req.headers.authorization;

    // No token present - continue without authentication
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next();
    }

    const token = authHeader.split('Bearer ')[1];

    // Empty token - continue without authentication
    if (!token) {
      return next();
    }

    // Attempt to verify token
    try {
      const decodedToken = await admin.auth().verifyIdToken(token);

      // Set user information on request object
      req.userId = decodedToken.uid;
      req.userEmail = decodedToken.email;
      req.userClaims = decodedToken;

      // Set Sentry user context for error tracking
      if (process.env.SENTRY_DSN) {
        Sentry.setUser({
          id: decodedToken.uid,
          email: decodedToken.email,
        });
      }

      // Log successful authentication (debug level, not info)
      logger.debug('Conditional auth succeeded', {
        requestId: req.id,
        userId: req.userId,
        path: req.path,
      });

      return next();
    } catch (tokenError) {
      // Token verification failed - log but continue
      // The request will be blocked later by authenticateUser if route is protected
      logger.debug('Conditional auth failed - invalid token', {
        requestId: req.id,
        path: req.path,
        error: tokenError.code || tokenError.message,
      });

      return next();
    }
  } catch (error) {
    // Unexpected error in conditional auth - log and continue
    logger.error('Conditional auth unexpected error', {
      requestId: req.id,
      path: req.path,
      error: error.message,
    });

    return next();
  }
}

module.exports = {
  conditionalAuth,
  isExemptRoute,
  EXEMPT_ROUTES,
};
