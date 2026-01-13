/// Daily Quiz Result Screen
/// Shows quiz completion summary with performance breakdown
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_user_service.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/priya_avatar.dart';
import '../widgets/buttons/gradient_button.dart';
import 'daily_quiz_review_screen.dart';
import 'assessment_intro_screen.dart';
import 'analytics_screen.dart';

class DailyQuizResultScreen extends StatefulWidget {
  final String quizId;
  final Map<String, dynamic>? resultData;

  const DailyQuizResultScreen({
    super.key,
    required this.quizId,
    this.resultData,
  });

  @override
  State<DailyQuizResultScreen> createState() => _DailyQuizResultScreenState();
}

class _DailyQuizResultScreenState extends State<DailyQuizResultScreen> {
  Map<String, dynamic>? _quizResult;
  UserProfile? _userProfile;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _streak;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();
      
      if (token == null) {
        setState(() {
          _error = 'Authentication required';
          _isLoading = false;
        });
        return;
      }

      // Load user profile
      final firestoreService = Provider.of<FirestoreUserService>(context, listen: false);
      final user = authService.currentUser;
      if (user != null) {
        final profile = await firestoreService.getUserProfile(user.uid);
        if (mounted) {
          setState(() {
            _userProfile = profile;
          });
        }
      }

      // Load quiz result
      final result = await ApiService.getDailyQuizResult(
        authToken: token,
        quizId: widget.quizId,
      );

