/**
 * Authentication Middleware
 * 
 * Verifies Firebase Auth tokens and extracts user information
 */

const { admin } = require('../config/firebase');

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
  try {
    // Extract token from Authorization header
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'No authentication token provided. Include "Authorization: Bearer <token>" header.'
      });
    }
    
    const token = authHeader.split('Bearer ')[1];
    
    if (!token) {
      return res.status(401).json({
        success: false,
        error: 'Invalid token format'
      });
    }
    
    // Verify token with Firebase Admin SDK
    const decodedToken = await admin.auth().verifyIdToken(token);
    
    // Set user information on request object
    req.userId = decodedToken.uid;
    req.userEmail = decodedToken.email;
    req.userClaims = decodedToken;
    
    next();
  } catch (error) {
    console.error('Authentication error:', error.message);
    
    // Handle specific Firebase Auth errors
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({
        success: false,
        error: 'Token has expired. Please sign in again.'
      });
    }
    
    if (error.code === 'auth/id-token-revoked' || error.code === 'auth/argument-error') {
      return res.status(401).json({
        success: false,
        error: 'Invalid or revoked token. Please sign in again.'
      });
    }
    
    return res.status(401).json({
      success: false,
      error: 'Authentication failed: ' + error.message
    });
  }
}

module.exports = {
  authenticateUser
};
