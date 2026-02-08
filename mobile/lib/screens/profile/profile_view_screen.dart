import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firestore_user_service.dart';
import '../../services/subscription_service.dart';
import '../../providers/offline_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../services/quiz_storage_service.dart';
import '../../models/user_profile.dart';
import '../../models/subscription_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_header.dart';
import '../auth/welcome_screen.dart';
import '../subscription/paywall_screen.dart';
import 'profile_edit_screen.dart';

class ProfileViewScreen extends StatefulWidget {
  /// When true, the screen is embedded in bottom navigation
  final bool isInBottomNav;

  const ProfileViewScreen({
    super.key,
    this.isInBottomNav = false,
  });

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  String _appVersion = '';
  SubscriptionStatus? _subscriptionStatus;
  bool _loadingSubscription = true;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadSubscriptionStatus();
    _ensureProfileLoaded();
  }

  /// Ensure profile is loaded - fetch if null
  Future<void> _ensureProfileLoaded() async {
    final profileProvider = Provider.of<UserProfileProvider>(context, listen: false);
    if (profileProvider.profile == null) {
      debugPrint('Profile is null, fetching...');
      await profileProvider.fetchProfile();
    }
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'v${packageInfo.version} (${packageInfo.buildNumber})';
      });
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

  String _getUserName(UserProfileProvider profileProvider) {
    return profileProvider.firstName;
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
    final tierInfo = _getTierBadgeInfo(tierEnum);

    return GestureDetector(
      onTap: () => _onTierBadgeTap(tierEnum),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: tierInfo.gradient,
          color: tierInfo.gradient == null ? tierInfo.backgroundColor : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tierInfo.borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tierInfo.icon,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              tierInfo.label,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({String label, IconData icon, Color backgroundColor, Color borderColor, Gradient? gradient}) _getTierBadgeInfo(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return (
          label: 'Free',
          icon: Icons.person_outline,
          backgroundColor: Colors.grey.withAlpha(100),
          borderColor: Colors.grey.withAlpha(150),
          gradient: null,
        );
      case SubscriptionTier.pro:
        return (
          label: 'Pro',
          icon: Icons.workspace_premium_outlined,
          backgroundColor: Colors.amber.withAlpha(150),
          borderColor: Colors.amber,
          gradient: null,
        );
      case SubscriptionTier.ultra:
        return (
          label: 'Ultra',
          icon: Icons.diamond_outlined,
          backgroundColor: const Color(0xFFFFD700),
          borderColor: const Color(0xFFFFD700),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
    }
  }

  void _onTierBadgeTap(SubscriptionTier tier) {
    if (tier == SubscriptionTier.ultra) {
      // Show tier benefits dialog for Ultra users
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
                child: const Icon(Icons.star, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Ultra Benefits'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTierBenefitItem('Unlimited history access'),
              _buildTierBenefitItem('Unlimited daily quizzes'),
              _buildTierBenefitItem('Unlimited snap & solve'),
              _buildTierBenefitItem('AI Tutor (Priya Ma\'am)'),
              _buildTierBenefitItem('Full analytics access'),
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
    } else {
      // Navigate to paywall for Free/Pro users
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

  Widget _buildTierBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 18),
          const SizedBox(width: 12),
          Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AppHeader(
      showGradient: true,
      gradient: AppColors.ctaGradient,
      leading: widget.isInBottomNav
          ? Container(
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
                        Icons.person,
                        color: AppColors.primary,
                        size: 22,
                      );
                    },
                  ),
                ),
              ),
            )
          : Container(
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
                onPressed: () => Navigator.of(context).pop(),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ),
      title: Consumer<UserProfileProvider>(
        builder: (context, profileProvider, child) {
          return Text(
            'Hi ${_getUserName(profileProvider)}! 👋',
            style: AppTextStyles.headerWhite.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          );
        },
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Profile',
          style: AppTextStyles.bodyWhite.copyWith(
            fontSize: 14,
            color: Colors.white.withAlpha(230),
          ),
          textAlign: TextAlign.center,
        ),
      ),
      trailing: _buildHeaderTierBadge(),
    );
  }

  Future<void> _navigateToEditProfile() async {
    final profileProvider = Provider.of<UserProfileProvider>(context, listen: false);
    final profile = profileProvider.profile;

    if (profile == null) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ProfileEditScreen(profile: profile),
      ),
    );

    // If profile was updated, reload the profile data from provider
    if (result == true) {
      profileProvider.refreshProfile();
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

    // Clear quiz state (prevent old quiz from being used by new user)
    try {
      final quizStorageService = QuizStorageService();
      await quizStorageService.clearQuizState();
    } catch (e) {
      debugPrint('Error clearing quiz state: $e');
    }

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
    return Consumer<UserProfileProvider>(
      builder: (context, profileProvider, child) {
        final profile = profileProvider.profile;

        return Scaffold(
          backgroundColor: AppColors.backgroundWhite,
          body: profile == null
            ? Scaffold(
              backgroundColor: AppColors.backgroundWhite,
              body: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.person_off_outlined,
                        size: 64,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Profile not found',
                        style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textLight),
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Container(
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
                                  'Sign Out & Retry',
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
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Column(
              children: [
                // Header using AppHeader for consistency
                _buildHeader(),
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
                                    (profile!.firstName?.isNotEmpty ?? false)
                                        ? profile!.firstName![0].toUpperCase()
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
                                      '${profile!.firstName ?? ''} ${profile!.lastName ?? ''}'.trim(),
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
                                          profile!.phoneNumber,
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
                          child: _buildGroupedProfileFields(profile),
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
      },
    );
  }

  Widget _buildGroupedProfileFields(UserProfile profile) {
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

    // Format JEE target exam date to display "January 2027" or "April 2027"
    String? jeeTargetDisplay;
    if (profile.jeeTargetExamDate != null && profile.jeeTargetExamDate!.isNotEmpty) {
      final parts = profile.jeeTargetExamDate!.split('-');
      if (parts.length == 2) {
        final year = parts[0];
        final month = parts[1];
        final monthName = month == '01' ? 'January' : month == '04' ? 'April' : month;
        jeeTargetDisplay = '$monthName $year';
      }
    }

    // Legacy: Format currentClass to display "Class 11" or "Class 12" (for users who haven't migrated)
    final currentClassDisplay = profile.currentClass != null && profile.currentClass != 'Other'
        ? 'Class ${profile.currentClass}'
        : profile.currentClass;

    // Show JEE Target Exam Date (new field) or fall back to Current Class (legacy)
    if (jeeTargetDisplay != null) {
      addField(Icons.calendar_today_outlined, 'JEE Target Exam', jeeTargetDisplay);
    } else if (currentClassDisplay != null) {
      addField(Icons.class_outlined, 'Current Class', currentClassDisplay);
    }

    addField(Icons.school_outlined, 'Coaching Enrollment', profile.isEnrolledInCoaching == true ? 'Yes' : profile.isEnrolledInCoaching == false ? 'No' : null);
    addField(Icons.email_outlined, 'Email', profile.email);
    addField(Icons.location_on_outlined, 'State', profile.state);
    addField(Icons.workspace_premium_outlined, 'Dream Branch', profile.dreamBranch);

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
