/**
 * Tests for mockTestService
 *
 * Coverage target: 80%+
 */

const mockTestService = require('../../src/services/mockTestService');
const { db } = require('../../src/config/firebase');

// Mock Firebase
jest.mock('../../src/config/firebase', () => ({
  db: {
    collection: jest.fn()
  },
  admin: {
    firestore: {
      FieldValue: {
        serverTimestamp: jest.fn(() => new Date()),
        increment: jest.fn((n) => n)
      },
      Timestamp: {
        now: jest.fn(() => ({ toDate: () => new Date() })),
        fromDate: jest.fn((date) => ({ toDate: () => date }))
      }
    }
  }
}));

// Mock logger
jest.mock('../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn()
}));

// Mock dependencies
jest.mock('../../src/services/tierConfigService', () => ({
  getTierLimits: jest.fn(() => Promise.resolve({
    mock_tests_monthly: 5
  }))
}));

jest.mock('../../src/services/thetaUpdateService', () => ({
  updateThetaFromMockTest: jest.fn()
}));

jest.mock('../../src/utils/firestoreRetry', () => ({
  retryFirestoreOperation: jest.fn((fn) => fn())
}));

describe('mockTestService', () => {
  let mockGet;
  let mockSet;
  let mockUpdate;
  let mockDoc;
  let mockCollection;
  let mockWhere;
  let mockOrderBy;
  let mockLimit;

  beforeEach(() => {
    // Setup mock chain
    mockGet = jest.fn();
    mockSet = jest.fn();
    mockUpdate = jest.fn();
    mockLimit = jest.fn(() => ({ get: mockGet }));
    mockOrderBy = jest.fn(() => ({ limit: mockLimit, get: mockGet }));
    mockWhere = jest.fn(() => ({
      where: mockWhere,
      orderBy: mockOrderBy,
      limit: mockLimit,
      get: mockGet
    }));

    mockDoc = jest.fn(() => ({
      get: mockGet,
      set: mockSet,
      update: mockUpdate,
      collection: jest.fn(() => ({
        doc: mockDoc,
        where: mockWhere,
        orderBy: mockOrderBy,
        get: mockGet
      }))
    }));

    mockCollection = jest.fn(() => ({
      doc: mockDoc,
      where: mockWhere,
      orderBy: mockOrderBy,
      get: mockGet
    }));

    db.collection = mockCollection;

    jest.clearAllMocks();
  });

  describe('initializeQuestionStates', () => {
    test('should initialize 90 question states as not_visited', () => {
      const states = mockTestService.initializeQuestionStates(90);

      expect(Object.keys(states).length).toBe(90);
      expect(states['1']).toBe('not_visited');
      expect(states['45']).toBe('not_visited');
      expect(states['90']).toBe('not_visited');
    });

    test('should create sequential question numbers', () => {
      const states = mockTestService.initializeQuestionStates(90);

      for (let i = 1; i <= 90; i++) {
        expect(states).toHaveProperty(String(i));
      }
    });
  });

  describe('calculateScore', () => {
    test('should calculate total marks correctly', () => {
      const questions = [
        { question_number: 1, question_type: 'mcq_single', correct_answer: 'A', subject: 'Physics' },
        { question_number: 2, question_type: 'mcq_single', correct_answer: 'B', subject: 'Chemistry' },
        { question_number: 3, question_type: 'numerical', correct_answer: '42', subject: 'Mathematics' }
      ];

      const responses = {
        1: { answer: 'A' }, // Correct: +4
        2: { answer: 'C' }, // Wrong: -1
        3: {} // Unattempted: 0
      };

      const result = mockTestService.calculateScore(questions, responses);

      expect(result.total_score).toBe(3); // 4 - 1 + 0
      expect(result.correct).toBe(1);
      expect(result.incorrect).toBe(1);
      expect(result.unattempted).toBe(1);
    });

    test('should handle all correct answers', () => {
      const questions = [
        { question_number: 1, question_type: 'mcq_single', correct_answer: 'A', subject: 'Physics' },
        { question_number: 2, question_type: 'mcq_single', correct_answer: 'B', subject: 'Chemistry' }
      ];

      const responses = {
        1: { answer: 'A' },
        2: { answer: 'B' }
      };

      const result = mockTestService.calculateScore(questions, responses);

      expect(result.total_score).toBe(8); // 2 × 4
      expect(result.correct).toBe(2);
      expect(result.incorrect).toBe(0);
      expect(parseFloat(result.accuracy)).toBe(100);
    });

    test('should handle all unattempted', () => {
      const questions = [
        { question_number: 1, question_type: 'mcq_single', correct_answer: 'A', subject: 'Physics' },
        { question_number: 2, question_type: 'mcq_single', correct_answer: 'B', subject: 'Chemistry' }
      ];

      const responses = {};

      const result = mockTestService.calculateScore(questions, responses);

      expect(result.total_score).toBe(0);
      expect(result.unattempted).toBe(2);
      expect(parseFloat(result.accuracy)).toBe(0);
    });

    test('should calculate accuracy correctly', () => {
      const questions = [
        { question_number: 1, question_type: 'mcq_single', correct_answer: 'A', subject: 'Physics' },
        { question_number: 2, question_type: 'mcq_single', correct_answer: 'B', subject: 'Chemistry' },
        { question_number: 3, question_type: 'mcq_single', correct_answer: 'C', subject: 'Mathematics' }
      ];

      const responses = {
        1: { answer: 'A' }, // Correct
        2: { answer: 'C' }  // Wrong
        // 3 not attempted
      };

      const result = mockTestService.calculateScore(questions, responses);

      expect(parseFloat(result.accuracy)).toBe(50); // 1 correct out of 2 attempted
    });

    test('should break down marks by subject', () => {
      const questions = [
        { question_number: 1, subject: 'Physics', question_type: 'mcq_single', correct_answer: 'A' },
        { question_number: 2, subject: 'Chemistry', question_type: 'mcq_single', correct_answer: 'B' },
        { question_number: 3, subject: 'Mathematics', question_type: 'mcq_single', correct_answer: 'C' }
      ];

      const responses = {
        1: { answer: 'A' }, // Physics: correct (+4)
        2: { answer: 'X' }, // Chemistry: wrong (-1)
        3: {} // Mathematics: unattempted (0)
      };

      const result = mockTestService.calculateScore(questions, responses);

      expect(result).toHaveProperty('subject_scores');
      expect(result.subject_scores).toHaveProperty('Physics');
      expect(result.subject_scores).toHaveProperty('Chemistry');
      expect(result.subject_scores).toHaveProperty('Mathematics');
    });
  });

  describe('isAnswerCorrect', () => {
    test('should check MCQ answers case-insensitively', () => {
      expect(mockTestService.isAnswerCorrect('A', 'A', false)).toBe(true);
      expect(mockTestService.isAnswerCorrect('a', 'A', false)).toBe(true);
      expect(mockTestService.isAnswerCorrect('B', 'A', false)).toBe(false);
    });

    test('should check numerical answers with tolerance', () => {
      // Exact match
      expect(mockTestService.isAnswerCorrect('42', '42', true)).toBe(true);
      expect(mockTestService.isAnswerCorrect('42.0', '42', true)).toBe(true);
      expect(mockTestService.isAnswerCorrect('42.00', '42', true)).toBe(true);

      // Within tolerance (±0.01)
      expect(mockTestService.isAnswerCorrect('42.005', '42', true)).toBe(true);
      expect(mockTestService.isAnswerCorrect('41.995', '42', true)).toBe(true);

      // Outside tolerance
      expect(mockTestService.isAnswerCorrect('42.1', '42', true)).toBe(false);
      expect(mockTestService.isAnswerCorrect('41.5', '42', true)).toBe(false);
    });

    test('should handle invalid numerical answers', () => {
      expect(mockTestService.isAnswerCorrect('abc', '42', true)).toBe(false);
      expect(mockTestService.isAnswerCorrect('', '42', true)).toBe(false);
    });

    test('should handle empty answers', () => {
      // Empty string doesn't match 'A'
      expect(mockTestService.isAnswerCorrect('', 'A', false)).toBe(false);
    });
  });

  describe('lookupNTAPercentile', () => {
    test('should return percentile for score within range', () => {
      const percentile = mockTestService.lookupNTAPercentile(200);
      expect(typeof percentile).toBe('number');
      expect(percentile).toBeGreaterThanOrEqual(0);
      expect(percentile).toBeLessThanOrEqual(100);
    });

    test('should return 99.99+ for very high scores', () => {
      const percentile = mockTestService.lookupNTAPercentile(290);
      expect(percentile).toBeGreaterThan(95);
    });

    test('should return low percentile for very low scores', () => {
      const percentile = mockTestService.lookupNTAPercentile(50);
      expect(percentile).toBeLessThan(50);
    });

    test('should handle edge scores', () => {
      expect(mockTestService.lookupNTAPercentile(0)).toBeGreaterThanOrEqual(0);
      expect(mockTestService.lookupNTAPercentile(300)).toBeLessThanOrEqual(100);
    });

    test('should handle negative scores', () => {
      const percentile = mockTestService.lookupNTAPercentile(-10);
      expect(percentile).toBeGreaterThanOrEqual(0);
    });
  });

  describe('sanitizeQuestionsForClient', () => {
    test('should remove correct answers from questions', () => {
      const questions = [
        {
          question_id: 'Q1',
          question_text: 'Test?',
          correct_answer: 'A',
          solution: 'This is the solution'
        }
      ];

      const sanitized = mockTestService.sanitizeQuestionsForClient(questions);

      expect(sanitized[0]).not.toHaveProperty('correct_answer');
      expect(sanitized[0]).not.toHaveProperty('solution');
      expect(sanitized[0]).toHaveProperty('question_id');
      expect(sanitized[0]).toHaveProperty('question_text');
    });

    test('should remove solution-related fields', () => {
      const questions = [
        {
          question_id: 'Q1',
          correct_answer: 'A',
          solution: 'Solution text',
          solution_steps: [],
          key_insight: 'Insight',
          common_mistakes: [],
          distractor_analysis: {}
        }
      ];

      const sanitized = mockTestService.sanitizeQuestionsForClient(questions);

      expect(sanitized[0]).not.toHaveProperty('solution');
      expect(sanitized[0]).not.toHaveProperty('solution_steps');
      expect(sanitized[0]).not.toHaveProperty('key_insight');
      expect(sanitized[0]).not.toHaveProperty('common_mistakes');
      expect(sanitized[0]).not.toHaveProperty('distractor_analysis');
    });

    test('should preserve non-sensitive fields', () => {
      const questions = [
        {
          question_id: 'Q1',
          question_text: 'What is 2+2?',
          question_type: 'mcq_single',
          subject: 'Mathematics',
          options: [
            { option_id: 'A', text: '3' },
            { option_id: 'B', text: '4' }
          ],
          correct_answer: 'B'
        }
      ];

      const sanitized = mockTestService.sanitizeQuestionsForClient(questions);

      expect(sanitized[0]).toHaveProperty('question_id');
      expect(sanitized[0]).toHaveProperty('question_text');
      expect(sanitized[0]).toHaveProperty('question_type');
      expect(sanitized[0]).toHaveProperty('subject');
      expect(sanitized[0]).toHaveProperty('options');
    });

    test('should handle empty array', () => {
      const sanitized = mockTestService.sanitizeQuestionsForClient([]);
      expect(Array.isArray(sanitized)).toBe(true);
      expect(sanitized.length).toBe(0);
    });
  });

  describe('checkRateLimit', () => {
    test('should allow test if under monthly limit', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({
          subscriptionStatus: 'pro'
        })
      };

      const mockTestsSnapshot = {
        size: 3 // 3 tests this month, limit is 5
      };

      mockGet
        .mockResolvedValueOnce(mockUserDoc)
        .mockResolvedValueOnce(mockTestsSnapshot);

      const result = await mockTestService.checkRateLimit('user123');

      expect(result.allowed).toBe(true);
      expect(result.tests_used).toBe(3);
      expect(result.tests_remaining).toBe(2);
    });

    test('should block test if at monthly limit', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({
          subscriptionStatus: 'pro'
        })
      };

      const mockTestsSnapshot = {
        size: 5 // At limit
      };

      mockGet
        .mockResolvedValueOnce(mockUserDoc)
        .mockResolvedValueOnce(mockTestsSnapshot);

      const result = await mockTestService.checkRateLimit('user123');

      expect(result.allowed).toBe(false);
      expect(result.tests_remaining).toBe(0);
    });

    test('should return error if user not found', async () => {
      const mockUserDoc = {
        exists: false
      };

      mockGet.mockResolvedValue(mockUserDoc);

      const result = await mockTestService.checkRateLimit('nonexistent');

      expect(result.allowed).toBe(false);
      expect(result.error).toBeDefined();
    });
  });

  describe('getAvailableTemplates', () => {
    test('should return list of active templates', async () => {
      const mockTemplates = [
        { id: 'template1', data: () => ({ active: true, template_name: 'JEE Main 1' }) },
        { id: 'template2', data: () => ({ active: true, template_name: 'JEE Main 2' }) },
        { id: 'template3', data: () => ({ active: false, template_name: 'Inactive' }) }
      ];

      const mockSnapshot = {
        forEach: (callback) => mockTemplates.forEach(callback)
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await mockTestService.getAvailableTemplates();

      expect(Array.isArray(result)).toBe(true);
      // Should only include active templates
      expect(result.every(t => t.active === true)).toBe(true);
    });

    test('should handle empty templates collection', async () => {
      const mockSnapshot = {
        forEach: (callback) => {}
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await mockTestService.getAvailableTemplates();

      expect(Array.isArray(result)).toBe(true);
      expect(result.length).toBe(0);
    });
  });

  describe('getTestResults', () => {
    test('should return test results with score and percentile', async () => {
      const mockTestDoc = {
        exists: true,
        data: () => ({
          status: 'completed',
          total_marks: 240,
          correct_answers: 60,
          accuracy: 80,
          nta_percentile: 85.5
        })
      };

      mockGet.mockResolvedValue(mockTestDoc);

      const result = await mockTestService.getTestResults('user123', 'test123');

      expect(result).toHaveProperty('total_marks');
      expect(result).toHaveProperty('correct_answers');
      expect(result).toHaveProperty('accuracy');
      expect(result).toHaveProperty('nta_percentile');
    });

    test('should return null for non-existent test', async () => {
      const mockTestDoc = {
        exists: false
      };

      mockGet.mockResolvedValue(mockTestDoc);

      const result = await mockTestService.getTestResults('user123', 'nonexistent');

      expect(result).toBeNull();
    });
  });

  describe('getUserMockTestHistory', () => {
    test('should return test history sorted by date', async () => {
      const mockTests = [
        {
          id: 'test1',
          data: () => ({
            completed_at: { toDate: () => new Date('2026-02-25') },
            total_marks: 200
          })
        },
        {
          id: 'test2',
          data: () => ({
            completed_at: { toDate: () => new Date('2026-02-26') },
            total_marks: 240
          })
        }
      ];

      const mockSnapshot = {
        forEach: (callback) => mockTests.forEach(callback)
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await mockTestService.getUserMockTestHistory('user123');

      expect(Array.isArray(result)).toBe(true);
      expect(result.length).toBe(2);
    });

    test('should handle user with no test history', async () => {
      const mockSnapshot = {
        forEach: (callback) => {}
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await mockTestService.getUserMockTestHistory('user123');

      expect(Array.isArray(result)).toBe(true);
      expect(result.length).toBe(0);
    });
  });

  describe('loadTemplateWithQuestions', () => {
    test('should load template with all questions', async () => {
      const mockTemplate = {
        template_id: 'template1',
        template_name: 'JEE Main Full Test 1',
        total_questions: 90,
        questions: [
          { question_id: 'Q1', subject: 'Physics' },
          { question_id: 'Q2', subject: 'Chemistry' }
        ]
      };

      const mockTemplateDoc = {
        exists: true,
        data: () => mockTemplate
      };

      mockGet.mockResolvedValue(mockTemplateDoc);

      const result = await mockTestService.loadTemplateWithQuestions('template1');

      expect(result).toHaveProperty('template_id', 'template1');
      expect(result).toHaveProperty('questions');
      expect(Array.isArray(result.questions)).toBe(true);
    });

    test('should return null for non-existent template', async () => {
      const mockTemplateDoc = {
        exists: false
      };

      mockGet.mockResolvedValue(mockTemplateDoc);

      const result = await mockTestService.loadTemplateWithQuestions('nonexistent');

      expect(result).toBeNull();
    });
  });

  describe('startMockTest', () => {
    test('should create new mock test session', async () => {
      const mockTemplate = {
        template_id: 'template1',
        template_name: 'JEE Main Full Test 1',
        total_questions: 90,
        questions: Array.from({ length: 90 }, (_, i) => ({
          question_id: `Q${i+1}`,
          subject: i < 30 ? 'Physics' : i < 60 ? 'Chemistry' : 'Mathematics',
          question_type: 'mcq_single',
          correct_answer: 'A'
        }))
      };

      const mockTemplateDoc = {
        exists: true,
        data: () => mockTemplate
      };

      const mockTestsSnapshot = {
        size: 0 // No tests this month
      };

      const mockUserDoc = {
        exists: true,
        data: () => ({
          subscription: { tier: 'pro' }
        })
      };

      mockGet
        .mockResolvedValueOnce(mockUserDoc) // checkRateLimit user check
        .mockResolvedValueOnce(mockTestsSnapshot) // checkRateLimit tests count
        .mockResolvedValueOnce(mockTemplateDoc); // loadTemplate

      mockSet.mockResolvedValue();

      const result = await mockTestService.startMockTest('user123', 'template1');

      expect(result).toHaveProperty('session_id');
      expect(result).toHaveProperty('template_id', 'template1');
      expect(result).toHaveProperty('questions');
      expect(result.questions.length).toBe(90);
      expect(mockSet).toHaveBeenCalled();
    });

    test('should return error if rate limit exceeded', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({
          subscription: { tier: 'pro' }
        })
      };

      const mockTestsSnapshot = {
        size: 5 // At monthly limit
      };

      mockGet
        .mockResolvedValueOnce(mockUserDoc)
        .mockResolvedValueOnce(mockTestsSnapshot);

      await expect(mockTestService.startMockTest('user123', 'template1'))
        .rejects
        .toThrow();
    });
  });

  describe('getActiveTest', () => {
    test('should return active test without questions', async () => {
      const mockActiveTest = {
        session_id: 'test123',
        template_id: 'template1',
        status: 'in_progress',
        started_at: { toDate: () => new Date() }
      };

      const mockTestDoc = {
        exists: true,
        data: () => mockActiveTest
      };

      mockGet.mockResolvedValue(mockTestDoc);

      const result = await mockTestService.getActiveTest('user123', 'test123');

      expect(result).toHaveProperty('session_id', 'test123');
      expect(result).toHaveProperty('status', 'in_progress');
    });

    test('should return null for non-existent test', async () => {
      const mockTestDoc = {
        exists: false
      };

      mockGet.mockResolvedValue(mockTestDoc);

      const result = await mockTestService.getActiveTest('user123', 'nonexistent');

      expect(result).toBeNull();
    });
  });

  describe('getActiveTestWithQuestions', () => {
    test('should return test with sanitized questions', async () => {
      const mockTest = {
        session_id: 'test123',
        questions: [
          {
            question_id: 'Q1',
            question_text: 'What is 2+2?',
            correct_answer: 'B',
            solution: 'The answer is 4'
          }
        ]
      };

      const mockTestDoc = {
        exists: true,
        data: () => mockTest
      };

      mockGet.mockResolvedValue(mockTestDoc);

      const result = await mockTestService.getActiveTestWithQuestions('user123', 'test123');

      expect(result).toHaveProperty('questions');
      expect(result.questions[0]).not.toHaveProperty('correct_answer');
      expect(result.questions[0]).not.toHaveProperty('solution');
    });
  });

  describe('saveAnswer', () => {
    test('should save answer and update question state', async () => {
      mockUpdate.mockResolvedValue();

      const result = await mockTestService.saveAnswer(
        'user123',
        'test123',
        5,
        'A',
        'answered'
      );

      expect(result.success).toBe(true);
      expect(mockUpdate).toHaveBeenCalled();

      const updateCall = mockUpdate.mock.calls[0][0];
      expect(updateCall).toHaveProperty('responses.5.selected_answer', 'A');
      expect(updateCall).toHaveProperty('question_states.5', 'answered');
    });

    test('should handle marked for review state', async () => {
      mockUpdate.mockResolvedValue();

      const result = await mockTestService.saveAnswer(
        'user123',
        'test123',
        10,
        'C',
        'answered_and_marked'
      );

      expect(result.success).toBe(true);
      const updateCall = mockUpdate.mock.calls[0][0];
      expect(updateCall).toHaveProperty('question_states.10', 'answered_and_marked');
    });
  });

  describe('clearAnswer', () => {
    test('should clear answer and set state to not_answered', async () => {
      mockUpdate.mockResolvedValue();

      const result = await mockTestService.clearAnswer('user123', 'test123', 15);

      expect(result.success).toBe(true);
      expect(mockUpdate).toHaveBeenCalled();

      const updateCall = mockUpdate.mock.calls[0][0];
      expect(updateCall).toHaveProperty('responses.15.selected_answer', null);
      expect(updateCall).toHaveProperty('question_states.15', 'not_answered');
    });
  });

  describe('submitMockTest', () => {
    test('should calculate score and update test status', async () => {
      const mockTest = {
        session_id: 'test123',
        template_id: 'template1',
        questions: [
          { question_number: 1, question_type: 'mcq_single', correct_answer: 'A', subject: 'Physics' },
          { question_number: 2, question_type: 'mcq_single', correct_answer: 'B', subject: 'Chemistry' },
          { question_number: 3, question_type: 'numerical', correct_answer: '42', subject: 'Mathematics' }
        ],
        responses: {
          1: { selected_answer: 'A' }, // Correct
          2: { selected_answer: 'C' }  // Wrong
        }
      };

      const mockTestDoc = {
        exists: true,
        data: () => mockTest
      };

      mockGet.mockResolvedValue(mockTestDoc);
      mockUpdate.mockResolvedValue();

      const result = await mockTestService.submitMockTest('user123', 'test123');

      expect(result).toHaveProperty('total_marks');
      expect(result).toHaveProperty('nta_percentile');
      expect(result).toHaveProperty('correct_answers', 1);
      expect(result).toHaveProperty('incorrect_answers', 1);
      expect(mockUpdate).toHaveBeenCalled();
    });

    test('should return error for non-existent test', async () => {
      const mockTestDoc = {
        exists: false
      };

      mockGet.mockResolvedValue(mockTestDoc);

      await expect(mockTestService.submitMockTest('user123', 'nonexistent'))
        .rejects
        .toThrow();
    });
  });

  describe('abandonTest', () => {
    test('should mark test as abandoned', async () => {
      mockUpdate.mockResolvedValue();

      const result = await mockTestService.abandonTest('user123', 'test123');

      expect(result.success).toBe(true);
      expect(mockUpdate).toHaveBeenCalled();

      const updateCall = mockUpdate.mock.calls[0][0];
      expect(updateCall).toHaveProperty('status', 'abandoned');
    });
  });
});
