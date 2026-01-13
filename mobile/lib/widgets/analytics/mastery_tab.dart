/// Mastery Tab Widget
/// Displays subject mastery details with chapter breakdown and chart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/analytics_data.dart';
import '../../services/analytics_service.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../screens/assessment_intro_screen.dart';
import '../priya_avatar.dart';
import 'chapter_mastery_item.dart';
import 'mastery_chart.dart';

class MasteryTab extends StatefulWidget {
  final String authToken;
  final AnalyticsOverview overview;

  const MasteryTab({
    super.key,
    required this.authToken,
    required this.overview,
  });

  @override
  State<MasteryTab> createState() => _MasteryTabState();
}

class _MasteryTabState extends State<MasteryTab> {
  String _selectedSubject = 'physics';
  SubjectMasteryDetails? _masteryDetails;
  MasteryTimeline? _timeline;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubjectData();
  }

  Future<void> _loadSubjectData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        AnalyticsService.getSubjectMastery(
          authToken: widget.authToken,
          subject: _selectedSubject,
        ),
        AnalyticsService.getMasteryTimeline(
          authToken: widget.authToken,
          subject: _selectedSubject,
          limit: 30,
        ),
      ]);

      if (mounted) {
        setState(() {
          _masteryDetails = results[0] as SubjectMasteryDetails;
          _timeline = results[1] as MasteryTimeline;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _onSubjectChanged(String subject) {
    if (subject != _selectedSubject) {
      setState(() {
        _selectedSubject = subject;
      });
      _loadSubjectData();
    }
  }

  Color get _subjectColor {
    switch (_selectedSubject) {
      case 'physics':
        return AppColors.infoBlue;
      case 'chemistry':
        return AppColors.successGreen;
      case 'maths':
      case 'mathematics':
        return AppColors.primaryPurple;
      default:
        return AppColors.primaryPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject filter chips
          _buildSubjectFilters(),
          const SizedBox(height: 20),
          // Content based on loading state
          if (_isLoading)
            _buildLoadingState()
          else if (_error != null)
            _buildErrorState()
          else if (_masteryDetails != null) ...[
            // Overall mastery card
            _buildOverallMasteryCard(),
            const SizedBox(height: 20),
            // Mastery over time chart
            _buildChartCard(),
            const SizedBox(height: 20),
            // Chapter breakdown
            _buildChapterBreakdown(),
            const SizedBox(height: 20),
            // Priya Ma'am card
            _buildPriyaMaamCard(),
            const SizedBox(height: 20),
          ],
          // Back to Dashboard button
          _buildBackToDashboardButton(),
          // Bottom padding to account for Android navigation bar
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 24),
        ],
      ),
    );
  }

  Widget _buildSubjectFilters() {
    return Row(
      children: [
        _buildSubjectChip('Physics', 'physics', AppColors.infoBlue),
        const SizedBox(width: 8),
        _buildSubjectChip('Chemistry', 'chemistry', AppColors.successGreen),
        const SizedBox(width: 8),
        _buildSubjectChip('Maths', 'maths', AppColors.primaryPurple),
      ],
    );
  }

  Widget _buildSubjectChip(String label, String value, Color color) {
    final isSelected = _selectedSubject == value;
    IconData icon;
    
    switch (value) {
      case 'physics':
        icon = Icons.bolt;
        break;
      case 'chemistry':
        icon = Icons.science;
        break;
      case 'maths':
      case 'mathematics':
        icon = Icons.calculate;
        break;
      default:
        icon = Icons.book;
    }

    return GestureDetector(
      onTap: () => _onSubjectChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.borderDefault,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const SizedBox(
      height: 300,
      child: Center(
        child: CircularProgressIndicator(color: AppColors.primaryPurple),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            _error ?? 'An error occurred',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _loadSubjectData,
            child: Text(
              'Retry',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryPurple),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallMasteryCard() {
    final details = _masteryDetails!;

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
          // Subject name and percentage
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${details.subjectName} Mastery',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${details.overallPercentile.toInt()}%',
                style: AppTextStyles.displaySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _subjectColor,
                  fontSize: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Status badge and chapters tested
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: details.status.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  details.status.displayName,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: details.status.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${details.chaptersTested} chapters tested',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    if (_timeline == null || _timeline!.timeline.isEmpty) {
      return const SizedBox.shrink();
    }

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
              Icon(Icons.trending_up, color: _subjectColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Mastery over time',
                style: AppTextStyles.headerSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          MasteryChart(
            timeline: _timeline!,
            lineColor: _subjectColor,
            height: 180,
          ),
        ],
      ),
    );
  }

  Widget _buildChapterBreakdown() {
    final details = _masteryDetails!;

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
              const Icon(Icons.list_alt, color: AppColors.textMedium, size: 20),
              const SizedBox(width: 8),
              Text(
                'Chapter Breakdown',
                style: AppTextStyles.headerSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Summary badges
              _buildSummaryBadge(details.summary.mastered, AppColors.success, 'M'),
              const SizedBox(width: 6),
              _buildSummaryBadge(details.summary.growing, AppColors.warning, 'G'),
              const SizedBox(width: 6),
              _buildSummaryBadge(details.summary.focus, AppColors.error, 'F'),
            ],
          ),
          const SizedBox(height: 16),
          ...details.chapters.map((chapter) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ChapterMasteryItem(
                  chapter: chapter,
                  progressColor: _subjectColor,
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSummaryBadge(int count, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriyaMaamCard() {
    // Generate simplified message focused on topic recommendations for mastery tab
    final message = _generateMasteryMessage();

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
                Row(
                  children: [
                    Text(
                      'Priya Ma\'am',
                      style: AppTextStyles.priyaHeader.copyWith(
                        color: AppColors.primaryPurple,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.auto_awesome,
                      color: AppColors.primaryPurple,
                      size: 14,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _buildFormattedMessage(message),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _generateMasteryMessage() {
    if (_masteryDetails == null || _masteryDetails!.chapters.isEmpty) {
      return 'Keep practicing to see your mastery improve!';
    }

    // Find the top focus area (lowest percentile chapter)
    final focusChapters = _masteryDetails!.chapters
        .where((ch) => ch.status == MasteryStatus.focus)
        .toList();
    
    if (focusChapters.isEmpty) {
      // If no focus chapters, find the lowest percentile chapter
      final sortedChapters = List<ChapterMastery>.from(_masteryDetails!.chapters)
        ..sort((a, b) => a.percentile.compareTo(b.percentile));
      
      if (sortedChapters.isNotEmpty) {
        final topFocus = sortedChapters.first;
        if (topFocus.percentile < 60) {
          return 'Focus on **${topFocus.chapterName}** next — it\'s high-weight and you\'re close to breakthrough.';
        } else {
          return 'Keep pushing **${topFocus.chapterName}** — you\'re making great progress!';
        }
      }
    } else {
      // Sort focus chapters by percentile (lowest first)
      focusChapters.sort((a, b) => a.percentile.compareTo(b.percentile));
      final topFocus = focusChapters.first;
      
      // Determine message based on percentile
      if (topFocus.percentile < 50) {
        return 'Focus on **${topFocus.chapterName}** next — it\'s high-weight and you\'re close to breakthrough.';
      } else if (topFocus.percentile < 60) {
        return 'Focus on **${topFocus.chapterName}** next — you\'re close to a breakthrough.';
      } else {
        return 'Keep pushing **${topFocus.chapterName}** — you\'re making great progress!';
      }
    }

    return 'Keep practicing to see your mastery improve!';
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

  Widget _buildBackToDashboardButton() {
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
