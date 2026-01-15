// Sync Service
//
// Handles synchronization of solutions and other data between
// the backend and local Isar database for offline access.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import 'image_cache_service.dart';
import '../../models/offline/cached_solution.dart';
import '../../models/snap_data_model.dart';
import '../api_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  SyncService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final ImageCacheService _imageCacheService = ImageCacheService();

  // Sync mutex using Completer
  Completer<SyncResult>? _syncCompleter;
  bool _isSyncing = false;

  // Note: Solution limits are now fetched from subscription status
  // These are fallback values only (should not be used in production)
  // Backend config: Pro/Ultra both have offline_solutions_limit: -1 (unlimited)
  @Deprecated('Use subscription status limit instead')
  static const int proTierSolutionLimit = 50;
  @Deprecated('Use subscription status limit instead')
  static const int ultraTierSolutionLimit = 200;

  // HTTP timeout
  static const Duration _httpTimeout = Duration(seconds: 30);

  /// Sync solutions from backend to local database (thread-safe)
  Future<SyncResult> syncSolutions({
    required String userId,
    required String authToken,
    required int maxSolutions,
    DateTime? since,
    Function(int current, int total)? onProgress,
  }) async {
    // If sync is already in progress, wait for it
    if (_isSyncing && _syncCompleter != null) {
      return _syncCompleter!.future;
    }

    _isSyncing = true;
    _syncCompleter = Completer<SyncResult>();

    try {
      final result = await _performSync(
        userId: userId,
        authToken: authToken,
        maxSolutions: maxSolutions,
        since: since,
        onProgress: onProgress,
      );
      _syncCompleter?.complete(result);
      return result;
    } catch (e) {
      final errorResult = SyncResult(
        success: false,
        error: e.toString(),
        syncedCount: 0,
      );
      _syncCompleter?.complete(errorResult);
      return errorResult;
    } finally {
      // BUG-003 fix: Nullify completer BEFORE setting flag to false
      // This prevents race condition where new sync starts while
      // old completer is still being accessed
      _syncCompleter = null;
      _isSyncing = false;
    }
  }

  /// Internal sync implementation
  Future<SyncResult> _performSync({
    required String userId,
    required String authToken,
    required int maxSolutions,
    DateTime? since,
    Function(int current, int total)? onProgress,
  }) async {
    if (kDebugMode) {
      print('SyncService: Starting sync for user $userId');
    }

    // Fetch solutions from backend
    final solutions = await _fetchSolutionsFromBackend(
      authToken: authToken,
      since: since,
      limit: maxSolutions,
    );

    if (solutions == null) {
      return SyncResult(
        success: false,
        error: 'Failed to fetch solutions from backend',
        syncedCount: 0,
      );
    }

    if (kDebugMode) {
      print('SyncService: Fetched ${solutions.length} solutions from backend');
    }

    // Cache each solution
    int syncedCount = 0;
    for (int i = 0; i < solutions.length; i++) {
      final solution = solutions[i];

      try {
        // Convert to CachedSolution
        final cachedSolution = _convertToCachedSolution(solution, userId);

        // Cache image FIRST if available (before saving to DB)
        if (solution.imageUrl != null && solution.imageUrl!.isNotEmpty) {
          final localPath = await _imageCacheService.cacheImage(solution.imageUrl!);
          if (localPath != null) {
            cachedSolution.localImagePath = localPath;
            cachedSolution.isImageCached = true;
          }
        }

        // Save to database ONCE (after image caching)
        await _databaseService.saveCachedSolution(cachedSolution);

        syncedCount++;
        onProgress?.call(syncedCount, solutions.length);
      } catch (e) {
        if (kDebugMode) {
          print('SyncService: Error caching solution ${solution.id}: $e');
        }
      }
    }

    // Evict excess solutions and clean up orphaned images (BUG-009 fix)
    try {
      final evictionResult = await _databaseService.evictExcessSolutions(userId, maxSolutions);

      // Clean up orphaned cached images
      if (evictionResult.imagePaths.isNotEmpty) {
        for (final imagePath in evictionResult.imagePaths) {
          try {
            await _imageCacheService.removeFromCache(imagePath);
          } catch (e) {
            if (kDebugMode) {
              print('SyncService: Error removing orphaned image $imagePath: $e');
            }
          }
        }
        if (kDebugMode) {
          print('SyncService: Cleaned up ${evictionResult.imagePaths.length} orphaned images');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('SyncService: Error evicting excess solutions: $e');
      }
    }

    if (kDebugMode) {
      print('SyncService: Synced $syncedCount/${solutions.length} solutions');
    }

    return SyncResult(
      success: true,
      syncedCount: syncedCount,
      totalFetched: solutions.length,
    );
  }

  /// Fetch solutions from backend API
  Future<List<RecentSolution>?> _fetchSolutionsFromBackend({
    required String authToken,
    DateTime? since,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (since != null) {
        queryParams['since'] = since.toIso8601String();
      }
      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }

      final uri = Uri.parse('${ApiService.baseUrl}/api/snap-history')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(_httpTimeout);

      // Accept 2xx status codes
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (kDebugMode) {
          print('SyncService: Backend returned status ${response.statusCode}');
        }
        return null;
      }

      final data = json.decode(response.body);

      if (data['success'] != true || data['data'] == null) {
        return null;
      }

      final List<dynamic> snapsJson = data['data']['snaps'] ?? [];

      return snapsJson.map((snapJson) {
        // Safe cast for solutionData
        Map<String, dynamic>? solutionData;
        final rawSolution = snapJson['solution'];
        if (rawSolution is Map<String, dynamic>) {
          solutionData = rawSolution;
        } else if (rawSolution is Map) {
          solutionData = Map<String, dynamic>.from(rawSolution);
        }

        return RecentSolution(
          id: snapJson['snapId']?.toString() ?? '',
          question: snapJson['question']?.toString() ?? '',
          subject: snapJson['subject']?.toString() ?? 'Unknown',
          topic: snapJson['topic']?.toString() ?? 'General',
          timestamp: snapJson['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
          imageUrl: snapJson['imageUrl']?.toString(),
          solutionData: solutionData,
          language: snapJson['language']?.toString() ?? 'en',
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('SyncService: Error fetching from backend: $e');
      }
      return null;
    }
  }

  /// Convert RecentSolution to CachedSolution
  CachedSolution _convertToCachedSolution(RecentSolution solution, String userId) {
    final now = DateTime.now();

    return CachedSolution()
      ..solutionId = solution.id
      ..userId = userId
      ..question = solution.question
      ..topic = solution.topic
      ..subject = solution.subject
      ..timestamp = DateTime.tryParse(solution.timestamp) ?? now
      ..solutionDataJson = json.encode(solution.solutionData ?? {})
      ..originalImageUrl = solution.imageUrl
      ..language = solution.language
      ..cachedAt = now
      ..expiresAt = now.add(const Duration(days: 30))
      ..lastAccessedAt = now;
  }

  /// Convert CachedSolution back to RecentSolution
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
        print('SyncService: Error decoding solution data: $e');
      }
      solutionData = null;
    }

    return RecentSolution(
      id: cached.solutionId,
      question: cached.question,
      subject: cached.subject,
      topic: cached.topic,
      timestamp: cached.timestamp.toIso8601String(),
      imageUrl: cached.isImageCached ? cached.localImagePath : cached.originalImageUrl,
      solutionData: solutionData,
      language: cached.language,
    );
  }

  /// Cache a single solution immediately (for automatic caching after Snap & Solve)
  /// Returns true if cached successfully, false otherwise
  Future<bool> cacheSolution({
    required RecentSolution solution,
    required String userId,
    String? imageUrl,
  }) async {
    try {
      if (kDebugMode) {
        print('SyncService: Caching solution ${solution.id} for offline access');
      }

      // Convert to CachedSolution
      final cachedSolution = _convertToCachedSolution(solution, userId);

      // Cache image if available
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final localPath = await _imageCacheService.cacheImage(imageUrl);
          if (localPath != null) {
            cachedSolution.localImagePath = localPath;
            cachedSolution.isImageCached = true;
          }
        } catch (e) {
          if (kDebugMode) {
            print('SyncService: Error caching image for solution ${solution.id}: $e');
          }
          // Continue even if image caching fails
        }
      }

      // Save to database
      await _databaseService.saveCachedSolution(cachedSolution);

      // Check if we need to evict excess solutions
      // Get limit from subscription status (will be handled by caller if needed)
      // For now, we'll let the periodic sync handle eviction

      if (kDebugMode) {
        print('SyncService: Successfully cached solution ${solution.id}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('SyncService: Error caching solution ${solution.id}: $e');
      }
      return false;
    }
  }

  /// Get sync progress info
  bool get isSyncing => _isSyncing;
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String? error;
  final int syncedCount;
  final int totalFetched;

  SyncResult({
    required this.success,
    this.error,
    required this.syncedCount,
    this.totalFetched = 0,
  });
}
