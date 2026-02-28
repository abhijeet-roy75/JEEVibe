/**
 * Tests for adminMetricsService
 *
 * Coverage target: 80%+
 *
 * Note: This service makes heavy Firestore queries. Tests focus on logic,
 * data transformation, and edge cases. Integration tests cover end-to-end flows.
 */

const adminMetricsService = require('../../src/services/adminMetricsService');
const { db } = require('../../src/config/firebase');
const { getTodayIST, getYesterdayIST, formatDateIST } = require('../../src/utils/dateUtils');

// Mock Firebase
jest.mock('../../src/config/firebase', () => ({
  db: {
    collection: jest.fn()
  }
}));

// Mock logger
jest.mock('../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn()
}));

// Mock date utils
jest.mock('../../src/utils/dateUtils', () => ({
  getTodayIST: jest.fn(() => '2026-02-27'),
  getYesterdayIST: jest.fn(() => '2026-02-26'),
  formatDateIST: jest.fn((date) => {
    if (!date) return '2026-02-27';
    const d = new Date(date);
    return d.toISOString().split('T')[0];
  }),
  toIST: jest.fn((date) => date)
}));

describe('adminMetricsService', () => {
  let mockGet;
  let mockDoc;
  let mockCollection;
  let mockWhere;
  let mockOrderBy;
  let mockLimit;

  beforeEach(() => {
    // Setup mock chain
    mockGet = jest.fn();
    mockLimit = jest.fn(() => ({ get: mockGet }));
    mockOrderBy = jest.fn(() => ({ limit: mockLimit, get: mockGet }));
    mockWhere = jest.fn(() => ({
      where: mockWhere,
      orderBy: mockOrderBy,
      get: mockGet
    }));

    mockDoc = jest.fn(() => ({
      get: mockGet,
      collection: jest.fn(() => ({
        where: mockWhere,
        orderBy: mockOrderBy,
        limit: mockLimit,
        get: mockGet
      }))
    }));

    mockCollection = jest.fn(() => ({
      doc: mockDoc,
      where: mockWhere,
      get: mockGet
    }));

    db.collection = mockCollection;

    jest.clearAllMocks();
  });

  describe('getDailyHealth', () => {
    test('should calculate DAU from users with lastActive today', async () => {
      const todayDate = new Date('2026-02-27T10:00:00+05:30');
      const yesterdayDate = new Date('2026-02-26T10:00:00+05:30');

      const mockUsers = [
        { uid: 'user1', lastActive: { toDate: () => todayDate }, createdAt: { toDate: () => yesterdayDate } },
        { uid: 'user2', lastActive: { toDate: () => todayDate }, createdAt: { toDate: () => yesterdayDate } },
        { uid: 'user3', lastActive: { toDate: () => yesterdayDate }, createdAt: { toDate: () => yesterdayDate } }
      ];

      const mockSnapshot = {
        forEach: (callback) => mockUsers.forEach((user, i) => callback({ id: user.uid, data: () => user }))
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await adminMetricsService.getDailyHealth();

      expect(result).toHaveProperty('dau');
      expect(result).toHaveProperty('dauChange');
      expect(result).toHaveProperty('newSignups');
      expect(result).toHaveProperty('totalUsers');
      expect(result).toHaveProperty('generatedAt');
      expect(result.totalUsers).toBe(3);
    });

    test('should handle users without lastActive gracefully', async () => {
      const mockUsers = [
        { uid: 'user1' }, // No lastActive
        { uid: 'user2', lastActive: null },
        { uid: 'user3', lastActive: { toDate: () => new Date() } }
      ];

      const mockSnapshot = {
        forEach: (callback) => mockUsers.forEach((user) => callback({ id: user.uid, data: () => user }))
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await adminMetricsService.getDailyHealth();

      expect(result.totalUsers).toBe(3);
      expect(result).toHaveProperty('dau');
      expect(result).toHaveProperty('atRiskUsers');
    });

    test('should count new signups created today', async () => {
      const todayDate = new Date('2026-02-27T10:00:00+05:30');
      const yesterdayDate = new Date('2026-02-26T10:00:00+05:30');

      const mockUsers = [
        { uid: 'user1', createdAt: { toDate: () => todayDate } },
        { uid: 'user2', createdAt: { toDate: () => yesterdayDate } }
      ];

      const mockSnapshot = {
        forEach: (callback) => mockUsers.forEach((user) => callback({ id: user.uid, data: () => user }))
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await adminMetricsService.getDailyHealth();

      expect(result).toHaveProperty('newSignups');
    });

    test('should calculate at-risk users (inactive 3+ days)', async () => {
      const today = new Date('2026-02-27T10:00:00+05:30');
      const fourDaysAgo = new Date(today.getTime() - 4 * 24 * 60 * 60 * 1000);
      const fiveDaysAgo = new Date(today.getTime() - 5 * 24 * 60 * 60 * 1000);

      const mockUsers = [
        {
          uid: 'user1',
          lastActive: { toDate: () => fourDaysAgo },
          createdAt: { toDate: () => fiveDaysAgo }
        }
      ];

      const mockSnapshot = {
        forEach: (callback) => mockUsers.forEach((user) => callback({ id: user.uid, data: () => user }))
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await adminMetricsService.getDailyHealth();

      expect(result).toHaveProperty('atRiskUsers');
    });

    test('should include DAU trend for last 7 days', async () => {
      const mockSnapshot = {
        forEach: (callback) => {}
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await adminMetricsService.getDailyHealth();

      expect(result).toHaveProperty('dauTrend');
      expect(Array.isArray(result.dauTrend)).toBe(true);
    });
  });

  describe('getEngagement', () => {
    test('should calculate average quizzes per user', async () => {
      const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

      const mockUsers = [
        { uid: 'user1', lastActive: { toDate: () => new Date() }, completed_quiz_count: 10 },
        { uid: 'user2', lastActive: { toDate: () => new Date() }, completed_quiz_count: 20 },
        { uid: 'user3', lastActive: { toDate: () => sevenDaysAgo }, completed_quiz_count: 30 }
      ];

      const mockSnapshot = {
        forEach: (callback) => mockUsers.forEach((user) => callback({ id: user.uid, data: () => user }))
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await adminMetricsService.getEngagement();

      expect(result).toHaveProperty('avgQuizzesPerUser');
      expect(result).toHaveProperty('activeUsers');
      expect(typeof result.avgQuizzesPerUser).toBe('number');
    });

    test('should handle users without quiz counts', async () => {
      const mockUsers = [
        { uid: 'user1', lastActive: { toDate: () => new Date() } }, // No completed_quiz_count
        { uid: 'user2', lastActive: { toDate: () => new Date() }, completed_quiz_count: 5 }
      ];

      const mockSnapshot = {
        forEach: (callback) => mockUsers.forEach((user) => callback({ id: user.uid, data: () => user }))
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await adminMetricsService.getEngagement();

      expect(result.avgQuizzesPerUser).toBeGreaterThanOrEqual(0);
    });

    test('should calculate average questions per user', async () => {
      const mockUsers = [
        { uid: 'user1', lastActive: { toDate: () => new Date() }, total_questions_solved: 100 },
        { uid: 'user2', lastActive: { toDate: () => new Date() }, total_questions_solved: 200 }
      ];

      const mockSnapshot = {
        forEach: (callback) => mockUsers.forEach((user) => callback({ id: user.uid, data: () => user }))
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await adminMetricsService.getEngagement();

      expect(result).toHaveProperty('avgQuestionsPerUser');
      expect(result.avgQuestionsPerUser).toBeGreaterThan(0);
    });

    test('should include feature usage breakdown', async () => {
      const mockSnapshot = {
        forEach: (callback) => {}
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await adminMetricsService.getEngagement();

      expect(result).toHaveProperty('featureUsage');
      expect(result.featureUsage).toHaveProperty('daily_quiz');
      expect(result.featureUsage).toHaveProperty('snap_solve');
      expect(result.featureUsage).toHaveProperty('ai_tutor');
      expect(result.featureUsage).toHaveProperty('chapter_practice');
    });

    test('should include streak distribution', async () => {
      const mockUsersSnapshot = {
        forEach: (callback) => {}
      };

      // Mock practice_streaks collection
      const mockStreaksSnapshot = {
        forEach: (callback) => {
          [
            { id: 'user1', data: () => ({ current_streak: 5 }) },
            { id: 'user2', data: () => ({ current_streak: 0 }) },
            { id: 'user3', data: () => ({ current_streak: 20 }) }
          ].forEach(callback);
        }
      };

      mockGet
        .mockResolvedValueOnce(mockUsersSnapshot) // users
        .mockResolvedValueOnce(mockStreaksSnapshot); // practice_streaks

      const result = await adminMetricsService.getEngagement();

      expect(result).toHaveProperty('streakDistribution');
      expect(result.streakDistribution).toHaveProperty('0');
      expect(result.streakDistribution).toHaveProperty('1-3');
      expect(result.streakDistribution).toHaveProperty('4-7');
      expect(result.streakDistribution).toHaveProperty('8-14');
      expect(result.streakDistribution).toHaveProperty('15+');
    });
  });

  describe('getLearning', () => {
    test('should calculate mastery progression buckets', async () => {
      const mockUsers = [
        { uid: 'user1', overall_theta: 1.0, overall_percentile: 85 }, // Mastered
        { uid: 'user2', overall_theta: 0.0, overall_percentile: 50 }, // Growing
        { uid: 'user3', overall_theta: -0.5, overall_percentile: 30 }  // Focus
      ];

      const mockSnapshot = {
        forEach: (callback) => mockUsers.forEach((user) => callback({ id: user.uid, data: () => user }))
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await adminMetricsService.getLearning();

      expect(result).toHaveProperty('masteryProgression');
      expect(result.masteryProgression).toHaveProperty('mastered');
      expect(result.masteryProgression).toHaveProperty('growing');
      expect(result.masteryProgression).toHaveProperty('focus');
      expect(result.totalStudentsWithProgress).toBe(3);
    });

    test('should calculate average theta improvement', async () => {
      const mockUsers = [
        {
          uid: 'user1',
          overall_theta: 0.5,
          assessment_baseline: { overall_theta: 0.0 }
        },
        {
          uid: 'user2',
          overall_theta: 0.2,
          assessment_baseline: { overall_theta: -0.2 }
        }
      ];

      const mockSnapshot = {
        forEach: (callback) => mockUsers.forEach((user) => callback({ id: user.uid, data: () => user }))
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await adminMetricsService.getLearning();

      expect(result).toHaveProperty('avgThetaImprovement');
      expect(result.avgThetaImprovement).toBeGreaterThan(0);
    });

    test('should calculate percent of students improving', async () => {
      const mockUsers = [
        {
          uid: 'user1',
          overall_theta: 0.5,
          assessment_baseline: { overall_theta: 0.0 }
        },
        {
          uid: 'user2',
          overall_theta: -0.1,
          assessment_baseline: { overall_theta: 0.0 }
        }
      ];

      const mockSnapshot = {
        forEach: (callback) => mockUsers.forEach((user) => callback({ id: user.uid, data: () => user }))
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await adminMetricsService.getLearning();

      expect(result).toHaveProperty('percentImproving');
      expect(typeof result.percentImproving).toBe('number');
    });

    test('should identify most common focus chapters', async () => {
      const mockUsers = [
        {
          uid: 'user1',
          overall_theta: 0.0,
          theta_by_chapter: {
            'physics_kinematics': { percentile: 30, attempts: 10 },
            'chemistry_organic': { percentile: 50, attempts: 5 }
          }
        },
        {
          uid: 'user2',
          overall_theta: 0.0,
          theta_by_chapter: {
            'physics_kinematics': { percentile: 35, attempts: 8 }
          }
        }
      ];

      const mockSnapshot = {
        forEach: (callback) => mockUsers.forEach((user) => callback({ id: user.uid, data: () => user }))
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await adminMetricsService.getLearning();

      expect(result).toHaveProperty('mostCommonFocusChapters');
      expect(Array.isArray(result.mostCommonFocusChapters)).toBe(true);
    });

    test('should handle users without theta data', async () => {
      const mockUsers = [
        { uid: 'user1' }, // No theta data
        { uid: 'user2', overall_theta: 0.5, overall_percentile: 60 }
      ];

      const mockSnapshot = {
        forEach: (callback) => mockUsers.forEach((user) => callback({ id: user.uid, data: () => user }))
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await adminMetricsService.getLearning();

      expect(result.totalStudentsWithProgress).toBe(1);
    });
  });

  describe('getContent', () => {
    test('should identify low accuracy questions', async () => {
      const mockQuestions = [
        {
          id: 'q1',
          data: () => ({
            times_shown: 100,
            accuracy_rate: 0.15,
            subject: 'Physics',
            chapter: 'Kinematics'
          })
        },
        {
          id: 'q2',
          data: () => ({
            times_shown: 50,
            accuracy_rate: 0.95,
            subject: 'Chemistry',
            chapter: 'Organic'
          })
        },
        {
          id: 'q3',
          data: () => ({
            times_shown: 5, // Not enough data
            accuracy_rate: 0.10
          })
        }
      ];

      const mockSnapshot = {
        forEach: (callback) => mockQuestions.forEach(callback)
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await adminMetricsService.getContent();

      expect(result).toHaveProperty('lowAccuracyQuestions');
      expect(result).toHaveProperty('highAccuracyQuestions');
      expect(Array.isArray(result.lowAccuracyQuestions)).toBe(true);
      expect(Array.isArray(result.highAccuracyQuestions)).toBe(true);
    });

    test('should filter questions with insufficient data (times_shown <= 10)', async () => {
      const mockQuestions = [
        {
          id: 'q1',
          data: () => ({
            times_shown: 5, // Too few
            accuracy_rate: 0.10
          })
        }
      ];

      const mockSnapshot = {
        forEach: (callback) => mockQuestions.forEach(callback)
      };

      mockGet.mockResolvedValue(mockSnapshot);

      const result = await adminMetricsService.getContent();

      // Should not include questions with times_shown <= 10
      expect(result.lowAccuracyQuestions.length).toBe(0);
    });
  });

  describe('getCognitiveMasteryMetrics', () => {
    test('should aggregate weak spot events across all users', async () => {
      const mockEvents = [
        {
          id: 'evt1',
          data: () => ({
            user_id: 'user1',
            node_id: 'node1',
            event_type: 'weak_spot_detected',
            timestamp: { toDate: () => new Date() }
          })
        },
        {
          id: 'evt2',
          data: () => ({
            user_id: 'user1',
            node_id: 'node1',
            event_type: 'capsule_opened',
            timestamp: { toDate: () => new Date() }
          })
        }
      ];

      const mockSnapshot = {
        forEach: (callback) => mockEvents.forEach(callback)
      };

      // Mock atlas_nodes collection
      const mockNodesSnapshot = {
        forEach: (callback) => {
          [{
            id: 'node1',
            data: () => ({ title: 'Test Node', severity_level: 'high' })
          }].forEach(callback);
        }
      };

      mockGet
        .mockResolvedValueOnce(mockSnapshot) // weak_spot_events
        .mockResolvedValueOnce(mockNodesSnapshot); // atlas_nodes

      const result = await adminMetricsService.getCognitiveMasteryMetrics();

      expect(result).toHaveProperty('summary');
      expect(result).toHaveProperty('nodeBreakdown');
      expect(result).toHaveProperty('generatedAt');
    });

    test('should handle empty weak spot events', async () => {
      const mockSnapshot = {
        forEach: (callback) => {}
      };

      const mockNodesSnapshot = {
        forEach: (callback) => {}
      };

      mockGet
        .mockResolvedValueOnce(mockSnapshot)
        .mockResolvedValueOnce(mockNodesSnapshot);

      const result = await adminMetricsService.getCognitiveMasteryMetrics();

      expect(result.summary).toHaveProperty('totalEvents');
      expect(result.summary.totalEvents).toBe(0);
      expect(result.summary).toHaveProperty('uniqueUsersTriggered');
    });
  });

  describe('getUserDetails', () => {
    test('should return user profile with all metadata', async () => {
      const mockUser = {
        phoneNumber: '+1234567890',
        overall_theta: 0.5,
        overall_percentile: 65,
        subscription: { tier: 'pro' },
        createdAt: { toDate: () => new Date() }
      };

      const mockUserSnapshot = {
        exists: true,
        id: 'user123',
        data: () => mockUser
      };

      const mockStreakSnapshot = {
        exists: true,
        data: () => ({ current_streak: 5 })
      };

      const mockQuizzesSnapshot = {
        forEach: (callback) => {}
      };

      const mockPracticeSnapshot = {
        forEach: (callback) => {}
      };

      const mockMockTestsSnapshot = {
        forEach: (callback) => {}
      };

      mockGet
        .mockResolvedValueOnce(mockUserSnapshot)
        .mockResolvedValueOnce(mockStreakSnapshot)
        .mockResolvedValueOnce(mockQuizzesSnapshot)
        .mockResolvedValueOnce(mockPracticeSnapshot)
        .mockResolvedValueOnce(mockMockTestsSnapshot);

      const result = await adminMetricsService.getUserDetails('user123');

      expect(result).toHaveProperty('uid', 'user123');
      expect(result).toHaveProperty('profile');
      expect(result).toHaveProperty('progress');
      expect(result).toHaveProperty('subscription');
      expect(result.subscription).toHaveProperty('tier');
    });

    test('should throw error for non-existent user', async () => {
      const mockSnapshot = {
        exists: false
      };

      mockGet.mockResolvedValue(mockSnapshot);

      await expect(adminMetricsService.getUserDetails('nonexistent'))
        .rejects
        .toThrow('User not found');
    });
  });

  describe('getUsers', () => {
    test('should return paginated list of users', async () => {
      const mockUsers = [
        { id: 'user1', data: () => ({
          firstName: 'Test',
          lastName: 'User1',
          phoneNumber: '+1234567890',
          overall_theta: 0.5,
          subscription: { tier: 'free' }
        })},
        { id: 'user2', data: () => ({
          firstName: 'Test',
          lastName: 'User2',
          email: 'user2@test.com',
          overall_theta: -0.2,
          subscription: { tier: 'pro' }
        })}
      ];

      const mockUsersSnapshot = {
        forEach: (callback) => mockUsers.forEach(callback)
      };

      const mockStreaksSnapshot = {
        forEach: (callback) => {
          [
            { id: 'user1', data: () => ({ current_streak: 3 }) },
            { id: 'user2', data: () => ({ current_streak: 5 }) }
          ].forEach(callback);
        }
      };

      mockGet
        .mockResolvedValueOnce(mockUsersSnapshot)
        .mockResolvedValueOnce(mockStreaksSnapshot);

      const result = await adminMetricsService.getUsers();

      expect(result).toHaveProperty('users');
      expect(result).toHaveProperty('total');
      expect(result).toHaveProperty('limit');
      expect(result).toHaveProperty('offset');
      expect(Array.isArray(result.users)).toBe(true);
    });

    test('should handle empty users collection', async () => {
      const mockUsersSnapshot = {
        forEach: (callback) => {}
      };

      const mockStreaksSnapshot = {
        forEach: (callback) => {}
      };

      mockGet
        .mockResolvedValueOnce(mockUsersSnapshot)
        .mockResolvedValueOnce(mockStreaksSnapshot);

      const result = await adminMetricsService.getUsers();

      expect(result).toHaveProperty('users');
      expect(Array.isArray(result.users)).toBe(true);
      expect(result.total).toBe(0);
    });
  });
});
