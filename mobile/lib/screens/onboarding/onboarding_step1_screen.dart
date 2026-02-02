import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/profile_constants.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons/gradient_button.dart';
import 'onboarding_step2_screen.dart';

/// Simplified Onboarding - Screen 1
///
/// Collects essential information:
/// - Your Name (required)
/// - Phone Number (pre-filled from auth, verified)
/// - Coaching Enrollment Status (required)
class OnboardingStep1Screen extends StatefulWidget {
  const OnboardingStep1Screen({super.key});

  @override
  State<OnboardingStep1Screen> createState() => _OnboardingStep1ScreenState();
}

class _OnboardingStep1ScreenState extends State<OnboardingStep1Screen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _firstNameFocusNode = FocusNode();
  final _lastNameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();

  String? _firstName;
  String? _lastName;
  String? _email;
  String? _currentClass;
  bool? _isEnrolledInCoaching;
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _continue() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OnboardingStep2Screen(
            step1Data: {
              'firstName': _firstName,
              'lastName': _lastName,
              'email': _email,
              'phoneNumber': _phoneNumber,
              'currentClass': _currentClass,
              'isEnrolledInCoaching': _isEnrolledInCoaching,
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
                    // Wave emoji + Title inline
                    const Text(
                      '👋',
                      style: TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Let's Get to Know You!",
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 20,
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

          // White Content Section - Everything scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description moved here from header
                    Text(
                      'This helps us personalize your JEE prep journey',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMedium,
                      ),
                    ),

                    const SizedBox(height: 24),

                      // First Name (required)
                      Text(
                        'First Name',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _firstNameController,
                        focusNode: _firstNameFocusNode,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          // Move focus to last name field
                          FocusScope.of(context).requestFocus(_lastNameFocusNode);
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter your first name',
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
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your first name';
                          }
                          if (value.trim().length < 2) {
                            return 'First name must be at least 2 characters';
                          }
                          return null;
                        },
                        onSaved: (value) => _firstName = value?.trim(),
                      ),

                      const SizedBox(height: 24),

                      // Last Name (required)
                      Text(
                        'Last Name',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _lastNameController,
                        focusNode: _lastNameFocusNode,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          // Move focus to email field
                          FocusScope.of(context).requestFocus(_emailFocusNode);
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter your last name',
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
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your last name';
                          }
                          if (value.trim().length < 2) {
                            return 'Last name must be at least 2 characters';
                          }
                          return null;
                        },
                        onSaved: (value) => _lastName = value?.trim(),
                      ),

                      const SizedBox(height: 24),

                      // Email (required)
                      Text(
                        'Email',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
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
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email address';
                          }
                          final emailRegex = RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                          );
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                        onSaved: (value) => _email = value?.trim(),
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

                      // Current Class (required)
                      Text(
                        'Current Class',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _currentClass,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Select your current class',
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
                        items: ProfileConstants.currentClassOptions.map((String classValue) {
                          return DropdownMenuItem<String>(
                            value: classValue,
                            child: Text(
                              classValue == 'Other' ? classValue : 'Class $classValue',
                              style: AppTextStyles.bodyMedium,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _currentClass = value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select your current class';
                          }
                          return null;
                        },
                        onSaved: (value) => _currentClass = value,
                      ),

                      const SizedBox(height: 24),

                      // Coaching Enrollment Status (required)
                      Text(
                        'Do you attend coaching classes?',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<bool>(
                        value: _isEnrolledInCoaching,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Select an option',
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
                        items: const [
                          DropdownMenuItem<bool>(
                            value: true,
                            child: Text('Yes'),
                          ),
                          DropdownMenuItem<bool>(
                            value: false,
                            child: Text('No'),
                          ),
                        ],
                        onChanged: (value) => setState(() => _isEnrolledInCoaching = value),
                        validator: (value) {
                          if (value == null) {
                            return 'Please select an option';
                          }
                          return null;
                        },
                        onSaved: (value) => _isEnrolledInCoaching = value,
                      ),

                    const SizedBox(height: 32),

                    // Continue button with gradient (now inside scroll)
                    GradientButton(
                      text: 'Continue',
                      onPressed: _continue,
                      size: GradientButtonSize.large,
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
