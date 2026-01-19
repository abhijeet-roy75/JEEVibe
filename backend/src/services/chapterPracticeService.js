/**
 * Chapter Practice Service
 *
 * Generates chapter-specific practice sessions for focused learning.
 * Unlike daily quiz (cross-chapter), this targets a single chapter.
 *
 * Features:
 * - Single chapter focus (from Focus Areas)
 * - Up to 15 questions per session
 * - IRT-based question selection
 * - Prioritizes unseen/incorrect questions
 * - 0.5x theta multiplier (vs 1.0 for daily quiz)
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { v4: uuidv4 } = require('uuid');
const { normalizeQuestion } = require('./questionSelectionService');
const { getDatabaseNames } = require('./chapterMappingService');

// ============================================================================
// CONSTANTS
// ============================================================================

const DEFAULT_QUESTION_COUNT = 15;
const MAX_QUESTION_COUNT = 20;
const THETA_MULTIPLIER = 0.5; // Half the impact of daily quiz
const SESSION_EXPIRY_HOURS = 24;
const HISTORY_QUERY_LIMIT = 50; // Limit per collection for performance

// Difficulty bands for progressive question selection (easy → hard)
const DIFFICULTY_BANDS = {
  easy: { max: 0.7, target: 5 },      // b <= 0.7
  medium: { min: 0.7, max: 1.2, target: 5 },  // 0.7 < b <= 1.2
  hard: { min: 1.2, target: 5 }       // b > 1.2
};

// ============================================================================
// QUESTION PRIORITIZATION
// ============================================================================

/**
 * Get question history for a chapter to prioritize unseen/wrong questions
 *
 * @param {string} userId
 * @param {string} chapterKey
 * @returns {Promise<Map<string, {seen: boolean, lastCorrect: boolean}>>}
 */
async function getQuestionHistory(userId, chapterKey) {
  const history = new Map();

  try {
    // Query responses for this chapter from daily quiz responses
    // Limited to recent responses for performance
    const responsesRef = db.collection('daily_quiz_responses')
      .doc(userId)
      .collection('responses')
      .where('chapter_key', '==', chapterKey)
      .orderBy('answered_at', 'desc')
      .limit(HISTORY_QUERY_LIMIT);

    const snapshot = await retryFirestoreOperation(async () => {
      return await responsesRef.get();
    });

    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const questionId = data.question_id;

      // Only keep most recent response per question
      if (!history.has(questionId)) {
        history.set(questionId, {
          seen: true,
          lastCorrect: data.is_correct === true,
          answeredAt: data.answered_at
        });
      }
    });

    // Also check chapter practice responses
    const practiceResponsesRef = db.collection('chapter_practice_responses')
      .doc(userId)
      .collection('responses')
      .where('chapter_key', '==', chapterKey)
      .orderBy('answered_at', 'desc')
      .limit(HISTORY_QUERY_LIMIT);

    const practiceSnapshot = await retryFirestoreOperation(async () => {
      return await practiceResponsesRef.get();
    });

    practiceSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const questionId = data.question_id;

      // Only update if we haven't seen this question or this is more recent
      if (!history.has(questionId)) {
        history.set(questionId, {
          seen: true,
          lastCorrect: data.is_correct === true,
          answeredAt: data.answered_at
        });
      }
    });

    logger.info('Question history loaded for chapter', {
      userId,
      chapterKey,
      questionsTracked: history.size
    });

  } catch (error) {
    logger.warn('Failed to load question history, proceeding without prioritization', {
      userId,
      chapterKey,
      error: error.message
    });
  }

  return history;
}

/**
 * Score and sort questions by priority
 * Prioritizes: 1) Unseen, 2) Previously wrong, 3) Previously correct
 *
 * @param {Array} questions
 * @param {Map} history
 * @returns {Array} Sorted questions
 */
function prioritizeQuestions(questions, history) {
  return questions.map(q => {
    const questionId = q.question_id;
    const historyEntry = history.get(questionId);

    let priority = 0;
    if (!historyEntry) {
      // Never seen - highest priority
      priority = 3;
    } else if (!historyEntry.lastCorrect) {
      // Seen but got wrong - medium priority
      priority = 2;
    } else {
      // Seen and got correct - lowest priority
      priority = 1;
    }

    return { ...q, _priority: priority };
  }).sort((a, b) => {
    // Sort by priority descending
    if (b._priority !== a._priority) {
      return b._priority - a._priority;
    }
    // Secondary: randomize within same priority
    return Math.random() - 0.5;
  });
}

