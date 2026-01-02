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
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: 0.5, // Step 1 of 2
                      backgroundColor: AppColors.cardWhite,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '1/2',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMedium,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        "Let's get started!",
                        style: AppTextStyles.headerLarge.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Help us personalize your learning journey',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textMedium,
                        ),
                      ),

                      const SizedBox(height: 40),

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
                        value: _targetYear,
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

            // Continue button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
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
