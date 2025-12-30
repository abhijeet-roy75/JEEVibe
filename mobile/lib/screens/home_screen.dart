/// Home Screen - Matches design: Snap and Solve.PNG
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'camera_screen.dart';
import 'daily_limit_screen.dart';
import 'solution_review_screen.dart';
import 'all_solutions_screen.dart';
import 'photo_review_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../providers/app_state_provider.dart';
import '../widgets/app_header.dart';
import '../models/snap_data_model.dart';
import '../services/storage_service.dart';
import '../utils/text_preprocessor.dart';
import '../widgets/subject_icon_widget.dart';
import 'profile/profile_view_screen.dart';
import '../widgets/priya_avatar.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
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
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildBackToDashboardButton(),
                    ),
                    const SizedBox(height: 24),
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
            gradient: LinearGradient(
              colors: [AppColors.primaryPurple, AppColors.secondaryPink],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
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
                      color: Colors.white.withOpacity(0.1),
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
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: Back Button
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          // Middle: Centered Counter
                          Expanded(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(AppRadius.radiusRound),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${appState.snapsRemaining} remaining',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Right: Invisible Back Button for balance
                          Opacity(
                            opacity: 0,
                            child: IgnorePointer(
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () {},
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          size: 24,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Snap Your Question',
                        style: AppTextStyles.headerWhite.copyWith(fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Point your camera at any JEE question',
                        style: AppTextStyles.bodyWhite.copyWith(
                          color: Colors.white.withOpacity(0.9),
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
            color: AppColors.primaryPurple.withOpacity(0.1),
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

  Widget _buildBackToDashboardButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppColors.ctaGradient, // Using purple gradient as shown in design often
        borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
        boxShadow: AppShadows.buttonShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.home, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  'Back to Dashboard',
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
    );
  }



  Future<void> _capturePhoto() async {
    if (_isProcessing) return;
    
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (!appState.canTakeSnap) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const DailyLimitScreen(),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
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

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;
    
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (!appState.canTakeSnap) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const DailyLimitScreen(),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
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
    // Crop the image
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

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PhotoReviewScreen(
            imageFile: File(croppedFile.path),
          ),
        ),
      );
    }
  }

  Widget _buildActionButtons() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final canSnap = appState.canTakeSnap;

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
                                canSnap ? Icons.camera_alt : Icons.lock,
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

        return Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Snaps', style: AppTextStyles.headerMedium),
                  if (solutions.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AllSolutionsScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'View All',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (solutions.isEmpty)
                Container(
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
                          color: AppColors.textGray.withOpacity(0.5),
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
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    mainAxisExtent: 140, // Height of each card
                    mainAxisSpacing: 12,
                  ),
                  itemCount: solutions.length > 3 ? 3 : solutions.length,
                  itemBuilder: (context, index) => _buildSolutionCard(solutions[index]),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSolutionCard(RecentSolution solution) {
    final BuildContext context = this.context;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
        border: Border.all(color: AppColors.borderLight),
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
              children: [
                Row(
                  children: [
                    SubjectIconWidget(subject: solution.subject, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            solution.subject,
                            style: AppTextStyles.headerSmall.copyWith(fontSize: 16),
                          ),
                          Text(
                            solution.getTimeAgo(),
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textGray,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  TextPreprocessor.addSpacesToText(solution.getPreviewText()),
                  style: AppTextStyles.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Topic capsule/badge
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.cardLightPurple.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(AppRadius.radiusRound),
                          border: Border.all(
                            color: AppColors.primaryPurple.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          solution.topic,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
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
