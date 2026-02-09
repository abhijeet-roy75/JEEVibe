/// Stat Card Widget
/// Displays a single statistic with icon, value, and label
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_platform_sizing.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color? iconBackgroundColor;
  final String value;
  final String label;
  final Color? valueColor;

  const StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    this.iconBackgroundColor,
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = iconBackgroundColor ?? iconColor;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: PlatformSizing.spacing(12),
        vertical: PlatformSizing.spacing(10),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Icon + Value
          Row(
            children: [
              Container(
                width: PlatformSizing.spacing(32),
                height: PlatformSizing.spacing(32),
                decoration: BoxDecoration(
                  color: bgColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(PlatformSizing.radius(8)),
                ),
                child: Icon(
                  icon,
                  color: bgColor,
                  size: PlatformSizing.iconSize(18),
                ),
              ),
              SizedBox(width: PlatformSizing.spacing(8)),
              Expanded(
                child: Text(
                  value,
                  style: AppTextStyles.numericMedium.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontSize: PlatformSizing.fontSize(18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: PlatformSizing.spacing(4)),
          // Row 2: Label
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
              fontSize: PlatformSizing.fontSize(12),  // 12px iOS, 10.56px Android (was 11)
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal stat card variant (for inline display)
class StatCardHorizontal extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const StatCardHorizontal({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: PlatformSizing.spacing(44),
          height: PlatformSizing.spacing(44),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: PlatformSizing.iconSize(24),
          ),
        ),
        SizedBox(width: PlatformSizing.spacing(12)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTextStyles.headerMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
