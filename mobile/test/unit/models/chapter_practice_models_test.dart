import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/models/chapter_practice_models.dart';
import 'package:jeevibe_mobile/models/daily_quiz_question.dart';

void main() {
  group('ChapterPracticeSession', () {
    test('fromJson parses session data correctly', () {
      final json = {
        'session_id': 'cp_test123_1234567890',
        'chapter_key': 'physics_kinematics',
        'chapter_name': 'Kinematics',
        'subject': 'Physics',
        'questions': [
          {
            'question_id': 'q1',
            'position': 0,
            'subject': 'Physics',
            'chapter': 'Kinematics',
            'chapter_key': 'physics_kinematics',
            'question_type': 'mcq_single',
            'question_text': 'What is velocity?',
            'options': [
              {'option_id': 'A', 'text': 'Speed with direction'},
              {'option_id': 'B', 'text': 'Just speed'},
            ],
          },
        ],
        'total_questions': 1,
        'questions_answered': 0,
        'theta_at_start': 0.5,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final session = ChapterPracticeSession.fromJson(json);

      expect(session.sessionId, 'cp_test123_1234567890');
      expect(session.chapterKey, 'physics_kinematics');
      expect(session.chapterName, 'Kinematics');
      expect(session.subject, 'Physics');
      expect(session.questions.length, 1);
      expect(session.totalQuestions, 1);
      expect(session.questionsAnswered, 0);
      expect(session.thetaAtStart, 0.5);
    });

    test('isExistingSession returns true when set', () {
      final json = {
        'session_id': 'cp_test123',
        'chapter_key': 'physics_kinematics',
        'chapter_name': 'Kinematics',
        'subject': 'Physics',
        'questions': [],
        'total_questions': 0,
        'questions_answered': 0,
        'theta_at_start': 0.0,
        'is_existing_session': true,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final session = ChapterPracticeSession.fromJson(json);

      expect(session.isExistingSession, true);
    });

    test('handles missing optional fields gracefully', () {
      final json = {
        'session_id': 'cp_test123',
        'chapter_key': 'physics_kinematics',
        'chapter_name': 'Kinematics',
        'subject': 'Physics',
        'questions': [],
        'total_questions': 5,
      };

      final session = ChapterPracticeSession.fromJson(json);

      expect(session.questionsAnswered, 0);
      expect(session.thetaAtStart, 0.0);
      expect(session.isExistingSession, false);
    });
  });

  group('PracticeQuestion', () {
    test('fromJson parses question data correctly', () {
      final json = {
        'question_id': 'q1',
        'position': 0,
        'subject': 'Physics',
        'chapter': 'Kinematics',
        'chapter_key': 'physics_kinematics',
        'question_type': 'mcq_single',
        'question_text': 'What is velocity?',
        'question_text_html': '<p>What is velocity?</p>',
        'options': [
          {'option_id': 'A', 'text': 'Speed with direction'},
          {'option_id': 'B', 'text': 'Just speed'},
          {'option_id': 'C', 'text': 'Acceleration'},
          {'option_id': 'D', 'text': 'Distance'},
        ],
        'image_url': 'https://example.com/image.png',
        'sub_topics': ['velocity', 'motion'],
        'irt_parameters': {
          'discrimination_a': 1.5,
          'difficulty_b': 0.5,
          'guessing_c': 0.25,
        },
      };

      final question = PracticeQuestion.fromJson(json);

      expect(question.questionId, 'q1');
      expect(question.position, 0);
      expect(question.subject, 'Physics');
      expect(question.chapter, 'Kinematics');
      expect(question.chapterKey, 'physics_kinematics');
      expect(question.questionType, 'mcq_single');
      expect(question.questionText, 'What is velocity?');
      expect(question.questionTextHtml, '<p>What is velocity?</p>');
      expect(question.options.length, 4);
      expect(question.imageUrl, 'https://example.com/image.png');
      expect(question.subTopics.length, 2);
      expect(question.irtParameters, isNotNull);
      expect(question.answered, false);
    });

    test('parses answered question state correctly', () {
      final json = {
        'question_id': 'q1',
        'position': 0,
        'subject': 'Physics',
        'chapter': 'Kinematics',
        'chapter_key': 'physics_kinematics',
        'question_type': 'mcq_single',
        'question_text': 'What is velocity?',
        'options': [],
        'answered': true,
        'student_answer': 'A',
        'correct_answer': 'A',
        'is_correct': true,
        'time_taken_seconds': 30,
      };

      final question = PracticeQuestion.fromJson(json);

      expect(question.answered, true);
      expect(question.studentAnswer, 'A');
      expect(question.correctAnswer, 'A');
      expect(question.isCorrect, true);
      expect(question.timeTakenSeconds, 30);
    });

    test('handles missing optional fields', () {
      final json = {
        'question_id': 'q1',
        'position': 0,
        'subject': 'Physics',
        'chapter': 'Kinematics',
        'chapter_key': 'physics_kinematics',
        'question_type': 'mcq_single',
        'question_text': 'Test',
        'options': [],
      };

      final question = PracticeQuestion.fromJson(json);

      expect(question.questionTextHtml, isNull);
      expect(question.imageUrl, isNull);
      expect(question.subTopics, isEmpty);
      expect(question.irtParameters, isNull);
      expect(question.answered, false);
      expect(question.studentAnswer, isNull);
      expect(question.correctAnswer, isNull);
      expect(question.isCorrect, isNull);
    });
  });

  group('PracticeOption', () {
    test('fromJson parses option correctly', () {
      final json = {
        'option_id': 'A',
        'text': 'Option A text',
        'html': '<p>Option A text</p>',
      };

      final option = PracticeOption.fromJson(json);

      expect(option.optionId, 'A');
      expect(option.text, 'Option A text');
      expect(option.html, '<p>Option A text</p>');
    });

    test('handles missing optional fields', () {
      final json = {
        'option_id': 'A',
        'text': 'Option A',
      };

      final option = PracticeOption.fromJson(json);

      expect(option.html, isNull);
    });
  });

  group('PracticeAnswerResult', () {
    test('fromJson parses answer result correctly', () {
      final json = {
        'is_correct': true,
        'correct_answer': 'A',
        'correct_answer_text': 'Speed with direction',
        'solution_text': 'Velocity is speed with direction.',
        'solution_steps': ['Step 1', 'Step 2'],
        'theta_delta': 0.05,
        'theta_multiplier': 0.5,
      };

      final result = PracticeAnswerResult.fromJson(json);

      expect(result.isCorrect, true);
      expect(result.correctAnswer, 'A');
      expect(result.correctAnswerText, 'Speed with direction');
      expect(result.solutionText, 'Velocity is speed with direction.');
      expect(result.solutionSteps.length, 2);
      expect(result.thetaDelta, 0.05);
      expect(result.thetaMultiplier, 0.5);
    });

    test('handles incorrect answer', () {
      final json = {
        'is_correct': false,
        'correct_answer': 'A',
        'theta_delta': -0.03,
      };

      final result = PracticeAnswerResult.fromJson(json);

      expect(result.isCorrect, false);
      expect(result.thetaDelta, -0.03);
    });
  });

  group('PracticeSessionSummary', () {
    test('fromJson parses summary correctly', () {
      final json = {
        'summary': {
          'session_id': 'cp_test123',
          'chapter_key': 'physics_kinematics',
          'chapter_name': 'Kinematics',
          'subject': 'Physics',
          'total_questions': 15,
          'questions_answered': 15,
          'correct_count': 12,
          'accuracy': 0.8,
          'total_time_seconds': 900,
          'theta_multiplier': 0.5,
        },
        'updated_stats': {
          'overall_theta': 0.6,
          'overall_percentile': 65.0,
        },
      };

      final summary = PracticeSessionSummary.fromJson(json);

      expect(summary.sessionId, 'cp_test123');
      expect(summary.chapterKey, 'physics_kinematics');
      expect(summary.chapterName, 'Kinematics');
      expect(summary.subject, 'Physics');
      expect(summary.totalQuestions, 15);
      expect(summary.questionsAnswered, 15);
      expect(summary.correctCount, 12);
      expect(summary.accuracy, 0.8);
      expect(summary.totalTimeSeconds, 900);
      expect(summary.thetaMultiplier, 0.5);
      expect(summary.overallTheta, 0.6);
      expect(summary.overallPercentile, 65.0);
    });
  });

  group('PracticeQuestionResult', () {
    test('creates result with all fields', () {
      final result = PracticeQuestionResult(
        questionId: 'q1',
        position: 0,
        questionText: 'What is velocity?',
        questionTextHtml: '<p>What is velocity?</p>',
        options: [],
        studentAnswer: 'A',
        correctAnswer: 'A',
        isCorrect: true,
        timeTakenSeconds: 30,
        solutionText: 'Explanation here',
        solutionSteps: [SolutionStep(stepNumber: 1, description: 'Step 1')],
      );

      expect(result.questionId, 'q1');
      expect(result.position, 0);
      expect(result.studentAnswer, 'A');
      expect(result.correctAnswer, 'A');
      expect(result.isCorrect, true);
      expect(result.timeTakenSeconds, 30);
      expect(result.solutionText, 'Explanation here');
      expect(result.solutionSteps.length, 1);
    });
  });

  group('PracticeIrtParameters', () {
    test('fromJson parses IRT parameters correctly', () {
      final json = {
        'discrimination_a': 1.5,
        'difficulty_b': 0.5,
        'guessing_c': 0.25,
      };

      final params = PracticeIrtParameters.fromJson(json);

      expect(params.discriminationA, 1.5);
      expect(params.difficultyB, 0.5);
      expect(params.guessingC, 0.25);
    });

    test('handles missing values with defaults', () {
      final json = <String, dynamic>{};

      final params = PracticeIrtParameters.fromJson(json);

      // Default values from the actual implementation
      expect(params.discriminationA, 1.5);
      expect(params.difficultyB, 0.0);
      expect(params.guessingC, 0.25);
    });
  });
}
