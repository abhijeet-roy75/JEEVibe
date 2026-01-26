/**
 * JEEVibe - Snap & Solve API Route
 * Handles image upload, OCR, solution generation, and follow-up questions
 */

const express = require('express');
const multer = require('multer');
const { body, validationResult } = require('express-validator');
// AI Provider selection - defaults to Claude, falls back to OpenAI if ANTHROPIC_API_KEY not set
const AI_PROVIDER = process.env.AI_PROVIDER || (process.env.ANTHROPIC_API_KEY ? 'claude' : 'openai');
const aiService = AI_PROVIDER === 'claude'
  ? require('../services/claude')
  : require('../services/openai');
const { solveQuestionFromImage, generateFollowUpQuestions, generateSingleFollowUpQuestion } = aiService;
console.log(`[Snap & Solve] Using AI provider: ${AI_PROVIDER}`);
const { authenticateUser } = require('../middleware/auth');
const logger = require('../utils/logger');
const { ApiError } = require('../middleware/errorHandler');
const { storage, db, admin } = require('../config/firebase');
const { withTimeout } = require('../utils/timeout');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const { calculateSubjectAndOverallThetaUpdate } = require('../services/thetaUpdateService');

// Timeout for Firebase Storage upload (30 seconds)
const STORAGE_UPLOAD_TIMEOUT = 30000;
const { saveSnapRecord } = require('../services/snapHistoryService');
const { canUse, incrementUsage, getUsage } = require('../services/usageTrackingService');
const { v4: uuidv4 } = require('uuid');
const { formatChapterKey } = require('../services/thetaCalculationService');
const { selectQuestionsForChapter } = require('../services/questionSelectionService');
const { getEffectiveTier } = require('../services/subscriptionService');
const { updateStreak } = require('../services/streakService');

// Valid subjects for JEE
const VALID_SUBJECTS = ['Mathematics', 'Physics', 'Chemistry'];

// Snap practice theta multiplier (0.4x compared to daily quiz's 1.0x)
// Only applied when student gets at least 1 correct answer
const SNAP_PRACTICE_THETA_MULTIPLIER = 0.4;

// Encouraging notes for practice questions (used when DB doesn't have key_insight)
const PRIYA_PRACTICE_NOTES = [
  'Great practice! Keep solving more questions like this.',
  'You\'re building strong foundations! Keep going.',
  'Every problem you solve makes you stronger for JEE!',
  'Excellent effort! Practice makes perfect.',
  'Keep up the momentum! You\'re doing great.',
  'This is exactly the kind of practice that leads to success.',
  'Stay focused and keep practicing - you\'ve got this!',
  'Remember: consistent practice is the key to JEE success.',
];


/**
 * Handle AI service errors (OpenAI/Claude) by mapping them to ApiError
 */
