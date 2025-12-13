import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/profile_constants.dart';
import '../../services/firebase/firestore_user_service.dart';
import '../../models/user_profile.dart';
import '../../services/storage_service.dart';
import '../assessment_intro_screen.dart';
import '../welcome_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class ProfileAdvancedScreen extends StatefulWidget {
  final Map<String, dynamic> basicsData;

  const ProfileAdvancedScreen({
    super.key,
    required this.basicsData,
  });

  @override
  State<ProfileAdvancedScreen> createState() => _ProfileAdvancedScreenState();
}

class _ProfileAdvancedScreenState extends State<ProfileAdvancedScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  String? _schoolName;
  String? _state;
  String? _city;
  String? _studyMode;
  String? _coachingInstitute;
  String? _coachingBranch;
  String? _preferredLanguage;
  
  final List<String> _weakSubjects = []; 

  bool _isLoading = false;

  Future<void> _completeProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      setState(() => _isLoading = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception("No authenticated user found");

        final profile = UserProfile(
          uid: user.uid,
          firstName: widget.basicsData['firstName'],
          lastName: widget.basicsData['lastName'],
          email: widget.basicsData['email'],
          phoneNumber: user.phoneNumber ?? '', 
          dateOfBirth: widget.basicsData['dob'],
          gender: widget.basicsData['gender'],
          currentClass: widget.basicsData['class'],
          targetExam: widget.basicsData['targetExam'],
          targetYear: widget.basicsData['targetYear'],
          schoolName: _schoolName,
          state: _state,
          city: _city,
          studyMode: _studyMode,
          coachingInstitute: _coachingInstitute,
          coachingBranch: _coachingBranch,
          preferredLanguage: _preferredLanguage,
          weakSubjects: _weakSubjects,
          strongSubjects: const [], // Not collected in profile setup
          createdAt: DateTime.now(),
          lastActive: DateTime.now(),
          profileCompleted: true,
        );

        final userService = FirestoreUserService();
        await userService.saveUserProfile(profile);

        if (mounted) {
          // Check if user has seen welcome screens
          final storageService = StorageService();
          final hasSeenWelcome = await storageService.hasSeenWelcome();
          
          if (!hasSeenWelcome) {
            // Show welcome screens for first time
            // WelcomeScreen will handle navigation internally
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const WelcomeScreen(),
              ),
              (route) => false,
            );
          } else {
            // User has already seen welcome screens, go directly to assessment intro
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AssessmentIntroScreen()),
              (route) => false,
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving profile: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: Column(
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
                            color: Colors.white.withOpacity(0.2),
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
                        // Logo in circle (matching home screen style)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
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
                      'Setup Profile',
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
              child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step 2 of 2',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryPurple),
                ),
                const SizedBox(height: 8),
                Text(
                  'Academic Details',
                  style: AppTextStyles.headerLarge,
                ),
                const SizedBox(height: 24),

                // School Name (Optional)
                TextFormField(
                  decoration: _inputDecoration('School Name (Optional)'),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDark),
                  onSaved: (v) => _schoolName = v?.isEmpty ?? true ? null : v,
                ),
                const SizedBox(height: 16),

                // City
                TextFormField(
                  decoration: _inputDecoration('City'),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDark),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  onSaved: (v) => _city = v,
                ),
                const SizedBox(height: 16),

                // State
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: _inputDecoration('State'),
                  dropdownColor: Colors.white,
                  items: ProfileConstants.states.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value, style: AppTextStyles.bodyMedium));
                  }).toList(),
                  onChanged: (v) => setState(() => _state = v),
                  validator: (v) => v == null ? 'Required' : null,
                  onSaved: (v) => _state = v,
                ),
                const SizedBox(height: 16),

                // Coaching Institute
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: _inputDecoration('Coaching Institute (Optional)'),
                  dropdownColor: Colors.white,
                  items: ProfileConstants.coachingInstitutes.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value, style: AppTextStyles.bodyMedium));
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      _coachingInstitute = v;
                      if (v == null || v == 'No Coaching') {
                        _coachingBranch = null;
                      }
                    });
                  },
                  onSaved: (v) => _coachingInstitute = v?.isEmpty ?? true ? null : v,
                ),
                const SizedBox(height: 16),

                // Coaching Branch (shown only if coaching institute selected)
                if (_coachingInstitute != null && _coachingInstitute != 'No Coaching' && _coachingInstitute!.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        decoration: _inputDecoration('Coaching Branch (Optional)'),
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDark),
                        onSaved: (v) => _coachingBranch = v?.isEmpty ?? true ? null : v,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),

                // Study Mode
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: _inputDecoration('Study Mode'),
                  dropdownColor: Colors.white,
                  items: ProfileConstants.studyModes.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value, style: AppTextStyles.bodyMedium));
                  }).toList(),
                  onChanged: (v) => setState(() => _studyMode = v),
                  validator: (v) => v == null ? 'Required' : null,
                  onSaved: (v) => _studyMode = v,
                ),
                const SizedBox(height: 16),

                // Preferred Language
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: _inputDecoration('Preferred Language'),
                  dropdownColor: Colors.white,
                  items: ProfileConstants.languages.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value, style: AppTextStyles.bodyMedium));
                  }).toList(),
                  onChanged: (v) => setState(() => _preferredLanguage = v),
                  validator: (v) => v == null ? 'Required' : null,
                  onSaved: (v) => _preferredLanguage = v,
                ),
                const SizedBox(height: 16),

                // Weak Subjects (Multi-select)
                Text('Subjects you find difficult (Select all that apply)', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: ProfileConstants.subjects.map((subject) {
                     final isSelected = _weakSubjects.contains(subject);
                     return FilterChip(
                       label: Text(subject),
                       selected: isSelected,
                       onSelected: (bool selected) {
                         setState(() {
                           if (selected) {
                             _weakSubjects.add(subject);
                           } else {
                             _weakSubjects.remove(subject);
                           }
                         });
                       },
                       selectedColor: AppColors.primaryPurple.withOpacity(0.2),
                       checkmarkColor: AppColors.primaryPurple,
                       labelStyle: TextStyle(
                         color: isSelected ? AppColors.primaryPurple : AppColors.textDark,
                       ),
                       backgroundColor: Colors.white,
                       shape: RoundedRectangleBorder(
                         side: BorderSide(color: isSelected ? AppColors.primaryPurple : AppColors.borderGray),
                         borderRadius: BorderRadius.circular(20),
                       ),
                     );
                  }).toList(),
                ),

                const SizedBox(height: 32),

                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: _isLoading ? null : AppColors.ctaGradient,
                    color: _isLoading ? Colors.grey : null,
                    boxShadow: _isLoading ? [] : AppShadows.buttonShadow,
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _completeProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading 
                      ? const SizedBox(
                          height: 20, 
                          width: 20, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : Text(
                          'Complete Setup',
                          style: AppTextStyles.labelMedium.copyWith(fontSize: 16, color: Colors.white),
                        ),
                  ),
                ),
              ],
            ),
          ),
                ),
              ),
          ],
        ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textLight),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.errorRed),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
