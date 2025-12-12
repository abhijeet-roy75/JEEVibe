/// Assessment Loading Screen
/// Shows Priya Ma'am while assessment is being scored
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/assessment_response.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/priya_avatar.dart';
import '../services/storage_service.dart';
import 'assessment_intro_screen.dart';

class AssessmentLoadingScreen extends StatefulWidget {
  final AssessmentData assessmentData;

  const AssessmentLoadingScreen({
    super.key,
    required this.assessmentData,
  });

  @override
  State<AssessmentLoadingScreen> createState() => _AssessmentLoadingScreenState();
}

class _AssessmentLoadingScreenState extends State<AssessmentLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isComplete = false;
  Timer? _minDisplayTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Show loading for at least 5 seconds
    _minDisplayTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isComplete = true;
        });
        _navigateToDashboard();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _minDisplayTimer?.cancel();
    super.dispose();
  }

  void _navigateToDashboard() async {
    // Update local storage status
    final storageService = StorageService();
    await storageService.setAssessmentStatus('completed');
    
    // Wait a bit for animation to complete
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AssessmentIntroScreen()),
          (route) => false, // Remove all previous routes
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Priya Ma'am Avatar with animation
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_animationController.value * 0.1),
                        child: Opacity(
                          opacity: 0.8 + (_animationController.value * 0.2),
                          child: child,
                        ),
                      );
                    },
                    child: const PriyaAvatar(size: 120),
                  ),
                  const SizedBox(height: 32),
                  // Title
                  Text(
                    'Scoring in Progress',
                    style: AppTextStyles.headerLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Message
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Priya Ma\'am',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Great job completing the assessment! I\'m analyzing your responses to create your personalized study plan. This will just take a moment... 💜',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Loading indicator
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
