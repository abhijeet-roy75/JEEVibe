import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'otp_verification_screen.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/storage_service.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();
  
  String _initialCountry = 'IN'; 
  PhoneNumber _number = PhoneNumber(isoCode: 'IN');
  String? _phoneNumber;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCountryCode();
  }

  Future<void> _loadCountryCode() async {
    final storageService = StorageService();
    final savedCountry = await storageService.getCountryCode();
    
    if (mounted) {
      setState(() {
        _initialCountry = savedCountry;
        _number = PhoneNumber(isoCode: savedCountry);
      });
    }
  }

  Future<void> _sendOTP() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      
      final authService = Provider.of<AuthService>(context, listen: false);
      
      await authService.verifyPhoneNumber(
        phoneNumber: _phoneNumber!,
        verificationCompleted: (credential) async {
           // Auto-verification (rare on this step, usually on OTP step)
           setState(() => _isLoading = false);
        },
        verificationFailed: (e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification Failed: ${e.message}')),
          );
        },
        codeSent: (verificationId, resendToken) {
          setState(() => _isLoading = false);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(
                verificationId: verificationId,
                phoneNumber: _phoneNumber!,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
           // Timeout handling
        },
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
                          // Logo in circle (matching profile pages style)
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
                        'Phone Number',
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
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to JEEVibe! 👋',
                      style: AppTextStyles.headerLarge.copyWith(height: 1.2, fontSize: 24),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enter your mobile number to get started',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textLight),
                    ),
                    const SizedBox(height: 32),
              
              Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.borderGray),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: InternationalPhoneNumberInput(
                    onInputChanged: (PhoneNumber number) {
                      _number = number;
                      _phoneNumber = number.phoneNumber;
                      // Save country code when changed
                      if (number.isoCode != null && number.isoCode != _initialCountry) {
                        _initialCountry = number.isoCode!;
                        StorageService().setCountryCode(_initialCountry);
                      }
                    },
                    selectorConfig: const SelectorConfig(
                      selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                      setSelectorButtonAsPrefixIcon: true,
                      leadingPadding: 12,
                    ),
                    ignoreBlank: false,
                    autoValidateMode: AutovalidateMode.disabled,
                    selectorTextStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    textStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    initialValue: _number,
                    textFieldController: _controller,
                    formatInput: true,
                    keyboardType: TextInputType.phone,
                    inputBorder: InputBorder.none,
                    onSaved: (PhoneNumber number) {
                      _phoneNumber = number.phoneNumber;
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 48), // Spacing instead of Spacer for SingleChildScrollView
              
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: _isLoading ? null : AppColors.ctaGradient,
                  color: _isLoading ? Colors.grey : null,
                  boxShadow: _isLoading ? [] : AppShadows.buttonShadow,
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOTP,
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
                        'Send Code',
                        style: AppTextStyles.labelMedium.copyWith(fontSize: 16, color: Colors.white),
                      ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'By continuing, you agree to our\nTerms of Service and Privacy Policy',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textLight),
                ),
              ),
              const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
          ],
        ),
    );
  }
}
