/// Solution Screen - Matches design: 9 Solution Screen.png
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/solution_model.dart';
import '../models/snap_data_model.dart';
import 'followup_quiz_screen.dart';
import 'ocr_failed_screen.dart';
import 'processing_screen.dart';
import 'camera_screen.dart';
import 'daily_limit_screen.dart';
import '../widgets/latex_widget.dart';
import '../widgets/chemistry_text.dart';
import '../widgets/priya_avatar.dart';
import '../widgets/app_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../providers/app_state_provider.dart';
import '../config/content_config.dart';
import '../utils/text_preprocessor.dart';

class SolutionScreen extends StatefulWidget {
  final Future<Solution> solutionFuture;
  final File? imageFile;

  const SolutionScreen({
    super.key, 
    required this.solutionFuture,
    this.imageFile,
  });

  @override
  State<SolutionScreen> createState() => _SolutionScreenState();
}

class _SolutionScreenState extends State<SolutionScreen> {
  bool _hasIncrementedSnap = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Solution>(
        future: widget.solutionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
          return const ProcessingScreen();
          } else if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          } else if (snapshot.hasData) {
          if (!_hasIncrementedSnap) {
            _hasIncrementedSnap = true;
            _incrementSnapAndSaveSolution(snapshot.data!);
          }
            return _buildContent(snapshot.data!);
          } else {
            return _buildErrorState("Unknown error occurred");
          }
        },
    );
  }

  Future<void> _incrementSnapAndSaveSolution(Solution solution) async {
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      
      final questionId = 'snap_${DateTime.now().millisecondsSinceEpoch}';
      await appState.incrementSnap(
        questionId,
        solution.topic,
        subject: solution.subject,
      );

      final recentSolution = RecentSolution(
        id: questionId,
        question: solution.recognizedQuestion,
        topic: solution.topic,
        subject: solution.subject,
        timestamp: DateTime.now().toIso8601String(),
        solutionData: {
          'solution': {
            'approach': solution.solution.approach,
            'steps': solution.solution.steps,
            'finalAnswer': solution.solution.finalAnswer,
            'priyaMaamTip': solution.solution.priyaMaamTip,
          },
          'difficulty': solution.difficulty,
        },
      );
      
      await appState.addRecentSolution(recentSolution);
    } catch (e) {
      debugPrint('Error incrementing snap/saving solution: $e');
    }
  }

  Widget _buildErrorState(String error) {
    final isOCRError = error.toLowerCase().contains('recognize') ||
        error.toLowerCase().contains('ocr') ||
        error.toLowerCase().contains('could not read') ||
        error.toLowerCase().contains('unclear');

    if (isOCRError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => OCRFailedScreen(errorMessage: error),
            ),
          );
        }
      });
      
      return Container(
        color: AppColors.backgroundLight,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Text('Error: $error', style: AppTextStyles.bodyMedium),
      ),
    );
  }

  Widget _buildContent(Solution solution) {
    return Scaffold(
      body: Container(
      decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
      ),
        child: Column(
          children: [
            _buildHeader(solution),
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.space24),
                    _buildQuestionCard(solution),
                    const SizedBox(height: AppSpacing.space32),
                    _buildSolutionSteps(solution),
                    const SizedBox(height: AppSpacing.space24),
                    _buildFinalAnswer(solution),
                    const SizedBox(height: AppSpacing.space24),
                    _buildPriyaTip(solution),
                    const SizedBox(height: AppSpacing.space32),
                    _buildPracticeSection(solution),
                    const SizedBox(height: AppSpacing.space32),
                    _buildActionButtons(solution),
                    const SizedBox(height: AppSpacing.space32),
                  ],
                ),
              ),
            ),
            _buildBottomBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Solution solution) {
    return AppHeaderWithIcon(
      icon: Icons.check,
      title: 'Question Recognized!',
      subtitle: '${solution.topic} - ${solution.subject}',
      iconColor: AppColors.successGreen,
      iconSize: 40, // Further reduced from 48 to match photo review screen
      onClose: () => Navigator.of(context).popUntil((route) => route.isFirst),
      bottomPadding: 12, // Further reduced from 16
    );
  }

  Widget _buildQuestionCard(Solution solution) {
    // CRITICAL: Preprocess question text for proper spacing
    final processedQuestion = TextPreprocessor.addSpacesToText(solution.recognizedQuestion);
    
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
                'HERE\'S WHAT I SEE:',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Display original question image if available
          if (widget.imageFile != null) ...[
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                child: Image.file(
                  widget.imageFile!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildContentWidget(
            processedQuestion,
            solution.subject,
            ContentConfig.getQuestionTextStyle(color: AppColors.textMedium),
          ),
          const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
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
                          ],
                        ),
        ],
      ),
    );
  }

  Widget _buildSolutionSteps(Solution solution) {
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
          return _buildStepCard(entry.key + 1, entry.value);
        }),
      ],
    );
  }

  Widget _buildStepCard(int stepNumber, String stepContent) {
    // CRITICAL: Preprocess step content for proper spacing
    final processedStepContent = TextPreprocessor.preprocessStepContent(stepContent);
    
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
            _getStepTitle(stepNumber, processedStepContent),
            style: AppTextStyles.labelMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                              child: LaTeXWidget(
                text: processedStepContent,
                textStyle: ContentConfig.getStepTextStyle(color: AppColors.textMedium),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
  }

  String _getStepTitle(int number, String stepContent) {
    // Try to extract title from step content
    // Format: "Step 1: Title" or "Title: description" or just use first few words
    String content = stepContent.trim();
    
    // CRITICAL: Preprocess for spacing before extracting title
    content = TextPreprocessor.preprocessStepContent(content);
    
    // Remove LaTeX delimiters and commands for title extraction
    content = _cleanLaTeXForTitle(content);
    
    // Check if step starts with "Step N:" or "Step N -"
    final stepPattern = RegExp(r'^Step\s+\d+[:\-]\s*(.+?)(?:\.|,|$)', caseSensitive: false);
    final match = stepPattern.firstMatch(content);
    if (match != null && match.group(1) != null) {
      String title = match.group(1)!.trim();
      // Stop at first sentence or comma for cleaner title
      final sentenceEnd = title.indexOf('.');
      if (sentenceEnd > 0 && sentenceEnd < 40) {
        title = title.substring(0, sentenceEnd);
      }
      // Limit title length to avoid overflow
      if (title.length > 40) {
        title = '${title.substring(0, 37)}...';
      }
      return title;
    }
    
    // Check if step has a colon separator (e.g., "Title: description")
    final colonIndex = content.indexOf(':');
    if (colonIndex > 0 && colonIndex < 50) {
      String title = content.substring(0, colonIndex).trim();
      // Remove common prefixes
      title = title.replaceAll(RegExp(r'^(Step\s+\d+[:\-]?\s*)', caseSensitive: true), '');
      // Clean LaTeX from title
      title = _cleanLaTeXForTitle(title);
      if (title.isNotEmpty && title.length <= 40) {
        return title;
      }
    }
    
    // Fallback: use first few words (up to 5 words or 40 chars), skip LaTeX-heavy parts
    final words = content.split(RegExp(r'\s+'));
    if (words.isNotEmpty) {
      String title = '';
      int wordCount = 0;
      for (int i = 0; i < words.length && wordCount < 5 && title.length < 40; i++) {
        String word = words[i];
        // Skip words that are mostly LaTeX
        if (!word.contains('\\(') && !word.contains('\\[') && !word.contains('\\mathrm')) {
          if (title.isNotEmpty) title += ' ';
          title += word;
          wordCount++;
        }
      }
      if (title.isNotEmpty) {
        return title.length > 40 ? '${title.substring(0, 37)}...' : title;
      }
    }
    
    // Ultimate fallback
    return 'Step $number';
  }
  
  /// Clean LaTeX commands from text for use in titles
  String _cleanLaTeXForTitle(String text) {
    String cleaned = text;
    // Remove LaTeX delimiters
    cleaned = cleaned.replaceAll(RegExp(r'\\[\(\[\)\]]'), '');
    // Remove \mathrm{} and content
    cleaned = cleaned.replaceAll(RegExp(r'\\mathrm\{([^}]+)\}'), r'$1');
    // Remove subscripts/superscripts but keep content
    cleaned = cleaned.replaceAll(RegExp(r'[_\^]\{([^}]+)\}'), r'$1');
    // Remove standalone LaTeX commands
    cleaned = cleaned.replaceAll(RegExp(r'\\[a-zA-Z]+\{?[^}]*\}?'), '');
    // Clean up extra spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  Widget _buildFinalAnswer(Solution solution) {
    // CRITICAL: Preprocess final answer for proper spacing
    final processedAnswer = TextPreprocessor.addSpacesToText(solution.solution.finalAnswer);
    
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
                          processedAnswer,
                          solution.subject,
                          TextStyle(
                            fontSize: ContentConfig.finalAnswerTextSize,
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.w600,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildPriyaTip(Solution solution) {
    if (solution.solution.priyaMaamTip.isEmpty) return const SizedBox.shrink();

    // Pre-process the tip text to add spaces and ensure readability
    final tipText = TextPreprocessor.addSpacesToText(solution.solution.priyaMaamTip);

    return Container(
      padding: const EdgeInsets.all(28), // Increased padding for more space
      decoration: BoxDecoration(
        gradient: AppColors.priyaCardGradient,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PriyaAvatar(size: 56), // Larger avatar
          const SizedBox(width: 20), // More spacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Priya Ma\'am\'s Tip',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: const Color(0xFF7C3AED),
                        fontSize: 18, // Larger title
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF9333EA),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 16), // More spacing
                // Use direct Text widget for maximum readability - no LaTeX processing
                Text(
                  tipText,
                  style: TextStyle(
                    fontSize: ContentConfig.priyaTipTextSize,
                    color: const Color(0xFF4C1D95), // Darker purple for better contrast
                    height: ContentConfig.priyaTipLineHeight, // Increased line height for better readability
                    fontWeight: ContentConfig.priyaTipFontWeight,
                    letterSpacing: 0.3, // Slight letter spacing for clarity
                  ),
                  softWrap: true, // Enable text wrapping
                  overflow: TextOverflow.visible, // Allow wrapping instead of clipping
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeSection(Solution solution) {
    return Container(
      padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                width: 32,
                height: 32,
                              decoration: const BoxDecoration(
                  color: AppColors.infoBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                            ),
              const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                    Text(
                      'Practice Similar Questions',
                      style: AppTextStyles.labelMedium,
                    ),
                                  Text(
                      'Master this concept with follow-up questions',
                      style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
          const SizedBox(height: 16),
                        
          // Three difficulty boxes
                        Row(
                          children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.successBackground.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppRadius.radiusSmall),
                    border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Basic',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.successGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Q1',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.successGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
                            const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.warningBackground.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppRadius.radiusSmall),
                    border: Border.all(color: AppColors.warningAmber.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Intermediate',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.warningAmber,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Q2',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.warningAmber,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
                            const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBackground.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppRadius.radiusSmall),
                    border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Advanced',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Q3',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.errorRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Start Practice button
          Container(
                          width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.infoBlue,
              borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
              boxShadow: [
                BoxShadow(
                  color: AppColors.infoBlue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => FollowUpQuizScreen(
                                    recognizedQuestion: solution.recognizedQuestion,
                                    solution: solution.solution,
                                    topic: solution.topic,
                                    difficulty: solution.difficulty,
                                    subject: solution.subject,
                                  ),
                                ),
                              );
                            },
                borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                      const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                                    Text(
                                      'Start Practice',
                        style: AppTextStyles.labelMedium.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildActionButtons(Solution solution) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Column(
          children: [
            // Snap Another Question
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
                    if (appState.canTakeSnap) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const CameraScreen(),
                        ),
                        (route) => route.isFirst,
                      );
                    } else {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const DailyLimitScreen(),
                        ),
                        (route) => route.isFirst,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.menu_book, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          'Snap Another Question',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.white,
                            fontSize: 16,
            ),
          ),
        ],
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
                border: Border.all(color: AppColors.borderGray, width: 2),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.home, color: AppColors.textDark),
                        const SizedBox(width: 12),
            Text(
                          'Back to Dashboard',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textDark,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomBanner() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(
            gradient: AppColors.ctaGradient,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
            children: [
                const Icon(
                  Icons.track_changes,
                  color: Colors.white,
                  size: 18,
                ),
              const SizedBox(width: 8),
              Text(
                  '${appState.snapsRemaining}/${appState.snapLimit} snaps remaining today',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  /// Build content widget based on subject (ChemistryText for Chemistry, LaTeXWidget for others)
  Widget _buildContentWidget(String content, String subject, TextStyle textStyle) {
    if (subject.toLowerCase() == 'chemistry') {
      return ChemistryText(
        content,
        textStyle: textStyle,
        fontSize: textStyle.fontSize ?? 16, // Use bodyLarge size (16) as default
      );
    } else {
      return LaTeXWidget(
        text: content,
        textStyle: textStyle,
      );
    }
  }
}
