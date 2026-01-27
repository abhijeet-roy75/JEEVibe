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
    return Consumer<SubscriptionService>(
      builder: (context, subscriptionService, child) {
        print('TrialBanner: build() called');
        final status = subscriptionService.status;

    print('TrialBanner: status = ${status != null}');
    if (status != null) {
      print('TrialBanner: isOnTrial = ${status.subscription.isOnTrial}');
      print('TrialBanner: source = ${status.subscription.source}');
      print('TrialBanner: trial = ${status.subscription.trial}');
      if (status.subscription.trial != null) {
        print('TrialBanner: trial.isUrgent = ${status.subscription.trial!.isUrgent}');
        print('TrialBanner: trial.daysRemaining = ${status.subscription.trial!.daysRemaining}');
      }
    }

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: trial.urgencyColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
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
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                trial.bannerText,
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Upgrade',
                style: AppTextStyles.labelSmall.copyWith(
                  color: trial.urgencyColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}
