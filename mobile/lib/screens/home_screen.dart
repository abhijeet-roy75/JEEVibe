/// Home Screen - Matches design: Snap and Solve.PNG
import 'dart:io';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'image_preview_screen.dart';
import 'daily_limit_screen.dart';
import 'solution_review_screen.dart';
import 'all_solutions_screen.dart';
import 'photo_review_screen.dart';
import 'subscription/paywall_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../providers/app_state_provider.dart';
import '../providers/offline_provider.dart';
import '../widgets/buttons/gradient_button.dart';
import '../widgets/buttons/icon_button.dart';
import '../widgets/offline/offline_banner.dart';
import '../widgets/trial_banner.dart';
import '../models/snap_data_model.dart';
import '../models/subscription_models.dart';
import '../services/storage_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/subscription_service.dart';
import '../utils/text_preprocessor.dart';
import '../widgets/subject_icon_widget.dart';
import '../widgets/priya_avatar.dart';
import 'main_navigation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _resetCountdown = '';
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  bool _isQuickTipsExpanded = false;

  @override
  void initState() {
    super.initState();
    _checkAndReset();
    _updateCountdown();
  }

  Future<void> _checkAndReset() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    await appState.checkAndResetIfNeeded();
  }

  Future<void> _updateCountdown() async {
    if (!mounted) return;
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final countdown = await appState.getResetCountdownText();
    if (mounted) {
      setState(() {
        _resetCountdown = countdown;
      });
    }
  }

  void _showOfflineMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'You\'re offline. Snap & Solve requires an internet connection.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.textMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('HomeScreen: build() called');
    return Scaffold(
      body: Column(
        children: [
          // Offline banner at the very top
          const OfflineBanner(),
          // Trial banner (shows when trial is active and urgent)
          const TrialBanner(),
          _buildHeader(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildPriyaMaamCard(),
                    ),
                    const SizedBox(height: 24),
                    _buildRecentSolutions(),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildQuickTips(),
                    ),
                    // Add extra padding for Android system navigation bar
                    SizedBox(height: 24 + MediaQuery.of(context).viewPadding.bottom),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: AppColors.ctaGradient,
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned(
                  top: -64,
                  right: -64,
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -48,
                  left: -48,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      // Top row: Back button | Title with icon | Remaining counter
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left: Back Button
                          AppIconButton.back(
                            forGradientHeader: true,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 12),
                          // Center: Icon + Title
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 18,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Snap Your Question',
                                  style: AppTextStyles.headerWhite.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Right: Remaining counter
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  appState.snapLimit == -1
                                      ? '∞'
                                      : '${appState.snapsRemaining}',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Subtitle
                      Text(
                        'Point your camera at any JEE question',
                        style: AppTextStyles.bodyWhite.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriyaMaamCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.priyaCardGradient,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(
          color: const Color(0xFFE9D5FF),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PriyaAvatar(size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Priya Ma\'am',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.auto_awesome,
                      color: AppColors.primaryPurple,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'I\'m ready to help! Just snap a clear photo of your question, and I\'ll solve it step-by-step for you. 📚',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF6B21A8),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTips() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isQuickTipsExpanded = !_isQuickTipsExpanded;
              });
            },
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.warningAmber,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Quick Tips for Best Results',
                    style: AppTextStyles.headerSmall,
                  ),
                ),
                AnimatedRotation(
                  turns: _isQuickTipsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          if (_isQuickTipsExpanded) ...[
            const SizedBox(height: 20),
            _buildTipItem('💡', 'Good Lighting', 'Ensure the question is well-lit, no shadows'),
            const SizedBox(height: 16),
            _buildTipItem('📐', 'Frame Completely', 'Include the entire question in the frame'),
            const SizedBox(height: 16),
            _buildTipItem('📱', 'Hold Steady', 'Keep your phone still to avoid blurry photos'),
            const SizedBox(height: 16),
            _buildTipItem('✍️', 'Clear Text', 'Works with printed and neat handwriting'),
          ],
        ],
      ),
    );
  }

  Widget _buildTipItem(String emoji, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }




  Future<void> _capturePhoto() async {
    if (_isProcessing) return;

    // Check offline status first
    final offlineProvider = Provider.of<OfflineProvider>(context, listen: false);
    if (offlineProvider.isOffline) {
      _showOfflineMessage();
      return;
    }

    // Check subscription-based snap limit
    final canProceed = await _checkSnapAccess();
    if (!canProceed) return;

    setState(() => _isProcessing = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture image: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Check if user can use Snap & Solve based on subscription
  Future<bool> _checkSnapAccess() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getIdToken();

    if (token != null) {
      final subscriptionService = SubscriptionService();
      final canProceed = await subscriptionService.gatekeepFeature(
        context,
        UsageType.snapSolve,
        'Snap & Solve',
        token,
      );

      if (!canProceed) {
        // Paywall was shown
        return false;
      }
    }

    // Also check local state as fallback
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (!appState.canTakeSnap) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const DailyLimitScreen(),
          ),
        );
      }
      return false;
    }

    return true;
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    // Check offline status first
    final offlineProvider = Provider.of<OfflineProvider>(context, listen: false);
    if (offlineProvider.isOffline) {
      _showOfflineMessage();
      return;
    }

    // Check subscription-based snap limit
    final canProceed = await _checkSnapAccess();
    if (!canProceed) return;

    setState(() => _isProcessing = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _processImage(File imageFile) async {
    // On Android, use custom preview screen with large buttons
    // On iOS, use native ImageCropper (which has proper Cancel/Next buttons)
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    const forceCustomPreview = false;

    if (isAndroid || forceCustomPreview) {
      // Use custom preview screen with large, easy-to-tap buttons
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ImagePreviewScreen(
              imageFile: imageFile,
              onConfirm: (File finalImage) {
                Navigator.of(context).pop(); // Pop preview screen
                _navigateToPhotoReview(finalImage);
              },
              onCancel: () {
                Navigator.of(context).pop(); // Pop preview screen
              },
            ),
          ),
        );
      }
    } else {
      // iOS: Use native ImageCropper (has proper text buttons)
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Question',
            toolbarColor: AppColors.primaryPurple,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Question',
            doneButtonTitle: 'Next',
            cancelButtonTitle: 'Cancel',
            aspectRatioLockEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) {
        return;
      }

      _navigateToPhotoReview(File(croppedFile.path));
    }
  }

  void _navigateToPhotoReview(File imageFile) {
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PhotoReviewScreen(
            imageFile: imageFile,
          ),
        ),
      );
    }
  }

  Widget _buildActionButtons() {
    return Consumer2<AppStateProvider, OfflineProvider>(
      builder: (context, appState, offlineProvider, child) {
        final isOffline = offlineProvider.isOffline;
        final canSnap = appState.canTakeSnap && !isOffline;

        return Padding(
          padding: AppSpacing.screenPadding,
          child: Row(
            children: [
              // Capture Button
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: canSnap ? AppColors.ctaGradient : null,
                    color: canSnap ? null : AppColors.borderGray,
                    borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                    boxShadow: canSnap ? AppShadows.buttonShadow : [],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isProcessing ? null : (canSnap ? _capturePhoto : null),
                      borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isProcessing)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Icon(
                                isOffline
                                    ? Icons.cloud_off
                                    : (canSnap ? Icons.camera_alt : Icons.lock),
                                color: canSnap ? Colors.white : AppColors.textGray,
                                size: 20,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              'Capture',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: canSnap ? Colors.white : AppColors.textGray,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Gallery Button
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                    border: Border.all(
                      color: canSnap ? AppColors.primaryPurple : AppColors.borderGray,
                      width: 2,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isProcessing ? null : (canSnap ? _pickFromGallery : null),
                      borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              color: canSnap ? AppColors.primaryPurple : AppColors.textGray,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Gallery',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: canSnap ? AppColors.textDark : AppColors.textGray,
                                fontSize: 15,
                              ),
                            ),
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
      },
    );
  }


  Widget _buildRecentSolutions() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final solutions = appState.recentSolutions;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Snaps',
                    style: AppTextStyles.headerSmall,
                  ),
                  if (solutions.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                         Navigator.of(context).push(
                           MaterialPageRoute(
                             builder: (context) => const AllSolutionsScreen(),
                           ),
                         );
                      },
                      child: Text(
                        'View All',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            if (solutions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: AppColors.textGray.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No solutions yet',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Snap your first question to get started!',
                          style: AppTextStyles.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 190, // Fixed height for horizontal list
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  scrollDirection: Axis.horizontal,
                  itemCount: solutions.length > 5 ? 5 : solutions.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    return _buildSolutionCard(solutions[index]);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSolutionCard(RecentSolution solution) {
    final BuildContext context = this.context;
    return Container(
      width: 260, // Fixed width for horizontal card
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // Get all solutions for today to enable navigation
            final storage = StorageService();
            final allSolutions = await storage.getAllSolutionsForToday();
            if (allSolutions.isEmpty) {
              // Fallback: use recent solutions if today's list is empty
              final appState = Provider.of<AppStateProvider>(context, listen: false);
              final recentSolutions = appState.recentSolutions;
              if (recentSolutions.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SolutionReviewScreen(
                      allSolutions: recentSolutions,
                      initialIndex: recentSolutions.indexOf(solution),
                    ),
                  ),
                );
              }
            } else {
              final index = allSolutions.indexWhere((s) => s.id == solution.id);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SolutionReviewScreen(
                    allSolutions: allSolutions,
                    initialIndex: index >= 0 ? index : 0,
                  ),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Shrink wrap vertically
              children: [
                Row(
                  children: [
                    SubjectIconWidget(subject: solution.subject, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            solution.subject,
                            style: AppTextStyles.labelMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            solution.getTimeAgo(),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textLight,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Text(
                    TextPreprocessor.addSpacesToText(solution.getPreviewText()),
                    style: AppTextStyles.bodyMedium.copyWith(
                      height: 1.4,
                      fontSize: 13,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: SubjectIconWidget.getColor(solution.subject).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: SubjectIconWidget.getColor(solution.subject).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          solution.topic.isNotEmpty ? solution.topic : 'General',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: SubjectIconWidget.getColor(solution.subject),
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
