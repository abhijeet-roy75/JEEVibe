import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/profile_constants.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_platform_sizing.dart';
import '../../widgets/buttons/gradient_button.dart';
import 'onboarding_step2_screen.dart';

/// Simplified Onboarding - Screen 1
///
/// Collects essential information:
/// - Your Name (required)
/// - Email (required)
/// - Phone Number (pre-filled from auth, verified)
/// - JEE Target Exam Date (required)
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
  String? _jeeTargetExamDate;
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
              'jeeTargetExamDate': _jeeTargetExamDate,
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
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: PlatformSizing.spacing(12), // 12→9.6px Android
                ),
                child: Row(
                  children: [
                    // Wave emoji + Title inline
                    Text(
                      '👋',
                      style: TextStyle(fontSize: PlatformSizing.fontSize(28)), // 28→24.64px Android
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        "Let's Get to Know You!",
                        style: AppTextStyles.headerLarge.copyWith(
                          fontSize: PlatformSizing.fontSize(20), // 20→17.6px Android
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Progress indicator dots
                    Row(
                      children: [
                        Container(
                          width: PlatformSizing.spacing(20), // 20→16px Android
                          height: PlatformSizing.spacing(4), // 4→4px Android (min)
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(PlatformSizing.radius(2)), // 2→1.6px Android
                          ),
                        ),
                        SizedBox(width: PlatformSizing.spacing(4)), // 4→4px Android (min)
                        Container(
                          width: PlatformSizing.spacing(20), // 20→16px Android
                          height: PlatformSizing.spacing(4), // 4→4px Android (min)
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(PlatformSizing.radius(2)), // 2→1.6px Android
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
              padding: EdgeInsets.all(AppSpacing.xxl),
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

                    SizedBox(height: AppSpacing.xxl),

                      // First Name (required)
                      Text(
                        'First Name',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
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
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.borderGray,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.borderGray,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.primaryPurple,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.errorRed,
                              width: 1,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: PlatformSizing.spacing(14), // 14→11.2px Android
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

                      SizedBox(height: AppSpacing.xxl),

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
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.borderGray,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.borderGray,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.primaryPurple,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.errorRed,
                              width: 1,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: PlatformSizing.spacing(14), // 14→11.2px Android
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

                      SizedBox(height: AppSpacing.xxl),

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
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.borderGray,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.borderGray,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.primaryPurple,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.errorRed,
                              width: 1,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: PlatformSizing.spacing(14), // 14→11.2px Android
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

                      SizedBox(height: AppSpacing.xxl),

                      // Phone Number (verified, read-only)
                      Text(
                        'Phone Number',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: PlatformSizing.spacing(14), // 14→11.2px Android
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppColors.successGreen,
                              size: PlatformSizing.iconSize(20), // 20→17.6px Android
                            ),
                            SizedBox(width: AppSpacing.md),
                            Text(
                              _phoneNumber ?? 'Not available',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textDark,
                              ),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: PlatformSizing.spacing(2), // 2→1.6px Android
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.successGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(PlatformSizing.radius(4)), // 4→3.2px Android
                              ),
                              child: Text(
                                'Verified',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.successGreen,
                                  fontWeight: FontWeight.w600,
                                  fontSize: PlatformSizing.fontSize(12),  // 12px iOS, 10.56px Android (was 11)
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: AppSpacing.xxl),

                      // JEE Target Exam Date (required)
                      Text(
                        'When are you appearing for JEE?',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _jeeTargetExamDate,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Select your target exam date',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textLight,
                          ),
                          filled: true,
                          fillColor: AppColors.cardWhite,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.borderGray,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.borderGray,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.primaryPurple,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.errorRed,
                              width: 1,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: PlatformSizing.spacing(14), // 14→11.2px Android
                          ),
                        ),
                        dropdownColor: Colors.white,
                        items: _getJeeExamOptions().map((option) {
                          return DropdownMenuItem<String>(
                            value: option['value'],
                            child: Text(
                              option['label']!,
                              style: AppTextStyles.bodyMedium,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _jeeTargetExamDate = value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select your JEE target date';
                          }
                          return null;
                        },
                        onSaved: (value) => _jeeTargetExamDate = value,
                      ),

                    SizedBox(height: PlatformSizing.spacing(32)), // 32→25.6px Android

                    // Continue button with gradient (now inside scroll)
                    GradientButton(
                      text: 'Continue',
                      onPressed: _continue,
                      size: GradientButtonSize.large,
                    ),

                    const SizedBox(height: 24),

                    // Bottom safe area padding to prevent Android nav bar covering content
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }

  /// Generates available January and April exam dates
  List<Map<String, String>> _getJeeExamOptions() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    List<Map<String, String>> options = [];

    // April of current year (only if we're before April)
    if (currentMonth <= 3) {
      final monthsAway = 4 - currentMonth;
      options.add({
        'value': '$currentYear-04',
        'label': 'April $currentYear ($monthsAway ${monthsAway == 1 ? 'month' : 'months'} away)',
      });
    }

    // January of next year (always available)
    final nextYear = currentYear + 1;
    final monthsToNextJan = currentMonth == 1 ? 12 : (13 - currentMonth);
    options.add({
      'value': '$nextYear-01',
      'label': 'January $nextYear ($monthsToNextJan months away)',
    });

    // April of next year (always available)
    final monthsToNextApril = ((nextYear - currentYear) * 12) + (4 - currentMonth);
    options.add({
      'value': '$nextYear-04',
      'label': 'April $nextYear ($monthsToNextApril months away)',
    });

    // January of year after next
    final yearAfterNext = currentYear + 2;
    final monthsToNextNextJan = ((yearAfterNext - currentYear) * 12) + (1 - currentMonth);
    options.add({
      'value': '$yearAfterNext-01',
      'label': 'January $yearAfterNext ($monthsToNextNextJan months away)',
    });

    return options;
  }
}
