import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/pin_service.dart';
import '../../utils/auth_error_helper.dart';
import 'otp_verification_screen.dart';

/// Forgot PIN Screen
///
/// Allows users to reset their PIN by re-authenticating with phone number.
///
/// Flow:
/// 1. User enters phone number (pre-filled from current auth, editable)
/// 2. System sends OTP
/// 3. User verifies OTP (reuses OtpVerificationScreen)
/// 4. On success: Clear old PIN, navigate to CreatePinScreen to set new PIN
class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill phone number from current auth
    final user = FirebaseAuth.instance.currentUser;
    if (user?.phoneNumber != null) {
      _phoneController.text = user!.phoneNumber!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final phoneNumber = _phoneController.text.trim();

      // Send OTP
      await authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (rare on most devices)
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);

            if (!mounted) return;

            // Clear old PIN immediately after successful verification
            final pinService = PinService();
            await pinService.clearPin();

            // Navigate to CreatePinScreen (via OTP screen's logic)
            // This case is handled by verificationCompleted callback
          } catch (e) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _errorMessage = 'Auto-verification failed. Please try manual OTP entry.';
            });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          final userFriendlyMessage = AuthErrorHelper.getUserFriendlyMessage(e);
          setState(() {
            _isLoading = false;
            _errorMessage = userFriendlyMessage;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;

          setState(() {
            _isLoading = false;
          });

          // Navigate to OTP verification screen with isForgotPinFlow flag
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ForgotPinOtpVerificationScreen(
                verificationId: verificationId,
                phoneNumber: phoneNumber,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Timeout - user will need to enter OTP manually
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
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
              child: Stack(
                children: [
                  // Main content column
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                    child: Column(
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Title
                        Text(
                          "Reset PIN",
                          style: AppTextStyles.headerLarge.copyWith(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Don't worry! We'll send you an OTP to verify your identity, then you can create a new PIN.",
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  // Absolutely positioned back button
                  Positioned(
                    top: 32,
                    left: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
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

                    // Section header
                    Text(
                      'Phone Number',
                      style: AppTextStyles.headerMedium.copyWith(
                        fontSize: 20,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter the phone number associated with your account',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textLight,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Phone number input
                    Text(
                      'Phone Number',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: '+91 1234567890',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textLight,
                        ),
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: AppColors.textMedium,
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
                          return 'Please enter your phone number';
                        }
                        // Basic phone validation (E.164 format)
                        if (!RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(value.trim())) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.errorRed.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.errorRed,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.errorRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
                children: [
                  // Send OTP button with gradient
                  Container(
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
                      onPressed: _isLoading ? null : _sendOTP,
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
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Send OTP',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.infoBlue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.infoBlue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.infoBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Make sure you have access to this phone number. We\'ll send you a one-time verification code.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }
}

/// Custom OTP Verification Screen for Forgot PIN flow
///
/// Wraps the existing OtpVerificationScreen with forgot-PIN specific logic.
class ForgotPinOtpVerificationScreen extends StatelessWidget {
  final String verificationId;
  final String phoneNumber;

  const ForgotPinOtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    // We'll modify OtpVerificationScreen to accept a flag for forgot PIN flow
    // For now, use the existing screen and handle the flow in the callback
    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation during OTP verification
        // User must complete flow or explicitly cancel
        return false;
      },
      child: OtpVerificationScreen(
        verificationId: verificationId,
        phoneNumber: phoneNumber,
        isForgotPinFlow: true, // NEW parameter we'll add
      ),
    );
  }
}
