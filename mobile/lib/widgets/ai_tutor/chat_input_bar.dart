/// AI Tutor Chat Input Bar Widget
/// Text input field with send button for chat
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_platform_sizing.dart';

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
      padding: EdgeInsets.symmetric(
        horizontal: PlatformSizing.spacing(16),
        vertical: PlatformSizing.spacing(12),
      ),
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
                constraints: BoxConstraints(maxHeight: PlatformSizing.spacing(120)),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGrey,
                  borderRadius: BorderRadius.circular(PlatformSizing.radius(24)),
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
                  style: TextStyle(
                    fontSize: PlatformSizing.fontSize(15),
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? 'Ask Priya Ma\'am...',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary.withValues(alpha: 0.7),
                      fontSize: PlatformSizing.fontSize(15),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: PlatformSizing.spacing(16),
                      vertical: PlatformSizing.spacing(12),
                    ),
                  ),
                  onSubmitted: (_) => _handleSend(),
                  textInputAction: TextInputAction.send,
                  enabled: !widget.isLoading,
                ),
              ),
            ),
            SizedBox(width: PlatformSizing.spacing(8)),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: _hasText && !widget.isLoading
                    ? AppColors.primary
                    : AppColors.disabled,
                borderRadius: BorderRadius.circular(PlatformSizing.radius(24)),
                child: InkWell(
                  onTap: _hasText && !widget.isLoading ? _handleSend : null,
                  borderRadius: BorderRadius.circular(PlatformSizing.radius(24)),
                  child: Container(
                    width: PlatformSizing.spacing(44),
                    height: PlatformSizing.spacing(44),
                    alignment: Alignment.center,
                    child: widget.isLoading
                        ? SizedBox(
                            width: PlatformSizing.iconSize(20),
                            height: PlatformSizing.iconSize(20),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: _hasText ? Colors.white : AppColors.textTertiary,
                            size: PlatformSizing.iconSize(20),
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
