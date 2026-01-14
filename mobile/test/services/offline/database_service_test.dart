// Unit tests for DatabaseService
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/services/offline/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DatabaseService', () {
    test('should be a singleton', () {
      final instance1 = DatabaseService();
      final instance2 = DatabaseService();

      expect(identical(instance1, instance2), isTrue);
    });

    test('should have isInitialized = false before initialization', () {
      final service = DatabaseService();

      expect(service.isInitialized, isFalse);
    });

    test('should throw when accessing isar before initialization', () {
      final service = DatabaseService();

      expect(
        () => service.isar,
        throwsA(isA<Exception>()),
      );
    });

    // Note: Full integration tests for Isar operations would require
    // initializing Isar with a test directory, which is more complex.
    // These tests verify the basic service structure.
  });

  group('DatabaseService - Singleton behavior', () {
    test('factory returns same instance', () {
      final a = DatabaseService();
      final b = DatabaseService();
      final c = DatabaseService();

      expect(identical(a, b), isTrue);
      expect(identical(b, c), isTrue);
    });
  });
}
