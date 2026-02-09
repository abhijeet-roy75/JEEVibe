/// Priya Ma'am Card Widget
/// Reusable widget for displaying Priya Ma'am's messages
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_platform_sizing.dart';
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
      margin: EdgeInsets.symmetric(horizontal: PlatformSizing.spacing(16)),
      padding: EdgeInsets.all(PlatformSizing.spacing(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PlatformSizing.radius(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, PlatformSizing.spacing(4)),
          ),
        ],
      ),
      child: Row(
        children: [
          PriyaAvatar(size: PlatformSizing.spacing(48)),
          SizedBox(width: PlatformSizing.spacing(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Priya Ma\'am',
                      style: AppTextStyles.priyaHeader.copyWith( // Guideline: 15px bold for header
                        color: AppColors.primaryPurple,
                      ),
                    ),
                    SizedBox(width: PlatformSizing.spacing(4)),
                    Text('✨', style: TextStyle(fontSize: PlatformSizing.fontSize(14))), // Slightly smaller emoji
                  ],
                ),
                SizedBox(height: PlatformSizing.spacing(4)),
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
        style: AppTextStyles.priyaMessage, // Guideline: 16px for message body
        children: parts.asMap().entries.map((entry) {
          final index = entry.key;
          final text = entry.value;
          if (index % 2 == 1) {
            // Odd indices are bold
            return TextSpan(
              text: text,
              style: AppTextStyles.priyaMessage.copyWith(
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

