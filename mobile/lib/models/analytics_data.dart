/// Analytics Data Models
/// Models for analytics API responses
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Mastery status enum
enum MasteryStatus {
  mastered,
  growing,
  focus;

  static MasteryStatus fromString(String status) {
    switch (status.toUpperCase()) {
      case 'MASTERED':
        return MasteryStatus.mastered;
      case 'GROWING':
        return MasteryStatus.growing;
      case 'FOCUS':
        return MasteryStatus.focus;
      default:
        return MasteryStatus.focus;
    }
  }

  String get displayName {
    switch (this) {
      case MasteryStatus.mastered:
        return 'MASTERED';
      case MasteryStatus.growing:
        return 'GROWING';
      case MasteryStatus.focus:
        return 'FOCUS';
    }
  }

  Color get color {
    switch (this) {
      case MasteryStatus.mastered:
        return AppColors.success;
      case MasteryStatus.growing:
        return AppColors.warning;
      case MasteryStatus.focus:
        return AppColors.error;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case MasteryStatus.mastered:
        return AppColors.successBackground;
      case MasteryStatus.growing:
        return AppColors.warningBackground;
      case MasteryStatus.focus:
        return AppColors.errorBackground;
    }
  }
}

/// User basic info
class AnalyticsUser {
  final String firstName;
  final String lastName;

  AnalyticsUser({
    required this.firstName,
    required this.lastName,
  });

