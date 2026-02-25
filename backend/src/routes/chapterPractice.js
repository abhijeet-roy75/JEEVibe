/**
 * Chapter Practice Routes
 *
 * API endpoints for chapter-specific practice sessions:
 * - POST /api/chapter-practice/generate - Generate new practice session
 * - POST /api/chapter-practice/submit-answer - Submit answer for a question
 * - POST /api/chapter-practice/complete - Complete session and update theta
 * - GET /api/chapter-practice/session/:sessionId - Get session details
 * - GET /api/chapter-practice/active - Get active session (if any)
 */

const express = require('express');
const router = express.Router();
const { db, admin } = require('../config/firebase');
const { authenticateUser } = require('../middleware/auth');
const { validateSessionMiddleware } = require('../middleware/sessionValidator');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { ApiError } = require('../middleware/errorHandler');
const { body, param, validationResult } = require('express-validator');

// Services
const {
  generateChapterPractice,
  getSession,
  getActiveSession,
  THETA_MULTIPLIER
} = require('../services/chapterPracticeService');
const { getDatabaseNames } = require('../services/chapterMappingService');

// Subscription & Tier Services
const { getEffectiveTier } = require('../services/subscriptionService');
const { getTierLimits } = require('../services/tierConfigService');

const {
  calculateChapterThetaUpdate,
  calculateSubjectAndOverallThetaUpdate,
  calculateSubtopicAccuracyUpdate
} = require('../services/thetaUpdateService');
const { updateStreak } = require('../services/streakService');
const { detectWeakSpots } = require('../services/weakSpotScoringService');

// ============================================================================
// CONSTANTS
// ============================================================================

const THETA_MIN = -3;
const THETA_MAX = 3;
const ACCURACY_PRECISION = 3; // Decimal places for accuracy rounding

/**
 * Round a number to specified decimal places
 * @param {number} value - Value to round
 * @param {number} decimals - Number of decimal places
 * @returns {number} Rounded value
 */
function roundToDecimals(value, decimals = ACCURACY_PRECISION) {
  const multiplier = Math.pow(10, decimals);
  return Math.round(value * multiplier) / multiplier;
}

// ============================================================================
// VALIDATION MIDDLEWARE
// ============================================================================

const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    const firstError = errors.array()[0];
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      message: firstError.msg,
      field: firstError.path,
      code: 'VALIDATION_ERROR'
    });
  }
  next();
};

const validateGenerate = [
  body('chapter_key')
    .trim()
    .notEmpty().withMessage('chapter_key is required')
    .isString().withMessage('chapter_key must be a string')
    .isLength({ min: 3, max: 100 }).withMessage('chapter_key must be between 3 and 100 characters')
    .matches(/^[a-zA-Z0-9_\-\s]+$/).withMessage('chapter_key contains invalid characters'),
  body('question_count')
    .optional()
    .isInt({ min: 1, max: 20 }).withMessage('question_count must be between 1 and 20'),
  handleValidationErrors
];

const validateSubmitAnswer = [
  body('session_id')
    .trim()
    .notEmpty().withMessage('session_id is required')
    .isString().withMessage('session_id must be a string'),
  body('question_id')
    .trim()
    .notEmpty().withMessage('question_id is required')
    .isString().withMessage('question_id must be a string'),
  body('student_answer')
    .trim()
    .notEmpty().withMessage('student_answer is required')
    .isString().withMessage('student_answer must be a string'),
  body('time_taken_seconds')
    .optional()
    .isInt({ min: 0, max: 3600 }).withMessage('time_taken_seconds must be between 0 and 3600'),
  handleValidationErrors
];

const validateSessionId = [
  body('session_id')
    .trim()
    .notEmpty().withMessage('session_id is required')
    .isString().withMessage('session_id must be a string'),
  handleValidationErrors
];

// ============================================================================
// GENERATE PRACTICE SESSION
// ============================================================================

/**
 * POST /api/chapter-practice/generate
 *
 * Generate a new chapter practice session
 *
 * Body: { chapter_key: string, question_count?: number }
 * Returns: { session_id, questions[], chapter_info }
 *
 * Authentication: Required
 */
