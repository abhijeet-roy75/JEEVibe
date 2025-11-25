/**
 * JEEVibe - Snap & Solve API Route
 * Handles image upload, OCR, solution generation, and follow-up questions
 */

const express = require('express');
const multer = require('multer');
const { solveQuestionFromImage, generateFollowUpQuestions, generateSingleFollowUpQuestion } = require('../services/openai');

const router = express.Router();

// Configure multer for memory storage (no disk writes for POC)
const storage = multer.memoryStorage();
const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB limit
  },
  fileFilter: (req, file, cb) => {
    // Accept images - check MIME type or file extension
    const isImage = 
      file.mimetype && file.mimetype.startsWith('image/') ||
      /\.(jpg|jpeg|png|gif|heic|webp)$/i.test(file.originalname || file.fieldname);
    
    if (isImage || !file.mimetype) {
      // If no MIME type, accept it and let image processing handle validation
      console.log('Accepting file:', file.originalname, 'MIME:', file.mimetype);
      cb(null, true);
    } else {
      console.log('Rejecting file:', file.originalname, 'MIME:', file.mimetype);
      cb(new Error('Only image files are allowed'), false);
    }
  }
});

/**
 * POST /api/solve
 * Upload image, solve question, generate follow-up questions
 */
router.post('/solve', upload.single('image'), async (req, res) => {
  try {
    // Validate image
    if (!req.file) {
      console.log('No file received. Request body keys:', Object.keys(req.body || {}));
      return res.status(400).json({
        error: 'No image file provided'
      });
    }

    console.log('File received:', {
      originalname: req.file.originalname,
      mimetype: req.file.mimetype,
      size: req.file.size,
      fieldname: req.file.fieldname
    });

    const imageBuffer = req.file.buffer;
    const imageSize = imageBuffer.length;

    // Validate image size
    if (imageSize > 5 * 1024 * 1024) {
      return res.status(400).json({
        error: 'Image too large. Maximum size is 5MB.'
      });
    }

    // Step 1: Solve question from image (don't generate follow-up questions yet)
    console.log('Solving question from image...');
    const solutionData = await solveQuestionFromImage(imageBuffer);

    // Return solution only (follow-up questions will be generated on demand)
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.json({
      success: true,
      data: {
        recognizedQuestion: solutionData.recognizedQuestion,
        subject: solutionData.subject,
        topic: solutionData.topic,
        difficulty: solutionData.difficulty,
        solution: solutionData.solution,
        // No followUpQuestions - will be generated on demand
      }
    });
  } catch (error) {
    console.error('Error in /api/solve:', error);
    
    // Handle specific error types
    if (error.message.includes('timeout')) {
      return res.status(504).json({
        error: 'Request timed out. Please try again.'
      });
    }
    
    if (error.message.includes('rate limit')) {
      return res.status(429).json({
        error: 'Too many requests. Please wait a moment and try again.'
      });
    }

    // Generic error
    res.status(500).json({
      error: 'Failed to process question. Please try again.',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

/**
 * POST /api/generate-practice-questions
 * Generate follow-up practice questions on demand
 */
router.post('/generate-practice-questions', express.json(), async (req, res) => {
  try {
    const { recognizedQuestion, solution, topic, difficulty } = req.body;

    // Validate required fields
    if (!recognizedQuestion || !solution || !topic || !difficulty) {
      return res.status(400).json({
        error: 'Missing required fields: recognizedQuestion, solution, topic, difficulty'
      });
    }

    console.log('Generating follow-up questions on demand...');
    const followUpQuestions = await generateFollowUpQuestions(
      recognizedQuestion,
      typeof solution === 'string' ? solution : JSON.stringify(solution),
      topic,
      difficulty
    );

    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.json({
      success: true,
      data: {
        questions: followUpQuestions
      }
    });
  } catch (error) {
    console.error('Error generating practice questions:', error);
    
    if (error.message.includes('timeout')) {
      return res.status(504).json({
        error: 'Request timed out. Please try again.'
      });
    }
    
    if (error.message.includes('rate limit')) {
      return res.status(429).json({
        error: 'Too many requests. Please wait a moment and try again.'
      });
    }

    res.status(500).json({
      error: 'Failed to generate practice questions. Please try again.',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

/**
 * POST /api/generate-single-question
 * Generate a single practice question (for lazy loading)
 */
router.post('/generate-single-question', express.json(), async (req, res) => {
  try {
    const { recognizedQuestion, solution, topic, difficulty, questionNumber } = req.body;

    // Validate required fields
    if (!recognizedQuestion || !solution || !topic || !difficulty || !questionNumber) {
      return res.status(400).json({
        error: 'Missing required fields: recognizedQuestion, solution, topic, difficulty, questionNumber'
      });
    }

    if (![1, 2, 3].includes(questionNumber)) {
      return res.status(400).json({
        error: 'questionNumber must be 1, 2, or 3'
      });
    }

    console.log(`Generating question ${questionNumber} on demand...`);
    console.log('Request data:', {
      recognizedQuestion: recognizedQuestion?.substring(0, 100),
      topic,
      difficulty,
      questionNumber
    });
    
    try {
      const question = await generateSingleFollowUpQuestion(
        recognizedQuestion,
        typeof solution === 'string' ? solution : JSON.stringify(solution),
        topic,
        difficulty,
        questionNumber
      );

      console.log(`Successfully generated question ${questionNumber}`);
      
      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      res.json({
        success: true,
        data: {
          question: question
        }
      });
    } catch (error) {
      console.error(`Error in generateSingleFollowUpQuestion for Q${questionNumber}:`, error);
      throw error; // Re-throw to be caught by outer catch
    }
  } catch (error) {
    console.error('Error generating single question:', error);
    
    if (error.message.includes('timeout')) {
      return res.status(504).json({
        error: 'Request timed out. Please try again.'
      });
    }
    
    if (error.message.includes('rate limit')) {
      return res.status(429).json({
        error: 'Too many requests. Please wait a moment and try again.'
      });
    }

    res.status(500).json({
      error: 'Failed to generate question. Please try again.',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

/**
 * GET /api/health
 * Health check endpoint
 */
router.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString()
  });
});

module.exports = router;

