/// Daily Quiz Loading Screen
/// Generates quiz and navigates to question screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/daily_quiz_question.dart';
import '../providers/daily_quiz_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/priya_avatar.dart';
import '../utils/error_handler.dart';
import 'daily_quiz_question_screen.dart';

class DailyQuizLoadingScreen extends StatefulWidget {
  const DailyQuizLoadingScreen({super.key});

  @override
  State<DailyQuizLoadingScreen> createState() => _DailyQuizLoadingScreenState();
}

class _DailyQuizLoadingScreenState extends State<DailyQuizLoadingScreen>
    with SingleTickerProviderStateMixin {
  String? _error;
  bool _isLoading = true;
  late AnimationController _avatarAnimationController;

  @override
  void initState() {
    super.initState();
    
    // Avatar pulsing animation
    _avatarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _generateQuiz();
  }

  @override
  void dispose() {
    _avatarAnimationController.dispose();
    super.dispose();
  }

  Future<void> _generateQuiz() async {
    try {
      final provider = Provider.of<DailyQuizProvider>(context, listen: false);
      
      // Check if there's a saved quiz state first
      final hasSavedState = await provider.hasSavedState();
      if (hasSavedState && provider.currentQuiz != null) {
        // Restore existing quiz
        if (mounted) {
          Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DailyQuizQuestionScreen(quiz: provider.currentQuiz!),
          ),
          );
        }
        return;
      }

      // Generate new quiz
      final quiz = await ErrorHandler.withRetry(
        operation: () => provider.generateQuiz(),
        maxRetries: 3,
      );
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DailyQuizQuestionScreen(quiz: quiz),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorHandler.getErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            // Purple to pink gradient background matching assessment header
            gradient: LinearGradient(
              colors: [Color(0xFF9333EA), Color(0xFFEC4899)], // Purple to pink
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.white.withOpacity(0.95),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error',
                      style: AppTextStyles.headerMedium.copyWith(
                        color: Colors.white.withOpacity(0.95),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _isLoading = true;
                        });
                        _generateQuiz();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryPurple,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // Purple to pink gradient background matching assessment header
          gradient: LinearGradient(
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
                      'I am preparing your personalized daily quiz. This will just take a moment.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.95), // White text on gradient
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    // Loading spinner
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    // Purple heart
                    const Text(
                      '💜',
                      style: TextStyle(fontSize: 24),
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