router.post('/generate', authenticateUser, validateSessionMiddleware, validateGenerate, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { chapter_key, question_count } = req.body;

    // Check subscription tier for chapter practice access
    const tierInfo = await getEffectiveTier(userId);
    const limits = await getTierLimits(tierInfo.tier);

    if (!limits.chapter_practice_enabled) {
      logger.warn('Chapter practice access denied - not enabled for tier', {
        userId,
        tier: tierInfo.tier,
        chapterKey: chapter_key
      });

      return res.status(403).json({
        success: false,
        error: {
          code: 'FEATURE_NOT_ENABLED',
          message: 'Chapter Practice is a Pro/Ultra feature. Upgrade to access focused chapter practice!',
          details: 'Upgrade your subscription to practice specific chapters'
        },
        tier: tierInfo.tier,
        upgrade_prompt: {
          message: 'Upgrade to Pro for Chapter Practice',
          cta: 'Upgrade Now'
        },
        requestId: req.id
      });
    }

    // Check daily limit for chapter practice (Free tier: 5 chapters/day)
    const dailyLimit = limits.chapter_practice_daily_limit ?? -1;
    if (dailyLimit !== -1) {
      // Get today's date in IST (YYYY-MM-DD format)
      const getTodayIST = () => {
        const formatter = new Intl.DateTimeFormat('en-CA', {
          timeZone: 'Asia/Kolkata',
          year: 'numeric',
          month: '2-digit',
          day: '2-digit'
        });
        return formatter.format(new Date());
      };

      const todayKey = getTodayIST();
      const dailyUsageRef = db.collection('users').doc(userId)
        .collection('daily_usage').doc(todayKey);

      const usageDoc = await retryFirestoreOperation(async () => {
        return await dailyUsageRef.get();
      });

      const usageData = usageDoc.exists ? usageDoc.data() : {};
      const chaptersCompletedToday = usageData.chapter_practice_count || 0;

      if (chaptersCompletedToday >= dailyLimit) {
        logger.warn('Chapter practice daily limit reached', {
          userId,
          tier: tierInfo.tier,
          chaptersCompletedToday,
          dailyLimit,
          date: todayKey
        });

        return res.status(403).json({
          success: false,
          error: {
            code: 'DAILY_LIMIT_REACHED',
            message: `You've practiced ${dailyLimit} chapters today. Come back tomorrow for more!`,
            details: `Free tier allows ${dailyLimit} chapter practices per day`
          },
          chapters_completed_today: chaptersCompletedToday,
          daily_limit: dailyLimit,
          tier: tierInfo.tier,
          upgrade_prompt: {
            message: 'Upgrade to Pro for unlimited chapter practice',
            cta: 'Upgrade Now'
          },
          requestId: req.id
        });
      }
    }

    // Check if user has completed at least 1 daily quiz (prerequisite for chapter practice)
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    if (!userDoc.exists) {
      throw new ApiError(404, 'User not found', 'USER_NOT_FOUND');
    }

    const userData = userDoc.data();
    const completedQuizCount = userData.completed_quiz_count || 0;

    if (completedQuizCount < 1) {
      logger.warn('Chapter practice blocked - no daily quiz completed', {
        userId,
        completedQuizCount,
        chapterKey: chapter_key
      });

      return res.status(403).json({
        success: false,
        error: {
          code: 'DAILY_QUIZ_REQUIRED',
          message: 'Complete at least one Daily Quiz to unlock Chapter Practice.',
          details: 'Daily Quiz helps calibrate your skill level for better practice questions.'
        },
        completed_quiz_count: completedQuizCount,
        upgrade_prompt: {
          message: 'Complete your first Daily Quiz',
          cta: 'Start Daily Quiz',
          action: 'navigate_to_daily_quiz'
        },
        requestId: req.id
      });
    }

    // Check for existing active session for this chapter
    const activeSession = await getActiveSession(userId, chapter_key);

    if (activeSession) {
      // Check tier-based question count limit first
      const tierQuestionLimit = limits.chapter_practice_per_chapter || 15;
      const sessionQuestionCount = activeSession.total_questions || activeSession.questions?.length || 0;
      const exceedsTierLimit = sessionQuestionCount > tierQuestionLimit;

      // Check if session has expired
      const expiresAt = activeSession.expires_at ? new Date(activeSession.expires_at) : null;
      const isExpired = expiresAt && new Date() > expiresAt;

      // Validate that session questions have proper options (for sessions created before fixes)
      const hasValidQuestions = activeSession.questions && activeSession.questions.every(q => {
        // Numerical questions don't need options
        if (q.question_type === 'numerical') return true;
        // MCQ questions must have at least 2 valid options
        return q.options && Array.isArray(q.options) && q.options.length >= 2 &&
          q.options.every(opt => opt && opt.option_id && opt.text && opt.text.trim() !== '');
      });

      if (isExpired || !hasValidQuestions || exceedsTierLimit) {
        // Mark corrupted/expired/over-limit session as invalidated and generate new one
        const reason = isExpired ? 'expired' : !hasValidQuestions ? 'invalid_questions' : 'exceeds_tier_limit';
        logger.info('Active session invalidated, marking and generating new one', {
          userId,
          sessionId: activeSession.session_id,
          reason,
          expiresAt: activeSession.expires_at,
          questionCount: sessionQuestionCount,
          tierLimit: tierQuestionLimit
        });

        const invalidSessionRef = db.collection('chapter_practice_sessions')
          .doc(userId)
          .collection('sessions')
          .doc(activeSession.session_id);

        await retryFirestoreOperation(async () => {
          return await invalidSessionRef.update({
            status: reason === 'expired' ? 'expired' : 'invalidated',
            invalidated_at: admin.firestore.FieldValue.serverTimestamp(),
            invalidation_reason: reason
          });
        });
      } else {
        logger.info('Returning existing active session', {
          userId,
          sessionId: activeSession.session_id,
          chapterKey: chapter_key,
          questionCount: sessionQuestionCount
        });

        return res.json({
          success: true,
          message: 'Active session found',
          session: {
            session_id: activeSession.session_id,
            chapter_key: activeSession.chapter_key,
            chapter_name: activeSession.chapter_name,
            subject: activeSession.subject,
            questions: activeSession.questions,
            total_questions: activeSession.total_questions,
            questions_answered: activeSession.questions_answered,
            theta_at_start: activeSession.theta_at_start,
            created_at: activeSession.created_at
          },
          is_existing_session: true,
          requestId: req.id
        });
      }
    }

    // Enforce tier-based question count limit
    // Use tier's chapter_practice_per_chapter limit as the max
    const tierQuestionLimit = limits.chapter_practice_per_chapter || 15;
    const effectiveQuestionCount = question_count
      ? Math.min(question_count, tierQuestionLimit)
      : tierQuestionLimit;

    logger.info('Generating chapter practice session with tier limits', {
      userId,
      tier: tierInfo.tier,
      requestedCount: question_count,
      tierLimit: tierQuestionLimit,
      effectiveCount: effectiveQuestionCount
    });

    // Generate new session
    const sessionData = await generateChapterPractice(userId, chapter_key, effectiveQuestionCount);

    res.json({
      success: true,
      message: 'Chapter practice session generated',
      session: sessionData,
      is_existing_session: false,
      requestId: req.id
    });

  } catch (error) {
    next(error);
  }
});

// ============================================================================
// SUBMIT ANSWER
// ============================================================================

/**
 * POST /api/chapter-practice/submit-answer
 *
 * Submit answer for a question in active session
 * Updates theta immediately with 0.5x multiplier
 *
 * Body: { session_id, question_id, student_answer, time_taken_seconds? }
 * Returns: { is_correct, correct_option, explanation, theta_delta }
 *
 * Authentication: Required
 */
