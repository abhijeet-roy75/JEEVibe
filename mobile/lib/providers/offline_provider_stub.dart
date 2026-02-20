// Stub Offline Provider for Web
// This file is used on web where offline features are not supported

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/offline/cached_solution_conditional.dart';

class OfflineProvider extends ChangeNotifier {
  bool _isInitialized = false;
  bool _offlineEnabled = false;
  String? _currentUserId;

  // ============================================================================
  // GETTERS
  // ============================================================================

  bool get isInitialized => _isInitialized;
  bool get offlineEnabled => false; // Always false on web
  bool get isOnline => true; // Always online on web
  bool get isOffline => false; // Never offline on web
  int get cachedSolutionsCount => 0;
  int get availableQuizzesCount => 0;
  int get pendingActionsCount => 0;
  SyncState get syncState => SyncState.idle;
  String? get lastSyncError => null;
  DateTime? get lastSyncAt => null;
  bool get hasPendingActions => false;
  String? get currentUserId => _currentUserId;
  bool get isSyncing => false;
  String? get lastSyncTimeFormatted => null;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  Future<void> initialize(String userId, {bool offlineEnabled = false, String? authToken}) async {
    _currentUserId = userId;
    _offlineEnabled = false; // Always disabled on web
    _isInitialized = true;

    if (kDebugMode) {
      print('OfflineProvider (Web Stub): Initialized for user $userId (offline features disabled)');
    }
    notifyListeners();
  }

  void updateAuthToken(String? token) {
    // No-op on web
  }

  void updateOfflineEnabled(bool enabled) {
    // No-op on web - always disabled
  }

  // ============================================================================
  // CONNECTIVITY HANDLING
  // ============================================================================

  Future<bool> refreshConnectivity() async {
    return true; // Always online on web
  }

  // ============================================================================
  // CACHED SOLUTIONS
  // ============================================================================

  Future<List<CachedSolution>> getCachedSolutions({int? limit}) async {
    return [];
  }

  Future<CachedSolution?> getCachedSolution(String solutionId) async {
    return null;
  }

  Future<bool> isSolutionCached(String solutionId) async {
    return false;
  }

  // ============================================================================
  // CACHED QUIZZES
  // ============================================================================

  Future<List<CachedQuiz>> getAvailableQuizzes() async {
    return [];
  }

  Future<void> markQuizUsed(String quizId) async {
    // No-op on web
  }

  // ============================================================================
  // OFFLINE ACTIONS QUEUE
  // ============================================================================

  Future<void> queueAction(String actionType, Map<String, dynamic> data) async {
    if (kDebugMode) {
      print('OfflineProvider (Web Stub): Queue action not supported - $actionType');
    }
  }

  Future<void> syncNow() async {
    if (kDebugMode) {
      print('OfflineProvider (Web Stub): Sync not supported on web');
    }
  }

  // ============================================================================
  // SYNC MANAGEMENT
  // ============================================================================

  Future<void> updateSyncState(SyncState state, {String? error}) async {
    // No-op on web
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  Future<void> clearUserData() async {
    _currentUserId = null;
    _offlineEnabled = false;
    _isInitialized = false;
    notifyListeners();

    if (kDebugMode) {
      print('OfflineProvider (Web Stub): Cleared user data');
    }
  }

  Future<void> cleanupExpiredData() async {
    // No-op on web
  }

  @override
  void dispose() {
    super.dispose();
  }
}
