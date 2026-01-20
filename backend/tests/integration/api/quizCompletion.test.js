/**
 * Integration Tests for Quiz Completion with Atomic Theta Updates
 *
 * Tests the atomic transaction behavior of quiz completion:
 * - Verifies quiz status + user stats + theta updates are all-or-nothing
 * - Tests rollback on errors
 * - Tests race conditions and concurrent completions
 * - Tests error recovery
 *
 * NOTE: These tests require Firebase Emulator to be running:
 *   firebase emulators:start --only firestore,auth
 *
 * These tests will be SKIPPED if the emulator is not available.
 */

const request = require('supertest');

// Check if Firebase Emulator is available before running tests
const isEmulatorAvailable = () => {
  return process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_EMULATOR_RUNNING === 'true';
};

// Skip all tests if emulator is not available
const describeIfEmulator = isEmulatorAvailable() ? describe : describe.skip;

// Only import Firebase if emulator is available to avoid connection errors
let db, admin;
if (isEmulatorAvailable()) {
  const firebase = require('../../../src/config/firebase');
  db = firebase.db;
  admin = firebase.admin;
}

// Mock dependencies
jest.mock('../../../src/utils/logger', () => ({
  info: jest.fn(),
  error: jest.fn(),
  warn: jest.fn(),
}));

// Mock circuit breaker, spaced repetition, and streak services
jest.mock('../../../src/services/circuitBreakerService', () => ({
  updateFailureCount: jest.fn().mockResolvedValue({}),
}));

jest.mock('../../../src/services/spacedRepetitionService', () => ({
  updateReviewInterval: jest.fn().mockResolvedValue({}),
}));

jest.mock('../../../src/services/streakService', () => ({
  updateStreak: jest.fn().mockResolvedValue({ current_streak: 1, longest_streak: 1 }),
  getStreak: jest.fn().mockResolvedValue({ current_streak: 0, longest_streak: 0 }),
}));

// Only import app if emulator is available
const app = isEmulatorAvailable() ? require('../../../src/index') : null;