router.post('/submit-answer', authenticateUser, validateSessionMiddleware, validateSubmitAnswer, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { session_id, question_id, student_answer, time_taken_seconds = 0 } = req.body;

    // Get session
    const sessionRef = db.collection('chapter_practice_sessions')
      .doc(userId)
      .collection('sessions')
      .doc(session_id);

    const sessionDoc = await retryFirestoreOperation(async () => {
      return await sessionRef.get();
    });

    if (!sessionDoc.exists) {
      throw new ApiError(404, `Session ${session_id} not found`, 'SESSION_NOT_FOUND');
    }

    const sessionData = sessionDoc.data();

    // Validate session ownership
    if (sessionData.student_id && sessionData.student_id !== userId) {
      logger.warn('Session ownership mismatch in submit-answer', {
        sessionId: session_id,
        sessionOwner: sessionData.student_id,
        requestingUser: userId
      });
      throw new ApiError(403, 'You do not have access to this session', 'SESSION_ACCESS_DENIED');
    }

    if (sessionData.status !== 'in_progress') {
      throw new ApiError(400, `Session ${session_id} is not in progress`, 'SESSION_NOT_IN_PROGRESS');
    }

    // Check if session has expired
    const expiresAt = sessionData.expires_at ? new Date(sessionData.expires_at) : null;
    if (expiresAt && new Date() > expiresAt) {
      // Mark session as expired
      await retryFirestoreOperation(async () => {
        return await sessionRef.update({
          status: 'expired',
          expired_at: admin.firestore.FieldValue.serverTimestamp()
        });
      });

      throw new ApiError(410, `Session ${session_id} has expired. Please start a new practice session.`, 'SESSION_EXPIRED');
    }

    // Find question in session
    const questionsSnapshot = await retryFirestoreOperation(async () => {
      return await sessionRef.collection('questions')
        .where('question_id', '==', question_id)
        .limit(1)
        .get();
    });

    if (questionsSnapshot.empty) {
      throw new ApiError(404, `Question ${question_id} not found in session`, 'QUESTION_NOT_FOUND');
    }

    const questionDoc = questionsSnapshot.docs[0];
    const questionDocRef = sessionRef.collection('questions').doc(questionDoc.id);

    // Use transaction to atomically check if answered and reserve the question
    // This prevents race conditions where the same question could be answered twice
    let questionData;
    let alreadyAnswered = false;
    try {
      questionData = await db.runTransaction(async (transaction) => {
        const qDoc = await transaction.get(questionDocRef);

        if (!qDoc.exists) {
          throw new ApiError(404, `Question ${question_id} not found in session`, 'QUESTION_NOT_FOUND');
        }

        const data = qDoc.data();

        if (data.answered) {
          // Question already answered - we'll return the existing response
          return { ...data, _alreadyAnswered: true };
        }

        // Mark as being answered to prevent concurrent submissions
        transaction.update(questionDocRef, { answering: true });

        return data;
      });

      alreadyAnswered = questionData._alreadyAnswered === true;
    } catch (error) {
      if (error instanceof ApiError) {
        throw error;
      }
      throw new ApiError(500, 'Failed to submit answer', 'TRANSACTION_FAILED');
    }

    // If question was already answered, return the existing response
    if (alreadyAnswered) {
      logger.info('Question already answered, returning existing response', {
        userId,
        sessionId: session_id,
        questionId: question_id
      });

      // Fetch the existing response
      const existingResponseRef = db.collection('chapter_practice_responses')
        .doc(userId)
        .collection('responses')
        .doc(`${session_id}_${question_id}`);

      const existingResponseDoc = await retryFirestoreOperation(async () => {
        return await existingResponseRef.get();
      });

      if (existingResponseDoc.exists) {
        const existingResponse = existingResponseDoc.data();

        // Return the existing response in the expected format
        return res.json({
          success: true,
          data: {
            is_correct: existingResponse.is_correct,
            student_answer: existingResponse.student_answer,
            correct_answer: existingResponse.correct_answer,
            correct_answer_text: existingResponse.correct_answer_text,
            explanation: existingResponse.explanation,
            solution_text: existingResponse.solution_text,
            solution_steps: existingResponse.solution_steps || [],
            key_insight: existingResponse.key_insight,
            distractor_analysis: existingResponse.distractor_analysis,
            common_mistakes: existingResponse.common_mistakes,
            theta_delta: existingResponse.theta_delta || 0,
            theta_multiplier: existingResponse.theta_multiplier || 0.5,
            question_position: questionData.position,
            session_progress: {
              answered: sessionData.answered_count || 0,
              total: sessionData.total_questions,
              correct: sessionData.correct_count || 0
            },
            _already_answered: true
          }
        });
      }

      // If no existing response found (shouldn't happen), throw error
      throw new ApiError(400, `Question ${question_id} marked as answered but no response found`, 'RESPONSE_NOT_FOUND');
    }

    // Get full question from questions collection for correct answer
    const fullQuestionRef = db.collection('questions').doc(question_id);
    const fullQuestionDoc = await retryFirestoreOperation(async () => {
      return await fullQuestionRef.get();
    });

    if (!fullQuestionDoc.exists) {
      throw new ApiError(404, `Question ${question_id} not found in database`, 'QUESTION_NOT_IN_DB');
    }

    const fullQuestionData = fullQuestionDoc.data();
    const correctAnswer = fullQuestionData.correct_answer;
    const isCorrect = student_answer.toUpperCase() === correctAnswer?.toUpperCase();

    // Get IRT parameters
    const irtParams = fullQuestionData.irt_parameters || {
      discrimination_a: 1.5,
      difficulty_b: fullQuestionData.difficulty_irt || 0,
      guessing_c: fullQuestionData.question_type === 'mcq_single' ? 0.25 : 0.0
    };

    // Get current user data for theta update
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    const userData = userDoc.data();
    const chapterKey = sessionData.chapter_key;
    const currentChapterData = userData.theta_by_chapter?.[chapterKey] || {
      theta: 0.0,
      percentile: 50.0,
      confidence_SE: 0.6,
      attempts: 0,
      accuracy: 0.0
    };

    // Calculate theta update with 0.5x multiplier
    const response = {
      questionIRT: {
        a: irtParams.discrimination_a,
        b: irtParams.difficulty_b,
        c: irtParams.guessing_c
      },
      isCorrect: isCorrect
    };

    // ========================================================================
    // THETA UPDATE LOGGING - BEFORE
    // ========================================================================
    logger.info('🔵 [CHAPTER PRACTICE] THETA UPDATE - BEFORE', {
      userId,
      sessionId: session_id,
      questionId: question_id,
      chapterKey,
      isCorrect,
      questionDifficulty: irtParams.difficulty_b,
      BEFORE: {
        chapter_theta: currentChapterData.theta,
        chapter_attempts: currentChapterData.attempts,
        chapter_accuracy: currentChapterData.accuracy,
        chapter_percentile: currentChapterData.percentile
      }
    });

    const chapterUpdate = calculateChapterThetaUpdate(currentChapterData, [response]);

    // Apply 0.5x multiplier to theta delta
    const rawThetaDelta = chapterUpdate.theta - currentChapterData.theta;
    const adjustedThetaDelta = rawThetaDelta * THETA_MULTIPLIER;
    const adjustedTheta = currentChapterData.theta + adjustedThetaDelta;

    // Bound adjusted theta within valid range
    const boundedTheta = Math.max(THETA_MIN, Math.min(THETA_MAX, adjustedTheta));

    // Prepare updated chapter data for user
    const updatedChapterData = {
      ...chapterUpdate,
      theta: boundedTheta,
      theta_delta: adjustedThetaDelta
    };

    // ========================================================================
    // THETA UPDATE LOGGING - AFTER (calculated, before write)
    // ========================================================================
    logger.info('🟢 [CHAPTER PRACTICE] THETA UPDATE - AFTER (calculated)', {
      userId,
      sessionId: session_id,
      questionId: question_id,
      chapterKey,
      AFTER: {
        chapter_theta: boundedTheta,
        chapter_attempts: updatedChapterData.attempts,
        chapter_accuracy: updatedChapterData.accuracy,
        chapter_percentile: updatedChapterData.percentile,
        raw_theta_delta: roundToDecimals(rawThetaDelta, 4),
        adjusted_theta_delta: roundToDecimals(adjustedThetaDelta, 4),
        multiplier: THETA_MULTIPLIER
      }
    });

    // Response document reference
    const responseRef = db.collection('chapter_practice_responses')
      .doc(userId)
      .collection('responses')
      .doc(`${session_id}_${question_id}`);

    // Use batch write for atomicity across all related updates
    // This ensures either all updates succeed or none do
    const batch = db.batch();

    // 1. Update question in session (clear answering flag and mark as answered)
    // Also store solution fields so they're available when reviewing from history
    batch.update(questionDocRef, {
      answered: true,
      answering: admin.firestore.FieldValue.delete(),
      student_answer: student_answer,
      is_correct: isCorrect,
      correct_answer: correctAnswer,
      time_taken_seconds: time_taken_seconds,
      answered_at: admin.firestore.FieldValue.serverTimestamp(),
      theta_delta: adjustedThetaDelta,
      // Solution fields for history review
      solution_text: fullQuestionData.solution_text || null,
      solution_steps: fullQuestionData.solution_steps || [],
      key_insight: fullQuestionData.metadata?.key_insight || fullQuestionData.key_insight || null,
      distractor_analysis: fullQuestionData.distractor_analysis || null,
      common_mistakes: fullQuestionData.metadata?.common_mistakes || fullQuestionData.common_mistakes || null
    });

    // 2. Update session stats
    batch.update(sessionRef, {
      questions_answered: admin.firestore.FieldValue.increment(1),
      correct_count: isCorrect
        ? admin.firestore.FieldValue.increment(1)
        : admin.firestore.FieldValue.increment(0)
    });

    // 3. Update user theta immediately (with multiplier applied)
    batch.update(userRef, {
      [`theta_by_chapter.${chapterKey}`]: updatedChapterData
    });

    // 4. Save response to chapter_practice_responses collection
    batch.set(responseRef, {
      session_id: session_id,
      question_id: question_id,
      chapter_key: chapterKey,
      subject: sessionData.subject,
      chapter: sessionData.chapter_name,
      student_answer: student_answer,
      correct_answer: correctAnswer,
      is_correct: isCorrect,
      time_taken_seconds: time_taken_seconds,
      theta_delta: adjustedThetaDelta,
      question_irt_params: irtParams,
      sub_topics: fullQuestionData.sub_topics || [],
      answered_at: admin.firestore.FieldValue.serverTimestamp(),
      // Solution fields for history review and idempotency
      solution_text: fullQuestionData.solution_text || null,
      solution_steps: fullQuestionData.solution_steps || [],
      key_insight: fullQuestionData.metadata?.key_insight || fullQuestionData.key_insight || null,
      distractor_analysis: fullQuestionData.distractor_analysis || null,
      common_mistakes: fullQuestionData.metadata?.common_mistakes || fullQuestionData.common_mistakes || null
    });

    // Commit all updates atomically
    await retryFirestoreOperation(async () => {
      return await batch.commit();
    });

    logger.info('Chapter practice answer submitted', {
      userId,
      sessionId: session_id,
      questionId: question_id,
      chapterKey,
      subject: sessionData.subject,
      isCorrect,
      questionDifficulty: irtParams.difficulty_b,
      timeTakenSeconds: time_taken_seconds,
      rawThetaDelta: roundToDecimals(rawThetaDelta, 4),
      adjustedThetaDelta: roundToDecimals(adjustedThetaDelta, 4),
      newTheta: roundToDecimals(boundedTheta, 4)
    });

    // Return feedback with rich explanation data
    res.json({
      success: true,
      is_correct: isCorrect,
      correct_answer: correctAnswer,
      correct_answer_text: fullQuestionData.correct_answer_text || null,
      explanation: fullQuestionData.explanation || fullQuestionData.solution_text || null,
      solution_text: fullQuestionData.solution_text || null,
      solution_steps: fullQuestionData.solution_steps || [],
      key_insight: fullQuestionData.metadata?.key_insight || fullQuestionData.key_insight || null,
      distractor_analysis: fullQuestionData.distractor_analysis || null,
      common_mistakes: fullQuestionData.metadata?.common_mistakes || fullQuestionData.common_mistakes || null,
      theta_delta: adjustedThetaDelta,
      theta_multiplier: THETA_MULTIPLIER,
      requestId: req.id
    });

  } catch (error) {
    next(error);
  }
});

