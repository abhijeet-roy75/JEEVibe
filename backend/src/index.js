/**
 * JEEVibe - Snap & Solve Backend Server
 * Express server for handling image uploads and OpenAI API calls
 */

require('dotenv').config();

// ========================================
// SENTRY ERROR TRACKING (Initialize first!)
// ========================================
const Sentry = require('@sentry/node');

if (process.env.SENTRY_DSN) {
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV || 'development',

    // Performance monitoring (sample 10% of transactions in production)
    tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,

    // Filter out sensitive data
    beforeSend(event) {
      // Remove sensitive headers
      if (event.request?.headers) {
        delete event.request.headers['authorization'];
        delete event.request.headers['cookie'];
      }
      // Remove sensitive body fields
      if (event.request?.data) {
        const data = typeof event.request.data === 'string'
          ? JSON.parse(event.request.data)
          : event.request.data;
        if (data.password) data.password = '[REDACTED]';
        if (data.token) data.token = '[REDACTED]';
        event.request.data = JSON.stringify(data);
      }
      return event;
    },

    // Ignore certain errors
    ignoreErrors: [
      'CORS',
      'Not allowed by CORS',
      'Rate limit exceeded',
    ],
  });
  console.log('✅ Sentry initialized');
}

const express = require('express');
const cors = require('cors');
const compression = require('compression');
const solveRouter = require('./routes/solve');

// Initialize Firebase
const { db, storage } = require('./config/firebase');

// Initialize logger (must be before other imports that use it)
const logger = require('./utils/logger');
logger.info('🔥 Firebase connected');

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  const errorInfo = {
    promise: promise.toString(),
    reason: reason instanceof Error ? {
      message: reason.message,
      stack: reason.stack,
    } : reason,
  };
  logger.error('Unhandled Rejection', errorInfo);
  // Report to Sentry
  if (process.env.SENTRY_DSN) {
    Sentry.captureException(reason instanceof Error ? reason : new Error(String(reason)));
  }
  // Also log to console for Render.com visibility
  console.error('UNHANDLED REJECTION:', JSON.stringify(errorInfo, null, 2));
  // Don't exit, just log the error
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  const errorInfo = {
    message: error.message,
    stack: error.stack,
  };
  logger.error('Uncaught Exception', errorInfo);
  // Report to Sentry
  if (process.env.SENTRY_DSN) {
    Sentry.captureException(error);
  }
  // Also log to console for Render.com visibility
  console.error('UNCAUGHT EXCEPTION:', JSON.stringify(errorInfo, null, 2));
  // Don't exit immediately, log and continue
});

const app = express();
const PORT = process.env.PORT || 3000;

// Trust proxy for Render.com and other reverse proxies
// Required for express-rate-limit to correctly identify users via X-Forwarded-For header
app.set('trust proxy', 1);

// ========================================
// SECURITY MIDDLEWARE
// ========================================

// CORS Configuration
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map(origin => origin.trim())
  : ['http://localhost:3000', 'http://localhost:8080']; // Default for development

const corsOptions = {
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, Postman, etc.)
    if (!origin) return callback(null, true);

    // In production, strictly validate origins
    if (process.env.NODE_ENV === 'production') {
      if (allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        logger.warn('CORS blocked request in production', { origin });
        callback(new Error('Not allowed by CORS'));
      }
    } else {
      // In development, allow localhost and common dev origins
      const devOrigins = [
        'http://localhost:3000',
        'http://localhost:8080',
        'http://127.0.0.1:3000',
        'http://127.0.0.1:8080',
      ];

      // Allow localhost with any port, or exact matches
      const isLocalhost = origin.startsWith('http://localhost:') ||
        origin.startsWith('http://127.0.0.1:') ||
        devOrigins.includes(origin);

      if (isLocalhost || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        logger.warn('CORS blocked request in development', { origin });
        callback(new Error('Not allowed by CORS'));
      }
    }
  },
  credentials: true,
  optionsSuccessStatus: 200,
  methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-ID', 'x-session-token', 'x-device-id'],
};

app.use(cors(corsOptions));

// Request compression (reduce response sizes)
app.use(compression());

// Body parsing with size limits
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// ========================================
// REQUEST TRACKING & LOGGING
// ========================================

// Request ID middleware (must be early in chain)
const requestIdMiddleware = require('./middleware/requestId');
app.use(requestIdMiddleware);

// Request logging middleware
app.use((req, res, next) => {
  logger.info('Incoming request', {
    requestId: req.id,
    method: req.method,
    path: req.path,
    ip: req.ip,
    userAgent: req.get('user-agent'),
  });

  // Set Sentry context for this request
  if (process.env.SENTRY_DSN) {
    Sentry.setTag('request_id', req.id);
    Sentry.setContext('request', {
      method: req.method,
      path: req.path,
      ip: req.ip,
    });
  }

  next();
});

