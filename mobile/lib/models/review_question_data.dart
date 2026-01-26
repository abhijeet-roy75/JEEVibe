/// Review Question Data Model
///
/// Common model for question review that can be used by both
/// Daily Quiz and Chapter Practice review screens.
import 'daily_quiz_question.dart' show SolutionStep;
import 'chapter_practice_models.dart' show PracticeQuestionResult, PracticeOption;
import 'mock_test_models.dart' show MockTestQuestion, MockTestOption;

/// Common data model for reviewing questions
class ReviewQuestionData {
  final String questionId;
  final int position;
  final String questionText;
  final String? questionTextHtml;
  final List<ReviewOptionData> options;
  final String studentAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final int? timeTakenSeconds;
  final String? solutionText;
  final List<SolutionStep> solutionSteps;
  final String? subject;
  final String? chapter;
  final String? difficulty;
  final String? imageUrl;
  final String? keyInsight;
  final Map<String, String>? distractorAnalysis;
  final List<String>? commonMistakes;
  final String? questionType;

  ReviewQuestionData({
    required this.questionId,
    required this.position,
    required this.questionText,
    this.questionTextHtml,
    required this.options,
    required this.studentAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    this.timeTakenSeconds,
    this.solutionText,
    this.solutionSteps = const [],
    this.subject,
    this.chapter,
    this.difficulty,
    this.imageUrl,
    this.keyInsight,
    this.distractorAnalysis,
    this.commonMistakes,
    this.questionType,
  });

  /// Safe integer parsing helper
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Create from Daily Quiz API response (Map<String, dynamic>)
  factory ReviewQuestionData.fromDailyQuizMap(Map<String, dynamic> json) {
    // Parse options
    List<ReviewOptionData> options = [];
    if (json['options'] != null && json['options'] is List) {
      options = (json['options'] as List)
          .where((opt) => opt is Map<String, dynamic>)
          .map((opt) => ReviewOptionData.fromMap(opt as Map<String, dynamic>))
          .toList();
    }

    // Parse solution steps
    List<SolutionStep> solutionSteps = [];
    if (json['solution_steps'] != null && json['solution_steps'] is List) {
      solutionSteps = (json['solution_steps'] as List)
          .map((step) => SolutionStep.fromJson(step))
          .toList();
    }

    // Parse distractor analysis
    Map<String, String>? distractorAnalysis;
    if (json['distractor_analysis'] != null && json['distractor_analysis'] is Map) {
      distractorAnalysis = Map<String, String>.from(
        (json['distractor_analysis'] as Map).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      );
    }

    // Parse common mistakes
    List<String>? commonMistakes;
    if (json['common_mistakes'] != null && json['common_mistakes'] is List) {
      commonMistakes = (json['common_mistakes'] as List)
          .map((m) => m.toString())
          .toList();
    }

    return ReviewQuestionData(
      questionId: json['question_id'] as String? ?? '',
      position: json['position'] as int? ?? 0,
      questionText: json['question_text'] as String? ?? '',
      questionTextHtml: json['question_text_html'] as String?,
      options: options,
      studentAnswer: json['student_answer'] as String? ?? '',
      correctAnswer: json['correct_answer'] as String? ?? '',
      isCorrect: json['is_correct'] as bool? ?? false,
      timeTakenSeconds: json['time_taken_seconds'] as int?,
      solutionText: json['solution_text'] as String?,
      solutionSteps: solutionSteps,
      subject: json['subject'] as String?,
      chapter: json['chapter'] as String?,
      difficulty: json['difficulty'] as String?,
      imageUrl: json['image_url'] as String?,
      keyInsight: json['key_insight'] as String?,
      distractorAnalysis: distractorAnalysis,
      commonMistakes: commonMistakes,
      questionType: json['question_type'] as String?,
    );
  }

