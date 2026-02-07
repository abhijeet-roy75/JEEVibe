// Assessment Intro Screen - New Home Page/Dashboard
// Shows Initial Assessment prompt, Daily Adaptive Quiz (locked), and Snap & Solve
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:screenshot/screenshot.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_header.dart';
import '../widgets/priya_avatar.dart';
import '../widgets/buttons/gradient_button.dart';
import '../widgets/offline/offline_banner.dart';
import '../widgets/trial_banner.dart';
import '../services/storage_service.dart';
import '../services/firebase/firestore_user_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/api_service.dart';
import '../services/priya_message_service.dart';
import '../services/analytics_service.dart';
import '../models/user_profile.dart';
import '../models/assessment_response.dart';
import '../models/analytics_data.dart';
import '../providers/app_state_provider.dart';
import '../providers/offline_provider.dart';
import '../providers/user_profile_provider.dart';
import 'profile/profile_view_screen.dart';
import 'assessment_instructions_screen.dart';
import 'daily_quiz_loading_screen.dart';
import 'home_screen.dart';
import 'all_solutions_screen.dart';
import 'analytics_screen.dart';
import '../widgets/feedback/feedback_fab.dart';
import '../services/session_tracking_service.dart';
import 'ai_tutor_chat_screen.dart';
import '../services/subscription_service.dart';
import '../models/subscription_models.dart';
import '../services/journey_service.dart';
import '../services/share_service.dart';
import '../widgets/shareable_journey_card.dart';
import 'subscription/paywall_screen.dart';
import 'chapter_practice/chapter_practice_loading_screen.dart';
import 'chapter_practice/chapter_picker_screen.dart';
import 'chapter_list_screen.dart';
import 'mock_test/mock_test_home_screen.dart';
import '../providers/mock_test_provider.dart';

class AssessmentIntroScreen extends StatefulWidget {
  /// When true, the screen is embedded in bottom navigation
  /// Profile icon is replaced with tier badge (profile is in bottom nav)
  final bool isInBottomNav;

  const AssessmentIntroScreen({
    super.key,
    this.isInBottomNav = false,
  });

  @override
  State<AssessmentIntroScreen> createState() => _AssessmentIntroScreenState();
}

class _AssessmentIntroScreenState extends State<AssessmentIntroScreen> {
  UserProfile? _userProfile;
  String _assessmentStatus = 'not_started';
  bool _isLoading = true;
  AssessmentData? _assessmentData;
  int _remainingSnaps = 5;

  // Daily quiz summary data for dynamic Priya messages
  Map<String, dynamic>? _quizSummary;
  PriyaMessage? _priyaMessage;

  // Analytics overview for cumulative progress display
  AnalyticsOverview? _analyticsOverview;

  // Chapter unlock data for JEE countdown timeline
  Map<String, dynamic>? _chapterUnlockData;

