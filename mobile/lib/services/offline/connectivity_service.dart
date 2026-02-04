// Connectivity Service
//
// Monitors network connectivity and provides real connectivity status.
// Uses connectivity_plus for network state and performs actual connectivity
// checks to verify internet access (not just network presence).

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool _isInitialized = false;
  DateTime? _lastCheck;

  // Completer to prevent concurrent initialization
  Completer<void>? _initCompleter;

  /// Whether the device has network connectivity
  bool get isOnline => _isOnline;

  /// Whether the device is offline
  bool get isOffline => !_isOnline;

  /// Whether the service has been initialized
  bool get isInitialized => _isInitialized;

  ConnectivityService._internal();

  /// Reset the connectivity service state (useful for hot restart)
  /// This allows re-initialization without creating a new instance
  void reset() {
    _subscription?.cancel();
    _subscription = null;
    _isInitialized = false;
    _initCompleter = null;
    _lastCheck = null;
    // Keep _isOnline = true as default (optimistic)
    _isOnline = true;

    if (kDebugMode) {
      print('ConnectivityService: Reset for re-initialization');
    }
  }

  /// Initialize the connectivity service (thread-safe)
  /// Set forceReinit to true during hot restart to reset state first
  Future<void> initialize({bool forceReinit = false}) async {
    // Force reset if requested (e.g., during hot restart)
    if (forceReinit) {
      reset();
    }

    // Already initialized
    if (_isInitialized) return;

    // Another initialization is in progress, wait for it
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }

    // Start initialization
    _initCompleter = Completer<void>();

    try {
      // Cancel any existing subscription first
      _subscription?.cancel();
      _subscription = null;

      // Check initial connectivity
      await _checkConnectivity();

      // Listen to connectivity changes
      // Note: connectivity_plus 6.x uses List<ConnectivityResult> for multiple interfaces
      _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

      _isInitialized = true;

      if (kDebugMode) {
        print('ConnectivityService: Initialized, online: $_isOnline');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ConnectivityService: Initialization error: $e');
      }
      // Default to online on error to not block functionality
      _isOnline = true;
      _isInitialized = true;
    } finally {
      _initCompleter?.complete();
      _initCompleter = null;
    }
  }

  /// Dispose of resources
  /// Note: As a singleton, this is typically not called during app lifetime
  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }

  /// Handle connectivity state changes
  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    // If no connectivity, mark as offline immediately
    if (_hasNoConnectivity(results)) {
      _updateOnlineStatus(false);
      return;
    }

    // If we have network, verify actual connectivity
    await _checkRealConnectivity();
  }

  /// Check if result indicates no connectivity
  /// Returns true if all results are 'none' or the list is empty
  bool _hasNoConnectivity(List<ConnectivityResult> results) {
    return results.isEmpty || results.every((result) => result == ConnectivityResult.none);
  }

  /// Check connectivity state
  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();

      if (_hasNoConnectivity(results)) {
        _updateOnlineStatus(false);
        return;
      }

      // Verify actual internet access
      await _checkRealConnectivity();
    } catch (e) {
      if (kDebugMode) {
        print('ConnectivityService: Error checking connectivity: $e');
      }
      // Default to online on error
      _updateOnlineStatus(true);
    }
  }

  /// Perform actual connectivity check by pinging a reliable endpoint
  Future<bool> checkRealConnectivity() async {
    return _checkRealConnectivity();
  }

  /// Internal method to verify actual internet access
  Future<bool> _checkRealConnectivity() async {
    // Don't check too frequently (at most every 5 seconds)
    if (_lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < const Duration(seconds: 5)) {
      return _isOnline;
    }

    _lastCheck = DateTime.now();

    try {
      // Try to connect to Google's DNS server (fast and reliable)
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));

      final hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _updateOnlineStatus(hasConnection);
      return hasConnection;
    } on SocketException catch (_) {
      _updateOnlineStatus(false);
      return false;
    } on TimeoutException catch (_) {
      _updateOnlineStatus(false);
      return false;
    } catch (_) {
      _updateOnlineStatus(false);
      return false;
    }
  }

  /// Update online status and notify listeners
  void _updateOnlineStatus(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      notifyListeners();

      if (kDebugMode) {
        print('ConnectivityService: Online status changed to $isOnline');
      }
    }
  }

  /// Force refresh connectivity status
  Future<bool> refresh() async {
    _lastCheck = null; // Reset throttle
    return _checkRealConnectivity();
  }

  /// Stream of connectivity changes
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.asyncMap((results) async {
      if (_hasNoConnectivity(results)) {
        return false;
      }
      return await _checkRealConnectivity();
    });
  }
}
