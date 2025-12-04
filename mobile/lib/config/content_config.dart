/// JEEVibe Content Configuration
/// Centralized configuration for mathematical and chemical content display
/// Ensures consistency across all screens displaying problems and solutions

import 'package:flutter/material.dart';

class ContentConfig {
  // ============================================================================
  // TEXT SIZES - Consistent across all screens
  // ============================================================================
  
  /// Questions (main question text)  
  /// Used in: solution_screen, followup_quiz_screen, review_questions_screen, solution_review_screen
  /// Set to 18px for better fit without overflow
  static const double questionTextSize = 18.0;
  
  /// Options (multiple choice options)
  /// Used in: followup_quiz_screen, review_questions_screen
  /// Set to 16px for better balance
  static const double optionTextSize = 16.0;
  
  /// Steps and explanations
  /// Used in: solution_screen, solution_review_screen, review_questions_screen
  static const double stepTextSize = 16.0;
  static const double explanationTextSize = 16.0;
  
  /// Approach text (solution strategy)
  /// Used in: solution_screen, solution_review_screen
  static const double approachTextSize = 16.0;
  
  /// Final answer text
  /// Used in: solution_screen, solution_review_screen
  /// Set to 17px for better balance
  static const double finalAnswerTextSize = 17.0;
  
  /// Priya Ma'am's tips - Adjusted for balance with other text
  /// Was 28px (too small), tried 34px (too large), now 18px for good balance
  /// Used in: solution_screen, practice_results_screen
  static const double priyaTipTextSize = 18.0;
  
  /// Labels and metadata (subject, topic, difficulty)
  /// Used in: all screens
  static const double labelTextSize = 14.0;
  static const double metadataTextSize = 14.0;
  
  // ============================================================================
  // LATEX RENDERING CONFIGURATION
  // ============================================================================
  
  /// Scale factor for LaTeX rendering
  /// Can be adjusted if LaTeX appears too small/large relative to regular text
  static const double latexScaleFactor = 1.0;
  
  /// Font weight for LaTeX content
  /// Slightly bold to make mathematical/chemical formulas stand out
  static const FontWeight latexFontWeight = FontWeight.w600;
  
  /// Font weight for regular text
  static const FontWeight regularTextWeight = FontWeight.w400;
  
  /// Font weight for Priya's tips
  /// Bold for better visibility and emphasis
  static const FontWeight priyaTipFontWeight = FontWeight.w700;
  
  // ============================================================================
  // LINE HEIGHT / SPACING
  // ============================================================================
  
  /// Line height for questions (for readability)
  static const double questionLineHeight = 1.6;
  
  /// Line height for options
  static const double optionLineHeight = 1.5;
  
  /// Line height for steps and explanations
  static const double stepLineHeight = 1.6;
  
  /// Line height for Priya's tips (extra spacing for readability)
  static const double priyaTipLineHeight = 1.8;
  
  // ============================================================================
  // HELPER METHODS
  // ============================================================================
  
  /// Get text style for questions
  static TextStyle getQuestionTextStyle({Color? color}) {
    return TextStyle(
      fontSize: questionTextSize,
      fontWeight: regularTextWeight,
      height: questionLineHeight,
      color: color,
    );
  }
  
  /// Get text style for options
  static TextStyle getOptionTextStyle({Color? color}) {
    return TextStyle(
      fontSize: optionTextSize,
      fontWeight: regularTextWeight,
      height: optionLineHeight,
      color: color,
    );
  }
  
  /// Get text style for steps
  static TextStyle getStepTextStyle({Color? color}) {
    return TextStyle(
      fontSize: stepTextSize,
      fontWeight: regularTextWeight,
      height: stepLineHeight,
      color: color,
    );
  }
  
  /// Get text style for Priya's tips
  static TextStyle getPriyaTipTextStyle({Color? color}) {
    return TextStyle(
      fontSize: priyaTipTextSize,
      fontWeight: priyaTipFontWeight,
      height: priyaTipLineHeight,
      color: color,
      letterSpacing: 0.3, // Slight letter spacing for clarity
    );
  }
  
  /// Get text style for LaTeX content
  static TextStyle getLatexTextStyle(TextStyle baseStyle) {
    return baseStyle.copyWith(
      fontWeight: latexFontWeight,
    );
  }
}

