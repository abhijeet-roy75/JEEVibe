/// Chapter Practice Models
///
/// Data models for chapter-specific practice sessions.

/// Chapter Practice Session
class ChapterPracticeSession {
  final String sessionId;
  final String chapterKey;
  final String chapterName;
  final String subject;
  final List<PracticeQuestion> questions;
  final int totalQuestions;
  final int questionsAnswered;
  final double thetaAtStart;
  final DateTime createdAt;
  final bool isExistingSession;

  ChapterPracticeSession({
    required this.sessionId,
    required this.chapterKey,
    required this.chapterName,
    required this.subject,
    required this.questions,
    required this.totalQuestions,
    this.questionsAnswered = 0,
    required this.thetaAtStart,
    required this.createdAt,
    this.isExistingSession = false,
  });

  factory ChapterPracticeSession.fromJson(Map<String, dynamic> json) {
    return ChapterPracticeSession(
      sessionId: json['session_id'] ?? '',
      chapterKey: json['chapter_key'] ?? '',
      chapterName: json['chapter_name'] ?? '',
      subject: json['subject'] ?? '',
      questions: (json['questions'] as List<dynamic>?)
              ?.map((q) => PracticeQuestion.fromJson(q))
              .toList() ??
          [],
      totalQuestions: json['total_questions'] ?? 0,
      questionsAnswered: json['questions_answered'] ?? 0,
      thetaAtStart: (json['theta_at_start'] ?? 0.0).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      isExistingSession: json['is_existing_session'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'chapter_key': chapterKey,
        'chapter_name': chapterName,
        'subject': subject,
        'questions': questions.map((q) => q.toJson()).toList(),
        'total_questions': totalQuestions,
        'questions_answered': questionsAnswered,
        'theta_at_start': thetaAtStart,
        'created_at': createdAt.toIso8601String(),
        'is_existing_session': isExistingSession,
      };
}

/// Practice Question
class PracticeQuestion {
  final String questionId;
  final int position;
  final String subject;
  final String chapter;
  final String chapterKey;
  final String questionType;
  final String questionText;
  final String? questionTextHtml;
  final List<PracticeOption> options;
  final String? imageUrl;
  final List<String> subTopics;
  final PracticeIrtParameters? irtParameters;

  // Answer state (filled after answering)
  bool answered;
  String? studentAnswer;
  String? correctAnswer; // Returned by server for answered questions
  bool? isCorrect;
  int? timeTakenSeconds;

  PracticeQuestion({
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
    this.subTopics = const [],
    this.irtParameters,
    this.answered = false,
    this.studentAnswer,
    this.correctAnswer,
    this.isCorrect,
    this.timeTakenSeconds,
  });

  factory PracticeQuestion.fromJson(Map<String, dynamic> json) {
    // Robustly parse options
    List<PracticeOption> parsedOptions = [];
    final rawOptions = json['options'];
    if (rawOptions != null && rawOptions is List) {
      parsedOptions = rawOptions
          .where((o) => o != null && o is Map<String, dynamic>)
          .map((o) => PracticeOption.fromJson(o as Map<String, dynamic>))
          .where((o) => o.text.isNotEmpty) // Filter out empty options
          .toList();
    }

    return PracticeQuestion(
      questionId: json['question_id'] ?? '',
      position: json['position'] ?? 0,
      subject: json['subject'] ?? '',
      chapter: json['chapter'] ?? '',
      chapterKey: json['chapter_key'] ?? '',
      questionType: json['question_type'] ?? 'mcq_single',
      questionText: json['question_text'] ?? '',
      questionTextHtml: json['question_text_html'],
      options: parsedOptions,
      imageUrl: json['image_url'],
      subTopics: (json['sub_topics'] as List<dynamic>?)
              ?.map((s) => s.toString())
              .toList() ??
          [],
      irtParameters: json['irt_parameters'] != null
          ? PracticeIrtParameters.fromJson(json['irt_parameters'])
          : null,
      answered: json['answered'] ?? false,
      studentAnswer: json['student_answer'],
      correctAnswer: json['correct_answer'],
      isCorrect: json['is_correct'],
      timeTakenSeconds: json['time_taken_seconds'],
    );
  }

  /// Check if this is a numerical question
  bool get isNumerical => questionType.toLowerCase() == 'numerical';

  /// Check if question has an image
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  Map<String, dynamic> toJson() => {
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
        'sub_topics': subTopics,
        'irt_parameters': irtParameters?.toJson(),
        'answered': answered,
        'student_answer': studentAnswer,
        'is_correct': isCorrect,
        'time_taken_seconds': timeTakenSeconds,
      };
}

/// Practice Option
class PracticeOption {
  final String optionId;
  final String text;
  final String? html;

  PracticeOption({
    required this.optionId,
    required this.text,
    this.html,
  });

  factory PracticeOption.fromJson(Map<String, dynamic> json) {
    return PracticeOption(
      optionId: json['option_id'] ?? '',
      text: json['text'] ?? '',
      html: json['html'],
    );
  }

  Map<String, dynamic> toJson() => {
        'option_id': optionId,
        'text': text,
        'html': html,
      };
}

/// IRT Parameters
class PracticeIrtParameters {
  final double discriminationA;
  final double difficultyB;
  final double guessingC;

  PracticeIrtParameters({
    required this.discriminationA,
    required this.difficultyB,
    required this.guessingC,
  });

  factory PracticeIrtParameters.fromJson(Map<String, dynamic> json) {
    return PracticeIrtParameters(
      discriminationA: (json['discrimination_a'] ?? 1.5).toDouble(),
      difficultyB: (json['difficulty_b'] ?? 0.0).toDouble(),
      guessingC: (json['guessing_c'] ?? 0.25).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'discrimination_a': discriminationA,
        'difficulty_b': difficultyB,
        'guessing_c': guessingC,
      };
}

/// Answer Result from submit-answer API
class PracticeAnswerResult {
  final bool isCorrect;
  final String studentAnswer;
  final String correctAnswer;
  final String? correctAnswerText;
  final String? solutionText;
  final List<String> solutionSteps;
  final double thetaDelta;
  final double thetaMultiplier;

  PracticeAnswerResult({
    required this.isCorrect,
    required this.studentAnswer,
    required this.correctAnswer,
    this.correctAnswerText,
    this.solutionText,
    this.solutionSteps = const [],
    required this.thetaDelta,
    required this.thetaMultiplier,
  });

  factory PracticeAnswerResult.fromJson(Map<String, dynamic> json, {String? submittedAnswer}) {
    return PracticeAnswerResult(
      isCorrect: json['is_correct'] ?? false,
      studentAnswer: submittedAnswer ?? json['student_answer'] ?? '',
      correctAnswer: json['correct_answer'] ?? '',
      correctAnswerText: json['correct_answer_text'],
      solutionText: json['solution_text'],
      solutionSteps: (json['solution_steps'] as List<dynamic>?)
              ?.map((s) => s.toString())
              .toList() ??
          [],
      thetaDelta: (json['theta_delta'] ?? 0.0).toDouble(),
      thetaMultiplier: (json['theta_multiplier'] ?? 0.5).toDouble(),
    );
  }
}

/// Session Complete Summary
class PracticeSessionSummary {
  final String sessionId;
  final String chapterKey;
  final String chapterName;
  final String subject;
  final int totalQuestions;
  final int questionsAnswered;
  final int correctCount;
  final double accuracy;
  final int totalTimeSeconds;
  final double thetaMultiplier;
  final double overallTheta;
  final double overallPercentile;

  PracticeSessionSummary({
    required this.sessionId,
    required this.chapterKey,
    required this.chapterName,
    required this.subject,
    required this.totalQuestions,
    required this.questionsAnswered,
    required this.correctCount,
    required this.accuracy,
    required this.totalTimeSeconds,
    required this.thetaMultiplier,
    required this.overallTheta,
    required this.overallPercentile,
  });

  factory PracticeSessionSummary.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] ?? {};
    final updatedStats = json['updated_stats'] ?? {};

    return PracticeSessionSummary(
      sessionId: summary['session_id'] ?? '',
      chapterKey: summary['chapter_key'] ?? '',
      chapterName: summary['chapter_name'] ?? '',
      subject: summary['subject'] ?? '',
      totalQuestions: summary['total_questions'] ?? 0,
      questionsAnswered: summary['questions_answered'] ?? 0,
      correctCount: summary['correct_count'] ?? 0,
      accuracy: (summary['accuracy'] ?? 0.0).toDouble(),
      totalTimeSeconds: summary['total_time_seconds'] ?? 0,
      thetaMultiplier: (summary['theta_multiplier'] ?? 0.5).toDouble(),
      overallTheta: (updatedStats['overall_theta'] ?? 0.0).toDouble(),
      overallPercentile: (updatedStats['overall_percentile'] ?? 50.0).toDouble(),
    );
  }
}

/// Question result for review screen
class PracticeQuestionResult {
  final String questionId;
  final int position;
  final String questionText;
  final String? questionTextHtml;
  final List<PracticeOption> options;
  final String studentAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final int timeTakenSeconds;
  final String? solutionText;
  final List<String> solutionSteps;

  PracticeQuestionResult({
    required this.questionId,
    required this.position,
    required this.questionText,
    this.questionTextHtml,
    required this.options,
    required this.studentAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.timeTakenSeconds,
    this.solutionText,
    this.solutionSteps = const [],
  });
}
