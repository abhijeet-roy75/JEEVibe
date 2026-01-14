import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firestore_user_service.dart';
import '../../services/subscription_service.dart';
import '../../providers/offline_provider.dart';
import '../../models/user_profile.dart';
import '../../models/subscription_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../auth/welcome_screen.dart';
import '../subscription/paywall_screen.dart';

class ProfileViewScreen extends StatefulWidget {
  const ProfileViewScreen({super.key});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  UserProfile? _profile;
  bool _isLoading = true;
  String _appVersion = '';
  SubscriptionStatus? _subscriptionStatus;
  bool _loadingSubscription = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAppVersion();
    _loadSubscriptionStatus();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'v${packageInfo.version} (${packageInfo.buildNumber})';
      });
    }
  }

  Future<void> _loadProfile() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final firestore = Provider.of<FirestoreUserService>(context, listen: false);
      if (auth.currentUser != null) {
        final profile = await firestore.getUserProfile(auth.currentUser!.uid);
        if (mounted) {
          setState(() {
            _profile = profile;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final token = await auth.getIdToken();
      if (token != null) {
        final status = await SubscriptionService().fetchStatus(token);
        if (mounted) {
          setState(() {
            _subscriptionStatus = status;
            _loadingSubscription = false;
          });

          // Update OfflineProvider with subscription tier (BUG-001 fix)
          if (status != null) {
            try {
              final offlineProvider = Provider.of<OfflineProvider>(context, listen: false);
              offlineProvider.updateOfflineEnabled(status.limits.offlineEnabled);
            } catch (e) {
              debugPrint('Error updating offline provider: $e');
            }
          }
        }
      } else {
        if (mounted) setState(() => _loadingSubscription = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loadingSubscription = false);
    }
  }

  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Clear offline cached data before signing out (BUG-002 fix)
    try {
      final offlineProvider = Provider.of<OfflineProvider>(context, listen: false);
      await offlineProvider.clearUserData();
    } catch (e) {
      // OfflineProvider might not be available, continue with sign out
      debugPrint('Error clearing offline data: $e');
    }

    // Clear subscription cache
    SubscriptionService().clearCache();

    await authService.signOut();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: _isLoading 
        ? const Scaffold(
            backgroundColor: AppColors.backgroundWhite,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            ),
          )
        : _profile == null
          ? Scaffold(
              backgroundColor: AppColors.backgroundWhite,
              body: Center(
                child: Text(
                  'Profile not found',
                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textLight),
                ),
              ),
            )
          : Column(
              children: [
                // Gradient Header Section - Minimal
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: AppColors.ctaGradient,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Row(
                        children: [
                          // Back button
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 16),
                          // Title
                          Text(
                            'Profile',
                            style: AppTextStyles.headerWhite.copyWith(fontSize: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // White Content Section
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24.0,
                      24.0,
                      24.0,
                      24.0 + MediaQuery.of(context).viewPadding.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar and Name Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.borderLight,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.ctaGradient,
                                ),
                                child: Center(
                                  child: Text(
                                    (_profile!.firstName?.isNotEmpty ?? false)
                                        ? _profile!.firstName![0].toUpperCase()
                                        : '?',
                                    style: AppTextStyles.headerLarge.copyWith(
                                      fontSize: 28,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Name and phone
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_profile!.firstName ?? ''} ${_profile!.lastName ?? ''}'.trim(),
                                      style: AppTextStyles.headerMedium.copyWith(
                                        fontSize: 20,
                                        color: AppColors.textDark,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _profile!.phoneNumber,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textMedium,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Profile Information Section
                        Text(
                          'JEE Preparation Details',
                          style: AppTextStyles.headerMedium.copyWith(
                            fontSize: 18,
                            color: AppColors.textDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Information fields - Only show fields that have values
                        ..._buildProfileFields(),

                        const SizedBox(height: 24),

                        // Subscription & Plan Section
                        _buildSubscriptionSection(),

                        const SizedBox(height: 32),

                        /*
                        // Get API Token Button (for testing)
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryPurple,
                              width: 2,
                            ),
                            boxShadow: AppShadows.buttonShadow,
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const TokenDisplayScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primaryPurple,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.vpn_key, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Get API Token',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    fontSize: 16,
                                    color: AppColors.primaryPurple,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        */
                        
                        // Sign Out Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [AppColors.errorRed, AppColors.errorRedLight],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: AppShadows.buttonShadow,
                          ),
                          child: ElevatedButton(
                            onPressed: _signOut,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.logout, size: 20, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  'Sign Out',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // App Version
                        if (_appVersion.isNotEmpty)
                          Center(
                            child: Text(
                              'JEEVibe $_appVersion',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textLight,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildProfileFields() {
    final fields = <Widget>[];

    void addField(String label, String? value) {
      if (value != null && value.isNotEmpty) {
        if (fields.isNotEmpty) {
          fields.add(const SizedBox(height: 16));
        }
        fields.add(_buildInfoField(label, value));
      }
    }

    addField('Target Year', _profile!.targetYear);
    addField('Target Exam', _profile!.targetExam);
    addField('Email', _profile!.email);
    addField('State', _profile!.state);
    addField('Dream Branch', _profile!.dreamBranch);
    if (_profile!.studySetup.isNotEmpty) {
      addField('Study Setup', _profile!.studySetup.join(', '));
    }

    return fields;
  }

  Widget _buildInfoField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textDark,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Text(
          'Subscription & Plan',
          style: AppTextStyles.headerMedium.copyWith(
            fontSize: 18,
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Tier Badge Card
        _buildTierBadge(),

        const SizedBox(height: 16),

        // Usage Section
        if (!_loadingSubscription && _subscriptionStatus != null) ...[
          _buildUsageSection(),
          const SizedBox(height: 16),
        ],

        // Upgrade or Manage Button
        _buildSubscriptionCTA(),
      ],
    );
  }

  Widget _buildTierBadge() {
    if (_loadingSubscription) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryPurple,
            ),
          ),
        ),
      );
    }

    final tierEnum = _subscriptionStatus?.subscription.tier ?? SubscriptionTier.free;
    final isFreeTier = tierEnum == SubscriptionTier.free;
    final isProTier = tierEnum == SubscriptionTier.pro;
    final isUltraTier = tierEnum == SubscriptionTier.ultra;

    // Determine colors and icon based on tier
    Color badgeColor;
    Color textColor;
    IconData tierIcon;
    String tierLabel;
    Gradient? badgeGradient;

    if (isUltraTier) {
      badgeGradient = const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      textColor = Colors.white;
      tierIcon = Icons.diamond_outlined;
      tierLabel = 'ULTRA PLAN';
      badgeColor = const Color(0xFFFFD700);
    } else if (isProTier) {
      badgeGradient = AppColors.ctaGradient;
      textColor = Colors.white;
      tierIcon = Icons.workspace_premium_rounded;
      tierLabel = 'PRO PLAN';
      badgeColor = AppColors.primaryPurple;
    } else {
      badgeColor = AppColors.textLight;
      textColor = AppColors.textDark;
      tierIcon = Icons.person_outline;
      tierLabel = 'FREE PLAN';
      badgeGradient = null;
    }

    // Check for expiry date
    String? expiryText;
    if (!isFreeTier && _subscriptionStatus != null) {
      final expiresAtStr = _subscriptionStatus!.subscription.expiresAt;
      if (expiresAtStr != null) {
        try {
          final endDate = DateTime.parse(expiresAtStr);
          final daysLeft = endDate.difference(DateTime.now()).inDays;
          if (daysLeft > 0) {
            expiryText = 'Expires in $daysLeft days';
          } else if (daysLeft == 0) {
            expiryText = 'Expires today';
          }
        } catch (_) {
          // Invalid date format, skip expiry text
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: badgeGradient,
        color: badgeGradient == null ? AppColors.backgroundLight : null,
        borderRadius: BorderRadius.circular(12),
        border: badgeGradient == null
            ? Border.all(color: AppColors.borderLight)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: badgeGradient != null
                  ? Colors.white.withValues(alpha: 0.2)
                  : badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              tierIcon,
              color: badgeGradient != null ? Colors.white : badgeColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tierLabel,
                  style: AppTextStyles.headerSmall.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (expiryText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    expiryText,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: textColor.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageSection() {
    final limits = _subscriptionStatus?.limits;
    final usage = _subscriptionStatus?.usage;

    if (limits == null || usage == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Usage",
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          // Snap & Solve usage
          _buildUsageBar(
            icon: Icons.camera_alt_outlined,
            label: 'Snap & Solve',
            used: usage.snapSolve.used,
            limit: limits.snapSolveDaily,
          ),
          const SizedBox(height: 12),
          // Daily Quiz usage
          _buildUsageBar(
            icon: Icons.quiz_outlined,
            label: 'Daily Quizzes',
            used: usage.dailyQuiz.used,
            limit: limits.dailyQuizDaily,
          ),
        ],
      ),
    );
  }

  Widget _buildUsageBar({
    required IconData icon,
    required String label,
    required int used,
    required int limit,
  }) {
    final isUnlimited = limit == -1;
    final progress = isUnlimited ? 0.0 : (used / limit).clamp(0.0, 1.0);

    // Color based on usage
    Color progressColor;
    if (isUnlimited) {
      progressColor = AppColors.successGreen;
    } else if (progress >= 1.0) {
      progressColor = AppColors.errorRed;
    } else if (progress >= 0.8) {
      progressColor = AppColors.warningAmber;
    } else {
      progressColor = AppColors.successGreen;
    }

    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textMedium),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMedium,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    isUnlimited ? 'Unlimited' : '$used/$limit used',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: progressColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: isUnlimited ? 1.0 : progress,
                  backgroundColor: AppColors.borderGray,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionCTA() {
    final tierEnum = _subscriptionStatus?.subscription.tier ?? SubscriptionTier.free;
    final isFreeTier = tierEnum == SubscriptionTier.free;

    if (isFreeTier) {
      // Show upgrade button for free tier
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: AppColors.ctaGradient,
          boxShadow: AppShadows.buttonShadow,
        ),
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PaywallScreen(
                  featureName: 'Pro Features',
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Upgrade to Pro',
                style: AppTextStyles.labelMedium.copyWith(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // For Pro/Ultra - show manage subscription (placeholder for now)
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryPurple,
          width: 1.5,
        ),
      ),
      child: ElevatedButton(
        onPressed: () {
          // TODO: Navigate to subscription management screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription management coming soon'),
              backgroundColor: AppColors.primaryPurple,
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.primaryPurple,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings_outlined, size: 20, color: AppColors.primaryPurple),
            const SizedBox(width: 8),
            Text(
              'Manage Subscription',
              style: AppTextStyles.labelMedium.copyWith(
                fontSize: 16,
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
