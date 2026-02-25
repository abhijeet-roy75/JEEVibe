/**
 * Snap History & Limits API Routes
 */

const express = require('express');
const { authenticateUser } = require('../middleware/auth');
const { validateSessionMiddleware } = require('../middleware/sessionValidator');
const { getDailyUsage, getSnapHistory } = require('../services/snapHistoryService');
const { getEffectiveTier } = require('../services/subscriptionService');
const { getTierLimits } = require('../services/tierConfigService');
const logger = require('../utils/logger');

const router = express.Router();

/**
 * GET /api/snap-limit
 * Returns user's daily snap usage and limit
 */
router.get('/snap-limit', authenticateUser, validateSessionMiddleware, async (req, res, next) => {
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
 * History is limited based on tier: Free=7 days, Pro=30 days, Ultra=unlimited
 */
router.get('/snap-history', authenticateUser, validateSessionMiddleware, async (req, res, next) => {
    try {
        const userId = req.userId;
        const limit = parseInt(req.query.limit) || 20;
        const lastDocId = req.query.lastDocId;

        // Get user's tier to determine history limit
        const tierInfo = await getEffectiveTier(userId);
        const tierLimits = await getTierLimits(tierInfo.tier);
        const historyDays = tierLimits.solution_history_days || 7; // Default to 7 days

        logger.info('Fetching snap history with tier limit', {
            userId,
            tier: tierInfo.tier,
            historyDays: historyDays === -1 ? 'unlimited' : historyDays
        });

        const history = await getSnapHistory(userId, limit, lastDocId, historyDays);

        res.json({
            success: true,
            data: {
                history,
                hasMore: history.length === limit,
                history_limit_days: historyDays === -1 ? null : historyDays,
                tier: tierInfo.tier
            }
        });
    } catch (error) {
        logger.error('Error in /snap-history:', { userId: req.userId, error: error.message });
        next(error);
    }
});

module.exports = router;
