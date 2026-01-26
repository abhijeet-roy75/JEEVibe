/// Mastery Tab Widget
/// Displays subject mastery details with chapter breakdown and chart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/analytics_data.dart';
import '../../models/ai_tutor_models.dart';
import '../../services/analytics_service.dart';
import '../../services/subscription_service.dart';
import '../../services/share_service.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../screens/ai_tutor_chat_screen.dart';
import '../priya_avatar.dart';
import '../shareable_subject_mastery_card.dart';
import 'chapter_mastery_item.dart';
import 'accuracy_chart.dart';

class MasteryTab extends StatefulWidget {
  final String authToken;
  final AnalyticsOverview overview;

  const MasteryTab({
    super.key,
    required this.authToken,
    required this.overview,
  });

  @override
  State<MasteryTab> createState() => MasteryTabState();
}

class MasteryTabState extends State<MasteryTab> {
  String _selectedSubject = 'physics';
  SubjectMasteryDetails? _masteryDetails;
  AccuracyTimeline? _accuracyTimeline;
  bool _isLoading = true;
  String? _error;

  // Cache for subject data to avoid re-fetching when switching tabs
  final Map<String, SubjectMasteryDetails> _masteryCache = {};
  final Map<String, AccuracyTimeline> _timelineCache = {};

  // Share functionality
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _loadSubjectData();
  }

  /// Public method to trigger share from parent widget
  /// [sharePositionOrigin] is required on iPad to position the share popover
  Future<void> triggerShare([Rect? sharePositionOrigin]) async {
    if (_isLoading || _masteryDetails == null) return;

    // Only share if there's actual data
    if (_masteryDetails!.chapters.isEmpty) {
      debugPrint('Cannot share mastery - no chapter data available');
      return;
    }

    try {
      // Calculate overall accuracy from chapters (not percentile)
      int totalCorrect = 0;
      int totalQuestions = 0;
      for (final chapter in _masteryDetails!.chapters) {
        totalCorrect += chapter.correct;
        totalQuestions += chapter.total;
      }
      final accuracy = totalQuestions > 0
          ? (totalCorrect / totalQuestions * 100).round()
          : 0;

      // Capture screenshot of shareable card
      final imageBytes = await _screenshotController.captureFromWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Material(
            color: Colors.transparent,
            child: ShareableSubjectMasteryCard(
              studentName: widget.overview.user.firstName,
              masteryDetails: _masteryDetails!,
            ),
          ),
        ),
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 100),
      );

      // Share via native share sheet
      await ShareService.shareSubjectMasteryAsImage(
        imageBytes: imageBytes,
        subject: _masteryDetails!.subjectName,
        accuracy: accuracy,
        status: _masteryDetails!.status.displayName,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      debugPrint('Error sharing subject mastery: $e');
    }
  }

  Future<void> _loadSubjectData() async {
    // Check cache first
    if (_masteryCache.containsKey(_selectedSubject) &&
        _timelineCache.containsKey(_selectedSubject)) {
      setState(() {
        _masteryDetails = _masteryCache[_selectedSubject];
        _accuracyTimeline = _timelineCache[_selectedSubject];
        _isLoading = false;
        _error = null;
      });
      return;
    }

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
        AnalyticsService.getAccuracyTimeline(
          authToken: widget.authToken,
          subject: _selectedSubject,
          days: 30,
        ),
      ]);

      if (mounted) {
        final masteryDetails = results[0] as SubjectMasteryDetails;
        final accuracyTimeline = results[1] as AccuracyTimeline;

        // Store in cache
        _masteryCache[_selectedSubject] = masteryDetails;
        _timelineCache[_selectedSubject] = accuracyTimeline;

        // Mastery details loaded successfully (verbose logging disabled)
        setState(() {
          _masteryDetails = masteryDetails;
          _accuracyTimeline = accuracyTimeline;
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
    return Column(
      children: [
        // Subject filter chips - fixed at top with background
        Container(
          color: AppColors.backgroundLight,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: _buildSubjectFilters(),
        ),
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  // Chapter list (directly, not in a card)
                  _buildChapterList(),
                  const SizedBox(height: 20),
                  // Priya Ma'am card
                  _buildPriyaMaamCard(),
                ],
                // Bottom padding to account for Android navigation bar
                SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 24),
              ],
            ),
          ),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.ctaGradient : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.borderDefault,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
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

    // Get accuracy from overview subject progress
    final subjectKey = _selectedSubject == 'maths' ? 'maths' : _selectedSubject;
    final subjectProgress = widget.overview.subjectProgress[subjectKey];
    final accuracy = subjectProgress?.accuracy ?? 0;
    final correctCount = subjectProgress?.correct ?? 0;
    final totalCount = subjectProgress?.total ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          // Subject name and accuracy percentage
          Row(
            children: [
              Text(
                '${details.subjectName} Accuracy',
                style: AppTextStyles.headerSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                totalCount > 0 ? '$accuracy%' : '--',
                style: AppTextStyles.headerSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _subjectColor,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Questions count and chapters tested
          Row(
            children: [
              if (totalCount > 0) ...[
                Text(
                  '$correctCount/$totalCount correct',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Text(
                '${details.chaptersTested} chapters tested',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    if (_accuracyTimeline == null || _accuracyTimeline!.timeline.isEmpty) {
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
                'Accuracy over time',
                style: AppTextStyles.headerSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AccuracyChart(
            timeline: _accuracyTimeline!,
            lineColor: _subjectColor,
            height: 180,
          ),
        ],
      ),
    );
  }

  Widget _buildChapterList() {
    final details = _masteryDetails!;

    if (details.chapters.isEmpty) {
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
        child: Center(
          child: Text(
            'No chapters tested yet. Complete quizzes to see your mastery progress.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...details.chapters.map((chapter) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ChapterMasteryItem(
                chapter: chapter,
                progressColor: _subjectColor,
              ),
            )),
      ],
    );
  }


  Widget _buildPriyaMaamCard() {
    // Generate simplified message focused on topic recommendations for mastery tab
    final message = _generateMasteryMessage();
    final subscriptionService = SubscriptionService();
    final hasAiTutorAccess = subscriptionService.status?.limits.aiTutorEnabled ?? false;

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
            // "Ask Priya Ma'am" action (Ultra tier only)
            if (hasAiTutorAccess) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
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
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ask Priya Ma\'am about my progress',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.primaryPurple,
                      size: 14,
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

  String _generateMasteryMessage() {
    // Use backend-provided focus areas (1 per subject) for consistency with Overview tab
    final subjectFocusArea = widget.overview.focusAreas
        .where((fa) => fa.subject == _selectedSubject)
        .firstOrNull;

    if (subjectFocusArea != null) {
      final chapterName = subjectFocusArea.chapterName;
      final percentile = subjectFocusArea.percentile;

      // Determine message based on percentile
      if (percentile < 50) {
        return 'Focus on **$chapterName** next — it\'s high-weight and you\'re close to breakthrough.';
      } else if (percentile < 60) {
        return 'Focus on **$chapterName** next — you\'re close to a breakthrough.';
      } else if (percentile < 70) {
        return 'Keep pushing **$chapterName** — you\'re making great progress!';
      } else {
        return 'Great work on **$chapterName**! Keep up the momentum.';
      }
    }

    // Fallback if no focus area for this subject
    if (_masteryDetails == null || _masteryDetails!.chapters.isEmpty) {
      return 'Keep practicing to see your mastery improve!';
    }

    return 'Keep practicing to build your ${_selectedSubject} skills!';
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

}
