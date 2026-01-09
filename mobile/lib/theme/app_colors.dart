/// JEEVibe Design System
/// Single source of truth for all design tokens
/// Based on Robinhood-inspired light theme
import 'package:flutter/material.dart';

// =============================================================================
// COLORS
// =============================================================================

class AppColors {
  AppColors._(); // Prevent instantiation

  // ---------------------------------------------------------------------------
  // Primary Colors
  // ---------------------------------------------------------------------------
  static const Color primary = Color(0xFF9333EA);
  static const Color primaryDark = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0xFFA855F7);
  static const Color secondary = Color(0xFFEC4899);
  static const Color secondaryDark = Color(0xFFDB2777);

  // Legacy aliases (for backward compatibility during migration)
  static const Color primaryPurple = primary;
  static const Color primaryPurpleDark = primaryDark;
  static const Color secondaryPink = secondary;
  static const Color purple500 = primaryLight;

  // ---------------------------------------------------------------------------
  // Background Colors
  // ---------------------------------------------------------------------------
  static const Color background = Color(0xFFFAF5FF);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceGrey = Color(0xFFF9FAFB);

  // Legacy aliases
  static const Color backgroundLight = background;
  static const Color cardWhite = surface;

  // ---------------------------------------------------------------------------
  // Card & Surface Colors
  // ---------------------------------------------------------------------------
  static const Color cardLightPurple = Color(0xFFF3E8FF);
  static const Color cardLightPink = Color(0xFFFCE7F3);
  static const Color cardLightGreen = Color(0xFFF0FDF4);
  static const Color cardLightBlue = Color(0xFFEFF6FF);
  static const Color cardLightAmber = Color(0xFFFEF3C7);

  // ---------------------------------------------------------------------------
  // Text Colors
  // ---------------------------------------------------------------------------
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textTertiary = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF9CA3AF);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textWhite90 = Color(0xE6FFFFFF); // 90% opacity

  // Legacy aliases
  static const Color textDark = textPrimary;
  static const Color textMedium = textSecondary;
  static const Color textLight = textTertiary;
  static const Color textGray = textDisabled;

  // ---------------------------------------------------------------------------
  // Border Colors
  // ---------------------------------------------------------------------------
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color borderDefault = Color(0xFFE5E7EB);
  static const Color borderMedium = Color(0xFFD1D5DB);
  static const Color borderFocus = primary;
  static const Color borderError = Color(0xFFEF4444);

  // Legacy aliases
  static const Color borderGray = borderDefault;
  static const Color divider = borderDefault;

  // ---------------------------------------------------------------------------
  // Semantic Colors - Success
  // ---------------------------------------------------------------------------
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF6EE7B7);
  static const Color successBackground = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF059669);

  // Legacy aliases
  static const Color successGreen = success;
  static const Color successGreenLight = successLight;

  // ---------------------------------------------------------------------------
  // Semantic Colors - Error
  // ---------------------------------------------------------------------------
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFF87171);
  static const Color errorBackground = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFDC2626);

  // Legacy aliases
  static const Color errorRed = error;
  static const Color errorRedLight = errorLight;

  // ---------------------------------------------------------------------------
  // Semantic Colors - Warning
  // ---------------------------------------------------------------------------
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningBackground = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFD97706);

  // Legacy alias
  static const Color warningAmber = warning;

  // ---------------------------------------------------------------------------
  // Semantic Colors - Info
  // ---------------------------------------------------------------------------
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF60A5FA);
  static const Color infoBackground = Color(0xFFDCEAFE);
  static const Color infoDark = Color(0xFF2563EB);

  // Legacy alias
  static const Color infoBlue = info;

  // ---------------------------------------------------------------------------
  // Subject Colors (for charts and results)
  // ---------------------------------------------------------------------------
  static const Color subjectPhysics = primary;
  static const Color subjectChemistry = Color(0xFF4CAF50);
  static const Color subjectMathematics = Color(0xFF2196F3);
  static const Color performanceOrange = Color(0xFFFF9800);

  // ---------------------------------------------------------------------------
  // Disabled State
  // ---------------------------------------------------------------------------
  static const Color disabled = Color(0xFFE5E7EB);
  static const Color disabledText = Color(0xFF9CA3AF);

  // ---------------------------------------------------------------------------
  // Gradients
  // ---------------------------------------------------------------------------
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient ctaGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient priyaCardGradient = LinearGradient(
    colors: [cardLightPurple, cardLightPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, backgroundWhite, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient finalAnswerGradient = LinearGradient(
    colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Welcome screen gradients
  static const LinearGradient welcomeScreen1Gradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient welcomeScreen2Gradient = LinearGradient(
    colors: [secondary, secondaryDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient welcomeScreen3Gradient = LinearGradient(
    colors: [warning, warningDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [errorDark, errorLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

// =============================================================================
// SPACING
// =============================================================================

class AppSpacing {
  AppSpacing._(); // Prevent instantiation

  // Base spacing values (4px grid)
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 40.0;
  static const double massive = 48.0;

  // Legacy aliases (for backward compatibility)
  static const double space4 = xs;
  static const double space8 = sm;
  static const double space12 = md;
  static const double space16 = lg;
  static const double space20 = xl;
  static const double space24 = xxl;
  static const double space32 = xxxl;
  static const double space40 = huge;
  static const double space48 = massive;

  // Common padding presets
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);
  static const EdgeInsets paddingXxl = EdgeInsets.all(xxl);

  // Legacy aliases
  static const EdgeInsets paddingSmall = paddingMd;
  static const EdgeInsets paddingMedium = paddingLg;
  static const EdgeInsets paddingLarge = paddingXl;
  static const EdgeInsets paddingXL = paddingXxl;

  // Screen padding
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: xxl);
  static const EdgeInsets screenPaddingCompact = EdgeInsets.symmetric(horizontal: lg);

  // Horizontal padding
  static EdgeInsets horizontalSm = const EdgeInsets.symmetric(horizontal: sm);
  static EdgeInsets horizontalMd = const EdgeInsets.symmetric(horizontal: md);
  static EdgeInsets horizontalLg = const EdgeInsets.symmetric(horizontal: lg);
  static EdgeInsets horizontalXl = const EdgeInsets.symmetric(horizontal: xl);
  static EdgeInsets horizontalXxl = const EdgeInsets.symmetric(horizontal: xxl);

  // Vertical padding
  static EdgeInsets verticalSm = const EdgeInsets.symmetric(vertical: sm);
  static EdgeInsets verticalMd = const EdgeInsets.symmetric(vertical: md);
  static EdgeInsets verticalLg = const EdgeInsets.symmetric(vertical: lg);
  static EdgeInsets verticalXl = const EdgeInsets.symmetric(vertical: xl);
  static EdgeInsets verticalXxl = const EdgeInsets.symmetric(vertical: xxl);

  // SizedBox helpers for gaps
  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl);
  static const SizedBox gapXxxl = SizedBox(height: xxxl);

  static const SizedBox gapHorizontalXs = SizedBox(width: xs);
  static const SizedBox gapHorizontalSm = SizedBox(width: sm);
  static const SizedBox gapHorizontalMd = SizedBox(width: md);
  static const SizedBox gapHorizontalLg = SizedBox(width: lg);
  static const SizedBox gapHorizontalXl = SizedBox(width: xl);
  static const SizedBox gapHorizontalXxl = SizedBox(width: xxl);
}

// =============================================================================
// RADIUS
// =============================================================================

class AppRadius {
  AppRadius._(); // Prevent instantiation

  // Border radius values
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double round = 100.0;

  // Legacy aliases
  static const double radiusSmall = sm;
  static const double radiusMedium = md;
  static const double radiusLarge = lg;
  static const double radiusXL = xl;
  static const double radiusRound = round;

  // BorderRadius presets
  static BorderRadius borderRadiusXs = BorderRadius.circular(xs);
  static BorderRadius borderRadiusSm = BorderRadius.circular(sm);
  static BorderRadius borderRadiusMd = BorderRadius.circular(md);
  static BorderRadius borderRadiusLg = BorderRadius.circular(lg);
  static BorderRadius borderRadiusXl = BorderRadius.circular(xl);
  static BorderRadius borderRadiusXxl = BorderRadius.circular(xxl);
  static BorderRadius borderRadiusRound = BorderRadius.circular(round);
}

// =============================================================================
// SHADOWS
// =============================================================================

class AppShadows {
  AppShadows._(); // Prevent instantiation

  // Card shadow (subtle)
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // Elevated card shadow
  static List<BoxShadow> get cardElevated => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 40,
          offset: const Offset(0, 10),
        ),
      ];

  // Button shadow with primary color
  static List<BoxShadow> get button => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  // Soft shadow
  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  // None (for consistency)
  static List<BoxShadow> get none => [];

  // Legacy aliases
  static List<BoxShadow> get cardShadow => card;
  static List<BoxShadow> get cardShadowElevated => cardElevated;
  static List<BoxShadow> get buttonShadow => button;
}

// =============================================================================
// ICON SIZES
// =============================================================================

class AppIconSizes {
  AppIconSizes._(); // Prevent instantiation

  static const double xs = 12.0;
  static const double sm = 16.0;
  static const double md = 20.0;
  static const double lg = 24.0;
  static const double xl = 28.0;
  static const double xxl = 32.0;
  static const double huge = 40.0;
  static const double massive = 48.0;

  // Specific use-case sizes
  static const double navIcon = lg;
  static const double actionIcon = md;
  static const double buttonIcon = md;
  static const double headerIcon = xxl;
}

// =============================================================================
// BUTTON SIZES
// =============================================================================

class AppButtonSizes {
  AppButtonSizes._(); // Prevent instantiation

  // Heights
  static const double heightSm = 36.0;
  static const double heightMd = 44.0;
  static const double heightLg = 52.0;
  static const double heightXl = 56.0;

  // Icon button sizes
  static const double iconButtonSm = 36.0;
  static const double iconButtonMd = 44.0;
  static const double iconButtonLg = 52.0;

  // Minimum touch target (accessibility)
  static const double minTouchTarget = 44.0;
}

// =============================================================================
// OPACITY VALUES
// =============================================================================

class AppOpacity {
  AppOpacity._(); // Prevent instantiation

  static const double full = 1.0;
  static const double disabled = 0.6;
  static const double hint = 0.5;
  static const double subtle = 0.4;
  static const double faint = 0.2;
  static const double barely = 0.1;
}

// =============================================================================
// ANIMATION DURATIONS
// =============================================================================

class AppDurations {
  AppDurations._(); // Prevent instantiation

  static const Duration fastest = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration slower = Duration(milliseconds: 500);
  static const Duration slowest = Duration(milliseconds: 600);
}

// =============================================================================
// BREAKPOINTS (for responsive design)
// =============================================================================

class AppBreakpoints {
  AppBreakpoints._(); // Prevent instantiation

  static const double mobile = 480.0;
  static const double tablet = 768.0;
  static const double desktop = 1024.0;
  static const double wide = 1280.0;
}
