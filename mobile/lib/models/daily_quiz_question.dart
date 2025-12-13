/// Daily Quiz Question Model
/// Represents a question in the daily adaptive quiz
import 'assessment_question.dart' show QuestionOption;

class DailyQuizQuestion {
  final String questionId;
  final int position;
  final String subject;
  final String chapter;
  final String chapterKey;
  final String questionType; // 'mcq_single' or 'numerical'
  final String questionText;
  final String? questionTextHtml;
  final String? questionLatex;
  final List<QuestionOption>? options; // For MCQ questions
  final String? imageUrl; // SVG image URL
  final int? timeEstimate;
  final String? selectionReason; // 'exploration', 'deliberate_practice', 'review'
  final bool answered;
  final String? studentAnswer;
  final bool? isCorrect;
  final int? timeTakenSeconds;

  DailyQuizQuestion({
    required this.questionId,
    required this.position,
    required this.subject,
    required this.chapter,
    required this.chapterKey,
    required this.questionType,
    required this.questionText,
    this.questionTextHtml,
    this.questionLatex,
    this.options,
    this.imageUrl,
    this.timeEstimate,
    this.selectionReason,
    this.answered = false,
    this.studentAnswer,
    this.isCorrect,
    this.timeTakenSeconds,
  });

  factory DailyQuizQuestion.fromJson(Map<String, dynamic> json) {
    return DailyQuizQuestion(
      questionId: json['question_id'] as String,
      position: json['position'] as int? ?? 0,
      subject: json['subject'] as String? ?? '',
      chapter: json['chapter'] as String? ?? '',
      chapterKey: json['chapter_key'] as String? ?? '',
      questionType: json['question_type'] as String? ?? 'mcq_single',
      questionText: json['question_text'] as String? ?? '',
      questionTextHtml: json['question_text_html'] as String?,
      questionLatex: json['question_latex'] as String?,
      options: json['options'] != null
          ? (json['options'] as List)
              .map((opt) => QuestionOption.fromJson(opt as Map<String, dynamic>))
              .toList()
          : null,
      imageUrl: json['image_url'] as String?,
      timeEstimate: json['time_estimate'] as int?,
      selectionReason: json['selection_reason'] as String?,
      answered: json['answered'] as bool? ?? false,
      studentAnswer: json['student_answer'] as String?,
      isCorrect: json['is_correct'] as bool?,
      timeTakenSeconds: json['time_taken_seconds'] as int?,
    );
  }

  bool get isMcq => questionType == 'mcq_single';
  bool get isNumerical => questionType == 'numerical';
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}

/// Daily Quiz Model
class DailyQuiz {
  final String quizId;
  final int quizNumber;
  final String learningPhase; // 'exploration' or 'exploitation'
  final List<DailyQuizQuestion> questions;
  final String? generatedAt;
  final bool isRecoveryQuiz;

  DailyQuiz({
    required this.quizId,
    required this.quizNumber,
    required this.learningPhase,
    required this.questions,
    this.generatedAt,
    this.isRecoveryQuiz = false,
  });

  factory DailyQuiz.fromJson(Map<String, dynamic> json) {
    return DailyQuiz(
      quizId: json['quiz_id'] as String,
      quizNumber: json['quiz_number'] as int? ?? 0,
      learningPhase: json['learning_phase'] as String? ?? 'exploration',
      questions: (json['questions'] as List? ?? [])
          .map((q) => DailyQuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      generatedAt: json['generated_at'] as String?,
      isRecoveryQuiz: json['is_recovery_quiz'] as bool? ?? false,
    );
  }

  int get totalQuestions => questions.length;
  int get answeredCount => questions.where((q) => q.answered).length;
  int get correctCount => questions.where((q) => q.isCorrect == true).length;
}

/// Answer Feedback Model
class AnswerFeedback {
  final String questionId;
  final bool isCorrect;
  final String? correctAnswer;
  final String? correctAnswerText;
  final String? explanation;
  final String? solutionText;
  final List<SolutionStep>? solutionSteps;
  final int timeTakenSeconds;
  final String? studentAnswer;

  AnswerFeedback({
    required this.questionId,
    required this.isCorrect,
    this.correctAnswer,
    this.correctAnswerText,
    this.explanation,
    this.solutionText,
    this.solutionSteps,
    required this.timeTakenSeconds,
    this.studentAnswer,
  });

  factory AnswerFeedback.fromJson(Map<String, dynamic> json) {
    return AnswerFeedback(
      questionId: json['question_id'] as String,
      isCorrect: json['is_correct'] as bool,
      correctAnswer: json['correct_answer'] as String?,
      correctAnswerText: json['correct_answer_text'] as String?,
      explanation: json['explanation'] as String?,
      solutionText: json['solution_text'] as String?,
      solutionSteps: json['solution_steps'] != null
          ? (json['solution_steps'] as List)
              .map((step) => SolutionStep.fromJson(step))
              .toList()
          : null,
      timeTakenSeconds: json['time_taken_seconds'] as int,
      studentAnswer: json['student_answer'] as String?,
    );
  }
}

/// Solution Step Model
class SolutionStep {
  final int? stepNumber;
  final String? description;
  final String? explanation;
  final String? formula;
  final String? calculation;

  SolutionStep({
    this.stepNumber,
    this.description,
    this.explanation,
    this.formula,
    this.calculation,
  });

  factory SolutionStep.fromJson(dynamic json) {
    // Handle both Map and String formats
    if (json is String) {
      return SolutionStep(
        description: json,
      );
    }
    
    if (json is! Map<String, dynamic>) {
      return SolutionStep(description: json.toString());
    }
    
    // Handle different field names for solution steps
    String? text;
    if (json['description'] != null) {
      text = json['description'] as String?;
    } else if (json['explanation'] != null) {
      text = json['explanation'] as String?;
    } else if (json['step'] != null) {
      text = json['step'] as String?;
    } else if (json['text'] != null) {
      text = json['text'] as String?;
    }

    return SolutionStep(
      stepNumber: json['step_number'] as int? ?? json['number'] as int? ?? json['stepNumber'] as int?,
      description: text ?? json['description'] as String?,
      explanation: json['explanation'] as String?,
      formula: json['formula'] as String?,
      calculation: json['calculation'] as String?,
    );
  }

  String get displayText {
    return description ?? explanation ?? '';
  }
}

