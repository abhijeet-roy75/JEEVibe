/**
 * Mock Test Factory
 *
 * Creates test data for JEE Main mock tests (90 questions, 3 hours, 300 marks).
 */

/**
 * Create mock test template
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Mock test template
 */
function createMockTestTemplate(overrides = {}) {
  const defaults = {
    template_id: `mock_template_${Date.now()}`,
    template_name: 'JEE Main Mock Test',
    duration_seconds: 10800, // 3 hours
    total_questions: 90,
    subjects: {
      physics: {
        total_questions: 30,
        mcq_single: 20,
        numerical: 10,
        question_ids: Array.from({ length: 30 }, (_, i) => `PHY_${i + 1}`)
      },
      chemistry: {
        total_questions: 30,
        mcq_single: 20,
        numerical: 10,
        question_ids: Array.from({ length: 30 }, (_, i) => `CHEM_${i + 1}`)
      },
      mathematics: {
        total_questions: 30,
        mcq_single: 20,
        numerical: 10,
        question_ids: Array.from({ length: 30 }, (_, i) => `MATH_${i + 1}`)
      }
    },
    marking_scheme: {
      mcq_single_correct: 4,
      mcq_single_incorrect: -1,
      mcq_single_unattempted: 0,
      numerical_correct: 4,
      numerical_incorrect: -1,
      numerical_unattempted: 0
    },
    maximum_marks: 300,
    passing_marks: 90,
    recommended_attempts: 75,
    active: true,
    created_at: new Date().toISOString()
  };

  return { ...defaults, ...overrides };
}

/**
 * Create mock test session
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Mock test session
 */
function createMockTestSession(overrides = {}) {
  const defaults = {
    session_id: `mock_session_${Date.now()}`,
    user_id: 'test-user-001',
    template_id: 'mock_template_001',
    status: 'in_progress',
    started_at: new Date().toISOString(),
    expires_at: new Date(Date.now() + 10800 * 1000).toISOString(), // 3 hours
    time_remaining_seconds: 10800,
    total_questions: 90,
    questions_attempted: 0,
    questions_answered: 0,
    questions_marked_for_review: 0,
    current_subject: 'physics',
    current_question_index: 0,
    question_states: {}
  };

  // Initialize question states (Not Visited)
  for (let i = 1; i <= 90; i++) {
    defaults.question_states[`Q_${i}`] = 'not_visited';
  }

  return { ...defaults, ...overrides };
}

/**
 * Create question state object for mock test
 *
 * @param {string} state - 'not_visited', 'not_answered', 'answered', 'marked_for_review', 'answered_and_marked'
 * @param {string} selectedAnswer - Selected answer (optional)
 * @returns {Object} Question state
 */
function createQuestionState(state = 'not_visited', selectedAnswer = null) {
  return {
    state,
    selected_answer: selectedAnswer,
    visited_at: state !== 'not_visited' ? new Date().toISOString() : null,
    answered_at: ['answered', 'answered_and_marked'].includes(state) ? new Date().toISOString() : null
  };
}

/**
 * Create mock test response (single question)
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Mock test response
 */
function createMockTestResponse(overrides = {}) {
  const defaults = {
    question_id: 'PHY_001',
    question_type: 'mcq_single',
    selected_answer: 'A',
    is_correct: true,
    marks_awarded: 4,
    time_spent_seconds: 120
  };

  return { ...defaults, ...overrides };
}

/**
 * Create mock test submission (full 90 questions)
 *
 * @param {number} correctCount - Number of correct answers
 * @param {number} incorrectCount - Number of incorrect answers
 * @param {Object} overrides - Custom fields
 * @returns {Object} Mock test submission
 */
