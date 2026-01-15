/// Analytics Screen
/// Main screen for student analytics with Overview and Mastery tabs
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_user_service.dart';
import '../services/analytics_service.dart';
import '../services/subscription_service.dart';
import '../models/analytics_data.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/analytics/overview_tab.dart';
import '../widgets/analytics/mastery_tab.dart';
import '../widgets/buttons/gradient_button.dart';
import '../widgets/offline/offline_banner.dart';
import 'subscription/paywall_screen.dart';
import 'ai_tutor_chat_screen.dart';
import '../models/ai_tutor_models.dart';
import '../widgets/priya_avatar.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AnalyticsOverview? _overview;
  UserProfile? _userProfile;
  bool _isLoading = true;
  String? _error;
  String? _authToken;
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _hasFullAnalytics = false; // true for PRO/ULTRA, false for FREE

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();

      if (token == null) {
        setState(() {
          _error = 'Authentication required';
          _isLoading = false;
        });
        return;
      }

      _authToken = token;

      // Load user profile for name
      final firestoreService = Provider.of<FirestoreUserService>(context, listen: false);
      final user = authService.currentUser;
      if (user != null) {
        final profile = await firestoreService.getUserProfile(user.uid);
        if (mounted) {
          _userProfile = profile;
        }
      }

      // Load subscription status to determine analytics access level
      await _subscriptionService.fetchStatus(token);
      final analyticsAccess = _subscriptionService.status?.features.analyticsAccess ?? 'basic';
      _hasFullAnalytics = analyticsAccess == 'full';

      final overview = await AnalyticsService.getOverview(authToken: token);

      if (mounted) {
        setState(() {
          _overview = overview;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _getUserName() {
    return _userProfile?.firstName ?? 'Student';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      floatingActionButton: _buildAiTutorFab(),
      body: Column(
        children: [
          // Offline banner at top
          const OfflineBanner(),
          // Header with gradient
          _buildHeader(),
          // Tab bar
          _buildTabBar(),
          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.ctaGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              // Top row with back button, greeting, and PRO badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  // Centered greeting
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Hi ${_getUserName()}! 👋',
                          style: AppTextStyles.headerWhite.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Historical Analytics',
                          style: AppTextStyles.bodyWhite.copyWith(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  // Tier badge
                  GestureDetector(
                    onTap: _hasFullAnalytics
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PaywallScreen(
                                  featureName: 'Full Analytics',
                                ),
                              ),
                            );
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _hasFullAnalytics ? Icons.auto_awesome : Icons.lock_outline,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _hasFullAnalytics
                                ? (_subscriptionService.currentTier.name.toUpperCase())
                                : 'FREE',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: AppColors.ctaGradient, // Pink-purple gradient per design
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textTertiary, // Light gray per design
          labelStyle: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: AppTextStyles.labelMedium,
          padding: const EdgeInsets.all(4),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Mastery'),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryPurple),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: AppTextStyles.headerMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GradientButton(
                text: 'Retry',
                onPressed: _loadData,
                size: GradientButtonSize.medium,
                width: 120,
              ),
            ],
          ),
        ),
      );
    }

    if (_overview == null || _authToken == null) {
      return Center(
        child: Text(
          'No data available',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        OverviewTab(
          overview: _overview!,
          isBasicView: !_hasFullAnalytics,
        ),
        _hasFullAnalytics
            ? MasteryTab(
                authToken: _authToken!,
                overview: _overview!,
              )
            : _buildLockedMasteryTab(),
      ],
    );
  }

  Widget _buildLockedMasteryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 60),
          // Lock icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.cardLightPurple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.lock_outline,
              color: AppColors.primaryPurple,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Unlock Detailed Mastery',
            style: AppTextStyles.headerMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Upgrade to Pro to see chapter-by-chapter progress, mastery trends over time, and personalized recommendations.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          // Feature list
          _buildLockedFeatureItem(Icons.menu_book, 'Chapter-by-chapter mastery'),
          const SizedBox(height: 12),
          _buildLockedFeatureItem(Icons.trending_up, 'Progress trends over time'),
          const SizedBox(height: 12),
          _buildLockedFeatureItem(Icons.gps_fixed, 'Personalized focus areas'),
          const SizedBox(height: 32),
          // Upgrade button
          GradientButton(
            text: 'Upgrade to Pro',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PaywallScreen(
                    featureName: 'Full Analytics',
                  ),
                ),
              );
            },
            size: GradientButtonSize.large,
          ),
        ],
      ),
    );
  }

  Widget _buildLockedFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.cardLightGreen,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.success, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Build the AI Tutor FAB (Ultra tier only)
  Widget? _buildAiTutorFab() {
    final subscriptionService = SubscriptionService();
    final hasAiTutorAccess = subscriptionService.status?.limits.aiTutorEnabled ?? false;
    if (!hasAiTutorAccess) return null;

    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AiTutorChatScreen(
              injectContext: TutorContext(
                type: TutorContextType.analytics,
                title: 'My Progress',
              ),
            ),
          ),
        );
      },
      backgroundColor: AppColors.primary,
      icon: const PriyaAvatar(size: 24, showShadow: false),
      label: const Text(
        'Ask Priya Ma\'am',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

}
