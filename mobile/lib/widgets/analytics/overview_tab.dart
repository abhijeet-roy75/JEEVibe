/// Overview Tab Widget
/// Displays analytics overview content
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/analytics_data.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../screens/assessment_intro_screen.dart';
import '../priya_avatar.dart';
import 'stat_card.dart';

class OverviewTab extends StatelessWidget {
  final AnalyticsOverview overview;

  const OverviewTab({
    super.key,
    required this.overview,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Priya Ma'am card at top per design
          _buildPriyaMaamCard(),
          const SizedBox(height: 20),
          // Stats grid (Streak, Qs Done, Mastered) - order per design
          _buildStatsGrid(),
          const SizedBox(height: 20),
          // Subject progress section
          _buildSubjectMasteryCard(),
          const SizedBox(height: 20),
          // Focus Areas section
          if (overview.focusAreas.isNotEmpty) ...[
            _buildFocusAreasCard(),
            const SizedBox(height: 20),
          ],
          // Back to Dashboard button
          _buildBackToDashboardButton(context),
          // Bottom padding to account for Android navigation bar
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 24),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        // Streak - purple background per design
        Expanded(
          child: StatCard(
            icon: Icons.local_fire_department,
            iconColor: AppColors.primaryPurple,
            iconBackgroundColor: AppColors.primaryPurple,
            value: '${overview.stats.currentStreak}',
            label: 'Streak',
          ),
        ),
        const SizedBox(width: 12),
        // Qs Done - orange/amber background per design
        Expanded(
          child: StatCard(
            icon: Icons.check_circle,
            iconColor: AppColors.warningAmber,
            iconBackgroundColor: AppColors.warningAmber,
            value: '${overview.stats.questionsSolved}',
            label: 'Qs Done',
          ),
        ),
        const SizedBox(width: 12),
        // Mastered - green background per design
        Expanded(
          child: StatCard(
            icon: Icons.emoji_events,
            iconColor: AppColors.successGreen,
            iconBackgroundColor: AppColors.successGreen,
            value: '${overview.stats.chaptersMastered}',
            label: 'Mastered',
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectMasteryCard() {
    final subjects = overview.orderedSubjectProgress;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              const Icon(Icons.menu_book, color: AppColors.successGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Subject Mastery',
                style: AppTextStyles.headerSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...subjects.map((subject) => _buildSubjectRow(subject)),
        ],
      ),
    );
  }

  Widget _buildSubjectRow(SubjectProgress subject) {
    final displayName = subject.subject.toLowerCase() == 'mathematics'
        ? 'Maths'
        : subject.displayName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Subject icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: subject.iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              subject.icon,
              color: subject.iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // Progress bar and label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: subject.percentile / 100,
                    backgroundColor: AppColors.borderGray,
                    valueColor: AlwaysStoppedAnimation<Color>(subject.progressColor),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Percentage
          Text(
            '${subject.percentile.toInt()}%',
            style: AppTextStyles.labelMedium.copyWith(
              color: subject.progressColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusAreasCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              const Icon(Icons.gps_fixed, color: AppColors.primaryPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                'Focus Areas',
                style: AppTextStyles.headerSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chips/capsules layout per design
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: overview.focusAreas.map((area) => _buildFocusAreaChip(area)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusAreaChip(FocusArea area) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        area.chapterName,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPriyaMaamCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardLightPurple,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                  'Priya Ma\'am',
                  style: AppTextStyles.priyaHeader.copyWith(
                    color: AppColors.primaryPurple,
                  ),
                ),
                const SizedBox(height: 4),
                _buildFormattedMessage(overview.priyaMaamMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedMessage(String message) {
    // Simple formatting for **bold** text
    final parts = message.split('**');
    return RichText(
      text: TextSpan(
        style: AppTextStyles.priyaMessage,
        children: parts.asMap().entries.map((entry) {
          final index = entry.key;
          final text = entry.value;
          if (index % 2 == 1) {
            // Odd indices are bold
            return TextSpan(
              text: text,
              style: AppTextStyles.priyaMessage.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryPurple,
              ),
            );
          } else {
            return TextSpan(text: text);
          }
        }).toList(),
      ),
    );
  }

  Widget _buildBackToDashboardButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GradientButton(
        text: 'Back to Dashboard',
        onPressed: () {
          // Navigate to main home screen (AssessmentIntroScreen) where snap-and-solve card is
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AssessmentIntroScreen()),
            (route) => false,
          );
        },
        size: GradientButtonSize.large,
      ),
    );
  }
}