function handleAIError(error, next) {
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

    // Check daily limit based on user's tier
    const usageCheck = await canUse(userId, 'snap_solve');
    if (!usageCheck.allowed) {
      logger.warn('Daily snap limit reached', {
        userId,
        tier: usageCheck.tier,
        used: usageCheck.used,
        limit: usageCheck.limit
      });
      throw new ApiError(429, `Daily limit of ${usageCheck.limit} snaps reached. ${usageCheck.tier === 'free' ? 'Upgrade to Pro for more!' : 'Please come back tomorrow!'}`, {
        code: 'LIMIT_REACHED',
        usage: {
          used: usageCheck.used,
          limit: usageCheck.limit,
          remaining: 0,
          resets_at: usageCheck.resets_at
        },
        tier: usageCheck.tier,
        upgrade_prompt: usageCheck.tier === 'free' ? 'Upgrade to Pro for 10 daily snaps' : null
      });
    }

    // Validate image content (magic numbers/file signatures)
    if (!validateImageContent(imageBuffer, req.file.mimetype)) {
      throw new ApiError(400, 'File content does not match declared image type. File may be corrupted or not an image.');
    }

    // Performance tracking - Step 0: Upload image to Firebase Storage
    const perfStart = Date.now();
    const perfSteps = {};

    logger.info('⏱️  [PERF] Starting solve request', { userId, requestId: req.id, imageSize });

    const storageStartTime = Date.now();
    const filename = `snaps/${userId}/${uuidv4()}_${req.file.originalname}`;
    const file = storage.bucket().file(filename);

    // Upload with timeout protection
    await withTimeout(
      file.save(imageBuffer, {
        metadata: {
          contentType: req.file.mimetype,
          metadata: {
            userId: userId,
            requestId: req.id
          }
        }
      }),
      STORAGE_UPLOAD_TIMEOUT,
      'Image upload timed out. Please try again.'
    );
    perfSteps.firebaseStorageUpload = Date.now() - storageStartTime;
    logger.info(`⏱️  [PERF] Firebase Storage upload: ${perfSteps.firebaseStorageUpload}ms`, { requestId: req.id });

    // Get public URL or bucket path
    const imageUrl = `gs://${storage.bucket().name}/${filename}`;

    // Step 1: Solve question from image (don't generate follow-up questions yet)
    // Note: AI service has built-in circuit breaker with 120s timeout
    const aiProviderName = AI_PROVIDER === 'claude' ? 'Claude' : 'OpenAI';
    logger.info(`⏱️  [PERF] Starting ${aiProviderName} Vision API call`, {
      requestId: req.id,
      userId,
      imageSize,
      aiProvider: AI_PROVIDER,
    });

    const aiStartTime = Date.now();
    const solutionData = await solveQuestionFromImage(imageBuffer);
    perfSteps.aiApiCall = Date.now() - aiStartTime;
    logger.info(`⏱️  [PERF] ${aiProviderName} Vision API call: ${perfSteps.aiApiCall}ms`, {
      requestId: req.id,
      subject: solutionData.subject,
      topic: solutionData.topic,
      aiProvider: AI_PROVIDER,
    });

    // Run Firestore operations in parallel (save + increment usage)
    // This saves ~1-2 seconds by avoiding sequential round-trips to Firestore
    const firestoreStart = Date.now();
    const [snapId, updatedUsage] = await Promise.all([
      saveSnapRecord(userId, {
        recognizedQuestion: solutionData.recognizedQuestion,
        subject: solutionData.subject,
        topic: solutionData.topic,
        difficulty: solutionData.difficulty,
        language: solutionData.language,
        solution: solutionData.solution,
        imageUrl: imageUrl,
        requestId: req.id
      }),
      incrementUsage(userId, 'snap_solve')
    ]);
    perfSteps.firestoreOperations = Date.now() - firestoreStart;
    logger.info(`⏱️  [PERF] Firestore operations (parallel): ${perfSteps.firestoreOperations}ms`, { requestId: req.id });

    // Calculate and log total performance
    const totalTime = Date.now() - perfStart;
    perfSteps.totalTime = totalTime;

    logger.info('⏱️  [PERF] Request completed - Performance Summary', {
      requestId: req.id,
      userId,
      totalTimeMs: totalTime,
      aiProvider: AI_PROVIDER,
      breakdown: {
        firebaseStorageUpload: `${perfSteps.firebaseStorageUpload}ms (${((perfSteps.firebaseStorageUpload / totalTime) * 100).toFixed(1)}%)`,
        [`${aiProviderName.toLowerCase()}ApiCall`]: `${perfSteps.aiApiCall}ms (${((perfSteps.aiApiCall / totalTime) * 100).toFixed(1)}%)`,
        firestoreOperations: `${perfSteps.firestoreOperations}ms (${((perfSteps.firestoreOperations / totalTime) * 100).toFixed(1)}%) - parallel save + usage check`
      }
    });

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
        remainingSnaps: updatedUsage.is_unlimited ? -1 : updatedUsage.remaining,
        dailyLimit: updatedUsage.limit,
        tier: updatedUsage.tier,
        resetsAt: updatedUsage.resets_at
      },
      requestId: req.id,
    });
  } catch (error) {
    handleAIError(error, next);
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

      const { recognizedQuestion, solution, topic, difficulty, language } = req.body;
      const userId = req.userId;

      logger.info('Generating follow-up questions', {
        requestId: req.id,
        userId,
        topic,
        difficulty,
        language
      });

      const followUpQuestions = await generateFollowUpQuestions(
        recognizedQuestion,
        typeof solution === 'string' ? solution : JSON.stringify(solution),
        topic,
        difficulty,
        language
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
      handleAIError(error, next);
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

      const { recognizedQuestion, solution, topic, difficulty, questionNumber, language } = req.body;
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
        questionNumber,
        language
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
      handleAIError(error, next);
    }
  }
);

