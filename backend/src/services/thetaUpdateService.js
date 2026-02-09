/**
 * Theta Update Service
 * 
 * Implements Bayesian theta updates for daily adaptive quizzes.
 * Updates student ability (theta) after each question response using IRT.
 * 
 * Features:
 * - Incremental Bayesian theta updates
 * - Bounded constraints [-3, +3]
 * - Standard error reduction
 * - Chapter-level theta tracking
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { calculateSubjectTheta, calculateWeightedOverallTheta } = require('./thetaCalculationService');

// Import IRT functions from questionSelectionService
const { calculateIRTProbability } = require('./questionSelectionService');

// ============================================================================
// CONSTANTS
// ============================================================================

const THETA_MIN = -3.0;
const THETA_MAX = 3.0;
const SE_FLOOR = 0.15;
const SE_CEILING = 0.6;
const LEARNING_RATE = 0.3; // Step size for gradient descent
const MAX_ITERATIONS = 10; // Maximum iterations for convergence

// ============================================================================
// THETA BOUNDING
// ============================================================================

/**
 * Bound theta to valid range
 * 
 * @param {number} theta - Theta value
 * @returns {number} Bounded theta [-3, +3]
 */
function boundTheta(theta) {
  return Math.max(THETA_MIN, Math.min(THETA_MAX, theta));
}

/**
 * Bound standard error to valid range
 * 
 * @param {number} se - Standard error
 * @returns {number} Bounded SE [0.15, 0.6]
 */
function boundSE(se) {
  return Math.max(SE_FLOOR, Math.min(SE_CEILING, se));
}

// ============================================================================
// IRT DERIVATIVES
// ============================================================================

/**
 * Calculate derivative of log-likelihood with respect to theta
 * Used for gradient descent update
 * 
 * @param {number} theta - Current theta estimate
 * @param {number} a - Discrimination parameter
 * @param {number} b - Difficulty parameter
 * @param {number} c - Guessing parameter
 * @param {boolean} isCorrect - Whether answer was correct
 * @returns {number} Gradient value
 */
function calculateGradient(theta, a, b, c, isCorrect) {
  const D = 1.702; // Scaling constant for 3PL model
  const P = calculateIRTProbability(theta, a, b, c);

  // Avoid division by zero
  if (P <= 0 || P >= 1) {
    return 0;
  }

  // Gradient of log-likelihood
  const residual = (isCorrect ? 1 : 0) - P;
  const gradient = D * a * (P - c) / ((1 - c) * P * (1 - P)) * residual;

  return gradient;
}

/**
 * Calculate Fisher Information for standard error update
 * 
 * @param {number} theta - Current theta estimate
 * @param {number} a - Discrimination parameter
 * @param {number} b - Difficulty parameter
 * @param {number} c - Guessing parameter
 * @returns {number} Fisher Information
 */
function calculateFisherInformation(theta, a, b, c) {
  const P = calculateIRTProbability(theta, a, b, c);

  if (P <= 0 || P >= 1) {
    return 0;
  }

  const numerator = Math.pow(a, 2) * Math.pow(P - c, 2);
  const denominator = Math.pow(1 - c, 2) * P * (1 - P);

  if (denominator === 0) {
    return 0;
  }

  return numerator / denominator;
}

// ============================================================================
// SINGLE QUESTION UPDATE
// ============================================================================

/**
 * Update theta after a single question response
 * Uses Bayesian IRT update with gradient descent
 * 
 * @param {number} currentTheta - Current theta estimate
 * @param {number} currentSE - Current standard error
 * @param {Object} questionIRT - IRT parameters {a, b, c}
 * @param {boolean} isCorrect - Whether answer was correct
 * @returns {Object} Updated {theta, se}
 */
function updateThetaAfterQuestion(currentTheta, currentSE, questionIRT, isCorrect) {
  const { a, b, c } = questionIRT;

  // Calculate gradient
  const gradient = calculateGradient(currentTheta, a, b, c, isCorrect);

  // Update theta using gradient descent
  let newTheta = currentTheta + LEARNING_RATE * gradient;
  newTheta = boundTheta(newTheta);

  // Update standard error using Fisher Information
  const fisherInfo = calculateFisherInformation(newTheta, a, b, c);

  // SE decreases as we gain more information
  // Formula: new_SE = 1 / sqrt(1/old_SE² + Fisher_Info)
  const oldVariance = Math.pow(currentSE, 2);
  const newVariance = 1 / (1 / oldVariance + fisherInfo);
  let newSE = Math.sqrt(newVariance);
  newSE = boundSE(newSE);

  return {
    theta: newTheta,
    se: newSE,
    theta_delta: newTheta - currentTheta,
    se_delta: newSE - currentSE
  };
}

