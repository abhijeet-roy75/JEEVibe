/// Share Service
/// Handles sharing JEEVibe content via WhatsApp and other platforms
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'api_service.dart';

class ShareService {
  /// Share solution via native share sheet
  /// Returns true if share was initiated successfully
  ///
  /// [sharePositionOrigin] is required on iPad to position the share popover.
  /// Pass the bounds of the share button for best UX.
  static Future<bool> shareSolution({
    required String authToken,
    required String solutionId,
    required String question,
    required String finalAnswer,
    required String subject,
    required String topic,
    required List<String> steps,
    Rect? sharePositionOrigin,
  }) async {
    try {
      // Build share message
      final message = _buildShareMessage(
        question: question,
        steps: steps,
        finalAnswer: finalAnswer,
        subject: subject,
        topic: topic,
      );

      // Log share event to backend (fire-and-forget, don't block UI)
      _logShareEvent(
        authToken: authToken,
        solutionId: solutionId,
        subject: subject,
        topic: topic,
      );

      // Share via native share sheet (use shareWithResult to get ShareResult)
      // sharePositionOrigin is required on iPad for the popover position
      final result = await Share.shareWithResult(
        message,
        subject: 'JEEVibe - $subject Solution',
        sharePositionOrigin: sharePositionOrigin,
      );

      return result.status == ShareResultStatus.success ||
             result.status == ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('Error sharing solution: $e');
      return false;
    }
  }

  /// Build the share message text
  static String _buildShareMessage({
    required String question,
    required List<String> steps,
    required String finalAnswer,
    required String subject,
    required String topic,
  }) {
    // Clean LaTeX from question FIRST, then truncate
    final cleanQuestion = _cleanLaTeXForSharing(question);
    final truncatedQuestion = cleanQuestion.length > 200
        ? '${cleanQuestion.substring(0, 197)}...'
        : cleanQuestion;

    // Clean and format solution steps
    final stepsBuffer = StringBuffer();
    for (int i = 0; i < steps.length; i++) {
      final cleanStep = _cleanLaTeXForSharing(steps[i]);
      // Truncate each step to keep message reasonable
      final truncatedStep = cleanStep.length > 150
          ? '${cleanStep.substring(0, 147)}...'
          : cleanStep;
      stepsBuffer.writeln('*Step ${i + 1}:* $truncatedStep');
      if (i < steps.length - 1) stepsBuffer.writeln();
    }

    // Clean LaTeX from finalAnswer for plain text display
    final cleanAnswer = _cleanLaTeXForSharing(finalAnswer);

    // Format message for WhatsApp compatibility
    // NOTE: WhatsApp on iOS extracts URLs and only shows link preview
    // So we DON'T include https:// URLs - use plain text instead
    return '''📚 *JEE Question*
$truncatedQuestion

📝 *Solution*
${stepsBuffer.toString().trim()}

✅ *Final Answer*
$cleanAnswer

Solved with JEEVibe - Download from App Store''';
  }

