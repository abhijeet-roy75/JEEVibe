/**
 * Daily Quiz Routes
 * 
 * API endpoints for daily adaptive quizzes:
 * - GET /api/daily-quiz/generate - Generate new quiz
 * - POST /api/daily-quiz/start - Start a quiz
 * - POST /api/daily-quiz/submit-answer - Submit answer for a question
 * - POST /api/daily-quiz/complete - Complete quiz and update theta
 * - GET /api/daily-quiz/active - Get active quiz
 */

const express = require('express');
const router = express.Router();
const { db, admin } = require('../config/firebase');
const { authenticateUser } = require('../middleware/auth');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { ApiError } = require('../middleware/errorHandler');
const { body, validationResult } = require('express-validator');

// Subscription & Usage Services
const { incrementUsage, decrementUsage, getUsage } = require('../services/usageTrackingService');

// Services
const { generateDailyQuiz } = require('../services/dailyQuizService');
const { submitAnswer, getQuizResponses } = require('../services/quizResponseService');
const {
  calculateChapterThetaUpdate,
  calculateSubjectAndOverallThetaUpdate,
  calculateSubtopicAccuracyUpdate,
  updateChapterTheta,
  updateSubjectAndOverallTheta
} = require('../services/thetaUpdateService');
const { updateFailureCount } = require('../services/circuitBreakerService');
const { updateReviewInterval } = require('../services/spacedRepetitionService');
const { formatChapterKey } = require('../services/thetaCalculationService');
const { getChapterProgress, getSubjectProgress, getAccuracyTrends, getCumulativeStats } = require('../services/progressService');
const { getStreak, updateStreak } = require('../services/streakService');
const { saveThetaSnapshot, getThetaSnapshots, getThetaSnapshotByQuizId, getChapterThetaProgression, getSubjectThetaProgression, getOverallThetaProgression } = require('../services/thetaSnapshotService');

// ============================================================================
// VALIDATION MIDDLEWARE
// ============================================================================

/**
 * Validation middleware helper - handles validation errors
 */
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    const firstError = errors.array()[0];
    return res.status(400).json({
      error: 'Validation failed',
      message: firstError.msg,
      field: firstError.path,
      code: 'VALIDATION_ERROR'
    });
  }
  next();
};

// Validation rules
const validateQuizId = [
  body('quiz_id')
    .trim()
    .notEmpty().withMessage('quiz_id is required')
    .isString().withMessage('quiz_id must be a string')
    .isLength({ min: 1, max: 100 }).withMessage('quiz_id must be between 1 and 100 characters')
    .matches(/^[a-zA-Z0-9_-]+$/).withMessage('quiz_id can only contain letters, numbers, hyphens, and underscores'),
  handleValidationErrors
];

