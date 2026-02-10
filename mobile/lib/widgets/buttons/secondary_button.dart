import 'package:flutter/material.dart';
import 'package:jeevibe_mobile/theme/app_colors.dart';
import 'package:jeevibe_mobile/theme/app_platform_sizing.dart';

/// Secondary Button Widget
/// Reusable button for secondary actions (Cancel, Back, Skip, etc.)
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? borderColor;
  final Color? textColor;
  final IconData? icon;
  final double? width;
  final double? height;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.borderColor,
    this.textColor,
    this.icon,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? AppColors.borderDefault;
    final effectiveTextColor = textColor ?? AppColors.primary;

    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? PlatformSizing.buttonHeight(48),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: effectiveTextColor,
          side: BorderSide(color: effectiveBorderColor, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
          ),
        ),
        child: icon != null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: effectiveTextColor),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: effectiveTextColor,
                    ),
                  ),
                ],
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: effectiveTextColor,
                ),
              ),
      ),
    );
  }
}
