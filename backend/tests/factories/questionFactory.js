/**
 * Question Factory
 *
 * Creates test question data with proper IRT parameters.
 */

/**
 * Create question with default values
 *
 * @param {Object} overrides - Custom fields to override defaults
 * @returns {Object} Question object
 */
function createQuestion(overrides = {}) {
  const defaults = {
    question_id: `TEST_Q_${Date.now()}`,
    subject: 'Physics',
    chapter: 'Kinematics',
    chapter_key: 'physics_kinematics',
    question_type: 'mcq_single',
    difficulty: 'medium',
    question_text: 'Sample test question?',
    question_text_html: '<p>Sample test question?</p>',
    options: [
      { option_id: 'A', text: 'Option A', html: '<p>Option A</p>' },
      { option_id: 'B', text: 'Option B', html: '<p>Option B</p>' },
      { option_id: 'C', text: 'Option C', html: '<p>Option C</p>' },
      { option_id: 'D', text: 'Option D', html: '<p>Option D</p>' }
    ],
    correct_answer: 'A',
    solution_text: 'This is the solution explanation',
    solution_steps: [
      { step_number: 1, description: 'Step 1', formula: 'f = ma' }
    ],
    key_insight: 'Key concept for this question',
    common_mistakes: ['Common mistake 1', 'Common mistake 2'],
    distractor_analysis: {
      B: 'Why B is incorrect',
      C: 'Why C is incorrect',
      D: 'Why D is incorrect'
    },
    irt_parameters: {
      difficulty_b: 0.0,
      discrimination_a: 1.5,
      guessing_c: 0.25
    },
    active: true,
    created_at: new Date().toISOString()
  };

  return { ...defaults, ...overrides };
}

/**
 * Create Physics question
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Physics question
 */
function createPhysicsQuestion(overrides = {}) {
  return createQuestion({
    subject: 'Physics',
    chapter: 'Kinematics',
    chapter_key: 'physics_kinematics',
    ...overrides
  });
}

/**
 * Create Chemistry question
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Chemistry question
 */
function createChemistryQuestion(overrides = {}) {
  return createQuestion({
    subject: 'Chemistry',
    chapter: 'Atomic Structure',
    chapter_key: 'chemistry_atomic_structure',
    ...overrides
  });
}

/**
 * Create Mathematics question
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Mathematics question
 */
function createMathematicsQuestion(overrides = {}) {
  return createQuestion({
    subject: 'Mathematics',
    chapter: 'Differentiation',
    chapter_key: 'mathematics_differentiation',
    ...overrides
  });
}

/**
 * Create easy question (difficulty_b < -0.3)
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Easy question
 */
function createEasyQuestion(overrides = {}) {
  return createQuestion({
    difficulty: 'easy',
    irt_parameters: {
      difficulty_b: -0.5,
      discrimination_a: 1.2,
      guessing_c: 0.25
    },
    ...overrides
  });
}

/**
 * Create medium question (difficulty_b between -0.3 and 0.3)
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Medium question
 */
function createMediumQuestion(overrides = {}) {
  return createQuestion({
    difficulty: 'medium',
    irt_parameters: {
      difficulty_b: 0.0,
      discrimination_a: 1.5,
      guessing_c: 0.25
    },
    ...overrides
  });
}

/**
 * Create hard question (difficulty_b > 0.3)
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Hard question
 */
function createHardQuestion(overrides = {}) {
  return createQuestion({
    difficulty: 'hard',
    irt_parameters: {
      difficulty_b: 0.8,
      discrimination_a: 1.8,
      guessing_c: 0.25
    },
    ...overrides
  });
}

/**
 * Create numerical question (no options)
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Numerical question
 */
function createNumericalQuestion(overrides = {}) {
  return createQuestion({
    question_type: 'numerical',
    options: [],
    correct_answer: '42.50',
    ...overrides
  });
}

/**
 * Create question with specific IRT parameters
 *
 * @param {number} difficulty_b - Difficulty parameter (-3 to 3)
 * @param {number} discrimination_a - Discrimination parameter (0.5 to 2.5)
 * @param {number} guessing_c - Guessing parameter (0 to 0.5)
 * @param {Object} overrides - Custom fields
 * @returns {Object} Question with specific IRT params
 */
function createQuestionWithIRT(difficulty_b, discrimination_a, guessing_c = 0.25, overrides = {}) {
  return createQuestion({
    irt_parameters: {
      difficulty_b,
      discrimination_a,
      guessing_c
    },
    ...overrides
  });
}

/**
 * Create multiple questions at once
 *
 * @param {number} count - Number of questions to create
 * @param {Object} template - Template to use for all questions
 * @returns {Array<Object>} Array of questions
 */
function createMultipleQuestions(count, template = {}) {
  return Array.from({ length: count }, (_, index) => {
    return createQuestion({
      question_id: `TEST_Q_${Date.now()}_${index}`,
      ...template
    });
  });
}

/**
 * Create assessment question (with broad_chapter field)
 *
 * @param {Object} overrides - Custom fields
 * @returns {Object} Assessment question
 */
function createAssessmentQuestion(overrides = {}) {
  return createQuestion({
    broad_chapter: 'Mechanics',
    chapter_key: 'physics_kinematics',
    ...overrides
  });
}

module.exports = {
  createQuestion,
  createPhysicsQuestion,
  createChemistryQuestion,
  createMathematicsQuestion,
  createEasyQuestion,
  createMediumQuestion,
  createHardQuestion,
  createNumericalQuestion,
  createQuestionWithIRT,
  createMultipleQuestions,
  createAssessmentQuestion
};
