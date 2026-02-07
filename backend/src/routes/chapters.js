/**
 * Chapter Unlock Routes
 *
 * Endpoints for the 24-month countdown timeline chapter unlock system
 */

const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { authenticateUser } = require('../middleware/auth');
const { getUnlockedChapters, isChapterUnlocked, TOTAL_TIMELINE_MONTHS } = require('../services/chapterUnlockService');
const logger = require('../utils/logger');

/**
 * GET /api/chapters/unlocked
 * Get all unlocked chapters for the authenticated user
 */
router.get('/unlocked', authenticateUser, async (req, res) => {
  try {
    const userId = req.userId;
    const result = await getUnlockedChapters(userId);

    res.json({
      success: true,
      data: {
        unlockedChapters: result.unlockedChapterKeys,
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
router.get('/:chapterKey/unlock-status', authenticateUser, async (req, res) => {
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
