import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subscription_models.dart';
import '../models/trial_status.dart';
import '../services/subscription_service.dart';
import '../screens/subscription/paywall_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Banner displayed at the top of the home screen when trial is active and urgent
/// Shows days remaining and upgrade CTA
class TrialBanner extends StatelessWidget {
  const TrialBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final subscriptionService = Provider.of<SubscriptionService>(context);
    final status = subscriptionService.status;

    // Don't show if no subscription status or not on trial
    if (status == null || !status.subscription.isOnTrial) {
      return const SizedBox.shrink();
    }

    final trial = status.subscription.trial;

    // Only show if trial exists and is urgent (5 days or less)
    if (trial == null || !trial.isUrgent) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            trial.urgencyColor.withOpacity(0.9),
            trial.urgencyColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              trial.urgencyIcon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trial.bannerText,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (trial.isLastDay) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Upgrade now to keep your Pro features',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PaywallScreen(
                      featureName: 'Continue Pro',
                    ),
                  ),
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                trial.ctaText,
                style: AppTextStyles.labelSmall.copyWith(
                  color: trial.urgencyColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