// ============================================================================
// CHAPTER PRACTICE STATS AGGREGATION
// ============================================================================

/**
 * Update aggregated chapter practice stats after session completion
 *
 * Stats structure:
 * chapter_practice_stats: {
 *   total_sessions: number,
 *   total_questions_practiced: number,
 *   overall_accuracy: number,
 *   total_time_seconds: number,
 *   by_chapter: {
 *     [chapter_key]: {
 *       sessions: number,
 *       questions: number,
 *       correct: number,
 *       accuracy: number,
 *       avg_time_per_question: number,
 *       total_time_seconds: number,
 *       theta_improvement: number,
 *       first_practiced: timestamp,
 *       last_practiced: timestamp
 *     }
 *   },
 *   by_subject: {
 *     [subject]: {
 *       sessions: number,
 *       questions: number,
 *       correct: number,
 *       accuracy: number
 *     }
 *   }
 * }
 */
function aggregateChapterPracticeStats(existingStats, sessionData, sessionResults) {
  const stats = existingStats || {
    total_sessions: 0,
    total_questions_practiced: 0,
    total_correct: 0,
    overall_accuracy: 0,
    total_time_seconds: 0,
    by_chapter: {},
    by_subject: {}
  };

  const chapterKey = sessionData.chapter_key;
  const subject = sessionData.subject;
  const { correctCount, totalAnswered, totalTime, thetaImprovement } = sessionResults;

  // Update totals
  stats.total_sessions += 1;
  stats.total_questions_practiced += totalAnswered;
  stats.total_correct += correctCount;
  stats.total_time_seconds += totalTime;
  stats.overall_accuracy = stats.total_questions_practiced > 0
    ? roundToDecimals(stats.total_correct / stats.total_questions_practiced)
    : 0;

  // Update by_chapter stats
  if (!stats.by_chapter[chapterKey]) {
    stats.by_chapter[chapterKey] = {
      chapter_name: sessionData.chapter_name,
      subject: subject,
      sessions: 0,
      questions: 0,
      correct: 0,
      accuracy: 0,
      avg_time_per_question: 0,
      total_time_seconds: 0,
      theta_improvement: 0,
      first_practiced: new Date().toISOString(),
      last_practiced: new Date().toISOString()
    };
  }

  const chapterStats = stats.by_chapter[chapterKey];
  chapterStats.sessions += 1;
  chapterStats.questions += totalAnswered;
  chapterStats.correct += correctCount;
  chapterStats.total_time_seconds += totalTime;
  chapterStats.accuracy = chapterStats.questions > 0
    ? roundToDecimals(chapterStats.correct / chapterStats.questions)
    : 0;
  chapterStats.avg_time_per_question = chapterStats.questions > 0
    ? Math.round(chapterStats.total_time_seconds / chapterStats.questions)
    : 0;
  chapterStats.theta_improvement += thetaImprovement;
  chapterStats.last_practiced = new Date().toISOString();

  // Update by_subject stats
  if (!stats.by_subject[subject]) {
    stats.by_subject[subject] = {
      sessions: 0,
      questions: 0,
      correct: 0,
      accuracy: 0
    };
  }

  const subjectStats = stats.by_subject[subject];
  subjectStats.sessions += 1;
  subjectStats.questions += totalAnswered;
  subjectStats.correct += correctCount;
  subjectStats.accuracy = subjectStats.questions > 0
    ? roundToDecimals(subjectStats.correct / subjectStats.questions)
    : 0;

  return stats;
}

