import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SubjectIconWidget extends StatelessWidget {
  final String subject;
  final double size;
  final bool useCircularBackground;
  final Color? customColor;

  const SubjectIconWidget({
    super.key,
    required this.subject,
    this.size = 24.0,
    this.useCircularBackground = true,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final String normalizedSubject = subject.toLowerCase();
    
    Color backgroundColor;
    Color iconColor;
    IconData iconData;

    if (normalizedSubject.contains('math')) {
      backgroundColor = AppColors.cardLightPurple;
      iconColor = customColor ?? AppColors.primaryPurple;
      iconData = Icons.functions; // Keeping functions as it's more "Advanced" for JEE
    } else if (normalizedSubject.contains('phys')) {
      backgroundColor = const Color(0xFFFEF3C7); // Light amber
      iconColor = customColor ?? AppColors.warningAmber;
      iconData = Icons.bolt; 
    } else if (normalizedSubject.contains('chem')) {
      backgroundColor = AppColors.successBackground;
      iconColor = customColor ?? AppColors.successGreen;
      iconData = Icons.science;
    } else if (normalizedSubject.contains('all') || normalizedSubject.contains('total')) {
      backgroundColor = AppColors.infoBackground;
      iconColor = customColor ?? AppColors.infoBlue;
      iconData = Icons.library_books;
    } else {
      backgroundColor = AppColors.infoBackground;
      iconColor = customColor ?? AppColors.infoBlue;
      iconData = Icons.description_outlined;
    }

    if (!useCircularBackground) {
      return Icon(iconData, color: iconColor, size: size);
    }

    return Container(
      width: size * 1.6,
      height: size * 1.6,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: size,
      ),
    );
  }

  // Static helper to get just the icon data
  static IconData getIcon(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) return Icons.functions;
    if (s.contains('phys')) return Icons.bolt;
    if (s.contains('chem')) return Icons.science;
    if (s.contains('all') || s.contains('total')) return Icons.library_books;
    return Icons.description_outlined;
  }

  // Static helper to get the color
  static Color getColor(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) return AppColors.primaryPurple;
    if (s.contains('phys')) return AppColors.warningAmber;
    if (s.contains('chem')) return AppColors.successGreen;
    if (s.contains('all') || s.contains('total')) return AppColors.infoBlue;
    return AppColors.textMedium;
  }
}
