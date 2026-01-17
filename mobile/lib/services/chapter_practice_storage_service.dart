import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chapter_practice_models.dart';

/// Chapter Practice Storage Service
///
/// Handles local persistence for chapter practice sessions.
/// Enables mid-exit recovery and offline resilience.
class ChapterPracticeStorageService {
  static const String _sessionPrefix = 'chapter_practice_session_';
  static const String _progressPrefix = 'chapter_practice_progress_';
  static const String _activeSessionKey = 'chapter_practice_active_session';

  /// Save session to local storage
  Future<void> saveSession(ChapterPracticeSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_sessionPrefix${session.sessionId}';
    await prefs.setString(key, jsonEncode(session.toJson()));

    // Also track as active session
    await prefs.setString(_activeSessionKey, session.sessionId);
  }

  /// Load session from local storage
  Future<ChapterPracticeSession?> loadSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_sessionPrefix$sessionId';
    final data = prefs.getString(key);

    if (data == null) return null;

    try {
      return ChapterPracticeSession.fromJson(jsonDecode(data));
    } catch (e) {
      return null;
    }
  }

  /// Clear session from local storage
  Future<void> clearSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_sessionPrefix$sessionId');
    await prefs.remove('$_progressPrefix$sessionId');

    // Clear active session if this was it
    final activeId = prefs.getString(_activeSessionKey);
    if (activeId == sessionId) {
      await prefs.remove(_activeSessionKey);
    }
  }

  /// Save progress (current question index and results)
  Future<void> saveProgress(
    String sessionId,
    int questionIndex,
    List<PracticeQuestionResult> results,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_progressPrefix$sessionId';

    final progressData = {
      'question_index': questionIndex,
      'results': results
          .map((r) => {
                'question_id': r.questionId,
                'position': r.position,
                'student_answer': r.studentAnswer,
                'correct_answer': r.correctAnswer,
                'is_correct': r.isCorrect,
                'time_taken_seconds': r.timeTakenSeconds,
              })
          .toList(),
      'saved_at': DateTime.now().toIso8601String(),
    };

    await prefs.setString(key, jsonEncode(progressData));
  }

  /// Load progress
  Future<Map<String, dynamic>?> loadProgress(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_progressPrefix$sessionId';
    final data = prefs.getString(key);

    if (data == null) return null;

    try {
      return jsonDecode(data);
    } catch (e) {
      return null;
    }
  }

  /// Get active session ID (if any)
  Future<String?> getActiveSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeSessionKey);
  }

  /// Clear all chapter practice data
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(_sessionPrefix) ||
          key.startsWith(_progressPrefix) ||
          key == _activeSessionKey) {
        await prefs.remove(key);
      }
    }
  }
}
