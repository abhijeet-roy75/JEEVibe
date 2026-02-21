// AI Tutor (Priya Ma'am) Chat Screen
// Main chat interface for conversing with the AI tutor
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ai_tutor_models.dart';
import '../providers/ai_tutor_provider.dart';
import '../widgets/app_header.dart';
import '../widgets/buttons/icon_button.dart';
import '../widgets/priya_avatar.dart';
import '../theme/app_text_styles.dart';
import '../widgets/ai_tutor/chat_bubble.dart';
import '../widgets/ai_tutor/context_marker_widget.dart';
import '../widgets/ai_tutor/chat_input_bar.dart';
import '../widgets/ai_tutor/quick_actions_row.dart';
import '../widgets/ai_tutor/typing_indicator.dart';
import '../widgets/responsive_layout.dart';
import '../theme/app_colors.dart';
import '../theme/app_platform_sizing.dart';

/// Animation timing constants
const Duration kScrollDelayDuration = Duration(milliseconds: 100);
const Duration kScrollAnimationDuration = Duration(milliseconds: 300);

class AiTutorChatScreen extends StatefulWidget {
  /// Optional context to inject when opening the chat
  /// Pass this when navigating from solution/quiz/analytics screens
  final TutorContext? injectContext;

  const AiTutorChatScreen({
    super.key,
    this.injectContext,
  });

  @override
  State<AiTutorChatScreen> createState() => _AiTutorChatScreenState();
}

class _AiTutorChatScreenState extends State<AiTutorChatScreen> {
  final ScrollController _scrollController = ScrollController();

  /// Completer to prevent double-initialization race condition
  /// Using a Completer is more robust than a simple bool flag
  Completer<void>? _initCompleter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    // Prevent double-initialization using Completer
    if (_initCompleter != null) {
      // Already initializing or completed, wait for it
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    final provider = Provider.of<AiTutorProvider>(context, listen: false);

    try {
      // First, load existing conversation
      await provider.loadConversation();

      // Then, if we have context to inject, do it
      if (widget.injectContext != null && mounted) {
        await provider.injectContext(widget.injectContext!);
      }

      // Scroll to bottom after loading
      if (mounted) {
        _scrollToBottom();
      }

      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      if (mounted) {
        _showErrorSnackbar('Failed to load chat: ${e.toString()}');
      }
    }
  }

