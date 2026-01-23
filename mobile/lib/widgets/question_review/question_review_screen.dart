/// Question Review Screen
///
/// Common reusable screen for reviewing questions after practice/quiz completion.
/// Used by both Daily Quiz and Chapter Practice review flows.
import 'package:flutter/material.dart';
import '../../models/review_question_data.dart';
import '../latex_widget.dart';
import '../../models/daily_quiz_question.dart' show SolutionStep;
import '../../models/ai_tutor_models.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons/icon_button.dart';
import '../../widgets/safe_svg_widget.dart';
import '../../widgets/priya_avatar.dart';
import '../../screens/ai_tutor_chat_screen.dart';

/// Configuration for AI Tutor context in the review screen
class ReviewTutorContext {
  final TutorContextType type;
  final String id;
  final String title;

  const ReviewTutorContext({
    required this.type,
    required this.id,
    required this.title,
  });
}

class QuestionReviewScreen extends StatefulWidget {
  /// List of questions to review
  final List<ReviewQuestionData> questions;

  /// Initial question index to show
  final int initialIndex;

  /// Optional filter applied ('all', 'correct', 'wrong')
  final String? filterType;

  /// Subject name for display
  final String? subject;

  /// Chapter name for display
  final String? chapterName;

  /// Context for AI Tutor integration (optional)
  final ReviewTutorContext? tutorContext;

  const QuestionReviewScreen({
    super.key,
    required this.questions,
    required this.initialIndex,
    this.filterType,
    this.subject,
    this.chapterName,
    this.tutorContext,
  });

  @override
  State<QuestionReviewScreen> createState() => _QuestionReviewScreenState();
}

class _QuestionReviewScreenState extends State<QuestionReviewScreen> {
  int _currentIndex = 0;
  bool _showDetailedExplanation = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Clamp initialIndex to valid range (filtered questions will be validated in getter)
    final maxIndex = widget.questions.isEmpty ? 0 : widget.questions.length - 1;
    _currentIndex = widget.initialIndex.clamp(0, maxIndex);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  List<ReviewQuestionData> get _filteredQuestions {
    if (widget.filterType == null || widget.filterType == 'all') {
      return widget.questions;
    }

    switch (widget.filterType) {
      case 'correct':
        return widget.questions.where((q) => q.isCorrect).toList();
      case 'wrong':
        return widget.questions.where((q) => !q.isCorrect).toList();
      default:
        return widget.questions;
    }
  }

  ReviewQuestionData? get _currentQuestion {
    if (_currentIndex >= _filteredQuestions.length || _filteredQuestions.isEmpty) {
      return null;
    }
    return _filteredQuestions[_currentIndex];
  }

  int get _currentQuestionPosition {
    if (_currentQuestion == null) return _currentIndex + 1;
    return _currentQuestion!.position + 1;
  }

