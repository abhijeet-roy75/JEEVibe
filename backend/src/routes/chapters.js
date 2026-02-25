/**
 * Chapter Unlock Routes
 *
 * Endpoints for the 24-month countdown timeline chapter unlock system
 */

const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { authenticateUser } = require('../middleware/auth');
const { validateSessionMiddleware } = require('../middleware/sessionValidator');
const { getUnlockedChapters, isChapterUnlocked, getFullChapterOrder, TOTAL_TIMELINE_MONTHS } = require('../services/chapterUnlockService');
const logger = require('../utils/logger');

/**
 * GET /api/chapters/unlocked
 * Get all unlocked chapters for the authenticated user
 */
router.get('/unlocked', authenticateUser, validateSessionMiddleware, async (req, res) => {
  try {
    const userId = req.userId;
    const result = await getUnlockedChapters(userId);
    const fullChapterOrder = await getFullChapterOrder();

    res.json({
      success: true,
      data: {
        unlockedChapters: result.unlockedChapterKeys,
        chapterUnlockOrder: result.chapterUnlockOrder || [],
        fullChapterOrder, // All chapters in unlock order (months 1-24)
        currentMonth: result.currentMonth,
        monthsUntilExam: result.monthsUntilExam,
        totalMonths: TOTAL_TIMELINE_MONTHS,
        isPostExam: result.isPostExam,
        examSession: result.examSession,
        usingHighWaterMark: result.usingHighWaterMark || false,
        isLegacyUser: result.isLegacyUser || false
      }
    });
  } catch (error) {
    logger.error('Error getting unlocked chapters', { error: error.message, userId: req.userId });
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/chapters/:chapterKey/unlock-status
 * Check if a specific chapter is unlocked
 */
router.get('/:chapterKey/unlock-status', authenticateUser, validateSessionMiddleware, async (req, res) => {
  try {
    const userId = req.userId;
    const { chapterKey } = req.params;

    const unlocked = await isChapterUnlocked(userId, chapterKey);

    res.json({
      success: true,
      data: {
        chapterKey,
        unlocked
      }
    });
  } catch (error) {
    logger.error('Error checking chapter unlock status', {
      error: error.message,
      userId: req.userId,
      chapterKey: req.params.chapterKey
    });
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
