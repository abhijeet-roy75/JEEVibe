/// AI Tutor Chat Input Bar Widget
/// Text input field with send button for chat
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String) onSend;
  final bool isLoading;
  final String? hintText;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.isLoading = false,
    this.hintText,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.isLoading) {
      widget.onSend(text);
      _controller.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGrey,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.borderLight,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? 'Ask Priya Ma\'am...',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary.withValues(alpha: 0.7),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _handleSend(),
                  textInputAction: TextInputAction.send,
                  enabled: !widget.isLoading,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: _hasText && !widget.isLoading
                    ? AppColors.primary
                    : AppColors.disabled,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: _hasText && !widget.isLoading ? _handleSend : null,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: widget.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: _hasText ? Colors.white : AppColors.textTertiary,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
