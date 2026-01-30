/**
 * Quiz Response Service
 * 
 * Handles answer submission and validation for daily quizzes.
 * Provides immediate feedback to users without updating theta.
 * 
 * Features:
 * - Answer validation (MCQ and numerical with range)
 * - Immediate feedback (correct/incorrect + explanation)
 * - Temporary response storage in quiz document
 * - Does NOT update theta (batch update happens after completion)
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { validateQuestionId, validateStudentAnswer, validateTimeTaken } = require('../utils/validation');

// ============================================================================
// ANSWER VALIDATION
// ============================================================================

/**
 * Validate and check if answer is correct
 * 
 * @param {Object} questionData - Question document data
 * @param {string} studentAnswer - Student's answer
 * @returns {Object} { isCorrect: boolean, validatedAnswer: string }
 */
function validateAnswer(questionData, studentAnswer) {
  const questionId = questionData.question_id;
  const questionType = questionData.question_type;
  const validatedAnswer = validateStudentAnswer(studentAnswer);
  
  let isCorrect = false;
  
  if (questionType === 'mcq_single') {
    // MCQ: Exact match with correct_answer
    if (!questionData.correct_answer) {
      throw new Error(`Question ${questionId} (MCQ) missing correct_answer field`);
    }
    
    // Check against correct_answer and alternate_correct_answers
    const correctAnswers = [
      questionData.correct_answer,
      ...(questionData.alternate_correct_answers || [])
    ].map(a => String(a).trim().toUpperCase());
    
    isCorrect = correctAnswers.includes(validatedAnswer.trim().toUpperCase());
    
  } else if (questionType === 'numerical') {
    // Numerical: Check if within range or exact match
    const studentAnswerNum = parseFloat(validatedAnswer);
    
    if (isNaN(studentAnswerNum)) {
      throw new Error(
        `Invalid numerical answer for question ${questionId}: "${validatedAnswer}". ` +
        `Must be a valid number.`
      );
    }
    
    if (questionData.answer_range) {
      // Check if within range
      const { min, max } = questionData.answer_range;
      
      if (typeof min !== 'number' || typeof max !== 'number') {
        throw new Error(
          `Question ${questionId} has invalid answer_range: min=${min}, max=${max}`
        );
      }
      
      isCorrect = studentAnswerNum >= min && studentAnswerNum <= max;
      
    } else if (questionData.correct_answer_exact) {
      // Exact match with tolerance
      const correctAnswer = parseFloat(questionData.correct_answer_exact);

      if (isNaN(correctAnswer)) {
        // Log the error for admin to fix, but don't block the user
        logger.error('Question has invalid correct_answer_exact - marking as incorrect', {
          questionId,
          correct_answer_exact: questionData.correct_answer_exact,
          note: 'Admin must fix this question data in Firestore'
        });

        // Mark as incorrect and continue (don't throw error that blocks user)
        isCorrect = false;
      } else {
        // Tolerance: 0.01 or 1% (whichever is larger)
        const tolerance = Math.max(0.01, Math.abs(correctAnswer) * 0.01);
        isCorrect = Math.abs(studentAnswerNum - correctAnswer) <= tolerance;
      }
      
    } else {
      // Fallback to correct_answer
      const correctAnswer = parseFloat(questionData.correct_answer);
      
      if (isNaN(correctAnswer)) {
        throw new Error(
          `Question ${questionId} has invalid correct_answer: ${questionData.correct_answer}`
        );
      }
      
      const tolerance = Math.max(0.01, Math.abs(correctAnswer) * 0.01);
      isCorrect = Math.abs(studentAnswerNum - correctAnswer) <= tolerance;
    }
    
  } else {
    throw new Error(
      `Question ${questionId} has unknown question_type: "${questionType}". ` +
      `Expected 'mcq_single' or 'numerical'.`
    );
  }
  
  return {
    isCorrect,
    validatedAnswer
  };
}

// ============================================================================
// IMMEDIATE FEEDBACK
// ============================================================================

/**
 * Generate immediate feedback for a response
 * 
 * @param {Object} questionData - Question document data
 * @param {boolean} isCorrect - Whether answer was correct
 * @param {string} studentAnswer - Student's answer
 * @returns {Object} Feedback object
 */
