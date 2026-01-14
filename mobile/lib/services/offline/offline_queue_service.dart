// Offline Queue Service
//
// Manages queuing of actions when offline and syncing when back online.
// Handles quiz answers, quiz completions, and other user actions.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import '../../models/offline/cached_solution.dart';
import '../api_service.dart';

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;

  OfflineQueueService._internal();

  final DatabaseService _databaseService = DatabaseService();

  // Action types
  static const String actionQuizAnswer = 'quiz_answer';
  static const String actionQuizComplete = 'quiz_complete';
  static const String actionQuizStart = 'quiz_start';

  // BUG-006 fix: Retry configuration
  static const int maxRetries = 3;
  static const Duration retryBaseDelay = Duration(seconds: 5);

  /// Queue a quiz answer submission for later sync
  Future<void> queueQuizAnswer({
    required String userId,
    required String quizId,
    required String questionId,
    required String answer,
    required int timeTaken,
  }) async {
    final action = OfflineAction()
      ..userId = userId
      ..actionType = actionQuizAnswer
      ..actionDataJson = json.encode({
        'quiz_id': quizId,
        'question_id': questionId,
        'answer': answer,
        'time_taken': timeTaken,
        'timestamp': DateTime.now().toIso8601String(),
      })
      ..queuedAt = DateTime.now();

    await _databaseService.queueOfflineAction(action);

    if (kDebugMode) {
      print('OfflineQueueService: Queued quiz answer for $questionId');
    }
  }

  /// Queue a quiz completion for later sync
  Future<void> queueQuizComplete({
    required String userId,
    required String quizId,
    required int totalQuestions,
    required int correctAnswers,
    required int totalTime,
  }) async {
    final action = OfflineAction()
      ..userId = userId
      ..actionType = actionQuizComplete
      ..actionDataJson = json.encode({
        'quiz_id': quizId,
        'total_questions': totalQuestions,
        'correct_answers': correctAnswers,
        'total_time': totalTime,
        'timestamp': DateTime.now().toIso8601String(),
      })
      ..queuedAt = DateTime.now();

    await _databaseService.queueOfflineAction(action);

    if (kDebugMode) {
      print('OfflineQueueService: Queued quiz completion for $quizId');
    }
  }

  /// Sync all pending actions to backend
  Future<SyncActionsResult> syncPendingActions({
    required String userId,
    required String authToken,
  }) async {
    final pendingActions = await _databaseService.getPendingActions(userId);

    if (pendingActions.isEmpty) {
      return SyncActionsResult(synced: 0, failed: 0);
    }

    int synced = 0;
    int failed = 0;
    int skipped = 0;

    for (final action in pendingActions) {
      // BUG-006 fix: Skip actions that have exceeded max retries
      if (action.retryCount >= maxRetries) {
        if (kDebugMode) {
          print('OfflineQueueService: Skipping action ${action.id} - max retries exceeded');
        }
        skipped++;
        continue;
      }

      try {
        bool success = false;

        switch (action.actionType) {
          case actionQuizAnswer:
            success = await _syncQuizAnswer(action, authToken);
            break;
          case actionQuizComplete:
            success = await _syncQuizComplete(action, authToken);
            break;
          default:
            // BUG-007 fix: Log warning for unknown action types instead of silently consuming
            if (kDebugMode) {
              print('OfflineQueueService: WARNING - Unknown action type: ${action.actionType}');
            }
            // Mark as synced to prevent infinite retry, but log it
            success = true;
        }

        if (success) {
          await _databaseService.markActionSynced(action.id);
          synced++;
        } else {
          // BUG-006 fix: Increment retry count on failure
          await _incrementRetryCount(action);
          failed++;
        }
      } catch (e) {
        if (kDebugMode) {
          print('OfflineQueueService: Error syncing action ${action.id}: $e');
        }
        // BUG-006 fix: Increment retry count on exception
        await _incrementRetryCount(action);
        failed++;
      }
    }

    if (kDebugMode) {
      print('OfflineQueueService: Synced $synced, failed $failed, skipped $skipped (max retries)');
    }

    return SyncActionsResult(synced: synced, failed: failed, skipped: skipped);
  }

  /// BUG-006 fix: Increment retry count for an action
  Future<void> _incrementRetryCount(OfflineAction action) async {
    try {
      action.retryCount++;
      await _databaseService.isar.writeTxn(() async {
        await _databaseService.isar.offlineActions.put(action);
      });
    } catch (e) {
      if (kDebugMode) {
        print('OfflineQueueService: Error incrementing retry count: $e');
      }
    }
  }

  /// Sync a single quiz answer
  Future<bool> _syncQuizAnswer(OfflineAction action, String authToken) async {
    try {
      final data = json.decode(action.actionDataJson) as Map<String, dynamic>;

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/daily-quiz/submit-answer'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'quizId': data['quiz_id'],
          'questionId': data['question_id'],
          'answer': data['answer'],
          'timeTaken': data['time_taken'],
        }),
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('OfflineQueueService: Error syncing quiz answer: $e');
      }
      return false;
    }
  }

  /// Sync a single quiz completion
  Future<bool> _syncQuizComplete(OfflineAction action, String authToken) async {
    try {
      final data = json.decode(action.actionDataJson) as Map<String, dynamic>;

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/daily-quiz/complete'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'quizId': data['quiz_id'],
        }),
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('OfflineQueueService: Error syncing quiz completion: $e');
      }
      return false;
    }
  }

  /// Get count of pending actions
  Future<int> getPendingActionsCount(String userId) async {
    return _databaseService.getPendingActionsCount(userId);
  }

  /// Get pending actions grouped by type
  Future<Map<String, int>> getPendingActionsByType(String userId) async {
    final actions = await _databaseService.getPendingActions(userId);
    final result = <String, int>{};

    for (final action in actions) {
      result[action.actionType] = (result[action.actionType] ?? 0) + 1;
    }

    return result;
  }
}

/// Result of syncing pending actions
class SyncActionsResult {
  final int synced;
  final int failed;
  final int skipped; // BUG-006 fix: Track actions skipped due to max retries

  SyncActionsResult({
    required this.synced,
    required this.failed,
    this.skipped = 0,
  });

  int get total => synced + failed + skipped;
  bool get hasFailures => failed > 0;
  bool get hasSkipped => skipped > 0;
}
