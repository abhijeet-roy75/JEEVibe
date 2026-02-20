/// Weak Spot Results Screen
/// Shown after submitting retrieval answers.
/// Pass: 2+/3 correct → "Weak Spot Improved!" with new state label.
/// Fail: <2/3 correct → "Keep Practicing" with encouragement.
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:jeevibe_mobile/theme/app_platform_sizing.dart';
import '../widgets/buttons/gradient_button.dart';
import 'main_navigation_screen.dart';

/// Maps backend node state to user-facing label.
String nodeStateLabel(String state) {
  switch (state) {
    case 'improving':
      return 'Keep Practicing';
    case 'stable':
      return 'Recently Strengthened';
    case 'active':
    default:
      return 'Needs Strengthening';
  }
}

class WeakSpotResultsScreen extends StatelessWidget {
  final bool passed;
  final int correctCount;
  final int totalCount;
  final String newNodeState;
  final String nodeTitle;

  const WeakSpotResultsScreen({
    super.key,
    required this.passed,
    required this.correctCount,
    required this.totalCount,
    required this.newNodeState,
    required this.nodeTitle,
  });

  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: PlatformSizing.spacing(88),
                height: PlatformSizing.spacing(88),
                decoration: BoxDecoration(
                  color: passed
                      ? AppColors.successGreen.withValues(alpha: 0.1)
                      : AppColors.primaryPurple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  passed ? Icons.emoji_events_rounded : Icons.fitness_center_rounded,
                  size: PlatformSizing.iconSize(44),
                  color: passed ? AppColors.successGreen : AppColors.primaryPurple,
                ),
              ),
              SizedBox(height: PlatformSizing.spacing(24)),

              // Title
              Text(
                passed ? 'Weak Spot Improved!' : 'Keep Practicing',
                style: AppTextStyles.headerMedium.copyWith(
                  fontSize: PlatformSizing.fontSize(24),
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: PlatformSizing.spacing(12)),

              // Score
              Text(
                'You got $correctCount/$totalCount correct.',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: PlatformSizing.fontSize(16),
                  color: AppColors.textMedium,
                ),
              ),
              SizedBox(height: PlatformSizing.spacing(20)),

              // Detail card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(PlatformSizing.spacing(20)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(PlatformSizing.radius(16)),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    // Node label
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: PlatformSizing.spacing(12),
                        vertical: PlatformSizing.spacing(6),
                      ),
                      decoration: BoxDecoration(
                        color: passed
                            ? AppColors.successGreen.withValues(alpha: 0.1)
                            : AppColors.primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(PlatformSizing.radius(20)),
                      ),
                      child: Text(
                        nodeStateLabel(newNodeState),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: passed ? AppColors.successGreen : AppColors.primaryPurple,
                          fontWeight: FontWeight.w600,
                          fontSize: PlatformSizing.fontSize(13),
                        ),
                      ),
                    ),
                    SizedBox(height: PlatformSizing.spacing(12)),

                    Text(
                      passed
                          ? 'Great work on "$nodeTitle"! It\'s now marked as improving — do more chapter practice to make it fully stable.'
                          : '"$nodeTitle" still needs work. Review the lesson and try more chapter practice, then come back to strengthen it.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMedium,
                        height: 1.5,
                        fontSize: PlatformSizing.fontSize(14),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: PlatformSizing.spacing(32)),

              // CTA
              GradientButton(
                text: 'Back to Home',
                onPressed: () => _goHome(context),
                size: GradientButtonSize.large,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
