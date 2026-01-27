/**
 * AI Tutor Context Service Test Suite
 * Tests for building context objects from solutions, quizzes, and analytics
 */

// Create mock functions for Firestore
const mockGet = jest.fn();
const mockQuestionsGet = jest.fn();

// Mock Firebase before requiring the service
jest.mock('../../../../src/config/firebase', () => {
  // Create a chainable mock for nested collections with all Firestore methods
  const createChainableMock = (getMock) => ({
    get: getMock,
    where: jest.fn(() => createChainableMock(getMock)),
    orderBy: jest.fn(() => createChainableMock(getMock)),
    limit: jest.fn(() => createChainableMock(getMock)),
    select: jest.fn(() => createChainableMock(getMock))
  });

  const createDocMock = (getMock) => ({
    get: getMock,
    collection: jest.fn(() => ({
      doc: jest.fn(() => createDocMock(getMock)),
      ...createChainableMock(mockQuestionsGet)
    }))
  });

  return {
    db: {
      collection: jest.fn(() => ({
        doc: jest.fn(() => createDocMock(mockGet))
      }))
    },
    admin: {
      firestore: {
        FieldValue: {
          serverTimestamp: jest.fn()
        }
      }
    }
  };
});

jest.mock('../../../../src/utils/firestoreRetry', () => ({
  retryFirestoreOperation: jest.fn((fn) => fn())
}));

jest.mock('../../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  debug: jest.fn()
}));

// Mock analyticsService
jest.mock('../../../../src/services/analyticsService', () => ({
  calculateFocusAreas: jest.fn(() => Promise.resolve([
    { chapter_name: 'Kinematics', chapter_key: 'physics_kinematics', subject_name: 'Physics', percentile: 30, reason: 'low_performance' }
  ])),
  getMasteryStatus: jest.fn((percentile) => percentile >= 70 ? 'mastered' : percentile >= 50 ? 'learning' : 'needs_work'),
  getSubjectDisplayName: jest.fn((subject) => subject.charAt(0).toUpperCase() + subject.slice(1)),
  getChapterDisplayNameAsync: jest.fn()
}));

const logger = require('../../../../src/utils/logger');

const {
  buildSolutionContext,
  buildQuizContext,
  buildAnalyticsContext,
  buildGeneralContext,
  buildContext,
  getStudentProfile
} = require('../../../../src/services/aiTutorContextService');

