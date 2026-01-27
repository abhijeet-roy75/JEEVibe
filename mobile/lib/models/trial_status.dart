import 'package:flutter/material.dart';

/// Represents the status of a user's trial subscription
class TrialStatus {
  final String tierId;
  final DateTime startedAt;
  final DateTime endsAt;
  final int daysRemaining;
  final bool isActive;

  TrialStatus({
    required this.tierId,
    required this.startedAt,
    required this.endsAt,
    required this.daysRemaining,
    required this.isActive,
  });

  /// Create empty/null trial status
  factory TrialStatus.empty() {
    return TrialStatus(
      tierId: '',
      startedAt: DateTime.now(),
      endsAt: DateTime.now(),
      daysRemaining: 0,
      isActive: false,
    );
  }

  /// Parse from API response JSON
  factory TrialStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return TrialStatus.empty();

    return TrialStatus(
      tierId: json['tier_id'] ?? 'pro',
      startedAt: DateTime.parse(json['started_at']),
      endsAt: DateTime.parse(json['ends_at']),
      daysRemaining: json['days_remaining'] ?? 0,
      isActive: json['is_active'] ?? false,
    );
  }

  /// Whether the trial is in urgent state (5 days or less)
  bool get isUrgent => daysRemaining <= 5 && daysRemaining > 0;

  /// Whether the trial has expired
  bool get isExpired => daysRemaining <= 0;

  /// Whether it's the last day of trial
  bool get isLastDay => daysRemaining <= 1 && daysRemaining > 0;

  /// Get urgency-based color for UI elements
  Color get urgencyColor {
    if (daysRemaining <= 2) return Colors.red;
    if (daysRemaining <= 5) return Colors.orange;
    return Colors.blue;
  }

  /// Get banner text based on days remaining
  String get bannerText {
    if (daysRemaining <= 0) return 'Trial expired';
    if (daysRemaining == 1) return 'Last day of Pro trial!';
    if (daysRemaining <= 5) return '$daysRemaining days left in Pro trial';
    return 'Pro Trial • $daysRemaining days remaining';
  }

  /// Get urgency icon
  IconData get urgencyIcon {
    if (isExpired) return Icons.timer_off;
    if (isLastDay) return Icons.alarm;
    if (isUrgent) return Icons.timer;
    return Icons.star;
  }

  /// Get call-to-action text
  String get ctaText {
    if (isExpired) return 'Upgrade Now';
    if (isLastDay) return 'Upgrade';
    if (isUrgent) return 'Upgrade';
    return 'Learn More';
  }

  /// Convert to JSON for debugging
  Map<String, dynamic> toJson() {
    return {
      'tier_id': tierId,
      'started_at': startedAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
      'days_remaining': daysRemaining,
      'is_active': isActive,
      'is_urgent': isUrgent,
    };
  }
}