// ============================================================================
// BATCH UPDATE (Multiple Questions)
// ============================================================================

/**
 * Update theta after multiple question responses (batch processing)
 * Processes responses sequentially, updating theta after each
 * 
 * @param {number} initialTheta - Starting theta estimate
 * @param {number} initialSE - Starting standard error
 * @param {Array} responses - Array of {questionIRT: {a, b, c}, isCorrect: boolean}
 * @returns {Object} Final {theta, se, updates: Array}
 */
function batchUpdateTheta(initialTheta, initialSE, responses) {
  let currentTheta = initialTheta;
  let currentSE = initialSE;
  const updates = [];

  for (const response of responses) {
    const { questionIRT, isCorrect } = response;
    const update = updateThetaAfterQuestion(currentTheta, currentSE, questionIRT, isCorrect);

    updates.push({
      theta_before: currentTheta,
      theta_after: update.theta,
      se_before: currentSE,
      se_after: update.se,
      theta_delta: update.theta_delta,
      se_delta: update.se_delta
    });

    currentTheta = update.theta;
    currentSE = update.se;
  }

  return {
    theta: currentTheta,
    se: currentSE,
    updates: updates
  };
}

// ============================================================================
// CHAPTER-LEVEL CALCULATIONS (Pure Functions - No Firestore)
// ============================================================================

/**
 * Calculate chapter theta update (pure function, no Firestore writes)
 * Separated from updateChapterTheta to enable pre-calculation for transactions
 *
 * @param {Object} currentChapterData - Current chapter data {theta, confidence_SE, attempts, accuracy}
 * @param {Array} responses - Array of responses for this chapter
 *   Each response: {questionIRT: {a, b, c}, isCorrect}
 * @returns {Object} Calculated chapter theta data (no persistence)
 */
function calculateChapterThetaUpdate(currentChapterData, responses) {
  try {
    // Prepare responses for batch update
    const batchResponses = responses.map(r => ({
      questionIRT: r.questionIRT,
      isCorrect: r.isCorrect
    }));

    // Perform batch theta update
    const updateResult = batchUpdateTheta(
      currentChapterData.theta,
      currentChapterData.confidence_SE,
      batchResponses
    );

    // Calculate new accuracy as fraction (0-1)
    const correctCount = responses.filter(r => r.isCorrect).length;
    const totalCount = responses.length;
    const newAccuracyFraction = totalCount > 0 ? correctCount / totalCount : 0;

    // Combine with existing attempts
    const newAttempts = currentChapterData.attempts + totalCount;

    // Calculate weighted accuracy (combine old and new)
    // Note: Old data might be stored as fraction (0-1) or percentage (0-100)
    // Normalize to fraction for calculation, then convert to percentage for storage
    let oldAccuracy = currentChapterData.accuracy || 0;
    // If > 1, it's stored as percentage, convert to fraction
    if (oldAccuracy > 1) {
      oldAccuracy = oldAccuracy / 100;
    }
    const oldAttempts = currentChapterData.attempts || 0;
    const combinedAccuracyFraction = oldAttempts > 0
      ? (oldAccuracy * oldAttempts + newAccuracyFraction * totalCount) / newAttempts
      : newAccuracyFraction;

    // Calculate percentile from theta
    const percentile = thetaToPercentile(updateResult.theta);

    // Return calculated data (no Firestore write)
    return {
      theta: boundTheta(updateResult.theta),
      percentile: percentile,
      confidence_SE: boundSE(updateResult.se),
      attempts: newAttempts,
      accuracy: Math.round(combinedAccuracyFraction * 100), // Store as percentage 0-100 for consistency with subject_accuracy
      last_updated: new Date().toISOString(),
      // Metadata for debugging
      theta_delta: updateResult.theta - currentChapterData.theta,
      se_delta: updateResult.se - currentChapterData.confidence_SE
    };
  } catch (error) {
    logger.error('Error calculating chapter theta update', {
      chapterKey: currentChapterData.chapterKey,
      error: error.message,
      stack: error.stack
    });
    throw error;
  }
}

