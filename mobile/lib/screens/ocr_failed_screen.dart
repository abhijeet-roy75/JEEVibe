/// OCR Failed Screen - Matches design: 6b OCR Recognition Failed.png
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/priya_avatar.dart';
import '../widgets/app_header.dart';
import '../widgets/buttons/gradient_button.dart';
import '../widgets/buttons/icon_button.dart';

class OCRFailedScreen extends StatelessWidget {
  final String? errorMessage;

  const OCRFailedScreen({super.key, this.errorMessage});

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
                padding: AppSpacing.screenPadding,
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.space24),
                    _buildWhatWentWrong(),
                    const SizedBox(height: AppSpacing.space24),
                    _buildPriyaMaamCard(),
                    const SizedBox(height: AppSpacing.space24),
                    _buildQuickTips(),
                    const SizedBox(height: AppSpacing.space32),
                    _buildButtons(context),
                    const SizedBox(height: AppSpacing.space32),
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
    return AppHeader(
      leading: AppIconButton.close(
        onPressed: () => Navigator.of(context).pop(),
        color: Colors.white,
      ),
      centerContent: Container(
        width: 48, // Reduced from 64
        height: 48,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.error_outline,
          color: AppColors.errorRed,
          size: 24, // Reduced from 32
        ),
      ),
      title: Text(
        'Couldn\'t Read Question',
        style: AppTextStyles.headerWhite.copyWith(fontSize: 20), // Consistent with other headers
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Let\'s try again with a clearer photo',
          textAlign: TextAlign.center,
          style: AppTextStyles.subtitleWhite,
        ),
      ),
      // Use default padding (24 top, 16 bottom) for consistency
      gradient: AppColors.errorGradient,
    );
  }

  Widget _buildWhatWentWrong() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What Went Wrong?',
            style: AppTextStyles.headerSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'The image quality wasn\'t clear enough for me to read the question accurately. This usually happens when:',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 20),
          _buildIssueItem(1, 'Blurry or out of focus', 'Hold your phone steady when capturing'),
          const SizedBox(height: 16),
          _buildIssueItem(2, 'Poor lighting or shadows', 'Ensure good, even lighting on the page'),
          const SizedBox(height: 16),
          _buildIssueItem(3, 'Question cut off or incomplete', 'Frame the entire question within guides'),
          const SizedBox(height: 16),
          _buildIssueItem(4, 'Handwriting too messy', 'Works best with neat handwriting or print'),
        ],
      ),
    );
  }

  Widget _buildIssueItem(int number, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorBackground.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.errorRed,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriyaMaamCard() {
    return Container(
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
                  'Don\'t worry! This happens sometimes. Try taking a new photo with better lighting and make sure the text is in focus. I\'m here to help! 💪',
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
    );
  }

  Widget _buildQuickTips() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warningBackground.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: AppColors.warningAmber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Quick Tips for Next Try',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipItem('Use good natural light or turn on room lights'),
          const SizedBox(height: 12),
          _buildTipItem('Hold your phone 6-8 inches above the page'),
          const SizedBox(height: 12),
          _buildTipItem('Make sure the entire question fits in the frame'),
          const SizedBox(height: 12),
          _buildTipItem('Tap to focus before capturing if text looks blurry'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check,
          color: AppColors.successGreen,
          size: 18,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        // Try Again with Camera button
        GradientButton(
          text: 'Try Again with Camera',
          onPressed: () {
            // Pop back to camera screen
            Navigator.of(context).pop();
          },
          size: GradientButtonSize.large,
          leadingIcon: Icons.camera_alt,
        ),

        const SizedBox(height: 12),

        // Back to Dashboard button
        AppOutlinedButton(
          text: 'Back to Dashboard',
          onPressed: () {
            // Pop all the way back to home
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ],
    );
  }
}
