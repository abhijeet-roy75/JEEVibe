import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/models/chapter_practice_models.dart';
import 'package:jeevibe_mobile/models/daily_quiz_question.dart';
import 'package:jeevibe_mobile/utils/question_adapters.dart';

void main() {
  group('practiceQuestionToDailyQuiz', () {
    test('should convert all required fields correctly', () {
      final practice = PracticeQuestion(
        questionId: 'q123',
        position: 5,
        subject: 'Physics',
        chapter: 'Kinematics',
        chapterKey: 'physics_kinematics',
        questionType: 'mcq_single',
        questionText: 'What is velocity?',
        questionTextHtml: '<p>What is <b>velocity</b>?</p>',
        options: [
          PracticeOption(optionId: 'A', text: 'Speed with direction', html: null),
          PracticeOption(optionId: 'B', text: 'Just speed', html: null),
          PracticeOption(optionId: 'C', text: 'Acceleration', html: null),
          PracticeOption(optionId: 'D', text: 'Distance', html: null),
        ],
        imageUrl: 'https://example.com/image.svg',
        answered: true,
        studentAnswer: 'A',
        isCorrect: true,
        timeTakenSeconds: 45,
      );

      final daily = practiceQuestionToDailyQuiz(practice);

      expect(daily.questionId, equals('q123'));
      expect(daily.position, equals(5));
      expect(daily.subject, equals('Physics'));
      expect(daily.chapter, equals('Kinematics'));
      expect(daily.chapterKey, equals('physics_kinematics'));
      expect(daily.questionType, equals('mcq_single'));
      expect(daily.questionText, equals('What is velocity?'));
      expect(daily.questionTextHtml, equals('<p>What is <b>velocity</b>?</p>'));
      expect(daily.options?.length, equals(4));
      expect(daily.options?[0].optionId, equals('A'));
      expect(daily.options?[0].text, equals('Speed with direction'));
      expect(daily.imageUrl, equals('https://example.com/image.svg'));
      expect(daily.answered, isTrue);
      expect(daily.studentAnswer, equals('A'));
      expect(daily.isCorrect, isTrue);
      expect(daily.timeTakenSeconds, equals(45));
    });

    test('should handle numerical questions (empty options)', () {
      final practice = PracticeQuestion(
        questionId: 'q456',
        position: 0,
        subject: 'Mathematics',
        chapter: 'Calculus',
        chapterKey: 'mathematics_calculus',
        questionType: 'numerical',
        questionText: 'Calculate the derivative of x^2',
        options: [],
      );

      final daily = practiceQuestionToDailyQuiz(practice);

      expect(daily.isNumerical, isTrue);
      expect(daily.isMcq, isFalse);
      expect(daily.options, isEmpty);
    });

    test('should handle null optional fields', () {
      final practice = PracticeQuestion(
        questionId: 'q789',
        position: 0,
        subject: 'Chemistry',
        chapter: 'Organic',
        chapterKey: 'chemistry_organic',
        questionType: 'mcq_single',
        questionText: 'Question text',
        options: [],
        questionTextHtml: null,
        imageUrl: null,
      );

      final daily = practiceQuestionToDailyQuiz(practice);

      expect(daily.questionTextHtml, isNull);
      expect(daily.imageUrl, isNull);
      expect(daily.hasImage, isFalse);
    });

    test('should preserve answer state when converting', () {
      final practice = PracticeQuestion(
        questionId: 'q_state',
        position: 3,
        subject: 'Physics',
        chapter: 'Mechanics',
        chapterKey: 'physics_mechanics',
        questionType: 'mcq_single',
        questionText: 'Test question',
        options: [
          PracticeOption(optionId: 'A', text: 'Option A'),
          PracticeOption(optionId: 'B', text: 'Option B'),
        ],
        answered: true,
        studentAnswer: 'B',
        isCorrect: false,
        timeTakenSeconds: 120,
      );

      final daily = practiceQuestionToDailyQuiz(practice);

      expect(daily.answered, isTrue);
      expect(daily.studentAnswer, equals('B'));
      expect(daily.isCorrect, isFalse);
      expect(daily.timeTakenSeconds, equals(120));
    });

    test('should convert option HTML correctly', () {
      final practice = PracticeQuestion(
        questionId: 'q_html',
        position: 0,
        subject: 'Mathematics',
        chapter: 'Algebra',
        chapterKey: 'mathematics_algebra',
        questionType: 'mcq_single',
        questionText: 'Solve for x',
        options: [
          PracticeOption(
            optionId: 'A',
            text: 'x = 5',
            html: '<math>x = 5</math>',
          ),
          PracticeOption(
            optionId: 'B',
            text: 'x = -5',
            html: '<math>x = -5</math>',
          ),
        ],
      );

      final daily = practiceQuestionToDailyQuiz(practice);

      expect(daily.options?[0].html, equals('<math>x = 5</math>'));
      expect(daily.options?[1].html, equals('<math>x = -5</math>'));
    });
  });

  group('practiceResultToFeedback', () {
    test('should convert correct answer result', () {
      final result = PracticeAnswerResult(
        isCorrect: true,
        studentAnswer: 'A',
        correctAnswer: 'A',
        correctAnswerText: 'Speed with direction',
        solutionText: 'Velocity is speed with direction.',
        solutionSteps: ['Step 1: Understand speed', 'Step 2: Add direction'],
        thetaDelta: 0.15,
        thetaMultiplier: 0.5,
      );

      final feedback = practiceResultToFeedback(
        result,
        questionId: 'q123',
        timeTakenSeconds: 30,
        questionType: 'mcq_single',
      );

      expect(feedback.questionId, equals('q123'));
      expect(feedback.isCorrect, isTrue);
      expect(feedback.correctAnswer, equals('A'));
      expect(feedback.correctAnswerText, equals('Speed with direction'));
      expect(feedback.solutionText, equals('Velocity is speed with direction.'));
      expect(feedback.solutionSteps?.length, equals(2));
      expect(feedback.solutionSteps?[0].description, equals('Step 1: Understand speed'));
      expect(feedback.solutionSteps?[1].description, equals('Step 2: Add direction'));
      expect(feedback.timeTakenSeconds, equals(30));
      expect(feedback.studentAnswer, equals('A'));
      expect(feedback.questionType, equals('mcq_single'));
    });

    test('should convert incorrect answer result', () {
      final result = PracticeAnswerResult(
        isCorrect: false,
        studentAnswer: 'B',
        correctAnswer: 'A',
        correctAnswerText: 'Correct answer text',
        solutionText: 'Explanation',
        solutionSteps: [],
        thetaDelta: -0.1,
        thetaMultiplier: 0.5,
      );

      final feedback = practiceResultToFeedback(
        result,
        questionId: 'q456',
        timeTakenSeconds: 60,
      );

      expect(feedback.isCorrect, isFalse);
      expect(feedback.studentAnswer, equals('B'));
      expect(feedback.correctAnswer, equals('A'));
    });

    test('should handle empty solution steps', () {
      final result = PracticeAnswerResult(
        isCorrect: true,
        studentAnswer: '42',
        correctAnswer: '42',
        solutionSteps: [],
        thetaDelta: 0.1,
        thetaMultiplier: 0.5,
      );

      final feedback = practiceResultToFeedback(
        result,
        questionId: 'q789',
        questionType: 'numerical',
      );

      expect(feedback.solutionSteps, isEmpty);
      expect(feedback.questionType, equals('numerical'));
    });

    test('should use default timeTakenSeconds when not provided', () {
      final result = PracticeAnswerResult(
        isCorrect: true,
        studentAnswer: 'A',
        correctAnswer: 'A',
        solutionSteps: [],
        thetaDelta: 0.1,
        thetaMultiplier: 0.5,
      );

      final feedback = practiceResultToFeedback(
        result,
        questionId: 'q000',
      );

      expect(feedback.timeTakenSeconds, equals(0));
    });

    test('should handle null optional fields in result', () {
      final result = PracticeAnswerResult(
        isCorrect: true,
        studentAnswer: 'A',
        correctAnswer: 'A',
        correctAnswerText: null,
        solutionText: null,
        solutionSteps: [],
        thetaDelta: 0.1,
        thetaMultiplier: 0.5,
      );

      final feedback = practiceResultToFeedback(
        result,
        questionId: 'q_null',
      );

      expect(feedback.correctAnswerText, isNull);
      expect(feedback.solutionText, isNull);
    });
  });

  group('practiceQuestionsToDailyQuiz', () {
    test('should convert a list of questions', () {
      final questions = [
        PracticeQuestion(
          questionId: 'q1',
          position: 0,
          subject: 'Physics',
          chapter: 'Mechanics',
          chapterKey: 'physics_mechanics',
          questionType: 'mcq_single',
          questionText: 'Question 1',
          options: [],
        ),
        PracticeQuestion(
          questionId: 'q2',
          position: 1,
          subject: 'Physics',
          chapter: 'Mechanics',
          chapterKey: 'physics_mechanics',
          questionType: 'numerical',
          questionText: 'Question 2',
          options: [],
        ),
      ];

      final dailyQuestions = practiceQuestionsToDailyQuiz(questions);

      expect(dailyQuestions.length, equals(2));
      expect(dailyQuestions[0].questionId, equals('q1'));
      expect(dailyQuestions[0].isMcq, isTrue);
      expect(dailyQuestions[1].questionId, equals('q2'));
      expect(dailyQuestions[1].isNumerical, isTrue);
    });

    test('should handle empty list', () {
      final dailyQuestions = practiceQuestionsToDailyQuiz([]);
      expect(dailyQuestions, isEmpty);
    });
  });

  group('createFeedbackFromPractice', () {
    test('should create feedback from question and result', () {
      final question = PracticeQuestion(
        questionId: 'q_combo',
        position: 0,
        subject: 'Chemistry',
        chapter: 'Organic',
        chapterKey: 'chemistry_organic',
        questionType: 'mcq_single',
        questionText: 'Test question',
        options: [],
      );

      final result = PracticeAnswerResult(
        isCorrect: true,
        studentAnswer: 'A',
        correctAnswer: 'A',
        solutionText: 'Solution',
        solutionSteps: ['Step 1'],
        thetaDelta: 0.1,
        thetaMultiplier: 0.5,
      );

      final feedback = createFeedbackFromPractice(
        question: question,
        result: result,
        timeTakenSeconds: 45,
      );

      expect(feedback.questionId, equals('q_combo'));
      expect(feedback.questionType, equals('mcq_single'));
      expect(feedback.timeTakenSeconds, equals(45));
      expect(feedback.isCorrect, isTrue);
    });
  });
}