/**
 * Calculate subject and overall theta updates (pure function, no Firestore writes)
 * Separated from updateSubjectAndOverallTheta to enable pre-calculation for transactions
 *
 * @param {Object} thetaByChapter - Updated theta_by_chapter map
 * @returns {Object} Calculated subject and overall theta data (no persistence)
 */
function calculateSubjectAndOverallThetaUpdate(thetaByChapter) {
  try {
    // Calculate subject-level thetas and aggregate accuracy
    const thetaBySubject = {};
    const subjectAccuracy = {};
    const subjects = ['physics', 'chemistry', 'mathematics'];

    for (const subject of subjects) {
      const subjectData = calculateSubjectTheta(thetaByChapter, subject);
      thetaBySubject[subject] = subjectData;

      // Calculate aggregated accuracy for this subject from thetaByChapter
      let correct = 0;
      let total = 0;

      Object.entries(thetaByChapter).forEach(([key, data]) => {
        if (key.startsWith(`${subject}_`)) {
          // Weighted by attempts to get cumulative accuracy
          // Note: chapter accuracy should be percentage 0-100, but old data might be fraction 0-1
          const attempts = data.attempts || 0;
          let accuracy = data.accuracy || 0;
          // Normalize: if accuracy <= 1, treat as fraction; if > 1, it's percentage
          if (accuracy > 0 && accuracy <= 1) {
            accuracy = accuracy * 100; // Convert fraction to percentage
          }
          correct += Math.round((accuracy / 100) * attempts);
          total += attempts;
        }
      });

      subjectAccuracy[subject] = {
        correct,
        total,
        accuracy: total > 0 ? Math.round((correct / total) * 100) : 0
      };
    }

    // Calculate overall theta (weighted by JEE chapter importance)
    const overallTheta = calculateWeightedOverallTheta(thetaByChapter);
    const overallPercentile = thetaToPercentile(overallTheta);

    // Return calculated data (no Firestore write)
    return {
      theta_by_subject: thetaBySubject,
      subject_accuracy: subjectAccuracy,
      overall_theta: overallTheta,
      overall_percentile: overallPercentile
    };
  } catch (error) {
    logger.error('Error calculating subject and overall theta update', {
      error: error.message,
      stack: error.stack
    });
    throw error;
  }
}

// ============================================================================
// CHAPTER-LEVEL UPDATE (Legacy - with Firestore persistence)
// ============================================================================

/**
 * Update chapter-level theta after quiz completion
 *
 * NOTE: This function is being deprecated in favor of atomic transaction approach.
 * Use calculateChapterThetaUpdate() for transaction-safe calculations.
 *
 * @param {string} userId
 * @param {string} chapterKey - Chapter key (e.g., "physics_electrostatics")
 * @param {Array} responses - Array of responses for this chapter
 *   Each response: {question_id, questionIRT: {a, b, c}, isCorrect, time_taken_seconds}
 * @returns {Promise<Object>} Updated chapter theta data
 */
