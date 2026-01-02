/**
 * Question Selection Service
 * 
 * Implements IRT-optimized question selection for daily adaptive quizzes.
 * Uses Fisher Information to maximize information gain about student ability.
 * 
 * Features:
 * - IRT-based selection using Fisher Information
 * - Difficulty matching (|b-θ|≤0.5)
 * - 30-day recency filtering
 * - Discrimination-based ranking
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { getDatabaseNames } = require('./chapterMappingService');

// ============================================================================
// CONSTANTS
// ============================================================================

// ADAPTIVE DIFFICULTY THRESHOLD (optimized for high/low performers)
// Previously: Fixed 0.5 SD was too restrictive for extreme theta values
// Now: Adapts based on available question pool size
const DIFFICULTY_MATCH_THRESHOLD_STRICT = 0.5; // When many questions available
const DIFFICULTY_MATCH_THRESHOLD_MODERATE = 1.0; // When moderate pool
const DIFFICULTY_MATCH_THRESHOLD_RELAXED = 1.5; // When few questions available

const RECENCY_FILTER_DAYS = 30; // Don't show questions answered in last 30 days
const MAX_CANDIDATES = 50; // Maximum candidates to evaluate before selecting

/**
 * Get adaptive difficulty threshold based on available questions
 * Relaxes threshold when question pool is small to ensure sufficient questions
 *
 * @param {number} availableCount - Number of available questions in pool
 * @returns {number} Threshold in standard deviations
 */
function getDifficultyThreshold(availableCount) {
  if (availableCount < 10) {
    return DIFFICULTY_MATCH_THRESHOLD_RELAXED; // 1.5 SD - very permissive
  }
  if (availableCount < 30) {
    return DIFFICULTY_MATCH_THRESHOLD_MODERATE; // 1.0 SD - moderate
  }
  return DIFFICULTY_MATCH_THRESHOLD_STRICT; // 0.5 SD - strict (original)
}

// ============================================================================
// FISCHER INFORMATION CALCULATION
// ============================================================================

/**
 * Calculate probability of correct response using 3PL IRT model
 * 
 * @param {number} theta - Student ability [-3, +3]
 * @param {number} a - Discrimination parameter
 * @param {number} b - Difficulty parameter
 * @param {number} c - Guessing parameter
 * @returns {number} Probability [0, 1]
 */
function calculateIRTProbability(theta, a, b, c) {
  const D = 1.702; // Scaling constant for 3PL model
  const exponent = D * a * (theta - b);
  const p = c + (1 - c) / (1 + Math.exp(-exponent));
  return Math.max(0, Math.min(1, p)); // Clamp to [0, 1]
}

/**
 * Calculate Fisher Information for a question
 * Fisher Information measures how much information a question provides about theta
 * Higher FI = more informative question
 * 
 * Formula: I(θ) = a² * (P(θ) - c)² / ((1 - c)² * P(θ) * (1 - P(θ)))
 * 
 * @param {number} theta - Student ability [-3, +3]
 * @param {number} a - Discrimination parameter
 * @param {number} b - Difficulty parameter
 * @param {number} c - Guessing parameter
 * @returns {number} Fisher Information (higher = more informative)
 */
function calculateFisherInformation(theta, a, b, c) {
  const P = calculateIRTProbability(theta, a, b, c);

  // Avoid division by zero
  if (P <= 0 || P >= 1) {
    return 0;
  }

  // Fisher Information formula for 3PL model
  const numerator = Math.pow(a, 2) * Math.pow(P - c, 2);
  const denominator = Math.pow(1 - c, 2) * P * (1 - P);

  if (denominator === 0) {
    return 0;
  }

  return numerator / denominator;
}

// ============================================================================
// QUESTION FILTERING
// ============================================================================

/**
 * Get questions answered by user in last N days
 * 
 * @param {string} userId
 * @param {number} days - Number of days to look back
 * @returns {Promise<Set<string>>} Set of question IDs
 */
