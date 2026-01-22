/// AppIconButton - Reusable icon button component
///
/// A standardized icon button that follows JEEVibe design system.
/// Use for actions like back, close, menu, settings, etc.
///
/// Example:
/// ```dart
/// AppIconButton(
///   icon: Icons.arrow_back,
///   onPressed: () => Navigator.pop(context),
/// )
/// ```
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum AppIconButtonSize { small, medium, large }

enum AppIconButtonVariant {
  /// Default: transparent background
  ghost,

  /// Filled with primary gradient
  filled,

  /// White background with border
  outlined,

  /// Circular with light background
  circular,

  /// Semi-transparent white background for use on gradient headers
  glass,
}

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final AppIconButtonSize size;
  final AppIconButtonVariant variant;
  final Color? iconColor;
  final Color? backgroundColor;
  final String? tooltip;
  final bool isDisabled;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = AppIconButtonSize.medium,
    this.variant = AppIconButtonVariant.ghost,
    this.iconColor,
    this.backgroundColor,
    this.tooltip,
    this.isDisabled = false,
  });

  /// Creates a back button with standard styling
  /// Set [forGradientHeader] to true for the glass style on gradient backgrounds
  factory AppIconButton.back({
    Key? key,
    VoidCallback? onPressed,
    Color? color,
    AppIconButtonSize size = AppIconButtonSize.medium,
    bool forGradientHeader = false,
  }) {
    return AppIconButton(
      key: key,
      icon: Icons.arrow_back_ios_rounded,
      onPressed: onPressed,
      iconColor: color ?? Colors.white,
      size: size,
      variant: forGradientHeader ? AppIconButtonVariant.glass : AppIconButtonVariant.ghost,
      tooltip: 'Go back',
    );
  }

  /// Creates a close button with standard styling
  /// Set [forGradientHeader] to true for the glass style on gradient backgrounds
  factory AppIconButton.close({
    Key? key,
    VoidCallback? onPressed,
    Color? color,
    AppIconButtonSize size = AppIconButtonSize.medium,
    bool forGradientHeader = false,
  }) {
    return AppIconButton(
      key: key,
      icon: Icons.close_rounded,
      onPressed: onPressed,
      iconColor: color ?? (forGradientHeader ? Colors.white : AppColors.textSecondary),
      size: size,
      variant: forGradientHeader ? AppIconButtonVariant.glass : AppIconButtonVariant.ghost,
      tooltip: 'Close',
    );
  }

  /// Creates a menu button with standard styling
  factory AppIconButton.menu({
    Key? key,
    VoidCallback? onPressed,
    Color? color,
    AppIconButtonSize size = AppIconButtonSize.medium,
  }) {
    return AppIconButton(
      key: key,
      icon: Icons.menu_rounded,
      onPressed: onPressed,
      iconColor: color ?? AppColors.textPrimary,
      size: size,
      tooltip: 'Menu',
    );
  }

  /// Creates a settings button with standard styling
  factory AppIconButton.settings({
    Key? key,
    VoidCallback? onPressed,
    Color? color,
    AppIconButtonSize size = AppIconButtonSize.medium,
  }) {
    return AppIconButton(
      key: key,
      icon: Icons.settings_outlined,
      onPressed: onPressed,
      iconColor: color ?? AppColors.textSecondary,
      size: size,
      tooltip: 'Settings',
    );
  }

  /// Creates a more/options button with standard styling
  factory AppIconButton.more({
    Key? key,
    VoidCallback? onPressed,
    Color? color,
    AppIconButtonSize size = AppIconButtonSize.medium,
  }) {
    return AppIconButton(
      key: key,
      icon: Icons.more_vert_rounded,
      onPressed: onPressed,
      iconColor: color ?? AppColors.textSecondary,
      size: size,
      tooltip: 'More options',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = !isDisabled && onPressed != null;
    final double buttonSize = _getButtonSize();
    final double iconSize = _getIconSize();
    final Color effectiveIconColor = _getIconColor(isEnabled);
    final Color? effectiveBgColor = _getBackgroundColor(isEnabled);

    Widget button = AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isEnabled ? AppOpacity.full : AppOpacity.disabled,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: _getDecoration(isEnabled, effectiveBgColor),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onPressed : null,
            borderRadius: BorderRadius.circular(_getBorderRadius()),
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: effectiveIconColor,
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }

  double _getButtonSize() {
    switch (size) {
      case AppIconButtonSize.small:
        return AppButtonSizes.iconButtonSm;
      case AppIconButtonSize.medium:
        return AppButtonSizes.iconButtonMd;
      case AppIconButtonSize.large:
        return AppButtonSizes.iconButtonLg;
    }
  }

  double _getIconSize() {
    switch (size) {
      case AppIconButtonSize.small:
        return AppIconSizes.sm;
      case AppIconButtonSize.medium:
        return AppIconSizes.lg;
      case AppIconButtonSize.large:
        return AppIconSizes.xl;
    }
  }

  double _getBorderRadius() {
    switch (variant) {
      case AppIconButtonVariant.ghost:
        return AppRadius.sm;
      case AppIconButtonVariant.filled:
        return AppRadius.md;
      case AppIconButtonVariant.outlined:
        return AppRadius.md;
      case AppIconButtonVariant.circular:
        return AppRadius.round;
      case AppIconButtonVariant.glass:
        return AppRadius.md;
    }
  }

  Color _getIconColor(bool isEnabled) {
    if (iconColor != null) return iconColor!;

    if (!isEnabled) return AppColors.textDisabled;

    switch (variant) {
      case AppIconButtonVariant.ghost:
        return AppColors.textSecondary;
      case AppIconButtonVariant.filled:
        return Colors.white;
      case AppIconButtonVariant.outlined:
        return AppColors.primary;
      case AppIconButtonVariant.circular:
        return AppColors.primary;
      case AppIconButtonVariant.glass:
        return Colors.white;
    }
  }

  Color? _getBackgroundColor(bool isEnabled) {
    if (backgroundColor != null) return backgroundColor;

    if (!isEnabled) {
      switch (variant) {
        case AppIconButtonVariant.ghost:
          return null;
        case AppIconButtonVariant.filled:
          return AppColors.disabled;
        case AppIconButtonVariant.outlined:
          return AppColors.surface;
        case AppIconButtonVariant.circular:
          return AppColors.disabled;
        case AppIconButtonVariant.glass:
          return Colors.white.withValues(alpha: 0.1);
      }
    }

    switch (variant) {
      case AppIconButtonVariant.ghost:
        return null;
      case AppIconButtonVariant.filled:
        return null; // Uses gradient
      case AppIconButtonVariant.outlined:
        return AppColors.surface;
      case AppIconButtonVariant.circular:
        return AppColors.cardLightPurple;
      case AppIconButtonVariant.glass:
        return Colors.white.withValues(alpha: 0.2);
    }
  }

  BoxDecoration? _getDecoration(bool isEnabled, Color? bgColor) {
    switch (variant) {
      case AppIconButtonVariant.ghost:
        return null;
      case AppIconButtonVariant.filled:
        return BoxDecoration(
          gradient: isEnabled ? AppColors.ctaGradient : null,
          color: isEnabled ? null : AppColors.disabled,
          borderRadius: BorderRadius.circular(_getBorderRadius()),
          boxShadow: isEnabled ? AppShadows.soft : null,
        );
      case AppIconButtonVariant.outlined:
        return BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(_getBorderRadius()),
          border: Border.all(
            color: isEnabled ? AppColors.borderDefault : AppColors.disabled,
            width: 1,
          ),
        );
      case AppIconButtonVariant.circular:
        return BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        );
      case AppIconButtonVariant.glass:
        return BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(_getBorderRadius()),
        );
    }
  }
}

/// Floating Action Button variant
class AppFloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isExtended;
  final String? label;
  final bool mini;

  const AppFloatingButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.isExtended = false,
    this.label,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isExtended && label != null) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: Icon(icon),
        label: Text(label!),
        tooltip: tooltip,
      );
    }

    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      mini: mini,
      tooltip: tooltip,
      child: Icon(icon),
    );
  }
}
