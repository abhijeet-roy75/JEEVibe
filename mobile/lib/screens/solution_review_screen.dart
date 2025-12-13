/// Solution Review Screen - Displays stored solutions from history
import 'package:flutter/material.dart';
import '../models/snap_data_model.dart';
import '../models/solution_model.dart';
import '../widgets/latex_widget.dart';
import '../widgets/chemistry_text.dart';
import '../widgets/priya_avatar.dart';
import '../widgets/app_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../config/content_config.dart';
import '../utils/text_preprocessor.dart';

class SolutionReviewScreen extends StatefulWidget {
  final List<RecentSolution> allSolutions;
  final int initialIndex;

  const SolutionReviewScreen({
    super.key,
    required this.allSolutions,
    this.initialIndex = 0,
  });

  @override
  State<SolutionReviewScreen> createState() => _SolutionReviewScreenState();
}

class _SolutionReviewScreenState extends State<SolutionReviewScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    if (_currentIndex >= widget.allSolutions.length) {
      _currentIndex = 0;
    }
  }

  RecentSolution get _currentSolution => widget.allSolutions[_currentIndex];

  void _nextSolution() {
    if (_currentIndex < widget.allSolutions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  void _previousSolution() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  /// Reconstruct Solution object from stored RecentSolution data
  Solution _reconstructSolution(RecentSolution recentSolution) {
    final solutionData = recentSolution.solutionData;
    
    // Extract solution details from stored data
    final solutionDetails = solutionData?['solution'] as Map<String, dynamic>? ?? {};
    
    return Solution(
      recognizedQuestion: recentSolution.question,
      subject: recentSolution.subject,
      topic: recentSolution.topic,
      difficulty: solutionData?['difficulty']?.toString() ?? 'medium',
      solution: SolutionDetails(
        approach: solutionDetails['approach']?.toString() ?? '',
        steps: (solutionDetails['steps'] as List<dynamic>?)
                ?.map((s) => s.toString())
                .toList() ??
            [],
        finalAnswer: solutionDetails['finalAnswer']?.toString() ?? '',
        priyaMaamTip: solutionDetails['priyaMaamTip']?.toString() ?? '',
      ),
      followUpQuestions: [], // Not stored in RecentSolution
    );
  }

  @override
  Widget build(BuildContext context) {
    final solution = _reconstructSolution(_currentSolution);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.space24),
                    _buildQuestionCard(solution),
                    const SizedBox(height: AppSpacing.space32),
                    _buildSolutionSteps(solution, context),
                    const SizedBox(height: AppSpacing.space24),
                    _buildFinalAnswer(solution),
                    const SizedBox(height: AppSpacing.space24),
                    _buildPriyaTip(solution),
                    const SizedBox(height: AppSpacing.space24),
                    _buildNavigationButtons(),
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

  Widget _buildHeader(BuildContext context) {
    return AppHeaderWithIcon(
      icon: Icons.history,
      title: 'Solution ${_currentIndex + 1} of ${widget.allSolutions.length}',
      subtitle: '${_currentSolution.topic} - ${_currentSolution.subject}',
      iconColor: AppColors.primaryPurple,
      iconSize: 48,
      onClose: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildQuestionCard(Solution solution) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book, color: AppColors.primaryPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                'QUESTION:',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildContentWidget(
            solution.recognizedQuestion,
            solution.subject,
            ContentConfig.getQuestionTextStyle(color: AppColors.textMedium).copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.infoBackground,
                  borderRadius: BorderRadius.circular(AppRadius.radiusRound),
                ),
                child: Text(
                  'JEE Main Level',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.infoBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _currentSolution.getTimeAgo(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionSteps(Solution solution, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.primaryPurple, size: 20),
            const SizedBox(width: 8),
            Text('Step-by-Step Solution', style: AppTextStyles.headerMedium),
          ],
        ),
        const SizedBox(height: 16),
        ...solution.solution.steps.asMap().entries.map((entry) {
          return _buildStepCard(entry.key + 1, entry.value, context);
        }),
      ],
    );
  }

  Widget _buildStepCard(int stepNumber, String stepContent, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.cardLightPurple,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$stepNumber',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
                 title: Text(
                   _getStepTitle(stepNumber, stepContent),
                   style: AppTextStyles.labelMedium,
                 ),
          trailing: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMedium),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(AppRadius.radiusSmall),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child:                       _buildContentWidget(
                        TextPreprocessor.addSpacesToText(stepContent),
                        _currentSolution.subject,
                        ContentConfig.getStepTextStyle(color: AppColors.textMedium),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Add spaces between words that are concatenated (e.g., "BothStatementI" -> "Both Statement I")
  String _getStepTitle(int number, String stepContent) {
    // Try to extract title from step content
    // Format: "Step 1: Title" or "Title: description" or just use first few words
    final content = stepContent.trim();
    
    // Check if step starts with "Step N:" or "Step N -"
    final stepPattern = RegExp(r'^Step\s+\d+[:\-]\s*(.+?)(?:\.|$)', caseSensitive: false);
    final match = stepPattern.firstMatch(content);
    if (match != null && match.group(1) != null) {
      String title = match.group(1)!.trim();
      // Limit title length to avoid overflow
      if (title.length > 50) {
        title = '${title.substring(0, 47)}...';
      }
      return title;
    }
    
    // Check if step has a colon separator (e.g., "Title: description")
    final colonIndex = content.indexOf(':');
    if (colonIndex > 0 && colonIndex < 60) {
      String title = content.substring(0, colonIndex).trim();
      // Remove common prefixes
      title = title.replaceAll(RegExp(r'^(Step\s+\d+[:\-]?\s*)', caseSensitive: true), '');
      if (title.isNotEmpty && title.length <= 50) {
        return title;
      }
    }
    
    // Fallback: use first few words (up to 6 words or 50 chars)
    final words = content.split(RegExp(r'\s+'));
    if (words.isNotEmpty) {
      String title = '';
      for (int i = 0; i < words.length && i < 6 && title.length < 50; i++) {
        if (title.isNotEmpty) title += ' ';
        title += words[i];
      }
      if (title.isNotEmpty) {
        return title.length > 50 ? '${title.substring(0, 47)}...' : title;
      }
    }
    
    // Ultimate fallback
    return 'Step $number';
  }

  Widget _buildFinalAnswer(Solution solution) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.successBackground.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: AppColors.successGreen.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.successGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'FINAL ANSWER',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.successGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildContentWidget(
            solution.solution.finalAnswer,
            _currentSolution.subject,
            TextStyle(
              fontSize: ContentConfig.finalAnswerTextSize,
              color: AppColors.successGreen,
              fontWeight: FontWeight.w600,
              height: 1.6,
            ),
            allowWrapping: true, // Enable wrapping for Final Answer
          ),
        ],
      ),
    );
  }

  Widget _buildPriyaTip(Solution solution) {
    if (solution.solution.priyaMaamTip.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.priyaCardGradient,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PriyaAvatar(size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Priya Ma\'am\'s Tip',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF9333EA),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildContentWidget(
                  TextPreprocessor.addSpacesToText(solution.solution.priyaMaamTip),
                  _currentSolution.subject,
                  ContentConfig.getPriyaTipTextStyle(
                    color: const Color(0xFF4C1D95), // Darker purple for better contrast
                  ),
                  allowWrapping: true, // Enable wrapping for Priya's Tip
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build content widget based on subject (ChemistryText for Chemistry, LaTeXWidget for others)
  Widget _buildContentWidget(String content, String subject, TextStyle textStyle, {bool allowWrapping = false}) {
    if (subject.toLowerCase() == 'chemistry') {
      return ChemistryText(
        content,
        textStyle: textStyle,
        fontSize: textStyle.fontSize ?? 14,
        allowWrapping: allowWrapping,
      );
    } else {
      return LaTeXWidget(
        text: content,
        textStyle: textStyle,
        allowWrapping: allowWrapping,
      );
    }
  }

  Widget _buildNavigationButtons() {
    return Column(
      children: [
        // Next Solution / Back to List
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.ctaGradient,
            borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
            boxShadow: AppShadows.buttonShadow,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (_currentIndex < widget.allSolutions.length - 1) {
                  _nextSolution();
                } else {
                  Navigator.of(context).pop();
                }
              },
              borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
              child: Center(
                child: Text(
                  _currentIndex < widget.allSolutions.length - 1
                      ? 'Next Solution'
                      : 'Back to List',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Back to Dashboard
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
            border: Border.all(color: AppColors.primaryPurple, width: 2),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Pop until we reach home screen
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
              child: Center(
                child: Text(
                  'Back to Dashboard',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primaryPurple,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

