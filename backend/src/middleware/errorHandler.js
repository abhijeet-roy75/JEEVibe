/**
 * Error Handler Middleware
 * 
 * Standardized error handling across all endpoints
 */

const logger = require('../utils/logger');

/**
 * Custom API Error class
 */
class ApiError extends Error {
  constructor(statusCode, message, code = null, details = null) {
    super(message);
    this.statusCode = statusCode;
    this.code = code || this.generateErrorCode(statusCode, message);
    this.details = details;
    this.name = 'ApiError';
    Error.captureStackTrace(this, this.constructor);
  }
  
  generateErrorCode(statusCode, message) {
    // Generate error code from message if not provided
    if (message.includes('not found')) return 'NOT_FOUND';
    if (message.includes('already completed')) return 'QUIZ_ALREADY_COMPLETED';
    if (message.includes('not in progress')) return 'QUIZ_NOT_IN_PROGRESS';
    if (message.includes('not started')) return 'QUIZ_NOT_STARTED';
    if (message.includes('insufficient')) return 'INSUFFICIENT_QUESTIONS';
    if (message.includes('assessment')) return 'ASSESSMENT_NOT_COMPLETED';
    if (message.includes('invalid')) return 'INVALID_INPUT';
    if (message.includes('timeout')) return 'TIMEOUT_ERROR';
    if (statusCode === 400) return 'BAD_REQUEST';
    if (statusCode === 401) return 'UNAUTHORIZED';
    if (statusCode === 403) return 'FORBIDDEN';
    if (statusCode === 404) return 'NOT_FOUND';
    if (statusCode === 409) return 'CONFLICT';
    return 'INTERNAL_ERROR';
  }
}

/**
 * Error handler middleware
 * Must be last middleware in the chain
 */
function errorHandler(err, req, res, next) {
  // Ensure requestId exists (might not if error occurs before requestId middleware)
  const requestId = req.id || 'unknown';
  
  // Log error with context - use console.error for Render.com visibility
  const errorInfo = {
    requestId,
    method: req.method || 'unknown',
    path: req.path || 'unknown',
    userId: req.userId || 'anonymous',
    error: {
      message: err.message,
      stack: err.stack,
      statusCode: err.statusCode || 500,
      details: err.details,
      code: err.code,
      name: err.name,
    },
  };
  
  // Log to winston
  logger.error('Request error', errorInfo);
  
  // Also log to console for Render.com (winston console transport might not capture all errors)
  console.error('ERROR:', JSON.stringify(errorInfo, null, 2));

  // Handle ApiError (known errors)
  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({
      success: false,
      error: {
        code: err.code,
        message: err.message,
        details: err.details
      },
      requestId,
    });
  }

  // Handle validation errors from express-validator
  if (err.name === 'ValidationError' || err.array) {
    return res.status(400).json({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Validation error',
        details: err.array ? err.array() : err.message
      },
      requestId,
    });
  }

  // Handle Firebase Auth errors
  if (err.code && err.code.startsWith('auth/')) {
    return res.status(401).json({
      success: false,
      error: {
        code: 'AUTHENTICATION_FAILED',
        message: 'Authentication failed',
        details: err.message
      },
      requestId,
    });
  }

  // Handle Firestore errors
  if (err.code && typeof err.code === 'number') {
    const statusCode = err.code === 5 ? 404 : // NOT_FOUND
                      err.code === 3 ? 400 : // INVALID_ARGUMENT
                      err.code === 10 ? 409 : // ABORTED
                      500;
    
    return res.status(statusCode).json({
      success: false,
      error: {
        code: 'DATABASE_ERROR',
        message: 'Database error',
        details: process.env.NODE_ENV === 'development' ? err.message : 'An error occurred'
      },
      requestId,
    });
  }

  // Default error response
  const statusCode = err.statusCode || err.status || 500;
  const message = process.env.NODE_ENV === 'production' 
    ? 'Internal server error' 
    : err.message;

  res.status(statusCode).json({
    success: false,
    error: {
      code: statusCode === 500 ? 'INTERNAL_ERROR' : 'UNKNOWN_ERROR',
      message: message,
      details: process.env.NODE_ENV === 'development' ? { stack: err.stack } : null
    },
    requestId,
  });
}

module.exports = {
  errorHandler,
  ApiError,
};