function generateFeedback(questionData, isCorrect, studentAnswer) {
  // Ensure correct_answer is always a string (some DB entries have it as number)
  const correctAnswer = questionData.correct_answer != null
    ? String(questionData.correct_answer)
    : null;

  const feedback = {
    is_correct: isCorrect,
    correct_answer: correctAnswer,
    correct_answer_text: questionData.correct_answer_text || correctAnswer,
    explanation: null,
    solution_text: questionData.solution_text || null,
    solution_steps: questionData.solution_steps || [],
    // Key insight from metadata (for Key Takeaway section)
    key_insight: questionData.metadata?.key_insight || null,
    // Common mistakes for numerical questions
    common_mistakes: questionData.metadata?.common_mistakes || questionData.common_mistakes || null,
    // Distractor analysis for MCQ questions (explains why each wrong option is wrong)
    distractor_analysis: questionData.distractor_analysis || null,
    // Question type for frontend to display appropriate "why wrong" content
    question_type: questionData.question_type || null,
    // Student's answer for reference
    student_answer: studentAnswer,
    // Hint (optional)
    hint: questionData.metadata?.hint || null
  };

  // Add explanation if available
  if (questionData.solution_text) {
    feedback.explanation = questionData.solution_text;
  } else if (questionData.solution_steps && questionData.solution_steps.length > 0) {
    // Use first solution step as explanation
    feedback.explanation = questionData.solution_steps[0].explanation ||
                           questionData.solution_steps[0].description ||
                           null;
  }

  return feedback;
}

// ============================================================================
// RESPONSE SUBMISSION
// ============================================================================

/**
 * Submit answer for a question in an active quiz
 * Stores response temporarily in quiz document
 * Returns immediate feedback
 * 
 * @param {string} userId
 * @param {string} quizId
 * @param {string} questionId
 * @param {string} studentAnswer
 * @param {number} timeTakenSeconds
 * @returns {Promise<Object>} Feedback and response data
 */
async function submitAnswer(userId, quizId, questionId, studentAnswer, timeTakenSeconds) {
  const startTime = Date.now();
  const timings = {};

  try {
    // Validate inputs
    const validatedQuestionId = validateQuestionId(questionId);
    const validatedTime = validateTimeTaken(timeTakenSeconds);

    // Get quiz document
    const quizRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .doc(quizId);

    const t1 = Date.now();
    const quizDoc = await retryFirestoreOperation(async () => {
      return await quizRef.get();
    });
    timings.getQuizDoc = Date.now() - t1;

    if (!quizDoc.exists) {
      throw new Error(`Quiz ${quizId} not found`);
    }

    const quizData = quizDoc.data();

    // Check if quiz is active
    if (quizData.status !== 'in_progress') {
      throw new Error(`Quiz ${quizId} is not in progress. Status: ${quizData.status}`);
    }

    // Find question in quiz subcollection
    const t2 = Date.now();
    const questionsSnapshot = await retryFirestoreOperation(async () => {
      return await quizRef.collection('questions')
        .where('question_id', '==', questionId)
        .limit(1)
        .get();
    });
    timings.queryQuestion = Date.now() - t2;

    if (questionsSnapshot.empty) {
      throw new Error(`Question ${questionId} not found in quiz ${quizId}`);
    }

    const questionDoc = questionsSnapshot.docs[0];
    let questionData = questionDoc.data();
    const questionPosition = questionData.position;

    // Validate question data exists
    if (!questionData) {
      throw new Error(`Question data missing for ${questionId} in quiz ${quizId}`);
    }

    // Only fetch from questions collection if correct_answer is missing (required for validation)
    // Skip fetch for missing solution_steps - old quizzes just won't show detailed explanations
    // This prioritizes response speed over showing solution steps for legacy quizzes
    const needsCorrectAnswer = !questionData.correct_answer;

    if (needsCorrectAnswer) {
      const t3 = Date.now();
      const fullQuestionRef = db.collection('questions').doc(questionId);
      const fullQuestionDoc = await retryFirestoreOperation(async () => {
        return await fullQuestionRef.get();
      });
      timings.fetchFullQuestion = Date.now() - t3;

      if (!fullQuestionDoc.exists) {
        throw new Error(`Question ${questionId} not found in questions collection`);
      }

      questionData = { ...questionData, ...fullQuestionDoc.data() };
    } else {
      timings.fetchFullQuestion = 0; // correct_answer present - no fetch needed
    }

    // Validate answer
    const validation = validateAnswer(questionData, studentAnswer);

    // Generate feedback
    const feedback = generateFeedback(questionData, validation.isCorrect, validation.validatedAnswer);

    // Prepare response data
    // Ensure correct_answer is always stored as string for consistency
    const now = admin.firestore.Timestamp.now();
    const responseData = {
      student_answer: validation.validatedAnswer,
      correct_answer: questionData.correct_answer != null ? String(questionData.correct_answer) : null,
      is_correct: validation.isCorrect,
      time_taken_seconds: validatedTime,
      answered_at: now,
      answered: true
    };

    // Update question document and quiz document in a single batch (reduces network round trips)
    const t4 = Date.now();
    const questionRef = quizRef.collection('questions').doc(String(questionPosition));
    await retryFirestoreOperation(async () => {
      const batch = db.batch();
      batch.update(questionRef, responseData);
      batch.update(quizRef, {
        last_answered_at: admin.firestore.FieldValue.serverTimestamp(),
        questions_answered: admin.firestore.FieldValue.increment(1)
      });
      return await batch.commit();
    });
    timings.batchWrite = Date.now() - t4;
    timings.total = Date.now() - startTime;

    logger.info('Answer submitted', {
      userId,
      quizId,
      questionId,
      isCorrect: validation.isCorrect,
      position: questionPosition,
      timingsMs: timings
    });

    return {
      success: true,
      question_id: validatedQuestionId,
      ...feedback,
      time_taken_seconds: validatedTime
    };
  } catch (error) {
    logger.error('Error submitting answer', {
      userId,
      quizId,
      questionId,
      error: error.message,
      stack: error.stack
    });
    throw error;
  }
}

