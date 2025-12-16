/// Welcome Screen - 3-slide onboarding carousel
/// Matches designs: 2a, 2b, 2c Welcome Screen.png
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/storage_service.dart';
import 'assessment_intro_screen.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const WelcomeScreen({super.key, this.onComplete});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // For step 2: Shuffling cards
  late List<String> _shufflingMessages;
  int _currentMessageIndex = 0;
  Timer? _shuffleTimer;
  
  // For step 3: Snap & Solve card animation
  late AnimationController _snapCardController;
  late Animation<double> _snapCardScale;
  late Animation<double> _snapCardRotation;

  @override
  void initState() {
    super.initState();
    
    // Initialize shuffling messages for step 2
    _shufflingMessages = [
      'Focus on what matters most',
      'Practice smarter, not harder',
      'Adaptive learning for you',
      'Track your progress daily',
    ];
    
    // Initialize animation controller for step 3
    _snapCardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _snapCardScale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _snapCardController,
        curve: Curves.easeInOut,
      ),
    );
    
    _snapCardRotation = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(
        parent: _snapCardController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Start shuffling animation when on step 2
    _startShuffling();
    
    // Start snap card animation when on step 3
    _startSnapCardAnimation();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _shuffleTimer?.cancel();
    _snapCardController.dispose();
    super.dispose();
  }
  
  void _startShuffling() {
    _shuffleTimer?.cancel();
    _shuffleTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _currentPage == 1) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % _shufflingMessages.length;
        });
      }
    });
  }
  
  void _startSnapCardAnimation() {
    _snapCardController.repeat(reverse: true);
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    
    // Start/stop animations based on current page
    if (page == 1) {
      _startShuffling();
    } else {
      _shuffleTimer?.cancel();
    }
    
    if (page == 2) {
      _snapCardController.repeat(reverse: true);
    } else {
      _snapCardController.stop();
      _snapCardController.reset();
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _handleComplete();
    }
  }

  void _skipToEnd() {
    _handleComplete();
  }

  Future<void> _handleComplete() async {
    // If custom callback is provided, use it
    if (widget.onComplete != null) {
      widget.onComplete!();
      return;
    }
    
    // Default behavior: mark as seen and navigate to assessment intro (new home)
    final storageService = StorageService();
    await storageService.setHasSeenWelcome(true);
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AssessmentIntroScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [
          _buildSlide1(), // Initial Assessment
          _buildSlide2(), // Snap & Solve (moved from slide 1)
          _buildSlide3(), // Adaptive Learning
        ],
      ),
    );
  }

  // Slide 1: Priya Ma'am Introduction
  Widget _buildSlide1() {
    return SafeArea(
      child: SizedBox.expand(
        child: Stack(
          children: [
            // Skip button
            Positioned(
              top: 16,
              right: 16,
              child: TextButton(
                onPressed: _skipToEnd,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Skip',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ),
            // Main content
            Column(
              children: [
                const Spacer(flex: 2),
                // Large circular graphic with gradient
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.ctaGradient,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/priya_maam.jpeg',
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to emoji if image fails to load
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: AppColors.ctaGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              '👩‍🏫',
                              style: TextStyle(fontSize: 80),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Main Heading
                Text(
                  'Hey! I\'m Priya Ma\'am',
                  style: AppTextStyles.headerLarge.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Body text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Your JEE journey just got a whole lot smarter. I\'ll help you practice what matters most.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 16,
                      color: AppColors.textMedium,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                // Highlighted text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Ready to focus on what actually moves your percentile?',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 16,
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(flex: 3),
                // Page indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDot(0, onWhiteBackground: true),
                    const SizedBox(width: 8),
                    _buildDot(1, onWhiteBackground: true),
                    const SizedBox(width: 8),
                    _buildDot(2, onWhiteBackground: true),
                  ],
                ),
                const SizedBox(height: 24),
                // Next Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.ctaGradient,
                      borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
                      boxShadow: AppShadows.buttonShadow,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _nextPage,
                        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Next',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Slide 2: Adaptive Learning
  Widget _buildSlide2() {
    return SafeArea(
      child: SizedBox.expand(
        child: Stack(
          children: [
            // Skip button
            Positioned(
              top: 16,
              right: 16,
              child: TextButton(
                onPressed: _skipToEnd,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Skip',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ),
            // Main content
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    // Animated shuffling cards
                    SizedBox(
                      height: 200,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.3),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            )),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: _buildShufflingCard(
                          key: ValueKey<int>(_currentMessageIndex),
                          message: _shufflingMessages[_currentMessageIndex],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // AI adapting badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: AppColors.ctaGradient,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            'AI',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text('✨', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            'adapting to you',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Main Heading
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: AppTextStyles.headerLarge.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                        children: [
                          const TextSpan(text: 'Practice What '),
                          TextSpan(
                            text: 'YOU',
                            style: TextStyle(color: AppColors.secondaryPink),
                          ),
                          const TextSpan(text: ' Need'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Three bullet points
                    _buildAdaptiveFeature(
                      icon: Icons.gps_fixed,
                      title: 'Adapts to your level',
                      description: 'Questions get easier or harder based on your performance',
                    ),
                    const SizedBox(height: 24),
                    _buildAdaptiveFeature(
                      icon: Icons.search,
                      title: 'Focuses on weak topics',
                      description: 'Spend more time where you need it most',
                    ),
                    const SizedBox(height: 24),
                    _buildAdaptiveFeature(
                      icon: Icons.timer,
                      title: 'Just 15 minutes daily',
                      description: 'Short, focused practice that fits your schedule',
                    ),
                    const SizedBox(height: 40),
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildDot(0, onWhiteBackground: true),
                        const SizedBox(width: 8),
                        _buildDot(1, onWhiteBackground: true),
                        const SizedBox(width: 8),
                        _buildDot(2, onWhiteBackground: true),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Next Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppColors.ctaGradient,
                        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
                        boxShadow: AppShadows.buttonShadow,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _nextPage,
                          borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Next',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShufflingCard({required String message, Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.ctaGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lightbulb_outline,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.headerLarge.copyWith(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptiveFeature({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.primaryPurple,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Slide 3: Features Summary
  Widget _buildSlide3() {
    return SafeArea(
      child: SizedBox.expand(
        child: Stack(
          children: [
            // Skip button
            Positioned(
              top: 16,
              right: 16,
              child: TextButton(
                onPressed: _skipToEnd,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Skip',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
            // Main content
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    // Two feature cards at top
                    Row(
                      children: [
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _snapCardController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _snapCardScale.value,
                                child: Transform.rotate(
                                  angle: _snapCardRotation.value,
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.ctaGradient,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryPurple.withOpacity(0.4),
                                          blurRadius: 15,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Snap & Solve',
                                          style: AppTextStyles.labelMedium.copyWith(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Instant solutions',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: Colors.white.withOpacity(0.9),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.trending_up,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Track Progress',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'See growth daily',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    // Main Heading
                    Text(
                      'Everything You Need\nto Succeed',
                      style: AppTextStyles.headerLarge.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // Three feature cards
                    _buildFeatureCard(
                      icon: Icons.camera_alt,
                      title: 'Stuck? Just snap it',
                      description: 'Instant step-by-step solutions',
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureCard(
                      icon: Icons.trending_up,
                      title: 'Track your improvement daily',
                      description: 'See exactly where you\'re getting better',
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureCard(
                      icon: Icons.gps_fixed,
                      title: 'Stay motivated with streaks',
                      description: 'Build consistent study habits that stick',
                    ),
                    const SizedBox(height: 40),
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildDot(0, onWhiteBackground: true),
                        const SizedBox(width: 8),
                        _buildDot(1, onWhiteBackground: true),
                        const SizedBox(width: 8),
                        _buildDot(2, onWhiteBackground: true),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Get Started Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppColors.ctaGradient,
                        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
                        boxShadow: AppShadows.buttonShadow,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _handleComplete,
                          borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Get Started',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryPurple,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipItemWhite(String text) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle,
          color: AppColors.successGreen,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItemWhite(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle,
          color: AppColors.successGreen,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDot(int index, {bool onWhiteBackground = false}) {
    final isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: onWhiteBackground
            ? (isActive ? AppColors.primaryPurple : AppColors.borderMedium)
            : (isActive ? Colors.white : Colors.white.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
