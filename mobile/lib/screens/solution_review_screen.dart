/// Solution Review Screen - Displays stored solutions from history
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import '../models/snap_data_model.dart';
import '../models/solution_model.dart';
import '../models/ai_tutor_models.dart';
import '../widgets/latex_widget.dart';
import '../widgets/chemistry_text.dart';
import '../widgets/priya_avatar.dart';
import '../widgets/app_header.dart';
import '../widgets/buttons/gradient_button.dart';
import '../widgets/offline/offline_banner.dart';
import '../widgets/offline/cached_image_widget.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../config/content_config.dart';
import '../utils/text_preprocessor.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'home_screen.dart';
import 'ai_tutor_chat_screen.dart';
import '../services/localization_service.dart';
import '../services/subscription_service.dart';
import '../services/share_service.dart';
import '../services/firebase/auth_service.dart';
import '../widgets/shareable_solution_card.dart';
import 'package:provider/provider.dart';

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
  bool _isShareInProgress = false;
  final _screenshotController = ScreenshotController();

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
      imageUrl: recentSolution.imageUrl,
      language: recentSolution.language,
    );
  }

  Future<String> _resolveImageUrl(String url) async {
    if (url.startsWith('gs://')) {
      try {
        return await FirebaseStorage.instance.refFromURL(url).getDownloadURL();
      } catch (e) {
        debugPrint('Error resolving gs:// URL: $e');
        return url; 
      }
    }
    return url;
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
            const OfflineBanner(),
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.space24,
                  AppSpacing.space24,
                  AppSpacing.space24,
                  AppSpacing.space24 + MediaQuery.of(context).viewPadding.bottom,
                ),
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
      leadingIcon: Icons.arrow_back,
      icon: Icons.auto_awesome,
      title: 'Snap Solution',
      subtitle: '${_currentSolution.topic} • ${_currentSolution.subject}',
      iconColor: AppColors.primaryPurple,
      iconSize: 48,
      onClose: () {
        bool found = false;
        Navigator.of(context).popUntil((route) {
          if (route.settings.name == '/snap_home') {
            found = true;
            return true;
          }
          return route.isFirst;
        });

        if (!found) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => HomeScreen(),
              settings: const RouteSettings(name: '/snap_home'),
            ),
          );
        }
      },
      trailing: IconButton(
        icon: Icon(
          Icons.share,
          color: _isShareInProgress ? Colors.white.withValues(alpha: 0.5) : Colors.white,
        ),
        tooltip: 'Share on WhatsApp',
        onPressed: _isShareInProgress ? null : _handleShare,
      ),
      gradient: AppColors.ctaGradient,
    );
  }

  Future<void> _handleShare() async {
    if (_isShareInProgress) return;

    setState(() => _isShareInProgress = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getIdToken();

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to share')),
          );
        }
        return;
      }

      final solution = _reconstructSolution(_currentSolution);

      // Capture screenshot of the shareable card widget
      final imageBytes = await _screenshotController.captureFromWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Material(
            color: Colors.transparent,
            child: ShareableSolutionCard(
              question: solution.recognizedQuestion,
              steps: solution.solution.steps,
              finalAnswer: solution.solution.finalAnswer,
              subject: solution.subject,
              topic: solution.topic,
            ),
          ),
        ),
        pixelRatio: 3.0, // High quality image
        delay: const Duration(milliseconds: 100),
      );

      if (imageBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not capture solution image')),
          );
        }
        return;
      }

      // Get share button position for iPad popover (top-right of screen)
      final screenSize = MediaQuery.of(context).size;
      final shareButtonRect = Rect.fromLTWH(
        screenSize.width - 60, // 60px from right edge
        60, // 60px from top
        48, // button width
        48, // button height
      );

      final success = await ShareService.shareSolutionAsImage(
        authToken: token,
        solutionId: _currentSolution.id,
        imageBytes: imageBytes,
        subject: solution.subject,
        topic: solution.topic,
        sharePositionOrigin: shareButtonRect,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open share dialog')),
        );
      }
    } finally {
      // Re-enable after 2 seconds to prevent rapid taps
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _isShareInProgress = false);
    }
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
                LocalizationService.getString('see_header', solution.language ?? 'en'),
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          // Display question image if available (from URL)
          if (solution.imageUrl != null) ...[
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: CachedImageWidget(
                imageUrl: solution.imageUrl,
                fit: BoxFit.contain,
                borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                height: 200,
              ),
            ),
            const SizedBox(height: 16),
          ],
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
            Text(
              LocalizationService.getString('solution_header', solution.language ?? 'en'), 
              style: AppTextStyles.headerMedium
            ),
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
                        TextPreprocessor.preprocessStepContent(stepContent),
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
        color: AppColors.successBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.successGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                LocalizationService.getString('final_answer', solution.language ?? 'en'),
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

    final subscriptionService = SubscriptionService();
    final hasAiTutorAccess = subscriptionService.status?.limits.aiTutorEnabled ?? false;

    return GestureDetector(
      onTap: hasAiTutorAccess ? () {
        final recentSolution = _currentSolution;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AiTutorChatScreen(
              injectContext: TutorContext(
                type: TutorContextType.solution,
                id: recentSolution.id,
                title: '${recentSolution.topic} - ${recentSolution.subject}',
              ),
            ),
          ),
        );
      } : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.priyaCardGradient,
          borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
          border: Border.all(color: const Color(0xFFE9D5FF), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                            LocalizationService.getString('priya_tip', solution.language ?? 'en'),
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
                          color: const Color(0xFF4C1D95),
                        ),
                        allowWrapping: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // "Ask Priya Ma'am" action integrated into the card (Ultra tier only)
            if (hasAiTutorAccess) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                  border: Border.all(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      color: const Color(0xFF7C3AED),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ask Priya Ma\'am about this',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: const Color(0xFF7C3AED),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: const Color(0xFF7C3AED),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
        // Back to Snap and Solve
        GradientButton(
          text: LocalizationService.getString('back_to_snap', _reconstructSolution(_currentSolution).language ?? 'en'),
          onPressed: () {
            bool found = false;
            Navigator.of(context).popUntil((route) {
              if (route.settings.name == '/snap_home') {
                found = true;
                return true;
              }
              return route.isFirst;
            });

            if (!found) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => HomeScreen(),
                  settings: const RouteSettings(name: '/snap_home'),
                ),
              );
            }
          },
          size: GradientButtonSize.large,
          leadingIcon: Icons.camera_alt,
        ),
      ],
    );
  }
}

