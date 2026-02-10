import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jeevibe_mobile/providers/unlock_quiz_provider.dart';
import 'package:jeevibe_mobile/services/firebase/auth_service.dart';
import 'package:jeevibe_mobile/theme/app_colors.dart';
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

class _UnlockQuizLoadingScreenState extends State<UnlockQuizLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _initializeQuiz();
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
          gradient: LinearGradient(
            colors: [
              AppColors.background,
              AppColors.surface,
              AppColors.background,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lock icon with animation
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.2),
                      AppColors.primaryLight.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.lock_open,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Text(
                'Preparing unlock quiz...',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.chapterName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subject,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
