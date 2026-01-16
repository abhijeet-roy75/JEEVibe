/// Priya Ma'am Dynamic Message Service
///
/// Generates personalized, data-driven messages for the home screen card.
/// Follows the Priya Ma'am Message Framework:
/// - Never demotivate, always forward-looking
/// - Supportive elder sister who believes in you
/// - Focus on effort/process, not fixed ability

class PriyaMessageService {
  /// Generate a dynamic message based on quiz data
  ///
  /// Priority order:
  /// 1. Streak milestone (7, 14, 30 days)
  /// 2. Performance tier based on last quiz accuracy
  /// 3. Volume milestone (50/100 questions, 10/25 quizzes)
  /// 4. Default message (assessment only, no quizzes yet)
  static PriyaMessage generateMessage({
    required String studentName,
    int? currentStreak,
    int? longestStreak,
    int? totalQuizzesCompleted,
    int? totalQuestionsAnswered,
    double? lastQuizAccuracy, // 0-1 scale
    double? previousQuizAccuracy, // For improvement detection
    String? weakTopic,
    String? strongTopic,
  }) {
    final name = studentName.isNotEmpty ? studentName : 'Student';

    // 1. Check for streak milestones (highest priority - rare and impactful)
    if (currentStreak != null && currentStreak > 0) {
      final streakMessage = _getStreakMilestoneMessage(
        name: name,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        lastQuizAccuracy: lastQuizAccuracy,
      );
      if (streakMessage != null) {
        return streakMessage;
      }
    }

    // 2. Check for improvement (if we have previous accuracy to compare)
    if (lastQuizAccuracy != null && previousQuizAccuracy != null) {
      final improvement = lastQuizAccuracy - previousQuizAccuracy;
      if (improvement >= 0.15) { // 15%+ improvement
        final lastPct = (lastQuizAccuracy * 100).round();
        final prevPct = (previousQuizAccuracy * 100).round();
        return PriyaMessage(
          title: 'You\'re Improving! 📈',
          subtitle: 'Keep the momentum',
          message: 'You jumped from $prevPct% to $lastPct%! Practice works.',
          type: PriyaMessageType.improvement,
        );
      }
    }

    // 3. Performance tier based on last quiz accuracy
    if (lastQuizAccuracy != null) {
      return _getPerformanceMessage(
        name: name,
        accuracy: lastQuizAccuracy,
        currentStreak: currentStreak,
        weakTopic: weakTopic,
        strongTopic: strongTopic,
      );
    }

    // 4. Volume milestones (if no recent quiz data)
    if (totalQuestionsAnswered != null && totalQuestionsAnswered > 0) {
      final volumeMessage = _getVolumeMilestoneMessage(
        name: name,
        totalQuestions: totalQuestionsAnswered,
        totalQuizzes: totalQuizzesCompleted ?? 0,
      );
      if (volumeMessage != null) {
        return volumeMessage;
      }
    }

    // 5. Default message (assessment completed, no quizzes yet)
    return PriyaMessage(
      title: 'Great Job, $name! 🎉',
      subtitle: 'Assessment Complete',
      message: "I've analyzed your strengths and areas for improvement. Let's build on this with daily adaptive practice tailored for you!",
      type: PriyaMessageType.assessmentComplete,
    );
  }

  /// Check for streak milestones and return appropriate message
  static PriyaMessage? _getStreakMilestoneMessage({
    required String name,
    required int currentStreak,
    int? longestStreak,
    double? lastQuizAccuracy,
  }) {
    // Major milestones: 30, 14, 7, 3 days
    if (currentStreak == 30) {
      return PriyaMessage(
        title: '30 Days! 🏆',
        subtitle: 'Incredible dedication',
        message: 'A full month of practice! Your future self will thank you for this discipline.',
        type: PriyaMessageType.streakMilestone,
      );
    }

    if (currentStreak == 14) {
      return PriyaMessage(
        title: '2 Weeks Strong! 🔥',
        subtitle: 'Top 10% dedication',
        message: "2 weeks of consistent practice! You're in the top tier of dedicated students.",
        type: PriyaMessageType.streakMilestone,
      );
    }

    if (currentStreak == 7) {
      return PriyaMessage(
        title: 'One Week! 🔥',
        subtitle: 'Building a habit',
        message: 'A full week of practice! Consistency beats intensity every time.',
        type: PriyaMessageType.streakMilestone,
      );
    }

    if (currentStreak == 3) {
      return PriyaMessage(
        title: '3 Days Strong! 💪',
        subtitle: 'Great start',
        message: "3 days in a row! You're building a habit. Keep it up!",
        type: PriyaMessageType.streakMilestone,
      );
    }

    // For struggling performance + streak: emphasize consistency
    if (lastQuizAccuracy != null && lastQuizAccuracy < 0.5 && currentStreak >= 3) {
      return PriyaMessage(
        title: '$currentStreak Days Straight! 💪',
        subtitle: 'Consistency counts',
        message: 'Tough topics, but $currentStreak days of showing up! Consistency beats any single score.',
        type: PriyaMessageType.streakWithEncouragement,
      );
    }

    return null;
  }