// Health check is now in separate route file (routes/health.js)

// ============================================================================
// SNAP PRACTICE - Database-first question selection with AI fallback
// ============================================================================

/**
 * Map difficulty string to theta value for IRT-based question selection
 */
function getDifficultyTheta(difficulty) {
  const mapping = {
    'easy': -1.0,
    'medium': 0.0,
    'hard': 1.0
  };
  return mapping[difficulty] || 0.0;
}

/**
 * Get a random Priya note for practice questions
 */
function getRandomPriyaNote() {
  return PRIYA_PRACTICE_NOTES[Math.floor(Math.random() * PRIYA_PRACTICE_NOTES.length)];
}

/**
 * Transform a database question to FollowUpQuestion format
 * This ensures compatibility with the existing mobile app models
 */
function transformDatabaseQuestionToFollowUp(dbQuestion) {
  // Convert options to map format {A: "text", B: "text"}
  // Handle multiple possible formats from database
  let optionsMap = {};

  if (Array.isArray(dbQuestion.options)) {
    // Format 1: [{option_id: 'A', text: '...'}, ...]
    if (dbQuestion.options.length > 0 && typeof dbQuestion.options[0] === 'object' && dbQuestion.options[0].option_id) {
      dbQuestion.options.forEach(opt => {
        optionsMap[opt.option_id] = opt.text || opt.option_text || '';
      });
    }
    // Format 2: Array of strings ['option1', 'option2', 'option3', 'option4']
    else if (dbQuestion.options.length > 0 && typeof dbQuestion.options[0] === 'string') {
      const labels = ['A', 'B', 'C', 'D'];
      dbQuestion.options.forEach((text, index) => {
        if (index < 4) {
          optionsMap[labels[index]] = text;
        }
      });
    }
  }
  // Format 3: Already a map {A: '...', B: '...'}
  else if (dbQuestion.options && typeof dbQuestion.options === 'object') {
    optionsMap = { ...dbQuestion.options };
  }

  // Log warning if options are empty (likely a data issue)
  if (Object.keys(optionsMap).length === 0) {
    logger.warn('Database question has no options', {
      questionId: dbQuestion.question_id,
      questionType: dbQuestion.question_type,
      hasOptions: !!dbQuestion.options,
      optionsType: typeof dbQuestion.options,
      optionsValue: JSON.stringify(dbQuestion.options)?.substring(0, 200)
    });
  }

  // Extract steps - handle both array of strings and array of objects
  let steps = [];
  if (Array.isArray(dbQuestion.solution_steps)) {
    steps = dbQuestion.solution_steps.map(step => {
      if (typeof step === 'string') return step;
      return step.explanation || step.description || step.text || JSON.stringify(step);
    });
  }

  // Use key_insight from DB if available, otherwise pick a random encouraging note
  const priyaNote = dbQuestion.metadata?.key_insight
    || dbQuestion.key_insight
    || dbQuestion.metadata?.tip
    || getRandomPriyaNote();

  return {
    question: dbQuestion.question_text || dbQuestion.text || '',
    options: optionsMap,
    correctAnswer: dbQuestion.correct_answer || 'A',
    explanation: {
      approach: dbQuestion.solution_text || 'Apply the concept step by step.',
      steps: steps,
      finalAnswer: dbQuestion.correct_answer_text || dbQuestion.correct_answer || ''
    },
    priyaMaamNote: priyaNote,
    source: 'database',
    questionId: dbQuestion.question_id,
    questionType: dbQuestion.question_type || 'mcq_single' // 'mcq_single' or 'numerical'
  };
}

/**
 * POST /api/snap-practice/questions
 * Get practice questions from database with AI fallback
 *
 * Authentication: Required (Bearer token in Authorization header)
 *
 * Request body:
 * - subject: string (required) - "Mathematics", "Physics", "Chemistry"
 * - topic: string (required) - Chapter name from snap-solve
 * - difficulty: string (required) - "easy", "medium", "hard"
 * - count: number (optional) - Number of questions (default: 3, max: 5)
 * - language: string (optional) - "en" or "hi" (default: "en")
 * - recognizedQuestion: string (optional) - Original question for AI fallback
 * - solution: object (optional) - Original solution for AI fallback
 */
