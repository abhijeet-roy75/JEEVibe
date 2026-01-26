/// Mock Test Models
/// Data models for JEE Main mock test feature

import 'assessment_question.dart' show QuestionOption;

/// Mock Test Template (available tests)
class MockTestTemplate {
  final String templateId;
  final String name;
  final String description;
  final int questionCount;
  final int durationSeconds;
  final List<MockTestSection> sections;
  final bool completed;
  final MockTestStats? stats;

  MockTestTemplate({
    required this.templateId,
    required this.name,
    required this.description,
    required this.questionCount,
    required this.durationSeconds,
    required this.sections,
    this.completed = false,
    this.stats,
  });

  factory MockTestTemplate.fromJson(Map<String, dynamic> json) {
    return MockTestTemplate(
      templateId: json['template_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      questionCount: json['question_count'] as int? ?? 90,
      durationSeconds: json['duration_seconds'] as int? ?? 10800,
      sections: (json['sections'] as List? ?? [])
          .map((s) => MockTestSection.fromJson(s as Map<String, dynamic>))
          .toList(),
      completed: json['completed'] as bool? ?? false,
      stats: json['stats'] != null
          ? MockTestStats.fromJson(json['stats'] as Map<String, dynamic>)
          : null,
    );
  }

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return minutes > 0 ? '$hours hr $minutes min' : '$hours hours';
    }
    return '$minutes minutes';
  }
}

/// Mock Test Section
class MockTestSection {
  final String name;
  final String subject;
  final int questionCount;
  final int mcqCount;
  final int nvqCount;
  final int startIndex;
  final int endIndex;

  MockTestSection({
    required this.name,
    required this.subject,
    required this.questionCount,
    required this.mcqCount,
    required this.nvqCount,
    required this.startIndex,
    required this.endIndex,
  });

  factory MockTestSection.fromJson(Map<String, dynamic> json) {
    return MockTestSection(
      name: json['name'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      questionCount: json['question_count'] as int? ?? 30,
      mcqCount: json['mcq_count'] as int? ?? 20,
      nvqCount: json['nvq_count'] as int? ?? 10,
      startIndex: json['start_index'] as int? ?? 0,
      endIndex: json['end_index'] as int? ?? 29,
    );
  }
}

/// Mock Test Stats
class MockTestStats {
  final double avgDifficulty;
  final double physicsAvgDifficulty;
  final double chemistryAvgDifficulty;
  final double mathematicsAvgDifficulty;

  MockTestStats({
    required this.avgDifficulty,
    required this.physicsAvgDifficulty,
    required this.chemistryAvgDifficulty,
    required this.mathematicsAvgDifficulty,
  });

