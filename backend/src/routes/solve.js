/**
 * JEEVibe - Snap & Solve API Route
 * Handles image upload, OCR, solution generation, and follow-up questions
 */

const express = require('express');
const multer = require('multer');
const { promisify } = require('util');
const { body, validationResult } = require('express-validator');
const { solveQuestionFromImage, generateFollowUpQuestions, generateSingleFollowUpQuestion } = require('../services/openai');
const { authenticateUser } = require('../middleware/auth');
const logger = require('../utils/logger');
const { ApiError } = require('../middleware/errorHandler');
const { storage } = require('../config/firebase');
const { getDailyUsage, saveSnapRecord } = require('../services/snapHistoryService');
const { v4: uuidv4 } = require('uuid');


/**
 * Handle OpenAI errors by mapping them to ApiError
 */
function handleOpenAIError(error, next) {
  if (error.status) {
    if (error.status === 401) {
      // 500 because it's a server config error, not client's fault
      return next(new ApiError(500, 'AI Service Configuration Error: Authentication Failed'));
    }
    if (error.status === 429) {
      return next(new ApiError(429, 'System is busy (Rate Limit), please try again later'));
    }
    if (error.status >= 500) {
      return next(new ApiError(502, 'AI Service temporarily unavailable'));
    }
    // For other errors (400, etc), pass through message if safe?
    // 400 from OpenAI means bad request (our prompt often).
    return next(new ApiError(error.status, error.message));
  }
  next(error);
}

const router = express.Router();

/**
 * Validate image content by checking magic numbers (file signatures)
 * Prevents spoofed MIME types and ensures file is actually an image
 */
function validateImageContent(buffer, declaredMimeType) {
  if (!buffer || buffer.length < 4) {
    return false;
  }

  // File signatures (magic numbers) for different image types
  const signatures = {
    'image/jpeg': [[0xFF, 0xD8, 0xFF]],
    'image/jpg': [[0xFF, 0xD8, 0xFF]],
    'image/png': [[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]],
    'image/gif': [[0x47, 0x49, 0x46, 0x38, 0x37, 0x61], [0x47, 0x49, 0x46, 0x38, 0x39, 0x61]], // GIF87a or GIF89a
    'image/webp': [[0x52, 0x49, 0x46, 0x46]], // RIFF (WebP starts with RIFF)
  };

  const expectedSignatures = signatures[declaredMimeType];
  if (!expectedSignatures) {
    // If we don't have a signature for this type, allow it (for HEIC, etc.)
    return true;
  }

  // Check if buffer matches any of the expected signatures
  return expectedSignatures.some(signature => {
    return signature.every((byte, index) => buffer[index] === byte);
  });
}

// Configure multer for memory storage (no disk writes for POC)
const multerStorage = multer.memoryStorage();
const upload = multer({
  storage: multerStorage,
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
      logger.debug('Accepting file', {
        filename: file.originalname,
        mimetype: file.mimetype,
      });
      cb(null, true);
    } else {
      logger.warn('Rejecting file: Invalid type', {
        filename: file.originalname,
        mimetype: file.mimetype,
      });
      cb(new Error('Only image files are allowed'), false);
    }
  }
});

/**
 * POST /api/solve
 * Upload image, solve question, generate follow-up questions
 * 
 * Authentication: Required (Bearer token in Authorization header)
 */