  // Screenshot controller for image sharing
  final _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _trackSession();
  }

  Future<void> _trackSession() async {
    try {
      final sessionService = SessionTrackingService();
      await sessionService.initialize();
      await sessionService.trackSession();
    } catch (e) {
      debugPrint('Error tracking session: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      final storageService = StorageService();
      var status = await storageService.getAssessmentStatus();

      final user = FirebaseAuth.instance.currentUser;
      AssessmentData? assessmentData;

      // Get profile from centralized provider (already loaded at startup)
      // This avoids duplicate Firestore calls
      final userProfileProvider = Provider.of<UserProfileProvider>(context, listen: false);
      UserProfile? profile = userProfileProvider.profile;

      // Get remaining snap count from provider
      int remainingSnaps = 5;
      try {
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        // Ensure provider is initialized
        if (!appState.isInitialized) {
          await appState.initialize();
        }
        remainingSnaps = appState.snapsRemaining.clamp(0, 5);
      } catch (e) {
        debugPrint('Error getting snap count: $e');
      }

      // Note: offlineProvider is already initialized at app startup in main.dart
      // No need to initialize again here

      if (user != null) {

        // PERFORMANCE OPTIMIZATION: Parallelize all data fetching
        // Previously: assessment → quiz summary → analytics (sequential: 15-30s)
        // Now: All 3 in parallel (optimized: 5-10s)

        final authService = Provider.of<AuthService>(context, listen: false);
        final token = await authService.getIdToken();

        if (token != null) {
          try {
            // Fetch all data in parallel (including subscription for tier badge and chapter unlock)
            final results = await Future.wait([
              ApiService.getAssessmentResults(
                authToken: token,
                userId: user.uid,
              ).catchError((e) {
                debugPrint('Error fetching assessment results: $e');
                return AssessmentResult(success: false, error: e.toString());
              }),
              ApiService.getDailyQuizSummary(authToken: token).catchError((e) {
                debugPrint('Error fetching quiz summary: $e');
                return <String, dynamic>{};
              }),
              AnalyticsService.getOverview(authToken: token).catchError((e) {
                debugPrint('Error fetching analytics overview: $e');
                return null;
              }),
              ApiService.getUnlockedChapters(authToken: token).catchError((e) {
                debugPrint('Error fetching chapter unlock data: $e');
                return <String, dynamic>{};
              }),
              // Fetch subscription to ensure tier badge shows correct data
              SubscriptionService().fetchStatus(token).catchError((e) {
                debugPrint('Error fetching subscription status: $e');
                return null;
              }),
            ]);

            if (!mounted) return;

            // Process assessment results
            final assessmentResult = results[0] as AssessmentResult;
            if (assessmentResult.success && assessmentResult.data != null) {
              assessmentData = assessmentResult.data;

              // Check if assessment status is 'processing'
              final assessmentStatus = assessmentData?.assessment['status'];

              // Check if we have actual assessment results (questions were answered)
              final hasActualResults = assessmentData != null &&
                  ((assessmentData.subjectAccuracy['physics']?['total'] ?? 0) > 0 ||
                   (assessmentData.subjectAccuracy['chemistry']?['total'] ?? 0) > 0 ||
                   (assessmentData.subjectAccuracy['mathematics']?['total'] ?? 0) > 0);

              // If status is already completed and we have backend data, preserve it
              if (status == 'completed') {
                if (assessmentStatus == 'processing' && !hasActualResults) {
                  debugPrint('Assessment is still processing, resetting local status to in_progress');
                  await storageService.setAssessmentStatus('in_progress');
                  status = 'in_progress';
                } else {
                  debugPrint('Preserving completed status - user has completed assessment');
                }
              }
              // Only sync to completed if conditions met
              else if (status != 'completed' &&
                       assessmentStatus != 'processing' &&
                       hasActualResults) {
                debugPrint('Assessment data found in backend, syncing local status to completed');
                await storageService.setAssessmentStatus('completed');
                status = 'completed';
              }

              debugPrint('Assessment Data - subjectAccuracy: ${assessmentData?.subjectAccuracy}');
            } else if (assessmentResult.success == false && status == 'completed') {
              debugPrint('Backend says assessment not completed, resetting stale local status');
              await storageService.setAssessmentStatus('not_started');
              status = 'not_started';
            }

            // Process quiz summary
            final summary = results[1] as Map<String, dynamic>;
            if (summary.isNotEmpty && mounted) {
              _quizSummary = summary;
              debugPrint('Quiz summary loaded: streak=${summary['streak']?['current_streak']}, today_accuracy=${summary['today_stats']?['accuracy']}');
            }

            // Process analytics overview
            final overview = results[2] as AnalyticsOverview?;
            if (overview != null && mounted) {
              _analyticsOverview = overview;
              debugPrint('Analytics overview loaded: quizzes=${overview.stats.quizzesCompleted}, questions=${overview.stats.questionsSolved}');
            }

            // Process chapter unlock data
            final unlockData = results[3] as Map<String, dynamic>?;
            if (unlockData != null && unlockData.isNotEmpty && mounted) {
              _chapterUnlockData = unlockData;
              debugPrint('Chapter unlock data loaded: month=${unlockData['currentMonth']}, unlocked=${(unlockData['unlockedChapters'] as List?)?.length ?? 0}');
            }
          } catch (e) {
            debugPrint('Error in parallel data fetch: $e');
            // Continue with partial data
          }
        }

        // Note: Subscription status is already fetched at app startup in main.dart
        // Using cached data to avoid duplicate API calls

        // Load mock test templates to get usage data for the card
        if (mounted) {
          final mockTestProvider = context.read<MockTestProvider>();
          mockTestProvider.loadTemplates();
        }
      }

      if (mounted) {
        // Generate dynamic Priya message based on quiz data
        PriyaMessage? priyaMessage;
        if (status == 'completed') {
          priyaMessage = _generatePriyaMessage(profile);
        }

        // Note: Profile is already loaded from UserProfileProvider
        // No need to sync it back - it's already centralized

        setState(() {
          _assessmentStatus = status;
          _userProfile = profile;
          _assessmentData = assessmentData;
          _remainingSnaps = remainingSnaps;
          _priyaMessage = priyaMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading assessment intro data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    return DateFormat('EEEE, MMM d').format(now);
  }

  String _getUserName() {
    // Read from centralized provider (with listen=true so it rebuilds)
    // Provider is pre-populated during app initialization
    final provider = Provider.of<UserProfileProvider>(context);
    return provider.firstName;
  }

  /// Generate dynamic Priya message based on quiz summary data
  PriyaMessage _generatePriyaMessage(UserProfile? profile) {
    final studentName = profile?.firstName ?? 'Student';

    // Extract data from quiz summary
    final streak = _quizSummary?['streak'] as Map<String, dynamic>?;
    final todayStats = _quizSummary?['today_stats'] as Map<String, dynamic>?;

    final currentStreak = streak?['current_streak'] as int?;
    final longestStreak = streak?['longest_streak'] as int?;
    final totalQuizzesCompleted = streak?['total_quizzes_completed'] as int?;
    final totalQuestionsAnswered = streak?['total_questions_answered'] as int?;

    // Get most recent quiz accuracy (0-1 scale)
    // Use last_quiz_accuracy if available, otherwise fall back to average accuracy
    double? lastQuizAccuracy;
    final lastAccuracyValue = todayStats?['last_quiz_accuracy'] ?? todayStats?['accuracy'];
    if (lastAccuracyValue != null && lastAccuracyValue is num) {
      lastQuizAccuracy = lastAccuracyValue.toDouble();
      // Normalize if it's in percentage format (>1)
      if (lastQuizAccuracy > 1) {
        lastQuizAccuracy = lastQuizAccuracy / 100;
      }
    }

    // Get previous quiz accuracy for improvement detection
    double? previousQuizAccuracy;
    final prevAccuracyValue = todayStats?['previous_quiz_accuracy'];
    if (prevAccuracyValue != null && prevAccuracyValue is num) {
      previousQuizAccuracy = prevAccuracyValue.toDouble();
      // Normalize if it's in percentage format (>1)
      if (previousQuizAccuracy > 1) {
        previousQuizAccuracy = previousQuizAccuracy / 100;
      }
    }

    // Only use accuracy if they completed a quiz today
    final quizzesCompletedToday = todayStats?['quizzes_completed'] as int? ?? 0;
    final effectiveLastAccuracy = quizzesCompletedToday > 0 ? lastQuizAccuracy : null;
    final effectivePrevAccuracy = quizzesCompletedToday > 1 ? previousQuizAccuracy : null;

    // Generate message using the service
    return PriyaMessageService.generateMessage(
      studentName: studentName,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalQuizzesCompleted: totalQuizzesCompleted,
      totalQuestionsAnswered: totalQuestionsAnswered,
      lastQuizAccuracy: effectiveLastAccuracy,
      previousQuizAccuracy: effectivePrevAccuracy,
    );
  }

  bool get _isFirstTime => _assessmentStatus == 'not_started';
  bool get _isAssessmentPending => _assessmentStatus == 'in_progress';
  bool get _isAssessmentCompleted => _assessmentStatus == 'completed';

  @override
  Widget build(BuildContext context) {
    // Watch UserProfileProvider so widget rebuilds when profile loads
    context.watch<UserProfileProvider>();

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            // Offline banner (shows when offline)
            const OfflineBanner(),
            // Trial banner (shows when trial is urgent)
            const TrialBanner(),
            // Header with logo, title, profile
            _buildHeader(),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Show results if completed, otherwise show assessment card
                    if (_isAssessmentCompleted && _assessmentData != null) ...[
                      _buildPriyaMessageCard(),
                      const SizedBox(height: 16),
                      _buildResultsCard(),
                    ] else
                      _buildAssessmentCard(),
                    const SizedBox(height: 16),
                    // Daily Adaptive Quiz Card (Locked until assessment complete)
                    _buildDailyPracticeCard(),
                    // Focus Areas card (always show)
                    const SizedBox(height: 16),
                    _buildFocusAreasCard(),
                    const SizedBox(height: 16),
                    // Mock Test Card
                    _buildMockTestCard(),
                    const SizedBox(height: 24),
                    // Snap & Solve Card
                    _buildSnapSolveCard(),
                    const SizedBox(height: 24),
                    // Journey Card (always visible)
                    _buildJourneyCard(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FeedbackFAB(
        currentScreen: 'AssessmentIntroScreen',
      ),
    );
  }

  Widget _buildHeader() {
    return AppHeader(
      showGradient: true,
      gradient: AppColors.ctaGradient,
      leading: Container(
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
              'assets/images/JEEVibeLogo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
      title: Text(
        'Hi ${_getUserName()}! 👋',
        style: AppTextStyles.headerWhite.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          _getFormattedDate(),
          style: AppTextStyles.bodyWhite.copyWith(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          textAlign: TextAlign.center,
        ),
      ),
      trailing: widget.isInBottomNav
          ? _buildTierBadge()
          : GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileViewScreen()),
                ).then((_) {
                  // Refresh data when returning from profile (user may have edited their profile)
                  _loadData();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white24,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ),
    );
  }

  Widget _buildTierBadge() {
    return Consumer<SubscriptionService>(
      builder: (context, subscriptionService, child) {
        final tier = subscriptionService.currentTier;
        final tierInfo = _getTierBadgeInfo(tier);

        return GestureDetector(
          onTap: () => _onTierBadgeTap(tier),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: tierInfo.gradient,
              color: tierInfo.gradient == null ? tierInfo.backgroundColor : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: tierInfo.borderColor,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tierInfo.icon,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  tierInfo.label,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onTierBadgeTap(SubscriptionTier tier) {
    if (tier == SubscriptionTier.ultra) {
      // Show tier benefits dialog for Ultra users
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.star, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Ultra Benefits'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTierBenefitItem('Unlimited history access'),
              _buildTierBenefitItem('Unlimited daily quizzes'),
              _buildTierBenefitItem('Unlimited snap & solve'),
              _buildTierBenefitItem('AI Tutor (Priya Ma\'am)'),
              _buildTierBenefitItem('Full analytics access'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    } else {
      // Navigate to paywall for Free/Pro users
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PaywallScreen(
            featureName: 'Upgrade',
          ),
        ),
      );
    }
  }

  Widget _buildTierBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 18),
          const SizedBox(width: 12),
          Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  ({String label, IconData icon, Color backgroundColor, Color borderColor, Gradient? gradient}) _getTierBadgeInfo(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return (
          label: 'Free',
          icon: Icons.person_outline,
          backgroundColor: Colors.grey.withAlpha(100),
          borderColor: Colors.grey.withAlpha(150),
          gradient: null,
        );
      case SubscriptionTier.pro:
        return (
          label: 'Pro',
          icon: Icons.workspace_premium_outlined,
          backgroundColor: Colors.amber.withAlpha(150),
          borderColor: Colors.amber,
          gradient: null,
        );
      case SubscriptionTier.ultra:
        return (
          label: 'Ultra',
          icon: Icons.diamond_outlined,
          backgroundColor: const Color(0xFFFFD700),
          borderColor: const Color(0xFFFFD700),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
    }
  }

  Widget _buildAssessmentCard() {
    final isPending = _isAssessmentPending;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPending ? AppColors.warningBackground : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isPending
              ? Border.all(color: AppColors.warningAmber, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Priya's avatar and title
            Row(
              children: [
                // Priya Ma'am avatar
                PriyaAvatar(size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPending ? 'Complete Your Assessment' : 'Initial Assessment',
                        style: AppTextStyles.headerSmall.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isPending)
                        Text(
                          'Ready when you are!',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textLight,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Priya Ma'am message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isPending ? Colors.white.withValues(alpha: 0.7) : AppColors.cardLightPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isPending
                    ? 'Ready to discover your strengths? Complete the assessment in 45 minutes and I\'ll create a personalized study plan that focuses on what matters most for your JEE success. I\'m here to help you succeed! 💜'
                    : 'Hi! I\'m Priya Ma\'am. Let me discover your strengths and growth areas so I can create your perfect study plan.',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.primaryPurple,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Assessment details chips - fit on one line
            Row(
              children: [
                Expanded(
                  child: _buildDetailChip('✏️ 30 questions', isPending: isPending),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildDetailChip('⏱️ 45 minutes', isPending: isPending),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildDetailChip('📚 All subjects', isPending: isPending),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Get Started button
            GradientButton(
              text: 'Get Started',
              onPressed: () async {
                // Set status to in_progress when user clicks Get Started
                final storageService = StorageService();
                await storageService.setAssessmentStatus('in_progress');

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AssessmentInstructionsScreen(),
                  ),
                ).then((_) {
                  // Reload data when returning from instructions
                  _loadData();
                });
              },
              size: GradientButtonSize.large,
              trailingIcon: Icons.arrow_forward,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(String text, {bool isPending = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isPending ? Colors.white.withValues(alpha: 0.8) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textMedium,
          fontSize: 11,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDailyPracticeCard() {
    final isUnlocked = _isAssessmentCompleted;
    final subscriptionService = SubscriptionService();
    final quizUsage = subscriptionService.getUsageInfo(UsageType.dailyQuiz);

    // Build the subtitle based on unlock status and usage
    String subtitle;
    if (!isUnlocked) {
      subtitle = '🔒 Complete assessment to unlock personalized practice';
    } else if (quizUsage != null) {
      if (quizUsage.isUnlimited) {
        subtitle = 'Unlimited quizzes';
      } else if (quizUsage.remaining > 0) {
        subtitle = '${quizUsage.remaining} ${quizUsage.remaining == 1 ? 'quiz' : 'quizzes'} remaining today';
      } else {
        subtitle = 'Daily limit reached • Resets tomorrow';
      }
    } else {
      subtitle = 'Personalized practice questions tailored for you';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.ctaGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Adaptive Quiz',
                        style: AppTextStyles.headerSmall.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isUnlocked && quizUsage != null
                              ? AppColors.primaryPurple
                              : AppColors.textLight,
                          fontWeight: isUnlocked && quizUsage != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDetailChip('✏️ 10 questions'),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildDetailChip('⏱️ ~15 min'),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildDetailChip('📚 Mixed subjects'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Check if limit reached (not unlimited and remaining <= 0)
            if (isUnlocked && quizUsage != null && !quizUsage.isUnlimited && quizUsage.remaining <= 0) ...[
              // Replace button with upgrade CTA when limit reached (outlined style)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PaywallScreen(
                          featureName: 'Daily Quiz',
                          usageType: UsageType.dailyQuiz,
                          limitReachedMessage: "You've used your free daily Daily Quiz. Upgrade for more!",
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.workspace_premium_rounded, size: 20),
                  label: const Text('Upgrade for More Quizzes'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryPurple,
                    side: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Normal button - disabled if assessment not completed
              GradientButton(
                text: 'Start Quiz',
                onPressed: isUnlocked
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DailyQuizLoadingScreen(),
                          ),
                        ).then((_) {
                          // Refresh data when returning from quiz
                          _loadData();
                        });
                      }
                    : null,
                isDisabled: !isUnlocked, // Explicitly disable when assessment not completed
                size: GradientButtonSize.large,
                trailingIcon: Icons.arrow_forward,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMockTestCard() {
    final isUnlocked = _isAssessmentCompleted;

    return Consumer<MockTestProvider>(
      builder: (context, mockTestProvider, child) {
        final usage = mockTestProvider.usage;
        // Mock test card rendered (verbose logging disabled)

        // Determine subtitle text based on unlock and usage state
        String subtitleText;
        if (!isUnlocked) {
          subtitleText = '🔒 Complete assessment to unlock';
        } else if (usage == null) {
          subtitleText = 'Full JEE Main simulation';
        } else if (usage.hasUnlimited) {
          subtitleText = 'Unlimited tests';
        } else {
          subtitleText = '${usage.remaining} tests remaining';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.ctaGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.assignment,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'JEE Main Simulation',
                            style: AppTextStyles.headerSmall.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            subtitleText,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isUnlocked
                                  ? AppColors.primaryPurple
                                  : AppColors.textLight,
                              fontWeight: isUnlocked
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailChip('✏️ 90 questions'),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildDetailChip('⏱️ 3 hours'),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildDetailChip('📊 300 marks'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GradientButton(
                  text: 'Start Simulation',
                  onPressed: isUnlocked
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MockTestHomeScreen(),
                            ),
                          ).then((_) {
                            // Refresh data when returning
                            _loadData();
                          });
                        }
                      : null,
                  isDisabled: !isUnlocked,
                  size: GradientButtonSize.large,
                  trailingIcon: Icons.arrow_forward,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSnapSolveCard() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.ctaGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Snap & Solve',
                            style: AppTextStyles.headerSmall.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            appState.snapLimit == -1
                                ? 'Unlimited snaps'
                                : '${appState.snapsRemaining} snaps remaining',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Stuck on a problem? Just snap a photo and get instant step-by-step solutions!',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 20),
                Consumer<OfflineProvider>(
                  builder: (context, offlineProvider, child) {
                    final isOffline = offlineProvider.isInitialized && offlineProvider.isOffline;

                    if (isOffline) {
                      // Show disabled state when offline
                      return Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: AppColors.textLight.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_off,
                                  color: AppColors.textMedium,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Camera unavailable offline',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.textMedium,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Snap & Solve requires internet to analyze your questions',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textLight,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    }

                    // Check if snap limit reached (not unlimited and no snaps remaining)
                    final isLimitReached = appState.snapLimit != -1 && appState.snapsRemaining <= 0;

                    if (isLimitReached) {
                      // Show upgrade button when limit reached (outlined style)
                      return SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PaywallScreen(
                                  featureName: 'Snap & Solve',
                                  usageType: UsageType.snapSolve,
                                  limitReachedMessage: "You've used all your daily snaps. Upgrade for more!",
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.workspace_premium_rounded, size: 20),
                          label: const Text('Upgrade for More Snaps'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryPurple,
                            side: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      );
                    }

                    return GradientButton(
                      text: 'Take a Photo',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomeScreen(),
                            settings: const RouteSettings(name: '/snap_home'),
                          ),
                        ).then((_) => _loadData());
                      },
                      size: GradientButtonSize.large,
                      leadingIcon: Icons.camera_alt,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildJourneyCard() {
    // Get questions practiced from analytics overview
    final questionsPracticed = _analyticsOverview?.stats.questionsSolved ?? 0;
    final studentName = _getUserName();

    // Generate journey message
    final journeyMessage = JourneyService.generateMessage(
      studentName: studentName,
      questionsPracticed: questionsPracticed,
    );

    // Get visible milestones and next milestone
    final visibleMilestones = JourneyService.getVisibleMilestones(questionsPracticed);
    final nextMilestone = JourneyService.getNextMilestone(questionsPracticed);
    final isNewJourney = JourneyService.isNewJourney(questionsPracticed);

    // GlobalKey for share button positioning (iPad popover)
    final shareButtonKey = GlobalKey();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and share button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      const Text('🚀', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isNewJourney ? 'Your Journey Begins!' : 'Your Journey',
                          style: AppTextStyles.headerSmall.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Share button - increased tap target
                GestureDetector(
                  key: shareButtonKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    // Capture screenshot of the shareable journey card
                    final imageBytes = await _screenshotController.captureFromWidget(
                      MediaQuery(
                        data: const MediaQueryData(),
                        child: Material(
                          color: Colors.transparent,
                          child: ShareableJourneyCard(
                            studentName: studentName,
                            questionsPracticed: questionsPracticed,
                            nextMilestone: nextMilestone,
                          ),
                        ),
                      ),
                      pixelRatio: 3.0,
                      delay: const Duration(milliseconds: 100),
                    );

                    if (imageBytes == null) return;

                    final RenderBox? box = shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
                    final Rect? sharePositionOrigin = box != null
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null;

                    ShareService.shareJourneyProgressAsImage(
                      imageBytes: imageBytes,
                      sharePositionOrigin: sharePositionOrigin,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.share_outlined,
                          size: 16,
                          color: AppColors.primaryPurple,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Share',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress line with milestones
            _buildProgressLine(questionsPracticed, visibleMilestones),
            const SizedBox(height: 8),
            // Questions practiced label
            Center(
              child: Text(
                questionsPracticed == 0
                    ? 'questions practiced'
                    : '$questionsPracticed questions practiced!',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Message card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryPurple.withValues(alpha: 0.1),
                    AppColors.secondaryPink.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    journeyMessage.title,
                    style: AppTextStyles.headerSmall.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    journeyMessage.message,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            // Next milestone (if available)
            if (journeyMessage.nextMilestoneText != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    'Next: ',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMedium,
                    ),
                  ),
                  Text(
                    journeyMessage.nextMilestoneText!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressLine(int questionsPracticed, List<int> milestones) {
    // Horizontal padding to prevent edge dots from being cut off
    const double edgePadding = 12.0;

    return SizedBox(
      height: 50,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Account for edge padding in width calculations
          final availableWidth = constraints.maxWidth - (edgePadding * 2);
          final segmentWidth = availableWidth / (milestones.length - 1);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Background line
              Positioned(
                left: edgePadding,
                right: edgePadding,
                top: 15,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Progress line (filled portion)
              if (questionsPracticed > 0)
                Positioned(
                  left: edgePadding,
                  top: 15,
                  child: Container(
                    height: 4,
                    width: _calculateProgressWidth(questionsPracticed, milestones, availableWidth),
                    decoration: BoxDecoration(
                      gradient: AppColors.ctaGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              // Milestone dots and labels
              ...List.generate(milestones.length, (index) {
                final milestone = milestones[index];
                final isCompleted = questionsPracticed >= milestone;
                final isCurrent = questionsPracticed >= milestone &&
                    (index == milestones.length - 1 || questionsPracticed < milestones[index + 1]);
                // Position from edge padding, centered on the dot (dot is 20px wide now)
                final xPosition = edgePadding + (index * segmentWidth) - 10;

                return Positioned(
                  left: xPosition,
                  top: 5,
                  child: Column(
                    children: [
                      // Milestone dot (slightly smaller to fit better)
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isCompleted ? AppColors.primaryPurple : Colors.grey.shade300,
                          shape: BoxShape.circle,
                          border: isCurrent ? Border.all(color: AppColors.secondaryPink, width: 2) : null,
                        ),
                        child: isCompleted
                            ? const Icon(Icons.check, color: Colors.white, size: 12)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      // Milestone label
                      Text(
                        '$milestone',
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 10,
                          color: isCompleted ? AppColors.primaryPurple : AppColors.textLight,
                          fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  double _calculateProgressWidth(int questionsPracticed, List<int> milestones, double totalWidth) {
    if (questionsPracticed <= milestones.first) {
      return 0;
    }
    if (questionsPracticed >= milestones.last) {
      return totalWidth;
    }

    // Find which segment we're in
    for (int i = 0; i < milestones.length - 1; i++) {
      if (questionsPracticed >= milestones[i] && questionsPracticed < milestones[i + 1]) {
        final segmentWidth = totalWidth / (milestones.length - 1);
        final segmentStart = i * segmentWidth;
        final progress = (questionsPracticed - milestones[i]) / (milestones[i + 1] - milestones[i]);
        return segmentStart + (progress * segmentWidth);
      }
    }

    return totalWidth;
  }

  Widget _buildPriyaMessageCard() {
    final subscriptionService = SubscriptionService();
    final hasAiTutorAccess = subscriptionService.status?.limits.aiTutorEnabled ?? false;

    // Use dynamic message if available, otherwise use default
    final message = _priyaMessage ?? PriyaMessage(
      title: 'Great Job, ${_getUserName()}! 🎉',
      subtitle: 'Assessment Complete',
      message: "I've analyzed your strengths and areas for improvement. Let's build on this with daily adaptive practice tailored for you!",
      type: PriyaMessageType.assessmentComplete,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar and title row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PriyaAvatar(size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.title,
                        style: AppTextStyles.headerSmall.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textLight,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Message bubble
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardLightPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.message,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.textMedium,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // JEE Countdown Timeline Section (if data available)
            if (_chapterUnlockData != null && _chapterUnlockData!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildJeeCountdownSection(),
            ],
            // Chat with Priya button (Ultra tier only)
            if (hasAiTutorAccess) ...[
              const SizedBox(height: 16),
              GradientButton(
                text: 'Chat with Priya Ma\'am',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AiTutorChatScreen(),
                    ),
                  );
                },
                size: GradientButtonSize.large,
                leadingIcon: Icons.chat_bubble_outline,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJeeCountdownSection() {
    if (_chapterUnlockData == null) return const SizedBox.shrink();

    final monthsUntilExam = _chapterUnlockData!['monthsUntilExam'] as int? ?? 0;
    final unlockedChapters = _chapterUnlockData!['unlockedChapters'] as List? ?? [];
    final totalMonths = _chapterUnlockData!['totalMonths'] as int? ?? 24;
    final currentMonth = _chapterUnlockData!['currentMonth'] as int? ?? 1;

    // Get jeeTargetExamDate from user profile to show the actual exam date
    final userProfileProvider = Provider.of<UserProfileProvider>(context, listen: false);
    final examDate = userProfileProvider.profile?.jeeTargetExamDate ?? '';

    // Parse exam date (format: "YYYY-MM")
    String examLabel = '';
    if (examDate.isNotEmpty) {
      final parts = examDate.split('-');
      if (parts.length == 2) {
        final year = parts[0];
        final month = parts[1];
        examLabel = month == '01' ? 'JEE January $year' : 'JEE April $year';
      }
    }

    // Calculate progress percentage (total chapters is approximately 63)
    const totalChapters = 63;
    final progress = unlockedChapters.length / totalChapters;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardLightPurple.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryPurple.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exam date and countdown row
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 16,
                color: AppColors.primaryPurple,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  examLabel.isNotEmpty ? examLabel : 'Your JEE Target',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  monthsUntilExam == 0
                      ? 'Exam time!'
                      : '$monthsUntilExam ${monthsUntilExam == 1 ? 'month' : 'months'} left',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress row
          Row(
            children: [
              const Icon(
                Icons.auto_stories,
                size: 16,
                color: AppColors.primaryPurple,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${unlockedChapters.length}/$totalChapters chapters unlocked',
                      style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primaryPurple,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChapterUnlockProgress() {
    if (_chapterUnlockData == null) return const SizedBox.shrink();

    final unlockedChapters = _chapterUnlockData!['unlockedChapters'] as List? ?? [];
    final monthsUntilExam = _chapterUnlockData!['monthsUntilExam'] as int? ?? 0;

    // Calculate progress percentage (total chapters is approximately 63)
    const totalChapters = 63;
    final progress = unlockedChapters.length / totalChapters;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardLightPurple.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chapters Unlocked',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primaryPurple,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${unlockedChapters.length}/$totalChapters',
                      style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryPurple,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (monthsUntilExam > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$monthsUntilExam ${monthsUntilExam == 1 ? 'month' : 'months'} to JEE',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textLight,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // View All button - opens chapter list screen
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ChapterListScreen(),
                ),
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'View All',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    // Check if we have analytics data with completed quizzes (cumulative progress)
    final hasQuizProgress = _analyticsOverview != null &&
        _analyticsOverview!.stats.quizzesCompleted > 0;

    // Determine header text based on whether they've done daily quizzes
    final headerText = hasQuizProgress ? 'Your Progress' : 'Assessment';

    // Get subject data - prefer analytics overview for cumulative data
    final SubjectProgressData physicsProgress;
    final SubjectProgressData chemistryProgress;
    final SubjectProgressData mathsProgress;

    if (hasQuizProgress && _analyticsOverview != null) {
      // Use analytics data for cumulative progress
      final physics = _analyticsOverview!.subjectProgress['physics'];
      final chemistry = _analyticsOverview!.subjectProgress['chemistry'];
      final maths = _analyticsOverview!.subjectProgress['maths'] ??
                   _analyticsOverview!.subjectProgress['mathematics'];

      physicsProgress = SubjectProgressData(
        accuracy: physics?.accuracy,
        correct: physics?.correct ?? 0,
        total: physics?.total ?? 0,
      );
      chemistryProgress = SubjectProgressData(
        accuracy: chemistry?.accuracy,
        correct: chemistry?.correct ?? 0,
        total: chemistry?.total ?? 0,
      );
      mathsProgress = SubjectProgressData(
        accuracy: maths?.accuracy,
        correct: maths?.correct ?? 0,
        total: maths?.total ?? 0,
      );
    } else {
      // Fall back to assessment data
      final physicsData = _assessmentData!.subjectAccuracy['physics'] as Map<String, dynamic>?;
      final chemistryData = _assessmentData!.subjectAccuracy['chemistry'] as Map<String, dynamic>?;
      final mathematicsData = _assessmentData!.subjectAccuracy['mathematics'] as Map<String, dynamic>?;

      physicsProgress = SubjectProgressData(
        accuracy: _extractAccuracy(physicsData),
        correct: physicsData?['correct'] as int? ?? 0,
        total: physicsData?['total'] as int? ?? 0,
      );
      chemistryProgress = SubjectProgressData(
        accuracy: _extractAccuracy(chemistryData),
        correct: chemistryData?['correct'] as int? ?? 0,
        total: chemistryData?['total'] as int? ?? 0,
      );
      mathsProgress = SubjectProgressData(
        accuracy: _extractAccuracy(mathematicsData),
        correct: mathematicsData?['correct'] as int? ?? 0,
        total: mathematicsData?['total'] as int? ?? 0,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and View Insights link
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        hasQuizProgress ? Icons.trending_up : Icons.bar_chart,
                        size: 24,
                        color: AppColors.primaryPurple,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          headerText,
                          style: AppTextStyles.headerSmall.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Subject Results
            _buildSubjectResult('Physics', physicsProgress, AppColors.subjectPhysics, Icons.bolt),
            const SizedBox(height: 8),
            _buildSubjectResult('Chemistry', chemistryProgress, AppColors.subjectChemistry, Icons.science),
            const SizedBox(height: 8),
            _buildSubjectResult('Mathematics', mathsProgress, AppColors.subjectMathematics, Icons.functions),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectResult(String subject, SubjectProgressData progress, Color color, IconData icon) {
    final accuracyValue = progress.accuracy ?? 0;
    final displayAccuracy = progress.accuracy != null ? '${progress.accuracy}%' : 'N/A';

    // Determine progress bar color based on accuracy thresholds
    Color progressColor;
    if (progress.accuracy == null || accuracyValue == 0) {
      progressColor = Colors.grey;
    } else if (accuracyValue < 70) {
      progressColor = AppColors.performanceOrange;
    } else if (accuracyValue <= 85) {
      progressColor = AppColors.subjectMathematics;
    } else {
      progressColor = AppColors.subjectChemistry;
    }

    // Build the correct/total display string
    final hasQuestionData = progress.total > 0;
    final correctTotalText = hasQuestionData
        ? '${progress.correct}/${progress.total}'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subject name with icon, question count, and percentage row
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              subject,
              style: AppTextStyles.headerSmall.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (correctTotalText.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                correctTotalText,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textLight,
                  fontSize: 12,
                ),
              ),
            ],
            const Spacer(),
            Text(
              displayAccuracy,
              style: AppTextStyles.headerSmall.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: accuracyValue / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
  
  int? _extractAccuracy(Map<String, dynamic>? data) {
    if (data == null) return null;
    
    final accuracy = data['accuracy'];
    if (accuracy == null) return null;
    
    if (accuracy is int) {
      return accuracy;
    } else if (accuracy is num) {
      return accuracy.toInt();
    }
    
    return null;
  }

  Widget _buildFocusAreasCard() {
    final subscriptionService = SubscriptionService();
    final hasChapterPractice = subscriptionService.isChapterPracticeEnabled;
    final isFree = subscriptionService.isFree;
    final hasAnySubjectLocked = subscriptionService.hasAnySubjectLocked;

    // Check if user has completed initial assessment and at least 1 daily quiz
    final hasCompletedAssessment = _isAssessmentCompleted;
    final quizzesCompleted = _analyticsOverview?.stats.quizzesCompleted ?? 0;
    final hasCompletedAtLeastOneQuiz = quizzesCompleted > 0;

    // Show unlock message if analytics not loaded, assessment not completed, OR no quizzes completed
    final shouldShowUnlockMessage = _analyticsOverview == null ||
                                     !hasCompletedAssessment ||
                                     !hasCompletedAtLeastOneQuiz;

    // Get focus areas (empty list if analytics not loaded)
    final focusAreas = _analyticsOverview?.focusAreas ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.ctaGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.gps_fixed,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Focus Chapters',
                        style: AppTextStyles.headerSmall.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isFree)
                        Text(
                          '1 chapter/week per subject',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Chapter unlock progress bar (if data available)
            if (_chapterUnlockData != null && _chapterUnlockData!.isNotEmpty) ...[
              _buildChapterUnlockProgress(),
              const SizedBox(height: 12),
            ],
            // Show unlock message if assessment not completed OR no quizzes completed
            if (shouldShowUnlockMessage)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '🔒 Complete Daily Adaptive Quiz to unlock focus area',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              )
            // Show focus areas for all users (free tier with weekly limits, paid with unlimited)
            else if (hasChapterPractice && focusAreas.isNotEmpty)
              // Focus areas list with individual Practise links (with lock status for free users)
              Column(
                children: [
                  ...focusAreas.asMap().entries.map((entry) {
                    final index = entry.key;
                    final area = entry.value;
                    final isLast = index == focusAreas.length - 1;
                    // Check if this subject is locked (only applies to free tier)
                    final isSubjectLocked = isFree && subscriptionService.isSubjectLocked(area.subject);
                    final unlockInfo = isFree ? subscriptionService.getSubjectUnlockInfo(area.subject) : null;
                    return _buildFocusAreaRow(area, isLast, isSubjectLocked, unlockInfo);
                  }),
                  // Show "Practice any chapter" link for Pro/Ultra users
                  if (!isFree) ...[
                    const SizedBox(height: 12),
                    _buildPracticeAnyChapterLink(),
                  ],
                  // Show upgrade button at bottom if any subject is locked (free tier only)
                  if (isFree && hasAnySubjectLocked) ...[
                    const SizedBox(height: 12),
                    _buildFocusAreasUpgradeButton(),
                  ],
                ],
              )
            else if (focusAreas.isEmpty && hasChapterPractice)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Great job! No weak areas detected yet.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  // Show "Practice any chapter" link for Pro/Ultra users even when no focus areas
                  if (!isFree) ...[
                    const SizedBox(height: 8),
                    _buildPracticeAnyChapterLink(),
                  ],
                ],
              )
            // Fallback for users without chapter practice enabled (shouldn't happen with new config)
            else
              _buildFocusAreasUpgradeContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusAreasUpgradeContent() {
    return Column(
      children: [
        Text(
          'Unlock detailed chapter-wise analysis to identify your weak areas and improve faster.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PaywallScreen(
                    featureName: 'Focus Areas',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.workspace_premium_rounded, size: 18),
            label: const Text('Upgrade to Pro'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryPurple,
              side: BorderSide(color: AppColors.primaryPurple.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFocusAreaRow(FocusArea area, bool isLast, bool isLocked, SubjectPracticeUsage? unlockInfo) {
    // Get subject icon and color
    IconData subjectIcon;
    Color subjectColor;
    switch (area.subject.toLowerCase()) {
      case 'physics':
        subjectIcon = Icons.bolt;
        subjectColor = AppColors.subjectPhysics;
        break;
      case 'chemistry':
        subjectIcon = Icons.science;
        subjectColor = AppColors.subjectChemistry;
        break;
      case 'mathematics':
      case 'maths':
        subjectIcon = Icons.functions;
        subjectColor = AppColors.subjectMathematics;
        break;
      default:
        subjectIcon = Icons.book;
        subjectColor = AppColors.textMedium;
    }

    return Column(
      children: [
        InkWell(
          onTap: isLocked ? null : () {
            // Navigate to Chapter Practice for this focus area
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChapterPracticeLoadingScreen(
                  chapterKey: area.chapterKey,
                  chapterName: area.chapterName,
                  subject: area.subject,
                ),
              ),
            ).then((_) {
              // Refresh data when returning from chapter practice
              _loadData();
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Opacity(
            opacity: isLocked ? 0.5 : 1.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  // Subject icon
                  Icon(
                    subjectIcon,
                    size: 16,
                    color: isLocked ? AppColors.textLight : subjectColor,
                  ),
                  const SizedBox(width: 8),
                  // Chapter name and unlock info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          area.chapterName,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isLocked ? AppColors.textSecondary : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isLocked && unlockInfo != null)
                          Text(
                            'Unlocks in ${unlockInfo.daysRemaining} day${unlockInfo.daysRemaining == 1 ? '' : 's'}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Lock icon or chevron (no score badge on home page)
                  Icon(
                    isLocked ? Icons.lock : Icons.chevron_right,
                    size: 18,
                    color: isLocked ? AppColors.textLight : AppColors.textLight,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            color: AppColors.borderLight,
          ),
      ],
    );
  }

  Widget _buildFocusAreasUpgradeButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PaywallScreen(
                limitReachedMessage: 'Practice more chapters with Pro!',
                featureName: 'Chapter Practice',
              ),
            ),
          );
        },
        icon: const Icon(Icons.workspace_premium_rounded, size: 18),
        label: const Text('Upgrade to Pro'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryPurple,
          side: BorderSide(color: AppColors.primaryPurple.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildPracticeAnyChapterLink() {
    return GradientButton(
      text: 'Practice Any Chapter',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ChapterPickerScreen(),
          ),
        ).then((_) {
          // Refresh data when returning from chapter practice
          _loadData();
        });
      },
      size: GradientButtonSize.large,
      trailingIcon: Icons.arrow_forward,
    );
  }

  Color _getFocusAreaColor(double accuracy) {
    if (accuracy < 50) {
      return AppColors.performanceOrange;
    } else if (accuracy < 70) {
      return AppColors.warningAmber;
    } else {
      return AppColors.subjectMathematics;
    }
  }

  Widget _buildFloatingSnapButton() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppColors.ctaGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                    // Refresh data when returning
                    _loadData();
                  },
                  borderRadius: BorderRadius.circular(32),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
            // Notification badge with snap count
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    appState.snapLimit == -1 ? '∞' : '${appState.snapsRemaining}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Helper class for subject progress data
class SubjectProgressData {
  final int? accuracy;
  final int correct;
  final int total;

  const SubjectProgressData({
    this.accuracy,
    this.correct = 0,
    this.total = 0,
  });
}
