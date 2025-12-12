/**
 * Input Validation Utilities
 * 
 * Validates and sanitizes user inputs
 */

/**
 * Validate Firebase Auth UID format
 * Firebase UIDs are typically 28 characters, alphanumeric
 * 
 * @param {string} userId - User ID to validate
 * @returns {string} Validated and trimmed userId
 * @throws {Error} If userId is invalid
 */
function validateUserId(userId) {
  if (!userId || typeof userId !== 'string') {
    throw new Error('Invalid userId: must be a non-empty string');
  }
  
  const trimmed = userId.trim();
  
  // Firebase UIDs are typically 20-128 characters, alphanumeric and some special chars
  // Allow alphanumeric, underscore, dash (common in Firebase UIDs)
  if (!/^[a-zA-Z0-9_-]{20,128}$/.test(trimmed)) {
    throw new Error('Invalid userId format: must be 20-128 characters, alphanumeric, underscore, or dash');
  }
  
  return trimmed;
}

/**
 * Validate assessment question ID format
 * Format: ASSESS_{SUBJECT}_{CHAPTER}_{NUMBER}
 * Example: ASSESS_PHY_MECH_001
 * 
 * @param {string} questionId - Question ID to validate
 * @returns {string} Validated questionId
 * @throws {Error} If questionId is invalid
 */
function validateQuestionId(questionId) {
  if (!questionId || typeof questionId !== 'string') {
    throw new Error('Invalid question_id: must be a non-empty string');
  }
  
  const trimmed = questionId.trim();
  
  // Pattern: ASSESS_{SUBJECT}_{CHAPTER}_{3_DIGITS}
  if (!/^ASSESS_[A-Z]+_[A-Z]+_\d{3}$/.test(trimmed)) {
    throw new Error('Invalid question_id format: must match ASSESS_{SUBJECT}_{CHAPTER}_{NUMBER}');
  }
  
  return trimmed;
}

/**
 * Validate student answer format
 * 
 * @param {any} answer - Student answer to validate
 * @returns {string} Validated answer as string
 * @throws {Error} If answer is invalid
 */
function validateStudentAnswer(answer) {
  if (answer === undefined || answer === null) {
    throw new Error('Invalid student_answer: cannot be null or undefined');
  }
  
  // Convert to string for consistency
  return String(answer).trim();
}

/**
 * Validate time taken (must be non-negative number)
 * 
 * @param {any} timeTaken - Time in seconds
 * @returns {number} Validated time
 * @throws {Error} If time is invalid
 */
function validateTimeTaken(timeTaken) {
  if (timeTaken === undefined || timeTaken === null) {
    return 0; // Default to 0 if not provided
  }
  
  const num = Number(timeTaken);
  
  if (isNaN(num) || num < 0) {
    throw new Error('Invalid time_taken_seconds: must be a non-negative number');
  }
  
  return Math.round(num); // Round to integer
}

/**
 * Sanitize string input (remove dangerous characters)
 * 
 * @param {string} input - Input to sanitize
 * @returns {string} Sanitized string
 */
function sanitizeString(input) {
  if (typeof input !== 'string') {
    return String(input);
  }
  
  // Remove null bytes and trim
  return input.replace(/\0/g, '').trim();
}

module.exports = {
  validateUserId,
  validateQuestionId,
  validateStudentAnswer,
  validateTimeTaken,
  sanitizeString
};
