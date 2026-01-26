/// AI Tutor (Priya Ma'am) Models
///
/// Data models for the AI Tutor chat feature.

/// Types of chat messages
enum ChatMessageType {
  user,
  assistant,
  contextMarker,
}

/// Types of tutor contexts
enum TutorContextType {
  solution,
  quiz,
  analytics,
  general,
  mockTest,
}

/// Model for a chat message
class ChatMessage {
  final String id;
  final ChatMessageType type;
  final DateTime timestamp;

  // Content for user/assistant messages
  final String? content;

  // Context marker fields
  final String? contextType;
  final String? contextId;
  final String? contextTitle;

  ChatMessage({
    required this.id,
    required this.type,
    required this.timestamp,
    this.content,
    this.contextType,
    this.contextId,
    this.contextTitle,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      type: _parseMessageType(json['type']),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      content: json['content'],
      contextType: json['contextType'],
      contextId: json['contextId'],
      contextTitle: json['contextTitle'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'content': content,
      'contextType': contextType,
      'contextId': contextId,
      'contextTitle': contextTitle,
    };
  }

  static ChatMessageType _parseMessageType(String? type) {
    switch (type) {
      case 'user':
        return ChatMessageType.user;
      case 'assistant':
        return ChatMessageType.assistant;
      case 'context_marker':
        return ChatMessageType.contextMarker;
      default:
        return ChatMessageType.assistant;
    }
  }

  /// Check if this is a context marker
  bool get isContextMarker => type == ChatMessageType.contextMarker;

  /// Check if this is from the user
  bool get isUser => type == ChatMessageType.user;

  /// Check if this is from the assistant (Priya Ma'am)
  bool get isAssistant => type == ChatMessageType.assistant;
}

/// Model for a quick action button
class QuickAction {
  final String id;
  final String label;
  final String prompt;

  QuickAction({
    required this.id,
    required this.label,
    required this.prompt,
  });

  factory QuickAction.fromJson(Map<String, dynamic> json) {
    return QuickAction(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      prompt: json['prompt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'prompt': prompt,
    };
  }
}

/// Model for a tutor context (passed when opening chat from a specific screen)
class TutorContext {
  final TutorContextType type;
  final String? id;
  final String title;

  TutorContext({
    required this.type,
    this.id,
    required this.title,
  });

  Map<String, dynamic> toJson() {
    return {
      'contextType': type.name,
      'contextId': id,
    };
  }

  /// Get the context type string for API calls
  String get contextTypeString => type.name;
}

/// Model for context marker in the chat
class ContextMarker {
  final String id;
  final String type;
  final String title;
  final DateTime timestamp;

  ContextMarker({
    required this.id,
    required this.type,
    required this.title,
    required this.timestamp,
  });

  factory ContextMarker.fromJson(Map<String, dynamic> json) {
    return ContextMarker(
      id: json['id'] ?? '',
      type: json['type'] ?? 'general',
      title: json['title'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
}

/// Response from the AI Tutor conversation endpoint
class ConversationResponse {
  final List<ChatMessage> messages;
  final int messageCount;
  final TutorContext? currentContext;
  final List<QuickAction> quickActions;
  final bool isNewConversation;

  ConversationResponse({
    required this.messages,
    required this.messageCount,
    this.currentContext,
    required this.quickActions,
    this.isNewConversation = false,
  });

  factory ConversationResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;

    return ConversationResponse(
      messages: (data['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromJson(m))
              .toList() ??
          [],
      messageCount: data['messageCount'] ?? 0,
      currentContext: data['currentContext'] != null
          ? TutorContext(
              type: _parseContextType(data['currentContext']['type']),
              id: data['currentContext']['id'],
              title: data['currentContext']['title'] ?? '',
            )
          : null,
      quickActions: (data['quickActions'] as List<dynamic>?)
              ?.map((a) => QuickAction.fromJson(a))
              .toList() ??
          [],
      isNewConversation: data['isNewConversation'] ?? false,
    );
  }

  static TutorContextType _parseContextType(String? type) {
    switch (type) {
      case 'solution':
        return TutorContextType.solution;
      case 'quiz':
        return TutorContextType.quiz;
      case 'analytics':
        return TutorContextType.analytics;
      default:
        return TutorContextType.general;
    }
  }
}

/// Response from the inject context endpoint
class InjectContextResponse {
  final String greeting;
  final ContextMarker contextMarker;
  final List<QuickAction> quickActions;

  InjectContextResponse({
    required this.greeting,
    required this.contextMarker,
    required this.quickActions,
  });

  factory InjectContextResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;

    return InjectContextResponse(
      greeting: data['greeting'] ?? '',
      contextMarker: ContextMarker.fromJson(data['contextMarker'] ?? {}),
      quickActions: (data['quickActions'] as List<dynamic>?)
              ?.map((a) => QuickAction.fromJson(a))
              .toList() ??
          [],
    );
  }
}

/// Response from the message endpoint
class MessageResponse {
  final String response;
  final List<QuickAction> quickActions;

  MessageResponse({
    required this.response,
    required this.quickActions,
  });

  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;

    return MessageResponse(
      response: data['response'] ?? '',
      quickActions: (data['quickActions'] as List<dynamic>?)
              ?.map((a) => QuickAction.fromJson(a))
              .toList() ??
          [],
    );
  }
}
