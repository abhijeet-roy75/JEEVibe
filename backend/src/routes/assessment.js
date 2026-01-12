/**
 * Assessment Routes
 * 
 * API endpoints for initial assessment:
 * - GET /api/assessment/questions - Get randomized assessment questions
 * - POST /api/assessment/submit - Submit assessment responses
 * - GET /api/assessment/results/:userId - Get assessment results
 */

const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const { db, admin } = require('../config/firebase');
const { getRandomizedAssessmentQuestions } = require('../services/stratifiedRandomizationService');
const { processInitialAssessment, validateAssessmentResponses } = require('../services/assessmentService');
const { authenticateUser } = require('../middleware/auth');
const { validateQuestionId, validateStudentAnswer, validateTimeTaken } = require('../utils/validation');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { ApiError } = require('../middleware/errorHandler');

// Rate limiter for results polling endpoint
// Allows 30 requests per minute per user (one every 2 seconds)
const resultsLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute window
  max: 30, // 30 requests per minute
  message: 'Too many requests for assessment results. Please try again later.',
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  // Use user ID as key for rate limiting
  keyGenerator: (req) => {
    return req.userId || req.ip; // Fall back to IP if no userId
  },
});

/**
 * GET /api/assessment/questions
 * 
 * Returns 30 assessment questions in stratified random order
 * Same user gets same order (deterministic)
 * 
 * Authentication: Required (Bearer token in Authorization header)
 */
