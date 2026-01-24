/**
 * Auth Service - Session Management
 *
 * Manages custom session tokens for single-device enforcement.
 *
 * Key concepts:
 * - Each user can only have ONE active session at a time
 * - New login = old session invalidated immediately
 * - Session tokens are separate from Firebase Auth tokens
 *   - Firebase token: proves identity ("who are you")
 *   - Session token: controls access ("are you allowed right now")
 *
 * Why custom tokens instead of Firebase token revocation?
 * - Firebase token revocation is async (can take up to 1 hour to propagate)
 * - Custom session tokens give instant invalidation via single Firestore read
 */

const crypto = require('crypto');
const { db, admin } = require('../config/firebase');
const logger = require('../utils/logger');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');

// Session configuration
const SESSION_MAX_AGE_DAYS = 30;
const SESSION_MAX_AGE_MS = SESSION_MAX_AGE_DAYS * 24 * 60 * 60 * 1000;

// Debounce interval for last_active_at updates (5 minutes)
const LAST_ACTIVE_DEBOUNCE_MS = 5 * 60 * 1000;

/**
 * Generate a cryptographically secure session token
 * Format: sess_<64 hex characters>
 * @returns {string} Session token
 */
function generateSecureToken() {
  // 32 bytes = 64 hex characters, cryptographically secure
  return 'sess_' + crypto.randomBytes(32).toString('hex');
}

/**
 * Create a new session for a user
 * This REPLACES any existing session (single session enforcement)
 *
 * @param {string} userId - Firebase user ID
 * @param {Object} deviceInfo - Device information
 * @param {string} deviceInfo.deviceId - Unique device identifier
 * @param {string} [deviceInfo.deviceName] - Human-readable device name
 * @param {string} [deviceInfo.ipAddress] - IP address for anomaly detection
 * @returns {Promise<string>} The new session token
 */
async function createSession(userId, deviceInfo) {
  const sessionToken = generateSecureToken();

  const sessionData = {
    token: sessionToken,
    device_id: deviceInfo.deviceId,
    device_name: deviceInfo.deviceName || 'Unknown Device',
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    last_active_at: admin.firestore.FieldValue.serverTimestamp(),
    ip_address: deviceInfo.ipAddress || null
  };

  await retryFirestoreOperation(async () => {
    // This REPLACES any existing session (single session enforcement)
    await db.collection('users').doc(userId).update({
      'auth.active_session': sessionData
    });
  });

  logger.info('Session created', {
    userId,
    deviceId: deviceInfo.deviceId,
    deviceName: deviceInfo.deviceName
  });

  return sessionToken;
}

/**
 * Validate a session token for a user
 *
 * @param {string} userId - Firebase user ID
 * @param {string} sessionToken - Session token to validate
 * @returns {Promise<Object>} Validation result
 * @returns {boolean} result.valid - Whether the session is valid
 * @returns {string} [result.code] - Error code if invalid
 * @returns {string} [result.message] - Error message if invalid
 * @returns {Object} [result.session] - Session data if valid
 */
async function validateSession(userId, sessionToken) {
  const userDoc = await retryFirestoreOperation(async () => {
    return await db.collection('users').doc(userId).get();
  });

  if (!userDoc.exists) {
    return {
      valid: false,
      code: 'USER_NOT_FOUND',
      message: 'User not found'
    };
  }

  const activeSession = userDoc.data()?.auth?.active_session;

  // No active session
  if (!activeSession) {
    return {
      valid: false,
      code: 'NO_ACTIVE_SESSION',
      message: 'No active session. Please login again.'
    };
  }

  // Token mismatch (user logged in on another device)
  if (activeSession.token !== sessionToken) {
    return {
      valid: false,
      code: 'SESSION_EXPIRED',
      message: 'Session expired. You may have logged in on another device.'
    };
  }

  // Check session age (30-day expiry)
  const sessionCreatedAt = activeSession.created_at?.toDate();
  if (sessionCreatedAt && (Date.now() - sessionCreatedAt.getTime() > SESSION_MAX_AGE_MS)) {
    return {
      valid: false,
      code: 'SESSION_EXPIRED_AGE',
      message: 'Session expired. Please verify your phone number.'
    };
  }

  return {
    valid: true,
    session: activeSession
  };
}

/**
 * Update last_active_at for a session (debounced)
 * Only updates if last_active_at is older than LAST_ACTIVE_DEBOUNCE_MS
 *
 * @param {string} userId - Firebase user ID
 * @param {Object} session - Current session data
 */
async function updateLastActive(userId, session) {
  try {
    const lastActive = session.last_active_at?.toDate();
    const debounceThreshold = new Date(Date.now() - LAST_ACTIVE_DEBOUNCE_MS);

    // Only update if last_active_at is older than debounce threshold
    if (!lastActive || lastActive < debounceThreshold) {
      await db.collection('users').doc(userId).update({
        'auth.active_session.last_active_at': admin.firestore.FieldValue.serverTimestamp()
      });
    }
  } catch (error) {
    // Non-critical error, just log it
    logger.warn('Failed to update last_active_at', {
      userId,
      error: error.message
    });
  }
}

/**
 * Clear the active session for a user (logout)
 *
 * @param {string} userId - Firebase user ID
 */
async function clearSession(userId) {
  await retryFirestoreOperation(async () => {
    await db.collection('users').doc(userId).update({
      'auth.active_session': admin.firestore.FieldValue.delete()
    });
  });

  logger.info('Session cleared (logout)', { userId });
}

/**
 * Get current session info for a user
 *
 * @param {string} userId - Firebase user ID
 * @returns {Promise<Object|null>} Session info or null
 */
async function getSessionInfo(userId) {
  const userDoc = await retryFirestoreOperation(async () => {
    return await db.collection('users').doc(userId).get();
  });

  if (!userDoc.exists) {
    return null;
  }

  const activeSession = userDoc.data()?.auth?.active_session;
  if (!activeSession) {
    return null;
  }

  // Return session info without the token (for security)
  return {
    device_id: activeSession.device_id,
    device_name: activeSession.device_name,
    created_at: activeSession.created_at?.toDate?.() || activeSession.created_at,
    last_active_at: activeSession.last_active_at?.toDate?.() || activeSession.last_active_at,
    ip_address: activeSession.ip_address
  };
}

module.exports = {
  generateSecureToken,
  createSession,
  validateSession,
  updateLastActive,
  clearSession,
  getSessionInfo,
  SESSION_MAX_AGE_DAYS
};