// ============================================================================
// QUIZ COMPLETION PREPARATION
// ============================================================================

/**
 * Get all responses from a quiz for batch processing
 *
 * @param {string} userId
 * @param {string} quizId
 * @returns {Promise<Array>} Array of response objects with question data
 */
async function getQuizResponses(userId, quizId) {
  try {
    const quizRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .doc(quizId);

    const quizDoc = await retryFirestoreOperation(async () => {
      return await quizRef.get();
    });

    if (!quizDoc.exists) {
      throw new Error(`Quiz ${quizId} not found`);
    }

    // Fetch questions from subcollection
    const questionsSnapshot = await retryFirestoreOperation(async () => {
      return await quizRef.collection('questions')
        .orderBy('position', 'asc')
        .get();
    });

    const questions = questionsSnapshot.docs.map(doc => doc.data());

    // Filter to answered questions and format for batch processing
    const responses = questions
      .filter(q => q.answered && q.question_id)
      .map(q => {
        // Extract and validate IRT parameters
        const a = q.irt_parameters?.discrimination_a !== undefined
          ? q.irt_parameters.discrimination_a
          : 1.5;
        const b = q.irt_parameters?.difficulty_b !== undefined
          ? q.irt_parameters.difficulty_b
          : (q.difficulty_irt !== undefined ? q.difficulty_irt : 0);
        const c = q.irt_parameters?.guessing_c !== undefined
          ? q.irt_parameters.guessing_c
          : (q.question_type === 'mcq_single' ? 0.25 : 0.0);

        // Validate IRT parameters
        if (typeof a !== 'number' || isNaN(a) || a <= 0) {
          logger.warn('Invalid discrimination_a, using default', {
            question_id: q.question_id,
            value: a,
            default: 1.5
          });
        }
        if (typeof b !== 'number' || isNaN(b)) {
          logger.warn('Invalid difficulty_b, using default', {
            question_id: q.question_id,
            value: b,
            default: 0
          });
        }
        if (typeof c !== 'number' || isNaN(c) || c < 0 || c > 1) {
          logger.warn('Invalid guessing_c, using default', {
            question_id: q.question_id,
            value: c,
            default: q.question_type === 'mcq_single' ? 0.25 : 0.0
          });
        }

        // Use validated values with defaults
        const validatedA = (typeof a === 'number' && !isNaN(a) && a > 0) ? a : 1.5;
        const validatedB = (typeof b === 'number' && !isNaN(b)) ? b : 0;
        const validatedC = (typeof c === 'number' && !isNaN(c) && c >= 0 && c <= 1)
          ? c
          : (q.question_type === 'mcq_single' ? 0.25 : 0.0);

        return {
          question_id: q.question_id,
          student_answer: q.student_answer,
          correct_answer: q.correct_answer,
          is_correct: q.is_correct,
          time_taken_seconds: q.time_taken_seconds,
          chapter_key: q.chapter_key,
          sub_topics: q.sub_topics || [], // Include sub-topics for accuracy tracking
          question_irt_params: {
            a: validatedA,
            b: validatedB,
            c: validatedC
          }
        };
      });

    return responses;
  } catch (error) {
    logger.error('Error getting quiz responses', {
      userId,
      quizId,
      error: error.message
    });
    throw error;
  }
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  validateAnswer,
  generateFeedback,
  submitAnswer,
  getQuizResponses
};

