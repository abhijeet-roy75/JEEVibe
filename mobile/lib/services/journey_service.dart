/// Journey Service
/// Generates milestone-based messages for the student journey card.
/// Follows the Priya Ma'am Message Framework:
/// - Never demotivate, always forward-looking
/// - Supportive elder sister who believes in you
/// - Focus on effort/process, not fixed ability

class JourneyService {
  /// Milestone thresholds for the progress line
  static const List<int> milestones = [10, 25, 50, 100, 150, 200, 300, 500];

  /// Get visible milestones based on current progress
  /// Shows 6 milestones that are relevant to current position
  static List<int> getVisibleMilestones(int questionsPracticed) {
    if (questionsPracticed < 10) {
      // New user: show early milestones
      return [1, 10, 25, 50, 100, 200];
    } else if (questionsPracticed < 50) {
      return [10, 25, 50, 100, 150, 200];
    } else if (questionsPracticed < 100) {
      return [25, 50, 100, 150, 200, 250];
    } else if (questionsPracticed < 200) {
      return [50, 100, 150, 200, 250, 300];
    } else if (questionsPracticed < 300) {
      return [100, 150, 200, 250, 300, 400];
    } else if (questionsPracticed < 500) {
      return [150, 200, 300, 400, 500, 600];
    } else {
      return [300, 400, 500, 600, 750, 1000];
    }
  }

  /// Get the next milestone to achieve
  static int getNextMilestone(int questionsPracticed) {
    for (final milestone in milestones) {
      if (questionsPracticed < milestone) {
        return milestone;
      }
    }
    // Beyond all milestones, calculate next 100
    return ((questionsPracticed ~/ 100) + 1) * 100;
  }

  /// Get remaining questions to next milestone
  static int getRemainingToNext(int questionsPracticed) {
    final next = getNextMilestone(questionsPracticed);
    return next - questionsPracticed;
  }

  /// Generate journey message based on questions practiced
  static JourneyMessage generateMessage({
    required String studentName,
    required int questionsPracticed,
  }) {
    final name = studentName.isNotEmpty ? studentName : 'Student';
    final nextMilestone = getNextMilestone(questionsPracticed);
    final remaining = getRemainingToNext(questionsPracticed);

    // New user (0 questions)
    if (questionsPracticed == 0) {
      return JourneyMessage(
        title: '🎯 First milestone: 10 questions',
        message: "Complete today's quiz to start!",
        nextMilestoneText: null,
        type: JourneyMessageType.newUser,
      );
    }

    // Early journey (1-9 questions)
    if (questionsPracticed < 10) {
      return JourneyMessage(
        title: "💪 You've started, $name!",
        message: 'Every expert was once a beginner.',
        nextMilestoneText: '10 questions (only $remaining more!)',
        type: JourneyMessageType.earlyJourney,
      );
    }

    // 10 questions milestone
    if (questionsPracticed == 10) {
      return JourneyMessage(
        title: '🎉 10 questions done!',
        message: "You're building momentum! This is how habits form.",
        nextMilestoneText: '25 questions',
        type: JourneyMessageType.milestone,
      );
    }

    // 11-24 questions
    if (questionsPracticed < 25) {
      return JourneyMessage(
        title: '💜 Great to see you, $name!',
        message: "You've made solid progress. Let's keep going!",
        nextMilestoneText: '25 questions (only $remaining more!)',
        type: JourneyMessageType.progress,
      );
    }

    // 25 questions milestone
    if (questionsPracticed == 25) {
      return JourneyMessage(
        title: '⭐ 25 questions!',
        message: "Top 50% of students don't get this far!",
        nextMilestoneText: '50 questions',
        type: JourneyMessageType.milestone,
      );
    }

    // 26-49 questions
    if (questionsPracticed < 50) {
      return JourneyMessage(
        title: '💪 Keep it up, $name!',
        message: 'Consistency beats intensity every time.',
        nextMilestoneText: '50 questions (only $remaining more!)',
        type: JourneyMessageType.progress,
      );
    }

    // 50 questions milestone
    if (questionsPracticed == 50) {
      return JourneyMessage(
        title: '🔥 50 questions!',
        message: 'Halfway to 100! Your dedication is showing.',
        nextMilestoneText: '100 questions',
        type: JourneyMessageType.milestone,
      );
    }

    // 51-99 questions
    if (questionsPracticed < 100) {
      return JourneyMessage(
        title: '🌱 Growing stronger!',
        message: 'Small steps lead to big results.',
        nextMilestoneText: '100 questions (only $remaining more!)',
        type: JourneyMessageType.progress,
      );
    }

    // 100 questions milestone
    if (questionsPracticed == 100) {
      return JourneyMessage(
        title: '🏆 100 questions!',
        message: "Most students never get this far. Proud of you!",
        nextMilestoneText: '150 questions',
        type: JourneyMessageType.milestone,
      );
    }

    // 101-149 questions
    if (questionsPracticed < 150) {
      return JourneyMessage(
        title: "💎 You're dedicated!",
        message: 'This is exactly how JEE toppers prepare.',
        nextMilestoneText: '150 questions (only $remaining more!)',
        type: JourneyMessageType.progress,
      );
    }

    // 150 questions milestone
    if (questionsPracticed == 150) {
      return JourneyMessage(
        title: '🌟 150 questions!',
        message: "You're in the elite club now!",
        nextMilestoneText: '200 questions',
        type: JourneyMessageType.milestone,
      );
    }

    // 151-199 questions
    if (questionsPracticed < 200) {
      return JourneyMessage(
        title: '✨ Amazing progress, $name!',
        message: 'Your consistency is inspiring.',
        nextMilestoneText: '200 questions (only $remaining more!)',
        type: JourneyMessageType.progress,
      );
    }

    // 200 questions milestone
    if (questionsPracticed == 200) {
      return JourneyMessage(
        title: '👑 200 questions!',
        message: 'This is serious dedication. JEE success is built like this!',
        nextMilestoneText: '300 questions',
        type: JourneyMessageType.milestone,
      );
    }

    // 201-299 questions
    if (questionsPracticed < 300) {
      return JourneyMessage(
        title: '🚀 JEE Warrior, $name!',
        message: 'Your hard work will shine in the exam.',
        nextMilestoneText: '300 questions (only $remaining more!)',
        type: JourneyMessageType.progress,
      );
    }

    // 300+ questions
    return JourneyMessage(
      title: '👑 JEE Champion!',
      message: '$questionsPracticed questions! You are unstoppable!',
      nextMilestoneText: '$nextMilestone questions (only $remaining more!)',
      type: JourneyMessageType.champion,
    );
  }

  /// Check if the header should say "Your Journey Begins!" vs "Your Journey"
  static bool isNewJourney(int questionsPracticed) {
    return questionsPracticed == 0;
  }
}

/// Model class for journey message
class JourneyMessage {
  final String title;
  final String message;
  final String? nextMilestoneText;
  final JourneyMessageType type;

  const JourneyMessage({
    required this.title,
    required this.message,
    this.nextMilestoneText,
    required this.type,
  });
}

/// Types of journey messages
enum JourneyMessageType {
  newUser,
  earlyJourney,
  milestone,
  progress,
  champion,
}
