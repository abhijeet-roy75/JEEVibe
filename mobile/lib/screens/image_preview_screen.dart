/// Image Preview Screen - Custom preview with large tap targets
/// Replaces native ImageCropper on Android for better usability
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class ImagePreviewScreen extends StatefulWidget {
  final File imageFile;
  final Function(File) onConfirm;
  final VoidCallback onCancel;

  const ImagePreviewScreen({
    super.key,
    required this.imageFile,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  bool _isProcessing = false;
  bool _isCropMode = false;
  bool _imageLoaded = false;

  // Crop rectangle state (normalized 0-1 coordinates)
  Rect _cropRect = const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95);

  // Image dimensions
  Size _imageSize = Size.zero;
  Size _displaySize = Size.zero;

  // For drag handling
  String? _activeHandle;
  Offset _dragStart = Offset.zero;
  Rect _cropRectStart = Rect.zero;

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
  }

  Future<void> _loadImageDimensions() async {
    try {
      // Check if file exists
      if (!await widget.imageFile.exists()) {
        if (mounted) setState(() => _imageLoaded = true);
        return;
      }

      final bytes = await widget.imageFile.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) setState(() => _imageLoaded = true);
        return;
      }

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width.toDouble();
      final height = frame.image.height.toDouble();

      if (width > 0 && height > 0 && width.isFinite && height.isFinite) {
        if (mounted) {
          setState(() {
            _imageSize = Size(width, height);
            _imageLoaded = true;
          });
        }
      } else {
        if (mounted) setState(() => _imageLoaded = true);
      }
    } catch (e) {
      if (mounted) setState(() => _imageLoaded = true);
    }
  }

  void _enterCropMode() {
    if (_imageSize == Size.zero) {
      // Can't crop without image dimensions
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to enter crop mode')),
      );
      return;
    }
    setState(() {
      _isCropMode = true;
      _cropRect = const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95);
    });
  }

  void _exitCropMode() {
    setState(() {
      _isCropMode = false;
    });
  }

  Future<void> _applyCrop() async {
    setState(() => _isProcessing = true);

    try {
      final bytes = await widget.imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);

      if (originalImage == null) {
        widget.onConfirm(widget.imageFile);
        return;
      }

      // Calculate crop coordinates in pixels
      final cropX = (_cropRect.left * originalImage.width).round();
      final cropY = (_cropRect.top * originalImage.height).round();
      final cropWidth = ((_cropRect.right - _cropRect.left) * originalImage.width).round();
      final cropHeight = ((_cropRect.bottom - _cropRect.top) * originalImage.height).round();

      // Perform crop
      final croppedImage = img.copyCrop(
        originalImage,
        x: cropX.clamp(0, originalImage.width - 1),
        y: cropY.clamp(0, originalImage.height - 1),
        width: cropWidth.clamp(1, originalImage.width - cropX),
        height: cropHeight.clamp(1, originalImage.height - cropY),
      );

      // Save to temp file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 90));

      widget.onConfirm(tempFile);
    } catch (e) {
      // If cropping fails, use original
      widget.onConfirm(widget.imageFile);
    }
  }

  void _useWithoutCrop() {
    widget.onConfirm(widget.imageFile);
  }

  void _onPanStart(DragStartDetails details, String handle) {
    _activeHandle = handle;
    _dragStart = details.localPosition;
    _cropRectStart = _cropRect;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_activeHandle == null || _displaySize == Size.zero) return;

    final delta = details.localPosition - _dragStart;
    final normalizedDx = delta.dx / _displaySize.width;
    final normalizedDy = delta.dy / _displaySize.height;

    setState(() {
      switch (_activeHandle) {
        case 'topLeft':
          _cropRect = Rect.fromLTRB(
            (_cropRectStart.left + normalizedDx).clamp(0.0, _cropRectStart.right - 0.1),
            (_cropRectStart.top + normalizedDy).clamp(0.0, _cropRectStart.bottom - 0.1),
            _cropRectStart.right,
            _cropRectStart.bottom,
          );
          break;
        case 'topRight':
          _cropRect = Rect.fromLTRB(
            _cropRectStart.left,
            (_cropRectStart.top + normalizedDy).clamp(0.0, _cropRectStart.bottom - 0.1),
            (_cropRectStart.right + normalizedDx).clamp(_cropRectStart.left + 0.1, 1.0),
            _cropRectStart.bottom,
          );
          break;
        case 'bottomLeft':
          _cropRect = Rect.fromLTRB(
            (_cropRectStart.left + normalizedDx).clamp(0.0, _cropRectStart.right - 0.1),
            _cropRectStart.top,
            _cropRectStart.right,
            (_cropRectStart.bottom + normalizedDy).clamp(_cropRectStart.top + 0.1, 1.0),
          );
          break;
        case 'bottomRight':
          _cropRect = Rect.fromLTRB(
            _cropRectStart.left,
            _cropRectStart.top,
            (_cropRectStart.right + normalizedDx).clamp(_cropRectStart.left + 0.1, 1.0),
            (_cropRectStart.bottom + normalizedDy).clamp(_cropRectStart.top + 0.1, 1.0),
          );
          break;
        case 'move':
          final newLeft = (_cropRectStart.left + normalizedDx).clamp(0.0, 1.0 - _cropRectStart.width);
          final newTop = (_cropRectStart.top + normalizedDy).clamp(0.0, 1.0 - _cropRectStart.height);
          _cropRect = Rect.fromLTWH(newLeft, newTop, _cropRectStart.width, _cropRectStart.height);
          break;
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _activeHandle = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Image preview with optional crop overlay
            Expanded(
              child: _isCropMode ? _buildCropView() : _buildPreviewView(),
            ),

            // Bottom action buttons
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Cancel/Back button
          TextButton(
            onPressed: _isCropMode ? _exitCropMode : widget.onCancel,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              _isCropMode ? 'Back' : 'Cancel',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),

          // Title
          Text(
            _isCropMode ? 'Crop' : 'Preview',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Placeholder for balance
          const SizedBox(width: 70),
        ],
      ),
    );
  }

  Widget _buildPreviewView() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.file(
          widget.imageFile,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Text(
                'Unable to load image',
                style: TextStyle(color: Colors.white70),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCropView() {
    if (_imageSize == Size.zero) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Safety checks for constraints
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0 ||
            !constraints.maxWidth.isFinite || !constraints.maxHeight.isFinite) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        // Calculate display size maintaining aspect ratio
        final imageAspect = _imageSize.width / _imageSize.height;

        // Safety check for aspect ratio
        if (!imageAspect.isFinite || imageAspect <= 0) {
          return const Center(
            child: Text('Unable to process image', style: TextStyle(color: Colors.white70)),
          );
        }

        final containerAspect = constraints.maxWidth / constraints.maxHeight;

        double displayWidth, displayHeight;
        if (imageAspect > containerAspect) {
          displayWidth = constraints.maxWidth;
          displayHeight = constraints.maxWidth / imageAspect;
        } else {
          displayHeight = constraints.maxHeight;
          displayWidth = constraints.maxHeight * imageAspect;
        }

        // Final safety check
        if (!displayWidth.isFinite || !displayHeight.isFinite ||
            displayWidth <= 0 || displayHeight <= 0) {
          return const Center(
            child: Text('Unable to display image', style: TextStyle(color: Colors.white70)),
          );
        }

        _displaySize = Size(displayWidth, displayHeight);

        return Center(
          child: SizedBox(
            width: displayWidth,
            height: displayHeight,
            child: Stack(
              children: [
                // Image
                Image.file(widget.imageFile, fit: BoxFit.contain),

                // Dark overlay outside crop area
                CustomPaint(
                  size: Size(displayWidth, displayHeight),
                  painter: _CropOverlayPainter(_cropRect),
                ),

                // Crop handles
                _buildCropHandles(displayWidth, displayHeight),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCropHandles(double width, double height) {
    // Safety check for valid dimensions
    if (width <= 0 || height <= 0 || !width.isFinite || !height.isFinite) {
      return const SizedBox.shrink();
    }

    const handleSize = 28.0; // Smaller, more refined handles
    final cropPixelRect = Rect.fromLTRB(
      (_cropRect.left * width).clamp(0, width),
      (_cropRect.top * height).clamp(0, height),
      (_cropRect.right * width).clamp(0, width),
      (_cropRect.bottom * height).clamp(0, height),
    );

    // Safety check for valid crop rect
    if (!cropPixelRect.isFinite) {
      return const SizedBox.shrink();
    }

    final centerX = cropPixelRect.center.dx.clamp(0, width);
    final centerY = cropPixelRect.center.dy.clamp(0, height);

    return Stack(
      children: [
        // Move handle (center of crop area) - subtle
        Positioned(
          left: centerX - 20,
          top: centerY - 20,
          child: GestureDetector(
            onPanStart: (d) => _onPanStart(d, 'move'),
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
              ),
              child: const Icon(Icons.open_with, color: Colors.white70, size: 20),
            ),
          ),
        ),

        // Corner handles - refined style
        _buildCornerHandle((cropPixelRect.left - handleSize/2).clamp(-handleSize/2, width), (cropPixelRect.top - handleSize/2).clamp(-handleSize/2, height), 'topLeft', handleSize),
        _buildCornerHandle((cropPixelRect.right - handleSize/2).clamp(-handleSize/2, width), (cropPixelRect.top - handleSize/2).clamp(-handleSize/2, height), 'topRight', handleSize),
        _buildCornerHandle((cropPixelRect.left - handleSize/2).clamp(-handleSize/2, width), (cropPixelRect.bottom - handleSize/2).clamp(-handleSize/2, height), 'bottomLeft', handleSize),
        _buildCornerHandle((cropPixelRect.right - handleSize/2).clamp(-handleSize/2, width), (cropPixelRect.bottom - handleSize/2).clamp(-handleSize/2, height), 'bottomRight', handleSize),
      ],
    );
  }

  Widget _buildCornerHandle(double left, double top, String handle, double size) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanStart: (d) => _onPanStart(d, handle),
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: Colors.black,
      child: _isCropMode ? _buildCropModeButtons() : _buildPreviewModeButtons(),
    );
  }

  Widget _buildPreviewModeButtons() {
    return Row(
      children: [
        // Crop button (secondary)
        Expanded(
          child: _buildButton(
            label: 'Crop',
            icon: Icons.crop,
            onPressed: _imageLoaded ? _enterCropMode : null,
            isPrimary: false,
          ),
        ),
        const SizedBox(width: 12),
        // Use Photo button (primary)
        Expanded(
          flex: 2,
          child: _buildButton(
            label: 'Use Photo',
            icon: Icons.check,
            onPressed: _isProcessing ? null : _useWithoutCrop,
            isPrimary: true,
          ),
        ),
      ],
    );
  }

  Widget _buildCropModeButtons() {
    return Row(
      children: [
        // Reset button
        Expanded(
          child: _buildButton(
            label: 'Reset',
            icon: Icons.refresh,
            onPressed: () {
              setState(() {
                _cropRect = const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95);
              });
            },
            isPrimary: false,
          ),
        ),
        const SizedBox(width: 12),
        // Apply button (primary)
        Expanded(
          flex: 2,
          child: _buildButton(
            label: 'Apply',
            icon: Icons.check,
            onPressed: _isProcessing ? null : _applyCrop,
            isPrimary: true,
            isLoading: _isProcessing,
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isPrimary,
    bool isLoading = false,
  }) {
    return SizedBox(
      height: 48,
      child: isPrimary
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Custom painter to draw the dark overlay outside the crop area
class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  _CropOverlayPainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    // Safety checks
    if (size.width <= 0 || size.height <= 0 ||
        !size.width.isFinite || !size.height.isFinite ||
        !cropRect.isFinite) {
      return;
    }

    final paint = Paint()..color = Colors.black.withValues(alpha: 0.6);

    // Calculate crop rect in pixels with clamping
    final pixelCropRect = Rect.fromLTRB(
      (cropRect.left * size.width).clamp(0, size.width),
      (cropRect.top * size.height).clamp(0, size.height),
      (cropRect.right * size.width).clamp(0, size.width),
      (cropRect.bottom * size.height).clamp(0, size.height),
    );

    // Draw dark overlay outside crop area
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(pixelCropRect);
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // Draw crop border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(pixelCropRect, borderPaint);

    // Draw grid lines (rule of thirds)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final cropWidth = pixelCropRect.width;
    final cropHeight = pixelCropRect.height;
    final cropLeft = pixelCropRect.left;
    final cropTop = pixelCropRect.top;

    // Only draw grid if crop area has meaningful size
    if (cropWidth > 10 && cropHeight > 10) {
      // Vertical grid lines
      for (int i = 1; i < 3; i++) {
        final x = cropLeft + cropWidth * i / 3;
        canvas.drawLine(
          Offset(x, cropTop),
          Offset(x, cropTop + cropHeight),
          gridPaint,
        );
      }

      // Horizontal grid lines
      for (int i = 1; i < 3; i++) {
        final y = cropTop + cropHeight * i / 3;
        canvas.drawLine(
          Offset(cropLeft, y),
          Offset(cropLeft + cropWidth, y),
          gridPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return cropRect != oldDelegate.cropRect;
  }
}
