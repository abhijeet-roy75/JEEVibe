/// Weak Spot Retrieval Screen
/// 3 validation questions (2 near transfer + 1 contrast transfer).
/// Reuses QuestionCardWidget. No timer. Pass = 2/3 correct.
import 'package:flutter/material.dart';
import '../models/daily_quiz_question.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:jeevibe_mobile/theme/app_platform_sizing.dart';
import '../widgets/daily_quiz/question_card_widget.dart';
import '../widgets/buttons/gradient_button.dart';
import 'weak_spot_results_screen.dart';

class WeakSpotRetrievalScreen extends StatefulWidget {
  final String nodeId;
  final String nodeTitle;
  final String capsuleId;
  final List<dynamic> questions;
  final String authToken;
  final String userId;

  const WeakSpotRetrievalScreen({
    super.key,
    required this.nodeId,
    required this.nodeTitle,
    required this.capsuleId,
    required this.questions,
    required this.authToken,
    required this.userId,
  });

  @override
  State<WeakSpotRetrievalScreen> createState() => _WeakSpotRetrievalScreenState();
}

class _WeakSpotRetrievalScreenState extends State<WeakSpotRetrievalScreen> {
  int _currentIndex = 0;
  String? _selectedAnswer;
  bool _isSubmitting = false;
  bool _isDisposed = false;

  // answers[questionId] = selectedAnswer
  final Map<String, String> _answers = {};

  late final List<DailyQuizQuestion> _questions;

  @override
  void initState() {
    super.initState();
    _questions = widget.questions
        .map((q) => DailyQuizQuestion.fromJson(q as Map<String, dynamic>))
        .toList();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  DailyQuizQuestion get _current => _questions[_currentIndex];
  int get _totalQuestions => _questions.length;
  bool get _isLastQuestion => _currentIndex >= _totalQuestions - 1;
  bool get _canSubmit => _selectedAnswer != null;

  void _onAnswerSelected(String answer) {
    if (!_isDisposed && mounted) {
      setState(() {
        _selectedAnswer = answer;
      });
    }
  }

  Future<void> _submitAnswer() async {
    if (_selectedAnswer == null) return;
    _answers[_current.questionId] = _selectedAnswer!;

    if (!_isLastQuestion) {
      if (!_isDisposed && mounted) {
        setState(() {
          _currentIndex++;
          _selectedAnswer = null;
        });
      }
      return;
    }

    // Last question — submit all
    if (_isSubmitting) return;
    if (!_isDisposed && mounted) {
      setState(() => _isSubmitting = true);
    }

    try {
      final responses = _questions.map((q) {
        return {
          'questionId': q.questionId,
          'studentAnswer': _answers[q.questionId] ?? '',
        };
      }).toList();

      final apiService = ApiService();
      final result = await apiService.submitWeakSpotRetrieval(
        userId: widget.userId,
        nodeId: widget.nodeId,
        responses: responses,
        authToken: widget.authToken,
      );

      if (!_isDisposed && mounted) {
        final data = result['data'] as Map<String, dynamic>? ?? {};
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WeakSpotResultsScreen(
              passed: data['passed'] as bool? ?? false,
              correctCount: data['correctCount'] as int? ?? 0,
              totalCount: _totalQuestions,
              newNodeState: data['newState']?.toString() ?? 'active',
              nodeTitle: widget.nodeTitle,
            ),
          ),
        );
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to submit: ${e.toString().replaceAll('Exception: ', '')}',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Validation')),
        body: const Center(child: Text('No questions available.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewPadding.bottom + 100,
              ),
              child: QuestionCardWidget(
                question: _current,
                selectedAnswer: _selectedAnswer,
                showAnswerOptions: true,
                onAnswerSelected: _onAnswerSelected,
                elapsedSeconds: null, // no timer
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.textDark,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Validation (${_currentIndex + 1}/$_totalQuestions)',
                          style: AppTextStyles.headerMedium.copyWith(
                            fontSize: PlatformSizing.fontSize(18),
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          widget.nodeTitle,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMedium,
                            fontSize: PlatformSizing.fontSize(12),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Progress bar
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _totalQuestions,
              backgroundColor: AppColors.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
              minHeight: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).viewPadding.bottom + 12,
      ),
      child: GradientButton(
        text: _isSubmitting
            ? 'Submitting...'
            : _isLastQuestion
                ? 'Submit'
                : 'Next Question',
        onPressed: _canSubmit && !_isSubmitting ? _submitAnswer : null,
        size: GradientButtonSize.large,
      ),
    );
  }
}
