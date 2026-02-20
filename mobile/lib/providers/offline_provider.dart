// Offline Provider
//
// Central state management for offline functionality.
// Coordinates between connectivity service, database service, and sync operations.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/offline/connectivity_service.dart';
import '../services/offline/database_service_stub.dart'
    if (dart.library.io) '../services/offline/database_service.dart';
import '../services/offline/offline_queue_service_stub.dart'
    if (dart.library.io) '../services/offline/offline_queue_service.dart';
import '../models/offline/cached_solution_conditional.dart';

class OfflineProvider extends ChangeNotifier {
  final ConnectivityService _connectivityService;
  final DatabaseService _databaseService;
  final OfflineQueueService _offlineQueueService;

  bool _isInitialized = false;
  bool _offlineEnabled = false;
  String? _currentUserId;
  String? _authToken;
  int _cachedSolutionsCount = 0;
  int _availableQuizzesCount = 0;
  int _pendingActionsCount = 0;
  SyncState _syncState = SyncState.idle;
  String? _lastSyncError;
  DateTime? _lastSyncAt;

  // Sync mutex to prevent concurrent syncs
  Completer<void>? _syncCompleter;
  bool _isSyncing = false;

  OfflineProvider({
    ConnectivityService? connectivityService,
    DatabaseService? databaseService,
    OfflineQueueService? offlineQueueService,
  })  : _connectivityService = connectivityService ?? ConnectivityService(),
        _databaseService = databaseService ?? DatabaseService(),
        _offlineQueueService = offlineQueueService ?? OfflineQueueService() {
    // Listen to connectivity changes
    _connectivityService.addListener(_onConnectivityChanged);
  }

  // ============================================================================
  // GETTERS
  // ============================================================================

  /// Whether offline mode is initialized
  bool get isInitialized => _isInitialized;

  /// Whether offline mode is enabled for current user (Pro/Ultra)
  bool get offlineEnabled => _offlineEnabled;

  /// Whether device is currently online
  bool get isOnline => _connectivityService.isOnline;

  /// Whether device is currently offline
  bool get isOffline => _connectivityService.isOffline;

  /// Number of cached solutions
  int get cachedSolutionsCount => _cachedSolutionsCount;

  /// Number of available offline quizzes
  int get availableQuizzesCount => _availableQuizzesCount;

  /// Number of pending offline actions to sync
  int get pendingActionsCount => _pendingActionsCount;

  /// Current sync state
  SyncState get syncState => _syncState;

  /// Last sync error message
  String? get lastSyncError => _lastSyncError;

  /// Last successful sync time
  DateTime? get lastSyncAt => _lastSyncAt;

  /// Whether there are pending actions to sync
  bool get hasPendingActions => _pendingActionsCount > 0;

  /// Current user ID
  String? get currentUserId => _currentUserId;

  /// Whether a sync is currently in progress
  bool get isSyncing => _isSyncing;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  /// Initialize offline mode for a user
  Future<void> initialize(String userId, {bool offlineEnabled = false, String? authToken}) async {
    if (_isInitialized && _currentUserId == userId) {
      // Just update auth token if already initialized for same user
      _authToken = authToken;
      return;
    }

    _currentUserId = userId;
    _offlineEnabled = offlineEnabled;
    _authToken = authToken;

    try {
      // Initialize services
      await _connectivityService.initialize();
      await _databaseService.initialize();

      // Load cached counts
      await _refreshCounts();

      // Load sync status
      final syncStatus = await _databaseService.getSyncStatus(userId);
      _lastSyncAt = syncStatus.lastSyncAt;
      _syncState = syncStatus.syncState;
      _lastSyncError = syncStatus.lastSyncError;

      _isInitialized = true;
      notifyListeners();

      if (kDebugMode) {
        print('OfflineProvider: Initialized for user $userId, offline enabled: $offlineEnabled');
      }

      // Trigger initial sync if online and have pending actions
      if (_connectivityService.isOnline && hasPendingActions) {
        _syncPendingActions();
      }
    } catch (e) {
      if (kDebugMode) {
        print('OfflineProvider: Error during initialization: $e');
      }
      // Still mark as initialized to prevent repeated failures
      _isInitialized = true;
      _syncState = SyncState.error;
      _lastSyncError = e.toString();
      notifyListeners();
    }
  }