  factory AnalyticsUser.fromJson(Map<String, dynamic> json) {
    return AnalyticsUser(
      firstName: json['first_name'] ?? 'Student',
      lastName: json['last_name'] ?? '',
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}

/// Stats summary
class AnalyticsStats {
  final int questionsSolved;
  final int quizzesCompleted;
  final int chaptersMastered;
  final int currentStreak;
  final int longestStreak;

  AnalyticsStats({
    required this.questionsSolved,
    required this.quizzesCompleted,
    required this.chaptersMastered,
    required this.currentStreak,
    required this.longestStreak,
  });

  factory AnalyticsStats.fromJson(Map<String, dynamic> json) {
    return AnalyticsStats(
      questionsSolved: json['questions_solved'] ?? 0,
      quizzesCompleted: json['quizzes_completed'] ?? 0,
      chaptersMastered: json['chapters_mastered'] ?? 0,
      currentStreak: json['current_streak'] ?? 0,
      longestStreak: json['longest_streak'] ?? 0,
    );
  }
}

/// Subject progress data
class SubjectProgress {
  final String subject;
  final String displayName;
  final double percentile;
  final double theta;
  final MasteryStatus status;
  final int chaptersTested;
  final int? accuracy; // Assessment accuracy percentage (0-100)
  final int correct;   // Number of correct answers
  final int total;     // Total questions attempted

  SubjectProgress({
    required this.subject,
    required this.displayName,
    required this.percentile,
    required this.theta,
    required this.status,
    required this.chaptersTested,
    this.accuracy,
    this.correct = 0,
    this.total = 0,
  });

  factory SubjectProgress.fromJson(String subject, Map<String, dynamic> json) {
    return SubjectProgress(
      subject: subject,
      displayName: json['display_name'] ?? subject,
      percentile: (json['percentile'] ?? 0).toDouble(),
      theta: (json['theta'] ?? 0).toDouble(),
      status: MasteryStatus.fromString(json['status'] ?? 'FOCUS'),
      chaptersTested: json['chapters_tested'] ?? 0,
      accuracy: json['accuracy'],
      correct: json['correct'] ?? 0,
      total: json['total'] ?? 0,
    );
  }

  Color get progressColor {
    switch (subject.toLowerCase()) {
      case 'physics':
        return AppColors.infoBlue;
      case 'chemistry':
        return AppColors.successGreen;
      case 'mathematics':
      case 'maths':
        return AppColors.primaryPurple;
      default:
        return AppColors.textMedium;
    }
  }

  IconData get icon {
    switch (subject.toLowerCase()) {
      case 'physics':
        return Icons.bolt;
      case 'chemistry':
        return Icons.science;
      case 'mathematics':
      case 'maths':
        return Icons.functions;
      default:
        return Icons.book;
    }
  }

  Color get iconColor {
    switch (subject.toLowerCase()) {
      case 'physics':
        return AppColors.warningAmber;
      case 'chemistry':
        return AppColors.successGreen;
      case 'mathematics':
      case 'maths':
        return AppColors.primaryPurple;
      default:
        return AppColors.textMedium;
    }
  }
}

/// Focus area data
class FocusArea {
  final String chapterKey;
  final String chapterName;
  final String subject;
  final String subjectName;
  final double percentile;
  final int attempts;
  final double accuracy;
  final int correct;
  final int total;
  final String reason;
  final MasteryStatus status;

  FocusArea({
    required this.chapterKey,
    required this.chapterName,
    required this.subject,
    required this.subjectName,
    required this.percentile,
    required this.attempts,
    required this.accuracy,
    required this.correct,
    required this.total,
    required this.reason,
    required this.status,
  });

  factory FocusArea.fromJson(Map<String, dynamic> json) {
    return FocusArea(
      chapterKey: json['chapter_key'] ?? '',
      chapterName: json['chapter_name'] ?? '',
      subject: json['subject'] ?? '',
      subjectName: json['subject_name'] ?? '',
      percentile: (json['percentile'] ?? 0).toDouble(),
      attempts: json['attempts'] ?? 0,
      accuracy: (json['accuracy'] ?? 0).toDouble(),
      correct: json['correct'] ?? 0,
      total: json['total'] ?? 0,
      reason: json['reason'] ?? '',
      status: MasteryStatus.fromString(json['status'] ?? 'FOCUS'),
    );
  }
}

/// Complete analytics overview response
class AnalyticsOverview {
  final AnalyticsUser user;
  final AnalyticsStats stats;
  final Map<String, SubjectProgress> subjectProgress;
  final List<FocusArea> focusAreas;
  final String priyaMaamMessage;
  final DateTime generatedAt;

  AnalyticsOverview({
    required this.user,
    required this.stats,
    required this.subjectProgress,
    required this.focusAreas,
    required this.priyaMaamMessage,
    required this.generatedAt,
  });

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) {
    // Parse subject progress
    final subjectProgressJson = json['subject_progress'] as Map<String, dynamic>? ?? {};
    final Map<String, SubjectProgress> subjectProgress = {};
    subjectProgressJson.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        subjectProgress[key] = SubjectProgress.fromJson(key, value);
      }
    });

    // Parse focus areas
    final focusAreasJson = json['focus_areas'] as List<dynamic>? ?? [];
    final focusAreas = focusAreasJson
        .whereType<Map<String, dynamic>>()
        .map((e) => FocusArea.fromJson(e))
        .toList();

    return AnalyticsOverview(
      user: AnalyticsUser.fromJson(json['user'] ?? {}),
      stats: AnalyticsStats.fromJson(json['stats'] ?? {}),
      subjectProgress: subjectProgress,
      focusAreas: focusAreas,
      priyaMaamMessage: json['priya_maam_message'] ?? '',
      generatedAt: DateTime.tryParse(json['generated_at'] ?? '') ?? DateTime.now(),
    );
  }

  /// Get subject progress in display order
  List<SubjectProgress> get orderedSubjectProgress {
    final order = ['physics', 'chemistry', 'mathematics', 'maths'];
    final result = <SubjectProgress>[];
    for (final key in order) {
      if (subjectProgress.containsKey(key)) {
        result.add(subjectProgress[key]!);
      }
    }
    return result;
  }
}

/// Subtopic accuracy data
class SubtopicAccuracy {
  final String name;
  final int correct;
  final int total;
  final int accuracy;

  SubtopicAccuracy({
    required this.name,
    required this.correct,
    required this.total,
    required this.accuracy,
  });

  factory SubtopicAccuracy.fromJson(Map<String, dynamic> json) {
    return SubtopicAccuracy(
      name: json['name'] ?? '',
      correct: json['correct'] ?? 0,
      total: json['total'] ?? 0,
      accuracy: json['accuracy'] ?? 0,
    );
  }
}

