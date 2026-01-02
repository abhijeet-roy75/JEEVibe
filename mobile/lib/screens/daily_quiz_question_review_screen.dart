/// Daily Quiz Question Review Screen
/// Shows individual question with full details in review mode
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/daily_quiz_question.dart';
import '../services/api_service.dart';
import '../services/firebase/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/safe_svg_widget.dart';
import '../widgets/priya_avatar.dart';
import 'package:flutter_html/flutter_html.dart';

class DailyQuizQuestionReviewScreen extends StatefulWidget {
  final String quizId;
  final int questionIndex;
  final String? filterType; // 'all', 'correct', 'wrong'

  const DailyQuizQuestionReviewScreen({
    super.key,
    required this.quizId,
    required this.questionIndex,
    this.filterType,
  });

  @override
  State<DailyQuizQuestionReviewScreen> createState() => _DailyQuizQuestionReviewScreenState();
}

class _DailyQuizQuestionReviewScreenState extends State<DailyQuizQuestionReviewScreen> {
  Map<String, dynamic>? _quizResult;
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _error;
  bool _showDetailedExplanation = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.questionIndex;
    _loadQuizResult();
  }

  Future<void> _loadQuizResult() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();
      
      if (token == null) {
        setState(() {
          _error = 'Authentication required';
          _isLoading = false;
        });
        return;
      }

      final result = await ApiService.getDailyQuizResult(
        authToken: token,
        quizId: widget.quizId,
      );

      if (mounted) {
        setState(() {
          _quizResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _allQuestions => _quizResult?['quiz']?['questions'] ?? [];
  
  List<dynamic> get _filteredQuestions {
    if (widget.filterType == null) return _allQuestions;
    
    switch (widget.filterType) {
      case 'correct':
        return _allQuestions.where((q) => q['is_correct'] == true).toList();
      case 'wrong':
        return _allQuestions.where((q) => q['is_correct'] == false).toList();
      default:
        return _allQuestions;
    }
  }

  Map<String, dynamic>? get _currentQuestion {
    if (_currentIndex >= _filteredQuestions.length || _filteredQuestions.isEmpty) return null;
    return _filteredQuestions[_currentIndex] as Map<String, dynamic>?;
  }
  
  int get _currentQuestionPosition {
    if (_currentQuestion == null) return _currentIndex + 1;
    // Return the original position in the full quiz
    return _currentQuestion!['position'] as int? ?? (_currentIndex + 1);
  }
  
  int get _currentQuestionNumberInFiltered {
    // Return the position within the filtered list (1-indexed)
    return _currentIndex + 1;
  }

  bool get _isFirstQuestion => _currentIndex == 0;
  bool get _isLastQuestion => _currentIndex >= _filteredQuestions.length - 1;

  void _previousQuestion() {
    if (!_isFirstQuestion) {
      setState(() {
        _currentIndex--;
        _showDetailedExplanation = true;
      });
    }
  }

  void _nextQuestion() {
    if (!_isLastQuestion) {
      setState(() {
        _currentIndex++;
        _showDetailedExplanation = true;
      });
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '${minutes}:${secs.toString().padLeft(2, '0')}';
    }
    return '${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    if (_error != null || _quizResult == null || _currentQuestion == null) {
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
                Text(_error ?? 'Failed to load question', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _currentQuestion!;
    final isCorrect = question['is_correct'] as bool? ?? false;
    final questionNumberInFiltered = _currentQuestionNumberInFiltered;
    final totalFiltered = _filteredQuestions.length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // Header
          _buildHeader(questionNumberInFiltered, totalFiltered),
          // Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Status banner
                  _buildStatusBanner(question, isCorrect),
                  const SizedBox(height: 16),
                  // Question card
                  _buildQuestionCard(question),
                  const SizedBox(height: 16),
                  // Detailed explanation
                  _buildDetailedExplanation(question),
                  const SizedBox(height: 16),
                  // Priya Ma'am message
                  _buildPriyaMaamMessage(isCorrect),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader(int questionNumber, int totalFiltered) {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Question $questionNumber/$totalFiltered',
                      style: AppTextStyles.headerWhite.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(totalFiltered, (index) {
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: index == _currentIndex 
                                ? Colors.white 
                                : Colors.white.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48), // Balance back button
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(Map<String, dynamic> question, bool isCorrect) {
    final timeTaken = question['time_taken_seconds'] as int? ?? 0;
    final studentAnswer = question['student_answer'] as String? ?? '';
    final correctAnswer = question['correct_answer'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCorrect ? Icons.check : Icons.close,
                color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCorrect ? 'Correct Answer!' : 'Incorrect Answer',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCorrect 
                        ? 'Well done! You got this right.'
                        : 'Your answer: ${studentAnswer.toUpperCase()} • Correct: ${correctAnswer.toUpperCase()}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
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
                  _formatTime(timeTaken),
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
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question) {
    final subject = question['subject'] as String? ?? 'Unknown';
    final chapter = question['chapter'] as String? ?? 'Unknown';
    final questionText = question['question_text'] as String? ?? '';
    final questionTextHtml = question['question_text_html'] as String?;
    final imageUrl = question['image_url'] as String?;
    final options = question['options'] as List<dynamic>?;
    final isCorrect = question['is_correct'] as bool? ?? false;
    final studentAnswer = question['student_answer'] as String? ?? '';
    final correctAnswer = question['correct_answer'] as String? ?? '';
    final difficulty = question['difficulty'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject and difficulty
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getSubjectColor(subject),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$subject • $chapter',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Question number and difficulty tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Question ${_currentQuestionPosition}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warningAmber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getDifficultyLabel(difficulty),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.warningAmber,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Question text
            if (questionTextHtml != null)
              Html(data: questionTextHtml, style: {
                'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
              })
            else
              Text(
                questionText,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              SafeSvgWidget(url: imageUrl),
            ],
            const SizedBox(height: 24),
            // Answer options
            if (options != null)
              ...options.map((opt) => _buildReviewOption(
                opt as Map<String, dynamic>,
                studentAnswer,
                correctAnswer,
                isCorrect,
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewOption(
    Map<String, dynamic> option,
    String studentAnswer,
    String correctAnswer,
    bool isCorrect,
  ) {
    final optionId = option['option_id'] as String? ?? '';
    final optionText = option['text'] as String? ?? '';
    final optionHtml = option['html'] as String?;
    
    final isSelected = studentAnswer == optionId;
    final isCorrectAnswer = correctAnswer == optionId;
    
    Color backgroundColor = Colors.white;
    Color borderColor = AppColors.borderGray;
    Color textColor = AppColors.textDark;
    Widget? trailingIcon;

    if (isCorrectAnswer) {
      backgroundColor = AppColors.successGreen.withValues(alpha: 0.1);
      borderColor = AppColors.successGreen;
      textColor = AppColors.successGreen;
      trailingIcon = const Icon(Icons.check_circle, color: AppColors.successGreen);
    } else if (isSelected && !isCorrect) {
      backgroundColor = AppColors.errorRed.withValues(alpha: 0.1);
      borderColor = AppColors.errorRed;
      textColor = AppColors.errorRed;
      trailingIcon = const Icon(Icons.cancel, color: AppColors.errorRed);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                color: borderColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  optionId,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: borderColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: optionHtml != null
                  ? Html(data: optionHtml, style: {
                      'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
                    })
                  : Text(
                      optionText,
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
    );
  }

  Widget _buildDetailedExplanation(Map<String, dynamic> question) {
    final solutionText = question['solution_text'] as String?;
    final solutionSteps = question['solution_steps'] as List<dynamic>?;
    final explanation = question['explanation'] as String?;
    final isCorrect = question['is_correct'] as bool? ?? false;

    if (solutionText == null && (solutionSteps == null || solutionSteps!.isEmpty) && explanation == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
                        _showDetailedExplanation ? 'Hide Detailed Explanation' : 'Show Detailed Explanation',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ),
                    Icon(
                      _showDetailedExplanation ? Icons.remove : Icons.add,
                      color: AppColors.primaryPurple,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            // Content
            if (_showDetailedExplanation) ...[
              Divider(height: 1, color: AppColors.borderGray),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Explanation
                    if (explanation != null || solutionText != null) ...[
                      _buildExplanationSection(
                        icon: Icons.lightbulb,
                        iconColor: AppColors.warningAmber,
                        title: 'Quick Explanation',
                        content: explanation ?? solutionText ?? '',
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Step-by-Step Solution
                    if (solutionSteps != null && solutionSteps.isNotEmpty) ...[
                      _buildStepByStepSolution(solutionSteps),
                      const SizedBox(height: 16),
                    ],
                    // Why You Got This Wrong (only for incorrect)
                    if (!isCorrect) ...[
                      _buildWhyWrongSection(),
                      const SizedBox(height: 16),
                    ],
                    // Key Takeaway
                    _buildKeyTakeawaySection(solutionText ?? explanation ?? ''),
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
                  ),
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepByStepSolution(List<dynamic> steps) {
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
                ),
              ),
              const SizedBox(height: 12),
              ...steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                String stepText = '';
                
                if (step is Map<String, dynamic>) {
                  stepText = step['description'] ?? step['explanation'] ?? step['step'] ?? '';
                } else if (step is String) {
                  stepText = step;
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
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

  Widget _buildWhyWrongSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.warningAmber.withValues(alpha: 0.2),
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
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Review the explanation carefully. Understanding why you made this mistake helps you avoid it in the future.',
                style: AppTextStyles.bodySmall,
              ),
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
                data: content,
                style: {
                  'body': Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                    fontSize: FontSize(14),
                  ),
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriyaMaamMessage(bool isCorrect) {
    String message;
    if (isCorrect) {
      message = "Excellent! You understood this concept well. Make sure you can explain it to someone else—that's when you truly master it! 🎯";
    } else {
      message = "Don't worry about getting this wrong! Understanding why you made this mistake is actually more valuable than getting it right the first time. Review the explanation carefully and try a similar problem tomorrow! 💪";
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

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isFirstQuestion ? null : _previousQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.borderGray,
                foregroundColor: AppColors.textDark,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_back, size: 20),
                  const SizedBox(width: 8),
                  const Text('Previous'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLastQuestion ? null : _nextQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Next'),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
        return AppColors.textMedium;
    }
  }

  String _getDifficultyLabel(String? difficulty) {
    if (difficulty == null) return 'Moderate';
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 'Easy';
      case 'medium':
      case 'moderate':
        return 'Moderate';
      case 'hard':
      case 'challenging':
        return 'Challenging';
      default:
        return 'Moderate';
    }
  }
}

