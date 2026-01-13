/// Service for tracking app sessions
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionTrackingService {
  static const String _keyPrefix = 'jeevibe_';
  static const String _keySessionCount = '${_keyPrefix}session_count';
  static const String _keyLastSessionDate = '${_keyPrefix}last_session_date';
  static const String _keyHasSeenFeedbackTooltip = '${_keyPrefix}has_seen_feedback_tooltip';

  // Singleton pattern
  static final SessionTrackingService _instance = SessionTrackingService._internal();
  factory SessionTrackingService() => _instance;
  SessionTrackingService._internal();

  SharedPreferences? _prefs;

  /// Initialize the service
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get _preferences async {
    if (_prefs == null) {
      await initialize();
    }
    return _prefs!;
  }

  /// Track a new app session (call when AssessmentIntroScreen loads)
  /// Returns true if this is a new session (different day or first time)
  Future<bool> trackSession() async {
    try {
      final prefs = await _preferences;
      final now = DateTime.now();
      final todayStr = _formatDate(now);
      
      // Get last session date
      final lastSessionDate = prefs.getString(_keyLastSessionDate);
      
      // If it's a different day or first time, increment session count
      if (lastSessionDate != todayStr) {
        final currentCount = prefs.getInt(_keySessionCount) ?? 0;
        await prefs.setInt(_keySessionCount, currentCount + 1);
        await prefs.setString(_keyLastSessionDate, todayStr);
        
        debugPrint('Session tracked: ${currentCount + 1}');
        return true; // New session
      }
      
      return false; // Same day, already counted
    } catch (e) {
      debugPrint('Error tracking session: $e');
      return false;
    }
  }

  /// Get current session count
  Future<int> getSessionCount() async {
    try {
      final prefs = await _preferences;
      return prefs.getInt(_keySessionCount) ?? 0;
    } catch (e) {
      debugPrint('Error getting session count: $e');
      return 0;
    }
  }

  /// Check if user should see feedback tooltip (first 3 sessions)
  Future<bool> shouldShowTooltip() async {
    try {
      final sessionCount = await getSessionCount();
      final hasSeenTooltip = await hasSeenFeedbackTooltip();
      
      // Show tooltip if:
      // 1. Session count is <= 3
      // 2. User hasn't seen the tooltip yet (or we want to show it each time for first 3)
      return sessionCount <= 3 && !hasSeenTooltip;
    } catch (e) {
      debugPrint('Error checking tooltip visibility: $e');
      return false;
    }
  }

  /// Mark that user has seen the feedback tooltip
  Future<void> markTooltipSeen() async {
    try {
      final prefs = await _preferences;
      await prefs.setBool(_keyHasSeenFeedbackTooltip, true);
    } catch (e) {
      debugPrint('Error marking tooltip as seen: $e');
    }
  }

  /// Check if user has seen the feedback tooltip
  Future<bool> hasSeenFeedbackTooltip() async {
    try {
      final prefs = await _preferences;
      return prefs.getBool(_keyHasSeenFeedbackTooltip) ?? false;
    } catch (e) {
      debugPrint('Error checking tooltip status: $e');
      return false;
    }
  }

  /// Reset session tracking (for testing)
  Future<void> reset() async {
    try {
      final prefs = await _preferences;
      await prefs.remove(_keySessionCount);
      await prefs.remove(_keyLastSessionDate);
      await prefs.remove(_keyHasSeenFeedbackTooltip);
    } catch (e) {
      debugPrint('Error resetting session tracking: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