/// Chapter mastery data
class ChapterMastery {
  final String chapterKey;
  final String chapterName;
  final double percentile;
  final double theta;
  final int attempts;
  final double accuracy;
  final int correct; // Number of correct answers
  final int total; // Total questions attempted
  final MasteryStatus status;
  final DateTime? lastUpdated;
  final List<SubtopicAccuracy> subtopics;

  ChapterMastery({
    required this.chapterKey,
    required this.chapterName,
    required this.percentile,
    required this.theta,
    required this.attempts,
    required this.accuracy,
    required this.correct,
    required this.total,
    required this.status,
    this.lastUpdated,
    this.subtopics = const [],
  });

  factory ChapterMastery.fromJson(Map<String, dynamic> json) {
    final subtopicsJson = json['subtopics'] as List<dynamic>? ?? [];
    final subtopics = subtopicsJson
        .whereType<Map<String, dynamic>>()
        .map((e) => SubtopicAccuracy.fromJson(e))
        .toList();

    return ChapterMastery(
      chapterKey: json['chapter_key'] ?? '',
      chapterName: json['chapter_name'] ?? '',
      percentile: (json['percentile'] ?? 0).toDouble(),
      theta: (json['theta'] ?? 0).toDouble(),
      attempts: json['attempts'] ?? 0,
      accuracy: (json['accuracy'] ?? 0).toDouble(),
      correct: json['correct'] ?? 0,
      total: json['total'] ?? 0,
      status: MasteryStatus.fromString(json['status'] ?? 'FOCUS'),
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'].toString())
          : null,
      subtopics: subtopics,
    );
  }
}

/// Subject mastery details response
class SubjectMasteryDetails {
  final String subject;
  final String subjectName;
  final double overallPercentile;
  final double overallTheta;
  final MasteryStatus status;
  final int chaptersTested;
  final List<ChapterMastery> chapters;
  final MasterySummary summary;

  SubjectMasteryDetails({
    required this.subject,
    required this.subjectName,
    required this.overallPercentile,
    required this.overallTheta,
    required this.status,
    required this.chaptersTested,
    required this.chapters,
    required this.summary,
  });

  factory SubjectMasteryDetails.fromJson(Map<String, dynamic> json) {
    final chaptersJson = json['chapters'] as List<dynamic>? ?? [];
    final chapters = chaptersJson
        .whereType<Map<String, dynamic>>()
        .map((e) => ChapterMastery.fromJson(e))
        .toList();

    return SubjectMasteryDetails(
      subject: json['subject'] ?? '',
      subjectName: json['subject_name'] ?? '',
      overallPercentile: (json['overall_percentile'] ?? 0).toDouble(),
      overallTheta: (json['overall_theta'] ?? 0).toDouble(),
      status: MasteryStatus.fromString(json['status'] ?? 'FOCUS'),
      chaptersTested: json['chapters_tested'] ?? 0,
      chapters: chapters,
      summary: MasterySummary.fromJson(json['summary'] ?? {}),
    );
  }
}

/// Summary counts for mastery
class MasterySummary {
  final int mastered;
  final int growing;
  final int focus;

  MasterySummary({
    required this.mastered,
    required this.growing,
    required this.focus,
  });

  factory MasterySummary.fromJson(Map<String, dynamic> json) {
    return MasterySummary(
      mastered: json['mastered'] ?? 0,
      growing: json['growing'] ?? 0,
      focus: json['focus'] ?? 0,
    );
  }

  int get total => mastered + growing + focus;
}

/// Timeline data point for charts
class MasteryTimelinePoint {
  final DateTime date;
  final double percentile;
  final double theta;
  final int quizNumber;

  MasteryTimelinePoint({
    required this.date,
    required this.percentile,
    required this.theta,
    required this.quizNumber,
  });

  factory MasteryTimelinePoint.fromJson(Map<String, dynamic> json) {
    return MasteryTimelinePoint(
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      percentile: (json['percentile'] ?? 0).toDouble(),
      theta: (json['theta'] ?? 0).toDouble(),
      quizNumber: json['quiz_number'] ?? 0,
    );
  }
}

