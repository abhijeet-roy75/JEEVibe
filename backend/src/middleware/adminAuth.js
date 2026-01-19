/**
 * Admin Authentication Middleware
 *
 * Verifies Firebase Auth tokens and checks admin allowlist
 */

const { admin, db } = require('../config/firebase');
const { v4: uuidv4 } = require('uuid');
const logger = require('../utils/logger');

// Admin allowlist - emails that have admin access
// Can also be stored in Firestore 'admins' collection for dynamic management
const ADMIN_ALLOWLIST = (process.env.ADMIN_EMAILS || '').split(',').filter(Boolean);

/**
 * Middleware to authenticate admin requests
 *
 * First verifies Firebase Auth token, then checks if email is in admin allowlist
 * Can check either environment variable or Firestore 'admins' collection
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @param {Function} next - Express next middleware
 */
async function authenticateAdmin(req, res, next) {
  const requestId = req.id || uuidv4();
  req.id = requestId;

  try {
    // Extract token from Authorization header
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      logger.warn('Admin auth failed: No token provided', {
        requestId,
        path: req.path,
        ip: req.ip,
      });
      return res.status(401).json({
        success: false,
        error: 'No authentication token provided.',
        requestId,
      });
    }

    const token = authHeader.split('Bearer ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        error: 'Invalid token format',
        requestId,
      });
    }

    // Verify token with Firebase Admin SDK
    const decodedToken = await admin.auth().verifyIdToken(token);
    const email = decodedToken.email;

    if (!email) {
      logger.warn('Admin auth failed: No email in token', {
        requestId,
        uid: decodedToken.uid,
      });
      return res.status(403).json({
        success: false,
        error: 'Admin access requires email authentication.',
        requestId,
      });
    }

    // Check if email is in admin allowlist
    let isAdmin = ADMIN_ALLOWLIST.includes(email.toLowerCase());

    // Also check Firestore admins collection for dynamic management
    if (!isAdmin) {
      try {
        const adminDoc = await db.collection('admins').doc(email.toLowerCase()).get();
        isAdmin = adminDoc.exists;
      } catch (err) {
        // Collection might not exist yet, that's okay
        logger.debug('Could not check Firestore admins collection', { error: err.message });
      }
    }

    if (!isAdmin) {
      logger.warn('Admin auth failed: Not in allowlist', {
        requestId,
        email,
        uid: decodedToken.uid,
      });
      return res.status(403).json({
        success: false,
        error: 'Access denied. You are not authorized as an admin.',
        requestId,
      });
    }

    // Set user information on request object
    req.userId = decodedToken.uid;
    req.userEmail = email;
    req.isAdmin = true;

    logger.info('Admin authenticated', {
      requestId,
      email,
      uid: decodedToken.uid,
    });

    next();
  } catch (error) {
    logger.error('Admin authentication error', {
      requestId,
      path: req.path,
      error: error.message,
      code: error.code,
    });

    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({
        success: false,
        error: 'Token has expired. Please sign in again.',
        requestId,
      });
    }

    return res.status(401).json({
      success: false,
      error: 'Authentication failed: ' + error.message,
      requestId,
    });
  }
}

module.exports = {
  authenticateAdmin,
  ADMIN_ALLOWLIST
};
