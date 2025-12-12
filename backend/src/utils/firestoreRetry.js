/**
 * Firestore Retry Utility
 * 
 * Implements exponential backoff retry logic for Firestore operations
 * Handles transient errors (network issues, rate limits)
 */

/**
 * Retry a Firestore operation with exponential backoff
 * 
 * @param {Function} operation - Async function that performs Firestore operation
 * @param {Object} options - Retry options
 * @param {number} options.maxRetries - Maximum number of retries (default: 3)
 * @param {number} options.initialDelay - Initial delay in ms (default: 100)
 * @param {number} options.maxDelay - Maximum delay in ms (default: 5000)
 * @returns {Promise<any>} Result of the operation
 * @throws {Error} If operation fails after all retries
 */
async function retryFirestoreOperation(operation, options = {}) {
  const {
    maxRetries = 3,
    initialDelay = 100,
    maxDelay = 5000
  } = options;
  
  let lastError;
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      
      // Check if error is retryable
      const isRetryable = isRetryableError(error);
      
      if (!isRetryable) {
        // Don't retry on permanent errors
        throw error;
      }
      
      // If this was the last attempt, throw the error
      if (attempt === maxRetries) {
        throw error;
      }
      
      // Calculate delay with exponential backoff
      const delay = Math.min(
        initialDelay * Math.pow(2, attempt),
        maxDelay
      );
      
      console.warn(
        `Firestore operation failed (attempt ${attempt + 1}/${maxRetries + 1}), retrying in ${delay}ms:`,
        error.message
      );
      
      // Wait before retrying
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  
  // Should never reach here, but just in case
  throw lastError;
}

/**
 * Check if a Firestore error is retryable
 * 
 * @param {Error} error - Error to check
 * @returns {boolean} True if error is retryable
 */
function isRetryableError(error) {
  // Firebase/Firestore error codes that are retryable
  const retryableCodes = [
    14,  // UNAVAILABLE - Service unavailable
    8,   // DEADLINE_EXCEEDED - Request timeout
    4,   // DEADLINE_EXCEEDED (alternative)
    10,  // ABORTED - Operation aborted (can retry)
    13,  // INTERNAL - Internal error (may be transient)
  ];
  
  // Check error code
  if (error.code && retryableCodes.includes(error.code)) {
    return true;
  }
  
  // Check error message for common retryable patterns
  const errorMessage = error.message || '';
  const retryablePatterns = [
    /unavailable/i,
    /deadline exceeded/i,
    /timeout/i,
    /network error/i,
    /connection/i,
    /rate limit/i,
    /too many requests/i
  ];
  
  return retryablePatterns.some(pattern => pattern.test(errorMessage));
}

module.exports = {
  retryFirestoreOperation,
  isRetryableError
};