function createMockTestSubmission(correctCount = 60, incorrectCount = 15, overrides = {}) {
  const unattempted = 90 - correctCount - incorrectCount;

  // Create responses
  const responses = [];
  let questionIndex = 0;

  // Correct answers
  for (let i = 0; i < correctCount; i++) {
    responses.push(createMockTestResponse({
      question_id: `Q_${++questionIndex}`,
      is_correct: true,
      marks_awarded: 4
    }));
  }

  // Incorrect answers
  for (let i = 0; i < incorrectCount; i++) {
    responses.push(createMockTestResponse({
      question_id: `Q_${++questionIndex}`,
      is_correct: false,
      marks_awarded: -1
    }));
  }

  // Unattempted (no response objects for these)

  const totalMarks = (correctCount * 4) + (incorrectCount * -1);
  const accuracy = correctCount / (correctCount + incorrectCount) * 100;

  const defaults = {
    session_id: `mock_session_${Date.now()}`,
    user_id: 'test-user-001',
    template_id: 'mock_template_001',
    responses,
    total_questions: 90,
    questions_attempted: correctCount + incorrectCount,
    questions_answered: correctCount + incorrectCount,
    questions_unattempted: unattempted,
    correct_answers: correctCount,
    incorrect_answers: incorrectCount,
    total_marks: totalMarks,
    maximum_marks: 300,
    percentage: (totalMarks / 300) * 100,
    accuracy: accuracy,
    time_taken_seconds: 9000, // 2.5 hours
    completed_at: new Date().toISOString(),
    subject_breakdown: {
      physics: {
        attempted: Math.floor((correctCount + incorrectCount) / 3),
        correct: Math.floor(correctCount / 3),
        incorrect: Math.floor(incorrectCount / 3),
        marks: Math.floor(totalMarks / 3)
      },
      chemistry: {
        attempted: Math.floor((correctCount + incorrectCount) / 3),
        correct: Math.floor(correctCount / 3),
        incorrect: Math.floor(incorrectCount / 3),
        marks: Math.floor(totalMarks / 3)
      },
      mathematics: {
        attempted: Math.floor((correctCount + incorrectCount) / 3),
        correct: Math.floor(correctCount / 3),
        incorrect: Math.floor(incorrectCount / 3),
        marks: Math.floor(totalMarks / 3)
      }
    }
  };

  return { ...defaults, ...overrides };
}

/**
 * Create excellent mock test submission (75 correct, 10 incorrect, 5 unattempted)
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Excellent mock test submission
 */
function createExcellentMockTestSubmission(overrides = {}) {
  return createMockTestSubmission(75, 10, overrides);
}

/**
 * Create average mock test submission (50 correct, 20 incorrect, 20 unattempted)
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Average mock test submission
 */
function createAverageMockTestSubmission(overrides = {}) {
  return createMockTestSubmission(50, 20, overrides);
}

/**
 * Create poor mock test submission (30 correct, 30 incorrect, 30 unattempted)
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Poor mock test submission
 */
function createPoorMockTestSubmission(overrides = {}) {
  return createMockTestSubmission(30, 30, overrides);
}

/**
 * Create mock test result
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Mock test result
 */
function createMockTestResult(overrides = {}) {
  const defaults = {
    session_id: `mock_session_${Date.now()}`,
    user_id: 'test-user-001',
    template_id: 'mock_template_001',
    template_name: 'JEE Main Mock Test',
    total_marks: 240,
    maximum_marks: 300,
    percentage: 80.0,
    accuracy: 85.7,
    rank: null,
    percentile: null,
    total_questions: 90,
    attempted: 70,
    correct: 60,
    incorrect: 10,
    unattempted: 20,
    time_taken_seconds: 9000,
    completed_at: new Date().toISOString(),
    subject_breakdown: {
      physics: { attempted: 23, correct: 20, incorrect: 3, marks: 74 },
      chemistry: { attempted: 24, correct: 20, incorrect: 4, marks: 76 },
      mathematics: { attempted: 23, correct: 20, incorrect: 3, marks: 74 }
    }
  };

  return { ...defaults, ...overrides };
}

module.exports = {
  createMockTestTemplate,
  createMockTestSession,
  createQuestionState,
  createMockTestResponse,
  createMockTestSubmission,
  createExcellentMockTestSubmission,
  createAverageMockTestSubmission,
  createPoorMockTestSubmission,
  createMockTestResult
};
