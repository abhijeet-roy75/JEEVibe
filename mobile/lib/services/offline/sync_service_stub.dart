// Stub Sync Service for Web
// This file is used on web where offline sync is not supported

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/offline/cached_solution_conditional.dart';
import '../../models/snap_data_model.dart';

/// Result of a sync operation
class SyncResult {
  final bool success;
  final int syncedCount;
  final String? error;

  SyncResult({
    required this.success,
    required this.syncedCount,
    this.error,
  });

  factory SyncResult.success(int count) => SyncResult(
        success: true,
        syncedCount: count,
      );

  factory SyncResult.failure(String error) => SyncResult(
        success: false,
        syncedCount: 0,
        error: error,
      );
}

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  SyncService._internal();

  /// Sync solutions (no-op on web)
  Future<SyncResult> syncSolutions({
    required String userId,
    required String authToken,
    required int maxSolutions,
  }) async {
    if (kDebugMode) {
      print('SyncService (Web Stub): Sync not supported on web');
    }
    return SyncResult.failure('Offline sync not supported on web');
  }

  /// Convert CachedSolution to RecentSolution (stub implementation)
  RecentSolution convertToRecentSolution(CachedSolution cached) {
    Map<String, dynamic>? solutionData;
    try {
      final decoded = json.decode(cached.solutionDataJson);
      if (decoded is Map<String, dynamic>) {
        solutionData = decoded;
      } else if (decoded is Map) {
        solutionData = Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      if (kDebugMode) {
        print('SyncService (Web Stub): Error decoding solution data: $e');
      }
      solutionData = null;
    }

    return RecentSolution(
      id: cached.solutionId,
      question: cached.question,
      subject: cached.subject,
      topic: cached.topic,
      timestamp: cached.timestamp.toIso8601String(), // Convert DateTime to String
      solutionData: solutionData,
      imageUrl: cached.originalImageUrl ?? '',
      language: cached.language ?? 'en',
    );
  }

  /// Cache a solution (no-op on web)
  Future<bool> cacheSolution({
    required RecentSolution solution,
    required String userId,
    String? imageUrl,
  }) async {
    if (kDebugMode) {
      print('SyncService (Web Stub): Cache solution not supported on web');
    }
    return false;
  }

  /// All other methods throw UnsupportedError
  dynamic noSuchMethod(Invocation invocation) {
    if (kDebugMode) {
      print('SyncService: Offline sync not supported on web');
    }
    throw UnsupportedError('Offline sync not supported on web platform');
  }
}
