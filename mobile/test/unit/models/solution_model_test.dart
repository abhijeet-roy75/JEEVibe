/// Unit tests for Solution model
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/models/solution_model.dart';
import '../../fixtures/test_data.dart';

void main() {
  group('Solution Model', () {
    test('fromJson - valid data', () {
      final solution = Solution.fromJson(TestData.sampleSolutionJson);
      
      expect(solution.recognizedQuestion, 'Find the derivative of f(x) = x^2 + 3x + 5');
      expect(solution.subject, 'Mathematics');
      expect(solution.topic, 'Differential Calculus');
      expect(solution.difficulty, 'medium');
      expect(solution.solution.approach, isNotEmpty);
      expect(solution.solution.steps.length, 3);
      expect(solution.solution.finalAnswer, 'f\'(x) = 2x + 3');
      expect(solution.solution.priyaMaamTip, isNotEmpty);
    });

    test('fromJson - missing fields', () {
      final json = {
        'recognizedQuestion': 'Test question',
        // Missing other fields
      };
      
      final solution = Solution.fromJson(json);
      
      expect(solution.recognizedQuestion, 'Test question');
      expect(solution.subject, 'Mathematics'); // Default value
      expect(solution.topic, 'General'); // Default value
      expect(solution.difficulty, 'medium'); // Default value
      expect(solution.solution.steps, isEmpty);
    });

    test('fromJson - empty data', () {
      final solution = Solution.fromJson({});
      
      expect(solution.recognizedQuestion, '');
      expect(solution.subject, 'Mathematics');
      expect(solution.topic, 'General');
      expect(solution.difficulty, 'medium');
      expect(solution.solution.steps, isEmpty);
    });

    test('fromJson - with follow-up questions', () {
      final json = {
        ...TestData.sampleSolutionJson,
        'followUpQuestions': [TestData.sampleFollowUpQuestionJson],
      };
      
      final solution = Solution.fromJson(json);
      
      expect(solution.followUpQuestions.length, 1);
      expect(solution.followUpQuestions[0].question, isNotEmpty);
    });
  });

  group('SolutionDetails Model', () {
    test('fromJson - valid data', () {
      final json = TestData.sampleSolutionJson['solution'] as Map<String, dynamic>;
      final details = SolutionDetails.fromJson(json);
      
      expect(details.approach, isNotEmpty);
      expect(details.steps.length, 3);
      expect(details.finalAnswer, isNotEmpty);
      expect(details.priyaMaamTip, isNotEmpty);
    });

    test('fromJson - missing fields', () {
      final details = SolutionDetails.fromJson({});
      
      expect(details.approach, '');
      expect(details.steps, isEmpty);
      expect(details.finalAnswer, '');
      expect(details.priyaMaamTip, '');
    });
  });

  group('FollowUpQuestion Model', () {
    test('fromJson - valid data', () {
      final question = FollowUpQuestion.fromJson(TestData.sampleFollowUpQuestionJson);
      
      expect(question.question, isNotEmpty);
      expect(question.options.length, 4);
      expect(question.correctAnswer, 'A');
      expect(question.explanation, isNotNull);
    });

    test('fromJson - invalid options', () {
      final json = {
        'question': 'Test question',
        'options': 'invalid', // Should be a map
        'correctAnswer': 'A',
      };
      
      final question = FollowUpQuestion.fromJson(json);
      
      expect(question.question, 'Test question');
      expect(question.options, isEmpty);
    });

    test('fromJson - missing explanation', () {
      final json = {
        'question': 'Test question',
        'options': {'A': 'Option A'},
        'correctAnswer': 'A',
      };

      final question = FollowUpQuestion.fromJson(json);

      expect(question.explanation, isNotNull);
      expect(question.explanation.approach, '');
    });

    test('fromJson - with source field (database)', () {
      final json = {
        'question': 'Test question from DB',
        'options': {'A': 'Option A', 'B': 'Option B'},
        'correctAnswer': 'A',
        'source': 'database',
        'questionId': 'q_123',
      };

      final question = FollowUpQuestion.fromJson(json);

      expect(question.source, 'database');
      expect(question.questionId, 'q_123');
    });

    test('fromJson - with source field (ai)', () {
      final json = {
        'question': 'AI generated question',
        'options': {'A': 'Option A', 'B': 'Option B'},
        'correctAnswer': 'B',
        'source': 'ai',
      };

      final question = FollowUpQuestion.fromJson(json);

      expect(question.source, 'ai');
      expect(question.questionId, isNull);
    });

    test('fromJson - without source field (backwards compatibility)', () {
      final json = {
        'question': 'Legacy question',
        'options': {'A': 'Option A'},
        'correctAnswer': 'A',
      };

      final question = FollowUpQuestion.fromJson(json);

      expect(question.source, isNull);
      expect(question.questionId, isNull);
    });
  });
}

