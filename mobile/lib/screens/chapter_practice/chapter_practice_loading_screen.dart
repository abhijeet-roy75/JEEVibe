/// Chapter Practice Loading Screen
/// Generates practice session and navigates to question screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/subscription_models.dart';
import '../../providers/chapter_practice_provider.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/subscription_service.dart';
import '../../services/offline/connectivity_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/priya_avatar.dart';
import '../../utils/error_handler.dart';
import '../subscription/paywall_screen.dart';
import 'chapter_practice_question_screen.dart';

class ChapterPracticeLoadingScreen extends StatefulWidget {
  final String chapterKey;
  final String chapterName;
  final String subject;

  const ChapterPracticeLoadingScreen({
    super.key,
    required this.chapterKey,
    required this.chapterName,
    required this.subject,
  });

  @override
  State<ChapterPracticeLoadingScreen> createState() =>
      _ChapterPracticeLoadingScreenState();
}

class _ChapterPracticeLoadingScreenState
    extends State<ChapterPracticeLoadingScreen>
    with SingleTickerProviderStateMixin {
  String? _error;
  bool _isLoading = true;
  bool _isOffline = false;
  late AnimationController _avatarAnimationController;

  @override
  void initState() {
    super.initState();

    // Avatar pulsing animation
    _avatarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startPractice();
  }

  @override
  void dispose() {
    _avatarAnimationController.dispose();
    super.dispose();
  }

  Future<void> _startPractice() async {
    try {
      // Check connectivity first
      final connectivityService = ConnectivityService();
      final isOnline = await connectivityService.checkRealConnectivity();

      if (!isOnline) {
        if (mounted) {
          setState(() {
            _isOffline = true;
            _error = 'No internet connection';
            _isLoading = false;
          });
        }
        return;
      }

      // Get auth token
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();

      if (token == null) {
        if (mounted) {
          setState(() {
            _error = 'Authentication required';
            _isLoading = false;
          });
        }
        return;
      }

      // Check subscription status (Chapter Practice is Pro/Ultra only)
      final subscriptionService = SubscriptionService();
      final canProceed = await subscriptionService.gatekeepFeature(
        context,
        UsageType.chapterPractice,
        'Chapter Practice',
        token,
      );

      if (!canProceed) {
        // Paywall was shown, go back
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      // Start practice session
      final provider =
          Provider.of<ChapterPracticeProvider>(context, listen: false);

      final success = await ErrorHandler.withRetry(
        operation: () => provider.startPractice(widget.chapterKey, token),
        maxRetries: 3,
      );

      if (success && provider.session != null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const ChapterPracticeQuestionScreen(),
            ),
          );
        }
      } else {
        if (mounted) {
          // Check if error is quota-related
          final errorMessage =
              (provider.errorMessage ?? '').toLowerCase();
          if (_isQuotaError(errorMessage)) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const PaywallScreen(
                  limitReachedMessage:
                      'Chapter Practice is a Pro/Ultra feature. Upgrade to access!',
                  featureName: 'Chapter Practice',
                ),
              ),
            );
            return;
          }

          setState(() {
            _error = provider.errorMessage ?? 'Failed to start practice';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // Check if error is quota-related
      final errorMessage = e.toString().toLowerCase();
      if (_isQuotaError(errorMessage)) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const PaywallScreen(
                limitReachedMessage:
                    'Chapter Practice is a Pro/Ultra feature. Upgrade to access!',
                featureName: 'Chapter Practice',
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        final errorMsg = e.toString().toLowerCase();
        final isNetworkError = errorMsg.contains('socketexception') ||
            errorMsg.contains('connection') ||
            errorMsg.contains('network') ||
            errorMsg.contains('timeout') ||
            errorMsg.contains('host');

        setState(() {
          _isOffline = isNetworkError;
          _error = ErrorHandler.getErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  bool _isQuotaError(String errorMessage) {
    return errorMessage.contains('quota') ||
        errorMessage.contains('limit') ||
        errorMessage.contains('exceeded') ||
        errorMessage.contains('upgrade') ||
        errorMessage.contains('pro') ||
        errorMessage.contains('ultra') ||
        errorMessage.contains('not enabled');
  }

  Color _getSubjectColor() {
    switch (widget.subject.toLowerCase()) {
      case 'physics':
        return AppColors.infoBlue;
      case 'chemistry':
        return AppColors.successGreen;
      case 'mathematics':
      case 'math':
        return AppColors.primaryPurple;
      default:
        return AppColors.primaryPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon based on error type
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isOffline ? Icons.wifi_off_rounded : Icons.error_outline,
                    size: 40,
                    color: AppColors.errorRed,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isOffline ? 'You\'re Offline' : 'Something Went Wrong',
                  style: AppTextStyles.headerMedium.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isOffline
                      ? 'Chapter Practice requires an internet connection to start.'
                      : 'We couldn\'t load your practice session. Please try again.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMedium,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Go Back button (primary)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Try Again button (secondary)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _isOffline = false;
                        _isLoading = true;
                      });
                      _startPractice();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryPurple,
                      side: const BorderSide(color: AppColors.primaryPurple),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Priya Ma'am Avatar with pulsing animation
                    AnimatedBuilder(
                      animation: _avatarAnimationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale:
                              1.0 + (_avatarAnimationController.value * 0.05),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(
                                    alpha: 0.3 +
                                        (_avatarAnimationController.value *
                                            0.2),
                                  ),
                                  blurRadius: 40,
                                  spreadRadius: 15,
                                ),
                              ],
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: const PriyaAvatar(size: 120),
                    ),
                    const SizedBox(height: 32),
                    // Chapter info card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          // Subject badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.subject,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Chapter name
                          Text(
                            widget.chapterName,
                            style: AppTextStyles.headerMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Message text
                    Text(
                      'Preparing your practice questions for ${widget.chapterName}. This will help strengthen your understanding!',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    // Loading spinner
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    // Practice mode badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_off_outlined,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'No Timer - Practice at your pace',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
