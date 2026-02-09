/// Camera Screen - Snap Your Question
/// Matches design: 4 Camera Interface Screen Redesigned.png
import 'dart:io';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'photo_review_screen.dart';
import 'image_preview_screen.dart';
import 'all_solutions_screen.dart';
import 'solution_review_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../providers/app_state_provider.dart';
import '../widgets/priya_avatar.dart';
import '../widgets/subject_icon_widget.dart';
import '../utils/text_preprocessor.dart';
import '../models/snap_data_model.dart';
import '../services/storage_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  File? _selectedImage;
  bool _isQuickTipsExpanded = false;

  Future<void> _capturePhoto() async {
    if (_isProcessing) return;

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
        _showError('Failed to capture image: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

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
        _showError('Failed to pick image: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _processImage(File imageFile) async {
    setState(() {
      _selectedImage = imageFile;
    });

    // On Android, use custom preview screen with large buttons
    // On iOS, use native ImageCropper (which has proper Cancel/Next buttons)
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    const forceCustomPreview = false;

    if (isAndroid || forceCustomPreview) {
      // Navigate to custom preview screen with large, easy-to-tap buttons
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
                setState(() {
                  _selectedImage = null;
                });
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
          IOSUiSettings(
            title: 'Crop Question',
            doneButtonTitle: 'Next',
            cancelButtonTitle: 'Cancel',
            aspectRatioLockEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) {
        setState(() {
          _selectedImage = null;
        });
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
      // Reset selected image after navigation
      setState(() {
        _selectedImage = null;
      });
    }
  }

  void _solveWithAI() {
    if (_selectedImage != null) {
      _processImage(_selectedImage!);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top section: Purple gradient header
          _buildHeader(),
          
          // Bottom section: White background with content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Capture and Gallery buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildCaptureButton(),
                          const SizedBox(height: 16),
                          _buildGalleryButton(),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Priya Ma'am Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildPriyaMaamCard(),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Solve with AI Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildSolveButton(),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Quick Tips Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildQuickTips(),
                    ),
                    
                    const SizedBox(height: 24),

                    // Recent Snaps Section
                    _buildRecentSnaps(),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom footer bar
          _buildBottomBar(),
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
                // Decorative circles
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
                // Header content
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 16), // Reduced bottom from 48 to 16
                  child: Column(
                    children: [
                      // Top row: Back button, Snap counter, Bookmark
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back button
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          
                          // Snap counter badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppRadius.radiusRound),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
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
                                const SizedBox(width: 6),
                                Text(
                                  '${appState.snapsUsed}/${appState.snapLimit} snaps',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Bookmark/History button
                          IconButton(
                            icon: const Icon(Icons.history, color: Colors.white),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const AllSolutionsScreen(),
                                ),
                              );
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12), // Reduced from 24
                      
                      // Camera icon in white circle
                      Container(
                        width: 48, // Reduced from 80
                        height: 48, // Reduced from 80
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 24, // Reduced from 40
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      
                      const SizedBox(height: 8), // Reduced from 16
                      
                      // Title
                      Text(
                        'Snap Your Question',
                        style: AppTextStyles.headerWhite.copyWith(fontSize: 20), // Consistent with other headers
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 4), // Reduced from 8
                      
                      // Subtitle
                      Text(
                        'Point your camera at any JEE question',
                        style: AppTextStyles.bodyWhite.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13, // Slightly smaller
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

  Widget _buildCaptureButton() {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        gradient: AppColors.ctaGradient,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        boxShadow: AppShadows.buttonShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isProcessing ? null : _capturePhoto,
          borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isProcessing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                else
                  const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 32,
                  ),
                const SizedBox(width: 12),
                Text(
                  'Capture',
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

  Widget _buildGalleryButton() {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: AppColors.borderGray, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isProcessing ? null : _pickFromGallery,
          borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  color: _isProcessing ? AppColors.textGray : AppColors.primaryPurple,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'Gallery',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: _isProcessing ? AppColors.textGray : AppColors.textDark,
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
          // Avatar
          PriyaAvatar(size: 48),
          const SizedBox(width: 12),
          // Text
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

  Widget _buildSolveButton() {
    final isEnabled = _selectedImage != null && !_isProcessing;
    
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: isEnabled ? AppColors.ctaGradient : null,
        color: isEnabled ? null : AppColors.borderGray,
        borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
        boxShadow: isEnabled ? AppShadows.buttonShadow : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? _solveWithAI : null,
          borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Solve with AI',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isEnabled ? Colors.white : AppColors.textGray,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  color: isEnabled ? Colors.white : AppColors.textGray,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
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

  Widget _buildRecentSnaps() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final solutions = appState.recentSolutions;
        if (solutions.isEmpty) return const SizedBox.shrink();

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
                    style: AppTextStyles.headerSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AllSolutionsScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'View All',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                itemCount: solutions.length > 5 ? 5 : solutions.length,
                itemBuilder: (context, index) {
                  return _buildRecentSnapCard(solutions[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentSnapCard(RecentSolution solution) {
    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(horizontal: 6),
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
            final storage = StorageService();
            final allSolutions = await storage.getAllSolutionsForToday();
            if (allSolutions.isEmpty) {
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
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SubjectIconWidget(subject: solution.subject, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        solution.subject,
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 12,
                          color: AppColors.textMedium,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    TextPreprocessor.addSpacesToText(solution.getPreviewText()),
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  solution.getTimeAgo(),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMedium,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.successGreen,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final remaining = appState.snapsRemaining;
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
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  appState.snapLimit == -1
                      ? 'Unlimited snaps available'
                      : '$remaining more snap${remaining != 1 ? 's' : ''} available today',
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
