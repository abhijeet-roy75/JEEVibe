/**
 * User Profile Routes
 * 
 * API endpoints for user profile operations:
 * - GET /api/users/profile - Get user profile
 * - POST /api/users/profile - Create or update user profile
 * - GET /api/users/profile/exists - Check if profile exists
 * - PATCH /api/users/profile/last-active - Update last active timestamp
 * - PATCH /api/users/profile/complete - Mark profile as completed
 */

const express = require('express');
const { body, validationResult } = require('express-validator');
const router = express.Router();
const { db, admin } = require('../config/firebase');
const { authenticateUser } = require('../middleware/auth');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { ApiError } = require('../middleware/errorHandler');
const { CacheKeys, get: getCache, set: setCache, del: delCache } = require('../utils/cache');

/**
 * GET /api/users/profile
 * 
 * Get the authenticated user's profile
 * 
 * Authentication: Required (Bearer token in Authorization header)
 */
router.get('/profile', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    const cacheKey = CacheKeys.userProfile(userId);
    
    // Check cache first
    const cached = getCache(cacheKey);
    if (cached) {
      logger.info('User profile served from cache', {
        requestId: req.id,
        userId,
      });
      return res.json({
        success: true,
        data: cached,
        cached: true,
        requestId: req.id,
      });
    }
    
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    if (!userDoc.exists) {
      throw new ApiError(404, 'User profile not found');
    }

    const userData = userDoc.data();

    // Check if this is a valid profile (not just a partial document with auth/fcm fields)
    // A valid profile must have at least a phoneNumber
    if (!userData.phoneNumber) {
      throw new ApiError(404, 'User profile not found');
    }
    
    // Convert Firestore Timestamps to ISO strings for JSON response
    const profile = {
      uid: userId,
      ...userData,
      createdAt: userData.createdAt?.toDate?.()?.toISOString() || userData.createdAt,
      lastActive: userData.lastActive?.toDate?.()?.toISOString() || userData.lastActive,
      dateOfBirth: userData.dateOfBirth?.toDate?.()?.toISOString() || userData.dateOfBirth,
    };
    
    // Cache for 5 minutes
    setCache(cacheKey, profile, 300);
    
    logger.info('User profile fetched', {
      requestId: req.id,
      userId,
    });
    
    res.json({
      success: true,
      data: profile,
      requestId: req.id,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/users/profile
 * 
 * Create or update user profile (merge operation)
 * 
 * Authentication: Required (Bearer token in Authorization header)
 * 
 * Body: User profile object (all fields optional except uid which comes from token)
 */
router.post('/profile', 
  authenticateUser,
  [
    body('firstName').optional().isLength({ max: 100 }).trim().escape(),
    body('lastName').optional().isLength({ max: 100 }).trim().escape(),
    body('email').optional().isEmail().normalizeEmail(),
    body('phoneNumber').optional().custom((value) => {
      if (value == null || value === '') {
        return true; // Allow empty/null phoneNumber
      }
      if (!/^\+?[1-9]\d{1,14}$/.test(value)) {
        throw new Error('Invalid phone number format. Must be E.164 format (e.g., +1234567890)');
      }
      return true;
    }),
    body('targetExam').optional().isIn([
      'JEE Main',
      'JEE Main + Advanced'
    ]).withMessage('Invalid exam type. Must be "JEE Main" or "JEE Main + Advanced"'),
    body('targetYear').optional().isString().isLength({ min: 4, max: 4 }).matches(/^\d{4}$/)
      .withMessage('Target year must be a 4-digit year (e.g., 2025)'),
    body('dreamBranch').optional().isLength({ max: 100 }).trim().escape(),
    body('state').optional().isLength({ max: 100 }).trim().escape(),
    body('studySetup').optional().isArray().custom((arr) => {
      if (!Array.isArray(arr)) {
        throw new Error('studySetup must be an array');
      }
      if (arr.length > 4) {
        throw new Error('Maximum 4 study setup options allowed');
      }

      const validOptions = ['Self-study', 'Online coaching', 'Offline coaching', 'School only'];

      arr.forEach((item, index) => {
        if (typeof item !== 'string') {
          throw new Error(`studySetup[${index}] must be a string`);
        }
        if (!validOptions.includes(item)) {
          throw new Error(
            `studySetup[${index}] has invalid value "${item}". ` +
            `Must be one of: ${validOptions.join(', ')}`
          );
        }
      });

      // Check for duplicates
      const uniqueItems = new Set(arr);
      if (uniqueItems.size !== arr.length) {
        throw new Error('studySetup array contains duplicate values');
      }

      return true;
    }),
  ],
  async (req, res, next) => {
    try {
      // Check validation errors
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        throw new ApiError(400, 'Validation failed', errors.array());
      }

      const userId = req.userId;
      const profileData = req.body;
      
      // Remove uid from body if present (we use authenticated userId)
      delete profileData.uid;
    
      // Invalidate cache BEFORE saving (prevent race condition)
      delCache(CacheKeys.userProfile(userId));
    
      // Convert ISO date strings to Firestore Timestamps
      const firestoreData = { ...profileData };
      
      // Check if profile exists to determine if we should set createdAt
      const userRef = db.collection('users').doc(userId);
      const userDoc = await retryFirestoreOperation(async () => {
        return await userRef.get();
      });
      
      // Validate and convert createdAt
      if (firestoreData.createdAt) {
        const date = new Date(firestoreData.createdAt);
        if (isNaN(date.getTime())) {
          throw new ApiError(400, 'Invalid createdAt date format');
        }
        firestoreData.createdAt = admin.firestore.Timestamp.fromDate(date);
      } else if (!userDoc.exists) {
        // Set createdAt if not provided and this is a new profile
        firestoreData.createdAt = admin.firestore.FieldValue.serverTimestamp();
      }
      
      // Validate and convert lastActive
      if (firestoreData.lastActive) {
        const date = new Date(firestoreData.lastActive);
        if (isNaN(date.getTime())) {
          throw new ApiError(400, 'Invalid lastActive date format');
        }
        firestoreData.lastActive = admin.firestore.Timestamp.fromDate(date);
      } else {
        firestoreData.lastActive = admin.firestore.FieldValue.serverTimestamp();
      }
      
      // Validate and convert dateOfBirth
      if (firestoreData.dateOfBirth) {
        const date = new Date(firestoreData.dateOfBirth);
        if (isNaN(date.getTime())) {
          throw new ApiError(400, 'Invalid dateOfBirth format');
        }
        
        // Validate date is reasonable (between 5 and 120 years ago)
        const now = new Date();
        const minDate = new Date(now.getFullYear() - 120, 0, 1); // 120 years ago
        const maxDate = new Date(now.getFullYear() - 5, 11, 31); // 5 years ago (minimum age)
        
        if (date < minDate || date > maxDate) {
          throw new ApiError(400, 'dateOfBirth must be between 5 and 120 years ago');
        }
        
        firestoreData.dateOfBirth = admin.firestore.Timestamp.fromDate(date);
      }
      
      await retryFirestoreOperation(async () => {
        return await userRef.set(firestoreData, { merge: true });
      });

      // Initialize trial for new users (non-blocking)
      // Check if user doesn't have trial yet (not just if doc doesn't exist)
      const userData = userDoc.exists ? userDoc.data() : {};
      if (!userData.trial && firestoreData.phoneNumber) {
        try {
          const { initializeTrial } = require('../services/trialService');
          await initializeTrial(userId, firestoreData.phoneNumber);
        } catch (error) {
          // Don't fail signup if trial initialization fails
          logger.error('Failed to initialize trial', {
            userId,
            error: error.message,
            requestId: req.id
          });
        }
      }

      // Fetch updated profile to return
      const updatedDoc = await retryFirestoreOperation(async () => {
        return await userRef.get();
      });
      
      const updatedData = updatedDoc.data();
      const profile = {
        uid: userId,
        ...updatedData,
        createdAt: updatedData.createdAt?.toDate?.()?.toISOString() || updatedData.createdAt,
        lastActive: updatedData.lastActive?.toDate?.()?.toISOString() || updatedData.lastActive,
        dateOfBirth: updatedData.dateOfBirth?.toDate?.()?.toISOString() || updatedData.dateOfBirth,
      };
      
      logger.info('User profile saved', {
        requestId: req.id,
        userId,
      });
      
      res.json({
        success: true,
        data: profile,
        requestId: req.id,
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * GET /api/users/profile/exists
 * 
 * Check if user profile exists
 * 
 * Authentication: Required (Bearer token in Authorization header)
 */
router.get('/profile/exists', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;

    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    // Check if this is a valid profile (not just a partial document with auth/fcm fields)
    // A valid profile must have at least a phoneNumber
    const exists = userDoc.exists && userDoc.data()?.phoneNumber;

    res.json({
      success: true,
      exists: !!exists,
      requestId: req.id,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PATCH /api/users/profile/last-active
 * 
 * Update last active timestamp
 * 
 * Authentication: Required (Bearer token in Authorization header)
 */
router.patch('/profile/last-active', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    
    const userRef = db.collection('users').doc(userId);
    await retryFirestoreOperation(async () => {
      return await userRef.update({
        lastActive: admin.firestore.FieldValue.serverTimestamp()
      });
    });
    
    // Invalidate cache
    delCache(CacheKeys.userProfile(userId));
    
    res.json({
      success: true,
      message: 'Last active timestamp updated',
      requestId: req.id,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/users/fcm-token
 *
 * Save or clear FCM token for push notifications
 *
 * Request body: { fcm_token: string | null }
 * Authentication: Required (Bearer token in Authorization header)
 */
router.post('/fcm-token', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { fcm_token } = req.body;

    const userRef = db.collection('users').doc(userId);
    await retryFirestoreOperation(async () => {
      return await userRef.update({
        fcm_token: fcm_token || admin.firestore.FieldValue.delete(),
        fcm_token_updated_at: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    // Invalidate cache
    delCache(CacheKeys.userProfile(userId));

    logger.info('FCM token updated', {
      requestId: req.id,
      userId,
      hasToken: !!fcm_token
    });

    res.json({
      success: true,
      message: fcm_token ? 'FCM token saved' : 'FCM token cleared',
      requestId: req.id,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PATCH /api/users/profile/complete
 *
 * Mark profile as completed
 *
 * Authentication: Required (Bearer token in Authorization header)
 */
router.patch('/profile/complete', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    
    const userRef = db.collection('users').doc(userId);
    await retryFirestoreOperation(async () => {
      return await userRef.update({
        profileCompleted: true
      });
    });
    
    // Invalidate cache
    delCache(CacheKeys.userProfile(userId));
    
    logger.info('Profile marked as completed', {
      requestId: req.id,
      userId,
    });
    
    res.json({
      success: true,
      message: 'Profile marked as completed',
      requestId: req.id,
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;

