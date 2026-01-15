/// AI Tutor Chat Bubble Widget
/// Displays user and assistant messages in the chat
import 'package:flutter/material.dart';
import '../../models/ai_tutor_models.dart';
import '../../theme/app_colors.dart';
import '../priya_avatar.dart';
import '../latex_widget.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showAvatar;

  const ChatBubble({
    super.key,
    required this.message,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _buildUserBubble(context);
    } else {
      return _buildAssistantBubble(context);
    }
  }

  Widget _buildUserBubble(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 48,
        right: 16,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                gradient: AppColors.ctaGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: LaTeXWidget(
                text: message.content ?? '',
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
                allowWrapping: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 16,
        right: 48,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showAvatar) ...[
            const PriyaAvatar(size: 36, showShadow: false),
            const SizedBox(width: 8),
          ] else
            const SizedBox(width: 44), // Space for alignment when no avatar
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: AppColors.borderLight,
                  width: 1,
                ),
              ),
              child: LaTeXWidget(
                text: message.content ?? '',
                textStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                ),
                allowWrapping: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
