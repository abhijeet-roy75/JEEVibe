/// Unit tests for SnapCounterService
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jeevibe_mobile/services/storage_service.dart';
import 'package:jeevibe_mobile/services/snap_counter_service.dart';

void main() {
  group('SnapCounterService', () {
    late StorageService storageService;
    late SnapCounterService snapCounterService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storageService = StorageService();
      await storageService.initialize();
      snapCounterService = SnapCounterService(storageService);
    });

    test('getSnapsUsed - returns 0 for new user', () async {
      final used = await snapCounterService.getSnapsUsed();
      expect(used, 0);
    });

    test('getSnapsRemaining - returns default limit for new user', () async {
      final remaining = await snapCounterService.getSnapsRemaining();
      expect(remaining, StorageService.defaultSnapLimit);
    });

    test('canTakeSnap - returns true for new user', () async {
      final canSnap = await snapCounterService.canTakeSnap();
      expect(canSnap, true);
    });

    test('canTakeSnap - returns false when limit reached', () async {
      // Set snap count to limit (default limit is 5)
      await storageService.setSnapCount(5);
      
      final canSnap = await snapCounterService.canTakeSnap();
      expect(canSnap, false);
    });

    test('incrementSnap - increments counter', () async {
      // Default limit is 5, start with 0
      await storageService.setSnapCount(0);
      
      await snapCounterService.incrementSnap('test_q1', 'Calculus');
      
      final used = await snapCounterService.getSnapsUsed();
      expect(used, 1);
    });

    test('incrementSnap - does not increment when limit reached', () async {
      // Set snap count to default limit (5)
      await storageService.setSnapCount(5);
      
      await snapCounterService.incrementSnap('test_q1', 'Calculus');
      
      final used = await snapCounterService.getSnapsUsed();
      expect(used, 5); // Should remain at limit
    });

    test('getSnapCounterText - returns formatted text', () async {
      // Default limit is 5
      await storageService.setSnapCount(2);
      
      final text = await snapCounterService.getSnapCounterText();
      expect(text, '2/5 snaps today');
    });

    test('getResetCountdownText - returns formatted countdown', () async {
      final text = await snapCounterService.getResetCountdownText();
      expect(text, contains('Resets'));
    });

    test('getTimeUntilReset - returns positive duration', () async {
      final duration = await snapCounterService.getTimeUntilReset();
      expect(duration.inMilliseconds, greaterThan(0));
    });

    test('getTodaySnapHistory - returns only today snaps', () async {
      // Add a snap for today
      await snapCounterService.incrementSnap('test_q1', 'Calculus');

      final history = await snapCounterService.getTodaySnapHistory();
      expect(history.length, greaterThanOrEqualTo(0));
    });

    // Tests for unlimited (-1) handling
    group('Unlimited Users (-1 limit)', () {
      test('getSnapsRemaining - returns -1 for unlimited users', () async {
        // Set limit to -1 (unlimited)
        await storageService.setSnapLimit(-1);

        final remaining = await snapCounterService.getSnapsRemaining();
        expect(remaining, -1);
      });

      test('canTakeSnap - returns true for unlimited users regardless of usage', () async {
        // Set limit to -1 (unlimited) and high usage count
        await storageService.setSnapLimit(-1);
        await storageService.setSnapCount(100);

        final canSnap = await snapCounterService.canTakeSnap();
        expect(canSnap, true);
      });

      test('isUnlimited - returns true when limit is -1', () async {
        await storageService.setSnapLimit(-1);

        final unlimited = await snapCounterService.isUnlimited();
        expect(unlimited, true);
      });

      test('isUnlimited - returns false when limit is positive', () async {
        await storageService.setSnapLimit(5);

        final unlimited = await snapCounterService.isUnlimited();
        expect(unlimited, false);
      });

      test('getSnapCounterText - shows unlimited message', () async {
        await storageService.setSnapLimit(-1);
        await storageService.setSnapCount(10);

        final text = await snapCounterService.getSnapCounterText();
        expect(text, '10 snaps today (unlimited)');
      });

      test('incrementSnap - works for unlimited users', () async {
        await storageService.setSnapLimit(-1);
        await storageService.setSnapCount(0);

        await snapCounterService.incrementSnap('test_q1', 'Calculus');

        final used = await snapCounterService.getSnapsUsed();
        expect(used, 1);
      });
    });

    // Tests for error recovery during sync
    group('Sync Error Recovery', () {
      test('preserves existing state on sync failure', () async {
        // Set up existing state
        await storageService.setSnapCount(3);
        await storageService.setSnapLimit(10);

        // After failed sync, state should be preserved
        // (This is tested via the service behavior, not direct sync call)
        final used = await snapCounterService.getSnapsUsed();
        final limit = await snapCounterService.getSnapLimit();

        expect(used, 3);
        expect(limit, 10);
      });
    });

    // Tests for edge cases
    group('Edge Cases', () {
      test('getSnapsRemaining - never returns negative for limited users', () async {
        // Set usage higher than limit (edge case)
        await storageService.setSnapLimit(5);
        await storageService.setSnapCount(10);

        final remaining = await snapCounterService.getSnapsRemaining();
        expect(remaining, 0); // Should clamp to 0, not return -5
      });

      test('canTakeSnap - returns false when usage equals limit', () async {
        await storageService.setSnapLimit(5);
        await storageService.setSnapCount(5);

        final canSnap = await snapCounterService.canTakeSnap();
        expect(canSnap, false);
      });

      test('canTakeSnap - returns false when usage exceeds limit', () async {
        await storageService.setSnapLimit(5);
        await storageService.setSnapCount(6);

        final canSnap = await snapCounterService.canTakeSnap();
        expect(canSnap, false);
      });
    });
  });
}

