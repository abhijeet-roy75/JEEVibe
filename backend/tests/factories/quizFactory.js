/**
 * Quiz Factory
 *
 * Creates test quiz sessions and responses.
 */

/**
 * Create quiz session
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Quiz session
 */
function createQuizSession(overrides = {}) {
  const defaults = {
    quiz_id: `quiz_${Date.now()}`,
    user_id: 'test-user-001',
    quiz_type: 'daily',
    status: 'in_progress',
    questions: [
      {
        question_id: 'PHY_KIN_001',
        subject: 'Physics',
        chapter_key: 'physics_kinematics',
        difficulty: 'medium',
        irt_parameters: {
          difficulty_b: 0.0,
          discrimination_a: 1.5,
          guessing_c: 0.25
        }
      }
    ],
    total_questions: 5,
    questions_answered: 0,
    started_at: new Date().toISOString(),
    expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
  };

  return { ...defaults, ...overrides };
}

/**
 * Create completed quiz session
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Completed quiz session
 */
function createCompletedQuizSession(overrides = {}) {
  return createQuizSession({
    status: 'completed',
    questions_answered: 5,
    completed_at: new Date().toISOString(),
    score: 4,
    total_questions: 5,
    accuracy: 80.0,
    ...overrides
  });
}

/**
 * Create quiz response
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Quiz response
 */
function createQuizResponse(overrides = {}) {
  const defaults = {
    question_id: 'PHY_KIN_001',
    selected_answer: 'A',
    is_correct: true,
    time_spent_seconds: 45
  };

  return { ...defaults, ...overrides };
}

/**
 * Create quiz submission (full response set)
 *
 * @param {number} totalQuestions - Total questions in quiz
 * @param {number} correctCount - Number of correct answers
 * @param {Object} overrides - Custom fields
 * @returns {Object} Quiz submission
 */
function createQuizSubmission(totalQuestions = 5, correctCount = 4, overrides = {}) {
  const responses = Array.from({ length: totalQuestions }, (_, index) => {
    return createQuizResponse({
      question_id: `Q_${index + 1}`,
      selected_answer: index < correctCount ? 'A' : 'B', // First N correct
      is_correct: index < correctCount,
      time_spent_seconds: 30 + Math.floor(Math.random() * 60)
    });
  });

  const defaults = {
    user_id: 'test-user-001',
    quiz_id: `quiz_${Date.now()}`,
    responses,
    total_time_seconds: responses.reduce((sum, r) => sum + r.time_spent_seconds, 0),
    completed_at: new Date().toISOString()
  };

  return { ...defaults, ...overrides };
}

/**
 * Create perfect quiz submission (all correct)
 *
 * @param {number} totalQuestions - Total questions
 * @param {Object} overrides - Custom fields
 * @returns {Object} Perfect quiz submission
 */
function createPerfectQuizSubmission(totalQuestions = 5, overrides = {}) {
  return createQuizSubmission(totalQuestions, totalQuestions, overrides);
}

/**
 * Create failed quiz submission (all incorrect)
 *
 * @param {number} totalQuestions - Total questions
 * @param {Object} overrides - Custom fields
 * @returns {Object} Failed quiz submission
 */
function createFailedQuizSubmission(totalQuestions = 5, overrides = {}) {
  return createQuizSubmission(totalQuestions, 0, overrides);
}

/**
 * Create invalid quiz submission (missing required fields)
 *
 * @param {string} missingField - Which field to omit
 * @returns {Object} Invalid quiz submission
 */
function createInvalidQuizSubmission(missingField = 'user_id') {
  const valid = createQuizSubmission();
  delete valid[missingField];
  return valid;
}

/**
 * Create daily quiz history entry
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Daily quiz history entry
 */
function createDailyQuizHistory(overrides = {}) {
  const defaults = {
    quiz_id: `daily_quiz_${Date.now()}`,
    user_id: 'test-user-001',
    completed_at: new Date().toISOString(),
    score: 4,
    total_questions: 5,
    accuracy: 80.0,
    time_taken_seconds: 300,
    theta_before: 0.0,
    theta_after: 0.1,
    theta_change: 0.1,
    questions_breakdown: {
      physics: { correct: 2, total: 2 },
      chemistry: { correct: 1, total: 2 },
      mathematics: { correct: 1, total: 1 }
    }
  };

  return { ...defaults, ...overrides };
}

/**
 * Create chapter practice session
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Chapter practice session
 */
function createChapterPracticeSession(overrides = {}) {
  const defaults = {
    session_id: `practice_${Date.now()}`,
    user_id: 'test-user-001',
    chapter_key: 'physics_kinematics',
    chapter_name: 'Kinematics',
    subject: 'Physics',
    status: 'in_progress',
    questions: [],
    total_questions: 5,
    questions_answered: 0,
    started_at: new Date().toISOString(),
    tier_limit: 5
  };

  return { ...defaults, ...overrides };
}

/**
 * Create completed chapter practice session
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Completed chapter practice session
 */
function createCompletedChapterPracticeSession(overrides = {}) {
  return createChapterPracticeSession({
    status: 'completed',
    questions_answered: 5,
    completed_at: new Date().toISOString(),
    score: 4,
    accuracy: 80.0,
    theta_change: 0.15,
    ...overrides
  });
}

module.exports = {
  createQuizSession,
  createCompletedQuizSession,
  createQuizResponse,
  createQuizSubmission,
  createPerfectQuizSubmission,
  createFailedQuizSubmission,
  createInvalidQuizSubmission,
  createDailyQuizHistory,
  createChapterPracticeSession,
  createCompletedChapterPracticeSession
};