  /// Get performance-based message following the framework tiers
  static PriyaMessage _getPerformanceMessage({
    required String name,
    required double accuracy,
    int? currentStreak,
    String? weakTopic,
    String? strongTopic,
  }) {
    final percentage = (accuracy * 100).round();

    // Excellent (90%+): Celebratory + Challenge
    if (accuracy >= 0.9) {
      return PriyaMessage(
        title: "You're on Fire! 🌟",
        subtitle: '$percentage% accuracy',
        message: strongTopic != null
          ? "Brilliant work! You're mastering $strongTopic. Ready for a tougher challenge?"
          : "Brilliant! You crushed it. Ready for a tougher challenge?",
        type: PriyaMessageType.excellent,
      );
    }

    // Good (70-89%): Warm praise + Growth
    if (accuracy >= 0.7) {
      return PriyaMessage(
        title: 'Solid Progress! 💪',
        subtitle: '$percentage% accuracy',
        message: strongTopic != null
          ? "Great effort! You're getting stronger in $strongTopic. Keep the momentum!"
          : "Solid work! A few more reps and you'll master these.",
        type: PriyaMessageType.good,
      );
    }

    // Average (50-69%): Encouraging + Specific
    if (accuracy >= 0.5) {
      return PriyaMessage(
        title: 'Good Practice! 🎯',
        subtitle: '$percentage% accuracy',
        message: weakTopic != null
          ? "Good practice! Let's strengthen $weakTopic together today."
          : "Good practice! I'm adjusting today's quiz to help you improve.",
        type: PriyaMessageType.average,
      );
    }

    // Struggling (30-49%): Compassionate + Supportive
    if (accuracy >= 0.3) {
      // If they have a streak, emphasize that
      if (currentStreak != null && currentStreak >= 2) {
        return PriyaMessage(
          title: 'You Showed Up! 🌱',
          subtitle: '$currentStreak day streak',
          message: "Tough topics, but you're here $currentStreak days straight. That's what matters!",
          type: PriyaMessageType.struggling,
        );
      }
      return PriyaMessage(
        title: 'Keep Going! 🌱',
        subtitle: 'One step at a time',
        message: weakTopic != null
          ? "Tough topics. Today we'll tackle $weakTopic step by step."
          : "You showed up—that's what counts. Let's try again today!",
        type: PriyaMessageType.struggling,
      );
    }

    // Tough Day (<30%): Gentle + Normalizing
    return PriyaMessage(
      title: 'Fresh Start Today ❤️',
      subtitle: 'Everyone has tough days',
      message: "Tough one yesterday. It happens to everyone. Today we start fresh—I've got you.",
      type: PriyaMessageType.toughDay,
    );
  }

  /// Check for volume milestones
  static PriyaMessage? _getVolumeMilestoneMessage({
    required String name,
    required int totalQuestions,
    required int totalQuizzes,
  }) {
    // Question milestones: 100, 50
    if (totalQuestions == 100) {
      return PriyaMessage(
        title: '100 Questions! 🎉',
        subtitle: 'Major milestone',
        message: "100 questions solved! Most students don't get this far. Proud of you!",
        type: PriyaMessageType.volumeMilestone,
      );
    }

    if (totalQuestions == 50) {
      return PriyaMessage(
        title: '50 Questions! 🎯',
        subtitle: 'Building momentum',
        message: '50 questions down! Small steps lead to big results.',
        type: PriyaMessageType.volumeMilestone,
      );
    }

    // Quiz milestones: 25, 10
    if (totalQuizzes == 25) {
      return PriyaMessage(
        title: '25 Quizzes! 🏅',
        subtitle: 'Outstanding commitment',
        message: "25 quizzes complete! Most students never get this far. You're dedicated!",
        type: PriyaMessageType.volumeMilestone,
      );
    }

    if (totalQuizzes == 10) {
      return PriyaMessage(
        title: '10 Quizzes! ⭐',
        subtitle: 'In a rhythm',
        message: "10 quizzes complete! You're officially in a rhythm. Keep it going!",
        type: PriyaMessageType.volumeMilestone,
      );
    }

    return null;
  }

  /// Get a message for returning users (streak broken)
  static PriyaMessage getWelcomeBackMessage(String name) {
    return PriyaMessage(
      title: 'Welcome Back! 👋',
      subtitle: 'Ready to continue',
      message: "Welcome back, $name! Every comeback starts with showing up. Let's go!",
      type: PriyaMessageType.welcomeBack,
    );
  }
}

/// Model class for Priya's message
class PriyaMessage {
  final String title;
  final String subtitle;
  final String message;
  final PriyaMessageType type;

  const PriyaMessage({
    required this.title,
    required this.subtitle,
    required this.message,
    required this.type,
  });
}

/// Types of Priya messages for potential styling differences
enum PriyaMessageType {
  assessmentComplete,
  streakMilestone,
  streakWithEncouragement,
  improvement,
  excellent,
  good,
  average,
  struggling,
  toughDay,
  volumeMilestone,
  welcomeBack,
}
