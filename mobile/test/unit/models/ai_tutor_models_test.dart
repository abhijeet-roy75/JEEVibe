import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/models/ai_tutor_models.dart';

void main() {
  group('ChatMessageType', () {
    test('should have three values', () {
      expect(ChatMessageType.values.length, 3);
      expect(ChatMessageType.values, contains(ChatMessageType.user));
      expect(ChatMessageType.values, contains(ChatMessageType.assistant));
      expect(ChatMessageType.values, contains(ChatMessageType.contextMarker));
    });
  });

  group('TutorContextType', () {
    test('should have four values', () {
      expect(TutorContextType.values.length, 4);
      expect(TutorContextType.values, contains(TutorContextType.solution));
      expect(TutorContextType.values, contains(TutorContextType.quiz));
      expect(TutorContextType.values, contains(TutorContextType.analytics));
      expect(TutorContextType.values, contains(TutorContextType.general));
    });
  });

  group('ChatMessage', () {
    test('should parse user message from JSON', () {
      final json = {
        'id': 'msg1',
        'type': 'user',
        'timestamp': '2024-01-15T10:30:00.000Z',
        'content': 'What is projectile motion?',
      };

      final message = ChatMessage.fromJson(json);

      expect(message.id, 'msg1');
      expect(message.type, ChatMessageType.user);
      expect(message.content, 'What is projectile motion?');
      expect(message.isUser, true);
      expect(message.isAssistant, false);
      expect(message.isContextMarker, false);
    });

    test('should parse assistant message from JSON', () {
      final json = {
        'id': 'msg2',
        'type': 'assistant',
        'timestamp': '2024-01-15T10:31:00.000Z',
        'content': 'Projectile motion is the motion of an object...',
      };

      final message = ChatMessage.fromJson(json);

      expect(message.id, 'msg2');
      expect(message.type, ChatMessageType.assistant);
      expect(message.isAssistant, true);
      expect(message.isUser, false);
    });

    test('should parse context marker from JSON', () {
      final json = {
        'id': 'marker1',
        'type': 'context_marker',
        'timestamp': '2024-01-15T10:00:00.000Z',
        'contextType': 'solution',
        'contextId': 'snap123',
        'contextTitle': 'Kinematics - Physics',
      };

      final message = ChatMessage.fromJson(json);

      expect(message.id, 'marker1');
      expect(message.type, ChatMessageType.contextMarker);
      expect(message.isContextMarker, true);
      expect(message.contextType, 'solution');
      expect(message.contextId, 'snap123');
      expect(message.contextTitle, 'Kinematics - Physics');
    });

    test('should default to assistant type for unknown type', () {
      final json = {
        'id': 'msg3',
        'type': 'unknown',
        'content': 'Some content',
      };

      final message = ChatMessage.fromJson(json);

      expect(message.type, ChatMessageType.assistant);
    });

    test('should handle missing fields gracefully', () {
      final json = <String, dynamic>{};

      final message = ChatMessage.fromJson(json);

      expect(message.id, '');
      expect(message.type, ChatMessageType.assistant);
      expect(message.content, null);
      expect(message.contextType, null);
    });

    test('should serialize to JSON correctly', () {
      final timestamp = DateTime.parse('2024-01-15T10:30:00.000Z');
      final message = ChatMessage(
        id: 'msg1',
        type: ChatMessageType.user,
        timestamp: timestamp,
        content: 'Test message',
      );

      final json = message.toJson();

      expect(json['id'], 'msg1');
      expect(json['type'], 'user');
      expect(json['content'], 'Test message');
      expect(json['timestamp'], timestamp.toIso8601String());
    });
  });

  group('QuickAction', () {
    test('should parse from JSON', () {
      final json = {
        'id': 'action1',
        'label': 'Explain step by step',
        'prompt': 'Can you explain the solution step by step?',
      };

      final action = QuickAction.fromJson(json);

      expect(action.id, 'action1');
      expect(action.label, 'Explain step by step');
      expect(action.prompt, 'Can you explain the solution step by step?');
    });

    test('should handle missing fields', () {
      final json = <String, dynamic>{};

      final action = QuickAction.fromJson(json);

      expect(action.id, '');
      expect(action.label, '');
      expect(action.prompt, '');
    });

    test('should serialize to JSON', () {
      final action = QuickAction(
        id: 'action1',
        label: 'Test Label',
        prompt: 'Test Prompt',
      );

      final json = action.toJson();

      expect(json['id'], 'action1');
      expect(json['label'], 'Test Label');
      expect(json['prompt'], 'Test Prompt');
    });
  });

  group('TutorContext', () {
    test('should create solution context', () {
      final context = TutorContext(
        type: TutorContextType.solution,
        id: 'snap123',
        title: 'Kinematics - Physics',
      );

      expect(context.type, TutorContextType.solution);
      expect(context.id, 'snap123');
      expect(context.title, 'Kinematics - Physics');
      expect(context.contextTypeString, 'solution');
    });

    test('should create analytics context without id', () {
      final context = TutorContext(
        type: TutorContextType.analytics,
        title: 'My Progress',
      );

      expect(context.type, TutorContextType.analytics);
      expect(context.id, null);
      expect(context.contextTypeString, 'analytics');
    });

    test('should serialize to JSON for API call', () {
      final context = TutorContext(
        type: TutorContextType.quiz,
        id: 'quiz456',
        title: 'Daily Quiz #5',
      );

      final json = context.toJson();

      expect(json['contextType'], 'quiz');
      expect(json['contextId'], 'quiz456');
    });
  });

  group('ContextMarker', () {
    test('should parse from JSON', () {
      final json = {
        'id': 'marker1',
        'type': 'solution',
        'title': 'Kinematics - Physics',
        'timestamp': '2024-01-15T10:00:00.000Z',
      };

      final marker = ContextMarker.fromJson(json);

      expect(marker.id, 'marker1');
      expect(marker.type, 'solution');
      expect(marker.title, 'Kinematics - Physics');
    });

    test('should handle missing fields', () {
      final json = <String, dynamic>{};

      final marker = ContextMarker.fromJson(json);

      expect(marker.id, '');
      expect(marker.type, 'general');
      expect(marker.title, '');
    });
  });

  group('ConversationResponse', () {
    test('should parse from API response', () {
      final json = {
        'data': {
          'messages': [
            {'id': '1', 'type': 'assistant', 'content': 'Hello!'},
            {'id': '2', 'type': 'user', 'content': 'Hi'},
          ],
          'messageCount': 2,
          'currentContext': {
            'type': 'solution',
            'id': 'snap123',
            'title': 'Kinematics',
          },
          'quickActions': [
            {'id': 'a1', 'label': 'Action 1', 'prompt': 'Prompt 1'},
          ],
          'isNewConversation': false,
        }
      };

      final response = ConversationResponse.fromJson(json);

      expect(response.messages.length, 2);
      expect(response.messageCount, 2);
      expect(response.currentContext?.type, TutorContextType.solution);
      expect(response.currentContext?.id, 'snap123');
      expect(response.quickActions.length, 1);
      expect(response.isNewConversation, false);
    });

    test('should handle new conversation flag', () {
      final json = {
        'data': {
          'messages': [
            {'id': 'welcome', 'type': 'assistant', 'content': 'Welcome!'},
          ],
          'messageCount': 1,
          'currentContext': null,
          'quickActions': [],
          'isNewConversation': true,
        }
      };

      final response = ConversationResponse.fromJson(json);

      expect(response.isNewConversation, true);
      expect(response.currentContext, null);
    });

    test('should handle missing data wrapper', () {
      final json = {
        'messages': [],
        'messageCount': 0,
      };

      final response = ConversationResponse.fromJson(json);

      expect(response.messages, isEmpty);
      expect(response.messageCount, 0);
    });

    test('should parse different context types', () {
      for (final contextType in ['solution', 'quiz', 'analytics', 'general', 'unknown']) {
        final json = {
          'data': {
            'messages': [],
            'messageCount': 0,
            'currentContext': {'type': contextType},
            'quickActions': [],
          }
        };

        final response = ConversationResponse.fromJson(json);

        if (contextType == 'solution') {
          expect(response.currentContext?.type, TutorContextType.solution);
        } else if (contextType == 'quiz') {
          expect(response.currentContext?.type, TutorContextType.quiz);
        } else if (contextType == 'analytics') {
          expect(response.currentContext?.type, TutorContextType.analytics);
        } else {
          expect(response.currentContext?.type, TutorContextType.general);
        }
      }
    });
  });

  group('InjectContextResponse', () {
    test('should parse from API response', () {
      final json = {
        'data': {
          'greeting': "I see you're working on Kinematics!",
          'contextMarker': {
            'id': 'marker1',
            'type': 'solution',
            'title': 'Kinematics - Physics',
            'timestamp': '2024-01-15T10:00:00.000Z',
          },
          'quickActions': [
            {'id': 'explain', 'label': 'Explain', 'prompt': 'Explain this'},
          ],
        }
      };

      final response = InjectContextResponse.fromJson(json);

      expect(response.greeting, "I see you're working on Kinematics!");
      expect(response.contextMarker.type, 'solution');
      expect(response.contextMarker.title, 'Kinematics - Physics');
      expect(response.quickActions.length, 1);
    });

    test('should handle empty response', () {
      final json = {'data': {}};

      final response = InjectContextResponse.fromJson(json);

      expect(response.greeting, '');
      expect(response.quickActions, isEmpty);
    });
  });

  group('MessageResponse', () {
    test('should parse from API response', () {
      final json = {
        'data': {
          'response': 'Projectile motion is the motion of an object...',
          'quickActions': [
            {'id': 'more', 'label': 'Tell me more', 'prompt': 'More details'},
          ],
        }
      };

      final response = MessageResponse.fromJson(json);

      expect(response.response, 'Projectile motion is the motion of an object...');
      expect(response.quickActions.length, 1);
      expect(response.quickActions[0].label, 'Tell me more');
    });

    test('should handle empty response', () {
      final json = {'data': {}};

      final response = MessageResponse.fromJson(json);

      expect(response.response, '');
      expect(response.quickActions, isEmpty);
    });

    test('should handle missing data wrapper', () {
      final json = {
        'response': 'Direct response',
        'quickActions': [],
      };

      final response = MessageResponse.fromJson(json);

      expect(response.response, 'Direct response');
    });
  });
}
