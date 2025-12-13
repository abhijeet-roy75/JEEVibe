/// Unit tests for AssessmentQuestion model
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/models/assessment_question.dart';
import '../../fixtures/test_data.dart';

void main() {
  group('AssessmentQuestion Model', () {
    test('fromJson - valid MCQ question', () {
      final json = {
        'question_id': 'test_q1',
        'subject': 'Mathematics',
        'chapter': 'Algebra',
        'question_type': 'mcq_single',
        'question_text': 'What is 2 + 2?',
        'options': [
          {'option_id': 'A', 'text': '3'},
          {'option_id': 'B', 'text': '4'},
          {'option_id': 'C', 'text': '5'},
          {'option_id': 'D', 'text': '6'},
        ],
        'difficulty_irt': 0.5,
      };

      final question = AssessmentQuestion.fromJson(json);

      expect(question.questionId, 'test_q1');
      expect(question.subject, 'Mathematics');
      expect(question.chapter, 'Algebra');
      expect(question.questionType, 'mcq_single');
      expect(question.questionText, 'What is 2 + 2?');
      expect(question.options, isNotNull);
      expect(question.options!.length, 4);
      expect(question.difficultyIrt, 0.5);
      expect(question.isMcq, true);
      expect(question.isNumerical, false);
    });

    test('fromJson - valid numerical question', () {
      final json = {
        'question_id': 'test_q2',
        'subject': 'Physics',
        'chapter': 'Mechanics',
        'question_type': 'numerical',
        'question_text': 'Calculate the force',
        'difficulty_irt': 0.8,
      };

      final question = AssessmentQuestion.fromJson(json);

      expect(question.questionId, 'test_q2');
      expect(question.questionType, 'numerical');
      expect(question.options, isNull);
      expect(question.isMcq, false);
      expect(question.isNumerical, true);
    });

    test('fromJson - question with image', () {
      final json = {
        'question_id': 'test_q3',
        'subject': 'Chemistry',
        'chapter': 'Organic',
        'question_type': 'mcq_single',
        'question_text': 'Identify the compound',
        'image_url': 'https://example.com/image.svg',
      };

      final question = AssessmentQuestion.fromJson(json);

      expect(question.imageUrl, 'https://example.com/image.svg');
      expect(question.hasImage, true);
    });

    test('fromJson - question without image', () {
      final json = {
        'question_id': 'test_q4',
        'subject': 'Mathematics',
        'chapter': 'Calculus',
        'question_type': 'mcq_single',
        'question_text': 'Solve the equation',
      };

      final question = AssessmentQuestion.fromJson(json);

      expect(question.hasImage, false);
    });

    test('fromJson - missing optional fields', () {
      final json = {
        'question_id': 'test_q5',
        'subject': 'Mathematics',
        'chapter': 'Algebra',
        'question_type': 'mcq_single',
        'question_text': 'Test question',
      };

      final question = AssessmentQuestion.fromJson(json);

      expect(question.questionText, 'Test question');
      expect(question.questionTextHtml, isNull);
      expect(question.questionLatex, isNull);
      expect(question.options, isNull);
      expect(question.imageUrl, isNull);
      expect(question.difficultyIrt, isNull);
    });
  });

  group('QuestionOption Model', () {
    test('fromJson - valid option', () {
      final json = {
        'option_id': 'A',
        'text': 'Option A',
        'html': '<p>Option A</p>',
      };

      final option = QuestionOption.fromJson(json);

      expect(option.optionId, 'A');
      expect(option.text, 'Option A');
      expect(option.html, '<p>Option A</p>');
    });

    test('fromJson - option without html', () {
      final json = {
        'option_id': 'B',
        'text': 'Option B',
      };

      final option = QuestionOption.fromJson(json);

      expect(option.optionId, 'B');
      expect(option.text, 'Option B');
      expect(option.html, isNull);
    });
  });
}

