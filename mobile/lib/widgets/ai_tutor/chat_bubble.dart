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
              child: _buildFormattedContent(message.content ?? ''),
            ),
          ),
        ],
      ),
    );
  }

  /// Build formatted content that preserves paragraph structure
  /// and handles steps/lists properly
  Widget _buildFormattedContent(String content) {
    const textStyle = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 15,
      height: 1.5,
    );

    // Preprocess: Convert markdown to HTML for proper rendering
    final processedContent = _preprocessMarkdown(content);

    // Split by double newlines (paragraphs) or numbered/bullet lists
    // Preserve structure while still handling LaTeX within each block
    final paragraphs = _splitIntoParagraphs(processedContent);

    if (paragraphs.length == 1) {
      // Single paragraph - render normally
      return LaTeXWidget(
        text: processedContent,
        textStyle: textStyle,
        allowWrapping: true,
      );
    }

    // Multiple paragraphs - render each with spacing
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.asMap().entries.map((entry) {
        final index = entry.key;
        final paragraph = entry.value.trim();

        if (paragraph.isEmpty) {
          return const SizedBox(height: 8);
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: index < paragraphs.length - 1 ? 12 : 0,
          ),
          child: LaTeXWidget(
            text: paragraph,
            textStyle: textStyle,
            allowWrapping: true,
          ),
        );
      }).toList(),
    );
  }

  /// Convert markdown formatting to HTML for proper rendering
  String _preprocessMarkdown(String content) {
    String processed = content;

    // Convert **bold** to <strong>bold</strong>
    processed = processed.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'),
      (match) => '<strong>${match.group(1)}</strong>',
    );

    // Convert *italic* to <em>italic</em> (but not inside <strong> tags)
    processed = processed.replaceAllMapped(
      RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)'),
      (match) => '<em>${match.group(1)}</em>',
    );

    return processed;
  }

  /// Split content into paragraphs while preserving structure
  List<String> _splitIntoParagraphs(String content) {
    // First, normalize different newline formats
    String normalized = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    // Split by:
    // 1. Double newlines (paragraph breaks)
    // 2. Lines starting with numbers (1., 2., etc.) or bullets (-, *, •)
    final List<String> result = [];
    final lines = normalized.split('\n');

    StringBuffer currentParagraph = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      // Check if this line starts a new numbered/bulleted item
      final isListItem = RegExp(r'^(\d+[\.\)]\s|[-*•]\s)').hasMatch(trimmedLine);

      // Check if previous line was empty (paragraph break)
      final prevWasEmpty = i > 0 && lines[i - 1].trim().isEmpty;

      if (trimmedLine.isEmpty) {
        // Empty line - save current paragraph if any
        if (currentParagraph.isNotEmpty) {
          result.add(currentParagraph.toString().trim());
          currentParagraph.clear();
        }
      } else if (isListItem || prevWasEmpty) {
        // New list item or after paragraph break - start new paragraph
        if (currentParagraph.isNotEmpty) {
          result.add(currentParagraph.toString().trim());
          currentParagraph.clear();
        }
        currentParagraph.write(trimmedLine);
      } else {
        // Continue current paragraph
        if (currentParagraph.isNotEmpty) {
          currentParagraph.write(' ');
        }
        currentParagraph.write(trimmedLine);
      }
    }

    // Don't forget the last paragraph
    if (currentParagraph.isNotEmpty) {
      result.add(currentParagraph.toString().trim());
    }

    return result.isEmpty ? [content] : result;
  }
}
