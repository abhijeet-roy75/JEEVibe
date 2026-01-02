/// JEEVibe Light Theme Color System
/// Based on Robinhood-inspired design
import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primaryPurple = Color(0xFF9333EA);
  static const Color primaryPurpleDark = Color(0xFF7C3AED);
  static const Color secondaryPink = Color(0xFFEC4899);
  static const Color purple500 = Color(0xFFA855F7);

  // Background Colors
  static const Color backgroundLight = Color(0xFFFAF5FF); // Light purple
  static const Color backgroundWhite = Color(0xFFFFFFFF);

  // Card & Surface Colors
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color cardLightPurple = Color(0xFFF3E8FF);
  static const Color cardLightPink = Color(0xFFFCE7F3);

  // Text Colors
  static const Color textDark = Color(0xFF1F2937); // Headings
  static const Color textMedium = Color(0xFF4B5563); // Body text
  static const Color textLight = Color(0xFF6B7280); // Secondary text
  static const Color textGray = Color(0xFF9CA3AF); // Disabled/placeholder

  // Border Colors
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color borderGray = Color(0xFFE5E7EB);
  static const Color borderMedium = Color(0xFFD1D5DB);

  // Semantic Colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color successGreenLight = Color(0xFF6EE7B7);
  static const Color successBackground = Color(0xFFD1FAE5);

  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorRedLight = Color(0xFFF87171);
  static const Color errorBackground = Color(0xFFFEE2E2);

  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color warningBackground = Color(0xFFFEF3C7);

  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color infoBackground = Color(0xFFDCEAFE);

  // Subject-specific colors (for results/charts)
  static const Color subjectPhysics = primaryPurple; // Reuse primary purple
  static const Color subjectChemistry = Color(0xFF4CAF50); // Green
  static const Color subjectMathematics = Color(0xFF2196F3); // Blue
  static const Color performanceOrange = Color(0xFFFF9800); // Orange for medium performance

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, purple500],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient ctaGradient = LinearGradient(
    colors: [primaryPurple, secondaryPink],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient priyaCardGradient = LinearGradient(
    colors: [cardLightPurple, cardLightPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [backgroundLight, backgroundWhite, backgroundLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.5, 1.0],
  );

  // Welcome screen gradients
  static const LinearGradient welcomeScreen1Gradient = LinearGradient(
    colors: [primaryPurple, purple500],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient welcomeScreen2Gradient = LinearGradient(
    colors: [secondaryPink, Color(0xFFDB2777)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient welcomeScreen3Gradient = LinearGradient(
    colors: [warningAmber, Color(0xFFD97706)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Error screen gradient (for OCR failed)
  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFF87171)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppSpacing {
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;

  static const EdgeInsets paddingSmall = EdgeInsets.all(12);
  static const EdgeInsets paddingMedium = EdgeInsets.all(16);
  static const EdgeInsets paddingLarge = EdgeInsets.all(20);
  static const EdgeInsets paddingXL = EdgeInsets.all(24);

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 24);
}

class AppRadius {
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusRound = 100.0;
}

class AppShadows {
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get cardShadowElevated => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 40,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: AppColors.primaryPurple.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}

