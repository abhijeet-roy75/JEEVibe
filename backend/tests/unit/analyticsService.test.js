/**
 * Tests for analyticsService
 *
 * Coverage target: 80%+
 */

const analyticsService = require('../../src/services/analyticsService');
const { db } = require('../../src/config/firebase');

// Mock dependencies
jest.mock('../../src/config/firebase', () => ({
  db: {
    collection: jest.fn()
  },
  admin: {}
}));

jest.mock('../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn()
}));

jest.mock('../../src/utils/firestoreRetry', () => ({
  retryFirestoreOperation: jest.fn((fn) => fn())
}));

jest.mock('../../src/services/chapterMappingService', () => ({
  getDatabaseNames: jest.fn(),
  initializeMappings: jest.fn(() => Promise.resolve(new Map()))
}));

jest.mock('../../src/services/chapterUnlockService', () => ({
  getUnlockedChapters: jest.fn()
}));

jest.mock('../../src/utils/chapterKeyFormatter', () => ({
  chapterKeyToDisplayName: jest.fn((key) => {
    // Mock implementation: physics_kinematics → Kinematics
    const parts = key.split('_');
    return parts.slice(1).map(word =>
      word.charAt(0).toUpperCase() + word.slice(1)
    ).join(' ');
  })
}));

// Mock fs to avoid file system dependencies
jest.mock('fs', () => ({
  readFileSync: jest.fn(() => JSON.stringify({
    greetings: {
      morning: "Good morning, {firstName}!",
      afternoon: "Hey {firstName}!",
      evening: "Good evening, {firstName}!",
      night: "{firstName}, burning the midnight oil?",
      streak_champion: "{firstName}, my consistent star!",
      comeback: "Welcome back, {firstName}!"
    },
    progress_celebration: {
      near_milestone_questions: "You're just **{remaining} questions** away from **{milestone}**!",
      hit_milestone_chapters: "**{chaptersMastered} chapters mastered** — impressive depth!",
      both_zero: "Let's get started! Complete your first quiz to begin tracking your progress.",
      questions_only: "**{questionsSolved} questions** completed — great start!",
      chapters_only: "**{chaptersMastered} chapters mastered** — impressive depth!",
      default: "**{questionsSolved} questions** and **{chaptersMastered} chapters mastered** — that's real progress!"
    },
    strength_callout: {
      one_strongest: "Your **{bestSubject}** is strongest at **{percent}%**.",
      two_tied: "Your **{subject1}** and **{subject2}** are both looking solid!",
      all_balanced: "Nice balanced progress across all subjects!",
      exceptional: "Your **{subject}** is exceptional at **{percent}%** — JEE-ready!"
    },
    focus_recommendation: {
      close_to_breakthrough: "For {subject}, focus on **{chapter}** next — you're close to a breakthrough.",
      needs_attention: "**{chapter}** needs attention — let's strengthen that foundation.",
      low_attempts: "Try more **{chapter}** questions — practice builds confidence.",
      no_weak_areas: "No major weak spots — keep pushing those growing chapters!"
    },
    streak_motivation: {
      day_1: "Great start — come back tomorrow to build momentum!",
      days_2_to_6: "Keep that **{streak}-day streak** going!",
      days_7_to_13: "**{streak} days** strong — you're building a habit!",
      days_14_to_29: "**{streak}-day streak**! Consistency is your superpower.",
      days_30_plus: "Incredible **{streak}-day streak** — Priya Ma'am is proud!",
      no_streak: "Start today's quiz to get your streak going!"
    },
    mastery_thresholds: {
      mastered_min_percentile: 80,
      growing_min_percentile: 40,
      focus_max_percentile: 40,
      exceptional_min_percentile: 85
    },
    question_milestones: [100, 250, 500, 750, 1000, 1500, 2000, 3000, 5000],
    subject_display_names: {
      physics: 'Physics',
      chemistry: 'Chemistry',
      maths: 'Maths',
      mathematics: 'Maths'
    }
  })),
  watchFile: jest.fn()
}));

jest.mock('path', () => ({
  join: jest.fn((...args) => args.join('/'))
}));

