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
import 'package:jeevibe_mobile/theme/app_platform_sizing.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/buttons/secondary_button.dart';
import '../../widgets/quiz_loading_screen.dart';
import '../../utils/error_handler.dart';
import '../subscription/paywall_screen.dart';
import '../daily_quiz_loading_screen.dart';
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
    extends State<ChapterPracticeLoadingScreen> {
  String? _error;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _startPractice();
  }

  Future<void> _startPractice() async {
    try {
      // Get auth token first (needed for both resume check and new session)
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();

      if (token == null) {
        if (mounted) {
          setState(() {
            _error = 'Authentication required';
          });
        }
        return;
      }

      final provider =
          Provider.of<ChapterPracticeProvider>(context, listen: false);

      // CRITICAL: Check for existing session to resume first
      // This ensures students don't lose progress if app was killed mid-session
      final hasActiveSession = await provider.tryResumeSession(token);
      if (hasActiveSession && provider.session != null) {
        // Check if the active session is for the same chapter
        if (provider.session!.chapterKey == widget.chapterKey) {
          // Resume existing session - critical for ensuring completion
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const ChapterPracticeQuestionScreen(),
              ),
            );
          }
          return;
        }
        // Different chapter - will start new session (backend handles this)
      }

      // Check connectivity before starting new session
      final connectivityService = ConnectivityService();
      final isOnline = await connectivityService.checkRealConnectivity();

      if (!isOnline) {
        if (mounted) {
          setState(() {
            _isOffline = true;
            _error = 'No internet connection';
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

      // Start practice session (backend will return existing session if one exists)
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
          final errorMessage =
              (provider.errorMessage ?? '').toLowerCase();

          // Check if daily quiz is required first
          if (_isDailyQuizRequired(errorMessage)) {
            _showDailyQuizRequiredDialog();
            return;
          }

          // Check if error is quota-related
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
          });
        }
      }
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();

      // Check if daily quiz is required first
      if (_isDailyQuizRequired(errorMessage)) {
        if (mounted) {
          _showDailyQuizRequiredDialog();
        }
        return;
      }

      // Check if error is quota-related
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
        final isNetworkError = errorMessage.contains('socketexception') ||
            errorMessage.contains('connection') ||
            errorMessage.contains('network') ||
            errorMessage.contains('timeout') ||
            errorMessage.contains('host');

        setState(() {
          _isOffline = isNetworkError;
          _error = ErrorHandler.getErrorMessage(e);
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

  /// Check if error is DAILY_QUIZ_REQUIRED
  bool _isDailyQuizRequired(String errorMessage) {
    return errorMessage.contains('daily_quiz_required') ||
        errorMessage.contains('daily quiz') ||
        errorMessage.contains('complete at least one');
  }

  /// Show dialog prompting user to complete daily quiz first
  void _showDailyQuizRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.quiz_outlined,
                color: AppColors.primaryPurple,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Daily Quiz Required',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Complete at least one Daily Quiz first to unlock Chapter Practice. '
          'This helps calibrate your skill level for better practice questions.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textMedium,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text(
              'Go Back',
              style: TextStyle(color: AppColors.textMedium),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
              // Navigate to daily quiz loading screen
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DailyQuizLoadingScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Start Daily Quiz'),
          ),
        ],
      ),
    );
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
                  width: PlatformSizing.spacing(80),
                  height: PlatformSizing.spacing(80),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isOffline ? Icons.wifi_off_rounded : Icons.error_outline,
                    size: PlatformSizing.iconSize(40),
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
                PrimaryButton(
                  text: 'Go Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icons.arrow_back,
                ),
                const SizedBox(height: 12),
                // Try Again button (secondary)
                SecondaryButton(
                  text: 'Try Again',
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _isOffline = false;
                    });
                    _startPractice();
                  },
                  icon: Icons.refresh,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return QuizLoadingScreen(
      subject: widget.subject,
      chapterName: widget.chapterName,
      message:
          'Preparing your practice questions for ${widget.chapterName}. This will help strengthen your understanding!',
      badgeText: 'No Timer - Practice at your pace',
      badgeIcon: Icons.timer_off_outlined,
    );
  }
}
