/// History Screen
/// Main history hub with scrollable tabs for different history types

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_header.dart';
import '../all_solutions_screen.dart';
import '../subscription/paywall_screen.dart';
import '../../models/subscription_models.dart';
import 'daily_quiz_history_screen.dart';
import 'chapter_practice_history_screen.dart';
import 'mock_test_history_screen.dart';
import 'pyq_history_screen.dart';

class HistoryScreen extends StatefulWidget {
  final int initialTabIndex;

  const HistoryScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_HistoryTab> _tabs = [
    _HistoryTab(
      label: 'Daily Adaptive Quiz',
      icon: Icons.trending_up_outlined,
    ),
    _HistoryTab(
      label: 'Chapter Practice',
      icon: Icons.menu_book_outlined,
    ),
    _HistoryTab(
      label: 'Snap & Solve',
      icon: Icons.camera_alt_outlined,
    ),
    _HistoryTab(
      label: 'Mock Tests',
      icon: Icons.assignment_outlined,
    ),
    _HistoryTab(
      label: 'PYQ',
      icon: Icons.history_edu_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _tabs.length - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header (has SafeArea built-in for top)
          _buildHeader(),

          // Tab bar and content (SafeArea for bottom only)
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        const DailyQuizHistoryScreen(),
                        const ChapterPracticeHistoryScreen(),
                        const AllSolutionsScreen(isInHistoryTab: true),
                        const MockTestHistoryScreen(),
                        const PyqHistoryScreen(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer2<SubscriptionService, UserProfileProvider>(
      builder: (context, subscriptionService, userProfileProvider, child) {
        final tier = subscriptionService.currentTier;
        final tierDisplay = _getTierDisplay(tier);
        final userName = userProfileProvider.firstName;

        return AppHeader(
          showGradient: true,
          gradient: AppColors.ctaGradient,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  'assets/images/JEEVibeLogo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.history,
                      color: AppColors.primary,
                      size: 22,
                    );
                  },
                ),
              ),
            ),
          ),
          title: Text(
            'Hi $userName! 👋',
            style: AppTextStyles.headerWhite.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Practice History',
              style: AppTextStyles.bodyWhite.copyWith(
                fontSize: 14,
                color: Colors.white.withAlpha(230),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          trailing: GestureDetector(
            onTap: () => _onTierBadgeTap(tier),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                gradient: tierDisplay.gradient,
                color: tierDisplay.gradient == null ? tierDisplay.backgroundColor : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: tierDisplay.borderColor,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tierDisplay.icon,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tierDisplay.label,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.background,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTextStyles.bodyMedium,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.borderDefault,
        tabs: _tabs.map((tab) {
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tab.icon, size: 18),
                const SizedBox(width: 8),
                Text(tab.label),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _onTierBadgeTap(SubscriptionTier tier) {
    if (tier == SubscriptionTier.ultra) {
      // Show tier benefits dialog
      _showTierBenefitsDialog();
    } else {
      // Navigate to paywall
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PaywallScreen(
            featureName: 'Upgrade',
          ),
        ),
      );
    }
  }

  void _showTierBenefitsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.star,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Ultra Benefits'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBenefitItem('Unlimited history access'),
            _buildBenefitItem('Unlimited daily quizzes'),
            _buildBenefitItem('Unlimited snap & solve'),
            _buildBenefitItem('AI Tutor (Priya Ma\'am)'),
            _buildBenefitItem('Full analytics access'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  _TierDisplay _getTierDisplay(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return _TierDisplay(
          label: 'Free',
          icon: Icons.person_outline,
          backgroundColor: Colors.grey.withAlpha(100),
          borderColor: Colors.grey.withAlpha(150),
        );
      case SubscriptionTier.pro:
        return _TierDisplay(
          label: 'Pro',
          icon: Icons.workspace_premium_outlined,
          backgroundColor: Colors.amber.withAlpha(150),
          borderColor: Colors.amber,
        );
      case SubscriptionTier.ultra:
        return _TierDisplay(
          label: 'Ultra',
          icon: Icons.diamond_outlined,
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderColor: const Color(0xFFFFD700),
        );
    }
  }
}

class _HistoryTab {
  final String label;
  final IconData icon;

  _HistoryTab({
    required this.label,
    required this.icon,
  });
}

class _TierDisplay {
  final String label;
  final IconData icon;
  final Color? backgroundColor;
  final Color borderColor;
  final Gradient? gradient;

  _TierDisplay({
    required this.label,
    required this.icon,
    this.backgroundColor,
    required this.borderColor,
    this.gradient,
  });
}