/**
 * Get the difficulty band for a question based on its IRT difficulty parameter
 * @param {Object} question - Question object with irt_parameters or difficulty_irt
 * @returns {string} 'easy', 'medium', or 'hard'
 */
function getDifficultyBand(question) {
  const b = question.irt_parameters?.difficulty_b ??
            question.difficulty_irt ?? 0;

  if (b <= DIFFICULTY_BANDS.easy.max) return 'easy';
  if (b <= DIFFICULTY_BANDS.medium.max) return 'medium';
  return 'hard';
}

/**
 * Select questions with difficulty progression (easy → medium → hard)
 * This helps weak students "ease into" the chapter by starting with easier questions
 *
 * @param {Array} questions - All available questions for the chapter
 * @param {Map} history - Question history map from getQuestionHistory
 * @param {number} totalCount - Total questions to select (default: 15)
 * @returns {Array} Questions ordered by difficulty band (easy first, hard last)
 */
function selectDifficultyProgressiveQuestions(questions, history, totalCount = DEFAULT_QUESTION_COUNT) {
  if (!questions || questions.length === 0) {
    return [];
  }

  // Step 1: Add priority scores and difficulty info to each question
  const scoredQuestions = questions.map(q => {
    const questionId = q.question_id;
    const historyEntry = history.get(questionId);

    // Priority: 3 = unseen, 2 = wrong, 1 = correct
    let priority = 0;
    if (!historyEntry) {
      priority = 3; // Never seen - highest priority
    } else if (!historyEntry.lastCorrect) {
      priority = 2; // Seen but got wrong - medium priority
    } else {
      priority = 1; // Seen and got correct - lowest priority
    }

    const b = q.irt_parameters?.difficulty_b ?? q.difficulty_irt ?? 0;
    const band = getDifficultyBand(q);

    return { ...q, _priority: priority, _difficulty: b, _band: band };
  });

  // Step 2: Group by difficulty band
  const bands = {
    easy: scoredQuestions.filter(q => q._band === 'easy'),
    medium: scoredQuestions.filter(q => q._band === 'medium'),
    hard: scoredQuestions.filter(q => q._band === 'hard')
  };

  // Step 3: Sort each band by priority (desc), then difficulty (asc within band)
  Object.keys(bands).forEach(band => {
    bands[band].sort((a, b) => {
      // Primary: priority descending (unseen first)
      if (b._priority !== a._priority) {
        return b._priority - a._priority;
      }
      // Secondary: difficulty ascending (easier first within same priority)
      return a._difficulty - b._difficulty;
    });
  });

  // Step 4: Select questions with target per band, with fallback
  const selected = [];
  const targetPerBand = Math.floor(totalCount / 3);
  let remaining = totalCount;

  // Select from easy band first
  const easyCount = Math.min(targetPerBand, bands.easy.length, remaining);
  selected.push(...bands.easy.slice(0, easyCount));
  remaining -= easyCount;

  // Select from medium band
  const mediumCount = Math.min(targetPerBand, bands.medium.length, remaining);
  selected.push(...bands.medium.slice(0, mediumCount));
  remaining -= mediumCount;

  // Select from hard band (gets any remainder from division)
  const hardCount = Math.min(remaining, bands.hard.length);
  selected.push(...bands.hard.slice(0, hardCount));
  remaining -= hardCount;

  // Step 5: Fill remaining slots if we don't have enough
  if (remaining > 0) {
    // Get all questions not yet selected, sorted by difficulty ascending
    const selectedIds = new Set(selected.map(q => q.question_id));
    const availableQuestions = scoredQuestions
      .filter(q => !selectedIds.has(q.question_id))
      .sort((a, b) => a._difficulty - b._difficulty);

    while (remaining > 0 && availableQuestions.length > 0) {
      selected.push(availableQuestions.shift());
      remaining--;
    }
  }

  // Step 6: Final sort to ensure easy → medium → hard order
  // We maintain stability within bands (priority order preserved)
  const bandOrder = { easy: 0, medium: 1, hard: 2 };
  selected.sort((a, b) => {
    const bandDiff = bandOrder[a._band] - bandOrder[b._band];
    if (bandDiff !== 0) return bandDiff;
    // Within same band, maintain priority order
    return b._priority - a._priority;
  });

  logger.info('Difficulty-progressive question selection complete', {
    totalAvailable: questions.length,
    selected: selected.length,
    byBand: {
      easy: selected.filter(q => q._band === 'easy').length,
      medium: selected.filter(q => q._band === 'medium').length,
      hard: selected.filter(q => q._band === 'hard').length
    }
  });

  return selected;
}

