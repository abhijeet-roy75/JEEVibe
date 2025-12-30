/**
 * Snap History & Limits API Routes
 */

const express = require('express');
const { authenticateUser } = require('../middleware/auth');
const { getDailyUsage, getSnapHistory } = require('../services/snapHistoryService');
const logger = require('../utils/logger');

const router = express.Router();

/**
 * GET /api/snap-limit
 * Returns user's daily snap usage and limit
 */
router.get('/snap-limit', authenticateUser, async (req, res, next) => {
    try {
        const userId = req.userId;
        const usage = await getDailyUsage(userId);

        res.json({
            success: true,
            data: usage
        });
    } catch (error) {
        logger.error('Error in /snap-limit:', { userId: req.userId, error: error.message });
        next(error);
    }
});

/**
 * GET /api/snap-history
 * Returns user's snap history with pagination
 */
router.get('/snap-history', authenticateUser, async (req, res, next) => {
    try {
        const userId = req.userId;
        const limit = parseInt(req.query.limit) || 20;
        const lastDocId = req.query.lastDocId;

        const history = await getSnapHistory(userId, limit, lastDocId);

        res.json({
            success: true,
            data: {
                history,
                hasMore: history.length === limit
            }
        });
    } catch (error) {
        logger.error('Error in /snap-history:', { userId: req.userId, error: error.message });
        next(error);
    }
});

module.exports = router;
