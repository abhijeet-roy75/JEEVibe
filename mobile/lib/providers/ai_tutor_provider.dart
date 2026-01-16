/// AI Tutor (Priya Ma'am) State Provider
/// Centralized state management for AI Tutor chat feature
import 'package:flutter/foundation.dart';
import '../models/ai_tutor_models.dart';
import '../services/api_service.dart';
import '../services/firebase/auth_service.dart';

/// Maximum messages to keep in memory to prevent memory issues
const int kMaxInMemoryMessages = 100;

/// Represents a message that failed to send and can be retried
class FailedMessage {
  final String content;
  final DateTime timestamp;
  final String? error;

  FailedMessage({
    required this.content,
    required this.timestamp,
    this.error,
  });
}

class AiTutorProvider extends ChangeNotifier {
  final AuthService _authService;

  // Chat State
  List<ChatMessage> _messages = [];
  List<QuickAction> _quickActions = [];
  TutorContext? _currentContext;
  int _messageCount = 0;
  bool _isNewConversation = true;

  // Loading States
  bool _isLoadingConversation = false;
  bool _isSendingMessage = false;
  bool _isInjectingContext = false;
  bool _isClearingConversation = false;

  // Error States
  String? _error;

  // Failed message for retry functionality
  FailedMessage? _failedMessage;

  // Disposal State
  bool _disposed = false;

  AiTutorProvider(this._authService);

  // Getters
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<QuickAction> get quickActions => List.unmodifiable(_quickActions);
  TutorContext? get currentContext => _currentContext;
  int get messageCount => _messageCount;
  bool get isNewConversation => _isNewConversation;

  // Loading State Getters
  bool get isLoadingConversation => _isLoadingConversation;
  bool get isSendingMessage => _isSendingMessage;
  bool get isInjectingContext => _isInjectingContext;
  bool get isClearingConversation => _isClearingConversation;
  bool get isLoading =>
      _isLoadingConversation ||
      _isSendingMessage ||
      _isInjectingContext ||
      _isClearingConversation;

  // Error State Getters
  String? get error => _error;
  bool get hasError => _error != null;

  // Failed Message Getters (for retry functionality)
  FailedMessage? get failedMessage => _failedMessage;
  bool get hasFailedMessage => _failedMessage != null;

  // Computed Properties
  bool get hasConversation => _messages.isNotEmpty;
  bool get hasMessages => _messages.where((m) => !m.isContextMarker).isNotEmpty;

