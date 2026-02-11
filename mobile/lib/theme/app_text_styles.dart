/// JEEVibe Typography System
/// Consolidated text styles using Inter font
/// Single source of truth for all text styling
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_platform_sizing.dart';

class AppTextStyles {
  AppTextStyles._(); // Prevent instantiation

  // ===========================================================================
  // DISPLAY STYLES (Large headings)
  // ===========================================================================

  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(32),  // 32px iOS, 28.8px Android
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.2,
        letterSpacing: -0.5,
      );

  static TextStyle get displayMedium => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(28),  // 28px iOS, 25.2px Android
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.2,
        letterSpacing: -0.5,
      );

  static TextStyle get displaySmall => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(24),  // 24px iOS, 21.6px Android
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.2,
        letterSpacing: -0.3,
      );

  // ===========================================================================
  // HEADER STYLES (Section headings)
  // ===========================================================================

  static TextStyle get headerLarge => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(24),  // 24px iOS, 21.6px Android
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.2,
      );

  static TextStyle get headerMedium => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(20),  // 20px iOS, 18px Android
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get headerSmall => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(18),  // 18px iOS, 16.2px Android
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  // Legacy aliases (h1, h2, h3 from JVStyles)
  static TextStyle get h1 => headerLarge;
  static TextStyle get h2 => headerMedium;
  static TextStyle get h3 => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(16),  // 16px iOS, 14.4px Android
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  // ===========================================================================
  // BODY STYLES (Content text)
  // Per Typography Guidelines: bodyLarge 16-17px, bodyMedium 16px, bodySmall 13px
  // ===========================================================================

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(17),  // 17px iOS, 15.3px Android
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.6,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(16),  // 16px iOS, 14.4px Android
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(13),  // 13px iOS, 11.7px Android
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
        height: 1.5,
      );

  // ===========================================================================
  // LABEL STYLES (UI labels, buttons)
  // Per Typography Guidelines: labels 15-16px, chips/badges 12-13px
  // ===========================================================================

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(16),  // 16px iOS, 14.4px Android
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(15),  // 15px iOS, 13.5px Android
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(13),  // 13px iOS, 11.7px Android
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
        height: 1.4,
        letterSpacing: 0.5,
      );

  // ===========================================================================
  // BUTTON STYLES
  // ===========================================================================

  static TextStyle get buttonLarge => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(18),  // 18px iOS, 16.2px Android
        fontWeight: FontWeight.w600,
        color: AppColors.textWhite,
        height: 1.4,  // Increased from 1.2 to prevent text cutoff
      );

  static TextStyle get buttonMedium => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(16),  // 16px iOS, 14.4px Android
        fontWeight: FontWeight.w600,
        color: AppColors.textWhite,
        height: 1.4,  // Increased from 1.2 to prevent text cutoff
      );

  static TextStyle get buttonSmall => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(14),  // 14px iOS, 12.6px Android
        fontWeight: FontWeight.w600,
        color: AppColors.textWhite,
        height: 1.4,  // Increased from 1.2 to prevent text cutoff
      );

  // Legacy alias from JVStyles
  static TextStyle get button => buttonMedium;

  // ===========================================================================
  // CAPTION & METADATA
  // ===========================================================================

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(12),  // 12px iOS, 10.8px Android
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
        height: 1.4,
      );

  static TextStyle get metadata => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(14),  // 14px iOS, 12.6px Android
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
        height: 1.4,
      );

  static TextStyle get overline => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(12),  // 12px iOS, 10.56px Android (was 10)
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
        height: 1.4,
        letterSpacing: 1.0,
      );

  // ===========================================================================
  // WHITE/ON-COLOR VARIANTS (for dark backgrounds)
  // ===========================================================================

  static TextStyle get headerWhite => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(24),  // 24px iOS, 21.6px Android
        fontWeight: FontWeight.w700,
        color: AppColors.textWhite,
        height: 1.2,
      );

  static TextStyle get headerWhiteMedium => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(20),  // 20px iOS, 18px Android
        fontWeight: FontWeight.w700,
        color: AppColors.textWhite,
        height: 1.3,
      );

  static TextStyle get headerWhiteSmall => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(18),  // 18px iOS, 16.2px Android
        fontWeight: FontWeight.w600,
        color: AppColors.textWhite,
        height: 1.4,
      );

  static TextStyle get bodyWhite => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(16),  // 16px iOS, 14.4px Android
        fontWeight: FontWeight.w400,
        color: AppColors.textWhite,
        height: 1.5,
      );

  static TextStyle get bodyWhiteLarge => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(17),  // 17px iOS, 15.3px Android
        fontWeight: FontWeight.w400,
        color: AppColors.textWhite,
        height: 1.6,
      );

  static TextStyle get subtitleWhite => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(16),  // 16px iOS, 14.4px Android
        fontWeight: FontWeight.w400,
        color: AppColors.textWhite90,
        height: 1.5,
      );

  static TextStyle get labelWhite => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(15),  // 15px iOS, 13.5px Android
        fontWeight: FontWeight.w600,
        color: AppColors.textWhite,
        height: 1.4,
      );

  static TextStyle get captionWhite => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(12),  // 12px iOS, 10.8px Android
        fontWeight: FontWeight.w400,
        color: AppColors.textWhite90,
        height: 1.4,
      );

  // ===========================================================================
  // CONTENT STYLES (from ContentConfig - for questions/solutions)
  // Per Typography Guidelines for Quiz/Question and Solution screens
  // ===========================================================================

  /// Question text style (main question display) - CRITICAL for readability
  /// Guideline: 18-20px
  static TextStyle get question => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(18),  // 18px iOS, 16.2px Android
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.6,
      );

  /// Option text style (multiple choice options)
  /// Guideline: 16px for answer options
  static TextStyle get option => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(16),  // 16px iOS, 14.4px Android
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  /// Solution section header style (Quick Explanation, Step-by-Step, etc.)
  /// Guideline: 17px semibold for section headers
  static TextStyle get solutionHeader => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(17),  // 17px iOS, 15.3px Android
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  /// Step/explanation text style
  /// Guideline: 16px for explanation body and step text
  static TextStyle get step => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(16),  // 16px iOS, 14.4px Android
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.6,
      );

  /// Explanation body text style
  /// Guideline: 16px for explanation body
  static TextStyle get explanationBody => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(16),  // 16px iOS, 14.4px Android
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.6,
      );

  /// Step number circle text style
  /// Guideline: 14px for step numbers
  static TextStyle get stepNumber => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(14),  // 14px iOS, 12.6px Android
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.0,
      );

  /// Final answer text style
  static TextStyle get finalAnswer => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(17),  // 17px iOS, 15.3px Android
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  /// Priya Ma'am header text style
  /// Guideline: 15px bold for "Priya Ma'am ✨"
  static TextStyle get priyaHeader => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(15),  // 15px iOS, 13.5px Android
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  /// Priya Ma'am message text style
  /// Guideline: 16px for message body
  static TextStyle get priyaMessage => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(16),  // 16px iOS, 14.4px Android
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  /// Priya's tip text style (legacy, kept for compatibility)
  static TextStyle get priyaTip => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(16),  // 16px iOS, 14.4px Android
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  // ===========================================================================
  // INPUT STYLES
  // ===========================================================================

  static TextStyle get input => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(16),  // 16px iOS, 14.4px Android
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get inputHint => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(16),  // 16px iOS, 14.4px Android
        fontWeight: FontWeight.w400,
        color: AppColors.textDisabled,
        height: 1.5,
      );

  static TextStyle get inputError => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(12),  // 12px iOS, 10.8px Android
        fontWeight: FontWeight.w400,
        color: AppColors.error,
        height: 1.4,
      );

  // ===========================================================================
  // NUMERIC STYLES (for stats, counts, scores)
  // ===========================================================================

  static TextStyle get numericLarge => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(32),  // 32px iOS, 28.8px Android
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.0,
      );

  static TextStyle get numericMedium => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(24),  // 24px iOS, 21.6px Android
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.0,
      );

  static TextStyle get numericSmall => GoogleFonts.inter(
        fontSize: PlatformSizing.fontSize(18),  // 18px iOS, 16.2px Android
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.0,
      );

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  /// Apply custom color to any text style
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Apply primary color
  static TextStyle primary(TextStyle style) {
    return style.copyWith(color: AppColors.primary);
  }

  /// Apply success color
  static TextStyle success(TextStyle style) {
    return style.copyWith(color: AppColors.success);
  }

  /// Apply error color
  static TextStyle error(TextStyle style) {
    return style.copyWith(color: AppColors.error);
  }

  /// Apply warning color
  static TextStyle warning(TextStyle style) {
    return style.copyWith(color: AppColors.warning);
  }

  /// Make text bold
  static TextStyle bold(TextStyle style) {
    return style.copyWith(fontWeight: FontWeight.w700);
  }

  /// Make text semi-bold
  static TextStyle semiBold(TextStyle style) {
    return style.copyWith(fontWeight: FontWeight.w600);
  }

  /// Make text medium weight
  static TextStyle medium(TextStyle style) {
    return style.copyWith(fontWeight: FontWeight.w500);
  }
}
