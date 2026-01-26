/// Daily Quiz Loading Screen
/// Generates quiz and navigates to question screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/session_constants.dart';
import '../models/daily_quiz_question.dart';
import '../models/subscription_models.dart';
import '../providers/daily_quiz_provider.dart';
import '../services/firebase/auth_service.dart';
import '../services/subscription_service.dart';
import '../services/offline/connectivity_service.dart';
import '../services/quiz_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/priya_avatar.dart';
import '../utils/error_handler.dart';
import 'daily_quiz_question_screen.dart';
import 'subscription/paywall_screen.dart';

class DailyQuizLoadingScreen extends StatefulWidget {
  const DailyQuizLoadingScreen({super.key});

  @override
  State<DailyQuizLoadingScreen> createState() => _DailyQuizLoadingScreenState();
}

class _DailyQuizLoadingScreenState extends State<DailyQuizLoadingScreen>
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
    
    _generateQuiz();
  }

  @override
  void dispose() {
    _avatarAnimationController.dispose();
    super.dispose();
  }

  Future<void> _generateQuiz() async {
    try {
      final provider = Provider.of<DailyQuizProvider>(context, listen: false);

      // CRITICAL: Wait for provider to finish restoring any saved state
      // This ensures we don't miss an interrupted quiz that needs to be resumed
      int attempts = 0;
      while (provider.isRestoringState &&
          attempts < SessionTimeouts.maxRestorationAttempts) {
        await Future.delayed(
          Duration(milliseconds: SessionTimeouts.restorationPollIntervalMs),
        );
        attempts++;
        if (!mounted) return;
      }

      // Check if there's a saved quiz state first (MUST check after restoration completes)
      final hasSavedState = await provider.hasSavedState();
      if (hasSavedState) {
        DailyQuiz? quizToResume = provider.currentQuiz;

        // Fallback: If provider doesn't have the quiz but storage does, load directly
        // This handles edge cases where provider restoration failed
        if (quizToResume == null) {
          final storageService = QuizStorageService();
          await storageService.initialize();
          final savedState = await storageService.loadQuizState();
          if (savedState != null) {
            quizToResume = savedState.quiz;
            // Also set it in provider for consistency
            provider.setQuiz(quizToResume);
          }
        }

        if (quizToResume != null) {
          // Resume existing quiz - this is critical for free plan users!
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => DailyQuizQuestionScreen(quiz: quizToResume!),
              ),
            );
          }
          return;
        }
      }

      // Check connectivity before generating new quiz
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

      // Safety gate check before generating new quiz
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();
      if (token != null) {
        final subscriptionService = SubscriptionService();
        final canProceed = await subscriptionService.gatekeepFeature(
          context,
          UsageType.dailyQuiz,
          'Daily Quiz',
          token,
        );

        if (!canProceed) {
          // Paywall was shown, go back
          if (mounted) {
            Navigator.of(context).pop();
          }
          return;
        }
      }

      // Generate new quiz
      final quiz = await ErrorHandler.withRetry(
        operation: () => provider.generateQuiz(),
        maxRetries: 3,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DailyQuizQuestionScreen(quiz: quiz),
          ),
        );
      }
    } catch (e, stackTrace) {
      // Check if error is quota-related - redirect to paywall instead of showing error
      final errorMessage = e.toString().toLowerCase();
      if (_isQuotaError(errorMessage)) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const PaywallScreen(
                limitReachedMessage: 'You\'ve used your free daily quiz. Upgrade for more!',
                featureName: 'Daily Quiz',
              ),
            ),
          );
        }
        return;
      }

      // Report non-quota errors to Crashlytics
      ErrorHandler.reportError(
        e,
        stackTrace,
        reason: 'Daily Quiz generation failed',
      );

      if (mounted) {
        // Check if error is network-related
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

  /// Check if error message indicates quota exceeded
  bool _isQuotaError(String errorMessage) {
    return errorMessage.contains('quota') ||
        errorMessage.contains('limit') ||
        errorMessage.contains('exceeded') ||
        errorMessage.contains('free daily') ||
        errorMessage.contains('upgrade to pro');
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
                      ? 'Daily Quiz requires an internet connection to generate questions.'
                      : 'We couldn\'t load your quiz. Please try again.',
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
                      _generateQuiz();
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
          // Purple to pink gradient background matching assessment header
          gradient: LinearGradient(
            colors: [Color(0xFF9333EA), Color(0xFFEC4899)], // Purple to pink
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
                          scale: 1.0 + (_avatarAnimationController.value * 0.05),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(
                                    alpha: 0.3 + (_avatarAnimationController.value * 0.2),
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
                    const SizedBox(height: 40),
                    // Message text (white for visibility on gradient)
                    Text(
                      'I am preparing your personalized daily quiz. This will just take a moment.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.95), // White text on gradient
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
                    // Purple heart
                    const Text(
                      '💜',
                      style: TextStyle(fontSize: 24),
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

