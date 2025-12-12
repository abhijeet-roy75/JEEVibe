/// Assessment Question Model
/// Represents a question from the initial assessment
class AssessmentQuestion {
  final String questionId;
  final String subject;
  final String chapter;
  final String questionType; // 'mcq_single' or 'numerical'
  final String questionText;
  final String? questionTextHtml;
  final String? questionLatex;
  final List<QuestionOption>? options; // For MCQ questions
  final String? imageUrl; // SVG image URL
  final Map<String, dynamic>? irtParameters;
  final String? difficulty;
  final double? difficultyIrt;

  AssessmentQuestion({
    required this.questionId,
    required this.subject,
    required this.chapter,
    required this.questionType,
    required this.questionText,
    this.questionTextHtml,
    this.questionLatex,
    this.options,
    this.imageUrl,
    this.irtParameters,
    this.difficulty,
    this.difficultyIrt,
  });

  factory AssessmentQuestion.fromJson(Map<String, dynamic> json) {
    return AssessmentQuestion(
      questionId: json['question_id'] as String,
      subject: json['subject'] as String,
      chapter: json['chapter'] as String,
      questionType: json['question_type'] as String,
      questionText: json['question_text'] as String? ?? '',
      questionTextHtml: json['question_text_html'] as String?,
      questionLatex: json['question_latex'] as String?,
      options: json['options'] != null
          ? (json['options'] as List)
              .map((opt) => QuestionOption.fromJson(opt as Map<String, dynamic>))
              .toList()
          : null,
      imageUrl: json['image_url'] as String?,
      irtParameters: json['irt_parameters'] as Map<String, dynamic>?,
      difficulty: json['difficulty'] as String?,
      difficultyIrt: json['difficulty_irt'] != null
          ? (json['difficulty_irt'] as num).toDouble()
          : null,
    );
  }

  bool get isMcq => questionType == 'mcq_single';
  bool get isNumerical => questionType == 'numerical';
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}

class QuestionOption {
  final String optionId;
  final String text;
  final String? html;

  QuestionOption({
    required this.optionId,
    required this.text,
    this.html,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      optionId: json['option_id'] as String,
      text: json['text'] as String,
      html: json['html'] as String?,
    );
  }
}