  /// Load existing conversation from backend
  Future<void> loadConversation({int limit = 50}) async {
    if (_disposed) return;

    _isLoadingConversation = true;
    _error = null;
    _safeNotifyListeners();

    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await ApiService.getAiTutorConversation(
        authToken: token,
        limit: limit,
      );

      if (_disposed) return;

      final conversationResponse = ConversationResponse.fromJson(response);

      // Limit in-memory messages to prevent memory issues on low-end devices
      final allMessages = conversationResponse.messages;
      _messages = allMessages.length > kMaxInMemoryMessages
          ? allMessages.sublist(allMessages.length - kMaxInMemoryMessages)
          : allMessages;
      _messageCount = conversationResponse.messageCount;
      _currentContext = conversationResponse.currentContext;
      _quickActions = conversationResponse.quickActions;
      _isNewConversation = conversationResponse.isNewConversation;
      _isLoadingConversation = false;
      _error = null;

      _safeNotifyListeners();
    } catch (e) {
      if (_disposed) return;
      _isLoadingConversation = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      _safeNotifyListeners();
      rethrow;
    }
  }

  /// Inject context when entering chat from solution/quiz/analytics
  /// This adds a context marker and gets a contextual greeting
  Future<void> injectContext(TutorContext context) async {
    if (_disposed) return;

    _isInjectingContext = true;
    _error = null;
    _safeNotifyListeners();

    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await ApiService.injectAiTutorContext(
        authToken: token,
        contextType: context.contextTypeString,
        contextId: context.id,
      );

      if (_disposed) return;

      final injectResponse = InjectContextResponse.fromJson(response);

      // Add context marker to messages
      final contextMarkerMessage = ChatMessage(
        id: injectResponse.contextMarker.id,
        type: ChatMessageType.contextMarker,
        timestamp: injectResponse.contextMarker.timestamp,
        contextType: injectResponse.contextMarker.type,
        contextId: context.id,
        contextTitle: injectResponse.contextMarker.title,
      );

      // Add greeting as assistant message
      final greetingMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ChatMessageType.assistant,
        timestamp: DateTime.now(),
        content: injectResponse.greeting,
      );

      _messages = [..._messages, contextMarkerMessage, greetingMessage];
      _quickActions = injectResponse.quickActions;
      _currentContext = context;
      _messageCount += 2;
      _isNewConversation = false;
      _isInjectingContext = false;
      _error = null;

      _safeNotifyListeners();
    } catch (e) {
      if (_disposed) return;
      _isInjectingContext = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      _safeNotifyListeners();
      rethrow;
    }
  }

  /// Send a message to Priya Ma'am and get a response
  Future<String> sendMessage(String message) async {
    if (_disposed) throw Exception('Provider has been disposed');

    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw Exception('Message cannot be empty');
    }

    _isSendingMessage = true;
    _error = null;
    _failedMessage = null; // Clear any previous failed message

    // Optimistically add user message to UI
    final userMessage = ChatMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      type: ChatMessageType.user,
      timestamp: DateTime.now(),
      content: trimmedMessage,
    );
    _messages = [..._messages, userMessage];
    _safeNotifyListeners();

    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await ApiService.sendAiTutorMessage(
        authToken: token,
        message: trimmedMessage,
      );

      if (_disposed) {
        // Even if disposed, don't leave dangling state
        return '';
      }

      final messageResponse = MessageResponse.fromJson(response);

      // Add assistant response to messages
      final assistantMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ChatMessageType.assistant,
        timestamp: DateTime.now(),
        content: messageResponse.response,
      );

      // Add new message and trim if over limit
      var updatedMessages = [..._messages, assistantMessage];
      if (updatedMessages.length > kMaxInMemoryMessages) {
        updatedMessages = updatedMessages.sublist(
          updatedMessages.length - kMaxInMemoryMessages,
        );
      }
      _messages = updatedMessages;
      _quickActions = messageResponse.quickActions;
      _messageCount += 2;
      _isNewConversation = false;
      _isSendingMessage = false;
      _error = null;

      _safeNotifyListeners();

      return messageResponse.response;
    } catch (e) {
      // Always clean up optimistic message, even if disposed
      _messages = _messages.where((m) => m.id != userMessage.id).toList();

      if (_disposed) {
        rethrow;
      }

      // Store failed message for retry
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      _failedMessage = FailedMessage(
        content: trimmedMessage,
        timestamp: DateTime.now(),
        error: errorMessage,
      );

      _isSendingMessage = false;
      _error = errorMessage;
      _safeNotifyListeners();
      rethrow;
    }
  }

  /// Retry sending the last failed message
  Future<String> retryFailedMessage() async {
    if (_failedMessage == null) {
      throw Exception('No failed message to retry');
    }

    final messageToRetry = _failedMessage!.content;
    _failedMessage = null; // Clear before retrying

    return sendMessage(messageToRetry);
  }

  /// Clear the failed message without retrying
  void clearFailedMessage() {
    if (_disposed) return;
    _failedMessage = null;
    _safeNotifyListeners();
  }

  /// Clear conversation and start fresh
  Future<void> clearConversation() async {
    if (_disposed) return;

    _isClearingConversation = true;
    _error = null;
    _safeNotifyListeners();

    try {
      final token = await _authService.getIdToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      await ApiService.clearAiTutorConversation(authToken: token);

      if (_disposed) return;

      _messages = [];
      _quickActions = [];
      _currentContext = null;
      _messageCount = 0;
      _isNewConversation = true;
      _isClearingConversation = false;
      _error = null;

      _safeNotifyListeners();
    } catch (e) {
      if (_disposed) return;
      _isClearingConversation = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      _safeNotifyListeners();
      rethrow;
    }
  }

  /// Send a quick action (convenience method)
  Future<String> sendQuickAction(QuickAction action) async {
    return sendMessage(action.prompt);
  }

  /// Clear error state
  void clearError() {
    if (_disposed) return;
    _error = null;
    _safeNotifyListeners();
  }

  /// Reset provider state (useful when user logs out)
  void reset() {
    if (_disposed) return;
    _messages = [];
    _quickActions = [];
    _currentContext = null;
    _messageCount = 0;
    _isNewConversation = true;
    _isLoadingConversation = false;
    _isSendingMessage = false;
    _isInjectingContext = false;
    _isClearingConversation = false;
    _error = null;
    _failedMessage = null;
    _safeNotifyListeners();
  }

  /// Safe notification that checks disposal state
  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _messages = [];
    _quickActions = [];
    _currentContext = null;
    _error = null;
    _failedMessage = null;
    super.dispose();
  }
}
