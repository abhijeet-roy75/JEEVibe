/// Daily Quiz Question Screen (Refactored)
/// Uses DailyQuizProvider and extracted widgets
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/daily_quiz_question.dart';
import '../providers/daily_quiz_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/priya_avatar.dart';
import '../widgets/daily_quiz/question_card_widget.dart';
import '../widgets/daily_quiz/feedback_banner_widget.dart';
import '../widgets/daily_quiz/detailed_explanation_widget.dart';
import '../utils/error_handler.dart';
import 'daily_quiz_result_screen.dart';

// Note: This file was refactored. The old version is saved as daily_quiz_question_screen_old.dart

class DailyQuizQuestionScreen extends StatefulWidget {
  final DailyQuiz quiz;

  const DailyQuizQuestionScreen({
    super.key,
    required this.quiz,
  });

  @override
  State<DailyQuizQuestionScreen> createState() => _DailyQuizQuestionScreenState();
}

class _DailyQuizQuestionScreenState extends State<DailyQuizQuestionScreen> {
  Timer? _timer;
  bool _quizInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkForSavedState();
  }

  Future<void> _checkForSavedState() async {
    final provider = Provider.of<DailyQuizProvider>(context, listen: false);
    
    // C6: Wait for provider initialization to complete
    // Poll until restoration is complete (with timeout)
    int attempts = 0;
    const maxAttempts = 10; // 5 seconds max wait
    while (provider.isRestoringState && attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }
    
    // Set quiz in provider if not already set
    if (provider.currentQuiz == null || provider.currentQuiz!.quizId != widget.quiz.quizId) {
      provider.setQuiz(widget.quiz);
    }

    // C6: Check if we have a restored quiz with same ID (after restoration completes)
    if (provider.currentQuiz != null && provider.currentQuiz!.quizId == widget.quiz.quizId) {
      // State was restored, check if quiz was already started
      final questionState = provider.getQuestionState(provider.currentQuestionIndex);
      if (questionState != null && mounted) {
        // Quiz was in progress, resume
        setState(() {
          _quizInitialized = true;
        });
        _startTimer();
        return;
      }
    }
    
    // No saved state or quiz not started, initialize normally
    if (mounted) {
      _initializeQuiz();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeQuiz() async {
    final provider = Provider.of<DailyQuizProvider>(context, listen: false);
    
    // Set quiz in provider if not already set
    if (provider.currentQuiz == null || provider.currentQuiz!.quizId != widget.quiz.quizId) {
      provider.setQuiz(widget.quiz);
    }

    try {
      await ErrorHandler.handleApiError(
        context,
        () => provider.startQuiz(),
        showDialog: false,
      );
      
      if (mounted) {
        setState(() {
          _quizInitialized = true;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          message: ErrorHandler.getErrorMessage(e),
          onRetry: _initializeQuiz,
        );
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final provider = Provider.of<DailyQuizProvider>(context, listen: false);
    
    // Use current index from provider inside timer to avoid stale closure
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final provider = Provider.of<DailyQuizProvider>(context, listen: false);
      // Get current index fresh from provider each time
      final currentIndex = provider.currentQuestionIndex;
      final questionState = provider.getQuestionState(currentIndex);
      
      if (questionState == null || questionState.isAnswered) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(questionState.startTime).inSeconds;
      provider.updateQuestionTimer(currentIndex, elapsed);
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _handleOptionSelection(String answer) {
    // For MCQ questions, just select the answer (don't submit yet)
    final provider = Provider.of<DailyQuizProvider>(context, listen: false);
    provider.selectAnswer(answer);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleAnswerSubmission(String answer) async {
    final provider = Provider.of<DailyQuizProvider>(context, listen: false);
    final currentIndex = provider.currentQuestionIndex;
    final questionState = provider.getQuestionState(currentIndex);
    
    if (questionState?.isAnswered == true) return;

    // C3: Stop timer immediately when answer is submitted
    _timer?.cancel();
    _timer = null;

    // C7: Validate numerical answers
    final quiz = provider.currentQuiz;
    if (quiz != null && currentIndex < quiz.questions.length) {
      final question = quiz.questions[currentIndex];
      if (question.isNumerical) {
        // Validate numerical input
        final numValue = double.tryParse(answer);
        if (numValue == null) {
          if (mounted) {
            ErrorHandler.showErrorSnackBar(
              context,
              message: 'Please enter a valid number',
            );
          }
          return;
        }
      }
    }

    try {
      await ErrorHandler.handleApiError(
        context,
        () => provider.submitAnswer(answer),
        showDialog: false,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          message: ErrorHandler.getErrorMessage(e),
          onRetry: () => _handleAnswerSubmission(answer),
        );
      }
    }
  }

  void _handleNextQuestion() {
    final provider = Provider.of<DailyQuizProvider>(context, listen: false);
    
    if (provider.isQuizComplete) {
      _completeQuiz();
    } else {
      provider.nextQuestion();
      _startTimer();
      setState(() {});
    }
  }

  Future<void> _completeQuiz() async {
    final provider = Provider.of<DailyQuizProvider>(context, listen: false);
    
    try {
      final result = await ErrorHandler.handleApiError(
        context,
        () => provider.completeQuiz(),
        showDialog: false,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DailyQuizResultScreen(
              quizId: widget.quiz.quizId,
              resultData: result,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          message: ErrorHandler.getErrorMessage(e),
          onRetry: _completeQuiz,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DailyQuizProvider>(
      builder: (context, provider, child) {
        // Error state
        if (provider.hasError && !_quizInitialized) {
          return _buildErrorState(provider.error!);
        }

        // Loading state
        if (!_quizInitialized || provider.currentQuiz == null) {
          return const Scaffold(
            backgroundColor: AppColors.backgroundLight,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            ),
          );
        }

        final quiz = provider.currentQuiz!;
        final currentIndex = provider.currentQuestionIndex;
        
        // C4: Division by zero check
        if (quiz.totalQuestions == 0 || currentIndex >= quiz.questions.length) {
          return Scaffold(
            backgroundColor: AppColors.backgroundLight,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.errorRed),
                    const SizedBox(height: 16),
                    Text('Error', style: AppTextStyles.headerMedium),
                    const SizedBox(height: 8),
                    Text('Invalid quiz data', style: AppTextStyles.bodyMedium),
                  ],
                ),
              ),
            ),
          );
        }
        
        final question = quiz.questions[currentIndex];
        final questionState = provider.getQuestionState(currentIndex);
        final feedback = questionState?.feedback;
        final progress = quiz.totalQuestions > 0 ? (currentIndex + 1) / quiz.totalQuestions : 0.0;
        final elapsedTime = questionState?.elapsedSeconds ?? 0;

        // C2: Prevent back navigation during active quiz
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) async {
            if (didPop) return;
            
            // Show confirmation dialog
            final shouldPop = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Exit Quiz?', style: AppTextStyles.headerMedium),
                content: Text(
                  'Your progress will be saved, but you\'ll need to resume later. Are you sure you want to exit?',
                  style: AppTextStyles.bodyMedium,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Cancel', style: AppTextStyles.labelMedium),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorRed,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Exit', style: AppTextStyles.labelMedium),
                  ),
                ],
              ),
            );
            
            if (shouldPop == true && mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.backgroundLight,
            body: Column(
            children: [
              // Header
              _buildHeader(progress, elapsedTime, quiz.totalQuestions, currentIndex + 1, quiz),
              // Main content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Feedback banner (if answered)
                      if (feedback != null) ...[
                        FeedbackBannerWidget(
                          feedback: feedback,
                          timeTakenSeconds: elapsedTime,
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Question card
                      QuestionCardWidget(
                        key: ValueKey('question_${question.questionId}'),
                        question: question,
                        selectedAnswer: questionState?.selectedAnswer,
                        showAnswerOptions: feedback == null,
                        // FIX: Simplified callback logic - always provide callback when not yet answered
                        onAnswerSelected: feedback == null ? _handleOptionSelection : null,
                        onAnswerSubmitted: feedback == null 
                            ? ((question.options != null && question.options!.isNotEmpty && questionState?.selectedAnswer != null)
                                ? () => _handleAnswerSubmission(questionState!.selectedAnswer!)
                                : question.isNumerical
                                    ? () {
                                        // For numerical, get the answer from the text field
                                        // The onAnswerSelected callback will have been called when user types
                                        final provider = Provider.of<DailyQuizProvider>(context, listen: false);
                                        final currentState = provider.getQuestionState(provider.currentQuestionIndex);
                                        if (currentState?.selectedAnswer != null) {
                                          _handleAnswerSubmission(currentState!.selectedAnswer!);
                                        }
                                      }
                                    : null)
                            : null,
                        elapsedSeconds: elapsedTime,
                        feedback: feedback,
                      ),
                      const SizedBox(height: 16),
                      // Detailed explanation (if answered)
                      if (feedback != null) ...[
                        DetailedExplanationWidget(
                          feedback: feedback,
                          isCorrect: feedback.isCorrect,
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Teacher message
                      _buildTeacherMessage(feedback),
                      // Next button (if feedback shown)
                      if (feedback != null) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildActionButton(provider),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              // Bottom status bar
              _buildBottomStatusBar(quiz, currentIndex),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.errorRed),
              const SizedBox(height: 16),
              Text('Error', style: AppTextStyles.headerMedium.copyWith(color: AppColors.errorRed)),
              const SizedBox(height: 8),
              Text(error, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeQuiz,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double progress, int elapsedTime, int totalQuestions, int currentQuestion, DailyQuiz quiz) {
    final answeredCount = quiz.questions.where((q) => q.answered).length;
    final correctCount = quiz.questions.where((q) => q.isCorrect == true).length;
    
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top line with back button and centered title/subtitle
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Adaptive Daily Quiz',
                          style: AppTextStyles.headerWhite.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Personalized for your growth',
                          style: AppTextStyles.bodyWhite.copyWith(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  // Spacer to balance the back button
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 16),
              // Progress card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Question $currentQuestion/$totalQuestions',
                            style: AppTextStyles.bodyWhite.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withValues(alpha: 0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$correctCount correct',
                      style: AppTextStyles.bodyWhite.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherMessage(AnswerFeedback? feedback) {
    String message;
    if (feedback == null) {
      message = "Take your time and think carefully. You've got this! 💪";
    } else if (feedback.isCorrect) {
      message = "Excellent! You understood this concept well. Keep it up! 🎯";
    } else {
      message = "Don't worry! Understanding why you made this mistake is valuable. Review the explanation carefully! 📚";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryPurple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const PriyaAvatar(size: 48),
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
                      const Text('✨', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
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
    );
  }

  Widget _buildActionButton(DailyQuizProvider provider) {
    final isLastQuestion = provider.isQuizComplete;
    
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: provider.isSubmittingAnswer ? null : _handleNextQuestion,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: provider.isSubmittingAnswer
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                isLastQuestion ? 'Complete Quiz' : 'Next Question',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildBottomStatusBar(DailyQuiz quiz, int currentIndex) {
    final answeredCount = quiz.questions.where((q) => q.answered).length;
    final correctCount = quiz.questions.where((q) => q.isCorrect == true).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.my_location,
            text: '$answeredCount/${quiz.totalQuestions} answered',
            color: AppColors.primaryPurple,
          ),
          _buildStatItem(
            icon: Icons.check_circle,
            text: '$correctCount correct',
            color: AppColors.successGreen,
          ),
          _buildStatItem(
            icon: Icons.local_fire_department,
            text: 'Stay focused!',
            color: AppColors.warningAmber,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textMedium,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

