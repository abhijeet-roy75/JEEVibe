/// Chapter Practice Question Screen
/// Main question interface for chapter practice (no timer, practice mode)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chapter_practice_models.dart';
import '../../providers/chapter_practice_provider.dart';
import '../../services/firebase/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/priya_avatar.dart';
import '../../utils/error_handler.dart';
import '../../utils/question_adapters.dart';
import '../../widgets/daily_quiz/feedback_banner_widget.dart';
import '../../widgets/daily_quiz/detailed_explanation_widget.dart';
import 'chapter_practice_review_screen.dart';

class ChapterPracticeQuestionScreen extends StatefulWidget {
  const ChapterPracticeQuestionScreen({super.key});

  @override
  State<ChapterPracticeQuestionScreen> createState() =>
      _ChapterPracticeQuestionScreenState();
}

class _ChapterPracticeQuestionScreenState
    extends State<ChapterPracticeQuestionScreen> {
  String? _selectedOption;
  DateTime? _questionStartTime;
  bool _isCompletingSession = false;

  // Numerical input controller
  late TextEditingController _numericalController;

  @override
  void initState() {
    super.initState();
    _questionStartTime = DateTime.now();
    _numericalController = TextEditingController();
  }

  @override
  void dispose() {
    _numericalController.dispose();
    super.dispose();
  }

  int get _elapsedSeconds {
    if (_questionStartTime == null) return 0;
    return DateTime.now().difference(_questionStartTime!).inSeconds;
  }

  Future<void> _handleAnswerSubmission() async {
    final provider =
        Provider.of<ChapterPracticeProvider>(context, listen: false);
    final question = provider.currentQuestion;
    if (question == null) return;

    // Prevent re-submission of already answered questions (e.g., from resumed session)
    if (question.answered) return;

    // Get the answer based on question type
    final String? answer;
    if (question.isNumerical) {
      final numericalAnswer = _numericalController.text.trim();
      if (numericalAnswer.isEmpty) return;
      answer = numericalAnswer;
    } else {
      if (_selectedOption == null) return;
      answer = _selectedOption;
    }

    if (provider.isSubmitting) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getIdToken();

    if (token == null) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          message: 'Authentication required',
        );
      }
      return;
    }

    try {
      await ErrorHandler.handleApiError(
        context,
        () => provider.submitAnswer(
          answer!,
          token,
          timeTakenSeconds: _elapsedSeconds,
        ),
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
          onRetry: _handleAnswerSubmission,
        );
      }
    }
  }

  void _handleNextQuestion() {
    final provider =
        Provider.of<ChapterPracticeProvider>(context, listen: false);

    if (!provider.hasMoreQuestions) {
      _completeSession();
    } else {
      provider.nextQuestion();
      setState(() {
        _selectedOption = null;
        _numericalController.clear();
        _questionStartTime = DateTime.now();
      });
    }
  }

  Future<void> _completeSession() async {
    if (_isCompletingSession) return;

    final provider =
        Provider.of<ChapterPracticeProvider>(context, listen: false);
    if (provider.isLoading) return;

    setState(() {
      _isCompletingSession = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getIdToken();

    if (token == null) {
      if (mounted) {
        setState(() {
          _isCompletingSession = false;
        });
        ErrorHandler.showErrorSnackBar(
          context,
          message: 'Authentication required',
        );
      }
      return;
    }

    try {
      final summary = await ErrorHandler.handleApiError(
        context,
        () => provider.completeSession(token),
        showDialog: false,
      );

      if (mounted && summary != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChapterPracticeReviewScreen(summary: summary),
          ),
        );
      } else if (mounted) {
        // Even if summary is null, navigate to review with results from provider
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChapterPracticeReviewScreen(
              summary: null,
              results: provider.results,
              session: provider.session,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCompletingSession = false;
        });

        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('already completed')) {
          // Session was completed, navigate to review
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ChapterPracticeReviewScreen(
                summary: null,
                results: provider.results,
                session: provider.session,
              ),
            ),
          );
        } else {
          ErrorHandler.showErrorSnackBar(
            context,
            message: ErrorHandler.getErrorMessage(e),
            onRetry: _completeSession,
          );
        }
      }
    }
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
        return AppColors.primaryPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChapterPracticeProvider>(
      builder: (context, provider, child) {
        if (provider.session == null || provider.currentQuestion == null) {
          return Scaffold(
            backgroundColor: AppColors.backgroundLight,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.errorRed),
                  const SizedBox(height: 16),
                  Text('No session found', style: AppTextStyles.headerMedium),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final session = provider.session!;
        final question = provider.currentQuestion!;
        final currentIndex = provider.currentQuestionIndex;
        final totalQuestions = session.totalQuestions;
        final progress =
            totalQuestions > 0 ? (currentIndex + 1) / totalQuestions : 0.0;
        // Use provider's encapsulated logic for answer state
        final isAnswered = provider.currentQuestionIsAnswered;
        final hasFullFeedback = provider.hasFullFeedbackAvailable;

        // Completely prevent back navigation during active practice session
        // Students MUST complete the session - progress is auto-saved
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) async {
            // Completely block back navigation - session must be completed
            // Progress is auto-saved, so if app is killed, it will resume on restart
            if (!didPop && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Please complete the practice. Your progress is auto-saved.',
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
                  ),
                  backgroundColor: AppColors.primaryPurple,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.backgroundLight,
            body: Column(
              children: [
                // Header
                _buildHeader(session, currentIndex + 1, totalQuestions,
                    progress, provider.correctCount),
                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        // Feedback banner (if answered with full result available) - using shared widget
                        if (hasFullFeedback) ...[
                          FeedbackBannerWidget(
                            feedback: practiceResultToFeedback(
                              provider.lastAnswerResult!,
                              questionId: question.questionId,
                              timeTakenSeconds: _elapsedSeconds,
                              questionType: question.questionType,
                            ),
                            timeTakenSeconds: _elapsedSeconds,
                          ),
                          const SizedBox(height: 16),
                        ],
                        // For resumed already-answered questions without full feedback, show simple indicator
                        if (isAnswered && !hasFullFeedback) ...[
                          _buildResumedAnswerIndicator(question),
                          const SizedBox(height: 16),
                        ],
                        // Question card
                        _buildQuestionCard(question, isAnswered),
                        const SizedBox(height: 16),
                        // Solution (if full feedback available) - using shared widget
                        if (hasFullFeedback) ...[
                          DetailedExplanationWidget(
                            feedback: practiceResultToFeedback(
                              provider.lastAnswerResult!,
                              questionId: question.questionId,
                              timeTakenSeconds: _elapsedSeconds,
                              questionType: question.questionType,
                            ),
                            isCorrect: provider.lastAnswerResult!.isCorrect,
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Teacher message
                        _buildTeacherMessage(provider.lastAnswerResult),
                        // Action button
                        if (isAnswered) ...[
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
                _buildBottomStatusBar(provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ChapterPracticeSession session, int currentQuestion,
      int totalQuestions, double progress, int correctCount) {
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
              // Top line with centered title (no back button - session must be completed)
              Row(
                children: [
                  // Spacer to balance the layout (no back button during practice)
                  const SizedBox(width: 48),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Chapter Practice',
                          style: AppTextStyles.headerWhite.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          session.chapterName,
                          style: AppTextStyles.bodyWhite.copyWith(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Practice mode badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_off_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Practice',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
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

  // _buildFeedbackBanner removed - using shared FeedbackBannerWidget via adapter

  Widget _buildQuestionCard(PracticeQuestion question, bool isAnswered) {
    final provider = Provider.of<ChapterPracticeProvider>(context, listen: false);
    final currentIndex = provider.currentQuestionIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject, chapter, and question number tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        _getSubjectColor(question.subject).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    question.subject,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: _getSubjectColor(question.subject),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Question ${currentIndex + 1}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Question text
            Text(
              question.questionText,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            // Show numerical input or MCQ options based on question type
            if (question.isNumerical) ...[
              // Numerical input field
              _buildNumericalInput(isAnswered),
            ] else if (question.options.isEmpty) ...[
              // Error state: MCQ without options - allow skipping
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warningAmber.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warningAmber,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Question options unavailable',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.warningAmber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This question has a data issue. You can skip it.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMedium,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleNextQuestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warningAmber,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          provider.hasMoreQuestions ? 'Skip to Next Question' : 'Complete Practice',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Options
              ...question.options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = _selectedOption == option.optionId;
              final answerResult =
                  Provider.of<ChapterPracticeProvider>(context, listen: false)
                      .lastAnswerResult;
              final isCorrectOption =
                  answerResult?.correctAnswer == option.optionId;
              final showAsCorrect = isAnswered && isCorrectOption;
              final showAsWrong =
                  isAnswered && isSelected && !answerResult!.isCorrect;

              Color bgColor = AppColors.backgroundLight;
              Color borderColor = AppColors.borderGray;

              if (showAsCorrect) {
                bgColor = AppColors.successGreen.withValues(alpha: 0.1);
                borderColor = AppColors.successGreen;
              } else if (showAsWrong) {
                bgColor = AppColors.errorRed.withValues(alpha: 0.1);
                borderColor = AppColors.errorRed;
              } else if (isSelected && !isAnswered) {
                bgColor = AppColors.primaryPurple.withValues(alpha: 0.1);
                borderColor = AppColors.primaryPurple;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: isAnswered
                      ? null
                      : () {
                          setState(() {
                            _selectedOption = option.optionId;
                          });
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: showAsCorrect
                                ? AppColors.successGreen
                                : showAsWrong
                                    ? AppColors.errorRed
                                    : isSelected
                                        ? AppColors.primaryPurple
                                        : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: showAsCorrect
                                  ? AppColors.successGreen
                                  : showAsWrong
                                      ? AppColors.errorRed
                                      : isSelected
                                          ? AppColors.primaryPurple
                                          : AppColors.borderGray,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: showAsCorrect || showAsWrong
                                ? Icon(
                                    showAsCorrect ? Icons.check : Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : Text(
                                    String.fromCharCode(65 + index),
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textMedium,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option.text,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            // Submit button (if not answered) - for MCQ options only
            // Numerical questions have their own submit button in _buildNumericalInput
            if (!isAnswered && _selectedOption != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: Provider.of<ChapterPracticeProvider>(context)
                          .isSubmitting
                      ? null
                      : _handleAnswerSubmission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      Provider.of<ChapterPracticeProvider>(context).isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Submit Answer',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                ),
              ),
            ],
            ], // end of else block (MCQ options available)
          ],
        ),
      ),
    );
  }

  // _buildSolutionCard removed - using shared DetailedExplanationWidget via adapter

  Widget _buildTeacherMessage(PracticeAnswerResult? result) {
    String message;
    if (result == null) {
      message = "Take your time - there's no timer. Focus on understanding!";
    } else if (result.isCorrect) {
      message = "Excellent! You're making great progress on this chapter!";
    } else {
      message =
          "No worries! Review the solution carefully. Practice makes perfect!";
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
                      const Text('', style: TextStyle(fontSize: 16)),
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

  /// Shows a simple indicator for resumed questions that were already answered
  /// (when we don't have the full lastAnswerResult with solution details)
  Widget _buildResumedAnswerIndicator(PracticeQuestion question) {
    final isCorrect = question.isCorrect ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCorrect
              ? AppColors.successGreen.withValues(alpha: 0.1)
              : AppColors.errorRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCorrect ? 'Correct!' : 'Incorrect',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You answered: ${question.studentAnswer ?? "N/A"}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMedium,
                    ),
                  ),
                  if (!isCorrect && question.correctAnswer != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Correct answer: ${question.correctAnswer}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.successGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(ChapterPracticeProvider provider) {
    final isLastQuestion = !provider.hasMoreQuestions;
    final isLoading = provider.isLoading || _isCompletingSession;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleNextQuestion,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                isLastQuestion ? 'Complete Practice' : 'Next Question',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildNumericalInput(bool isAnswered) {
    final provider = Provider.of<ChapterPracticeProvider>(context, listen: false);
    final answerResult = provider.lastAnswerResult;

    if (isAnswered && answerResult != null) {
      // Show submitted answer with feedback
      final isCorrect = answerResult.isCorrect;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCorrect
              ? AppColors.successGreen.withValues(alpha: 0.1)
              : AppColors.errorRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isCorrect ? 'Correct!' : 'Incorrect',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your answer: ${answerResult.studentAnswer}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textDark,
              ),
            ),
            if (!isCorrect) ...[
              const SizedBox(height: 4),
              Text(
                'Correct answer: ${answerResult.correctAnswer}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.successGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Show input field for answering
    final hasAnswer = _numericalController.text.trim().isNotEmpty;
    final isSubmitting = provider.isSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter your numerical answer:',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textMedium,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
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
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderGray),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          style: AppTextStyles.bodyMedium,
          onChanged: (value) {
            // Trigger rebuild to update submit button state
            setState(() {});
          },
          onSubmitted: hasAnswer ? (_) => _handleAnswerSubmission() : null,
        ),
        const SizedBox(height: 16),
        // Submit button for numerical questions
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: hasAnswer && !isSubmitting ? _handleAnswerSubmission : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: hasAnswer ? AppColors.primaryPurple : AppColors.borderGray,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Submit Answer',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomStatusBar(ChapterPracticeProvider provider) {
    final correctCount = provider.correctCount;
    final totalAnswered = provider.totalAnswered;
    final session = provider.session;

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
            text: '$totalAnswered/${session?.totalQuestions ?? 0} answered',
            color: AppColors.primaryPurple,
          ),
          _buildStatItem(
            icon: Icons.check_circle,
            text: '$correctCount correct',
            color: AppColors.successGreen,
          ),
          _buildStatItem(
            icon: Icons.timer_off_outlined,
            text: 'No timer',
            color: AppColors.textMedium,
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