// ========================================
// ROUTES (Health check before rate limiting)
// ========================================

// Health check endpoint (BEFORE rate limiting - important for monitoring)
app.get('/api/health', require('./routes/health'));

// ========================================
// CONDITIONAL AUTHENTICATION (Before Rate Limiting)
// ========================================

// CRITICAL: This must run BEFORE rate limiting so req.userId is available
// for user-based rate limit keys. It attempts authentication but doesn't block
// unauthenticated requests (protected routes will block them later via authenticateUser).
const { conditionalAuth } = require('./middleware/conditionalAuth');
app.use('/api', conditionalAuth);

logger.info('✅ Conditional auth middleware enabled - user-based rate limiting active');

// ========================================
// RATE LIMITING (After Conditional Auth)
// ========================================

const { apiLimiter, strictLimiter, imageProcessingLimiter } = require('./middleware/rateLimiter');

// Apply general rate limiting to all API routes
// Now req.userId is set (if authenticated), so rate limiter can use user-based keys
app.use('/api', apiLimiter);

// Apply strict rate limiting to expensive operations
app.use('/api/solve', imageProcessingLimiter);
app.use('/api/assessment/submit', strictLimiter);

// ========================================
// SESSION VALIDATION (Single-Device Enforcement)
// ========================================

// IMPORTANT: Session validation is applied at the ROUTE level, not here
// Each route file applies validateSessionMiddleware AFTER authenticateUser
// This ensures req.userId is available for session validation
//
// Routes that need session validation must use this pattern:
//   router.get('/endpoint', authenticateUser, validateSessionMiddleware, async (req, res) => { ... })
//
// Exempt routes (no session validation):
// - /api/auth/* (session creation happens here)
// - /api/users/profile GET (profile check during OTP login)
// - /api/users/fcm-token (FCM registration during login)
// - /api/health (monitoring)
// - /api/cron/* (scheduled tasks)
// - /api/share/* (public routes)

logger.warn('⚠️  Session validation DISABLED temporarily - breaks login flow');

// API Routes
app.use('/api', solveRouter);

const assessmentRouter = require('./routes/assessment');
app.use('/api/assessment', assessmentRouter);

const usersRouter = require('./routes/users');
app.use('/api/users', usersRouter);

const cronRouter = require('./routes/cron');
app.use('/api/cron', cronRouter);

const dailyQuizRouter = require('./routes/dailyQuiz');
app.use('/api/daily-quiz', dailyQuizRouter);

const analyticsRouter = require('./routes/analytics');
const { analyticsLimiter } = require('./middleware/rateLimiter');
app.use('/api/analytics', analyticsLimiter, analyticsRouter);

const snapHistoryRouter = require('./routes/snapHistory');
app.use('/api', snapHistoryRouter);

const feedbackRouter = require('./routes/feedback');
app.use('/api/feedback', feedbackRouter);

const subscriptionsRouter = require('./routes/subscriptions');
app.use('/api/subscriptions', subscriptionsRouter);

const aiTutorRouter = require('./routes/aiTutor');
app.use('/api/ai-tutor', aiTutorRouter);

const chapterPracticeRouter = require('./routes/chapterPractice');
app.use('/api/chapter-practice', chapterPracticeRouter);

const weakSpotsRouter = require('./routes/weakSpots');
app.use('/api', weakSpotsRouter);

const shareRouter = require('./routes/share');
app.use('/api/share', shareRouter);

const adminRouter = require('./routes/admin');
app.use('/api/admin', adminRouter);

const authRouter = require('./routes/auth');
app.use('/api/auth', authRouter);

const mockTestsRouter = require('./routes/mockTests');
app.use('/api/mock-tests', mockTestsRouter);

const teachersRouter = require('./routes/teachers');
app.use('/api/teachers', teachersRouter);

const chaptersRouter = require('./routes/chapters');
app.use('/api/chapters', chaptersRouter);

const unlockQuizRouter = require('./routes/unlockQuiz');
app.use('/api/unlock-quiz', unlockQuizRouter);

