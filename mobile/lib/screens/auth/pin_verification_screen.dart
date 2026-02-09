import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_platform_sizing.dart';
import '../../services/firebase/pin_service.dart';
import 'forgot_pin_screen.dart';

class PinVerificationScreen extends StatefulWidget {
  final Widget? targetScreen;
  final bool isUnlockMode;
  
  const PinVerificationScreen({
    super.key,
    this.targetScreen,
    this.isUnlockMode = false,
  });

  @override
  State<PinVerificationScreen> createState() => _PinVerificationScreenState();
}

class _PinVerificationScreenState extends State<PinVerificationScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Auto-focus and show numeric keypad immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pinFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    // Don't call unfocus() in dispose - widget tree is being torn down
    // The FocusNode should already be unfocused before navigation in _verifyPin
    // Wrap in try-catch to handle any edge cases during disposal
    try {
      _pinFocusNode.dispose();
    } catch (e) {
      // Ignore disposal errors - FocusNode may already be disposed
    }
    // _pinController.dispose(); // Commented out to prevent crash - PinCodeTextField issue
    super.dispose();
  }

  Future<void> _verifyPin(String pin) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pinService = PinService();
      final isValid = await pinService.verifyPin(pin);

      if (!mounted) return;

      if (isValid) {
        // Success - navigate to target screen or pop if unlocking
        // Remove focus before navigation to prevent dispose errors
        if (_pinFocusNode.hasFocus) {
          _pinFocusNode.unfocus();
        }
        FocusScope.of(context).unfocus();
        // Wait longer to ensure FocusNode is fully detached
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!mounted) return;

        if (widget.isUnlockMode) {
          Navigator.of(context).pop(); // Unlock app
        } else if (widget.targetScreen != null) {
          // Use pushAndRemoveUntil to ensure clean navigation
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => widget.targetScreen!),
            (route) => false,
          );
        } else {
          // Fallback if no target screen provided (should not happen in normal flow)
          Navigator.of(context).pop(); 
        }
      } else {
        // Invalid PIN
        setState(() {
          _isLoading = false;
          _errorMessage = 'Incorrect PIN. Please try again.';
          _pinController.clear();
        });
        // Keep keyboard open after error
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _pinFocusNode.requestFocus();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _pinController.clear();
      });
      // Keep keyboard open after error
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _pinFocusNode.requestFocus();
        }
      });
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
                  // Top bar with logo (no back button - PIN required)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: PlatformSizing.spacing(12), // 12→9.6px Android
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo in circle (matching profile pages style)
                        Container(
                          width: PlatformSizing.iconSize(40), // 40→35.2px Android
                          height: PlatformSizing.iconSize(40), // 40→35.2px Android
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
                              padding: EdgeInsets.all(PlatformSizing.spacing(6)), // 6→4.8px Android
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
                      ],
                    ),
                  ),
                  // Title in header
                  Padding(
                    padding: EdgeInsets.only(bottom: PlatformSizing.spacing(32)), // 32→25.6px Android
                    child: Text(
                      'Enter your PIN',
                      style: AppTextStyles.headerLarge.copyWith(
                        fontSize: PlatformSizing.fontSize(28), // 28→24.64px Android
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
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: AppSpacing.xxl),
                  Container(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: AppIconSizes.massive, // 48→43.2px Android
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  SizedBox(height: PlatformSizing.spacing(36)), // 36→28.8px Android
                  Text(
                    'Enter your 4-digit PIN to continue',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium,
                  ),
                  if (_errorMessage != null) ...[
                    SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorBackground,
                        borderRadius: BorderRadius.circular(PlatformSizing.radius(8)), // 8→6.4px Android
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppColors.errorRed,
                            size: PlatformSizing.iconSize(20), // 20→17.6px Android
                          ),
                          SizedBox(width: AppSpacing.sm),
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
                  ],
                  SizedBox(height: PlatformSizing.spacing(48)), // 48→38.4px Android

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: PlatformSizing.spacing(48)), // 48→38.4px Android
                    child: PinCodeTextField(
                      appContext: context,
                      length: 4,
                      obscureText: true,
                      animationType: AnimationType.fade,
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.circle,
                        fieldHeight: PlatformSizing.buttonHeight(56), // 56→48px Android
                        fieldWidth: PlatformSizing.buttonHeight(56), // 56→48px Android
                        activeFillColor: Colors.grey.shade100,
                        inactiveFillColor: Colors.grey.shade100,
                        selectedFillColor: Colors.white,
                        activeColor: AppColors.primaryPurple,
                        inactiveColor: Colors.transparent,
                        selectedColor: AppColors.primaryPurple,
                        borderWidth: 1,
                      ),
                      animationDuration: const Duration(milliseconds: 300),
                      backgroundColor: Colors.transparent,
                      enableActiveFill: true,
                      controller: _pinController,
                      focusNode: _pinFocusNode,
                      keyboardType: TextInputType.number,
                      autoFocus: true,
                      onCompleted: (v) {
                        _verifyPin(v);
                      },
                      onChanged: (value) {
                        // Clear error when user starts typing
                        if (_errorMessage != null) {
                          setState(() {
                            _errorMessage = null;
                          });
                        }
                      },
                    ),
                  ),

                  SizedBox(height: PlatformSizing.spacing(32)), // 32→25.6px Android

                  // Forgot PIN button
                  TextButton(
                    onPressed: () {
                      // Navigate to Forgot PIN flow
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ForgotPinScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMedium,
                      padding: EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                        horizontal: AppSpacing.xxl,
                      ),
                    ),
                    child: Text(
                      'Forgot PIN?',
                      style: AppTextStyles.bodyMedium.copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.textMedium,
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