// ============================================================================
// COMPLETE SESSION
// ============================================================================

/**
 * POST /api/chapter-practice/complete
 *
 * Complete a practice session
 * Updates subject and overall theta
 * Aggregates chapter practice stats
 *
 * Body: { session_id }
 * Returns: { summary, updated_stats }
 *
 * Authentication: Required
 */
router.post('/complete', authenticateUser, validateSessionMiddleware, validateSessionId, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { session_id } = req.body;

    // Get session
    const sessionRef = db.collection('chapter_practice_sessions')
      .doc(userId)
      .collection('sessions')
      .doc(session_id);

    // Use transaction to atomically check status and mark as completing
    // This prevents double-counting stats if /complete is called twice
    let sessionData;
    try {
      sessionData = await db.runTransaction(async (transaction) => {
        const sessionDoc = await transaction.get(sessionRef);

        if (!sessionDoc.exists) {
          throw new ApiError(404, `Session ${session_id} not found`, 'SESSION_NOT_FOUND');
        }

        const data = sessionDoc.data();

        // Validate session ownership
        if (data.student_id && data.student_id !== userId) {
          logger.warn('Session ownership mismatch in complete', {
            sessionId: session_id,
            sessionOwner: data.student_id,
            requestingUser: userId
          });
          throw new ApiError(403, 'You do not have access to this session', 'SESSION_ACCESS_DENIED');
        }

        if (data.status === 'completed') {
          throw new ApiError(400, `Session ${session_id} is already completed`, 'SESSION_ALREADY_COMPLETED');
        }

        if (data.status === 'completing') {
          throw new ApiError(409, `Session ${session_id} is being completed by another request`, 'SESSION_COMPLETING');
        }

        // Mark as completing to prevent concurrent completions
        transaction.update(sessionRef, { status: 'completing' });

        return data;
      });
    } catch (error) {
      // Re-throw ApiError as-is
      if (error instanceof ApiError) {
        throw error;
      }
      throw new ApiError(500, 'Failed to complete session', 'TRANSACTION_FAILED');
    }

    // Get all answered questions
    const questionsSnapshot = await retryFirestoreOperation(async () => {
      return await sessionRef.collection('questions')
        .where('answered', '==', true)
        .get();
    });

    const answeredQuestions = questionsSnapshot.docs.map(doc => doc.data());
    const correctCount = answeredQuestions.filter(q => q.is_correct).length;
    const totalAnswered = answeredQuestions.length;
    const accuracy = totalAnswered > 0 ? correctCount / totalAnswered : 0;
    const totalTime = answeredQuestions.reduce((sum, q) => sum + (q.time_taken_seconds || 0), 0);

    // Calculate total theta improvement from this session
    const thetaImprovement = answeredQuestions.reduce((sum, q) => sum + (q.theta_delta || 0), 0);

    // Get user data
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    const userData = userDoc.data();
    const updatedThetaByChapter = userData.theta_by_chapter || {};

    // ========================================================================
    // SESSION COMPLETE LOGGING - BEFORE
    // ========================================================================
    logger.info('🔵 [CHAPTER PRACTICE COMPLETE] THETA UPDATE - BEFORE', {
      userId,
      sessionId: session_id,
      chapterKey: sessionData.chapter_key,
      subject: sessionData.subject,
      sessionStats: {
        totalAnswered,
        correctCount,
        accuracy: roundToDecimals(accuracy, 3),
        thetaImprovement: roundToDecimals(thetaImprovement, 4)
      },
      BEFORE: {
        chapter_theta: updatedThetaByChapter[sessionData.chapter_key]?.theta,
        chapter_attempts: updatedThetaByChapter[sessionData.chapter_key]?.attempts,
        subject_theta: userData.theta_by_subject?.[sessionData.subject]?.theta,
        overall_theta: userData.overall_theta,
        overall_percentile: userData.overall_percentile,
        total_questions_solved: userData.total_questions_solved
      }
    });

    // Calculate subject and overall theta
    const subjectAndOverallUpdate = calculateSubjectAndOverallThetaUpdate(updatedThetaByChapter);

    // ========================================================================
    // SESSION COMPLETE LOGGING - AFTER (calculated, before write)
    // ========================================================================
    logger.info('🟢 [CHAPTER PRACTICE COMPLETE] THETA UPDATE - AFTER (calculated)', {
      userId,
      sessionId: session_id,
      chapterKey: sessionData.chapter_key,
      AFTER: {
        subject_theta: subjectAndOverallUpdate.theta_by_subject?.[sessionData.subject]?.theta,
        subject_percentile: subjectAndOverallUpdate.theta_by_subject?.[sessionData.subject]?.percentile,
        overall_theta: subjectAndOverallUpdate.overall_theta,
        overall_percentile: subjectAndOverallUpdate.overall_percentile
      }
    });

    // Get responses for subtopic accuracy update
    const responsesSnapshot = await retryFirestoreOperation(async () => {
      return await db.collection('chapter_practice_responses')
        .doc(userId)
        .collection('responses')
        .where('session_id', '==', session_id)
        .get();
    });

    const responses = responsesSnapshot.docs.map(doc => doc.data());
    const currentSubtopicAccuracy = userData.subtopic_accuracy || {};
    const updatedSubtopicAccuracy = calculateSubtopicAccuracyUpdate(currentSubtopicAccuracy, responses);

    // Aggregate chapter practice stats
    const existingStats = userData.chapter_practice_stats || null;
    const updatedChapterPracticeStats = aggregateChapterPracticeStats(
      existingStats,
      sessionData,
      { correctCount, totalAnswered, totalTime, thetaImprovement }
    );

    // ========================================================================
    // ATOMIC TRANSACTION: Update session and user theta together
    // This prevents race conditions when multiple sessions complete concurrently
    // ========================================================================
    await retryFirestoreOperation(async () => {
      return await db.runTransaction(async (transaction) => {
        // Re-read user document in transaction to get latest theta values
        const userDocInTxn = await transaction.get(userRef);

        if (!userDocInTxn.exists) {
          throw new ApiError(404, `User ${userId} not found`, 'USER_NOT_FOUND');
        }

        const latestUserData = userDocInTxn.data();
        const latestThetaByChapter = latestUserData.theta_by_chapter || {};

        // Recalculate subject/overall theta with latest chapter data
        // (in case another session updated theta between our read and this transaction)
        const latestSubjectAndOverallUpdate = calculateSubjectAndOverallThetaUpdate(latestThetaByChapter);

        // Get latest subtopic accuracy
        const latestSubtopicAccuracy = latestUserData.subtopic_accuracy || {};
        const finalSubtopicAccuracy = calculateSubtopicAccuracyUpdate(latestSubtopicAccuracy, responses);

        // Aggregate chapter practice stats with latest data
        const latestStats = latestUserData.chapter_practice_stats || null;
        const finalChapterPracticeStats = aggregateChapterPracticeStats(
          latestStats,
          sessionData,
          { correctCount, totalAnswered, totalTime, thetaImprovement }
        );

        // Update session as completed (atomic with user update)
        transaction.update(sessionRef, {
          status: 'completed',
          completed_at: admin.firestore.FieldValue.serverTimestamp(),
          final_accuracy: accuracy,
          final_correct_count: correctCount,
          final_total_answered: totalAnswered,
          total_time_seconds: totalTime,
          theta_improvement: thetaImprovement
        });

        // Update user with subject/overall theta, subtopic accuracy, and chapter practice stats
        transaction.update(userRef, {
          theta_by_subject: latestSubjectAndOverallUpdate.theta_by_subject,
          subject_accuracy: latestSubjectAndOverallUpdate.subject_accuracy,
          overall_theta: latestSubjectAndOverallUpdate.overall_theta,
          overall_percentile: latestSubjectAndOverallUpdate.overall_percentile,
          subtopic_accuracy: finalSubtopicAccuracy,
          chapter_practice_stats: finalChapterPracticeStats,
          total_questions_solved: admin.firestore.FieldValue.increment(totalAnswered),
          total_time_spent_minutes: admin.firestore.FieldValue.increment(Math.round(totalTime / 60)),
          // Cumulative stats - consistent with daily quiz and initial assessment
          'cumulative_stats.total_questions_correct': admin.firestore.FieldValue.increment(correctCount),
          'cumulative_stats.total_questions_attempted': admin.firestore.FieldValue.increment(totalAnswered),
          'cumulative_stats.last_updated': admin.firestore.FieldValue.serverTimestamp()
        });

        logger.info('Chapter practice completed with atomic theta updates', {
          userId,
          sessionId: session_id,
          chapterKey: sessionData.chapter_key,
          overall_theta: latestSubjectAndOverallUpdate.overall_theta
        });
      });
    });

    // Update practice streak
    try {
      await updateStreak(userId);
    } catch (error) {
      logger.error('Error updating streak after chapter practice', {
        userId,
        error: error.message
      });
    }

    // Record daily usage for tier limit tracking (Free tier: 5 chapters/day)
    const tierInfo = await getEffectiveTier(userId);
    const limits = await getTierLimits(tierInfo.tier);
    const dailyLimit = limits.chapter_practice_daily_limit ?? -1;
    if (dailyLimit !== -1) {
      // Get today's date in IST
      const getTodayIST = () => {
        const formatter = new Intl.DateTimeFormat('en-CA', {
          timeZone: 'Asia/Kolkata',
          year: 'numeric',
          month: '2-digit',
          day: '2-digit'
        });
        return formatter.format(new Date());
      };

      const todayKey = getTodayIST();
      const dailyUsageRef = db.collection('users').doc(userId)
        .collection('daily_usage').doc(todayKey);

      // Increment chapter practice count for today
      await retryFirestoreOperation(async () => {
        await dailyUsageRef.set({
          chapter_practice_count: admin.firestore.FieldValue.increment(1),
          updated_at: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      });

      logger.info('Recorded daily chapter practice completion', {
        userId,
        date: todayKey,
        chapterKey: sessionData.chapter_key
      });
    }

    logger.info('Chapter practice session completed', {
      userId,
      sessionId: session_id,
      chapterKey: sessionData.chapter_key,
      accuracy,
      correctCount,
      totalAnswered,
      thetaImprovement
    });

    // Run weak spot detection (non-blocking — failure does not affect completion)
    const weakSpot = await detectWeakSpots(userId, session_id);

    res.json({
      success: true,
      message: 'Practice session completed',
      summary: {
        session_id: session_id,
        chapter_key: sessionData.chapter_key,
        chapter_name: sessionData.chapter_name,
        subject: sessionData.subject,
        total_questions: sessionData.total_questions,
        questions_answered: totalAnswered,
        correct_count: correctCount,
        accuracy: roundToDecimals(accuracy),
        total_time_seconds: totalTime,
        theta_multiplier: THETA_MULTIPLIER,
        theta_improvement: roundToDecimals(thetaImprovement)
      },
      updated_stats: {
        overall_theta: subjectAndOverallUpdate.overall_theta,
        overall_percentile: subjectAndOverallUpdate.overall_percentile
      },
      chapter_practice_stats: {
        total_sessions: updatedChapterPracticeStats.total_sessions,
        total_questions_practiced: updatedChapterPracticeStats.total_questions_practiced,
        overall_accuracy: updatedChapterPracticeStats.overall_accuracy,
        chapter_stats: updatedChapterPracticeStats.by_chapter[sessionData.chapter_key]
      },
      weakSpot: weakSpot || null,
      requestId: req.id
    });

  } catch (error) {
    next(error);
  }
});

