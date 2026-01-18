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
    } else {
      const parts = chapterKey.split('_');
      subject = parts[0]?.charAt(0).toUpperCase() + parts[0]?.slice(1).toLowerCase();
      chapterName = parts.slice(1).join(' ').replace(/_/g, ' ');
    }

    // Get question history for prioritization
    const questionHistory = await getQuestionHistory(userId, chapterKey);

    // Query all questions for this chapter (more than needed for prioritization)
    const questionsRef = db.collection('questions')
      .where('subject', '==', subject)
      .where('chapter', '==', chapterName)
      .limit(100);

    const snapshot = await retryFirestoreOperation(async () => {
      return await questionsRef.get();
    });

    if (snapshot.empty) {
      // Try title case fallback
      const titleCaseChapter = chapterName
        .split(' ')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
        .join(' ');

      const fallbackRef = db.collection('questions')
        .where('subject', '==', subject)
        .where('chapter', '==', titleCaseChapter)
        .limit(100);

      const fallbackSnapshot = await retryFirestoreOperation(async () => {
        return await fallbackRef.get();
      });

      if (fallbackSnapshot.empty) {
        throw new Error(`No questions found for chapter: ${chapterKey}`);
      }

      snapshot.docs.push(...fallbackSnapshot.docs);
    }

    // Normalize and filter questions
    let questions = snapshot.docs
      .map(doc => normalizeQuestion(doc.id, doc.data()))
      .filter(q => q !== null);

    // Debug: Log options status for first few questions
    if (questions.length > 0) {
      const optionsDebug = questions.slice(0, 3).map(q => ({
        question_id: q.question_id,
        has_options: !!(q.options && q.options.length > 0),
        options_count: q.options?.length || 0,
        question_type: q.question_type
      }));
      logger.info('Chapter practice questions options debug', {
        userId,
        chapterKey,
        total_questions: questions.length,
        sample_questions: optionsDebug
      });
    }

    // Prioritize questions (unseen > wrong > correct)
    questions = prioritizeQuestions(questions, questionHistory);

    // Select top N questions
    const selectedQuestions = questions.slice(0, questionCount);

    if (selectedQuestions.length === 0) {
      throw new Error(`No questions available for chapter: ${chapterKey}`);
    }

    // Assign positions and add chapter_key
    const formattedQuestions = selectedQuestions.map((q, index) => {
      // Remove priority field and add position
      const { _priority, ...questionData } = q;
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
      started_at: null,
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

    logger.info('Chapter practice session created', {
      userId,
      sessionId,
      chapterKey,
      questionCount: formattedQuestions.length
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
  THETA_MULTIPLIER,
  DEFAULT_QUESTION_COUNT,
  MAX_QUESTION_COUNT
};
