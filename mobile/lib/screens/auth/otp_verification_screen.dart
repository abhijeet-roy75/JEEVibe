import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firestore_user_service.dart';
import '../../services/firebase/pin_service.dart';
import 'create_pin_screen.dart';
import 'pin_verification_screen.dart';
import '../main_navigation_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_platform_sizing.dart';
import '../../utils/auth_error_helper.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/buttons/icon_button.dart';
import '../../widgets/responsive_layout.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final bool isForgotPinFlow;

  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.isForgotPinFlow = false,
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
  String? _errorMessage;
  String? _errorSuggestion;
  bool _isClearingProgrammatically = false;

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
    final firestoreService = Provider.of<FirestoreUserService>(context, listen: false);
    final pinService = PinService();

    try {
      final userCredential = await authService.signInWithSMSCode(
        verificationId: _currentVerificationId!,
        smsCode: otp,
      );

      if (mounted) {
        // Hide keyboard and remove focus before awaiting async checks
        try {
          if (_otpFocusNode.hasFocus) {
            _otpFocusNode.unfocus();
          }
        } catch (e) {
          // Ignore
        }
        FocusScope.of(context).unfocus();

        // Create server-side session for single-device enforcement
        // This invalidates any existing session on other devices
        try {
          await authService.createSession();
          debugPrint('Session created successfully');
        } catch (e) {
          // Log but don't block login - session will be created on next API call
          debugPrint('Warning: Failed to create session: $e');
        }

        // Smart Login Logic: Check if user already has a profile
        bool hasProfile = false;
        try {
          if (userCredential.user != null) {
            final profile = await firestoreService.getUserProfile(userCredential.user!.uid);
            hasProfile = profile != null;
          }
        } catch (e) {
          debugPrint('Error checking profile: $e');
        }

        if (!mounted || _isDisposed) return;

        // Wait to ensure FocusNode is fully detached
        await Future.delayed(const Duration(milliseconds: 600));

        if (!mounted || _isDisposed) return;

        // Handle Forgot PIN flow
        if (widget.isForgotPinFlow) {
          // Clear old PIN immediately after successful verification (skip on web)
          if (!kIsWeb) {
            await pinService.clearPin();
          }

          if (!mounted) return;

          // Load profile BEFORE navigating (prevents "Hi Student" flash)
          await _loadUserProfile();

          if (!mounted) return;

          // Web: Go directly to home (no PIN needed)
          if (kIsWeb) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
              (route) => false,
            );
            return;
          }

          // Mobile: Navigate to CreatePinScreen to set new PIN
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const CreatePinScreen(
                targetScreen: MainNavigationScreen(),
              ),
            ),
            (route) => false,
          );
          return;
        }

        // Standard login flow
        if (hasProfile) {
          debugPrint('📱 Existing user detected - loading profile...');
          // User exists - Load profile BEFORE navigating (prevents "Hi Student" flash)
          await _loadUserProfile();

          if (!mounted) return;

          // Target screen is always MainNavigationScreen (bottom nav) for existing users
          final targetScreen = const MainNavigationScreen();

          // Web: Skip PIN entirely, go straight to home
          if (kIsWeb) {
            debugPrint('🌐 Web platform detected - skipping PIN, navigating to home...');
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => targetScreen),
              (route) => false,
            );
            return;
          }

          // Mobile: Check PIN status
          debugPrint('🔐 Checking if PIN exists on device...');
          final hasPin = await pinService.pinExists();
          debugPrint('🔐 PIN exists: $hasPin');

          if (!mounted) return;

          if (hasPin) {
             debugPrint('➡️ Navigating to PIN verification screen...');
             // PIN exists - Verify it locally before going Home
             Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => PinVerificationScreen(
                  targetScreen: targetScreen,
                ),
              ),
              (route) => false,
            );
          } else {
             debugPrint('➡️ Navigating to create PIN screen (existing user)...');
             // PIN missing (e.g. new phone) - Create it then go Home
             Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => CreatePinScreen(
                  targetScreen: targetScreen,
                ),
              ),
              (route) => false,
            );
          }
        } else {
          // New User
          // Web: Skip PIN entirely, go straight to onboarding
          if (kIsWeb) {
            debugPrint('🌐 New user on web - skipping PIN, navigating to onboarding...');
            // Note: CreatePinScreen handles routing to onboarding for new users
            // But on web, we skip PIN entirely, so we need to import OnboardingStep1Screen
            // For now, use CreatePinScreen which will detect and route appropriately
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const CreatePinScreen()),
              (route) => false,
            );
            return;
          }

          debugPrint('➡️ Navigating to create PIN screen (new user)...');
          // Mobile: Standard flow - Create PIN -> Profile Setup
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const CreatePinScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final userFriendlyMessage = AuthErrorHelper.getUserFriendlyMessage(e);
        final suggestion = AuthErrorHelper.getActionableSuggestion(e);

        setState(() {
          _isLoading = false;
          _errorMessage = userFriendlyMessage;
          _errorSuggestion = suggestion;
        });

        // Clear OTP fields on error to allow retry
        _isClearingProgrammatically = true;
        _otpController.clear();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _isClearingProgrammatically = false;
          }
        });
      }
    }
  }

  /// Load user profile into UserProfileProvider before navigation
  /// This prevents "Hi Student" flash by ensuring profile is ready
  Future<void> _loadUserProfile() async {
    try {
      debugPrint('🔄 Loading user profile...');
      final userProfileProvider = Provider.of<UserProfileProvider>(context, listen: false);

      // Add timeout to prevent indefinite hanging
      await userProfileProvider.loadProfile().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ Profile load timed out after 10 seconds');
          throw TimeoutException('Profile load timed out');
        },
      );

      debugPrint('✅ Profile loaded successfully: ${userProfileProvider.firstName}');
    } catch (e) {
      debugPrint('⚠️ Failed to load profile: $e');
      // Don't block navigation on profile load failure
    }
  }

  Future<void> _resendOTP() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    await authService.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        final userFriendlyMessage = AuthErrorHelper.getUserFriendlyMessage(e);
        final suggestion = AuthErrorHelper.getActionableSuggestion(e);
        
        if (mounted) {
          setState(() {
            _errorMessage = userFriendlyMessage;
            _errorSuggestion = suggestion;
          });
        }
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
    final isDesktop = isDesktopViewport(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: ResponsiveScrollableLayout(
        maxWidth: 480,
        useSafeArea: false,
        child: Column(
          children: [
            // Gradient Header Section - Compact on desktop
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isDesktop ? 24.0 : 32.0,
              ),
              decoration: const BoxDecoration(
                gradient: AppColors.ctaGradient,
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Top bar with back button and logo
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: PlatformSizing.spacing(8),
                      ),
                      child: Row(
                        children: [
                          AppIconButton.back(
                            onPressed: () => Navigator.of(context).pop(),
                            color: Colors.white,
                          ),
                          const Spacer(),
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
                          const Spacer(),
                          // Spacer to balance the back button
                          SizedBox(width: PlatformSizing.spacing(48)), // 48→38.4px Android
                        ],
                      ),
                    ),
                    // Title in header
                    Padding(
                      padding: EdgeInsets.only(bottom: PlatformSizing.spacing(isDesktop ? 16 : 24)),
                      child: Text(
                        'Verification Code',
                        style: AppTextStyles.headerLarge.copyWith(
                          fontSize: PlatformSizing.fontSize(isDesktop ? 24 : 28),
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
            Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: AppSpacing.md),
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
              SizedBox(height: PlatformSizing.spacing(48)), // 48→38.4px Android

              PinCodeTextField(
                appContext: context,
                length: 6,
                obscureText: false,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  fieldHeight: PlatformSizing.buttonHeight(56), // 56→48px Android (CRITICAL)
                  fieldWidth: PlatformSizing.buttonHeight(48), // 48→44px Android (CRITICAL)
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
                    // Clear any error when user starts typing (but not when clearing programmatically)
                    if (_errorMessage != null && !_isClearingProgrammatically && value.isNotEmpty) {
                      setState(() {
                        _errorMessage = null;
                        _errorSuggestion = null;
                      });
                    }
                  }
                },
                beforeTextPaste: (text) {
                  return true;
                },
              ),

              SizedBox(height: AppSpacing.xxl),

              // Error message display
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.errorRed.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.errorRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_errorSuggestion != null) ...[
                        SizedBox(height: AppSpacing.sm),
                        Padding(
                          padding: EdgeInsets.only(left: PlatformSizing.spacing(28)), // 28→22.4px Android
                          child: Text(
                            _errorSuggestion!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
              ],

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
                            fontSize: PlatformSizing.fontSize(16), // 16→14.08px Android
                          ),
                        ),
                      ),
              ),

              SizedBox(height: AppSpacing.lg),

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

              SizedBox(height: PlatformSizing.spacing(32)), // 32→25.6px Android

              GradientButton(
                text: 'Verify',
                onPressed: () => _verifyOTP(_otpController.text),
                isLoading: _isLoading,
                size: GradientButtonSize.large,
              ),

              // Bottom safe area padding to prevent Android nav bar covering content
              SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
