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
import '../widgets/priya_avatar.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../providers/app_state_provider.dart';

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
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 48, 0, 32),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Close button
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ),
            ),
            
            // Checkmark icon
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: AppColors.successGreen,
                size: 32,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Question Recognized!',
              style: AppTextStyles.headerWhite.copyWith(fontSize: 24),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              '${solution.topic} - ${solution.subject}',
              style: AppTextStyles.bodyWhite.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
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
                'HERE\'S WHAT I SEE:',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LaTeXWidget(
            text: solution.recognizedQuestion,
            textStyle: AppTextStyles.bodyLarge,
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
              TextButton(
                onPressed: () {
                  // TODO: Report issue
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                children: [
                    const Icon(Icons.flag_outlined, size: 16, color: AppColors.primaryPurple),
                    const SizedBox(width: 6),
                                  Text(
                      'Report Issue',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                                ],
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
            _getStepTitle(stepNumber),
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
                              child: LaTeXWidget(
                text: stepContent,
                textStyle: AppTextStyles.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
  }

  String _getStepTitle(int number) {
    const titles = [
      'Identify the forces',
      'Calculate friction force',
      'Apply Newton\'s Second Law',
      'Solve for acceleration',
    ];
    return number <= titles.length ? titles[number - 1] : 'Step $number';
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
                        LaTeXWidget(
                          text: solution.solution.finalAnswer,
            textStyle: AppTextStyles.headerLarge.copyWith(
              color: AppColors.successGreen,
              fontSize: 28,
            ),
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
                                Text(
                                  solution.solution.priyaMaamTip,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: const Color(0xFF6B21A8),
                    height: 1.5,
                  ),
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
                  '${appState.snapsUsed}/${appState.snapLimit} snaps remaining today',
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
}
