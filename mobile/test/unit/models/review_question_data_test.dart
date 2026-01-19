/// Tests for ReviewQuestionData model
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/models/review_question_data.dart';
import 'package:jeevibe_mobile/models/chapter_practice_models.dart';
import 'package:jeevibe_mobile/models/daily_quiz_question.dart';

void main() {
  group('ReviewQuestionData', () {
    group('fromDailyQuizMap', () {
      test('should parse basic question data correctly', () {
        final json = {
          'question_id': 'q123',
          'position': 2,
          'question_text': 'What is 2+2?',
          'question_text_html': '<p>What is 2+2?</p>',
          'student_answer': 'A',
          'correct_answer': 'B',
          'is_correct': false,
          'time_taken_seconds': 45,
          'subject': 'Mathematics',
          'chapter': 'Arithmetic',
          'difficulty': 'easy',
        };

        final result = ReviewQuestionData.fromDailyQuizMap(json);

        expect(result.questionId, 'q123');
        expect(result.position, 2);
        expect(result.questionText, 'What is 2+2?');
        expect(result.questionTextHtml, '<p>What is 2+2?</p>');
        expect(result.studentAnswer, 'A');
        expect(result.correctAnswer, 'B');
        expect(result.isCorrect, false);
        expect(result.timeTakenSeconds, 45);
        expect(result.subject, 'Mathematics');
        expect(result.chapter, 'Arithmetic');
        expect(result.difficulty, 'easy');
      });

      test('should parse options correctly', () {
        final json = {
          'question_id': 'q123',
          'position': 0,
          'question_text': 'Test question',
          'student_answer': 'A',
          'correct_answer': 'B',
          'is_correct': false,
          'options': [
            {'option_id': 'A', 'text': 'Option A', 'html': '<p>Option A</p>'},
            {'option_id': 'B', 'text': 'Option B', 'html': null},
          ],
        };

        final result = ReviewQuestionData.fromDailyQuizMap(json);

        expect(result.options.length, 2);
        expect(result.options[0].optionId, 'A');
        expect(result.options[0].text, 'Option A');
        expect(result.options[0].html, '<p>Option A</p>');
        expect(result.options[1].optionId, 'B');
        expect(result.options[1].text, 'Option B');
        expect(result.options[1].html, null);
      });

      test('should parse solution steps correctly', () {
        final json = {
          'question_id': 'q123',
          'position': 0,
          'question_text': 'Test question',
          'student_answer': 'A',
          'correct_answer': 'A',
          'is_correct': true,
          'solution_steps': [
            {'step_number': 1, 'description': 'Step 1'},
            {'step_number': 2, 'description': 'Step 2'},
          ],
        };

        final result = ReviewQuestionData.fromDailyQuizMap(json);

        expect(result.solutionSteps.length, 2);
        expect(result.solutionSteps[0].stepNumber, 1);
        expect(result.solutionSteps[0].description, 'Step 1');
      });

      test('should parse distractor analysis correctly', () {
        final json = {
          'question_id': 'q123',
          'position': 0,
          'question_text': 'Test question',
          'student_answer': 'A',
          'correct_answer': 'B',
          'is_correct': false,
          'distractor_analysis': {
            'A': 'This is wrong because...',
            'C': 'This is also wrong...',
          },
        };

        final result = ReviewQuestionData.fromDailyQuizMap(json);

        expect(result.distractorAnalysis, isNotNull);
        expect(result.distractorAnalysis!['A'], 'This is wrong because...');
        expect(result.distractorAnalysis!['C'], 'This is also wrong...');
      });

      test('should parse common mistakes correctly', () {
        final json = {
          'question_id': 'q123',
          'position': 0,
          'question_text': 'Test question',
          'student_answer': '5',
          'correct_answer': '4',
          'is_correct': false,
          'common_mistakes': ['Forgot to carry', 'Sign error'],
        };

        final result = ReviewQuestionData.fromDailyQuizMap(json);

        expect(result.commonMistakes, isNotNull);
        expect(result.commonMistakes!.length, 2);
        expect(result.commonMistakes![0], 'Forgot to carry');
      });

      test('should handle missing optional fields gracefully', () {
        final json = {
          'question_id': 'q123',
          'position': 0,
          'question_text': 'Test question',
          'student_answer': 'A',
          'correct_answer': 'A',
          'is_correct': true,
        };

        final result = ReviewQuestionData.fromDailyQuizMap(json);

        expect(result.questionTextHtml, null);
        expect(result.timeTakenSeconds, null);
        expect(result.solutionText, null);
        expect(result.solutionSteps, isEmpty);
        expect(result.subject, null);
        expect(result.chapter, null);
        expect(result.difficulty, null);
        expect(result.imageUrl, null);
        expect(result.keyInsight, null);
        expect(result.distractorAnalysis, null);
        expect(result.commonMistakes, null);
      });

      test('should handle null values in required fields with defaults', () {
        final json = <String, dynamic>{
          'question_id': null,
          'position': null,
          'question_text': null,
          'student_answer': null,
          'correct_answer': null,
          'is_correct': null,
        };

        final result = ReviewQuestionData.fromDailyQuizMap(json);

        expect(result.questionId, '');
        expect(result.position, 0);
        expect(result.questionText, '');
        expect(result.studentAnswer, '');
        expect(result.correctAnswer, '');
        expect(result.isCorrect, false);
      });
    });

    group('fromChapterPractice', () {
      test('should convert PracticeQuestionResult correctly', () {
        final practiceResult = PracticeQuestionResult(
          questionId: 'pq123',
          position: 3,
          questionText: 'Practice question text',
          questionTextHtml: '<p>Practice question text</p>',
          options: [
            PracticeOption(optionId: 'A', text: 'Option A'),
            PracticeOption(optionId: 'B', text: 'Option B'),
          ],
          studentAnswer: 'A',
          correctAnswer: 'B',
          isCorrect: false,
          timeTakenSeconds: 30,
          solutionText: 'Solution explanation',
          solutionSteps: [
            SolutionStep(stepNumber: 1, description: 'First step'),
          ],
        );

        final result = ReviewQuestionData.fromChapterPractice(
          practiceResult,
          subject: 'Physics',
          chapter: 'Mechanics',
        );

        expect(result.questionId, 'pq123');
        expect(result.position, 3);
        expect(result.questionText, 'Practice question text');
        expect(result.questionTextHtml, '<p>Practice question text</p>');
        expect(result.options.length, 2);
        expect(result.studentAnswer, 'A');
        expect(result.correctAnswer, 'B');
        expect(result.isCorrect, false);
        expect(result.timeTakenSeconds, 30);
        expect(result.solutionText, 'Solution explanation');
        expect(result.solutionSteps.length, 1);
        expect(result.subject, 'Physics');
        expect(result.chapter, 'Mechanics');
      });

      test('should handle null subject and chapter', () {
        final practiceResult = PracticeQuestionResult(
          questionId: 'pq123',
          position: 0,
          questionText: 'Test',
          options: [],
          studentAnswer: 'A',
          correctAnswer: 'A',
          isCorrect: true,
          timeTakenSeconds: 20,
        );

        final result = ReviewQuestionData.fromChapterPractice(practiceResult);

        expect(result.subject, null);
        expect(result.chapter, null);
      });
    });
  });

  group('ReviewOptionData', () {
    group('fromMap', () {
      test('should parse option data correctly', () {
        final json = {
          'option_id': 'A',
          'text': 'Option text',
          'html': '<p>Option text</p>',
        };

        final result = ReviewOptionData.fromMap(json);

        expect(result.optionId, 'A');
        expect(result.text, 'Option text');
        expect(result.html, '<p>Option text</p>');
      });

      test('should handle missing optional html', () {
        final json = {
          'option_id': 'B',
          'text': 'Plain text option',
        };

        final result = ReviewOptionData.fromMap(json);

        expect(result.optionId, 'B');
        expect(result.text, 'Plain text option');
        expect(result.html, null);
      });

      test('should handle null values with defaults', () {
        final json = <String, dynamic>{
          'option_id': null,
          'text': null,
        };

        final result = ReviewOptionData.fromMap(json);

        expect(result.optionId, '');
        expect(result.text, '');
      });
    });

    group('fromPracticeOption', () {
      test('should convert PracticeOption correctly', () {
        final practiceOption = PracticeOption(
          optionId: 'C',
          text: 'Practice option',
          html: '<strong>Practice option</strong>',
        );

        final result = ReviewOptionData.fromPracticeOption(practiceOption);

        expect(result.optionId, 'C');
        expect(result.text, 'Practice option');
        expect(result.html, '<strong>Practice option</strong>');
      });
    });
  });
}