async function getRecentQuestionIds(userId, days = RECENCY_FILTER_DAYS) {
  try {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - days);
    const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

    // Query daily quiz responses
    const dailyQuizResponsesRef = db.collection('daily_quiz_responses')
      .doc(userId)
      .collection('responses')
      .where('answered_at', '>=', cutoffTimestamp);

    const dailyQuizSnapshot = await retryFirestoreOperation(async () => {
      return await dailyQuizResponsesRef.get();
    });

    // Query assessment responses (if within time window)
    const assessmentResponsesRef = db.collection('assessment_responses')
      .doc(userId)
      .collection('responses')
      .where('answered_at', '>=', cutoffTimestamp);

    const assessmentSnapshot = await retryFirestoreOperation(async () => {
      return await assessmentResponsesRef.get();
    });

    const recentQuestionIds = new Set();

    dailyQuizSnapshot.docs.forEach(doc => {
      const questionId = doc.data().question_id;
      if (questionId) {
        recentQuestionIds.add(questionId);
      }
    });

    assessmentSnapshot.docs.forEach(doc => {
      const questionId = doc.data().question_id;
      if (questionId) {
        recentQuestionIds.add(questionId);
      }
    });

    return recentQuestionIds;
  } catch (error) {
    logger.error('Error getting recent question IDs', {
      userId,
      error: error.message
    });
    return new Set(); // Return empty set on error (don't block selection)
  }
}

/**
 * Filter questions by difficulty match
 *
 * @param {Array} questions - Array of question documents
 * @param {number} theta - Student ability for this chapter
 * @param {number} threshold - Difficulty threshold (optional, defaults to adaptive)
 * @returns {Array} Filtered questions
 */
function filterByDifficultyMatch(questions, theta, threshold = null) {
  // Use adaptive threshold if not specified
  const difficultyThreshold = threshold !== null
    ? threshold
    : getDifficultyThreshold(questions.length);

  return questions.filter(q => {
    const irtParams = q.irt_parameters || {};
    const difficulty_b = irtParams.difficulty_b !== undefined
      ? irtParams.difficulty_b
      : q.difficulty_irt || 0;

    const diff = Math.abs(difficulty_b - theta);
    return diff <= difficultyThreshold;
  });
}

/**
 * Score questions by Fisher Information and discrimination
 * 
 * @param {Array} questions - Array of question documents
 * @param {number} theta - Student ability for this chapter
 * @returns {Array} Questions with scores, sorted by score (descending)
 */
function scoreQuestions(questions, theta) {
  return questions.map(q => {
    const irtParams = q.irt_parameters || {};
    const a = irtParams.discrimination_a || 1.5;
    const b = irtParams.difficulty_b !== undefined
      ? irtParams.difficulty_b
      : q.difficulty_irt || 0;
    const c = irtParams.guessing_c !== undefined
      ? irtParams.guessing_c
      : (q.question_type === 'mcq_single' ? 0.25 : 0.0);

    // Calculate Fisher Information
    const fisherInfo = calculateFisherInformation(theta, a, b, c);

    // Bonus for higher discrimination (better questions)
    const discriminationBonus = a * 0.1;

    // Penalty for difficulty mismatch (prefer questions closer to theta)
    const difficultyPenalty = Math.abs(b - theta) * 0.2;

    // Combined score
    const score = fisherInfo + discriminationBonus - difficultyPenalty;

    return {
      question: q,
      score: score,
      fisherInfo: fisherInfo,
      difficulty_b: b,
      discrimination_a: a
    };
  }).sort((a, b) => b.score - a.score); // Sort descending by score
}

/**
 * Normalize question document from Firestore to mobile-app compatible schema
 * 
 * @param {string} id - Question ID
 * @param {Object} data - Firestore document data
 * @returns {Object} Normalized question object
 */
