/// Solution model for Snap & Solve response
class Solution {
  final String? id;
  final String recognizedQuestion;
  final String subject;
  final String topic;
  final String difficulty;
  final String? language;
  final String? imageUrl;
  final SolutionDetails solution;
  final List<FollowUpQuestion> followUpQuestions;
  final int? remainingSnaps;
  final String? resetsAt;

  Solution({
    this.id,
    required this.recognizedQuestion,
    required this.subject,
    required this.topic,
    required this.difficulty,
    this.language,
    this.imageUrl,
    required this.solution,
    required this.followUpQuestions,
    this.remainingSnaps,
    this.resetsAt,
  });

  factory Solution.fromJson(Map<String, dynamic> json) {
    return Solution(
      id: json['id'],
      recognizedQuestion: json['recognizedQuestion'] ?? '',
      subject: json['subject'] ?? 'Mathematics',
      topic: json['topic'] ?? 'General',
      difficulty: json['difficulty'] ?? 'medium',
      language: json['language'],
      imageUrl: json['imageUrl'] ?? json['image_url'],
      solution: SolutionDetails.fromJson(json['solution'] ?? {}),
      followUpQuestions: (json['followUpQuestions'] as List<dynamic>?)
              ?.map((q) => FollowUpQuestion.fromJson(q))
              .toList() ??
          [],
      remainingSnaps: json['remainingSnaps'],
      resetsAt: json['resetsAt'],
    );
  }
}

class SolutionDetails {
  final String approach;
  final List<String> steps;
  final String finalAnswer;
  final String priyaMaamTip;

  SolutionDetails({
    required this.approach,
    required this.steps,
    required this.finalAnswer,
    required this.priyaMaamTip,
  });

  factory SolutionDetails.fromJson(Map<String, dynamic> json) {
    return SolutionDetails(
      approach: json['approach'] ?? '',
      steps: (json['steps'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [],
      finalAnswer: json['finalAnswer'] ?? '',
      priyaMaamTip: json['priyaMaamTip'] ?? '',
    );
  }
}

class FollowUpQuestion {
  final String question;
  final Map<String, String> options;
  final String correctAnswer;
  final QuestionExplanation explanation;
  final String? priyaMaamNote;
  final String? source; // "database" or "ai" - indicates where the question came from
  final String? questionId; // Database question ID for tracking
  final String questionType; // "mcq_single" or "numerical"

  FollowUpQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    this.priyaMaamNote,
    this.source,
    this.questionId,
    this.questionType = 'mcq_single',
  });

  /// Check if this is a numerical answer question
  bool get isNumerical => questionType == 'numerical';

  /// Check if this is an MCQ question
  bool get isMcq => questionType == 'mcq_single' || questionType == 'mcq';

  factory FollowUpQuestion.fromJson(Map<String, dynamic> json) {
    try {
      // Safely parse options
      Map<String, String> parsedOptions = {};
      if (json['options'] != null) {
        if (json['options'] is Map) {
          parsedOptions = Map<String, String>.from(
            (json['options'] as Map).map((key, value) => 
              MapEntry(key.toString(), value.toString())
            )
          );
        }
      }
      
      // Safely parse explanation
      QuestionExplanation parsedExplanation;
      try {
        parsedExplanation = QuestionExplanation.fromJson(json['explanation'] ?? {});
      } catch (e) {
        // Fallback explanation if parsing fails
        parsedExplanation = QuestionExplanation(
          approach: '',
          steps: [],
          finalAnswer: '',
        );
      }
      
      return FollowUpQuestion(
        question: json['question']?.toString() ?? '',
        options: parsedOptions,
        correctAnswer: json['correctAnswer']?.toString() ?? 'A',
        explanation: parsedExplanation,
        priyaMaamNote: json['priyaMaamNote']?.toString(),
        source: json['source']?.toString(),
        questionId: json['questionId']?.toString(),
        questionType: json['questionType']?.toString() ?? 'mcq_single',
      );
    } catch (e) {
      // Return a safe default if parsing completely fails
      return FollowUpQuestion(
        question: json['question']?.toString() ?? 'Question could not be loaded',
        options: {},
        correctAnswer: 'A',
        explanation: QuestionExplanation(
          approach: '',
          steps: [],
          finalAnswer: '',
        ),
        priyaMaamNote: null,
        source: null,
        questionId: null,
      );
    }
  }
}

class QuestionExplanation {
  final String approach;
  final List<String> steps;
  final String finalAnswer;

  QuestionExplanation({
    required this.approach,
    required this.steps,
    required this.finalAnswer,
  });

  factory QuestionExplanation.fromJson(Map<String, dynamic> json) {
    return QuestionExplanation(
      approach: json['approach'] ?? '',
      steps: (json['steps'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [],
      finalAnswer: json['finalAnswer'] ?? '',
    );
  }
}

