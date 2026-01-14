// Unit tests for SyncService
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/services/offline/sync_service.dart';
import 'package:jeevibe_mobile/models/offline/cached_solution.dart';
import 'package:jeevibe_mobile/models/snap_data_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncService', () {
    late SyncService service;

    setUp(() {
      service = SyncService();
    });

    group('singleton pattern', () {
      test('should return same instance', () {
        final instance1 = SyncService();
        final instance2 = SyncService();

        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('tier solution limits', () {
      test('should have correct pro tier solution limit', () {
        expect(SyncService.proTierSolutionLimit, 50);
      });

      test('should have correct ultra tier solution limit', () {
        expect(SyncService.ultraTierSolutionLimit, 200);
      });
    });

    group('isSyncing', () {
      test('should initially be false', () {
        expect(service.isSyncing, isFalse);
      });
    });

    group('convertToRecentSolution', () {
      test('should convert CachedSolution to RecentSolution correctly', () {
        final cached = CachedSolution()
          ..solutionId = 'test-id-123'
          ..userId = 'user-123'
          ..question = 'What is 2+2?'
          ..topic = 'Arithmetic'
          ..subject = 'Math'
          ..timestamp = DateTime(2024, 1, 15, 10, 30)
          ..solutionDataJson = '{"solution": {"approach": "Add numbers"}}'
          ..originalImageUrl = 'https://example.com/image.png'
          ..language = 'en'
          ..cachedAt = DateTime.now()
          ..expiresAt = DateTime.now().add(const Duration(days: 30))
          ..isImageCached = false;

        final recent = service.convertToRecentSolution(cached);

        expect(recent.id, 'test-id-123');
        expect(recent.question, 'What is 2+2?');
        expect(recent.topic, 'Arithmetic');
        expect(recent.subject, 'Math');
        expect(recent.imageUrl, 'https://example.com/image.png');
        expect(recent.language, 'en');
      });

      test('should use local image path when cached', () {
        final cached = CachedSolution()
          ..solutionId = 'test-id-456'
          ..userId = 'user-123'
          ..question = 'Test question'
          ..topic = 'Topic'
          ..subject = 'Physics'
          ..timestamp = DateTime.now()
          ..solutionDataJson = '{}'
          ..originalImageUrl = 'https://example.com/image.png'
          ..localImagePath = '/local/path/image.png'
          ..language = 'en'
          ..cachedAt = DateTime.now()
          ..expiresAt = DateTime.now().add(const Duration(days: 30))
          ..isImageCached = true;

        final recent = service.convertToRecentSolution(cached);

        // When image is cached, should use local path
        expect(recent.imageUrl, '/local/path/image.png');
      });

      test('should handle invalid JSON in solutionDataJson', () {
        final cached = CachedSolution()
          ..solutionId = 'test-id-789'
          ..userId = 'user-123'
          ..question = 'Test'
          ..topic = 'Topic'
          ..subject = 'Chemistry'
          ..timestamp = DateTime.now()
          ..solutionDataJson = 'invalid json {'
          ..cachedAt = DateTime.now()
          ..expiresAt = DateTime.now().add(const Duration(days: 30));

        final recent = service.convertToRecentSolution(cached);

        // Should not throw, should handle gracefully
        expect(recent.id, 'test-id-789');
        expect(recent.solutionData, isNull);
      });
    });
  });

  group('SyncResult', () {
    test('should calculate total correctly', () {
      final result = SyncResult(
        success: true,
        syncedCount: 5,
        totalFetched: 10,
      );

      expect(result.syncedCount, 5);
      expect(result.totalFetched, 10);
    });

    test('should indicate success with no error', () {
      final result = SyncResult(
        success: true,
        syncedCount: 10,
      );

      expect(result.success, isTrue);
      expect(result.error, isNull);
    });

    test('should contain error message on failure', () {
      final result = SyncResult(
        success: false,
        error: 'Network error',
        syncedCount: 0,
      );

      expect(result.success, isFalse);
      expect(result.error, 'Network error');
    });
  });
}
