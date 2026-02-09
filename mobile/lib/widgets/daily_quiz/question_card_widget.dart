/// Question Card Widget
/// Reusable widget for displaying quiz questions
import 'package:flutter/material.dart';
import '../../models/daily_quiz_question.dart';
import '../../models/assessment_question.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'package:jeevibe_mobile/theme/app_platform_sizing.dart';
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
  late TextEditingController _numericalController;
  String? _lastQuestionId; // Track question ID to reinitialize controller on question change
  bool _controllerInitialized = false; // Track if controller has been initialized for current question
  
  @override
  void initState() {
    super.initState();
    _lastQuestionId = widget.question.questionId;
    // Initialize controller - only use selectedAnswer if it exists (for restoring saved state)
    // Once initialized, controller is completely independent
    _numericalController = TextEditingController(text: widget.selectedAnswer ?? '');
    _controllerInitialized = true;
  }
  
  @override
  void didUpdateWidget(QuestionCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ONLY reinitialize controller if the QUESTION changed (not just selectedAnswer)
    // This prevents the controller from being reset when user is typing
    if (widget.question.questionId != _lastQuestionId) {
      _lastQuestionId = widget.question.questionId;
      _controllerInitialized = false; // Reset flag for new question
      _numericalController.text = widget.selectedAnswer ?? '';
      _controllerInitialized = true;
    }
    // CRITICAL: DO NOT sync controller with selectedAnswer changes
    // Controller is the source of truth while user is editing
    // Even if selectedAnswer prop changes, we ignore it to prevent circular updates
  }
  
  @override
  void dispose() {
    _numericalController.dispose();
    super.dispose();
  }

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

  String _getDisplayableOptionId(String optionId) {
    // If it's already a single character (A, B, C, D), use it
    if (optionId.length == 1) {
      return optionId.toUpperCase();
    }
    
    // If malformed (like "opt_813"), try to extract a letter
    final match = RegExp(r'[A-Za-z]').firstMatch(optionId);
    if (match != null) {
      return match.group(0)!.toUpperCase();
    }
    
    // Last resort: use first character
    return optionId.isNotEmpty ? optionId[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final selectedAnswer = widget.selectedAnswer;
    final showAnswerOptions = widget.showAnswerOptions;
    final onAnswerSelected = widget.onAnswerSelected;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: PlatformSizing.spacing(16)),
      padding: EdgeInsets.all(PlatformSizing.spacing(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PlatformSizing.radius(16)),
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
          // Subject and chapter with time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
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
                    Expanded(
                      child: Text(
                        widget.question.chapter,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Time display
              if (widget.elapsedSeconds != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: PlatformSizing.spacing(10),
                    vertical: PlatformSizing.spacing(4),
                  ),
                  decoration: BoxDecoration(
                    color: _getSubjectColor(question.subject).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: PlatformSizing.iconSize(14),
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
                padding: EdgeInsets.symmetric(
                  horizontal: PlatformSizing.spacing(12),
                  vertical: PlatformSizing.spacing(4),
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
                ),
                child: Text(
                  'Question ${widget.question.position}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryPurple,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: PlatformSizing.spacing(12),
                  vertical: PlatformSizing.spacing(4),
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
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
          // Question text - Typography Guidelines: 18-20px
          if (widget.question.questionTextHtml != null)
            Html(
              data: widget.question.questionTextHtml,
              style: {
                'body': Style(
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                  fontSize: FontSize(18), // Guideline: 18-20px for question text
                  lineHeight: LineHeight(1.6),
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
                'strong': Style(
                  fontWeight: FontWeight.w700,
                ),
                'b': Style(
                  fontWeight: FontWeight.w700,
                ),
              },
            )
          else
            Text(
              widget.question.questionText,
              style: AppTextStyles.question, // Use dedicated question style (18px)
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
              height: PlatformSizing.buttonHeight(48),
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
                    borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
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
            // Use ValueListenableBuilder to update button without setState
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _numericalController,
              builder: (context, value, child) {
                final hasText = value.text.isNotEmpty;
                return SizedBox(
                  width: double.infinity,
                  height: PlatformSizing.buttonHeight(48),
                  child: ElevatedButton(
                    onPressed: hasText && widget.onAnswerSubmitted != null
                        ? () {
                            if (_numericalController.text.isNotEmpty) {
                              widget.onAnswerSubmitted?.call();
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasText
                          ? AppColors.primaryPurple
                          : AppColors.borderGray,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
                      ),
                    ),
                    child: const Text('Submit Answer'),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNumericalInput() {
    return TextField(
      controller: _numericalController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(
        hintText: 'Enter your answer',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textLight,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
          borderSide: const BorderSide(color: AppColors.borderGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
          borderSide: const BorderSide(color: AppColors.borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
          borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      style: AppTextStyles.bodyMedium,
      onChanged: (value) {
        // Update provider state - DO NOT call setState here
        // The button will update via ValueListenableBuilder below
        if (widget.onAnswerSelected != null) {
          // Only update if value is not empty, or if it's empty (to allow deletion)
          // We want to store empty string so the button disables, but validation will catch it
          widget.onAnswerSelected!(value);
        }
      },
      onSubmitted: (value) {
        if (widget.onAnswerSelected != null) {
          widget.onAnswerSelected!(value);
        }
      },
    );
  }

  Widget _buildOption(QuestionOption option) {
    final optionId = option.optionId;
    final optionText = option.text;
    final optionHtml = option.html;
    final isSelected = widget.selectedAnswer == optionId;
    
    // Debug: Log option data for troubleshooting
    if (optionId.isEmpty) {
      print('WARNING: Option has empty ID - Text: $optionText');
    }
    
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
        circleColor = AppColors.borderGray.withValues(alpha: 0.2);
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
          ? AppColors.primaryPurple.withValues(alpha: 0.1)
          : Colors.white;
      circleColor = isSelected
          ? AppColors.primaryPurple.withValues(alpha: 0.2)
          : AppColors.borderGray.withValues(alpha: 0.2);
      textColor = AppColors.textDark;
      labelText = null;
      labelIcon = null;
      labelColor = null;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: PlatformSizing.spacing(12)),
      child: InkWell(
        onTap: widget.onAnswerSelected != null && !isReviewing ? () => widget.onAnswerSelected!(optionId) : null,
        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
        child: Container(
          padding: EdgeInsets.all(PlatformSizing.spacing(16)),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(
              color: borderColor,
              width: (isReviewing && (isCorrectAnswer || isWrongAnswer)) || isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
          ),
          child: Row(
            children: [
              Container(
                width: PlatformSizing.spacing(32),
                height: PlatformSizing.spacing(32),
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    // Display only single letter (A, B, C, D)
                    // If ID is malformed (like "opt_813"), extract first uppercase letter or use first char
                    _getDisplayableOptionId(optionId),
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
                            fontSize: FontSize(16), // Guideline: 16px for options
                            lineHeight: LineHeight(1.4),
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                          'strong': Style(
                            fontWeight: FontWeight.w700,
                          ),
                          'b': Style(
                            fontWeight: FontWeight.w700,
                          ),
                        },
                      )
                    : Text(
                        optionText,
                        style: AppTextStyles.option.copyWith(color: textColor), // 16px medium weight
                      ),
              ),
              // Label for correct/wrong answers
              if (labelText != null && labelIcon != null && labelColor != null) ...[
                SizedBox(width: PlatformSizing.spacing(8)),
                Icon(
                  labelIcon,
                  color: labelColor,
                  size: PlatformSizing.iconSize(20),
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