router.post('/snap-practice/questions',
  authenticateUser,
  [
    body('subject').isIn(VALID_SUBJECTS).withMessage(`subject must be one of: ${VALID_SUBJECTS.join(', ')}`),
    body('topic').notEmpty().withMessage('topic is required'),
    body('difficulty').isIn(['easy', 'medium', 'hard']).withMessage('difficulty must be easy, medium, or hard'),
    body('count').optional().isInt({ min: 1, max: 5 }).withMessage('count must be between 1 and 5'),
  ],
  async (req, res, next) => {
    try {
      // Check validation errors
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        throw new ApiError(400, 'Validation failed', errors.array());
      }

      const {
        subject,
        topic,
        difficulty,
        count = 3,
        language = 'en',
        recognizedQuestion,
        solution
      } = req.body;
      const userId = req.userId;

      // P0 Fix: Verify user has Pro or Ultra tier
      const tierInfo = await getEffectiveTier(userId);
      if (tierInfo.tier !== 'pro' && tierInfo.tier !== 'ultra') {
        throw new ApiError(403, 'Snap Practice is available for Pro and Ultra subscribers only', {
          code: 'TIER_REQUIRED',
          currentTier: tierInfo.tier,
          requiredTiers: ['pro', 'ultra']
        });
      }

      logger.info('Snap practice questions requested', {
        requestId: req.id,
        userId,
        subject,
        topic,
        difficulty,
        count,
        tier: tierInfo.tier
      });

      // Step 1: Try to get questions from database
      const chapterKey = formatChapterKey(subject, topic);
      const theta = getDifficultyTheta(difficulty);

      logger.info('Attempting database question selection', {
        requestId: req.id,
        chapterKey,
        theta,
        count
      });

      let dbQuestions = [];
      try {
        dbQuestions = await selectQuestionsForChapter(chapterKey, theta, new Set(), count);
      } catch (dbError) {
        logger.warn('Database question selection failed', {
          requestId: req.id,
          error: dbError.message
        });
      }

      // Step 2: If we got enough questions from DB, transform and return them
      if (dbQuestions && dbQuestions.length >= count) {
        const transformedQuestions = dbQuestions.map(q => transformDatabaseQuestionToFollowUp(q));

        logger.info('Returning database questions', {
          requestId: req.id,
          userId,
          count: transformedQuestions.length,
          source: 'database'
        });

        res.setHeader('Content-Type', 'application/json; charset=utf-8');
        return res.json({
          success: true,
          data: {
            questions: transformedQuestions,
            source: 'database',
            chapterKey: chapterKey
          },
          requestId: req.id
        });
      }

      // Step 3: If DB has some questions but not enough, use what we have + AI for rest
      const dbTransformed = dbQuestions.map(q => transformDatabaseQuestionToFollowUp(q));
      const needFromAI = count - dbTransformed.length;

      // OPTIMIZATION: If DB has 0 questions, return immediately with empty results
      // This allows the mobile app to fall back to individual question generation
      // which provides better progressive loading UX (questions appear one by one)
      if (dbTransformed.length === 0) {
        logger.info('No DB questions found, returning empty for progressive loading fallback', {
          requestId: req.id,
          chapterKey: chapterKey
        });

        res.setHeader('Content-Type', 'application/json; charset=utf-8');
        return res.json({
          success: true,
          data: {
            questions: [],
            source: 'none',
            note: 'No questions in database for this topic. Use individual generation.'
          },
          requestId: req.id
        });
      }

      if (needFromAI > 0 && recognizedQuestion && solution) {
        logger.info('Falling back to AI for remaining questions', {
          requestId: req.id,
          dbCount: dbTransformed.length,
          aiNeeded: needFromAI
        });

        try {
          // Generate remaining questions via AI
          const aiQuestions = await generateFollowUpQuestions(
            recognizedQuestion,
            typeof solution === 'string' ? solution : JSON.stringify(solution),
            topic,
            difficulty,
            language
          );

          // Take only what we need and mark as AI-sourced
          const aiTransformed = aiQuestions.slice(0, needFromAI).map(q => ({
            ...q,
            source: 'ai'
          }));

          const allQuestions = [...dbTransformed, ...aiTransformed];

          // Determine source: 'ai' if all from AI, 'mixed' if combination
          const source = dbTransformed.length === 0 ? 'ai' : 'mixed';

          logger.info(`Returning ${source} questions`, {
            requestId: req.id,
            userId,
            dbCount: dbTransformed.length,
            aiCount: aiTransformed.length,
            source: source
          });

          res.setHeader('Content-Type', 'application/json; charset=utf-8');
          return res.json({
            success: true,
            data: {
              questions: allQuestions,
              source: source,
              dbCount: dbTransformed.length,
              aiCount: aiTransformed.length
            },
            requestId: req.id
          });
        } catch (aiError) {
          logger.error('AI fallback failed', {
            requestId: req.id,
            error: aiError.message
          });
          // If AI fails but we have some DB questions, return those
          if (dbTransformed.length > 0) {
            res.setHeader('Content-Type', 'application/json; charset=utf-8');
            return res.json({
              success: true,
              data: {
                questions: dbTransformed,
                source: 'database',
                note: 'Partial results - AI fallback failed'
              },
              requestId: req.id
            });
          }
          throw aiError;
        }
      }

      // Step 4: No DB questions and no AI context - try pure AI fallback
      if (dbTransformed.length === 0 && recognizedQuestion && solution) {
        logger.info('No DB questions, using pure AI generation', {
          requestId: req.id,
          topic,
          difficulty
        });

        const aiQuestions = await generateFollowUpQuestions(
          recognizedQuestion,
          typeof solution === 'string' ? solution : JSON.stringify(solution),
          topic,
          difficulty,
          language
        );

        const aiTransformed = aiQuestions.slice(0, count).map(q => ({
          ...q,
          source: 'ai'
        }));

        logger.info('Returning AI-generated questions', {
          requestId: req.id,
          userId,
          count: aiTransformed.length,
          source: 'ai'
        });

        res.setHeader('Content-Type', 'application/json; charset=utf-8');
        return res.json({
          success: true,
          data: {
            questions: aiTransformed,
            source: 'ai'
          },
          requestId: req.id
        });
      }

      // Step 5: Return whatever we have (could be partial DB results)
      if (dbTransformed.length > 0) {
        logger.info('Returning partial database questions', {
          requestId: req.id,
          userId,
          count: dbTransformed.length,
          source: 'database'
        });

        res.setHeader('Content-Type', 'application/json; charset=utf-8');
        return res.json({
          success: true,
          data: {
            questions: dbTransformed,
            source: 'database',
            note: `Only ${dbTransformed.length} questions available`
          },
          requestId: req.id
        });
      }

      // Step 6: No questions available at all
      throw new ApiError(404, 'No practice questions available for this topic. Please try a different topic.');

    } catch (error) {
      handleAIError(error, next);
    }
  }
);

