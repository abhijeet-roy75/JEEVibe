/// Priya Ma'am Card Widget
/// Reusable widget for displaying Priya Ma'am's messages
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../priya_avatar.dart';

class PriyaMaamCardWidget extends StatelessWidget {
  final String message;

  const PriyaMaamCardWidget({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const PriyaAvatar(size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Priya Ma\'am',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('✨', style: TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                _buildFormattedMessage(message),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedMessage(String message) {
    // Simple formatting for **bold** text
    final parts = message.split('**');
    return RichText(
      text: TextSpan(
        style: AppTextStyles.bodyMedium,
        children: parts.asMap().entries.map((entry) {
          final index = entry.key;
          final text = entry.value;
          if (index % 2 == 1) {
            // Odd indices are bold
            return TextSpan(
              text: text,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryPurple,
              ),
            );
          } else {
            return TextSpan(text: text);
          }
        }).toList(),
      ),
    );
  }
}

