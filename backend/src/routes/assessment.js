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
const { db, admin } = require('../config/firebase');
const { getRandomizedAssessmentQuestions } = require('../services/stratifiedRandomizationService');
const { processInitialAssessment, validateAssessmentResponses } = require('../services/assessmentService');
const { authenticateUser } = require('../middleware/auth');
const { validateQuestionId, validateStudentAnswer, validateTimeTaken } = require('../utils/validation');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');

/**
 * GET /api/assessment/questions
 * 
 * Returns 30 assessment questions in stratified random order
 * Same user gets same order (deterministic)
 * 
 * Authentication: Required (Bearer token in Authorization header)
 */
router.get('/questions', authenticateUser, async (req, res) => {
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
      questions: sanitizedQuestions
    });
  } catch (error) {
    console.error('Error fetching assessment questions:', {
      userId: req.userId,
      error: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString()
    });
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to fetch assessment questions'
    });
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
    
    // Process assessment (enrichedResponses already have subject, chapter, is_correct)
    const assessmentResults = await processInitialAssessment(userId, enrichedResponses);
    
    // Return results (without sensitive data)
    const sanitizedResults = {
      success: true,
      assessment: {
        status: assessmentResults.assessment.status,
        completed_at: assessmentResults.assessment.completed_at,
        time_taken_seconds: assessmentResults.assessment.time_taken_seconds
      },
      theta_by_chapter: assessmentResults.theta_by_chapter,
      theta_by_subject: assessmentResults.theta_by_subject,
      overall_theta: assessmentResults.overall_theta,
      overall_percentile: assessmentResults.overall_percentile,
      chapters_explored: assessmentResults.chapters_explored,
      chapters_confident: assessmentResults.chapters_confident,
      subject_balance: assessmentResults.subject_balance
    };
    
    res.json(sanitizedResults);
  } catch (error) {
    // Enhanced error logging with context
    // Note: responses might not be defined if error occurs early
    const responseCount = (responses && Array.isArray(responses)) ? responses.length : 'unknown';
    console.error('Error submitting assessment:', {
      userId: req.userId,
      error: error.message,
      stack: error.stack,
      responseCount: responseCount,
      timestamp: new Date().toISOString()
    });
    
    // Determine appropriate status code
    let statusCode = 500;
    
    // Check for specific error codes
    if (error.code === 'ASSESSMENT_ALREADY_COMPLETED' || error.statusCode === 400) {
      statusCode = 400;
    } else if (error.message.includes('already completed')) {
      statusCode = 400;
    } else if (error.message.includes('not found') || error.code === 5) { // NOT_FOUND
      statusCode = 404;
    } else if (error.message.includes('Invalid') || error.message.includes('required') || error.message.includes('missing')) {
      statusCode = 400;
    } else if (error.code === 10) { // ABORTED - transaction conflict
      statusCode = 409; // Conflict
      error.message = 'Assessment submission conflicted with another request. Please wait a moment and try again.';
    }
    
    res.status(statusCode).json({
      success: false,
      error: error.message || 'Failed to process assessment'
    });
  }
});

/**
 * GET /api/assessment/results/:userId
 * 
 * Get assessment results for a user (if completed)
 * 
 * Authentication: Required (Bearer token in Authorization header)
 * User can only access their own results
 */
router.get('/results/:userId', authenticateUser, async (req, res) => {
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
    
    if (userData.assessment?.status !== 'completed') {
      return res.status(400).json({
        success: false,
        error: 'Assessment not completed',
        status: userData.assessment?.status || 'not_started'
      });
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
      subject_balance: userData.subject_balance || {}
    });
  } catch (error) {
    console.error('Error fetching assessment results:', {
      userId: req.userId,
      requestedUserId: paramUserId,
      error: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString()
    });
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to fetch assessment results'
    });
  }
});

module.exports = router;
