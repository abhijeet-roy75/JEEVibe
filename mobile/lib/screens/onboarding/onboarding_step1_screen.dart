import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/profile_constants.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'onboarding_step2_screen.dart';

/// Simplified Onboarding - Screen 1
///
/// Collects essential information:
/// - Your Name (required)
/// - Phone Number (pre-filled from auth, verified)
/// - Target JEE Year (required)
class OnboardingStep1Screen extends StatefulWidget {
  const OnboardingStep1Screen({super.key});

  @override
  State<OnboardingStep1Screen> createState() => _OnboardingStep1ScreenState();
}

class _OnboardingStep1ScreenState extends State<OnboardingStep1Screen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _fullName;
  String? _targetYear;
  String? _phoneNumber;

  @override
  void initState() {
    super.initState();
    // Pre-fill phone number from Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    _phoneNumber = user?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Parse full name into firstName and lastName
  Map<String, String?> _parseFullName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty || (parts.length == 1 && parts[0].isEmpty)) {
      return {'firstName': null, 'lastName': null};
    }

    if (parts.length == 1) {
      return {'firstName': parts[0], 'lastName': null};
    }

    // First word = firstName, rest = lastName
    final firstName = parts[0];
    final lastName = parts.sublist(1).join(' ');

    return {'firstName': firstName, 'lastName': lastName};
  }

  void _continue() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      final nameParts = _parseFullName(_fullName ?? '');

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OnboardingStep2Screen(
            step1Data: {
              'firstName': nameParts['firstName'],
              'lastName': nameParts['lastName'],
              'phoneNumber': _phoneNumber,
              'targetYear': _targetYear,
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: Column(
        children: [
          // Gradient Header Section
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.ctaGradient,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  children: [
                    // Wave emoji
                    const Text(
                      '👋',
                      style: TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 16),
                    // Title
                    Text(
                      "Let's Get to Know You!",
                      style: AppTextStyles.headerLarge.copyWith(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This helps us personalize your JEE prep journey',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    // Progress indicator dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 24,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
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

          // White Content Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section header
                    Text(
                      'Essential Information',
                      style: AppTextStyles.headerMedium.copyWith(
                        fontSize: 20,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Just the basics to get you started',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textLight,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 28),

                      // Your Name (required)
                      Text(
                        'Your Name',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Enter your full name',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textLight,
                          ),
                          filled: true,
                          fillColor: AppColors.cardWhite,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
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
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                        onSaved: (value) => _fullName = value?.trim(),
                      ),

                      const SizedBox(height: 24),

                      // Phone Number (verified, read-only)
                      Text(
                        'Phone Number',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.successGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _phoneNumber ?? 'Not available',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.successGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Verified',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.successGreen,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Target JEE Year (required)
                      Text(
                        'Target JEE Year',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _targetYear,
                        decoration: InputDecoration(
                          hintText: 'Select year',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textLight,
                          ),
                          filled: true,
                          fillColor: AppColors.cardWhite,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
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
                        items: ProfileConstants.getTargetYears().map((String year) {
                          return DropdownMenuItem<String>(
                            value: year,
                            child: Text(
                              year,
                              style: AppTextStyles.bodyMedium,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _targetYear = value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select your target year';
                          }
                          return null;
                        },
                        onSaved: (value) => _targetYear = value,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Continue button with gradient
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.ctaGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Continue',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
