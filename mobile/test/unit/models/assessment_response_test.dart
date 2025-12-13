/// Unit tests for AssessmentResponse model
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/models/assessment_response.dart';

void main() {
  group('AssessmentResponse Model', () {
    test('toJson - creates correct JSON', () {
      final response = AssessmentResponse(
        questionId: 'test_q1',
        studentAnswer: 'A',
        timeTakenSeconds: 30,
      );

      final json = response.toJson();

      expect(json['question_id'], 'test_q1');
      expect(json['student_answer'], 'A');
      expect(json['time_taken_seconds'], 30);
    });
  });

  group('AssessmentResult Model', () {
    test('fromJson - success response', () {
      final json = {
        'success': true,
        'assessment': {
          'status': 'completed',
          'overall_theta': 0.75,
          'overall_percentile': 85.5,
        },
        'theta_by_chapter': {},
        'theta_by_subject': {},
        'subject_accuracy': {
          'physics': {'accuracy': 0.8, 'correct': 8, 'total': 10},
          'chemistry': {'accuracy': 0.7, 'correct': 7, 'total': 10},
          'mathematics': {'accuracy': 0.9, 'correct': 9, 'total': 10},
        },
        'chapters_explored': 5,
        'chapters_confident': 3,
        'subject_balance': {},
      };

      final result = AssessmentResult.fromJson(json);

      expect(result.success, true);
      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect(result.data!.overallTheta, 0.75);
      expect(result.data!.overallPercentile, 85.5);
    });

    test('fromJson - processing status', () {
      final json = {
        'success': true,
        'status': 'processing',
        'message': 'Assessment submitted. Results will be available shortly.',
      };

      final result = AssessmentResult.fromJson(json);

      expect(result.success, true);
      expect(result.data, isNotNull);
      expect(result.data!.assessment['status'], 'processing');
    });

    test('fromJson - error response', () {
      final json = {
        'success': false,
        'error': 'Invalid assessment data',
      };

      final result = AssessmentResult.fromJson(json);

      expect(result.success, false);
      expect(result.error, 'Invalid assessment data');
      expect(result.data, isNull);
    });

    test('fromJson - missing fields', () {
      final json = {
        'success': false,
      };

      final result = AssessmentResult.fromJson(json);

      expect(result.success, false);
      expect(result.data, isNull);
    });
  });

  group('AssessmentData Model', () {
    test('fromJson - complete data', () {
      final json = {
        'assessment': {
          'status': 'completed',
          'overall_theta': 0.75,
          'overall_percentile': 85.5,
        },
        'theta_by_chapter': {
          'algebra': {'theta': 0.8, 'percentile': 90.0},
        },
        'theta_by_subject': {
          'mathematics': {'theta': 0.75, 'percentile': 85.0},
        },
        'subject_accuracy': {
          'physics': {'accuracy': 0.8, 'correct': 8, 'total': 10},
          'chemistry': {'accuracy': 0.7, 'correct': 7, 'total': 10},
          'mathematics': {'accuracy': 0.9, 'correct': 9, 'total': 10},
        },
        'chapters_explored': 5,
        'chapters_confident': 3,
        'subject_balance': {
          'physics': 0.33,
          'chemistry': 0.33,
          'mathematics': 0.34,
        },
      };

      final data = AssessmentData.fromJson(json);

      expect(data.overallTheta, 0.75);
      expect(data.overallPercentile, 85.5);
      expect(data.chaptersExplored, 5);
      expect(data.chaptersConfident, 3);
      expect(data.subjectAccuracy.length, 3);
    });

    test('fromJson - missing optional fields', () {
      final json = {
        'assessment': {'status': 'completed'},
        'theta_by_chapter': {},
        'theta_by_subject': {},
        'subject_accuracy': {},
      };

      final data = AssessmentData.fromJson(json);

      expect(data.overallTheta, 0.0);
      expect(data.overallPercentile, 0.0);
      expect(data.chaptersExplored, 0);
      expect(data.chaptersConfident, 0);
    });
  });
}

