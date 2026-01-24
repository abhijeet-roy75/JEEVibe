/**
 * Auth Routes - Session Management
 *
 * API endpoints for session management:
 * - POST /api/auth/session - Create a new session (after OTP verification)
 * - GET /api/auth/session - Get current session info
 * - POST /api/auth/logout - Clear active session
 *
 * Future (P1 - Device Limits):
 * - GET /api/auth/devices - List registered devices
 * - DELETE /api/auth/devices/:deviceId - Remove a device
 */

const express = require('express');
const router = express.Router();
const { authenticateUser } = require('../middleware/auth');
const logger = require('../utils/logger');
const {
  createSession,
  clearSession,
  getSessionInfo
} = require('../services/authService');

// ============================================================================
// SESSION MANAGEMENT
// ============================================================================

/**
 * POST /api/auth/session
 *
 * Create a new session for the authenticated user.
 * This should be called after successful OTP verification.
 *
 * Any existing session will be invalidated (single session enforcement).
 *
 * Request body:
 * - deviceId: string (required) - Unique device identifier
 * - deviceName: string (optional) - Human-readable device name
 *
 * Authentication: Required (Firebase token)
 *
 * Returns:
 * - sessionToken: The new session token to store and send with future requests
 */
router.post('/session', authenticateUser, async (req, res, next) => {
  const requestId = req.id;
  const userId = req.userId;

  try {
    const { deviceId, deviceName } = req.body;

    // Validate required fields
    if (!deviceId) {
      return res.status(400).json({
        success: false,
        error: 'deviceId is required',
        requestId
      });
    }

    // Get IP address for anomaly detection
    const ipAddress = req.ip || req.headers['x-forwarded-for'] || null;

    // Create the session (this invalidates any existing session)
    const sessionToken = await createSession(userId, {
      deviceId,
      deviceName,
      ipAddress
    });

    logger.info('Session created via API', {
      requestId,
      userId,
      deviceId,
      deviceName
    });

    res.json({
      success: true,
      data: {
        sessionToken,
        message: 'Session created successfully'
      },
      requestId
    });
  } catch (error) {
    logger.error('Error creating session', {
      requestId,
      userId,
      error: error.message,
      stack: error.stack
    });

    // Check for specific Firestore errors
    if (error.code === 5 || error.message?.includes('NOT_FOUND')) {
      return res.status(404).json({
        success: false,
        error: 'User profile not found. Please complete signup first.',
        requestId
      });
    }

    next(error);
  }
});

/**
 * GET /api/auth/session
 *
 * Get current session info for the authenticated user.
 * Does NOT require session token (useful for checking if session exists).
 *
 * Authentication: Required (Firebase token)
 *
 * Returns session info without the token (for security):
 * - device_id: Device identifier
 * - device_name: Human-readable device name
 * - created_at: When session was created
 * - last_active_at: Last API activity
 */
router.get('/session', authenticateUser, async (req, res, next) => {
  const requestId = req.id;
  const userId = req.userId;

  try {
    const sessionInfo = await getSessionInfo(userId);

    if (!sessionInfo) {
      return res.status(404).json({
        success: false,
        error: 'No active session found',
        code: 'NO_ACTIVE_SESSION',
        requestId
      });
    }

    res.json({
      success: true,
      data: {
        session: sessionInfo
      },
      requestId
    });
  } catch (error) {
    logger.error('Error getting session info', {
      requestId,
      userId,
      error: error.message
    });
    next(error);
  }
});

/**
 * POST /api/auth/logout
 *
 * Clear the active session for the authenticated user.
 * This should be called when the user explicitly signs out.
 *
 * Authentication: Required (Firebase token)
 * Note: Does NOT require valid session token (user may be logging out after being kicked)
 */
router.post('/logout', authenticateUser, async (req, res, next) => {
  const requestId = req.id;
  const userId = req.userId;

  try {
    await clearSession(userId);

    logger.info('User logged out', {
      requestId,
      userId
    });

    res.json({
      success: true,
      message: 'Logged out successfully',
      requestId
    });
  } catch (error) {
    logger.error('Error during logout', {
      requestId,
      userId,
      error: error.message
    });

    // Even if clearing fails, we should return success to the client
    // so they can proceed with local cleanup
    res.json({
      success: true,
      message: 'Logged out (with warning)',
      warning: 'Session may not have been fully cleared on server',
      requestId
    });
  }
});

// ============================================================================
// DEVICE MANAGEMENT (P1 - Future Implementation)
// ============================================================================

/**
 * GET /api/auth/devices
 *
 * List all registered devices for the user.
 * TODO: Implement in P1 phase
 */
router.get('/devices', authenticateUser, async (req, res) => {
  res.status(501).json({
    success: false,
    error: 'Device management not yet implemented',
    message: 'This feature will be available in a future update'
  });
});

/**
 * DELETE /api/auth/devices/:deviceId
 *
 * Remove a registered device.
 * TODO: Implement in P1 phase
 */
router.delete('/devices/:deviceId', authenticateUser, async (req, res) => {
  res.status(501).json({
    success: false,
    error: 'Device management not yet implemented',
    message: 'This feature will be available in a future update'
  });
});

module.exports = router;
