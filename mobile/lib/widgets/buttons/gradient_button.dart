/// GradientButton - Primary CTA button with gradient background
///
/// A reusable gradient button that follows JEEVibe design system.
/// Use this for primary actions like "Continue", "Submit", "Start Quiz", etc.
///
/// Example:
/// ```dart
/// GradientButton(
///   text: 'Continue',
///   onPressed: () => doSomething(),
/// )
/// ```
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

enum GradientButtonSize { small, medium, large }

enum GradientButtonVariant { primary, secondary, success, error }

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final GradientButtonSize size;
  final GradientButtonVariant variant;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double? width;
  final EdgeInsets? padding;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.size = GradientButtonSize.large,
    this.variant = GradientButtonVariant.primary,
    this.leadingIcon,
    this.trailingIcon,
    this.width,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = !isDisabled && !isLoading && onPressed != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isEnabled ? AppOpacity.full : AppOpacity.disabled,
      child: Container(
        width: width ?? double.infinity,
        height: _getHeight(),
        decoration: BoxDecoration(
          gradient: isEnabled ? _getGradient() : null,
          color: isEnabled ? null : AppColors.disabled,
          borderRadius: BorderRadius.circular(_getBorderRadius()),
          boxShadow: isEnabled ? AppShadows.button : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onPressed : null,
            borderRadius: BorderRadius.circular(_getBorderRadius()),
            child: Padding(
              padding: padding ?? _getPadding(),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: _getIconSize(),
                        height: _getIconSize(),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (leadingIcon != null) ...[
                            Icon(
                              leadingIcon,
                              color: Colors.white,
                              size: _getIconSize(),
                            ),
                            SizedBox(width: _getIconSpacing()),
                          ],
                          Flexible(
                            child: Text(
                              text,
                              style: _getTextStyle(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (trailingIcon != null) ...[
                            SizedBox(width: _getIconSpacing()),
                            Icon(
                              trailingIcon,
                              color: Colors.white,
                              size: _getIconSize(),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _getHeight() {
    switch (size) {
      case GradientButtonSize.small:
        return AppButtonSizes.heightSm;
      case GradientButtonSize.medium:
        return AppButtonSizes.heightMd;
      case GradientButtonSize.large:
        return AppButtonSizes.heightLg;
    }
  }

  double _getBorderRadius() {
    switch (size) {
      case GradientButtonSize.small:
        return AppRadius.sm;
      case GradientButtonSize.medium:
        return AppRadius.md;
      case GradientButtonSize.large:
        return AppRadius.md;
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case GradientButtonSize.small:
        return EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,  // 16px iOS, 13.6px Android
          vertical: 0,    // No vertical padding - height is fixed
        );
      case GradientButtonSize.medium:
        return EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,  // 20px iOS, 17px Android
          vertical: 0,    // No vertical padding - height is fixed
        );
      case GradientButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl, // 24px iOS, 20.4px Android
          vertical: 0,    // No vertical padding - height is fixed
        );
    }
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case GradientButtonSize.small:
        return AppTextStyles.buttonSmall;
      case GradientButtonSize.medium:
        return AppTextStyles.buttonMedium;
      case GradientButtonSize.large:
        return AppTextStyles.buttonLarge;
    }
  }

  double _getIconSize() {
    switch (size) {
      case GradientButtonSize.small:
        return AppIconSizes.sm;  // 16px iOS, 14.4px Android
      case GradientButtonSize.medium:
        return AppIconSizes.md;  // 20px iOS, 18px Android
      case GradientButtonSize.large:
        return AppIconSizes.lg;  // 24px iOS, 21.6px Android
    }
  }

  double _getIconSpacing() {
    switch (size) {
      case GradientButtonSize.small:
        return AppSpacing.xs;    // 4px iOS, 3.4px Android (was 6px)
      case GradientButtonSize.medium:
        return AppSpacing.sm;    // 8px iOS, 6.8px Android
      case GradientButtonSize.large:
        return AppSpacing.md;    // 12px iOS, 10.2px Android (was 10px)
    }
  }

  LinearGradient _getGradient() {
    switch (variant) {
      case GradientButtonVariant.primary:
        return AppColors.ctaGradient;
      case GradientButtonVariant.secondary:
        return AppColors.primaryGradient;
      case GradientButtonVariant.success:
        return const LinearGradient(
          colors: [AppColors.success, AppColors.successLight],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case GradientButtonVariant.error:
        return const LinearGradient(
          colors: [AppColors.error, AppColors.errorLight],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
    }
  }
}

/// Outlined variant of GradientButton
class AppOutlinedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final GradientButtonSize size;
  final Color? borderColor;
  final Color? textColor;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double? width;

  const AppOutlinedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.size = GradientButtonSize.large,
    this.borderColor,
    this.textColor,
    this.leadingIcon,
    this.trailingIcon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = !isDisabled && !isLoading && onPressed != null;
    final color = borderColor ?? AppColors.primary;
    final txtColor = textColor ?? AppColors.primary;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isEnabled ? AppOpacity.full : AppOpacity.disabled,
      child: Container(
        width: width ?? double.infinity,
        height: _getHeight(),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_getBorderRadius()),
          border: Border.all(
            color: isEnabled ? color : AppColors.disabled,
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onPressed : null,
            borderRadius: BorderRadius.circular(_getBorderRadius()),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: _getIconSize(),
                      height: _getIconSize(),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(txtColor),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (leadingIcon != null) ...[
                          Icon(
                            leadingIcon,
                            color: txtColor,
                            size: _getIconSize(),
                          ),
                          SizedBox(width: _getIconSpacing()),
                        ],
                        Flexible(
                          child: Text(
                            text,
                            style: _getTextStyle().copyWith(color: txtColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (trailingIcon != null) ...[
                          SizedBox(width: _getIconSpacing()),
                          Icon(
                            trailingIcon,
                            color: txtColor,
                            size: _getIconSize(),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  double _getHeight() {
    switch (size) {
      case GradientButtonSize.small:
        return AppButtonSizes.heightSm;
      case GradientButtonSize.medium:
        return AppButtonSizes.heightMd;
      case GradientButtonSize.large:
        return AppButtonSizes.heightLg;
    }
  }

  double _getBorderRadius() {
    switch (size) {
      case GradientButtonSize.small:
        return AppRadius.sm;
      case GradientButtonSize.medium:
        return AppRadius.md;
      case GradientButtonSize.large:
        return AppRadius.md;
    }
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case GradientButtonSize.small:
        return AppTextStyles.buttonSmall;
      case GradientButtonSize.medium:
        return AppTextStyles.buttonMedium;
      case GradientButtonSize.large:
        return AppTextStyles.buttonLarge;
    }
  }

  double _getIconSize() {
    switch (size) {
      case GradientButtonSize.small:
        return AppIconSizes.sm;  // 16px iOS, 14.4px Android
      case GradientButtonSize.medium:
        return AppIconSizes.md;  // 20px iOS, 18px Android
      case GradientButtonSize.large:
        return AppIconSizes.lg;  // 24px iOS, 21.6px Android
    }
  }

  double _getIconSpacing() {
    switch (size) {
      case GradientButtonSize.small:
        return AppSpacing.xs;    // 4px iOS, 3.4px Android (was 6px)
      case GradientButtonSize.medium:
        return AppSpacing.sm;    // 8px iOS, 6.8px Android
      case GradientButtonSize.large:
        return AppSpacing.md;    // 12px iOS, 10.2px Android (was 10px)
    }
  }
}

/// Text-only button variant
class AppTextButton extends StatelessWidget{
  final String text;
  final VoidCallback? onPressed;
  final bool isDisabled;
  final Color? textColor;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  const AppTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isDisabled = false,
    this.textColor,
    this.leadingIcon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = !isDisabled && onPressed != null;
    final color = textColor ?? AppColors.primary;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isEnabled ? AppOpacity.full : AppOpacity.disabled,
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,  // 8px iOS, 6.8px Android
            vertical: AppSpacing.xxs,   // 2px iOS, 1.7px Android (was 4px)
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingIcon != null) ...[
                Icon(
                  leadingIcon,
                  color: color,
                  size: AppIconSizes.sm,  // 16px iOS, 14.4px Android (was 18px)
                ),
                SizedBox(width: AppSpacing.xs),  // 4px iOS, 3.4px Android (was 6px)
              ],
              Text(
                text,
                style: AppTextStyles.labelMedium.copyWith(color: color),
              ),
              if (trailingIcon != null) ...[
                SizedBox(width: AppSpacing.xs),  // 4px iOS, 3.4px Android (was 6px)
                Icon(
                  trailingIcon,
                  color: color,
                  size: AppIconSizes.sm,  // 16px iOS, 14.4px Android (was 18px)
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