// ============================================================================
// GET SESSION
// ============================================================================

/**
 * GET /api/chapter-practice/session/:sessionId
 *
 * Get session details including questions
 *
 * Authentication: Required
 */
router.get('/session/:sessionId', authenticateUser, validateSessionMiddleware, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { sessionId } = req.params;

    if (!sessionId) {
      throw new ApiError(400, 'sessionId is required', 'MISSING_SESSION_ID');
    }

    const session = await getSession(userId, sessionId);

    if (!session) {
      throw new ApiError(404, `Session ${sessionId} not found`, 'SESSION_NOT_FOUND');
    }

    res.json({
      success: true,
      session: session,
      requestId: req.id
    });

  } catch (error) {
    next(error);
  }
});

// ============================================================================
// GET ACTIVE SESSION
// ============================================================================

/**
 * GET /api/chapter-practice/active
 *
 * Get active (in-progress) session if any
 *
 * Query params:
 * - chapter_key: Optional, filter by chapter
 *
 * Authentication: Required
 */
router.get('/active', authenticateUser, validateSessionMiddleware, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { chapter_key } = req.query;

    const session = await getActiveSession(userId, chapter_key || null);

    if (!session) {
      return res.json({
        success: true,
        has_active_session: false,
        session: null,
        requestId: req.id
      });
    }

    res.json({
      success: true,
      has_active_session: true,
      session: session,
      requestId: req.id
    });

  } catch (error) {
    next(error);
  }
});