// ============================================================================
// SESSION GENERATION
// ============================================================================

/**
 * Generate a chapter practice session
 *
 * @param {string} userId
 * @param {string} chapterKey - Format: "subject_chapter_name"
 * @param {number} questionCount - Number of questions (default: 15)
 * @returns {Promise<Object>} Session with questions
 */
async function generateChapterPractice(userId, chapterKey, questionCount = DEFAULT_QUESTION_COUNT) {
  try {
    logger.info('Generating chapter practice session', {
      userId,
      chapterKey,
      questionCount
    });

    // Validate question count
    questionCount = Math.min(Math.max(1, questionCount), MAX_QUESTION_COUNT);

    // Get user data for theta
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    if (!userDoc.exists) {
      throw new Error(`User ${userId} not found`);
    }

    const userData = userDoc.data();
    const thetaByChapter = userData.theta_by_chapter || {};
    const chapterData = thetaByChapter[chapterKey] || { theta: 0.0 };
    const chapterTheta = chapterData.theta || 0.0;

    // Parse chapter key to get chapter info
    const mapping = await getDatabaseNames(chapterKey);
    let subject, chapterName;

    if (mapping) {
      subject = mapping.subject;
      chapterName = mapping.chapter;
      logger.info('Chapter mapping found', { chapterKey, subject, chapterName });
    } else {
      const parts = chapterKey.split('_');
      subject = parts[0]?.charAt(0).toUpperCase() + parts[0]?.slice(1).toLowerCase();
      chapterName = parts.slice(1).join(' ').replace(/_/g, ' ');
      logger.warn('No chapter mapping found, using parsed values', { chapterKey, subject, chapterName });
    }

    // Get question history for prioritization
    const questionHistory = await getQuestionHistory(userId, chapterKey);

    // Query all questions for this chapter (more than needed for prioritization)
    let snapshot = await retryFirestoreOperation(async () => {
      return await db.collection('questions')
        .where('subject', '==', subject)
        .where('chapter', '==', chapterName)
        .limit(100)
        .get();
    });

    logger.info('Initial question query result', {
      chapterKey,
      subject,
      chapterName,
      found: snapshot.size
    });

    // Fallback 1: Try title case chapter name
    if (snapshot.empty) {
      const titleCaseChapter = chapterName
        .split(' ')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
        .join(' ');

      logger.info('Trying title case fallback', { titleCaseChapter });

      snapshot = await retryFirestoreOperation(async () => {
        return await db.collection('questions')
          .where('subject', '==', subject)
          .where('chapter', '==', titleCaseChapter)
          .limit(100)
          .get();
      });
    }

    // Fallback 2: Try lowercase chapter name
    if (snapshot.empty) {
      const lowerCaseChapter = chapterName.toLowerCase();
      logger.info('Trying lowercase fallback', { lowerCaseChapter });

      snapshot = await retryFirestoreOperation(async () => {
        return await db.collection('questions')
          .where('subject', '==', subject)
          .where('chapter', '==', lowerCaseChapter)
          .limit(100)
          .get();
      });
    }

    // Fallback 3: Try different subject case variations
    if (snapshot.empty) {
      const subjectVariations = [
        subject.toLowerCase(),
        subject.toUpperCase(),
        subject
      ];

      for (const subjectVar of subjectVariations) {
        logger.info('Trying subject variation', { subject: subjectVar, chapterName });

        snapshot = await retryFirestoreOperation(async () => {
          return await db.collection('questions')
            .where('subject', '==', subjectVar)
            .where('chapter', '==', chapterName)
            .limit(100)
            .get();
        });

        if (!snapshot.empty) break;
      }
    }

    if (snapshot.empty) {
      logger.error('No questions found after all fallbacks', {
        chapterKey,
        subject,
        chapterName,
        userId
      });
      throw new Error(`No questions found for chapter: ${chapterKey}. Please try a different chapter.`);
    }

    // Normalize and filter questions
    let questions = snapshot.docs
      .map(doc => normalizeQuestion(doc.id, doc.data()))
      .filter(q => q !== null);

    // Filter out MCQ questions without options (data quality issue)
    const questionsWithOptions = questions.filter(q => {
      // Numerical questions don't need options
      if (q.question_type === 'numerical') return true;
      // MCQ questions must have options
      const hasOptions = q.options && Array.isArray(q.options) && q.options.length > 0;
      if (!hasOptions) {
        logger.warn('Skipping MCQ question without options', {
          question_id: q.question_id,
          question_type: q.question_type,
          chapterKey
        });
      }
      return hasOptions;
    });

    // Debug: Log options status
    logger.info('Chapter practice questions filtered', {
      userId,
      chapterKey,
      total_raw: snapshot.size,
      total_normalized: questions.length,
      total_with_options: questionsWithOptions.length,
      filtered_out: questions.length - questionsWithOptions.length
    });

    questions = questionsWithOptions;

    // Debug: Log options status for first few questions
    if (questions.length > 0) {
      const optionsDebug = questions.slice(0, 3).map(q => ({
        question_id: q.question_id,
        has_options: !!(q.options && q.options.length > 0),
        options_count: q.options?.length || 0,
        options_sample: q.options?.slice(0, 2)?.map(o => ({ id: o.option_id, text: o.text?.substring(0, 30) })),
        question_type: q.question_type
      }));
      logger.info('Chapter practice questions options debug', {
        userId,
        chapterKey,
        total_questions: questions.length,
        sample_questions: optionsDebug
      });
    }

    // Select questions with difficulty progression (easy → medium → hard)
    // This helps weak students ease into the chapter
    const selectedQuestions = selectDifficultyProgressiveQuestions(
      questions,
      questionHistory,
      questionCount
    );

    if (selectedQuestions.length === 0) {
      throw new Error(`No questions available for chapter: ${chapterKey}`);
    }

    // Assign positions and add chapter_key
    const formattedQuestions = selectedQuestions.map((q, index) => {
      // Remove internal fields and add position
      const { _priority, _difficulty, _band, ...questionData } = q;
      return {
        ...questionData,
        position: index,
        chapter_key: chapterKey
      };
    });

    // Generate session ID
    const sessionId = `cp_${uuidv4().substring(0, 8)}_${Date.now()}`;

    // Create session document
    const sessionData = {
      session_id: sessionId,
      student_id: userId,
      chapter_key: chapterKey,
      chapter_name: chapterName,
      subject: subject,
      status: 'in_progress',
      theta_at_start: chapterTheta,
      theta_multiplier: THETA_MULTIPLIER,
      total_questions: formattedQuestions.length,
      questions_answered: 0,
      correct_count: 0,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      started_at: admin.firestore.FieldValue.serverTimestamp(), // Set when session is generated (no separate start endpoint)
      completed_at: null,
      expires_at: new Date(Date.now() + SESSION_EXPIRY_HOURS * 60 * 60 * 1000).toISOString()
    };

    // Save session to Firestore
    const sessionRef = db.collection('chapter_practice_sessions')
      .doc(userId)
      .collection('sessions')
      .doc(sessionId);

    await retryFirestoreOperation(async () => {
      return await sessionRef.set(sessionData);
    });

    // Save questions to subcollection (without sensitive fields)
    const batch = db.batch();

    formattedQuestions.forEach((q, index) => {
      const { correct_answer, correct_answer_text, solution_text, solution_steps, ...questionToStore } = q;

      // Ensure options is always an array (defensive)
      if (!questionToStore.options) {
        questionToStore.options = [];
      }

      const questionRef = sessionRef.collection('questions').doc(String(index));
      batch.set(questionRef, {
        ...questionToStore,
        answered: false,
        student_answer: null,
        is_correct: null,
        time_taken_seconds: null,
        answered_at: null
      });
    });

    await batch.commit();

    // Log what we stored (for debugging)
    const storedOptionsDebug = formattedQuestions.slice(0, 2).map(q => ({
      question_id: q.question_id,
      options_count: q.options?.length || 0
    }));

    logger.info('Chapter practice session created', {
      userId,
      sessionId,
      chapterKey,
      questionCount: formattedQuestions.length,
      stored_options_debug: storedOptionsDebug
    });

    // Return session with sanitized questions (no answers)
    const sanitizedQuestions = formattedQuestions.map(q => {
      const { correct_answer, correct_answer_text, solution_text, solution_steps, ...sanitized } = q;
      return sanitized;
    });

    return {
      session_id: sessionId,
      chapter_key: chapterKey,
      chapter_name: chapterName,
      subject: subject,
      questions: sanitizedQuestions,
      total_questions: sanitizedQuestions.length,
      theta_at_start: chapterTheta,
      created_at: new Date().toISOString()
    };

  } catch (error) {
    logger.error('Error generating chapter practice', {
      userId,
      chapterKey,
      error: error.message,
      stack: error.stack
    });
    throw error;
  }
}

