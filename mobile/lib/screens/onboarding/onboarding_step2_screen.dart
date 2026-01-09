import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../constants/profile_constants.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/buttons/icon_button.dart';
import '../../services/firebase/firestore_user_service.dart';
import '../../models/user_profile.dart';
import '../welcome_carousel_screen.dart';

/// Simplified Onboarding - Screen 2
///
/// Collects optional information:
/// - Email (optional)
/// - Your State (optional)
/// - Exam Type (optional) - "JEE Main" or "JEE Main + Advanced"
/// - Dream Branch (optional)
/// - Current Study Setup (optional, multi-select)
///
/// All fields are optional, user can skip to continue.
class OnboardingStep2Screen extends StatefulWidget {
  final Map<String, dynamic> step1Data;

  const OnboardingStep2Screen({
    super.key,
    required this.step1Data,
  });

  @override
  State<OnboardingStep2Screen> createState() => _OnboardingStep2ScreenState();
}

class _OnboardingStep2ScreenState extends State<OnboardingStep2Screen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();

  String? _email;
  String? _state;
  String? _examType;
  String? _dreamBranch;
  final Set<String> _studySetup = {};

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    // Save form state to capture current values
    _formKey.currentState?.save();

    // Validate email if provided (but don't block save if invalid - just exclude it)
    String? validEmail;
    if (_email != null && _email!.isNotEmpty) {
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (emailRegex.hasMatch(_email!)) {
        validEmail = _email;
      }
      // If email is invalid, we'll just exclude it (user can fix later)
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final userId = user.uid;
      final now = DateTime.now();

      // Create UserProfile object from collected data
      final profile = UserProfile(
        uid: userId,
        phoneNumber: widget.step1Data['phoneNumber'] ?? '',
        profileCompleted: true,
        // Screen 1 data (required)
        firstName: widget.step1Data['firstName'],
        lastName: widget.step1Data['lastName'],
        targetYear: widget.step1Data['targetYear'],
        // Screen 2 data (all optional)
        email: validEmail,
        state: _state,
        targetExam: _examType,
        dreamBranch: _dreamBranch,
        studySetup: _studySetup.toList(),
        // Metadata
        createdAt: now,
        lastActive: now,
      );

      // Save profile using backend API (ensures proper cache handling)
      final firestoreService = Provider.of<FirestoreUserService>(context, listen: false);
      await firestoreService.saveUserProfile(profile);

      if (!mounted) return;

      // Navigate to Welcome Carousel (3-slide feature introduction)
      // After onboarding, show the welcome carousel before going to home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const WelcomeCarouselScreen(),
        ),
        (route) => false, // Remove all previous routes
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: ${e.toString()}'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  void _skip() {
    // Skip to save profile without optional fields
    _saveProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: Column(
        children: [
          // Compact Gradient Header Section
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.ctaGradient,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    // Back button
                    AppIconButton.back(
                      onPressed: () => Navigator.of(context).pop(),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    // Wave emoji + Title inline
                    const Text(
                      '✨',
                      style: TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Tell Us More",
                        style: AppTextStyles.headerLarge.copyWith(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Progress indicator dots
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 20,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // White Content Section - Everything scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description moved here
                    Text(
                      'Optional - helps us personalize better (you can skip)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMedium,
                      ),
                    ),

                    const SizedBox(height: 24),

                      // Email (optional)
                      Row(
                        children: [
                          Text(
                            'Email',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(Optional)',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textLight,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          // Unfocus keyboard since next fields are dropdowns/selects
                          _emailFocusNode.unfocus();
                        },
                        decoration: InputDecoration(
                          hintText: 'your.email@example.com',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textLight,
                          ),
                          filled: true,
                          fillColor: AppColors.cardWhite,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderGray,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderGray,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryPurple,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.errorRed,
                              width: 1,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        style: AppTextStyles.bodyMedium,
                        validator: (value) {
                          // Only validate if email is provided
                          if (value != null && value.isNotEmpty) {
                            final emailRegex = RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                            );
                            if (!emailRegex.hasMatch(value)) {
                              return 'Please enter a valid email address';
                            }
                          }
                          return null;
                        },
                        onSaved: (value) => _email = value?.trim().isEmpty ?? true ? null : value?.trim(),
                      ),

                      const SizedBox(height: 20),

                      // Your State (optional)
                      Row(
                        children: [
                          Text(
                            'Your State',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(Optional)',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textLight,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _state,
                        decoration: InputDecoration(
                          hintText: 'Select state',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textLight,
                          ),
                          filled: true,
                          fillColor: AppColors.cardWhite,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderGray,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderGray,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryPurple,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.errorRed,
                              width: 1,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        dropdownColor: Colors.white,
                        items: ProfileConstants.states.map((String state) {
                          return DropdownMenuItem<String>(
                            value: state,
                            child: Text(
                              state,
                              style: AppTextStyles.bodyMedium,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _state = value),
                        onSaved: (value) => _state = value,
                      ),

                      const SizedBox(height: 20),

                      // Exam Type (optional)
                      Row(
                        children: [
                          Text(
                            'Exam Type',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(Optional)',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textLight,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: ProfileConstants.examTypes.map((examType) {
                          final isSelected = _examType == examType;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () => setState(() {
                                _examType = isSelected ? null : examType;
                              }),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryPurple.withValues(alpha: 0.1)
                                      : AppColors.cardWhite,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primaryPurple
                                        : AppColors.borderGray,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      color: isSelected
                                          ? AppColors.primaryPurple
                                          : AppColors.textLight,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        examType,
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          color: isSelected
                                              ? AppColors.primaryPurple
                                              : AppColors.textDark,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // Dream Branch (optional)
                      Row(
                        children: [
                          Text(
                            'Dream Branch',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(Optional)',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textLight,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _dreamBranch,
                        decoration: InputDecoration(
                          hintText: 'Select branch',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textLight,
                          ),
                          filled: true,
                          fillColor: AppColors.cardWhite,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderGray,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderGray,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryPurple,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.errorRed,
                              width: 1,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        dropdownColor: Colors.white,
                        items: ProfileConstants.dreamBranches.map((String branch) {
                          return DropdownMenuItem<String>(
                            value: branch,
                            child: Text(
                              branch,
                              style: AppTextStyles.bodyMedium,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _dreamBranch = value),
                        onSaved: (value) => _dreamBranch = value,
                      ),

                      const SizedBox(height: 16),

                      // Current Study Setup (optional, multi-select)
                      Text(
                        'Current Study Setup',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: ProfileConstants.studySetupOptions.map((option) {
                          final isSelected = _studySetup.contains(option);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () => setState(() {
                                if (isSelected) {
                                  _studySetup.remove(option);
                                } else {
                                  _studySetup.add(option);
                                }
                              }),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryPurple.withValues(alpha: 0.1)
                                      : AppColors.cardWhite,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primaryPurple
                                        : AppColors.borderGray,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank,
                                      color: isSelected
                                          ? AppColors.primaryPurple
                                          : AppColors.textLight,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        option,
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          color: isSelected
                                              ? AppColors.primaryPurple
                                              : AppColors.textDark,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 32),

                    // Continue button with gradient (now inside scroll)
                    GradientButton(
                      text: 'Continue',
                      onPressed: _isLoading ? null : _saveProfile,
                      isLoading: _isLoading,
                      size: GradientButtonSize.large,
                    ),

                    const SizedBox(height: 12),

                    // Skip button (now inside scroll)
                    Center(
                      child: AppTextButton(
                        text: 'Skip for now',
                        onPressed: _isLoading ? null : _skip,
                      ),
                    ),

                    const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }
}
