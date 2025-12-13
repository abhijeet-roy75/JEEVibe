/// Unit tests for ImageCompressor
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:jeevibe_mobile/utils/image_compressor.dart';

void main() {
  group('ImageCompressor', () {
    test('getFileSizeKB - calculates size correctly', () async {
      // Create a temporary file
      final tempFile = File('test_image.jpg');
      final testData = Uint8List(1024 * 5); // 5KB
      await tempFile.writeAsBytes(testData);

      final size = await ImageCompressor.getFileSizeKB(tempFile);
      expect(size, closeTo(5.0, 0.1));

      // Cleanup
      await tempFile.delete();
    });

    test('compressImage - returns file for invalid image', () async {
      // Create a file that's not a valid image
      final tempFile = File('test_invalid.jpg');
      await tempFile.writeAsBytes([1, 2, 3, 4, 5]);

      // Should return original file if compression fails
      final result = await ImageCompressor.compressImage(tempFile);
      expect(result, isA<File>());

      // Cleanup
      await tempFile.delete();
      if (await result.exists()) {
        await result.delete();
      }
    });

    // Note: Full compression tests require actual image files
    // These would be integration tests with real images
  });
}

