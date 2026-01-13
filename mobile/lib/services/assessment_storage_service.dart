/// Assessment Storage Service
/// Handles local persistence of initial assessment state
import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

class AssessmentStorageService {
  static const String _keyPrefix = 'jeevibe_assessment_';
  static const String _keyResponses = '${_keyPrefix}responses';
  static const String _keyCurrentIndex = '${_keyPrefix}current_index';
  static const String _keyRemainingSeconds = '${_keyPrefix}remaining_seconds';
  static const String _keyStartTime = '${_keyPrefix}start_time';
  static const String _keyQuestionStartTimes = '${_keyPrefix}question_start_times';
  static const String _keyLastSavedAt = '${_keyPrefix}last_saved_at';

  // Assessment state expires after 24 hours
  static const Duration _stateExpiration = Duration(hours: 24);

  // Singleton pattern
  static final AssessmentStorageService _instance = AssessmentStorageService._internal();
  factory AssessmentStorageService() => _instance;
  AssessmentStorageService._internal();

  SharedPreferences? _prefs;

  /// Reset internal state for testing purposes only
  @visibleForTesting
  void resetForTesting() {
    _prefs = null;
  }

  /// Initialize the storage service
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get _preferences async {
    if (_prefs == null) {
      await initialize();
    }
    return _prefs!;
  }

  /// Save current assessment state with validation
  Future<bool> saveAssessmentState({
    required Map<int, String> responses,
    required int currentIndex,
    required int remainingSeconds,
    required DateTime startTime,
    required Map<int, DateTime> questionStartTimes,
  }) async {
    try {
      // Validate inputs
      if (currentIndex < 0 || currentIndex >= 30) {
        throw ArgumentError('Invalid currentIndex: $currentIndex (must be 0-29)');
      }

      // Validate remainingSeconds is reasonable (-10 hours to +1 hour from 45 min)
      // Allow negative for overtime, but not absurdly negative
      if (remainingSeconds < -36000 || remainingSeconds > 3600) {
        debugPrint('Warning: Suspicious remainingSeconds: $remainingSeconds');
        // Don't throw, just warn - could be legitimate if user took very long
      }

      // Validate startTime is not in future (with 5 min tolerance for clock skew)
      final now = DateTime.now();
      if (startTime.isAfter(now.add(const Duration(minutes: 5)))) {
        throw ArgumentError('startTime cannot be in future: $startTime');
      }

      // Validate startTime is not too old (more than 7 days)
      if (now.difference(startTime) > const Duration(days: 7)) {
        throw ArgumentError('startTime is too old: $startTime');
      }

      // Validate response keys are in valid range
      for (final key in responses.keys) {
        if (key < 0 || key >= 30) {
          throw ArgumentError('Invalid response key: $key (must be 0-29)');
        }
      }

      final prefs = await _preferences;

      // Save responses (convert int keys to strings for JSON)
      final responsesJson = json.encode(
        responses.map((key, value) => MapEntry(key.toString(), value)),
      );
      await prefs.setString(_keyResponses, responsesJson);

      // Save current index and remaining seconds
      await prefs.setInt(_keyCurrentIndex, currentIndex);
      await prefs.setInt(_keyRemainingSeconds, remainingSeconds);

      // Save start time
      await prefs.setString(_keyStartTime, startTime.toIso8601String());

      // Save question start times
      final questionStartTimesJson = json.encode(
        questionStartTimes.map(
          (key, value) => MapEntry(key.toString(), value.toIso8601String()),
        ),
      );
      await prefs.setString(_keyQuestionStartTimes, questionStartTimesJson);

      // Save last saved timestamp
      await prefs.setString(_keyLastSavedAt, now.toIso8601String());

      debugPrint('Assessment state saved successfully');
      return true;
    } catch (e) {
      debugPrint('Error saving assessment state: $e');
      return false; // Return false so caller knows save failed
    }
  }