async function updateChapterTheta(userId, chapterKey, responses) {
  try {
    // Get current chapter theta from user document
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    if (!userDoc.exists) {
      throw new Error(`User ${userId} not found`);
    }

    const userData = userDoc.data();
    const currentChapterData = userData.theta_by_chapter?.[chapterKey] || {
      theta: 0.0,
      percentile: 50.0,
      confidence_SE: SE_CEILING,
      attempts: 0,
      accuracy: 0.0,
      last_updated: new Date().toISOString()
    };

    // Prepare responses for batch update
    const batchResponses = responses.map(r => ({
      questionIRT: r.questionIRT,
      isCorrect: r.isCorrect
    }));

    // Perform batch theta update
    const updateResult = batchUpdateTheta(
      currentChapterData.theta,
      currentChapterData.confidence_SE,
      batchResponses
    );

    // Calculate new accuracy as fraction (0-1)
    const correctCount = responses.filter(r => r.isCorrect).length;
    const totalCount = responses.length;
    const newAccuracyFraction = totalCount > 0 ? correctCount / totalCount : 0;

    // Combine with existing attempts
    const newAttempts = currentChapterData.attempts + totalCount;

    // Calculate weighted accuracy (combine old and new)
    // Note: Old data might be stored as fraction (0-1) or percentage (0-100)
    // Normalize to fraction for calculation, then convert to percentage for storage
    let oldAccuracy = currentChapterData.accuracy || 0;
    // If > 1, it's stored as percentage, convert to fraction
    if (oldAccuracy > 1) {
      oldAccuracy = oldAccuracy / 100;
    }
    const oldAttempts = currentChapterData.attempts || 0;
    const combinedAccuracyFraction = oldAttempts > 0
      ? (oldAccuracy * oldAttempts + newAccuracyFraction * totalCount) / newAttempts
      : newAccuracyFraction;

    // Calculate percentile from theta
    const percentile = thetaToPercentile(updateResult.theta);

    // Prepare updated chapter data
    const updatedChapterData = {
      theta: boundTheta(updateResult.theta),
      percentile: percentile,
      confidence_SE: boundSE(updateResult.se),
      attempts: newAttempts,
      accuracy: Math.round(combinedAccuracyFraction * 100), // Store as percentage 0-100 for consistency with subject_accuracy
      last_updated: new Date().toISOString()
    };

    // Update user document
    await retryFirestoreOperation(async () => {
      return await userRef.update({
        [`theta_by_chapter.${chapterKey}`]: updatedChapterData
      });
    });

    logger.info('Chapter theta updated', {
      userId,
      chapterKey,
      theta_before: currentChapterData.theta,
      theta_after: updatedChapterData.theta,
      attempts: newAttempts
    });

    return {
      chapter_key: chapterKey,
      ...updatedChapterData,
      theta_delta: updateResult.theta - currentChapterData.theta,
      se_delta: updateResult.se - currentChapterData.confidence_SE
    };
  } catch (error) {
    logger.error('Error updating chapter theta', {
      userId,
      chapterKey,
      error: error.message,
      stack: error.stack
    });
    throw error;
  }
}

/**
 * Standard normal cumulative distribution function (CDF)
 * Uses Abramowitz and Stegun approximation for accurate results
 *
 * @param {number} z - Standard normal variable
 * @returns {number} Probability [0, 1]
 */
function normalCDF(z) {
  // Approximation using erf with error < 1.5 × 10^-7
  const t = 1 / (1 + 0.2316419 * Math.abs(z));
  const d = 0.3989423 * Math.exp(-z * z / 2);
  const prob = d * t * (0.319381530 + t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))));
  return z > 0 ? 1 - prob : prob;
}

/**
 * Convert theta to percentile
 *
 * @param {number} theta - Theta value [-3, +3]
 * @returns {number} Percentile [0, 100]
 */
function thetaToPercentile(theta) {
  // Use proper cumulative normal distribution
  // Percentile = Φ(theta) * 100
  const z = boundTheta(theta);
  const percentile = normalCDF(z) * 100;
  return Math.max(0, Math.min(100, Math.round(percentile * 100) / 100));
}

// ============================================================================
// SUBJECT & OVERALL UPDATE
// ============================================================================

/**
 * Update subject-level and overall theta after quiz completion
 * Called after all chapter-level updates are complete
 * 
 * @param {string} userId
 * @returns {Promise<Object>} Updated subject and overall theta data
 */
async function updateSubjectAndOverallTheta(userId) {
  try {
    // Get updated chapter thetas
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    if (!userDoc.exists) {
      throw new Error(`User ${userId} not found`);
    }

    const userData = userDoc.data();
    const thetaByChapter = userData.theta_by_chapter || {};

    // Calculate subject-level thetas and aggregate accuracy
    const thetaBySubject = {};
    const subjectAccuracy = {};
    const subjects = ['physics', 'chemistry', 'mathematics'];

    for (const subject of subjects) {
      const subjectData = calculateSubjectTheta(thetaByChapter, subject);
      thetaBySubject[subject] = subjectData;

      // Calculate aggregated accuracy for this subject from thetaByChapter
      let correct = 0;
      let total = 0;

      Object.entries(thetaByChapter).forEach(([key, data]) => {
        if (key.startsWith(`${subject}_`)) {
          // Weighted by attempts to get cumulative accuracy
          // Note: chapter accuracy should be percentage 0-100, but old data might be fraction 0-1
          const attempts = data.attempts || 0;
          let accuracy = data.accuracy || 0;
          // Normalize: if accuracy <= 1, treat as fraction; if > 1, it's percentage
          if (accuracy > 0 && accuracy <= 1) {
            accuracy = accuracy * 100; // Convert fraction to percentage
          }
          correct += Math.round((accuracy / 100) * attempts);
          total += attempts;
        }
      });

      subjectAccuracy[subject] = {
        correct,
        total,
        accuracy: total > 0 ? Math.round((correct / total) * 100) : 0
      };
    }

    // Calculate overall theta (weighted by JEE chapter importance)
    const overallTheta = calculateWeightedOverallTheta(thetaByChapter);
    const overallPercentile = thetaToPercentile(overallTheta);

    // Update user document
    await retryFirestoreOperation(async () => {
      return await userRef.update({
        theta_by_subject: thetaBySubject,
        subject_accuracy: subjectAccuracy,
        overall_theta: overallTheta,
        overall_percentile: overallPercentile
      });
    });

    logger.info('Subject and overall theta updated', {
      userId,
      overall_theta: overallTheta,
      overall_percentile: overallPercentile,
      subject_accuracy: subjectAccuracy
    });

    return {
      theta_by_subject: thetaBySubject,
      subject_accuracy: subjectAccuracy,
      overall_theta: overallTheta,
      overall_percentile: overallPercentile
    };
  } catch (error) {
    logger.error('Error updating subject and overall theta', {
      userId,
      error: error.message,
      stack: error.stack
    });
    throw error;
  }
}

