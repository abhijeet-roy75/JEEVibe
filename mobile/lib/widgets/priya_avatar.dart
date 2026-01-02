/// Reusable Priya Ma'am Avatar Widget
/// Displays the Priya Ma'am image in a circular container
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PriyaAvatar extends StatelessWidget {
  final double size;
  final bool showShadow;

  const PriyaAvatar({
    super.key,
    this.size = 48,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Add a white background to ensure circular shape is visible
        color: Colors.white,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppColors.primaryPurple.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/priya_maam.jpeg',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to gradient circle with P if image fails to load
            return Container(
              decoration: const BoxDecoration(
                gradient: AppColors.ctaGradient,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'P',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.375,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