  /// Load saved assessment state
  Future<AssessmentStateData?> loadAssessmentState() async {
    try {
      final prefs = await _preferences;

      // Check if state exists
      if (!prefs.containsKey(_keyResponses)) {
        return null;
      }

      // Check if state has expired
      final lastSavedAtStr = prefs.getString(_keyLastSavedAt);
      if (lastSavedAtStr != null) {
        final lastSavedAt = DateTime.parse(lastSavedAtStr);
        final now = DateTime.now();
        if (now.difference(lastSavedAt) > _stateExpiration) {
          // State expired, clear it
          debugPrint('Assessment state expired, clearing...');
          await clearAssessmentState();
          return null;
        }
      }

      // Load responses
      final responsesJson = prefs.getString(_keyResponses);
      if (responsesJson == null) return null;

      final responsesData = json.decode(responsesJson) as Map<String, dynamic>;
      final responses = responsesData.map(
        (key, value) => MapEntry(int.parse(key), value as String),
      );

      // Load current index and remaining seconds
      final currentIndex = prefs.getInt(_keyCurrentIndex) ?? 0;
      final remainingSeconds = prefs.getInt(_keyRemainingSeconds) ?? 2700; // Default 45 minutes

      // Load start time
      final startTimeStr = prefs.getString(_keyStartTime);
      final startTime = startTimeStr != null
          ? DateTime.parse(startTimeStr)
          : DateTime.now();

      // Load question start times
      final questionStartTimesJson = prefs.getString(_keyQuestionStartTimes);
      Map<int, DateTime> questionStartTimes = {};

      if (questionStartTimesJson != null) {
        final timesData = json.decode(questionStartTimesJson) as Map<String, dynamic>;
        questionStartTimes = timesData.map(
          (key, value) => MapEntry(int.parse(key), DateTime.parse(value as String)),
        );
      }

      debugPrint('Assessment state loaded successfully');
      return AssessmentStateData(
        responses: responses,
        currentIndex: currentIndex,
        remainingSeconds: remainingSeconds,
        startTime: startTime,
        questionStartTimes: questionStartTimes,
      );
    } catch (e) {
      debugPrint('Error loading assessment state: $e');
      return null;
    }
  }

  /// Clear saved assessment state
  Future<void> clearAssessmentState() async {
    try {
      final prefs = await _preferences;
      await prefs.remove(_keyResponses);
      await prefs.remove(_keyCurrentIndex);
      await prefs.remove(_keyRemainingSeconds);
      await prefs.remove(_keyStartTime);
      await prefs.remove(_keyQuestionStartTimes);
      await prefs.remove(_keyLastSavedAt);
      debugPrint('Assessment state cleared');
    } catch (e) {
      debugPrint('Error clearing assessment state: $e');
    }
  }

  /// Check if there's a saved assessment state
  Future<bool> hasSavedAssessmentState() async {
    try {
      final prefs = await _preferences;
      return prefs.containsKey(_keyResponses);
    } catch (e) {
      return false;
    }
  }

  /// Check if saved state is expired
  Future<bool> isStateExpired() async {
    try {
      final prefs = await _preferences;
      final lastSavedAtStr = prefs.getString(_keyLastSavedAt);
      if (lastSavedAtStr == null) return true;

      final lastSavedAt = DateTime.parse(lastSavedAtStr);
      final now = DateTime.now();
      return now.difference(lastSavedAt) > _stateExpiration;
    } catch (e) {
      return true;
    }
  }

  void debugPrint(String message) {
    print('[AssessmentStorageService] $message');
  }
}

/// Assessment State Data Model
class AssessmentStateData {
  final Map<int, String> responses;
  final int currentIndex;
  final int remainingSeconds;
  final DateTime startTime;
  final Map<int, DateTime> questionStartTimes;

  AssessmentStateData({
    required this.responses,
    required this.currentIndex,
    required this.remainingSeconds,
    required this.startTime,
    required this.questionStartTimes,
  });
}
