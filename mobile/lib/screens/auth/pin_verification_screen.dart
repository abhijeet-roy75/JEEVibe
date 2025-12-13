import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../services/firebase/pin_service.dart';

class PinVerificationScreen extends StatefulWidget {
  final Widget targetScreen;
  
  const PinVerificationScreen({
    super.key,
    required this.targetScreen,
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
    // Auto-focus and show numeric keypad after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _pinFocusNode.requestFocus();
        }
      });
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
        // Success - navigate to target screen
        // Remove focus before navigation to prevent dispose errors
        if (_pinFocusNode.hasFocus) {
          _pinFocusNode.unfocus();
        }
        FocusScope.of(context).unfocus();
        // Wait longer to ensure FocusNode is fully detached
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!mounted) return;

        // Use pushAndRemoveUntil to ensure clean navigation
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => widget.targetScreen),
          (route) => false,
        );
      } else {
        // Invalid PIN
        setState(() {
          _isLoading = false;
          _errorMessage = 'Incorrect PIN. Please try again.';
          _pinController.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _pinController.clear();
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
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                      ],
                    ),
                  ),
                  // Title in header
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32.0),
                    child: Text(
                      'Enter your PIN',
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 48,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'Enter your 4-digit PIN to continue',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.errorBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.errorRed,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
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
                  const SizedBox(height: 48),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48.0),
                    child: PinCodeTextField(
                      appContext: context,
                      length: 4,
                      obscureText: true,
                      animationType: AnimationType.fade,
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.circle,
                        fieldHeight: 56,
                        fieldWidth: 56,
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

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

