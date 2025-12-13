/**
 * Timeout Utility
 * 
 * Wraps async operations with timeout protection
 */

/**
 * Execute an async operation with timeout
 * 
 * @param {Promise} promise - Promise to execute
 * @param {number} timeoutMs - Timeout in milliseconds
 * @param {string} errorMessage - Error message if timeout occurs
 * @returns {Promise} Result of the operation
 * @throws {Error} If operation times out
 */
async function withTimeout(promise, timeoutMs, errorMessage = 'Operation timed out') {
  const timeoutPromise = new Promise((_, reject) => {
    setTimeout(() => {
      reject(new Error(`${errorMessage} (timeout: ${timeoutMs}ms)`));
    }, timeoutMs);
  });
  
  return Promise.race([promise, timeoutPromise]);
}

module.exports = {
  withTimeout
};

