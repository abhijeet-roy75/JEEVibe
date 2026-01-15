/// AI Tutor (Priya Ma'am) Chat Screen
/// Main chat interface for conversing with the AI tutor
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ai_tutor_models.dart';
import '../providers/ai_tutor_provider.dart';
import '../widgets/app_header.dart';
import '../widgets/ai_tutor/chat_bubble.dart';
import '../widgets/ai_tutor/context_marker_widget.dart';
import '../widgets/ai_tutor/chat_input_bar.dart';
import '../widgets/ai_tutor/quick_actions_row.dart';
import '../widgets/ai_tutor/typing_indicator.dart';
import '../theme/app_colors.dart';

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
  bool _initialLoadDone = false;

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
    if (_initialLoadDone) return;
    _initialLoadDone = true;

    final provider = Provider.of<AiTutorProvider>(context, listen: false);

    try {
      // First, load existing conversation
      await provider.loadConversation();

      // Then, if we have context to inject, do it
      if (widget.injectContext != null) {
        await provider.injectContext(widget.injectContext!);
      }

      // Scroll to bottom after loading
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to load chat: ${e.toString()}');
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
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

  Future<void> _handleSendMessage(String message) async {
    final provider = Provider.of<AiTutorProvider>(context, listen: false);

    try {
      _scrollToBottom();
      await provider.sendMessage(message);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to send message');
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Consumer<AiTutorProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoadingConversation && provider.messages.isEmpty) {
                    return _buildLoadingState();
                  }

                  if (provider.hasError && provider.messages.isEmpty) {
                    return _buildErrorState(provider.error ?? 'Unknown error');
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: _buildMessageList(provider),
                      ),
                      if (provider.quickActions.isNotEmpty)
                        QuickActionsRow(
                          actions: provider.quickActions,
                          onActionTap: _handleQuickAction,
                          isLoading: provider.isSendingMessage,
                        ),
                      ChatInputBar(
                        onSend: _handleSendMessage,
                        isLoading: provider.isSendingMessage,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppHeader(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        children: [
          Text(
            'Priya Ma\'am',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Your AI Tutor',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onSelected: (value) {
          if (value == 'clear') {
            _handleClearChat();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'clear',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 20),
                SizedBox(width: 8),
                Text('Clear Chat'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading conversation...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _initialLoadDone = false;
                });
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
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
              child: const Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chat with Priya Ma\'am',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask questions about concepts, get study tips,\nor discuss your JEE preparation!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
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
