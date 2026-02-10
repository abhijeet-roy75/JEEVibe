/**
 * Unlock Quiz API Routes
 *
 * Endpoints for chapter unlock quiz feature
 */

const express = require('express');
const router = express.Router();
const { authenticateUser } = require('../middleware/auth');
const {
  generateUnlockQuiz,
  submitUnlockQuizAnswer,
  completeUnlockQuiz,
  getUnlockQuizSession
} = require('../services/unlockQuizService');
const logger = require('../utils/logger');

/**
 * POST /api/unlock-quiz/generate
 *
 * Generate a new unlock quiz session for a locked chapter
 *
 * Request body:
 *   - chapterKey: string (required)
 *
 * Response:
 *   - sessionId: string
 *   - chapterKey: string
 *   - chapterName: string
 *   - subject: string
 *   - questions: Array of 5 questions (sanitized, no correct_answer)
 */
router.post('/generate', authenticateUser, async (req, res) => {
  try {
    const { chapterKey } = req.body;
    const userId = req.user.uid;

    if (!chapterKey) {
      return res.status(400).json({
        success: false,
        error: 'chapterKey is required'
      });
    }

    const result = await generateUnlockQuiz(userId, chapterKey);

    res.json({
      success: true,
      data: result
    });

  } catch (error) {
    logger.error('POST /api/unlock-quiz/generate error:', {
      userId: req.user?.uid,
      error: error.message
    });

    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/unlock-quiz/submit-answer
 *
 * Submit answer to a question (no theta updates)
 *
 * Request body:
 *   - sessionId: string (required)
 *   - questionId: string (required)
 *   - selectedOption: string (required) - A/B/C/D/E
 *   - timeTakenSeconds: number (optional)
 *
 * Response:
 *   - isCorrect: boolean
 *   - studentAnswer: string
 *   - correctAnswer: string
 *   - correctAnswerText: string
 *   - solutionText: string
 *   - solutionSteps: Array
 *   - keyInsight: string
 *   - distractorAnalysis: Object
 *   - commonMistakes: Array
 */
router.post('/submit-answer', authenticateUser, async (req, res) => {
  try {
    const { sessionId, questionId, selectedOption, timeTakenSeconds } = req.body;
    const userId = req.user.uid;

    if (!sessionId || !questionId || !selectedOption) {
      return res.status(400).json({
        success: false,
        error: 'sessionId, questionId, and selectedOption are required'
      });
    }

    const result = await submitUnlockQuizAnswer(
      userId,
      sessionId,
      questionId,
      selectedOption,
      timeTakenSeconds || 0
    );

    res.json({
      success: true,
      data: result
    });

  } catch (error) {
    logger.error('POST /api/unlock-quiz/submit-answer error:', {
      userId: req.user?.uid,
      error: error.message
    });

    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/unlock-quiz/complete
 *
 * Complete unlock quiz
 * - Check if passed (3+ correct)
 * - If passed: unlock chapter
 * - Update user stats
 *
 * Request body:
 *   - sessionId: string (required)
 *
 * Response:
 *   - sessionId: string
 *   - chapterKey: string
 *   - chapterName: string
 *   - subject: string
 *   - totalQuestions: number
 *   - correctCount: number
 *   - passed: boolean
 *   - canRetry: boolean
 */
router.post('/complete', authenticateUser, async (req, res) => {
  try {
    const { sessionId } = req.body;
    const userId = req.user.uid;

    if (!sessionId) {
      return res.status(400).json({
        success: false,
        error: 'sessionId is required'
      });
    }

    const result = await completeUnlockQuiz(userId, sessionId);

    res.json({
      success: true,
      data: result
    });

  } catch (error) {
    logger.error('POST /api/unlock-quiz/complete error:', {
      userId: req.user?.uid,
      error: error.message
    });

    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/unlock-quiz/session/:sessionId
 *
 * Get unlock quiz session details
 *
 * Response:
 *   - Full session object
 */
router.get('/session/:sessionId', authenticateUser, async (req, res) => {
  try {
    const { sessionId } = req.params;
    const userId = req.user.uid;

    if (!sessionId) {
      return res.status(400).json({
        success: false,
        error: 'sessionId is required'
      });
    }

    const session = await getUnlockQuizSession(userId, sessionId);

    res.json({
      success: true,
      data: session
    });

  } catch (error) {
    logger.error('GET /api/unlock-quiz/session/:sessionId error:', {
      userId: req.user?.uid,
      error: error.message
    });

    res.status(404).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
