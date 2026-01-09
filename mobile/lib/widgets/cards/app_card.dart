/// AppCard - Reusable card component
///
/// A standardized card widget that follows JEEVibe design system.
/// Use for content containers, list items, sections, etc.
///
/// Example:
/// ```dart
/// AppCard(
///   child: Text('Card content'),
/// )
/// ```
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum AppCardVariant {
  /// Default: white background with shadow
  elevated,

  /// White background with border, no shadow
  outlined,

  /// Light purple/pink gradient background
  gradient,

  /// Success state (green tint)
  success,

  /// Error state (red tint)
  error,

  /// Warning state (amber tint)
  warning,

  /// Info state (blue tint)
  info,

  /// Flat card with no shadow or border
  flat,
}

class AppCard extends StatelessWidget {
  final Widget child;
  final AppCardVariant variant;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final double? borderRadius;
  final Color? backgroundColor;
  final bool isSelected;
  final Widget? header;
  final Widget? footer;

  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.elevated,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.isSelected = false,
    this.header,
    this.footer,
  });

  /// Creates a card optimized for list items
  factory AppCard.listItem({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets? padding,
    EdgeInsets? margin,
    Widget? leading,
    Widget? trailing,
    bool isSelected = false,
  }) {
    return AppCard(
      key: key,
      variant: AppCardVariant.outlined,
      onTap: onTap,
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      isSelected: isSelected,
      child: Row(
        children: [
          if (leading != null) ...[
            leading,
            const SizedBox(width: 12),
          ],
          Expanded(child: child),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing,
          ],
        ],
      ),
    );
  }

  /// Creates a card for displaying stats/metrics
  factory AppCard.stat({
    Key? key,
    required String label,
    required String value,
    IconData? icon,
    Color? iconColor,
    AppCardVariant variant = AppCardVariant.elevated,
  }) {
    return AppCard(
      key: key,
      variant: variant,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(
              icon,
              color: iconColor ?? AppColors.primary,
              size: 24,
            ),
          if (icon != null) const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double radius = borderRadius ?? AppRadius.lg;

    Widget cardContent = Container(
      margin: margin,
      decoration: _getDecoration(radius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) header!,
              Padding(
                padding: padding ?? const EdgeInsets.all(16),
                child: child,
              ),
              if (footer != null) footer!,
            ],
          ),
        ),
      ),
    );

    return cardContent;
  }

  BoxDecoration _getDecoration(double radius) {
    if (backgroundColor != null) {
      return BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: variant == AppCardVariant.elevated ? AppShadows.card : null,
        border: _getBorder(),
      );
    }

    switch (variant) {
      case AppCardVariant.elevated:
        return BoxDecoration(
          color: isSelected ? AppColors.cardLightPurple : AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: AppShadows.card,
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : Border.all(color: AppColors.borderLight, width: 1),
        );

      case AppCardVariant.outlined:
        return BoxDecoration(
          color: isSelected ? AppColors.cardLightPurple : AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : Border.all(color: AppColors.borderDefault, width: 1),
        );

      case AppCardVariant.gradient:
        return BoxDecoration(
          gradient: AppColors.priyaCardGradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: AppShadows.soft,
        );

      case AppCardVariant.success:
        return BoxDecoration(
          color: AppColors.successBackground,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.3),
            width: 1,
          ),
        );

      case AppCardVariant.error:
        return BoxDecoration(
          color: AppColors.errorBackground,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.3),
            width: 1,
          ),
        );

      case AppCardVariant.warning:
        return BoxDecoration(
          color: AppColors.warningBackground,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.3),
            width: 1,
          ),
        );

      case AppCardVariant.info:
        return BoxDecoration(
          color: AppColors.infoBackground,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: AppColors.info.withValues(alpha: 0.3),
            width: 1,
          ),
        );

      case AppCardVariant.flat:
        return BoxDecoration(
          color: isSelected ? AppColors.cardLightPurple : AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
        );
    }
  }

  Border? _getBorder() {
    if (isSelected) {
      return Border.all(color: AppColors.primary, width: 2);
    }
    return null;
  }
}

/// Gradient card specifically for Priya's tips
class PriyaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const PriyaCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.gradient,
      padding: padding,
      margin: margin,
      child: child,
    );
  }
}

/// Section card with a title header
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final AppCardVariant variant;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding,
    this.margin,
    this.variant = AppCardVariant.elevated,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: variant,
      margin: margin,
      padding: EdgeInsets.zero,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
