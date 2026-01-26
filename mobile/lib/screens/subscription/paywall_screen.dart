import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/subscription_models.dart';
import '../../services/subscription_service.dart';

/// Paywall Screen
///
/// Shows upgrade options when user hits a limit or tries to access pro features.
/// Displays both Pro and Ultra tiers with a tab selector.
class PaywallScreen extends StatefulWidget {
  final String? featureName;
  final UsageType? usageType;
  final String? limitReachedMessage;
  /// If true, pre-select Ultra tab (e.g., when coming from AI Tutor)
  final bool suggestUltra;

  const PaywallScreen({
    super.key,
    this.featureName,
    this.usageType,
    this.limitReachedMessage,
    this.suggestUltra = false,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  List<PurchasablePlan> _plans = [];
  bool _isLoading = true;

  // Selected tier: 0 = Pro, 1 = Ultra
  int _selectedTierIndex = 0;

  @override
  void initState() {
    super.initState();
    // Pre-select Ultra if suggested (e.g., coming from AI Tutor feature)
    if (widget.suggestUltra) {
      _selectedTierIndex = 1;
    }
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final plans = await _subscriptionService.fetchPlans();
    setState(() {
      _plans = plans;
      _isLoading = false;
    });
  }

  PurchasablePlan? get _selectedPlan {
    if (_plans.isEmpty) return null;
    // Plans are ordered: Pro first, then Ultra
    if (_selectedTierIndex == 0) {
      return _plans.firstWhere(
        (p) => p.tierId == 'pro',
        orElse: () => _plans.first,
      );
    } else {
      return _plans.firstWhere(
        (p) => p.tierId == 'ultra',
        orElse: () => _plans.length > 1 ? _plans[1] : _plans.first,
      );
    }
  }

  bool get _isUltraSelected => _selectedTierIndex == 1;

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

                    const SizedBox(height: 24),

                    // Tier selector tabs
                    _buildTierSelector(),

                    const SizedBox(height: 24),

                    // Current tier badge
                    _buildCurrentTierBadge(),

                    const SizedBox(height: 24),

                    // Features comparison
                    _buildFeaturesComparison(),

                    const SizedBox(height: 32),

                    // Pricing cards
                    if (_selectedPlan != null) _buildPricingSection(_selectedPlan!),

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
        // Show limit reached banner if applicable
        if (widget.limitReachedMessage != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warningAmber.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.warningAmber,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.limitReachedMessage!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        // Animated icon based on selected tier
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: _isUltraSelected ? _ultraGradient : AppColors.ctaGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.button,
          ),
          child: Icon(
            _isUltraSelected ? Icons.diamond_outlined : Icons.workspace_premium_rounded,
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
              ? 'Upgrade to get more ${widget.featureName} and unlock your potential'
              : _isUltraSelected
                  ? 'Get maximum access with AI Tutor support'
                  : 'Upgrade to Pro for enhanced features',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTierSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTierTab(
              index: 0,
              title: 'Pro',
              icon: Icons.workspace_premium_rounded,
              gradient: AppColors.ctaGradient,
            ),
          ),
          Expanded(
            child: _buildTierTab(
              index: 1,
              title: 'Ultra',
              icon: Icons.diamond_outlined,
              gradient: _ultraGradient,
              badge: 'Best Value',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierTab({
    required int index,
    required String title,
    required IconData icon,
    required Gradient gradient,
    String? badge,
  }) {
    final isSelected = _selectedTierIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedTierIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: isSelected ? gradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? AppShadows.button : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            if (badge != null && isSelected) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
    final tierName = _isUltraSelected ? 'Ultra' : 'Pro';
    final tierColor = _isUltraSelected ? _ultraColor : AppColors.success;
    final tierBgColor = _isUltraSelected ? _ultraLightColor : AppColors.cardLightGreen;

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
          Text(
            'What you get with $tierName',
            style: const TextStyle(
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
                const Expanded(
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
                    tierName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tierColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Features - different values for Pro vs Ultra
          // Ultra tier has soft caps (50/25/100) instead of truly unlimited
          _buildFeatureRow(
            Icons.camera_alt_outlined,
            'Snap & Solve',
            '5/day',
            _isUltraSelected ? '50/day' : '10/day',
            tierColor,
            tierBgColor,
          ),
          _buildFeatureRow(
            Icons.quiz_outlined,
            'Daily Quizzes',
            '1/day',
            _isUltraSelected ? '25/day' : '10/day',
            tierColor,
            tierBgColor,
          ),
          _buildFeatureRow(
            Icons.school_outlined,
            'AI Tutor (Priya Ma\'am)',
            'No',
            _isUltraSelected ? '100/day' : 'No',
            tierColor,
            tierBgColor,
            highlight: _isUltraSelected, // Highlight this for Ultra
          ),
          _buildFeatureRow(
            Icons.analytics_outlined,
            'Analytics',
            'Basic',
            'Full',
            tierColor,
            tierBgColor,
          ),
          _buildFeatureRow(
            Icons.gps_fixed_outlined,
            'Chapter Practice',
            '3/week',
            'Unlimited',
            tierColor,
            tierBgColor,
          ),
          _buildFeatureRow(
            Icons.assignment_outlined,
            'JEE Simulations',
            '1/month',
            _isUltraSelected ? '15/month' : '5/month',
            tierColor,
            tierBgColor,
          ),
          _buildFeatureRow(
            Icons.history_outlined,
            'Solution History',
            '7 days',
            _isUltraSelected ? '1 year' : '30 days',
            tierColor,
            tierBgColor,
          ),
          _buildFeatureRow(
            Icons.offline_bolt_outlined,
            'Offline Mode',
            'No',
            'Yes',
            tierColor,
            tierBgColor,
          ),
          if (_isUltraSelected) ...[
            _buildFeatureRow(
              Icons.support_agent_outlined,
              'Priority Support',
              'No',
              'Yes',
              tierColor,
              tierBgColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
    IconData icon,
    String feature,
    String free,
    String tierValue,
    Color tierColor,
    Color tierBgColor, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: highlight ? tierColor : AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              free,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
                color: tierBgColor,
                borderRadius: BorderRadius.circular(8),
                border: highlight ? Border.all(color: tierColor, width: 1.5) : null,
              ),
              child: Text(
                tierValue,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tierColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection(PurchasablePlan plan) {
    final tierColor = _isUltraSelected ? _ultraColor : AppColors.primary;
    final tierLightColor = _isUltraSelected ? _ultraLightColor : AppColors.cardLightPurple;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Choose Your ${_isUltraSelected ? "Ultra" : "Pro"} Plan',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            if (_isUltraSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: _ultraGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'RECOMMENDED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _buildPricingCard(
          'Monthly',
          '\u20B9${plan.monthly.price}',
          '\u20B9${plan.monthly.perMonth}/month',
          plan.monthly.badge,
          false,
          tierColor,
          tierLightColor,
        ),
        const SizedBox(height: 12),
        _buildPricingCard(
          'Quarterly',
          '\u20B9${plan.quarterly.price}',
          '\u20B9${plan.quarterly.perMonth}/month',
          plan.quarterly.badge,
          true,
          tierColor,
          tierLightColor,
        ),
        const SizedBox(height: 12),
        _buildPricingCard(
          'Annual',
          '\u20B9${plan.annual.price}',
          '\u20B9${plan.annual.perMonth}/month',
          plan.annual.badge,
          false,
          tierColor,
          tierLightColor,
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
    Color tierColor,
    Color tierLightColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPopular ? tierLightColor : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPopular ? tierColor : AppColors.borderDefault,
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
                        color: isPopular ? tierColor : AppColors.textPrimary,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPopular ? tierColor : AppColors.success,
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
                  style: const TextStyle(
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
              color: isPopular ? tierColor : AppColors.textPrimary,
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
      child: const Row(
        children: [
          Icon(Icons.construction_rounded, color: AppColors.warning),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

  // Ultra tier colors
  static const _ultraColor = Color(0xFFD4A017); // Gold color
  static const _ultraLightColor = Color(0xFFFFF8E1); // Light gold background
  static const _ultraGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
