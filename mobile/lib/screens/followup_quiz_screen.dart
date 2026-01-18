/// Practice Questions Screen - Matches design: 11 Practice Questions.png
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/solution_model.dart';
import '../models/snap_data_model.dart';
import '../widgets/latex_widget.dart';
import '../widgets/chemistry_text.dart';
import '../widgets/app_header.dart';
import '../services/api_service.dart';
import '../services/firebase/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../providers/app_state_provider.dart';
import 'practice_results_screen.dart';
import '../config/content_config.dart';
import '../utils/text_preprocessor.dart';

class FollowUpQuizScreen extends StatefulWidget {
  final String recognizedQuestion;
  final SolutionDetails solution;
  final String topic;
  final String difficulty;
  final String subject; // Mathematics, Physics, or Chemistry
  final String language; // "en" or "hi"

  const FollowUpQuizScreen({
    super.key,
    required this.recognizedQuestion,
    required this.solution,
    required this.topic,
    required this.difficulty,
    required this.subject,
    this.language = 'en',
  });

  @override
  State<FollowUpQuizScreen> createState() => _FollowUpQuizScreenState();
}

class _FollowUpQuizScreenState extends State<FollowUpQuizScreen> {
  List<FollowUpQuestion?> _questions = [null, null, null];
  List<bool> _questionLoading = [false, false, false];
  List<String?> _questionErrors = [null, null, null];
  int currentQuestionIndex = 0;
  String? selectedAnswer;
  bool showFeedback = false;
  bool isCorrect = false;
  int correctCount = 0;
  Timer? _timer;
  int timeRemaining = 90;
  DateTime? _sessionStartTime;
  DateTime? _questionStartTime;
  List<QuestionResult> _questionResults = [];
  bool _dbQuestionsLoaded = false; // Track if we've tried DB loading
  String _questionSource = 'unknown'; // Track source: "database", "ai", "mixed"

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _loadQuestionsFromDatabase(); // Try DB first, then fallback to AI
  }

  /// Try to load all questions from database first
  /// Falls back to AI generation if DB has no matching questions
  Future<void> _loadQuestionsFromDatabase() async {
    if (_dbQuestionsLoaded) return;
    _dbQuestionsLoaded = true;

    setState(() {
      _questionLoading = [true, true, true];
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      String? token = await authService.getIdToken();
      if (token == null && authService.currentUser != null) {
        token = await authService.currentUser!.getIdToken(true);
      }

      if (token == null) {
        throw Exception('Authentication required. Please sign in again.');
      }

      // Try to get questions from database
      final result = await ApiService.getSnapPracticeQuestions(
        authToken: token,
        subject: widget.subject,
        topic: widget.topic,
        difficulty: widget.difficulty,
        count: 3,
        language: widget.language,
        recognizedQuestion: widget.recognizedQuestion,
        solution: {
          'approach': widget.solution.approach,
          'steps': widget.solution.steps,
          'finalAnswer': widget.solution.finalAnswer,
          'priyaMaamTip': widget.solution.priyaMaamTip,
        },
      );

      // Safely extract questions list from result
      final questionsList = result['questions'];
      final List<FollowUpQuestion> questions = questionsList is List
          ? questionsList.whereType<FollowUpQuestion>().toList()
          : <FollowUpQuestion>[];
      _questionSource = result['source'] as String? ?? 'unknown';

      if (mounted && questions.isNotEmpty) {
        setState(() {
          for (int i = 0; i < questions.length && i < 3; i++) {
            _questions[i] = questions[i];
            _questionLoading[i] = false;
          }
          // Mark any remaining slots as not loading
          for (int i = questions.length; i < 3; i++) {
            _questionLoading[i] = false;
          }
        });

        // Start timer for first question
        if (_questions[0] != null && _timer == null) {
          _startTimer();
        }
        return;
      }
    } catch (e) {
      // Database loading failed, will fallback to AI
    }

    // Fallback: Load questions via AI (original lazy-loading approach)
    if (mounted) {
      setState(() {
        // Reset loading states - _loadQuestion will set the appropriate one
        _questionLoading = [false, false, false];
      });
      _questionSource = 'ai';
      _loadQuestion(0); // This will set _questionLoading[0] = true and start AI generation
    }
  }

  /// Load a single question via AI (fallback method)
  /// Used when database doesn't have questions for the current slot
  Future<void> _loadQuestion(int index) async {
    if (index < 0 || index >= 3) return;
    if (_questions[index] != null || _questionLoading[index]) return;

    setState(() {
      _questionLoading[index] = true;
      _questionErrors[index] = null;
    });

    try {
      // Get authentication token with refresh capability
      final authService = Provider.of<AuthService>(context, listen: false);

      // Get token right before use to avoid race conditions
      String? token;
      try {
        token = await authService.getIdToken();
        // If null, try to refresh
        if (token == null && authService.currentUser != null) {
          token = await authService.currentUser!.getIdToken(true); // Force refresh
        }
      } catch (e) {
        throw Exception('Authentication required. Please sign in again.');
      }

      if (token == null) {
        throw Exception('Authentication required. Please sign in again.');
      }

      final question = await ApiService.generateSingleQuestion(
        authToken: token!, // Non-null assertion safe here after null check
        recognizedQuestion: widget.recognizedQuestion,
        solution: {
          'approach': widget.solution.approach,
          'steps': widget.solution.steps,
          'finalAnswer': widget.solution.finalAnswer,
          'priyaMaamTip': widget.solution.priyaMaamTip,
        },
        topic: widget.topic,
        difficulty: widget.difficulty,
        questionNumber: index + 1,
      );

      if (mounted) {
        setState(() {
          _questions[index] = question;
          _questionLoading[index] = false;
        });

        if (index == 0 && _timer == null) {
          _startTimer();
        }
      }
    } catch (e) {
      if (mounted) {
        // Handle rate limiting errors specifically
        String errorMessage = e.toString();
        if (errorMessage.contains('Too many requests')) {
          errorMessage = 'Too many requests. Please wait a moment and try again.';
        } else if (errorMessage.contains('Authentication')) {
          errorMessage = 'Authentication required. Please sign in again.';
        }

        setState(() {
          _questionErrors[index] = errorMessage;
          _questionLoading[index] = false;
        });
      }
    }
  }

  void _startTimer() {
    _questionStartTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeRemaining > 0) {
        setState(() {
          timeRemaining--;
        });
      } else {
        _submitAnswer(null);
      }
    });
  }

  void _selectAnswer(String answer) {
    if (!showFeedback) {
      setState(() {
        selectedAnswer = answer;
      });
    }
  }

  void _submitAnswer(String? answer) {
    _timer?.cancel();
    
    final question = _questions[currentQuestionIndex];
    if (question == null) return;
    
    final isAnswerCorrect = answer == question.correctAnswer;
    
    // Calculate time spent on this question
    int timeSpent = 0;
    if (_questionStartTime != null) {
      final elapsed = DateTime.now().difference(_questionStartTime!);
      timeSpent = elapsed.inSeconds;
      // If timer ran out, use the full 90 seconds
      if (timeSpent > 90) {
        timeSpent = 90;
      }
    } else {
      // Fallback: calculate from remaining time
      timeSpent = 90 - timeRemaining;
    }
    
    _questionResults.add(QuestionResult(
      questionNumber: currentQuestionIndex + 1,
      question: question.question,
      userAnswer: answer ?? '',
      correctAnswer: question.correctAnswer,
      isCorrect: isAnswerCorrect,
      explanation: {
        'approach': question.explanation.approach,
        'steps': question.explanation.steps,
        'finalAnswer': question.explanation.finalAnswer,
      },
      timeSpentSeconds: timeSpent,
    ));
    
    setState(() {
      showFeedback = true;
      isCorrect = isAnswerCorrect;
      if (isAnswerCorrect) {
        correctCount++;
      }
    });
  }

  void _nextQuestion() {
    if (currentQuestionIndex < 2) {
      final nextIndex = currentQuestionIndex + 1;
      
      if (_questions[nextIndex] == null && !_questionLoading[nextIndex]) {
        _loadQuestion(nextIndex);
      }
      
      setState(() {
        currentQuestionIndex = nextIndex;
        selectedAnswer = null;
        showFeedback = false;
        timeRemaining = 90;
        _questionStartTime = null; // Reset for next question
      });
      _startTimer();
    } else {
      _showCompletionSummary();
    }
  }

  void _showCompletionSummary() async {
    final sessionDuration = DateTime.now().difference(_sessionStartTime!);
    
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    await appState.updateStats(_questionResults.length, correctCount);
    
    final sessionResult = PracticeSessionResult(
      score: correctCount,
      total: _questionResults.length,
      timeSpentSeconds: sessionDuration.inSeconds,
      questionResults: _questionResults,
      sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now().toIso8601String(),
    );
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PracticeResultsScreen(
            sessionResult: sessionResult,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[currentQuestionIndex];
    final isLoading = _questionLoading[currentQuestionIndex];
    final error = _questionErrors[currentQuestionIndex];

    // Check error first - if loading failed, show error state
    if (error != null && !isLoading) {
      return _buildErrorState(error);
    }

    // Show loading if still loading or no question loaded yet
    if (isLoading || question == null) {
      return _buildLoadingState();
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            _buildHeader(question),
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.space24),
                    _buildProgressCard(),
                    const SizedBox(height: AppSpacing.space20),
                    _buildDifficultyChip(),
                    const SizedBox(height: AppSpacing.space20),
                    _buildQuestionCard(question),
                    const SizedBox(height: AppSpacing.space20),
                    _buildOptions(question),
                    const SizedBox(height: AppSpacing.space24),
                    _buildSubmitButton(),
                    const SizedBox(height: AppSpacing.space12),
                    _buildSkipButton(),
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

  Widget _buildHeader(FollowUpQuestion question) {
    final difficultyLevels = ['Basic', 'Intermediate', 'Advanced'];
    final level = difficultyLevels[currentQuestionIndex];

    return AppHeaderWithProgress(
      currentIndex: currentQuestionIndex,
      total: 3,
      title: 'Question ${currentQuestionIndex + 1} of 3',
      subtitle: '$level Level',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.radiusRound),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${timeRemaining}s',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                // Progress segments
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: currentQuestionIndex >= 0 ? AppColors.ctaGradient : null,
                      color: currentQuestionIndex >= 0 ? null : AppColors.borderLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.borderGray,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: currentQuestionIndex >= 1 ? AppColors.primaryPurple : AppColors.borderLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.borderGray,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: currentQuestionIndex >= 2 ? AppColors.primaryPurple : AppColors.borderLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyChip() {
    final levels = ['Basic', 'Intermediate', 'Advanced'];
    final level = levels[currentQuestionIndex];
    final colors = [AppColors.successGreen, AppColors.warningAmber, AppColors.errorRed];
    final color = colors[currentQuestionIndex];
    final messages = [
      'Warming up with basics',
      'Getting more challenging',
      'Testing your mastery',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.radiusRound),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            level,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '•',
            style: TextStyle(color: color),
          ),
          const SizedBox(width: 8),
          Text(
            messages[currentQuestionIndex],
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(FollowUpQuestion question) {
    return Container(
      padding: const EdgeInsets.all(24), // Increased from 20 for better readability
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              gradient: AppColors.ctaGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'Q${currentQuestionIndex + 1}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildContentWidget(
              TextPreprocessor.addSpacesToText(question.question),
              widget.subject,
              ContentConfig.getQuestionTextStyle(color: AppColors.textDark).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions(FollowUpQuestion question) {
    return Column(
      children: question.options.entries.map((entry) {
        final optionKey = entry.key;
        final optionValue = entry.value;
        final isSelected = selectedAnswer == optionKey;
        final isCorrectOption = optionKey == question.correctAnswer;
        final isWrongAnswer = showFeedback && isSelected && !isCorrect;

        Color backgroundColor = Colors.white;
        Color borderColor = AppColors.borderGray;
        Color circleColor = AppColors.borderGray.withValues(alpha: 0.2);

        if (showFeedback) {
          if (isCorrectOption) {
            backgroundColor = AppColors.successGreen.withValues(alpha: 0.1);
            borderColor = AppColors.successGreen;
            circleColor = AppColors.successGreen;
          } else if (isWrongAnswer) {
            backgroundColor = AppColors.errorRed.withValues(alpha: 0.1);
            borderColor = AppColors.errorRed;
            circleColor = AppColors.errorRed;
          }
        } else if (isSelected) {
          backgroundColor = AppColors.primaryPurple.withValues(alpha: 0.1);
          borderColor = AppColors.primaryPurple;
          circleColor = AppColors.primaryPurple;
        }

        final showIcon = showFeedback && (isCorrectOption || isWrongAnswer);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: showFeedback ? null : () => _selectAnswer(optionKey),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: (showFeedback && (isCorrectOption || isWrongAnswer)) || isSelected ? 2 : 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: circleColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: showIcon || isSelected ? borderColor : AppColors.borderGray,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: showIcon
                          ? Icon(
                              isCorrectOption ? Icons.check : Icons.close,
                              color: Colors.white,
                              size: 18,
                            )
                          : Text(
                              optionKey,
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
                    child: _buildContentWidget(
                      TextPreprocessor.addSpacesToText(optionValue),
                      widget.subject,
                      ContentConfig.getOptionTextStyle(color: AppColors.textDark).copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton() {
    final hasSelected = selectedAnswer != null;
    final buttonText = showFeedback 
        ? (currentQuestionIndex < 2 ? 'Next Question' : 'View Results')
        : 'Submit Answer';

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: hasSelected || showFeedback ? AppColors.ctaGradient : null,
        color: hasSelected || showFeedback ? null : AppColors.borderLight,
        borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
        boxShadow: hasSelected || showFeedback ? AppShadows.buttonShadow : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: showFeedback
              ? _nextQuestion
              : hasSelected
                  ? () => _submitAnswer(selectedAnswer!)
                  : null,
          borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
          child: Center(
            child: Text(
              buttonText,
              style: AppTextStyles.labelMedium.copyWith(
                color: hasSelected || showFeedback ? Colors.white : AppColors.textGray,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    if (showFeedback) return const SizedBox.shrink();

    return TextButton(
      onPressed: () => _submitAnswer(null),
      child: Text(
        'Skip this question',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textLight,
        ),
      ),
    );
  }


  /// Build content widget based on subject (ChemistryText for Chemistry, LaTeXWidget for others)
  Widget _buildContentWidget(String content, String subject, TextStyle textStyle) {
    if (subject.toLowerCase() == 'chemistry') {
      return ChemistryText(
        content,
        textStyle: textStyle,
        fontSize: textStyle.fontSize ?? 16,
      );
    } else {
      return LaTeXWidget(
        text: content,
        textStyle: textStyle,
      );
    }
  }

  Widget _buildLoadingState() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 24),
              Text(
                'Loading question...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    // Detect if error is network-related
    final errorMsg = error.toLowerCase();
    final isOffline = errorMsg.contains('socketexception') ||
        errorMsg.contains('connection') ||
        errorMsg.contains('network') ||
        errorMsg.contains('timeout') ||
        errorMsg.contains('host') ||
        errorMsg.contains('internet');

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOffline ? Icons.wifi_off_rounded : Icons.error_outline,
                  size: 40,
                  color: AppColors.errorRed,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isOffline ? 'You\'re Offline' : 'Something Went Wrong',
                style: AppTextStyles.headerMedium.copyWith(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isOffline
                    ? 'Please check your internet connection and try again.'
                    : 'We couldn\'t load the question. Please try again.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Go Back button (primary)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Try Again button (secondary)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _loadQuestion(currentQuestionIndex),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryPurple,
                    side: const BorderSide(color: AppColors.primaryPurple),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
