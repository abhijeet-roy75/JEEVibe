import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SubjectIconWidget extends StatelessWidget {
  final String subject;
  final double size;

  const SubjectIconWidget({
    super.key,
    required this.subject,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final String normalizedSubject = subject.toLowerCase();
    
    Color backgroundColor;
    Color iconColor;
    IconData iconData;

    if (normalizedSubject.contains('math')) {
      backgroundColor = AppColors.cardLightPurple;
      iconColor = AppColors.primaryPurple;
      iconData = Icons.functions; // Integral-like icon
    } else if (normalizedSubject.contains('phys')) {
      backgroundColor = const Color(0xFFFEF3C7); // Light amber
      iconColor = AppColors.warningAmber;
      iconData = Icons.bolt; // Lightning icon
    } else if (normalizedSubject.contains('chem')) {
      backgroundColor = AppColors.successBackground;
      iconColor = AppColors.successGreen;
      iconData = Icons.science; // Test tube/beaker icon
    } else {
      backgroundColor = AppColors.infoBackground;
      iconColor = AppColors.infoBlue;
      iconData = Icons.description_outlined;
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
}
