/// Daily Quiz History Models
/// Models for displaying quiz history in the History screen

class DailyQuizHistoryItem {
  final String quizId;
  final int quizNumber;
  final DateTime completedAt;
  final int totalQuestions;
  final int correctCount;
  final double accuracy;
  final int totalTimeSeconds;
  final String? learningPhase;
  final bool isRecoveryQuiz;
  final List<String> chaptersCovered;

  DailyQuizHistoryItem({
    required this.quizId,
    required this.quizNumber,
    required this.completedAt,
    required this.totalQuestions,
    required this.correctCount,
    required this.accuracy,
    required this.totalTimeSeconds,
    this.learningPhase,
    this.isRecoveryQuiz = false,
    this.chaptersCovered = const [],
  });

  factory DailyQuizHistoryItem.fromJson(Map<String, dynamic> json) {
    return DailyQuizHistoryItem(
      quizId: json['quiz_id'] as String? ?? '',
      quizNumber: json['quiz_number'] as int? ?? 0,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : DateTime.now(),
      totalQuestions: json['total'] as int? ?? 0,
      correctCount: json['score'] as int? ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      totalTimeSeconds: json['total_time_seconds'] as int? ?? 0,
      learningPhase: json['learning_phase'] as String?,
      isRecoveryQuiz: json['is_recovery_quiz'] as bool? ?? false,
      chaptersCovered: (json['chapters_covered'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  /// Formatted accuracy as percentage string
  String get accuracyPercent => '${(accuracy * 100).round()}%';

  /// Formatted time (e.g., "5m 30s")
  String get formattedTime {
    final minutes = totalTimeSeconds ~/ 60;
    final seconds = totalTimeSeconds % 60;
    if (minutes > 0 && seconds > 0) {
      return '${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${seconds}s';
    }
  }

  /// Score display (e.g., "8/10")
  String get scoreDisplay => '$correctCount/$totalQuestions';
}

/// Response model for quiz history API
class DailyQuizHistoryResponse {
  final List<DailyQuizHistoryItem> quizzes;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  DailyQuizHistoryResponse({
    required this.quizzes,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  factory DailyQuizHistoryResponse.fromJson(Map<String, dynamic> json) {
    final quizzesList = (json['quizzes'] as List<dynamic>?)
            ?.map((e) => DailyQuizHistoryItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};

    return DailyQuizHistoryResponse(
      quizzes: quizzesList,
      total: pagination['total'] as int? ?? quizzesList.length,
      limit: pagination['limit'] as int? ?? 20,
      offset: pagination['offset'] as int? ?? 0,
      hasMore: pagination['has_more'] as bool? ?? false,
    );
  }
}
