/// Assessment Question Screen
/// Displays questions one at a time with forward-only navigation
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/assessment_question.dart';
import '../models/assessment_response.dart';
import '../services/api_service.dart';
import '../services/firebase/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/latex_widget.dart';
import 'assessment_loading_screen.dart';

class AssessmentQuestionScreen extends StatefulWidget {
  const AssessmentQuestionScreen({super.key});

  @override
  State<AssessmentQuestionScreen> createState() => _AssessmentQuestionScreenState();
}

class _AssessmentQuestionScreenState extends State<AssessmentQuestionScreen> {
  List<AssessmentQuestion>? _questions;
  int _currentQuestionIndex = 0;
  Map<int, AssessmentResponse> _responses = {};
  Map<int, DateTime> _questionStartTimes = {};
  Timer? _timer;
  int _remainingSeconds = 45 * 60; // 45 minutes in seconds
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();
      
      if (token == null) {
        setState(() {
          _error = 'Authentication required. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      final questions = await ApiService.getAssessmentQuestions(authToken: token);
      
      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
          if (questions.isNotEmpty) {
            _questionStartTimes[0] = DateTime.now();
          }
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

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            // Time's up - auto-submit
            _timer?.cancel();
            _submitAssessment();
          }
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  AssessmentQuestion? get _currentQuestion {
    if (_questions == null || _currentQuestionIndex >= _questions!.length) {
      return null;
    }
    return _questions![_currentQuestionIndex];
  }

  bool get _isLastQuestion => _currentQuestionIndex == (_questions?.length ?? 0) - 1;
  bool get _hasAnswer => _responses.containsKey(_currentQuestionIndex);

  void _recordAnswer(String answer) {
    final question = _currentQuestion;
    if (question == null) return;

    final startTime = _questionStartTimes[_currentQuestionIndex] ?? DateTime.now();
    final timeTaken = DateTime.now().difference(startTime).inSeconds;

    setState(() {
      _responses[_currentQuestionIndex] = AssessmentResponse(
        questionId: question.questionId,
        studentAnswer: answer,
        timeTakenSeconds: timeTaken,
      );
    });
  }

  void _nextQuestion() {
    if (_isLastQuestion) {
      _submitAssessment();
    } else {
      setState(() {
        _currentQuestionIndex++;
        _questionStartTimes[_currentQuestionIndex] = DateTime.now();
      });
    }
  }

  Future<void> _submitAssessment() async {
    if (_isSubmitting) return;
    
    final question = _currentQuestion;
    if (question != null && !_hasAnswer) {
      // Record current question if not answered
      _recordAnswer('');
    }

    if (_responses.length != _questions?.length) {
      // Show error - not all questions answered
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all questions before submitting.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();
      
      if (token == null) {
        throw Exception('Authentication required');
      }

      final responsesList = List.generate(
        _questions!.length,
        (index) => _responses[index]!,
      );

      final result = await ApiService.submitAssessment(
        authToken: token,
        responses: responsesList,
      );

      if (mounted) {
        if (result.success && result.data != null) {
          // Navigate to loading screen, then to dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AssessmentLoadingScreen(
                assessmentData: result.data!,
              ),
            ),
          );
        } else {
          throw Exception(result.error ?? 'Failed to submit assessment');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppColors.errorRed,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _submitAssessment();
              },
            ),
          ),
        );
      }
    }
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

    if (_error != null) {
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
                Text(
                  'Error',
                  style: AppTextStyles.headerMedium.copyWith(
                    color: AppColors.errorRed,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _isLoading = true;
                    });
                    _loadQuestions();
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

    if (_questions == null || _currentQuestion == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    return PopScope(
      canPop: false, // Prevent back navigation
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Column(
            children: [
              _buildProgressBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQuestionHeader(),
                      const SizedBox(height: 16),
                      if (_currentQuestion!.hasImage) ...[
                        _buildQuestionImage(),
                        const SizedBox(height: 16),
                      ],
                      _buildQuestionText(),
                      const SizedBox(height: 24),
                      _buildAnswerInput(),
                    ],
                  ),
                ),
              ),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(), // No back button
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer, color: AppColors.primaryPurple, size: 20),
          const SizedBox(width: 8),
          Text(
            _formatTime(_remainingSeconds),
            style: AppTextStyles.headerSmall.copyWith(
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      centerTitle: true,
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentQuestionIndex + 1) / (_questions?.length ?? 30);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} of ${_questions?.length ?? 30}',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${((progress * 100).round())}%',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.borderGray,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionHeader() {
    final question = _currentQuestion!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardLightPurple,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              question.subject,
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              question.chapter,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionImage() {
    final imageUrl = _currentQuestion!.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SvgPicture.network(
          imageUrl,
          fit: BoxFit.contain,
          placeholderBuilder: (context) => Container(
            height: 200,
            color: AppColors.borderGray,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            ),
          ),
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 200,
              color: AppColors.borderGray,
              child: const Center(
                child: Icon(Icons.broken_image, color: AppColors.textLight),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuestionText() {
    final question = _currentQuestion!;
    final text = question.questionLatex ?? question.questionText;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LaTeXWidget(
        text: text,
        textStyle: AppTextStyles.bodyLarge,
        allowWrapping: true,
      ),
    );
  }

  Widget _buildAnswerInput() {
    final question = _currentQuestion!;
    final currentAnswer = _responses[_currentQuestionIndex]?.studentAnswer ?? '';

    if (question.isMcq) {
      return _buildMcqOptions(currentAnswer);
    } else {
      return _buildNumericalInput(currentAnswer);
    }
  }

  Widget _buildMcqOptions(String selectedAnswer) {
    final question = _currentQuestion!;
    final options = question.options ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select your answer:',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...options.map((option) {
          final isSelected = selectedAnswer == option.optionId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                _recordAnswer(option.optionId);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.cardLightPurple : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryPurple
                        : AppColors.borderGray,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryPurple
                              : AppColors.borderMedium,
                          width: 2,
                        ),
                        color: isSelected
                            ? AppColors.primaryPurple
                            : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: LaTeXWidget(
                        text: option.text,
                        textStyle: AppTextStyles.bodyMedium,
                        allowWrapping: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNumericalInput(String currentAnswer) {
    final controller = TextEditingController(text: currentAnswer);
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: currentAnswer.length),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter your answer:',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
          ],
          decoration: InputDecoration(
            hintText: 'Enter numerical value',
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
          style: AppTextStyles.bodyLarge,
          onChanged: (value) {
            if (value.isNotEmpty) {
              _recordAnswer(value);
            }
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Enter decimal values (e.g., 2.5, -1.23)',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _nextQuestion,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLastQuestion ? 'Submit Assessment' : 'Next Question',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!_isLastQuestion) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
