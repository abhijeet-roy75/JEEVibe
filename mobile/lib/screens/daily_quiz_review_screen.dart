/// Daily Quiz Review Screen
/// Shows all questions with filters (All, Correct, Wrong)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/review_question_data.dart';
import '../models/ai_tutor_models.dart';
import '../services/api_service.dart';
import '../services/firebase/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/buttons/icon_button.dart';
import '../widgets/priya_avatar.dart';
import '../widgets/question_review/question_review_screen.dart';
import '../widgets/responsive_layout.dart';

class DailyQuizReviewScreen extends StatefulWidget {
  final String quizId;
  final String filterType; // 'all', 'correct', 'wrong'

  const DailyQuizReviewScreen({
    super.key,
    required this.quizId,
    this.filterType = 'all',
  });

  @override
  State<DailyQuizReviewScreen> createState() => _DailyQuizReviewScreenState();
}

class _DailyQuizReviewScreenState extends State<DailyQuizReviewScreen> {
  Map<String, dynamic>? _quizResult;
  String _currentFilter = 'all';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.filterType;
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
    switch (_currentFilter) {
      case 'correct':
        return _allQuestions.where((q) => q['is_correct'] == true).toList();
      case 'wrong':
        return _allQuestions.where((q) => q['is_correct'] == false).toList();
      default:
        return _allQuestions;
    }
  }

  int get _totalQuestions => _allQuestions.length;
  int get _correctCount => _allQuestions.where((q) => q['is_correct'] == true).length;
  int get _wrongCount => _allQuestions.where((q) => q['is_correct'] == false).length;
  
  int get _avgTimeSeconds {
    if (_allQuestions.isEmpty) return 0;
    final totalTime = _allQuestions
        .map((q) => q['time_taken_seconds'] as int? ?? 0)
        .fold(0, (sum, time) => sum + time);
    return (totalTime / _allQuestions.length).round();
  }

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

  /// Convert all questions to ReviewQuestionData for the common widget
  List<ReviewQuestionData> get _reviewQuestionData {
    return _allQuestions
        .map((q) => ReviewQuestionData.fromDailyQuizMap(q as Map<String, dynamic>))
        .toList();
  }

  /// Navigate to the common question review screen
  void _navigateToQuestionReview(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionReviewScreen(
          questions: _reviewQuestionData,
          initialIndex: index,
          filterType: _currentFilter,
          tutorContext: ReviewTutorContext(
            type: TutorContextType.quiz,
            id: widget.quizId,
            title: 'Daily Quiz Review',
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

    if (_error != null || _quizResult == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isDesktopViewport(context) ? 480 : double.infinity,
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.errorRed),
                const SizedBox(height: 16),
                Text('Error', style: AppTextStyles.headerMedium),
                const SizedBox(height: 8),
                Text(_error ?? 'Failed to load quiz', style: AppTextStyles.bodyMedium),
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
          // Purple header - Full width
          _buildHeader(),
          // Scrollable content - Constrained on desktop
          Expanded(
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isDesktopViewport(context) ? 900 : double.infinity,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewPadding.bottom,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        // Filter buttons (also show counts)
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
              // Back button on left
              AppIconButton.back(
                onPressed: () => Navigator.of(context).pop(),
                forGradientHeader: true,
              ),
              // Message centered
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Review All Questions',
                      style: AppTextStyles.headerWhite.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap any question to review',
                      style: AppTextStyles.bodyWhite.copyWith(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Empty space on right to balance (same width as back button)
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // IntrinsicHeight ensures Row children can use CrossAxisAlignment.stretch properly
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildSummaryCard('Total', '$_totalQuestions', AppColors.primaryPurple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard('Correct', '$_correctCount', AppColors.successGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard('Wrong', '$_wrongCount', AppColors.errorRed),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard('Avg Time', _formatTime(_avgTimeSeconds), AppColors.primaryPurple),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTextStyles.headerWhite.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodyWhite.copyWith(fontSize: 12),  // 12px iOS, 10.56px Android (was 11)
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButtons() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: AppColors.textMedium, size: 20),
              const SizedBox(width: 8),
              Text(
                'FILTER QUESTIONS',
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
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterButton(
                  label: '✓ ($_correctCount)',
                  isSelected: _currentFilter == 'correct',
                  icon: Icons.check,
                  iconColor: AppColors.successGreen,
                  onTap: () => setState(() => _currentFilter = 'correct'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterButton(
                  label: '× ($_wrongCount)',
                  isSelected: _currentFilter == 'wrong',
                  icon: Icons.close,
                  iconColor: AppColors.errorRed,
                  backgroundColor: _currentFilter == 'wrong' ? AppColors.errorRed : null,
                  textColor: _currentFilter == 'wrong' ? Colors.white : AppColors.textDark,
                  onTap: () => setState(() => _currentFilter = 'wrong'),
                ),
              ),
            ],
          ),
        ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: backgroundColor ?? (isSelected ? AppColors.primaryPurple : AppColors.borderGray),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: textColor ?? (isSelected ? Colors.white : iconColor ?? AppColors.textDark),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: textColor ?? (isSelected ? Colors.white : AppColors.textDark),
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
      // Context-aware empty state messages
      String message;
      IconData icon;
      Color iconColor;

      if (_allQuestions.isEmpty) {
        // No questions at all - shouldn't normally happen
        message = 'No questions available';
        icon = Icons.quiz_outlined;
        iconColor = AppColors.textLight;
      } else if (_currentFilter == 'correct') {
        // Filtered to correct but none found
        message = 'No correct answers yet.\nKeep practicing!';
        icon = Icons.emoji_emotions_outlined;
        iconColor = AppColors.textLight;
      } else if (_currentFilter == 'wrong') {
        // Filtered to wrong but none found - positive message!
        message = 'No wrong answers!\nGreat job! 🎉';
        icon = Icons.celebration;
        iconColor = AppColors.successGreen;
      } else {
        // All filter but nothing shown
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
    // Get the actual position from backend (0-indexed)
    final actualPosition = question['position'] as int?;

    // Log if position is missing (helps debug data inconsistencies)
    if (actualPosition == null) {
      print('[DailyQuizReview] WARNING: Question missing position field, using fallback index $index. QuestionId: ${question['question_id']}');
    }

    // Backend position is 0-indexed, add 1 for display (1-10 instead of 0-9)
    final questionNumber = (actualPosition ?? index) + 1;
    final subject = question['subject'] as String? ?? 'Unknown';
    final chapter = question['chapter'] as String? ?? 'Unknown';
    final questionText = question['question_text'] as String? ?? '';
    final timeTaken = question['time_taken_seconds'] as int? ?? 0;
    final studentAnswer = question['student_answer'] as String? ?? '';
    final correctAnswer = question['correct_answer'] as String? ?? '';
    final difficulty = question['difficulty'] as String?;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? AppColors.successGreen.withValues(alpha: 0.3) : AppColors.errorRed.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToQuestionReview(index),
        child: Row(
          children: [
            // Question number circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCorrect ? AppColors.successGreen : AppColors.errorRed,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$questionNumber',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Question details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject and difficulty tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getSubjectColor(subject).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          subject,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _getSubjectColor(subject),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warningAmber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getDifficultyLabel(difficulty),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.warningAmber,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Topic
                  Text(
                    chapter,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Question text (truncated)
                  Text(
                    questionText.length > 60 ? '${questionText.substring(0, 60)}...' : questionText,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Time and answers
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(timeTaken),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          children: [
                            if (!isCorrect) ...[
                              Flexible(
                                child: Text(
                                  'Your answer: ${studentAnswer.toUpperCase()}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.errorRed,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                'Correct: ${correctAnswer.toUpperCase()}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.successGreen,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  Widget _buildPriyaMaamMessage() {
    String message;
    if (_currentFilter == 'wrong') {
      message = "Focus on understanding why you got these wrong. Review the step-by-step explanations carefully!";
    } else {
      message = "Great job! Review all questions to reinforce your understanding and identify areas for improvement.";
    }

    return Container(
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
    );
  }

  Widget _buildStartReviewingButton() {
    return Container(
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
                _navigateToQuestionReview(0); // First item in filtered list
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
    );
  }
}

