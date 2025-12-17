/// Daily Quiz Question Screen
/// Displays questions one at a time with immediate feedback
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/daily_quiz_question.dart';
import '../services/api_service.dart';
import '../services/firebase/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/latex_widget.dart';
import '../widgets/safe_svg_widget.dart';
import '../widgets/priya_avatar.dart';
import 'package:flutter_html/flutter_html.dart';
import 'daily_quiz_result_screen.dart';

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
  int _currentQuestionIndex = 0;
  Map<int, DateTime> _questionStartTimes = {};
  Map<int, Timer?> _questionTimers = {};
  Map<int, int> _questionElapsedSeconds = {};
  Map<int, String?> _selectedAnswers = {};
  Map<int, AnswerFeedback?> _answerFeedbacks = {};
  Map<int, bool> _showDetailedExplanation = {};
  Map<int, TextEditingController> _numericalControllers = {}; // Controllers for numerical inputs
  bool _isSubmitting = false;
  bool _quizStarted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startQuiz();
  }

  @override
  void dispose() {
    for (var timer in _questionTimers.values) {
      timer?.cancel();
    }
    for (var controller in _numericalControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _startQuiz() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();
      
      if (token == null) {
        setState(() {
          _error = 'Authentication required. Please log in again.';
        });
        return;
      }

      // Start the quiz on backend
      await ApiService.startDailyQuiz(
        authToken: token,
        quizId: widget.quiz.quizId,
      );

      // Start timer for first question
      if (mounted) {
        setState(() {
          _quizStarted = true;
          _questionStartTimes[0] = DateTime.now();
          _questionElapsedSeconds[0] = 0;
          _startQuestionTimer(0);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _startQuestionTimer(int questionIndex) {
    _questionTimers[questionIndex]?.cancel();
    _questionTimers[questionIndex] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _answerFeedbacks[questionIndex] == null) {
        setState(() {
          _questionElapsedSeconds[questionIndex] = 
              (DateTime.now().difference(_questionStartTimes[questionIndex] ?? DateTime.now())).inSeconds;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  DailyQuizQuestion? get _currentQuestion {
    if (_currentQuestionIndex >= widget.quiz.questions.length) {
      return null;
    }
    return widget.quiz.questions[_currentQuestionIndex];
  }

  bool get _isLastQuestion => _currentQuestionIndex == widget.quiz.questions.length - 1;
  bool get _hasAnswer => _selectedAnswers.containsKey(_currentQuestionIndex) && 
                        _selectedAnswers[_currentQuestionIndex] != null &&
                        _selectedAnswers[_currentQuestionIndex]!.isNotEmpty;
  bool get _hasFeedback => _answerFeedbacks.containsKey(_currentQuestionIndex);

  int get _correctCount {
    return _answerFeedbacks.values.where((f) => f?.isCorrect == true).length;
  }

  void _selectAnswer(String answer) {
    if (_hasFeedback) return; // Don't allow changing answer after feedback
    
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = answer;
    });
  }

  Future<void> _submitAnswer() async {
    if (_isSubmitting || !_hasAnswer || _hasFeedback) return;

    final question = _currentQuestion;
    if (question == null) return;

    // Stop timer
    _questionTimers[_currentQuestionIndex]?.cancel();
    final timeTaken = _questionElapsedSeconds[_currentQuestionIndex] ?? 0;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();
      
      if (token == null) {
        throw Exception('Authentication required');
      }

      final feedback = await ApiService.submitAnswer(
        authToken: token,
        quizId: widget.quiz.quizId,
        questionId: question.questionId,
        studentAnswer: _selectedAnswers[_currentQuestionIndex]!,
        timeTakenSeconds: timeTaken,
      );

      if (mounted) {
        setState(() {
          _answerFeedbacks[_currentQuestionIndex] = feedback;
          _showDetailedExplanation[_currentQuestionIndex] = true; // Show by default
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error!),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _nextQuestion() {
    if (_isLastQuestion) {
      _completeQuiz();
    } else {
      setState(() {
        _currentQuestionIndex++;
        _questionStartTimes[_currentQuestionIndex] = DateTime.now();
        _questionElapsedSeconds[_currentQuestionIndex] = 0;
        _startQuestionTimer(_currentQuestionIndex);
      });
    }
  }

  Future<void> _completeQuiz() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();
      
      if (token == null) {
        throw Exception('Authentication required');
      }

      final result = await ApiService.completeDailyQuiz(
        authToken: token,
        quizId: widget.quiz.quizId,
      );

      if (mounted) {
        // Navigate to results screen
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
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error!),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && !_quizStarted) {
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
                Text(_error!, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                    });
                    _startQuiz();
                  },
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

    if (_currentQuestion == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    final question = _currentQuestion;
    final feedback = _answerFeedbacks[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / widget.quiz.totalQuestions;
    final elapsedTime = _questionElapsedSeconds[_currentQuestionIndex] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // Purple header with progress
          _buildHeader(progress, elapsedTime),
          // Main content
          Expanded(
            child: SingleChildScrollView(
            child: Column(
              children: [
                // Feedback banner (if answered)
                if (feedback != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildFeedback(feedback, question),
                  ),
                  const SizedBox(height: 16),
                ],
                // White card with question
                _buildQuestionCard(question, feedback),
                const SizedBox(height: 16),
                // Teacher message
                _buildTeacherMessage(feedback),
                // Next button (if feedback shown)
                if (feedback != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildActionButton(feedback),
                  ),
                ],
              ],
            ),
            ),
          ),
          // Bottom status bar
          _buildBottomStatusBar(),
        ],
      ),
    );
  }

  Widget _buildHeader(double progress, int elapsedTime) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row: Back button, Daily Quiz badge, empty space
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Daily Quiz',
                          style: AppTextStyles.bodyWhite.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    'Adaptive Daily Quiz',
                    style: AppTextStyles.headerWhite.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Personalized for your growth',
                    style: AppTextStyles.bodyWhite.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Progress bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${_currentQuestionIndex + 1}/${widget.quiz.totalQuestions}',
                        style: AppTextStyles.bodyWhite.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$_correctCount correct',
                    style: AppTextStyles.bodyWhite.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(DailyQuizQuestion question, AnswerFeedback? feedback) {
    return Container(
      margin: const EdgeInsets.all(16),
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
          // Subject and timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.successGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${question.subject} • ${question.chapter}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: AppColors.successGreen),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(_questionElapsedSeconds[_currentQuestionIndex] ?? 0),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.successGreen,
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
          Row(
            children: [
              const Icon(Icons.psychology, color: AppColors.primaryPurple, size: 20),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Question ${question.position}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryPurple,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Moderate',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.warningAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Question text
          if (question.questionTextHtml != null)
            Html(data: question.questionTextHtml, style: {
              'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
            })
          else
            Text(
              question.questionText,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          if (question.hasImage) ...[
            const SizedBox(height: 16),
            SafeSvgWidget(imageUrl: question.imageUrl!),
          ],
          const SizedBox(height: 24),
          // Answer options
          if (question.isMcq && question.options != null)
            ...question.options!.map((option) => _buildMcqOption(option, feedback)),
          if (question.isNumerical)
            _buildNumericalInput(feedback),
          // Submit button (only show if no feedback yet)
          if (feedback == null) ...[
            const SizedBox(height: 16),
            _buildActionButton(feedback),
          ],
        ],
      ),
    );
  }

  Widget _buildMcqOption(QuestionOption option, AnswerFeedback? feedback) {
    final isSelected = _selectedAnswers[_currentQuestionIndex] == option.optionId;
    final isCorrect = feedback?.isCorrect == true && option.optionId == feedback.correctAnswer;
    final isWrong = feedback?.isCorrect == false && isSelected && option.optionId != feedback.correctAnswer;
    final showCorrect = feedback != null && option.optionId == feedback.correctAnswer;

    Color backgroundColor = Colors.white;
    Color borderColor = AppColors.borderGray;
    Color textColor = AppColors.textDark;
    Widget? trailingIcon;

    if (feedback != null) {
      if (isCorrect || showCorrect) {
        backgroundColor = AppColors.successGreen.withOpacity(0.1);
        borderColor = AppColors.successGreen;
        textColor = AppColors.successGreen;
        trailingIcon = const Icon(Icons.check_circle, color: AppColors.successGreen);
      } else if (isWrong) {
        backgroundColor = AppColors.errorRed.withOpacity(0.1);
        borderColor = AppColors.errorRed;
        textColor = AppColors.errorRed;
        trailingIcon = const Icon(Icons.cancel, color: AppColors.errorRed);
      }
    } else if (isSelected) {
      backgroundColor = AppColors.primaryPurple.withOpacity(0.1);
      borderColor = AppColors.primaryPurple;
      textColor = AppColors.primaryPurple;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: feedback == null ? () => _selectAnswer(option.optionId) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: borderColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    option.optionId,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: borderColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: option.html != null
                    ? Html(data: option.html, style: {
                        'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
                      })
                    : Text(
                        option.text,
                        style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                      ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                trailingIcon,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumericalInput(AnswerFeedback? feedback) {
    // Get or create controller for this question
    // Controller persists across rebuilds
    if (!_numericalControllers.containsKey(_currentQuestionIndex)) {
      final initialValue = _selectedAnswers[_currentQuestionIndex] ?? '';
      _numericalControllers[_currentQuestionIndex] = TextEditingController(text: initialValue);
    }
    
    final controller = _numericalControllers[_currentQuestionIndex]!;
    
    return TextField(
      controller: controller,
      enabled: feedback == null,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(
        hintText: 'Enter your answer',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
        ),
      ),
      onChanged: (value) => _selectAnswer(value),
    );
  }

  Widget _buildFeedback(AnswerFeedback feedback, DailyQuizQuestion question) {
    final isExpanded = _showDetailedExplanation[_currentQuestionIndex] ?? true;
    final studentAnswer = _selectedAnswers[_currentQuestionIndex] ?? feedback.studentAnswer ?? '';
    
    return Column(
      children: [
        // Status Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: feedback.isCorrect ? AppColors.successGreen : AppColors.errorRed,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  feedback.isCorrect ? Icons.check : Icons.close,
                  color: feedback.isCorrect ? AppColors.successGreen : AppColors.errorRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feedback.isCorrect ? 'Correct Answer!' : 'Incorrect Answer',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feedback.isCorrect 
                          ? 'Well done! You got this right.'
                          : 'Your answer: ${_getOptionLabel(studentAnswer)} • Correct: ${_getOptionLabel(feedback.correctAnswer ?? '')}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(feedback.timeTakenSeconds),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Detailed Explanation (Expandable)
        _buildDetailedExplanation(feedback, question, isExpanded),
      ],
    );
  }

  String _getOptionLabel(String? optionId) {
    if (optionId == null || optionId.isEmpty) return '';
    return optionId.toUpperCase();
  }

  Widget _buildDetailedExplanation(AnswerFeedback feedback, DailyQuizQuestion question, bool isExpanded) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        children: [
          // Header (always visible)
          InkWell(
            onTap: () {
              setState(() {
                _showDetailedExplanation[_currentQuestionIndex] = !isExpanded;
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
                      isExpanded ? 'Hide Detailed Explanation' : 'Show Detailed Explanation',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.remove : Icons.add,
                    color: AppColors.primaryPurple,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Content (expandable)
          if (isExpanded) ...[
            Divider(height: 1, color: AppColors.borderGray),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Explanation
                  if (feedback.explanation != null || feedback.solutionText != null) ...[
                    _buildExplanationSection(
                      icon: Icons.lightbulb,
                      iconColor: AppColors.warningAmber,
                      title: 'Quick Explanation',
                      content: feedback.explanation ?? feedback.solutionText ?? '',
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Step-by-Step Solution
                  if (feedback.solutionSteps != null && feedback.solutionSteps!.isNotEmpty) ...[
                    _buildStepByStepSolution(feedback.solutionSteps!),
                    const SizedBox(height: 16),
                  ],
                  // Why You Got This Wrong (only for incorrect answers)
                  if (!feedback.isCorrect) ...[
                    _buildWhyWrongSection(feedback, question),
                    const SizedBox(height: 16),
                  ],
                  // Key Takeaway
                  _buildKeyTakeawaySection(feedback, question),
                ],
              ),
            ),
          ],
        ],
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
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Html(
                data: content,
                style: {
                  'body': Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                    fontSize: FontSize(14),
                    color: Color(AppColors.textMedium.value),
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
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              ...steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final stepNumber = step.stepNumber ?? (index + 1);
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
                          color: AppColors.successGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$stepNumber',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.successGreen,
                              fontWeight: FontWeight.w700,
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
                              fontSize: FontSize(14),
                              color: Color(AppColors.textMedium.value),
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

  Widget _buildWhyWrongSection(AnswerFeedback feedback, DailyQuizQuestion question) {
    // Generate explanation based on the mistake
    String whyWrong = "Review the explanation carefully. Understanding why you made this mistake helps you avoid it in the future.";
    
    // Try to infer why they got it wrong based on the question type
    if (question.isMcq) {
      whyWrong = "Students often confuse similar concepts. Review the explanation and make sure you understand the key differences between the options.";
    }
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.warningAmber.withOpacity(0.2),
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
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                whyWrong,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeyTakeawaySection(AnswerFeedback feedback, DailyQuizQuestion question) {
    String takeaway = "Review the key concepts covered in this question to strengthen your understanding.";
    
    if (feedback.solutionText != null && feedback.solutionText!.isNotEmpty) {
      // Try to extract key takeaway from solution text
      takeaway = feedback.solutionText!;
    }
    
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
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryPurple,
                ),
              ),
              const SizedBox(height: 8),
              Html(
                data: takeaway,
                style: {
                  'body': Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                    fontSize: FontSize(14),
                    color: Color(AppColors.textMedium.value),
                  ),
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(AnswerFeedback? feedback) {
    final hasAnswer = _hasAnswer;
    final isSubmitting = _isSubmitting;

    if (feedback != null) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isSubmitting ? null : _nextQuestion,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isLastQuestion ? 'Complete Quiz' : 'Next Question',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 20),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: (hasAnswer && !isSubmitting) ? _submitAnswer : null,
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
    );
  }

  Widget _buildTeacherMessage(AnswerFeedback? feedback) {
    String message;
    if (feedback == null) {
      message = "Take your time to think through each option carefully. You've got this! 📚";
    } else if (feedback.isCorrect) {
      message = "Excellent work! You're mastering this concept. Keep up the great momentum! 🎉";
    } else {
      message = "Don't worry! Mistakes help us learn. Review the explanation and you'll get it next time! 💪";
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.1),
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
                Text(
                  'Priya Ma\'am ✨',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryPurple,
                  ),
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
    );
  }

  Widget _buildBottomStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes, color: AppColors.primaryPurple, size: 20),
              const SizedBox(width: 4),
              Text(
                '${_currentQuestionIndex + 1}/10 answered',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.successGreen, size: 20),
              const SizedBox(width: 4),
              Text(
                '$_correctCount correct',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.successGreen,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: AppColors.warningAmber, size: 20),
              const SizedBox(width: 4),
              Text(
                'Stay focused!',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.warningAmber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

