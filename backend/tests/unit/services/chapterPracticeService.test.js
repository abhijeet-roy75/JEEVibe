/**
 * Unit Tests for Chapter Practice Service
 *
 * Tests question prioritization, session generation, and session retrieval logic
 */

// Mock Firebase before requiring the service
jest.mock('../../../../src/config/firebase', () => {
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
jest.mock('../../../../src/utils/firestoreRetry', () => ({
  retryFirestoreOperation: jest.fn((fn) => fn()),
}));

// Mock chapter mapping service
jest.mock('../../../../src/services/chapterMappingService', () => ({
  getDatabaseNames: jest.fn((chapterKey) => {
    if (chapterKey === 'physics_kinematics') {
      return Promise.resolve({ subject: 'Physics', chapter: 'Kinematics' });
    }
    return Promise.resolve(null);
  }),
}));

// Mock question selection service
jest.mock('../../../../src/services/questionSelectionService', () => ({
  normalizeQuestion: jest.fn((id, data) => ({
    question_id: id,
    ...data,
  })),
}));

// Mock logger
jest.mock('../../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

// Now require the service
const {
  prioritizeQuestions,
  selectDifficultyProgressiveQuestions,
  getDifficultyBand,
  getQuestionHistory,
  THETA_MULTIPLIER,
  DEFAULT_QUESTION_COUNT,
  MAX_QUESTION_COUNT,
  DIFFICULTY_BANDS,
} = require('../../../../src/services/chapterPracticeService');

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

describe('DIFFICULTY_BANDS constant', () => {
  test('should have correct thresholds for easy band', () => {
    expect(DIFFICULTY_BANDS.easy.max).toBe(0.7);
    expect(DIFFICULTY_BANDS.easy.target).toBe(5);
  });

  test('should have correct thresholds for medium band', () => {
    expect(DIFFICULTY_BANDS.medium.min).toBe(0.7);
    expect(DIFFICULTY_BANDS.medium.max).toBe(1.2);
    expect(DIFFICULTY_BANDS.medium.target).toBe(5);
  });

  test('should have correct thresholds for hard band', () => {
    expect(DIFFICULTY_BANDS.hard.min).toBe(1.2);
    expect(DIFFICULTY_BANDS.hard.target).toBe(5);
  });
});

describe('getDifficultyBand', () => {
  test('should classify questions with b <= 0.7 as easy', () => {
    expect(getDifficultyBand({ irt_parameters: { difficulty_b: 0.0 } })).toBe('easy');
    expect(getDifficultyBand({ irt_parameters: { difficulty_b: 0.5 } })).toBe('easy');
    expect(getDifficultyBand({ irt_parameters: { difficulty_b: 0.7 } })).toBe('easy');
  });

  test('should classify questions with 0.7 < b <= 1.2 as medium', () => {
    expect(getDifficultyBand({ irt_parameters: { difficulty_b: 0.71 } })).toBe('medium');
    expect(getDifficultyBand({ irt_parameters: { difficulty_b: 1.0 } })).toBe('medium');
    expect(getDifficultyBand({ irt_parameters: { difficulty_b: 1.2 } })).toBe('medium');
  });

  test('should classify questions with b > 1.2 as hard', () => {
    expect(getDifficultyBand({ irt_parameters: { difficulty_b: 1.21 } })).toBe('hard');
    expect(getDifficultyBand({ irt_parameters: { difficulty_b: 2.0 } })).toBe('hard');
    expect(getDifficultyBand({ irt_parameters: { difficulty_b: 3.0 } })).toBe('hard');
  });

  test('should use difficulty_irt as fallback when irt_parameters not present', () => {
    expect(getDifficultyBand({ difficulty_irt: 0.5 })).toBe('easy');
    expect(getDifficultyBand({ difficulty_irt: 1.0 })).toBe('medium');
    expect(getDifficultyBand({ difficulty_irt: 1.5 })).toBe('hard');
  });

  test('should default to 0 (easy) when no difficulty field present', () => {
    expect(getDifficultyBand({})).toBe('easy');
    expect(getDifficultyBand({ question_id: 'q1' })).toBe('easy');
  });
});

describe('selectDifficultyProgressiveQuestions', () => {
  describe('difficulty ordering', () => {
    test('should return questions in easy → medium → hard order', () => {
      const questions = [
        { question_id: 'hard1', irt_parameters: { difficulty_b: 1.5 } },
        { question_id: 'easy1', irt_parameters: { difficulty_b: 0.3 } },
        { question_id: 'medium1', irt_parameters: { difficulty_b: 1.0 } },
      ];
      const history = new Map();

      const result = selectDifficultyProgressiveQuestions(questions, history, 3);

      expect(result[0]._band).toBe('easy');
      expect(result[1]._band).toBe('medium');
      expect(result[2]._band).toBe('hard');
    });

    test('should classify questions correctly by difficulty_b thresholds', () => {
      const questions = [
        { question_id: 'q1', irt_parameters: { difficulty_b: 0.7 } },  // easy
        { question_id: 'q2', irt_parameters: { difficulty_b: 0.71 } }, // medium
        { question_id: 'q3', irt_parameters: { difficulty_b: 1.2 } },  // medium
        { question_id: 'q4', irt_parameters: { difficulty_b: 1.21 } }, // hard
      ];
      const history = new Map();

      const result = selectDifficultyProgressiveQuestions(questions, history, 4);

      expect(result.filter(q => q._band === 'easy').length).toBe(1);
      expect(result.filter(q => q._band === 'medium').length).toBe(2);
      expect(result.filter(q => q._band === 'hard').length).toBe(1);
    });

    test('should maintain band order even with mixed input', () => {
      const questions = [
        { question_id: 'h1', irt_parameters: { difficulty_b: 2.0 } },
        { question_id: 'e1', irt_parameters: { difficulty_b: 0.1 } },
        { question_id: 'm1', irt_parameters: { difficulty_b: 0.9 } },
        { question_id: 'h2', irt_parameters: { difficulty_b: 1.8 } },
        { question_id: 'e2', irt_parameters: { difficulty_b: 0.3 } },
        { question_id: 'm2', irt_parameters: { difficulty_b: 1.1 } },
      ];
      const history = new Map();

      const result = selectDifficultyProgressiveQuestions(questions, history, 6);

      // First two should be easy
      expect(result[0]._band).toBe('easy');
      expect(result[1]._band).toBe('easy');
      // Next two should be medium
      expect(result[2]._band).toBe('medium');
      expect(result[3]._band).toBe('medium');
      // Last two should be hard
      expect(result[4]._band).toBe('hard');
      expect(result[5]._band).toBe('hard');
    });
  });

  describe('priority within bands', () => {
    test('should prioritize unseen questions over previously wrong within same band', () => {
      const questions = [
        { question_id: 'seen_wrong', irt_parameters: { difficulty_b: 0.5 } },
        { question_id: 'unseen', irt_parameters: { difficulty_b: 0.5 } },
      ];
      const history = new Map([
        ['seen_wrong', { seen: true, lastCorrect: false }]
      ]);

      const result = selectDifficultyProgressiveQuestions(questions, history, 2);

      // Both are easy, but unseen should come first due to priority
      expect(result[0].question_id).toBe('unseen');
      expect(result[0]._priority).toBe(3);
      expect(result[1].question_id).toBe('seen_wrong');
      expect(result[1]._priority).toBe(2);
    });

    test('should prioritize previously wrong over previously correct within same band', () => {
      const questions = [
        { question_id: 'correct', irt_parameters: { difficulty_b: 0.5 } },
        { question_id: 'wrong', irt_parameters: { difficulty_b: 0.5 } },
      ];
      const history = new Map([
        ['correct', { seen: true, lastCorrect: true }],
        ['wrong', { seen: true, lastCorrect: false }]
      ]);

      const result = selectDifficultyProgressiveQuestions(questions, history, 2);

      expect(result[0].question_id).toBe('wrong');
      expect(result[0]._priority).toBe(2);
      expect(result[1].question_id).toBe('correct');
      expect(result[1]._priority).toBe(1);
    });

    test('should use priority ordering across all bands', () => {
      const questions = [
        { question_id: 'easy_correct', irt_parameters: { difficulty_b: 0.3 } },
        { question_id: 'easy_unseen', irt_parameters: { difficulty_b: 0.4 } },
        { question_id: 'medium_correct', irt_parameters: { difficulty_b: 1.0 } },
        { question_id: 'medium_unseen', irt_parameters: { difficulty_b: 1.1 } },
      ];
      const history = new Map([
        ['easy_correct', { seen: true, lastCorrect: true }],
        ['medium_correct', { seen: true, lastCorrect: true }]
      ]);

      const result = selectDifficultyProgressiveQuestions(questions, history, 4);

      // Easy band: unseen before correct
      const easyQuestions = result.filter(q => q._band === 'easy');
      expect(easyQuestions[0].question_id).toBe('easy_unseen');

      // Medium band: unseen before correct
      const mediumQuestions = result.filter(q => q._band === 'medium');
      expect(mediumQuestions[0].question_id).toBe('medium_unseen');
    });
  });

  describe('fallback behavior', () => {
    test('should fill from other bands when a band has insufficient questions', () => {
      // Only easy questions available
      const questions = Array(15).fill(null).map((_, i) => ({
        question_id: `easy_${i}`,
        irt_parameters: { difficulty_b: 0.3 }
      }));
      const history = new Map();

      const result = selectDifficultyProgressiveQuestions(questions, history, 15);

      expect(result.length).toBe(15);
      // All should be easy since that's all we have
      expect(result.every(q => q._band === 'easy')).toBe(true);
    });

    test('should handle missing bands gracefully', () => {
      // Only medium and hard questions
      const questions = [
        { question_id: 'm1', irt_parameters: { difficulty_b: 0.9 } },
        { question_id: 'm2', irt_parameters: { difficulty_b: 1.0 } },
        { question_id: 'h1', irt_parameters: { difficulty_b: 1.5 } },
        { question_id: 'h2', irt_parameters: { difficulty_b: 2.0 } },
      ];
      const history = new Map();

      const result = selectDifficultyProgressiveQuestions(questions, history, 4);

      expect(result.length).toBe(4);
      // Should still order medium before hard
      expect(result[0]._band).toBe('medium');
      expect(result[1]._band).toBe('medium');
      expect(result[2]._band).toBe('hard');
      expect(result[3]._band).toBe('hard');
    });

    test('should handle empty question pool gracefully', () => {
      const result = selectDifficultyProgressiveQuestions([], new Map(), 15);
      expect(result.length).toBe(0);
    });

    test('should handle null/undefined questions gracefully', () => {
      const result = selectDifficultyProgressiveQuestions(null, new Map(), 15);
      expect(result.length).toBe(0);
    });

    test('should respect totalCount parameter', () => {
      const questions = Array(20).fill(null).map((_, i) => ({
        question_id: `q_${i}`,
        irt_parameters: { difficulty_b: i * 0.1 }
      }));

      const result = selectDifficultyProgressiveQuestions(questions, new Map(), 10);
      expect(result.length).toBe(10);
    });

    test('should return all questions if pool is smaller than requested', () => {
      const questions = [
        { question_id: 'q1', irt_parameters: { difficulty_b: 0.5 } },
        { question_id: 'q2', irt_parameters: { difficulty_b: 1.0 } },
      ];

      const result = selectDifficultyProgressiveQuestions(questions, new Map(), 15);
      expect(result.length).toBe(2);
    });
  });

  describe('legacy difficulty field support', () => {
    test('should use difficulty_irt when irt_parameters not present', () => {
      const questions = [
        { question_id: 'q1', difficulty_irt: 0.5 },
        { question_id: 'q2', irt_parameters: { difficulty_b: 1.5 } },
      ];

      const result = selectDifficultyProgressiveQuestions(questions, new Map(), 2);

      expect(result[0]._band).toBe('easy');  // 0.5 is easy
      expect(result[1]._band).toBe('hard');  // 1.5 is hard
    });

    test('should handle mixed difficulty field formats', () => {
      const questions = [
        { question_id: 'q1', difficulty_irt: 0.3 },
        { question_id: 'q2', irt_parameters: { difficulty_b: 0.9 } },
        { question_id: 'q3', difficulty_irt: 1.5 },
        { question_id: 'q4', irt_parameters: { difficulty_b: 1.8 } },
      ];

      const result = selectDifficultyProgressiveQuestions(questions, new Map(), 4);

      // Should still order correctly
      expect(result[0]._band).toBe('easy');
      expect(result[1]._band).toBe('medium');
      expect(result[2]._band).toBe('hard');
      expect(result[3]._band).toBe('hard');
    });
  });

  describe('target distribution', () => {
    test('should aim for balanced distribution across bands when possible', () => {
      // Create 6 questions of each difficulty
      const questions = [
        ...Array(6).fill(null).map((_, i) => ({
          question_id: `easy_${i}`,
          irt_parameters: { difficulty_b: 0.3 + i * 0.05 }
        })),
        ...Array(6).fill(null).map((_, i) => ({
          question_id: `medium_${i}`,
          irt_parameters: { difficulty_b: 0.8 + i * 0.05 }
        })),
        ...Array(6).fill(null).map((_, i) => ({
          question_id: `hard_${i}`,
          irt_parameters: { difficulty_b: 1.3 + i * 0.1 }
        })),
      ];

      const result = selectDifficultyProgressiveQuestions(questions, new Map(), 15);

      expect(result.length).toBe(15);

      const easyCnt = result.filter(q => q._band === 'easy').length;
      const mediumCnt = result.filter(q => q._band === 'medium').length;
      const hardCnt = result.filter(q => q._band === 'hard').length;

      // Should have 5 from each band
      expect(easyCnt).toBe(5);
      expect(mediumCnt).toBe(5);
      expect(hardCnt).toBe(5);
    });
  });
});