/**
 * POST /api/snap-practice/complete
 * Complete a snap practice session and record results
 *
 * Updates:
 * - total_questions_solved counter
 * - cumulative_stats (total_questions_correct, total_questions_attempted)
 * - subject-level theta with 0.4x multiplier (only if correct >= 1)
 * - snap_practice_history for analytics
 *
 * Body: {
 *   subject: string,
 *   topic: string,
 *   chapter_key: string (optional - will be derived from topic if not provided),
 *   results: [{
 *     question_number: number,
 *     is_correct: boolean,
 *     time_spent_seconds: number,
 *     question_id: string (optional)
 *   }],
 *   total_time_seconds: number,
 *   source: string ("database" | "ai" | "mixed")
 * }
 *
 * Returns: { success, summary, theta_update }
 */
router.post('/snap-practice/complete',
  authenticateUser,
  [
    body('subject').isIn(VALID_SUBJECTS).withMessage('Invalid subject'),
    body('topic').notEmpty().withMessage('Topic is required'),
    body('results').isArray({ min: 1, max: 5 }).withMessage('Results must be an array of 1-5 items'),
    body('results.*.is_correct').isBoolean().withMessage('is_correct must be a boolean'),
    body('results.*.time_spent_seconds').isInt({ min: 0 }).withMessage('time_spent_seconds must be a non-negative integer'),
    body('total_time_seconds').isInt({ min: 0 }).withMessage('total_time_seconds must be a non-negative integer')
  ],
  async (req, res, next) => {
    try {
      // Validate request
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return next(new ApiError(400, 'Validation failed', errors.array()));
      }

      const userId = req.userId;
      const { subject, topic, chapter_key, results, total_time_seconds, source } = req.body;

      // Calculate stats
      const totalQuestions = results.length;
      const correctCount = results.filter(r => r.is_correct).length;
      const accuracy = totalQuestions > 0 ? correctCount / totalQuestions : 0;

      logger.info('🔵 [SNAP PRACTICE COMPLETE] Starting', {
        userId,
        subject,
        topic,
        chapterKey: chapter_key,
        totalQuestions,
        correctCount,
        accuracy: Math.round(accuracy * 100) / 100,
        source
      });

      // Get user data
      const userRef = db.collection('users').doc(userId);
      const userDoc = await retryFirestoreOperation(async () => {
        return await userRef.get();
      });

      if (!userDoc.exists) {
        throw new ApiError(404, 'User not found');
      }

      const userData = userDoc.data();

      // Derive chapter key if not provided
      const effectiveChapterKey = chapter_key || formatChapterKey(subject, topic);

      // ========================================================================
      // THETA UPDATE (only if correct >= 1)
      // ========================================================================
      let thetaUpdateInfo = null;

      if (correctCount > 0) {
        const thetaByChapter = userData.theta_by_chapter || {};

        // Get current chapter theta or use default
        const currentChapterData = thetaByChapter[effectiveChapterKey] || {
          theta: 0.0,
          se: 0.5,
          attempts: 0,
          correct: 0,
          accuracy: 0,
          percentile: 50
        };

        // Calculate simple accuracy-based theta adjustment
        // Higher accuracy = positive theta change, lower = negative
        // Using a simple ELO-like formula scaled by multiplier
        const expectedAccuracy = 0.5; // Baseline expectation
        const accuracyDelta = accuracy - expectedAccuracy;

        // Base theta change: +0.1 for each 10% above expected, -0.1 for each 10% below
        const baseThetaDelta = accuracyDelta * 1.0;

        // Apply 0.4x multiplier for snap practice
        const adjustedThetaDelta = baseThetaDelta * SNAP_PRACTICE_THETA_MULTIPLIER;

        // Calculate new theta (bounded -3 to +3)
        const newTheta = Math.max(-3, Math.min(3, currentChapterData.theta + adjustedThetaDelta));

        // Update chapter data
        const updatedChapterData = {
          theta: newTheta,
          se: Math.max(0.15, currentChapterData.se * 0.98), // Slight SE reduction
          attempts: currentChapterData.attempts + totalQuestions,
          correct: currentChapterData.correct + correctCount,
          accuracy: (currentChapterData.correct + correctCount) / (currentChapterData.attempts + totalQuestions),
          percentile: Math.round(50 + (newTheta / 3) * 50), // Rough percentile estimate
          last_updated: admin.firestore.FieldValue.serverTimestamp()
        };

        // Merge updated chapter data
        const updatedThetaByChapter = {
          ...thetaByChapter,
          [effectiveChapterKey]: updatedChapterData
        };

        // Calculate subject and overall theta
        const subjectAndOverallUpdate = calculateSubjectAndOverallThetaUpdate(updatedThetaByChapter);

        thetaUpdateInfo = {
          chapter_key: effectiveChapterKey,
          before: {
            theta: currentChapterData.theta,
            percentile: currentChapterData.percentile
          },
          after: {
            theta: newTheta,
            percentile: updatedChapterData.percentile
          },
          delta: adjustedThetaDelta,
          multiplier: SNAP_PRACTICE_THETA_MULTIPLIER,
          subject_theta: subjectAndOverallUpdate.theta_by_subject?.[subject.toLowerCase()]?.theta ?? null,
          overall_theta: subjectAndOverallUpdate.overall_theta ?? null
        };

        logger.info('🟢 [SNAP PRACTICE COMPLETE] Theta update calculated', {
          userId,
          chapterKey: effectiveChapterKey,
          thetaUpdateInfo
        });

        // Update user document with theta and stats
        await retryFirestoreOperation(async () => {
          return await userRef.update({
            theta_by_chapter: updatedThetaByChapter,
            theta_by_subject: subjectAndOverallUpdate.theta_by_subject,
            subject_accuracy: subjectAndOverallUpdate.subject_accuracy,
            overall_theta: subjectAndOverallUpdate.overall_theta,
            overall_percentile: subjectAndOverallUpdate.overall_percentile,
            total_questions_solved: admin.firestore.FieldValue.increment(totalQuestions),
            total_time_spent_minutes: admin.firestore.FieldValue.increment(Math.round(total_time_seconds / 60)),
            'cumulative_stats.total_questions_correct': admin.firestore.FieldValue.increment(correctCount),
            'cumulative_stats.total_questions_attempted': admin.firestore.FieldValue.increment(totalQuestions),
            'cumulative_stats.last_updated': admin.firestore.FieldValue.serverTimestamp(),
            // Track snap practice specific stats
            'snap_practice_stats.total_sessions': admin.firestore.FieldValue.increment(1),
            'snap_practice_stats.total_questions': admin.firestore.FieldValue.increment(totalQuestions),
            'snap_practice_stats.total_correct': admin.firestore.FieldValue.increment(correctCount),
            'snap_practice_stats.last_session': admin.firestore.FieldValue.serverTimestamp()
          });
        });
      } else {
        // No correct answers - update stats only, no theta update
        logger.info('🟡 [SNAP PRACTICE COMPLETE] No correct answers - skipping theta update', {
          userId,
          subject,
          topic,
          totalQuestions,
          correctCount
        });

        await retryFirestoreOperation(async () => {
          return await userRef.update({
            total_questions_solved: admin.firestore.FieldValue.increment(totalQuestions),
            total_time_spent_minutes: admin.firestore.FieldValue.increment(Math.round(total_time_seconds / 60)),
            'cumulative_stats.total_questions_correct': admin.firestore.FieldValue.increment(correctCount),
            'cumulative_stats.total_questions_attempted': admin.firestore.FieldValue.increment(totalQuestions),
            'cumulative_stats.last_updated': admin.firestore.FieldValue.serverTimestamp(),
            'snap_practice_stats.total_sessions': admin.firestore.FieldValue.increment(1),
            'snap_practice_stats.total_questions': admin.firestore.FieldValue.increment(totalQuestions),
            'snap_practice_stats.total_correct': admin.firestore.FieldValue.increment(correctCount),
            'snap_practice_stats.last_session': admin.firestore.FieldValue.serverTimestamp()
          });
        });
      }

      // ========================================================================
      // UPDATE PRACTICE STREAK
      // ========================================================================
      try {
        await updateStreak(userId);
      } catch (error) {
        logger.error('Error updating streak after snap practice', {
          userId,
          error: error.message
        });
      }

      // ========================================================================
      // SAVE SESSION TO HISTORY (for analytics)
      // ========================================================================
      const sessionId = `snap_practice_${Date.now()}_${uuidv4().slice(0, 8)}`;

      await retryFirestoreOperation(async () => {
        return await db.collection('snap_practice_sessions')
          .doc(userId)
          .collection('sessions')
          .doc(sessionId)
          .set({
            session_id: sessionId,
            subject,
            topic,
            chapter_key: effectiveChapterKey,
            total_questions: totalQuestions,
            correct_count: correctCount,
            accuracy: Math.round(accuracy * 100) / 100,
            total_time_seconds,
            source: source || 'unknown',
            results: results.map((r, i) => ({
              question_number: r.question_number || i + 1,
              is_correct: r.is_correct,
              time_spent_seconds: r.time_spent_seconds,
              question_id: r.question_id || null
            })),
            theta_update: thetaUpdateInfo,
            created_at: admin.firestore.FieldValue.serverTimestamp()
          });
      });

      logger.info('✅ [SNAP PRACTICE COMPLETE] Session completed successfully', {
        userId,
        sessionId,
        subject,
        topic,
        totalQuestions,
        correctCount,
        thetaUpdated: correctCount > 0
      });

      res.json({
        success: true,
        message: 'Snap practice session completed',
        summary: {
          session_id: sessionId,
          subject,
          topic,
          chapter_key: effectiveChapterKey,
          total_questions: totalQuestions,
          correct_count: correctCount,
          accuracy: Math.round(accuracy * 100),
          total_time_seconds,
          theta_updated: correctCount > 0
        },
        theta_update: thetaUpdateInfo,
        requestId: req.id
      });

    } catch (error) {
      logger.error('❌ [SNAP PRACTICE COMPLETE] Error', {
        userId: req.userId,
        error: error.message,
        stack: error.stack
      });
      next(error);
    }
  }
);

module.exports = router;