// Test endpoints (only in development)
if (process.env.NODE_ENV !== 'production') {
  const testFirebaseRouter = require('./routes/test-firebase');
  app.use('/api', testFirebaseRouter);
  logger.info('Test endpoints enabled (development mode)');
} else {
  logger.warn('Test endpoints disabled (production mode)');
}

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'JEEVibe Snap & Solve API',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    endpoints: {
      health: 'GET /api/health',
      solve: 'POST /api/solve',
      assessment: {
        questions: 'GET /api/assessment/questions',
        submit: 'POST /api/assessment/submit',
        results: 'GET /api/assessment/results/:userId'
      },
      users: {
        profile: 'GET /api/users/profile',
        createProfile: 'POST /api/users/profile',
        profileExists: 'GET /api/users/profile/exists',
        updateLastActive: 'PATCH /api/users/profile/last-active',
        markComplete: 'PATCH /api/users/profile/complete'
      },
      dailyQuiz: {
        generate: 'GET /api/daily-quiz/generate',
        start: 'POST /api/daily-quiz/start',
        submitAnswer: 'POST /api/daily-quiz/submit-answer',
        complete: 'POST /api/daily-quiz/complete',
        active: 'GET /api/daily-quiz/active',
        history: 'GET /api/daily-quiz/history',
        result: 'GET /api/daily-quiz/result/:quiz_id',
        question: 'GET /api/daily-quiz/question/:question_id',
        summary: 'GET /api/daily-quiz/summary',
        progress: 'GET /api/daily-quiz/progress',
        stats: 'GET /api/daily-quiz/stats',
        chapterProgress: 'GET /api/daily-quiz/chapter-progress/:chapter_key'
      },
      analytics: {
        overview: 'GET /api/analytics/overview',
        mastery: 'GET /api/analytics/mastery/:subject',
        masteryTimeline: 'GET /api/analytics/mastery-timeline',
        allChapters: 'GET /api/analytics/all-chapters'
      },
      subscriptions: {
        status: 'GET /api/subscriptions/status',
        plans: 'GET /api/subscriptions/plans',
        usage: 'GET /api/subscriptions/usage'
      },
      share: {
        log: 'POST /api/share/log'
      },
      chapterPractice: {
        generate: 'POST /api/chapter-practice/generate',
        submitAnswer: 'POST /api/chapter-practice/submit-answer',
        complete: 'POST /api/chapter-practice/complete',
        session: 'GET /api/chapter-practice/session/:sessionId',
        active: 'GET /api/chapter-practice/active'
      },
      auth: {
        createSession: 'POST /api/auth/session',
        getSession: 'GET /api/auth/session',
        logout: 'POST /api/auth/logout',
        listDevices: 'GET /api/auth/devices (P1)',
        removeDevice: 'DELETE /api/auth/devices/:deviceId (P1)'
      },
      mockTests: {
        available: 'GET /api/mock-tests/available',
        active: 'GET /api/mock-tests/active',
        start: 'POST /api/mock-tests/start',
        saveAnswer: 'POST /api/mock-tests/save-answer',
        clearAnswer: 'POST /api/mock-tests/clear-answer',
        submit: 'POST /api/mock-tests/submit',
        abandon: 'POST /api/mock-tests/abandon',
        history: 'GET /api/mock-tests/history',
        results: 'GET /api/mock-tests/:testId/results'
      }
    }
  });
});

// ========================================
// ERROR HANDLING
// ========================================

// Sentry error handler (must be before other error handlers)
// Note: Sentry v8+ uses setupExpressErrorHandler instead of Handlers.errorHandler
if (process.env.SENTRY_DSN) {
  Sentry.setupExpressErrorHandler(app);
}

const { errorHandler } = require('./middleware/errorHandler');
app.use(errorHandler);

// 404 handler (must be after all routes)
app.use((req, res) => {
  logger.warn('404 - Route not found', {
    requestId: req.id,
    method: req.method,
    path: req.path,
  });
  res.status(404).json({
    success: false,
    error: 'Route not found',
    requestId: req.id,
  });
});

// ========================================
// START SERVER
// ========================================

const server = app.listen(PORT, () => {
  logger.info('🚀 JEEVibe backend server started', {
    port: PORT,
    environment: process.env.NODE_ENV || 'development',
    nodeVersion: process.version,
  });

  // Check for required environment variables
  const requiredEnvVars = ['OPENAI_API_KEY', 'FIREBASE_PROJECT_ID'];
  const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);

  if (missingVars.length > 0) {
    logger.warn('⚠️  Missing required environment variables', {
      missing: missingVars,
    });
  }

  if (process.env.NODE_ENV === 'production') {
    logger.info('✅ Production mode - Security features enabled');
  } else {
    logger.info('⚠️  Development mode - Some security features relaxed');
  }
});

// ========================================
// GRACEFUL SHUTDOWN
// ========================================

// Track if shutdown is in progress
let isShuttingDown = false;

// Graceful shutdown handler
const gracefulShutdown = (signal) => {
  if (isShuttingDown) {
    logger.warn(`⚠️  Received ${signal} during shutdown, ignoring`);
    return;
  }

  isShuttingDown = true;
  logger.info(`🛑 Received ${signal}, starting graceful shutdown...`);

  // Stop accepting new connections
  server.close((err) => {
    if (err) {
      logger.error('Error during server close', { error: err.message });
      process.exit(1);
    }

    logger.info('✅ Server closed, all connections handled');
    process.exit(0);
  });

  // Force shutdown after 30 seconds (Render gives ~30s grace period)
  setTimeout(() => {
    logger.error('⚠️  Forcing shutdown after timeout');
    process.exit(1);
  }, 25000);
};

// Listen for termination signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

module.exports = app;

