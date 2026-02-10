import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jeevibe_mobile/providers/unlock_quiz_provider.dart';
import 'package:jeevibe_mobile/services/firebase/auth_service.dart';
import 'package:jeevibe_mobile/theme/app_colors.dart';
import 'package:jeevibe_mobile/widgets/daily_quiz/feedback_banner_widget.dart';
import 'package:jeevibe_mobile/widgets/daily_quiz/detailed_explanation_widget.dart';
import 'package:jeevibe_mobile/widgets/daily_quiz/question_card_widget.dart';
import 'package:jeevibe_mobile/widgets/app_header.dart';
import 'package:jeevibe_mobile/widgets/buttons/primary_button.dart';
import 'package:jeevibe_mobile/screens/unlock_quiz/unlock_quiz_result_screen.dart';
import 'package:jeevibe_mobile/models/unlock_quiz_models.dart';
import 'package:jeevibe_mobile/models/daily_quiz_question.dart' show AnswerFeedback, DailyQuizQuestion;

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

  /// Convert UnlockQuizQuestion to DailyQuizQuestion for use with QuestionCardWidget
  DailyQuizQuestion _convertToDailyQuizQuestion(UnlockQuizQuestion question) {
    return DailyQuizQuestion(
      questionId: question.questionId,
      position: question.position,
      subject: question.subject,
      chapter: question.chapter,
      chapterKey: question.chapterKey,
      questionType: question.questionType,
      questionText: question.questionText,
      questionTextHtml: question.questionTextHtml,
      options: question.options,
      imageUrl: question.imageUrl,
      answered: question.answered,
      studentAnswer: question.studentAnswer,
      isCorrect: question.isCorrect,
      timeTakenSeconds: question.timeTakenSeconds,
    );
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
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.background,
                    AppColors.surface,
                    AppColors.background,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Column(
                children: [
                  // Standard header with progress
                  AppHeaderWithProgress(
                    currentIndex: provider.currentQuestionIndex,
                    total: 5,
                    title: 'Unlock Chapter',
                    subtitle: 'Need 3+ correct to unlock',
                    leading: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _showExitConfirmation,
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_open,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Q ${provider.currentQuestionIndex + 1}/5',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        children: [
                          // Question Card - using reusable widget
                          QuestionCardWidget(
                            question: _convertToDailyQuizQuestion(question),
                            selectedAnswer: _selectedOption,
                            showAnswerOptions: !isAnswered,
                            onAnswerSelected: (answer) {
                              setState(() {
                                _selectedOption = answer;
                              });
                            },
                            onAnswerSubmitted: () => _submitAnswer(question),
                            feedback: isAnswered && answerResult != null
                                ? AnswerFeedback(
                                    questionId: question.questionId,
                                    isCorrect: answerResult.isCorrect,
                                    correctAnswer: answerResult.correctAnswer,
                                    correctAnswerText: answerResult.correctAnswerText,
                                    explanation: answerResult.keyInsight,
                                    solutionText: answerResult.solutionText,
                                    solutionSteps: answerResult.solutionSteps,
                                    timeTakenSeconds: _questionStartTime != null
                                        ? DateTime.now().difference(_questionStartTime!).inSeconds
                                        : 0,
                                    studentAnswer: answerResult.studentAnswer,
                                    keyInsight: answerResult.keyInsight,
                                    commonMistakes: answerResult.commonMistakes,
                                    distractorAnalysis: answerResult.distractorAnalysis,
                                    questionType: question.questionType,
                                  )
                                : null,
                          ),

                  // Feedback Banner (if answered)
                  if (isAnswered && answerResult != null)
                    FeedbackBannerWidget(
                      feedback: AnswerFeedback(
                        questionId: question.questionId,
                        isCorrect: answerResult.isCorrect,
                        correctAnswer: answerResult.correctAnswer,
                        correctAnswerText: answerResult.correctAnswerText,
                        explanation: answerResult.keyInsight,
                        solutionText: answerResult.solutionText,
                        solutionSteps: answerResult.solutionSteps,
                        timeTakenSeconds: _questionStartTime != null
                            ? DateTime.now().difference(_questionStartTime!).inSeconds
                            : 0,
                        studentAnswer: answerResult.studentAnswer,
                        keyInsight: answerResult.keyInsight,
                        commonMistakes: answerResult.commonMistakes,
                        distractorAnalysis: answerResult.distractorAnalysis,
                        questionType: question.questionType,
                      ),
                      timeTakenSeconds: _questionStartTime != null
                          ? DateTime.now().difference(_questionStartTime!).inSeconds
                          : 0,
                    ),

                  // Detailed Explanation (if answered)
                  if (isAnswered && answerResult != null)
                    DetailedExplanationWidget(
                      feedback: AnswerFeedback(
                        questionId: question.questionId,
                        isCorrect: answerResult.isCorrect,
                        correctAnswer: answerResult.correctAnswer,
                        correctAnswerText: answerResult.correctAnswerText,
                        explanation: answerResult.keyInsight,
                        solutionText: answerResult.solutionText,
                        solutionSteps: answerResult.solutionSteps,
                        timeTakenSeconds: _questionStartTime != null
                            ? DateTime.now().difference(_questionStartTime!).inSeconds
                            : 0,
                        studentAnswer: answerResult.studentAnswer,
                        keyInsight: answerResult.keyInsight,
                        commonMistakes: answerResult.commonMistakes,
                        distractorAnalysis: answerResult.distractorAnalysis,
                        questionType: question.questionType,
                      ),
                      isCorrect: answerResult.isCorrect,
                    ),

                          // Action Buttons
                          if (isAnswered) _buildNavigationButtons(provider),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Exit Unlock Quiz?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Your progress will be lost. You can try again anytime.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Continue Quiz',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close quiz screen
            },
            child: const Text(
              'Exit',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Extra bottom padding for OS nav bar
      child: provider.hasMoreQuestions
          ? PrimaryButton(
              text: 'Next Question →',
              onPressed: () {
                provider.goToNextQuestion();
                setState(() {
                  _selectedOption = null;
                  _questionStartTime = DateTime.now();
                });
                _scrollToTop();
              },
              backgroundColor: AppColors.primary,
            )
          : PrimaryButton(
              text: 'Complete Quiz ✓',
              onPressed: () => _completeQuiz(provider),
              backgroundColor: Colors.green,
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
