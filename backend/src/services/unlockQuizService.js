/**
 * Unlock Quiz Service
 *
 * Handles chapter unlock quiz logic:
 * - Generates 5-question quiz for locked chapters
 * - Processes answers (no theta updates)
 * - Unlocks chapter if student scores 3+ correct
 * - Tracks unlock attempts and success rates
 */

const { db } = require('../config/firebase');
const admin = require('firebase-admin');
const logger = require('../utils/logger');
const {
  getExposureQuestions,
  validateChapterHasExposureQuestions,
  sanitizeQuestions,
  shuffleArray
} = require('./chapterExposureService');
const { isChapterUnlocked } = require('./chapterUnlockService');

const QUESTIONS_PER_QUIZ = 5;
const PASS_THRESHOLD = 3; // Must get 3 out of 5 correct to unlock

/**
 * Generate unlock quiz session
 *
 * @param {string} userId - Student's user ID
 * @param {string} chapterKey - Chapter to unlock
 * @returns {Promise<Object>} Session data with questions
 */
async function generateUnlockQuiz(userId, chapterKey) {
  try {
    // Check if chapter is already unlocked
    const unlocked = await isChapterUnlocked(userId, chapterKey);
    if (unlocked) {
      throw new Error('Chapter is already unlocked');
    }

    // Validate chapter has exposure questions
    const hasQuestions = await validateChapterHasExposureQuestions(chapterKey);
    if (!hasQuestions) {
      throw new Error(`Chapter ${chapterKey} does not have ${QUESTIONS_PER_QUIZ} exposure questions`);
    }

    // Fetch all exposure questions
    const allQuestions = await getExposureQuestions(chapterKey);

    if (allQuestions.length !== QUESTIONS_PER_QUIZ) {
      throw new Error(`Expected ${QUESTIONS_PER_QUIZ} questions, found ${allQuestions.length}`);
    }

    // Get previously answered questions (for retry scenario)
    const answeredQuestionIds = await getPreviouslyAnsweredQuestionIds(userId, chapterKey);

    // Select questions: prefer unanswered, fallback to all if retrying
    let selectedQuestions = allQuestions.filter(
      q => !answeredQuestionIds.has(q.question_id)
    );

    if (selectedQuestions.length < QUESTIONS_PER_QUIZ) {
      // Not enough unanswered → allow retry with same questions
      selectedQuestions = allQuestions;
      logger.info(`User ${userId} retrying chapter ${chapterKey} with same questions`);
    }

    // Shuffle questions for variety
    selectedQuestions = shuffleArray(selectedQuestions);

    // Take exactly 5 questions
    selectedQuestions = selectedQuestions.slice(0, QUESTIONS_PER_QUIZ);

    // Create session
    const sessionId = `unlock_${userId}_${Date.now()}`;
    const now = new Date();
    const expiresAt = new Date(now.getTime() + 24 * 60 * 60 * 1000); // 24 hours

    const session = {
      session_id: sessionId,
      student_id: userId,
      chapter_key: chapterKey,
      chapter_name: selectedQuestions[0].chapter,
      subject: selectedQuestions[0].subject,
      status: 'in_progress',
      total_questions: QUESTIONS_PER_QUIZ,
      questions_answered: 0,
      correct_count: 0,
      questions: selectedQuestions.map((q, idx) => ({
        question_id: q.question_id,
        position: idx + 1,
        correct_answer: q.correct_answer // Kept server-side only
      })),
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      expires_at: expiresAt.toISOString()
    };

    // Save session to Firestore
    await db
      .collection('unlock_quiz_sessions')
      .doc(userId)
      .collection('sessions')
      .doc(sessionId)
      .set(session);

    logger.info('Unlock quiz session created', {
      userId,
      sessionId,
      chapterKey
    });

    // Return session with sanitized questions (no correct_answer)
    return {
      sessionId,
      chapterKey,
      chapterName: session.chapter_name,
      subject: session.subject,
      questions: sanitizeQuestions(selectedQuestions).map((q, idx) => ({
        ...q,
        position: idx + 1
      }))
    };

  } catch (error) {
    logger.error('Error generating unlock quiz:', {
      userId,
      chapterKey,
      error: error.message
    });
    throw error;
  }
}

/**
 * Get previously answered question IDs for a chapter
 *
 * @param {string} userId - Student's user ID
 * @param {string} chapterKey - Chapter key
 * @returns {Promise<Set>} Set of answered question IDs
 */
