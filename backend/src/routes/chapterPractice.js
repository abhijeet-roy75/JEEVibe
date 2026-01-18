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
const { canPracticeSubject, recordCompletion } = require('../services/weeklyChapterPracticeService');

const {
  calculateChapterThetaUpdate,
  calculateSubjectAndOverallThetaUpdate,
  calculateSubtopicAccuracyUpdate
} = require('../services/thetaUpdateService');

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
router.post('/generate', authenticateUser, validateGenerate, async (req, res, next) => {
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

    // Check weekly limit per subject (for free tier)
    const weeklyLimit = limits.chapter_practice_weekly_per_subject ?? -1;
    if (weeklyLimit !== -1) {
      // Get subject from chapter_key
      const mapping = await getDatabaseNames(chapter_key);
      const subject = mapping?.subject || chapter_key.split('_')[0];

      const canPractice = await canPracticeSubject(userId, subject);

      if (!canPractice.allowed) {
        logger.warn('Chapter practice weekly limit reached', {
          userId,
          subject,
          tier: tierInfo.tier,
          lastChapter: canPractice.last_chapter_name,
          unlocksAt: canPractice.unlocks_at
        });

        return res.status(403).json({
          success: false,
          error: {
            code: 'WEEKLY_LIMIT_REACHED',
            message: `You practiced ${canPractice.last_chapter_name} this week. Practice unlocks in ${canPractice.days_remaining} day${canPractice.days_remaining === 1 ? '' : 's'}.`,
            details: 'Free tier allows 1 chapter practice per subject per week'
          },
          subject: subject,
          last_chapter_name: canPractice.last_chapter_name,
          unlocks_at: canPractice.unlocks_at,
          days_remaining: canPractice.days_remaining,
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

      if (isExpired || !hasValidQuestions) {
        // Mark corrupted/expired session as invalidated and generate new one
        const reason = isExpired ? 'expired' : 'invalid_questions';
        logger.info('Active session invalidated, marking and generating new one', {
          userId,
          sessionId: activeSession.session_id,
          reason,
          expiresAt: activeSession.expires_at,
          questionCount: activeSession.questions?.length || 0
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
          chapterKey: chapter_key
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

    // Generate new session
    const sessionData = await generateChapterPractice(userId, chapter_key, question_count);

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
router.post('/submit-answer', authenticateUser, validateSubmitAnswer, async (req, res, next) => {
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
    try {
      questionData = await db.runTransaction(async (transaction) => {
        const qDoc = await transaction.get(questionDocRef);

        if (!qDoc.exists) {
          throw new ApiError(404, `Question ${question_id} not found in session`, 'QUESTION_NOT_FOUND');
        }

        const data = qDoc.data();

        if (data.answered) {
          throw new ApiError(400, `Question ${question_id} already answered`, 'QUESTION_ALREADY_ANSWERED');
        }

        // Mark as being answered to prevent concurrent submissions
        transaction.update(questionDocRef, { answering: true });

        return data;
      });
    } catch (error) {
      if (error instanceof ApiError) {
        throw error;
      }
      throw new ApiError(500, 'Failed to submit answer', 'TRANSACTION_FAILED');
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

    // Response document reference
    const responseRef = db.collection('chapter_practice_responses')
      .doc(userId)
      .collection('responses')
      .doc(`${session_id}_${question_id}`);

    // Use batch write for atomicity across all related updates
    // This ensures either all updates succeed or none do
    const batch = db.batch();

    // 1. Update question in session (clear answering flag and mark as answered)
    batch.update(questionDocRef, {
      answered: true,
      answering: admin.firestore.FieldValue.delete(),
      student_answer: student_answer,
      is_correct: isCorrect,
      correct_answer: correctAnswer,
      time_taken_seconds: time_taken_seconds,
      answered_at: admin.firestore.FieldValue.serverTimestamp(),
      theta_delta: adjustedThetaDelta
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
      answered_at: admin.firestore.FieldValue.serverTimestamp()
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
router.post('/complete', authenticateUser, validateSessionId, async (req, res, next) => {
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

    // Calculate subject and overall theta
    const subjectAndOverallUpdate = calculateSubjectAndOverallThetaUpdate(updatedThetaByChapter);

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

    // Update session as completed
    await retryFirestoreOperation(async () => {
      return await sessionRef.update({
        status: 'completed',
        completed_at: admin.firestore.FieldValue.serverTimestamp(),
        final_accuracy: accuracy,
        final_correct_count: correctCount,
        final_total_answered: totalAnswered,
        total_time_seconds: totalTime,
        theta_improvement: thetaImprovement
      });
    });

    // Update user with subject/overall theta, subtopic accuracy, and chapter practice stats
    await retryFirestoreOperation(async () => {
      return await userRef.update({
        theta_by_subject: subjectAndOverallUpdate.theta_by_subject,
        subject_accuracy: subjectAndOverallUpdate.subject_accuracy,
        overall_theta: subjectAndOverallUpdate.overall_theta,
        overall_percentile: subjectAndOverallUpdate.overall_percentile,
        subtopic_accuracy: updatedSubtopicAccuracy,
        chapter_practice_stats: updatedChapterPracticeStats,
        total_questions_solved: admin.firestore.FieldValue.increment(totalAnswered),
        total_time_spent_minutes: admin.firestore.FieldValue.increment(Math.round(totalTime / 60))
      });
    });

    // Record weekly usage for free tier (if weekly limit applies)
    const tierInfo = await getEffectiveTier(userId);
    const limits = await getTierLimits(tierInfo.tier);
    const weeklyLimit = limits.chapter_practice_weekly_per_subject ?? -1;
    if (weeklyLimit !== -1) {
      await recordCompletion(
        userId,
        sessionData.subject,
        sessionData.chapter_key,
        sessionData.chapter_name
      );
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
router.get('/session/:sessionId', authenticateUser, async (req, res, next) => {
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
router.get('/active', authenticateUser, async (req, res, next) => {
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
router.get('/stats', authenticateUser, async (req, res, next) => {
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

module.exports = router;