      if (mounted) {
        setState(() {
          _quizResult = result;
          _streak = result['streak'] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _getUserName() {
    return _userProfile?.firstName ?? 'Student';
  }

  String _getStreakText() {
    final currentStreak = _streak?['current_streak'] as int? ?? 0;
    if (currentStreak <= 0) {
      return 'Start your streak!';
    } else if (currentStreak == 1) {
      return '1-day streak!';
    } else {
      return '$currentStreak-day streak!';
    }
  }

  // C5: Add null-safe access with proper type checking
  int get _score {
    final quiz = _quizResult?['quiz'];
    if (quiz == null) return 0;
    final score = quiz['score'];
    return score is int ? score : (score is num ? score.toInt() : 0);
  }
  
  int get _total {
    final quiz = _quizResult?['quiz'];
    if (quiz == null) return 0;
    final total = quiz['total'];
    return total is int ? total : (total is num ? total.toInt() : 0);
  }
  
  double get _accuracy {
    final quiz = _quizResult?['quiz'];
    if (quiz == null) return 0.0;
    final accuracy = quiz['accuracy'];
    return accuracy is double ? accuracy : (accuracy is num ? accuracy.toDouble() : 0.0);
  }
  
  int get _totalTimeSeconds {
    final quiz = _quizResult?['quiz'];
    if (quiz == null) return 0;
    final time = quiz['total_time_seconds'];
    return time is int ? time : (time is num ? time.toInt() : 0);
  }
  
  List<dynamic> get _questions {
    final quiz = _quizResult?['quiz'];
    if (quiz == null) return [];
    final questions = quiz['questions'];
    return questions is List ? questions : [];
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;

    if (minutes > 0 && secs > 0) {
      return '${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${secs}s';
    }
  }

  Map<String, Map<String, dynamic>> _getPerformanceByTopic() {
    final Map<String, Map<String, dynamic>> topicPerformance = {};
    
    for (var q in _questions) {
      if (q is! Map<String, dynamic>) continue; // C5: Type check
      final chapter = q['chapter'] as String? ?? 'Unknown';
      final subject = q['subject'] as String? ?? 'Unknown';
      final isCorrect = q['is_correct'] is bool ? q['is_correct'] as bool : false;
      
      if (!topicPerformance.containsKey(chapter)) {
        topicPerformance[chapter] = {
          'subject': subject,
          'correct': 0,
          'total': 0,
        };
      }
      
      topicPerformance[chapter]!['total'] = (topicPerformance[chapter]!['total'] as int) + 1;
      if (isCorrect) {
        topicPerformance[chapter]!['correct'] = (topicPerformance[chapter]!['correct'] as int) + 1;
      }
    }
    
    return topicPerformance;
  }

  String _getPerformanceLabel(int correct, int total) {
    final percentage = total > 0 ? (correct / total) : 0.0;
    if (percentage >= 0.8) return 'Excellent!';
    if (percentage >= 0.6) return 'Good job!';
    if (percentage >= 0.4) return 'Keep practicing';
    return 'Needs work';
  }

  Color _getPerformanceColor(int correct, int total) {
    final percentage = total > 0 ? (correct / total) : 0.0;
    if (percentage >= 0.8) return AppColors.successGreen;
    if (percentage >= 0.6) return AppColors.warningAmber;
    return AppColors.errorRed;
  }

  Color _getPerformanceBackgroundColor(int correct, int total) {
    final percentage = total > 0 ? (correct / total) : 0.0;
    if (percentage >= 0.8) return AppColors.successGreen.withValues(alpha: 0.1);
    if (percentage >= 0.6) return AppColors.warningAmber.withValues(alpha: 0.1);
    return AppColors.errorRed.withValues(alpha: 0.1);
  }

  IconData _getPerformanceIcon(int correct, int total) {
    final percentage = total > 0 ? (correct / total) : 0.0;
    if (percentage >= 0.8) return Icons.check_circle;
    if (percentage >= 0.6) return Icons.thumb_up;
    return Icons.error_outline;
  }

  /// Get emoji for score card based on performance
  String _getScoreEmoji() {
    switch (_getPerformanceTier()) {
      case 'excellent':
        return '🏆';
      case 'good':
        return '⭐';
      case 'average':
        return '📊';
      case 'struggling':
        return '📚';
      case 'tough_day':
        return '💪';
      default:
        return '📝';
    }
  }

  /// Get title for score card based on performance
  String _getScoreTitle() {
    switch (_getPerformanceTier()) {
      case 'excellent':
        return 'Excellent!';
      case 'good':
        return 'Good Job!';
      case 'average':
        return 'Keep Going!';
      case 'struggling':
        return 'Nice Try!';
      case 'tough_day':
        return 'Keep Learning!';
      default:
        return 'Quiz Complete';
    }
  }

  /// Get subtitle for score card based on performance
  String _getScoreSubtitle() {
    switch (_getPerformanceTier()) {
      case 'excellent':
        return 'You nailed it!';
      case 'good':
        return 'Solid performance';
      case 'average':
        return 'Room to improve';
      case 'struggling':
        return 'Every step counts';
      case 'tough_day':
        return 'Tomorrow is fresh';
      default:
        return 'Keep practicing';
    }
  }

  /// Get performance tier based on score out of 10
  /// Returns: 'excellent', 'good', 'average', 'struggling', or 'tough_day'
  String _getPerformanceTier() {
    // Normalize score to 10-point scale
    final scoreOutOf10 = _total > 0 ? (_score / _total) * 10 : 0;

    if (scoreOutOf10 >= 9) return 'excellent';
    if (scoreOutOf10 >= 7) return 'good';
    if (scoreOutOf10 >= 5) return 'average';
    if (scoreOutOf10 >= 3) return 'struggling';
    return 'tough_day';
  }

  /// Get the weakest topic from quiz results
  String? _getWeakTopic() {
    final topics = _getPerformanceByTopic();
    String? weakestTopic;
    double lowestAccuracy = 1.0;

    for (final entry in topics.entries) {
      final total = entry.value['total'] as int;
      final correct = entry.value['correct'] as int;
      if (total > 0) {
        final accuracy = correct / total;
        if (accuracy < lowestAccuracy) {
          lowestAccuracy = accuracy;
          weakestTopic = entry.key;
        }
      }
    }

    return weakestTopic;
  }

  /// Get the strongest topic from quiz results
  String? _getStrongTopic() {
    final topics = _getPerformanceByTopic();
    String? strongestTopic;
    double highestAccuracy = 0.0;

    for (final entry in topics.entries) {
      final total = entry.value['total'] as int;
      final correct = entry.value['correct'] as int;
      if (total > 0) {
        final accuracy = correct / total;
        if (accuracy > highestAccuracy) {
          highestAccuracy = accuracy;
          strongestTopic = entry.key;
        }
      }
    }

    return strongestTopic;
  }

  /// Priya Ma'am's feedback based on performance tier
  /// Framework: Never demotivate, always forward-looking
  /// Tone: Supportive elder sister who believes in you
  String _getPriyaMaamFeedback() {
    final tier = _getPerformanceTier();
    final name = _getUserName();
    final weakTopic = _getWeakTopic();
    final strongTopic = _getStrongTopic();
    final currentStreak = _streak?['current_streak'] as int? ?? 0;

    switch (tier) {
      case 'excellent':
        // 9-10/10: Celebratory + Challenge
        return "Superb, $name! 🌟 You nailed it today - your hard work is showing. Ready for a tougher challenge tomorrow? Let's push your limits!";

      case 'good':
        // 7-8/10: Warm praise + Growth
        if (strongTopic != null) {
          return "Great effort today, $name! 💪 You're getting stronger in $strongTopic. Keep this momentum going!";
        }
        return "Great effort today, $name! 💪 You're building solid momentum. Keep this up!";

      case 'average':
        // 5-6/10: Encouraging + Specific
        if (weakTopic != null) {
          return "Good practice today, $name. Some tricky ones in there! $weakTopic needs a bit more attention - we'll tackle it together. You've got this! 🎯";
        }
        return "Good practice today, $name. Some tricky questions in there! Review the concepts and you'll do even better. You've got this! 🎯";

      case 'struggling':
        // 3-4/10: Compassionate + Supportive
        if (currentStreak >= 3) {
          return "Tough quiz, $name - but look, $currentStreak days straight! That consistency matters more than any single score. Tomorrow we'll revisit these topics step by step. 🌱";
        }
        if (weakTopic != null) {
          return "Tough topics today, $name - I know these weren't easy. What matters is you showed up and practiced. Tomorrow, we'll revisit $weakTopic with simpler problems first. One step at a time! 🌱";
        }
        return "Tough topics today, $name - I know these weren't easy. What matters is you showed up and practiced. One step at a time! 🌱";

      case 'tough_day':
        // 0-2/10: Gentle + Normalizing
        return "Hey $name, rough day - it happens to everyone, even toppers. These topics are genuinely challenging. Take a break, and tomorrow we start fresh with the basics. I believe in you. ❤️";

      default:
        return "Keep practicing, $name! Every question is a learning opportunity. 📚";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    if (_error != null || _quizResult == null) {
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
                Text(_error ?? 'Failed to load quiz results', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final topicPerformance = _getPerformanceByTopic();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // Purple gradient header
          _buildHeader(),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Quiz summary card
                  _buildQuizSummaryCard(),
                  const SizedBox(height: 16),
                  // Performance by topic
                  _buildPerformanceByTopic(topicPerformance),
                  const SizedBox(height: 16),
                  // Priya Ma'am feedback
                  _buildPriyaMaamFeedback(),
                  const SizedBox(height: 16),
                  // Action buttons
                  _buildActionButtons(),
                  // Bottom padding to account for Android navigation bar (using viewPadding for system UI)
                  SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get header title based on performance tier
  String _getHeaderTitle() {
    switch (_getPerformanceTier()) {
      case 'excellent':
        return 'Outstanding! 🌟';
      case 'good':
        return 'Well Done! 💪';
      case 'average':
        return 'Quiz Complete! 🎯';
      case 'struggling':
        return 'Quiz Complete 🌱';
      case 'tough_day':
        return 'Quiz Complete';
      default:
        return 'Quiz Complete';
    }
  }

  /// Get header subtitle based on performance tier
  String _getHeaderSubtitle() {
    switch (_getPerformanceTier()) {
      case 'excellent':
        return 'You crushed it today!';
      case 'good':
        return 'Solid performance!';
      case 'average':
        return 'Good practice session';
      case 'struggling':
        return 'Every attempt counts';
      case 'tough_day':
        return 'Tomorrow is a new day';
      default:
        return 'Keep learning';
    }
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
              // Logo on left (circular)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/JEEVibeLogo_240.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.white,
                        child: const Icon(
                          Icons.school,
                          color: Color(0xFF9333EA),
                          size: 24,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Message centered - performance-aware
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _getHeaderTitle(),
                      style: AppTextStyles.headerWhite.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getHeaderSubtitle(),
                      style: AppTextStyles.bodyWhite.copyWith(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Empty space on right to balance (same width as logo + spacing)
              const SizedBox(width: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizSummaryCard() {
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
        children: [
          Row(
            children: [
              Text(_getScoreEmoji(), style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getScoreTitle(),
                      style: AppTextStyles.headerMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getScoreSubtitle(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, 
                        color: AppColors.warningAmber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _getStreakText(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.warningAmber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Stats with dividers - use IntrinsicHeight to allow stretch cross-axis alignment
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Score
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_score/$_total',
                        style: AppTextStyles.headerLarge.copyWith(
                          color: AppColors.primaryPurple,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Score',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  color: AppColors.borderGray,
                ),
                // Time
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_outlined,
                              color: AppColors.primaryPurple, size: 18),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _formatTime(_totalTimeSeconds),
                              style: AppTextStyles.headerLarge.copyWith(
                                color: AppColors.primaryPurple,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Time',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  color: AppColors.borderGray,
                ),
                // Accuracy
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.trending_up,
                              color: AppColors.primaryPurple, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${(_accuracy * 100).toInt()}%',
                            style: AppTextStyles.headerLarge.copyWith(
                              color: AppColors.primaryPurple,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Accuracy',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textLight,
                        ),
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

  Widget _buildPerformanceByTopic(Map<String, Map<String, dynamic>> topicPerformance) {
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
            children: [
              const Icon(Icons.bar_chart, color: AppColors.primaryPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                'Performance by Topic',
                style: AppTextStyles.headerSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...topicPerformance.entries.map((entry) {
            final topic = entry.key;
            final data = entry.value;
            final correct = data['correct'] as int;
            final total = data['total'] as int;
            final subject = data['subject'] as String;
            final color = _getPerformanceColor(correct, total);
            final bgColor = _getPerformanceBackgroundColor(correct, total);
            final icon = _getPerformanceIcon(correct, total);
            final label = _getPerformanceLabel(correct, total);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$correct/$total correct',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subject,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.infoBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPriyaMaamFeedback() {
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PriyaAvatar(size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Priya Ma\'am\'s Feedback ✨',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getPriyaMaamFeedback(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Review All Questions button (has filter for mistakes built-in)
          _buildActionButton(
            icon: Icons.rate_review,
            iconColor: Colors.white,
            label: 'Review Questions ($_total)',
            backgroundColor: AppColors.primaryPurple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DailyQuizReviewScreen(
                    quizId: widget.quizId,
                    filterType: 'all',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // View Insights button
          _buildActionButton(
            icon: Icons.insights,
            iconColor: AppColors.primaryPurple,
            label: 'View Insights',
            backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.1),
            textColor: AppColors.primaryPurple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnalyticsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // Back to Dashboard button
          GradientButton(
            text: 'Back to Dashboard',
            onPressed: () {
              // Navigate to main home screen (AssessmentIntroScreen) where snap-and-solve card is
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AssessmentIntroScreen()),
                (route) => false, // Remove all routes, make AssessmentIntroScreen the new root
              );
            },
            size: GradientButtonSize.large,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color backgroundColor,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    final effectiveTextColor = textColor ?? Colors.white;
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: iconColor, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: effectiveTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.chevron_right, color: effectiveTextColor, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

