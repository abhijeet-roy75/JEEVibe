/// Chapter Practice Models
///
/// Data models for chapter-specific practice sessions.

import 'daily_quiz_question.dart' show SolutionStep;

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
    // Parse questions safely
    List<PracticeQuestion> questions = [];
    final rawQuestions = json['questions'];
    if (rawQuestions is List) {
      questions = rawQuestions
          .where((q) => q != null && q is Map<String, dynamic>)
          .map((q) => PracticeQuestion.fromJson(q as Map<String, dynamic>))
          .toList();
    }

    // Parse created_at safely
    DateTime createdAt = DateTime.now();
    final rawCreatedAt = json['created_at'];
    if (rawCreatedAt is String && rawCreatedAt.isNotEmpty) {
      try {
        createdAt = DateTime.parse(rawCreatedAt);
      } catch (_) {}
    }

    return ChapterPracticeSession(
      sessionId: json['session_id']?.toString() ?? '',
      chapterKey: json['chapter_key']?.toString() ?? '',
      chapterName: json['chapter_name']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      questions: questions,
      totalQuestions: json['total_questions'] ?? 0,
      questionsAnswered: json['questions_answered'] ?? 0,
      thetaAtStart: (json['theta_at_start'] ?? 0.0).toDouble(),
      createdAt: createdAt,
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

    // Handle student_answer - could be String or Map
    String? studentAnswer;
    final rawStudentAnswer = json['student_answer'];
    if (rawStudentAnswer is String) {
      studentAnswer = rawStudentAnswer;
    } else if (rawStudentAnswer is Map) {
      studentAnswer = rawStudentAnswer['option_id']?.toString() ??
                      rawStudentAnswer['value']?.toString();
    }

    // Handle correct_answer - could be String or Map
    String? correctAnswer;
    final rawCorrectAnswer = json['correct_answer'];
    if (rawCorrectAnswer is String) {
      correctAnswer = rawCorrectAnswer;
    } else if (rawCorrectAnswer is Map) {
      correctAnswer = rawCorrectAnswer['option_id']?.toString() ??
                      rawCorrectAnswer['value']?.toString();
    }

    // Safely extract string fields that could potentially be Maps
    String questionId = '';
    if (json['question_id'] is String) {
      questionId = json['question_id'];
    } else if (json['question_id'] != null) {
      questionId = json['question_id'].toString();
    }

    String questionText = '';
    if (json['question_text'] is String) {
      questionText = json['question_text'];
    } else if (json['question_text'] is Map) {
      questionText = json['question_text']['text']?.toString() ??
                     json['question_text']['value']?.toString() ?? '';
    } else if (json['question_text'] != null) {
      questionText = json['question_text'].toString();
    }

    String? questionTextHtml;
    if (json['question_text_html'] is String) {
      questionTextHtml = json['question_text_html'];
    } else if (json['question_text_html'] is Map) {
      questionTextHtml = json['question_text_html']['html']?.toString() ??
                         json['question_text_html']['value']?.toString();
    }

    String? imageUrl;
    if (json['image_url'] is String) {
      imageUrl = json['image_url'];
    } else if (json['image_url'] is Map) {
      imageUrl = json['image_url']['url']?.toString();
    }

    return PracticeQuestion(
      questionId: questionId,
      position: json['position'] ?? 0,
      subject: json['subject']?.toString() ?? '',
      chapter: json['chapter']?.toString() ?? '',
      chapterKey: json['chapter_key']?.toString() ?? '',
      questionType: json['question_type']?.toString() ?? 'mcq_single',
      questionText: questionText,
      questionTextHtml: questionTextHtml,
      options: parsedOptions,
      imageUrl: imageUrl,
      subTopics: (json['sub_topics'] as List<dynamic>?)
              ?.map((s) => s.toString())
              .toList() ??
          [],
      irtParameters: json['irt_parameters'] != null && json['irt_parameters'] is Map
          ? PracticeIrtParameters.fromJson(json['irt_parameters'])
          : null,
      answered: json['answered'] ?? false,
      studentAnswer: studentAnswer,
      correctAnswer: correctAnswer,
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
    // Handle option_id - could be String or Map
    String optionId = '';
    final rawOptionId = json['option_id'];
    if (rawOptionId is String) {
      optionId = rawOptionId;
    } else if (rawOptionId != null) {
      optionId = rawOptionId.toString();
    }

    // Handle text - could be String or Map
    String text = '';
    final rawText = json['text'];
    if (rawText is String) {
      text = rawText;
    } else if (rawText is Map) {
      text = rawText['value']?.toString() ?? rawText['text']?.toString() ?? '';
    } else if (rawText != null) {
      text = rawText.toString();
    }

    // Handle html - could be String or Map
    String? html;
    final rawHtml = json['html'];
    if (rawHtml is String) {
      html = rawHtml;
    } else if (rawHtml is Map) {
      html = rawHtml['value']?.toString() ?? rawHtml['html']?.toString();
    }

    return PracticeOption(
      optionId: optionId,
      text: text,
      html: html,
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
/// Note: Uses unified SolutionStep from daily_quiz_question.dart
class PracticeAnswerResult {
  final bool isCorrect;
  final String studentAnswer;
  final String correctAnswer;
  final String? correctAnswerText;
  final String? explanation;
  final String? solutionText;
  final List<SolutionStep> solutionSteps;
  final String? keyInsight;
  final Map<String, String>? distractorAnalysis;
  final List<String>? commonMistakes;
  final double thetaDelta;
  final double thetaMultiplier;

  PracticeAnswerResult({
    required this.isCorrect,
    required this.studentAnswer,
    required this.correctAnswer,
    this.correctAnswerText,
    this.explanation,
    this.solutionText,
    this.solutionSteps = const [],
    this.keyInsight,
    this.distractorAnalysis,
    this.commonMistakes,
    required this.thetaDelta,
    required this.thetaMultiplier,
  });

  factory PracticeAnswerResult.fromJson(Map<String, dynamic> json, {String? submittedAnswer}) {
    // Parse distractor_analysis map
    Map<String, String>? distractorAnalysis;
    if (json['distractor_analysis'] != null && json['distractor_analysis'] is Map) {
      distractorAnalysis = Map<String, String>.from(
        (json['distractor_analysis'] as Map).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      );
    }

    // Parse common_mistakes list
    List<String>? commonMistakes;
    if (json['common_mistakes'] != null && json['common_mistakes'] is List) {
      commonMistakes = (json['common_mistakes'] as List)
          .map((m) => m.toString())
          .toList();
    }

    // Parse solution_steps using unified SolutionStep model
    List<SolutionStep> solutionSteps = [];
    if (json['solution_steps'] != null && json['solution_steps'] is List) {
      solutionSteps = (json['solution_steps'] as List)
          .map((step) => SolutionStep.fromJson(step))
          .toList();
    }

    // Handle student_answer - could be String or Map
    String parsedStudentAnswer = '';
    final rawStudentAnswer = json['student_answer'];
    if (rawStudentAnswer is String) {
      parsedStudentAnswer = rawStudentAnswer;
    } else if (rawStudentAnswer is Map) {
      parsedStudentAnswer = rawStudentAnswer['option_id']?.toString() ??
                            rawStudentAnswer['value']?.toString() ?? '';
    }

    // Handle correct_answer - could be String or Map
    String correctAnswer = '';
    final rawCorrectAnswer = json['correct_answer'];
    if (rawCorrectAnswer is String) {
      correctAnswer = rawCorrectAnswer;
    } else if (rawCorrectAnswer is Map) {
      correctAnswer = rawCorrectAnswer['option_id']?.toString() ??
                      rawCorrectAnswer['value']?.toString() ?? '';
    }

    // Safely extract string fields that could potentially be Maps
    String? correctAnswerText;
    if (json['correct_answer_text'] is String) {
      correctAnswerText = json['correct_answer_text'];
    } else if (json['correct_answer_text'] is Map) {
      correctAnswerText = json['correct_answer_text']['text']?.toString() ??
                          json['correct_answer_text']['value']?.toString();
    }

    String? explanation;
    if (json['explanation'] is String) {
      explanation = json['explanation'];
    } else if (json['explanation'] is Map) {
      explanation = json['explanation']['text']?.toString() ??
                    json['explanation']['value']?.toString();
    }

    String? solutionText;
    if (json['solution_text'] is String) {
      solutionText = json['solution_text'];
    } else if (json['solution_text'] is Map) {
      solutionText = json['solution_text']['text']?.toString() ??
                     json['solution_text']['value']?.toString();
    }

    String? keyInsight;
    if (json['key_insight'] is String) {
      keyInsight = json['key_insight'];
    } else if (json['key_insight'] is Map) {
      keyInsight = json['key_insight']['text']?.toString() ??
                   json['key_insight']['value']?.toString();
    }

    return PracticeAnswerResult(
      isCorrect: json['is_correct'] ?? false,
      studentAnswer: submittedAnswer ?? parsedStudentAnswer,
      correctAnswer: correctAnswer,
      correctAnswerText: correctAnswerText,
      explanation: explanation,
      solutionText: solutionText,
      solutionSteps: solutionSteps,
      keyInsight: keyInsight,
      distractorAnalysis: distractorAnalysis,
      commonMistakes: commonMistakes,
      thetaDelta: (json['theta_delta'] ?? 0.0).toDouble(),
      thetaMultiplier: (json['theta_multiplier'] ?? 0.5).toDouble(),
    );
  }
}

/// Weak spot data returned in chapter practice completion response
class WeakSpotDetected {
  final String nodeId;
  final String title;
  final double score;
  final String nodeState;
  final String? capsuleId;
  final String severityLevel;

  WeakSpotDetected({
    required this.nodeId,
    required this.title,
    required this.score,
    required this.nodeState,
    this.capsuleId,
    required this.severityLevel,
  });

  factory WeakSpotDetected.fromJson(Map<String, dynamic> json) {
    return WeakSpotDetected(
      nodeId: json['nodeId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      score: (json['score'] ?? 0.0).toDouble(),
      nodeState: json['nodeState']?.toString() ?? 'active',
      capsuleId: json['capsuleId']?.toString(),
      severityLevel: json['severityLevel']?.toString() ?? 'medium',
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
  final WeakSpotDetected? weakSpot;

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
    this.weakSpot,
  });

  factory PracticeSessionSummary.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] is Map ? json['summary'] as Map<String, dynamic> : <String, dynamic>{};
    final updatedStats = json['updated_stats'] is Map ? json['updated_stats'] as Map<String, dynamic> : <String, dynamic>{};

    WeakSpotDetected? weakSpot;
    if (json['weakSpot'] is Map) {
      weakSpot = WeakSpotDetected.fromJson(json['weakSpot'] as Map<String, dynamic>);
    }

    return PracticeSessionSummary(
      sessionId: summary['session_id']?.toString() ?? '',
      chapterKey: summary['chapter_key']?.toString() ?? '',
      chapterName: summary['chapter_name']?.toString() ?? '',
      subject: summary['subject']?.toString() ?? '',
      totalQuestions: summary['total_questions'] ?? 0,
      questionsAnswered: summary['questions_answered'] ?? 0,
      correctCount: summary['correct_count'] ?? 0,
      accuracy: (summary['accuracy'] ?? 0.0).toDouble(),
      totalTimeSeconds: summary['total_time_seconds'] ?? 0,
      thetaMultiplier: (summary['theta_multiplier'] ?? 0.5).toDouble(),
      overallTheta: (updatedStats['overall_theta'] ?? 0.0).toDouble(),
      overallPercentile: (updatedStats['overall_percentile'] ?? 50.0).toDouble(),
      weakSpot: weakSpot,
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
  final List<SolutionStep> solutionSteps;
  final String? keyInsight;
  final Map<String, String>? distractorAnalysis;
  final List<String>? commonMistakes;
  final String? explanation;
  final String? difficulty;

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
    this.keyInsight,
    this.distractorAnalysis,
    this.commonMistakes,
    this.explanation,
    this.difficulty,
  });

  factory PracticeQuestionResult.fromJson(Map<String, dynamic> json) {
    // Parse options
    List<PracticeOption> parsedOptions = [];
    final rawOptions = json['options'];
    if (rawOptions != null && rawOptions is List) {
      parsedOptions = rawOptions
          .where((o) => o != null && o is Map<String, dynamic>)
          .map((o) => PracticeOption.fromJson(o as Map<String, dynamic>))
          .toList();
    }

    // Parse solution steps
    List<SolutionStep> solutionSteps = [];
    if (json['solution_steps'] != null && json['solution_steps'] is List) {
      solutionSteps = (json['solution_steps'] as List)
          .map((step) => SolutionStep.fromJson(step))
          .toList();
    }

    // Handle student_answer - could be String or Map
    String studentAnswer = '';
    final rawStudentAnswer = json['student_answer'];
    if (rawStudentAnswer is String) {
      studentAnswer = rawStudentAnswer;
    } else if (rawStudentAnswer is Map) {
      studentAnswer = rawStudentAnswer['option_id']?.toString() ??
                      rawStudentAnswer['value']?.toString() ?? '';
    }

    // Handle correct_answer - could be String or Map
    String correctAnswer = '';
    final rawCorrectAnswer = json['correct_answer'];
    if (rawCorrectAnswer is String) {
      correctAnswer = rawCorrectAnswer;
    } else if (rawCorrectAnswer is Map) {
      correctAnswer = rawCorrectAnswer['option_id']?.toString() ??
                      rawCorrectAnswer['value']?.toString() ?? '';
    }

    // Safely extract string fields that could potentially be Maps
    String questionId = '';
    if (json['question_id'] is String) {
      questionId = json['question_id'];
    } else if (json['question_id'] != null) {
      questionId = json['question_id'].toString();
    }

    String questionText = '';
    if (json['question_text'] is String) {
      questionText = json['question_text'];
    } else if (json['question_text'] is Map) {
      questionText = json['question_text']['text']?.toString() ??
                     json['question_text']['value']?.toString() ?? '';
    } else if (json['question_text'] != null) {
      questionText = json['question_text'].toString();
    }

    String? questionTextHtml;
    if (json['question_text_html'] is String) {
      questionTextHtml = json['question_text_html'];
    } else if (json['question_text_html'] is Map) {
      questionTextHtml = json['question_text_html']['html']?.toString() ??
                         json['question_text_html']['value']?.toString();
    }

    String? solutionText;
    if (json['solution_text'] is String) {
      solutionText = json['solution_text'];
    } else if (json['solution_text'] is Map) {
      solutionText = json['solution_text']['text']?.toString() ??
                     json['solution_text']['value']?.toString();
    }

    // Parse distractor_analysis map
    Map<String, String>? distractorAnalysis;
    if (json['distractor_analysis'] != null && json['distractor_analysis'] is Map) {
      distractorAnalysis = Map<String, String>.from(
        (json['distractor_analysis'] as Map).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      );
    }

    // Parse common_mistakes list
    List<String>? commonMistakes;
    if (json['common_mistakes'] != null && json['common_mistakes'] is List) {
      commonMistakes = (json['common_mistakes'] as List)
          .map((m) => m.toString())
          .toList();
    }

    // Parse key_insight
    String? keyInsight;
    if (json['key_insight'] is String) {
      keyInsight = json['key_insight'];
    } else if (json['key_insight'] is Map) {
      keyInsight = json['key_insight']['text']?.toString() ??
                   json['key_insight']['value']?.toString();
    }

    // Parse explanation
    String? explanation;
    if (json['explanation'] is String) {
      explanation = json['explanation'];
    } else if (json['explanation'] is Map) {
      explanation = json['explanation']['text']?.toString() ??
                    json['explanation']['value']?.toString();
    }

    return PracticeQuestionResult(
      questionId: questionId,
      position: json['position'] ?? 0,
      questionText: questionText,
      questionTextHtml: questionTextHtml,
      options: parsedOptions,
      studentAnswer: studentAnswer,
      correctAnswer: correctAnswer,
      isCorrect: json['is_correct'] ?? false,
      timeTakenSeconds: json['time_taken_seconds'] ?? 0,
      solutionText: solutionText,
      solutionSteps: solutionSteps,
      keyInsight: keyInsight,
      distractorAnalysis: distractorAnalysis,
      commonMistakes: commonMistakes,
      explanation: explanation,
      difficulty: json['difficulty']?.toString(),
    );
  }
}
