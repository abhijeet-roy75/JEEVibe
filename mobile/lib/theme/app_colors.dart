/// JEEVibe Design System
/// Single source of truth for all design tokens
/// Based on Robinhood-inspired light theme
import 'package:flutter/material.dart';
import 'app_platform_sizing.dart';

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

  // Base spacing values (4px grid) - Platform-adaptive
  static double get xxs => PlatformSizing.spacing(2.5);   // 2.5px iOS, 2.0px Android (meets 2px minimum)
  static double get xs => PlatformSizing.spacing(4.0);    // 4.0px iOS, 3.2px Android
  static double get sm => PlatformSizing.spacing(8.0);    // 8.0px iOS, 6.8px Android
  static double get md => PlatformSizing.spacing(12.0);   // 12px iOS, 10.2px Android
  static double get lg => PlatformSizing.spacing(16.0);   // 16px iOS, 13.6px Android
  static double get xl => PlatformSizing.spacing(20.0);   // 20px iOS, 17px Android
  static double get xxl => PlatformSizing.spacing(24.0);  // 24px iOS, 20.4px Android
  static double get xxxl => PlatformSizing.spacing(32.0); // 32px iOS, 27.2px Android
  static double get huge => PlatformSizing.spacing(40.0); // 40px iOS, 34px Android
  static double get massive => PlatformSizing.spacing(48.0); // 48px iOS, 40.8px Android

  // Legacy aliases (for backward compatibility)
  static double get space4 => xs;
  static double get space8 => sm;
  static double get space12 => md;
  static double get space16 => lg;
  static double get space20 => xl;
  static double get space24 => xxl;
  static double get space32 => xxxl;
  static double get space40 => huge;
  static double get space48 => massive;

  // Common padding presets - Platform-adaptive
  static EdgeInsets get paddingXs => EdgeInsets.all(xs);
  static EdgeInsets get paddingSm => EdgeInsets.all(sm);
  static EdgeInsets get paddingMd => EdgeInsets.all(md);
  static EdgeInsets get paddingLg => EdgeInsets.all(lg);
  static EdgeInsets get paddingXl => EdgeInsets.all(xl);
  static EdgeInsets get paddingXxl => EdgeInsets.all(xxl);

  // Legacy aliases
  static EdgeInsets get paddingSmall => paddingMd;
  static EdgeInsets get paddingMedium => paddingLg;
  static EdgeInsets get paddingLarge => paddingXl;
  static EdgeInsets get paddingXL => paddingXxl;

  // Screen padding
  static EdgeInsets get screenPadding => EdgeInsets.symmetric(horizontal: xxl);
  static EdgeInsets get screenPaddingCompact => EdgeInsets.symmetric(horizontal: lg);

  // Horizontal padding
  static EdgeInsets get horizontalSm => EdgeInsets.symmetric(horizontal: sm);
  static EdgeInsets get horizontalMd => EdgeInsets.symmetric(horizontal: md);
  static EdgeInsets get horizontalLg => EdgeInsets.symmetric(horizontal: lg);
  static EdgeInsets get horizontalXl => EdgeInsets.symmetric(horizontal: xl);
  static EdgeInsets get horizontalXxl => EdgeInsets.symmetric(horizontal: xxl);

  // Vertical padding
  static EdgeInsets get verticalSm => EdgeInsets.symmetric(vertical: sm);
  static EdgeInsets get verticalMd => EdgeInsets.symmetric(vertical: md);
  static EdgeInsets get verticalLg => EdgeInsets.symmetric(vertical: lg);
  static EdgeInsets get verticalXl => EdgeInsets.symmetric(vertical: xl);
  static EdgeInsets get verticalXxl => EdgeInsets.symmetric(vertical: xxl);

  // SizedBox helpers for gaps - Platform-adaptive
  static SizedBox get gapXs => SizedBox(height: xs);
  static SizedBox get gapSm => SizedBox(height: sm);
  static SizedBox get gapMd => SizedBox(height: md);
  static SizedBox get gapLg => SizedBox(height: lg);
  static SizedBox get gapXl => SizedBox(height: xl);
  static SizedBox get gapXxl => SizedBox(height: xxl);
  static SizedBox get gapXxxl => SizedBox(height: xxxl);

  static SizedBox get gapHorizontalXs => SizedBox(width: xs);
  static SizedBox get gapHorizontalSm => SizedBox(width: sm);
  static SizedBox get gapHorizontalMd => SizedBox(width: md);
  static SizedBox get gapHorizontalLg => SizedBox(width: lg);
  static SizedBox get gapHorizontalXl => SizedBox(width: xl);
  static SizedBox get gapHorizontalXxl => SizedBox(width: xxl);
}

