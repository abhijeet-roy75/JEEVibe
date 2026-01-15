/// AI Tutor Context Marker Widget
/// Displays a visual divider when context changes in the conversation
import 'package:flutter/material.dart';
import '../../models/ai_tutor_models.dart';
import '../../theme/app_colors.dart';

class ContextMarkerWidget extends StatelessWidget {
  final ChatMessage message;

  const ContextMarkerWidget({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final contextType = message.contextType ?? 'general';
    final contextTitle = message.contextTitle ?? 'New Topic';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.borderDefault.withValues(alpha: 0.5),
                    AppColors.borderDefault,
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getContextColor(contextType).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getContextColor(contextType).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getContextIcon(contextType),
                  size: 14,
                  color: _getContextColor(contextType),
                ),
                const SizedBox(width: 6),
                Text(
                  contextTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _getContextColor(contextType),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.borderDefault,
                    AppColors.borderDefault.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getContextIcon(String contextType) {
    switch (contextType) {
      case 'solution':
        return Icons.lightbulb_outline;
      case 'quiz':
        return Icons.quiz_outlined;
      case 'analytics':
        return Icons.analytics_outlined;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  Color _getContextColor(String contextType) {
    switch (contextType) {
      case 'solution':
        return AppColors.primary;
      case 'quiz':
        return AppColors.info;
      case 'analytics':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }
}
