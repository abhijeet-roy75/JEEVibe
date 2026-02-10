import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_platform_sizing.dart';
import '../screens/subscription/paywall_screen.dart';

/// Dialog shown when user's trial expires
/// Shows before/after comparison and special discount offer
class TrialExpiredDialog extends StatelessWidget {
  final VoidCallback onUpgrade;
  final VoidCallback onContinueFree;

  const TrialExpiredDialog({
    super.key,
    required this.onUpgrade,
    required this.onContinueFree,
  });

  /// Show the dialog
  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TrialExpiredDialog(
        onUpgrade: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PaywallScreen(
                featureName: 'Trial Expired',
              ),
            ),
          );
        },
        onContinueFree: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg), // 16→12.8px Android
      ),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.xxl), // 24→19.2px Android
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon - CRITICAL sizing for dialog prominence
              Container(
                width: PlatformSizing.iconSize(64), // 64→56.32px Android
                height: PlatformSizing.iconSize(64), // 64→56.32px Android
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.timer_off,
                  size: AppIconSizes.xxl, // 32→28.8px Android
                  color: Colors.orange,
                ),
              ),
              SizedBox(height: AppSpacing.lg), // 16→12.8px Android

              // Title
              Text(
                'Your Pro Trial Has Ended',
                style: AppTextStyles.headerMedium.copyWith(
                  fontSize: PlatformSizing.fontSize(20), // 20→17.6px Android
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.xs), // 8→6.4px Android

              // Subtitle
              Text(
                'Thank you for trying JEEVibe Pro!',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.xl), // 20→16px Android

              // Before/After comparison
              Text(
                'What changes with Free tier:',
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: AppSpacing.md), // 12→9.6px Android

              _buildLimitComparison('Snap & Solve', '15/day', '5/day'),
              _buildLimitComparison('Daily Quiz', '10/day', '1/day'),
              _buildLimitComparison('Offline Mode', 'Enabled', 'Disabled'),
              _buildLimitComparison('Solution History', '90 days', '7 days'),

              SizedBox(height: AppSpacing.xl), // 20→16px Android

              // Discount offer banner
              Container(
                padding: EdgeInsets.all(AppSpacing.lg), // 16→12.8px Android
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade50,
                      Colors.orange.shade100,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md), // 12→9.6px Android
                  border: Border.all(
                    color: Colors.orange.shade200,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_offer,
                          color: Colors.orange,
                          size: AppIconSizes.md, // 20→17.6px Android
                        ),
                        SizedBox(width: AppSpacing.xs), // 8→6.4px Android
                        Text(
                          'Special Offer: 20% OFF',
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.xs), // 8→6.4px Android
                    Text(
                      'Use code: TRIAL2PRO',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontSize: PlatformSizing.fontSize(18), // 18→15.84px Android
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xxs), // 4→3.2px Android
                    Text(
                      'Valid for 7 days',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.orange.shade700,
                        fontSize: PlatformSizing.fontSize(12), // 12→10.56px Android
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.xl), // 20→16px Android

              // Upgrade button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onUpgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm), // 14→11.2px Android
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md), // 12→9.6px Android
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Claim Discount & Upgrade',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontSize: PlatformSizing.fontSize(16), // 16→14.08px Android
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.md), // 12→9.6px Android

              // Continue with free button
              TextButton(
                onPressed: onContinueFree,
                child: Text(
                  'Continue with Free',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLimitComparison(String feature, String proLimit, String freeLimit) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxs + 2), // 4.5→4.0px Android (xxs=2.5→2.0, +2 hardcoded)
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.xs), // 8→6.4px Android
          Expanded(
            flex: 2,
            child: Text(
              proLimit,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textLight,
                decoration: TextDecoration.lineThrough,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(width: AppSpacing.xxs), // 4→3.2px Android
          Icon(
            Icons.arrow_forward,
            size: PlatformSizing.iconSize(14), // 14→12.32px Android
            color: AppColors.textLight,
          ),
          SizedBox(width: AppSpacing.xxs), // 4→3.2px Android
          Expanded(
            flex: 2,
            child: Text(
              freeLimit,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
