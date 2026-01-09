/// JEEVibe Theme Configuration
/// This file re-exports the consolidated design system for backward compatibility
/// and provides the app ThemeData.
///
/// NOTE: JVColors and JVStyles are DEPRECATED.
/// Use AppColors and AppTextStyles directly instead.
/// These aliases will be removed in a future version.

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

// =============================================================================
// DEPRECATED: JVColors - Use AppColors instead
// =============================================================================

@Deprecated('Use AppColors instead')
class JVColors {
  JVColors._();

  // Purple/Pink Palette - use AppColors.primary, etc.
  static const Color primary = AppColors.primary;
  static const Color primaryDark = AppColors.primaryDark;
  static const Color secondary = AppColors.secondary;

  // Backgrounds - use AppColors.background, etc.
  static const Color background = AppColors.background;
  static const Color surface = AppColors.surface;
  static const Color surfaceGrey = AppColors.surfaceGrey;

  // Typography Colors - use AppColors.textPrimary, etc.
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textTertiary = AppColors.textTertiary;

  // Functional Colors - use AppColors.error, etc.
  static const Color error = AppColors.error;
  static const Color warning = AppColors.warning;
  static const Color success = AppColors.success;
  static const Color divider = AppColors.divider;

  // Legacy/Compatibility
  static const Color primaryLight = AppColors.cardLightPurple;
  static const Color purple = AppColors.primary;
  static const Color accentPurple = AppColors.primary;

  // Gradients - use AppColors gradients
  static const LinearGradient primaryGradient = AppColors.ctaGradient;
  static const LinearGradient headerGradient = AppColors.headerGradient;
  static const LinearGradient priyaCardGradient = AppColors.priyaCardGradient;
  static const LinearGradient finalAnswerGradient = AppColors.finalAnswerGradient;
}

// =============================================================================
// DEPRECATED: JVStyles - Use AppTextStyles instead
// =============================================================================

@Deprecated('Use AppTextStyles instead')
class JVStyles {
  JVStyles._();

  // Typography - use AppTextStyles
  static TextStyle get h1 => AppTextStyles.h1;
  static TextStyle get h2 => AppTextStyles.h2;
  static TextStyle get h3 => AppTextStyles.h3;
  static TextStyle get bodyLarge => AppTextStyles.bodyLarge;
  static TextStyle get bodyMedium => AppTextStyles.bodyMedium;
  static TextStyle get bodySmall => AppTextStyles.bodySmall;
  static TextStyle get button => AppTextStyles.button;

  // Decorations
  static BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppRadius.borderRadiusLg,
    boxShadow: AppShadows.card,
    border: Border.all(color: AppColors.divider, width: 1),
  );
}

// =============================================================================
// APP THEME
// =============================================================================

class JVTheme {
  JVTheme._();

  static ThemeData get theme {
    return ThemeData(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.surface,
      ),

      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge,
        displayMedium: AppTextStyles.displayMedium,
        displaySmall: AppTextStyles.displaySmall,
        headlineLarge: AppTextStyles.headerLarge,
        headlineMedium: AppTextStyles.headerMedium,
        headlineSmall: AppTextStyles.headerSmall,
        titleLarge: AppTextStyles.h3,
        titleMedium: AppTextStyles.labelLarge,
        titleSmall: AppTextStyles.labelMedium,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.labelLarge,
        labelMedium: AppTextStyles.labelMedium,
        labelSmall: AppTextStyles.labelSmall,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.h3.copyWith(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.button.copyWith(color: AppColors.primary),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: AppTextStyles.labelMedium,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.divider),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        hintStyle: AppTextStyles.inputHint,
        errorStyle: AppTextStyles.inputError,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardLightPurple,
        labelStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.round),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: AppTextStyles.headerMedium,
        contentTextStyle: AppTextStyles.bodyMedium,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      useMaterial3: true,
    );
  }
}

// =============================================================================
// APP DECORATIONS (Common BoxDecoration presets)
// =============================================================================

class AppDecorations {
  AppDecorations._();

  /// Standard card decoration with shadow
  static BoxDecoration get card => BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderRadiusLg,
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.divider, width: 1),
      );

  /// Elevated card decoration
  static BoxDecoration get cardElevated => BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderRadiusLg,
        boxShadow: AppShadows.cardElevated,
      );

  /// Card with gradient background
  static BoxDecoration get gradientCard => BoxDecoration(
        gradient: AppColors.priyaCardGradient,
        borderRadius: AppRadius.borderRadiusLg,
        boxShadow: AppShadows.soft,
      );

  /// Primary button decoration
  static BoxDecoration get primaryButton => BoxDecoration(
        gradient: AppColors.ctaGradient,
        borderRadius: AppRadius.borderRadiusMd,
        boxShadow: AppShadows.button,
      );

  /// Outlined card decoration (no shadow)
  static BoxDecoration get cardOutlined => BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.all(color: AppColors.borderDefault, width: 1),
      );

  /// Success card decoration
  static BoxDecoration get cardSuccess => BoxDecoration(
        color: AppColors.successBackground,
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      );

  /// Error card decoration
  static BoxDecoration get cardError => BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      );

  /// Warning card decoration
  static BoxDecoration get cardWarning => BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      );

  /// Info card decoration
  static BoxDecoration get cardInfo => BoxDecoration(
        color: AppColors.infoBackground,
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      );
}
