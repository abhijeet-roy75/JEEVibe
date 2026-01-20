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
import '../../widgets/buttons/icon_button.dart';
import '../auth/welcome_screen.dart';
import '../subscription/paywall_screen.dart';
import 'profile_edit_screen.dart';

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

  String _getUserName() {
    if (_profile?.firstName != null && _profile!.firstName!.isNotEmpty) {
      return _profile!.firstName!;
    }
    return 'Student';
  }

  Widget _buildHeaderTierBadge() {
    if (_loadingSubscription) {
      return const SizedBox(
        width: 60,
        height: 28,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    final tierEnum = _subscriptionStatus?.subscription.tier ?? SubscriptionTier.free;
    final isFreeTier = tierEnum == SubscriptionTier.free;
    final tierName = isFreeTier ? 'FREE' : tierEnum.name.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFreeTier ? Icons.lock_outline : Icons.auto_awesome,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            tierName,
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToEditProfile() async {
    if (_profile == null) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ProfileEditScreen(profile: _profile!),
      ),
    );

    // If profile was updated, reload the profile data
    if (result == true) {
      setState(() => _isLoading = true);
      await _loadProfile();
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
                // Enhanced Header Section with Greeting and Tier Badge
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: AppColors.ctaGradient,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Back button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: AppIconButton.back(
                              onPressed: () => Navigator.of(context).pop(),
                              color: Colors.white,
                              size: AppIconButtonSize.small,
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
                                  'Profile',
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
                          _buildHeaderTierBadge(),
                        ],
                      ),
                    ),
                  ),
                ),
                // White Content Section
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.xxl,
                      AppSpacing.xxl,
                      AppSpacing.xxl,
                      AppSpacing.xxl + MediaQuery.of(context).viewPadding.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Enhanced Avatar and Name Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundWhite,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: AppColors.borderLight,
                              width: 1,
                            ),
                            boxShadow: AppShadows.card,
                          ),
                          child: Row(
                            children: [
                              // Enhanced Avatar with shadow
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.ctaGradient,
                                  boxShadow: AppShadows.soft,
                                ),
                                child: Center(
                                  child: Text(
                                    (_profile!.firstName?.isNotEmpty ?? false)
                                        ? _profile!.firstName![0].toUpperCase()
                                        : '?',
                                    style: AppTextStyles.headerLarge.copyWith(
                                      fontSize: 32,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
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
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.phone_outlined,
                                          size: 16,
                                          color: AppColors.textMedium,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _profile!.phoneNumber,
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            color: AppColors.textMedium,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Edit Profile Button
                              IconButton(
                                onPressed: () => _navigateToEditProfile(),
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryPurple.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        // Profile Information Section - Grouped Card
                        Text(
                          'JEE Preparation Details',
                          style: AppTextStyles.headerMedium.copyWith(
                            fontSize: 18,
                            color: AppColors.textDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Unified Information Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundWhite,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: AppColors.borderLight,
                              width: 1,
                            ),
                            boxShadow: AppShadows.card,
                          ),
                          child: _buildGroupedProfileFields(),
                        ),

                        const SizedBox(height: AppSpacing.xxl),

                        // Subscription & Plan Section
                        _buildSubscriptionSection(),

                        const SizedBox(height: AppSpacing.xxl),

                        // Sign Out Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            gradient: const LinearGradient(
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
                                borderRadius: BorderRadius.circular(AppRadius.md),
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
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),

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
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGroupedProfileFields() {
    final fields = <Widget>[];
    int fieldCount = 0;

    void addField(IconData icon, String label, String? value) {
      if (value != null && value.isNotEmpty) {
        if (fieldCount > 0) {
          fields.add(const Divider(
            height: 24,
            thickness: 1,
            color: AppColors.borderLight,
          ));
        }
        fields.add(_buildInfoFieldWithIcon(icon, label, value));
        fieldCount++;
      }
    }

    addField(Icons.calendar_today_outlined, 'Target Year', _profile!.targetYear);
    addField(Icons.school_outlined, 'Target Exam', _profile!.targetExam);
    addField(Icons.email_outlined, 'Email', _profile!.email);
    addField(Icons.location_on_outlined, 'State', _profile!.state);
    addField(Icons.workspace_premium_outlined, 'Dream Branch', _profile!.dreamBranch);
    if (_profile!.studySetup.isNotEmpty) {
      addField(Icons.book_outlined, 'Study Setup', _profile!.studySetup.join(', '));
    }

    if (fields.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            'No profile information available',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMedium,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields,
    );
  }

  Widget _buildInfoFieldWithIcon(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.primaryPurple,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMedium,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
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
        ),
      ],
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
        const SizedBox(height: AppSpacing.lg),

        // Tier Badge Card
        _buildTierBadge(),

        const SizedBox(height: AppSpacing.lg),

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
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderLight, width: 1),
          boxShadow: AppShadows.soft,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: badgeGradient,
        color: badgeGradient == null ? AppColors.backgroundWhite : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: badgeGradient == null
            ? Border.all(color: AppColors.borderLight, width: 1)
            : null,
        boxShadow: badgeGradient != null ? AppShadows.card : AppShadows.soft,
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
          const SizedBox(width: AppSpacing.md),
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

  Widget _buildSubscriptionCTA() {
    final tierEnum = _subscriptionStatus?.subscription.tier ?? SubscriptionTier.free;
    final isFreeTier = tierEnum == SubscriptionTier.free;

    if (isFreeTier) {
      // Show upgrade button for free tier
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
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
              borderRadius: BorderRadius.circular(AppRadius.md),
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
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.primaryPurple,
          width: 1.5,
        ),
        boxShadow: AppShadows.soft,
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
            borderRadius: BorderRadius.circular(AppRadius.md),
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