const validateSubmitAnswer = [
  body('quiz_id')
    .trim()
    .notEmpty().withMessage('quiz_id is required')
    .isString().withMessage('quiz_id must be a string'),
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

// ============================================================================
// GENERATE QUIZ
// ============================================================================

/**
 * GET /api/daily-quiz/generate
 * 
 * Generate a new daily quiz for the user
 * Returns quiz questions (without answers)
 * 
 * Authentication: Required
 */
router.get('/generate', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;

    // Check if user has active quiz (in progress)
    const activeQuizRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .where('status', '==', 'in_progress')
      .limit(1);

    const activeQuizSnapshot = await retryFirestoreOperation(async () => {
      return await activeQuizRef.get();
    });

    if (!activeQuizSnapshot.empty) {
      const activeQuiz = activeQuizSnapshot.docs[0].data();
      const activeQuizId = activeQuizSnapshot.docs[0].id;

      // Fetch questions from subcollection
      const questionsSnapshot = await retryFirestoreOperation(async () => {
        return await db.collection('daily_quizzes')
          .doc(userId)
          .collection('quizzes')
          .doc(activeQuizId)
          .collection('questions')
          .orderBy('position', 'asc')
          .get();
      });

      const questions = questionsSnapshot.docs.map(doc => {
        const questionData = doc.data();
        // Remove sensitive fields (if any still present)
        const { correct_answer, correct_answer_text, solution_text, solution_steps, ...sanitized } = questionData;
        return sanitized;
      });

      return res.json({
        success: true,
        message: 'Active quiz found',
        quiz: {
          quiz_id: activeQuizId,
          quiz_number: activeQuiz.quiz_number,
          learning_phase: activeQuiz.learning_phase,
          questions,
          generated_at: activeQuiz.generated_at,
          is_recovery_quiz: activeQuiz.is_recovery_quiz || false
        },
        requestId: req.id
      });
    }

    // RACE CONDITION FIX: Reserve usage slot BEFORE generating quiz
    // This atomically checks limit AND increments in one transaction
    // If limit is reached, the increment is rejected and we return 429
    const usageReservation = await incrementUsage(userId, 'daily_quiz');

    if (!usageReservation.allowed) {
      logger.warn('Daily quiz limit reached', {
        userId,
        tier: usageReservation.tier,
        used: usageReservation.used,
        limit: usageReservation.limit
      });

      return res.status(429).json({
        success: false,
        error: {
          code: 'LIMIT_REACHED',
          message: usageReservation.tier === 'free'
            ? 'You have used your free daily quiz. Upgrade to Pro for 10 quizzes per day!'
            : `Daily limit of ${usageReservation.limit} quizzes reached. Come back tomorrow!`,
          details: `Daily quiz limit: ${usageReservation.limit} per day (resets at midnight IST)`
        },
        usage: {
          used: usageReservation.used,
          limit: usageReservation.limit,
          remaining: 0,
          resets_at: usageReservation.resets_at
        },
        tier: usageReservation.tier,
        upgrade_prompt: usageReservation.tier === 'free' ? {
          message: 'Upgrade to Pro for 10 daily quizzes',
          cta: 'Upgrade Now'
        } : null,
        requestId: req.id
      });
    }

    // Usage slot reserved successfully - now generate the quiz
    // If quiz generation fails, we rollback the usage reservation
    logger.info('Generating daily quiz (usage reserved)', {
      userId,
      usageUsed: usageReservation.used,
      usageLimit: usageReservation.limit,
      requestId: req.id
    });

    let quizData;
    try {
      quizData = await generateDailyQuiz(userId);
      logger.info('Daily quiz generated successfully', {
        userId,
        quizId: quizData.quiz_id,
        questionCount: quizData.questions?.length || 0,
        requestId: req.id
      });
    } catch (quizGenerationError) {
      // ROLLBACK: Quiz generation failed, restore the usage slot
      logger.error('Quiz generation failed, rolling back usage reservation', {
        userId,
        error: quizGenerationError.message,
        requestId: req.id
      });

      // Attempt to rollback - non-blocking (best effort)
      if (!usageReservation.is_unlimited) {
        decrementUsage(userId, 'daily_quiz').catch(rollbackError => {
          logger.error('Usage rollback failed', {
            userId,
            error: rollbackError.message,
            requestId: req.id
          });
        });
      }

      throw quizGenerationError;
    }

    // Save quiz to Firestore atomically using transaction to prevent concurrent generation
    const quizRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .doc(quizData.quiz_id);

    let savedQuizData = null;

    // Use transaction to atomically check and create quiz
    // Note: We already checked for active quiz above, so this prevents duplicate quiz_id creation
    try {
      await retryFirestoreOperation(async () => {
        return await db.runTransaction(async (transaction) => {
          // Check if quiz already exists (another request might have created it with same ID)
          const quizDoc = await transaction.get(quizRef);

          if (quizDoc.exists) {
            // Quiz already exists, get existing data
            savedQuizData = quizDoc.data();
            return; // Exit transaction without creating
          }

          // Create quiz metadata document (WITHOUT embedded questions array)
          const { questions, ...quizMetadata } = quizData;

          transaction.set(quizRef, {
            ...quizMetadata,
            student_id: userId,
            status: 'in_progress',
            started_at: null, // Will be set when quiz is started
            completed_at: null,
            total_time_seconds: 0,
            total_questions: questions.length,
            questions_answered: 0
          });

          savedQuizData = quizData; // Mark as saved
        });
      });

      // After transaction succeeds, save questions to subcollection
      // This happens AFTER quiz document is created, but before returning to user
      if (savedQuizData === quizData) {
        const batch = db.batch();

        quizData.questions.forEach((q, index) => {
          // Remove sensitive fields before storing
          const { solution_text, solution_steps, correct_answer, correct_answer_text, ...questionData } = q;

          const questionRef = quizRef.collection('questions').doc(String(index));
          batch.set(questionRef, {
            ...questionData,
            position: index,
            answered: false,
            student_answer: null,
            is_correct: null,
            time_taken_seconds: null,
            answered_at: null
          });
        });

        await batch.commit();
        logger.info('Quiz questions saved to subcollection', {
          userId,
          quizId: quizData.quiz_id,
          questionCount: quizData.questions.length
        });
      }
    } catch (error) {
      // If transaction failed, check if quiz was created by another request
      const existingQuizDoc = await retryFirestoreOperation(async () => {
        return await quizRef.get();
      });

      if (existingQuizDoc.exists) {
        savedQuizData = existingQuizDoc.data();
      } else {
        // Re-throw if it's not a transaction conflict
        throw error;
      }
    }

    // If quiz was already created by another request, use existing data
    if (savedQuizData && savedQuizData !== quizData) {
      // Fetch questions from subcollection
      const questionsSnapshot = await retryFirestoreOperation(async () => {
        return await quizRef.collection('questions')
          .orderBy('position', 'asc')
          .get();
      });

      const sanitizedQuestions = questionsSnapshot.docs.map(doc => {
        const questionData = doc.data();
        const { correct_answer, correct_answer_text, solution_text, solution_steps, ...sanitized } = questionData;
        return sanitized;
      });

      return res.json({
        success: true,
        quiz: {
          quiz_id: quizRef.id,
          quiz_number: savedQuizData.quiz_number,
          learning_phase: savedQuizData.learning_phase,
          questions: sanitizedQuestions,
          generated_at: savedQuizData.generated_at,
          is_recovery_quiz: savedQuizData.is_recovery_quiz || false
        },
        requestId: req.id
      });
    }

    // Return sanitized quiz (without answers)
    const sanitizedQuestions = quizData.questions.map(q => {
      const { correct_answer, correct_answer_text, solution_text, solution_steps, ...sanitized } = q;
      return sanitized;
    });

    // Log questions for debugging
    if (sanitizedQuestions) {
      sanitizedQuestions.forEach((q, i) => {
        logger.info(`Sending Question ${i + 1}`, {
          id: q.question_id,
          type: q.question_type,
          has_options: !!q.options,
          options_count: q.options?.length
        });
      });
    }

    // Usage was already reserved at the beginning - use those values
    res.json({
      success: true,
      quiz: {
        quiz_id: quizData.quiz_id,
        quiz_number: quizData.quiz_number,
        learning_phase: quizData.learning_phase,
        questions: sanitizedQuestions,
        generated_at: quizData.generated_at,
        is_recovery_quiz: quizData.is_recovery_quiz || false
      },
      usage: {
        daily_quiz: {
          used: usageReservation.used,
          limit: usageReservation.limit,
          remaining: usageReservation.is_unlimited ? -1 : usageReservation.remaining,
          is_unlimited: usageReservation.is_unlimited,
          resets_at: usageReservation.resets_at
        }
      },
      tier: usageReservation.tier,
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// START QUIZ
// ============================================================================

/**
 * POST /api/daily-quiz/start
 * 
 * Start a quiz (mark as started)
 * 
 * Body: { quiz_id: string }
 * Authentication: Required
 */
router.post('/start', authenticateUser, validateQuizId, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { quiz_id } = req.body;

    if (!quiz_id) {
      throw new ApiError(400, 'quiz_id is required', 'MISSING_QUIZ_ID');
    }

    const quizRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .doc(quiz_id);

    const quizDoc = await retryFirestoreOperation(async () => {
      return await quizRef.get();
    });

    if (!quizDoc.exists) {
      throw new ApiError(404, `Quiz ${quiz_id} not found`, 'QUIZ_NOT_FOUND');
    }

    const quizData = quizDoc.data();

    if (quizData.status !== 'in_progress') {
      throw new ApiError(400, `Quiz ${quiz_id} is not in progress. Status: ${quizData.status}`, 'QUIZ_NOT_IN_PROGRESS');
    }

    // Update quiz with started_at timestamp
    await retryFirestoreOperation(async () => {
      return await quizRef.update({
        started_at: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    res.json({
      success: true,
      message: 'Quiz started',
      quiz_id: quiz_id,
      started_at: new Date().toISOString(),
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
 * POST /api/daily-quiz/submit-answer
 * 
 * Submit answer for a question in active quiz
 * Returns immediate feedback (correct/incorrect + explanation)
 * 
 * Body: {
 *   quiz_id: string,
 *   question_id: string,
 *   student_answer: string,
 *   time_taken_seconds: number
 * }
 * Authentication: Required
 */
router.post('/submit-answer', authenticateUser, validateSubmitAnswer, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { quiz_id, question_id, student_answer, time_taken_seconds } = req.body;

    if (!quiz_id || !question_id || student_answer === undefined || time_taken_seconds === undefined) {
      throw new ApiError(400, 'quiz_id, question_id, student_answer, and time_taken_seconds are required', 'MISSING_REQUIRED_FIELDS');
    }

    const feedback = await submitAnswer(userId, quiz_id, question_id, student_answer, time_taken_seconds);

    res.json({
      success: true,
      ...feedback,
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// COMPLETE QUIZ
// ============================================================================

/**
 * POST /api/daily-quiz/complete
 * 
 * Complete a quiz and update theta values
 * Processes all responses in batch and updates chapter/subject/overall theta
 * 
 * Body: { quiz_id: string }
 * Authentication: Required
 */
router.post('/complete', authenticateUser, validateQuizId, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { quiz_id } = req.body;

    if (!quiz_id) {
      throw new ApiError(400, 'quiz_id is required', 'MISSING_QUIZ_ID');
    }

    // Get quiz and responses
    const quizRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .doc(quiz_id);
    const userRef = db.collection('users').doc(userId);

    // Get all responses first (before transaction)
    const responses = await getQuizResponses(userId, quiz_id);

    if (responses.length === 0) {
      throw new ApiError(400, 'No responses found in quiz', 'NO_RESPONSES_FOUND');
    }

    // Calculate quiz statistics
    const correctCount = responses.filter(r => r.is_correct).length;
    const totalCount = responses.length;
    const accuracy = totalCount > 0 ? correctCount / totalCount : 0;
    const totalTime = responses.reduce((sum, r) => sum + (r.time_taken_seconds || 0), 0);
    const avgTimePerQuestion = totalCount > 0 ? Math.round(totalTime / totalCount) : 0;
    const quizPassed = accuracy >= 0.5;

    // Group responses by chapter
    const responsesByChapter = {};
    responses.forEach(response => {
      const chapterKey = response.chapter_key;
      if (!chapterKey) {
        logger.warn('Response missing chapter_key', { question_id: response.question_id });
        return;
      }
      if (!responsesByChapter[chapterKey]) {
        responsesByChapter[chapterKey] = [];
      }
      responsesByChapter[chapterKey].push(response);
    });

    // ========================================================================
    // PHASE 1: Fetch current user data BEFORE transaction
    // ========================================================================
    const userDocSnapshot = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    if (!userDocSnapshot.exists) {
      throw new ApiError(404, `User ${userId} not found`, 'USER_NOT_FOUND');
    }

    const currentUserData = userDocSnapshot.data();
    const currentThetaByChapter = currentUserData.theta_by_chapter || {};

    // ========================================================================
    // DAILY QUIZ LOGGING - BEFORE
    // ========================================================================
    logger.info('🔵 [DAILY QUIZ] THETA UPDATE - BEFORE', {
      userId,
      quizId: quiz_id,
      chaptersInQuiz: Object.keys(responsesByChapter),
      totalResponses: responses.length,
      correctCount,
      BEFORE: {
        overall_theta: currentUserData.overall_theta,
        overall_percentile: currentUserData.overall_percentile,
        total_questions_solved: currentUserData.total_questions_solved,
        theta_by_subject: {
          physics: currentUserData.theta_by_subject?.physics?.theta,
          chemistry: currentUserData.theta_by_subject?.chemistry?.theta,
          mathematics: currentUserData.theta_by_subject?.mathematics?.theta
        }
      }
    });

    // ========================================================================
    // PHASE 2: Pre-calculate all theta updates BEFORE transaction
    // ========================================================================
    const updatedThetaByChapter = { ...currentThetaByChapter };
    const chapterUpdateResults = {};

    // Calculate theta for each chapter
    for (const [chapterKey, chapterResponses] of Object.entries(responsesByChapter)) {
      try {
        // Get current chapter data or use defaults
        const currentChapterData = currentThetaByChapter[chapterKey] || {
          theta: 0.0,
          percentile: 50.0,
          confidence_SE: 0.6,
          attempts: 0,
          accuracy: 0.0,
          last_updated: new Date().toISOString()
        };

        // Prepare responses with IRT parameters
        const responsesWithIRT = chapterResponses.map(r => ({
          questionIRT: r.question_irt_params || { a: 1.0, b: 0.0, c: 0.25 },
          isCorrect: r.is_correct
        }));

        // Calculate new theta (pure function, no Firestore write)
        const chapterUpdate = calculateChapterThetaUpdate(currentChapterData, responsesWithIRT);

        // Store calculated update
        updatedThetaByChapter[chapterKey] = chapterUpdate;
        chapterUpdateResults[chapterKey] = {
          theta_before: currentChapterData.theta,
          theta_after: chapterUpdate.theta,
          theta_delta: chapterUpdate.theta_delta
        };

        logger.info('Pre-calculated chapter theta update', {
          userId,
          chapterKey,
          theta_before: currentChapterData.theta,
          theta_after: chapterUpdate.theta,
          responses_count: responsesWithIRT.length
        });
      } catch (error) {
        logger.error('Error pre-calculating chapter theta', {
          userId,
          chapterKey,
          error: error.message,
          stack: error.stack
        });
        throw new ApiError(500, `Failed to calculate theta for ${chapterKey}`, 'THETA_CALCULATION_ERROR');
      }
    }

    // ========================================================================
    // PHASE 3: Calculate subject and overall theta updates
    // ========================================================================
    let subjectAndOverallUpdate;
    try {
      subjectAndOverallUpdate = calculateSubjectAndOverallThetaUpdate(updatedThetaByChapter);

      // ========================================================================
      // DAILY QUIZ LOGGING - AFTER (calculated, before write)
      // ========================================================================
      logger.info('🟢 [DAILY QUIZ] THETA UPDATE - AFTER (calculated)', {
        userId,
        quizId: quiz_id,
        chapterUpdates: chapterUpdateResults,
        AFTER: {
          overall_theta: subjectAndOverallUpdate.overall_theta,
          overall_percentile: subjectAndOverallUpdate.overall_percentile,
          theta_by_subject: {
            physics: subjectAndOverallUpdate.theta_by_subject?.physics?.theta,
            chemistry: subjectAndOverallUpdate.theta_by_subject?.chemistry?.theta,
            mathematics: subjectAndOverallUpdate.theta_by_subject?.mathematics?.theta
          }
        }
      });
    } catch (error) {
      logger.error('Error pre-calculating subject/overall theta', {
        userId,
        error: error.message,
        stack: error.stack
      });
      throw new ApiError(500, 'Failed to calculate overall theta', 'THETA_CALCULATION_ERROR');
    }

    // ========================================================================
    // PHASE 3.5: Calculate subtopic accuracy updates
    // ========================================================================
    const currentSubtopicAccuracy = currentUserData.subtopic_accuracy || {};
    const updatedSubtopicAccuracy = calculateSubtopicAccuracyUpdate(currentSubtopicAccuracy, responses);

    logger.info('Pre-calculated subtopic accuracy', {
      userId,
      chaptersWithSubtopics: Object.keys(updatedSubtopicAccuracy).length
    });

    // ========================================================================
    // PHASE 4: Execute SINGLE atomic transaction with ALL updates
    // ========================================================================
    await retryFirestoreOperation(async () => {
      return await db.runTransaction(async (transaction) => {
        // Read quiz and user documents in transaction
        const quizDoc = await transaction.get(quizRef);
        const userDoc = await transaction.get(userRef);

        if (!quizDoc.exists) {
          throw new ApiError(404, `Quiz ${quiz_id} not found`, 'QUIZ_NOT_FOUND');
        }

        const quizData = quizDoc.data();

        // Security: Verify quiz belongs to authenticated user (defense in depth)
        // The Firestore path already scopes to the user, but this explicit check
        // protects against potential bugs in path construction
        if (quizData.student_id && quizData.student_id !== userId) {
          logger.warn('Quiz ownership mismatch detected', {
            requestId: req.id,
            userId,
            quizStudentId: quizData.student_id,
            quizId: quiz_id
          });
          throw new ApiError(403, 'Access denied: Quiz belongs to another user', 'FORBIDDEN');
        }

        // Check if already completed (atomic check)
        if (quizData.status === 'completed') {
          throw new ApiError(400, `Quiz ${quiz_id} is already completed`, 'QUIZ_ALREADY_COMPLETED');
        }

        if (!userDoc.exists) {
          throw new ApiError(404, `User ${userId} not found`, 'USER_NOT_FOUND');
        }

        const userData = userDoc.data();
        const completedQuizCount = userData.completed_quiz_count || 0;
        const newQuizCount = completedQuizCount + 1;

        // Calculate learning phase
        const assessmentDate = userData.assessment?.completed_at
          ? new Date(userData.assessment.completed_at)
          : new Date();
        const currentDate = new Date();
        const daysSinceAssessment = Math.floor((currentDate - assessmentDate) / (1000 * 60 * 60 * 24));
        const learningPhase = newQuizCount < 14 ? 'exploration' : 'exploitation';
        const chaptersCovered = Object.keys(responsesByChapter);

        // Update quiz document atomically
        transaction.update(quizRef, {
          status: 'completed',
          completed_at: admin.firestore.FieldValue.serverTimestamp(),
          total_time_seconds: totalTime,
          score: correctCount,
          accuracy: Math.round(accuracy * 1000) / 1000,
          avg_time_per_question: avgTimePerQuestion,
          chapters_covered: chaptersCovered,
          exploration_questions: responses.filter(r => r.selection_reason === 'exploration').length,
          deliberate_practice_questions: responses.filter(r => r.selection_reason === 'deliberate_practice').length,
          review_questions: responses.filter(r => r.selection_reason === 'review').length
        });

        // Update user document atomically with ALL updates
        transaction.update(userRef, {
          // Existing user stats
          completed_quiz_count: newQuizCount,
          current_day: daysSinceAssessment + 1,
          learning_phase: learningPhase,
          phase_switched_at_quiz: learningPhase === 'exploitation' && completedQuizCount < 14 ? 14 : userData.phase_switched_at_quiz,
          last_quiz_completed_at: admin.firestore.FieldValue.serverTimestamp(),
          total_questions_solved: admin.firestore.FieldValue.increment(totalCount),
          total_time_spent_minutes: admin.firestore.FieldValue.increment(Math.round(totalTime / 60)),

          // Theta updates (atomic with quiz completion)
          theta_by_chapter: updatedThetaByChapter,
          theta_by_subject: subjectAndOverallUpdate.theta_by_subject,
          subject_accuracy: subjectAndOverallUpdate.subject_accuracy,
          overall_theta: subjectAndOverallUpdate.overall_theta,
          overall_percentile: subjectAndOverallUpdate.overall_percentile,

          // Subtopic accuracy tracking
          subtopic_accuracy: updatedSubtopicAccuracy,

          // NEW: Cumulative stats (denormalized for Progress API optimization)
          'cumulative_stats.total_questions_correct': admin.firestore.FieldValue.increment(correctCount),
          'cumulative_stats.total_questions_attempted': admin.firestore.FieldValue.increment(totalCount),
          'cumulative_stats.last_updated': admin.firestore.FieldValue.serverTimestamp()
        });

        logger.info('Quiz completed with atomic theta updates', {
          userId,
          quiz_id,
          chapters_updated: Object.keys(chapterUpdateResults),
          overall_theta: subjectAndOverallUpdate.overall_theta
        });
      });
    });

    // Update practice streak
    try {
      await updateStreak(userId);
    } catch (error) {
      logger.error('Error updating streak', {
        userId,
        error: error.message
      });
    }

    // Update failure count (circuit breaker)
    try {
      await updateFailureCount(userId, quizPassed);
    } catch (error) {
      logger.error('Error updating failure count', {
        userId,
        error: error.message
      });
    }

    // PERFORMANCE: Batch update review intervals for incorrect answers
    // Previously: N sequential writes (one per incorrect answer)
    // Now: Single batched write (reduces network calls by N-1)
    const incorrectResponses = responses.filter(r => !r.is_correct && r.question_id);
    if (incorrectResponses.length > 0) {
      try {
        const batch = db.batch();
        for (const response of incorrectResponses) {
          const reviewRef = db.collection('users')
            .doc(userId)
            .collection('review_intervals')
            .doc(response.question_id);

          // Calculate new interval (same logic as updateReviewInterval)
          const newInterval = 1; // Reset to 1 day for incorrect answers
          batch.set(reviewRef, {
            question_id: response.question_id,
            interval: newInterval,
            next_review: new Date(Date.now() + newInterval * 24 * 60 * 60 * 1000),
            last_reviewed: new Date(),
            times_reviewed: db.FieldValue.increment(1)
          }, { merge: true });
        }
        await batch.commit();
      } catch (error) {
        logger.warn('Error batch updating review intervals', {
          userId,
          count: incorrectResponses.length,
          error: error.message
        });
      }
    }

    // Get final user data and quiz data for response
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });
    const userData = userDoc.data();
    const newQuizCount = (userData.completed_quiz_count || 0);

    // Get quiz data again (needed for metadata)
    const quizDoc = await retryFirestoreOperation(async () => {
      return await quizRef.get();
    });
    const quizData = quizDoc.data();

    // ========================================================================
    // Save theta snapshot for analytics (non-blocking)
    // ========================================================================
    try {
      await saveThetaSnapshot(userId, quiz_id, {
        quiz_number: quizData.quiz_number,
        theta_by_chapter: updatedThetaByChapter,
        theta_by_subject: subjectAndOverallUpdate.theta_by_subject,
        overall_theta: subjectAndOverallUpdate.overall_theta,
        overall_percentile: subjectAndOverallUpdate.overall_percentile,
        quiz_performance: {
          score: correctCount,
          total: totalCount,
          accuracy: accuracy,
          total_time_seconds: totalTime,
          chapters_tested: Object.keys(responsesByChapter)
        },
        chapter_updates: chapterUpdateResults
      });
      logger.info('Theta snapshot saved for analytics', {
        userId,
        quizId: quiz_id,
        quizNumber: quizData.quiz_number,
        chapters_updated: Object.keys(chapterUpdateResults).length
      });
    } catch (error) {
      // Non-blocking - log error but don't fail the request
      logger.error('Error saving theta snapshot (non-blocking)', {
        userId,
        quizId: quiz_id,
        error: error.message,
        stack: error.stack
      });
    }

    // Get questions from subcollection for saving responses
    const questionsSnapshot = await retryFirestoreOperation(async () => {
      return await quizRef.collection('questions').get();
    });
    const questionsMap = {};
    questionsSnapshot.docs.forEach(doc => {
      const questionData = doc.data();
      questionsMap[questionData.question_id] = questionData;
    });

    // Save individual responses to daily_quiz_responses collection
    const responsesRef = db.collection('daily_quiz_responses')
      .doc(userId)
      .collection('responses');

    let batch = db.batch(); // Initialize first batch
    let batchCount = 0;

    for (const response of responses) {
      const responseId = `${quiz_id}_${response.question_id}`;
      const responseRef = responsesRef.doc(responseId);

      const questionData = questionsMap[response.question_id] || {};

      batch.set(responseRef, {
        response_id: responseId,
        student_id: userId,
        question_id: response.question_id,
        quiz_id: quiz_id,
        quiz_number: quizData.quiz_number,
        question_position: questionData.position || 0,
        learning_phase: quizData.learning_phase,
        selection_reason: questionData.selection_reason || 'unknown',

        // Chapter metadata
        subject: questionData.subject,
        chapter: questionData.chapter,
        chapter_key: response.chapter_key,

        // IRT parameters (denormalized)
        difficulty_b: response.question_irt_params.b,
        discrimination_a: response.question_irt_params.a,
        guessing_c: response.question_irt_params.c,

        // Response details
        student_answer: response.student_answer,
        correct_answer: response.correct_answer,
        is_correct: response.is_correct,
        time_taken_seconds: response.time_taken_seconds,

        // Review interval (for spaced repetition)
        review_interval: response.is_correct ? null : 1, // Start at 1 day if incorrect

        // Timestamps
        answered_at: admin.firestore.FieldValue.serverTimestamp(),
        created_at: admin.firestore.FieldValue.serverTimestamp()
      });

      batchCount++;

      // Firestore batch limit is 500
      if (batchCount >= 500) {
        await retryFirestoreOperation(async () => {
          return await batch.commit();
        });
        batch = db.batch(); // Create new batch after commit
        batchCount = 0;
      }
    }

    // Commit remaining batch
    if (batchCount > 0) {
      await retryFirestoreOperation(async () => {
        return await batch.commit();
      });
    }

    logger.info('Quiz completed', {
      userId,
      quizId: quiz_id,
      quizNumber: newQuizCount,
      accuracy,
      correctCount,
      totalCount
    });

    res.json({
      success: true,
      message: 'Quiz completed',
      quiz_id: quiz_id,
      quiz_number: newQuizCount,
      accuracy: Math.round(accuracy * 1000) / 1000,
      score: correctCount,
      total: totalCount,
      chapters_updated: Object.keys(chapterUpdateResults).length,
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// GET ACTIVE QUIZ
// ============================================================================

/**
 * GET /api/daily-quiz/active
 * 
 * Get active quiz for user (if any)
 * Authentication: Required
 */
router.get('/active', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;

    const activeQuizRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .where('status', '==', 'in_progress')
      .orderBy('generated_at', 'desc')
      .limit(1);

    const activeQuizSnapshot = await retryFirestoreOperation(async () => {
      return await activeQuizRef.get();
    });

    if (activeQuizSnapshot.empty) {
      return res.json({
        success: true,
        has_active_quiz: false,
        quiz: null,
        requestId: req.id
      });
    }

    const activeQuiz = activeQuizSnapshot.docs[0].data();
    const quizId = activeQuizSnapshot.docs[0].id;

    // Fetch questions from subcollection
    // PERFORMANCE: Add limit(15) to prevent loading all 90 questions for mock tests
    // Daily quizzes typically have 5-10 questions, mock tests can have 90
    const questionsSnapshot = await retryFirestoreOperation(async () => {
      return await db.collection('daily_quizzes')
        .doc(userId)
        .collection('quizzes')
        .doc(quizId)
        .collection('questions')
        .orderBy('position', 'asc')
        .limit(15) // Limit initial fetch to reduce payload size
        .get();
    });

    // Sanitize questions (remove answers)
    const sanitizedQuestions = questionsSnapshot.docs.map(doc => {
      const questionData = doc.data();
      const { correct_answer, correct_answer_text, solution_text, solution_steps, ...sanitized } = questionData;
      return sanitized;
    });

    res.json({
      success: true,
      has_active_quiz: true,
      quiz: {
        quiz_id: quizId,
        quiz_number: activeQuiz.quiz_number,
        learning_phase: activeQuiz.learning_phase,
        questions: sanitizedQuestions,
        generated_at: activeQuiz.generated_at,
        started_at: activeQuiz.started_at,
        is_recovery_quiz: activeQuiz.is_recovery_quiz || false
      },
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// PROGRESS & STATS
// ============================================================================

/**
 * GET /api/daily-quiz/progress
 * 
 * Get progress data for home page display
 * Includes chapter progress, subject progress, and overall stats
 * 
 * Authentication: Required
 */
router.get('/progress', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;

    // Get user data for overall theta
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    const userData = userDoc.exists ? userDoc.data() : {};

    // Get all progress data in parallel
    const [chapterProgress, subjectProgress, cumulativeStats, streak] = await Promise.all([
      getChapterProgress(userId),
      getSubjectProgress(userId),
      getCumulativeStats(userId),
      getStreak(userId)
    ]);

    res.json({
      success: true,
      progress: {
        chapters: chapterProgress,
        subjects: subjectProgress,
        overall: {
          theta: userData.overall_theta || 0,
          percentile: userData.overall_percentile || 50,
          accuracy: cumulativeStats.overall_accuracy || 0
        },
        cumulative: cumulativeStats,
        streak: streak
      },
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/daily-quiz/stats
 * 
 * Get detailed statistics and trends
 * Includes accuracy trends, chapter improvements, etc.
 * 
 * Query params:
 * - days: Number of days for trends (default: 30)
 * 
 * Authentication: Required
 */
router.get('/stats', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    const days = parseInt(req.query.days) || 30;

    const [accuracyTrends, chapterProgress, subjectProgress, cumulativeStats, streak] = await Promise.all([
      getAccuracyTrends(userId, days),
      getChapterProgress(userId),
      getSubjectProgress(userId),
      getCumulativeStats(userId),
      getStreak(userId)
    ]);

    // Calculate chapter improvements
    const chapterImprovements = Object.values(chapterProgress)
      .filter(ch => ch.theta_change > 0)
      .sort((a, b) => b.theta_change - a.theta_change)
      .slice(0, 5); // Top 5 improvements

    res.json({
      success: true,
      stats: {
        accuracy_trends: accuracyTrends,
        chapter_progress: chapterProgress,
        subject_progress: subjectProgress,
        chapter_improvements: chapterImprovements,
        cumulative: cumulativeStats,
        streak: streak
      },
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// QUIZ HISTORY
// ============================================================================

/**
 * GET /api/daily-quiz/history
 * 
 * Get quiz history for the user
 * Returns list of completed quizzes with pagination
 * 
 * Query params:
 * - limit: Number of quizzes to return (default: 20, max: 50)
 * - offset: Number of quizzes to skip (default: 0)
 * - start_date: Filter quizzes from this date (ISO string)
 * - end_date: Filter quizzes until this date (ISO string)
 * 
 * Authentication: Required
 */
router.get('/history', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    const limit = Math.min(parseInt(req.query.limit) || 20, 50);
    const offset = parseInt(req.query.offset) || 0;

    // Validate and parse date parameters
    function validateDate(dateString, paramName) {
      if (!dateString) return null;
      const date = new Date(dateString);
      if (isNaN(date.getTime())) {
        throw new ApiError(400, `Invalid ${paramName} format. Expected ISO 8601 date string (e.g., 2024-12-10T00:00:00Z)`, 'INVALID_DATE_FORMAT');
      }
      return date;
    }

    const startDate = validateDate(req.query.start_date, 'start_date');
    const endDate = validateDate(req.query.end_date, 'end_date');

    // Validate date range
    if (startDate && endDate && startDate > endDate) {
      throw new ApiError(400, 'start_date must be before or equal to end_date', 'INVALID_DATE_RANGE');
    }

    // Validate pagination parameters
    if (limit < 1 || limit > 50) {
      throw new ApiError(400, 'limit must be between 1 and 50', 'INVALID_LIMIT');
    }
    if (offset < 0) {
      throw new ApiError(400, 'offset must be >= 0', 'INVALID_OFFSET');
    }

    // Firestore doesn't support efficient offset for large values
    // For offsets > 100, recommend cursor-based pagination
    if (offset > 100) {
      throw new ApiError(400,
        'Offset > 100 not supported. Use cursor-based pagination with last_quiz_id parameter for better performance',
        'OFFSET_TOO_LARGE'
      );
    }

    const quizzesRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .where('status', '==', 'completed');

    // Apply date filters if provided
    let query = quizzesRef;
    if (startDate) {
      query = query.where('completed_at', '>=', admin.firestore.Timestamp.fromDate(startDate));
    }
    if (endDate) {
      query = query.where('completed_at', '<=', admin.firestore.Timestamp.fromDate(endDate));
    }

    // Order by completed_at descending and apply pagination
    query = query
      .orderBy('completed_at', 'desc')
      .limit(limit + offset);

    const snapshot = await retryFirestoreOperation(async () => {
      return await query.get();
    });

    // Apply offset manually (Firestore doesn't support offset directly)
    const allQuizzes = snapshot.docs.slice(offset, offset + limit);

    const quizzes = allQuizzes.map(doc => {
      const data = doc.data();
      return {
        quiz_id: doc.id,
        quiz_number: data.quiz_number,
        completed_at: data.completed_at?.toDate?.()?.toISOString() || data.completed_at,
        accuracy: data.accuracy || 0,
        score: data.score || 0,
        total: data.total_questions || 0,
        total_time_seconds: data.total_time_seconds || 0,
        learning_phase: data.learning_phase,
        is_recovery_quiz: data.is_recovery_quiz || false,
        chapters_covered: data.chapters_covered || [],
        exploration_questions: data.exploration_questions || 0,
        deliberate_practice_questions: data.deliberate_practice_questions || 0,
        review_questions: data.review_questions || 0
      };
    });

    // Get total count (for pagination info) - apply same filters
    let countQuery = quizzesRef;
    if (startDate) {
      countQuery = countQuery.where('completed_at', '>=', admin.firestore.Timestamp.fromDate(startDate));
    }
    if (endDate) {
      countQuery = countQuery.where('completed_at', '<=', admin.firestore.Timestamp.fromDate(endDate));
    }

    const totalSnapshot = await retryFirestoreOperation(async () => {
      return await countQuery.count().get();
    });
    const total = totalSnapshot.data().count;
    const hasMore = offset + limit < total;

    res.json({
      success: true,
      quizzes: quizzes,
      pagination: {
        limit: limit,
        offset: offset,
        total: total,
        has_more: hasMore
      },
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// QUIZ RESULT (Individual Quiz Details)
// ============================================================================

/**
 * GET /api/daily-quiz/result/:quiz_id
 * 
 * Get detailed result of a completed quiz
 * Includes all questions with answers and solutions
 * 
 * Authentication: Required
 */
router.get('/result/:quiz_id', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { quiz_id } = req.params;

    const quizRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .doc(quiz_id);

    const quizDoc = await retryFirestoreOperation(async () => {
      return await quizRef.get();
    });

    if (!quizDoc.exists) {
      throw new ApiError(404, `Quiz ${quiz_id} not found`, 'QUIZ_NOT_FOUND');
    }

    const quizData = quizDoc.data();

    // Security: Verify quiz belongs to authenticated user (defense in depth)
    if (quizData.student_id && quizData.student_id !== userId) {
      throw new ApiError(403, 'Access denied: Quiz belongs to another user', 'FORBIDDEN');
    }

    // Only return results for completed quizzes
    if (quizData.status !== 'completed') {
      throw new ApiError(400, `Quiz ${quiz_id} is not completed. Status: ${quizData.status}`, 'QUIZ_NOT_COMPLETED');
    }

    // Get questions from subcollection
    const questionsSnapshot = await retryFirestoreOperation(async () => {
      return await quizRef.collection('questions')
        .orderBy('position', 'asc')
        .get();
    });

    if (questionsSnapshot.empty) {
      throw new ApiError(400, 'Quiz has no questions', 'NO_QUESTIONS_IN_QUIZ');
    }

    const quizQuestions = questionsSnapshot.docs.map(doc => doc.data());
    const questionIds = quizQuestions.map(q => q.question_id).filter(Boolean);

    // Batch read all questions from questions collection for full details (solutions, etc.)
    const questionRefs = questionIds.map(id => db.collection('questions').doc(id));
    const questionDocs = await retryFirestoreOperation(async () => {
      return await db.getAll(...questionRefs);
    });

    // Create lookup map for O(1) access
    const questionMap = new Map();
    questionDocs.forEach(doc => {
      if (doc.exists) {
        questionMap.set(doc.id, doc.data());
      }
    });

    // Get streak data for the result
    const streak = await getStreak(userId);

    // Map questions with details
    const questionsWithDetails = quizQuestions.map(q => {
      const questionData = questionMap.get(q.question_id);

      if (questionData) {
        // Full question data available
        return {
          question_id: q.question_id,
          position: q.position || 0,
          subject: questionData.subject || q.subject,
          chapter: questionData.chapter || q.chapter,
          question_text: questionData.question_text,
          question_text_html: questionData.question_text_html,
          question_type: questionData.question_type,
          options: questionData.options || [],
          image_url: questionData.image_url,

          // Response data
          student_answer: q.student_answer,
          correct_answer: q.correct_answer || questionData.correct_answer,
          correct_answer_text: questionData.correct_answer_text,
          is_correct: q.is_correct,
          time_taken_seconds: q.time_taken_seconds,

          // Solution data
          solution_text: questionData.solution_text,
          solution_steps: questionData.solution_steps || [],
          concepts_tested: questionData.concepts_tested || [],

          // "Why wrong" analysis data
          distractor_analysis: questionData.distractor_analysis || null,
          common_mistakes: questionData.metadata?.common_mistakes || questionData.common_mistakes || null,

          // Metadata
          difficulty: questionData.difficulty || null,
          selection_reason: q.selection_reason,
          chapter_key: q.chapter_key
        };
      } else {
        // Fallback to quiz data if question not found
        logger.warn('Question not found in database', {
          questionId: q.question_id,
          quizId: quiz_id
        });
        return {
          question_id: q.question_id,
          position: q.position || 0,
          subject: q.subject,
          chapter: q.chapter,
          student_answer: q.student_answer,
          correct_answer: q.correct_answer,
          is_correct: q.is_correct,
          time_taken_seconds: q.time_taken_seconds,
          selection_reason: q.selection_reason,
          chapter_key: q.chapter_key,
          note: 'Full question details not available in database'
        };
      }
    });

    res.json({
      success: true,
      quiz: {
        quiz_id: quiz_id,
        quiz_number: quizData.quiz_number,
        completed_at: quizData.completed_at?.toDate?.()?.toISOString() || quizData.completed_at,
        started_at: quizData.started_at?.toDate?.()?.toISOString() || quizData.started_at,
        generated_at: quizData.generated_at,
        accuracy: quizData.accuracy || 0,
        score: quizData.score || 0,
        total: quizData.total_questions || quizQuestions.length || 0,
        total_time_seconds: quizData.total_time_seconds || 0,
        avg_time_per_question: quizData.avg_time_per_question || 0,
        learning_phase: quizData.learning_phase,
        is_recovery_quiz: quizData.is_recovery_quiz || false,
        chapters_covered: quizData.chapters_covered || [],
        exploration_questions: quizData.exploration_questions || 0,
        deliberate_practice_questions: quizData.deliberate_practice_questions || 0,
        review_questions: quizData.review_questions || 0,
        questions: questionsWithDetails
      },
      streak: streak,
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// QUESTION DETAILS
// ============================================================================

/**
 * GET /api/daily-quiz/question/:question_id
 * 
 * Get full details of a question including solution
 * 
 * Query params:
 * - include_solution: Include solution (default: true)
 * 
 * Authentication: Required
 */
router.get('/question/:question_id', authenticateUser, async (req, res, next) => {
  try {
    // Validate question_id parameter
    function validateQuestionId(questionId) {
      if (!questionId || typeof questionId !== 'string') {
        throw new ApiError(400, 'question_id is required and must be a string', 'INVALID_QUESTION_ID');
      }
      if (questionId.length > 200) {
        throw new ApiError(400, 'question_id too long (max 200 characters)', 'INVALID_QUESTION_ID');
      }
      // Validate format (alphanumeric, underscore, dash, dot)
      if (!/^[a-zA-Z0-9_.-]+$/.test(questionId)) {
        throw new ApiError(400, 'question_id contains invalid characters. Only alphanumeric, underscore, dash, and dot are allowed', 'INVALID_QUESTION_ID');
      }
      return questionId;
    }

    const question_id = validateQuestionId(req.params.question_id);
    const includeSolution = req.query.include_solution !== 'false';

    const questionRef = db.collection('questions').doc(question_id);
    const questionDoc = await retryFirestoreOperation(async () => {
      return await questionRef.get();
    });

    if (!questionDoc.exists) {
      throw new ApiError(404, `Question ${question_id} not found`, 'QUESTION_NOT_FOUND');
    }

    const questionData = questionDoc.data();

    const response = {
      success: true,
      question: {
        question_id: question_id,
        subject: questionData.subject,
        chapter: questionData.chapter,
        topic: questionData.topic,
        unit: questionData.unit,
        sub_topics: questionData.sub_topics || [],
        question_type: questionData.question_type,
        question_text: questionData.question_text,
        question_text_html: questionData.question_text_html,
        question_latex: questionData.question_latex,
        options: questionData.options || [],
        correct_answer: questionData.correct_answer,
        correct_answer_text: questionData.correct_answer_text,
        correct_answer_exact: questionData.correct_answer_exact,
        answer_range: questionData.answer_range,
        image_url: questionData.image_url,
        has_image: questionData.has_image || false,
        difficulty: questionData.difficulty,
        time_estimate: questionData.time_estimate,
        weightage_marks: questionData.weightage_marks,
        concepts_tested: questionData.concepts_tested || [],
        tags: questionData.tags || [],
        irt_parameters: questionData.irt_parameters || {
          difficulty_b: questionData.difficulty_irt || 0,
          discrimination_a: 1.5,
          guessing_c: questionData.question_type === 'mcq_single' ? 0.25 : 0.0
        }
      },
      requestId: req.id
    };

    // Include solution if requested
    if (includeSolution) {
      response.question.solution_text = questionData.solution_text;
      response.question.solution_steps = questionData.solution_steps || [];
    }

    res.json(response);
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// QUIZ SUMMARY
// ============================================================================

/**
 * GET /api/daily-quiz/summary
 * 
 * Get quick summary for dashboard/home screen
 * Includes active quiz status, today's stats, and streak
 * 
 * Authentication: Required
 */
router.get('/summary', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayTimestamp = admin.firestore.Timestamp.fromDate(today);

    // Get active quiz
    const activeQuizRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .where('status', '==', 'in_progress')
      .orderBy('generated_at', 'desc')
      .limit(1);

    const activeQuizSnapshot = await retryFirestoreOperation(async () => {
      return await activeQuizRef.get();
    });

    let activeQuiz = null;
    if (!activeQuizSnapshot.empty) {
      const quizDoc = activeQuizSnapshot.docs[0];
      const quizData = quizDoc.data();
      const answeredCount = (quizData.questions || []).filter(q => q.answered).length;

      activeQuiz = {
        quiz_id: quizDoc.id,
        quiz_number: quizData.quiz_number,
        questions_answered: answeredCount,
        total_questions: quizData.questions?.length || 0,
        started_at: quizData.started_at?.toDate?.()?.toISOString() || quizData.started_at,
        generated_at: quizData.generated_at
      };
    }

    // Get today's completed quizzes
    const todayQuizzesRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .where('status', '==', 'completed')
      .where('completed_at', '>=', todayTimestamp);

    const todayQuizzesSnapshot = await retryFirestoreOperation(async () => {
      return await todayQuizzesRef.get();
    });

    // Sort quizzes by completion time (most recent first) for accurate tracking
    const todayQuizzes = todayQuizzesSnapshot.docs
      .map(doc => doc.data())
      .sort((a, b) => {
        const aTime = a.completed_at?.toDate?.() || a.completed_at || new Date(0);
        const bTime = b.completed_at?.toDate?.() || b.completed_at || new Date(0);
        return bTime - aTime; // Descending (most recent first)
      });

    // Calculate today's stats with proper validation
    const accuracySum = todayQuizzes.reduce((sum, q) => {
      const acc = typeof q.accuracy === 'number' && !isNaN(q.accuracy) ? q.accuracy : 0;
      return sum + acc;
    }, 0);

    // Get most recent quiz accuracy (for personalized messages)
    const lastQuizAccuracy = todayQuizzes.length > 0 && typeof todayQuizzes[0].accuracy === 'number'
      ? todayQuizzes[0].accuracy
      : null;

    // Get previous quiz accuracy (for improvement detection)
    const previousQuizAccuracy = todayQuizzes.length > 1 && typeof todayQuizzes[1].accuracy === 'number'
      ? todayQuizzes[1].accuracy
      : null;

    const todayStats = {
      quizzes_completed: todayQuizzes.length,
      questions_solved: todayQuizzes.reduce((sum, q) => {
        const count = Array.isArray(q.questions) ? q.questions.length : 0;
        return sum + count;
      }, 0),
      accuracy: todayQuizzes.length > 0 ? accuracySum / todayQuizzes.length : 0,
      last_quiz_accuracy: lastQuizAccuracy,
      previous_quiz_accuracy: previousQuizAccuracy,
      time_spent_minutes: todayQuizzes.reduce((sum, q) => {
        const time = typeof q.total_time_seconds === 'number' && !isNaN(q.total_time_seconds)
          ? q.total_time_seconds
          : 0;
        return sum + Math.round(time / 60);
      }, 0)
    };

    // Get streak
    const streak = await getStreak(userId);

    // Get user data for next quiz availability
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    const userData = userDoc.exists ? userDoc.data() : {};
    const assessmentCompleted = userData.assessment?.completed_at;
    const lastQuizCompleted = userData.last_quiz_completed_at?.toDate?.() || userData.last_quiz_completed_at;

    // Check if next quiz is available (can generate new quiz if no active quiz)
    const nextQuizAvailable = assessmentCompleted && !activeQuiz;

    res.json({
      success: true,
      summary: {
        has_active_quiz: !!activeQuiz,
        active_quiz: activeQuiz,
        today_stats: todayStats,
        streak: streak,
        next_quiz_available: nextQuizAvailable,
        assessment_completed: !!assessmentCompleted,
        last_quiz_completed_at: lastQuizCompleted?.toISOString?.() || lastQuizCompleted
      },
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// CHAPTER PROGRESS DETAILS
// ============================================================================

/**
 * GET /api/daily-quiz/chapter-progress/:chapter_key
 * 
 * Get detailed progress for a specific chapter
 * Includes current state, baseline, recent quizzes, and trends
 * 
 * Authentication: Required
 */
router.get('/chapter-progress/:chapter_key', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;

    // Validate chapter_key parameter
    function validateChapterKey(chapterKey) {
      if (!chapterKey || typeof chapterKey !== 'string') {
        throw new ApiError(400, 'chapter_key is required and must be a string', 'INVALID_CHAPTER_KEY');
      }
      if (chapterKey.length > 100) {
        throw new ApiError(400, 'chapter_key too long (max 100 characters)', 'INVALID_CHAPTER_KEY');
      }
      if (chapterKey.trim().length === 0) {
        throw new ApiError(400, 'chapter_key cannot be empty', 'INVALID_CHAPTER_KEY');
      }
      return chapterKey;
    }

    const chapter_key = validateChapterKey(req.params.chapter_key);

    // Get user data
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    if (!userDoc.exists) {
      throw new ApiError(404, `User ${userId} not found`, 'USER_NOT_FOUND');
    }

    const userData = userDoc.data();
    const thetaByChapter = userData.theta_by_chapter || {};
    const baseline = userData.assessment_baseline?.theta_by_chapter || {};

    const currentData = thetaByChapter[chapter_key];
    const baselineData = baseline[chapter_key];

    if (!currentData) {
      throw new ApiError(404, `Chapter ${chapter_key} not found in user progress`, 'CHAPTER_NOT_FOUND');
    }

    // Parse chapter key to get subject and chapter name
    const parts = chapter_key.split('_');
    const subject = parts[0]?.charAt(0).toUpperCase() + parts[0]?.slice(1) || '';
    const chapter = parts.slice(1).join(' ').replace(/_/g, ' ') || '';

    // Get recent quizzes that covered this chapter
    const recentQuizzesRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .where('status', '==', 'completed')
      .where('chapters_covered', 'array-contains', chapter_key)
      .orderBy('completed_at', 'desc')
      .limit(10);

    const recentQuizzesSnapshot = await retryFirestoreOperation(async () => {
      return await recentQuizzesRef.get();
    });

    const recentQuizzes = recentQuizzesSnapshot.docs.map(doc => {
      const quizData = doc.data();
      const chapterQuestions = (quizData.questions || []).filter(q => q.chapter_key === chapter_key);
      const chapterCorrect = chapterQuestions.filter(q => q.is_correct).length;

      return {
        quiz_id: doc.id,
        quiz_number: quizData.quiz_number,
        completed_at: quizData.completed_at?.toDate?.()?.toISOString() || quizData.completed_at,
        accuracy: chapterQuestions.length > 0 ? chapterCorrect / chapterQuestions.length : 0,
        questions_count: chapterQuestions.length,
        correct_count: chapterCorrect
      };
    });

    // Calculate status
    const percentile = currentData.percentile || 50;
    let status = 'untested';
    if (percentile >= 70) status = 'strong';
    else if (percentile >= 40) status = 'average';
    else if (percentile > 0) status = 'weak';

    res.json({
      success: true,
      chapter: {
        chapter_key: chapter_key,
        subject: subject,
        chapter: chapter,
        current_theta: currentData.theta || 0,
        current_percentile: percentile,
        baseline_theta: baselineData?.theta || currentData.theta || 0,
        baseline_percentile: baselineData?.percentile || percentile,
        theta_change: (currentData.theta || 0) - (baselineData?.theta || currentData.theta || 0),
        percentile_change: percentile - (baselineData?.percentile || percentile),
        attempts: currentData.attempts || 0,
        accuracy: currentData.accuracy || 0,
        confidence_SE: currentData.confidence_SE || 0.6,
        questions_solved: currentData.attempts || 0,
        last_updated: currentData.last_updated,
        status: status
      },
      recent_quizzes: recentQuizzes,
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// THETA HISTORY & PROGRESSION
// ============================================================================

/**
 * GET /api/daily-quiz/theta-history
 *
 * Get theta snapshots history for the user
 * Returns list of theta states captured after each quiz
 *
 * Query params:
 * - limit: Number of snapshots to return (default: 30, max: 100)
 * - start_date: Filter snapshots from this date (ISO string)
 * - end_date: Filter snapshots until this date (ISO string)
 * - cursor: Pagination cursor (quiz_id of last item)
 *
 * Authentication: Required
 */
router.get('/theta-history', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    const limit = Math.min(parseInt(req.query.limit) || 30, 100);

    // Validate and parse date parameters
    let startDate = null;
    let endDate = null;

    if (req.query.start_date) {
      startDate = new Date(req.query.start_date);
      if (isNaN(startDate.getTime())) {
        throw new ApiError(400, 'Invalid start_date format', 'INVALID_DATE_FORMAT');
      }
    }

    if (req.query.end_date) {
      endDate = new Date(req.query.end_date);
      if (isNaN(endDate.getTime())) {
        throw new ApiError(400, 'Invalid end_date format', 'INVALID_DATE_FORMAT');
      }
    }

    const cursor = req.query.cursor || null;

    const result = await getThetaSnapshots(userId, {
      limit,
      startDate,
      endDate,
      startAfter: cursor
    });

    res.json({
      success: true,
      snapshots: result.snapshots,
      pagination: result.pagination,
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/daily-quiz/theta-progression
 *
 * Get theta progression over time (for charts/graphs)
 *
 * Query params:
 * - type: 'overall' | 'subject' | 'chapter' (default: 'overall')
 * - subject: Subject name (required if type='subject')
 * - chapter_key: Chapter key (required if type='chapter')
 * - limit: Number of data points (default: 30, max: 100)
 *
 * Authentication: Required
 */
router.get('/theta-progression', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    const type = req.query.type || 'overall';
    const limit = Math.min(parseInt(req.query.limit) || 30, 100);

    let progression;

    switch (type) {
      case 'overall':
        progression = await getOverallThetaProgression(userId, { limit });
        break;

      case 'subject':
        const subject = req.query.subject;
        if (!subject) {
          throw new ApiError(400, 'subject parameter is required for type=subject', 'MISSING_SUBJECT');
        }
        if (!['physics', 'chemistry', 'mathematics'].includes(subject.toLowerCase())) {
          throw new ApiError(400, 'Invalid subject. Must be physics, chemistry, or mathematics', 'INVALID_SUBJECT');
        }
        progression = await getSubjectThetaProgression(userId, subject, { limit });
        break;

      case 'chapter':
        const chapterKey = req.query.chapter_key;
        if (!chapterKey) {
          throw new ApiError(400, 'chapter_key parameter is required for type=chapter', 'MISSING_CHAPTER_KEY');
        }
        progression = await getChapterThetaProgression(userId, chapterKey, { limit });
        break;

      default:
        throw new ApiError(400, 'Invalid type. Must be overall, subject, or chapter', 'INVALID_TYPE');
    }

    res.json({
      success: true,
      type,
      progression,
      count: progression.length,
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/daily-quiz/theta-snapshot/:quiz_id
 *
 * Get a specific theta snapshot by quiz ID
 *
 * Authentication: Required
 */
router.get('/theta-snapshot/:quiz_id', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { quiz_id } = req.params;

    if (!quiz_id) {
      throw new ApiError(400, 'quiz_id is required', 'MISSING_QUIZ_ID');
    }

    const snapshot = await getThetaSnapshotByQuizId(userId, quiz_id);

    if (!snapshot) {
      throw new ApiError(404, `Theta snapshot for quiz ${quiz_id} not found`, 'SNAPSHOT_NOT_FOUND');
    }

    res.json({
      success: true,
      snapshot,
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;

