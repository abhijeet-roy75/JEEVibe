/**
 * Teacher Authentication Middleware
 *
 * Verifies Firebase Auth tokens and checks teacher allowlist in Firestore
 * Follows same pattern as adminAuth.js
 */

const { admin, db } = require('../config/firebase');
const { v4: uuidv4 } = require('uuid');
const logger = require('../utils/logger');

/**
 * Middleware to authenticate teacher requests
 *
 * First verifies Firebase Auth token, then checks if email exists in teachers collection
 * and that the teacher account is active
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @param {Function} next - Express next middleware
 */
async function authenticateTeacher(req, res, next) {
  const requestId = req.id || uuidv4();
  req.id = requestId;

  try {
    // Extract token from Authorization header
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      logger.warn('Teacher auth failed: No token provided', {
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
      logger.warn('Teacher auth failed: No email in token', {
        requestId,
        uid: decodedToken.uid,
      });
      return res.status(403).json({
        success: false,
        error: 'Teacher access requires email authentication.',
        requestId,
      });
    }

    // Check if email exists in teachers collection
    let teacherDoc = null;
    try {
      const teachersSnapshot = await db.collection('teachers')
        .where('email', '==', email.toLowerCase())
        .limit(1)
        .get();

      if (!teachersSnapshot.empty) {
        teacherDoc = teachersSnapshot.docs[0];
      }
    } catch (err) {
      logger.error('Error querying teachers collection', {
        requestId,
        error: err.message
      });
      return res.status(500).json({
        success: false,
        error: 'Error verifying teacher status',
        requestId,
      });
    }

    if (!teacherDoc) {
      logger.warn('Teacher auth failed: Not in teachers collection', {
        requestId,
        email,
        uid: decodedToken.uid,
      });
      return res.status(403).json({
        success: false,
        error: 'Access denied. You are not authorized as a teacher.',
        requestId,
      });
    }

    const teacherData = teacherDoc.data();

    // Check if teacher account is active
    if (!teacherData.is_active) {
      logger.warn('Teacher auth failed: Account inactive', {
        requestId,
        email,
        teacherId: teacherDoc.id,
      });
      return res.status(403).json({
        success: false,
        error: 'Your teacher account has been deactivated. Please contact support.',
        requestId,
      });
    }

    // Set teacher information on request object
    req.userId = decodedToken.uid;
    req.teacherId = teacherDoc.id;
    req.teacherEmail = email;
    req.isTeacher = true;
    req.teacherData = teacherData;

    logger.info('Teacher authenticated', {
      requestId,
      email,
      teacherId: teacherDoc.id,
      uid: decodedToken.uid,
    });

    next();
  } catch (error) {
    logger.error('Teacher authentication error', {
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
  authenticateTeacher
};
