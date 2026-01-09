/// JEEVibe Content Configuration
///
/// DEPRECATED: This file is kept for backward compatibility only.
/// Use AppTextStyles from theme/app_text_styles.dart instead:
/// - AppTextStyles.question
/// - AppTextStyles.option
/// - AppTextStyles.step
/// - AppTextStyles.finalAnswer
/// - AppTextStyles.priyaTip
///
/// This file re-exports from the consolidated design system.

import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';

@Deprecated('Use AppTextStyles instead. This class will be removed in a future version.')
class ContentConfig {
  ContentConfig._();

  // ============================================================================
  // TEXT SIZES - Now defined in AppTextStyles
  // ============================================================================

  /// @Deprecated Use AppTextStyles.question instead
  static const double questionTextSize = 18.0;

  /// @Deprecated Use AppTextStyles.option instead
  static const double optionTextSize = 16.0;

  /// @Deprecated Use AppTextStyles.step instead
  static const double stepTextSize = 16.0;
  static const double explanationTextSize = 16.0;
  static const double approachTextSize = 16.0;

  /// @Deprecated Use AppTextStyles.finalAnswer instead
  static const double finalAnswerTextSize = 17.0;

  /// @Deprecated Use AppTextStyles.priyaTip instead
  static const double priyaTipTextSize = 18.0;

  /// @Deprecated Use AppTextStyles.labelSmall/metadata instead
  static const double labelTextSize = 14.0;
  static const double metadataTextSize = 14.0;

  // ============================================================================
  // LATEX RENDERING CONFIGURATION
  // ============================================================================

  static const double latexScaleFactor = 1.0;
  static const FontWeight latexFontWeight = FontWeight.w600;
  static const FontWeight regularTextWeight = FontWeight.w400;
  static const FontWeight priyaTipFontWeight = FontWeight.w700;

  // ============================================================================
  // LINE HEIGHT / SPACING
  // ============================================================================

  static const double questionLineHeight = 1.6;
  static const double optionLineHeight = 1.5;
  static const double stepLineHeight = 1.6;
  static const double priyaTipLineHeight = 1.8;

  // ============================================================================
  // HELPER METHODS - Now delegate to AppTextStyles
  // ============================================================================

  /// @Deprecated Use AppTextStyles.question.copyWith(color: color) instead
  static TextStyle getQuestionTextStyle({Color? color}) {
    return AppTextStyles.question.copyWith(color: color ?? AppColors.textPrimary);
  }

  /// @Deprecated Use AppTextStyles.option.copyWith(color: color) instead
  static TextStyle getOptionTextStyle({Color? color}) {
    return AppTextStyles.option.copyWith(color: color ?? AppColors.textPrimary);
  }

  /// @Deprecated Use AppTextStyles.step.copyWith(color: color) instead
  static TextStyle getStepTextStyle({Color? color}) {
    return AppTextStyles.step.copyWith(color: color ?? AppColors.textSecondary);
  }

  /// @Deprecated Use AppTextStyles.priyaTip.copyWith(color: color) instead
  static TextStyle getPriyaTipTextStyle({Color? color}) {
    return AppTextStyles.priyaTip.copyWith(color: color ?? AppColors.textPrimary);
  }

  /// Get text style for LaTeX content
  static TextStyle getLatexTextStyle(TextStyle baseStyle) {
    return baseStyle.copyWith(fontWeight: latexFontWeight);
  }
}
