/// Chapter Practice Review Screen
/// Shows all questions with filters (All, Correct, Wrong)
/// Similar to DailyQuizReviewScreen - accessed from result screen
import 'package:flutter/material.dart';
import '../../models/chapter_practice_models.dart';
import '../../models/review_question_data.dart';
import '../../models/ai_tutor_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons/icon_button.dart';
import '../../widgets/priya_avatar.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/question_review/question_review_screen.dart';
import '../../utils/text_preprocessor.dart';

class ChapterPracticeReviewScreen extends StatefulWidget {
  final PracticeSessionSummary? summary;
  final List<PracticeQuestionResult>? results;
  final ChapterPracticeSession? session;

  const ChapterPracticeReviewScreen({
    super.key,
    this.summary,
    this.results,
    this.session,
  });

  @override
  State<ChapterPracticeReviewScreen> createState() =>
      _ChapterPracticeReviewScreenState();
}

class _ChapterPracticeReviewScreenState
    extends State<ChapterPracticeReviewScreen> {
  String _currentFilter = 'all';

  // Computed values from either summary or provider results
  int get _totalQuestions =>
      widget.summary?.totalQuestions ??
      widget.results?.length ??
      widget.session?.totalQuestions ??
      0;

  int get _correctCount =>
      widget.summary?.correctCount ??
      widget.results?.where((r) => r.isCorrect).length ??
      0;

  int get _wrongCount => _totalQuestions - _correctCount;

  String get _chapterName =>
      widget.summary?.chapterName ?? widget.session?.chapterName ?? 'Chapter';

  List<PracticeQuestionResult> get _allResults => widget.results ?? [];

  List<PracticeQuestionResult> get _filteredResults {
    switch (_currentFilter) {
      case 'correct':
        return _allResults.where((r) => r.isCorrect).toList();
      case 'wrong':
        return _allResults.where((r) => !r.isCorrect).toList();
      default:
        return _allResults;
    }
  }

  String get _subject =>
      widget.summary?.subject ?? widget.session?.subject ?? '';

  String? get _sessionId => widget.summary?.sessionId ?? widget.session?.sessionId;

  /// Convert results to ReviewQuestionData for the common screen
  List<ReviewQuestionData> get _reviewQuestionData {
    return _allResults
        .map((r) => ReviewQuestionData.fromChapterPractice(
              r,
              subject: _subject,
              chapter: _chapterName,
            ))
        .toList();
  }

  void _navigateToQuestionReview(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionReviewScreen(
          questions: _reviewQuestionData,
          initialIndex: index,
          filterType: _currentFilter,
          subject: _subject,
          chapterName: _chapterName,
          tutorContext: _sessionId != null
              ? ReviewTutorContext(
                  type: TutorContextType.chapterPractice,
                  id: _sessionId!,
                  title: '$_chapterName - $_subject',
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // Purple header - Full width
          _buildHeader(),
          // Scrollable content - Constrained on desktop
          Expanded(
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isDesktopViewport(context) ? 900 : double.infinity,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewPadding.bottom,
                  ),
                  child: Column(
                    children: [
                  const SizedBox(height: 16),
                  // Filter buttons (also show counts)
                  _buildFilterButtons(),
                  const SizedBox(height: 16),
                  // Question list
                  _buildQuestionList(),
                  const SizedBox(height: 16),
                  // Priya Ma'am message
                  _buildPriyaMaamMessage(),
                  const SizedBox(height: 16),
                  // Start Reviewing button
                  _buildStartReviewingButton(),
                  const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              AppIconButton.back(
                onPressed: () => Navigator.of(context).pop(),
                forGradientHeader: true,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Review All Questions',
                      style: AppTextStyles.headerWhite.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _chapterName,
                      style: AppTextStyles.bodyWhite.copyWith(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildSummaryCard('Total', '$_totalQuestions', AppColors.primaryPurple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard('Correct', '$_correctCount', AppColors.successGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard('Wrong', '$_wrongCount', AppColors.errorRed),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTextStyles.headerWhite.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodyWhite.copyWith(fontSize: 12),  // 12px iOS, 10.56px Android (was 11)
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterButton(
              label: 'All ($_totalQuestions)',
              isSelected: _currentFilter == 'all',
              onTap: () => setState(() => _currentFilter = 'all'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterButton(
              label: 'Correct ($_correctCount)',
              isSelected: _currentFilter == 'correct',
              color: AppColors.successGreen,
              onTap: () => setState(() => _currentFilter = 'correct'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterButton(
              label: 'Wrong ($_wrongCount)',
              isSelected: _currentFilter == 'wrong',
              color: AppColors.errorRed,
              onTap: () => setState(() => _currentFilter = 'wrong'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required String label,
    required bool isSelected,
    Color? color,
    required VoidCallback onTap,
  }) {
    final activeColor = color ?? AppColors.primaryPurple;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppColors.borderGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: isSelected ? Colors.white : AppColors.textDark,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionList() {
    if (_filteredResults.isEmpty) {
      String message;
      IconData icon;
      Color iconColor;

      if (_allResults.isEmpty) {
        message = 'No questions answered';
        icon = Icons.quiz_outlined;
        iconColor = AppColors.textLight;
      } else if (_currentFilter == 'correct') {
        message = 'No correct answers yet.\nKeep practicing!';
        icon = Icons.emoji_emotions_outlined;
        iconColor = AppColors.textLight;
      } else if (_currentFilter == 'wrong') {
        message = 'No wrong answers!\nPerfect score!';
        icon = Icons.celebration;
        iconColor = AppColors.successGreen;
      } else {
        message = 'No questions to review';
        icon = Icons.quiz_outlined;
        iconColor = AppColors.textLight;
      }

      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: iconColor),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _filteredResults.asMap().entries.map((entry) {
          final index = entry.key;
          final result = entry.value;
          return _buildQuestionCard(result, index);
        }).toList(),
      ),
    );
  }

  Widget _buildQuestionCard(PracticeQuestionResult result, int displayIndex) {
    final isCorrect = result.isCorrect;
    final questionNumber = result.position + 1; // Convert 0-indexed to 1-indexed

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect
              ? AppColors.successGreen.withValues(alpha: 0.3)
              : AppColors.errorRed.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToQuestionReview(displayIndex),
        child: Row(
          children: [
            // Question number circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$questionNumber',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Question details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question text (truncated, HTML stripped)
                  Builder(
                    builder: (context) {
                      final cleanText = TextPreprocessor.stripHtml(result.questionText);
                      return Text(
                        cleanText.length > 60
                            ? '${cleanText.substring(0, 60)}...'
                            : cleanText,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  // Status and answers
                  Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        size: 16,
                        color: isCorrect
                            ? AppColors.successGreen
                            : AppColors.errorRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCorrect ? 'Correct' : 'Wrong',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isCorrect
                              ? AppColors.successGreen
                              : AppColors.errorRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!isCorrect) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Your: ${result.studentAnswer.toUpperCase()}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.errorRed,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Correct: ${result.correctAnswer.toUpperCase()}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.successGreen,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  Widget _buildPriyaMaamMessage() {
    String message;
    if (_currentFilter == 'wrong') {
      message =
          "Focus on understanding why you got these wrong. Review the step-by-step explanations carefully!";
    } else {
      message =
          "Great job! Review all questions to reinforce your understanding and identify areas for improvement.";
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
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
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('✨', style: TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(
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

  Widget _buildStartReviewingButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primaryPurple,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (_filteredResults.isNotEmpty) {
                _navigateToQuestionReview(0); // First item in filtered list
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.menu_book, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Start Reviewing',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
