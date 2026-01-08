/// Image Preview Screen - Custom preview with large tap targets
/// Replaces native ImageCropper on Android for better usability
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
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
  bool _isCropping = false;

  Future<void> _confirmImage() async {
    // Option to crop before confirming
    setState(() => _isCropping = true);

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: widget.imageFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Question',
            toolbarColor: AppColors.primaryPurple,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            hideBottomControls: false,
            showCropGrid: true,
            cropGridColor: Colors.white,
            cropFrameColor: Colors.white,
            activeControlsWidgetColor: AppColors.primaryPurple,
          ),
          IOSUiSettings(
            title: 'Crop Question',
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Back',
            aspectRatioLockEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        widget.onConfirm(File(croppedFile.path));
      } else {
        // User cancelled cropping, stay on preview
        setState(() => _isCropping = false);
      }
    } catch (e) {
      setState(() => _isCropping = false);
      // If cropping fails, just use original image
      widget.onConfirm(widget.imageFile);
    }
  }

  void _useWithoutCrop() {
    widget.onConfirm(widget.imageFile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Cancel button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: AppColors.ctaGradient,
              ),
              child: Row(
                children: [
                  // Large Cancel button
                  TextButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    label: Text(
                      'Cancel',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Preview',
                    style: AppTextStyles.headerMedium.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  // Spacer to balance
                  const SizedBox(width: 100),
                ],
              ),
            ),

            // Image preview
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.file(
                    widget.imageFile,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // Bottom action buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
              ),
              child: Column(
                children: [
                  // Hint text
                  Text(
                    'Pinch to zoom • Tap buttons below to continue',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      // Crop & Use button
                      Expanded(
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isCropping ? null : _confirmImage,
                              borderRadius: BorderRadius.circular(12),
                              child: Center(
                                child: _isCropping
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primaryPurple,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.crop,
                                            color: AppColors.primaryPurple,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Crop & Use',
                                            style: AppTextStyles.labelMedium.copyWith(
                                              color: AppColors.primaryPurple,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Use as-is button (large, primary)
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: AppColors.ctaGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: AppShadows.buttonShadow,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isCropping ? null : _useWithoutCrop,
                              borderRadius: BorderRadius.circular(12),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Use Photo',
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
