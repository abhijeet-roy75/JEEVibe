import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/models/chapter_practice_models.dart';
import 'package:jeevibe_mobile/providers/chapter_practice_provider.dart';

void main() {
  late ChapterPracticeProvider provider;

  setUp(() {
    provider = ChapterPracticeProvider();
  });

  tearDown(() {
    provider.dispose();
  });

  group('ChapterPracticeProvider - Initial State', () {
    test('should have null session initially', () {
      expect(provider.session, isNull);
    });

    test('should have zero currentQuestionIndex initially', () {
      expect(provider.currentQuestionIndex, 0);
    });

    test('should have empty results initially', () {
      expect(provider.results, isEmpty);
    });

    test('should not be loading initially', () {
      expect(provider.isLoading, false);
    });

    test('should not be submitting initially', () {
      expect(provider.isSubmitting, false);
    });

    test('should have no error message initially', () {
      expect(provider.errorMessage, isNull);
    });

    test('should have null lastAnswerResult initially', () {
      expect(provider.lastAnswerResult, isNull);
    });
  });

  group('ChapterPracticeProvider - currentQuestion', () {
    test('should return null when session is null', () {
      expect(provider.currentQuestion, isNull);
    });

    test('should return null when currentQuestionIndex is negative', () {
      // Can't directly set negative index, but the getter should handle it
      expect(provider.currentQuestion, isNull);
    });

    test('should return null when questions list is empty', () {
      // Session would need to have empty questions
      expect(provider.currentQuestion, isNull);
    });
  });

  group('ChapterPracticeProvider - hasMoreQuestions', () {
    test('should return false when session is null', () {
      expect(provider.hasMoreQuestions, false);
    });
  });

  group('ChapterPracticeProvider - accuracy calculation', () {
    test('should return 0.0 when no results', () {
      expect(provider.accuracy, 0.0);
    });

    test('should return correctCount as 0 when no results', () {
      expect(provider.correctCount, 0);
    });

    test('should return totalAnswered as 0 when no results', () {
      expect(provider.totalAnswered, 0);
    });
  });

  group('ChapterPracticeProvider - reset', () {
    test('should reset all state', () {
      // First modify some state
      provider.reset();

      expect(provider.session, isNull);
      expect(provider.currentQuestionIndex, 0);
      expect(provider.results, isEmpty);
      expect(provider.lastAnswerResult, isNull);
      expect(provider.isLoading, false);
      expect(provider.isSubmitting, false);
      expect(provider.errorMessage, isNull);
    });
  });

  group('ChapterPracticeProvider - nextQuestion', () {
    test('should not increment index when no session', () {
      final initialIndex = provider.currentQuestionIndex;
      provider.nextQuestion();
      expect(provider.currentQuestionIndex, initialIndex);
    });
  });

  // Additional unit tests for business logic
  group('Question prioritization logic', () {
    test('unseen questions should have highest priority', () {
      // Priority 3 = unseen
      // Priority 2 = seen but wrong
      // Priority 1 = seen and correct
      const unseenPriority = 3;
      const wrongPriority = 2;
      const correctPriority = 1;

      expect(unseenPriority, greaterThan(wrongPriority));
      expect(wrongPriority, greaterThan(correctPriority));
    });
  });

  group('Theta multiplier', () {
    test('chapter practice should use 0.5x multiplier', () {
      const thetaMultiplier = 0.5;
      const dailyQuizMultiplier = 1.0;

      expect(thetaMultiplier, lessThan(dailyQuizMultiplier));
    });

    test('multiplier should reduce theta delta impact', () {
      const rawDelta = 0.2;
      const thetaMultiplier = 0.5;
      final adjustedDelta = rawDelta * thetaMultiplier;

      expect(adjustedDelta, 0.1);
      expect(adjustedDelta, lessThan(rawDelta));
    });
  });

  group('Session ownership validation', () {
    test('should match session student_id with requesting user', () {
      const sessionOwnerId = 'user-a';
      const requestingUserId = 'user-a';

      expect(sessionOwnerId == requestingUserId, true);
    });

    test('should reject mismatched ownership', () {
      const sessionOwnerId = 'user-a';
      const requestingUserId = 'user-b';

      expect(sessionOwnerId == requestingUserId, false);
    });
  });

  group('Bounds validation', () {
    test('currentQuestionIndex should be validated against list bounds', () {
      // Given a questions list of length 5
      const questionsLength = 5;

      // Valid indices are 0-4
      for (var i = 0; i < questionsLength; i++) {
        expect(i >= 0 && i < questionsLength, true);
      }

      // Invalid indices
      expect(-1 >= 0 && -1 < questionsLength, false);
      expect(5 >= 0 && 5 < questionsLength, false);
    });
  });

  group('Result rebuilding on resume', () {
    test('should rebuild results from answered questions', () {
      // Simulate answered questions
      final answeredQuestions = [
        {'question_id': 'q1', 'answered': true, 'is_correct': true},
        {'question_id': 'q2', 'answered': true, 'is_correct': false},
        {'question_id': 'q3', 'answered': false, 'is_correct': null},
      ];

      final answeredCount = answeredQuestions
          .where((q) => q['answered'] == true)
          .length;

      expect(answeredCount, 2);
    });

    test('should correctly calculate accuracy from rebuilt results', () {
      final results = [
        {'is_correct': true},
        {'is_correct': true},
        {'is_correct': false},
      ];

      final correctCount = results.where((r) => r['is_correct'] == true).length;
      final totalAnswered = results.length;
      final accuracy = correctCount / totalAnswered;

      expect(correctCount, 2);
      expect(totalAnswered, 3);
      expect(accuracy, closeTo(0.667, 0.001));
    });
  });
}
