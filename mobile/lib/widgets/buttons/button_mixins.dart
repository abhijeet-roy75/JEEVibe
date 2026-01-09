/// Button Mixins - Shared helper methods for button components
///
/// Provides common sizing and styling logic for GradientButton,
/// AppOutlinedButton, and AppTextButton.
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Size enum used by all button types
enum ButtonSize { small, medium, large }

/// Mixin providing shared sizing logic for buttons
mixin ButtonSizeMixin {
  /// Gets the button height for a given size
  double getButtonHeight(ButtonSize size) {
    switch (size) {
      case ButtonSize.small:
        return AppButtonSizes.heightSm;
      case ButtonSize.medium:
        return AppButtonSizes.heightMd;
      case ButtonSize.large:
        return AppButtonSizes.heightLg;
    }
  }

  /// Gets the border radius for a given size
  double getButtonBorderRadius(ButtonSize size) {
    switch (size) {
      case ButtonSize.small:
        return AppRadius.sm;
      case ButtonSize.medium:
        return AppRadius.md;
      case ButtonSize.large:
        return AppRadius.md;
    }
  }

  /// Gets the text style for a given size
  dynamic getButtonTextStyle(ButtonSize size) {
    switch (size) {
      case ButtonSize.small:
        return AppTextStyles.buttonSmall;
      case ButtonSize.medium:
        return AppTextStyles.buttonMedium;
      case ButtonSize.large:
        return AppTextStyles.buttonLarge;
    }
  }

  /// Gets the icon size for a given size
  double getButtonIconSize(ButtonSize size) {
    switch (size) {
      case ButtonSize.small:
        return 16;
      case ButtonSize.medium:
        return 20;
      case ButtonSize.large:
        return 24;
    }
  }

  /// Gets the icon spacing for a given size
  double getButtonIconSpacing(ButtonSize size) {
    switch (size) {
      case ButtonSize.small:
        return 6;
      case ButtonSize.medium:
        return 8;
      case ButtonSize.large:
        return 10;
    }
  }
}

/// Extension to convert between GradientButtonSize and ButtonSize
/// This allows backward compatibility during migration
extension GradientButtonSizeExtension on ButtonSize {
  /// Convert to the legacy GradientButtonSize enum
  /// Use this during migration period
  static ButtonSize fromLegacy(dynamic legacySize) {
    final name = legacySize.toString().split('.').last;
    switch (name) {
      case 'small':
        return ButtonSize.small;
      case 'medium':
        return ButtonSize.medium;
      case 'large':
      default:
        return ButtonSize.large;
    }
  }
}
