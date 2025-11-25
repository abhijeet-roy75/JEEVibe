import 'dart:async';
import 'package:flutter/material.dart';
import '../models/solution_model.dart';
import '../widgets/latex_widget.dart';
import '../services/api_service.dart';
import '../theme/jeevibe_theme.dart';

class FollowUpQuizScreen extends StatefulWidget {
  final String recognizedQuestion;
  final SolutionDetails solution;
  final String topic;
  final String difficulty;

  const FollowUpQuizScreen({
    super.key,
    required this.recognizedQuestion,
    required this.solution,
    required this.topic,
    required this.difficulty,
  });

  @override
  State<FollowUpQuizScreen> createState() => _FollowUpQuizScreenState();
}

class _FollowUpQuizScreenState extends State<FollowUpQuizScreen> {
  List<FollowUpQuestion?> _questions = [null, null, null]; // Lazy loaded questions
  List<bool> _questionLoading = [false, false, false];
  List<String?> _questionErrors = [null, null, null];
  int currentQuestionIndex = 0;
  String? selectedAnswer;
  bool showFeedback = false;
  bool isCorrect = false;
  int correctCount = 0;
  Timer? _timer;
  int timeRemaining = 90; // 90 seconds per question

  @override
  void initState() {
    super.initState();
    _loadQuestion(0); // Load first question immediately
  }

  Future<void> _loadQuestion(int index) async {
    if (index < 0 || index >= 3) return;
    if (_questions[index] != null || _questionLoading[index]) return; // Already loaded or loading

    setState(() {
      _questionLoading[index] = true;
      _questionErrors[index] = null;
    });

    try {
      final question = await ApiService.generateSingleQuestion(
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
        
        // Start timer only for the first question
        if (index == 0 && _timer == null) {
          _startTimer();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _questionErrors[index] = e.toString();
          _questionLoading[index] = false;
        });
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeRemaining > 0) {
        setState(() {
          timeRemaining--;
        });
      } else {
        _submitAnswer(null); // Auto-submit when time expires
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
      
      // Preload next question if not already loaded
      if (_questions[nextIndex] == null && !_questionLoading[nextIndex]) {
        _loadQuestion(nextIndex);
      }
      
      setState(() {
        currentQuestionIndex = nextIndex;
        selectedAnswer = null;
        showFeedback = false;
        timeRemaining = 90;
      });
      _startTimer();
    } else {
      _showCompletionSummary();
    }
  }

  void _showCompletionSummary() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: JVColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Practice Complete!', style: JVStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: JVColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$correctCount/3',
                style: JVStyles.h1.copyWith(color: JVColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "You're getting better at ${widget.topic}! 🎉",
              style: JVStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Return to solution screen
            },
            child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get current question
    final question = _questions[currentQuestionIndex];
    final isLoading = _questionLoading[currentQuestionIndex];
    final error = _questionErrors[currentQuestionIndex];
    final isLastQuestion = currentQuestionIndex == 2;

    return Scaffold(
      backgroundColor: JVColors.background,
      appBar: AppBar(
        title: Text('Question ${currentQuestionIndex + 1}/3'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: JVColors.headerGradient,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: isLoading || question == null
          ? _buildLoadingState()
          : error != null
              ? _buildErrorState(error)
              : _buildQuestionContent(question, isLastQuestion),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: JVColors.primary),
          const SizedBox(height: 24),
          Text(
            'Generating question...',
            style: JVStyles.bodyLarge.copyWith(color: JVColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: JVColors.error),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: JVStyles.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _loadQuestion(currentQuestionIndex),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionContent(FollowUpQuestion question, bool isLastQuestion) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress and Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${currentQuestionIndex + 1} of 3',
                style: JVStyles.bodySmall.copyWith(fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: timeRemaining < 15 ? JVColors.error : JVColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${timeRemaining}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Question Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: JVStyles.cardDecoration,
            child: _buildQuestionText(question.question),
          ),

          const SizedBox(height: 24),

          // Options
          ...question.options.entries.map((entry) {
            final optionKey = entry.key;
            final optionValue = entry.value;
            final isSelected = selectedAnswer == optionKey;
            final isCorrectOption = optionKey == question.correctAnswer;
            
            Color? backgroundColor = JVColors.surface;
            Color borderColor = Colors.transparent;
            
            if (showFeedback) {
              if (isCorrectOption) {
                backgroundColor = JVColors.success.withOpacity(0.1);
                borderColor = JVColors.success;
              } else if (isSelected && !isCorrect) {
                backgroundColor = JVColors.error.withOpacity(0.1);
                borderColor = JVColors.error;
              }
            } else if (isSelected) {
              backgroundColor = JVColors.primary.withOpacity(0.1);
              borderColor = JVColors.primary;
            }

            return GestureDetector(
              onTap: () => _selectAnswer(optionKey),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  border: Border.all(
                    color: borderColor != Colors.transparent 
                        ? borderColor 
                        : Colors.grey.shade200,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: borderColor == Colors.transparent 
                      ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: borderColor != Colors.transparent 
                            ? borderColor 
                            : Colors.grey.shade200,
                      ),
                      child: Center(
                        child: Text(
                          optionKey,
                          style: TextStyle(
                            color: borderColor != Colors.transparent 
                                ? Colors.white 
                                : JVColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: LaTeXWidget(
                        text: optionValue,
                        textStyle: JVStyles.bodyLarge,
                      ),
                    ),
                    if (showFeedback && isCorrectOption)
                      const Icon(Icons.check_circle, color: JVColors.success),
                    if (showFeedback && isSelected && !isCorrect)
                      const Icon(Icons.cancel, color: JVColors.error),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // Feedback Section
          if (showFeedback) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isCorrect
                    ? JVColors.success.withOpacity(0.1)
                    : JVColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect ? JVColors.success : JVColors.error,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? JVColors.success : JVColors.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isCorrect ? 'Correct! Well done.' : 'Not quite. Correct answer: ${question.correctAnswer}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isCorrect ? JVColors.success : JVColors.error,
                        ),
                      ),
                    ],
                  ),
                  if (question.explanation.approach.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      question.explanation.approach,
                      style: JVStyles.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Submit/Next Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: showFeedback
                  ? _nextQuestion
                  : selectedAnswer != null
                      ? () => _submitAnswer(selectedAnswer!)
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: showFeedback 
                    ? JVColors.primary 
                    : JVColors.success,
                foregroundColor: Colors.white, // White text on colored background
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: Text(
                showFeedback
                    ? (isLastQuestion ? 'View Summary' : 'Next Question')
                    : 'Submit Answer',
              ),
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildQuestionText(String questionText) {
    // Handle [image] placeholders
    final imagePattern = RegExp(r'\[(image|Image|diagram|Diagram|figure|Figure)\]', caseSensitive: false);
    if (imagePattern.hasMatch(questionText)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LaTeXWidget(
            text: questionText.replaceAll(imagePattern, ''),
            textStyle: JVStyles.bodyLarge,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JVColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: JVColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.image, color: JVColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Refer to the original question image.',
                    style: JVStyles.bodySmall.copyWith(color: JVColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    
    return LaTeXWidget(
      text: questionText,
      textStyle: JVStyles.bodyLarge,
    );
  }
}

