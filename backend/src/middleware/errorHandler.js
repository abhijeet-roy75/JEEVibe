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
  constructor(statusCode, message, details = null) {
    super(message);
    this.statusCode = statusCode;
    this.details = details;
    this.name = 'ApiError';
    Error.captureStackTrace(this, this.constructor);
  }
}

/**
 * Error handler middleware
 * Must be last middleware in the chain
 */
function errorHandler(err, req, res, next) {
  // Ensure requestId exists (might not if error occurs before requestId middleware)
  const requestId = req.id || 'unknown';
  
  // Log error with context
  logger.error('Request error', {
    requestId,
    method: req.method || 'unknown',
    path: req.path || 'unknown',
    userId: req.userId || 'anonymous',
    error: {
      message: err.message,
      stack: err.stack,
      statusCode: err.statusCode || 500,
      details: err.details,
    },
  });

  // Handle ApiError (known errors)
  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({
      success: false,
      error: err.message,
      details: err.details,
      requestId,
    });
  }

  // Handle validation errors from express-validator
  if (err.name === 'ValidationError' || err.array) {
    return res.status(400).json({
      success: false,
      error: 'Validation error',
      details: err.array ? err.array() : err.message,
      requestId,
    });
  }

  // Handle Firebase Auth errors
  if (err.code && err.code.startsWith('auth/')) {
    return res.status(401).json({
      success: false,
      error: 'Authentication failed',
      details: err.message,
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
      error: 'Database error',
      details: process.env.NODE_ENV === 'development' ? err.message : 'An error occurred',
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
    error: message,
    requestId,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
}

module.exports = {
  errorHandler,
  ApiError,
};

