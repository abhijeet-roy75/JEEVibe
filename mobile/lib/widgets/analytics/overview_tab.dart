/// Overview Tab Widget
/// Displays analytics overview content
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/analytics_data.dart';
import '../../models/ai_tutor_models.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/responsive_layout.dart';
import '../../screens/subscription/paywall_screen.dart';
import '../../screens/ai_tutor_chat_screen.dart';
import '../../services/subscription_service.dart';
import '../../services/share_service.dart';
import '../priya_avatar.dart';
import '../shareable_analytics_overview_card.dart';
import 'stat_card.dart';
import 'weekly_activity_chart.dart';

class OverviewTab extends StatefulWidget {
  final AnalyticsOverview overview;
  final WeeklyActivity? weeklyActivity;
  final bool isBasicView; // true for FREE tier, false for PRO/ULTRA

  const OverviewTab({
    super.key,
    required this.overview,
    this.weeklyActivity,
    this.isBasicView = false,
  });

  @override
  State<OverviewTab> createState() => OverviewTabState();
}

class OverviewTabState extends State<OverviewTab> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  AnalyticsOverview get overview => widget.overview;
  WeeklyActivity? get weeklyActivity => widget.weeklyActivity;
  bool get isBasicView => widget.isBasicView;

  /// Public method to trigger share from parent widget
  /// [sharePositionOrigin] is required on iPad to position the share popover
  Future<void> triggerShare([Rect? sharePositionOrigin]) async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    try {
      // Capture screenshot of shareable card
      final imageBytes = await _screenshotController.captureFromWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Material(
            color: Colors.transparent,
            child: ShareableAnalyticsOverviewCard(
              studentName: overview.user.firstName,
              stats: overview.stats,
              subjectProgress: overview.orderedSubjectProgress,
              weeklyActivity: weeklyActivity,
            ),
          ),
        ),
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 100),
      );

      // Share via native share sheet
      await ShareService.shareAnalyticsOverviewAsImage(
        imageBytes: imageBytes,
        studentName: overview.user.firstName,
        currentStreak: overview.stats.currentStreak,
        questionsSolved: overview.stats.questionsSolved,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      debugPrint('Error sharing analytics overview: $e');
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isDesktopViewport(context) ? 900 : double.infinity,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats grid (Streak, Qs Done, Accuracy)
          _buildStatsGrid(),
          const SizedBox(height: 20),
          // Your Progress section (same as home page)
          _buildYourProgressCard(context),
          const SizedBox(height: 20),
          // Weekly Activity chart
          if (weeklyActivity != null) ...[
            _buildWeeklyActivityCard(),
            const SizedBox(height: 20),
          ],
          // Focus Areas section (show for all tiers, upgrade prompt inside for FREE)
          _buildFocusAreasCard(context),
          const SizedBox(height: 20),
          // Priya Ma'am motivation card (after Focus Areas)
          _buildPriyaMaamCard(context),
          // Bottom padding to account for Android navigation bar
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 24),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    // Calculate overall accuracy from subjects
    final subjects = overview.orderedSubjectProgress;
    int totalCorrect = 0;
    int totalQuestions = 0;
    for (final subject in subjects) {
      totalCorrect += subject.correct;
      totalQuestions += subject.total;
    }
    final overallAccuracy = totalQuestions > 0
        ? ((totalCorrect / totalQuestions) * 100).round()
        : 0;

    return Row(
      children: [
        // Streak - purple background
        Expanded(
          child: StatCard(
            icon: Icons.local_fire_department,
            iconColor: AppColors.primaryPurple,
            iconBackgroundColor: AppColors.primaryPurple,
            value: '${overview.stats.currentStreak}',
            label: 'Streak',
          ),
        ),
        const SizedBox(width: 8),
        // Qs Done - orange/amber background
        Expanded(
          child: StatCard(
            icon: Icons.check_circle,
            iconColor: AppColors.warningAmber,
            iconBackgroundColor: AppColors.warningAmber,
            value: '${overview.stats.questionsSolved}',
            label: 'Qs Done',
          ),
        ),
        const SizedBox(width: 8),
        // Overall Accuracy - green background
        Expanded(
          child: StatCard(
            icon: Icons.track_changes,
            iconColor: AppColors.successGreen,
            iconBackgroundColor: AppColors.successGreen,
            value: '$overallAccuracy%',
            label: 'Accuracy',
          ),
        ),
      ],
    );
  }

  Widget _buildYourProgressCard(BuildContext context) {
    final subjects = overview.orderedSubjectProgress;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          Row(
            children: [
              const Icon(
                Icons.trending_up,
                size: 24,
                color: AppColors.primaryPurple,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Progress',
                style: AppTextStyles.headerSmall.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Subject Results
          _buildSubjectResult(
            'Physics',
            subjects.firstWhere((s) => s.subject.toLowerCase() == 'physics',
                orElse: () => _emptySubject('physics')),
            AppColors.subjectPhysics,
            Icons.bolt,
          ),
          const SizedBox(height: 8),
          _buildSubjectResult(
            'Chemistry',
            subjects.firstWhere((s) => s.subject.toLowerCase() == 'chemistry',
                orElse: () => _emptySubject('chemistry')),
            AppColors.subjectChemistry,
            Icons.science,
          ),
          const SizedBox(height: 8),
          _buildSubjectResult(
            'Mathematics',
            subjects.firstWhere(
                (s) => s.subject.toLowerCase() == 'mathematics' || s.subject.toLowerCase() == 'maths',
                orElse: () => _emptySubject('mathematics')),
            AppColors.subjectMathematics,
            Icons.functions,
          ),
        ],
      ),
    );
  }

  SubjectProgress _emptySubject(String subject) {
    return SubjectProgress(
      subject: subject,
      displayName: subject,
      percentile: 0,
      theta: 0,
      status: MasteryStatus.focus,
      chaptersTested: 0,
    );
  }

  Widget _buildSubjectResult(String subjectName, SubjectProgress subject, Color color, IconData icon) {
    final accuracyValue = subject.accuracy ?? 0;
    final displayAccuracy = subject.accuracy != null ? '${subject.accuracy}%' : 'N/A';

    // Determine progress bar color based on accuracy thresholds
    Color progressColor;
    if (subject.accuracy == null || accuracyValue == 0) {
      progressColor = Colors.grey;
    } else if (accuracyValue < 70) {
      progressColor = AppColors.performanceOrange;
    } else if (accuracyValue <= 85) {
      progressColor = AppColors.subjectMathematics;
    } else {
      progressColor = AppColors.subjectChemistry;
    }

    // Build the correct/total display string
    final hasQuestionData = subject.total > 0;
    final correctTotalText = hasQuestionData
        ? '${subject.correct}/${subject.total}'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subject name with icon, question count, and percentage row
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              subjectName,
              style: AppTextStyles.headerSmall.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (correctTotalText.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                correctTotalText,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textLight,
                  fontSize: 12,
                ),
              ),
            ],
            const Spacer(),
            Text(
              displayAccuracy,
              style: AppTextStyles.headerSmall.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: accuracyValue / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                size: 24,
                color: AppColors.primaryPurple,
              ),
              const SizedBox(width: 8),
              Text(
                'This Week',
                style: AppTextStyles.headerSmall.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${weeklyActivity!.totalQuestions} Qs',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bar chart
          WeeklyActivityChart(
            activity: weeklyActivity!,
            height: 140,
          ),
        ],
      ),
    );
  }

  Widget _buildFocusAreasCard(BuildContext context) {
    final subscriptionService = SubscriptionService();
    final hasChapterPractice = subscriptionService.isChapterPracticeEnabled;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gps_fixed, color: AppColors.primaryPurple, size: 24),
              const SizedBox(width: 8),
              Text(
                'Focus Areas',
                style: AppTextStyles.headerSmall.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Show upgrade prompt if chapter practice not enabled (FREE tier)
          if (!hasChapterPractice)
            _buildFocusAreasUpgradeContent(context)
          else if (overview.focusAreas.isNotEmpty)
            // Compact list of focus chapters (tap to practice)
            ...overview.focusAreas.asMap().entries.map((entry) {
              final index = entry.key;
              final area = entry.value;
              final isLast = index == overview.focusAreas.length - 1;
              return _buildFocusAreaRow(context, area, isLast);
            })
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Great job! No weak areas detected yet.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFocusAreasUpgradeContent(BuildContext context) {
    return Column(
      children: [
        Text(
          'Unlock detailed chapter-wise analysis to identify your weak areas and improve faster.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PaywallScreen(
                    featureName: 'Focus Areas',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.workspace_premium_rounded, size: 18),
            label: const Text('Upgrade to Pro'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryPurple,
              side: BorderSide(color: AppColors.primaryPurple.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFocusAreaRow(BuildContext context, FocusArea area, bool isLast) {
    // Get subject icon and color
    IconData subjectIcon;
    Color subjectColor;
    switch (area.subject.toLowerCase()) {
      case 'physics':
        subjectIcon = Icons.bolt;
        subjectColor = AppColors.subjectPhysics;
        break;
      case 'chemistry':
        subjectIcon = Icons.science;
        subjectColor = AppColors.subjectChemistry;
        break;
      case 'mathematics':
      case 'maths':
        subjectIcon = Icons.functions;
        subjectColor = AppColors.subjectMathematics;
        break;
      default:
        subjectIcon = Icons.book;
        subjectColor = AppColors.textMedium;
    }

    // Format display - show correct/total like mastery tab
    final correct = area.correct;
    final total = area.total;
    final accuracyColor = _getFocusAreaColor(area.accuracy);

    // Display-only row (no navigation from analytics page)
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              // Subject icon
              Icon(subjectIcon, size: 16, color: subjectColor),
              const SizedBox(width: 8),
              // Chapter name
              Expanded(
                child: Text(
                  area.chapterName,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Score badge (correct/total)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accuracyColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$correct/$total',
                  style: AppTextStyles.caption.copyWith(
                    color: accuracyColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            color: AppColors.borderLight,
          ),
      ],
    );
  }

  Color _getFocusAreaColor(double accuracy) {
    if (accuracy < 50) {
      return AppColors.performanceOrange;
    } else if (accuracy < 70) {
      return AppColors.warningAmber;
    } else {
      return AppColors.subjectMathematics;
    }
  }

  String _generateMotivationalMessage() {
    // Calculate overall accuracy
    final subjects = overview.orderedSubjectProgress;
    int totalCorrect = 0;
    int totalQuestions = 0;
    for (final subject in subjects) {
      totalCorrect += subject.correct;
      totalQuestions += subject.total;
    }
    final overallAccuracy = totalQuestions > 0
        ? ((totalCorrect / totalQuestions) * 100).round()
        : 0;

    // Get focus area info
    final focusAreas = overview.focusAreas;
    final hasFocusAreas = focusAreas.isNotEmpty;
    final topFocusChapter = hasFocusAreas ? focusAreas.first.chapterName : '';

    // Generate contextual message
    if (totalQuestions == 0) {
      return 'Start practicing to see your accuracy! Every question you solve helps you improve.';
    }

    if (overallAccuracy >= 80) {
      if (hasFocusAreas) {
        return 'Great accuracy at $overallAccuracy%! Focus on $topFocusChapter to strengthen your weaker areas.';
      }
      return 'Excellent work! Your $overallAccuracy% accuracy shows strong understanding. Keep it up!';
    } else if (overallAccuracy >= 60) {
      if (hasFocusAreas) {
        return 'Good progress at $overallAccuracy%! Practice $topFocusChapter regularly to boost your score.';
      }
      return 'You\'re doing well at $overallAccuracy%! Consistent practice will help you reach 80%+.';
    } else {
      if (hasFocusAreas) {
        return 'Your accuracy is $overallAccuracy%. Let\'s work on $topFocusChapter to build a stronger foundation.';
      }
      return 'Keep practicing! Every mistake is a learning opportunity. Focus on understanding concepts deeply.';
    }
  }

  Widget _buildPriyaMaamCard(BuildContext context) {
    final subscriptionService = SubscriptionService();
    final hasAiTutorAccess = subscriptionService.status?.limits.aiTutorEnabled ?? false;

    // Generate a short motivational message based on accuracy and focus areas
    final message = _generateMotivationalMessage();

    return GestureDetector(
      onTap: hasAiTutorAccess ? () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AiTutorChatScreen(
              injectContext: TutorContext(
                type: TutorContextType.analytics,
                title: 'My Progress',
              ),
            ),
          ),
        );
      } : null,
      child: Container(
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
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PriyaAvatar(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Priya Ma\'am',
                        style: AppTextStyles.priyaHeader.copyWith(
                          color: AppColors.primaryPurple,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // "Ask Priya Ma'am" action (Ultra tier only)
            if (hasAiTutorAccess) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primaryPurple.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.primaryPurple,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ask Priya Ma\'am',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.primaryPurple,
                      size: 12,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

}
