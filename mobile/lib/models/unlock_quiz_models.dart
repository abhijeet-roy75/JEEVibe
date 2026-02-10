import 'package:jeevibe_mobile/models/daily_quiz_question.dart' show SolutionStep;
import 'package:jeevibe_mobile/models/assessment_question.dart' show QuestionOption;

/// Unlock Quiz Session
/// Represents a 5-question quiz session for unlocking a locked chapter
class UnlockQuizSession {
  final String sessionId;
  final String chapterKey;
  final String chapterName;
  final String subject;
  final List<UnlockQuizQuestion> questions;
  final int totalQuestions;
  final int questionsAnswered;

  UnlockQuizSession({
    required this.sessionId,
    required this.chapterKey,
    required this.chapterName,
    required this.subject,
    required this.questions,
    this.totalQuestions = 5,
    this.questionsAnswered = 0,
  });

  factory UnlockQuizSession.fromJson(Map<String, dynamic> json) {
    return UnlockQuizSession(
      sessionId: json['sessionId'] ?? '',
      chapterKey: json['chapterKey'] ?? '',
      chapterName: json['chapterName'] ?? '',
      subject: json['subject'] ?? '',
      questions: (json['questions'] as List?)
              ?.map((q) => UnlockQuizQuestion.fromJson(q))
              .toList() ??
          [],
      totalQuestions: json['totalQuestions'] ?? 5,
      questionsAnswered: json['questionsAnswered'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'chapterKey': chapterKey,
      'chapterName': chapterName,
      'subject': subject,
      'questions': questions.map((q) => q.toJson()).toList(),
      'totalQuestions': totalQuestions,
      'questionsAnswered': questionsAnswered,
    };
  }
}

/// Unlock Quiz Question
class UnlockQuizQuestion {
  final String questionId;
  final int position;
  final String subject;
  final String chapter;
  final String chapterKey;
  final String questionType;
  final String questionText;
  final String? questionTextHtml;
  final List<QuestionOption> options;
  final String? imageUrl;

  // Answer state (mutable)
  bool answered;
  String? studentAnswer;
  String? correctAnswer;
  bool? isCorrect;
  int? timeTakenSeconds;

  UnlockQuizQuestion({
    required this.questionId,
    required this.position,
    required this.subject,
    required this.chapter,
    required this.chapterKey,
    required this.questionType,
    required this.questionText,
    this.questionTextHtml,
    required this.options,
    this.imageUrl,
    this.answered = false,
    this.studentAnswer,
    this.correctAnswer,
    this.isCorrect,
    this.timeTakenSeconds,
  });

  bool get isNumerical => questionType.toLowerCase() == 'numerical';

  factory UnlockQuizQuestion.fromJson(Map<String, dynamic> json) {
    return UnlockQuizQuestion(
      questionId: json['question_id'] ?? '',
      position: json['position'] ?? 0,
      subject: json['subject'] ?? '',
      chapter: json['chapter'] ?? '',
      chapterKey: json['chapter_key'] ?? '',
      questionType: json['question_type'] ?? 'mcq_single',
      questionText: json['question_text'] ?? '',
      questionTextHtml: json['question_text_html'],
      options: (json['options'] as List?)
              ?.map((o) => QuestionOption.fromJson(o))
              .toList() ??
          [],
      imageUrl: json['image_url'],
      answered: json['answered'] ?? false,
      studentAnswer: json['student_answer'],
      correctAnswer: json['correct_answer'],
      isCorrect: json['is_correct'],
      timeTakenSeconds: json['time_taken_seconds'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'position': position,
      'subject': subject,
      'chapter': chapter,
      'chapter_key': chapterKey,
      'question_type': questionType,
      'question_text': questionText,
      'question_text_html': questionTextHtml,
      'options': options.map((o) => o.toJson()).toList(),
      'image_url': imageUrl,
      'answered': answered,
      'student_answer': studentAnswer,
      'correct_answer': correctAnswer,
      'is_correct': isCorrect,
      'time_taken_seconds': timeTakenSeconds,
    };
  }
}

/// Unlock Quiz Answer Result
/// Response from submitting an answer
class UnlockQuizAnswerResult {
  final bool isCorrect;
  final String studentAnswer;
  final String correctAnswer;
  final String? correctAnswerText;
  final String? solutionText;
  final List<SolutionStep> solutionSteps;
  final String? keyInsight;
  final Map<String, String> distractorAnalysis;
  final List<String> commonMistakes;

  UnlockQuizAnswerResult({
    required this.isCorrect,
    required this.studentAnswer,
    required this.correctAnswer,
    this.correctAnswerText,
    this.solutionText,
    this.solutionSteps = const [],
    this.keyInsight,
    this.distractorAnalysis = const {},
    this.commonMistakes = const [],
  });

  factory UnlockQuizAnswerResult.fromJson(Map<String, dynamic> json) {
    return UnlockQuizAnswerResult(
      isCorrect: json['isCorrect'] ?? false,
      studentAnswer: json['studentAnswer'] ?? '',
      correctAnswer: json['correctAnswer'] ?? '',
      correctAnswerText: json['correctAnswerText'],
      solutionText: json['solutionText'],
      solutionSteps: (json['solutionSteps'] as List?)
              ?.map((s) => SolutionStep.fromJson(s))
              .toList() ??
          [],
      keyInsight: json['keyInsight'],
      distractorAnalysis:
          Map<String, String>.from(json['distractorAnalysis'] ?? {}),
      commonMistakes: List<String>.from(json['commonMistakes'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isCorrect': isCorrect,
      'studentAnswer': studentAnswer,
      'correctAnswer': correctAnswer,
      'correctAnswerText': correctAnswerText,
      'solutionText': solutionText,
      'solutionSteps': solutionSteps.map((s) => s.toJson()).toList(),
      'keyInsight': keyInsight,
      'distractorAnalysis': distractorAnalysis,
      'commonMistakes': commonMistakes,
    };
  }
}

/// Unlock Quiz Result
/// Final result after completing the quiz
class UnlockQuizResult {
  final String sessionId;
  final String chapterKey;
  final String chapterName;
  final String subject;
  final int totalQuestions;
  final int correctCount;
  final bool passed;
  final bool canRetry;

  UnlockQuizResult({
    required this.sessionId,
    required this.chapterKey,
    required this.chapterName,
    required this.subject,
    this.totalQuestions = 5,
    required this.correctCount,
    required this.passed,
    this.canRetry = false,
  });

  double get accuracy => correctCount / totalQuestions;

  factory UnlockQuizResult.fromJson(Map<String, dynamic> json) {
    return UnlockQuizResult(
      sessionId: json['sessionId'] ?? '',
      chapterKey: json['chapterKey'] ?? '',
      chapterName: json['chapterName'] ?? '',
      subject: json['subject'] ?? '',
      totalQuestions: json['totalQuestions'] ?? 5,
      correctCount: json['correctCount'] ?? 0,
      passed: json['passed'] ?? false,
      canRetry: json['canRetry'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'chapterKey': chapterKey,
      'chapterName': chapterName,
      'subject': subject,
      'totalQuestions': totalQuestions,
      'correctCount': correctCount,
      'passed': passed,
      'canRetry': canRetry,
    };
  }
}
