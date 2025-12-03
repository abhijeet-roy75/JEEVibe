/// Service for managing local storage with SharedPreferences
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/snap_data_model.dart';

class StorageService {
  static const String _keyPrefix = 'jeevibe_';
  
  // Key names
  static const String _keySnapCount = '${_keyPrefix}snap_count';
  static const String _keySnapLimit = '${_keyPrefix}snap_limit';
  static const String _keyLastResetDate = '${_keyPrefix}last_reset_date';
  static const String _keySnapHistory = '${_keyPrefix}snap_history';
  static const String _keyRecentSolutions = '${_keyPrefix}recent_solutions';
  static const String _keyAllSolutions = '${_keyPrefix}all_solutions';
  static const String _keyTotalQuestionsPracticed = '${_keyPrefix}total_questions_practiced';
  static const String _keyTotalCorrect = '${_keyPrefix}total_correct';
  static const String _keyTotalSnapsUsed = '${_keyPrefix}total_snaps_used';
  static const String _keyHasSeenWelcome = '${_keyPrefix}has_seen_welcome';
  static const String _keyFirstLaunchDate = '${_keyPrefix}first_launch_date';
  static const String _keyAppVersion = '${_keyPrefix}app_version';

  // Constants
  static const int defaultSnapLimit = 5;
  static const int maxRecentSolutions = 3;

  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  /// Initialize the storage service
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get _preferences async {
    if (_prefs == null) {
      await initialize();
    }
    return _prefs!;
  }

  // ===== SNAP COUNTER METHODS =====

  /// Get current snap count
  Future<int> getSnapCount() async {
    try {
      final prefs = await _preferences;
      return prefs.getInt(_keySnapCount) ?? 0;
    } catch (e) {
      debugPrint('Error getting snap count: $e');
      return 0;
    }
  }

  /// Set snap count
  Future<void> setSnapCount(int count) async {
    try {
      final prefs = await _preferences;
      await prefs.setInt(_keySnapCount, count);
    } catch (e) {
      debugPrint('Error setting snap count: $e');
    }
  }

  /// Get snap limit (default 5)
  Future<int> getSnapLimit() async {
    try {
      final prefs = await _preferences;
      return prefs.getInt(_keySnapLimit) ?? defaultSnapLimit;
    } catch (e) {
      debugPrint('Error getting snap limit: $e');
      return defaultSnapLimit;
    }
  }

  /// Get last reset date (ISO format)
  Future<String?> getLastResetDate() async {
    try {
      final prefs = await _preferences;
      return prefs.getString(_keyLastResetDate);
    } catch (e) {
      debugPrint('Error getting last reset date: $e');
      return null;
    }
  }

  /// Set last reset date
  Future<void> setLastResetDate(String date) async {
    try {
      final prefs = await _preferences;
      await prefs.setString(_keyLastResetDate, date);
    } catch (e) {
      debugPrint('Error setting last reset date: $e');
    }
  }

