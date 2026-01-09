/// Data models for snap counter and local storage
import 'dart:convert';

/// Represents a single snap record
class SnapRecord {
  final String timestamp;
  final String questionId;
  final String topic;
  final String? subject;

  SnapRecord({
    required this.timestamp,
    required this.questionId,
    required this.topic,
    this.subject,
  });

  factory SnapRecord.fromJson(Map<String, dynamic> json) {
    return SnapRecord(
      timestamp: json['timestamp'] ?? '',
      questionId: json['questionId'] ?? '',
      topic: json['topic'] ?? '',
      subject: json['subject'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'questionId': questionId,
      'topic': topic,
      'subject': subject,
    };
  }
}

/// Represents a recent solution for display on home screen
class RecentSolution {
  final String id;
  final String question;
  final String topic;
  final String subject;
  final String timestamp;
  final Map<String, dynamic>? solutionData;
  final String? imageUrl;
  final String? language;

  RecentSolution({
    required this.id,
    required this.question,
    required this.topic,
    required this.subject,
    required this.timestamp,
    this.solutionData,
    this.imageUrl,
    this.language,
  });

  factory RecentSolution.fromJson(Map<String, dynamic> json) {
    // Handle both local storage format (nested solutionData) and backend format (flat solution object)
    Map<String, dynamic>? data = json['solutionData'] as Map<String, dynamic>?;
    
    if (data == null && json['solution'] != null) {
      data = {
        'solution': json['solution'],
        'difficulty': json['difficulty'],
      };
    }

    return RecentSolution(
      id: json['id'] ?? '',
      question: json['question'] ?? json['recognizedQuestion'] ?? '',
      topic: json['topic'] ?? '',
      subject: json['subject'] ?? '',
      timestamp: json['timestamp'] ?? json['created_at'] ?? '',
      solutionData: data,
      imageUrl: json['imageUrl'] ?? json['image_url'],
      language: json['language'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'topic': topic,
      'subject': subject,
      'timestamp': timestamp,
      'solutionData': solutionData,
      'imageUrl': imageUrl,
      'language': language,
    };
  }

  /// Get preview text (first 80 characters) with LaTeX cleaned
  String getPreviewText() {
    // Clean LaTeX delimiters and commands for preview
    String cleanedQuestion = question
        .replaceAll(RegExp(r'\\\('), '') // Remove \(
        .replaceAll(RegExp(r'\\\)'), '') // Remove \)
        .replaceAll(RegExp(r'\\\['), '') // Remove \[
        .replaceAll(RegExp(r'\\\]'), ''); // Remove \]

    // Use replaceAllMapped for proper regex group capture
    cleanedQuestion = cleanedQuestion.replaceAllMapped(
      RegExp(r'\\mathrm\{([^}]+)\}'),
      (match) => match.group(1) ?? '',
    ); // \mathrm{X} -> X

    cleanedQuestion = cleanedQuestion.replaceAllMapped(
      RegExp(r'\\text\{([^}]+)\}'),
      (match) => match.group(1) ?? '',
    ); // \text{X} -> X

    cleanedQuestion = cleanedQuestion.replaceAllMapped(
      RegExp(r'[_^]\{([^}]+)\}'),
      (match) => match.group(1) ?? '',
    ); // _{X} or ^{X} -> X

    cleanedQuestion = cleanedQuestion
        .replaceAll(RegExp(r'\\[a-zA-Z]+'), '') // Remove LaTeX commands
        .replaceAll(RegExp(r'[{}]'), '') // Remove braces
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
    
    if (cleanedQuestion.length <= 80) return cleanedQuestion;
    return '${cleanedQuestion.substring(0, 77)}...';
  }

  /// Get time ago string (e.g., "5 min ago", "2 hours ago")
  String getTimeAgo() {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else {
        return 'A while ago';
      }
    } catch (e) {
      return '';
    }
  }
}

/// Represents aggregated user statistics
class UserStats {
  final int totalQuestionsPracticed;
  final int totalCorrect;
  final double accuracy;
  final int totalSnapsUsed;

  UserStats({
    required this.totalQuestionsPracticed,
    required this.totalCorrect,
    required this.accuracy,
    required this.totalSnapsUsed,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    final practiced = json['totalQuestionsPracticed'] ?? 0;
    final correct = json['totalCorrect'] ?? 0;
    
    return UserStats(
      totalQuestionsPracticed: practiced,
      totalCorrect: correct,
      accuracy: practiced > 0 ? (correct / practiced * 100) : 0.0,
      totalSnapsUsed: json['totalSnapsUsed'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalQuestionsPracticed': totalQuestionsPracticed,
      'totalCorrect': totalCorrect,
      'accuracy': accuracy,
      'totalSnapsUsed': totalSnapsUsed,
    };
  }

  /// Get accuracy percentage as string
  String getAccuracyString() {
    return '${accuracy.toStringAsFixed(0)}%';
  }
}

/// Practice session result data
class PracticeSessionResult {
  final int score;
  final int total;
  final int timeSpentSeconds;
  final List<QuestionResult> questionResults;
  final String sessionId;
  final String timestamp;

  PracticeSessionResult({
    required this.score,
    required this.total,
    required this.timeSpentSeconds,
    required this.questionResults,
    required this.sessionId,
    required this.timestamp,
  });

  double get accuracy => total > 0 ? (score / total * 100) : 0.0;

  factory PracticeSessionResult.fromJson(Map<String, dynamic> json) {
    return PracticeSessionResult(
      score: json['score'] ?? 0,
      total: json['total'] ?? 0,
      timeSpentSeconds: json['timeSpentSeconds'] ?? 0,
      questionResults: (json['questionResults'] as List<dynamic>?)
              ?.map((q) => QuestionResult.fromJson(q))
              .toList() ??
          [],
      sessionId: json['sessionId'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'total': total,
      'timeSpentSeconds': timeSpentSeconds,
      'questionResults': questionResults.map((q) => q.toJson()).toList(),
      'sessionId': sessionId,
      'timestamp': timestamp,
    };
  }
}

/// Individual question result in a practice session
class QuestionResult {
  final int questionNumber;
  final String question;
  final String userAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final Map<String, dynamic>? explanation;
  final int timeSpentSeconds;

  QuestionResult({
    required this.questionNumber,
    required this.question,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    this.explanation,
    this.timeSpentSeconds = 0,
  });

  factory QuestionResult.fromJson(Map<String, dynamic> json) {
    return QuestionResult(
      questionNumber: json['questionNumber'] ?? 0,
      question: json['question'] ?? '',
      userAnswer: json['userAnswer'] ?? '',
      correctAnswer: json['correctAnswer'] ?? '',
      isCorrect: json['isCorrect'] ?? false,
      explanation: json['explanation'] as Map<String, dynamic>?,
      timeSpentSeconds: json['timeSpentSeconds'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questionNumber': questionNumber,
      'question': question,
      'userAnswer': userAnswer,
      'correctAnswer': correctAnswer,
      'isCorrect': isCorrect,
      'explanation': explanation,
      'timeSpentSeconds': timeSpentSeconds,
    };
  }
}

