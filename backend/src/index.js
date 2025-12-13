/**
 * JEEVibe - Snap & Solve Backend Server
 * Express server for handling image uploads and OpenAI API calls
 */

require('dotenv').config();
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
  logger.error('Unhandled Rejection', {
    promise: promise.toString(),
    reason: reason instanceof Error ? {
      message: reason.message,
      stack: reason.stack,
    } : reason,
  });
  // Don't exit, just log the error
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception', {
    message: error.message,
    stack: error.stack,
  });
  // Don't exit immediately, log and continue
});

const app = express();
const PORT = process.env.PORT || 3000;

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
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-ID'],
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
  next();
});

// ========================================
// ROUTES (Health check before rate limiting)
// ========================================

// Health check endpoint (BEFORE rate limiting - important for monitoring)
app.get('/api/health', require('./routes/health'));

// ========================================
// RATE LIMITING
// ========================================

const { apiLimiter, strictLimiter, imageProcessingLimiter } = require('./middleware/rateLimiter');

// Apply general rate limiting to all API routes (after health check)
app.use('/api', apiLimiter);

// Apply strict rate limiting to expensive operations
app.use('/api/solve', imageProcessingLimiter);
app.use('/api/assessment/submit', strictLimiter);

// API Routes
app.use('/api', solveRouter);

const assessmentRouter = require('./routes/assessment');
app.use('/api/assessment', assessmentRouter);

const usersRouter = require('./routes/users');
app.use('/api/users', usersRouter);

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
      }
    }
  });
});

// ========================================
// ERROR HANDLING
// ========================================

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

app.listen(PORT, () => {
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

module.exports = app;

