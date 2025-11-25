/// Solution model for Snap & Solve response
class Solution {
  final String recognizedQuestion;
  final String subject;
  final String topic;
  final String difficulty;
  final SolutionDetails solution;
  final List<FollowUpQuestion> followUpQuestions;

  Solution({
    required this.recognizedQuestion,
    required this.subject,
    required this.topic,
    required this.difficulty,
    required this.solution,
    required this.followUpQuestions,
  });

  factory Solution.fromJson(Map<String, dynamic> json) {
    return Solution(
      recognizedQuestion: json['recognizedQuestion'] ?? '',
      subject: json['subject'] ?? 'Mathematics',
      topic: json['topic'] ?? 'General',
      difficulty: json['difficulty'] ?? 'medium',
      solution: SolutionDetails.fromJson(json['solution'] ?? {}),
      followUpQuestions: (json['followUpQuestions'] as List<dynamic>?)
              ?.map((q) => FollowUpQuestion.fromJson(q))
              .toList() ??
          [],
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

  FollowUpQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    this.priyaMaamNote,
  });

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