// =============================================================================
// RADIUS
// =============================================================================

class AppRadius {
  AppRadius._(); // Prevent instantiation

  // Border radius values - Platform-adaptive
  static double get xs => PlatformSizing.radius(4.0);    // 4.0px iOS, 3.4px Android
  static double get sm => PlatformSizing.radius(8.0);    // 8.0px iOS, 6.8px Android
  static double get md => PlatformSizing.radius(12.0);   // 12px iOS, 10.2px Android
  static double get lg => PlatformSizing.radius(16.0);   // 16px iOS, 13.6px Android
  static double get xl => PlatformSizing.radius(20.0);   // 20px iOS, 17px Android
  static double get xxl => PlatformSizing.radius(24.0);  // 24px iOS, 20.4px Android
  static double get round => PlatformSizing.radius(100.0); // 100px iOS, 85px Android

  // Legacy aliases
  static double get radiusSmall => sm;
  static double get radiusMedium => md;
  static double get radiusLarge => lg;
  static double get radiusXL => xl;
  static double get radiusRound => round;

  // BorderRadius presets
  static BorderRadius get borderRadiusXs => BorderRadius.circular(xs);
  static BorderRadius get borderRadiusSm => BorderRadius.circular(sm);
  static BorderRadius get borderRadiusMd => BorderRadius.circular(md);
  static BorderRadius get borderRadiusLg => BorderRadius.circular(lg);
  static BorderRadius get borderRadiusXl => BorderRadius.circular(xl);
  static BorderRadius get borderRadiusXxl => BorderRadius.circular(xxl);
  static BorderRadius get borderRadiusRound => BorderRadius.circular(round);
}

// =============================================================================
// SHADOWS
// =============================================================================

class AppShadows {
  AppShadows._(); // Prevent instantiation

  // Card shadow (subtle)
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
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

  // Platform-adaptive icon sizes
  static double get xs => PlatformSizing.iconSize(12.0);      // 12px iOS, 10.8px Android
  static double get sm => PlatformSizing.iconSize(16.0);      // 16px iOS, 14.4px Android
  static double get md => PlatformSizing.iconSize(20.0);      // 20px iOS, 18px Android
  static double get lg => PlatformSizing.iconSize(24.0);      // 24px iOS, 21.6px Android
  static double get xl => PlatformSizing.iconSize(28.0);      // 28px iOS, 25.2px Android
  static double get xxl => PlatformSizing.iconSize(32.0);     // 32px iOS, 28.8px Android
  static double get huge => PlatformSizing.iconSize(40.0);    // 40px iOS, 36px Android
  static double get massive => PlatformSizing.iconSize(48.0); // 48px iOS, 43.2px Android

  // Specific use-case sizes
  static double get navIcon => lg;
  static double get actionIcon => md;
  static double get buttonIcon => md;
  static double get headerIcon => xxl;
}

// =============================================================================
// BUTTON SIZES
// =============================================================================

class AppButtonSizes {
  AppButtonSizes._(); // Prevent instantiation

  // Heights - Platform-adaptive (Material 3 compliant on Android)
  static double get heightSm => PlatformSizing.buttonHeight(36.0);  // 36px iOS, 36px Android
  static double get heightMd => PlatformSizing.buttonHeight(44.0);  // 44px iOS, 44px Android
  static double get heightLg => PlatformSizing.buttonHeight(52.0);  // 52px iOS, 48px Android
  static double get heightXl => PlatformSizing.buttonHeight(56.0);  // 56px iOS, 48px Android

  // Icon button sizes - Platform-adaptive
  static double get iconButtonSm => PlatformSizing.buttonHeight(36.0);  // 36px iOS, 36px Android
  static double get iconButtonMd => PlatformSizing.buttonHeight(44.0);  // 44px iOS, 44px Android
  static double get iconButtonLg => PlatformSizing.buttonHeight(52.0);  // 52px iOS, 48px Android

  // Minimum touch target (accessibility) - constant across platforms
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
