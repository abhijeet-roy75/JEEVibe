/**
 * Request ID Middleware
 * 
 * Adds unique request ID to each request for tracing
 */

const { v4: uuidv4 } = require('uuid');

/**
 * Middleware to add request ID to requests
 * Sets X-Request-ID header in response
 */
function requestIdMiddleware(req, res, next) {
  // Generate or use existing request ID
  req.id = req.headers['x-request-id'] || uuidv4();
  
  // Set response header
  res.setHeader('X-Request-ID', req.id);
  
  next();
}

module.exports = requestIdMiddleware;

