/// Daily Quiz Home/Dashboard Screen
/// Shows different states based on user activity level
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_user_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../models/user_profile.dart';
import '../models/assessment_response.dart';
import '../models/subscription_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/priya_avatar.dart';
import '../widgets/daily_quiz/priya_maam_card_widget.dart';
import '../widgets/daily_quiz/daily_quiz_card_widget.dart';
import '../widgets/daily_quiz/subject_progress_widget.dart';
import '../providers/daily_quiz_provider.dart';
import '../utils/error_handler.dart';
import 'daily_quiz_loading_screen.dart';
import 'analytics_screen.dart';
import 'subscription/paywall_screen.dart';

enum UserState {
  newUserDay1,
  firstWeek,
  activeUser,
  lapsedUser,
  returningUser,
}

class DailyQuizHomeScreen extends StatefulWidget {
  const DailyQuizHomeScreen({super.key});

  @override
  State<DailyQuizHomeScreen> createState() => _DailyQuizHomeScreenState();
}

class _DailyQuizHomeScreenState extends State<DailyQuizHomeScreen> {
  UserProfile? _userProfile;
  UserState _userState = UserState.newUserDay1;
  AssessmentData? _assessmentData;
  bool _isLoadingAssessment = false;
  bool _isCheckingQuizAccess = false; // Loading state for paywall check
  final SubscriptionService _subscriptionService = SubscriptionService();
  int _quizzesRemaining = 1; // Default for free tier
  bool _isQuizUnlimited = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load user profile
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreUserService>(context, listen: false);
      final user = authService.currentUser;
      if (user != null) {
        final profile = await firestoreService.getUserProfile(user.uid);
        if (mounted) {
          setState(() {
            _userProfile = profile;
          });
        }

        // Load subscription status for quiz gating
        final token = await authService.getIdToken();
        if (token != null) {
          await _subscriptionService.fetchStatus(token);
          final quizUsage = _subscriptionService.getUsageInfo(UsageType.dailyQuiz);
          if (mounted && quizUsage != null) {
            setState(() {
              _isQuizUnlimited = quizUsage.isUnlimited;
              _quizzesRemaining = quizUsage.isUnlimited ? 999 : quizUsage.remaining;
            });
          }
        }
      }

      // Load summary and progress using provider
      final provider = Provider.of<DailyQuizProvider>(context, listen: false);
      await Future.wait([
        ErrorHandler.withRetry(operation: () => provider.loadSummary()),
        ErrorHandler.withRetry(operation: () => provider.loadProgress()),
      ]);

      // Check if user has completed assessment but no daily quizzes
      final progress = provider.progress;
      final completedQuizCount = progress?['cumulative']?['total_quizzes'] ?? 0;
      
      // Check assessment status from local storage
      final storageService = StorageService();
      final assessmentStatus = await storageService.getAssessmentStatus();
      
      if (completedQuizCount == 0 && assessmentStatus == 'completed') {
        // Load assessment results
        await _loadAssessmentResults(user!.uid);
      }