function normalizeQuestion(id, data) {
  if (!data) return null;

  // Ensure all top-level IDs and strings are actually strings and never null
  const q = {
    ...data,
    question_id: String(id || data.question_id || data.id || "unknown_" + Math.random().toString(36).substr(2, 9)),
    subject: String(data.subject || data.subject_id || 'Unknown'),
    chapter: String(data.chapter || data.chapter_name || 'Unknown'),
    chapter_key: String(data.chapter_key || ''),
    question_type: String(data.question_type || 'mcq_single'),
    question_text: String(data.question_text || data.text || '')
  };

  // 1. Transform options to standardized List format
  if (q.options) {
    if (typeof q.options === 'object' && !Array.isArray(q.options)) {
      // Map format: {"A": "Text"} or {"A": {"text": "Text"}}
      q.options = Object.entries(q.options)
        .filter(([key, value]) => key !== null && key !== undefined)
        .sort(([a], [b]) => String(a).localeCompare(String(b)))
        .map(([key, value], index) => {
          const isObj = typeof value === 'object' && value !== null;
          // Ensure option_id is not empty string
          const optionId = String(key || '').trim() || String.fromCharCode(65 + index);
          return {
            option_id: optionId,
            text: String(isObj ? (value.text || value.description || '') : (value !== undefined && value !== null ? value : '')),
            html: isObj ? (value.html || value.rich_text || null) : null
          };
        });
    } else if (Array.isArray(q.options)) {
      // Array format: check for missing option_id or nulls
      q.options = q.options
        .filter(opt => opt !== null && opt !== undefined)
        .map((opt, index) => {
          if (typeof opt === 'string' || typeof opt === 'number') {
            return {
              option_id: String.fromCharCode(65 + index),
              text: String(opt)
            };
          }
          if (typeof opt === 'object') {
            // Get option_id and fallback to A, B, C, D if missing or empty
            const optionId = opt.option_id || opt.id || opt.key || '';
            return {
              ...opt,
              option_id: String(optionId).trim() || String.fromCharCode(65 + index),
              text: String(opt.text || opt.description || opt.value || ''),
              html: opt.html || opt.rich_text || null
            };
          }
          // Fallback for weird types
          return {
            option_id: String.fromCharCode(65 + index),
            text: String(opt || '')
          };
        });
    }
  } else if (q.question_type !== 'numerical') {
    q.options = [];
  }

  // 2. IRT parameters normalization
  if (q.irt_parameters) {
    const p = q.irt_parameters;
    q.irt_parameters = {
      discrimination_a: Number(p.discrimination_a || p.a || 1.5),
      difficulty_b: Number(p.difficulty_b !== undefined ? p.difficulty_b : (p.b !== undefined ? p.b : 0)),
      guessing_c: Number(p.guessing_c !== undefined ? p.guessing_c : (p.c !== undefined ? p.c : (q.question_type === 'mcq_single' ? 0.25 : 0.0)))
    };

    // Safety check for NaN
    if (isNaN(q.irt_parameters.discrimination_a)) q.irt_parameters.discrimination_a = 1.5;
    if (isNaN(q.irt_parameters.difficulty_b)) q.irt_parameters.difficulty_b = 0;
    if (isNaN(q.irt_parameters.guessing_c)) q.irt_parameters.guessing_c = 0.25;
  }

  return q;
}

// ============================================================================
// QUESTION SELECTION
// ============================================================================

/**
 * Select optimal question for a chapter using IRT
 * 
 * @param {string} chapterKey - Chapter key (e.g., "physics_electrostatics")
 * @param {number} theta - Student ability for this chapter [-3, +3]
 * @param {Set<string>} excludeQuestionIds - Question IDs to exclude (recently answered)
 * @param {number} count - Number of questions to select (default: 1)
 * @returns {Promise<Array>} Selected question documents
 */
