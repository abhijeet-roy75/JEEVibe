/// Shareable Solution Card Widget
/// A branded widget designed for screenshot capture and sharing
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/text_preprocessor.dart';
import 'latex_widget.dart';

class ShareableSolutionCard extends StatelessWidget {
  final String question;
  final List<String> steps;
  final String finalAnswer;
  final String subject;
  final String topic;

  const ShareableSolutionCard({
    super.key,
    required this.question,
    required this.steps,
    required this.finalAnswer,
    required this.subject,
    required this.topic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380, // Fixed width for consistent screenshots
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with JEEVibe branding
          _buildHeader(),
          const SizedBox(height: 20),

          // Question section
          _buildQuestionSection(),
          const SizedBox(height: 20),

          // Solution steps (condensed)
          _buildSolutionSteps(),
          const SizedBox(height: 20),

          // Final answer
          _buildFinalAnswer(),
          const SizedBox(height: 24),

          // Footer with branding
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.ctaGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'J',
                style: TextStyle(
                  color: AppColors.primaryPurple,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'JEEVibe Solution',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$topic • $subject',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSection() {
    final cleanQuestion = TextPreprocessor.addSpacesToText(question);
    final truncatedQuestion = cleanQuestion.length > 250
        ? '${cleanQuestion.substring(0, 247)}...'
        : cleanQuestion;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book, color: AppColors.primaryPurple, size: 16),
              const SizedBox(width: 6),
              Text(
                'Question',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LaTeXWidget(
            text: truncatedQuestion,
            textStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.textMedium,
              height: 1.4,
            ),
            allowWrapping: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionSteps() {
    // Show up to 3 steps, truncated
    final displaySteps = steps.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.primaryPurple, size: 16),
            const SizedBox(width: 6),
            Text(
              'Solution',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (steps.length > 3) ...[
              const Spacer(),
              Text(
                '${steps.length} steps total',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textLight,
                  fontSize: 12,  // 12px iOS, 10.56px Android (was 11)
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        ...displaySteps.asMap().entries.map((entry) {
          final stepNum = entry.key + 1;
          final stepContent = TextPreprocessor.preprocessStepContent(entry.value);
          final truncatedStep = stepContent.length > 120
              ? '${stepContent.substring(0, 117)}...'
              : stepContent;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.cardLightPurple,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$stepNum',
                      style: const TextStyle(
                        color: AppColors.primaryPurple,
                        fontSize: 12,  // 12px iOS, 10.56px Android (was 11)
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LaTeXWidget(
                    text: truncatedStep,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMedium,
                      height: 1.4,
                    ),
                    allowWrapping: true,
                  ),
                ),
              ],
            ),
          );
        }),
        if (steps.length > 3)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              '... and ${steps.length - 3} more steps',
              style: TextStyle(
                fontSize: 12,  // 12px iOS, 10.56px Android (was 11)
                color: AppColors.textLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFinalAnswer() {
    final cleanAnswer = TextPreprocessor.addSpacesToText(finalAnswer);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.successGreen, size: 16),
              const SizedBox(width: 6),
              Text(
                'Final Answer',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.successGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LaTeXWidget(
            text: cleanAnswer,
            textStyle: const TextStyle(
              fontSize: 14,
              color: AppColors.successGreen,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            allowWrapping: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    // Format timestamp with 12-hour format and AM/PM
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final timestamp = '${now.day}/${now.month}/${now.year} $hour:${now.minute.toString().padLeft(2, '0')} $amPm';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.ctaGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Solved with JEEVibe',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            timestamp,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
