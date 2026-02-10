import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:jeevibe/providers/unlock_quiz_provider.dart';
import 'package:jeevibe/services/firebase/auth_service.dart';
import 'package:jeevibe/theme/app_colors.dart';
import 'package:jeevibe/widgets/daily_quiz/feedback_banner_widget.dart';
import 'package:jeevibe/widgets/daily_quiz/detailed_explanation_widget.dart';
import 'package:jeevibe/screens/unlock_quiz/unlock_quiz_result_screen.dart';
import 'package:jeevibe/models/unlock_quiz_models.dart';

/// Unlock Quiz Question Screen
/// Displays questions and handles answer submission
class UnlockQuizQuestionScreen extends StatefulWidget {
  const UnlockQuizQuestionScreen({super.key});

  @override
  State<UnlockQuizQuestionScreen> createState() =>
      _UnlockQuizQuestionScreenState();
}

class _UnlockQuizQuestionScreenState extends State<UnlockQuizQuestionScreen> {
  String? _selectedOption;
  final _scrollController = ScrollController();
  DateTime? _questionStartTime;

  @override
  void initState() {
    super.initState();
    _questionStartTime = DateTime.now();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UnlockQuizProvider>(
      builder: (context, provider, _) {
        final question = provider.currentQuestion;
        final isAnswered = provider.currentQuestionIsAnswered;
        final answerResult = provider.lastAnswerResult;

        if (question == null) {
          return Scaffold(
            body: Center(child: Text('No question loaded')),
          );
        }

        return PopScope(
          canPop: false, // Prevent back navigation
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: _buildAppBar(provider),
            body: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  // Progress indicator
                  _buildProgressIndicator(provider),

                  // Question Card
                  _buildQuestionCard(question, isAnswered),

                  // Feedback Banner (if answered)
                  if (isAnswered && answerResult != null)
                    FeedbackBannerWidget(
                      isCorrect: answerResult.isCorrect,
                      correctAnswer:
                          answerResult.correctAnswerText ?? answerResult.correctAnswer,
                      studentAnswer: answerResult.studentAnswer,
                    ),

                  // Detailed Explanation (if answered)
                  if (isAnswered && answerResult != null)
                    DetailedExplanationWidget(
                      solutionSteps: answerResult.solutionSteps,
                      keyInsight: answerResult.keyInsight,
                      distractorAnalysis: answerResult.distractorAnalysis,
                      commonMistakes: answerResult.commonMistakes,
                      motivationalMessage: _getMotivationalMessage(answerResult.isCorrect),
                    ),

                  // Action Buttons
                  if (isAnswered) _buildNavigationButtons(provider),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(UnlockQuizProvider provider) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: Container(), // Remove back button
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unlock Quiz',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Text(
            provider.session?.chapterName ?? '',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Q ${provider.currentQuestionIndex + 1}/5',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(UnlockQuizProvider provider) {
    final progress = (provider.currentQuestionIndex + 1) / 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.surface,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Answer all 5 questions',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Need 3+ correct',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.border.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(UnlockQuizQuestion question, bool isAnswered) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
          // Question Text
          if (question.questionTextHtml != null)
            Html(
              data: question.questionTextHtml,
              style: {
                'body': Style(
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                  fontSize: FontSize(18),
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                  lineHeight: const LineHeight(1.5),
                ),
                'p': Style(
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                ),
              },
            )
          else
            Text(
              question.questionText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
                height: 1.5,
              ),
            ),

          const SizedBox(height: 24),

          // Options
          ...question.options.map((option) => _buildOption(
                option,
                isAnswered,
                question,
              )),

          // Submit Button
          if (!isAnswered && _selectedOption != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _submitAnswer(question),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Submit Answer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOption(
    UnlockQuizOption option,
    bool isAnswered,
    UnlockQuizQuestion question,
  ) {
    final isSelected = _selectedOption == option.optionId;
    final isCorrectAnswer = isAnswered && option.optionId == question.correctAnswer;
    final isWrongAnswer = isAnswered &&
        isSelected &&
        option.optionId != question.correctAnswer;

    Color borderColor = AppColors.border;
    Color backgroundColor = AppColors.background;

    if (isAnswered) {
      if (isCorrectAnswer) {
        borderColor = Colors.green;
        backgroundColor = Colors.green.withOpacity(0.1);
      } else if (isWrongAnswer) {
        borderColor = Colors.red;
        backgroundColor = Colors.red.withOpacity(0.1);
      }
    } else if (isSelected) {
      borderColor = AppColors.primary;
      backgroundColor = AppColors.primary.withOpacity(0.1);
    }

    return GestureDetector(
      onTap: isAnswered ? null : () {
        setState(() {
          _selectedOption = option.optionId;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Option ID
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isAnswered
                    ? (isCorrectAnswer
                        ? Colors.green
                        : isWrongAnswer
                            ? Colors.red
                            : AppColors.border.withOpacity(0.3))
                    : (isSelected
                        ? AppColors.primary
                        : AppColors.border.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  option.optionId,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected || isAnswered && (isCorrectAnswer || isWrongAnswer)
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Option Text
            Expanded(
              child: option.html != null
                  ? Html(
                      data: option.html,
                      style: {
                        'body': Style(
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                          fontSize: FontSize(16),
                          color: AppColors.textDark,
                        ),
                      },
                    )
                  : Text(
                      option.text,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textDark,
                      ),
                    ),
            ),

            // Checkmark for correct answer
            if (isAnswered && isCorrectAnswer)
              const Icon(Icons.check_circle, color: Colors.green, size: 24),
            if (isAnswered && isWrongAnswer)
              const Icon(Icons.cancel, color: Colors.red, size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAnswer(UnlockQuizQuestion question) async {
    if (_selectedOption == null) return;

    final provider = context.read<UnlockQuizProvider>();
    final authService = context.read<AuthService>();
    final authToken = await authService.getIdToken();

    if (authToken == null) {
      _showError('Authentication error');
      return;
    }

    final timeTaken = DateTime.now().difference(_questionStartTime!).inSeconds;

    try {
      await provider.submitAnswer(_selectedOption!, authToken, timeTaken);

      // Scroll to top to see feedback
      _scrollToTop();
    } catch (e) {
      _showError('Failed to submit answer: $e');
    }
  }

  Widget _buildNavigationButtons(UnlockQuizProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: provider.hasMoreQuestions
            ? ElevatedButton(
                onPressed: () {
                  provider.goToNextQuestion();
                  setState(() {
                    _selectedOption = null;
                    _questionStartTime = DateTime.now();
                  });
                  _scrollToTop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Next Question →',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
            : ElevatedButton(
                onPressed: () => _completeQuiz(provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Complete Quiz ✓',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _completeQuiz(UnlockQuizProvider provider) async {
    final authService = context.read<AuthService>();
    final authToken = await authService.getIdToken();

    if (authToken == null) return;

    try {
      final result = await provider.completeQuiz(authToken);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UnlockQuizResultScreen(result: result),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to complete quiz: $e');
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String _getMotivationalMessage(bool isCorrect) {
    if (isCorrect) {
      return "Great job! You're on track to unlock this chapter.";
    } else {
      return "Don't worry! Review the solution and keep trying.";
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
