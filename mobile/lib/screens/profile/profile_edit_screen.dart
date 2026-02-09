import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../constants/profile_constants.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_platform_sizing.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/buttons/icon_button.dart';
import '../../services/firebase/firestore_user_service.dart';
import '../../models/user_profile.dart';
import '../../providers/user_profile_provider.dart';

/// Profile Edit Screen
///
/// Allows users to edit their profile information.
/// Contains all fields from onboarding step 1 and step 2.
/// Phone number is read-only (verified via Firebase Auth).
class ProfileEditScreen extends StatefulWidget {
  final UserProfile profile;

  const ProfileEditScreen({
    super.key,
    required this.profile,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
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
  bool? _isEnrolledInCoaching;
  String? _state;
  String? _dreamBranch;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeFromProfile();
  }

  void _initializeFromProfile() {
    // Pre-fill form with existing profile data
    _firstNameController.text = widget.profile.firstName ?? '';
    _lastNameController.text = widget.profile.lastName ?? '';
    _emailController.text = widget.profile.email ?? '';
    _firstName = widget.profile.firstName;
    _lastName = widget.profile.lastName;
    _email = widget.profile.email;
    _jeeTargetExamDate = widget.profile.jeeTargetExamDate;
    _isEnrolledInCoaching = widget.profile.isEnrolledInCoaching;
    _state = widget.profile.state;
    _dreamBranch = widget.profile.dreamBranch;
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

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    _formKey.currentState?.save();

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create updated UserProfile object
      final updatedProfile = UserProfile(
        uid: user.uid,
        phoneNumber: widget.profile.phoneNumber,
        profileCompleted: true,
        // Screen 1 data (required)
        firstName: _firstName,
        lastName: _lastName,
        email: _email,
        jeeTargetExamDate: _jeeTargetExamDate,
        isEnrolledInCoaching: _isEnrolledInCoaching,
        // Screen 2 data (optional)
        state: _state,
        dreamBranch: _dreamBranch,
        // Preserve original createdAt, update lastActive
        createdAt: widget.profile.createdAt,
        lastActive: DateTime.now(),
      );

      // Save profile using backend API
      final firestoreService = Provider.of<FirestoreUserService>(context, listen: false);
      await firestoreService.saveUserProfile(updatedProfile);

      if (!mounted) return;

      // Update centralized UserProfileProvider so all screens reflect the change
      context.read<UserProfileProvider>().updateProfile(updatedProfile);

      // Show success message and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppColors.successGreen,
        ),
      );

      Navigator.of(context).pop(true); // Return true to indicate profile was updated
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

