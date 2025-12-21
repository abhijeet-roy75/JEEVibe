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

// Services
const { generateDailyQuiz } = require('../services/dailyQuizService');
const { submitAnswer, getQuizResponses } = require('../services/quizResponseService');
const { updateChapterTheta, updateSubjectAndOverallTheta } = require('../services/thetaUpdateService');
const { updateFailureCount } = require('../services/circuitBreakerService');
const { updateReviewInterval } = require('../services/spacedRepetitionService');
const { formatChapterKey } = require('../services/thetaCalculationService');
const { getChapterProgress, getSubjectProgress, getAccuracyTrends, getCumulativeStats } = require('../services/progressService');
const { getStreak, updateStreak } = require('../services/streakService');

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
      return res.json({
        success: true,
        message: 'Active quiz found',
        quiz: {
          quiz_id: activeQuizSnapshot.docs[0].id,
          quiz_number: activeQuiz.quiz_number,
          learning_phase: activeQuiz.learning_phase,
          questions: activeQuiz.questions?.map(q => {
            // Remove sensitive fields
            const { correct_answer, correct_answer_text, solution_text, solution_steps, ...sanitized } = q;
            return sanitized;
          }) || [],
          generated_at: activeQuiz.generated_at,
          is_recovery_quiz: activeQuiz.is_recovery_quiz || false
        },
        requestId: req.id
      });
    }

    // Check daily limit: one quiz per day (resets at midnight)
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayEnd = new Date(today);
    todayEnd.setHours(23, 59, 59, 999);

    const todayQuizzesRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .where('status', '==', 'completed')
      .where('completed_at', '>=', admin.firestore.Timestamp.fromDate(today))
      .where('completed_at', '<=', admin.firestore.Timestamp.fromDate(todayEnd))
      .limit(1);

    const todayQuizzesSnapshot = await retryFirestoreOperation(async () => {
      return await todayQuizzesRef.get();
    });

    /*
    if (!todayQuizzesSnapshot.empty) {
      const completedQuiz = todayQuizzesSnapshot.docs[0].data();
      const completedQuizId = todayQuizzesSnapshot.docs[0].id;
      
      // User has already completed a quiz today
      return res.status(429).json({
        success: false,
        error: {
          code: 'DAILY_LIMIT_REACHED',
          message: 'You have already completed your daily quiz today. Come back tomorrow for a new quiz!',
          details: 'Daily quiz limit: 1 quiz per day (resets at midnight)'
        },
        completed_quiz: {
          quiz_id: completedQuizId,
          quiz_number: completedQuiz.quiz_number,
          completed_at: completedQuiz.completed_at?.toDate?.()?.toISOString() || completedQuiz.completed_at
        },
        next_quiz_available: new Date(today.getTime() + 24 * 60 * 60 * 1000).toISOString(), // Tomorrow at midnight
        requestId: req.id
      });
    }
    */

    // Generate new quiz
    logger.info('Generating daily quiz', { userId, requestId: req.id });
    const quizData = await generateDailyQuiz(userId);
    logger.info('Daily quiz generated successfully', {
      userId,
      quizId: quizData.quiz_id,
      questionCount: quizData.questions?.length || 0,
      requestId: req.id
    });

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

          // Create new quiz atomically
          transaction.set(quizRef, {
            ...quizData,
            student_id: userId,
            status: 'in_progress',
            started_at: null, // Will be set when quiz is started
            completed_at: null,
            total_time_seconds: 0,
            questions: quizData.questions.map(q => {
              // Store question data but mark as not answered
              const { solution_text, solution_steps, correct_answer, correct_answer_text, ...questionData } = q;
              return {
                ...questionData,
                answered: false,
                student_answer: null,
                is_correct: null,
                time_taken_seconds: null
              };
            })
          });

          savedQuizData = quizData; // Mark as saved
        });
      });
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
      const sanitizedQuestions = (savedQuizData.questions || []).map(q => {
        const { correct_answer, correct_answer_text, solution_text, solution_steps, ...sanitized } = q;
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
router.post('/start', authenticateUser, async (req, res, next) => {
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
router.post('/submit-answer', authenticateUser, async (req, res, next) => {
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
router.post('/complete', authenticateUser, async (req, res, next) => {
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

    // Use transaction to atomically complete quiz and update user
    await retryFirestoreOperation(async () => {
      return await db.runTransaction(async (transaction) => {
        // Read quiz and user documents in transaction
        const quizDoc = await transaction.get(quizRef);
        const userDoc = await transaction.get(userRef);

        if (!quizDoc.exists) {
          throw new ApiError(404, `Quiz ${quiz_id} not found`, 'QUIZ_NOT_FOUND');
        }

        const quizData = quizDoc.data();

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

        // Update user document atomically
        transaction.update(userRef, {
          completed_quiz_count: newQuizCount,
          current_day: daysSinceAssessment + 1,
          learning_phase: learningPhase,
          phase_switched_at_quiz: learningPhase === 'exploitation' && completedQuizCount < 14 ? 14 : userData.phase_switched_at_quiz,
          last_quiz_completed_at: admin.firestore.FieldValue.serverTimestamp(),
          total_questions_solved: admin.firestore.FieldValue.increment(totalCount),
          total_time_spent_minutes: admin.firestore.FieldValue.increment(Math.round(totalTime / 60))
        });
      });
    });

    // Update chapter thetas (outside transaction - these can fail without blocking completion)
    const chapterUpdates = await Promise.all(
      Object.entries(responsesByChapter).map(async ([chapterKey, chapterResponses]) => {
        try {
          return await updateChapterTheta(userId, chapterKey, chapterResponses);
        } catch (error) {
          logger.error('Error updating chapter theta', {
            userId,
            chapterKey,
            error: error.message
          });
          return null;
        }
      })
    );

    // Update subject and overall theta
    try {
      await updateSubjectAndOverallTheta(userId);
    } catch (error) {
      logger.error('Error updating subject/overall theta', {
        userId,
        error: error.message
      });
    }

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

    // Update review intervals for incorrect answers
    for (const response of responses) {
      if (!response.is_correct && response.question_id) {
        try {
          await updateReviewInterval(userId, response.question_id, false);
        } catch (error) {
          logger.warn('Error updating review interval', {
            userId,
            questionId: response.question_id,
            error: error.message
          });
        }
      }
    }

    // Get final user data and quiz data for response
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });
    const userData = userDoc.data();
    const newQuizCount = (userData.completed_quiz_count || 0);

    // Get quiz data again (needed for saving responses)
    const quizDoc = await retryFirestoreOperation(async () => {
      return await quizRef.get();
    });
    const quizData = quizDoc.data();

    // Save individual responses to daily_quiz_responses collection
    const responsesRef = db.collection('daily_quiz_responses')
      .doc(userId)
      .collection('responses');

    let batch = db.batch(); // Initialize first batch
    let batchCount = 0;

    for (const response of responses) {
      const responseId = `${quiz_id}_${response.question_id}`;
      const responseRef = responsesRef.doc(responseId);

      const questionData = quizData.questions?.find(q => q.question_id === response.question_id) || {};

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
        difficulty_b: response.questionIRT.b,
        discrimination_a: response.questionIRT.a,
        guessing_c: response.questionIRT.c,

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
      chapters_updated: chapterUpdates.filter(u => u !== null).length,
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

    // Sanitize questions (remove answers)
    const sanitizedQuestions = (activeQuiz.questions || []).map(q => {
      const { correct_answer, correct_answer_text, solution_text, solution_steps, ...sanitized } = q;
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
        total: data.questions?.length || 0,
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

    // Get full question details from questions collection using batch read
    const questionIds = (quizData.questions || []).map(q => q.question_id).filter(Boolean);

    if (questionIds.length === 0) {
      throw new ApiError(400, 'Quiz has no questions', 'NO_QUESTIONS_IN_QUIZ');
    }

    // Batch read all questions at once (fixes N+1 query problem)
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
    const questionsWithDetails = (quizData.questions || []).map(q => {
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

          // Metadata
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
        total: quizData.questions?.length || 0,
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

    const todayQuizzes = todayQuizzesSnapshot.docs.map(doc => doc.data());

    // Calculate today's stats with proper validation
    const accuracySum = todayQuizzes.reduce((sum, q) => {
      const acc = typeof q.accuracy === 'number' && !isNaN(q.accuracy) ? q.accuracy : 0;
      return sum + acc;
    }, 0);

    const todayStats = {
      quizzes_completed: todayQuizzes.length,
      questions_solved: todayQuizzes.reduce((sum, q) => {
        const count = Array.isArray(q.questions) ? q.questions.length : 0;
        return sum + count;
      }, 0),
      accuracy: todayQuizzes.length > 0 ? accuracySum / todayQuizzes.length : 0,
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

module.exports = router;

