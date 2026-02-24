/// Shareable Subject Mastery Card Widget
/// A branded widget designed for screenshot capture and sharing subject mastery
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../models/analytics_data.dart';

class ShareableSubjectMasteryCard extends StatelessWidget {
  final String studentName;
  final SubjectMasteryDetails masteryDetails;

  const ShareableSubjectMasteryCard({
    super.key,
    required this.studentName,
    required this.masteryDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380, // Fixed width for consistent screenshots
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with subject branding
          _buildHeader(),
          const SizedBox(height: 20),

          // Overall stats
          _buildOverallStats(),
          const SizedBox(height: 16),

          // Mastery breakdown
          _buildMasteryBreakdown(),
          const SizedBox(height: 16),

          // Top chapters (max 5)
          _buildTopChapters(),
          const SizedBox(height: 16),

          // Footer with branding
          _buildFooter(),
        ],
      ),
    );
  }

  Color get _subjectColor {
    switch (masteryDetails.subject.toLowerCase()) {
      case 'physics':
        return AppColors.infoBlue;
      case 'chemistry':
        return AppColors.successGreen;
      case 'mathematics':
      case 'maths':
        return AppColors.primaryPurple;
      default:
        return AppColors.primaryPurple;
    }
  }

  String get _subjectEmoji {
    switch (masteryDetails.subject.toLowerCase()) {
      case 'physics':
        return '⚡';
      case 'chemistry':
        return '🧪';
      case 'mathematics':
      case 'maths':
        return '📐';
      default:
        return '📚';
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _subjectColor,
            _subjectColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                _subjectEmoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${masteryDetails.subjectName} Mastery',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (studentName.isNotEmpty)
                  Text(
                    studentName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStats() {
    // Calculate overall accuracy from chapters (not percentile)
    int totalCorrect = 0;
    int totalQuestions = 0;
    for (final chapter in masteryDetails.chapters) {
      totalCorrect += chapter.correct;
      totalQuestions += chapter.total;
    }
    final accuracy = totalQuestions > 0
        ? (totalCorrect / totalQuestions * 100).round()
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _subjectColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _subjectColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Accuracy (not percentile)
          Expanded(
            child: Column(
              children: [
                Text(
                  '$accuracy%',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _subjectColor,
                  ),
                ),
                Text(
                  'Accuracy',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: _subjectColor.withValues(alpha: 0.3),
          ),
          // Status
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: masteryDetails.status.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    masteryDetails.status.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: masteryDetails.status.color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Status',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: _subjectColor.withValues(alpha: 0.3),
          ),
          // Chapters
          Expanded(
            child: Column(
              children: [
                Text(
                  '${masteryDetails.chaptersTested}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _subjectColor,
                  ),
                ),
                Text(
                  'Chapters',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasteryBreakdown() {
    final summary = masteryDetails.summary;
    final total = summary.mastered + summary.growing + summary.focus;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mastery Breakdown',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 10),
          _buildMasteryBar(
            label: 'Mastered',
            count: summary.mastered,
            total: total,
            color: AppColors.successGreen,
            icon: Icons.check_circle,
          ),
          const SizedBox(height: 8),
          _buildMasteryBar(
            label: 'Growing',
            count: summary.growing,
            total: total,
            color: AppColors.warningAmber,
            icon: Icons.trending_up,
          ),
          const SizedBox(height: 8),
          _buildMasteryBar(
            label: 'Focus',
            count: summary.focus,
            total: total,
            color: AppColors.errorRed,
            icon: Icons.flag,
          ),
        ],
      ),
    );
  }

  Widget _buildMasteryBar({
    required String label,
    required int count,
    required int total,
    required Color color,
    required IconData icon,
  }) {
    final percentage = total > 0 ? count / total : 0.0;

    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,  // 12px iOS, 10.56px Android (was 11)
              fontWeight: FontWeight.w500,
              color: AppColors.textMedium,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage.clamp(0.0, 1.0),
                child: Container(color: color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 20,
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,  // 12px iOS, 10.56px Android (was 11)
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildTopChapters() {
    // Show top 5 chapters sorted by accuracy (highest first)
    final sortedChapters = List<ChapterMastery>.from(masteryDetails.chapters)
      ..sort((a, b) => b.accuracy.compareTo(a.accuracy));
    final topChapters = sortedChapters.take(5).toList();

    if (topChapters.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Chapters',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 10),
          ...topChapters.map((chapter) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildChapterItem(chapter),
          )),
        ],
      ),
    );
  }

  Widget _buildChapterItem(ChapterMastery chapter) {
    final icon = _getStatusIcon(chapter.status);
    final color = chapter.status.color;

    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            chapter.chapterName,
            style: const TextStyle(
              fontSize: 12,  // 12px iOS, 10.56px Android (was 11)
              color: AppColors.textMedium,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${chapter.accuracy.round()}%',
          style: TextStyle(
            fontSize: 12,  // 12px iOS, 10.56px Android (was 11)
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(MasteryStatus status) {
    switch (status) {
      case MasteryStatus.mastered:
        return Icons.check_circle;
      case MasteryStatus.growing:
        return Icons.trending_up;
      case MasteryStatus.focus:
        return Icons.flag;
    }
  }

  Widget _buildFooter() {
    // Format timestamp with 12-hour format and AM/PM
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final timestamp = '${now.day}/${now.month}/${now.year} $hour:${now.minute.toString().padLeft(2, '0')} $amPm';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.ctaGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.rocket_launch, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'My Progress on JEEVibe',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            timestamp,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
