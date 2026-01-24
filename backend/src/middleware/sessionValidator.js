/**
 * Session Validation Middleware
 *
 * Validates custom session tokens for single-device enforcement.
 *
 * This middleware should be used AFTER authenticateUser middleware.
 * It checks that the request has a valid session token (x-session-token header)
 * that matches the user's active session in Firestore.
 *
 * Error codes returned:
 * - SESSION_TOKEN_MISSING: No x-session-token header provided
 * - SESSION_EXPIRED: Token doesn't match active session (logged in on another device)
 * - SESSION_EXPIRED_AGE: Session older than 30 days
 * - NO_ACTIVE_SESSION: User has no active session
 */

const logger = require('../utils/logger');
const { validateSession, updateLastActive } = require('../services/authService');

/**
 * Middleware to validate session tokens
 *
 * Expects:
 * - req.userId to be set (from authenticateUser middleware)
 * - x-session-token header with valid session token
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @param {Function} next - Express next middleware
 */
async function validateSessionMiddleware(req, res, next) {
  const requestId = req.id;
  const userId = req.userId;

  // userId should be set by authenticateUser middleware
  if (!userId) {
    logger.error('Session validation called without userId', { requestId });
    return res.status(500).json({
      success: false,
      error: 'Internal error: user not authenticated',
      requestId
    });
  }

  // Extract session token from header
  const sessionToken = req.headers['x-session-token'];

  if (!sessionToken) {
    logger.warn('Session validation failed: no token', {
      requestId,
      userId,
      path: req.path
    });
    return res.status(401).json({
      success: false,
      error: 'Session token required',
      code: 'SESSION_TOKEN_MISSING',
      action: 'FORCE_LOGOUT',
      requestId
    });
  }

  try {
    // Validate the session token
    const result = await validateSession(userId, sessionToken);

    if (!result.valid) {
      logger.warn('Session validation failed', {
        requestId,
        userId,
        code: result.code,
        path: req.path
      });

      // Determine the appropriate action for the client
      let action = 'FORCE_LOGOUT';
      if (result.code === 'SESSION_EXPIRED_AGE') {
        action = 'REQUIRE_OTP';
      }

      return res.status(401).json({
        success: false,
        error: result.message,
        code: result.code,
        action,
        requestId
      });
    }

    // Session is valid - update last_active_at (debounced, non-blocking)
    updateLastActive(userId, result.session).catch(err => {
      logger.warn('Failed to update last_active_at', {
        userId,
        error: err.message
      });
    });

    // Attach session info to request for downstream use
    req.sessionInfo = result.session;

    next();
  } catch (error) {
    logger.error('Session validation error', {
      requestId,
      userId,
      error: error.message,
      stack: error.stack
    });

    return res.status(500).json({
      success: false,
      error: 'Session validation failed',
      requestId
    });
  }
}

/**
 * Optional session validation middleware
 *
 * Like validateSessionMiddleware but doesn't reject requests without session tokens.
 * Useful for endpoints that should work with or without sessions.
 *
 * If a session token is provided and valid, attaches session info to req.sessionInfo.
 * If no token or invalid token, simply continues without session info.
 */
async function optionalSessionMiddleware(req, res, next) {
  const userId = req.userId;
  const sessionToken = req.headers['x-session-token'];

  // No token provided - continue without session
  if (!sessionToken || !userId) {
    return next();
  }

  try {
    const result = await validateSession(userId, sessionToken);

    if (result.valid) {
      req.sessionInfo = result.session;
      // Update last_active_at (debounced, non-blocking)
      updateLastActive(userId, result.session).catch(() => {});
    }
  } catch (error) {
    // Log but don't fail - this is optional validation
    logger.warn('Optional session validation error', {
      userId,
      error: error.message
    });
  }

  next();
}

module.exports = {
  validateSessionMiddleware,
  optionalSessionMiddleware
};
