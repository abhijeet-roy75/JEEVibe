/// Unit tests for SnapData model
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/models/snap_data_model.dart';

void main() {
  group('SnapRecord Model', () {
    test('fromJson - valid data', () {
      final json = {
        'timestamp': '2024-01-01T00:00:00Z',
        'questionId': 'test_q1',
        'topic': 'Calculus',
        'subject': 'Mathematics',
      };

      final record = SnapRecord.fromJson(json);

      expect(record.timestamp, '2024-01-01T00:00:00Z');
      expect(record.questionId, 'test_q1');
      expect(record.topic, 'Calculus');
      expect(record.subject, 'Mathematics');
    });

    test('fromJson - missing optional fields', () {
      final json = {
        'timestamp': '2024-01-01T00:00:00Z',
        'questionId': 'test_q2',
        'topic': 'Algebra',
      };

      final record = SnapRecord.fromJson(json);

      expect(record.questionId, 'test_q2');
      expect(record.topic, 'Algebra');
      expect(record.subject, isNull);
    });

    test('toJson - creates correct JSON', () {
      final record = SnapRecord(
        timestamp: '2024-01-01T00:00:00Z',
        questionId: 'test_q1',
        topic: 'Calculus',
        subject: 'Mathematics',
      );

      final json = record.toJson();

      expect(json['timestamp'], '2024-01-01T00:00:00Z');
      expect(json['questionId'], 'test_q1');
      expect(json['topic'], 'Calculus');
      expect(json['subject'], 'Mathematics');
    });
  });

  group('RecentSolution Model', () {
    test('fromJson - valid data', () {
      final json = {
        'id': 'sol_1',
        'question': 'Test question',
        'topic': 'Calculus',
        'subject': 'Mathematics',
        'timestamp': '2024-01-01T00:00:00Z',
      };

      final solution = RecentSolution.fromJson(json);

      expect(solution.id, 'sol_1');
      expect(solution.question, 'Test question');
      expect(solution.topic, 'Calculus');
      expect(solution.subject, 'Mathematics');
    });

    test('getPreviewText - truncates long text', () {
      final longQuestion = 'A' * 100;
      final solution = RecentSolution(
        id: 'sol_1',
        question: longQuestion,
        topic: 'Calculus',
        subject: 'Mathematics',
        timestamp: '2024-01-01T00:00:00Z',
      );

      final preview = solution.getPreviewText();
      expect(preview.length, lessThanOrEqualTo(80));
      expect(preview, endsWith('...'));
    });

    test('getTimeAgo - formats time correctly', () {
      final now = DateTime.now();
      final solution = RecentSolution(
        id: 'sol_1',
        question: 'Test',
        topic: 'Calculus',
        subject: 'Mathematics',
        timestamp: now.subtract(const Duration(minutes: 5)).toIso8601String(),
      );

      final timeAgo = solution.getTimeAgo();
      expect(timeAgo, contains('5 min ago'));
    });
  });

  group('UserStats Model', () {
    test('fromJson - valid data', () {
      final json = {
        'totalQuestionsPracticed': 100,
        'totalCorrect': 80,
        'totalSnapsUsed': 50,
      };

      final stats = UserStats.fromJson(json);

      expect(stats.totalQuestionsPracticed, 100);
      expect(stats.totalCorrect, 80);
      expect(stats.totalSnapsUsed, 50);
      expect(stats.accuracy, 80.0);
    });

    test('fromJson - calculates accuracy', () {
      final json = {
        'totalQuestionsPracticed': 50,
        'totalCorrect': 40,
        'totalSnapsUsed': 30,
      };

      final stats = UserStats.fromJson(json);

      expect(stats.accuracy, 80.0);
    });

    test('getAccuracyString - formats percentage', () {
      final stats = UserStats(
        totalQuestionsPracticed: 100,
        totalCorrect: 75,
        accuracy: 75.0,
        totalSnapsUsed: 50,
      );

      expect(stats.getAccuracyString(), '75%');
    });
  });

  group('PracticeSessionResult Model', () {
    test('fromJson - valid data', () {
      final json = {
        'score': 2,
        'total': 3,
        'timeSpentSeconds': 300,
        'questionResults': [],
        'sessionId': 'session_1',
        'timestamp': '2024-01-01T00:00:00Z',
      };

      final result = PracticeSessionResult.fromJson(json);

      expect(result.score, 2);
      expect(result.total, 3);
      expect(result.accuracy, closeTo(66.67, 0.1));
      expect(result.sessionId, 'session_1');
    });

    test('accuracy - calculates correctly', () {
      final result = PracticeSessionResult(
        score: 3,
        total: 3,
        timeSpentSeconds: 300,
        questionResults: [],
        sessionId: 'session_1',
        timestamp: '2024-01-01T00:00:00Z',
      );

      expect(result.accuracy, 100.0);
    });
  });

  group('QuestionResult Model', () {
    test('fromJson - valid data', () {
      final json = {
        'questionNumber': 1,
        'question': 'Test question',
        'userAnswer': 'A',
        'correctAnswer': 'A',
        'isCorrect': true,
        'timeSpentSeconds': 30,
      };

      final result = QuestionResult.fromJson(json);

      expect(result.questionNumber, 1);
      expect(result.question, 'Test question');
      expect(result.userAnswer, 'A');
      expect(result.correctAnswer, 'A');
      expect(result.isCorrect, true);
      expect(result.timeSpentSeconds, 30);
    });

    test('toJson - creates correct JSON', () {
      final result = QuestionResult(
        questionNumber: 1,
        question: 'Test question',
        userAnswer: 'A',
        correctAnswer: 'B',
        isCorrect: false,
        timeSpentSeconds: 30,
      );

      final json = result.toJson();

      expect(json['questionNumber'], 1);
      expect(json['userAnswer'], 'A');
      expect(json['correctAnswer'], 'B');
      expect(json['isCorrect'], false);
    });
  });
}

