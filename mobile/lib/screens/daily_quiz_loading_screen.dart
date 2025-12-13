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

class _DailyQuizLoadingScreenState extends State<DailyQuizLoadingScreen> {
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateQuiz();
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
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.errorRed),
                const SizedBox(height: 16),
                Text(
                  'Error',
                  style: AppTextStyles.headerMedium.copyWith(
                    color: AppColors.errorRed,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: AppTextStyles.bodyMedium,
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
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryPurple),
            const SizedBox(height: 24),
            Text(
              'Generating your personalized quiz...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 32),
            const PriyaAvatar(size: 64),
            const SizedBox(height: 16),
            Text(
              'Priya Ma\'am ✨',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primaryPurple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'re preparing questions tailored just for you!',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

