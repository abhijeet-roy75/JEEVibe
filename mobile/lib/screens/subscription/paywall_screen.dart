import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_platform_sizing.dart';
import '../../models/subscription_models.dart';
import '../../services/subscription_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/buttons/icon_button.dart';

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
      extendBodyBehindAppBar: true,
      appBar: null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Standard header
                AppHeader(
                  showGradient: true,
                  gradient: AppColors.ctaGradient,
                  leading: AppIconButton.close(
                    onPressed: () => Navigator.of(context).pop(),
                    size: AppIconButtonSize.medium,
                  ),
                  title: Text(
                    'Upgrade',
                    style: AppTextStyles.headerWhite.copyWith(
                      fontSize: PlatformSizing.fontSize(20), // 20→17.6px Android
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl), // 24→19.2px Android
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: AppSpacing.lg), // 16→12.8px Android

                          // Hero section
                          _buildHeroSection(),

                    SizedBox(height: AppSpacing.xxl), // 24→19.2px Android

                    // Tier selector tabs
                    _buildTierSelector(),

                    SizedBox(height: AppSpacing.xxl), // 24→19.2px Android

                    // Current tier badge
                    _buildCurrentTierBadge(),

                    SizedBox(height: AppSpacing.xxl), // 24→19.2px Android

                    // Features comparison
                    _buildFeaturesComparison(),

                    SizedBox(height: AppSpacing.xxxl), // 32→25.6px Android

                    // Pricing cards
                    if (_selectedPlan != null) _buildPricingSection(_selectedPlan!),

                    SizedBox(height: AppSpacing.xxl), // 24→19.2px Android

                          // Coming soon notice
                          _buildComingSoonNotice(),

                          SizedBox(height: PlatformSizing.buttonHeight(48)), // 48→44px Android
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
            padding: EdgeInsets.all(AppSpacing.lg), // 16→12.8px Android
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md), // 12→9.6px Android
              border: Border.all(
                color: AppColors.warningAmber.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.warningAmber,
                  size: AppIconSizes.lg, // 24→21.12px Android
                ),
                SizedBox(width: AppSpacing.md), // 12→9.6px Android
                Expanded(
                  child: Text(
                    widget.limitReachedMessage!,
                    style: TextStyle(
                      fontSize: PlatformSizing.fontSize(14), // 14→12.32px Android
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.xxl), // 24→19.2px Android
        ],
        // Animated icon based on selected tier - CRITICAL sizing (most prominent element)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: PlatformSizing.iconSize(80), // 80→70.4px Android
          height: PlatformSizing.iconSize(80), // 80→70.4px Android
          decoration: BoxDecoration(
            gradient: _isUltraSelected ? _ultraGradient : AppColors.ctaGradient,
            borderRadius: BorderRadius.circular(AppRadius.xl), // 20→16px Android
            boxShadow: AppShadows.button,
          ),
          child: Icon(
            _isUltraSelected ? Icons.diamond_outlined : Icons.workspace_premium_rounded,
            color: Colors.white,
            size: PlatformSizing.iconSize(44), // 44→38.72px Android
          ),
        ),
        SizedBox(height: AppSpacing.xxl), // 24→19.2px Android
        Text(
          'Unlock Your Potential',
          style: TextStyle(
            fontSize: PlatformSizing.fontSize(28), // 28→24.64px Android
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: AppSpacing.xs), // 8→6.4px Android
        Text(
          widget.featureName != null
              ? 'Upgrade to get more ${widget.featureName} and unlock your potential'
              : _isUltraSelected
                  ? 'Get maximum access with AI Tutor support'
                  : 'Upgrade to Pro for enhanced features',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: PlatformSizing.fontSize(16), // 16→14.08px Android
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTierSelector() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xxs), // 4→3.2px Android
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppRadius.md), // 12→9.6px Android
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
        padding: EdgeInsets.symmetric(
          vertical: AppSpacing.md, // 12→9.6px Android
          horizontal: AppSpacing.lg, // 16→12.8px Android
        ),
        decoration: BoxDecoration(
          gradient: isSelected ? gradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm), // 10→8px Android
          boxShadow: isSelected ? AppShadows.button : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppIconSizes.md, // 20→17.6px Android
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            SizedBox(width: AppSpacing.xs), // 8→6.4px Android
            Text(
              title,
              style: TextStyle(
                fontSize: PlatformSizing.fontSize(16), // 16→14.08px Android
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            if (badge != null && isSelected) ...[
              SizedBox(width: AppSpacing.xs), // 8→6.4px Android
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxs + 2, // 6→4.8px Android
                  vertical: AppSpacing.xxs / 2, // 2→1.6px Android
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.xs), // 8→6.4px Android
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: PlatformSizing.fontSize(9), // 9→7.92px Android
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
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, // 16→12.8px Android
        vertical: AppSpacing.xs, // 8→6.4px Android
      ),
      decoration: BoxDecoration(
        color: AppColors.cardLightPurple,
        borderRadius: BorderRadius.circular(AppRadius.xl), // 20→16px Android
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: PlatformSizing.fontSize(18), color: AppColors.primary), // 18→15.84px Android
          SizedBox(width: AppSpacing.xs), // 8→6.4px Android
          Text(
            'Current: ${tier.name.toUpperCase()}',
            style: TextStyle(
              fontSize: PlatformSizing.fontSize(14), // 14→12.32px Android
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
      padding: EdgeInsets.all(AppSpacing.xl), // 20→16px Android
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg), // 16→12.8px Android
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What you get with $tierName',
            style: TextStyle(
              fontSize: PlatformSizing.fontSize(18), // 18→15.84px Android
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSpacing.lg), // 16→12.8px Android
          // Column headers
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.xs), // 8→6.4px Android
            child: Row(
              children: [
                SizedBox(width: PlatformSizing.iconSize(34)), // 34→29.92px Android - Icon space
                Expanded(
                  flex: 3,
                  child: Text(
                    'Feature',
                    style: TextStyle(
                      fontSize: PlatformSizing.fontSize(12), // 12→10.56px Android
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
                      fontSize: PlatformSizing.fontSize(12), // 12→10.56px Android
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
                      fontSize: PlatformSizing.fontSize(12), // 12→10.56px Android
                      fontWeight: FontWeight.w600,
                      color: tierColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(height: AppSpacing.xs), // 8→6.4px Android

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
            '5/day',
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
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm - 4), // 10→8px Android
      child: Row(
        children: [
          Icon(icon, size: PlatformSizing.iconSize(22), color: highlight ? tierColor : AppColors.primary), // 22→19.36px Android
          SizedBox(width: AppSpacing.md), // 12→9.6px Android
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: TextStyle(
                fontSize: PlatformSizing.fontSize(14), // 14→12.32px Android
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
              style: TextStyle(
                fontSize: PlatformSizing.fontSize(13), // 13→11.44px Android
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, // 8→6.4px Android
                vertical: AppSpacing.xxs, // 4→3.2px Android
              ),
              decoration: BoxDecoration(
                color: tierBgColor,
                borderRadius: BorderRadius.circular(AppRadius.xs), // 8→6.4px Android
                border: highlight ? Border.all(color: tierColor, width: 1.5) : null,
              ),
              child: Text(
                tierValue,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: PlatformSizing.fontSize(13), // 13→11.44px Android
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
              style: TextStyle(
                fontSize: PlatformSizing.fontSize(18), // 18→15.84px Android
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(width: AppSpacing.xs), // 8→6.4px Android
            if (_isUltraSelected)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs, // 8→6.4px Android
                  vertical: AppSpacing.xxs / 2, // 2→1.6px Android
                ),
                decoration: BoxDecoration(
                  gradient: _ultraGradient,
                  borderRadius: BorderRadius.circular(AppRadius.sm), // 10→8px Android
                ),
                child: Text(
                  'RECOMMENDED',
                  style: TextStyle(
                    fontSize: PlatformSizing.fontSize(9), // 9→7.92px Android
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: AppSpacing.lg), // 16→12.8px Android
        _buildPricingCard(
          'Monthly',
          '\u20B9${plan.monthly.price}',
          '\u20B9${plan.monthly.perMonth}/month',
          plan.monthly.badge,
          false,
          tierColor,
          tierLightColor,
        ),
        SizedBox(height: AppSpacing.md), // 12→9.6px Android
        _buildPricingCard(
          'Quarterly',
          '\u20B9${plan.quarterly.price}',
          '\u20B9${plan.quarterly.perMonth}/month',
          plan.quarterly.badge,
          true,
          tierColor,
          tierLightColor,
        ),
        SizedBox(height: AppSpacing.md), // 12→9.6px Android
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
      padding: EdgeInsets.all(AppSpacing.lg), // 16→12.8px Android
      decoration: BoxDecoration(
        color: isPopular ? tierLightColor : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md), // 12→9.6px Android
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
                        fontSize: PlatformSizing.fontSize(16), // 16→14.08px Android
                        fontWeight: FontWeight.w600,
                        color: isPopular ? tierColor : AppColors.textPrimary,
                      ),
                    ),
                    if (badge != null) ...[
                      SizedBox(width: AppSpacing.xs), // 8→6.4px Android
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs, // 8→6.4px Android
                          vertical: AppSpacing.xxs / 2, // 2→1.6px Android
                        ),
                        decoration: BoxDecoration(
                          color: isPopular ? tierColor : AppColors.success,
                          borderRadius: BorderRadius.circular(AppRadius.sm), // 10→8px Android
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: PlatformSizing.fontSize(12),  // 12px iOS, 10.56px Android (was 10)
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: AppSpacing.xxs), // 4→3.2px Android
                Text(
                  perMonth,
                  style: TextStyle(
                    fontSize: PlatformSizing.fontSize(13), // 13→11.44px Android
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: TextStyle(
              fontSize: PlatformSizing.fontSize(20), // 20→17.6px Android
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
      padding: EdgeInsets.all(AppSpacing.lg), // 16→12.8px Android
      decoration: BoxDecoration(
        color: AppColors.cardLightAmber,
        borderRadius: BorderRadius.circular(AppRadius.md), // 12→9.6px Android
      ),
      child: Row(
        children: [
          Icon(Icons.construction_rounded, color: AppColors.warning),
          SizedBox(width: AppSpacing.md), // 12→9.6px Android
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payments Coming Soon',
                  style: TextStyle(
                    fontSize: PlatformSizing.fontSize(14), // 14→12.32px Android
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: AppSpacing.xxs), // 4→3.2px Android
                Text(
                  'We\'re setting up payments. Stay tuned!',
                  style: TextStyle(
                    fontSize: PlatformSizing.fontSize(12), // 12→10.56px Android
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