// ============================================================================
// GET SESSION
// ============================================================================

/**
 * Get an existing session with its questions
 *
 * @param {string} userId
 * @param {string} sessionId
 * @returns {Promise<Object|null>}
 */
async function getSession(userId, sessionId) {
  try {
    const sessionRef = db.collection('chapter_practice_sessions')
      .doc(userId)
      .collection('sessions')
      .doc(sessionId);

    const sessionDoc = await retryFirestoreOperation(async () => {
      return await sessionRef.get();
    });

    if (!sessionDoc.exists) {
      return null;
    }

    const sessionData = sessionDoc.data();

    // Validate session ownership (defense in depth)
    if (sessionData.student_id && sessionData.student_id !== userId) {
      logger.warn('Session ownership mismatch in getSession', {
        sessionId,
        sessionOwner: sessionData.student_id,
        requestingUser: userId
      });
      return null;
    }

    // Get questions
    const questionsSnapshot = await retryFirestoreOperation(async () => {
      return await sessionRef.collection('questions')
        .orderBy('position', 'asc')
        .get();
    });

    const questions = questionsSnapshot.docs.map(doc => {
      const data = doc.data();
      // Remove answers for in-progress sessions
      if (sessionData.status === 'in_progress' && !data.answered) {
        const { correct_answer, correct_answer_text, solution_text, solution_steps, ...sanitized } = data;
        return sanitized;
      }
      return data;
    });

    // Log options status for debugging existing sessions
    const optionsDebug = questions.slice(0, 2).map(q => ({
      question_id: q.question_id,
      has_options: !!(q.options && q.options.length > 0),
      options_count: q.options?.length || 0
    }));
    logger.info('GetSession returning questions', {
      sessionId,
      total_questions: questions.length,
      options_debug: optionsDebug
    });

    return {
      ...sessionData,
      questions
    };

  } catch (error) {
    logger.error('Error getting session', {
      userId,
      sessionId,
      error: error.message
    });
    throw error;
  }
}