      if (mounted) {
        setState(() {
          _userState = _determineUserState(provider.summary, provider.progress);
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          message: ErrorHandler.getErrorMessage(e),
          onRetry: _loadData,
        );
      }
    }
  }

  UserState _determineUserState(Map<String, dynamic>? summary, Map<String, dynamic>? progress) {
    if (summary == null || progress == null) return UserState.newUserDay1;
    
    final completedQuizCount = progress['cumulative']?['total_quizzes'] ?? 0;
    final lastQuizCompleted = summary['last_quiz_completed_at'] as String?;
    final streak = summary['streak'] as Map<String, dynamic>? ?? {};
    final currentStreak = streak['current'] as int? ?? 0;
    
    // Calculate days since last quiz
    int daysSinceLastQuiz = 999;
    if (lastQuizCompleted != null) {
      try {
        final lastDate = DateTime.parse(lastQuizCompleted);
        final now = DateTime.now();
        daysSinceLastQuiz = now.difference(lastDate).inDays;
      } catch (e) {
        // Invalid date, treat as new user
      }
    }

    // Determine state
    if (completedQuizCount == 0) {
      return UserState.newUserDay1;
    } else if (completedQuizCount >= 1 && completedQuizCount < 7) {
      return UserState.firstWeek;
    } else if (daysSinceLastQuiz >= 7) {
      return UserState.returningUser;
    } else if (daysSinceLastQuiz >= 3 && daysSinceLastQuiz < 7) {
      return UserState.lapsedUser;
    } else {
      return UserState.activeUser;
    }
  }

  String _getUserName() {
    return _userProfile?.firstName ?? 'Student';
  }

  String _getFormattedDate() {
    return DateFormat('EEEE, MMM d').format(DateTime.now());
  }

  Future<void> _loadAssessmentResults(String userId) async {
    if (_isLoadingAssessment) return;
    
    setState(() {
      _isLoadingAssessment = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();
      
      if (token != null) {
        final result = await ApiService.getAssessmentResults(
          authToken: token,
          userId: userId,
        );
        
        if (mounted && result.success && result.data != null) {
          setState(() {
            _assessmentData = result.data;
            _isLoadingAssessment = false;
          });
        } else {
          if (mounted) {
            setState(() {
              _isLoadingAssessment = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingAssessment = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading assessment results: $e');
      if (mounted) {
        setState(() {
          _isLoadingAssessment = false;
        });
      }
    }
  }

  String _getPriyaMaamMessage() {
    final provider = Provider.of<DailyQuizProvider>(context, listen: false);
    final progress = provider.progress;
    
    switch (_userState) {
      case UserState.newUserDay1:
        return "I've prepared your first quiz based on your assessment. Let's see what you've got! 💜";
      case UserState.firstWeek:
        final focusTopic = _getFocusTopic(progress);
        if (focusTopic != null) {
          return "Today's quiz focuses on **$focusTopic**. Let's strengthen it! 💪";
        }
        return "Great progress! Keep up the momentum with today's quiz! 🚀";
      case UserState.activeUser:
        final focusTopic = _getFocusTopic(progress);
        if (focusTopic != null) {
          return "Physics is improving! Today I'm adding **$focusTopic** to keep you sharp. 🎯";
        }
        return "Welcome back! Your quiz is ready. Let's pick up where you left off! 💜";
      case UserState.lapsedUser:
        return "Welcome back! I've refreshed your quiz. Ready? 🚀";
      case UserState.returningUser:
        return "Great to see you! I've refreshed your quiz. Ready? 🚀";
    }
  }

  String? _getFocusTopic(Map<String, dynamic>? progress) {
    if (progress == null) return null;
    
    // Get weakest chapter from progress
    final chapters = progress['chapters'] as Map<String, dynamic>? ?? {};
    if (chapters.isEmpty) return null;
    
    final sortedChapters = chapters.entries.toList()
      ..sort((a, b) {
        final aPercentile = a.value['current_percentile'] as num? ?? 50;
        final bPercentile = b.value['current_percentile'] as num? ?? 50;
        return aPercentile.compareTo(bPercentile);
      });
    
    if (sortedChapters.isNotEmpty) {
      final weakest = sortedChapters.first;
      return weakest.value['chapter'] as String? ?? weakest.key.split('_').last;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DailyQuizProvider>(
      builder: (context, provider, child) {
        final isLoading = provider.isLoadingSummary || provider.isLoadingProgress;
        final hasError = provider.hasError;

        if (isLoading) {
          return Scaffold(
            backgroundColor: AppColors.backgroundLight,
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            ),
          );
        }

        if (hasError && provider.summary == null) {
          return Scaffold(
            backgroundColor: AppColors.backgroundLight,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.errorRed),
                    const SizedBox(height: 16),
                    Text('Error', style: AppTextStyles.headerMedium),
                    const SizedBox(height: 8),
                    Text(
                      provider.error ?? 'Failed to load data',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // Purple gradient header
          _buildHeader(),
          // Scrollable content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Priya Ma'am message
                    _buildPriyaMaamCard(),
                    const SizedBox(height: 16),
                    // Welcome message for lapsed/returning users
                    if (_userState == UserState.lapsedUser || _userState == UserState.returningUser)
                      _buildWelcomeBanner(),
                    if (_userState == UserState.lapsedUser || _userState == UserState.returningUser)
                      const SizedBox(height: 16),
                    // Initial Assessment Results (if completed but no daily quizzes)
                    if (_shouldShowAssessmentResults(provider))
                      _buildAssessmentResultsCard(),
                    if (_shouldShowAssessmentResults(provider))
                      const SizedBox(height: 16),
                    // Daily Quiz Ready card
                    _buildDailyQuizCard(),
                    const SizedBox(height: 16),
                    // Subject Progress
                    _buildSubjectProgress(),
                    const SizedBox(height: 16),
                    // Your Progress / Your Journey
                    _buildProgressSection(provider),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildPriyaMaamCard() {
    return PriyaMaamCardWidget(
      message: _getPriyaMaamMessage(),
    );
  }

  Widget _buildDailyQuizCard() {
    final provider = Provider.of<DailyQuizProvider>(context, listen: false);
    final hasActiveQuiz = provider.hasActiveQuiz;

    // Check if user has quizzes remaining (tier-based)
    // Disable button while checking access to prevent double-tap
    bool canStartQuiz = !_isCheckingQuizAccess && (_isQuizUnlimited || _quizzesRemaining > 0);

    // C8: Get dynamic quiz size from summary or current quiz
    int? questionCount;
    int? estimatedTimeMinutes;

    if (provider.currentQuiz != null) {
      questionCount = provider.currentQuiz!.totalQuestions;
      // Estimate: 1.5 minutes per question
      estimatedTimeMinutes = (questionCount * 1.5).round();
    } else if (provider.summary != null) {
      // Try to get from summary if available
      // Default to 10 if not available
      questionCount = 10;
      estimatedTimeMinutes = 15;
    } else {
      questionCount = 10;
      estimatedTimeMinutes = 15;
    }

    return Stack(
      children: [
        DailyQuizCardWidget(
          hasActiveQuiz: hasActiveQuiz,
          canStartQuiz: canStartQuiz,
          questionCount: questionCount,
          estimatedTimeMinutes: estimatedTimeMinutes,
          quizzesRemaining: _isQuizUnlimited ? -1 : _quizzesRemaining,
          onStartQuiz: _isCheckingQuizAccess ? null : () async {
            // Prevent double-tap by showing loading state
            if (_isCheckingQuizAccess) return;

            setState(() {
              _isCheckingQuizAccess = true;
            });

            try {
              // Gate check before starting quiz
              final authService = Provider.of<AuthService>(context, listen: false);
              final token = await authService.getIdToken();

              if (token != null) {
                final canProceed = await _subscriptionService.gatekeepFeature(
                  context,
                  UsageType.dailyQuiz,
                  'Daily Quiz',
                  token,
                );

                if (!canProceed) {
                  // Paywall was shown, don't proceed
                  return;
                }
              }

              // Proceed to quiz
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DailyQuizLoadingScreen(),
                  ),
                );
              }
            } finally {
              if (mounted) {
                setState(() {
                  _isCheckingQuizAccess = false;
                });
              }
            }
          },
        ),
        // Loading overlay when checking access
        if (_isCheckingQuizAccess)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primaryPurple),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSubjectProgress() {
    final provider = Provider.of<DailyQuizProvider>(context, listen: false);
    final progress = provider.progress;
    
    if (progress == null) return const SizedBox.shrink();
    
    final subjects = progress['subjects'] as Map<String, dynamic>? ?? {};
    
    return SubjectProgressWidget(subjects: subjects);
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.ctaGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              // Circular logo on left
              Container(
                width: 48,
                height: 48,
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
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(
                      'assets/images/JEEVibeLogo_240.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.book, color: AppColors.primaryPurple);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Centered greeting and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Hi ${_getUserName()}! 👋',
                      style: AppTextStyles.headerWhite.copyWith(fontSize: 28),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getFormattedDate(),
                      style: AppTextStyles.bodyWhite.copyWith(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Empty space on right to balance the logo
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }


  Widget _getSubjectIcon(String subject) {
    IconData icon;
    Color color;
    
    switch (subject) {
      case 'Physics':
        icon = Icons.bolt;
        color = AppColors.warningAmber;
        break;
      case 'Chemistry':
        icon = Icons.science;
        color = AppColors.successGreen;
        break;
      case 'Mathematics':
        icon = Icons.calculate;
        color = AppColors.textLight;
        break;
      default:
        icon = Icons.book;
        color = AppColors.textMedium;
    }
    
    return Icon(icon, color: color, size: 24);
  }

  Color _getSubjectColor(String subject) {
    switch (subject) {
      case 'Physics':
        return AppColors.infoBlue;
      case 'Chemistry':
        return AppColors.successGreen;
      case 'Mathematics':
        return AppColors.primaryPurple;
      default:
        return AppColors.textMedium;
    }
  }

  Widget _buildProgressSection(DailyQuizProvider provider) {
    switch (_userState) {
      case UserState.newUserDay1:
      case UserState.firstWeek:
        return _buildJourneySection(provider);
      case UserState.activeUser:
        return _buildActiveUserJourneySection(provider);
      case UserState.lapsedUser:
      case UserState.returningUser:
        return _buildYourProgressSection(provider);
    }
  }

  Widget _buildActiveUserJourneySection(DailyQuizProvider provider) {
    final cumulative = provider.progress?['cumulative'] as Map<String, dynamic>? ?? {};
    final questionsPracticed = cumulative['total_questions'] as int? ?? 0;
    
    // Milestones: 50, 100, 150, 200, 250, 300
    final milestones = [50, 100, 150, 200, 250, 300];
    final nextMilestone = milestones.firstWhere(
      (m) => questionsPracticed < m,
      orElse: () => milestones.last,
    );
    final remaining = nextMilestone - questionsPracticed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.rocket_launch, color: AppColors.errorRed, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Your Journey',
                    style: AppTextStyles.headerSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // View All button removed
            ],
          ),
          const SizedBox(height: 16),
          // Progress tracker
          _buildMilestoneTracker(milestones, questionsPracticed),
          const SizedBox(height: 16),
          Text(
            '$questionsPracticed questions practiced!',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💜 Great to see you, ${_getUserName()}! You\'ve made solid progress. Let\'s keep going!',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodySmall,
                    children: [
                      const TextSpan(text: '🎯 Next: '),
                      TextSpan(
                        text: '$nextMilestone questions',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: remaining > 0 ? ' (only $remaining more!)' : '',
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

  Widget _buildJourneySection(DailyQuizProvider provider) {
    final cumulative = provider.progress?['cumulative'] as Map<String, dynamic>? ?? {};
    final questionsPracticed = cumulative['total_questions'] as int? ?? 0;
    
    // Milestones: 10, 25, 50, 100, 200
    final milestones = [10, 25, 50, 100, 200];
    final nextMilestone = milestones.firstWhere(
      (m) => questionsPracticed < m,
      orElse: () => milestones.last,
    );
    final remaining = nextMilestone - questionsPracticed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.rocket_launch, color: AppColors.errorRed, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Your Journey Begins!',
                    style: AppTextStyles.headerSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // View All button removed
            ],
          ),
          const SizedBox(height: 16),
          // Progress tracker
          _buildMilestoneTracker(milestones, questionsPracticed),
          const SizedBox(height: 16),
          Text(
            '$questionsPracticed questions practiced!',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.track_changes, color: AppColors.primaryPurple, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'First milestone: $nextMilestone questions',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        remaining > 0 
                            ? 'Complete today\'s quiz to start!'
                            : 'Congratulations! You\'ve reached your first milestone! 🎉',
                        style: AppTextStyles.bodySmall,
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

  Widget _buildMilestoneTracker(List<int> milestones, int current) {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: milestones.asMap().entries.map((entry) {
          final index = entry.key;
          final milestone = entry.value;
          final isCompleted = current >= milestone;
          final prevMilestone = index > 0 ? milestones[index - 1] : 0;
          final isCurrent = current >= prevMilestone && current < milestone;
          
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCompleted 
                            ? AppColors.primaryPurple 
                            : (isCurrent ? AppColors.primaryPurple : AppColors.borderGray),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : Text(
                                '$milestone',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isCurrent ? Colors.white : AppColors.textLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$milestone',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textLight,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                if (index < milestones.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 20),
                      color: isCompleted 
                          ? AppColors.primaryPurple 
                          : AppColors.borderGray,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    String message;
    if (_userState == UserState.returningUser) {
      message = "👋 Welcome back, ${_getUserName()}! Your progress is saved. Ready to continue?";
    } else {
      message = "👋 Welcome back, ${_getUserName()}! Your progress is saved. Ready to continue?";
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: AppTextStyles.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildYourProgressSection(DailyQuizProvider provider) {
    final cumulative = provider.progress?['cumulative'] as Map<String, dynamic>? ?? {};
    final streak = provider.summary?['streak'] as Map<String, dynamic>? ?? {};
    final questionsPracticed = cumulative['total_questions'] as int? ?? 0;
    final accuracy = cumulative['overall_accuracy'] as num? ?? 0.0;
    final currentStreak = streak['current'] as int? ?? 0;
    final longestStreak = streak['longest'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart, color: AppColors.successGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Your Progress',
                    style: AppTextStyles.headerSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to full progress view
                },
                child: Text(
                  'View All',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Metrics cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.track_changes,
                  value: '$questionsPracticed',
                  label: 'Questions',
                  subtitle: _getQuestionsSubtitle(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.trending_up,
                  value: '${(accuracy * 100).toInt()}%',
                  label: 'Accuracy',
                  subtitle: _getAccuracySubtitle(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // This Week tracker
          _buildWeekTracker(provider),
          const SizedBox(height: 16),
          // Streak message
          if (currentStreak > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, 
                      color: AppColors.warningAmber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentStreak >= 7
                          ? '🔥 $currentStreak-day streak! You\'re on fire!'
                          : '🔥 $currentStreak-day streak! Building momentum!',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.warningAmber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_userState == UserState.returningUser)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.track_changes, 
                      color: AppColors.primaryPurple, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🎯 New streak starts today!',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String value,
    required String label,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.borderGray),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.errorRed, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.headerMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textLight,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.successGreen,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _getQuestionsSubtitle() {
    // Get best week or improvement
    final provider = Provider.of<DailyQuizProvider>(context, listen: false);
    final cumulative = provider.progress?['cumulative'] as Map<String, dynamic>? ?? {};
    // TODO: Calculate from weekly stats
    return 'Keep going!';
  }

  String? _getAccuracySubtitle() {
    final provider = Provider.of<DailyQuizProvider>(context, listen: false);
    final cumulative = provider.progress?['cumulative'] as Map<String, dynamic>? ?? {};
    final accuracy = cumulative['overall_accuracy'] as num? ?? 0.0;
    if (accuracy >= 0.7) return 'Great start!';
    return 'Keep practicing!';
  }

  bool _shouldShowAssessmentResults(DailyQuizProvider provider) {
    final progress = provider.progress;
    final completedQuizCount = progress?['cumulative']?['total_quizzes'] ?? 0;
    return completedQuizCount == 0 && _assessmentData != null;
  }

  Widget _buildAssessmentResultsCard() {
    if (_assessmentData == null) return const SizedBox.shrink();
    
    final subjectAccuracy = _assessmentData!.subjectAccuracy;
    final physicsAccuracy = _extractAccuracy(subjectAccuracy['physics']);
    final chemistryAccuracy = _extractAccuracy(subjectAccuracy['chemistry']);
    final mathematicsAccuracy = _extractAccuracy(subjectAccuracy['mathematics']);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          // Header with title and View Insights link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.bar_chart,
                      size: 20,
                      color: AppColors.primaryPurple,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Assessment',
                        style: AppTextStyles.headerSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Analytics link with PRO badge
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnalyticsScreen(),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: AppColors.primaryPurple,
                            size: 10,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'PRO',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Analytics',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppColors.primaryPurple,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Subject Results
          _buildSubjectResult('Physics', physicsAccuracy, AppColors.subjectPhysics),
          const SizedBox(height: 12),
          _buildSubjectResult('Chemistry', chemistryAccuracy, AppColors.subjectChemistry),
          const SizedBox(height: 12),
          _buildSubjectResult('Mathematics', mathematicsAccuracy, AppColors.subjectMathematics),
        ],
      ),
    );
  }

  Widget _buildSubjectResult(String subject, int? accuracy, Color color) {
    final accuracyValue = accuracy ?? 0;
    final displayAccuracy = accuracy != null ? '$accuracy%' : 'N/A';
    
    // Determine feedback text and progress bar color based on thresholds
    String feedbackText;
    Color progressColor;
    
    if (accuracy == null || accuracyValue == 0) {
      feedbackText = 'Not assessed';
      progressColor = Colors.grey;
    } else if (accuracyValue < 70) {
      feedbackText = 'Needs more practice';
      progressColor = AppColors.performanceOrange;
    } else if (accuracyValue <= 85) {
      feedbackText = 'Good progress';
      progressColor = AppColors.subjectMathematics;
    } else {
      feedbackText = 'Strong performance';
      progressColor = AppColors.subjectChemistry;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subject name and percentage row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              subject,
              style: AppTextStyles.headerSmall.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              displayAccuracy,
              style: AppTextStyles.headerSmall.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: accuracyValue / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 6),
        // Feedback text
        Text(
          feedbackText,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textLight,
            fontSize: 13,
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

  Widget _buildWeekTracker(DailyQuizProvider provider) {
    final streak = provider.summary?['streak'] as Map<String, dynamic>? ?? {};
    final practiceDays = streak['practice_days'] as Map<String, dynamic>? ?? {};
    
    // Get practice status for each day of this week (Monday to Sunday)
    final now = DateTime.now();
    final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    // Calculate Monday of current week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    
    final dayStatus = List.generate(7, (index) {
      final day = monday.add(Duration(days: index));
      final dayStr = DateFormat('yyyy-MM-dd').format(day);
      return practiceDays?[dayStr] != null;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This Week',
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDays.asMap().entries.map((entry) {
            final index = entry.key;
            final day = entry.value;
            final practiced = dayStatus[index];
            final isToday = index == (now.weekday - 1);
            
            return Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppColors.primaryPurple
                        : (practiced ? AppColors.successGreen : AppColors.borderGray),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: practiced && !isToday
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : (isToday
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppColors.textLight,
                                  shape: BoxShape.circle,
                                ),
                              )),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  day,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

