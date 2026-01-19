/// Chapter Practice Review Screen
/// Shows all questions with filters (All, Correct, Wrong)
/// Similar to DailyQuizReviewScreen - accessed from result screen
import 'package:flutter/material.dart';
import '../../models/chapter_practice_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Review Questions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _chapterName,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter buttons
          _buildFilterButtons(),
          // Question list
          Expanded(
            child: _buildQuestionList(),
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

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredResults.length,
      itemBuilder: (context, index) {
        return _buildQuestionCard(_filteredResults[index], index);
      },
    );
  }

  Widget _buildQuestionCard(PracticeQuestionResult result, int displayIndex) {
    final isCorrect = result.isCorrect;
    final questionNumber = result.position + 1; // Convert 0-indexed to 1-indexed

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect
              ? AppColors.successGreen.withValues(alpha: 0.3)
              : AppColors.errorRed.withValues(alpha: 0.3),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
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
          title: Text(
            result.questionText.length > 60
                ? '${result.questionText.substring(0, 60)}...'
                : result.questionText,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
                ),
                const SizedBox(width: 4),
                Text(
                  isCorrect ? 'Correct' : 'Wrong',
                  style: AppTextStyles.bodySmall.copyWith(
                    color:
                        isCorrect ? AppColors.successGreen : AppColors.errorRed,
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
          ),
          children: [
            // Full question text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question:',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMedium,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.questionText,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Options
            ...result.options.asMap().entries.map((entry) {
              final optIndex = entry.key;
              final option = entry.value;
              final isSelectedOption = option.optionId == result.studentAnswer;
              final isCorrectOption = option.optionId == result.correctAnswer;

              Color bgColor = Colors.transparent;
              Color borderColor = AppColors.borderGray;

              if (isCorrectOption) {
                bgColor = AppColors.successGreen.withValues(alpha: 0.1);
                borderColor = AppColors.successGreen;
              } else if (isSelectedOption && !isCorrect) {
                bgColor = AppColors.errorRed.withValues(alpha: 0.1);
                borderColor = AppColors.errorRed;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isCorrectOption
                            ? AppColors.successGreen
                            : isSelectedOption && !isCorrect
                                ? AppColors.errorRed
                                : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCorrectOption
                              ? AppColors.successGreen
                              : isSelectedOption && !isCorrect
                                  ? AppColors.errorRed
                                  : AppColors.borderGray,
                        ),
                      ),
                      child: Center(
                        child: isCorrectOption || (isSelectedOption && !isCorrect)
                            ? Icon(
                                isCorrectOption ? Icons.check : Icons.close,
                                color: Colors.white,
                                size: 16,
                              )
                            : Text(
                                String.fromCharCode(65 + optIndex),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textMedium,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option.text,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            // Solution
            if (result.solutionText != null ||
                result.solutionSteps.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primaryPurple.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: AppColors.primaryPurple,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Solution',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (result.solutionText != null)
                      Text(
                        result.solutionText!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textDark,
                          height: 1.5,
                        ),
                      ),
                    if (result.solutionSteps.isNotEmpty) ...[
                      if (result.solutionText != null)
                        const SizedBox(height: 12),
                      ...result.solutionSteps.asMap().entries.map((entry) {
                        final stepIndex = entry.key;
                        final step = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple
                                      .withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${stepIndex + 1}',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.primaryPurple,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  step.displayText,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
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
