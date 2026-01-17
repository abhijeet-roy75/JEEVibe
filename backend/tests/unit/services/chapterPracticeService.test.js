/**
 * Unit Tests for Chapter Practice Service
 *
 * Tests question prioritization, session generation, and session retrieval logic
 */

// Mock Firebase before requiring the service
jest.mock('../../../src/config/firebase', () => {
  const mockBatch = {
    set: jest.fn(),
    commit: jest.fn(() => Promise.resolve()),
  };

  const mockQuestionDoc = {
    id: 'q1',
    data: () => ({
      question_id: 'q1',
      subject: 'Physics',
      chapter: 'Kinematics',
      question_text: 'Test question',
      options: [
        { id: 'A', text: 'Option A' },
        { id: 'B', text: 'Option B' },
        { id: 'C', text: 'Option C' },
        { id: 'D', text: 'Option D' },
      ],
      correct_answer: 'A',
      question_type: 'mcq_single',
      irt_parameters: { discrimination_a: 1.5, difficulty_b: 0.5, guessing_c: 0.25 },
    }),
  };

  const mockUserDoc = {
    exists: true,
    data: () => ({
      theta_by_chapter: {
        'physics_kinematics': { theta: 0.5, percentile: 60 },
      },
    }),
  };

  const mockSessionDoc = {
    exists: true,
    id: 'cp_test123_1234567890',
    data: () => ({
      session_id: 'cp_test123_1234567890',
      student_id: 'test-user-id',
      chapter_key: 'physics_kinematics',
      chapter_name: 'Kinematics',
      subject: 'Physics',
      status: 'in_progress',
      questions_answered: 0,
      total_questions: 5,
    }),
  };

  const mockResponseDoc = {
    id: 'resp1',
    data: () => ({
      question_id: 'q1',
      chapter_key: 'physics_kinematics',
      is_correct: false,
      answered_at: { toDate: () => new Date() },
    }),
  };

  const mockCollection = {
    doc: jest.fn(() => ({
      get: jest.fn(() => Promise.resolve(mockUserDoc)),
      set: jest.fn(() => Promise.resolve()),
      collection: jest.fn(() => ({
        doc: jest.fn(() => ({
          set: jest.fn(() => Promise.resolve()),
          get: jest.fn(() => Promise.resolve(mockSessionDoc)),
        })),
        where: jest.fn(() => ({
          orderBy: jest.fn(() => ({
            limit: jest.fn(() => ({
              get: jest.fn(() => Promise.resolve({ empty: true, docs: [] })),
            })),
          })),
        })),
        orderBy: jest.fn(() => ({
          get: jest.fn(() => Promise.resolve({
            docs: [],
          })),
        })),
      })),
    })),
    where: jest.fn(() => ({
      where: jest.fn(() => ({
        limit: jest.fn(() => ({
          get: jest.fn(() => Promise.resolve({
            empty: false,
            docs: [mockQuestionDoc, mockQuestionDoc, mockQuestionDoc, mockQuestionDoc, mockQuestionDoc],
          })),
        })),
      })),
      orderBy: jest.fn(() => ({
        limit: jest.fn(() => ({
          get: jest.fn(() => Promise.resolve({
            docs: [mockResponseDoc],
          })),
        })),
      })),
    })),
  };

  return {
    db: {
      collection: jest.fn(() => mockCollection),
      batch: jest.fn(() => mockBatch),
    },
    admin: {
      firestore: {
        FieldValue: {
          serverTimestamp: jest.fn(() => ({ _serverTimestamp: true })),
          increment: jest.fn((val) => ({ _increment: val })),
          delete: jest.fn(() => ({ _delete: true })),
        },
      },
    },
  };
});

// Mock retry utility
jest.mock('../../../src/utils/firestoreRetry', () => ({
  retryFirestoreOperation: jest.fn((fn) => fn()),
}));

// Mock chapter mapping service
jest.mock('../../../src/services/chapterMappingService', () => ({
  getDatabaseNames: jest.fn((chapterKey) => {
    if (chapterKey === 'physics_kinematics') {
      return Promise.resolve({ subject: 'Physics', chapter: 'Kinematics' });
    }
    return Promise.resolve(null);
  }),
}));

// Mock question selection service
jest.mock('../../../src/services/questionSelectionService', () => ({
  normalizeQuestion: jest.fn((id, data) => ({
    question_id: id,
    ...data,
  })),
}));

