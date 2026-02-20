// Stub Database Service for Web
// This file is used on web where Isar is not supported

import 'dart:async';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;

  DatabaseService._internal();

  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  /// Whether the database has been initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the database (no-op on web)
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }

    _initCompleter = Completer<void>();

    try {
      _isInitialized = true;
      if (kDebugMode) {
        print('DatabaseService (Web Stub): Offline features disabled on web');
      }
      _initCompleter?.complete();
    } catch (e) {
      _initCompleter?.completeError(e);
      rethrow;
    } finally {
      _initCompleter = null;
    }
  }

  /// Close the database (no-op on web)
  Future<void> close() async {
    _isInitialized = false;
  }

  // All other methods throw UnsupportedError
  dynamic noSuchMethod(Invocation invocation) {
    if (kDebugMode) {
      print('DatabaseService: Offline features not supported on web');
    }
    throw UnsupportedError('Offline database not supported on web platform');
  }
}

/// Stub for EvictionResult
class EvictionResult {
  final int deletedCount;
  final List<String> imagePaths;

  EvictionResult({
    required this.deletedCount,
    required this.imagePaths,
  });
}
