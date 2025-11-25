import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Compress image to target size (<5MB, max 2048x2048)
class ImageCompressor {
  /// Compress image file
  /// Returns compressed file path
  static Future<File> compressImage(File imageFile, {int maxSizeKB = 500}) async {
    try {
      // Read image
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Calculate target dimensions (max 1500x1500 for bandwidth optimization)
      int targetWidth = image.width;
      int targetHeight = image.height;

      if (targetWidth > 1500 || targetHeight > 1500) {
        if (targetWidth > targetHeight) {
          targetWidth = 1500;
          targetHeight = (image.height * 1500 / image.width).round();
        } else {
          targetHeight = 1500;
          targetWidth = (image.width * 1500 / image.height).round();
        }
      }

      // Resize if needed
      if (targetWidth != image.width || targetHeight != image.height) {
        image = img.copyResize(
          image,
          width: targetWidth,
          height: targetHeight,
        );
      }

      // Compress with quality 85%
      int quality = 85;
      Uint8List compressedBytes;

      do {
        compressedBytes = Uint8List.fromList(
          img.encodeJpg(image, quality: quality),
        );

        // If still too large, reduce quality
        if (compressedBytes.length > maxSizeKB * 1024 && quality > 60) {
          quality -= 5;
        } else {
          break;
        }
      } while (compressedBytes.length > maxSizeKB * 1024 && quality > 60);

      // Create compressed file
      final compressedFile = File(
        imageFile.path.replaceAll('.jpg', '_compressed.jpg').replaceAll('.png', '_compressed.jpg'),
      );
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (e) {
      // If compression fails, return original file
      debugPrint('Compression error: $e');
      return imageFile;
    }
  }

  /// Get image file size in KB
  static Future<double> getFileSizeKB(File file) async {
    final bytes = await file.length();
    return bytes / 1024;
  }
}

