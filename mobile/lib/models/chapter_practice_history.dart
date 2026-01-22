/// Chapter Practice History Models
/// Models for displaying chapter practice history in the History screen

class ChapterPracticeHistoryItem {
  final String sessionId;
  final String chapterKey;
  final String chapterName;
  final String subject;
  final DateTime completedAt;
  final int totalQuestions;
  final int questionsAnswered;
  final int correctCount;
  final double accuracy;
  final int totalTimeSeconds;
  final double thetaImprovement;

  ChapterPracticeHistoryItem({
    required this.sessionId,
    required this.chapterKey,
    required this.chapterName,
    required this.subject,
    required this.completedAt,
    required this.totalQuestions,
    required this.questionsAnswered,
    required this.correctCount,
    required this.accuracy,
    required this.totalTimeSeconds,
    this.thetaImprovement = 0.0,
  });

  factory ChapterPracticeHistoryItem.fromJson(Map<String, dynamic> json) {
    return ChapterPracticeHistoryItem(
      sessionId: json['session_id'] as String? ?? '',
      chapterKey: json['chapter_key'] as String? ?? '',
      chapterName: json['chapter_name'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : DateTime.now(),
      totalQuestions: json['total_questions'] as int? ?? 0,
      questionsAnswered: json['questions_answered'] as int? ?? 0,
      correctCount: json['correct_count'] as int? ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      totalTimeSeconds: json['total_time_seconds'] as int? ?? 0,
      thetaImprovement: (json['theta_improvement'] as num?)?.toDouble() ?? 0.0,
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
  String get scoreDisplay => '$correctCount/$questionsAnswered';

  /// Normalized subject name for display
  String get subjectDisplay {
    switch (subject.toLowerCase()) {
      case 'physics':
        return 'Physics';
      case 'chemistry':
        return 'Chemistry';
      case 'mathematics':
        return 'Mathematics';
      default:
        return subject;
    }
  }
}

/// Response model for chapter practice history API
class ChapterPracticeHistoryResponse {
  final List<ChapterPracticeHistoryItem> sessions;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;
  final String tier;
  final int historyDaysLimit;
  final bool isUnlimited;

  ChapterPracticeHistoryResponse({
    required this.sessions,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
    required this.tier,
    required this.historyDaysLimit,
    required this.isUnlimited,
  });

  factory ChapterPracticeHistoryResponse.fromJson(Map<String, dynamic> json) {
    final sessionsList = (json['sessions'] as List<dynamic>?)
            ?.map((e) =>
                ChapterPracticeHistoryItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};
    final tierInfo = json['tier_info'] as Map<String, dynamic>? ?? {};

    return ChapterPracticeHistoryResponse(
      sessions: sessionsList,
      total: pagination['total'] as int? ?? sessionsList.length,
      limit: pagination['limit'] as int? ?? 20,
      offset: pagination['offset'] as int? ?? 0,
      hasMore: pagination['has_more'] as bool? ?? false,
      tier: tierInfo['tier'] as String? ?? 'free',
      historyDaysLimit: tierInfo['history_days_limit'] as int? ?? 7,
      isUnlimited: tierInfo['is_unlimited'] as bool? ?? false,
    );
  }
}
