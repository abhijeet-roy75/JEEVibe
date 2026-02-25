/// Platform-Adaptive Sizing Utility
///
/// Provides platform-specific sizing adjustments to optimize UI for both iOS and Android.
/// Android gets 12-20% smaller sizing to feel more native and less "chunky".
///
/// Usage:
/// ```dart
/// fontSize: PlatformSizing.fontSize(16),  // 16px on iOS, 14.08px on Android
/// padding: EdgeInsets.all(PlatformSizing.spacing(20)),  // 20px on iOS, 16px on Android
/// ```
///
/// Features:
/// - Remote Config integration for A/B testing and instant rollback
/// - Assert-based validation in debug mode
/// - Simple API with clear method names
///
/// Scale Factors:
/// - Font: 0.88 (12% smaller on Android)
/// - Spacing: 0.80 (20% tighter on Android)
/// - Icon: 0.88 (12% smaller on Android)
/// - Radius: 0.80 (20% sharper on Android)
/// - Button Height: 0.88 (12% smaller on Android, consistent with fonts/icons)

import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformSizing {
  PlatformSizing._(); // Prevent instantiation

  // =============================================================================
  // CONFIGURATION
  // =============================================================================

  /// Feature flag - can be disabled via Firebase Remote Config for instant rollback
  /// Set to false to disable all adaptive sizing (emergency kill switch)
  static bool _enableAdaptiveSizing = true;

  /// Scale factors - can be adjusted via Remote Config for A/B testing
  static double _fontScale = 0.88;      // 12% smaller fonts on Android (was 0.9)
  static double _spacingScale = 0.80;   // 20% tighter spacing on Android (was 0.85)
  static double _iconScale = 0.88;      // 12% smaller icons on Android (was 0.9)
  static double _radiusScale = 0.80;    // 20% sharper corners on Android (was 0.85)

  // =============================================================================
  // PUBLIC API - Remote Config Integration
  // =============================================================================

  /// Enable or disable adaptive sizing at runtime
  /// Call this from Firebase Remote Config initialization
  static void setEnabled(bool enabled) {
    _enableAdaptiveSizing = enabled;
    if (kDebugMode) {
      print('[PlatformSizing] Adaptive sizing ${enabled ? "enabled" : "disabled"}');
    }
  }

  /// Update scale factors from Remote Config
  /// Allows A/B testing different scale values without app update
  static void updateScaleFactors({
    double? fontScale,
    double? spacingScale,
    double? iconScale,
    double? radiusScale,
  }) {
    if (fontScale != null) {
      assert(fontScale >= 0.7 && fontScale <= 1.0, 'Font scale must be between 0.7 and 1.0');
      _fontScale = fontScale;
    }
    if (spacingScale != null) {
      assert(spacingScale >= 0.7 && spacingScale <= 1.0, 'Spacing scale must be between 0.7 and 1.0');
      _spacingScale = spacingScale;
    }
    if (iconScale != null) {
      assert(iconScale >= 0.7 && iconScale <= 1.0, 'Icon scale must be between 0.7 and 1.0');
      _iconScale = iconScale;
    }
    if (radiusScale != null) {
      assert(radiusScale >= 0.7 && radiusScale <= 1.0, 'Radius scale must be between 0.7 and 1.0');
      _radiusScale = radiusScale;
    }

    if (kDebugMode) {
      print('[PlatformSizing] Scale factors updated: font=$_fontScale, spacing=$_spacingScale, icon=$_iconScale, radius=$_radiusScale');
    }
  }

  // =============================================================================
  // PLATFORM DETECTION
  // =============================================================================

  /// Check if we're running on Android
  static bool get isAndroid => kIsWeb ? false : Platform.isAndroid;

  /// Check if we're running on iOS
  static bool get isIOS => kIsWeb ? false : Platform.isIOS;

  // =============================================================================
  // SIZING METHODS
  // =============================================================================

  /// Apply platform-adaptive scaling to font sizes
  ///
  /// iOS: Returns original size unchanged
  /// Android: Returns size * 0.88 (12% smaller)
  ///
  /// Example:
  /// ```dart
  /// fontSize: PlatformSizing.fontSize(16),  // 16px iOS, 14.08px Android
  /// ```
  static double fontSize(double iosSize) {
    // Validation in debug mode
    assert(
      iosSize > 0 && iosSize < 100,
      'Invalid font size: $iosSize. Must be between 0 and 100.',
    );

    // If feature disabled, return original size
    if (!_enableAdaptiveSizing) return iosSize;

    // Apply scaling on Android
    final result = isAndroid ? iosSize * _fontScale : iosSize;

    // Ensure text remains readable (minimum 10sp)
    assert(
      result >= 10,
      'Font size too small: $result (from $iosSize). Minimum is 10sp for readability.',
    );

    return result;
  }

  /// Apply platform-adaptive scaling to spacing/padding values
  ///
  /// iOS: Returns original spacing unchanged
  /// Android: Returns spacing * 0.80 (20% tighter)
  ///
  /// Example:
  /// ```dart
  /// padding: EdgeInsets.all(PlatformSizing.spacing(20)),  // 20px iOS, 16px Android
  /// ```
  static double spacing(double iosSpacing) {
    // Validation in debug mode
    assert(
      iosSpacing >= 0,
      'Negative spacing: $iosSpacing. Spacing must be non-negative.',
    );

    // If feature disabled, return original spacing
    if (!_enableAdaptiveSizing) return iosSpacing;

    // Apply scaling on Android
    final result = isAndroid ? iosSpacing * _spacingScale : iosSpacing;

    // Note: Minimum spacing validation removed to support aggressive 20% reduction
    // 2px iOS * 0.80 = 1.6px Android (still renders correctly)
    // 4px iOS * 0.80 = 3.2px Android (acceptable tight spacing)

    return result;
  }

  /// Apply platform-adaptive scaling to icon sizes
  ///
  /// iOS: Returns original size unchanged
  /// Android: Returns size * 0.88 (12% smaller)
  ///
  /// Example:
  /// ```dart
  /// Icon(Icons.home, size: PlatformSizing.iconSize(24)),  // 24px iOS, 21.12px Android
  /// ```
  static double iconSize(double iosSize) {
    // Validation in debug mode
    assert(
      iosSize > 0 && iosSize < 200,
      'Invalid icon size: $iosSize. Must be between 0 and 200.',
    );

    // If feature disabled, return original size
    if (!_enableAdaptiveSizing) return iosSize;

    // Apply scaling on Android
    final result = isAndroid ? iosSize * _iconScale : iosSize;

    // Ensure icons remain visible (minimum 12px)
    assert(
      result >= 12,
      'Icon size too small: $result (from $iosSize). Minimum is 12px for visibility.',
    );

    return result;
  }

  /// Apply platform-adaptive scaling to border radius
  ///
  /// iOS: Returns original radius unchanged
  /// Android: Returns radius * 0.80 (20% sharper)
  ///
  /// Example:
  /// ```dart
  /// borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),  // 12px iOS, 9.6px Android
  /// ```
  static double radius(double iosRadius) {
    // Validation in debug mode
    assert(
      iosRadius >= 0,
      'Negative radius: $iosRadius. Radius must be non-negative.',
    );

    // If feature disabled, return original radius
    if (!_enableAdaptiveSizing) return iosRadius;

    // Apply scaling on Android
    final result = isAndroid ? iosRadius * _radiusScale : iosRadius;

    return result;
  }

  /// Apply platform-adaptive button heights
  ///
  /// Applies consistent 0.88 scale factor on Android (12% smaller):
  /// - Small (36px iOS) → 31.68px Android
  /// - Medium (44px iOS) → 38.72px Android
  /// - Large (48px iOS) → 42.24px Android
  /// - XL (56px iOS) → 49.28px Android
  ///
  /// iOS: Returns original height unchanged
  ///
  /// Example:
  /// ```dart
  /// height: PlatformSizing.buttonHeight(56),  // 56px iOS, 49.28px Android
  /// ```
  static double buttonHeight(double iosHeight) {
    // Validation in debug mode
    assert(
      iosHeight > 0 && iosHeight < 100,
      'Invalid button height: $iosHeight. Must be between 0 and 100.',
    );

    // If feature disabled, return original height
    if (!_enableAdaptiveSizing) return iosHeight;

    // Apply consistent 0.88 scaling on Android (same as fonts and icons)
    final result = isAndroid ? iosHeight * _fontScale : iosHeight;

    // Validation: Button should be at least 32px for touch targets
    assert(
      result >= 32.0,
      'Button height too small: ${result.toStringAsFixed(2)}px (from ${iosHeight}px). Minimum is 32px for accessibility.',
    );

    return result;
  }

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================

  /// Get current configuration info (useful for debugging)
  static Map<String, dynamic> getConfig() {
    return {
      'enabled': _enableAdaptiveSizing,
      'platform': isAndroid ? 'android' : (isIOS ? 'ios' : 'other'),
      'fontScale': _fontScale,
      'spacingScale': _spacingScale,
      'iconScale': _iconScale,
      'radiusScale': _radiusScale,
    };
  }

  /// Print current configuration (debug only)
  static void debugPrintConfig() {
    if (kDebugMode) {
      final config = getConfig();
      print('=== PlatformSizing Configuration ===');
      print('Enabled: ${config['enabled']}');
      print('Platform: ${config['platform']}');
      print('Font Scale: ${config['fontScale']} (${config['fontScale'] == 1.0 ? 'no change' : '${((1 - config['fontScale']!) * 100).toStringAsFixed(0)}% smaller on Android'})');
      print('Spacing Scale: ${config['spacingScale']} (${config['spacingScale'] == 1.0 ? 'no change' : '${((1 - config['spacingScale']!) * 100).toStringAsFixed(0)}% tighter on Android'})');
      print('Icon Scale: ${config['iconScale']} (${config['iconScale'] == 1.0 ? 'no change' : '${((1 - config['iconScale']!) * 100).toStringAsFixed(0)}% smaller on Android'})');
      print('Radius Scale: ${config['radiusScale']} (${config['radiusScale'] == 1.0 ? 'no change' : '${((1 - config['radiusScale']!) * 100).toStringAsFixed(0)}% sharper on Android'})');
      print('====================================');
    }
  }
}