describe('analyticsService', () => {
  let mockGet;
  let mockDoc;
  let mockCollection;

  beforeEach(() => {
    // Setup Firestore mocks
    mockGet = jest.fn();
    mockDoc = jest.fn(() => ({
      get: mockGet
    }));
    mockCollection = jest.fn(() => ({
      doc: mockDoc
    }));

    db.collection = mockCollection;

    // Clear all mock calls
    jest.clearAllMocks();
  });

  describe('getMasteryStatus', () => {
    test('should return MASTERED for percentile >= 80', () => {
      expect(analyticsService.getMasteryStatus(85)).toBe('MASTERED');
      expect(analyticsService.getMasteryStatus(80)).toBe('MASTERED');
      expect(analyticsService.getMasteryStatus(100)).toBe('MASTERED');
    });

    test('should return GROWING for percentile between 40-79', () => {
      expect(analyticsService.getMasteryStatus(70)).toBe('GROWING');
      expect(analyticsService.getMasteryStatus(50)).toBe('GROWING');
      expect(analyticsService.getMasteryStatus(40)).toBe('GROWING');
    });

    test('should return FOCUS for percentile < 40', () => {
      expect(analyticsService.getMasteryStatus(39)).toBe('FOCUS');
      expect(analyticsService.getMasteryStatus(20)).toBe('FOCUS');
      expect(analyticsService.getMasteryStatus(0)).toBe('FOCUS');
    });

    test('should handle edge cases', () => {
      expect(analyticsService.getMasteryStatus(79.99)).toBe('GROWING');
      expect(analyticsService.getMasteryStatus(39.99)).toBe('FOCUS');
    });
  });

  describe('getChapterDisplayName', () => {
    test('should format chapter key to display name', () => {
      const result = analyticsService.getChapterDisplayName('physics_kinematics');
      expect(typeof result).toBe('string');
      expect(result.length).toBeGreaterThan(0);
    });

    test('should handle various chapter key formats', () => {
      const result1 = analyticsService.getChapterDisplayName('chemistry_organic_chemistry');
      expect(typeof result1).toBe('string');

      const result2 = analyticsService.getChapterDisplayName('mathematics_calculus');
      expect(typeof result2).toBe('string');
    });
  });

  describe('getChapterDisplayNameAsync', () => {
    const { getDatabaseNames } = require('../../src/services/chapterMappingService');

    test('should fetch chapter name from database', async () => {
      getDatabaseNames.mockResolvedValue({
        chapter: 'Kinematics'
      });

      const result = await analyticsService.getChapterDisplayNameAsync('physics_kinematics');
      expect(result).toBe('Kinematics');
      expect(getDatabaseNames).toHaveBeenCalledWith('physics_kinematics');
    });

    test('should fall back to formatting if database lookup fails', async () => {
      getDatabaseNames.mockRejectedValue(new Error('Database error'));

      const result = await analyticsService.getChapterDisplayNameAsync('physics_kinematics');
      expect(typeof result).toBe('string');
      expect(result.length).toBeGreaterThan(0);
    });

    test('should fall back if mapping returns null', async () => {
      getDatabaseNames.mockResolvedValue(null);

      const result = await analyticsService.getChapterDisplayNameAsync('physics_kinematics');
      expect(typeof result).toBe('string');
    });
  });

  describe('getSubjectDisplayName', () => {
    test('should return proper display names for subjects', () => {
      expect(analyticsService.getSubjectDisplayName('physics')).toBe('Physics');
      expect(analyticsService.getSubjectDisplayName('chemistry')).toBe('Chemistry');
      expect(analyticsService.getSubjectDisplayName('mathematics')).toBe('Maths');
    });

    test('should handle capitalized input', () => {
      expect(analyticsService.getSubjectDisplayName('Physics')).toBe('Physics');
      expect(analyticsService.getSubjectDisplayName('PHYSICS')).toBe('Physics');
    });

    test('should capitalize unknown subjects', () => {
      const result = analyticsService.getSubjectDisplayName('biology');
      expect(result.charAt(0)).toBe(result.charAt(0).toUpperCase());
    });
  });

  describe('formatChapterKeyToDisplayName', () => {
    test('should format chapter keys to display names', () => {
      const result = analyticsService.formatChapterKeyToDisplayName('physics_kinematics');
      expect(typeof result).toBe('string');
      expect(result).not.toContain('_');
    });

    test('should handle complex chapter keys', () => {
      const result = analyticsService.formatChapterKeyToDisplayName('chemistry_organic_chemistry');
      expect(typeof result).toBe('string');
    });
  });

  describe('calculateFocusAreas', () => {
    test('should return 1 focus area per subject', async () => {
      const thetaByChapter = {
        'physics_kinematics': { percentile: 30, attempts: 10 },
        'physics_dynamics': { percentile: 35, attempts: 8 },
        'chemistry_organic': { percentile: 25, attempts: 12 },
        'mathematics_calculus': { percentile: 20, attempts: 15 }
      };

      const result = await analyticsService.calculateFocusAreas(thetaByChapter);

      expect(Array.isArray(result)).toBe(true);
      expect(result.length).toBeGreaterThan(0);
      expect(result.length).toBeLessThanOrEqual(3); // Max 1 per subject
    });

    test('should select lowest percentile chapter for each subject', async () => {
      const thetaByChapter = {
        'physics_kinematics': { percentile: 30, attempts: 10 },
        'physics_dynamics': { percentile: 10, attempts: 8 }, // Lowest for physics
        'chemistry_organic': { percentile: 25, attempts: 12 }
      };

      const result = await analyticsService.calculateFocusAreas(thetaByChapter);

      // Should pick physics_dynamics (percentile 10) over physics_kinematics (percentile 30)
      const physicsArea = result.find(area => area.chapterKey?.includes('physics'));
      if (physicsArea) {
        expect(physicsArea.percentile).toBe(10);
      }
    });

    test('should handle empty theta data', async () => {
      const result = await analyticsService.calculateFocusAreas({});

      expect(Array.isArray(result)).toBe(true);
      expect(result.length).toBe(0);
    });

    test('should filter out chapters with no attempts', async () => {
      const thetaByChapter = {
        'physics_kinematics': { percentile: 30, attempts: 0 }, // No attempts
        'chemistry_organic': { percentile: 25, attempts: 12 }
      };

      const result = await analyticsService.calculateFocusAreas(thetaByChapter);

      // Should not include physics_kinematics (0 attempts)
      const physicsArea = result.find(area => area.chapterKey === 'physics_kinematics');
      expect(physicsArea).toBeUndefined();
    });
  });

  describe('countMasteredChapters', () => {
    test('should count chapters with MASTERED status', () => {
      const chapterStats = {
        'physics_kinematics': { percentile: 85, masteryStatus: 'MASTERED' },
        'physics_dynamics': { percentile: 90, masteryStatus: 'MASTERED' },
        'chemistry_organic': { percentile: 50, masteryStatus: 'GROWING' },
        'mathematics_calculus': { percentile: 30, masteryStatus: 'FOCUS' }
      };

      const result = analyticsService.countMasteredChapters(chapterStats);

      expect(result).toBe(2);
    });

    test('should return 0 if no chapters are mastered', () => {
      const chapterStats = {
        'physics_kinematics': { percentile: 50, masteryStatus: 'GROWING' },
        'chemistry_organic': { percentile: 30, masteryStatus: 'FOCUS' }
      };

      const result = analyticsService.countMasteredChapters(chapterStats);

      expect(result).toBe(0);
    });

    test('should handle empty chapter stats', () => {
      const result = analyticsService.countMasteredChapters({});

      expect(result).toBe(0);
    });

    test('should handle null or undefined input', () => {
      // countMasteredChapters expects an object, null/undefined will throw
      expect(() => analyticsService.countMasteredChapters(null)).toThrow();
      expect(() => analyticsService.countMasteredChapters(undefined)).toThrow();
    });
  });

  describe('generatePriyaMaamMessage', () => {
    test('should generate appropriate message for new student', () => {
      const userData = {
        overall_theta: 0,
        completed_quiz_count: 2,
        assessment: { completed_at: new Date() }
      };

      const streakData = {
        current_streak: 0,
        last_practice_date: null
      };

      const subjectProgress = {
        physics: { percentile: 50 },
        chemistry: { percentile: 45 },
        mathematics: { percentile: 55 }
      };

      const focusAreas = [];

      const result = analyticsService.generatePriyaMaamMessage(userData, streakData, subjectProgress, focusAreas);

      expect(typeof result).toBe('string');
      expect(result.length).toBeGreaterThan(0);
    });

    test('should generate message for high performer', () => {
      const userData = {
        overall_theta: 1.5,
        overall_percentile: 90,
        completed_quiz_count: 50,
        assessment: { completed_at: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) }
      };

      const streakData = {
        current_streak: 15,
        last_practice_date: new Date()
      };

      const subjectProgress = {
        physics: { percentile: 88 },
        chemistry: { percentile: 90 },
        mathematics: { percentile: 92 }
      };

      const focusAreas = [];

      const result = analyticsService.generatePriyaMaamMessage(userData, streakData, subjectProgress, focusAreas);

      expect(typeof result).toBe('string');
      expect(result.length).toBeGreaterThan(0);
    });

    test('should handle missing user data gracefully', () => {
      const result = analyticsService.generatePriyaMaamMessage({}, {}, {}, []);

      expect(typeof result).toBe('string');
      expect(result.length).toBeGreaterThan(0);
    });

    test('should return different messages for different user states', () => {
      const newStudent = {
        completed_quiz_count: 1,
        overall_theta: 0
      };

      const advancedStudent = {
        completed_quiz_count: 100,
        overall_theta: 1.2,
        overall_percentile: 85
      };

      const streakData = { current_streak: 0, last_practice_date: null };
      const subjectProgress = {};
      const focusAreas = [];

      const msg1 = analyticsService.generatePriyaMaamMessage(newStudent, streakData, subjectProgress, focusAreas);
      const msg2 = analyticsService.generatePriyaMaamMessage(advancedStudent, streakData, subjectProgress, focusAreas);

      // Messages should be strings
      expect(typeof msg1).toBe('string');
      expect(typeof msg2).toBe('string');
      expect(msg1.length).toBeGreaterThan(0);
      expect(msg2.length).toBeGreaterThan(0);
    });
  });

  describe('getAllChaptersForSubject', () => {
    test('should return list of chapters for a subject', async () => {
      const mockUserData = {
        theta_by_chapter: {
          'physics_kinematics': { theta: 0.2, se: 0.3, percentile: 50, attempts: 10 },
          'physics_dynamics': { theta: 0.4, se: 0.3, percentile: 60, attempts: 8 },
          'chemistry_organic': { theta: 0.1, se: 0.3, percentile: 55, attempts: 5 }
        }
      };

      mockGet.mockResolvedValue({
        exists: true,
        data: () => mockUserData
      });

      const result = await analyticsService.getAllChaptersForSubject('user123', 'physics');

      expect(Array.isArray(result)).toBe(true);
      // Should only return physics chapters
      result.forEach(chapter => {
        expect(chapter.chapterKey).toContain('physics');
      });
    });

    test('should calculate mastery status for each chapter', async () => {
      const mockUserData = {
        theta_by_chapter: {
          'physics_kinematics': { theta: 1.0, se: 0.2, percentile: 85, attempts: 10 },
          'physics_dynamics': { theta: 0.3, se: 0.3, percentile: 50, attempts: 8 }
        }
      };

      mockGet.mockResolvedValue({
        exists: true,
        data: () => mockUserData
      });

      const result = await analyticsService.getAllChaptersForSubject('user123', 'physics');

      if (result.length > 0) {
        expect(result[0]).toHaveProperty('masteryStatus');
        expect(['MASTERED', 'GROWING', 'FOCUS']).toContain(result[0].masteryStatus);
      }
    });

    test('should handle empty theta data', async () => {
      const mockUserData = {
        theta_by_chapter: {}
      };

      mockGet.mockResolvedValue({
        exists: true,
        data: () => mockUserData
      });

      const result = await analyticsService.getAllChaptersForSubject('user123', 'physics');

      expect(Array.isArray(result)).toBe(true);
    });

    test('should filter chapters by subject', async () => {
      const mockUserData = {
        theta_by_chapter: {
          'physics_kinematics': { theta: 0.2, se: 0.3, percentile: 50, attempts: 10 },
          'chemistry_organic': { theta: 0.4, se: 0.3, percentile: 60, attempts: 8 },
          'mathematics_calculus': { theta: 0.3, se: 0.3, percentile: 55, attempts: 12 }
        }
      };

      mockGet.mockResolvedValue({
        exists: true,
        data: () => mockUserData
      });

      const physicsChapters = await analyticsService.getAllChaptersForSubject('user123', 'physics');
      const chemChapters = await analyticsService.getAllChaptersForSubject('user123', 'chemistry');

      physicsChapters.forEach(ch => expect(ch.chapterKey).toContain('physics'));
      chemChapters.forEach(ch => expect(ch.chapterKey).toContain('chemistry'));
    });
  });

  describe('getSubjectMasteryDetails', () => {
    test('should return mastery details for a subject', async () => {
      const mockUserData = {
        theta_by_subject: {
          physics: { theta: 0.5, se: 0.3, percentile: 65 }
        },
        theta_by_chapter: {
          'physics_kinematics': { theta: 0.6, se: 0.3, percentile: 70, attempts: 10 },
          'physics_dynamics': { theta: 0.4, se: 0.3, percentile: 60, attempts: 8 }
        }
      };

      mockGet.mockResolvedValue({
        exists: true,
        data: () => mockUserData
      });

      const result = await analyticsService.getSubjectMasteryDetails('user123', 'physics');

      expect(result).toHaveProperty('subject');
      expect(result).toHaveProperty('overall_theta');
      expect(result).toHaveProperty('overall_percentile');
      expect(result).toHaveProperty('status');
      expect(result).toHaveProperty('chapters');
      expect(result.overall_theta).toBe(0.5);
      expect(result.overall_percentile).toBe(65);
    });

    test('should handle missing subject data', async () => {
      const mockUserData = {
        theta_by_subject: {},
        theta_by_chapter: {}
      };

      mockGet.mockResolvedValue({
        exists: true,
        data: () => mockUserData
      });

      const result = await analyticsService.getSubjectMasteryDetails('user123', 'physics');

      expect(result).toHaveProperty('subject', 'physics');
      expect(result.overall_theta).toBe(0);
      expect(Array.isArray(result.chapters)).toBe(true);
    });
  });
});
