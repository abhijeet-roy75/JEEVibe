// Database Service for Isar
//
// Manages the Isar database instance and provides CRUD operations
// for offline cached data.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/offline/cached_solution.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;

  Isar? _isar;
  bool _isInitialized = false;

  // BUG-008 fix: Thread-safe initialization using Completer
  Completer<void>? _initCompleter;

  DatabaseService._internal();

  /// Whether the database has been initialized
  bool get isInitialized => _isInitialized;

  /// Get the Isar instance
  Isar get isar {
    if (_isar == null) {
      throw Exception('DatabaseService not initialized. Call initialize() first.');
    }
    return _isar!;
  }

  /// Initialize the Isar database (thread-safe)
  Future<void> initialize() async {
    // Already initialized
    if (_isInitialized) return;

    // BUG-008 fix: If initialization is in progress, wait for it
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }

    // Start initialization
    _initCompleter = Completer<void>();

    try {
      final dir = await getApplicationDocumentsDirectory();

      _isar = await Isar.open(
        [
          CachedSolutionSchema,
          CachedQuizSchema,
          CachedAnalyticsSchema,
          SyncStatusSchema,
          OfflineActionSchema,
        ],
        directory: dir.path,
        name: 'jeevibe_offline',
      );

      _isInitialized = true;

      if (kDebugMode) {
        print('DatabaseService: Isar database initialized');
      }

      _initCompleter?.complete();
    } catch (e) {
      _initCompleter?.completeError(e);
      rethrow;
    } finally {
      _initCompleter = null;
    }
  }

  /// Close the database
  Future<void> close() async {
    await _isar?.close();
    _isar = null;
    _isInitialized = false;
  }

  // ============================================================================
  // CACHED SOLUTIONS
  // ============================================================================

  /// Save a cached solution
  Future<int> saveCachedSolution(CachedSolution solution) async {
    return isar.writeTxn(() async {
      return isar.cachedSolutions.put(solution);
    });
  }

  /// Get a cached solution by ID
  Future<CachedSolution?> getCachedSolution(String solutionId) async {
    final solution = await isar.cachedSolutions
        .where()
        .solutionIdEqualTo(solutionId)
        .findFirst();

    // Update last accessed time
    if (solution != null) {
      solution.lastAccessedAt = DateTime.now();
      await isar.writeTxn(() async {
        await isar.cachedSolutions.put(solution);
      });
    }

    return solution;
  }

  /// Get all cached solutions for a user
  Future<List<CachedSolution>> getCachedSolutions(String userId, {int? limit}) async {
    var query = isar.cachedSolutions
        .where()
        .userIdEqualTo(userId)
        .sortByTimestampDesc();

    if (limit != null) {
      return query.limit(limit).findAll();
    }

    return query.findAll();
  }

  /// Get cached solutions count for a user
  Future<int> getCachedSolutionsCount(String userId) async {
    return isar.cachedSolutions
        .where()
        .userIdEqualTo(userId)
        .count();
  }

  /// Delete cached solutions older than a date
  Future<int> deleteExpiredSolutions() async {
    final now = DateTime.now();
    return isar.writeTxn(() async {
      return isar.cachedSolutions
          .filter()
          .expiresAtLessThan(now)
          .deleteAll();
    });
  }

  /// Delete least recently used solutions beyond limit
  /// BUG-009 fix: Returns EvictionResult with image paths for cleanup
  Future<EvictionResult> evictExcessSolutions(String userId, int maxSolutions) async {
    final count = await getCachedSolutionsCount(userId);
    if (count <= maxSolutions) return EvictionResult(deletedCount: 0, imagePaths: []);

    final toDelete = count - maxSolutions;

    // Get LRU solutions
    final lruSolutions = await isar.cachedSolutions
        .where()
        .userIdEqualTo(userId)
        .sortByLastAccessedAt()
        .limit(toDelete)
        .findAll();

    // BUG-009 fix: Collect image paths before deletion
    final imagePaths = lruSolutions
        .where((s) => s.localImagePath != null && s.localImagePath!.isNotEmpty)
        .map((s) => s.localImagePath!)
        .toList();

    final deletedCount = await isar.writeTxn(() async {
      return isar.cachedSolutions
          .deleteAll(lruSolutions.map((s) => s.id).toList());
    });

    return EvictionResult(deletedCount: deletedCount, imagePaths: imagePaths);
  }

  /// Delete all cached solutions for a user
  Future<int> clearUserSolutions(String userId) async {
    return isar.writeTxn(() async {
      return isar.cachedSolutions
          .filter()
          .userIdEqualTo(userId)
          .deleteAll();
    });
  }

  // ============================================================================
  // CACHED QUIZZES
  // ============================================================================

  /// Save a cached quiz
  Future<int> saveCachedQuiz(CachedQuiz quiz) async {
    return isar.writeTxn(() async {
      return isar.cachedQuizs.put(quiz);
    });
  }

  /// Get available (unused, not expired) quizzes for a user
  Future<List<CachedQuiz>> getAvailableQuizzes(String userId) async {
    final now = DateTime.now();
    return isar.cachedQuizs
        .filter()
        .userIdEqualTo(userId)
        .isUsedEqualTo(false)
        .expiresAtGreaterThan(now)
        .findAll();
  }

  /// Get count of available quizzes
  Future<int> getAvailableQuizzesCount(String userId) async {
    final now = DateTime.now();
    return isar.cachedQuizs
        .filter()
        .userIdEqualTo(userId)
        .isUsedEqualTo(false)
        .expiresAtGreaterThan(now)
        .count();
  }

  /// Mark a quiz as used
  Future<void> markQuizUsed(String quizId) async {
    final quiz = await isar.cachedQuizs
        .where()
        .quizIdEqualTo(quizId)
        .findFirst();

    if (quiz != null) {
      quiz.isUsed = true;
      await isar.writeTxn(() async {
        await isar.cachedQuizs.put(quiz);
      });
    }
  }

  /// Delete expired quizzes
  Future<int> deleteExpiredQuizzes() async {
    final now = DateTime.now();
    return isar.writeTxn(() async {
      return isar.cachedQuizs
          .filter()
          .expiresAtLessThan(now)
          .deleteAll();
    });
  }

  // ============================================================================
  // CACHED ANALYTICS
  // ============================================================================

  /// Save cached analytics
  Future<int> saveCachedAnalytics(CachedAnalytics analytics) async {
    return isar.writeTxn(() async {
      // Delete existing for this user first
      await isar.cachedAnalytics
          .filter()
          .userIdEqualTo(analytics.userId)
          .deleteAll();
      return isar.cachedAnalytics.put(analytics);
    });
  }

  /// Get cached analytics for a user
  Future<CachedAnalytics?> getCachedAnalytics(String userId) async {
    final now = DateTime.now();
    return isar.cachedAnalytics
        .filter()
        .userIdEqualTo(userId)
        .expiresAtGreaterThan(now)
        .findFirst();
  }

  // ============================================================================
  // SYNC STATUS
  // ============================================================================

  /// Get or create sync status for a user
  Future<SyncStatus> getSyncStatus(String userId) async {
    var status = await isar.syncStatus
        .where()
        .userIdEqualTo(userId)
        .findFirst();

    if (status == null) {
      status = SyncStatus()
        ..userId = userId
        ..syncState = SyncState.idle;
      await isar.writeTxn(() async {
        await isar.syncStatus.put(status!);
      });
    }

    return status;
  }

  /// Update sync status
  Future<void> updateSyncStatus(SyncStatus status) async {
    await isar.writeTxn(() async {
      await isar.syncStatus.put(status);
    });
  }

  // ============================================================================
  // OFFLINE ACTIONS (QUEUE)
  // ============================================================================

  /// Queue an offline action
  Future<int> queueOfflineAction(OfflineAction action) async {
    return isar.writeTxn(() async {
      return isar.offlineActions.put(action);
    });
  }

  /// Get pending offline actions for a user
  Future<List<OfflineAction>> getPendingActions(String userId) async {
    return isar.offlineActions
        .filter()
        .userIdEqualTo(userId)
        .isSyncedEqualTo(false)
        .sortByQueuedAt()
        .findAll();
  }

  /// Mark an action as synced
  Future<void> markActionSynced(int actionId) async {
    final action = await isar.offlineActions.get(actionId);
    if (action != null) {
      action.isSynced = true;
      await isar.writeTxn(() async {
        await isar.offlineActions.put(action);
      });
    }
  }

  /// Delete synced actions older than a day
  Future<int> cleanupSyncedActions() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    return isar.writeTxn(() async {
      return isar.offlineActions
          .filter()
          .isSyncedEqualTo(true)
          .queuedAtLessThan(cutoff)
          .deleteAll();
    });
  }

  /// Get pending actions count for a user
  Future<int> getPendingActionsCount(String userId) async {
    return isar.offlineActions
        .filter()
        .userIdEqualTo(userId)
        .isSyncedEqualTo(false)
        .count();
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  /// Clear all data for a user (on logout)
  Future<void> clearUserData(String userId) async {
    await isar.writeTxn(() async {
      await isar.cachedSolutions.filter().userIdEqualTo(userId).deleteAll();
      await isar.cachedQuizs.filter().userIdEqualTo(userId).deleteAll();
      await isar.cachedAnalytics.filter().userIdEqualTo(userId).deleteAll();
      await isar.syncStatus.filter().userIdEqualTo(userId).deleteAll();
      await isar.offlineActions.filter().userIdEqualTo(userId).deleteAll();
    });

    if (kDebugMode) {
      print('DatabaseService: Cleared all data for user $userId');
    }
  }

  /// Clear all data (full reset)
  Future<void> clearAllData() async {
    await isar.writeTxn(() async {
      await isar.cachedSolutions.clear();
      await isar.cachedQuizs.clear();
      await isar.cachedAnalytics.clear();
      await isar.syncStatus.clear();
      await isar.offlineActions.clear();
    });

    if (kDebugMode) {
      print('DatabaseService: Cleared all data');
    }
  }
}

/// BUG-009 fix: Result of evicting excess solutions
class EvictionResult {
  final int deletedCount;
  final List<String> imagePaths;

  EvictionResult({
    required this.deletedCount,
    required this.imagePaths,
  });
}