// ============================================================================
// GET CHAPTER PRACTICE STATS
// ============================================================================

/**
 * GET /api/chapter-practice/stats
 *
 * Get aggregated chapter practice statistics for the user
 *
 * Query params:
 * - chapter_key: Optional, filter to specific chapter
 *
 * Authentication: Required
 */
router.get('/stats', authenticateUser, validateSessionMiddleware, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { chapter_key } = req.query;

    // Get user data
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    if (!userDoc.exists) {
      throw new ApiError(404, 'User not found', 'USER_NOT_FOUND');
    }

    const userData = userDoc.data();
    const stats = userData.chapter_practice_stats || {
      total_sessions: 0,
      total_questions_practiced: 0,
      total_correct: 0,
      overall_accuracy: 0,
      total_time_seconds: 0,
      by_chapter: {},
      by_subject: {}
    };

    // If chapter_key provided, return filtered response
    if (chapter_key) {
      const chapterStats = stats.by_chapter[chapter_key] || null;

      return res.json({
        success: true,
        chapter_key: chapter_key,
        stats: chapterStats,
        has_practiced: chapterStats !== null,
        requestId: req.id
      });
    }

    // Return full stats
    res.json({
      success: true,
      stats: {
        total_sessions: stats.total_sessions,
        total_questions_practiced: stats.total_questions_practiced,
        overall_accuracy: stats.overall_accuracy,
        total_time_seconds: stats.total_time_seconds,
        total_time_formatted: formatTime(stats.total_time_seconds),
        by_chapter: stats.by_chapter,
        by_subject: stats.by_subject,
        // Top practiced chapters (sorted by sessions)
        top_practiced_chapters: Object.entries(stats.by_chapter)
          .map(([key, data]) => ({ chapter_key: key, ...data }))
          .sort((a, b) => b.sessions - a.sessions)
          .slice(0, 5),
        // Chapters needing practice (lowest accuracy with at least 1 session)
        chapters_needing_practice: Object.entries(stats.by_chapter)
          .map(([key, data]) => ({ chapter_key: key, ...data }))
          .filter(c => c.sessions >= 1)
          .sort((a, b) => a.accuracy - b.accuracy)
          .slice(0, 5)
      },
      requestId: req.id
    });

  } catch (error) {
    next(error);
  }
});

