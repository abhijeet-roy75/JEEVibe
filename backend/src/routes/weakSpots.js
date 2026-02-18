/**
 * Weak Spots Routes (Cognitive Mastery)
 *
 * - GET  /api/capsules/:capsuleId         - Fetch capsule content for display
 * - POST /api/weak-spots/retrieval        - Submit retrieval answers, update node score
 * - GET  /api/weak-spots/:userId          - List weak spots for dashboard
 * - POST /api/weak-spots/events           - Log mobile engagement events (capsule opened, etc.)
 *
 * NOTE: detectWeakSpots is NOT an HTTP endpoint.
 * It runs as an internal function call inside POST /api/chapter-practice/complete.
 */

const express = require('express');
const router = express.Router();
const { db } = require('../config/firebase');
const { authenticateUser } = require('../middleware/auth');
const logger = require('../utils/logger');
const { ApiError } = require('../middleware/errorHandler');
const { body, param, query, validationResult } = require('express-validator');

const {
  evaluateRetrieval,
  getUserWeakSpots,
  logEngagementEvent,
} = require('../services/weakSpotScoringService');

// ============================================================================
// GET /api/capsules/:capsuleId
// ============================================================================

router.get('/capsules/:capsuleId',
  authenticateUser,
  async (req, res, next) => {
    try {
      const { capsuleId } = req.params;

      const doc = await db.collection('capsules').doc(capsuleId).get();
      if (!doc.exists) {
        return next(new ApiError(404, 'Capsule not found'));
      }

      const data = doc.data();

      // Fetch retrieval questions from the pool
      let retrievalQuestions = [];
      if (data.pool_id) {
        const poolDoc = await db.collection('retrieval_pools').doc(data.pool_id).get();
        if (poolDoc.exists) {
          const poolData = poolDoc.data();
          const questionIds = poolData.question_ids || [];
          if (questionIds.length > 0) {
            const qDocs = await Promise.all(
              questionIds.map(qId => db.collection('retrieval_questions').doc(qId).get())
            );
            retrievalQuestions = qDocs
              .filter(d => d.exists)
              .map(d => ({ questionId: d.id, ...d.data() }));
          }
        }
      }

      return res.json({
        success: true,
        data: {
          capsule: {
            capsuleId: doc.id,
            nodeId: data.atlas_node_id,
            nodeName: data.node_name,
            coreMisconception: data.core_misconception,
            structuralRule: data.structural_rule,
            illustrativeExample: data.illustrative_example,
            estimatedReadTime: data.estimated_read_time || 90,
            poolId: data.pool_id,
          },
          retrievalQuestions,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// ============================================================================
// POST /api/weak-spots/retrieval
// ============================================================================

const retrievalValidation = [
  body('userId').notEmpty().withMessage('userId is required'),
  body('nodeId').notEmpty().withMessage('nodeId is required'),
  body('responses').isArray({ min: 1 }).withMessage('responses must be a non-empty array'),
  body('responses.*.questionId').notEmpty().withMessage('Each response needs questionId'),
  body('responses.*.isCorrect').isBoolean().withMessage('Each response needs isCorrect boolean'),
];

router.post('/weak-spots/retrieval',
  authenticateUser,
  retrievalValidation,
  async (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return next(new ApiError(400, errors.array()[0].msg));
    }

    try {
      const { userId, nodeId, responses } = req.body;

      // Auth check: user can only submit their own retrievals
      if (userId !== req.userId) {
        return next(new ApiError(403, 'Forbidden'));
      }

      // Load atlas node for thresholds
      const nodeDoc = await db.collection('atlas_nodes').doc(nodeId).get();
      if (!nodeDoc.exists) {
        return next(new ApiError(404, `Atlas node not found: ${nodeId}`));
      }
      const atlasNode = { atlas_node_id: nodeDoc.id, ...nodeDoc.data() };

      const result = await evaluateRetrieval(userId, nodeId, responses, atlasNode);

      logger.info(`Retrieval completed: user=${userId} node=${nodeId} passed=${result.passed} score=${result.newScore}`);

      return res.json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }
);

// ============================================================================
// GET /api/weak-spots/:userId
// ============================================================================

router.get('/weak-spots/:userId',
  authenticateUser,
  [
    param('userId').notEmpty(),
    query('nodeState').optional().isIn(['active', 'improving', 'stable']),
    query('limit').optional().isInt({ min: 1, max: 50 }),
  ],
  async (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return next(new ApiError(400, errors.array()[0].msg));
    }

    try {
      const { userId } = req.params;

      // Auth check: user can only read their own weak spots
      if (userId !== req.userId) {
        return next(new ApiError(403, 'Forbidden'));
      }

      const options = {
        nodeState: req.query.nodeState || null,
        limit: parseInt(req.query.limit, 10) || 10,
      };

      const weakSpots = await getUserWeakSpots(userId, options);

      return res.json({
        success: true,
        data: {
          weakSpots,
          totalCount: weakSpots.length,
        },
      });
    } catch (err) {
      next(err);
    }
  }
);

// ============================================================================
// POST /api/weak-spots/events
// ============================================================================

const eventsValidation = [
  body('nodeId').notEmpty().withMessage('nodeId is required'),
  body('eventType').notEmpty().withMessage('eventType is required'),
  body('capsuleId').optional(),
];

router.post('/weak-spots/events',
  authenticateUser,
  eventsValidation,
  async (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return next(new ApiError(400, errors.array()[0].msg));
    }

    try {
      const { nodeId, eventType, capsuleId } = req.body;
      const userId = req.userId;

      await logEngagementEvent(userId, nodeId, eventType, capsuleId);

      return res.json({ success: true });
    } catch (err) {
      if (err.message.startsWith('Invalid eventType')) {
        return next(new ApiError(400, err.message));
      }
      next(err);
    }
  }
);

module.exports = router;
