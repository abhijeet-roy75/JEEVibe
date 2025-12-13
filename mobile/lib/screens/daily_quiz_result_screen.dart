/// Daily Quiz Result Screen
/// Shows quiz completion summary with performance breakdown
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/daily_quiz_question.dart';
import '../services/api_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_user_service.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/priya_avatar.dart';
import 'daily_quiz_review_screen.dart';
import 'daily_quiz_home_screen.dart';

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

  String _getFormattedDate() {
    return DateFormat('EEEE, MMM d').format(DateTime.now());
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
  
  int get _wrongCount => _total - _score;
  
  List<dynamic> get _questions {
    final quiz = _quizResult?['quiz'];
    if (quiz == null) return [];
    final questions = quiz['questions'];
    return questions is List ? questions : [];
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    return '$minutes min';
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
    if (percentage >= 0.8) return AppColors.successGreen.withOpacity(0.1);
    if (percentage >= 0.6) return AppColors.warningAmber.withOpacity(0.1);
    return AppColors.errorRed.withOpacity(0.1);
  }

  IconData _getPerformanceIcon(int correct, int total) {
    final percentage = total > 0 ? (correct / total) : 0.0;
    if (percentage >= 0.8) return Icons.check_circle;
    if (percentage >= 0.6) return Icons.thumb_up;
    return Icons.error_outline;
  }

  String _getPriyaMaamFeedback() {
    final accuracy = _accuracy;
    final wrongCount = _wrongCount;
    
    if (accuracy >= 0.8) {
      return "Excellent work! You're mastering these concepts. Keep up the momentum! 🎉";
    } else if (accuracy >= 0.6) {
      return "Good job! You're making progress. Focus on the topics you got wrong to improve further! 💪";
    } else if (wrongCount > 0) {
      final weakTopic = _getPerformanceByTopic().entries
          .where((e) {
            final total = e.value['total'];
            final correct = e.value['correct'];
            if (total is! int || correct is! int) return false;
            return total > 0 && (correct / total) < 0.5;
          })
          .map((e) => e.key)
          .firstOrNull;
      
      if (weakTopic != null) {
        return "Great effort! Let's focus more on $weakTopic next. You're improving—keep it up! 🎯";
      }
      return "Don't worry! Review the mistakes and understand the concepts. You'll do better next time! 📚";
    }
    return "Keep practicing! Every mistake is a learning opportunity. Review the explanations carefully! 🌟";
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
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi ${_getUserName()}! 👋',
                    style: AppTextStyles.headerWhite.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getFormattedDate(),
                    style: AppTextStyles.bodyWhite.copyWith(fontSize: 14),
                  ),
                ],
              ),
              Text(
                'JEEVibe',
                style: AppTextStyles.headerWhite.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quiz Complete!',
                      style: AppTextStyles.headerMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Excellent effort today',
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
                  color: AppColors.warningAmber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, 
                        color: AppColors.warningAmber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '6-day streak!',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '$_score/$_total',
                    style: AppTextStyles.headerLarge.copyWith(
                      color: AppColors.primaryPurple,
                      fontSize: 28,
                    ),
                  ),
                ],
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.borderGray,
              ),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, 
                      color: AppColors.primaryPurple, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_totalTimeSeconds),
                    style: AppTextStyles.headerLarge.copyWith(
                      color: AppColors.primaryPurple,
                      fontSize: 28,
                    ),
                  ),
                ],
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.borderGray,
              ),
              Row(
                children: [
                  const Icon(Icons.trending_up, 
                      color: AppColors.primaryPurple, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${(_accuracy * 100).toInt()}%',
                    style: AppTextStyles.headerLarge.copyWith(
                      color: AppColors.primaryPurple,
                      fontSize: 28,
                    ),
                  ),
                ],
              ),
            ],
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
            color: Colors.black.withOpacity(0.05),
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
                      color: color.withOpacity(0.2),
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
            color: Colors.black.withOpacity(0.05),
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
          // Review Mistakes button
          if (_wrongCount > 0)
            _buildActionButton(
              icon: Icons.close,
              iconColor: AppColors.errorRed,
              label: 'Review Mistakes ($_wrongCount)',
              backgroundColor: AppColors.errorRed,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DailyQuizReviewScreen(
                      quizId: widget.quizId,
                      filterType: 'wrong',
                    ),
                  ),
                );
              },
            ),
          if (_wrongCount > 0) const SizedBox(height: 12),
          // Review All Questions button
          _buildActionButton(
            icon: Icons.check_circle,
            iconColor: AppColors.successGreen,
            label: 'Review All Questions ($_total)',
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
          // Back to Dashboard button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.ctaGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const DailyQuizHomeScreen()),
                    (route) => false,
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Text(
                    'Back to Dashboard',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
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
  }) {
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
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.chevron_right, color: Colors.white, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

