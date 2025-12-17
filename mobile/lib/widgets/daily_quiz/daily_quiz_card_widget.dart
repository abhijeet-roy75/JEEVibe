/// Daily Quiz Card Widget
/// Reusable widget for the "Daily Quiz Ready!" card
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class DailyQuizCardWidget extends StatelessWidget {
  final bool hasActiveQuiz;
  final bool canStartQuiz;
  final VoidCallback? onStartQuiz;
  final int? questionCount; // C8: Dynamic quiz size
  final int? estimatedTimeMinutes; // C8: Dynamic time estimate

  const DailyQuizCardWidget({
    super.key,
    this.hasActiveQuiz = false,
    this.canStartQuiz = true,
    this.onStartQuiz,
    this.questionCount,
    this.estimatedTimeMinutes,
  });

  @override
  Widget build(BuildContext context) {
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt,
                  color: AppColors.warningAmber,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Quiz Ready!',
                      style: AppTextStyles.headerSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      questionCount != null
                          ? '$questionCount questions across your growth areas'
                          : 'Questions across your growth areas',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.secondaryPink.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.track_changes,
                  color: AppColors.secondaryPink,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text(
                estimatedTimeMinutes != null
                    ? 'Est. time: $estimatedTimeMinutes min'
                    : 'Est. time: 15 min',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Personalized for you',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: canStartQuiz
                ? Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.ctaGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onStartQuiz,
                        borderRadius: BorderRadius.circular(12),
                        child: Center(
                          child: Text(
                            hasActiveQuiz ? 'Continue Quiz' : 'Start Today\'s Quiz',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.borderGray,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: AppColors.borderGray,
                    ),
                    child: Text(
                      'Completed for Today',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