  /// Create from Chapter Practice result
  factory ReviewQuestionData.fromChapterPractice(
    PracticeQuestionResult result, {
    String? subject,
    String? chapter,
  }) {
    return ReviewQuestionData(
      questionId: result.questionId,
      position: result.position,
      questionText: result.questionText,
      questionTextHtml: result.questionTextHtml,
      options: result.options
          .map((opt) => ReviewOptionData.fromPracticeOption(opt))
          .toList(),
      studentAnswer: result.studentAnswer,
      correctAnswer: result.correctAnswer,
      isCorrect: result.isCorrect,
      timeTakenSeconds: result.timeTakenSeconds,
      solutionText: result.solutionText ?? result.explanation,
      solutionSteps: result.solutionSteps,
      subject: subject,
      chapter: chapter,
      difficulty: result.difficulty,
      keyInsight: result.keyInsight,
      distractorAnalysis: result.distractorAnalysis,
      commonMistakes: result.commonMistakes,
    );
  }

  /// Create from Mock Test question with results
  /// The question map comes from the backend's getTestResults which merges
  /// template questions with user responses
  factory ReviewQuestionData.fromMockTestQuestion(Map<String, dynamic> json) {
    // Parse options - handle both Map format and String format
    List<ReviewOptionData> options = [];
    if (json['options'] != null && json['options'] is List) {
      final optionsList = json['options'] as List;
      for (int i = 0; i < optionsList.length; i++) {
        final opt = optionsList[i];
        if (opt is Map<String, dynamic>) {
          options.add(ReviewOptionData.fromMap(opt));
        } else if (opt is String) {
          // Convert string to ReviewOptionData with generated option_id (A, B, C, D)
          final optionId = String.fromCharCode(65 + i); // 65 is 'A' in ASCII
          options.add(ReviewOptionData(
            optionId: optionId,
            text: opt,
            html: null,
          ));
        } else {
          print('[ReviewQuestionData] Skipping invalid option type: ${opt.runtimeType}, value: $opt');
        }
      }
    }

    // Parse solution steps
    List<SolutionStep> solutionSteps = [];
    if (json['solution_steps'] != null && json['solution_steps'] is List) {
      solutionSteps = (json['solution_steps'] as List)
          .map((step) => SolutionStep.fromJson(step))
          .toList();
    }

    // Parse distractor analysis
    Map<String, String>? distractorAnalysis;
    if (json['distractor_analysis'] != null && json['distractor_analysis'] is Map) {
      distractorAnalysis = Map<String, String>.from(
        (json['distractor_analysis'] as Map).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      );
    }

    // Parse common mistakes
    List<String>? commonMistakes;
    if (json['common_mistakes'] != null && json['common_mistakes'] is List) {
      commonMistakes = (json['common_mistakes'] as List)
          .map((m) => m.toString())
          .toList();
    }

    // Question number is 1-indexed in mock tests, position is 0-indexed
    final questionNumber = _parseInt(json['question_number']) ?? 1;

    return ReviewQuestionData(
      questionId: json['question_id'] as String? ?? '',
      position: questionNumber - 1,
      questionText: json['question_text'] as String? ?? '',
      questionTextHtml: json['question_text_html'] as String?,
      options: options,
      studentAnswer: (json['user_answer'] ?? json['student_answer'] ?? '').toString(),
      correctAnswer: (json['correct_answer'] ?? '').toString(),
      isCorrect: json['is_correct'] as bool? ?? false,
      timeTakenSeconds: _parseInt(json['time_spent']) ?? _parseInt(json['time_taken_seconds']),
      solutionText: json['solution_text'] as String?,
      solutionSteps: solutionSteps,
      subject: json['subject'] as String?,
      chapter: json['chapter'] as String?,
      difficulty: json['difficulty'] as String?,
      imageUrl: json['image_url'] as String?,
      keyInsight: json['key_insight'] as String?,
      distractorAnalysis: distractorAnalysis,
      commonMistakes: commonMistakes,
      questionType: json['question_type'] as String?,
    );
  }
}

/// Common option data for review
class ReviewOptionData {
  final String optionId;
  final String text;
  final String? html;

  ReviewOptionData({
    required this.optionId,
    required this.text,
    this.html,
  });

  factory ReviewOptionData.fromMap(Map<String, dynamic> json) {
    return ReviewOptionData(
      optionId: json['option_id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      html: json['html'] as String?,
    );
  }

  factory ReviewOptionData.fromPracticeOption(PracticeOption option) {
    return ReviewOptionData(
      optionId: option.optionId,
      text: option.text,
      html: option.html,
    );
  }
}