// ============================================================================
// SUBTOPIC ACCURACY TRACKING
// ============================================================================

/**
 * Calculate subtopic accuracy updates from quiz responses
 * Aggregates accuracy per sub-topic within each chapter
 *
 * @param {Object} currentSubtopicAccuracy - Current subtopic_accuracy from user doc
 * @param {Array} responses - Array of response objects with sub_topics field
 * @returns {Object} Updated subtopic_accuracy map
 */
function calculateSubtopicAccuracyUpdate(currentSubtopicAccuracy, responses) {
  try {
    const updatedSubtopicAccuracy = { ...currentSubtopicAccuracy };

    // Debug: Log response structure to diagnose subtopic tracking
    const responsesWithSubtopics = responses.filter(r => r.sub_topics && r.sub_topics.length > 0);
    logger.info('Calculating subtopic accuracy', {
      responseCount: responses.length,
      responsesWithSubtopics: responsesWithSubtopics.length,
      sampleSubtopics: responsesWithSubtopics.length > 0 ? responsesWithSubtopics[0].sub_topics : 'none found',
      allResponseSubtopics: responses.map(r => ({
        chapter: r.chapter_key,
        subtopics: r.sub_topics || 'undefined'
      }))
    });

    // Group responses by chapter_key and sub_topic
    for (const response of responses) {
      const { chapter_key, sub_topics, is_correct } = response;

      if (!chapter_key || !sub_topics || !Array.isArray(sub_topics)) {
        continue;
      }

      // Initialize chapter entry if needed
      if (!updatedSubtopicAccuracy[chapter_key]) {
        updatedSubtopicAccuracy[chapter_key] = {};
      }

      // Update each sub-topic this question covers
      for (const subtopic of sub_topics) {
        if (!subtopic || typeof subtopic !== 'string') {
          continue;
        }

        const subtopicKey = subtopic.trim();
        if (!subtopicKey) {
          continue;
        }

        // Initialize subtopic entry if needed
        if (!updatedSubtopicAccuracy[chapter_key][subtopicKey]) {
          updatedSubtopicAccuracy[chapter_key][subtopicKey] = {
            correct: 0,
            total: 0,
            accuracy: 0
          };
        }

        // Update counts
        const subtopicData = updatedSubtopicAccuracy[chapter_key][subtopicKey];
        subtopicData.total += 1;
        if (is_correct) {
          subtopicData.correct += 1;
        }

        // Recalculate accuracy
        subtopicData.accuracy = subtopicData.total > 0
          ? Math.round((subtopicData.correct / subtopicData.total) * 100)
          : 0;
      }
    }

    return updatedSubtopicAccuracy;
  } catch (error) {
    logger.error('Error calculating subtopic accuracy update', {
      error: error.message,
      stack: error.stack
    });
    // Return current data unchanged on error
    return currentSubtopicAccuracy || {};
  }
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  // Pure calculation functions (for atomic transactions)
  calculateChapterThetaUpdate,
  calculateSubjectAndOverallThetaUpdate,
  calculateSubtopicAccuracyUpdate,

  // Legacy functions (with Firestore persistence)
  updateThetaAfterQuestion,
  batchUpdateTheta,
  updateChapterTheta,
  updateSubjectAndOverallTheta,

  // Utility functions
  boundTheta,
  boundSE,
  thetaToPercentile
};

