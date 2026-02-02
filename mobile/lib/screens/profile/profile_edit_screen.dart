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
  String? _currentClass;
  bool? _isEnrolledInCoaching;
  String? _state;
  String? _examType;
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
    _currentClass = widget.profile.currentClass;
    _isEnrolledInCoaching = widget.profile.isEnrolledInCoaching;
    _state = widget.profile.state;
    _examType = widget.profile.targetExam;
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
        currentClass: _currentClass,
        isEnrolledInCoaching: _isEnrolledInCoaching,
        // Screen 2 data (optional)
        state: _state,
        targetExam: _examType,
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: AppTextStyles.headerMedium.copyWith(
          fontSize: 16,
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
          const SizedBox(width: 6),
          Text(
            '(Optional)',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textLight,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
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
                    const SizedBox(width: 12),
                    const Text(
                      '✏️',
                      style: TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Edit Profile",
                        style: AppTextStyles.headerLarge.copyWith(
                          fontSize: 20,
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
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information Section
                    _buildSectionHeader('Basic Information'),

                    // First Name (required)
                    _buildFieldLabel('First Name'),
                    const SizedBox(height: 8),
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

                    const SizedBox(height: 20),

                    // Last Name (required)
                    _buildFieldLabel('Last Name'),
                    const SizedBox(height: 8),
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

                    const SizedBox(height: 20),

                    // Email (required)
                    _buildFieldLabel('Email'),
                    const SizedBox(height: 8),
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

                    const SizedBox(height: 20),

                    // Phone Number (read-only)
                    _buildFieldLabel('Phone Number'),
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
                            widget.profile.phoneNumber.isNotEmpty
                                ? widget.profile.phoneNumber
                                : 'Not available',
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

                    const SizedBox(height: 20),

                    // Current Class (required)
                    _buildFieldLabel('Current Class'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _currentClass,
                      isExpanded: true,
                      decoration: _buildInputDecoration(hintText: 'Select your current class'),
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

                    const SizedBox(height: 20),

                    // Coaching Enrollment Status (required)
                    _buildFieldLabel('Do you attend coaching classes?'),
                    const SizedBox(height: 8),
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
                      validator: (value) {
                        if (value == null) {
                          return 'Please select an option';
                        }
                        return null;
                      },
                      onSaved: (value) => _isEnrolledInCoaching = value,
                    ),

                    const SizedBox(height: 32),

                    // JEE Preparation Details Section
                    _buildSectionHeader('JEE Preparation Details'),

                    // Your State (optional)
                    _buildFieldLabel('Your State', isOptional: true),
                    const SizedBox(height: 8),
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

                    const SizedBox(height: 20),

                    // Exam Type (optional)
                    _buildFieldLabel('Exam Type', isOptional: true),
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

                    const SizedBox(height: 20),

                    // Dream Branch (optional)
                    _buildFieldLabel('Dream Branch', isOptional: true),
                    const SizedBox(height: 8),
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

                    const SizedBox(height: 32),

                    // Save button
                    GradientButton(
                      text: 'Save Changes',
                      onPressed: _isLoading ? null : _saveProfile,
                      isLoading: _isLoading,
                      size: GradientButtonSize.large,
                    ),

                    const SizedBox(height: 16),

                    // Cancel button
                    Center(
                      child: AppTextButton(
                        text: 'Cancel',
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
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