  /// Remove LaTeX formatting for plain text sharing
  static String _cleanLaTeXForSharing(String text) {
    String cleaned = text;

    // Convert Greek letters to symbols
    final greekLetters = {
      r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ', r'\delta': 'δ',
      r'\epsilon': 'ε', r'\theta': 'θ', r'\lambda': 'λ', r'\mu': 'μ',
      r'\pi': 'π', r'\sigma': 'σ', r'\omega': 'ω', r'\phi': 'φ',
      r'\psi': 'ψ', r'\rho': 'ρ', r'\tau': 'τ', r'\eta': 'η',
    };
    greekLetters.forEach((latex, symbol) {
      cleaned = cleaned.replaceAll(latex, symbol);
    });

    // Remove inline math delimiters \( ... \) - keep content
    cleaned = cleaned.replaceAll(RegExp(r'\\\('), '');
    cleaned = cleaned.replaceAll(RegExp(r'\\\)'), '');

    // Remove display math delimiters \[ ... \] - keep content
    cleaned = cleaned.replaceAll(RegExp(r'\\\['), '');
    cleaned = cleaned.replaceAll(RegExp(r'\\\]'), '');

    // Remove $ delimiters
    cleaned = cleaned.replaceAll(RegExp(r'\$'), '');

    // Remove \mathrm{} but keep content
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\\mathrm\{([^}]+)\}'),
      (match) => match.group(1) ?? '',
    );

    // Remove \text{} but keep content
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\\text\{([^}]+)\}'),
      (match) => match.group(1) ?? '',
    );

    // Convert \frac{a}{b} -> (a/b)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'),
      (match) => '(${match.group(1)}/${match.group(2)})',
    );

    // Remove subscripts/superscripts with braces
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'[_\^]\{([^}]+)\}'),
      (match) => match.group(1) ?? '',
    );

    // Remove single-char subscripts/superscripts
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'[_\^](\d)'),
      (match) => match.group(1) ?? '',
    );

    // Convert \sqrt{x} -> √(x)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\\sqrt\{([^}]+)\}'),
      (match) => '√(${match.group(1)})',
    );

    // Common math symbols
    cleaned = cleaned.replaceAll(r'\times', '×');
    cleaned = cleaned.replaceAll(r'\div', '÷');
    cleaned = cleaned.replaceAll(r'\pm', '±');
    cleaned = cleaned.replaceAll(r'\cdot', '·');
    cleaned = cleaned.replaceAll(r'\leq', '≤');
    cleaned = cleaned.replaceAll(r'\geq', '≥');
    cleaned = cleaned.replaceAll(r'\neq', '≠');
    cleaned = cleaned.replaceAll(r'\infty', '∞');
    cleaned = cleaned.replaceAll(r'\sum', 'Σ');
    cleaned = cleaned.replaceAll(r'\int', '∫');

    // Remove any remaining LaTeX commands
    cleaned = cleaned.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');

    // Clean up extra spaces and braces
    cleaned = cleaned.replaceAll(RegExp(r'\{|\}'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }

  /// Log share event to backend (non-blocking)
  static void _logShareEvent({
    required String authToken,
    required String solutionId,
    required String subject,
    required String topic,
  }) {
    // Fire and forget - don't await
    ApiService.logShareEvent(
      authToken: authToken,
      solutionId: solutionId,
      shareType: 'whatsapp',
      subject: subject,
      topic: topic,
    ).catchError((e) {
      debugPrint('Failed to log share event: $e');
    });
  }

  /// Share journey progress via native share sheet
  static Future<bool> shareJourneyProgress({
    required String studentName,
    required int questionsPracticed,
    required int nextMilestone,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final message = _buildJourneyShareMessage(
        studentName: studentName,
        questionsPracticed: questionsPracticed,
        nextMilestone: nextMilestone,
      );

      final result = await Share.shareWithResult(
        message,
        subject: 'My JEEVibe Journey',
        sharePositionOrigin: sharePositionOrigin,
      );

      return result.status == ShareResultStatus.success ||
             result.status == ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('Error sharing journey: $e');
      return false;
    }
  }

  /// Build the journey share message
  static String _buildJourneyShareMessage({
    required String studentName,
    required int questionsPracticed,
    required int nextMilestone,
  }) {
    String achievementEmoji;
    String achievementText;

    if (questionsPracticed >= 300) {
      achievementEmoji = '👑';
      achievementText = "I'm a JEE Champion!";
    } else if (questionsPracticed >= 200) {
      achievementEmoji = '🏆';
      achievementText = "I've reached 200 questions!";
    } else if (questionsPracticed >= 100) {
      achievementEmoji = '🔥';
      achievementText = "I've hit 100 questions!";
    } else if (questionsPracticed >= 50) {
      achievementEmoji = '⭐';
      achievementText = "Halfway to 100!";
    } else if (questionsPracticed >= 25) {
      achievementEmoji = '💪';
      achievementText = "I'm building momentum!";
    } else if (questionsPracticed >= 10) {
      achievementEmoji = '🎯';
      achievementText = "Just getting started!";
    } else {
      achievementEmoji = '🚀';
      achievementText = "Beginning my JEE journey!";
    }

    return '''$achievementEmoji *My JEEVibe Journey*

📚 *$questionsPracticed questions* practiced!
$achievementText

🎯 Next milestone: $nextMilestone questions

Join me on JEEVibe - Download from App Store''';
  }
}
