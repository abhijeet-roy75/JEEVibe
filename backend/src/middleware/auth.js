/**
 * Authentication Middleware
 * 
 * Verifies Firebase Auth tokens and extracts user information
 */

const { admin } = require('../config/firebase');
const { v4: uuidv4 } = require('uuid');
const logger = require('../utils/logger');
const Sentry = require('@sentry/node');

/**
 * Middleware to authenticate requests using Firebase Auth tokens
 * 
 * Expects: Authorization header with "Bearer <token>"
 * Sets: req.userId (from decoded token)
 * 
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @param {Function} next - Express next middleware
 */
async function authenticateUser(req, res, next) {
  // Ensure requestId exists (generate if not set by requestId middleware)
  const requestId = req.id || uuidv4();
  req.id = requestId;
  
  try {
    // Extract token from Authorization header
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      logger.warn('Authentication failed: No token provided', {
        requestId,
        path: req.path,
        ip: req.ip,
      });
      return res.status(401).json({
        success: false,
        error: 'No authentication token provided. Include "Authorization: Bearer <token>" header.',
        requestId,
        _debug: { source: 'auth_middleware_no_token', headers: Object.keys(req.headers) }
      });
    }
    
    const token = authHeader.split('Bearer ')[1];
    
    if (!token) {
      logger.warn('Authentication failed: Invalid token format', {
        requestId,
        path: req.path,
      });
      return res.status(401).json({
        success: false,
        error: 'Invalid token format',
        requestId,
      });
    }
    
    // Verify token with Firebase Admin SDK
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

    next();
  } catch (error) {
    logger.error('Authentication error', {
      requestId,
      path: req.path,
      error: error.message,
      code: error.code,
    });
    
    // Handle specific Firebase Auth errors
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({
        success: false,
        error: 'Token has expired. Please sign in again.',
        requestId,
        _debug: { source: 'auth_middleware_token_expired' }
      });
    }

    if (error.code === 'auth/id-token-revoked' || error.code === 'auth/argument-error') {
      return res.status(401).json({
        success: false,
        error: 'Invalid or revoked token. Please sign in again.',
        requestId,
        _debug: { source: 'auth_middleware_token_revoked' }
      });
    }

    return res.status(401).json({
      success: false,
      error: 'Authentication failed: ' + error.message,
      requestId,
      _debug: { source: 'auth_middleware_error', errorCode: error.code }
    });
  }
}

module.exports = {
  authenticateUser
};
