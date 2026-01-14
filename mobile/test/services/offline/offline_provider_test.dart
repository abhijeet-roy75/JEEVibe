// Unit tests for OfflineProvider
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/providers/offline_provider.dart';
import 'package:jeevibe_mobile/models/offline/cached_solution.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineProvider', () {
    late OfflineProvider provider;

    setUp(() {
      provider = OfflineProvider();
    });

    group('initial state', () {
      test('should have isInitialized = false initially', () {
        expect(provider.isInitialized, isFalse);
      });

      test('should have isOnline = true initially', () {
        expect(provider.isOnline, isTrue);
      });

      test('should have isOffline = false initially', () {
        expect(provider.isOffline, isFalse);
      });

      test('should have offlineEnabled = false initially', () {
        expect(provider.offlineEnabled, isFalse);
      });

      test('should have hasPendingActions = false initially', () {
        expect(provider.hasPendingActions, isFalse);
      });

      test('should have pendingActionsCount = 0 initially', () {
        expect(provider.pendingActionsCount, 0);
      });

      test('should have cachedSolutionsCount = 0 initially', () {
        expect(provider.cachedSolutionsCount, 0);
      });

      test('should have availableQuizzesCount = 0 initially', () {
        expect(provider.availableQuizzesCount, 0);
      });
    });

    group('syncState', () {
      test('should have idle syncState initially', () {
        expect(provider.syncState, SyncState.idle);
      });

      test('should have null lastSyncError initially', () {
        expect(provider.lastSyncError, isNull);
      });

      test('should have null lastSyncAt initially', () {
        expect(provider.lastSyncAt, isNull);
      });

      test('should have null lastSyncTimeFormatted initially', () {
        expect(provider.lastSyncTimeFormatted, isNull);
      });
    });

    group('updateOfflineEnabled', () {
      test('should update offlineEnabled state', () {
        expect(provider.offlineEnabled, isFalse);

        provider.updateOfflineEnabled(true);

        expect(provider.offlineEnabled, isTrue);
      });

      test('should notify listeners when state changes', () {
        bool notified = false;
        provider.addListener(() {
          notified = true;
        });

        provider.updateOfflineEnabled(true);

        expect(notified, isTrue);
      });

      test('should not notify if state does not change', () {
        provider.updateOfflineEnabled(false); // Same as initial

        int notifyCount = 0;
        provider.addListener(() {
          notifyCount++;
        });

        provider.updateOfflineEnabled(false); // Still false

        expect(notifyCount, 0);
      });
    });

    group('currentUserId', () {
      test('should be null initially', () {
        expect(provider.currentUserId, isNull);
      });
    });

    group('lastSyncTimeFormatted', () {
      test('should return null when lastSyncAt is null', () {
        expect(provider.lastSyncTimeFormatted, isNull);
      });
    });

    group('ChangeNotifier', () {
      test('should extend ChangeNotifier', () {
        expect(provider, isA<ChangeNotifier>());
      });

      test('should notify listeners when updateOfflineEnabled is called with new value', () {
        bool notified = false;
        provider.addListener(() {
          notified = true;
        });

        provider.updateOfflineEnabled(true);

        expect(notified, isTrue);
      });
    });

    group('dispose', () {
      test('should not throw when disposed', () {
        expect(() => provider.dispose(), returnsNormally);
      });
    });
  });
}
