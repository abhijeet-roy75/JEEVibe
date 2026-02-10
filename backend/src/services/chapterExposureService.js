/**
 * Chapter Exposure Service
 *
 * Handles retrieval of exposure questions for the chapter unlock quiz feature.
 * Exposure questions are used to assess if a student has basic familiarity with a chapter.
 */

const { db } = require('../config/firebase');
const logger = require('../utils/logger');

const EXPOSURE_QUESTIONS_PER_CHAPTER = 5;

/**
 * Get all exposure questions for a chapter
 *
 * @param {string} chapterKey - The chapter key (e.g., 'physics_electrostatics')
 * @returns {Promise<Array>} Array of 5 exposure questions
 */
async function getExposureQuestions(chapterKey) {
  try {
    const questionsSnapshot = await db
      .collection('chapter_exposure')
      .doc(chapterKey)
      .collection('questions')
      .where('active', '==', true)
      .get();

    if (questionsSnapshot.empty) {
      logger.warn(`No exposure questions found for chapter: ${chapterKey}`);
      return [];
    }

    const questions = questionsSnapshot.docs.map(doc => ({
      ...doc.data(),
      id: doc.id
    }));

    logger.info(`Retrieved ${questions.length} exposure questions for chapter: ${chapterKey}`);

    return questions;

  } catch (error) {
    logger.error('Error fetching exposure questions:', {
      chapterKey,
      error: error.message
    });
    throw new Error(`Failed to fetch exposure questions: ${error.message}`);
  }
}

/**
 * Validate that a chapter has the required number of exposure questions
 *
 * @param {string} chapterKey - The chapter key
 * @returns {Promise<boolean>} True if chapter has exactly 5 active questions
 */
async function validateChapterHasExposureQuestions(chapterKey) {
  try {
    const questions = await getExposureQuestions(chapterKey);
    const isValid = questions.length === EXPOSURE_QUESTIONS_PER_CHAPTER;

    if (!isValid) {
      logger.warn(`Chapter ${chapterKey} has ${questions.length} exposure questions, expected ${EXPOSURE_QUESTIONS_PER_CHAPTER}`);
    }

    return isValid;

  } catch (error) {
    logger.error('Error validating exposure questions:', {
      chapterKey,
      error: error.message
    });
    return false;
  }
}

/**
 * Sanitize question data before sending to client
 * Removes internal fields and server-side only data
 *
 * @param {Object} question - The question object
 * @returns {Object} Sanitized question
 */
function sanitizeQuestion(question) {
  // Remove fields that shouldn't be exposed to client
  const {
    active,
    imported_at,
    created_date,
    created_by,
    validated_by,
    ...sanitized
  } = question;

  return sanitized;
}

/**
 * Sanitize array of questions
 *
 * @param {Array} questions - Array of question objects
 * @returns {Array} Array of sanitized questions
 */
function sanitizeQuestions(questions) {
  return questions.map(q => sanitizeQuestion(q));
}

/**
 * Shuffle array using Fisher-Yates algorithm
 *
 * @param {Array} array - Array to shuffle
 * @returns {Array} Shuffled array (new copy, doesn't mutate original)
 */
function shuffleArray(array) {
  const shuffled = [...array];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}

module.exports = {
  getExposureQuestions,
  validateChapterHasExposureQuestions,
  sanitizeQuestion,
  sanitizeQuestions,
  shuffleArray,
  EXPOSURE_QUESTIONS_PER_CHAPTER
};
