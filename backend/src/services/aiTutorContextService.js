/**
 * AI Tutor Context Service
 * Builds context objects from solutions, quizzes, and analytics data
 * for injection into AI Tutor conversation prompts
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { calculateFocusAreas, getMasteryStatus, getSubjectDisplayName, getChapterDisplayNameAsync } = require('./analyticsService');

/**
 * Build context from a Snap & Solve solution
 * @param {string} solutionId - Solution document ID (snap ID)
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Context object for solution
 */
async function buildSolutionContext(solutionId, userId) {
  try {
    const snapRef = db.collection('users').doc(userId).collection('snaps').doc(solutionId);
    const snapDoc = await retryFirestoreOperation(() => snapRef.get());

    if (!snapDoc.exists) {
      logger.warn('Solution not found for context', { solutionId, userId });
      return null;
    }

    const snap = snapDoc.data();

    // Debug: Log what we found in the snap document
    logger.info('Building solution context', {
      solutionId,
      userId,
      hasRecognizedQuestion: !!snap.recognizedQuestion,
      questionLength: (snap.recognizedQuestion || snap.question || '').length,
      hasApproach: !!snap.solution?.approach,
      hasSteps: !!(snap.solution?.steps?.length),
      hasFinalAnswer: !!snap.solution?.finalAnswer
    });

    // Build context object
    const context = {
      type: 'solution',
      contextId: solutionId,
      title: `${snap.topic || 'Problem'} - ${getSubjectDisplayName(snap.subject || 'General')}`,
      snapshot: {
        question: snap.recognizedQuestion || snap.question || '',
        subject: snap.subject,
        topic: snap.topic,
        difficulty: snap.difficulty,
        approach: snap.solution?.approach || '',
        steps: snap.solution?.steps || [],
        finalAnswer: snap.solution?.finalAnswer || '',
        priyaMaamTip: snap.solution?.priyaMaamTip || snap.solution?.priya_maam_tip || '',
        conceptsTested: snap.conceptsTested || [],
        // Include image URL for reference
        imageUrl: snap.imageUrl || null
      }
    };

    logger.info('Solution context built', {
      solutionId,
      contextTitle: context.title,
      questionPreview: context.snapshot.question.substring(0, 100)
    });

    return context;
  } catch (error) {
    logger.error('Error building solution context', { solutionId, userId, error: error.message });
    throw error;
  }
}

/**
 * Build context from quiz results
 * @param {string} quizId - Quiz document ID
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Context object for quiz
 */
async function buildQuizContext(quizId, userId) {
  try {
    const quizRef = db.collection('daily_quizzes').doc(userId).collection('quizzes').doc(quizId);
    const quizDoc = await retryFirestoreOperation(() => quizRef.get());

    if (!quizDoc.exists) {
      logger.warn('Quiz not found for context', { quizId, userId });
      return null;
    }

    const quiz = quizDoc.data();

    // Get questions from subcollection
    const questionsSnapshot = await retryFirestoreOperation(() =>
      quizRef.collection('questions').orderBy('position', 'asc').get()
    );

    const questions = questionsSnapshot.docs.map(doc => doc.data());

    // Get incorrect questions with details
    const incorrectQuestions = questions
      .filter(q => q.is_correct === false)
      .map(q => ({
        position: q.position,
        question: q.question_text || `Question ${q.position}`,
        studentAnswer: q.student_answer,
        correctAnswer: q.correct_answer,
        subject: q.subject,
        chapter: q.chapter
      }));

    // Calculate score
    const correctCount = questions.filter(q => q.is_correct === true).length;
    const totalCount = questions.length;

    const context = {
      type: 'quiz',
      contextId: quizId,
      title: `Daily Quiz Review (${correctCount}/${totalCount})`,
      snapshot: {
        score: correctCount,
        total: totalCount,
        accuracy: totalCount > 0 ? Math.round((correctCount / totalCount) * 100) : 0,
        completedAt: quiz.completed_at ? quiz.completed_at.toDate().toISOString() : null,
        incorrectQuestions: incorrectQuestions.slice(0, 5), // Limit to 5 for context size
        subjectBreakdown: calculateSubjectBreakdown(questions)
      }
    };

    return context;
  } catch (error) {
    logger.error('Error building quiz context', { quizId, userId, error: error.message });
    throw error;
  }
}

/**
 * Calculate subject breakdown from quiz questions
 * @param {Array} questions - Quiz questions
 * @returns {Object} Subject-wise breakdown
 */
function calculateSubjectBreakdown(questions) {
  const breakdown = {};

  questions.forEach(q => {
    const subject = (q.subject || 'unknown').toLowerCase();
    if (!breakdown[subject]) {
      breakdown[subject] = { total: 0, correct: 0 };
    }
    breakdown[subject].total++;
    if (q.is_correct) {
      breakdown[subject].correct++;
    }
  });

  return breakdown;
}

/**
 * Build context from analytics/theta data
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Context object for analytics
 */
