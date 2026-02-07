/**
 * Chapter Unlock Service Tests - 24-Month Countdown Timeline
 *
 * Tests the chapter unlock logic for all 24 months of the countdown timeline
 * to ensure correct behavior regardless of when a user joins.
 */

// Create mock Firestore instance with smarter collection handling
let currentCollection = null;
let currentDoc = null;

const mockGet = jest.fn();
const mockCollection = jest.fn((name) => {
  currentCollection = name;
  return mockFirestore;
});
const mockDoc = jest.fn((id) => {
  currentDoc = id;
  return mockFirestore;
});

const mockFirestore = {
  collection: mockCollection,
  where: jest.fn(() => mockFirestore),
  limit: jest.fn(() => mockFirestore),
  get: mockGet,
  doc: mockDoc,
};

// Mock Firebase Admin before importing anything
jest.mock('firebase-admin', () => {
  return {
    firestore: jest.fn(() => mockFirestore),
    apps: [],
    app: jest.fn(),
    auth: jest.fn(() => ({ verifyIdToken: jest.fn() })),
  };
});

// Mock the Firebase config to return our mocked db
jest.mock('../../../src/config/firebase', () => ({
  initializeFirebase: jest.fn(),
  admin: require('firebase-admin'),
  db: mockFirestore,
}));

const admin = require('firebase-admin');
const { getTimelinePosition, getUnlockedChapters, isChapterUnlocked } = require('../../../src/services/chapterUnlockService');

// Load the actual schedule data
const fs = require('fs');
const path = require('path');
const scheduleData = JSON.parse(
  fs.readFileSync(
    path.join(__dirname, '../../../../docs/10-calendar/countdown_24month_schedule_CORRECTED.json'),
    'utf8'
  )
);

