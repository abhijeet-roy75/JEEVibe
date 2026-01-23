/// Shareable Analytics Overview Card Widget
/// A branded widget designed for screenshot capture and sharing analytics progress
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../models/analytics_data.dart';

class ShareableAnalyticsOverviewCard extends StatelessWidget {
  final String studentName;
  final AnalyticsStats stats;
  final List<SubjectProgress> subjectProgress;
  final WeeklyActivity? weeklyActivity;

  const ShareableAnalyticsOverviewCard({
    super.key,
    required this.studentName,
    required this.stats,
    required this.subjectProgress,
    this.weeklyActivity,
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
          // Header with JEEVibe branding
          _buildHeader(),
          const SizedBox(height: 20),

          // Stats summary
          _buildStatsRow(),
          const SizedBox(height: 20),

          // Subject progress
          _buildSubjectProgress(),
          const SizedBox(height: 16),

          // Weekly activity mini chart (if available)
          if (weeklyActivity != null) ...[
            _buildWeeklyActivity(),
            const SizedBox(height: 16),
          ],

          // Footer with branding
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.ctaGradient,
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
            child: const Center(
              child: Text(
                'J',
                style: TextStyle(
                  color: AppColors.primaryPurple,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My JEE Progress',
                  style: TextStyle(
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

  Widget _buildStatsRow() {
    // Calculate overall accuracy
    int totalCorrect = 0;
    int totalQuestions = 0;
    for (final subject in subjectProgress) {
      totalCorrect += subject.correct;
      totalQuestions += subject.total;
    }
    final overallAccuracy = totalQuestions > 0
        ? ((totalCorrect / totalQuestions) * 100).round()
        : 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            icon: Icons.local_fire_department,
            value: '${stats.currentStreak}',
            label: 'Day Streak',
            color: AppColors.primaryPurple,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            icon: Icons.check_circle,
            value: '${stats.questionsSolved}',
            label: 'Questions',
            color: AppColors.warningAmber,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            icon: Icons.trending_up,
            value: '$overallAccuracy%',
            label: 'Accuracy',
            color: AppColors.successGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectProgress() {
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
            'Subject Progress',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 10),
          ...subjectProgress.map((subject) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildSubjectBar(subject),
          )),
        ],
      ),
    );
  }

  Widget _buildSubjectBar(SubjectProgress subject) {
    final displayName = _getSubjectDisplayName(subject.subject);
    // Use accuracy instead of percentile for sharing
    final accuracy = subject.accuracy ?? 0;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            displayName,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textMedium,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (accuracy / 100).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: subject.progressColor,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '$accuracy%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: subject.progressColor,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _getSubjectDisplayName(String subject) {
    switch (subject.toLowerCase()) {
      case 'physics':
        return 'Physics';
      case 'chemistry':
        return 'Chemistry';
      case 'mathematics':
        return 'Maths';
      default:
        return subject;
    }
  }

  Widget _buildWeeklyActivity() {
    if (weeklyActivity == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'This Week',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMedium,
                ),
              ),
              Text(
                '${weeklyActivity!.totalQuestions} questions',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weeklyActivity!.week.map((day) {
              final hasActivity = day.questions > 0;
              return Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: hasActivity
                          ? AppColors.primaryPurple
                          : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: hasActivity
                            ? AppColors.primaryPurple
                            : AppColors.borderLight,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: hasActivity
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getDayLabel(day.date),
                    style: TextStyle(
                      fontSize: 9,
                      color: hasActivity
                          ? AppColors.textMedium
                          : AppColors.textLight,
                      fontWeight: hasActivity
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getDayLabel(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    } catch (e) {
      return '';
    }
  }

  Widget _buildFooter() {
    // Format timestamp
    final now = DateTime.now();
    final timestamp = '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

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
                      'Tracked with JEEVibe',
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