  /// Get snap history
  Future<List<SnapRecord>> getSnapHistory() async {
    try {
      final prefs = await _preferences;
      final jsonString = prefs.getString(_keySnapHistory);
      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((j) => SnapRecord.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error getting snap history: $e');
      return [];
    }
  }

  /// Add snap to history
  Future<void> addSnapToHistory(SnapRecord snap) async {
    try {
      final history = await getSnapHistory();
      history.add(snap);
      
      final prefs = await _preferences;
      final jsonString = json.encode(history.map((s) => s.toJson()).toList());
      await prefs.setString(_keySnapHistory, jsonString);
    } catch (e) {
      debugPrint('Error adding snap to history: $e');
    }
  }

  // ===== RECENT SOLUTIONS METHODS =====

  /// Get recent solutions (max 3)
  Future<List<RecentSolution>> getRecentSolutions() async {
    try {
      final prefs = await _preferences;
      final jsonString = prefs.getString(_keyRecentSolutions);
      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((j) => RecentSolution.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error getting recent solutions: $e');
      return [];
    }
  }

  /// Add recent solution (keeps only last 3)
  Future<void> addRecentSolution(RecentSolution solution) async {
    try {
      final solutions = await getRecentSolutions();
      
      // Add to beginning
      solutions.insert(0, solution);
      
      // Keep only last 3
      if (solutions.length > maxRecentSolutions) {
        solutions.removeRange(maxRecentSolutions, solutions.length);
      }
      
      final prefs = await _preferences;
      final jsonString = json.encode(solutions.map((s) => s.toJson()).toList());
      await prefs.setString(_keyRecentSolutions, jsonString);
      
      // Also add to all solutions list (for "View All" functionality)
      await _addToAllSolutions(solution);
    } catch (e) {
      debugPrint('Error adding recent solution: $e');
    }
  }

  /// Add solution to all solutions list (internal helper)
  Future<void> _addToAllSolutions(RecentSolution solution) async {
    try {
      // Get all solutions (this will trigger migration if needed)
      final allSolutions = await getAllSolutions();
      
      // Check if solution already exists (by id) to avoid duplicates
      final existingIndex = allSolutions.indexWhere((s) => s.id == solution.id);
      if (existingIndex >= 0) {
        // Update existing solution
        allSolutions[existingIndex] = solution;
      } else {
        // Add new solution at the beginning
        allSolutions.insert(0, solution);
      }
      
      final prefs = await _preferences;
      final jsonString = json.encode(allSolutions.map((s) => s.toJson()).toList());
      await prefs.setString(_keyAllSolutions, jsonString);
    } catch (e) {
      debugPrint('Error adding to all solutions: $e');
    }
  }

  /// Get all solutions (not limited to 3)
  Future<List<RecentSolution>> getAllSolutions() async {
    try {
      final prefs = await _preferences;
      var jsonString = prefs.getString(_keyAllSolutions);
      
      // Migration: If all solutions list is empty but recent solutions exist, migrate them
      if (jsonString == null || jsonString.isEmpty) {
        final recentSolutions = await getRecentSolutions();
        if (recentSolutions.isNotEmpty) {
          // Save all recent solutions to all solutions list
          final allSolutionsJson = json.encode(recentSolutions.map((s) => s.toJson()).toList());
          await prefs.setString(_keyAllSolutions, allSolutionsJson);
          jsonString = allSolutionsJson;
        } else {
          return [];
        }
      }

      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((j) => RecentSolution.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error getting all solutions: $e');
      return [];
    }
  }

  /// Get all solutions for today (filtered by date)
  Future<List<RecentSolution>> getAllSolutionsForToday() async {
    try {
      final allSolutions = await getAllSolutions();
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      
      final filtered = allSolutions.where((solution) {
        try {
          final solutionDate = DateTime.parse(solution.timestamp);
          // Include solutions from today (from start of today to start of tomorrow)
          final isToday = (solutionDate.isAtSameMomentAs(todayStart) || 
                          solutionDate.isAfter(todayStart)) && 
                         solutionDate.isBefore(todayEnd);
          return isToday;
        } catch (e) {
          return false;
        }
      }).toList();
      
      return filtered;
    } catch (e) {
      debugPrint('Error getting solutions for today: $e');
      return [];
    }
  }

  /// Clear all recent solutions
  Future<void> clearRecentSolutions() async {
    try {
      final prefs = await _preferences;
      await prefs.remove(_keyRecentSolutions);
    } catch (e) {
      debugPrint('Error clearing recent solutions: $e');
    }
  }

  // ===== STATS METHODS =====

  /// Get user statistics
  Future<UserStats> getStats() async {
    try {
      final prefs = await _preferences;
      final practiced = prefs.getInt(_keyTotalQuestionsPracticed) ?? 0;
      final correct = prefs.getInt(_keyTotalCorrect) ?? 0;
      final snapsUsed = prefs.getInt(_keyTotalSnapsUsed) ?? 0;
      
      return UserStats(
        totalQuestionsPracticed: practiced,
        totalCorrect: correct,
        accuracy: practiced > 0 ? (correct / practiced * 100) : 0.0,
        totalSnapsUsed: snapsUsed,
      );
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return UserStats(
        totalQuestionsPracticed: 0,
        totalCorrect: 0,
        accuracy: 0.0,
        totalSnapsUsed: 0,
      );
    }
  }

  /// Update stats with new practice session results
  Future<void> updateStats(int questionsPracticed, int correct) async {
    try {
      final stats = await getStats();
      final prefs = await _preferences;
      
      await prefs.setInt(_keyTotalQuestionsPracticed, 
          stats.totalQuestionsPracticed + questionsPracticed);
      await prefs.setInt(_keyTotalCorrect, 
          stats.totalCorrect + correct);
    } catch (e) {
      debugPrint('Error updating stats: $e');
    }
  }

  /// Increment total snaps used (lifetime counter)
  Future<void> incrementTotalSnaps() async {
    try {
      final stats = await getStats();
      final prefs = await _preferences;
      await prefs.setInt(_keyTotalSnapsUsed, stats.totalSnapsUsed + 1);
    } catch (e) {
      debugPrint('Error incrementing total snaps: $e');
    }
  }

  // ===== APP STATE METHODS =====

  /// Check if user has seen welcome screens
  Future<bool> hasSeenWelcome() async {
    try {
      final prefs = await _preferences;
      return prefs.getBool(_keyHasSeenWelcome) ?? false;
    } catch (e) {
      debugPrint('Error checking welcome status: $e');
      return false;
    }
  }

  /// Mark welcome screens as seen
  Future<void> setHasSeenWelcome(bool value) async {
    try {
      final prefs = await _preferences;
      await prefs.setBool(_keyHasSeenWelcome, value);
    } catch (e) {
      debugPrint('Error setting welcome status: $e');
    }
  }

  /// Get first launch date
  Future<String?> getFirstLaunchDate() async {
    try {
      final prefs = await _preferences;
      return prefs.getString(_keyFirstLaunchDate);
    } catch (e) {
      debugPrint('Error getting first launch date: $e');
      return null;
    }
  }

  /// Set first launch date
  Future<void> setFirstLaunchDate(String date) async {
    try {
      final prefs = await _preferences;
      await prefs.setString(_keyFirstLaunchDate, date);
    } catch (e) {
      debugPrint('Error setting first launch date: $e');
    }
  }

  /// Get app version
  Future<String?> getAppVersion() async {
    try {
      final prefs = await _preferences;
      return prefs.getString(_keyAppVersion);
    } catch (e) {
      debugPrint('Error getting app version: $e');
      return null;
    }
  }

  /// Set app version
  Future<void> setAppVersion(String version) async {
    try {
      final prefs = await _preferences;
      await prefs.setString(_keyAppVersion, version);
    } catch (e) {
      debugPrint('Error setting app version: $e');
    }
  }

  // ===== UTILITY METHODS =====

  /// Clear all app data (for testing/debugging)
  Future<void> clearAllData() async {
    try {
      final prefs = await _preferences;
      final keys = prefs.getKeys().where((key) => key.startsWith(_keyPrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('Error clearing all data: $e');
    }
  }

  /// Helper to print current state (debugging)
  void debugPrint(String message) {
    print('[StorageService] $message');
  }
}

