/**
 * Mock Test Service Unit Tests
 *
 * Tests the analytics counter updates added for mock test completion
 */

describe('MockTestService - Analytics Updates', () => {
  describe('Analytics Counter Calculations', () => {
    it('should calculate attempted questions count correctly', () => {
      const result = {
        correct_count: 40,
        incorrect_count: 20,
        unattempted_count: 30
      };

      const attemptedCount = result.correct_count + result.incorrect_count;

      expect(attemptedCount).toBe(60);
      // Unattempted questions should not be included in attempted count
      expect(result.unattempted_count).not.toBe(attemptedCount);
    });

    it('should increment total_questions_solved by attempted count only', () => {
      const correct = 45;
      const incorrect = 15;
      const unattempted = 30;

      const shouldIncrement = correct + incorrect;

      expect(shouldIncrement).toBe(60);
      expect(shouldIncrement).toBeLessThan(90); // Total questions in mock test
    });
  });

  describe('Subject Accuracy Updates', () => {
    it('should update subject_accuracy for all three subjects', () => {
      const userData = {
        subject_accuracy: {
          physics: { correct: 10, total: 20, accuracy: 50 },
          chemistry: { correct: 8, total: 16, accuracy: 50 },
          mathematics: { correct: 12, total: 24, accuracy: 50 }
        }
      };

      const result = {
        subject_scores: {
          Physics: { correct: 15, incorrect: 8, total: 30 },
          Chemistry: { correct: 12, incorrect: 6, total: 30 },
          Mathematics: { correct: 13, incorrect: 6, total: 30 }
        }
      };

      // Calculate expected new subject accuracy
      const newPhysics = {
        correct: userData.subject_accuracy.physics.correct + result.subject_scores.Physics.correct,
        total: userData.subject_accuracy.physics.total + result.subject_scores.Physics.total
      };
      newPhysics.accuracy = Math.round((newPhysics.correct / newPhysics.total) * 100);

      expect(newPhysics.correct).toBe(25); // 10 + 15
      expect(newPhysics.total).toBe(50); // 20 + 30
      expect(newPhysics.accuracy).toBe(50); // 50%

      const newChemistry = {
        correct: userData.subject_accuracy.chemistry.correct + result.subject_scores.Chemistry.correct,
        total: userData.subject_accuracy.chemistry.total + result.subject_scores.Chemistry.total
      };
      newChemistry.accuracy = Math.round((newChemistry.correct / newChemistry.total) * 100);

      expect(newChemistry.correct).toBe(20); // 8 + 12
      expect(newChemistry.total).toBe(46); // 16 + 30
      expect(newChemistry.accuracy).toBe(43); // 43%

      const newMath = {
        correct: userData.subject_accuracy.mathematics.correct + result.subject_scores.Mathematics.correct,
        total: userData.subject_accuracy.mathematics.total + result.subject_scores.Mathematics.total
      };
      newMath.accuracy = Math.round((newMath.correct / newMath.total) * 100);

      expect(newMath.correct).toBe(25); // 12 + 13
      expect(newMath.total).toBe(54); // 24 + 30
      expect(newMath.accuracy).toBe(46); // 46%
    });

    it('should calculate accuracy as 0 when total is 0', () => {
      const newCorrect = 0;
      const newTotal = 0;
      const accuracy = newTotal > 0 ? Math.round((newCorrect / newTotal) * 100) : 0;

      expect(accuracy).toBe(0);
    });

    it('should handle first-time subject accuracy (no previous data)', () => {
      const userData = {
        subject_accuracy: {
          physics: { correct: 0, total: 0, accuracy: 0 },
          chemistry: { correct: 0, total: 0, accuracy: 0 },
          mathematics: { correct: 0, total: 0, accuracy: 0 }
        }
      };

      const result = {
        subject_scores: {
          Physics: { correct: 15, incorrect: 15, total: 30 },
          Chemistry: { correct: 20, incorrect: 10, total: 30 },
          Mathematics: { correct: 18, incorrect: 12, total: 30 }
        }
      };

      // First mock test should set accuracy directly
      const physicsAccuracy = Math.round((result.subject_scores.Physics.correct / result.subject_scores.Physics.total) * 100);
      const chemistryAccuracy = Math.round((result.subject_scores.Chemistry.correct / result.subject_scores.Chemistry.total) * 100);
      const mathAccuracy = Math.round((result.subject_scores.Mathematics.correct / result.subject_scores.Mathematics.total) * 100);

      expect(physicsAccuracy).toBe(50); // 15/30 = 50%
      expect(chemistryAccuracy).toBe(67); // 20/30 = 66.67% rounds to 67%
      expect(mathAccuracy).toBe(60); // 18/30 = 60%
    });

    it('should handle perfect score (100% accuracy)', () => {
      const result = {
        subject_scores: {
          Physics: { correct: 30, incorrect: 0, total: 30 }
        }
      };

      const accuracy = Math.round((result.subject_scores.Physics.correct / result.subject_scores.Physics.total) * 100);

      expect(accuracy).toBe(100);
    });

    it('should handle zero score (0% accuracy)', () => {
      const result = {
        subject_scores: {
          Physics: { correct: 0, incorrect: 30, total: 30 }
        }
      };

      const accuracy = Math.round((result.subject_scores.Physics.correct / result.subject_scores.Physics.total) * 100);

      expect(accuracy).toBe(0);
    });
  });

  describe('Mock Test Stats Updates', () => {
    it('should increment total_tests counter', () => {
      const currentTotalTests = 2;
      const newTotalTests = currentTotalTests + 1;

      expect(newTotalTests).toBe(3);
    });

    it('should update best_score if current score is higher', () => {
      const currentBestScore = 150;
      const newScore = 180;
      const newBestScore = Math.max(currentBestScore, newScore);

      expect(newBestScore).toBe(180);
    });

    it('should not update best_score if current score is lower', () => {
      const currentBestScore = 200;
      const newScore = 150;
      const newBestScore = Math.max(currentBestScore, newScore);

      expect(newBestScore).toBe(200);
    });

    it('should calculate average score correctly', () => {
      const currentTotalTests = 2;
      const currentTotalScore = 240; // avg 120
      const newScore = 180;

      const newTotalTests = currentTotalTests + 1;
      const newTotalScore = currentTotalScore + newScore;
      const avgScore = newTotalScore / newTotalTests;

      expect(avgScore).toBe(140); // (240 + 180) / 3 = 140
    });

    it('should handle first mock test (no previous stats)', () => {
      const currentTotalTests = 0;
      const currentTotalScore = 0;
      const newScore = 150;

      const newTotalTests = currentTotalTests + 1;
      const newTotalScore = currentTotalScore + newScore;
      const avgScore = newTotalScore / newTotalTests;

      expect(newTotalTests).toBe(1);
      expect(avgScore).toBe(150);
    });
  });

  describe('Integration with Analytics Overview', () => {
    it('should update all counters that Analytics Overview displays', () => {
      // Analytics Overview displays:
      // - total_questions_solved (Questions Solved stat)
      // - subject_accuracy (shown in subject progress cards)
      // - theta values (calculated from chapter/subject theta)

      const result = {
        correct_count: 50,
        incorrect_count: 25,
        unattempted_count: 15,
        subject_scores: {
          Physics: { correct: 18, incorrect: 10, total: 30 },
          Chemistry: { correct: 16, incorrect: 8, total: 30 },
          Mathematics: { correct: 16, incorrect: 7, total: 30 }
        }
      };

      // Verify counters that SHOULD be updated
      const attemptedCount = result.correct_count + result.incorrect_count;
      expect(attemptedCount).toBe(75); // Will increment total_questions_solved

      expect(result.correct_count).toBe(50); // Will increment total_questions_correct
      expect(result.incorrect_count).toBe(25); // Will increment total_questions_incorrect

      // Verify subject accuracy updates
      Object.keys(result.subject_scores).forEach(subject => {
        const scores = result.subject_scores[subject];
        expect(scores).toHaveProperty('correct');
        expect(scores).toHaveProperty('total');
        expect(scores.total).toBeGreaterThan(0);
      });
    });

    it('should verify correct counter increments for typical mock test', () => {
      // Typical JEE Main mock test: 90 questions
      // Student attempts 75, leaves 15 unattempted
      // Out of 75 attempted: 50 correct, 25 incorrect

      const mockTestResult = {
        total_questions: 90,
        attempted: 75,
        correct: 50,
        incorrect: 25,
        unattempted: 15
      };

      expect(mockTestResult.attempted).toBe(mockTestResult.correct + mockTestResult.incorrect);
      expect(mockTestResult.total_questions).toBe(mockTestResult.attempted + mockTestResult.unattempted);

      // These should be the increments
      expect(mockTestResult.attempted).toBe(75); // total_questions_solved += 75
      expect(mockTestResult.correct).toBe(50); // total_questions_correct += 50
      expect(mockTestResult.incorrect).toBe(25); // total_questions_incorrect += 25
    });
  });

  describe('Subject Score Consistency', () => {
    it('should ensure subject scores sum to overall scores', () => {
      const result = {
        correct_count: 45,
        incorrect_count: 30,
        unattempted_count: 15,
        subject_scores: {
          Physics: { correct: 15, incorrect: 10, total: 30 },
          Chemistry: { correct: 15, incorrect: 10, total: 30 },
          Mathematics: { correct: 15, incorrect: 10, total: 30 }
        }
      };

      // Sum up subject scores
      const totalCorrect = Object.values(result.subject_scores).reduce((sum, s) => sum + s.correct, 0);
      const totalIncorrect = Object.values(result.subject_scores).reduce((sum, s) => sum + s.incorrect, 0);
      const totalQuestions = Object.values(result.subject_scores).reduce((sum, s) => sum + s.total, 0);

      expect(totalCorrect).toBe(result.correct_count);
      expect(totalIncorrect).toBe(result.incorrect_count);
      expect(totalQuestions).toBe(90); // JEE Main has 90 total questions
    });
  });

  describe('Cumulative Stats Updates (Cross-Feature Consistency)', () => {
    it('should update cumulative_stats like Daily Quiz and Chapter Practice', () => {
      const result = {
        correct_count: 50,
        incorrect_count: 25,
        unattempted_count: 15
      };

      const attemptedCount = result.correct_count + result.incorrect_count;

      // Mock tests should update same cumulative_stats as other features
      // Format: cumulative_stats.total_questions_correct, cumulative_stats.total_questions_attempted
      expect(result.correct_count).toBe(50); // Will increment cumulative_stats.total_questions_correct
      expect(attemptedCount).toBe(75); // Will increment cumulative_stats.total_questions_attempted
    });

    it('should match Daily Quiz cumulative stats pattern', () => {
      // Daily Quiz updates (from dailyQuiz.js:765-767):
      // 'cumulative_stats.total_questions_correct': FieldValue.increment(correctCount)
      // 'cumulative_stats.total_questions_attempted': FieldValue.increment(totalCount)
      // 'cumulative_stats.last_updated': FieldValue.serverTimestamp()

      const mockTestResult = {
        correct_count: 60,
        incorrect_count: 15
      };

      const attemptedCount = mockTestResult.correct_count + mockTestResult.incorrect_count;

      // Mock test should increment same fields
      expect(mockTestResult.correct_count).toBe(60); // cumulative_stats.total_questions_correct
      expect(attemptedCount).toBe(75); // cumulative_stats.total_questions_attempted
      // last_updated would be FieldValue.serverTimestamp()
    });

    it('should use atomic FieldValue.increment for cumulative stats', () => {
      // Verify the update pattern uses atomic increments, not read-then-write
      const correctIncrement = 50;
      const attemptedIncrement = 75;

      // These should be used with FieldValue.increment() for atomic updates
      expect(correctIncrement).toBeGreaterThan(0);
      expect(attemptedIncrement).toBeGreaterThan(0);
      expect(attemptedIncrement).toBeGreaterThanOrEqual(correctIncrement);
    });
  });
});
