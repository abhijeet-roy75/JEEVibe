/// Chapter Mastery Item Widget
/// Displays a chapter row with progress bar and status badge
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

  @override
  Widget build(BuildContext context) {
    final statusColor = chapter.status.color;
    
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
            // Colored side bar - stretches to full height via IntrinsicHeight
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Chapter name and status badge
                    Row(
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
                        _buildStatusBadge(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress bar and percentage
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: chapter.percentile / 100,
                              backgroundColor: AppColors.borderGray,
                              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 45,
                          child: Text(
                            '${chapter.percentile.toInt()}%',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chapter.status.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        chapter.status.displayName,
        style: AppTextStyles.labelSmall.copyWith(
          color: chapter.status.color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
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
