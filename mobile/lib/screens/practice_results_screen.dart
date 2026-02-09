/// Practice Results Screen - Matches design: 13 Practice Results Summary.png
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../models/snap_data_model.dart';
import '../providers/app_state_provider.dart';
import '../widgets/priya_avatar.dart';
import '../widgets/app_header.dart';
import 'camera_screen.dart';
import 'review_questions_screen.dart';
import 'daily_limit_screen.dart';
import 'main_navigation_screen.dart';

class PracticeResultsScreen extends StatelessWidget {
  final PracticeSessionResult sessionResult;

  const PracticeResultsScreen({
    super.key,
    required this.sessionResult,
  });

  @override
  Widget build(BuildContext context) {
    final hasIncorrect = sessionResult.questionResults.any((q) => !q.isCorrect);
    final minutesSpent = (sessionResult.timeSpentSeconds / 60).toStringAsFixed(1);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Column(
                  children: [
                    SizedBox(height: AppSpacing.space24),
                    _buildStatsRow(minutesSpent),
                    SizedBox(height: AppSpacing.space24),
                    _buildTopicMastery(),
                    SizedBox(height: AppSpacing.space24),
                    _buildPriyaMaamCard(),
                    SizedBox(height: AppSpacing.space24),
                    _buildQuestionBreakdown(context),
                    SizedBox(height: AppSpacing.space32),
                    _buildBackButton(context),
                    SizedBox(height: AppSpacing.space32),
                  ],
                ),
              ),
            ),
            _buildBottomBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppHeader(
      title: Text(
        'Good Effort!',
        style: AppTextStyles.headerWhite.copyWith(fontSize: 20),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        'You completed all 3 practice questions',
        style: AppTextStyles.bodyWhite.copyWith(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
      ),
      topPadding: 20,
      bottomPadding: 12,
    );
  }

  Widget _buildStatsRow(String minutes) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                Text(
                  '${sessionResult.score}/${sessionResult.total}',
                  style: AppTextStyles.headerLarge.copyWith(
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Correct',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.warningBackground.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
              border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  '${sessionResult.accuracy.toStringAsFixed(0)}%',
                  style: AppTextStyles.headerLarge.copyWith(
                    fontSize: 32,
                    color: AppColors.warningAmber,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Accuracy',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                Text(
                  minutes,
                  style: AppTextStyles.headerLarge.copyWith(
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Minutes',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopicMastery() {
    // Use session accuracy directly as the mastery indicator
    final accuracy = sessionResult.accuracy.round();

    // Determine color based on accuracy
    final Color progressColor;
    final Color textColor;
    if (accuracy >= 70) {
      progressColor = AppColors.successGreen;
      textColor = AppColors.successGreen;
    } else if (accuracy >= 40) {
      progressColor = AppColors.warningAmber;
      textColor = AppColors.warningAmber;
    } else {
      progressColor = AppColors.errorRed;
      textColor = AppColors.errorRed;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Session Accuracy', style: AppTextStyles.labelMedium),
              Text(
                '$accuracy%',
                style: AppTextStyles.labelSmall.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: accuracy / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: progressColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0%',
                style: AppTextStyles.bodySmall,
              ),
              Text(
                '${sessionResult.score}/${sessionResult.total} correct',
                style: AppTextStyles.labelSmall.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '100%',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriyaMaamCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.priyaCardGradient,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PriyaAvatar(size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Priya Ma\'am',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF9333EA),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getFeedbackMessage(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: const Color(0xFF6B21A8),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getFeedbackMessage() {
    final percentage = sessionResult.accuracy.round();
    
    if (percentage == 100) {
      return "Perfect score! You've mastered this concept. Keep up the excellent work! 🌟";
    } else if (percentage >= 67) {
      return "Great progress! You're solid on the basics. Let's work on advanced applications with multiple forces. You're almost there! 💪";
    } else {
      return "You're making progress! Review the concepts and try similar problems. Practice makes perfect!";
    }
  }

  Widget _buildQuestionBreakdown(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt, color: AppColors.primaryPurple, size: 20),
              const SizedBox(width: 8),
              Text('Question Breakdown', style: AppTextStyles.labelMedium),
            ],
          ),
          const SizedBox(height: 16),
          ...sessionResult.questionResults.asMap().entries.map((entry) {
            return _buildQuestionItem(context, entry.value, entry.key);
          }),
        ],
      ),
    );
  }

  Widget _buildQuestionItem(BuildContext context, QuestionResult result, int index) {
    final levels = ['Basic Level', 'Intermediate Level', 'Advanced Level'];

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.isCorrect ? Icons.check_circle : Icons.cancel,
                color: result.isCorrect ? AppColors.successGreen : AppColors.errorRed,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question ${result.questionNumber}',
                      style: AppTextStyles.labelMedium,
                    ),
                    Text(
                      levels[index],
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Your answer',
                    style: AppTextStyles.bodySmall,
                  ),
                  Text(
                    result.userAnswer.isEmpty || result.userAnswer == ''
                        ? 'Skipped'
                        : (result.isCorrect 
                            ? result.userAnswer
                            : '${result.userAnswer} → ${result.correctAnswer}'),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: result.userAnswer.isEmpty || result.userAnswer == ''
                          ? AppColors.textLight
                          : (result.isCorrect ? AppColors.successGreen : AppColors.errorRed),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: AppColors.textLight),
              const SizedBox(width: 6),
              Text(
                '${result.timeSpentSeconds}s',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              // Navigate to review screen, starting with this specific question
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ReviewQuestionsScreen(
                    sessionResult: sessionResult,
                    initialQuestionIndex: index,
                  ),
                ),
              );
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Review Solution',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: AppColors.primaryPurple,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () {
          // Navigate to main home screen with bottom navigation
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
            (route) => false,
          );
        },
        icon: const Icon(Icons.home_outlined),
        label: const Text('Back to Dashboard'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        gradient: AppColors.ctaGradient,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.military_tech,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Keep going! You\'re getting there! 💪',
              style: AppTextStyles.labelMedium.copyWith(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
