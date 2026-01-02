import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Shared header component for consistent sizing across all screens
/// Reduced by ~50% from original sizes for better content space
class AppHeader extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final Widget? centerContent; // For icons, progress circles, etc.
  final double topPadding;
  final double bottomPadding;
  final bool showGradient;
  final Gradient? gradient; // Custom gradient override

  const AppHeader({
    Key? key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.centerContent,
    this.topPadding = 24, // Reduced from 48
    this.bottomPadding = 16, // Reduced from 32 (default)
    this.showGradient = true,
    this.gradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(0, topPadding, 0, bottomPadding),
      decoration: showGradient
          ? BoxDecoration(
              gradient: gradient ?? AppColors.primaryGradient,
            )
          : null,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top bar (leading, title, trailing)
            if (leading != null || title != null || trailing != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Leading and trailing on sides
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        leading ?? const SizedBox.shrink(),
                        trailing ?? const SizedBox.shrink(),
                      ],
                    ),
                    // Title centered
                    if (title != null) 
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width - 120, // Leave space for buttons
                          ),
                          child: title!,
                        ),
                      ),
                  ],
                ),
              ),

            // Center content (icons, progress circles, etc.)
            if (centerContent != null) ...[
              SizedBox(height: leading != null || title != null ? 8 : 0), // Further reduced from 12
              centerContent!,
            ],

            // Subtitle
            if (subtitle != null) ...[
              SizedBox(height: centerContent != null ? 4 : 0), // Further reduced from 8
              subtitle!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Helper widget for header with icon and text (common pattern)
class AppHeaderWithIcon extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color iconColor;
  final double iconSize;
  final VoidCallback? onClose;
  final Widget? trailing;
  final Widget? customCenterContent; // For custom center widgets (like target icon)
  final double bottomPadding; // Allow custom bottom padding

  const AppHeaderWithIcon({
    Key? key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor = Colors.white,
    this.iconSize = 48, // Reduced from 64
    this.onClose,
    this.trailing,
    this.customCenterContent,
    this.bottomPadding = 16, // Default reduced from 32
    this.gradient,
    this.leadingIcon = Icons.close,
  }) : super(key: key);

  final Gradient? gradient;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    return AppHeader(
      leading: onClose != null
          ? IconButton(
              icon: Icon(leadingIcon, color: Colors.white),
              onPressed: onClose,
            )
          : null,
      centerContent: customCenterContent ??
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: iconSize * 0.5, // Icon is 50% of container
            ),
          ),
      title: title.isNotEmpty
          ? Text(
              title,
              style: AppTextStyles.headerWhite.copyWith(fontSize: 20), // Reduced from 24
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      subtitle: subtitle != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                subtitle!,
                style: AppTextStyles.bodyWhite.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13, // Slightly smaller subtitle
                ),
                textAlign: TextAlign.center,
              ),
            )
          : null,
      trailing: trailing,
      bottomPadding: bottomPadding,
      topPadding: 20, // Reduced from default 24 for more compact header
      gradient: gradient,
    );
  }
}

/// Helper widget for header with progress circle (for quiz screens)
class AppHeaderWithProgress extends StatelessWidget {
  final int currentIndex;
  final int total;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final double circleSize;

  const AppHeaderWithProgress({
    Key? key,
    required this.currentIndex,
    required this.total,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.circleSize = 60, // Reduced from 80
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppHeader(
      leading: leading,
      trailing: trailing,
      // Removed centerContent (circle icon) since title already shows question number
      title: Text(
        title,
        style: AppTextStyles.headerWhite.copyWith(fontSize: 18), // Reduced from default
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: AppTextStyles.bodyWhite.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            )
          : null,
      bottomPadding: 20, // Reduced from 40
    );
  }
}

