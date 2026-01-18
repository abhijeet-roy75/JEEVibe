/// Review Questions Screen - Matches design: 13b Review Questions screen.png
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../models/snap_data_model.dart';
import '../widgets/latex_widget.dart';
import '../widgets/chemistry_text.dart';
import '../widgets/app_header.dart';
import '../providers/app_state_provider.dart';
import 'camera_screen.dart';
import 'daily_limit_screen.dart';
import '../config/content_config.dart';
import '../utils/text_preprocessor.dart';

class ReviewQuestionsScreen extends StatefulWidget {
  final PracticeSessionResult sessionResult;
  final int? initialQuestionIndex;

  const ReviewQuestionsScreen({
    super.key,
    required this.sessionResult,
    this.initialQuestionIndex,
  });

  @override
  State<ReviewQuestionsScreen> createState() => _ReviewQuestionsScreenState();
}

class _ReviewQuestionsScreenState extends State<ReviewQuestionsScreen> {
  late int _currentQuestionIndex;

  List<QuestionResult> get _allQuestions {
    return widget.sessionResult.questionResults;
  }

  @override
  void initState() {
    super.initState();
    // Use initialQuestionIndex if provided, otherwise start at 0
    _currentQuestionIndex = widget.initialQuestionIndex ?? 0;
    if (_currentQuestionIndex >= _allQuestions.length) {
      _currentQuestionIndex = 0;
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _allQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allQuestions.isEmpty) {
      return _buildNoMistakes();
    }

    final question = _allQuestions[_currentQuestionIndex];
    final levels = ['Basic', 'Intermediate', 'Advanced'];
    final level = levels[question.questionNumber - 1];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            _buildHeader(question, level),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.space24,
                  AppSpacing.space24,
                  AppSpacing.space24,
                  AppSpacing.space24 + MediaQuery.of(context).viewPadding.bottom,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.space24),
                    _buildQuestionCard(question),
                    const SizedBox(height: AppSpacing.space20),
                    _buildOptionsReview(question),
                    const SizedBox(height: AppSpacing.space24),
                    _buildConceptCard(question),
                    const SizedBox(height: AppSpacing.space32),
                    _buildNavigationButtons(),
                    const SizedBox(height: AppSpacing.space32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(QuestionResult question, String level) {
    return AppHeader(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Question ${question.questionNumber}',
        style: AppTextStyles.headerWhite.copyWith(fontSize: 20),
        textAlign: TextAlign.center,
      ),
      subtitle: Column(
        children: [
          const SizedBox(height: 8), // Reduced from 16
          Text(
            'Time: ${question.timeSpentSeconds}s • From today\'s practice',
            style: AppTextStyles.bodyWhite.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6), // Reduced from 12
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.radiusRound),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Text(
              level,
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      // Use default padding (24 top, 16 bottom) for consistency
    );
  }

  Widget _buildQuestionCard(QuestionResult question) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Question', style: AppTextStyles.labelMedium),
          const SizedBox(height: 12),
          LaTeXWidget(
            text: question.question,
            textStyle: ContentConfig.getQuestionTextStyle(color: AppColors.textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsReview(QuestionResult question) {
    final options = ['A', 'B', 'C', 'D'];
    
    return Column(
      children: options.map((option) {
        final isCorrect = option == question.correctAnswer;
        final isUserAnswer = option == question.userAnswer;
        
        Color backgroundColor = Colors.white;
        Color borderColor = AppColors.borderGray;
        Widget? badge;
        
        if (isCorrect) {
          backgroundColor = AppColors.successBackground;
          borderColor = AppColors.successGreen;
          badge = _buildBadge('Correct Answer', AppColors.successGreen);
        } else if (isUserAnswer && !isCorrect) {
          backgroundColor = AppColors.errorBackground;
          borderColor = AppColors.errorRed;
          badge = _buildBadge('Your Answer', AppColors.errorRed);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (badge != null) ...[
                badge,
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCorrect || isUserAnswer 
                          ? borderColor
                          : AppColors.borderLight,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        option,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: isCorrect || isUserAnswer
                              ? Colors.white
                              : AppColors.textMedium,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    // Note: Options text is not currently stored in QuestionResult
                    // This is a placeholder. When option text is available, it will be rendered with LaTeXWidget
                    child: LaTeXWidget(
                      text: 'Option text for $option',
                      textStyle: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.radiusRound),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildConceptCard(QuestionResult question) {
    final isWrong = !question.isCorrect;
    final explanation = question.explanation;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isWrong 
            ? LinearGradient(
                colors: [
                  AppColors.errorRed.withValues(alpha: 0.1),
                  AppColors.primaryPurple.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppColors.priyaCardGradient,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(
          color: isWrong 
              ? AppColors.errorRed.withValues(alpha: 0.4)
              : AppColors.primaryPurple.withValues(alpha: 0.3),
          width: isWrong ? 2.5 : 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWrong ? Icons.school : Icons.lightbulb_outline,
                color: isWrong ? AppColors.errorRed : AppColors.primaryPurple,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isWrong ? 'Let\'s Understand This Better' : 'Understanding the Concept',
                  style: AppTextStyles.headerSmall.copyWith(
                    color: isWrong ? AppColors.errorRed : const Color(0xFF7C3AED),
                    fontWeight: isWrong ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          if (isWrong) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.errorRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Don\'t worry! Let\'s break this down step-by-step so you master this concept.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.errorRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Approach Section
          if (explanation?['approach'] != null && (explanation!['approach'] as String).isNotEmpty) ...[
            Text(
              'Overall Strategy',
              style: AppTextStyles.labelMedium.copyWith(
                color: isWrong ? AppColors.errorRed : const Color(0xFF7C3AED),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            LaTeXWidget(
              text: explanation!['approach'] as String,
              textStyle: ContentConfig.getStepTextStyle(color: const Color(0xFF6B21A8)),
            ),
            const SizedBox(height: 20),
          ],
          
          // Step-by-Step Solution
          if (explanation?['steps'] != null) ...[
            Builder(
              builder: (context) {
                final steps = explanation!['steps'];
                if (steps is List && steps.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step-by-Step Solution',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: isWrong ? AppColors.errorRed : const Color(0xFF7C3AED),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(steps as List).asMap().entries.map((entry) {
                        final stepIndex = entry.key;
                        final stepContent = entry.value.toString();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                            border: Border.all(
                              color: isWrong 
                                  ? AppColors.errorRed.withValues(alpha: 0.2)
                                  : AppColors.primaryPurple.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isWrong 
                                      ? AppColors.errorRed.withValues(alpha: 0.2)
                                      : AppColors.primaryPurple.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${stepIndex + 1}',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: isWrong ? AppColors.errorRed : AppColors.primaryPurple,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: LaTeXWidget(
                                  text: stepContent,
                                  textStyle: ContentConfig.getStepTextStyle(color: const Color(0xFF6B21A8)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 16),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
          
          // Final Answer
          if (explanation?['finalAnswer'] != null && (explanation!['finalAnswer'] as String).isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.successBackground.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                border: Border.all(
                  color: AppColors.successGreen.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.successGreen, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Final Answer',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.successGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LaTeXWidget(
                    text: explanation!['finalAnswer'] as String,
                    textStyle: TextStyle(
                      fontSize: ContentConfig.finalAnswerTextSize,
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.w600,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Key Takeaway box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warningBackground.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
              border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.star, color: AppColors.warningAmber, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Key Takeaway',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isWrong
                            ? 'Review these steps carefully and practice similar problems to strengthen your understanding!'
                            : 'Remember the core concept and apply it to similar problems. Practice makes perfect!',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Column(
      children: [
        // Next Question / Back to Results
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.ctaGradient,
            borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
            boxShadow: AppShadows.buttonShadow,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (_currentQuestionIndex < _allQuestions.length - 1) {
                  _nextQuestion();
                } else {
                  Navigator.of(context).pop();
                }
              },
              borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
              child: Center(
                child: Text(
                  _currentQuestionIndex < _allQuestions.length - 1
                      ? 'Next Question'
                      : 'Back to Results',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Back to Review List
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
            border: Border.all(color: AppColors.primaryPurple, width: 2),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
              child: Center(
                child: Text(
                  'Back to Review List',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primaryPurple,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoMistakes() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Center(
          child: Text(
            'No mistakes to review!',
            style: AppTextStyles.headerMedium,
          ),
        ),
      ),
    );
  }
}