router.get('/questions', authenticateUser, async (req, res, next) => {
  try {
    // Use authenticated userId from middleware
    const userId = req.userId;
    
    // TEMPORARILY DISABLED FOR TESTING: Allow multiple assessment attempts
    // TODO: Re-enable this check before production
    // Check if user already completed assessment
    // const userRef = db.collection('users').doc(userId);
    // const userDoc = await retryFirestoreOperation(async () => {
    //   return await userRef.get();
    // });
    // 
    // if (userDoc.exists) {
    //   const userData = userDoc.data();
    //   if (userData.assessment?.status === 'completed') {
    //     return res.status(400).json({
    //       success: false,
    //       error: 'Assessment already completed. Cannot retake.',
    //       completed_at: userData.assessment.completed_at
    //     });
    //   }
    // }
    
    // Get randomized questions (with retry)
    const questions = await retryFirestoreOperation(async () => {
      return await getRandomizedAssessmentQuestions(userId, db);
    });
    
    // Remove sensitive fields (solution, correct_answer) for client
    const sanitizedQuestions = questions.map(q => {
      const { solution_text, solution_steps, correct_answer, correct_answer_text, ...sanitized } = q;
      return sanitized;
    });
    
    res.json({
      success: true,
      count: sanitizedQuestions.length,
      questions: sanitizedQuestions,
      requestId: req.id,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/assessment/submit
 * 
 * Submit assessment responses and calculate theta estimates
 * 
 * Authentication: Required (Bearer token in Authorization header)
 * 
 * Body:
 *   {
 *     responses: [
 *       {
 *         question_id: string,
 *         student_answer: string,
 *         time_taken_seconds: number
 *       },
 *       ... (30 total)
 *     ]
 *   }
 * 
 * Note: userId is extracted from authentication token, not from body
 */
router.post('/submit', authenticateUser, async (req, res) => {
  // Declare responses outside try block to avoid ReferenceError in catch
  let responses;
  try {
    // Use authenticated userId from middleware (not from body for security)
    const userId = req.userId;
    responses = req.body?.responses;
    
    if (!responses || !Array.isArray(responses)) {
      return res.status(400).json({
        success: false,
        error: 'responses array is required'
      });
    }
    
    // TEMPORARILY DISABLED FOR TESTING: Allow multiple assessment submissions
    // TODO: Re-enable this check before production
    // Check if user already completed assessment BEFORE processing
    // This prevents wasted computation if assessment is already done
    // const userRef = db.collection('users').doc(userId);
    // const userDoc = await retryFirestoreOperation(async () => {
    //   return await userRef.get();
    // });
    // 
    // if (userDoc.exists) {
    //   const userData = userDoc.data();
    //   if (userData.assessment?.status === 'completed') {
    //     return res.status(400).json({
    //       success: false,
    //       error: 'Assessment already completed. Cannot submit again.',
    //       completed_at: userData.assessment.completed_at
    //     });
    //   }
    // }
    
    // Validate and sanitize inputs
    try {
      responses.forEach((response, index) => {
        validateQuestionId(response.question_id);
        validateStudentAnswer(response.student_answer);
        response.time_taken_seconds = validateTimeTaken(response.time_taken_seconds);
      });
    } catch (validationError) {
      return res.status(400).json({
        success: false,
        error: 'Invalid input data',
        details: validationError.message
      });
    }
    
    // Validate responses structure
    const validation = validateAssessmentResponses(responses);
    if (!validation.valid) {
      return res.status(400).json({
        success: false,
        error: 'Invalid responses',
        details: validation.errors
      });
    }
    
    // FIX N+1 QUERY: Batch read all questions at once
    const questionIds = responses.map(r => validateQuestionId(r.question_id));
    const questionRefs = questionIds.map(id => 
      db.collection('initial_assessment_questions').doc(id)
    );
    
    // Batch read all questions with retry
    const questionDocs = await retryFirestoreOperation(async () => {
      return await db.getAll(...questionRefs);
    });
    
    // Validate all questions were fetched
    if (questionDocs.length !== responses.length) {
      const foundIds = questionDocs.map(doc => doc.id);
      const requestedIds = questionIds;
      const missing = requestedIds.filter(id => !foundIds.includes(id));
      
      throw new Error(
        `Missing questions: Expected ${responses.length}, found ${questionDocs.length}. ` +
        `Missing question IDs: ${missing.join(', ')}`
      );
    }
    
    // Create lookup map for O(1) access
    const questionMap = new Map();
    questionDocs.forEach(doc => {
      if (!doc.exists) {
        throw new Error(`Question ${doc.id} not found in database`);
      }
      const questionData = doc.data();
      
      // Validate required fields exist
      if (!questionData.subject || !questionData.chapter) {
        throw new Error(
          `Question ${doc.id} missing required fields: ` +
          `subject=${questionData.subject}, chapter=${questionData.chapter}`
        );
      }
      
      questionMap.set(doc.id, questionData);
    });
    
    // Enrich responses with question data (no more individual queries!)
    const enrichedResponses = responses.map((response) => {
      const questionId = validateQuestionId(response.question_id);
      const questionData = questionMap.get(questionId);
      
      if (!questionData) {
        throw new Error(`Question ${questionId} not found in database`);
      }
      
      // Validate question has required fields (double-check)
      if (!questionData.subject || !questionData.chapter) {
        throw new Error(
          `Question ${questionId} missing required fields: ` +
          `subject=${questionData.subject}, chapter=${questionData.chapter}`
        );
      }
      
      // Determine if answer is correct
      let isCorrect = false;
      const studentAnswer = validateStudentAnswer(response.student_answer);
      
      if (questionData.question_type === 'mcq_single') {
        if (!questionData.correct_answer) {
          throw new Error(`Question ${questionId} (MCQ) missing correct_answer field`);
        }
        isCorrect = studentAnswer === questionData.correct_answer;
      } else if (questionData.question_type === 'numerical') {
        const studentAnswerNum = parseFloat(studentAnswer);
        if (isNaN(studentAnswerNum)) {
          throw new Error(
            `Invalid numerical answer for question ${questionId}: "${studentAnswer}". ` +
            `Must be a valid number.`
          );
        }
        
        const correctAnswer = parseFloat(questionData.correct_answer_exact || questionData.correct_answer);
        if (isNaN(correctAnswer)) {
          throw new Error(
            `Question ${questionId} has invalid correct_answer: ${questionData.correct_answer}. ` +
            `Must be a valid number for numerical questions.`
          );
        }
        
        if (questionData.answer_range) {
          if (typeof questionData.answer_range.min !== 'number' || 
              typeof questionData.answer_range.max !== 'number') {
            throw new Error(
              `Question ${questionId} has invalid answer_range: ` +
              `min=${questionData.answer_range.min}, max=${questionData.answer_range.max}`
            );
          }
          // Check if within range
          isCorrect = studentAnswerNum >= questionData.answer_range.min &&
                     studentAnswerNum <= questionData.answer_range.max;
        } else {
          // Exact match (with small tolerance)
          isCorrect = Math.abs(studentAnswerNum - correctAnswer) < 0.01;
        }
      } else {
        throw new Error(
          `Question ${questionId} has unknown question_type: "${questionData.question_type}". ` +
          `Expected 'mcq_single' or 'numerical'.`
        );
      }
      
      return {
        question_id: questionId,
        student_answer: studentAnswer,
        correct_answer: questionData.correct_answer,
        is_correct: isCorrect,
        time_taken_seconds: validateTimeTaken(response.time_taken_seconds),
        subject: questionData.subject,
        chapter: questionData.chapter
      };
    });
    
    // Set status to "processing" in Firestore immediately
    const userRef = db.collection('users').doc(userId);
    await retryFirestoreOperation(async () => {
      await userRef.set({
        assessment: {
          status: 'processing',
          submitted_at: new Date().toISOString()
        }
      }, { merge: true });
    });
    
    // Process assessment asynchronously (don't await - return immediately)
    // Note: processInitialAssessment already saves results to Firestore
    processInitialAssessment(userId, enrichedResponses)
      .then((assessmentResults) => {
        // Results are already saved by processInitialAssessment
        // Just log success
        logger.info('Assessment processing completed', {
          requestId: req.id,
          userId,
          overallTheta: assessmentResults.overall_theta,
          timestamp: new Date().toISOString()
        });
      })
      .catch((error) => {
        // Update status to error
        logger.error('Error processing assessment in background', {
          requestId: req.id,
          userId,
          error: error.message,
          stack: error.stack
        });
        return retryFirestoreOperation(async () => {
          await userRef.set({
            assessment: {
              status: 'error',
              error: error.message,
              error_at: new Date().toISOString()
            }
          }, { merge: true });
        });
      });
    
    // Return immediately with processing status
    res.json({
      success: true,
      status: 'processing',
      message: 'Assessment submitted. Results will be available shortly.',
      check_results_at: `/api/assessment/results/${userId}`
    });
  } catch (error) {
    // Error handler middleware will catch this
    next(error);
  }
});

/**
 * GET /api/assessment/results/:userId
 *
 * Get assessment results for a user (if completed)
 *
 * Authentication: Required (Bearer token in Authorization header)
 * User can only access their own results
 * Rate Limited: 30 requests per minute per user
 */
router.get('/results/:userId', resultsLimiter, authenticateUser, async (req, res) => {
  try {
    const { userId: paramUserId } = req.params;
    const authenticatedUserId = req.userId;
    
    // Security: Users can only access their own results
    if (paramUserId !== authenticatedUserId) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: You can only access your own assessment results'
      });
    }
    
    const userRef = db.collection('users').doc(authenticatedUserId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });
    
    if (!userDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }
    
    const userData = userDoc.data();
    const assessmentStatus = userData.assessment?.status || 'not_started';
    
    // Handle processing status
    if (assessmentStatus === 'processing') {
      return res.json({
        success: true,
        status: 'processing',
        message: 'Assessment is being processed. Please check again in a moment.'
      });
    }
    
    // Handle error status
    if (assessmentStatus === 'error') {
      return res.status(500).json({
        success: false,
        error: userData.assessment?.error || 'Assessment processing failed',
        status: 'error'
      });
    }
    
    // Only return full results if completed
    if (assessmentStatus !== 'completed') {
      return res.status(400).json({
        success: false,
        error: 'Assessment not completed',
        status: assessmentStatus
      });
    }
    
    // Calculate subject_accuracy if missing (for assessments completed before this feature)
    let subjectAccuracy = userData.subject_accuracy;
    if (!subjectAccuracy || 
        !subjectAccuracy.physics || 
        subjectAccuracy.physics.accuracy === null ||
        (subjectAccuracy.physics.total === 0 && userData.theta_by_chapter)) {
      // Recalculate from stored responses
      try {
        const responsesRef = db.collection('assessment_responses')
          .doc(authenticatedUserId)
          .collection('responses');
        
        const responsesSnapshot = await retryFirestoreOperation(async () => {
          return await responsesRef.get();
        });
        
        if (!responsesSnapshot.empty) {
          const { calculateSubjectAccuracy } = require('../services/assessmentService');
          const enrichedResponses = responsesSnapshot.docs.map(doc => {
            const data = doc.data();
            return {
              subject: data.subject,
              is_correct: data.is_correct === true,
              question_id: data.question_id
            };
          });
          
          subjectAccuracy = calculateSubjectAccuracy(enrichedResponses);
          
          // Save the calculated accuracy back to user profile (async, don't wait)
          const userRef = db.collection('users').doc(authenticatedUserId);
          userRef.set({
            subject_accuracy: subjectAccuracy
          }, { merge: true }).catch(err => {
            logger.error('Error saving calculated subject_accuracy', {
              requestId: req.id,
              userId: authenticatedUserId,
              error: err.message,
            });
          });
        }
      } catch (calcError) {
        logger.error('Error calculating subject_accuracy from responses', {
          requestId: req.id,
          userId: authenticatedUserId,
          error: calcError.message,
        });
        // Use default if calculation fails
        subjectAccuracy = {
          physics: { accuracy: null, correct: 0, total: 0 },
          chemistry: { accuracy: null, correct: 0, total: 0 },
          mathematics: { accuracy: null, correct: 0, total: 0 }
        };
      }
    }
    
    // Return assessment results
    res.json({
      success: true,
      assessment: userData.assessment,
      theta_by_chapter: userData.theta_by_chapter || {},
      theta_by_subject: userData.theta_by_subject || {
        physics: { 
          theta: null, 
          percentile: null, 
          status: 'not_tested',
          message: 'No questions answered in this subject',
          chapters_tested: 0 
        },
        chemistry: { 
          theta: null, 
          percentile: null, 
          status: 'not_tested',
          message: 'No questions answered in this subject',
          chapters_tested: 0 
        },
        mathematics: { 
          theta: null, 
          percentile: null, 
          status: 'not_tested',
          message: 'No questions answered in this subject',
          chapters_tested: 0 
        }
      },
      overall_theta: userData.overall_theta || 0,
      overall_percentile: userData.overall_percentile || 50,
      chapters_explored: userData.chapters_explored || 0,
      chapters_confident: userData.chapters_confident || 0,
      subject_balance: userData.subject_balance || {},
      subject_accuracy: subjectAccuracy || {
        physics: { accuracy: null, correct: 0, total: 0 },
        chemistry: { accuracy: null, correct: 0, total: 0 },
        mathematics: { accuracy: null, correct: 0, total: 0 }
      }
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
