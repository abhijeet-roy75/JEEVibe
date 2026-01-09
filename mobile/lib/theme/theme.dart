/// JEEVibe Design System
/// Barrel file for easy importing of all theme-related classes
///
/// Usage:
/// ```dart
/// import 'package:jeevibe_mobile/theme/theme.dart';
/// ```
///
/// This gives you access to:
/// - AppColors (colors, gradients)
/// - AppSpacing (spacing values, padding presets, gaps)
/// - AppRadius (border radius values and presets)
/// - AppShadows (shadow presets)
/// - AppIconSizes (icon size values)
/// - AppButtonSizes (button height values)
/// - AppDurations (animation durations)
/// - AppBreakpoints (responsive breakpoints)
/// - AppTextStyles (typography)
/// - AppDecorations (common BoxDecoration presets)
/// - JVTheme (app ThemeData)
///
/// DEPRECATED classes (still available for backward compatibility):
/// - JVColors -> use AppColors instead
/// - JVStyles -> use AppTextStyles instead

library theme;

export 'app_colors.dart';
export 'app_text_styles.dart';
export 'jeevibe_theme.dart';
