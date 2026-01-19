// Chapter Mastery Item Widget
// Displays a chapter card with accuracy (subtopics hidden for now)
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/analytics_data.dart';

class ChapterMasteryItem extends StatelessWidget {
  final ChapterMastery chapter;
  final Color progressColor;

  const ChapterMasteryItem({
    super.key,
    required this.chapter,
    required this.progressColor,
  });

  Color get _accuracyColor {
    final accuracy = chapter.accuracy;
    if (accuracy >= 70) return AppColors.success;
    if (accuracy >= 40) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    // Use backend-provided correct/total values
    final correct = chapter.correct;
    final total = chapter.total;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored side bar based on accuracy
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: _accuracyColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Chapter name and accuracy
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            chapter.chapterName,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Accuracy badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _accuracyColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${chapter.accuracy.toInt()}%',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: _accuracyColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Questions correct
                    if (total > 0)
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: _accuracyColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$correct/$total correct',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textMedium,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    // Note: Subtopic display removed - keeping analytics at chapter level for now
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
