// Unit tests for ImageCacheService
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/services/offline/image_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageCacheService', () {
    late ImageCacheService service;

    setUp(() {
      service = ImageCacheService();
    });

    group('singleton pattern', () {
      test('should return same instance', () {
        final instance1 = ImageCacheService();
        final instance2 = ImageCacheService();

        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('cache size limits', () {
      test('should have correct free tier cache limit', () {
        expect(ImageCacheService.freeTierCacheLimit, 0);
      });

      test('should have correct pro tier cache limit (100MB)', () {
        expect(ImageCacheService.proTierCacheLimit, 100 * 1024 * 1024);
      });

      test('should have correct ultra tier cache limit (500MB)', () {
        expect(ImageCacheService.ultraTierCacheLimit, 500 * 1024 * 1024);
      });
    });

    group('resolveGsUrl', () {
      test('should return same URL for non-gs URLs', () async {
        const httpsUrl = 'https://example.com/image.png';
        final result = await service.resolveGsUrl(httpsUrl);
        expect(result, httpsUrl);
      });

      test('should return same URL for http URLs', () async {
        const httpUrl = 'http://example.com/image.png';
        final result = await service.resolveGsUrl(httpUrl);
        expect(result, httpUrl);
      });
    });

    group('getFormattedCacheSize', () {
      test('should format bytes correctly', () async {
        // This will return actual cache size, which should be minimal in tests
        final formatted = await service.getFormattedCacheSize();
        expect(formatted, isNotNull);
        // Should end with B, KB, or MB
        expect(
          formatted.endsWith('B') ||
          formatted.endsWith('KB') ||
          formatted.endsWith('MB'),
          isTrue,
        );
      });
    });
  });
}