describe('AI Tutor Context Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('buildSolutionContext', () => {
    const mockSnapData = {
      recognizedQuestion: 'A ball is thrown vertically upward with velocity 20 m/s. Find maximum height.',
      subject: 'physics',
      topic: 'Kinematics',
      difficulty: 'medium',
      solution: {
        approach: 'Using kinematic equations',
        steps: ['Step 1: Identify given values', 'Step 2: Apply v² = u² + 2as'],
        finalAnswer: 'Maximum height = 20 m',
        priyaMaamTip: 'Remember to take g as negative when going up!'
      },
      conceptsTested: ['kinematics', 'projectile motion'],
      imageUrl: 'https://storage.example.com/snap.jpg'
    };

    test('should build context from valid snap document', async () => {
      mockGet.mockResolvedValue({
        exists: true,
        data: () => mockSnapData
      });

      const context = await buildSolutionContext('snap123', 'user123');

      expect(context).not.toBeNull();
      expect(context.type).toBe('solution');
      expect(context.contextId).toBe('snap123');
      expect(context.snapshot.question).toBe(mockSnapData.recognizedQuestion);
      expect(context.snapshot.approach).toBe(mockSnapData.solution.approach);
      expect(context.snapshot.steps).toEqual(mockSnapData.solution.steps);
      expect(context.snapshot.finalAnswer).toBe(mockSnapData.solution.finalAnswer);
      // Note: imageUrl is intentionally not included in context (removed for storage optimization)
    });

    test('should return null if snap document does not exist', async () => {
      mockGet.mockResolvedValue({
        exists: false
      });

      const context = await buildSolutionContext('nonexistent', 'user123');

      expect(context).toBeNull();
      expect(logger.warn).toHaveBeenCalledWith(
        'Solution not found for context',
        expect.objectContaining({ solutionId: 'nonexistent' })
      );
    });

    test('should handle missing optional fields gracefully', async () => {
      const partialSnapData = {
        recognizedQuestion: 'What is 2+2?',
        subject: 'maths'
        // Missing: topic, solution, conceptsTested, imageUrl
      };

      mockGet.mockResolvedValue({
        exists: true,
        data: () => partialSnapData
      });

      const context = await buildSolutionContext('snap456', 'user123');

      expect(context).not.toBeNull();
      expect(context.snapshot.question).toBe(partialSnapData.recognizedQuestion);
      expect(context.snapshot.approach).toBe('');
      expect(context.snapshot.steps).toEqual([]);
      // Note: imageUrl is intentionally not included in context
    });

    test('should use question field if recognizedQuestion is missing', async () => {
      const snapDataWithQuestion = {
        question: 'Alternative question field',
        subject: 'chemistry'
      };

      mockGet.mockResolvedValue({
        exists: true,
        data: () => snapDataWithQuestion
      });

      const context = await buildSolutionContext('snap789', 'user123');

      expect(context.snapshot.question).toBe(snapDataWithQuestion.question);
    });
  });

  describe('buildQuizContext', () => {
    const mockQuizData = {
      completed_at: { toDate: () => new Date('2024-01-15T10:00:00Z') }
    };

    const mockQuestions = [
      { position: 1, is_correct: true, subject: 'physics', chapter: 'kinematics' },
      { position: 2, is_correct: false, subject: 'physics', chapter: 'kinematics', question_text: 'Q2', student_answer: 'A', correct_answer: 'B' },
      { position: 3, is_correct: true, subject: 'chemistry', chapter: 'organic' },
      { position: 4, is_correct: false, subject: 'chemistry', chapter: 'organic', question_text: 'Q4', student_answer: 'C', correct_answer: 'D' },
      { position: 5, is_correct: true, subject: 'maths', chapter: 'calculus' }
    ];

    test('should build context from quiz with questions', async () => {
      mockGet.mockResolvedValue({
        exists: true,
        data: () => mockQuizData
      });

      // Mock returns incorrect questions for first call, all for second
      const incorrectQuestions = mockQuestions.filter(q => !q.is_correct);
      mockQuestionsGet
        .mockResolvedValueOnce({
          docs: incorrectQuestions.map(q => ({
            data: () => q
          }))
        })
        .mockResolvedValueOnce({
          docs: mockQuestions.map(q => ({
            data: () => q
          }))
        });

      const context = await buildQuizContext('quiz123', 'user123');

      expect(context).not.toBeNull();
      expect(context.type).toBe('quiz');
      expect(context.snapshot.score).toBe(3); // 3 correct
      expect(context.snapshot.total).toBe(5); // 5 total
      expect(context.snapshot.accuracy).toBe(60); // 60%
      expect(context.snapshot.incorrectQuestions).toHaveLength(2);
    });

    test('should return null if quiz does not exist', async () => {
      mockGet.mockResolvedValue({
        exists: false
      });

      const context = await buildQuizContext('nonexistent', 'user123');

      expect(context).toBeNull();
    });
  });

  describe('buildAnalyticsContext', () => {
    const mockUserData = {
      overall_percentile: 75,
      overall_theta: 1.5,
      theta_by_chapter: {
        physics_kinematics: { percentile: 80, attempts: 10 },
        physics_thermodynamics: { percentile: 45, attempts: 5 }
      },
      theta_by_subject: {
        physics: { percentile: 70 },
        chemistry: { percentile: 60 },
        maths: { percentile: 80 }
      },
      completed_quiz_count: 25,
      streak: 7
    };

    test('should build analytics context with user data', async () => {
      mockGet.mockResolvedValue({
        exists: true,
        data: () => mockUserData
      });

      const context = await buildAnalyticsContext('user123');

      expect(context).not.toBeNull();
      expect(context.type).toBe('analytics');
      expect(context.snapshot.overallPercentile).toBe(75);
      expect(context.snapshot.overallTheta).toBe(1.5);
      expect(context.snapshot.totalQuizzes).toBe(25);
      expect(context.snapshot.streak).toBe(7);
      expect(context.snapshot.subjectPerformance).toHaveLength(3);
    });

    test('should return null if user does not exist', async () => {
      mockGet.mockResolvedValue({
        exists: false
      });

      const context = await buildAnalyticsContext('nonexistent');

      expect(context).toBeNull();
    });
  });

  describe('buildGeneralContext', () => {
    test('should build general context with basic user info', async () => {
      const mockUserData = {
        overall_percentile: 65,
        streak: 3,
        completed_quiz_count: 10
      };

      mockGet.mockResolvedValue({
        exists: true,
        data: () => mockUserData
      });

      const context = await buildGeneralContext('user123');

      expect(context).not.toBeNull();
      expect(context.type).toBe('general');
      expect(context.snapshot.overallPercentile).toBe(65);
      expect(context.snapshot.streak).toBe(3);
    });

    test('should return minimal context if user does not exist', async () => {
      mockGet.mockResolvedValue({
        exists: false
      });

      const context = await buildGeneralContext('nonexistent');

      expect(context).not.toBeNull();
      expect(context.type).toBe('general');
      expect(context.snapshot).toBeNull();
    });
  });

  describe('buildContext', () => {
    test('should route to buildSolutionContext for solution type', async () => {
      mockGet.mockResolvedValue({
        exists: true,
        data: () => ({ recognizedQuestion: 'Test', subject: 'physics' })
      });

      const context = await buildContext('solution', 'snap123', 'user123');

      expect(context.type).toBe('solution');
    });

    test('should throw error if contextId missing for solution type', async () => {
      await expect(buildContext('solution', null, 'user123'))
        .rejects.toThrow('contextId required for solution context');
    });

    test('should throw error if contextId missing for quiz type', async () => {
      await expect(buildContext('quiz', null, 'user123'))
        .rejects.toThrow('contextId required for quiz context');
    });

    test('should default to general context for unknown types', async () => {
      mockGet.mockResolvedValue({
        exists: true,
        data: () => ({ overall_percentile: 50 })
      });

      const context = await buildContext('unknown', null, 'user123');

      expect(context.type).toBe('general');
    });
  });

  describe('getStudentProfile', () => {
    test('should build student profile with strengths and weaknesses', async () => {
      const mockUserData = {
        firstName: 'Rahul',
        overall_theta: 1.2,
        overall_percentile: 70,
        theta_by_chapter: {
          physics_kinematics: { percentile: 85, attempts: 10 },
          physics_thermodynamics: { percentile: 35, attempts: 5 },
          chemistry_organic: { percentile: 75, attempts: 8 }
        },
        theta_by_subject: {
          physics: { percentile: 70 },
          chemistry: { percentile: 65 }
        },
        streak: 5,
        completed_quiz_count: 20
      };

      mockGet.mockResolvedValue({
        exists: true,
        data: () => mockUserData
      });

      const profile = await getStudentProfile('user123');

      expect(profile).not.toBeNull();
      expect(profile.firstName).toBe('Rahul');
      expect(profile.overallTheta).toBe(1.2);
      expect(profile.overallPercentile).toBe(70);
      expect(profile.streak).toBe(5);
      expect(profile.totalQuizzes).toBe(20);
      // Strengths should include chapters with percentile >= 70
      expect(profile.strengths.length).toBeGreaterThanOrEqual(1);
      // Weaknesses should include chapters with percentile < 50 and attempts > 0
      expect(profile.weaknesses.length).toBeGreaterThanOrEqual(1);
    });

    test('should return null if user does not exist', async () => {
      mockGet.mockResolvedValue({
        exists: false
      });

      const profile = await getStudentProfile('nonexistent');

      expect(profile).toBeNull();
    });
  });
});
