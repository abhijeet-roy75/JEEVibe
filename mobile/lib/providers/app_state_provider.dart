/// Provider for managing global app state
import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../services/snap_counter_service.dart';
import '../models/snap_data_model.dart';

import '../services/firebase/auth_service.dart';

class AppStateProvider extends ChangeNotifier {
  final StorageService _storage;
  final SnapCounterService _snapCounter;
  final AuthService? _authService;

  AppStateProvider(this._storage, this._snapCounter, [this._authService]);

  // State variables
  int _snapsUsed = 0;
  int _snapLimit = 5;
  bool _hasSeenWelcome = false;
  List<RecentSolution> _recentSolutions = [];
  UserStats _stats = UserStats(
    totalQuestionsPracticed: 0,
    totalCorrect: 0,
    accuracy: 0.0,
    totalSnapsUsed: 0,
  );
  bool _isInitialized = false;
  bool _isLoading = false;

  // Getters with lazy initialization
  int get snapsUsed {
    _ensureInitialized();
    return _snapsUsed;
  }

  int get snapLimit {
    _ensureInitialized();
    return _snapLimit;
  }

  int get snapsRemaining {
    _ensureInitialized();
    return _snapLimit == -1 ? -1 : (_snapLimit - _snapsUsed);
  }

  bool get hasSeenWelcome {
    _ensureInitialized();
    return _hasSeenWelcome;
  }

  List<RecentSolution> get recentSolutions {
    _ensureInitialized();
    return _recentSolutions;
  }

  UserStats get stats {
    _ensureInitialized();
    return _stats;
  }

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get canTakeSnap {
    // Unlimited users (Ultra with -1 limit) can always take snaps
    if (_snapLimit == -1) return true;
    return snapsRemaining > 0;
  }

  /// Get formatted snap count text for display
  /// Returns "∞" (infinity symbol) for unlimited users, or "X/Y remaining" for limited users
  String get snapCountText {
    if (_snapLimit == -1) {
      return '∞';
    }
    return '${snapsRemaining}/${_snapLimit}';
  }

  /// Get formatted snap count text with label
  /// Returns "Unlimited snaps" or "X/Y snaps remaining"
  String get snapCountTextWithLabel {
    if (_snapLimit == -1) {
      return 'Unlimited snaps';
    }
    return '${snapsRemaining}/${_snapLimit} snaps remaining';
  }

  /// Ensure provider is initialized before accessing data
  /// Called automatically by getters - lazy initialization pattern
  void _ensureInitialized() {
    if (!_isInitialized && !_isLoading) {
      initialize();
    }
  }

  /// Initialize the provider (called lazily on first access)
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _storage.initialize();
      await _snapCounter.initialize();

      // Load local state first for immediate UI
      await _loadState();

      // PERFORMANCE: Backend sync now deferred to avoid blocking app startup
      // Sync happens in background after initial load
      if (_authService != null && _authService!.isAuthenticated) {
        final token = await _authService!.getIdToken();
        if (token != null) {
          // Sync in background without blocking
          _snapCounter.syncWithBackend(token).then((_) async {
            // Reload state after sync completes
            await _loadState();
            notifyListeners();
          }).catchError((e) {
            debugPrint('Error syncing with backend: $e');
          });
        }
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing AppStateProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load all state from storage
  Future<void> _loadState() async {
    try {
      _snapsUsed = await _snapCounter.getSnapsUsed();
      _snapLimit = await _snapCounter.getSnapLimit();
      _hasSeenWelcome = await _storage.hasSeenWelcome();
      _recentSolutions = await _storage.getRecentSolutions();
      _stats = await _storage.getStats();
      
      debugPrint('State loaded: used=$_snapsUsed, limit=$_snapLimit, snapsRemaining=$snapsRemaining');
    } catch (e) {
      debugPrint('Error loading state: $e');
    }
  }

  /// Refresh state from storage
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadState();
    } catch (e) {
      debugPrint('Error refreshing state: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark welcome screens as seen
  Future<void> setWelcomeSeen() async {
    try {
      await _storage.setHasSeenWelcome(true);
      _hasSeenWelcome = true;
      
      // Set first launch date if not set
      final firstLaunch = await _storage.getFirstLaunchDate();
      if (firstLaunch == null) {
        await _storage.setFirstLaunchDate(DateTime.now().toIso8601String());
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting welcome seen: $e');
    }
  }

  /// Increment snap counter
  Future<void> incrementSnap(String questionId, String topic, {String? subject}) async {
    try {
      await _snapCounter.incrementSnap(questionId, topic, subject: subject);
      _snapsUsed = await _snapCounter.getSnapsUsed();
      notifyListeners();
    } catch (e) {
      debugPrint('Error incrementing snap: $e');
    }
  }

  /// Add a recent solution
  Future<void> addRecentSolution(RecentSolution solution) async {
    try {
      await _storage.addRecentSolution(solution);
      _recentSolutions = await _storage.getRecentSolutions();
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding recent solution: $e');
    }
  }

  /// Update stats after practice session
  Future<void> updateStats(int questionsPracticed, int correct) async {
    try {
      await _storage.updateStats(questionsPracticed, correct);
      _stats = await _storage.getStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating stats: $e');
    }
  }

  /// Get snap counter text for display
  Future<String> getSnapCounterText() async {
    return await _snapCounter.getSnapCounterText();
  }

  /// Get reset countdown text
  Future<String> getResetCountdownText() async {
    return await _snapCounter.getResetCountdownText();
  }

  /// Check if counter needs reset and refresh state
  Future<void> checkAndResetIfNeeded() async {
    try {
      await _snapCounter.checkAndResetIfNeeded();
      await refresh();
    } catch (e) {
      debugPrint('Error checking/resetting: $e');
    }
  }

  /// Clear all data (for testing/debugging)
  Future<void> clearAllData() async {
    try {
      await _storage.clearAllData();
      await _loadState();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing all data: $e');
    }
  }

  void debugPrint(String message) {
    if (kDebugMode) {
      print('[AppStateProvider] $message');
    }
  }
}

