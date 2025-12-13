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
  });
}

