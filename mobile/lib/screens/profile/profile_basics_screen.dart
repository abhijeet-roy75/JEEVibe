import 'package:flutter/material.dart';
import '../../constants/profile_constants.dart';
import 'profile_advanced_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../auth/create_pin_screen.dart';

class ProfileBasicsScreen extends StatefulWidget {
  const ProfileBasicsScreen({super.key});

  @override
  State<ProfileBasicsScreen> createState() => _ProfileBasicsScreenState();
}

class _ProfileBasicsScreenState extends State<ProfileBasicsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  // Form Fields
  String? _firstName;
  String? _lastName;
  String? _email;
  DateTime? _dob;
  String? _gender;
  String? _class;
  String? _targetExam;
  String? _targetYear;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 16)), // Approx 16 yo
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryPurple,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dob) {
      setState(() {
        _dob = picked;
      });
    }
  }

  void _continue() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProfileAdvancedScreen(
            basicsData: {
              'firstName': _firstName,
              'lastName': _lastName,
              'email': _email,
              'dob': _dob,
              'gender': _gender,
              'class': _class,
              'targetExam': _targetExam,
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
                            onPressed: () {
                              // Check if we can pop, otherwise navigate to create PIN screen
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              } else {
                                // If no route to pop, navigate back to PIN creation
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => const CreatePinScreen()),
                                  (route) => false,
                                );
                              }
                            },
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
                  'Step 1 of 2',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryPurple),
                ),
                const SizedBox(height: 8),
                Text(
                  'Basic Details',
                  style: AppTextStyles.headerLarge,
                ),
                const SizedBox(height: 24),
                
                // Name Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: _inputDecoration('First Name'),
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDark),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 2) return 'Min 2 characters';
                          return null;
                        },
                        onSaved: (v) => _firstName = v,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        decoration: _inputDecoration('Last Name'),
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDark),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 2) return 'Min 2 characters';
                          return null;
                        },
                        onSaved: (v) => _lastName = v,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Email (Optional)
                TextFormField(
                  decoration: _inputDecoration('Email (Optional)'),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDark),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(v)) {
                        return 'Invalid email format';
                      }
                    }
                    return null;
                  },
                  onSaved: (v) => _email = v?.isEmpty ?? true ? null : v,
                ),
                const SizedBox(height: 16),
                
                // DOB
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: _inputDecoration('Date of Birth'),
                    child: Text(
                      _dob == null 
                        ? 'Select Date' 
                        : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                      style: _dob == null 
                        ? AppTextStyles.bodyMedium.copyWith(color: AppColors.textLight)
                        : AppTextStyles.bodyMedium.copyWith(color: AppColors.textDark),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Gender
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration('Gender'),
                  dropdownColor: Colors.white,
                  items: ProfileConstants.genders.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value, style: AppTextStyles.bodyMedium));
                  }).toList(),
                  onChanged: (v) => setState(() => _gender = v),
                  validator: (v) => v == null ? 'Required' : null,
                  onSaved: (v) => _gender = v,
                ),
                const SizedBox(height: 16),
                
                // Class
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration('Current Class'),
                  dropdownColor: Colors.white,
                  items: ProfileConstants.currentClasses.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value, style: AppTextStyles.bodyMedium));
                  }).toList(),
                  onChanged: (v) => setState(() => _class = v),
                  validator: (v) => v == null ? 'Required' : null,
                  onSaved: (v) => _class = v,
                ),
                const SizedBox(height: 16),
                
                // Target Exam
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration('Target Exam'),
                  dropdownColor: Colors.white,
                  items: ProfileConstants.targetExams.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value, style: AppTextStyles.bodyMedium));
                  }).toList(),
                  onChanged: (v) => setState(() => _targetExam = v),
                  validator: (v) => v == null ? 'Required' : null,
                  onSaved: (v) => _targetExam = v,
                ),
                const SizedBox(height: 16),
                
                // Target Year
                DropdownButtonFormField<String>(
                  isExpanded: true, // Fix overflow just in case
                  decoration: _inputDecoration('Target Year'),
                  dropdownColor: Colors.white,
                  items: ProfileConstants.getTargetYears().map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value, style: AppTextStyles.bodyMedium));
                  }).toList(),
                  onChanged: (v) => setState(() => _targetYear = v),
                  validator: (v) => v == null ? 'Required' : null,
                  onSaved: (v) => _targetYear = v,
                ),
                
                const SizedBox(height: 32),
                
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: AppColors.ctaGradient,
                    boxShadow: AppShadows.buttonShadow,
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
                    ),
                    child: Text(
                      'Continue',
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
