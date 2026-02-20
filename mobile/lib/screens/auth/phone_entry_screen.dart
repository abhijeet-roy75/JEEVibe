import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'otp_verification_screen.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/storage_service.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_platform_sizing.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/buttons/icon_button.dart';
import '../../widgets/responsive_layout.dart';

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
  int _remainingOtpRequests = 3;
  bool _isDisposed = false; // Track disposal state for async safety

  @override
  void initState() {
    super.initState();
    _loadCountryCode();
    _loadRemainingOtpRequests();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
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

  Future<void> _loadRemainingOtpRequests() async {
    final storageService = StorageService();
    final remaining = await storageService.getRemainingOtpRequests();

    if (mounted) {
      setState(() {
        _remainingOtpRequests = remaining;
      });
    }
  }

  /// Validate phone number based on country
  /// India: Mobile only (starts with 6, 7, 8, or 9), exactly 10 digits
  /// USA: Standard format, 10 digits
  String? _validatePhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return 'Please enter your phone number';
    }

    // Extract just the digits from the phone number
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Detect country based on country code
    if (digitsOnly.startsWith('91')) {
      // Indian number - validate as mobile only
      String mobileNumber = digitsOnly;
      if (digitsOnly.length == 12) {
        mobileNumber = digitsOnly.substring(2); // Remove '91' prefix
      }

      // Check if it's exactly 10 digits
      if (mobileNumber.length != 10) {
        return 'Mobile number must be 10 digits';
      }

      // Check if it starts with valid mobile prefix (6, 7, 8, or 9)
      final firstDigit = mobileNumber[0];
      if (!['6', '7', '8', '9'].contains(firstDigit)) {
        return 'Please enter a valid mobile number (not landline)';
      }
    } else if (digitsOnly.startsWith('1')) {
      // USA number - validate standard 10-digit format
      String usaNumber = digitsOnly;
      if (digitsOnly.length == 11) {
        usaNumber = digitsOnly.substring(1); // Remove '1' prefix
      }

      // Check if it's exactly 10 digits
      if (usaNumber.length != 10) {
        return 'Phone number must be 10 digits';
      }
    } else {
      // For numbers without country code, check length
      if (digitsOnly.length != 10) {
        return 'Phone number must be 10 digits';
      }

      // If current country is India, validate as mobile
      if (_number.isoCode == 'IN') {
        final firstDigit = digitsOnly[0];
        if (!['6', '7', '8', '9'].contains(firstDigit)) {
          return 'Please enter a valid mobile number (not landline)';
        }
      }
    }

    return null; // Valid
  }

  Future<void> _sendOTP() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Check OTP rate limit before sending
      final storageService = StorageService();
      final canRequest = await storageService.canRequestOtp();

      if (!canRequest) {
        final minutesUntilNext = await storageService.getMinutesUntilNextOtpAllowed();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Too many OTP requests. Please try again in $minutesUntilNext ${minutesUntilNext == 1 ? 'minute' : 'minutes'}.',
            ),
            backgroundColor: AppColors.errorRed,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      final authService = Provider.of<AuthService>(context, listen: false);

      await authService.verifyPhoneNumber(
        phoneNumber: _phoneNumber!,
        verificationCompleted: (credential) async {
           // Auto-verification (rare on this step, usually on OTP step)
           if (!_isDisposed && mounted) {
             setState(() => _isLoading = false);
           }
        },
        verificationFailed: (e) {
          if (!_isDisposed && mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Verification Failed: ${e.message}'),
                backgroundColor: AppColors.errorRed,
              ),
            );
          }
        },
        codeSent: (verificationId, resendToken) async {
          if (_isDisposed) return;

          // Record successful OTP request
          await storageService.recordOtpRequest();

          // Update remaining requests count
          await _loadRemainingOtpRequests();

          if (!_isDisposed && mounted) {
            setState(() => _isLoading = false);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => OtpVerificationScreen(
                  verificationId: verificationId,
                  phoneNumber: _phoneNumber!,
                ),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
           // Timeout handling
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopViewport(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: ResponsiveScrollableLayout(
        maxWidth: 480,
        useSafeArea: false, // We'll handle SafeArea manually for the header
        child: Column(
          children: [
            // Gradient Header Section - Compact on desktop
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isDesktop ? 24.0 : 32.0, // Less padding on desktop
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
                        vertical: PlatformSizing.spacing(8), // Reduced from 12
                      ),
                      child: Row(
                        children: [
                          AppIconButton.back(
                            onPressed: () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            },
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
                      padding: EdgeInsets.only(bottom: PlatformSizing.spacing(isDesktop ? 16 : 24)), // Reduced on desktop
                      child: Text(
                        'Phone Number',
                        style: AppTextStyles.headerLarge.copyWith(
                          fontSize: PlatformSizing.fontSize(isDesktop ? 24 : 28), // Smaller on desktop
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
                    Text(
                      'Welcome to JEEVibe! 👋',
                      style: AppTextStyles.headerLarge.copyWith(
                        height: 1.2,
                        fontSize: PlatformSizing.fontSize(24), // 24→21.12px Android
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      'Enter your mobile number to get started',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textLight),
                    ),
                    SizedBox(height: PlatformSizing.spacing(32)), // 32→25.6px Android
              
              Form(
                key: _formKey,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: PlatformSizing.spacing(4), // 4→4px Android (min)
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.borderGray),
                    borderRadius: BorderRadius.circular(AppRadius.md),
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
                    },
                    selectorConfig: const SelectorConfig(
                      selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                      setSelectorButtonAsPrefixIcon: true,
                      leadingPadding: 12,
                      showFlags: true,
                      useEmoji: false,
                    ),
                    countries: const ['IN', 'US'], // Allow India and USA
                    ignoreBlank: false,
                    autoValidateMode: AutovalidateMode.onUserInteraction,
                    selectorTextStyle: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark, // Normal color for selectable country
                    ),
                    textStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    initialValue: _number,
                    textFieldController: _controller,
                    formatInput: true,
                    keyboardType: TextInputType.phone,
                    inputBorder: InputBorder.none,
                    validator: _validatePhoneNumber,
                    onSaved: (PhoneNumber number) {
                      _phoneNumber = number.phoneNumber;
                    },
                  ),
                ),
              ),

              SizedBox(height: AppSpacing.xxl),

              // OTP Rate Limit Info
              if (_remainingOtpRequests < 3)
                Container(
                  padding: EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _remainingOtpRequests > 0
                        ? AppColors.primaryPurple.withValues(alpha: 0.1)
                        : AppColors.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(PlatformSizing.radius(8)), // 8→6.4px Android
                    border: Border.all(
                      color: _remainingOtpRequests > 0
                          ? AppColors.primaryPurple.withValues(alpha: 0.3)
                          : AppColors.errorRed.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _remainingOtpRequests > 0
                            ? Icons.info_outline
                            : Icons.warning_amber_rounded,
                        size: PlatformSizing.iconSize(20), // 20→17.6px Android
                        color: _remainingOtpRequests > 0
                            ? AppColors.primaryPurple
                            : AppColors.errorRed,
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          _remainingOtpRequests > 0
                              ? '$_remainingOtpRequests OTP ${_remainingOtpRequests == 1 ? 'request' : 'requests'} remaining this hour'
                              : 'Rate limit reached. Please try again later.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _remainingOtpRequests > 0
                                ? AppColors.primaryPurple
                                : AppColors.errorRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: AppSpacing.xxl),

              GradientButton(
                text: 'Send Code',
                onPressed: _sendOTP,
                isLoading: _isLoading,
                size: GradientButtonSize.large,
              ),
              SizedBox(height: AppSpacing.lg),

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