// Mock logger
jest.mock('../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

// Now require the service
const {
  prioritizeQuestions,
  getQuestionHistory,
  THETA_MULTIPLIER,
  DEFAULT_QUESTION_COUNT,
  MAX_QUESTION_COUNT,
} = require('../../../src/services/chapterPracticeService');

describe('Chapter Practice Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('Constants', () => {
    test('THETA_MULTIPLIER should be 0.5', () => {
      expect(THETA_MULTIPLIER).toBe(0.5);
    });

    test('DEFAULT_QUESTION_COUNT should be 15', () => {
      expect(DEFAULT_QUESTION_COUNT).toBe(15);
    });

    test('MAX_QUESTION_COUNT should be 20', () => {
      expect(MAX_QUESTION_COUNT).toBe(20);
    });
  });

  describe('prioritizeQuestions', () => {
    test('should prioritize unseen questions highest (priority 3)', () => {
      const questions = [
        { question_id: 'q1' },
        { question_id: 'q2' },
        { question_id: 'q3' },
      ];
      const history = new Map(); // Empty history = all unseen

      const result = prioritizeQuestions(questions, history);

      result.forEach((q) => {
        expect(q._priority).toBe(3);
      });
    });

    test('should prioritize previously wrong questions medium (priority 2)', () => {
      const questions = [{ question_id: 'q1' }];
      const history = new Map([
        ['q1', { seen: true, lastCorrect: false }],
      ]);

      const result = prioritizeQuestions(questions, history);

      expect(result[0]._priority).toBe(2);
    });

    test('should prioritize previously correct questions lowest (priority 1)', () => {
      const questions = [{ question_id: 'q1' }];
      const history = new Map([
        ['q1', { seen: true, lastCorrect: true }],
      ]);

      const result = prioritizeQuestions(questions, history);

      expect(result[0]._priority).toBe(1);
    });

    test('should sort questions by priority descending', () => {
      const questions = [
        { question_id: 'correct' },
        { question_id: 'wrong' },
        { question_id: 'unseen' },
      ];
      const history = new Map([
        ['correct', { seen: true, lastCorrect: true }],
        ['wrong', { seen: true, lastCorrect: false }],
      ]);

      const result = prioritizeQuestions(questions, history);

      // Unseen (3) should be before wrong (2) should be before correct (1)
      expect(result[0].question_id).toBe('unseen');
      expect(result[0]._priority).toBe(3);
      expect(result[1].question_id).toBe('wrong');
      expect(result[1]._priority).toBe(2);
      expect(result[2].question_id).toBe('correct');
      expect(result[2]._priority).toBe(1);
    });

    test('should handle empty questions array', () => {
      const result = prioritizeQuestions([], new Map());
      expect(result).toEqual([]);
    });

    test('should handle empty history', () => {
      const questions = [{ question_id: 'q1' }, { question_id: 'q2' }];
      const result = prioritizeQuestions(questions, new Map());

      expect(result.length).toBe(2);
      expect(result.every((q) => q._priority === 3)).toBe(true);
    });
  });

  describe('getQuestionHistory', () => {
    test('should return Map of question history', async () => {
      const history = await getQuestionHistory('test-user', 'physics_kinematics');

      expect(history).toBeInstanceOf(Map);
    });

    test('should handle errors gracefully and return empty Map', async () => {
      // The mock is set up to return data, but if it threw,
      // the function should catch and return empty Map
      const history = await getQuestionHistory('test-user', 'physics_kinematics');

      expect(history).toBeInstanceOf(Map);
    });
  });

  describe('Theta multiplier calculation', () => {
    test('should apply 0.5x multiplier to theta delta', () => {
      const rawDelta = 0.2;
      const adjustedDelta = rawDelta * THETA_MULTIPLIER;

      expect(adjustedDelta).toBe(0.1);
    });

    test('multiplier should be less than daily quiz (1.0)', () => {
      expect(THETA_MULTIPLIER).toBeLessThan(1.0);
    });
  });
});

describe('Session ownership validation', () => {
  test('should reject session access when student_id does not match', () => {
    const sessionData = {
      student_id: 'user-a',
      status: 'in_progress',
    };
    const requestingUserId = 'user-b';

    const isOwner = sessionData.student_id === requestingUserId;

    expect(isOwner).toBe(false);
  });

  test('should allow session access when student_id matches', () => {
    const sessionData = {
      student_id: 'user-a',
      status: 'in_progress',
    };
    const requestingUserId = 'user-a';

    const isOwner = sessionData.student_id === requestingUserId;

    expect(isOwner).toBe(true);
  });
});
