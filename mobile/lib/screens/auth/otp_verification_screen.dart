import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../services/firebase/auth_service.dart';
import 'create_pin_screen.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  bool _isLoading = false;
  int _secondsRemaining = 60;
  Timer? _timer;
  String? _currentVerificationId;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startTimer();
    // Auto-focus and show numeric keypad after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _otpFocusNode.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    
    _timer?.cancel();
    // Don't call unfocus() in dispose - widget tree is being torn down
    // Focus is already removed before navigation in _verifyOTP
    // Wrap in try-catch to handle any edge cases during disposal
    // The PinCodeTextField might still be using the FocusNode when dispose is called
    try {
      _otpFocusNode.dispose();
    } catch (e) {
      // Ignore disposal errors - FocusNode may already be disposed or still attached to widget
    }
    // _otpController.dispose(); // Commented out to prevent crash - PinCodeTextField issue
    super.dispose();
  }

  void _startTimer() {
    setState(() => _secondsRemaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  Future<void> _verifyOTP(String otp) async {
    if (_isLoading || _isDisposed || !mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    final authService = Provider.of<AuthService>(context, listen: false);
    
    try {
      await authService.signInWithSMSCode(
        verificationId: _currentVerificationId!,
        smsCode: otp,
      );
      
      if (mounted) {
        // Hide keyboard and remove focus before navigation
        // Check if FocusNode has focus before unfocusing
        try {
          if (_otpFocusNode.hasFocus) {
            _otpFocusNode.unfocus();
          }
        } catch (e) {
          // Ignore if FocusNode is already disposed
        }
        FocusScope.of(context).unfocus();
        // Wait longer to ensure FocusNode is fully detached from widget tree
        await Future.delayed(const Duration(milliseconds: 600));
        
        if (!mounted || _isDisposed) return;

        // Navigate to Create PIN
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const CreatePinScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Invalid OTP. Please try again. ($e)')),
        );
      }
    }
  }

  Future<void> _resendOTP() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    await authService.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resend Failed: ${e.message}')),
        );
      },
      codeSent: (verificationId, resendToken) {
        setState(() => _currentVerificationId = verificationId);
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP Resent!')),
        );
      },
      codeAutoRetrievalTimeout: (_) {},
    );
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
                          // Logo in circle (matching profile pages style)
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
                        'Verification Code',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
              RichText(
                text: TextSpan(
                  text: 'Please enter the code sent to\n',
                  style: AppTextStyles.bodyMedium,
                  children: [
                    TextSpan(
                      text: widget.phoneNumber,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              
              PinCodeTextField(
                appContext: context,
                length: 6,
                obscureText: false,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 56,
                  fieldWidth: 48,
                  activeFillColor: Colors.white,
                  inactiveFillColor: Colors.white,
                  selectedFillColor: Colors.white,
                  activeColor: AppColors.primaryPurple,
                  inactiveColor: AppColors.borderGray,
                  selectedColor: AppColors.primaryPurple,
                  borderWidth: 1,
                ),
                animationDuration: const Duration(milliseconds: 300),
                backgroundColor: Colors.transparent,
                enableActiveFill: true,
                controller: _otpController,
                focusNode: _otpFocusNode,
                keyboardType: TextInputType.number,
                autoFocus: true,
                onCompleted: (v) {
                  // Guard against calling after disposal or during navigation
                  if (!_isDisposed && mounted) {
                    _verifyOTP(v); // Auto-submit
                  }
                },
                onChanged: (value) {
                  // Guard against state updates after disposal
                  if (!_isDisposed && mounted) {
                    // Clear any error when user starts typing
                  }
                },
                beforeTextPaste: (text) {
                  return true;
                },
              ),
              
              const SizedBox(height: 32),
              
              Center(
                child: _secondsRemaining > 0
                    ? Text(
                        'Resend code in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textLight),
                      )
                    : TextButton(
                        onPressed: _resendOTP,
                        child: Text(
                          'Resend Code',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primaryPurple,
                            fontSize: 16,
                          ),
                        ),
                      ),
              ),
              
              const SizedBox(height: 16),
              
              // Edit phone number link
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Edit phone number',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primaryPurple,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
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
                  onPressed: _isLoading 
                    ? null 
                    : () => _verifyOTP(_otpController.text),
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
                        'Verify',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                ),
              ),
                    ],
                  ),
                ),
              ),
          ],
        ),
    );
  }
}