/// Mastery timeline response
class MasteryTimeline {
  final String? subject;
  final String? chapter;
  final int dataPoints;
  final List<MasteryTimelinePoint> timeline;

  MasteryTimeline({
    this.subject,
    this.chapter,
    required this.dataPoints,
    required this.timeline,
  });

  factory MasteryTimeline.fromJson(Map<String, dynamic> json) {
    final filter = json['filter'] as Map<String, dynamic>? ?? {};
    final timelineJson = json['timeline'] as List<dynamic>? ?? [];
    final timeline = timelineJson
        .whereType<Map<String, dynamic>>()
        .map((e) => MasteryTimelinePoint.fromJson(e))
        .toList();

    return MasteryTimeline(
      subject: filter['subject'],
      chapter: filter['chapter'],
      dataPoints: json['data_points'] ?? 0,
      timeline: timeline,
    );
  }
}

/// Daily activity data point
class DailyActivity {
  final String date;
  final String dayName;
  final int quizzes;
  final int questions;
  final int correct;
  final double accuracy;
  final bool isToday;
  final bool isFuture;

  DailyActivity({
    required this.date,
    required this.dayName,
    required this.quizzes,
    required this.questions,
    required this.correct,
    required this.accuracy,
    required this.isToday,
    this.isFuture = false,
  });

  factory DailyActivity.fromJson(Map<String, dynamic> json) {
    return DailyActivity(
      date: json['date'] ?? '',
      dayName: json['dayName'] ?? '',
      quizzes: json['quizzes'] ?? 0,
      questions: json['questions'] ?? 0,
      correct: json['correct'] ?? 0,
      accuracy: (json['accuracy'] ?? 0).toDouble(),
      isToday: json['isToday'] ?? false,
      isFuture: json['isFuture'] ?? false,
    );
  }
}

/// Weekly activity response
class WeeklyActivity {
  final List<DailyActivity> week;
  final int totalQuestions;
  final int totalQuizzes;

  WeeklyActivity({
    required this.week,
    required this.totalQuestions,
    required this.totalQuizzes,
  });

  factory WeeklyActivity.fromJson(Map<String, dynamic> json) {
    final weekJson = json['week'] as List<dynamic>? ?? [];
    final week = weekJson
        .whereType<Map<String, dynamic>>()
        .map((e) => DailyActivity.fromJson(e))
        .toList();

    return WeeklyActivity(
      week: week,
      totalQuestions: json['total_questions'] ?? 0,
      totalQuizzes: json['total_quizzes'] ?? 0,
    );
  }
}

/// Accuracy timeline data point for charts
class AccuracyTimelinePoint {
  final DateTime date;
  final int accuracy; // Percentage 0-100
  final int questions;
  final int correct;
  final int quizzes;

  AccuracyTimelinePoint({
    required this.date,
    required this.accuracy,
    required this.questions,
    required this.correct,
    required this.quizzes,
  });

  factory AccuracyTimelinePoint.fromJson(Map<String, dynamic> json) {
    return AccuracyTimelinePoint(
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      accuracy: json['accuracy'] ?? 0,
      questions: json['questions'] ?? 0,
      correct: json['correct'] ?? 0,
      quizzes: json['quizzes'] ?? 0,
    );
  }
}

/// Accuracy timeline response
class AccuracyTimeline {
  final String subject;
  final int days;
  final int dataPoints;
  final List<AccuracyTimelinePoint> timeline;

  AccuracyTimeline({
    required this.subject,
    required this.days,
    required this.dataPoints,
    required this.timeline,
  });

  factory AccuracyTimeline.fromJson(Map<String, dynamic> json) {
    final timelineJson = json['timeline'] as List<dynamic>? ?? [];
    final timeline = timelineJson
        .whereType<Map<String, dynamic>>()
        .map((e) => AccuracyTimelinePoint.fromJson(e))
        .toList();

    return AccuracyTimeline(
      subject: json['subject'] ?? '',
      days: json['days'] ?? 30,
      dataPoints: json['data_points'] ?? 0,
      timeline: timeline,
    );
  }
}
