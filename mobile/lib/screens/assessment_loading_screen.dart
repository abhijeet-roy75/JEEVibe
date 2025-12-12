/// Assessment Loading Screen
/// Shows Priya Ma'am while assessment is being scored
/// Polls backend for results when processing asynchronously
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/assessment_response.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/priya_avatar.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import 'assessment_intro_screen.dart';

class AssessmentLoadingScreen extends StatefulWidget {
  final AssessmentData assessmentData;
  final String? userId;
  final String? authToken;

  const AssessmentLoadingScreen({
    super.key,
    required this.assessmentData,
    this.userId,
    this.authToken,
  });

  @override
  State<AssessmentLoadingScreen> createState() => _AssessmentLoadingScreenState();
}

class _AssessmentLoadingScreenState extends State<AssessmentLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _avatarAnimationController;
  bool _isComplete = false;
  Timer? _minDisplayTimer;
  Timer? _pollingTimer;
  bool _hasStartedPolling = false;
  bool _backendComplete = false;
  bool _minTimeElapsed = false;
  late final DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    
    // Avatar pulsing animation
    _avatarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Always ensure minimum 5 seconds display
    _minDisplayTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _minTimeElapsed = true;
        });
        _checkAndNavigate();
      }
    });

    // Check if we need to poll for results
    final status = widget.assessmentData.assessment['status'] as String?;
    if (status == 'processing' && widget.userId != null && widget.authToken != null) {
      // Start polling for results
      _startPolling();
    } else {
      // Already completed (shouldn't happen in normal flow, but handle it)
      setState(() {
        _backendComplete = true;
      });
      _checkAndNavigate();
    }
  }
  
  void _checkAndNavigate() {
    // Only navigate when BOTH conditions are met:
    // 1. Backend processing is complete (or not needed)
    // 2. Minimum 5 seconds have elapsed
    if (_backendComplete && _minTimeElapsed && !_isComplete) {
      setState(() {
        _isComplete = true;
      });
      _navigateToDashboard();
    }
  }
  
  void _startPolling() {
    if (_hasStartedPolling) return;
    _hasStartedPolling = true;
    
    // Poll every 2 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted || _isComplete) {
        timer.cancel();
        return;
      }
      
      try {
        final result = await ApiService.getAssessmentResults(
          authToken: widget.authToken!,
          userId: widget.userId!,
        );
        
        if (result.success && result.data != null) {
          final newStatus = result.data!.assessment['status'] as String?;
          
          if (newStatus == 'completed') {
            // Results are ready!
            timer.cancel();
            
            if (mounted) {
              setState(() {
                _backendComplete = true;
              });
              _checkAndNavigate();
            }
          } else if (newStatus == 'error') {
            // Error occurred
            timer.cancel();
            if (mounted) {
              setState(() {
                _backendComplete = true; // Mark as complete to allow navigation
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error processing assessment: ${result.error ?? "Unknown error"}'),
                  backgroundColor: Colors.red,
                ),
              );
              // Still navigate after minimum time even on error
              _checkAndNavigate();
            }
          }
          // If still processing, continue polling
        }
      } catch (e) {
        // Log error but continue polling
        print('Error polling for results: $e');
      }
    });
  }

  @override
  void dispose() {
    _avatarAnimationController.dispose();
    _minDisplayTimer?.cancel();
    _pollingTimer?.cancel();
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
        decoration: BoxDecoration(
          // Purple to pink gradient background matching assessment header
          gradient: const LinearGradient(
            colors: [Color(0xFF9333EA), Color(0xFFEC4899)], // Purple to pink
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Priya Ma'am Avatar with pulsing animation
                    AnimatedBuilder(
                      animation: _avatarAnimationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_avatarAnimationController.value * 0.05),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(
                                    0.3 + (_avatarAnimationController.value * 0.2),
                                  ),
                                  blurRadius: 40,
                                  spreadRadius: 15,
                                ),
                              ],
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: const PriyaAvatar(size: 120),
                    ),
                    const SizedBox(height: 40),
                    // Message text (white for visibility on gradient)
                    Text(
                      'I am evaluating your answers and generating your personalized study plan. This will just take a moment.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.95), // White text on gradient
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    // Purple heart
                    const Text(
                      '💜',
                      style: TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 40),
                    // Loading spinner
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}
