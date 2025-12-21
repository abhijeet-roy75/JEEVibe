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
    // Parse options and validate IDs
    List<QuestionOption>? options;
    if (json['options'] != null) {
      final optionsList = (json['options'] as List)
          .map((opt) => QuestionOption.fromJson(opt as Map<String, dynamic>))
          .toList();
      
      // Validate and fix duplicate/empty option IDs
      final seenIds = <String>{};
      options = optionsList.map((opt) {
        String optionId = opt.optionId;
        
        // If empty or duplicate, generate a unique ID
        if (optionId.isEmpty || seenIds.contains(optionId)) {
          // Use A, B, C, D based on index
          final index = optionsList.indexOf(opt);
          optionId = String.fromCharCode(65 + index); // A=65, B=66, etc.
          print('WARNING: Fixed option ID for question ${json['question_id']} - assigned: $optionId');
        }
        
        seenIds.add(optionId);
        
        // Return new option with corrected ID if needed
        return optionId != opt.optionId
            ? QuestionOption(optionId: optionId, text: opt.text, html: opt.html)
            : opt;
      }).toList();
    }
    
    return AssessmentQuestion(
      questionId: json['question_id'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      chapter: json['chapter'] as String? ?? '',
      questionType: json['question_type'] as String? ?? 'mcq_single',
      questionText: json['question_text'] as String? ?? '',
      questionTextHtml: json['question_text_html'] as String?,
      questionLatex: json['question_latex'] as String?,
      options: options,
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
    // Keep option_id as-is (even if empty) - parent will fix it with proper A, B, C, D
    return QuestionOption(
      optionId: json['option_id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      html: json['html'] as String?,
    );
  }
}