async function selectQuestionsForChapter(chapterKey, theta, excludeQuestionIds = new Set(), count = 1) {
  try {
    logger.info('Selecting questions for chapter', { chapterKey, theta, excludeCount: excludeQuestionIds.size, count });

    // Validate chapter key format
    if (!chapterKey || typeof chapterKey !== 'string') {
      logger.warn('Invalid chapter key provided', { chapterKey });
      return [];
    }

    // 1. Try dynamic mapping first (most robust)
    const mapping = await getDatabaseNames(chapterKey);
    let subject, chapterFromKey;

    if (mapping) {
      subject = mapping.subject;
      chapterFromKey = mapping.chapter;
      logger.info('Using dynamic mapping for chapter selection', { chapterKey, subject, chapter: chapterFromKey });
    } else {
      // Fallback: Parse from key (existing logic)
      const parts = chapterKey.split('_');
      if (parts.length < 2) {
        logger.warn('Invalid chapter key format', { chapterKey });
        return [];
      }
      subject = parts[0].charAt(0).toUpperCase() + parts[0].slice(1).toLowerCase();
      chapterFromKey = parts.slice(1).join(' ').replace(/_/g, ' ');
      logger.info('Falling back to key parsing for chapter selection', { chapterKey, subject, chapter: chapterFromKey });
    }

    // Query questions for this chapter
    logger.info('Querying Firestore for questions', { chapterKey, subject, chapter: chapterFromKey });
    let questionsRef = db.collection('questions')
      .where('subject', '==', subject)
      .where('chapter', '==', chapterFromKey)
      .orderBy('irt_parameters.discrimination_a', 'desc')
      .limit(MAX_CANDIDATES);

    let snapshot = await retryFirestoreOperation(async () => {
      return await questionsRef.get();
    });
    logger.info('Firestore query completed', { chapterKey, resultCount: snapshot.size });

    // If no results and we didn't use a mapping, try Title Case as a last resort
    if (snapshot.empty && !mapping && chapterFromKey) {
      const titleCaseChapter = chapterFromKey
        .split(' ')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
        .join(' ');

      logger.info('Trying Title Case chapter name fallback', { chapterKey, titleCaseChapter });
      questionsRef = db.collection('questions')
        .where('subject', '==', subject)
        .where('chapter', '==', titleCaseChapter)
        .limit(MAX_CANDIDATES);

      snapshot = await retryFirestoreOperation(async () => {
        return await questionsRef.get();
      });
      logger.info('Firestore query completed (Title Case fallback)', { chapterKey, resultCount: snapshot.size });
    }

    if (snapshot.empty) {
      logger.warn('No questions found for chapter after all attempts', {
        chapterKey,
        subject,
        chapter: chapterFromKey
      });
      return [];
    }

    let questions = snapshot.docs
      .map(doc => normalizeQuestion(doc.id, doc.data()))
      .filter(q => q !== null);

    // Filter out excluded questions (recently answered)
    questions = questions.filter(q => !excludeQuestionIds.has(q.question_id));

    if (questions.length === 0) {
      logger.warn('All questions excluded (recently answered)', { chapterKey });
      return [];
    }

    // Filter by difficulty match
    questions = filterByDifficultyMatch(questions, theta);

    if (questions.length === 0) {
      logger.warn('No questions match difficulty threshold', {
        chapterKey,
        theta,
        threshold: DIFFICULTY_MATCH_THRESHOLD
      });
      // Fallback: use all questions if none match
      questions = snapshot.docs
        .map(doc => normalizeQuestion(doc.id, doc.data()))
        .filter(q => q !== null && !excludeQuestionIds.has(q.question_id));
    }

    // Score and rank questions
    const scoredQuestions = scoreQuestions(questions, theta);

    // Select top N questions
    const selected = scoredQuestions
      .slice(0, count)
      .map(item => item.question);

    logger.info('Questions selected for chapter', {
      chapterKey,
      theta,
      candidates: questions.length,
      selected: selected.length,
      topScore: scoredQuestions[0]?.score
    });

    return selected;
  } catch (error) {
    logger.error('Error selecting questions for chapter', {
      chapterKey,
      theta,
      error: error.message,
      stack: error.stack
    });
    throw error;
  }
}

/**
 * Select questions for multiple chapters
 * 
 * @param {Object} chapterThetas - Object mapping chapterKey to theta value
 * @param {Set<string>} excludeQuestionIds - Question IDs to exclude
 * @param {Object} options - Selection options
 * @param {number} options.questionsPerChapter - Questions per chapter (default: 1)
 * @returns {Promise<Array>} Selected question documents
 */
