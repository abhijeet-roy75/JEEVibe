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

// ============================================================================
// CONSTANTS
// ============================================================================

const DIFFICULTY_MATCH_THRESHOLD = 0.5; // |b - θ| ≤ 0.5
const RECENCY_FILTER_DAYS = 30; // Don't show questions answered in last 30 days
const MAX_CANDIDATES = 50; // Maximum candidates to evaluate before selecting

// ============================================================================
// FISHER INFORMATION CALCULATION
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
 * @returns {Array} Filtered questions
 */
function filterByDifficultyMatch(questions, theta) {
  return questions.filter(q => {
    const irtParams = q.irt_parameters || {};
    const difficulty_b = irtParams.difficulty_b !== undefined 
      ? irtParams.difficulty_b 
      : q.difficulty_irt || 0;
    
    const diff = Math.abs(difficulty_b - theta);
    return diff <= DIFFICULTY_MATCH_THRESHOLD;
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
    // Validate chapter key format
    if (!chapterKey || typeof chapterKey !== 'string') {
      logger.warn('Invalid chapter key provided', { chapterKey });
      return [];
    }
    
    // Extract subject and chapter from chapterKey
    // Format: "subject_chapter_name" or "subject_chapter_name_with_spaces"
    const parts = chapterKey.split('_');
    
    if (parts.length < 2) {
      logger.warn('Chapter key format may be invalid, attempting to parse', { 
        chapterKey,
        parts: parts.length 
      });
      // Try to handle single-word chapters (fallback)
      if (parts.length === 1) {
        // Assume entire string is chapter name, try to infer subject from context
        // This is a fallback - ideally chapter keys should always have subject prefix
        logger.warn('Single-part chapter key detected, may cause query issues', { chapterKey });
        return [];
      }
    }
    
    const subject = parts[0].charAt(0).toUpperCase() + parts[0].slice(1).toLowerCase(); // Capitalize first letter, lowercase rest
    const chapterFromKey = parts.slice(1).join(' ').replace(/_/g, ' '); // Convert underscores to spaces
    
    // Query questions for this chapter
    // Try exact match first, then case-insensitive fallback
    let questionsRef = db.collection('questions')
      .where('subject', '==', subject)
      .where('chapter', '==', chapterFromKey)
      .limit(MAX_CANDIDATES);
    
    let snapshot = await retryFirestoreOperation(async () => {
      return await questionsRef.get();
    });
    
    // If no results, try with capitalized chapter name (Title Case)
    if (snapshot.empty && chapterFromKey) {
      const titleCaseChapter = chapterFromKey
        .split(' ')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
        .join(' ');
      
      questionsRef = db.collection('questions')
        .where('subject', '==', subject)
        .where('chapter', '==', titleCaseChapter)
        .limit(MAX_CANDIDATES);
      
      snapshot = await retryFirestoreOperation(async () => {
        return await questionsRef.get();
      });
    }
    
    if (snapshot.empty) {
      logger.warn('No questions found for chapter', { 
        chapterKey, 
        subject, 
        chapter: chapterFromKey,
        triedFormats: [chapterFromKey, chapterFromKey.split(' ').map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join(' ')]
      });
      return [];
    }
    
    let questions = snapshot.docs.map(doc => ({
      question_id: doc.id,
      ...doc.data()
    }));
    
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
      questions = snapshot.docs.map(doc => ({
        question_id: doc.id,
        ...doc.data()
      })).filter(q => !excludeQuestionIds.has(q.question_id));
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

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  selectQuestionsForChapter,
  selectQuestionsForChapters,
  getRecentQuestionIds,
  calculateFisherInformation,
  calculateIRTProbability,
  filterByDifficultyMatch,
  scoreQuestions
};

