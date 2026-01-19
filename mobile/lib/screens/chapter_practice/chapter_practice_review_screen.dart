/// Chapter Practice Review Screen
/// Shows practice session results and allows question review
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chapter_practice_models.dart';
import '../../providers/chapter_practice_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/priya_avatar.dart';

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

  double get _accuracy {
    if (_totalQuestions == 0) return 0.0;
    return _correctCount / _totalQuestions;
  }

  String get _chapterName =>
      widget.summary?.chapterName ?? widget.session?.chapterName ?? 'Chapter';

  String get _subject =>
      widget.summary?.subject ?? widget.session?.subject ?? '';

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

  String _getEncouragingMessage() {
    final percentage = _accuracy * 100;
    if (percentage >= 80) {
      return 'Outstanding performance! You have a strong grasp of ${_chapterName}. Keep up the excellent work!';
    } else if (percentage >= 60) {
      return 'Good job! You\'re building a solid understanding of ${_chapterName}. Review the wrong answers to improve further.';
    } else if (percentage >= 40) {
      return 'Nice effort! Focus on reviewing the solutions for the questions you got wrong. Practice will help you improve!';
    } else {
      return 'Every practice session makes you stronger! Review the solutions carefully and try practicing again. You\'ll get better!';
    }
  }

  void _goHome() {
    // Reset provider state
    final provider =
        Provider.of<ChapterPracticeProvider>(context, listen: false);
    provider.reset();

    // Pop back to home
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _practiceAgain() {
    // Reset provider and go back to loading screen to restart practice
    final provider =
        Provider.of<ChapterPracticeProvider>(context, listen: false);
    provider.reset();

    // Pop back twice (review -> question -> loading) or just go to first and let user restart
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _goHome();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(
          children: [
            // Header
            _buildHeader(),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewPadding.bottom + 16,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Summary cards
                    _buildSummaryCards(),
                    const SizedBox(height: 16),
                    // Priya Ma'am message
                    _buildPriyaMaamMessage(),
                    const SizedBox(height: 16),
                    // Filter buttons (only if we have results)
                    if (_allResults.isNotEmpty) ...[
                      _buildFilterButtons(),
                      const SizedBox(height: 16),
                      // Question list
                      _buildQuestionList(),
                      const SizedBox(height: 16),
                    ],
                    // Action buttons
                    _buildActionButtons(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
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
          child: Column(
            children: [
              // Title
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _goHome,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Practice Complete!',
                          style: AppTextStyles.headerWhite.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _chapterName,
                          style: AppTextStyles.bodyWhite.copyWith(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the close button
                ],
              ),
              const SizedBox(height: 24),
              // Score circle
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(_accuracy * 100).toInt()}%',
                        style: AppTextStyles.headerWhite.copyWith(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$_correctCount / $_totalQuestions',
                        style: AppTextStyles.bodyWhite.copyWith(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Subject badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _subject,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
              child: _buildSummaryCard(
                'Total',
                '$_totalQuestions',
                AppColors.primaryPurple,
                Icons.quiz_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Correct',
                '$_correctCount',
                AppColors.successGreen,
                Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Wrong',
                '$_wrongCount',
                AppColors.errorRed,
                Icons.cancel_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.headerMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriyaMaamMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const PriyaAvatar(size: 56),
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
                    const Text('', style: TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getEncouragingMessage(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMedium,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: AppColors.textMedium, size: 20),
              const SizedBox(width: 8),
              Text(
                'REVIEW QUESTIONS',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMedium,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
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

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Back to Home button (primary)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _goHome,
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to Home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Practice Again button (secondary)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _practiceAgain,
              icon: const Icon(Icons.refresh),
              label: const Text('Practice Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
                side: const BorderSide(color: AppColors.primaryPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