async function selectQuestionsForChapters(chapterThetas, excludeQuestionIds = new Set(), options = {}) {
  const { questionsPerChapter = 1 } = options;

  const allSelected = [];

  // Select questions for each chapter in parallel
  const selections = await Promise.all(
    Object.entries(chapterThetas).map(async ([chapterKey, theta]) => {
      try {
        const questions = await selectQuestionsForChapter(
          chapterKey,
          theta,
          excludeQuestionIds,
          questionsPerChapter
        );
        return questions.map(q => ({
          ...q,
          chapter_key: chapterKey,
          selection_theta: theta
        }));
      } catch (error) {
        logger.error('Error selecting questions for chapter', {
          chapterKey,
          error: error.message
        });
        return [];
      }
    })
  );

  // Flatten results
  selections.forEach(chapterQuestions => {
    allSelected.push(...chapterQuestions);
  });

  return allSelected;
}

/**
 * Fallback: Select any available questions from the database
 * Used when no questions are found for selected chapters
 * 
 * @param {Set<string>} excludeQuestionIds - Question IDs to exclude
 * @param {number} limit - Maximum number of questions to return
 * @returns {Promise<Array>} Available question documents
 */
async function selectAnyAvailableQuestions(excludeQuestionIds = new Set(), limit = 10) {
  try {
    logger.info(`selectAnyAvailableQuestions called with limit=${limit}`);

    // Query all questions, limited by count
    const questionsRef = db.collection('questions')
      .limit(limit * 3); // Get more to account for exclusions

    logger.info('Executing fallback Firestore query', { limit: limit * 3 });
    const snapshot = await retryFirestoreOperation(async () => {
      return await questionsRef.get();
    });
    logger.info('Fallback Firestore query completed', { resultCount: snapshot.size });

    if (snapshot.empty) {
      logger.warn('No questions found in database (fallback)', {});
      return [];
    }

    // Map to question objects
    let questions = snapshot.docs
      .map(doc => normalizeQuestion(doc.id, doc.data()))
      .filter(q => q !== null);

    // Filter out excluded questions
    let filteredQuestions = questions.filter(q => !excludeQuestionIds.has(q.question_id));

    logger.info('Filtered available questions', {
      initialCount: snapshot.size,
      filteredCount: filteredQuestions.length,
      excludeCount: excludeQuestionIds.size
    });

    // If all questions were excluded, return questions anyway (ignore exclusions)
    // This ensures we can still generate a quiz even if all questions were recently answered
    if (filteredQuestions.length === 0 && questions.length > 0) {
      logger.warn('All questions were excluded, returning questions anyway (ignoring exclusions for fallback)', {
        totalQuestions: questions.length,
        excludeCount: excludeQuestionIds.size
      });
      filteredQuestions = questions;
    }

    // Limit to requested count
    const selectedQuestions = filteredQuestions.slice(0, limit);

    logger.info('Fallback questions selected', {
      selected: selectedQuestions.length,
      limit,
      hadToIgnoreExclusions: filteredQuestions.length === questions.length && excludeQuestionIds.size > 0
    });

    return selectedQuestions;
  } catch (error) {
    logger.error('Error in fallback question selection', {
      error: error.message,
      stack: error.stack
    });
    return []; // Return empty array instead of throwing to allow graceful degradation
  }
}

async function getRecentQuestionIdsFromResponses(userId, days = RECENCY_FILTER_DAYS) {
  return await getRecentQuestionIds(userId, days);
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  selectQuestionsForChapter,
  selectQuestionsForChapters,
  selectAnyAvailableQuestions,
  getRecentQuestionIds,
  calculateFisherInformation,
  calculateIRTProbability,
  filterByDifficultyMatch,
  getDifficultyThreshold,  // NEW: Adaptive threshold function
  scoreQuestions,
  normalizeQuestion
};
