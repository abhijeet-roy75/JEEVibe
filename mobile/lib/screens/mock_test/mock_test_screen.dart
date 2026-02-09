/// Mock Test Screen
/// Main test interface with timer, question display, and navigation

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_platform_sizing.dart';
import '../../widgets/latex_widget.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/offline/cached_image_widget.dart';
import '../../providers/mock_test_provider.dart';
import '../../models/mock_test_models.dart';
import '../../models/assessment_question.dart' show QuestionOption;
import 'mock_test_results_screen.dart';

class MockTestScreen extends StatefulWidget {
  const MockTestScreen({super.key});

  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen> {
  String? _selectedAnswer;
  final TextEditingController _numericalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentAnswer();
  }

  @override
  void dispose() {
    _numericalController.dispose();
    super.dispose();
  }

  void _loadCurrentAnswer() {
    final provider = context.read<MockTestProvider>();
    final answer = provider.getCurrentAnswer();
    final question = provider.currentQuestion;

    if (question?.isMcq == true) {
      _selectedAnswer = answer;
    } else {
      _numericalController.text = answer ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showExitDialog();
        return false;
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Consumer<MockTestProvider>(
                  builder: (context, provider, _) {
                    if (provider.activeSession == null) {
                      return const Center(
                        child: Text('No active test'),
                      );
                    }
                    return _buildQuestionView(provider);
                  },
                ),
              ),
              _buildBottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<MockTestProvider>(
      builder: (context, provider, _) {
        final session = provider.activeSession;
        if (session == null) return const SizedBox.shrink();

        final currentQ = provider.currentQuestion;
        final sectionName = currentQ != null
            ? session.sections[currentQ.sectionIndex].name
            : 'Test';

        return Container(
          decoration: const BoxDecoration(
            gradient: AppColors.ctaGradient,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(PlatformSizing.spacing(16), PlatformSizing.spacing(8), PlatformSizing.spacing(16), PlatformSizing.spacing(12)),
              child: Column(
                children: [
                  // Timer and section row
                  Row(
                    children: [
                      // Exit button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(PlatformSizing.radius(10)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () => _showExitDialog(),
                          padding: EdgeInsets.all(PlatformSizing.spacing(8)),
                          constraints: const BoxConstraints(),
                          tooltip: 'Exit Test',
                        ),
                      ),
                      SizedBox(width: PlatformSizing.spacing(8)),
                      // Question palette button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(PlatformSizing.radius(10)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.grid_view, color: Colors.white, size: 20),
                          onPressed: () => _showQuestionPalette(),
                          padding: EdgeInsets.all(PlatformSizing.spacing(8)),
                          constraints: const BoxConstraints(),
                          tooltip: 'Question Palette',
                        ),
                      ),
                      // Section name
                      Expanded(
                        child: Text(
                          sectionName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: PlatformSizing.fontSize(16),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Timer
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getTimerColor(provider.timeRemainingSeconds),
                          borderRadius: BorderRadius.circular(PlatformSizing.radius(20)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer,
                              color: Colors.white,
                              size: PlatformSizing.iconSize(16),
                            ),
                            SizedBox(width: PlatformSizing.spacing(4)),
                            Text(
                              _formatTime(provider.timeRemainingSeconds),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: PlatformSizing.fontSize(14),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: PlatformSizing.spacing(8)),
                  // Progress
                  Row(
                    children: [
                      Text(
                        'Q ${provider.currentQuestionIndex + 1} of ${provider.totalQuestions}',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: PlatformSizing.fontSize(12),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${provider.answeredCount} answered',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: PlatformSizing.fontSize(12),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: PlatformSizing.spacing(8)),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(PlatformSizing.radius(4)),
                    child: LinearProgressIndicator(
                      value: (provider.currentQuestionIndex + 1) /
                          provider.totalQuestions,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuestionView(MockTestProvider provider) {
    final question = provider.currentQuestion;
    if (question == null) {
      return const Center(child: Text('No question'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(PlatformSizing.spacing(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(PlatformSizing.spacing(16)),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(PlatformSizing.radius(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: PlatformSizing.spacing(10),
                  offset: Offset(PlatformSizing.spacing(0), PlatformSizing.spacing(2)),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getSubjectColor(question.subject)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(PlatformSizing.radius(8)),
                      ),
                      child: Text(
                        question.subject,
                        style: TextStyle(
                          color: _getSubjectColor(question.subject),
                          fontSize: PlatformSizing.fontSize(12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        provider.isCurrentMarkedForReview()
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: provider.isCurrentMarkedForReview()
                            ? AppColors.primary
                            : AppColors.textLight,
                      ),
                      onPressed: () => provider.toggleMarkForReview(),
                    ),
                  ],
                ),
                SizedBox(height: PlatformSizing.spacing(16)),
                // Question text - prefer HTML, fallback to plain text
                _buildQuestionText(question),
                // Question image (debug logging removed - was causing spam on every rebuild)
                if (question.hasImage) ...[
                  SizedBox(height: PlatformSizing.spacing(16)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(PlatformSizing.radius(8)),
                    child: _buildQuestionImage(question.imageUrl!),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: PlatformSizing.spacing(16)),
          // Answer section
          _buildAnswerSection(question, provider),
        ],
      ),
    );
  }

  Widget _buildAnswerSection(MockTestQuestion question, MockTestProvider provider) {
    if (question.isMcq) {
      return _buildMcqOptions(question, provider);
    } else {
      return _buildNumericalInput(provider);
    }
  }

  Widget _buildMcqOptions(MockTestQuestion question, MockTestProvider provider) {
    if (question.options == null || question.options!.isEmpty) {
      return const Text('No options available');
    }

    return Column(
      children: question.options!.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final optionId = option.optionId.isNotEmpty
            ? option.optionId
            : String.fromCharCode(65 + index);
        final isSelected = _selectedAnswer == optionId;

        return Container(
          margin: EdgeInsets.only(bottom: PlatformSizing.spacing(12)),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderDefault,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _selectOption(optionId, provider),
              borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
              child: Padding(
                padding: EdgeInsets.all(PlatformSizing.spacing(16)),
                child: Row(
                  children: [
                    Container(
                      width: PlatformSizing.spacing(32),
                      height: PlatformSizing.spacing(32),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.cardLightPurple,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          optionId,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: PlatformSizing.spacing(12)),
                    Expanded(
                      child: _buildOptionText(option),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumericalInput(MockTestProvider provider) {
    return Container(
      padding: EdgeInsets.all(PlatformSizing.spacing(16)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your answer:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: PlatformSizing.spacing(12)),
          TextField(
            controller: _numericalController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              hintText: 'Type your numerical answer',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: PlatformSizing.fontSize(18),
            ),
            onChanged: (value) => _saveNumericalAnswer(value, provider),
          ),
          SizedBox(height: PlatformSizing.spacing(8)),
          Text(
            'Note: Numerical questions have no negative marking',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Build question text using Html widget for HTML content or LaTeXWidget for plain text with LaTeX.
  Widget _buildQuestionText(MockTestQuestion question) {
    // Prefer HTML rendering - Html widget handles LaTeX in HTML automatically
    if (question.questionTextHtml != null && question.questionTextHtml!.isNotEmpty) {
      return Html(
        data: question.questionTextHtml!,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(16),
            lineHeight: LineHeight(1.6),
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
          ),
          'strong': Style(fontWeight: FontWeight.w700),
          'b': Style(fontWeight: FontWeight.w700),
        },
      );
    }

    // Fallback to LaTeXWidget for plain text (may contain LaTeX with $ delimiters)
    if (question.questionText.isNotEmpty) {
      return LaTeXWidget(
        text: question.questionText,
        textStyle: AppTextStyles.bodyMedium.copyWith(
          fontSize: PlatformSizing.fontSize(16),
          height: PlatformSizing.spacing(1.6),
        ),
      );
    }

    return Text(
      'Question text not available',
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  /// Build option text using Html widget for HTML content or LaTeXWidget for plain text with LaTeX.
  Widget _buildOptionText(QuestionOption option) {
    if (option.html != null && option.html!.isNotEmpty) {
      return Html(
        data: option.html!,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(15),
            lineHeight: LineHeight(1.5),
            color: AppColors.textPrimary,
          ),
          // Normalize bold/strong to regular weight so no option stands out
          'strong': Style(fontWeight: FontWeight.w400),
          'b': Style(fontWeight: FontWeight.w400),
        },
      );
    }

    // Fallback to LaTeXWidget for plain text (may contain LaTeX with $ delimiters)
    return LaTeXWidget(
      text: option.text,
      textStyle: AppTextStyles.bodyMedium.copyWith(
        fontSize: PlatformSizing.fontSize(15),
        height: PlatformSizing.spacing(1.5),
      ),
    );
  }

  /// Build question image - uses _NetworkSvgImage for SVGs, CachedImageWidget for raster
  Widget _buildQuestionImage(String imageUrl) {
    final isSvg = imageUrl.toLowerCase().contains('.svg');

    if (isSvg) {
      return _NetworkSvgImage(
        url: imageUrl,
        width: double.infinity,
        fit: BoxFit.contain,
      );
    }

    return CachedImageWidget(
      imageUrl: imageUrl,
      width: double.infinity,
      fit: BoxFit.contain,
      errorWidget: _buildImageError(),
    );
  }

  static Widget _buildImageError() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: PlatformSizing.spacing(16)),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(PlatformSizing.radius(8)),
      ),
      child: Column(
        children: [
          const Icon(Icons.image_not_supported_outlined,
              color: AppColors.textLight, size: 28),
          SizedBox(height: PlatformSizing.spacing(4)),
          Text(
            'Image could not be loaded',
            style: TextStyle(color: AppColors.textLight, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Consumer<MockTestProvider>(
      builder: (context, provider, _) {
        final hasPrevious = provider.currentQuestionIndex > 0;
        final isLastQuestion =
            provider.currentQuestionIndex == provider.totalQuestions - 1;

        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.of(context).viewPadding.bottom,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: PlatformSizing.spacing(10),
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Previous button
              Expanded(
                child: AppOutlinedButton(
                  text: 'Previous',
                  leadingIcon: Icons.arrow_back_ios_rounded,
                  size: GradientButtonSize.medium,
                  onPressed: hasPrevious
                      ? () {
                          _saveCurrentAnswer(provider);
                          provider.previousQuestion();
                          _loadCurrentAnswer();
                        }
                      : null,
                ),
              ),
              // Clear button (center)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: PlatformSizing.spacing(12)),
                child: TextButton(
                  onPressed: () => _clearAnswer(provider),
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: PlatformSizing.fontSize(14),
                    ),
                  ),
                ),
              ),
              // Next / Submit button
              Expanded(
                child: isLastQuestion
                    ? GradientButton(
                        text: 'Submit',
                        size: GradientButtonSize.medium,
                        trailingIcon: Icons.check,
                        onPressed: () => _showSubmitDialog(),
                      )
                    : GradientButton(
                        text: 'Next',
                        size: GradientButtonSize.medium,
                        trailingIcon: Icons.arrow_forward_ios_rounded,
                        onPressed: () {
                          _saveCurrentAnswer(provider);
                          provider.nextQuestion();
                          _loadCurrentAnswer();
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectOption(String optionId, MockTestProvider provider) {
    setState(() {
      _selectedAnswer = optionId;
    });
    provider.saveAnswer(optionId);
  }

  void _saveNumericalAnswer(String value, MockTestProvider provider) {
    provider.saveAnswer(value.isNotEmpty ? value : null);
  }

  void _saveCurrentAnswer(MockTestProvider provider) {
    final question = provider.currentQuestion;
    if (question == null) return;

    if (question.isMcq) {
      if (_selectedAnswer != null) {
        provider.saveAnswer(_selectedAnswer);
      }
    } else {
      final value = _numericalController.text.trim();
      provider.saveAnswer(value.isNotEmpty ? value : null);
    }
  }

  void _clearAnswer(MockTestProvider provider) {
    setState(() {
      _selectedAnswer = null;
      _numericalController.clear();
    });
    provider.clearAnswer();
  }

  Color _getSubjectColor(String subject) {
    switch (subject) {
      case 'Physics':
        return AppColors.subjectPhysics;
      case 'Chemistry':
        return AppColors.subjectChemistry;
      case 'Mathematics':
        return AppColors.subjectMathematics;
      default:
        return AppColors.primary;
    }
  }

  Color _getTimerColor(int seconds) {
    if (seconds < 300) return Colors.red; // < 5 min
    if (seconds < 900) return Colors.orange; // < 15 min
    return Colors.black54;
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes}:${secs.toString().padLeft(2, '0')}';
  }

  void _showQuestionPalette() {
    final provider = context.read<MockTestProvider>();
    final session = provider.activeSession;
    if (session == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuestionPaletteSheet(
        session: session,
        currentIndex: provider.currentQuestionIndex,
        onQuestionTap: (index) {
          _saveCurrentAnswer(provider);
          provider.goToQuestion(index);
          _loadCurrentAnswer();
          Navigator.pop(context);
        },
        onSubmit: () {
          Navigator.pop(context);
          _showSubmitDialog();
        },
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Test?'),
        content: const Text(
          'Your progress will be saved. You can resume later, but the timer will continue running.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Test'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit test
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  void _showSubmitDialog() {
    final provider = context.read<MockTestProvider>();
    final session = provider.activeSession;
    if (session == null) return;

    final unanswered = session.totalQuestions - session.answeredCount;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Test?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Answered: ${session.answeredCount}/${session.totalQuestions}'),
            if (unanswered > 0)
              Text(
                '$unanswered questions unanswered',
                style: TextStyle(color: AppColors.error),
              ),
            if (session.markedCount > 0)
              Text('${session.markedCount} marked for review'),
            SizedBox(height: PlatformSizing.spacing(16)),
            const Text(
              'Are you sure you want to submit? This cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Review'),
          ),
          GradientButton(
            text: 'Submit',
            size: GradientButtonSize.small,
            trailingIcon: Icons.check,
            width: PlatformSizing.spacing(120),
            onPressed: () {
              Navigator.pop(context);
              _submitTest();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submitTest() async {
    final provider = context.read<MockTestProvider>();

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            SizedBox(width: PlatformSizing.spacing(16)),
            const Text('Submitting...'),
          ],
        ),
      ),
    );

    try {
      final result = await provider.submitTest();

      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MockTestResultsScreen(
              testId: result.testId,
              result: result,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

/// Question Palette Bottom Sheet
class _QuestionPaletteSheet extends StatelessWidget {
  final MockTestSession session;
  final int currentIndex;
  final Function(int) onQuestionTap;
  final VoidCallback onSubmit;

  const _QuestionPaletteSheet({
    required this.session,
    required this.currentIndex,
    required this.onQuestionTap,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: PlatformSizing.spacing(12)),
            width: PlatformSizing.spacing(40),
            height: PlatformSizing.spacing(4),
            decoration: BoxDecoration(
              color: AppColors.textLight,
              borderRadius: BorderRadius.circular(PlatformSizing.radius(2)),
            ),
          ),
          // Title
          Padding(
            padding: EdgeInsets.all(PlatformSizing.spacing(16)),
            child: Text(
              'Question Palette',
              style: TextStyle(
                fontSize: PlatformSizing.fontSize(18),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Legend
          Padding(
            padding: EdgeInsets.symmetric(horizontal: PlatformSizing.spacing(16)),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildLegendItem(Colors.grey, 'Not Visited'),
                _buildLegendItem(Colors.red, 'Not Answered'),
                _buildLegendItem(Colors.green, 'Answered'),
                _buildLegendItem(Colors.purple, 'Marked'),
              ],
            ),
          ),
          const Divider(height: 24),
          // Question grid
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(PlatformSizing.spacing(16)),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: session.questions.length,
              itemBuilder: (context, index) {
                final qNum = index + 1;
                final state = session.questionStates[qNum] ?? QuestionState.notVisited;
                final isCurrent = index == currentIndex;

                return GestureDetector(
                  onTap: () => onQuestionTap(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getStateColor(state),
                      borderRadius: BorderRadius.circular(PlatformSizing.radius(8)),
                      border: isCurrent
                          ? Border.all(color: AppColors.primary, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$qNum',
                        style: TextStyle(
                          color: state == QuestionState.notVisited
                              ? AppColors.textDark
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Submit button
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.of(context).viewPadding.bottom,
            ),
            child: GradientButton(
              text: 'Submit Test',
              leadingIcon: Icons.check_circle_outline,
              onPressed: onSubmit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: PlatformSizing.spacing(16),
          height: PlatformSizing.spacing(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(PlatformSizing.radius(4)),
          ),
        ),
        SizedBox(width: PlatformSizing.spacing(4)),
        Text(
          label,
          style: TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  Color _getStateColor(QuestionState state) {
    switch (state) {
      case QuestionState.notVisited:
        return Colors.grey.shade300;
      case QuestionState.notAnswered:
        return Colors.red;
      case QuestionState.answered:
        return Colors.green;
      case QuestionState.markedForReview:
        return Colors.purple;
      case QuestionState.answeredMarked:
        return Colors.purple.shade300;
    }
  }
}

/// Fetches SVG from network, strips namespace prefixes (ns0:, ns2:, etc.),
/// and renders with SvgPicture.string(). Needed because Matplotlib-generated
/// SVGs use namespace-prefixed elements that flutter_svg cannot parse.
class _NetworkSvgImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  const _NetworkSvgImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  State<_NetworkSvgImage> createState() => _NetworkSvgImageState();
}

class _NetworkSvgImageState extends State<_NetworkSvgImage> {
  String? _svgData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchAndSanitize();
  }

  Future<void> _fetchAndSanitize() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode != 200) {
        if (mounted) setState(() { _hasError = true; _isLoading = false; });
        return;
      }

      String svg = utf8.decode(response.bodyBytes);
      svg = _sanitizeSvg(svg);

      if (mounted) {
        setState(() {
          _svgData = svg;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[MockTest] SVG fetch error: $e');
      if (mounted) setState(() { _hasError = true; _isLoading = false; });
    }
  }

  /// Remove namespace prefixes and XML declaration so flutter_svg can parse.
  String _sanitizeSvg(String svg) {
    // Remove XML declaration
    svg = svg.replaceAll(RegExp(r'<\?xml[^?]*\?>'), '');

    // Strip namespace prefixes from tags: <ns0:svg> → <svg>, </ns0:g> → </g>
    // Uses replaceAllMapped to properly handle capture groups (not $1 literal)
    svg = svg.replaceAllMapped(
      RegExp(r'<(/?)ns\d+:'),
      (match) => '<${match.group(1)}',
    );

    // Strip namespace prefixes from attributes: ns4:href → href
    svg = svg.replaceAllMapped(
      RegExp(r'\bns\d+:'),
      (match) => '',
    );

    // Remove namespace declarations: xmlns:ns0="...", xmlns:dc="...", etc.
    svg = svg.replaceAll(RegExp(r'\s+xmlns:\w+="[^"]*"'), '');

    // Ensure root svg has the standard xmlns
    if (!svg.contains('xmlns="http://www.w3.org/2000/svg"')) {
      svg = svg.replaceFirst('<svg', '<svg xmlns="http://www.w3.org/2000/svg"');
    }

    // Remove <metadata>...</metadata> blocks entirely
    svg = svg.replaceAll(RegExp(r'<metadata>[\s\S]*?</metadata>'), '');

    return svg.trim();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height ?? 200,
        color: AppColors.backgroundLight,
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryPurple,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_hasError || _svgData == null) {
      return Container(
        width: widget.width,
        height: widget.height ?? 200,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }

    // Use LayoutBuilder to resolve double.infinity to actual pixel width.
    // SvgPicture cannot lay out with unbounded constraints from ScrollView.
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth = (widget.width != null && widget.width!.isFinite)
            ? widget.width
            : (constraints.maxWidth.isFinite ? constraints.maxWidth : 300.0);
        return SvgPicture.string(
          _svgData!,
          width: resolvedWidth,
          height: widget.height,
          fit: widget.fit,
          allowDrawingOutsideViewBox: true,
        );
      },
    );
  }
}