router.post('/solve', authenticateUser, upload.single('image'), async (req, res, next) => {
  try {
    const userId = req.userId;

    // Validate image
    if (!req.file) {
      logger.warn('No file received in solve request', {
        requestId: req.id,
        userId,
        bodyKeys: Object.keys(req.body || {}),
      });
      throw new ApiError(400, 'No image file provided');
    }

    logger.info('Image upload received', {
      requestId: req.id,
      userId,
      filename: req.file.originalname,
      mimetype: req.file.mimetype,
      size: req.file.size,
    });

    const imageBuffer = req.file.buffer;
    const imageSize = imageBuffer.length;

    // Validate image size
    if (imageSize > 5 * 1024 * 1024) {
      throw new ApiError(400, 'Image too large. Maximum size is 5MB.');
    }

    // Validate image type
    const allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/heic', 'image/webp'];
    if (!allowedMimeTypes.includes(req.file.mimetype)) {
      throw new ApiError(400, `Invalid image type. Allowed types: ${allowedMimeTypes.join(', ')}`);
    }

    // Check daily limit first
    const usage = await getDailyUsage(userId);
    if (usage.used >= usage.limit) {
      logger.warn('Daily snap limit reached', { userId, used: usage.used, limit: usage.limit });
      throw new ApiError(429, `Daily limit of ${usage.limit} snaps reached. Please come back tomorrow!`, {
        code: 'LIMIT_EXHAUSTED',
        resetsAt: usage.resetsAt
      });
    }

    // Validate image content (magic numbers/file signatures)
    if (!validateImageContent(imageBuffer, req.file.mimetype)) {
      throw new ApiError(400, 'File content does not match declared image type. File may be corrupted or not an image.');
    }

    // Step 0: Upload image to Firebase Storage
    logger.info('Updating image to storage', { userId, requestId: req.id });
    const filename = `snaps/${userId}/${uuidv4()}_${req.file.originalname}`;
    const file = storage.bucket().file(filename);

    await file.save(imageBuffer, {
      metadata: {
        contentType: req.file.mimetype,
        metadata: {
          userId: userId,
          requestId: req.id
        }
      }
    });

    // Get public URL or bucket path
    // For simplicity in this POC, we'll use the bucket path
    // The mobile app can use the Firebase Storage SDK to get the download URL
    const imageUrl = `gs://${storage.bucket().name}/${filename}`;

    // Step 1: Solve question from image (don't generate follow-up questions yet)
    logger.info('Processing image with OpenAI', {
      requestId: req.id,
      userId,
      imageSize,
    });

    // Add timeout for long-running OpenAI operations (2 minutes)
    const setTimeoutPromise = promisify(setTimeout);

    const solutionData = await Promise.race([
      solveQuestionFromImage(imageBuffer),
      setTimeoutPromise(120000).then(() => {
        throw new ApiError(504, 'Request timeout. Image processing took too long. Please try again with a clearer image.');
      }),
    ]);

    logger.info('Image processed successfully', {
      requestId: req.id,
      userId,
      subject: solutionData.subject,
      topic: solutionData.topic,
    });

    // Save snap record to history
    const snapId = await saveSnapRecord(userId, {
      recognizedQuestion: solutionData.recognizedQuestion,
      subject: solutionData.subject,
      topic: solutionData.topic,
      difficulty: solutionData.difficulty,
      language: solutionData.language,
      solution: solutionData.solution,
      imageUrl: imageUrl,
      requestId: req.id
    });

    // Get updated usage
    const updatedUsage = await getDailyUsage(userId);

    // Return solution only (follow-up questions will be generated on demand)
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.json({
      success: true,
      data: {
        id: snapId,
        recognizedQuestion: solutionData.recognizedQuestion,
        subject: solutionData.subject,
        topic: solutionData.topic,
        difficulty: solutionData.difficulty,
        language: solutionData.language,
        solution: solutionData.solution,
        imageUrl: imageUrl,
        remainingSnaps: updatedUsage.limit - updatedUsage.used,
        resetsAt: updatedUsage.resetsAt
      },
      requestId: req.id,
    });
  } catch (error) {
    handleOpenAIError(error, next);
  }
});

/**
 * POST /api/generate-practice-questions
 * Generate follow-up practice questions on demand
 * 
 * Authentication: Required (Bearer token in Authorization header)
 */
router.post('/generate-practice-questions',
  authenticateUser,
  [
    body('recognizedQuestion').notEmpty().withMessage('recognizedQuestion is required'),
    body('solution').notEmpty().withMessage('solution is required'),
    body('topic').notEmpty().withMessage('topic is required'),
    body('difficulty').isIn(['easy', 'medium', 'hard']).withMessage('difficulty must be easy, medium, or hard'),
  ],
  async (req, res, next) => {
    try {
      // Check validation errors
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        throw new ApiError(400, 'Validation failed', errors.array());
      }

      const { recognizedQuestion, solution, topic, difficulty } = req.body;
      const userId = req.userId;

      logger.info('Generating follow-up questions', {
        requestId: req.id,
        userId,
        topic,
        difficulty,
      });

      const followUpQuestions = await generateFollowUpQuestions(
        recognizedQuestion,
        typeof solution === 'string' ? solution : JSON.stringify(solution),
        topic,
        difficulty
      );

      logger.info('Follow-up questions generated', {
        requestId: req.id,
        userId,
        questionCount: followUpQuestions.length,
      });

      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      res.json({
        success: true,
        data: {
          questions: followUpQuestions
        },
        requestId: req.id,
      });
    } catch (error) {
      handleOpenAIError(error, next);
    }
  }
);

/**
 * POST /api/generate-single-question
 * Generate a single practice question (for lazy loading)
 * 
 * Authentication: Required (Bearer token in Authorization header)
 */
router.post('/generate-single-question',
  authenticateUser,
  [
    body('recognizedQuestion').notEmpty().withMessage('recognizedQuestion is required'),
    body('solution').notEmpty().withMessage('solution is required'),
    body('topic').notEmpty().withMessage('topic is required'),
    body('difficulty').isIn(['easy', 'medium', 'hard']).withMessage('difficulty must be easy, medium, or hard'),
    body('questionNumber').isInt({ min: 1, max: 3 }).withMessage('questionNumber must be 1, 2, or 3'),
  ],
  async (req, res, next) => {
    try {
      // Check validation errors
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        throw new ApiError(400, 'Validation failed', errors.array());
      }

      const { recognizedQuestion, solution, topic, difficulty, questionNumber } = req.body;
      const userId = req.userId;

      logger.info('Generating single question', {
        requestId: req.id,
        userId,
        topic,
        difficulty,
        questionNumber,
      });

      const question = await generateSingleFollowUpQuestion(
        recognizedQuestion,
        typeof solution === 'string' ? solution : JSON.stringify(solution),
        topic,
        difficulty,
        questionNumber
      );

      logger.info('Single question generated', {
        requestId: req.id,
        userId,
        questionNumber,
      });

      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      res.json({
        success: true,
        data: {
          question: question
        },
        requestId: req.id,
      });
    } catch (error) {
      handleOpenAIError(error, next);
    }
  }
);

// Health check is now in separate route file (routes/health.js)

module.exports = router;

