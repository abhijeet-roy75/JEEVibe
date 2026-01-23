/// Shareable Journey Card Widget
/// A branded widget designed for screenshot capture and sharing journey progress
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class ShareableJourneyCard extends StatelessWidget {
  final String studentName;
  final int questionsPracticed;
  final int nextMilestone;

  const ShareableJourneyCard({
    super.key,
    required this.studentName,
    required this.questionsPracticed,
    required this.nextMilestone,
  });

  @override
  Widget build(BuildContext context) {
    final achievementData = _getAchievementData();

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
          const SizedBox(height: 24),

          // Achievement badge
          _buildAchievementBadge(achievementData),
          const SizedBox(height: 20),

          // Questions count
          _buildQuestionsCount(),
          const SizedBox(height: 16),

          // Progress bar
          _buildProgressBar(),
          const SizedBox(height: 16),

          // Next milestone
          _buildNextMilestone(),
          const SizedBox(height: 24),

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
                  'My JEEVibe Journey',
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

  Widget _buildAchievementBadge(_AchievementData data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            data.color.withValues(alpha: 0.15),
            data.color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: data.color.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            data.emoji,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 8),
          Text(
            data.title,
            style: AppTextStyles.headerSmall.copyWith(
              color: data.color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsCount() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.menu_book,
              color: AppColors.primaryPurple,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              '$questionsPracticed',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'questions practiced',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    // Calculate progress to next milestone
    final previousMilestone = _getPreviousMilestone();
    final progress = nextMilestone > previousMilestone
        ? (questionsPracticed - previousMilestone) / (nextMilestone - previousMilestone)
        : 1.0;

    return Column(
      children: [
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.ctaGradient,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$previousMilestone',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textLight,
              ),
            ),
            Text(
              '$nextMilestone',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNextMilestone() {
    final remaining = nextMilestone - questionsPracticed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.infoBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.flag,
            color: AppColors.infoBlue,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Next milestone: $nextMilestone',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.infoBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (remaining > 0) ...[
            Text(
              ' (only $remaining more!)',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.infoBlue,
              ),
            ),
          ],
        ],
      ),
    );
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
                      'Join me on JEEVibe!',
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

  _AchievementData _getAchievementData() {
    if (questionsPracticed >= 300) {
      return _AchievementData(
        emoji: '👑',
        title: 'JEE Champion!',
        color: const Color(0xFFD4AF37), // Gold
      );
    } else if (questionsPracticed >= 200) {
      return _AchievementData(
        emoji: '🏆',
        title: 'JEE Warrior!',
        color: const Color(0xFFFF8C00), // Orange
      );
    } else if (questionsPracticed >= 100) {
      return _AchievementData(
        emoji: '🔥',
        title: 'On Fire!',
        color: const Color(0xFFFF4500), // Red-Orange
      );
    } else if (questionsPracticed >= 50) {
      return _AchievementData(
        emoji: '⭐',
        title: 'Rising Star!',
        color: const Color(0xFF9333EA), // Purple
      );
    } else if (questionsPracticed >= 25) {
      return _AchievementData(
        emoji: '💪',
        title: 'Building Momentum!',
        color: const Color(0xFF3B82F6), // Blue
      );
    } else if (questionsPracticed >= 10) {
      return _AchievementData(
        emoji: '🎯',
        title: 'Great Start!',
        color: const Color(0xFF10B981), // Green
      );
    } else {
      return _AchievementData(
        emoji: '🚀',
        title: 'Journey Begins!',
        color: AppColors.primaryPurple,
      );
    }
  }

  int _getPreviousMilestone() {
    const milestones = [0, 10, 25, 50, 100, 150, 200, 300, 500];
    for (int i = milestones.length - 1; i >= 0; i--) {
      if (questionsPracticed >= milestones[i]) {
        return milestones[i];
      }
    }
    return 0;
  }
}

class _AchievementData {
  final String emoji;
  final String title;
  final Color color;

  const _AchievementData({
    required this.emoji,
    required this.title,
    required this.color,
  });
}
