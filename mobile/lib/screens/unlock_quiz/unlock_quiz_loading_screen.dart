import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jeevibe_mobile/providers/unlock_quiz_provider.dart';
import 'package:jeevibe_mobile/services/firebase/auth_service.dart';
import 'package:jeevibe_mobile/widgets/quiz_loading_screen.dart';
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
    return QuizLoadingScreen(
      subject: widget.subject,
      chapterName: widget.chapterName,
      message:
          'Preparing your unlock quiz. Answer 3 out of 5 questions correctly to unlock this chapter!',
      badgeText: 'Unlock Quiz - 5 Questions',
      badgeIcon: Icons.lock_open,
    );
  }
}
