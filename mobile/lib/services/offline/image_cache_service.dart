// Image Cache Service
//
// Manages caching of solution images for offline viewing.
// Uses flutter_cache_manager for efficient image caching.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Result of an image cache operation
class ImageCacheResult {
  final bool success;
  final String? localPath;
  final String? error;
  final ImageCacheErrorType? errorType;

  ImageCacheResult({
    required this.success,
    this.localPath,
    this.error,
    this.errorType,
  });

  factory ImageCacheResult.success(String path) => ImageCacheResult(
    success: true,
    localPath: path,
  );

  factory ImageCacheResult.failure(String error, ImageCacheErrorType type) => ImageCacheResult(
    success: false,
    error: error,
    errorType: type,
  );
}

enum ImageCacheErrorType {
  notInitialized,
  invalidUrl,
  untrustedDomain,
  networkError,
  storageError,
  timeout,
  unknown,
}

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;

  ImageCacheService._internal();

  // Custom cache manager for solution images
  CacheManager? _cacheManager;
  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  // Cached cache size (updated periodically)
  int? _cachedSize;
  DateTime? _cacheSizeLastUpdated;
  static const Duration _cacheSizeValidityDuration = Duration(minutes: 5);

  // Cache size limits by tier (in bytes)
  static const int freeTierCacheLimit = 0; // No cache for free tier
  static const int proTierCacheLimit = 100 * 1024 * 1024; // 100 MB
  static const int ultraTierCacheLimit = 500 * 1024 * 1024; // 500 MB

  // Timeouts
  static const Duration _firebaseTimeout = Duration(seconds: 15);
  static const Duration _downloadTimeout = Duration(seconds: 30);

  // Trusted domains for URL validation
  static const List<String> _trustedDomains = [
    'firebasestorage.googleapis.com',
    'storage.googleapis.com',
    'jeevibe.com',
    'api.jeevibe.com',
  ];

  /// Initialize the image cache service (thread-safe)
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Another initialization is in progress, wait for it
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }

    _initCompleter = Completer<void>();

    try {
      _cacheManager = CacheManager(
        Config(
          'jeevibe_solution_images',
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 500,
        ),
      );

      _isInitialized = true;

      if (kDebugMode) {
        print('ImageCacheService: Initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ImageCacheService: Initialization error: $e');
      }
      // Still mark as initialized to prevent repeated failures
      _isInitialized = true;
    } finally {
      _initCompleter?.complete();
      _initCompleter = null;
    }
  }

  /// Validate URL against trusted domains
  bool _isUrlTrusted(String url) {
    // Allow gs:// URLs (Firebase Storage)
    if (url.startsWith('gs://')) {
      return true;
    }

    // Allow local file paths
    if (url.startsWith('/') || url.startsWith('file://')) {
      return true;
    }

    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

      // Check against trusted domains
      return _trustedDomains.any((domain) =>
        host == domain || host.endsWith('.$domain')
      );
    } catch (e) {
      return false;
    }
  }

  /// Resolve a Firebase Storage URL (gs://) to HTTPS URL with timeout
  Future<String?> resolveGsUrl(String url) async {
    if (!url.startsWith('gs://')) {
      return url;
    }

    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      return await ref.getDownloadURL().timeout(_firebaseTimeout);
    } on TimeoutException catch (_) {
      if (kDebugMode) {
        print('ImageCacheService: Timeout resolving gs:// URL');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('ImageCacheService: Error resolving gs:// URL: $e');
      }
      return null;
    }
  }

  /// Cache an image from URL and return the local file path
  Future<String?> cacheImage(String imageUrl) async {
    final result = await cacheImageWithResult(imageUrl);
    return result.localPath;
  }

  /// Cache an image from URL with detailed result
  Future<ImageCacheResult> cacheImageWithResult(String imageUrl) async {
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        return ImageCacheResult.failure(
          'Failed to initialize cache service',
          ImageCacheErrorType.notInitialized,
        );
      }
    }

    if (_cacheManager == null) {
      return ImageCacheResult.failure(
        'Cache manager not available',
        ImageCacheErrorType.notInitialized,
      );
    }

    // Validate URL
    if (imageUrl.isEmpty) {
      return ImageCacheResult.failure(
        'Empty URL provided',
        ImageCacheErrorType.invalidUrl,
      );
    }

    if (!_isUrlTrusted(imageUrl)) {
      return ImageCacheResult.failure(
        'URL domain not trusted: $imageUrl',
        ImageCacheErrorType.untrustedDomain,
      );
    }

    try {
      // Resolve gs:// URLs to HTTPS
      String? resolvedUrl = imageUrl;
      if (imageUrl.startsWith('gs://')) {
        resolvedUrl = await resolveGsUrl(imageUrl);
        if (resolvedUrl == null) {
          return ImageCacheResult.failure(
            'Failed to resolve Firebase Storage URL',
            ImageCacheErrorType.storageError,
          );
        }
      }

      // Download and cache the image
      final fileInfo = await _cacheManager!
          .downloadFile(resolvedUrl)
          .timeout(_downloadTimeout);

      // Invalidate cached size
      _cachedSize = null;

      return ImageCacheResult.success(fileInfo.file.path);
    } on TimeoutException catch (_) {
      return ImageCacheResult.failure(
        'Download timed out',
        ImageCacheErrorType.timeout,
      );
    } on SocketException catch (e) {
      return ImageCacheResult.failure(
        'Network error: ${e.message}',
        ImageCacheErrorType.networkError,
      );
    } catch (e) {
      return ImageCacheResult.failure(
        'Error caching image: $e',
        ImageCacheErrorType.unknown,
      );
    }
  }

  /// Get cached image file if available
  Future<File?> getCachedImage(String imageUrl) async {
    if (!_isInitialized || _cacheManager == null) {
      await initialize();
      if (_cacheManager == null) return null;
    }

    try {
      // Resolve gs:// URLs to HTTPS for cache key
      String? resolvedUrl = imageUrl;
      if (imageUrl.startsWith('gs://')) {
        resolvedUrl = await resolveGsUrl(imageUrl);
        if (resolvedUrl == null) {
          return null;
        }
      }

      final fileInfo = await _cacheManager!.getFileFromCache(resolvedUrl);
      return fileInfo?.file;
    } catch (e) {
      if (kDebugMode) {
        print('ImageCacheService: Error getting cached image: $e');
      }
      return null;
    }
  }

  /// Check if an image is cached
  Future<bool> isImageCached(String imageUrl) async {
    try {
      final file = await getCachedImage(imageUrl);
      if (file == null) return false;
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get image from cache or download it
  Future<File?> getImage(String imageUrl) async {
    if (!_isInitialized || _cacheManager == null) {
      await initialize();
      if (_cacheManager == null) return null;
    }

    try {
      // Validate URL
      if (!_isUrlTrusted(imageUrl)) {
        if (kDebugMode) {
          print('ImageCacheService: Untrusted URL: $imageUrl');
        }
        return null;
      }

      // Resolve gs:// URLs to HTTPS
      String? resolvedUrl = imageUrl;
      if (imageUrl.startsWith('gs://')) {
        resolvedUrl = await resolveGsUrl(imageUrl);
        if (resolvedUrl == null) {
          return null;
        }
      }

      final file = await _cacheManager!
          .getSingleFile(resolvedUrl)
          .timeout(_downloadTimeout);
      return file;
    } on TimeoutException catch (_) {
      if (kDebugMode) {
        print('ImageCacheService: Download timed out');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('ImageCacheService: Error getting image: $e');
      }
      return null;
    }
  }

  /// Get current cache size in bytes (with caching for performance)
  Future<int> getCacheSize({bool forceRefresh = false}) async {
    // Return cached size if still valid
    if (!forceRefresh &&
        _cachedSize != null &&
        _cacheSizeLastUpdated != null &&
        DateTime.now().difference(_cacheSizeLastUpdated!) < _cacheSizeValidityDuration) {
      return _cachedSize!;
    }

    try {
      final cacheDir = await getTemporaryDirectory();
      // BUG-005 fix: Use correct cache directory name matching CacheManager config
      final jeevibeCacheDir = Directory('${cacheDir.path}/jeevibe_solution_images');

      if (!await jeevibeCacheDir.exists()) {
        _cachedSize = 0;
        _cacheSizeLastUpdated = DateTime.now();
        return 0;
      }

      int totalSize = 0;

      // Use stat for better performance than length() per file
      await for (final entity in jeevibeCacheDir.list(recursive: true)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            totalSize += stat.size;
          } catch (e) {
            // Ignore individual file errors
          }
        }
      }

      _cachedSize = totalSize;
      _cacheSizeLastUpdated = DateTime.now();
      return totalSize;
    } catch (e) {
      if (kDebugMode) {
        print('ImageCacheService: Error getting cache size: $e');
      }
      return _cachedSize ?? 0;
    }
  }

  /// Get formatted cache size string
  Future<String> getFormattedCacheSize() async {
    final bytes = await getCacheSize();
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Clear all cached images
  Future<void> clearCache() async {
    if (!_isInitialized || _cacheManager == null) return;

    try {
      await _cacheManager!.emptyCache();
      _cachedSize = 0;
      _cacheSizeLastUpdated = DateTime.now();

      if (kDebugMode) {
        print('ImageCacheService: Cache cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ImageCacheService: Error clearing cache: $e');
      }
    }
  }

  /// Remove a specific image from cache
  Future<void> removeFromCache(String imageUrl) async {
    if (!_isInitialized || _cacheManager == null) return;

    try {
      // Resolve gs:// URLs to HTTPS for cache key
      String? resolvedUrl = imageUrl;
      if (imageUrl.startsWith('gs://')) {
        resolvedUrl = await resolveGsUrl(imageUrl);
        if (resolvedUrl == null) {
          return;
        }
      }

      await _cacheManager!.removeFile(resolvedUrl);
      _cachedSize = null; // Invalidate cached size
    } catch (e) {
      if (kDebugMode) {
        print('ImageCacheService: Error removing from cache: $e');
      }
    }
  }

  /// Evict cache if it exceeds the tier limit (fixed typo)
  Future<void> enforceCacheSizeLimit(int maxBytes) async {
    if (maxBytes <= 0) {
      // No caching allowed, clear everything
      await clearCache();
      return;
    }

    final currentSize = await getCacheSize(forceRefresh: true);
    if (currentSize <= maxBytes) {
      return; // Within limits
    }

    // Clear cache when over limit
    // TODO: Implement LRU eviction for better UX
    await clearCache();

    if (kDebugMode) {
      print('ImageCacheService: Cache exceeded limit ($currentSize > $maxBytes), cleared');
    }
  }
}
