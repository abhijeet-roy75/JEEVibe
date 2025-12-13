/// Question Card Widget
/// Reusable widget for displaying quiz questions
import 'package:flutter/material.dart';
import '../../models/daily_quiz_question.dart';
import '../../models/assessment_question.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../safe_svg_widget.dart';
import 'package:flutter_html/flutter_html.dart';

class QuestionCardWidget extends StatelessWidget {
  final DailyQuizQuestion question;
  final String? selectedAnswer;
  final bool showAnswerOptions;
  final Function(String)? onAnswerSelected;

  const QuestionCardWidget({
    super.key,
    required this.question,
    this.selectedAnswer,
    this.showAnswerOptions = true,
    this.onAnswerSelected,
  });

  Color _getSubjectColor(String? subject) {
    switch (subject?.toLowerCase()) {
      case 'physics':
        return AppColors.infoBlue;
      case 'chemistry':
        return AppColors.successGreen;
      case 'mathematics':
      case 'math':
        return AppColors.primaryPurple;
      default:
        return AppColors.textMedium;
    }
  }

  String _getDifficultyLabel(String? difficulty) {
    if (difficulty == null) return 'Moderate';
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 'Easy';
      case 'medium':
      case 'moderate':
        return 'Moderate';
      case 'hard':
      case 'challenging':
        return 'Challenging';
      default:
        return 'Moderate';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject and chapter
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getSubjectColor(question.subject),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${question.subject} • ${question.chapter}',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Question number and difficulty
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Question ${question.position}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryPurple,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getDifficultyLabel(null), // TODO: Add difficulty to model
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.warningAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Question text
          if (question.questionTextHtml != null)
            Html(
              data: question.questionTextHtml,
              style: {
                'body': Style(
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                ),
              },
            )
          else
            Text(
              question.questionText,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          if (question.hasImage) ...[
            const SizedBox(height: 16),
            SafeSvgWidget(url: question.imageUrl!),
          ],
          if (showAnswerOptions && question.options != null) ...[
            const SizedBox(height: 24),
            ...question.options!.map((option) => _buildOption(option)),
          ],
        ],
      ),
    );
  }

  Widget _buildOption(QuestionOption option) {
    final optionId = option.optionId;
    final optionText = option.text;
    final optionHtml = option.html;
    final isSelected = selectedAnswer == optionId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onAnswerSelected != null ? () => onAnswerSelected!(optionId) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryPurple.withOpacity(0.1)
                : Colors.white,
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryPurple
                  : AppColors.borderGray,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryPurple.withOpacity(0.2)
                      : AppColors.borderGray.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    optionId,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isSelected
                          ? AppColors.primaryPurple
                          : AppColors.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: optionHtml != null
                    ? Html(
                        data: optionHtml,
                        style: {
                          'body': Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                          ),
                        },
                      )
                    : Text(
                        optionText,
                        style: AppTextStyles.bodyMedium,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