  /// Reset initialization state (for retry)
  void _resetInitialization() {
    _initCompleter = null;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(kScrollDelayDuration, () {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: kScrollAnimationDuration,
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show error snackbar with retry action for failed messages
  void _showRetrySnackbar(String message, VoidCallback onRetry) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: onRetry,
        ),
      ),
    );
  }

  Future<void> _handleSendMessage(String message) async {
    final provider = Provider.of<AiTutorProvider>(context, listen: false);

    try {
      _scrollToBottom();
      await provider.sendMessage(message);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        // Show retry snackbar if there's a failed message
        if (provider.hasFailedMessage) {
          _showRetrySnackbar(
            'Failed to send message',
            () => _handleRetryMessage(),
          );
        } else {
          _showErrorSnackbar('Failed to send message');
        }
      }
    }
  }

  /// Retry the last failed message
  Future<void> _handleRetryMessage() async {
    final provider = Provider.of<AiTutorProvider>(context, listen: false);

    if (!provider.hasFailedMessage) return;

    try {
      _scrollToBottom();
      await provider.retryFailedMessage();
      _scrollToBottom();
    } catch (e) {
      if (mounted && provider.hasFailedMessage) {
        _showRetrySnackbar(
          'Failed to send message',
          () => _handleRetryMessage(),
        );
      }
    }
  }

  Future<void> _handleQuickAction(QuickAction action) async {
    await _handleSendMessage(action.prompt);
  }

  Future<void> _handleClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
          'This will clear your entire conversation history with Priya Ma\'am. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<AiTutorProvider>(context, listen: false);
      try {
        await provider.clearConversation();
      } catch (e) {
        if (mounted) {
          _showErrorSnackbar('Failed to clear chat');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Consumer<AiTutorProvider>(
                builder: (context, provider, _) {
                  // Show loading state for initial conversation load
                  if (provider.isLoadingConversation && provider.messages.isEmpty) {
                    return _buildLoadingState('Loading conversation...');
                  }

                  // Show loading state when injecting context (opening from solution/quiz)
                  if (provider.isInjectingContext && provider.messages.isEmpty) {
                    return _buildLoadingState('Loading context...');
                  }

                  if (provider.hasError && provider.messages.isEmpty) {
                    return _buildErrorState(provider.error ?? 'Unknown error');
                  }

                  return Column(
                    children: [
                      // Show a subtle loading banner when injecting context to existing conversation
                      if (provider.isInjectingContext && provider.messages.isNotEmpty)
                        _buildContextLoadingBanner(),
                      // Show failed message retry banner
                      if (provider.hasFailedMessage && !provider.isSendingMessage)
                        _buildFailedMessageBanner(provider),
                      Expanded(
                        child: _buildMessageList(provider),
                      ),
                      if (provider.quickActions.isNotEmpty)
                        Center(
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: isDesktopViewport(context) ? 900 : double.infinity,
                            ),
                            child: QuickActionsRow(
                              actions: provider.quickActions,
                              onActionTap: _handleQuickAction,
                              isLoading: provider.isSendingMessage || provider.isInjectingContext,
                            ),
                          ),
                        ),
                      Center(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: isDesktopViewport(context) ? 900 : double.infinity,
                          ),
                          child: ChatInputBar(
                            onSend: _handleSendMessage,
                            isLoading: provider.isSendingMessage || provider.isInjectingContext,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildHeader() {
    return AppHeader(
      leading: AppIconButton.back(
        onPressed: () => Navigator.of(context).pop(),
        forGradientHeader: true,
      ),
      title: Text(
        'Priya Ma\'am',
        style: AppTextStyles.headerWhite.copyWith(fontSize: PlatformSizing.fontSize(20)),
      ),
      subtitle: Padding(
        padding: EdgeInsets.symmetric(horizontal: PlatformSizing.spacing(16)),
        child: Text(
          'Your AI Tutor',
          style: AppTextStyles.bodyWhite.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: PlatformSizing.fontSize(14),
          ),
          textAlign: TextAlign.center,
        ),
      ),
      trailing: AppIconButton(
        icon: Icons.more_vert,
        onPressed: () => _showOptionsMenu(),
        variant: AppIconButtonVariant.glass,
        iconColor: Colors.white,
      ),
      bottomPadding: PlatformSizing.spacing(16),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: PlatformSizing.spacing(8)),
            Container(
              width: PlatformSizing.spacing(40),
              height: PlatformSizing.spacing(4),
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(PlatformSizing.radius(2)),
              ),
            ),
            SizedBox(height: PlatformSizing.spacing(16)),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error, size: PlatformSizing.iconSize(24)),
              title: const Text('Clear Chat'),
              subtitle: const Text('Delete all messages'),
              onTap: () {
                Navigator.pop(context);
                _handleClearChat();
              },
            ),
            SizedBox(height: PlatformSizing.spacing(8)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Priya avatar with pulsing effect
          Container(
            width: PlatformSizing.spacing(80),
            height: PlatformSizing.spacing(80),
            decoration: BoxDecoration(
              gradient: AppColors.ctaGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: PriyaAvatar(size: PlatformSizing.spacing(48), showShadow: false),
            ),
          ),
          SizedBox(height: PlatformSizing.spacing(24)),
          const CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: PlatformSizing.spacing(16)),
          Text(
            message,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: PlatformSizing.fontSize(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextLoadingBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: PlatformSizing.spacing(16),
        vertical: PlatformSizing.spacing(10),
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: PlatformSizing.iconSize(16),
            height: PlatformSizing.iconSize(16),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(width: PlatformSizing.spacing(10)),
          Text(
            'Loading context...',
            style: TextStyle(
              color: AppColors.primary.withValues(alpha: 0.8),
              fontSize: PlatformSizing.fontSize(13),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedMessageBanner(AiTutorProvider provider) {
    final failedMessage = provider.failedMessage;
    if (failedMessage == null) return const SizedBox.shrink();

    // Truncate long messages for display
    final displayContent = failedMessage.content.length > 50
        ? '${failedMessage.content.substring(0, 50)}...'
        : failedMessage.content;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: PlatformSizing.spacing(16),
        vertical: PlatformSizing.spacing(12),
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: AppColors.error.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: PlatformSizing.iconSize(20),
            color: AppColors.error.withValues(alpha: 0.8),
          ),
          SizedBox(width: PlatformSizing.spacing(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Message failed to send',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: PlatformSizing.fontSize(13),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: PlatformSizing.spacing(2)),
                Text(
                  displayContent,
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                    fontSize: PlatformSizing.fontSize(12),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: PlatformSizing.spacing(8)),
          TextButton(
            onPressed: _handleRetryMessage,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: EdgeInsets.symmetric(
                horizontal: PlatformSizing.spacing(12),
                vertical: PlatformSizing.spacing(6),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry'),
          ),
          IconButton(
            onPressed: () => provider.clearFailedMessage(),
            icon: Icon(Icons.close, size: PlatformSizing.iconSize(18)),
            color: AppColors.textSecondary,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: PlatformSizing.spacing(32),
              minHeight: PlatformSizing.spacing(32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(PlatformSizing.spacing(24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: PlatformSizing.iconSize(48),
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            SizedBox(height: PlatformSizing.spacing(16)),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: PlatformSizing.fontSize(18),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: PlatformSizing.spacing(8)),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: PlatformSizing.fontSize(14),
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: PlatformSizing.spacing(24)),
            ElevatedButton(
              onPressed: () {
                _resetInitialization();
                _initializeChat();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(AiTutorProvider provider) {
    final messages = provider.messages;

    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isDesktopViewport(context) ? 900 : double.infinity,
        ),
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(vertical: PlatformSizing.spacing(16)),
          itemCount: messages.length + (provider.isSendingMessage ? 1 : 0),
          itemBuilder: (context, index) {
        // Show typing indicator at the end while sending
        if (index == messages.length && provider.isSendingMessage) {
          return const TypingIndicator();
        }

        final message = messages[index];

        // Determine if we should show avatar (only for first message in a group)
        bool showAvatar = true;
        if (index > 0 && message.isAssistant) {
          final prevMessage = messages[index - 1];
          if (prevMessage.isAssistant) {
            showAvatar = false;
          }
        }

        if (message.isContextMarker) {
          return ContextMarkerWidget(message: message);
        }

        return ChatBubble(
          message: message,
          showAvatar: showAvatar,
        );
      },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(PlatformSizing.spacing(32)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: PlatformSizing.spacing(80),
              height: PlatformSizing.spacing(80),
              decoration: BoxDecoration(
                gradient: AppColors.ctaGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
                size: PlatformSizing.iconSize(36),
              ),
            ),
            SizedBox(height: PlatformSizing.spacing(24)),
            Text(
              'Chat with Priya Ma\'am',
              style: TextStyle(
                fontSize: PlatformSizing.fontSize(20),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: PlatformSizing.spacing(8)),
            Text(
              'Ask questions about concepts, get study tips,\nor discuss your JEE preparation!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: PlatformSizing.fontSize(14),
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
