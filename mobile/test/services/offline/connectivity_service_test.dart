// Unit tests for ConnectivityService
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/services/offline/connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectivityService', () {
    test('should be a singleton', () {
      final instance1 = ConnectivityService();
      final instance2 = ConnectivityService();

      expect(identical(instance1, instance2), isTrue);
    });

    test('should start with isOnline = true before initialization', () {
      final service = ConnectivityService();

      // Before initialization, default state is online
      expect(service.isOnline, isTrue);
      expect(service.isOffline, isFalse);
      expect(service.isInitialized, isFalse);
    });

    test('isOffline should be opposite of isOnline', () {
      final service = ConnectivityService();

      // isOffline should always be the opposite of isOnline
      expect(service.isOffline, !service.isOnline);
    });
  });

  group('ConnectivityService - Singleton behavior', () {
    test('factory returns same instance', () {
      final a = ConnectivityService();
      final b = ConnectivityService();
      final c = ConnectivityService();

      expect(identical(a, b), isTrue);
      expect(identical(b, c), isTrue);
    });
  });

  group('ConnectivityService - ChangeNotifier', () {
    test('should extend ChangeNotifier', () {
      final service = ConnectivityService();
      expect(service, isA<ChangeNotifier>());
    });

    test('should provide onConnectivityChanged stream', () {
      final service = ConnectivityService();
      expect(service.onConnectivityChanged, isA<Stream<bool>>());
    });
  });

  // Note: Tests requiring actual platform connectivity checks (initialize, refresh,
  // checkRealConnectivity) are not included here because they require platform plugins.
  // Those would be better tested as integration tests on an actual device.
}
