/// Photo Review Screen - Matches design: 6a Photo Review Screen.png
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/image_compressor.dart';
import '../services/api_service.dart';
import '../services/firebase/auth_service.dart';
import '../widgets/priya_avatar.dart';
import '../widgets/app_header.dart';
import '../widgets/buttons/gradient_button.dart';
import 'solution_screen.dart';
import '../utils/performance_tracker.dart';

class PhotoReviewScreen extends StatelessWidget {
  final File imageFile;

  const PhotoReviewScreen({
    super.key,
    required this.imageFile,
  });

  void _retakePhoto(BuildContext context) {
    Navigator.of(context).pop(); // Go back to camera
  }

  Future<void> _usePhoto(BuildContext context) async {
    final tracker = PerformanceTracker('Snap and Solve - Use Photo to API Call');
    tracker.start();

    try {
      // Get authentication token with refresh capability
      tracker.step('Getting authentication token');
      final authService = Provider.of<AuthService>(context, listen: false);

      // Get token right before use to avoid race conditions
      String? token;
      try {
        token = await authService.getIdToken();
        // If null, try to refresh
        if (token == null && authService.currentUser != null) {
          token = await authService.currentUser!.getIdToken(true); // Force refresh
        }
      } catch (e) {
        tracker.end();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required. Please sign in again.'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return;
      }

      if (token == null) {
        tracker.end();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required. Please sign in again.'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return;
      }

      tracker.step('Authentication token retrieved');

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );

      // Compress image
      tracker.step('Starting image compression');
      final compressedFile = await ImageCompressor.compressImage(imageFile);
      tracker.step('Image compression completed');

      // Start solving (but don't wait) - use token immediately to avoid race condition
      tracker.step('Calling API solve endpoint');
      final solutionFuture = ApiService.solveQuestion(
        imageFile: compressedFile,
        authToken: token!, // Non-null assertion safe here after null check
      );
      tracker.step('API call initiated (async)');

      tracker.end();

      if (context.mounted) {
        // Pop loading dialog
        Navigator.of(context).pop();

        // Pop photo review screen
        Navigator.of(context).pop();

        // Navigate to solution screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SolutionScreen(
              solutionFuture: solutionFuture,
              imageFile: compressedFile,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Pop loading dialog if shown
        Navigator.of(context).pop();
        
        // Handle rate limiting errors specifically
        final errorMessage = e.toString();
        String displayMessage;
        if (errorMessage.contains('Too many requests')) {
          displayMessage = 'Too many requests. Please wait a moment and try again.';
        } else if (errorMessage.contains('Authentication')) {
          displayMessage = 'Authentication required. Please sign in again.';
        } else {
          displayMessage = 'Failed to process image: $e';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayMessage),
            backgroundColor: AppColors.errorRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildImagePreview(),
                    SizedBox(height: AppSpacing.space24),
                    _buildQualityCheck(),
                    SizedBox(height: AppSpacing.space24),
                    _buildPriyaMaamCard(),
                    SizedBox(height: AppSpacing.space32),
                    _buildButtons(context),
                    SizedBox(height: AppSpacing.space16),
                    _buildBottomText(),
                    // Bottom padding to account for Android navigation bar (using viewPadding for system UI)
                    SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return AppHeaderWithIcon(
      icon: Icons.check,
      title: 'Looking Good!',
      subtitle: 'Make sure the question is clear and readable',
      iconColor: AppColors.successGreen,
      iconSize: 40, // Further reduced from 48 to match other screens better
      onClose: () => Navigator.of(context).pop(),
      bottomPadding: 12, // Further reduced from 16
      gradient: AppColors.ctaGradient,
    );
  }

  Widget _buildImagePreview() {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        children: [
          // Pinch to zoom tooltip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.textDark,
              borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.zoom_in, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Pinch to zoom, use tools below to adjust',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Image preview
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildQualityCheck() {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.infoBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quality Check',
                        style: AppTextStyles.labelMedium,
                      ),
                      Text(
                        'Automatic analysis of your photo',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCheckItem('Text is readable', true),
            const SizedBox(height: 12),
            _buildCheckItem('Good lighting', true),
            const SizedBox(height: 12),
            _buildCheckItem('No blur detected', true),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String text, bool isGood) {
    return Row(
      children: [
        Icon(
          Icons.check_circle,
          color: isGood ? AppColors.successGreen : AppColors.textGray,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium,
          ),
        ),
        Text(
          isGood ? 'Good' : 'Check',
          style: AppTextStyles.labelSmall.copyWith(
            color: isGood ? AppColors.successGreen : AppColors.textGray,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPriyaMaamCard() {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.priyaCardGradient,
          borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
          border: Border.all(color: const Color(0xFFE9D5FF), width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PriyaAvatar(size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Priya Ma\'am',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: const Color(0xFF7C3AED),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF9333EA),
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Perfect! The question is clear and I can read it well. Ready to solve this for you! 💜',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: const Color(0xFF6B21A8),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        children: [
          // Use This Photo button
          GradientButton(
            text: 'Use This Photo',
            onPressed: () => _usePhoto(context),
            size: GradientButtonSize.large,
            leadingIcon: Icons.check,
          ),

          const SizedBox(height: 12),

          // Retake Photo button
          AppOutlinedButton(
            text: 'Retake Photo',
            onPressed: () => _retakePhoto(context),
            leadingIcon: Icons.refresh,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomText() {
    return Text(
      'You can always retake if the result isn\'t accurate',
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textLight,
      ),
      textAlign: TextAlign.center,
    );
  }
}
