import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:jeevibe_mobile/models/unlock_quiz_models.dart';
import 'package:jeevibe_mobile/theme/app_colors.dart';
import 'package:jeevibe_mobile/screens/chapter_practice/chapter_practice_loading_screen.dart';

/// Unlock Quiz Result Screen
/// Shows pass/fail result with confetti animation for success
class UnlockQuizResultScreen extends StatefulWidget {
  final UnlockQuizResult result;

  const UnlockQuizResultScreen({super.key, required this.result});

  @override
  State<UnlockQuizResultScreen> createState() =>
      _UnlockQuizResultScreenState();
}

class _UnlockQuizResultScreenState extends State<UnlockQuizResultScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    if (widget.result.passed) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _confettiController.play();
        }
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: Text(
            widget.result.passed ? 'Chapter Unlocked!' : 'Keep Trying!',
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Stack(
          children: [
            _buildContent(),
            if (widget.result.passed) _buildConfetti(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Icon & Title
          Icon(
            widget.result.passed ? Icons.lock_open : Icons.lock,
            size: 80,
            color: widget.result.passed ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 16),

          Text(
            widget.result.passed ? '🎉 Chapter Unlocked!' : 'Almost there!',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            widget.result.chapterName,
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Score Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.result.passed
                    ? [Colors.green.shade300, Colors.green.shade500]
                    : [Colors.orange.shade300, Colors.orange.shade500],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'Score',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.result.correctCount} / ${widget.result.totalQuestions}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.result.passed
                      ? 'You passed! 🎊'
                      : 'Need ${3 - widget.result.correctCount} more correct',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getMessage(),
              style: const TextStyle(fontSize: 16, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),

          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  String _getMessage() {
    if (widget.result.passed) {
      return "Excellent work! You've unlocked \"${widget.result.chapterName}\". "
          "You can now practice all questions from this chapter. Keep up the great work! 🚀";
    } else {
      return "You got ${widget.result.correctCount} out of ${widget.result.totalQuestions} correct. "
          "Don't give up! Review the solutions, practice a bit more, and try again. "
          "You'll unlock this chapter soon! 💪";
    }
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Retry Button (if failed)
        if (!widget.result.passed)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Pop back to chapter list, which will allow retry
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Try Again with New Questions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Back to Chapters Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              // Navigate back to chapter list
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.borderDefault, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Back to Chapters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),

        // Start Practicing Button (if passed)
        if (widget.result.passed) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to chapter practice for this chapter
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChapterPracticeLoadingScreen(
                      chapterKey: widget.result.chapterKey,
                      chapterName: widget.result.chapterName,
                      subject: widget.result.subject,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Start Practicing Now!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConfetti() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: _confettiController,
        blastDirectionality: BlastDirectionality.explosive,
        particleDrag: 0.05,
        emissionFrequency: 0.05,
        numberOfParticles: 20,
        gravity: 0.1,
        shouldLoop: false,
        colors: const [
          Colors.green,
          Colors.blue,
          Colors.pink,
          Colors.orange,
          Colors.purple,
        ],
      ),
    );
  }
}
