/// Solution Screen - Matches design: 9 Solution Screen.png
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import '../models/solution_model.dart';
import '../models/snap_data_model.dart';
import 'followup_quiz_screen.dart';
import 'ocr_failed_screen.dart';
import 'processing_screen.dart';
import 'snap_home_screen.dart';
import '../widgets/latex_widget.dart';
import '../widgets/priya_avatar.dart';
import '../widgets/app_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/localization_service.dart';
import '../providers/app_state_provider.dart';
import '../config/content_config.dart';
import '../utils/text_preprocessor.dart';
import '../providers/offline_provider_conditional.dart';
import '../services/offline/sync_service_stub.dart'
    if (dart.library.io) '../services/offline/sync_service.dart';
import '../models/ai_tutor_models.dart';
import 'ai_tutor_chat_screen.dart';
import '../services/subscription_service.dart';
import '../services/share_service.dart';
import '../services/firebase/auth_service.dart';
import '../widgets/shareable_solution_card.dart';

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
  bool _isShareInProgress = false;
  final _screenshotController = ScreenshotController();

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
      final offlineProvider = Provider.of<OfflineProvider>(context, listen: false);
      
      final questionId = solution.id ?? 'snap_${DateTime.now().millisecondsSinceEpoch}';
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
        imageUrl: solution.imageUrl,
        language: solution.language,
      );
      
      await appState.addRecentSolution(recentSolution);

      // Automatically cache solution for offline access if user has Pro/Ultra tier
      if (offlineProvider.offlineEnabled && offlineProvider.currentUserId != null) {
        try {
          final syncService = SyncService();
          await syncService.cacheSolution(
            solution: recentSolution,
            userId: offlineProvider.currentUserId!,
            imageUrl: solution.imageUrl,
          );
          // Refresh counts will happen automatically via provider
        } catch (e) {
          debugPrint('Error caching solution for offline access: $e');
          // Don't fail the whole operation if caching fails
        }
      }
    } catch (e) {
      debugPrint('Error incrementing snap/saving solution: $e');
    }
  }

  Widget _buildErrorState(String error) {
    final errorLower = error.toLowerCase();

    // Check for OCR errors
    final isOCRError = errorLower.contains('recognize') ||
        errorLower.contains('ocr') ||
        errorLower.contains('could not read') ||
        errorLower.contains('unclear');

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

    // Parse error message for user-friendly display
    String errorTitle;
    String? errorSuggestion;
    IconData errorIcon = Icons.error_outline;

    if (errorLower.contains('timeout') || errorLower.contains('timed out')) {
      errorTitle = 'Request Timed Out';
      errorSuggestion = 'This question is taking longer than usual. Try:\n• Taking a clearer photo\n• Ensuring good lighting\n• Trying a simpler question first';
      errorIcon = Icons.timer_off_outlined;
    } else if (errorLower.contains('no internet') || errorLower.contains('network')) {
      errorTitle = 'Network Error';
      errorSuggestion = 'Please check your internet connection and try again.';
      errorIcon = Icons.wifi_off_outlined;
    } else if (errorLower.contains('too many requests')) {
      errorTitle = 'Too Many Requests';
      errorSuggestion = 'Please wait a moment before trying again.';
      errorIcon = Icons.speed_outlined;
    } else if (errorLower.contains('authentication') || errorLower.contains('sign in')) {
      errorTitle = 'Authentication Error';
      errorSuggestion = 'Please sign in again.';
      errorIcon = Icons.lock_outline;
    } else if (errorLower.contains('internal server error') || errorLower.contains('500')) {
      errorTitle = 'Server Error';
      errorSuggestion = 'Our servers are experiencing issues. Please try again in a few moments.';
      errorIcon = Icons.cloud_off_outlined;
    } else {
      errorTitle = 'Something Went Wrong';
      errorSuggestion = 'Please try again. If the problem persists, try taking a clearer photo.';
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Header with back button
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Error icon
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            errorIcon,
                            size: 64,
                            color: AppColors.errorRed,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Error title
                        Text(
                          errorTitle,
                          style: AppTextStyles.headerLarge.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // Error suggestion
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardWhite,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.borderGray,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              errorSuggestion,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textMedium,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 24),
                        // Retry button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: AppColors.ctaGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryPurple.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Try Again',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                    SizedBox(height: AppSpacing.space24),
                    _buildQuestionCard(solution),
                    SizedBox(height: AppSpacing.space32),
                    _buildSolutionSteps(solution),
                    SizedBox(height: AppSpacing.space24),
                    _buildFinalAnswer(solution),
                    SizedBox(height: AppSpacing.space24),
                    _buildPriyaTip(solution),
                    SizedBox(height: AppSpacing.space32),
                    // Practice section for Pro/Ultra users only
                    if (SubscriptionService().isPro || SubscriptionService().isUltra) ...[
                      _buildPracticeSection(solution),
                      SizedBox(height: AppSpacing.space32),
                    ],
                    _buildActionButtons(solution),
                    SizedBox(height: AppSpacing.space32),
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
    final lang = solution.language ?? 'en';
    return AppHeaderWithIcon(
      icon: Icons.check,
      title: LocalizationService.getString('recognized_title', lang),
      subtitle: '${solution.topic} - ${solution.subject}',
      iconColor: AppColors.successGreen,
      iconSize: 40, // Further reduced from 48 to match photo review screen
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
              builder: (context) => const SnapHomeScreen(),
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
        onPressed: _isShareInProgress ? null : () => _handleShare(solution),
      ),
      bottomPadding: 12, // Further reduced from 16
      gradient: AppColors.ctaGradient,
    );
  }

  Future<void> _handleShare(Solution solution) async {
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
        solutionId: solution.id ?? 'snap_${DateTime.now().millisecondsSinceEpoch}',
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
    // Only preprocess question text if we need to show it (when no image)
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
                LocalizationService.getString('see_header', solution.language ?? 'en'),
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
            // When image is shown, no need to show extracted text (it's redundant and truncates options)
          ] else ...[
            // Only show extracted text when there's no image
            _buildContentWidget(
              processedQuestion,
              solution.subject,
              ContentConfig.getQuestionTextStyle(color: AppColors.textMedium),
            ),
          ],
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
            Text(
              LocalizationService.getString('solution_header', solution.language ?? 'en'), 
              style: AppTextStyles.headerMedium
            ),
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
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
                        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                allowWrapping: true, // Enable wrapping to prevent horizontal scroll
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
  /// Converts LaTeX to plain text/Unicode for readable headers
  String _cleanLaTeXForTitle(String text) {
    String cleaned = text;

    // Remove LaTeX delimiters \( \) \[ \]
    cleaned = cleaned.replaceAll(RegExp(r'\\[\(\)\[\]]'), '');

    // Convert common LaTeX symbols to Unicode
    final latexToUnicode = {
      r'\neq': '≠',
      r'\leq': '≤',
      r'\geq': '≥',
      r'\pm': '±',
      r'\times': '×',
      r'\div': '÷',
      r'\infty': '∞',
      r'\alpha': 'α',
      r'\beta': 'β',
      r'\gamma': 'γ',
      r'\delta': 'δ',
      r'\theta': 'θ',
      r'\lambda': 'λ',
      r'\mu': 'μ',
      r'\pi': 'π',
      r'\sigma': 'σ',
      r'\omega': 'ω',
      r'\Delta': 'Δ',
      r'\Sigma': 'Σ',
      r'\Omega': 'Ω',
      r'\sqrt': '√',
      r'\rightarrow': '→',
      r'\leftarrow': '←',
      r'\Rightarrow': '⇒',
      r'\approx': '≈',
      r'\degree': '°',
      r'\circ': '°',
    };

    for (final entry in latexToUnicode.entries) {
      cleaned = cleaned.replaceAll(entry.key, entry.value);
    }

    // Remove \mathrm{} but keep content
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\\mathrm\{([^}]+)\}'),
      (match) => match.group(1) ?? '',
    );

    // Remove \text{} but keep content
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\\text\{([^}]+)\}'),
      (match) => match.group(1) ?? '',
    );

    // Convert \frac{a}{b} to a/b
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'),
      (match) => '${match.group(1)}/${match.group(2)}',
    );

    // Remove subscripts/superscripts but keep content
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'[_\^]\{([^}]+)\}'),
      (match) => match.group(1) ?? '',
    );

    // Handle subscripts/superscripts without braces (e.g., _2, ^3)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'[_\^](\d)'),
      (match) => match.group(1) ?? '',
    );

    // Remove any remaining LaTeX commands
    cleaned = cleaned.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');

    // Remove leftover braces
    cleaned = cleaned.replaceAll(RegExp(r'[{}]'), '');

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
                          processedAnswer,
                          solution.subject,
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

    // Pre-process the tip text to add spaces and ensure readability
    final tipText = TextPreprocessor.addSpacesToText(solution.solution.priyaMaamTip);

    // Check if user has AI Tutor access (Ultra tier)
    final subscriptionService = SubscriptionService();
    final hasAiTutorAccess = subscriptionService.status?.limits.aiTutorEnabled ?? false;

    return GestureDetector(
      onTap: hasAiTutorAccess ? () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AiTutorChatScreen(
              injectContext: TutorContext(
                type: TutorContextType.solution,
                id: solution.id ?? 'snap_${DateTime.now().millisecondsSinceEpoch}',
                title: '${solution.topic} - ${solution.subject}',
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
            // Header row with avatar and title
            Row(
              children: [
                const PriyaAvatar(size: 40),
                const SizedBox(width: 12),
                Text(
                  LocalizationService.getString('priya_tip', solution.language ?? 'en'),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: const Color(0xFF7C3AED),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF9333EA),
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Tip content - full width, uses LaTeXWidget for proper rendering
            LaTeXWidget(
              text: tipText,
              textStyle: const TextStyle(
                fontSize: 15,
                color: Color(0xFF4C1D95),
                height: 1.6,
                fontWeight: FontWeight.w400, // Regular weight, not bold
              ),
            ),
            // "Ask Priya Ma'am about this" action (Ultra tier only)
            if (hasAiTutorAccess) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: Color(0xFF7C3AED),
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
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFF7C3AED),
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
                    color: AppColors.successBackground.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.radiusSmall),
                    border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
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
                    color: AppColors.warningBackground.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.radiusSmall),
                    border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.3)),
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
                    color: AppColors.errorBackground.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.radiusSmall),
                    border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
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
                  color: AppColors.infoBlue.withValues(alpha: 0.3),
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
                                    language: solution.language ?? 'en',
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
            // Back to Snap and Solve - Single button since both buttons went to same destination
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
                    // Navigate back to HomeScreen
                    // HomeScreen enforces quota (camera/gallery buttons disabled when exhausted)
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
                          builder: (context) => const SnapHomeScreen(),
                          settings: const RouteSettings(name: '/snap_home'),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Back to Snap and Solve',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
                  appState.snapLimit == -1
                      ? 'Unlimited snaps'
                      : '${appState.snapsRemaining}/${appState.snapLimit} snaps remaining today',
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
  Widget _buildContentWidget(String content, String subject, TextStyle textStyle, {bool allowWrapping = false}) {
    // Always use LaTeXWidget to handle both simple text and complex formulas (math/chemistry)
    return LaTeXWidget(
      text: content,
      textStyle: textStyle,
      allowWrapping: allowWrapping,
    );
  }
}
