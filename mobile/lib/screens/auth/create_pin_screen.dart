import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../onboarding/onboarding_step1_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../services/firebase/pin_service.dart';

class CreatePinScreen extends StatefulWidget {
  final Widget? targetScreen;

  const CreatePinScreen({
    super.key,
    this.targetScreen,
  });

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  
  String _initialPin = '';
  bool _isConfirming = false;
  bool _isDisposed = false;
  
  @override
  void initState() {
    super.initState();
    // Auto-focus and show numeric keypad immediately
    // Use multiple delayed attempts to ensure keyboard stays visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _pinFocusNode.requestFocus();
        // Ensure focus persists with a slight delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_isDisposed && !_pinFocusNode.hasFocus) {
            _pinFocusNode.requestFocus();
          }
        });
      }
    });
  }
  
  void _handlePin(String pin) {
    // Guard against calling after disposal or during navigation
    if (_isDisposed || !mounted) return;
    
    if (_isConfirming) {
      if (pin == _initialPin) {
        _savePinAndContinue(pin);
      } else {
        if (!mounted || _isDisposed) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PINs do not match. Please try again.')),
        );
        _pinController.clear();
        setState(() {
          _isConfirming = false;
          _initialPin = '';
        });
        // Keep keyboard open after error
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_isDisposed) {
            _pinFocusNode.requestFocus();
          }
        });
      }
    } else {
      if (!mounted || _isDisposed) return;
      setState(() {
        _initialPin = pin;
        _isConfirming = true;
        _pinController.clear();
      });
      // Keep keyboard open when transitioning to confirm mode
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_isDisposed) {
          _pinFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    
    // Don't call unfocus() in dispose - widget tree is being torn down
    // Focus is already removed before navigation in _savePinAndContinue
    // Wrap in try-catch to handle any edge cases during disposal
    // The PinCodeTextField might still be using the FocusNode when dispose is called
    try {
      _pinFocusNode.dispose();
    } catch (e) {
      // Ignore disposal errors - FocusNode may already be disposed or still attached to widget
    }
    // _pinController.dispose(); // Commented out to prevent crash - PinCodeTextField issue
    super.dispose();
  }

  Future<void> _savePinAndContinue(String pin) async {
    try {
      final pinService = PinService();
      await pinService.savePin(pin);
      
      // Success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('PIN Set Successfully!')),
      );

      // Hide keyboard and remove focus before navigation
      // Check if FocusNode has focus before unfocusing
      try {
        if (_pinFocusNode.hasFocus) {
          _pinFocusNode.unfocus();
        }
      } catch (e) {
        // Ignore if FocusNode is already disposed
      }
      FocusScope.of(context).unfocus();
      // Wait longer to ensure FocusNode is fully detached from widget tree
      await Future.delayed(const Duration(milliseconds: 600));
      
      if (!mounted || _isDisposed) return;

      // Navigate to Target Screen (if provided) or Onboarding
      if (widget.targetScreen != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => widget.targetScreen!),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const OnboardingStep1Screen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        _pinController.clear();
        setState(() {
          _isConfirming = false;
          _initialPin = '';
        });
        // Keep keyboard open after error
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_isDisposed) {
            _pinFocusNode.requestFocus();
          }
        });
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
                    // Top bar with logo (no back button - cannot go back after OTP verification)
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
                        ],
                      ),
                    ),
                    // Title in header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32.0),
                      child: Text(
                        _isConfirming ? 'Confirm your PIN' : 'Create your PIN',
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
                        color: AppColors.primaryPurple.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        size: 48,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(height: 12),
              Text(
                _isConfirming 
                  ? 'Please re-enter your 4-digit PIN'
                  : 'Set a 4-digit PIN for quick access',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
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
                  autoDismissKeyboard: false, // Prevent keyboard from auto-dismissing
                  enablePinAutofill: false, // Disable autofill to prevent focus issues
                  onCompleted: (v) {
                    // Guard against calling after disposal or during navigation
                    if (!_isDisposed && mounted) {
                      _handlePin(v);
                    }
                  },
                  onChanged: (value) {
                    // Guard against state updates after disposal
                    if (!_isDisposed && mounted) {
                      // Pin changed - handled by onCompleted
                    }
                  },
                ),
              ),

                    const SizedBox(height: 32),
                    // Biometric toggle removed as per plan
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }
}
