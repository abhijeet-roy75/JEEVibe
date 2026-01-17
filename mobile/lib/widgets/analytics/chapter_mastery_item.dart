// Chapter Mastery Item Widget
// Displays a chapter card with accuracy and inline sub-topic breakdown
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
    final hasSubtopics = chapter.subtopics.isNotEmpty;
    // Use backend-provided correct/total values (derived from subtopics as single source of truth)
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
                    // Sub-topics inline (if any)
                    if (hasSubtopics) ...[
                      const SizedBox(height: 10),
                      _buildSubtopicsInline(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtopicsInline() {
    // Sort subtopics by accuracy (lowest first to highlight weak areas)
    final sortedSubtopics = List<SubtopicAccuracy>.from(chapter.subtopics)
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: sortedSubtopics.map((subtopic) => _buildSubtopicChip(subtopic)).toList(),
    );
  }

  Widget _buildSubtopicChip(SubtopicAccuracy subtopic) {
    final Color chipColor;
    if (subtopic.accuracy >= 70) {
      chipColor = AppColors.success;
    } else if (subtopic.accuracy >= 40) {
      chipColor = AppColors.warning;
    } else {
      chipColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: chipColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Subtopic name (truncated if too long)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              subtopic.name,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textDark,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          // Accuracy with correct/total
          Text(
            '${subtopic.correct}/${subtopic.total}',
            style: AppTextStyles.caption.copyWith(
              color: chipColor,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact variant for list display
class ChapterMasteryItemCompact extends StatelessWidget {
  final String chapterName;
  final double percentile;
  final MasteryStatus status;
  final Color progressColor;

  const ChapterMasteryItemCompact({
    super.key,
    required this.chapterName,
    required this.percentile,
    required this.status,
    required this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Status indicator dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          // Chapter name
          Expanded(
            child: Text(
              chapterName,
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Percentage
          Text(
            '${percentile.toInt()}%',
            style: AppTextStyles.labelMedium.copyWith(
              color: progressColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
