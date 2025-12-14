/// Question Card Widget
/// Reusable widget for displaying quiz questions
import 'package:flutter/material.dart';
import '../../models/daily_quiz_question.dart';
import '../../models/assessment_question.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../safe_svg_widget.dart';
import 'package:flutter_html/flutter_html.dart';

class QuestionCardWidget extends StatefulWidget {
  final DailyQuizQuestion question;
  final String? selectedAnswer;
  final bool showAnswerOptions;
  final Function(String)? onAnswerSelected;
  final VoidCallback? onAnswerSubmitted;
  final int? elapsedSeconds;
  final AnswerFeedback? feedback;

  const QuestionCardWidget({
    super.key,
    required this.question,
    this.selectedAnswer,
    this.showAnswerOptions = true,
    this.onAnswerSelected,
    this.onAnswerSubmitted,
    this.elapsedSeconds,
    this.feedback,
  });

  @override
  State<QuestionCardWidget> createState() => _QuestionCardWidgetState();
}

class _QuestionCardWidgetState extends State<QuestionCardWidget> {
  final TextEditingController _numericalController = TextEditingController();

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

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _numericalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final selectedAnswer = widget.selectedAnswer;
    final showAnswerOptions = widget.showAnswerOptions;
    final onAnswerSelected = widget.onAnswerSelected;
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
          // Subject and chapter with time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _getSubjectColor(question.subject),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.question.subject}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _getSubjectColor(question.subject),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.question.chapter,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              // Time display
              if (widget.elapsedSeconds != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getSubjectColor(question.subject).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: _getSubjectColor(question.subject),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(widget.elapsedSeconds!),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: _getSubjectColor(question.subject),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                  'Question ${widget.question.position}',
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
          if (widget.question.questionTextHtml != null)
            Html(
              data: widget.question.questionTextHtml,
              style: {
                'body': Style(
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                ),
              },
            )
          else
            Text(
              widget.question.questionText,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          if (widget.question.hasImage) ...[
            const SizedBox(height: 16),
            SafeSvgWidget(url: widget.question.imageUrl!),
          ],
          // Show options when answering or reviewing
          if (widget.question.options != null && (showAnswerOptions || widget.feedback != null)) ...[
            const SizedBox(height: 24),
            ...widget.question.options!.map((option) => _buildOption(option)),
          ],
          // Submit button for MCQ questions (only when answering, not reviewing)
          if (showAnswerOptions && widget.question.options != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: widget.selectedAnswer != null && widget.selectedAnswer!.isNotEmpty && widget.onAnswerSubmitted != null
                    ? widget.onAnswerSubmitted
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.selectedAnswer != null && widget.selectedAnswer!.isNotEmpty
                      ? AppColors.primaryPurple
                      : AppColors.borderGray,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Submit Answer'),
              ),
            ),
          ],
          // Numerical input field
          if (showAnswerOptions && widget.question.isNumerical) ...[
            const SizedBox(height: 24),
            _buildNumericalInput(),
            const SizedBox(height: 16),
            // Submit button for numerical questions
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _numericalController.text.isNotEmpty && widget.onAnswerSubmitted != null
                    ? () {
                        if (_numericalController.text.isNotEmpty) {
                          widget.onAnswerSubmitted?.call();
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _numericalController.text.isNotEmpty
                      ? AppColors.primaryPurple
                      : AppColors.borderGray,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Submit Answer'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNumericalInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AppColors.borderGray,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _numericalController,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: 'Enter your answer',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textLight,
          ),
          border: InputBorder.none,
        ),
        style: AppTextStyles.bodyMedium,
        onChanged: (value) {
          // Store the answer as user types
          if (value.isNotEmpty && widget.onAnswerSelected != null) {
            widget.onAnswerSelected!(value);
          }
          setState(() {}); // Update button state
        },
        onSubmitted: (value) {
          if (value.isNotEmpty && widget.onAnswerSelected != null) {
            widget.onAnswerSelected!(value);
          }
        },
      ),
    );
  }

  Widget _buildOption(QuestionOption option) {
    final optionId = option.optionId;
    final optionText = option.text;
    final optionHtml = option.html;
    final isSelected = widget.selectedAnswer == optionId;
    
    // Determine option state when reviewing
    final feedback = widget.feedback;
    final isReviewing = feedback != null;
    final isCorrectAnswer = feedback != null && feedback.correctAnswer == optionId;
    final isStudentAnswer = feedback != null && feedback.studentAnswer == optionId;
    final isWrongAnswer = isReviewing && isStudentAnswer && !feedback.isCorrect;
    
    // Determine colors and styling
    Color borderColor;
    Color backgroundColor;
    Color circleColor;
    Color textColor;
    String? labelText;
    IconData? labelIcon;
    Color? labelColor;
    
    if (isReviewing) {
      if (isCorrectAnswer) {
        // Correct answer: green
        borderColor = AppColors.successGreen;
        backgroundColor = AppColors.successBackground;
        circleColor = AppColors.successGreen;
        textColor = AppColors.textDark;
        labelText = 'Correct';
        labelIcon = Icons.check_circle;
        labelColor = AppColors.successGreen;
      } else if (isWrongAnswer) {
        // Student's wrong answer: red
        borderColor = AppColors.errorRed;
        backgroundColor = AppColors.errorBackground;
        circleColor = AppColors.errorRed;
        textColor = AppColors.textDark;
        labelText = 'Your answer';
        labelIcon = Icons.close;
        labelColor = AppColors.errorRed;
      } else {
        // Other options: gray
        borderColor = AppColors.borderGray;
        backgroundColor = Colors.white;
        circleColor = AppColors.borderGray.withOpacity(0.2);
        textColor = AppColors.textDark;
        labelText = null;
        labelIcon = null;
        labelColor = null;
      }
    } else {
      // Not reviewing: use selection state
      borderColor = isSelected
          ? AppColors.primaryPurple
          : AppColors.borderGray;
      backgroundColor = isSelected
          ? AppColors.primaryPurple.withOpacity(0.1)
          : Colors.white;
      circleColor = isSelected
          ? AppColors.primaryPurple.withOpacity(0.2)
          : AppColors.borderGray.withOpacity(0.2);
      textColor = AppColors.textDark;
      labelText = null;
      labelIcon = null;
      labelColor = null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: widget.onAnswerSelected != null && !isReviewing ? () => widget.onAnswerSelected!(optionId) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(
              color: borderColor,
              width: (isReviewing && (isCorrectAnswer || isWrongAnswer)) || isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    optionId,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isReviewing && (isCorrectAnswer || isWrongAnswer)
                          ? Colors.white
                          : (isSelected ? AppColors.primaryPurple : AppColors.textDark),
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
              // Label for correct/wrong answers
              if (labelText != null && labelIcon != null && labelColor != null) ...[
                const SizedBox(width: 8),
                Icon(
                  labelIcon,
                  color: labelColor,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  labelText,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