  /// Update auth token (called when token refreshes)
  void updateAuthToken(String? token) {
    _authToken = token;
  }

  /// Update offline enabled status (when tier changes)
  void updateOfflineEnabled(bool enabled) {
    if (_offlineEnabled != enabled) {
      _offlineEnabled = enabled;
      notifyListeners();

      if (kDebugMode) {
        print('OfflineProvider: Offline enabled changed to $enabled');
      }
    }
  }

  /// Refresh cached counts
  Future<void> _refreshCounts() async {
    if (_currentUserId == null) return;

    try {
      _cachedSolutionsCount = await _databaseService.getCachedSolutionsCount(_currentUserId!);
      _availableQuizzesCount = await _databaseService.getAvailableQuizzesCount(_currentUserId!);
      _pendingActionsCount = await _databaseService.getPendingActionsCount(_currentUserId!);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('OfflineProvider: Error refreshing counts: $e');
      }
    }
  }

  // ============================================================================
  // CONNECTIVITY HANDLING
  // ============================================================================

  /// Handle connectivity changes
  void _onConnectivityChanged() {
    notifyListeners();

    if (_connectivityService.isOnline && hasPendingActions && _isInitialized) {
      // Trigger sync when coming back online
      _syncPendingActions();
    }
  }

  /// Force refresh connectivity status
  Future<bool> refreshConnectivity() async {
    final result = await _connectivityService.refresh();
    notifyListeners();
    return result;
  }

  // ============================================================================
  // CACHED SOLUTIONS
  // ============================================================================

  /// Get cached solutions for current user
  Future<List<CachedSolution>> getCachedSolutions({int? limit}) async {
    if (_currentUserId == null) return [];
    try {
      return await _databaseService.getCachedSolutions(_currentUserId!, limit: limit);
    } catch (e) {
      if (kDebugMode) {
        print('OfflineProvider: Error getting cached solutions: $e');
      }
      return [];
    }
  }

  /// Get a specific cached solution
  Future<CachedSolution?> getCachedSolution(String solutionId) async {
    try {
      return await _databaseService.getCachedSolution(solutionId);
    } catch (e) {
      if (kDebugMode) {
        print('OfflineProvider: Error getting cached solution: $e');
      }
      return null;
    }
  }

  /// Check if a solution is cached
  Future<bool> isSolutionCached(String solutionId) async {
    final solution = await getCachedSolution(solutionId);
    return solution != null;
  }

  // ============================================================================
  // CACHED QUIZZES
  // ============================================================================

  /// Get available offline quizzes
  Future<List<CachedQuiz>> getAvailableQuizzes() async {
    if (_currentUserId == null) return [];
    try {
      return await _databaseService.getAvailableQuizzes(_currentUserId!);
    } catch (e) {
      if (kDebugMode) {
        print('OfflineProvider: Error getting available quizzes: $e');
      }
      return [];
    }
  }

  /// Mark a quiz as used
  Future<void> markQuizUsed(String quizId) async {
    try {
      await _databaseService.markQuizUsed(quizId);
      await _refreshCounts();
    } catch (e) {
      if (kDebugMode) {
        print('OfflineProvider: Error marking quiz used: $e');
      }
    }
  }

  // ============================================================================
  // OFFLINE ACTIONS QUEUE
  // ============================================================================

  /// Queue an offline action
  Future<void> queueAction(String actionType, Map<String, dynamic> data) async {
    if (_currentUserId == null) return;

    try {
      final action = OfflineAction()
        ..userId = _currentUserId!
        ..actionType = actionType
        ..actionDataJson = json.encode(data)
        ..queuedAt = DateTime.now();

      await _databaseService.queueOfflineAction(action);
      await _refreshCounts();

      if (kDebugMode) {
        print('OfflineProvider: Queued action $actionType');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OfflineProvider: Error queuing action: $e');
      }
    }
  }

  /// Sync pending actions when online (with mutex protection)
  Future<void> _syncPendingActions() async {
    // Prevent concurrent syncs
    if (_isSyncing) {
      // Wait for existing sync to complete
      await _syncCompleter?.future;
      return;
    }

    if (_currentUserId == null || !_connectivityService.isOnline || _authToken == null) {
      return;
    }

    _isSyncing = true;
    _syncCompleter = Completer<void>();

    try {
      await updateSyncState(SyncState.syncing);

      if (kDebugMode) {
        print('OfflineProvider: Starting sync of pending actions...');
      }

      // Use the OfflineQueueService to sync
      final result = await _offlineQueueService.syncPendingActions(
        userId: _currentUserId!,
        authToken: _authToken!,
      );

      // Refresh counts after sync
      await _refreshCounts();

      if (result.hasFailures) {
        await updateSyncState(
          SyncState.error,
          error: '${result.failed} action(s) failed to sync',
        );
      } else {
        await updateSyncState(SyncState.completed);
      }

      if (kDebugMode) {
        print('OfflineProvider: Sync completed - ${result.synced} synced, ${result.failed} failed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OfflineProvider: Sync error: $e');
      }
      await updateSyncState(SyncState.error, error: e.toString());
    } finally {
      // BUG-003 fix: Complete and nullify completer BEFORE setting flag to false
      _syncCompleter?.complete();
      _syncCompleter = null;
      _isSyncing = false;
    }
  }

  /// Manually trigger sync
  Future<void> syncNow() async {
    if (!_connectivityService.isOnline) {
      if (kDebugMode) {
        print('OfflineProvider: Cannot sync while offline');
      }
      return;
    }
    await _syncPendingActions();
  }

  // ============================================================================
  // SYNC MANAGEMENT
  // ============================================================================

  /// Update sync state
  Future<void> updateSyncState(SyncState state, {String? error}) async {
    _syncState = state;
    _lastSyncError = error;

    if (state == SyncState.completed) {
      _lastSyncAt = DateTime.now();
    }

    // Persist to database
    if (_currentUserId != null) {
      try {
        final status = await _databaseService.getSyncStatus(_currentUserId!);
        status.syncState = state;
        status.lastSyncError = error;
        if (state == SyncState.completed) {
          status.lastSyncAt = DateTime.now();
        }
        status.lastSyncAttemptAt = DateTime.now();
        await _databaseService.updateSyncStatus(status);
      } catch (e) {
        if (kDebugMode) {
          print('OfflineProvider: Error updating sync status: $e');
        }
      }
    }

    notifyListeners();
  }

  /// Get formatted last sync time
  /// BUG-012 fix: Ensure consistent local time comparison
  String? get lastSyncTimeFormatted {
    if (_lastSyncAt == null) return null;

    // Convert to local time if needed for consistent comparison
    final syncTime = _lastSyncAt!.isUtc ? _lastSyncAt!.toLocal() : _lastSyncAt!;
    final now = DateTime.now();
    final diff = now.difference(syncTime);

    // Handle edge case of negative difference (clock skew)
    if (diff.isNegative) {
      return 'Just now';
    }

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  /// Clear all user data (on logout)
  Future<void> clearUserData() async {
    // Wait for any ongoing sync to complete
    await _syncCompleter?.future;

    if (_currentUserId != null) {
      try {
        await _databaseService.clearUserData(_currentUserId!);
      } catch (e) {
        if (kDebugMode) {
          print('OfflineProvider: Error clearing user data: $e');
        }
      }
    }

    _currentUserId = null;
    _authToken = null;
    _offlineEnabled = false;
    _cachedSolutionsCount = 0;
    _availableQuizzesCount = 0;
    _pendingActionsCount = 0;
    _syncState = SyncState.idle;
    _lastSyncAt = null;
    _lastSyncError = null;
    _isInitialized = false;

    notifyListeners();

    if (kDebugMode) {
      print('OfflineProvider: Cleared user data');
    }
  }

  /// Clean up expired data
  Future<void> cleanupExpiredData() async {
    try {
      await _databaseService.deleteExpiredSolutions();
      await _databaseService.deleteExpiredQuizzes();
      await _databaseService.cleanupSyncedActions();
      await _refreshCounts();

      if (kDebugMode) {
        print('OfflineProvider: Cleaned up expired data');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OfflineProvider: Error cleaning up expired data: $e');
      }
    }
  }

  @override
  void dispose() {
    _connectivityService.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}