/**
 * Format seconds into human-readable time string
 */
function formatTime(seconds) {
  if (!seconds || seconds === 0) return '0m';

  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);

  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }
  return `${minutes}m`;
}

// ============================================================================
// CHAPTER PRACTICE HISTORY
// ============================================================================

/**
 * GET /api/chapter-practice/history
 *
 * Get chapter practice session history for the user
 * Returns list of completed sessions with pagination and tier-based filtering
 *
 * Query params:
 * - limit: Number of sessions to return (default: 20, max: 50)
 * - offset: Number of sessions to skip (default: 0)
 * - days: Filter sessions from last N days (default: tier-based limit)
 * - subject: Filter by subject (optional: physics, chemistry, mathematics)
 *
 * Authentication: Required
 */
router.get('/history', authenticateUser, validateSessionMiddleware, async (req, res, next) => {
  try {
    const userId = req.userId;
    const limit = Math.min(parseInt(req.query.limit) || 20, 50);
    const offset = parseInt(req.query.offset) || 0;
    const subjectFilter = req.query.subject ? req.query.subject.toLowerCase() : null;

    // Validate pagination parameters
    if (limit < 1 || limit > 50) {
      throw new ApiError(400, 'limit must be between 1 and 50', 'INVALID_LIMIT');
    }
    if (offset < 0) {
      throw new ApiError(400, 'offset must be >= 0', 'INVALID_OFFSET');
    }
    if (offset > 100) {
      throw new ApiError(400,
        'Offset > 100 not supported. Use cursor-based pagination for better performance',
        'OFFSET_TOO_LARGE'
      );
    }

    // Validate subject filter
    if (subjectFilter && !['physics', 'chemistry', 'mathematics'].includes(subjectFilter)) {
      throw new ApiError(400, 'subject must be physics, chemistry, or mathematics', 'INVALID_SUBJECT');
    }

    // Get tier-based history limit
    const tierInfo = await getEffectiveTier(userId);
    const limits = await getTierLimits(tierInfo.tier);
    const tierHistoryDays = limits.solution_history_days || 7;

    // Use provided days parameter or tier-based default
    let historyDays = parseInt(req.query.days) || tierHistoryDays;

    // For non-unlimited tiers, cap at tier limit
    if (tierHistoryDays !== -1 && historyDays > tierHistoryDays) {
      historyDays = tierHistoryDays;
    }

    // Calculate date filter
    let startDate = null;
    if (historyDays !== -1) {
      startDate = new Date();
      startDate.setDate(startDate.getDate() - historyDays);
      startDate.setHours(0, 0, 0, 0);
    }

    // Build query
    let query = db.collection('chapter_practice_sessions')
      .doc(userId)
      .collection('sessions')
      .where('status', '==', 'completed');

    // Apply date filter if not unlimited
    if (startDate) {
      query = query.where('completed_at', '>=', admin.firestore.Timestamp.fromDate(startDate));
    }

    // Apply subject filter if provided
    if (subjectFilter) {
      query = query.where('subject', '==', subjectFilter.charAt(0).toUpperCase() + subjectFilter.slice(1));
    }

    // Order by completed_at descending and apply pagination
    query = query
      .orderBy('completed_at', 'desc')
      .limit(limit + offset);

    const snapshot = await retryFirestoreOperation(async () => {
      return await query.get();
    });

    // Apply offset manually (Firestore doesn't support offset directly)
    const allSessions = snapshot.docs.slice(offset, offset + limit);

    const sessions = allSessions.map(doc => {
      const data = doc.data();
      return {
        session_id: doc.id,
        chapter_key: data.chapter_key,
        chapter_name: data.chapter_name,
        subject: data.subject,
        completed_at: data.completed_at?.toDate?.()?.toISOString() || data.completed_at,
        total_questions: data.total_questions || 0,
        questions_answered: data.final_total_answered || data.questions_answered || 0,
        correct_count: data.final_correct_count || data.correct_count || 0,
        accuracy: data.final_accuracy != null ? roundToDecimals(data.final_accuracy) : 0,
        total_time_seconds: data.total_time_seconds || 0,
        theta_improvement: data.theta_improvement ? roundToDecimals(data.theta_improvement, 4) : 0
      };
    });

    // Get total count for pagination info
    let countQuery = db.collection('chapter_practice_sessions')
      .doc(userId)
      .collection('sessions')
      .where('status', '==', 'completed');

    if (startDate) {
      countQuery = countQuery.where('completed_at', '>=', admin.firestore.Timestamp.fromDate(startDate));
    }
    if (subjectFilter) {
      countQuery = countQuery.where('subject', '==', subjectFilter.charAt(0).toUpperCase() + subjectFilter.slice(1));
    }

    const totalSnapshot = await retryFirestoreOperation(async () => {
      return await countQuery.count().get();
    });
    const total = totalSnapshot.data().count;
    const hasMore = offset + limit < total;

    res.json({
      success: true,
      sessions: sessions,
      pagination: {
        limit: limit,
        offset: offset,
        total: total,
        has_more: hasMore
      },
      tier_info: {
        tier: tierInfo.tier,
        history_days_limit: tierHistoryDays,
        is_unlimited: tierHistoryDays === -1
      },
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
