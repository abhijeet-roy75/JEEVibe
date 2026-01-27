import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timer_off,
                  size: 32,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Your Pro Trial Has Ended',
                style: AppTextStyles.headerMedium.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Thank you for trying JEEVibe Pro!',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Before/After comparison
              Text(
                'What changes with Free tier:',
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),

              _buildLimitComparison('Snap & Solve', '15/day', '5/day'),
              _buildLimitComparison('Daily Quiz', '10/day', '1/day'),
              _buildLimitComparison('Offline Mode', 'Enabled', 'Disabled'),
              _buildLimitComparison('Solution History', '90 days', '7 days'),

              const SizedBox(height: 20),

              // Discount offer banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade50,
                      Colors.orange.shade100,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
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
                        const Icon(
                          Icons.local_offer,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Special Offer: 20% OFF',
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use code: TRIAL2PRO',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Valid for 7 days',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Upgrade button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onUpgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Claim Discount & Upgrade',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              feature,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
              ),
            ),
          ),
          const Spacer(),
          Text(
            proLimit,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textLight,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward,
            size: 14,
            color: AppColors.textLight,
          ),
          const SizedBox(width: 8),
          Text(
            freeLimit,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
