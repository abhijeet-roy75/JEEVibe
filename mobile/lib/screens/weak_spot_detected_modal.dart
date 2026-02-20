/// Weak Spot Detection Modal
/// Shown as a bottom sheet after chapter practice when a weak spot is detected.
/// User can choose to read the capsule immediately or save for later.
import 'package:flutter/material.dart';
import '../models/chapter_practice_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:jeevibe_mobile/theme/app_platform_sizing.dart';
import '../widgets/buttons/gradient_button.dart';
import 'capsule_screen.dart';

/// Shows the weak spot detected modal as a bottom sheet.
/// Returns true if user tapped "Read Capsule", false if dismissed/skipped.
Future<void> showWeakSpotDetectedModal(
  BuildContext context,
  WeakSpotDetected weakSpot,
  String authToken,
  String userId,
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => WeakSpotDetectedModal(
      weakSpot: weakSpot,
      authToken: authToken,
      userId: userId,
    ),
  );
}

class WeakSpotDetectedModal extends StatelessWidget {
  final WeakSpotDetected weakSpot;
  final String authToken;
  final String userId;

  const WeakSpotDetectedModal({
    super.key,
    required this.weakSpot,
    required this.authToken,
    required this.userId,
  });

  Color get _severityColor {
    switch (weakSpot.severityLevel) {
      case 'high':
        return AppColors.errorRed;
      case 'medium':
        return const Color(0xFFF59E0B); // amber
      default:
        return AppColors.infoBlue;
    }
  }

  IconData get _severityIcon {
    switch (weakSpot.severityLevel) {
      case 'high':
        return Icons.warning_rounded;
      case 'medium':
        return Icons.info_rounded;
      default:
        return Icons.lightbulb_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPadding + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: PlatformSizing.spacing(20)),

          // Icon + title
          Container(
            width: PlatformSizing.spacing(56),
            height: PlatformSizing.spacing(56),
            decoration: BoxDecoration(
              color: _severityColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _severityIcon,
              color: _severityColor,
              size: PlatformSizing.iconSize(28),
            ),
          ),
          SizedBox(height: PlatformSizing.spacing(12)),

          Text(
            'Weak Spot Detected',
            style: AppTextStyles.headerMedium.copyWith(
              fontSize: PlatformSizing.fontSize(20),
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: PlatformSizing.spacing(6)),

          // Node name
          Text(
            weakSpot.title,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: PlatformSizing.fontSize(16),
              fontWeight: FontWeight.w600,
              color: _severityColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: PlatformSizing.spacing(16)),

          // Description box
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(PlatformSizing.spacing(16)),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your answers suggest a weak spot in this concept. '
                  'A 90-second capsule will help you fix it.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMedium,
                    height: 1.5,
                    fontSize: PlatformSizing.fontSize(14),
                  ),
                ),
                SizedBox(height: PlatformSizing.spacing(10)),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: PlatformSizing.iconSize(14),
                      color: AppColors.textMedium,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '90 seconds to read',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMedium,
                        fontSize: PlatformSizing.fontSize(12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.quiz_outlined,
                      size: PlatformSizing.iconSize(14),
                      color: AppColors.textMedium,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '3 validation questions',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMedium,
                        fontSize: PlatformSizing.fontSize(12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: PlatformSizing.spacing(20)),

          // Primary CTA
          GradientButton(
            text: 'Read Capsule ✨',
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CapsuleScreen(
                    capsuleId: weakSpot.capsuleId ?? '',
                    nodeId: weakSpot.nodeId,
                    nodeTitle: weakSpot.title,
                    authToken: authToken,
                    userId: userId,
                  ),
                ),
              );
            },
            size: GradientButtonSize.large,
          ),
          SizedBox(height: PlatformSizing.spacing(12)),

          // Secondary CTA
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Save for Later',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMedium,
                fontSize: PlatformSizing.fontSize(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
