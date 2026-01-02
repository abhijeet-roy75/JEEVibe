/// Processing Screen - Matches design: 8 Processing and Loading.png
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_header.dart';
import '../widgets/priya_avatar.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> with TickerProviderStateMixin {
  late AnimationController _dotsController;
  late AnimationController _progressController;
  int _currentStep = 3; // Currently on step 3 (out of 4 total)
  final int _totalSteps = 4;

  @override
  void initState() {
    super.initState();
    
    // Animated dots for loading
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    // Progress bar animation - animate to current step progress (3/4 = 75%)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _progressController.animateTo(_currentStep / _totalSteps); // 3/4 = 0.75 (75%)
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.space24),
                    _buildPriyaCard(),
                    const SizedBox(height: AppSpacing.space24),
                    _buildDidYouKnow(),
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

  Widget _buildHeader() {
    return AppHeader(
      centerContent: Container(
        width: 40, // Further reduced to match other screens
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.auto_awesome,
          color: AppColors.primaryPurple,
          size: 20, // Further reduced
        ),
      ),
      title: Text(
        'Hold Tight!',
        style: AppTextStyles.headerWhite.copyWith(fontSize: 18), // Reduced from 20
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              'Priya Ma\'am is working on your solution',
              style: AppTextStyles.subtitleWhite.copyWith(fontSize: 13), // Reduced from 15
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          _buildAnimatedDots(),
        ],
      ),
      topPadding: 20, // Reduced from default 24 to match photo review screen
      bottomPadding: 12, // Reduced from default 16 to match photo review screen
    );
  }

  Widget _buildAnimatedDots() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, child) {
        final progress = _dotsController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final opacity = (progress * 3 - index).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildPriyaCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.cardShadowElevated,
      ),
      child: Column(
        children: [
          // Priya avatar with decorative elements
          Stack(
            alignment: Alignment.center,
            children: [
              // Decorative sparkles
              const Positioned(
                top: 0,
                left: 40,
                child: Icon(Icons.auto_awesome, color: AppColors.warningAmber, size: 20),
              ),
              const Positioned(
                bottom: 0,
                right: 40,
                child: Icon(Icons.auto_awesome, color: AppColors.secondaryPink, size: 16),
              ),
              const Positioned(
                bottom: 10,
                right: 80,
                child: Icon(Icons.auto_awesome, color: AppColors.primaryPurple, size: 14),
              ),
              
              // Avatar
              PriyaAvatar(size: 80, showShadow: true),
            ],
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Priya Ma\'am is solving this...',
            style: AppTextStyles.headerMedium,
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 20),
          
          // Status box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardLightPurple.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryPurple,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Writing step-by-step explanation...',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'This usually takes 5-10 seconds',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textLight,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: AppTextStyles.labelSmall,
                  ),
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) {
                      final percentage = (_progressController.value * 100).toInt();
                      return Text(
                        '$percentage%',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  return Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progressController.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.ctaGradient,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Checklist
          _buildChecklistItem(1, 'Reading your question...', true),
          const SizedBox(height: 12),
          _buildChecklistItem(2, 'Identifying the concept...', true),
          const SizedBox(height: 12),
          _buildChecklistItem(3, 'Thinking through the solution...', true),
          const SizedBox(height: 12),
          _buildChecklistItem(4, 'Writing step-by-step explanation...', false, isNext: true),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(int number, String text, bool isComplete, {bool isNext = false}) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isComplete 
                ? AppColors.successGreen 
                : (isNext ? AppColors.primaryPurple : AppColors.borderGray),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isComplete
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : isNext
                    ? _buildAnimatedDots()
                    : Text(
                        '$number',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isComplete ? AppColors.textMedium : AppColors.textLight,
              decoration: isComplete ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.textLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDidYouKnow() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.infoBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: AppColors.infoBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.infoBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Did you know?',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.infoBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The average JEE Main question can be solved in 90 seconds. Priya Ma\'am breaks them down so you can master the concept!',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMedium,
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

  Widget _buildBottomBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        gradient: AppColors.ctaGradient,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Almost there! Preparing your solution...',
              style: AppTextStyles.labelMedium.copyWith(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

