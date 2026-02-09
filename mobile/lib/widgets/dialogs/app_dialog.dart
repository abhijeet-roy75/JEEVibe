/// AppDialog - Reusable dialog components
///
/// Standardized dialogs that follow JEEVibe design system.
/// Use for confirmations, alerts, and custom content dialogs.
///
/// Example:
/// ```dart
/// await AppDialog.confirm(
///   context: context,
///   title: 'Delete Item',
///   message: 'Are you sure you want to delete this item?',
/// );
/// ```
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_platform_sizing.dart';
import '../buttons/gradient_button.dart';

class AppDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final Widget? content;
  final List<Widget>? actions;
  final IconData? icon;
  final Color? iconColor;
  final bool showCloseButton;
  final EdgeInsets? padding;

  const AppDialog({
    super.key,
    this.title,
    this.message,
    this.content,
    this.actions,
    this.icon,
    this.iconColor,
    this.showCloseButton = false,
    this.padding,
  });

  /// Shows a confirmation dialog with Yes/No actions
  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Yes',
    String cancelText = 'No',
    bool isDestructive = false,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        message: message,
        icon: isDestructive ? Icons.warning_amber_rounded : Icons.help_outline,
        iconColor: isDestructive ? AppColors.error : AppColors.primary,
        actions: [
          Expanded(
            child: AppOutlinedButton(
              text: cancelText,
              size: GradientButtonSize.medium,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ),
          SizedBox(width: AppSpacing.md), // 12→9.6px Android
          Expanded(
            child: GradientButton(
              text: confirmText,
              size: GradientButtonSize.medium,
              variant: isDestructive
                  ? GradientButtonVariant.error
                  : GradientButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows an alert dialog with a single OK button
  static Future<void> alert({
    required BuildContext context,
    required String title,
    required String message,
    String buttonText = 'OK',
    IconData? icon,
    Color? iconColor,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        message: message,
        icon: icon ?? Icons.info_outline,
        iconColor: iconColor ?? AppColors.primary,
        actions: [
          Expanded(
            child: GradientButton(
              text: buttonText,
              size: GradientButtonSize.medium,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a success dialog
  static Future<void> success({
    required BuildContext context,
    required String title,
    String? message,
    String buttonText = 'OK',
    VoidCallback? onDismiss,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        message: message,
        icon: Icons.check_circle_outline,
        iconColor: AppColors.success,
        actions: [
          Expanded(
            child: GradientButton(
              text: buttonText,
              size: GradientButtonSize.medium,
              variant: GradientButtonVariant.success,
              onPressed: () {
                Navigator.of(context).pop();
                onDismiss?.call();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Shows an error dialog
  static Future<void> error({
    required BuildContext context,
    required String title,
    String? message,
    String buttonText = 'OK',
  }) async {
    return showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        message: message,
        icon: Icons.error_outline,
        iconColor: AppColors.error,
        actions: [
          Expanded(
            child: GradientButton(
              text: buttonText,
              size: GradientButtonSize.medium,
              variant: GradientButtonVariant.error,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog with custom content
  static Future<T?> custom<T>({
    required BuildContext context,
    required Widget content,
    String? title,
    List<Widget>? actions,
    bool showCloseButton = true,
    bool barrierDismissible = true,
  }) async {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AppDialog(
        title: title,
        content: content,
        actions: actions,
        showCloseButton: showCloseButton,
      ),
    );
  }

  /// Shows a loading dialog
  static Future<void> showLoading({
    required BuildContext context,
    String message = 'Loading...',
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: PlatformSizing.buttonHeight(48), // 48→44px Android
              height: PlatformSizing.buttonHeight(48),
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            SizedBox(height: AppSpacing.lg), // 16→12.8px Android
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Hides the loading dialog
  static void hideLoading(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Container(
        padding: padding ?? EdgeInsets.all(AppSpacing.xxl), // 24→19.2px Android
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showCloseButton)
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(
                    Icons.close,
                    size: AppIconSizes.lg, // 24→21.12px Android
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (icon != null) ...[
              Icon(
                icon,
                size: AppIconSizes.massive, // 48→43.2px Android
                color: iconColor ?? AppColors.primary,
              ),
              SizedBox(height: AppSpacing.lg), // 16→12.8px Android
            ],
            if (title != null) ...[
              Text(
                title!,
                style: AppTextStyles.headerMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.xs), // 8→6.4px Android
            ],
            if (message != null) ...[
              Text(
                message!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (content != null) content!,
            if (actions != null && actions!.isNotEmpty) ...[
              SizedBox(height: AppSpacing.xxl), // 24→19.2px Android
              Row(
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet dialog variant
class AppBottomSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final bool showHandle;
  final bool showCloseButton;
  final EdgeInsets? padding;

  const AppBottomSheet({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.showHandle = true,
    this.showCloseButton = false,
    this.padding,
  });

  /// Shows a bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    List<Widget>? actions,
    bool showHandle = true,
    bool showCloseButton = false,
    bool isScrollControlled = false,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AppBottomSheet(
        title: title,
        actions: actions,
        showHandle: showHandle,
        showCloseButton: showCloseButton,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: padding ?? EdgeInsets.all(AppSpacing.xxl), // 24→19.2px Android
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHandle)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: AppSpacing.lg), // 16→12.8px Android
                  decoration: BoxDecoration(
                    color: AppColors.borderMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            if (title != null || showCloseButton)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.lg), // 16→12.8px Android
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: AppTextStyles.headerMedium,
                      ),
                    if (showCloseButton)
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.close,
                          size: AppIconSizes.lg, // 24→21.12px Android
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            child,
            if (actions != null && actions!.isNotEmpty) ...[
              SizedBox(height: AppSpacing.xxl), // 24→19.2px Android
              ...actions!,
            ],
          ],
        ),
      ),
    );
  }
}
