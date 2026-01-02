import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firestore_user_service.dart';
import '../../models/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../auth/welcome_screen.dart';
import '../token_display_screen.dart';

class ProfileViewScreen extends StatefulWidget {
  const ProfileViewScreen({super.key});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  UserProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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

  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
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
                // Gradient Header Section - Full Width
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: AppColors.ctaGradient,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        // Top bar with back button and logo
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                                  onPressed: () => Navigator.of(context).pop(),
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                              const Spacer(),
                              // Logo in circle (matching other screens style)
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Image.asset(
                                      'assets/images/JEEVibeLogo_240.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Spacer to balance the back button
                              const SizedBox(width: 48),
                            ],
                          ),
                        ),
                        // Title in header
                        Padding(
                          padding: const EdgeInsets.only(bottom: 32.0),
                          child: Text(
                            'My Profile',
                            style: AppTextStyles.headerLarge.copyWith(
                              fontSize: 28,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // White Content Section
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar Section
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.ctaGradient,
                            boxShadow: AppShadows.cardShadow,
                          ),
                          child: Center(
                            child: Text(
                              (_profile!.firstName?.isNotEmpty ?? false) 
                                  ? _profile!.firstName![0].toUpperCase() 
                                  : '?',
                              style: AppTextStyles.headerLarge.copyWith(
                                fontSize: 48,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${_profile!.firstName ?? ''} ${_profile!.lastName ?? ''}'.trim(),
                          style: AppTextStyles.headerLarge.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _profile!.phoneNumber,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Profile Information Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppShadows.cardShadow,
                            border: Border.all(
                              color: AppColors.borderLight,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profile Information',
                                style: AppTextStyles.headerMedium.copyWith(
                                  fontSize: 18,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildInfoRow('Target Exam', _profile!.targetExam ?? 'Not set'),
                              const SizedBox(height: 16),
                              _buildInfoRow('Target Year', _profile!.targetYear?.toString() ?? 'Not set'),
                              if (_profile!.state != null && _profile!.state!.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildInfoRow('State', _profile!.state!),
                              ],
                              if (_profile!.dreamBranch != null && _profile!.dreamBranch!.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildInfoRow('Dream Branch', _profile!.dreamBranch!),
                              ],
                              if (_profile!.studySetup.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildInfoRow('Study Setup', _profile!.studySetup.join(', ')),
                              ],
                            ],
                          ),
                        ),
                        
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
