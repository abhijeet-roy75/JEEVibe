/// Detailed Explanation Widget
/// Shows expandable detailed explanation, solution steps, and takeaways
import 'package:flutter/material.dart';
import '../../models/daily_quiz_question.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'package:flutter_html/flutter_html.dart';

class DetailedExplanationWidget extends StatefulWidget {
  final AnswerFeedback feedback;
  final bool isCorrect;

  const DetailedExplanationWidget({
    super.key,
    required this.feedback,
    required this.isCorrect,
  });

  @override
  State<DetailedExplanationWidget> createState() => _DetailedExplanationWidgetState();
}

class _DetailedExplanationWidgetState extends State<DetailedExplanationWidget> {
  bool _showDetailedExplanation = true;

  @override
  Widget build(BuildContext context) {
    final hasContent = widget.feedback.explanation != null ||
        widget.feedback.solutionText != null ||
        (widget.feedback.solutionSteps != null && widget.feedback.solutionSteps!.isNotEmpty);

    if (!hasContent) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Column(
          children: [
            // Header
            InkWell(
              onTap: () {
                setState(() {
                  _showDetailedExplanation = !_showDetailedExplanation;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: AppColors.primaryPurple,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _showDetailedExplanation ? 'Hide Detailed Explanation' : 'Show Detailed Explanation',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ),
                    Icon(
                      _showDetailedExplanation ? Icons.remove : Icons.add,
                      color: AppColors.primaryPurple,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            // Content
            if (_showDetailedExplanation) ...[
              Divider(height: 1, color: AppColors.borderGray),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Explanation
                    if (widget.feedback.explanation != null || widget.feedback.solutionText != null) ...[
                      _buildExplanationSection(
                        icon: Icons.lightbulb,
                        iconColor: AppColors.warningAmber,
                        title: 'Quick Explanation',
                        content: widget.feedback.explanation ?? widget.feedback.solutionText ?? '',
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Step-by-Step Solution
                    if (widget.feedback.solutionSteps != null && widget.feedback.solutionSteps!.isNotEmpty) ...[
                      _buildStepByStepSolution(widget.feedback.solutionSteps!),
                      const SizedBox(height: 16),
                    ],
                    // Why You Got This Wrong (only for incorrect)
                    if (!widget.isCorrect) ...[
                      _buildWhyWrongSection(),
                      const SizedBox(height: 16),
                    ],
                    // Key Takeaway - Use keyInsight from metadata, fallback to solutionText
                    if (widget.feedback.keyInsight != null || widget.feedback.solutionText != null)
                      _buildKeyTakeawaySection(
                        widget.feedback.keyInsight ?? widget.feedback.solutionText ?? '',
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

  Widget _buildExplanationSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.solutionHeader, // Guideline: 17px for section headers
              ),
              const SizedBox(height: 8),
              Html(
                data: content,
                style: {
                  'body': Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                    fontSize: FontSize(16), // Guideline: 16px for explanation body
                    lineHeight: LineHeight(1.6),
                    color: AppColors.textSecondary,
                  ),
                  'strong': Style(
                    fontWeight: FontWeight.w700,
                  ),
                  'b': Style(
                    fontWeight: FontWeight.w700,
                  ),
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepByStepSolution(List<SolutionStep> steps) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.menu_book, color: AppColors.successGreen, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step-by-Step Solution',
                style: AppTextStyles.solutionHeader, // Guideline: 17px for section headers
              ),
              const SizedBox(height: 12),
              ...steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final stepText = step.displayText;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: AppTextStyles.stepNumber.copyWith( // Guideline: 14px for step numbers
                              color: AppColors.successGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Html(
                          data: stepText,
                          style: {
                            'body': Style(
                              margin: Margins.zero,
                              padding: HtmlPaddings.zero,
                              fontSize: FontSize(16), // Guideline: 16-17px for step text
                              lineHeight: LineHeight(1.5),
                              color: AppColors.textSecondary,
                            ),
                            'strong': Style(
                              fontWeight: FontWeight.w700,
                            ),
                            'b': Style(
                              fontWeight: FontWeight.w700,
                            ),
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWhyWrongSection() {
    // Determine what content to show based on question type
    final isMcq = widget.feedback.isMcq;
    final isNumerical = widget.feedback.isNumerical;

    // For MCQ: get distractor analysis for the student's wrong answer
    String? distractorExplanation;
    if (isMcq && widget.feedback.distractorAnalysis != null) {
      distractorExplanation = widget.feedback.getDistractorForAnswer(
        widget.feedback.studentAnswer,
      );
    }

    // For numerical: check if we have common mistakes
    final hasCommonMistakes = isNumerical &&
        widget.feedback.commonMistakes != null &&
        widget.feedback.commonMistakes!.isNotEmpty;

    // Determine if we have specific content to show
    final hasSpecificContent = distractorExplanation != null || hasCommonMistakes;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.warningAmber.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.info_outline,
            color: AppColors.warningAmber,
            size: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why You Got This Wrong',
                style: AppTextStyles.solutionHeader,
              ),
              const SizedBox(height: 8),
              if (distractorExplanation != null) ...[
                // MCQ: Show why the selected wrong option is incorrect
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Option ${widget.feedback.studentAnswer?.toUpperCase() ?? ""}',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Html(
                  data: distractorExplanation,
                  style: {
                    'body': Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      fontSize: FontSize(16),
                      lineHeight: LineHeight(1.5),
                      color: AppColors.textSecondary,
                    ),
                  },
                ),
              ] else if (hasCommonMistakes) ...[
                // Numerical: Show common mistakes
                ...widget.feedback.commonMistakes!.map((mistake) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: AppTextStyles.explanationBody.copyWith(
                          color: AppColors.warningAmber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Html(
                          data: mistake,
                          style: {
                            'body': Style(
                              margin: Margins.zero,
                              padding: HtmlPaddings.zero,
                              fontSize: FontSize(16),
                              lineHeight: LineHeight(1.5),
                              color: AppColors.textSecondary,
                            ),
                          },
                        ),
                      ),
                    ],
                  ),
                )),
              ] else ...[
                // Fallback to generic message
                Text(
                  'Review the explanation carefully. Understanding why you made this mistake helps you avoid it in the future.',
                  style: AppTextStyles.explanationBody,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeyTakeawaySection(String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.vpn_key, color: AppColors.primaryPurple, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Key Takeaway',
                style: AppTextStyles.solutionHeader.copyWith( // Guideline: 16px for Key Takeaway header
                  color: AppColors.primaryPurple,
                ),
              ),
              const SizedBox(height: 8),
              Html(
                data: content,
                style: {
                  'body': Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                    fontSize: FontSize(16), // Guideline: 16px for body text
                    lineHeight: LineHeight(1.5),
                    color: AppColors.textSecondary,
                  ),
                  'strong': Style(
                    fontWeight: FontWeight.w700,
                  ),
                  'b': Style(
                    fontWeight: FontWeight.w700,
                  ),
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