describe('Chapter Unlock Service - 24-Month Timeline Tests', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    currentCollection = null;
    currentDoc = null;

    // Setup collection to track what's being accessed
    mockCollection.mockImplementation((name) => {
      currentCollection = name;
      return mockFirestore;
    });

    // Setup doc to track document ID
    mockDoc.mockImplementation((id) => {
      currentDoc = id;
      return mockFirestore;
    });

    // Smart get() that returns different data based on collection
    mockGet.mockImplementation(() => {
      // Schedule fetch: db.collection('unlock_schedules').where().limit().get()
      if (currentCollection === 'unlock_schedules') {
        return Promise.resolve({
          empty: false,
          docs: [{ data: () => scheduleData }]
        });
      }

      // User fetch: db.collection('users').doc(userId).get()
      if (currentCollection === 'users') {
        // Default user data (will be overridden in specific tests)
        return Promise.resolve({
          exists: true,
          data: () => ({
            jeeTargetExamDate: '2027-01',
            chapterUnlockHighWaterMark: 0
          })
        });
      }

      // Questions fetch: db.collection('questions').get()
      if (currentCollection === 'questions') {
        return Promise.resolve({
          empty: false,
          docs: []
        });
      }

      // Default fallback
      return Promise.resolve({ empty: true, docs: [] });
    });
  });

  describe('getTimelinePosition - Calculation Logic', () => {
    test('should calculate correct month for 24 months until exam (just joined)', () => {
      const targetDate = '2027-01'; // January 2027
      const currentDate = new Date('2025-01-20'); // 24 months before

      const result = getTimelinePosition(targetDate, currentDate);

      expect(result.currentMonth).toBe(1); // Month 1 of 24
      expect(result.monthsUntilExam).toBe(24);
      expect(result.isPostExam).toBe(false);
      expect(result.examSession).toBe('January');
    });

    test('should calculate correct month for 12 months until exam (mid-timeline)', () => {
      const targetDate = '2027-01'; // January 2027
      const currentDate = new Date('2026-01-20'); // 12 months before

      const result = getTimelinePosition(targetDate, currentDate);

      expect(result.currentMonth).toBe(13); // 24 - 12 + 1 = 13
      expect(result.monthsUntilExam).toBe(12);
      expect(result.isPostExam).toBe(false);
    });

    test('should calculate correct month for 1 month until exam (almost done)', () => {
      const targetDate = '2027-01'; // January 2027
      const currentDate = new Date('2026-12-20'); // 1 month before

      const result = getTimelinePosition(targetDate, currentDate);

      expect(result.currentMonth).toBe(24); // 24 - 1 + 1 = 24
      expect(result.monthsUntilExam).toBe(1);
      expect(result.isPostExam).toBe(false);
    });

    test('should handle exam month (0 months until)', () => {
      const targetDate = '2027-01'; // January 2027
      const currentDate = new Date('2027-01-20'); // Exam month

      const result = getTimelinePosition(targetDate, currentDate);

      expect(result.monthsUntilExam).toBe(0);
      // During exam month, isPostExam is true since monthsUntilExam is 0
      expect(result.isPostExam).toBe(true);
    });

    test('should handle post-exam period', () => {
      const targetDate = '2027-01'; // January 2027
      const currentDate = new Date('2027-03-20'); // 2 months after

      const result = getTimelinePosition(targetDate, currentDate);

      expect(result.monthsUntilExam).toBe(0);
      expect(result.isPostExam).toBe(true);
    });

    test('should identify April session correctly', () => {
      const targetDate = '2027-04'; // April 2027
      const currentDate = new Date('2026-04-20');

      const result = getTimelinePosition(targetDate, currentDate);

      expect(result.examSession).toBe('April');
      expect(result.monthsUntilExam).toBe(12);
    });
  });

  describe('Chapter Unlock Count - All 24 Entry Points', () => {
    // Helper to count expected unlocked chapters
    function countExpectedChapters(currentMonth) {
      const unlockedChapters = new Set();
      for (let i = 1; i <= currentMonth; i++) {
        const monthKey = `month_${i}`;
        const monthData = scheduleData.timeline[monthKey];

        if (monthData) {
          ['physics', 'chemistry', 'mathematics'].forEach(subject => {
            if (monthData[subject] && Array.isArray(monthData[subject])) {
              monthData[subject].forEach(ch => unlockedChapters.add(ch));
            }
          });
        }
      }
      return unlockedChapters.size;
    }

    // Test all 24 entry points
    const testCases = [
      { month: 1, monthsUntil: 24, expected: countExpectedChapters(1) },
      { month: 2, monthsUntil: 23, expected: countExpectedChapters(2) },
      { month: 3, monthsUntil: 22, expected: countExpectedChapters(3) },
      { month: 4, monthsUntil: 21, expected: countExpectedChapters(4) },
      { month: 5, monthsUntil: 20, expected: countExpectedChapters(5) },
      { month: 6, monthsUntil: 19, expected: countExpectedChapters(6) },
      { month: 7, monthsUntil: 18, expected: countExpectedChapters(7) },
      { month: 8, monthsUntil: 17, expected: countExpectedChapters(8) },
      { month: 9, monthsUntil: 16, expected: countExpectedChapters(9) },
      { month: 10, monthsUntil: 15, expected: countExpectedChapters(10) },
      { month: 11, monthsUntil: 14, expected: countExpectedChapters(11) },
      { month: 12, monthsUntil: 13, expected: countExpectedChapters(12) },
      { month: 13, monthsUntil: 12, expected: countExpectedChapters(13) },
      { month: 14, monthsUntil: 11, expected: countExpectedChapters(14) },
      { month: 15, monthsUntil: 10, expected: countExpectedChapters(15) },
      { month: 16, monthsUntil: 9, expected: countExpectedChapters(16) },
      { month: 17, monthsUntil: 8, expected: countExpectedChapters(17) },
      { month: 18, monthsUntil: 7, expected: countExpectedChapters(18) },
      { month: 19, monthsUntil: 6, expected: countExpectedChapters(19) },
      { month: 20, monthsUntil: 5, expected: countExpectedChapters(20) },
      { month: 21, monthsUntil: 4, expected: countExpectedChapters(21) },
      { month: 22, monthsUntil: 3, expected: countExpectedChapters(22) },
      { month: 23, monthsUntil: 2, expected: countExpectedChapters(23) },
      { month: 24, monthsUntil: 1, expected: countExpectedChapters(24) },
    ];

    testCases.forEach(({ month, monthsUntil, expected }) => {
      test(`Month ${month} (${monthsUntil} months until exam) should unlock ${expected} chapters`, async () => {
        const targetDate = '2027-01';
        const currentDate = new Date(2027, 0, 20); // Jan 20, 2027
        currentDate.setMonth(currentDate.getMonth() - monthsUntil);

        const position = getTimelinePosition(targetDate, currentDate);

        expect(position.currentMonth).toBe(month);
        expect(position.monthsUntilExam).toBe(monthsUntil);

        // Mock user data
        const userId = 'test-user';
        mockGet.mockResolvedValue({
          exists: true,
          data: () => ({
            jeeTargetExamDate: targetDate,
            chapterUnlockHighWaterMark: 0 // No high water mark
          })
        });

        const result = await getUnlockedChapters(userId, currentDate);

        expect(result.unlockedChapterKeys.length).toBe(expected);
        expect(result.currentMonth).toBe(month);
        expect(result.monthsUntilExam).toBe(monthsUntil);
      });
    });
  });

  describe('Progressive Unlock Verification', () => {
    test('should unlock more chapters as time progresses', async () => {
      const targetDate = '2027-01';
      const userId = 'test-user';

      // Mock user data
      mockFirestore.collection().doc().get = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          jeeTargetExamDate: targetDate,
          chapterUnlockHighWaterMark: 0
        })
      });

      // Test at 20 months until exam
      let currentDate = new Date('2025-05-20');
      let result = await getUnlockedChapters(userId, currentDate);
      const chaptersAt20Months = result.unlockedChapterKeys.length;

      // Test at 10 months until exam
      currentDate = new Date('2026-03-20');
      result = await getUnlockedChapters(userId, currentDate);
      const chaptersAt10Months = result.unlockedChapterKeys.length;

      // Test at 1 month until exam
      currentDate = new Date('2026-12-20');
      result = await getUnlockedChapters(userId, currentDate);
      const chaptersAt1Month = result.unlockedChapterKeys.length;

      // Verify progressive unlock
      expect(chaptersAt10Months).toBeGreaterThan(chaptersAt20Months);
      expect(chaptersAt1Month).toBeGreaterThan(chaptersAt10Months);
      expect(chaptersAt1Month).toBe(63); // All chapters at month 24
    });
  });

  describe('High Water Mark Pattern', () => {
    test('should not re-lock chapters when target date changes forward', async () => {
      const userId = 'test-user';

      // User initially sets target to April 2027 (18 months away from now)
      const initialDate = new Date('2025-10-20');
      let targetDate = '2027-04';

      mockFirestore.collection().doc().get = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          jeeTargetExamDate: targetDate,
          chapterUnlockHighWaterMark: 7 // Previously reached month 7
        })
      });

      let result = await getUnlockedChapters(userId, initialDate);
      const initialUnlocked = result.unlockedChapterKeys.length;

      // User changes target to April 2028 (pushing exam forward by 12 months)
      // This would normally put them at month 1, but high water mark prevents re-lock
      targetDate = '2028-04';
      mockFirestore.collection().doc().get = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          jeeTargetExamDate: targetDate,
          chapterUnlockHighWaterMark: 7 // Still at month 7
        })
      });

      result = await getUnlockedChapters(userId, initialDate);

      // Should still have at least the chapters from month 7
      expect(result.unlockedChapterKeys.length).toBeGreaterThanOrEqual(initialUnlocked);
      expect(result.usingHighWaterMark).toBe(true);
    });
  });

  describe('Edge Cases', () => {
    test('should handle legacy users without jeeTargetExamDate', async () => {
      const userId = 'legacy-user';

      mockFirestore.collection().doc().get = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          // No jeeTargetExamDate field
          currentClass: '12'
        })
      });

      const result = await getUnlockedChapters(userId);

      expect(result.isLegacyUser).toBe(true);
      expect(result.unlockedChapterKeys.length).toBe(63); // All chapters unlocked
    });

    test('should unlock all chapters when exam has passed', async () => {
      const targetDate = '2027-01';
      const userId = 'test-user';
      const currentDate = new Date('2027-03-20'); // 2 months after exam

      mockFirestore.collection().doc().get = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          jeeTargetExamDate: targetDate,
          chapterUnlockHighWaterMark: 20
        })
      });

      const result = await getUnlockedChapters(userId, currentDate);

      expect(result.isPostExam).toBe(true);
      expect(result.unlockedChapterKeys.length).toBe(63); // All chapters
    });

    test('should handle user not found gracefully', async () => {
      const userId = 'non-existent-user';

      mockFirestore.collection().doc().get = jest.fn().mockResolvedValue({
        exists: false
      });

      await expect(getUnlockedChapters(userId)).rejects.toThrow('User not found');
    });
  });

  describe('Consistency Verification', () => {
    test('all 24 months should have valid chapter data', () => {
      for (let i = 1; i <= 24; i++) {
        const monthKey = `month_${i}`;
        const monthData = scheduleData.timeline[monthKey];

        expect(monthData).toBeDefined();
        expect(monthData.physics).toBeDefined();
        expect(monthData.chemistry).toBeDefined();
        expect(monthData.mathematics).toBeDefined();
        expect(Array.isArray(monthData.physics)).toBe(true);
        expect(Array.isArray(monthData.chemistry)).toBe(true);
        expect(Array.isArray(monthData.mathematics)).toBe(true);
      }
    });

    test('total unique chapters should be 63', () => {
      const allChapters = new Set();

      for (let i = 1; i <= 24; i++) {
        const monthKey = `month_${i}`;
        const monthData = scheduleData.timeline[monthKey];

        ['physics', 'chemistry', 'mathematics'].forEach(subject => {
          monthData[subject].forEach(ch => allChapters.add(ch));
        });
      }

      expect(allChapters.size).toBe(63);
    });

    test('chapter unlocks should be cumulative (track duplicates)', () => {
      const seenChapters = new Set();
      const duplicates = [];

      for (let i = 1; i <= 24; i++) {
        const monthKey = `month_${i}`;
        const monthData = scheduleData.timeline[monthKey];

        ['physics', 'chemistry', 'mathematics'].forEach(subject => {
          monthData[subject].forEach(ch => {
            if (ch) { // Skip empty entries
              if (seenChapters.has(ch)) {
                duplicates.push(ch);
              }
              seenChapters.add(ch);
            }
          });
        });
      }

      // Known issue: 5 chapters appear twice in the schedule
      // This is handled by using Set in the service (only counts unique)
      expect(duplicates.length).toBe(5);
      expect(duplicates).toContain('chemistry_p_block_elements');
      expect(duplicates).toContain('chemistry_redox_electrochemistry');
      expect(duplicates).toContain('mathematics_limits_continuity_differentiability');
      expect(duplicates).toContain('mathematics_probability');
      expect(duplicates).toContain('mathematics_three_dimensional_geometry');
    });
  });

  describe('Real-world Scenarios', () => {
    test('User joins 11 months before Jan 2027 exam (your actual case)', async () => {
      const targetDate = '2027-01';
      const userId = 'real-user';
      const currentDate = new Date('2026-02-20'); // 11 months before

      mockFirestore.collection().doc().get = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          jeeTargetExamDate: targetDate,
          chapterUnlockHighWaterMark: 0
        })
      });

      const result = await getUnlockedChapters(userId, currentDate);

      expect(result.currentMonth).toBe(14); // 24 - 11 + 1 = 14
      expect(result.monthsUntilExam).toBe(11);
      expect(result.unlockedChapterKeys.length).toBe(49); // Your reported value
    });

    test('User joins last minute (1 month before exam)', async () => {
      const targetDate = '2027-01';
      const userId = 'late-joiner';
      const currentDate = new Date('2026-12-20'); // 1 month before

      mockFirestore.collection().doc().get = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          jeeTargetExamDate: targetDate,
          chapterUnlockHighWaterMark: 0
        })
      });

      const result = await getUnlockedChapters(userId, currentDate);

      expect(result.currentMonth).toBe(24);
      expect(result.monthsUntilExam).toBe(1);
      expect(result.unlockedChapterKeys.length).toBe(63); // All chapters (progressive unlock)
    });

    test('User joins 24 months early (ideal timeline)', async () => {
      const targetDate = '2027-01';
      const userId = 'early-bird';
      const currentDate = new Date('2025-01-20'); // 24 months before

      mockFirestore.collection().doc().get = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          jeeTargetExamDate: targetDate,
          chapterUnlockHighWaterMark: 0
        })
      });

      const result = await getUnlockedChapters(userId, currentDate);

      expect(result.currentMonth).toBe(1);
      expect(result.monthsUntilExam).toBe(24);
      expect(result.unlockedChapterKeys.length).toBeGreaterThan(0); // Some chapters from month 1
    });
  });
});