async function buildAnalyticsContext(userId) {
  try {
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(() => userRef.get());

    if (!userDoc.exists) {
      logger.warn('User not found for analytics context', { userId });
      return null;
    }

    const userData = userDoc.data();
    const thetaByChapter = userData.theta_by_chapter || {};
    const thetaBySubject = userData.theta_by_subject || {};

    // Calculate focus areas
    const focusAreas = await calculateFocusAreas(thetaByChapter, 5);

    // Get subject strengths
    const subjects = Object.entries(thetaBySubject)
      .map(([subject, data]) => ({
        subject: getSubjectDisplayName(subject),
        percentile: data.percentile || 50,
        status: getMasteryStatus(data.percentile || 50)
      }))
      .sort((a, b) => b.percentile - a.percentile);

    const context = {
      type: 'analytics',
      contextId: null,
      title: 'My Progress',
      snapshot: {
        overallPercentile: userData.overall_percentile || 50,
        overallTheta: userData.overall_theta || 0,
        subjectPerformance: subjects,
        strongestSubject: subjects[0] || null,
        weakestSubject: subjects[subjects.length - 1] || null,
        focusAreas: focusAreas.map(area => ({
          chapter: area.chapter_name,
          chapterKey: area.chapter_key,
          subject: area.subject_name,
          percentile: area.percentile,
          reason: area.reason
        })),
        totalQuizzes: userData.completed_quiz_count || 0,
        streak: userData.streak || 0
      }
    };

    return context;
  } catch (error) {
    logger.error('Error building analytics context', { userId, error: error.message });
    throw error;
  }
}

/**
 * Build general context (from home screen, no specific topic)
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Context object for general chat
 */
async function buildGeneralContext(userId) {
  try {
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(() => userRef.get());

    if (!userDoc.exists) {
      return {
        type: 'general',
        contextId: null,
        title: 'General Chat',
        snapshot: null
      };
    }

    const userData = userDoc.data();

    return {
      type: 'general',
      contextId: null,
      title: 'General Chat',
      snapshot: {
        overallPercentile: userData.overall_percentile || 50,
        streak: userData.streak || 0,
        totalQuizzes: userData.completed_quiz_count || 0
      }
    };
  } catch (error) {
    logger.error('Error building general context', { userId, error: error.message });
    // Return minimal context on error
    return {
      type: 'general',
      contextId: null,
      title: 'General Chat',
      snapshot: null
    };
  }
}

/**
 * Get student profile data for system prompt
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Student profile data
 */
async function getStudentProfile(userId) {
  try {
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(() => userRef.get());

    if (!userDoc.exists) {
      return null;
    }

    const userData = userDoc.data();
    const thetaByChapter = userData.theta_by_chapter || {};
    const thetaBySubject = userData.theta_by_subject || {};

    // Calculate strengths (top 3 chapters)
    const strengths = Object.entries(thetaByChapter)
      .filter(([_, data]) => (data.percentile || 0) >= 70)
      .sort((a, b) => (b[1].percentile || 0) - (a[1].percentile || 0))
      .slice(0, 3)
      .map(([key, _]) => formatChapterKey(key));

    // Calculate weaknesses (bottom 3 chapters with attempts)
    const weaknesses = Object.entries(thetaByChapter)
      .filter(([_, data]) => (data.attempts || 0) > 0 && (data.percentile || 0) < 50)
      .sort((a, b) => (a[1].percentile || 0) - (b[1].percentile || 0))
      .slice(0, 3)
      .map(([key, _]) => formatChapterKey(key));

    return {
      firstName: userData.firstName || userData.first_name,
      overallTheta: userData.overall_theta,
      overallPercentile: userData.overall_percentile,
      thetaBySubject: Object.fromEntries(
        Object.entries(thetaBySubject).map(([subject, data]) => [
          subject,
          { percentile: data.percentile || 50 }
        ])
      ),
      strengths,
      weaknesses,
      streak: userData.streak || 0,
      totalQuizzes: userData.completed_quiz_count || 0
    };
  } catch (error) {
    logger.error('Error getting student profile', { userId, error: error.message });
    return null;
  }
}

/**
 * Format chapter key to readable name
 * @param {string} chapterKey - e.g., "physics_kinematics"
 * @returns {string} Formatted name e.g., "Kinematics"
 */
function formatChapterKey(chapterKey) {
  return chapterKey
    .replace(/^(physics|chemistry|maths|mathematics)_/, '')
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

/**
 * Build context based on context type
 * @param {string} contextType - 'solution', 'quiz', 'analytics', or 'general'
 * @param {string} contextId - ID of the context item (solution/quiz ID)
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Context object
 */
async function buildContext(contextType, contextId, userId) {
  switch (contextType) {
    case 'solution':
      if (!contextId) {
        throw new Error('contextId required for solution context');
      }
      return buildSolutionContext(contextId, userId);

    case 'quiz':
      if (!contextId) {
        throw new Error('contextId required for quiz context');
      }
      return buildQuizContext(contextId, userId);

    case 'analytics':
      return buildAnalyticsContext(userId);

    case 'general':
    default:
      return buildGeneralContext(userId);
  }
}

module.exports = {
  buildSolutionContext,
  buildQuizContext,
  buildAnalyticsContext,
  buildGeneralContext,
  buildContext,
  getStudentProfile
};