  factory MockTestStats.fromJson(Map<String, dynamic> json) {
    return MockTestStats(
      avgDifficulty: _parseDouble(json['avg_difficulty']),
      physicsAvgDifficulty: _parseDouble(json['physics_avg_difficulty']),
      chemistryAvgDifficulty: _parseDouble(json['chemistry_avg_difficulty']),
      mathematicsAvgDifficulty: _parseDouble(json['mathematics_avg_difficulty']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.9;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.9;
    return 0.9;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Mock Test Question
class MockTestQuestion {
  final int questionNumber;
  final int sectionIndex;
  final String questionId;
  final String questionType; // 'mcq_single' or 'numerical'
  final String subject;
  final String? chapter;
  final String questionText;
  final String? questionTextHtml;
  final String? imageUrl;
  final List<QuestionOption>? options;
  final int marksCorrect;
  final int marksIncorrect;

  // For results view only
  final String? correctAnswer;
  final String? solutionText;
  final List<SolutionStep>? solutionSteps;
  final String? keyInsight;

  MockTestQuestion({
    required this.questionNumber,
    required this.sectionIndex,
    required this.questionId,
    required this.questionType,
    required this.subject,
    this.chapter,
    required this.questionText,
    this.questionTextHtml,
    this.imageUrl,
    this.options,
    required this.marksCorrect,
    required this.marksIncorrect,
    this.correctAnswer,
    this.solutionText,
    this.solutionSteps,
    this.keyInsight,
  });

  factory MockTestQuestion.fromJson(Map<String, dynamic> json) {
    List<QuestionOption>? options;
    if (json['options'] != null) {
      options = (json['options'] as List).map((opt) {
        if (opt is Map<String, dynamic>) {
          return QuestionOption.fromJson(opt);
        } else if (opt is String) {
          // Handle case where option is just a string
          return QuestionOption(optionId: '', text: opt, html: opt);
        } else {
          return QuestionOption(optionId: '', text: opt.toString(), html: opt.toString());
        }
      }).toList();
    }

    List<SolutionStep>? solutionSteps;
    if (json['solution_steps'] != null) {
      solutionSteps = (json['solution_steps'] as List).map((s) {
        if (s is Map<String, dynamic>) {
          return SolutionStep.fromJson(s);
        } else {
          return SolutionStep(stepNumber: 0, description: s.toString());
        }
      }).toList();
    }

    return MockTestQuestion(
      questionNumber: _parseInt(json['question_number']),
      sectionIndex: _parseInt(json['section_index']),
      questionId: json['question_id'] as String? ?? '',
      questionType: json['question_type'] as String? ?? 'mcq_single',
      subject: json['subject'] as String? ?? '',
      chapter: json['chapter'] as String?,
      questionText: json['question_text'] as String? ?? '',
      questionTextHtml: json['question_text_html'] as String?,
      imageUrl: json['image_url'] as String?,
      options: options,
      marksCorrect: _parseInt(json['marks_correct']) == 0 ? 4 : _parseInt(json['marks_correct']),
      marksIncorrect: _parseInt(json['marks_incorrect']) == 0 ? -1 : _parseInt(json['marks_incorrect']),
      correctAnswer: json['correct_answer'] as String?,
      solutionText: json['solution_text'] as String?,
      solutionSteps: solutionSteps,
      keyInsight: json['key_insight'] as String?,
    );
  }

  bool get isMcq => questionType == 'mcq_single' || questionType == 'mcq';
  bool get isNumerical => questionType == 'numerical' || questionType == 'integer';
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}

/// Solution Step
class SolutionStep {
  final int stepNumber;
  final String description;
  final String? formula;

  SolutionStep({
    required this.stepNumber,
    required this.description,
    this.formula,
  });

  factory SolutionStep.fromJson(Map<String, dynamic> json) {
    return SolutionStep(
      stepNumber: json['step_number'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      formula: json['formula'] as String?,
    );
  }
}

/// Question State - JEE CBT style
enum QuestionState {
  notVisited,       // Gray - Never opened
  notAnswered,      // Red - Visited but no answer
  answered,         // Green - Answer selected
  markedForReview,  // Purple - Flagged, no answer
  answeredMarked,   // Purple+Green - Has answer AND flagged
}

extension QuestionStateExtension on QuestionState {
  static QuestionState fromString(String value) {
    switch (value) {
      case 'not_visited':
        return QuestionState.notVisited;
      case 'not_answered':
        return QuestionState.notAnswered;
      case 'answered':
        return QuestionState.answered;
      case 'marked_for_review':
        return QuestionState.markedForReview;
      case 'answered_marked':
        return QuestionState.answeredMarked;
      default:
        return QuestionState.notVisited;
    }
  }

  String get apiValue {
    switch (this) {
      case QuestionState.notVisited:
        return 'not_visited';
      case QuestionState.notAnswered:
        return 'not_answered';
      case QuestionState.answered:
        return 'answered';
      case QuestionState.markedForReview:
        return 'marked_for_review';
      case QuestionState.answeredMarked:
        return 'answered_marked';
    }
  }
}

/// Active Mock Test Session
class MockTestSession {
  final String testId;
  final String templateId;
  final String templateName;
  final DateTime startedAt;
  final DateTime expiresAt;
  final int durationSeconds;
  final List<MockTestSection> sections;
  final List<MockTestQuestion> questions;
  final Map<int, QuestionState> questionStates;
  final Map<int, MockTestResponse> responses;
  int timeRemainingSeconds;

  MockTestSession({
    required this.testId,
    required this.templateId,
    required this.templateName,
    required this.startedAt,
    required this.expiresAt,
    required this.durationSeconds,
    required this.sections,
    required this.questions,
    required this.questionStates,
    required this.responses,
    required this.timeRemainingSeconds,
  });

  factory MockTestSession.fromJson(Map<String, dynamic> json) {
    // Parse question states
    final questionStatesMap = <int, QuestionState>{};
    if (json['question_states'] != null) {
      (json['question_states'] as Map<String, dynamic>).forEach((key, value) {
        final qNum = int.tryParse(key) ?? 0;
        questionStatesMap[qNum] = QuestionStateExtension.fromString(value as String);
      });
    }

    // Parse responses
    final responsesMap = <int, MockTestResponse>{};
    if (json['responses'] != null) {
      (json['responses'] as Map<String, dynamic>).forEach((key, value) {
        final qNum = int.tryParse(key) ?? 0;
        responsesMap[qNum] = MockTestResponse.fromJson(value as Map<String, dynamic>);
      });
    }

    return MockTestSession(
      testId: json['test_id'] as String? ?? '',
      templateId: json['template_id'] as String? ?? '',
      templateName: json['template_name'] as String? ?? '',
      startedAt: _parseDateTime(json['started_at']),
      expiresAt: _parseDateTime(json['expires_at']),
      durationSeconds: json['duration_seconds'] as int? ?? 10800,
      sections: (json['sections'] as List? ?? [])
          .map((s) => MockTestSection.fromJson(s as Map<String, dynamic>))
          .toList(),
      questions: (json['questions'] as List? ?? [])
          .map((q) => MockTestQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      questionStates: questionStatesMap,
      responses: responsesMap,
      timeRemainingSeconds: json['time_remaining_seconds'] as int? ?? 10800,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  // Computed properties
  int get totalQuestions => questions.length;
  int get answeredCount => questionStates.values
      .where((s) => s == QuestionState.answered || s == QuestionState.answeredMarked)
      .length;
  int get markedCount => questionStates.values
      .where((s) => s == QuestionState.markedForReview || s == QuestionState.answeredMarked)
      .length;
  int get notVisitedCount => questionStates.values
      .where((s) => s == QuestionState.notVisited)
      .length;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Response for a single question
class MockTestResponse {
  final String? answer;
  final bool markedForReview;
  final int timeSpentSeconds;

  MockTestResponse({
    this.answer,
    this.markedForReview = false,
    this.timeSpentSeconds = 0,
  });

  factory MockTestResponse.fromJson(Map<String, dynamic> json) {
    return MockTestResponse(
      answer: json['answer'] as String?,
      markedForReview: json['marked_for_review'] as bool? ?? false,
      timeSpentSeconds: json['time_spent_seconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'answer': answer,
    'marked_for_review': markedForReview,
    'time_spent_seconds': timeSpentSeconds,
  };
}

/// Mock Test Result
class MockTestResult {
  final String testId;
  final int score;
  final int maxScore;
  final double percentile;
  final String accuracy;
  final int correct;
  final int incorrect;
  final int unattempted;
  final Map<String, SubjectScore> subjectScores;
  final int timeTakenSeconds;
  final bool isAutoSubmit;

  MockTestResult({
    required this.testId,
    required this.score,
    required this.maxScore,
    required this.percentile,
    required this.accuracy,
    required this.correct,
    required this.incorrect,
    required this.unattempted,
    required this.subjectScores,
    required this.timeTakenSeconds,
    this.isAutoSubmit = false,
  });

  factory MockTestResult.fromJson(Map<String, dynamic> json) {
    final subjectScoresMap = <String, SubjectScore>{};
    if (json['subject_scores'] != null) {
      (json['subject_scores'] as Map<String, dynamic>).forEach((key, value) {
        subjectScoresMap[key] = SubjectScore.fromJson(value as Map<String, dynamic>);
      });
    }

    return MockTestResult(
      testId: json['test_id'] as String? ?? '',
      score: json['score'] as int? ?? 0,
      maxScore: json['max_score'] as int? ?? 300,
      percentile: _parseDouble(json['percentile']),
      accuracy: json['accuracy']?.toString() ?? '0',
      correct: json['correct'] as int? ?? 0,
      incorrect: json['incorrect'] as int? ?? 0,
      unattempted: json['unattempted'] as int? ?? 0,
      subjectScores: subjectScoresMap,
      timeTakenSeconds: json['time_taken_seconds'] as int? ?? 0,
      isAutoSubmit: json['is_auto_submit'] as bool? ?? false,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String get formattedTime {
    final hours = timeTakenSeconds ~/ 3600;
    final minutes = (timeTakenSeconds % 3600) ~/ 60;
    final seconds = timeTakenSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }
}

/// Subject Score
class SubjectScore {
  final int score;
  final int correct;
  final int incorrect;
  final int unattempted;
  final int total;

  SubjectScore({
    required this.score,
    required this.correct,
    required this.incorrect,
    required this.unattempted,
    required this.total,
  });

  factory SubjectScore.fromJson(Map<String, dynamic> json) {
    return SubjectScore(
      score: json['score'] as int? ?? 0,
      correct: json['correct'] as int? ?? 0,
      incorrect: json['incorrect'] as int? ?? 0,
      unattempted: json['unattempted'] as int? ?? 0,
      total: json['total'] as int? ?? 30,
    );
  }

  double get accuracy => total > 0 ? (correct / total) * 100 : 0;
}

/// Mock Test History Item
class MockTestHistoryItem {
  final String testId;
  final String templateId;
  final String templateName;
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? score;
  final int? maxScore;
  final double? percentile;
  final String? accuracy;
  final int? correctCount;
  final int? incorrectCount;
  final int? unattemptedCount;
  final int? timeTakenSeconds;
  final Map<String, SubjectScore>? subjectScores;

  MockTestHistoryItem({
    required this.testId,
    required this.templateId,
    required this.templateName,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.score,
    this.maxScore,
    this.percentile,
    this.accuracy,
    this.correctCount,
    this.incorrectCount,
    this.unattemptedCount,
    this.timeTakenSeconds,
    this.subjectScores,
  });

  factory MockTestHistoryItem.fromJson(Map<String, dynamic> json) {
    Map<String, SubjectScore>? subjectScoresMap;
    if (json['subject_scores'] != null) {
      subjectScoresMap = {};
      (json['subject_scores'] as Map<String, dynamic>).forEach((key, value) {
        subjectScoresMap![key] = SubjectScore.fromJson(value as Map<String, dynamic>);
      });
    }

    return MockTestHistoryItem(
      testId: json['test_id'] as String? ?? '',
      templateId: json['template_id'] as String? ?? '',
      templateName: json['template_name'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      startedAt: _parseDateTime(json['started_at']),
      completedAt: _parseDateTime(json['completed_at']),
      score: json['score'] as int?,
      maxScore: json['max_score'] as int?,
      percentile: _parseDoubleNullable(json['percentile']),
      accuracy: json['accuracy']?.toString(),
      correctCount: json['correct_count'] as int?,
      incorrectCount: json['incorrect_count'] as int?,
      unattemptedCount: json['unattempted_count'] as int?,
      timeTakenSeconds: json['time_taken_seconds'] as int?,
      subjectScores: subjectScoresMap,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get isAbandoned => status == 'abandoned';
}

/// Usage info for mock tests
class MockTestUsage {
  final int used;
  final int limit;
  final int remaining;

  MockTestUsage({
    required this.used,
    required this.limit,
    required this.remaining,
  });

  factory MockTestUsage.fromJson(Map<String, dynamic> json) {
    return MockTestUsage(
      used: json['used'] as int? ?? 0,
      limit: json['limit'] as int? ?? 1,
      remaining: json['remaining'] as int? ?? 1,
    );
  }

  bool get hasUnlimited => limit == -1;
  bool get hasRemaining => hasUnlimited || remaining > 0;
}
