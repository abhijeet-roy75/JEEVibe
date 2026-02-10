import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jeevibe_mobile/providers/unlock_quiz_provider.dart';
import 'package:jeevibe_mobile/services/firebase/auth_service.dart';
import 'package:jeevibe_mobile/theme/app_colors.dart';
import 'package:jeevibe_mobile/theme/app_text_styles.dart';
import 'package:jeevibe_mobile/widgets/priya_avatar.dart';
import 'package:jeevibe_mobile/screens/unlock_quiz/unlock_quiz_question_screen.dart';

/// Unlock Quiz Loading Screen
/// Generates quiz session and navigates to question screen
class UnlockQuizLoadingScreen extends StatefulWidget {
  final String chapterKey;
  final String chapterName;
  final String subject;

  const UnlockQuizLoadingScreen({
    super.key,
    required this.chapterKey,
    required this.chapterName,
    required this.subject,
  });

  @override
  State<UnlockQuizLoadingScreen> createState() =>
      _UnlockQuizLoadingScreenState();
}

class _UnlockQuizLoadingScreenState extends State<UnlockQuizLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _avatarAnimationController;

  @override
  void initState() {
    super.initState();

    // Avatar pulsing animation
    _avatarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initializeQuiz();
  }

  @override
  void dispose() {
    _avatarAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeQuiz() async {
    final unlockQuizProvider = context.read<UnlockQuizProvider>();
    final authService = context.read<AuthService>();
    final authToken = await authService.getIdToken();

    if (authToken == null) {
      if (mounted) {
        _showError('Authentication error. Please try again.');
      }
      return;
    }

    try {
      await unlockQuizProvider.startUnlockQuiz(widget.chapterKey, authToken);

      // Navigate to question screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const UnlockQuizQuestionScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to load quiz: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // Purple to pink gradient background matching other quiz loading screens
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
                                  color: Colors.white.withValues(
                                    alpha: 0.3 +
                                        (_avatarAnimationController.value * 0.2),
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
                    const SizedBox(height: 32),
                    // Chapter info card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          // Subject badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.subject,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Chapter name
                          Text(
                            widget.chapterName,
                            style: AppTextStyles.headerMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Message text
                    Text(
                      'Preparing your unlock quiz. Answer 3 out of 5 questions correctly to unlock this chapter!',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
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
                    // Unlock quiz badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_open,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Unlock Quiz - 5 Questions',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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