  InputDecoration _buildInputDecoration({
    required String hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textLight,
      ),
      filled: true,
      fillColor: AppColors.cardWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
        borderSide: BorderSide(
          color: AppColors.borderGray,
          width: PlatformSizing.spacing(1),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
        borderSide: BorderSide(
          color: AppColors.borderGray,
          width: PlatformSizing.spacing(1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
        borderSide: BorderSide(
          color: AppColors.primaryPurple,
          width: PlatformSizing.spacing(2),
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
        borderSide: BorderSide(
          color: AppColors.errorRed,
          width: PlatformSizing.spacing(1),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: PlatformSizing.spacing(16)),
      child: Text(
        title,
        style: AppTextStyles.headerMedium.copyWith(
          fontSize: PlatformSizing.fontSize(16),
          color: AppColors.textDark,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isOptional = false}) {
    return Row(
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isOptional) ...[
          SizedBox(width: PlatformSizing.spacing(6)),
          Text(
            '(Optional)',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textLight,
              fontSize: PlatformSizing.fontSize(12),
            ),
          ),
        ],
      ],
    );
  }

  /// Generate JEE exam date options dynamically based on current date
  List<Map<String, String>> _getJeeExamOptions() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // JEE Main is held in January and April
    final allOptions = <Map<String, String>>[];

    // Determine if current year's exams have passed
    final jan2026Passed = currentYear > 2026 || (currentYear == 2026 && currentMonth > 1);
    final apr2026Passed = currentYear > 2026 || (currentYear == 2026 && currentMonth > 4);

    // Add 2026 options if not passed
    if (!jan2026Passed) {
      allOptions.add({'label': 'January 2026', 'value': '2026-01'});
    }
    if (!apr2026Passed) {
      allOptions.add({'label': 'April 2026', 'value': '2026-04'});
    }

    // Add 2027 and 2028 options (future exams)
    allOptions.addAll([
      {'label': 'January 2027', 'value': '2027-01'},
      {'label': 'April 2027', 'value': '2027-04'},
      {'label': 'January 2028', 'value': '2028-01'},
      {'label': 'April 2028', 'value': '2028-04'},
    ]);

    // If user has a current value that's not in the list (e.g., past date), add it at the beginning
    if (_jeeTargetExamDate != null && _jeeTargetExamDate!.isNotEmpty) {
      final hasCurrentValue = allOptions.any((option) => option['value'] == _jeeTargetExamDate);

      if (!hasCurrentValue) {
        final parts = _jeeTargetExamDate!.split('-');
        if (parts.length == 2) {
          final year = parts[0];
          final month = parts[1];
          final monthName = month == '01' ? 'January' : 'April';
          allOptions.insert(0, {
            'label': '$monthName $year (Selected)',
            'value': _jeeTargetExamDate!,
          });
        }
      }
    }

    return allOptions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.ctaGradient,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: PlatformSizing.spacing(16.0), vertical: PlatformSizing.spacing(12.0)),
                child: Row(
                  children: [
                    // Back button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
                      ),
                      child: AppIconButton.back(
                        onPressed: () => Navigator.of(context).pop(),
                        color: Colors.white,
                        size: AppIconButtonSize.small,
                      ),
                    ),
                    SizedBox(width: PlatformSizing.spacing(12)),
                    const Text(
                      '✏️',
                      style: TextStyle(fontSize: 24),
                    ),
                    SizedBox(width: PlatformSizing.spacing(8)),
                    Expanded(
                      child: Text(
                        "Edit Profile",
                        style: AppTextStyles.headerLarge.copyWith(
                          fontSize: PlatformSizing.fontSize(20),
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(PlatformSizing.spacing(24.0)),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information Section
                    _buildSectionHeader('Basic Information'),

                    // First Name (required)
                    _buildFieldLabel('First Name'),
                    SizedBox(height: PlatformSizing.spacing(8)),
                    TextFormField(
                      controller: _firstNameController,
                      focusNode: _firstNameFocusNode,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_lastNameFocusNode);
                      },
                      decoration: _buildInputDecoration(hintText: 'Enter your first name'),
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

                    SizedBox(height: PlatformSizing.spacing(20)),

                    // Last Name (required)
                    _buildFieldLabel('Last Name'),
                    SizedBox(height: PlatformSizing.spacing(8)),
                    TextFormField(
                      controller: _lastNameController,
                      focusNode: _lastNameFocusNode,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_emailFocusNode);
                      },
                      decoration: _buildInputDecoration(hintText: 'Enter your last name'),
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

                    SizedBox(height: PlatformSizing.spacing(20)),

                    // Email (required)
                    _buildFieldLabel('Email'),
                    SizedBox(height: PlatformSizing.spacing(8)),
                    TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        _emailFocusNode.unfocus();
                      },
                      decoration: _buildInputDecoration(hintText: 'your.email@example.com'),
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

                    SizedBox(height: PlatformSizing.spacing(20)),

                    // Phone Number (read-only)
                    _buildFieldLabel('Phone Number'),
                    SizedBox(height: PlatformSizing.spacing(8)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppColors.successGreen,
                            size: PlatformSizing.iconSize(20),
                          ),
                          SizedBox(width: PlatformSizing.spacing(12)),
                          Text(
                            widget.profile.phoneNumber.isNotEmpty
                                ? widget.profile.phoneNumber
                                : 'Not available',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(width: PlatformSizing.spacing(8)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.successGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(PlatformSizing.radius(4)),
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

                    SizedBox(height: PlatformSizing.spacing(20)),

                    // JEE Target Exam Date (required)
                    _buildFieldLabel('When are you giving JEE?'),
                    SizedBox(height: PlatformSizing.spacing(8)),
                    DropdownButtonFormField<String>(
                      value: _jeeTargetExamDate,
                      isExpanded: true,
                      decoration: _buildInputDecoration(hintText: 'Select your JEE exam date'),
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
                          return 'Please select your JEE exam date';
                        }
                        return null;
                      },
                      onSaved: (value) => _jeeTargetExamDate = value,
                    ),

                    SizedBox(height: PlatformSizing.spacing(20)),

                    // Coaching Enrollment Status (optional)
                    _buildFieldLabel('Do you attend coaching classes?', isOptional: true),
                    SizedBox(height: PlatformSizing.spacing(8)),
                    DropdownButtonFormField<bool>(
                      value: _isEnrolledInCoaching,
                      isExpanded: true,
                      decoration: _buildInputDecoration(hintText: 'Select an option'),
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
                      // No validator - this field is optional
                      onSaved: (value) => _isEnrolledInCoaching = value,
                    ),

                    SizedBox(height: PlatformSizing.spacing(32)),

                    // JEE Preparation Details Section
                    _buildSectionHeader('JEE Preparation Details'),

                    // Your State (optional)
                    _buildFieldLabel('Your State', isOptional: true),
                    SizedBox(height: PlatformSizing.spacing(8)),
                    DropdownButtonFormField<String>(
                      value: _state,
                      isExpanded: true,
                      decoration: _buildInputDecoration(hintText: 'Select state'),
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

                    SizedBox(height: PlatformSizing.spacing(20)),

                    // Dream Branch (optional)
                    _buildFieldLabel('Dream Branch', isOptional: true),
                    SizedBox(height: PlatformSizing.spacing(8)),
                    DropdownButtonFormField<String>(
                      value: _dreamBranch,
                      isExpanded: true,
                      decoration: _buildInputDecoration(hintText: 'Select branch'),
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

                    SizedBox(height: PlatformSizing.spacing(32)),

                    // Save button
                    GradientButton(
                      text: 'Save Changes',
                      onPressed: _isLoading ? null : _saveProfile,
                      isLoading: _isLoading,
                      size: GradientButtonSize.large,
                    ),

                    SizedBox(height: PlatformSizing.spacing(16)),

                    // Cancel button
                    Center(
                      child: AppTextButton(
                        text: 'Cancel',
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      ),
                    ),

                    SizedBox(height: PlatformSizing.spacing(24)),

                    // Bottom safe area padding to prevent Android nav bar covering Cancel button
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
}