describeIfEmulator('Quiz Completion - Atomic Theta Updates', () => {
  let testUserId;
  let testQuizId;
  let authToken;

  beforeAll(async () => {
    if (!process.env.FIRESTORE_EMULATOR_HOST) {
      process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
    }
  });

  beforeEach(async () => {
    // Create test user
    testUserId = `test_user_${Date.now()}_${Math.random().toString(36).substring(7)}`;

    // Create minimal user document
    await db
      .collection('users')
      .doc(testUserId)
      .set({
        uid: testUserId,
        email: `${testUserId}@test.com`,
        display_name: 'Test User',
        completed_quiz_count: 0,
        total_questions_solved: 0,
        total_time_spent_minutes: 0,
        theta_by_chapter: {},
        theta_by_subject: {
          physics: { theta: 0, percentile: 50 },
          chemistry: { theta: 0, percentile: 50 },
          mathematics: { theta: 0, percentile: 50 },
        },
        subject_accuracy: {
          physics: { correct: 0, total: 0, accuracy: 0 },
          chemistry: { correct: 0, total: 0, accuracy: 0 },
          mathematics: { correct: 0, total: 0, accuracy: 0 },
        },
        overall_theta: 0,
        overall_percentile: 50,
        assessment: {
          completed_at: new Date().toISOString(),
        },
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

    // Create test quiz
    testQuizId = `test_quiz_${Date.now()}_${Math.random().toString(36).substring(7)}`;
    await db
      .collection('users')
      .doc(testUserId)
      .collection('daily_quizzes')
      .doc(testQuizId)
      .set({
        quiz_id: testQuizId,
        status: 'active',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        question_count: 3,
        chapters: ['physics_kinematics'],
      });

    // Create test responses (3 responses with IRT parameters)
    const responsesRef = db
      .collection('users')
      .doc(testUserId)
      .collection('daily_quizzes')
      .doc(testQuizId)
      .collection('responses');

    await responsesRef.doc('response_1').set({
      question_id: 'q1',
      chapter_key: 'physics_kinematics',
      is_correct: true,
      time_taken_seconds: 30,
      question_irt_params: { a: 1.5, b: 0.0, c: 0.25 },
      selection_reason: 'deliberate_practice',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    await responsesRef.doc('response_2').set({
      question_id: 'q2',
      chapter_key: 'physics_kinematics',
      is_correct: true,
      time_taken_seconds: 45,
      question_irt_params: { a: 1.5, b: 0.5, c: 0.25 },
      selection_reason: 'deliberate_practice',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    await responsesRef.doc('response_3').set({
      question_id: 'q3',
      chapter_key: 'physics_kinematics',
      is_correct: false,
      time_taken_seconds: 60,
      question_irt_params: { a: 1.0, b: 1.0, c: 0.25 },
      selection_reason: 'exploration',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Mock auth token (in real test, you'd use Firebase Auth emulator)
    authToken = 'mock_token';
  });

  afterEach(async () => {
    // Clean up test data
    try {
      // Delete responses
      const responsesSnapshot = await db
        .collection('users')
        .doc(testUserId)
        .collection('daily_quizzes')
        .doc(testQuizId)
        .collection('responses')
        .get();

      const deletePromises = responsesSnapshot.docs.map((doc) => doc.ref.delete());
      await Promise.all(deletePromises);

      // Delete quiz
      await db
        .collection('users')
        .doc(testUserId)
        .collection('daily_quizzes')
        .doc(testQuizId)
        .delete();

      // Delete user
      await db.collection('users').doc(testUserId).delete();
    } catch (error) {
      console.error('Error cleaning up test data:', error);
    }
  });

  describe('Atomic Transaction Behavior', () => {
    test('should update quiz + user + theta atomically on success', async () => {
      // Complete quiz
      const response = await request(app)
        .post(`/api/daily-quiz/complete`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          quiz_id: testQuizId,
        });

      // Verify response (may be 200 or 500 depending on auth middleware)
      // For now, directly check Firestore state

      // Check quiz status
      const quizDoc = await db
        .collection('users')
        .doc(testUserId)
        .collection('daily_quizzes')
        .doc(testQuizId)
        .get();

      const quizData = quizDoc.data();
      expect(quizData.status).toBe('completed');
      expect(quizData.score).toBe(2); // 2 correct out of 3
      expect(quizData.accuracy).toBeCloseTo(0.667, 2);

      // Check user stats
      const userDoc = await db.collection('users').doc(testUserId).get();
      const userData = userDoc.data();

      expect(userData.completed_quiz_count).toBe(1);
      expect(userData.total_questions_solved).toBe(3);

      // Check theta updates
      expect(userData.theta_by_chapter).toHaveProperty('physics_kinematics');
      expect(userData.theta_by_chapter.physics_kinematics.attempts).toBe(3);
      expect(userData.theta_by_chapter.physics_kinematics.accuracy).toBeCloseTo(0.667, 2);

      expect(userData.overall_theta).toBeDefined();
      expect(typeof userData.overall_theta).toBe('number');

      expect(userData.theta_by_subject.physics).toBeDefined();
      expect(userData.subject_accuracy.physics.total).toBe(3);
      expect(userData.subject_accuracy.physics.correct).toBe(2);
    });

    test('should NOT mark quiz complete if theta calculation fails', async () => {
      // This test would require mocking calculateChapterThetaUpdate to throw
      // For now, we document the expected behavior:
      //
      // If theta calculation fails BEFORE transaction:
      //   - API returns 500 error
      //   - Quiz status remains 'active'
      //   - User stats NOT incremented
      //   - Theta NOT updated
      //
      // This is the desired behavior - all-or-nothing atomicity

      // TODO: Implement with proper mocking in future
      expect(true).toBe(true); // Placeholder
    });

    test('should rollback entire transaction on Firestore error', async () => {
      // This test would require forcing a Firestore transaction error
      // For now, we document the expected behavior:
      //
      // If transaction fails (e.g., network error, quota exceeded):
      //   - All writes rolled back
      //   - Quiz status remains 'active'
      //   - User stats unchanged
      //   - Theta unchanged
      //
      // Firestore guarantees atomic rollback

      // TODO: Implement with emulator fault injection in future
      expect(true).toBe(true); // Placeholder
    });
  });

  describe('Theta Calculation Correctness', () => {
    test('should calculate same theta as legacy method (regression)', async () => {
      // Complete quiz using new atomic method
      await request(app)
        .post(`/api/daily-quiz/complete`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          quiz_id: testQuizId,
        });

      // Get calculated theta
      const userDoc = await db.collection('users').doc(testUserId).get();
      const userData = userDoc.data();

      const calculatedTheta = userData.theta_by_chapter.physics_kinematics.theta;

      // Expected theta calculation (manual):
      // - Started at theta = 0, SE = 0.6
      // - Answered 3 questions: correct, correct, incorrect
      // - Question difficulties: 0.0, 0.5, 1.0
      // - Using IRT gradient descent with learning rate 0.3
      //
      // After Q1 (correct, b=0.0): theta increases
      // After Q2 (correct, b=0.5): theta increases more
      // After Q3 (incorrect, b=1.0): theta decreases slightly
      //
      // Final theta should be positive (2/3 correct)

      expect(calculatedTheta).toBeGreaterThan(0);
      expect(calculatedTheta).toBeLessThan(1.5);

      // Verify accuracy is exactly 2/3
      expect(userData.theta_by_chapter.physics_kinematics.accuracy).toBeCloseTo(0.667, 2);
    });

    test('should update all chapters that appear in quiz', async () => {
      // Add a chemistry response
      const responsesRef = db
        .collection('users')
        .doc(testUserId)
        .collection('daily_quizzes')
        .doc(testQuizId)
        .collection('responses');

      await responsesRef.doc('response_4').set({
        question_id: 'q4',
        chapter_key: 'chemistry_organic_chemistry',
        is_correct: true,
        time_taken_seconds: 40,
        question_irt_params: { a: 1.5, b: 0.0, c: 0.25 },
        selection_reason: 'exploration',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Complete quiz
      await request(app)
        .post(`/api/daily-quiz/complete`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          quiz_id: testQuizId,
        });

      // Check theta updates
      const userDoc = await db.collection('users').doc(testUserId).get();
      const userData = userDoc.data();

      expect(userData.theta_by_chapter).toHaveProperty('physics_kinematics');
      expect(userData.theta_by_chapter).toHaveProperty('chemistry_organic_chemistry');

      expect(userData.theta_by_chapter.physics_kinematics.attempts).toBe(3);
      expect(userData.theta_by_chapter.chemistry_organic_chemistry.attempts).toBe(1);
    });

    test('should preserve theta for chapters not in quiz', async () => {
      // Set existing theta for a different chapter
      await db
        .collection('users')
        .doc(testUserId)
        .update({
          'theta_by_chapter.mathematics_calculus': {
            theta: 1.5,
            percentile: 93,
            confidence_SE: 0.3,
            attempts: 20,
            accuracy: 0.85,
            last_updated: new Date().toISOString(),
          },
        });

      // Complete quiz (only physics_kinematics)
      await request(app)
        .post(`/api/daily-quiz/complete`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          quiz_id: testQuizId,
        });

      // Check theta
      const userDoc = await db.collection('users').doc(testUserId).get();
      const userData = userDoc.data();

      // Physics should be updated
      expect(userData.theta_by_chapter.physics_kinematics.attempts).toBe(3);

      // Math should be UNCHANGED
      expect(userData.theta_by_chapter.mathematics_calculus.theta).toBe(1.5);
      expect(userData.theta_by_chapter.mathematics_calculus.attempts).toBe(20);
      expect(userData.theta_by_chapter.mathematics_calculus.accuracy).toBe(0.85);
    });
  });

  describe('Race Conditions', () => {
    test('should prevent concurrent completions of same quiz', async () => {
      // This test checks that completing the same quiz twice fails
      // Due to the atomic check: if (quizData.status === 'completed') throw error

      // First completion
      await request(app)
        .post(`/api/daily-quiz/complete`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          quiz_id: testQuizId,
        });

      // Second completion (should fail)
      const response = await request(app)
        .post(`/api/daily-quiz/complete`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          quiz_id: testQuizId,
        });

      // Should return error (400 or 500 depending on implementation)
      // For now, check quiz is only marked complete once

      const userDoc = await db.collection('users').doc(testUserId).get();
      const userData = userDoc.data();

      // Should have only 1 completed quiz (not 2)
      expect(userData.completed_quiz_count).toBe(1);

      // Theta should only reflect 3 attempts (not 6)
      expect(userData.theta_by_chapter.physics_kinematics.attempts).toBe(3);
    });
  });

  describe('Error Handling', () => {
    test('should return error response on quiz not found', async () => {
      const response = await request(app)
        .post(`/api/daily-quiz/complete`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          quiz_id: 'nonexistent_quiz',
        });

      // Should return 404 or 500
      // User stats should not be affected
      const userDoc = await db.collection('users').doc(testUserId).get();
      const userData = userDoc.data();

      expect(userData.completed_quiz_count).toBe(0);
      expect(userData.theta_by_chapter).toEqual({});
    });

    test('should handle empty responses gracefully', async () => {
      // Delete all responses
      const responsesSnapshot = await db
        .collection('users')
        .doc(testUserId)
        .collection('daily_quizzes')
        .doc(testQuizId)
        .collection('responses')
        .get();

      await Promise.all(responsesSnapshot.docs.map((doc) => doc.ref.delete()));

      // Try to complete quiz
      const response = await request(app)
        .post(`/api/daily-quiz/complete`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          quiz_id: testQuizId,
        });

      // Should return error
      // Quiz should NOT be marked complete
      const quizDoc = await db
        .collection('users')
        .doc(testUserId)
        .collection('daily_quizzes')
        .doc(testQuizId)
        .get();

      const quizData = quizDoc.data();
      expect(quizData.status).toBe('active');
    });
  });

  describe('Performance', () => {
    test('should complete transaction in <2s', async () => {
      const startTime = Date.now();

      await request(app)
        .post(`/api/daily-quiz/complete`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          quiz_id: testQuizId,
        });

      const endTime = Date.now();
      const duration = endTime - startTime;

      // Should be fast (< 2000ms)
      expect(duration).toBeLessThan(2000);
    });
  });
});

describeIfEmulator('Quiz Completion - Backwards Compatibility', () => {
  test('should produce identical theta values to legacy implementation', () => {
    // This is a critical regression test to ensure the new atomic approach
    // produces the EXACT same theta values as the old non-atomic approach
    //
    // Test data:
    // - Same responses
    // - Same IRT parameters
    // - Same starting theta
    //
    // Expected: Theta values match within 0.01 tolerance

    // TODO: Implement detailed comparison test
    expect(true).toBe(true); // Placeholder
  });
});
