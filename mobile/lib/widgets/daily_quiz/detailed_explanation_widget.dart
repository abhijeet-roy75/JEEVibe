/// Detailed Explanation Widget
/// Shows expandable detailed explanation, solution steps, and takeaways
import 'package:flutter/material.dart';
import '../../models/daily_quiz_question.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_platform_sizing.dart';
import '../latex_widget.dart';

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
      padding: EdgeInsets.symmetric(horizontal: PlatformSizing.spacing(16)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
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
                padding: EdgeInsets.all(PlatformSizing.spacing(16)),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: AppColors.primaryPurple,
                      size: PlatformSizing.iconSize(20),
                    ),
                    SizedBox(width: PlatformSizing.spacing(8)),
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
                      size: PlatformSizing.iconSize(20),
                    ),
                  ],
                ),
              ),
            ),
            // Content
            if (_showDetailedExplanation) ...[
              Divider(height: 1, color: AppColors.borderGray),
              Padding(
                padding: EdgeInsets.all(PlatformSizing.spacing(16)),
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
                      SizedBox(height: PlatformSizing.spacing(16)),
                    ],
                    // Step-by-Step Solution
                    if (widget.feedback.solutionSteps != null && widget.feedback.solutionSteps!.isNotEmpty) ...[
                      _buildStepByStepSolution(widget.feedback.solutionSteps!),
                      SizedBox(height: PlatformSizing.spacing(16)),
                    ],
                    // Why You Got This Wrong (only for incorrect)
                    if (!widget.isCorrect) ...[
                      _buildWhyWrongSection(),
                      SizedBox(height: PlatformSizing.spacing(16)),
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
        Icon(icon, color: iconColor, size: PlatformSizing.iconSize(20)),
        SizedBox(width: PlatformSizing.spacing(8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.solutionHeader, // Guideline: 17px for section headers
              ),
              SizedBox(height: PlatformSizing.spacing(8)),
              LaTeXWidget(
                text: content,
                textStyle: TextStyle(
                  fontSize: PlatformSizing.fontSize(16), // Guideline: 16px for explanation body
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
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
        Icon(Icons.menu_book, color: AppColors.successGreen, size: PlatformSizing.iconSize(20)),
        SizedBox(width: PlatformSizing.spacing(8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step-by-Step Solution',
                style: AppTextStyles.solutionHeader, // Guideline: 17px for section headers
              ),
              SizedBox(height: PlatformSizing.spacing(12)),
              ...steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final stepText = step.displayText;

                return Padding(
                  padding: EdgeInsets.only(bottom: PlatformSizing.spacing(16)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: PlatformSizing.spacing(24),
                        height: PlatformSizing.spacing(24),
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
                      SizedBox(width: PlatformSizing.spacing(8)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Description
                            LaTeXWidget(
                              text: stepText,
                              textStyle: TextStyle(
                                fontSize: PlatformSizing.fontSize(16), // Guideline: 16-17px for step text
                                height: 1.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            // Formula (if exists)
                            if (step.formula != null && step.formula!.isNotEmpty) ...[
                              SizedBox(height: PlatformSizing.spacing(8)),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(PlatformSizing.spacing(12)),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(PlatformSizing.radius(8)),
                                  border: Border.all(
                                    color: AppColors.primaryPurple.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.functions,
                                      size: PlatformSizing.iconSize(16),
                                      color: AppColors.primaryPurple,
                                    ),
                                    SizedBox(width: PlatformSizing.spacing(8)),
                                    Expanded(
                                      child: LaTeXWidget(
                                        text: step.formula!,
                                        textStyle: TextStyle(
                                          fontSize: PlatformSizing.fontSize(15),
                                          height: 1.4,
                                          color: AppColors.primaryPurple,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // Calculation (if exists)
                            if (step.calculation != null && step.calculation!.isNotEmpty) ...[
                              SizedBox(height: PlatformSizing.spacing(8)),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(PlatformSizing.spacing(12)),
                                decoration: BoxDecoration(
                                  color: AppColors.successGreen.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(PlatformSizing.radius(8)),
                                  border: Border.all(
                                    color: AppColors.successGreen.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.calculate,
                                      size: PlatformSizing.iconSize(16),
                                      color: AppColors.successGreen,
                                    ),
                                    SizedBox(width: PlatformSizing.spacing(8)),
                                    Expanded(
                                      child: LaTeXWidget(
                                        text: step.calculation!,
                                        textStyle: TextStyle(
                                          fontSize: PlatformSizing.fontSize(15),
                                          height: 1.4,
                                          color: AppColors.textSecondary,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // Explanation (if exists and different from description)
                            if (step.explanation != null &&
                                step.explanation!.isNotEmpty &&
                                step.explanation != step.description) ...[
                              SizedBox(height: PlatformSizing.spacing(8)),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(PlatformSizing.spacing(12)),
                                decoration: BoxDecoration(
                                  color: AppColors.warningAmber.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(PlatformSizing.radius(8)),
                                  border: Border.all(
                                    color: AppColors.warningAmber.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline,
                                      size: PlatformSizing.iconSize(16),
                                      color: AppColors.warningAmber,
                                    ),
                                    SizedBox(width: PlatformSizing.spacing(8)),
                                    Expanded(
                                      child: LaTeXWidget(
                                        text: step.explanation!,
                                        textStyle: TextStyle(
                                          fontSize: PlatformSizing.fontSize(15),
                                          height: 1.4,
                                          color: AppColors.textSecondary,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
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
          width: PlatformSizing.iconSize(20),
          height: PlatformSizing.iconSize(20),
          decoration: BoxDecoration(
            color: AppColors.warningAmber.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.info_outline,
            color: AppColors.warningAmber,
            size: PlatformSizing.iconSize(14),
          ),
        ),
        SizedBox(width: PlatformSizing.spacing(8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why You Got This Wrong',
                style: AppTextStyles.solutionHeader,
              ),
              SizedBox(height: PlatformSizing.spacing(8)),
              if (distractorExplanation != null) ...[
                // MCQ: Show why the selected wrong option is incorrect
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: PlatformSizing.spacing(8), vertical: PlatformSizing.spacing(2)),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(PlatformSizing.radius(4)),
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
                SizedBox(height: PlatformSizing.spacing(8)),
                LaTeXWidget(
                  text: distractorExplanation,
                  textStyle: TextStyle(
                    fontSize: PlatformSizing.fontSize(16),
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else if (hasCommonMistakes) ...[
                // Numerical: Show common mistakes
                ...widget.feedback.commonMistakes!.map((mistake) => Padding(
                  padding: EdgeInsets.only(bottom: PlatformSizing.spacing(8)),
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
                        child: LaTeXWidget(
                          text: mistake,
                          textStyle: TextStyle(
                            fontSize: PlatformSizing.fontSize(16),
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
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
        Icon(Icons.vpn_key, color: AppColors.primaryPurple, size: PlatformSizing.iconSize(20)),
        SizedBox(width: PlatformSizing.spacing(8)),
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
              SizedBox(height: PlatformSizing.spacing(8)),
              LaTeXWidget(
                text: content,
                textStyle: TextStyle(
                  fontSize: PlatformSizing.fontSize(16), // Guideline: 16px for body text
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

