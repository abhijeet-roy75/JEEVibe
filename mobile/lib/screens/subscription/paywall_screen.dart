import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/subscription_models.dart';
import '../../services/subscription_service.dart';

/// Paywall Screen
///
/// Shows upgrade options when user hits a limit or tries to access pro features.
/// For Phase 1 (no Razorpay), this shows the upgrade prompt without payment.
class PaywallScreen extends StatefulWidget {
  final String? featureName;
  final UsageType? usageType;

  const PaywallScreen({
    super.key,
    this.featureName,
    this.usageType,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  List<PurchasablePlan> _plans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final plans = await _subscriptionService.fetchPlans();
    setState(() {
      _plans = plans;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    // Hero section
                    _buildHeroSection(),

                    const SizedBox(height: 32),

                    // Current tier badge
                    _buildCurrentTierBadge(),

                    const SizedBox(height: 24),

                    // Features comparison
                    _buildFeaturesComparison(),

                    const SizedBox(height: 32),

                    // Pricing cards
                    if (_plans.isNotEmpty) _buildPricingSection(_plans.first),

                    const SizedBox(height: 24),

                    // Coming soon notice
                    _buildComingSoonNotice(),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        // Crown icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppColors.ctaGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.button,
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: Colors.white,
            size: 44,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Unlock Your Potential',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.featureName != null
              ? 'Upgrade to get ${widget.featureName} and unlock features'
              : 'Upgrade to Pro for unlimited access',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentTierBadge() {
    final tier = _subscriptionService.currentTier;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardLightPurple,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            'Current: ${tier.name.toUpperCase()}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesComparison() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What you get with Pro',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Column headers
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const SizedBox(width: 34), // Icon space
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Feature',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Free',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Pro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _buildFeatureRow(Icons.camera_alt_outlined, 'Snap & Solve', '5/day', '10/day'),
          _buildFeatureRow(Icons.quiz_outlined, 'Daily Quizzes', '1/day', '10/day'),
          _buildFeatureRow(Icons.analytics_outlined, 'Analytics', 'Basic', 'Full Access'),
          _buildFeatureRow(Icons.history_outlined, 'Solution History', '7 days', '30 days'),
          _buildFeatureRow(Icons.offline_bolt_outlined, 'Offline Mode', 'No', 'Yes'),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String feature, String free, String pro) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              free,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cardLightGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                pro,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection(PurchasablePlan plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Your Plan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildPricingCard(
          'Monthly',
          '\u20B9${plan.monthly.price}',
          '\u20B9${plan.monthly.perMonth}/month',
          plan.monthly.badge,
          false,
        ),
        const SizedBox(height: 12),
        _buildPricingCard(
          'Quarterly',
          '\u20B9${plan.quarterly.price}',
          '\u20B9${plan.quarterly.perMonth}/month',
          plan.quarterly.badge,
          true,
        ),
        const SizedBox(height: 12),
        _buildPricingCard(
          'Annual',
          '\u20B9${plan.annual.price}',
          '\u20B9${plan.annual.perMonth}/month',
          plan.annual.badge,
          false,
        ),
      ],
    );
  }

  Widget _buildPricingCard(
    String duration,
    String price,
    String perMonth,
    String? badge,
    bool isPopular,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPopular ? AppColors.cardLightPurple : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPopular ? AppColors.primary : AppColors.borderDefault,
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      duration,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isPopular ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPopular ? AppColors.primary : AppColors.success,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  perMonth,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isPopular ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardLightAmber,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.construction_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Payments Coming Soon',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'We\'re setting up payments. Stay tuned!',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
