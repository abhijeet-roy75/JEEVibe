import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class JVColors {
  // Purple/Pink Palette
  static const Color primary = Color(0xFF9333EA); // Purple-600
  static const Color primaryDark = Color(0xFF7E22CE); // Purple-700
  static const Color secondary = Color(0xFFEC4899); // Pink-500
  
  // Backgrounds
  static const Color background = Color(0xFFFAF5FF); // Purple-50
  static const Color surface = Colors.white;
  static const Color surfaceGrey = Color(0xFFF9FAFB); // Gray-50
  
  // Typography Colors
  static const Color textPrimary = Color(0xFF1F2937); // Gray-800
  static const Color textSecondary = Color(0xFF4B5563); // Gray-600
  static const Color textTertiary = Color(0xFF9CA3AF); // Gray-400
  
  // Functional Colors
  static const Color error = Color(0xFFEF4444); // Red-500
  static const Color warning = Color(0xFFF59E0B); // Amber-500
  static const Color success = Color(0xFF10B981); // Emerald-500
  static const Color divider = Color(0xFFE5E7EB); // Gray-200
  
  // Legacy/Compatibility
  static const Color primaryLight = Color(0xFFF3E8FF); // Purple-100
  static const Color purple = primary;
  static const Color accentPurple = primary;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF9333EA), Color(0xFFEC4899)], // Purple to Pink
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF9333EA), Color(0xFFA855F7)], // Purple-600 to Purple-500
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient priyaCardGradient = LinearGradient(
    colors: [Color(0xFFF3E8FF), Color(0xFFFCE7F3)], // Purple-100 to Pink-100
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient finalAnswerGradient = LinearGradient(
    colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)], // Green-50 to Emerald-50
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class JVStyles {
  // Typography - Inter
  static TextStyle get h1 => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: JVColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get h2 => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: JVColors.textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle get h3 => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: JVColors.textPrimary,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: JVColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: JVColors.textSecondary,
    height: 1.5,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: JVColors.textTertiary,
  );

  static TextStyle get button => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // Decorations
  static BoxDecoration cardDecoration = BoxDecoration(
    color: JVColors.surface,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
    border: Border.all(color: JVColors.divider, width: 1),
  );
}

class JVTheme {
  static ThemeData get theme {
    return ThemeData(
      primaryColor: JVColors.primary,
      scaffoldBackgroundColor: JVColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: JVColors.primary,
        primary: JVColors.primary,
        secondary: JVColors.secondary,
        error: JVColors.error,
        surface: JVColors.surface,
        background: JVColors.background,
      ),
      
      textTheme: TextTheme(
        displayLarge: JVStyles.h1,
        displayMedium: JVStyles.h2,
        titleLarge: JVStyles.h3,
        bodyLarge: JVStyles.bodyLarge,
        bodyMedium: JVStyles.bodyMedium,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: JVStyles.h3.copyWith(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: JVColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: JVColors.primary.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: JVStyles.button,
        ),
      ),

      cardTheme: CardThemeData(
        color: JVColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: JVColors.divider),
        ),
        margin: EdgeInsets.zero,
      ),
      
      useMaterial3: true,
    );
  }
}
