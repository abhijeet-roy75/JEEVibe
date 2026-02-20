// Stub Offline Queue Service for Web
// This file is used on web where offline queue is not supported

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Result of syncing pending actions
class SyncActionsResult {
  final int synced;
  final int failed;
  final int skipped;

  SyncActionsResult({
    required this.synced,
    required this.failed,
    this.skipped = 0,
  });

  int get total => synced + failed + skipped;
  bool get hasFailures => failed > 0;
  bool get hasSkipped => skipped > 0;
}

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;

  OfflineQueueService._internal();

  /// Queue an action (no-op on web)
  Future<void> queueAction(Map<String, dynamic> action) async {
    if (kDebugMode) {
      print('OfflineQueueService (Web Stub): Offline queue not supported on web');
    }
  }

  /// Sync pending actions (no-op on web)
  Future<SyncActionsResult> syncPendingActions({
    required String userId,
    required String authToken,
  }) async {
    if (kDebugMode) {
      print('OfflineQueueService (Web Stub): Sync not supported on web');
    }
    return SyncActionsResult(synced: 0, failed: 0);
  }

  /// All other methods throw UnsupportedError
  dynamic noSuchMethod(Invocation invocation) {
    if (kDebugMode) {
      print('OfflineQueueService: Offline queue not supported on web');
    }
    throw UnsupportedError('Offline queue not supported on web platform');
  }
}
