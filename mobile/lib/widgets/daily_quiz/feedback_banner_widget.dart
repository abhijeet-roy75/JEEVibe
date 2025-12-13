/// Feedback Banner Widget
/// Shows immediate feedback after answering a question
import 'package:flutter/material.dart';
import '../../models/daily_quiz_question.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class FeedbackBannerWidget extends StatelessWidget {
  final AnswerFeedback feedback;
  final int timeTakenSeconds;

  const FeedbackBannerWidget({
    super.key,
    required this.feedback,
    required this.timeTakenSeconds,
  });

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '${minutes}:${secs.toString().padLeft(2, '0')}';
    }
    return '${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: feedback.isCorrect ? AppColors.successGreen : AppColors.errorRed,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                feedback.isCorrect ? Icons.check : Icons.close,
                color: feedback.isCorrect ? AppColors.successGreen : AppColors.errorRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feedback.isCorrect ? 'Correct Answer!' : 'Incorrect Answer',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feedback.isCorrect
                        ? 'Well done! You got this right.'
                        : 'Your answer: ${feedback.studentAnswer?.toUpperCase() ?? 'N/A'} • Correct: ${feedback.correctAnswer?.toUpperCase() ?? 'N/A'}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  _formatTime(timeTakenSeconds),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

