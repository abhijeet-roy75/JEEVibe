/// Mock Test Review Screen
/// Shows all questions with filters (All, Correct, Wrong, Unattempted)
/// Allows reviewing questions with detailed solutions

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/review_question_data.dart';
import '../../models/ai_tutor_models.dart';
import '../../services/api_service.dart';
import '../../services/firebase/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons/icon_button.dart';
import '../../widgets/priya_avatar.dart';
import '../../widgets/question_review/question_review_screen.dart';
import '../../widgets/subject_icon_widget.dart';

class MockTestReviewScreen extends StatefulWidget {
  final String testId;
  final String filterType; // 'all', 'correct', 'wrong', 'unattempted'

  const MockTestReviewScreen({
    super.key,
    required this.testId,
    this.filterType = 'all',
  });

  @override
  State<MockTestReviewScreen> createState() => _MockTestReviewScreenState();
}

class _MockTestReviewScreenState extends State<MockTestReviewScreen> {
  Map<String, dynamic>? _testResult;
  String _currentFilter = 'all'; // Default to showing all questions
  String _currentSubject = 'physics'; // Subject filter - default to first subject
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.filterType;
    _loadTestResult();
  }

  Future<void> _loadTestResult() async {
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

      final result = await ApiService.getMockTestResults(
        authToken: token,
        testId: widget.testId,
      );

      if (mounted) {
        setState(() {
          _testResult = result;
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

  List<dynamic> get _allQuestions => _testResult?['questions'] ?? [];

  List<dynamic> get _filteredQuestions {
    // Filter by subject (always apply since we removed "All")
    var questions = _allQuestions
        .where((q) => (q['subject'] as String?)?.toLowerCase() == _currentSubject.toLowerCase())
        .toList();

    // Filter by result
    switch (_currentFilter) {
      case 'correct':
        return questions.where((q) => q['is_correct'] == true).toList();
      case 'wrong':
        return questions
            .where((q) => q['is_correct'] == false && q['user_answer'] != null && q['user_answer'] != '')
            .toList();
      case 'unattempted':
        return questions
            .where((q) => q['user_answer'] == null || q['user_answer'] == '')
            .toList();
      default:
        return questions;
    }
  }

  // Get questions for current subject filter
  List<dynamic> get _subjectFilteredQuestions => _allQuestions
      .where((q) => (q['subject'] as String?)?.toLowerCase() == _currentSubject.toLowerCase())
      .toList();

  int get _totalQuestions => _subjectFilteredQuestions.length;
  int get _correctCount => _subjectFilteredQuestions.where((q) => q['is_correct'] == true).length;
  int get _wrongCount => _subjectFilteredQuestions
      .where((q) => q['is_correct'] == false && q['user_answer'] != null && q['user_answer'] != '')
      .length;
  int get _unattemptedCount =>
      _subjectFilteredQuestions.where((q) => q['user_answer'] == null || q['user_answer'] == '').length;

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '${minutes}:${secs.toString().padLeft(2, '0')}';
    }
    return '${secs}s';
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

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Color _getSubjectColor(String? subject) {
    switch (subject?.toLowerCase()) {
      case 'physics':
        return AppColors.subjectPhysics;
      case 'chemistry':
        return AppColors.subjectChemistry;
      case 'mathematics':
      case 'math':
        return AppColors.subjectMathematics;
      default:
        return AppColors.textMedium;
    }
  }

  /// Convert all questions to ReviewQuestionData for the common widget
  List<ReviewQuestionData> get _reviewQuestionData {
    return _allQuestions
        .map((q) => ReviewQuestionData.fromMockTestQuestion(q as Map<String, dynamic>))
        .toList();
  }

  /// Get filtered ReviewQuestionData
  List<ReviewQuestionData> get _filteredReviewQuestionData {
    return _filteredQuestions
        .map((q) => ReviewQuestionData.fromMockTestQuestion(q as Map<String, dynamic>))
        .toList();
  }

  /// Navigate to the common question review screen
  void _navigateToQuestionReview(int indexInFiltered) {
    // Find the actual index in allQuestions for the filtered item
    final filteredQuestion = _filteredQuestions[indexInFiltered];
    final actualIndex = _allQuestions.indexOf(filteredQuestion);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionReviewScreen(
          questions: _reviewQuestionData,
          initialIndex: actualIndex >= 0 ? actualIndex : indexInFiltered,
          filterType: _currentFilter,
          tutorContext: ReviewTutorContext(
            type: TutorContextType.mockTest,
            id: widget.testId,
            title: 'Simulation Review',
          ),
        ),
      ),
    );
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

    if (_error != null || _testResult == null) {
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
                Text(_error ?? 'Failed to load test', style: AppTextStyles.bodyMedium),
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

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Subject filter chips
                  _buildSubjectFilter(),
                  const SizedBox(height: 12),
                  // Result filter buttons
                  _buildFilterButtons(),
                  const SizedBox(height: 16),
                  // Question list
                  _buildQuestionList(),
                  const SizedBox(height: 16),
                  // Priya Ma'am message
                  _buildPriyaMaamMessage(),
                  const SizedBox(height: 16),
                  // Start Reviewing button
                  _buildStartReviewingButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
          padding: const EdgeInsets.all(24.0),
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
                      'Review Questions',
                      style: AppTextStyles.headerWhite.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_testResult?['template_name'] ?? 'JEE Main Simulation'}',
                      style: AppTextStyles.bodyWhite.copyWith(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildSubjectChip('Physics', 'physics', AppColors.subjectPhysics),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSubjectChip('Chemistry', 'chemistry', AppColors.subjectChemistry),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSubjectChip('Math', 'mathematics', AppColors.subjectMathematics),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectChip(String label, String value, Color? color) {
    final isSelected = _currentSubject == value;
    return GestureDetector(
      onTap: () => setState(() => _currentSubject = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? AppColors.primaryPurple)
              : (color ?? AppColors.primaryPurple).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color ?? AppColors.primaryPurple,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (value != 'all') ...[
              SubjectIconWidget(subject: label, size: 14),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: isSelected ? Colors.white : (color ?? AppColors.primaryPurple),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: AppColors.textMedium, size: 20),
              const SizedBox(width: 8),
              Text(
                'FILTER BY RESULT',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMedium,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFilterButton(
                  label: 'All ($_totalQuestions)',
                  isSelected: _currentFilter == 'all',
                  onTap: () => setState(() => _currentFilter = 'all'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterButton(
                  label: '✓ ($_correctCount)',
                  isSelected: _currentFilter == 'correct',
                  backgroundColor: _currentFilter == 'correct' ? AppColors.successGreen : null,
                  textColor: _currentFilter == 'correct' ? Colors.white : AppColors.textDark,
                  onTap: () => setState(() => _currentFilter = 'correct'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterButton(
                  label: '× ($_wrongCount)',
                  isSelected: _currentFilter == 'wrong',
                  backgroundColor: _currentFilter == 'wrong' ? AppColors.errorRed : null,
                  textColor: _currentFilter == 'wrong' ? Colors.white : AppColors.textDark,
                  onTap: () => setState(() => _currentFilter = 'wrong'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterButton(
                  label: '− ($_unattemptedCount)',
                  isSelected: _currentFilter == 'unattempted',
                  backgroundColor: _currentFilter == 'unattempted' ? AppColors.textMedium : null,
                  textColor: _currentFilter == 'unattempted' ? Colors.white : AppColors.textDark,
                  onTap: () => setState(() => _currentFilter = 'unattempted'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required String label,
    required bool isSelected,
    IconData? icon,
    Color? iconColor,
    Color? backgroundColor,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    final bgColor = backgroundColor ?? (isSelected ? AppColors.primaryPurple : AppColors.borderGray);
    final finalTextColor = textColor ?? (isSelected ? Colors.white : AppColors.textDark);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : iconColor ?? finalTextColor,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: finalTextColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionList() {
    if (_filteredQuestions.isEmpty) {
      String message;
      IconData icon;
      Color iconColor;

      if (_allQuestions.isEmpty) {
        message = 'No questions available';
        icon = Icons.quiz_outlined;
        iconColor = AppColors.textLight;
      } else if (_currentFilter == 'correct') {
        message = 'No correct answers in this section.\nKeep practicing!';
        icon = Icons.emoji_emotions_outlined;
        iconColor = AppColors.textLight;
      } else if (_currentFilter == 'wrong') {
        message = 'No wrong answers here!\nGreat job!';
        icon = Icons.celebration;
        iconColor = AppColors.successGreen;
      } else if (_currentFilter == 'unattempted') {
        message = 'All questions attempted!\nGreat effort!';
        icon = Icons.celebration;
        iconColor = AppColors.successGreen;
      } else {
        message = 'No questions to review';
        icon = Icons.quiz_outlined;
        iconColor = AppColors.textLight;
      }

      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: iconColor),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _filteredQuestions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          return _buildQuestionCard(question, index);
        }).toList(),
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int index) {
    final isCorrect = question['is_correct'] as bool? ?? false;
    final userAnswer = question['user_answer']?.toString() ?? '';
    final isUnattempted = userAnswer.isEmpty;
    final questionNumber = _parseInt(question['question_number']) ?? (index + 1);
    final subject = question['subject'] as String? ?? 'Unknown';
    final chapter = question['chapter'] as String? ?? '';
    final questionText = question['question_text'] as String? ?? '';
    final timeTaken = _parseInt(question['time_spent']) ?? 0;
    final correctAnswer = question['correct_answer']?.toString() ?? '';
    final difficulty = question['difficulty'] as String?;
    final questionType = question['question_type'] as String? ?? 'mcq';

    // Determine card border color
    Color borderColor;
    if (isUnattempted) {
      borderColor = AppColors.textLight.withOpacity(0.3);
    } else if (isCorrect) {
      borderColor = AppColors.successGreen.withOpacity(0.3);
    } else {
      borderColor = AppColors.errorRed.withOpacity(0.3);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: InkWell(
        onTap: () => _navigateToQuestionReview(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Question number circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isUnattempted
                      ? AppColors.textLight
                      : isCorrect
                          ? AppColors.successGreen
                          : AppColors.errorRed,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isUnattempted
                      ? const Icon(Icons.remove, color: Colors.white, size: 20)
                      : isCorrect
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              // Question details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question number and type tag
                    Row(
                      children: [
                        Text(
                          'Q$questionNumber',
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getSubjectColor(subject).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            subject,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: _getSubjectColor(subject),
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (questionType == 'numerical' || questionType == 'integer')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'NUM',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primaryPurple,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Chapter name
                    if (chapter.isNotEmpty)
                      Text(
                        chapter,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textLight,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    // Question text preview
                    Text(
                      questionText.length > 60 ? '${questionText.substring(0, 60)}...' : questionText,
                      style: AppTextStyles.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Bottom row: time and answer info
                    Row(
                      children: [
                        if (timeTaken > 0) ...[
                          const Icon(Icons.access_time, size: 12, color: AppColors.textLight),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(timeTaken),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textLight,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (isUnattempted)
                          Text(
                            'Unattempted',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textLight,
                              fontSize: 11,
                            ),
                          )
                        else if (!isCorrect)
                          Text(
                            'Your: ${userAnswer.toUpperCase()}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.errorRed,
                              fontSize: 11,
                            ),
                          ),
                        if (!isUnattempted) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Ans: ${correctAnswer.toUpperCase()}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.successGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriyaMaamMessage() {
    String message;
    if (_currentFilter == 'wrong') {
      message =
          "Focus on understanding why you got these wrong. Review the step-by-step explanations carefully!";
    } else if (_currentFilter == 'unattempted') {
      message =
          "These are the questions you skipped. Review them to see if you could have attempted them!";
    } else {
      message =
          "Great effort on completing the mock test! Review all questions to learn from both your correct and incorrect answers.";
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
    );
  }

  Widget _buildStartReviewingButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primaryPurple,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (_filteredQuestions.isNotEmpty) {
                _navigateToQuestionReview(0);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.menu_book, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Start Reviewing',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