async function getPreviouslyAnsweredQuestionIds(userId, chapterKey) {
  try {
    const responsesSnapshot = await db
      .collection('unlock_quiz_responses')
      .doc(userId)
      .collection('responses')
      .where('chapter_key', '==', chapterKey)
      .select('question_id')
      .get();

    const questionIds = new Set(
      responsesSnapshot.docs.map(doc => doc.data().question_id)
    );

    return questionIds;

  } catch (error) {
    logger.error('Error fetching previous responses:', {
      userId,
      chapterKey,
      error: error.message
    });
    return new Set(); // Return empty set on error
  }
}

/**
 * Submit answer to a question (no theta updates)
 *
 * @param {string} userId - Student's user ID
 * @param {string} sessionId - Session ID
 * @param {string} questionId - Question ID
 * @param {string} selectedOption - Selected answer (A/B/C/D/E)
 * @param {number} timeTakenSeconds - Time taken to answer
 * @returns {Promise<Object>} Answer feedback
 */
async function submitUnlockQuizAnswer(userId, sessionId, questionId, selectedOption, timeTakenSeconds) {
  try {
    // Get session
    const sessionDoc = await db
      .collection('unlock_quiz_sessions')
      .doc(userId)
      .collection('sessions')
      .doc(sessionId)
      .get();

    if (!sessionDoc.exists) {
      throw new Error('Session not found');
    }

    const session = sessionDoc.data();

    if (session.status !== 'in_progress') {
      throw new Error('Session is not in progress');
    }

    // Find question in session
    const questionData = session.questions.find(q => q.question_id === questionId);
    if (!questionData) {
      throw new Error('Question not found in session');
    }

    // Check if already answered
    const responseDoc = await db
      .collection('unlock_quiz_responses')
      .doc(userId)
      .collection('responses')
      .doc(`${sessionId}_${questionId}`)
      .get();

    if (responseDoc.exists) {
      throw new Error('Question already answered in this session');
    }

    // Get full question details for solution
    const fullQuestion = await db
      .collection('chapter_exposure')
      .doc(session.chapter_key)
      .collection('questions')
      .doc(questionId)
      .get();

    if (!fullQuestion.exists) {
      throw new Error('Question data not found');
    }

    const question = fullQuestion.data();
    const isCorrect = selectedOption === questionData.correct_answer;

    // Transaction: update session + save response
    await db.runTransaction(async (transaction) => {
      const sessionRef = db
        .collection('unlock_quiz_sessions')
        .doc(userId)
        .collection('sessions')
        .doc(sessionId);

      transaction.update(sessionRef, {
        questions_answered: admin.firestore.FieldValue.increment(1),
        correct_count: isCorrect
          ? admin.firestore.FieldValue.increment(1)
          : session.correct_count || 0
      });

      // Save response (no theta updates)
      const responseRef = db
        .collection('unlock_quiz_responses')
        .doc(userId)
        .collection('responses')
        .doc(`${sessionId}_${questionId}`);

      transaction.set(responseRef, {
        session_id: sessionId,
        question_id: questionId,
        chapter_key: session.chapter_key,
        student_answer: selectedOption,
        correct_answer: questionData.correct_answer,
        is_correct: isCorrect,
        time_taken_seconds: timeTakenSeconds || 0,
        answered_at: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    logger.info('Unlock quiz answer submitted', {
      userId,
      sessionId,
      questionId,
      isCorrect
    });

    // Return feedback with solution
    const correctOption = question.options.find(
      opt => opt.option_id === questionData.correct_answer
    );

    return {
      isCorrect,
      studentAnswer: selectedOption,
      correctAnswer: questionData.correct_answer,
      correctAnswerText: correctOption ? correctOption.text : '',
      solutionText: question.solution_text || '',
      solutionSteps: question.solution_steps || [],
      keyInsight: question.key_insight || '',
      distractorAnalysis: question.distractor_analysis || {},
      commonMistakes: question.common_mistakes || []
    };

  } catch (error) {
    logger.error('Error submitting unlock quiz answer:', {
      userId,
      sessionId,
      questionId,
      error: error.message
    });
    throw error;
  }
}

/**
 * Complete unlock quiz
 * - Check if passed (3+ correct)
 * - If passed: unlock chapter
 * - Update user stats
 *
 * @param {string} userId - Student's user ID
 * @param {string} sessionId - Session ID
 * @returns {Promise<Object>} Quiz result
 */
async function completeUnlockQuiz(userId, sessionId) {
  try {
    // Get session
    const sessionDoc = await db
      .collection('unlock_quiz_sessions')
      .doc(userId)
      .collection('sessions')
      .doc(sessionId)
      .get();

    if (!sessionDoc.exists) {
      throw new Error('Session not found');
    }

    const session = sessionDoc.data();

    if (session.status === 'completed') {
      throw new Error('Session already completed');
    }

    const passed = (session.correct_count || 0) >= PASS_THRESHOLD;

    // Transaction: Update session + stats atomically
    await db.runTransaction(async (transaction) => {
      const userRef = db.collection('users').doc(userId);
      const sessionRef = db
        .collection('unlock_quiz_sessions')
        .doc(userId)
        .collection('sessions')
        .doc(sessionId);

      // Update session status
      transaction.update(sessionRef, {
        status: 'completed',
        passed,
        completed_at: admin.firestore.FieldValue.serverTimestamp()
      });

      // Update user unlock_quiz_stats
      const chapterStatsPath = `unlock_quiz_stats.attempt_history.${session.chapter_key}`;

      transaction.set(userRef, {
        unlock_quiz_stats: {
          total_attempts: admin.firestore.FieldValue.increment(1),
          successful_unlocks: passed ? admin.firestore.FieldValue.increment(1) : admin.firestore.FieldValue.increment(0)
        }
      }, { merge: true });

      transaction.set(userRef, {
        [`${chapterStatsPath}.total_attempts`]: admin.firestore.FieldValue.increment(1),
        [`${chapterStatsPath}.successful`]: passed,
        [`${chapterStatsPath}.last_attempt_at`]: admin.firestore.FieldValue.serverTimestamp(),
        [`${chapterStatsPath}.scores`]: admin.firestore.FieldValue.arrayUnion(session.correct_count || 0)
      }, { merge: true });

      // If passed: add to chapters_unlocked_via_quiz array
      if (passed) {
        transaction.set(userRef, {
          'unlock_quiz_stats.chapters_unlocked_via_quiz': admin.firestore.FieldValue.arrayUnion(session.chapter_key)
        }, { merge: true });
      }
    });

    // If passed: unlock chapter via override (outside transaction)
    if (passed) {
      await addChapterUnlockOverride(
        userId,
        session.chapter_key,
        'unlock_quiz',
        `Passed unlock quiz with ${session.correct_count}/${session.total_questions} correct`
      );

      logger.info('Chapter unlocked via quiz', {
        userId,
        chapterKey: session.chapter_key,
        score: `${session.correct_count}/${session.total_questions}`
      });
    }

    return {
      sessionId,
      chapterKey: session.chapter_key,
      chapterName: session.chapter_name,
      subject: session.subject,
      totalQuestions: session.total_questions,
      correctCount: session.correct_count || 0,
      passed,
      canRetry: !passed
    };

  } catch (error) {
    logger.error('Error completing unlock quiz:', {
      userId,
      sessionId,
      error: error.message
    });
    throw error;
  }
}

/**
 * Add chapter unlock override
 * (Imported from chapterUnlockService to avoid circular dependency)
 *
 * @param {string} userId - Student's user ID
 * @param {string} chapterKey - Chapter to unlock
 * @param {string} reason - Unlock reason
 * @param {string} notes - Additional notes
 */
async function addChapterUnlockOverride(userId, chapterKey, reason, notes) {
  try {
    const userRef = db.collection('users').doc(userId);

    await userRef.set({
      chapterUnlockOverrides: {
        [chapterKey]: {
          unlocked: true,
          reason,
          notes,
          unlockedAt: admin.firestore.FieldValue.serverTimestamp()
        }
      }
    }, { merge: true });

    logger.info('Chapter unlock override added', {
      userId,
      chapterKey,
      reason
    });

  } catch (error) {
    logger.error('Error adding chapter unlock override:', {
      userId,
      chapterKey,
      error: error.message
    });
    throw error;
  }
}

/**
 * Get unlock quiz session
 *
 * @param {string} userId - Student's user ID
 * @param {string} sessionId - Session ID
 * @returns {Promise<Object>} Session data
 */
async function getUnlockQuizSession(userId, sessionId) {
  try {
    const sessionDoc = await db
      .collection('unlock_quiz_sessions')
      .doc(userId)
      .collection('sessions')
      .doc(sessionId)
      .get();

    if (!sessionDoc.exists) {
      throw new Error('Session not found');
    }

    return {
      ...sessionDoc.data(),
      id: sessionDoc.id
    };

  } catch (error) {
    logger.error('Error fetching unlock quiz session:', {
      userId,
      sessionId,
      error: error.message
    });
    throw error;
  }
}

module.exports = {
  generateUnlockQuiz,
  submitUnlockQuizAnswer,
  completeUnlockQuiz,
  getUnlockQuizSession,
  QUESTIONS_PER_QUIZ,
  PASS_THRESHOLD
};