  int get _currentQuestionNumberInFiltered {
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
      _scrollToTop();
    }
  }

  void _nextQuestion() {
    if (!_isLastQuestion) {
      setState(() {
        _currentIndex++;
        _showDetailedExplanation = true;
      });
      _scrollToTop();
    }
  }

  void _handleDone() {
    Navigator.of(context).pop();
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
    if (_currentQuestion == null) {
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
                Text('No question to display', style: AppTextStyles.bodyMedium),
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
    final isCorrect = question.isCorrect;
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
              controller: _scrollController,
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
                  _buildPriyaMaamMessage(question, isCorrect),
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
              AppIconButton.back(
                onPressed: () => Navigator.of(context).pop(),
                forGradientHeader: true,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Question $questionNumber/$totalFiltered',
                      style: AppTextStyles.headerWhite.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    // Progress dots (limit to reasonable number)
                    if (totalFiltered <= 15)
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

  Widget _buildStatusBanner(ReviewQuestionData question, bool isCorrect) {
    final studentAnswer = question.studentAnswer;
    final correctAnswer = question.correctAnswer;
    final timeTaken = question.timeTakenSeconds;

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
            if (timeTaken != null)
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

  Widget _buildQuestionCard(ReviewQuestionData question) {
    // Use HTML content directly - LaTeXWidget handles HTML rendering
    final questionText = question.questionText;
    final questionTextHtml = question.questionTextHtml;
    final options = question.options;
    final isCorrect = question.isCorrect;
    final studentAnswer = question.studentAnswer;
    final correctAnswer = question.correctAnswer;
    final subject = question.subject ?? widget.subject;
    final chapter = question.chapter ?? widget.chapterName;
    final difficulty = question.difficulty;
    final imageUrl = question.imageUrl;

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
            // Subject and chapter
            if (subject != null || chapter != null)
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
                  Expanded(
                    child: Text(
                      [subject, chapter].where((s) => s != null).join(' • '),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            // Tags (question number and difficulty)
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
                if (difficulty != null)
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
              LaTeXWidget(
                text: questionTextHtml,
                textStyle: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Text(
                questionText,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            // Image if present
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              SafeSvgWidget(url: imageUrl),
            ],
            const SizedBox(height: 24),
            // Answer options
            ...options.map((opt) => _buildReviewOption(
                  opt,
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
    ReviewOptionData option,
    String studentAnswer,
    String correctAnswer,
    bool isCorrect,
  ) {
    final optionId = option.optionId;
    // Use HTML content directly - LaTeXWidget handles HTML rendering
    final optionText = option.text;
    final optionHtml = option.html;

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
      trailingIcon =
          const Icon(Icons.check_circle, color: AppColors.successGreen);
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
                  ? LaTeXWidget(
                      text: optionHtml,
                      textStyle: AppTextStyles.bodyMedium.copyWith(color: textColor),
                    )
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

  Widget _buildDetailedExplanation(ReviewQuestionData question) {
    final solutionText = question.solutionText;
    final solutionSteps = question.solutionSteps;
    final isCorrect = question.isCorrect;
    final keyInsight = question.keyInsight;
    final distractorAnalysis = question.distractorAnalysis;
    final commonMistakes = question.commonMistakes;
    final studentAnswer = question.studentAnswer;

    if (solutionText == null && solutionSteps.isEmpty) {
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
                        _showDetailedExplanation
                            ? 'Hide Detailed Explanation'
                            : 'Show Detailed Explanation',
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
                    if (solutionText != null) ...[
                      _buildExplanationSection(
                        icon: Icons.lightbulb,
                        iconColor: AppColors.warningAmber,
                        title: 'Quick Explanation',
                        content: solutionText,
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Step-by-Step Solution
                    if (solutionSteps.isNotEmpty) ...[
                      _buildStepByStepSolution(solutionSteps),
                      const SizedBox(height: 16),
                    ],
                    // Why You Got This Wrong (only for incorrect)
                    if (!isCorrect) ...[
                      _buildWhyWrongSection(
                        studentAnswer: studentAnswer,
                        distractorAnalysis: distractorAnalysis,
                        commonMistakes: commonMistakes,
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Key Takeaway
                    if (keyInsight != null || solutionText != null)
                      _buildKeyTakeawaySection(keyInsight ?? solutionText!),
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
              LaTeXWidget(
                text: content,
                textStyle: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textMedium,
                ),
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
                ),
              ),
              const SizedBox(height: 12),
              ...steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final stepText = step.displayText;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LaTeXWidget(
                              text: stepText,
                              textStyle: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: AppColors.textMedium,
                              ),
                            ),
                            // Formula
                            if (step.formula != null && step.formula!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildStepBox(
                                icon: Icons.functions,
                                color: AppColors.primaryPurple,
                                content: step.formula!,
                              ),
                            ],
                            // Calculation
                            if (step.calculation != null && step.calculation!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildStepBox(
                                icon: Icons.calculate,
                                color: AppColors.successGreen,
                                content: step.calculation!,
                                fontFamily: 'monospace',
                              ),
                            ],
                            // Explanation (if different from description)
                            if (step.explanation != null &&
                                step.explanation!.isNotEmpty &&
                                step.explanation != step.description) ...[
                              const SizedBox(height: 8),
                              _buildStepBox(
                                icon: Icons.lightbulb_outline,
                                color: AppColors.warningAmber,
                                content: step.explanation!,
                                fontStyle: FontStyle.italic,
                              ),
                            ],
                          ],
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

  Widget _buildStepBox({
    required IconData icon,
    required Color color,
    required String content,
    String? fontFamily,
    FontStyle? fontStyle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: LaTeXWidget(
              text: content,
              textStyle: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: fontFamily != null ? AppColors.textMedium : color,
                fontFamily: fontFamily,
                fontStyle: fontStyle,
                fontWeight: fontFamily == null ? FontWeight.w500 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyWrongSection({
    required String studentAnswer,
    Map<String, String>? distractorAnalysis,
    List<String>? commonMistakes,
  }) {
    // Get distractor explanation for MCQ
    String? distractorExplanation;
    if (distractorAnalysis != null && studentAnswer.isNotEmpty) {
      distractorExplanation = distractorAnalysis[studentAnswer] ??
          distractorAnalysis[studentAnswer.toLowerCase()] ??
          distractorAnalysis[studentAnswer.toUpperCase()];
    }

    final hasCommonMistakes = commonMistakes != null && commonMistakes.isNotEmpty;

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
              if (distractorExplanation != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Option ${studentAnswer.toUpperCase()}',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LaTeXWidget(
                  text: distractorExplanation,
                  textStyle: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: AppColors.textMedium,
                  ),
                ),
              ] else if (hasCommonMistakes) ...[
                ...commonMistakes.map((mistake) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.warningAmber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: LaTeXWidget(
                              text: mistake,
                              textStyle: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: AppColors.textMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ] else ...[
                Text(
                  'Review the explanation carefully. Understanding why you made this mistake helps you avoid it in the future.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
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
              LaTeXWidget(
                text: content,
                textStyle: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriyaMaamMessage(ReviewQuestionData question, bool isCorrect) {
    String message;
    if (isCorrect) {
      message = _getCorrectReviewMessage();
    } else {
      message = _getIncorrectReviewMessage();
    }

    final subscriptionService = SubscriptionService();
    final hasAiTutorAccess =
        subscriptionService.status?.limits.aiTutorEnabled ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryPurple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            if (hasAiTutorAccess && widget.tutorContext != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AiTutorChatScreen(
                          injectContext: TutorContext(
                            type: widget.tutorContext!.type,
                            id: widget.tutorContext!.id,
                            title: widget.tutorContext!.title,
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Ask Priya Ma\'am'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryPurple,
                    side: const BorderSide(color: AppColors.primaryPurple),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
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
              onPressed: _isLastQuestion ? _handleDone : _nextQuestion,
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
                  Text(_isLastQuestion ? 'Done' : 'Next'),
                  const SizedBox(width: 8),
                  Icon(_isLastQuestion ? Icons.check : Icons.arrow_forward,
                      size: 20),
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

  // Varied messages for correct answers during review
  String _getCorrectReviewMessage() {
    final messages = [
      "Excellent! You understood this concept well. Make sure you can explain it to someone else—that's when you truly master it!",
      "Great work! Your solid understanding here shows your preparation is on track.",
      "Well done! This is exactly the kind of clarity you need for JEE. Keep building on it!",
      "Perfect! Understanding like this gives you confidence. You're doing great!",
      "Wonderful! Questions like this will feel easy in the exam with this foundation.",
    ];
    return messages[_currentIndex % messages.length];
  }

  // Varied messages for incorrect answers during review (encouraging)
  String _getIncorrectReviewMessage() {
    final messages = [
      "Don't worry about getting this wrong! Understanding why you made this mistake is actually more valuable than getting it right the first time. Review the explanation carefully!",
      "This was a tricky one! What matters is you're taking time to review it. That's how toppers improve!",
      "Everyone gets these wrong sometimes. The key is learning from it—you're doing exactly that!",
      "No problem! JEE tests deep understanding. This review will help you nail similar questions next time.",
      "It's okay! Some concepts need more practice. I believe in your ability to master this!",
    ];
    return messages[_currentIndex % messages.length];
  }
}
