/// Service for managing daily snap counter with automatic midnight reset
import 'package:flutter/foundation.dart';
import 'storage_service.dart';
import '../models/snap_data_model.dart';

class SnapCounterService {
  final StorageService _storage;

  SnapCounterService(this._storage);

  /// Initialize the service (should be called on app launch)
  Future<void> initialize() async {
    await _storage.initialize();
    await checkAndResetIfNeeded();
  }

  /// Check if counter needs reset based on date and reset if needed
  Future<void> checkAndResetIfNeeded() async {
    try {
      final lastResetDate = await _storage.getLastResetDate();
      final today = _getTodayDateString();

      if (lastResetDate == null || lastResetDate != today) {
        // New day - reset counter
        await _storage.setSnapCount(0);
        await _storage.setLastResetDate(today);
        debugPrint('Snap counter reset for new day: $today');
      }
    } catch (e) {
      debugPrint('Error checking/resetting snap counter: $e');
    }
  }

  /// Get current number of snaps used today
  Future<int> getSnapsUsed() async {
    try {
      return await _storage.getSnapCount();
    } catch (e) {
      debugPrint('Error getting snaps used: $e');
      return 0;
    }
  }

  /// Get number of snaps remaining today
  Future<int> getSnapsRemaining() async {
    try {
      final used = await getSnapsUsed();
      final limit = await _storage.getSnapLimit();
      return limit - used;
    } catch (e) {
      debugPrint('Error getting snaps remaining: $e');
      return StorageService.defaultSnapLimit;
    }
  }

  /// Check if user can take another snap
  Future<bool> canTakeSnap() async {
    try {
      final remaining = await getSnapsRemaining();
      return remaining > 0;
    } catch (e) {
      debugPrint('Error checking if can take snap: $e');
      return false;
    }
  }

  /// Get time remaining until reset (midnight)
  Future<Duration> getTimeUntilReset() async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day + 1);
      return midnight.difference(now);
    } catch (e) {
      debugPrint('Error calculating time until reset: $e');
      return Duration.zero;
    }
  }

  /// Increment snap counter (call only on successful solution)
  Future<void> incrementSnap(String questionId, String topic, {String? subject}) async {
    try {
      // Check if can take snap first
      final canSnap = await canTakeSnap();
      if (!canSnap) {
        debugPrint('Cannot increment snap - limit reached');
        return;
      }

      // Increment counter
      final current = await getSnapsUsed();
      await _storage.setSnapCount(current + 1);

      // Add to history
      final snapRecord = SnapRecord(
        timestamp: DateTime.now().toIso8601String(),
        questionId: questionId,
        topic: topic,
        subject: subject,
      );
      await _storage.addSnapToHistory(snapRecord);

      // Increment lifetime counter
      await _storage.incrementTotalSnaps();

      debugPrint('Snap counter incremented: ${current + 1}');
    } catch (e) {
      debugPrint('Error incrementing snap: $e');
    }
  }

  /// Get formatted snap counter text for display (e.g., "2/5 snaps today")
  Future<String> getSnapCounterText() async {
    try {
      final used = await getSnapsUsed();
      final limit = await _storage.getSnapLimit();
      return '$used/$limit snaps today';
    } catch (e) {
      debugPrint('Error getting snap counter text: $e');
      return '0/${StorageService.defaultSnapLimit} snaps today';
    }
  }

  /// Get formatted reset countdown text (e.g., "Resets in 8h 32m")
  Future<String> getResetCountdownText() async {
    try {
      final duration = await getTimeUntilReset();
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);

      if (hours > 0) {
        return 'Resets in ${hours}h ${minutes}m';
      } else {
        return 'Resets in ${minutes}m';
      }
    } catch (e) {
      debugPrint('Error getting reset countdown text: $e');
      return 'Resets at midnight';
    }
  }

  /// Get today's date as ISO string (YYYY-MM-DD)
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get snap limit
  Future<int> getSnapLimit() async {
    return await _storage.getSnapLimit();
  }

  /// Get snap history for today
  Future<List<SnapRecord>> getTodaySnapHistory() async {
    try {
      final allHistory = await _storage.getSnapHistory();
      final today = _getTodayDateString();
      
      return allHistory.where((snap) {
        try {
          final snapDate = DateTime.parse(snap.timestamp);
          final snapDateString = '${snapDate.year}-${snapDate.month.toString().padLeft(2, '0')}-${snapDate.day.toString().padLeft(2, '0')}';
          return snapDateString == today;
        } catch (e) {
          return false;
        }
      }).toList();
    } catch (e) {
      debugPrint('Error getting today\'s snap history: $e');
      return [];
    }
  }

  void debugPrint(String message) {
    if (kDebugMode) {
      print('[SnapCounterService] $message');
    }
  }
}

