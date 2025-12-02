/// Provider for managing global app state
import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../services/snap_counter_service.dart';
import '../models/snap_data_model.dart';

class AppStateProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final SnapCounterService _snapCounter = SnapCounterService();

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

  // Getters
  int get snapsUsed => _snapsUsed;
  int get snapLimit => _snapLimit;
  int get snapsRemaining => _snapLimit - _snapsUsed;
  bool get hasSeenWelcome => _hasSeenWelcome;
  List<RecentSolution> get recentSolutions => _recentSolutions;
  UserStats get stats => _stats;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get canTakeSnap => snapsRemaining > 0;

  /// Initialize the provider (call on app launch)
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _storage.initialize();
      await _snapCounter.initialize();
      await _loadState();
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