// ============================================================================
// GET ACTIVE SESSION
// ============================================================================

/**
 * Get active (in-progress) session for a chapter
 *
 * @param {string} userId
 * @param {string} chapterKey - Optional, if provided only check for this chapter
 * @returns {Promise<Object|null>}
 */
async function getActiveSession(userId, chapterKey = null) {
  try {
    let query = db.collection('chapter_practice_sessions')
      .doc(userId)
      .collection('sessions')
      .where('status', '==', 'in_progress')
      .orderBy('created_at', 'desc')
      .limit(1);

    if (chapterKey) {
      query = db.collection('chapter_practice_sessions')
        .doc(userId)
        .collection('sessions')
        .where('status', '==', 'in_progress')
        .where('chapter_key', '==', chapterKey)
        .orderBy('created_at', 'desc')
        .limit(1);
    }

    const snapshot = await retryFirestoreOperation(async () => {
      return await query.get();
    });

    if (snapshot.empty) {
      return null;
    }

    const sessionDoc = snapshot.docs[0];
    return await getSession(userId, sessionDoc.id);

  } catch (error) {
    logger.error('Error getting active session', {
      userId,
      chapterKey,
      error: error.message
    });
    return null;
  }
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  generateChapterPractice,
  getSession,
  getActiveSession,
  getQuestionHistory,
  prioritizeQuestions,
  selectDifficultyProgressiveQuestions,
  getDifficultyBand,
  THETA_MULTIPLIER,
  DEFAULT_QUESTION_COUNT,
  MAX_QUESTION_COUNT,
  DIFFICULTY_BANDS
};
