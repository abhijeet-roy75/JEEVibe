import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:jeevibe_mobile/models/ai_tutor_models.dart';
import 'package:jeevibe_mobile/providers/ai_tutor_provider.dart';
import 'package:jeevibe_mobile/services/firebase/auth_service.dart';
import 'package:jeevibe_mobile/services/api_service.dart';

// Mock classes
class MockAuthService extends Mock implements AuthService {}

void main() {
  late AiTutorProvider provider;
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
    provider = AiTutorProvider(mockAuthService);
  });

  tearDown(() {
    provider.dispose();
  });

  group('AiTutorProvider - Initial State', () {
    test('should have empty messages initially', () {
      expect(provider.messages, isEmpty);
      expect(provider.hasConversation, false);
      expect(provider.hasMessages, false);
    });

    test('should have no current context initially', () {
      expect(provider.currentContext, null);
    });

    test('should have empty quick actions initially', () {
      expect(provider.quickActions, isEmpty);
    });

    test('should not be loading initially', () {
      expect(provider.isLoadingConversation, false);
      expect(provider.isSendingMessage, false);
      expect(provider.isInjectingContext, false);
      expect(provider.isClearingConversation, false);
      expect(provider.isLoading, false);
    });

    test('should have no error initially', () {
      expect(provider.error, null);
      expect(provider.hasError, false);
    });

    test('should be a new conversation initially', () {
      expect(provider.isNewConversation, true);
    });

    test('should have zero message count initially', () {
      expect(provider.messageCount, 0);
    });
  });

  group('AiTutorProvider - loadConversation', () {
    test('should set loading state during load', () async {
      when(() => mockAuthService.getIdToken()).thenAnswer((_) async => null);

      var loadingStateObserved = false;
      provider.addListener(() {
        if (provider.isLoadingConversation) {
          loadingStateObserved = true;
        }
      });

      try {
        await provider.loadConversation();
      } catch (_) {}

      expect(loadingStateObserved, true);
    });

    test('should throw error when auth token is null', () async {
      when(() => mockAuthService.getIdToken()).thenAnswer((_) async => null);

      expect(
        () => provider.loadConversation(),
        throwsA(isA<Exception>()),
      );
    });

    test('should set error state on failure', () async {
      when(() => mockAuthService.getIdToken()).thenAnswer((_) async => null);

      try {
        await provider.loadConversation();
      } catch (_) {}

      expect(provider.hasError, true);
      expect(provider.isLoadingConversation, false);
    });
  });

  group('AiTutorProvider - injectContext', () {
    final testContext = TutorContext(
      type: TutorContextType.solution,
      id: 'snap123',
      title: 'Kinematics - Physics',
    );

    test('should set injecting context state during operation', () async {
      when(() => mockAuthService.getIdToken()).thenAnswer((_) async => null);

      var injectingStateObserved = false;
      provider.addListener(() {
        if (provider.isInjectingContext) {
          injectingStateObserved = true;
        }
      });

      try {
        await provider.injectContext(testContext);
      } catch (_) {}

      expect(injectingStateObserved, true);
    });

    test('should throw error when auth token is null', () async {
      when(() => mockAuthService.getIdToken()).thenAnswer((_) async => null);

      expect(
        () => provider.injectContext(testContext),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('AiTutorProvider - sendMessage', () {
    test('should throw error for empty message', () async {
      expect(
        () => provider.sendMessage(''),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw error for whitespace-only message', () async {
      expect(
        () => provider.sendMessage('   '),
        throwsA(isA<Exception>()),
      );
    });

    test('should set sending state during operation', () async {
      when(() => mockAuthService.getIdToken()).thenAnswer((_) async => null);

      var sendingStateObserved = false;
      provider.addListener(() {
        if (provider.isSendingMessage) {
          sendingStateObserved = true;
        }
      });

      try {
        await provider.sendMessage('Test message');
      } catch (_) {}

      expect(sendingStateObserved, true);
    });

    test('should add optimistic user message before API call', () async {
      when(() => mockAuthService.getIdToken()).thenAnswer((_) async => null);

      var messageAddedOptimistically = false;
      provider.addListener(() {
        if (provider.messages.any((m) => m.content == 'Test message')) {
          messageAddedOptimistically = true;
        }
      });

      try {
        await provider.sendMessage('Test message');
      } catch (_) {}

      expect(messageAddedOptimistically, true);
    });

    test('should remove optimistic message on error', () async {
      when(() => mockAuthService.getIdToken()).thenAnswer((_) async => null);

      try {
        await provider.sendMessage('Test message');
      } catch (_) {}

      // After error, the optimistic message should be removed
      expect(
        provider.messages.where((m) => m.content == 'Test message').isEmpty,
        true,
      );
    });
  });

  group('AiTutorProvider - sendQuickAction', () {
    test('should send quick action prompt as message', () async {
      when(() => mockAuthService.getIdToken()).thenAnswer((_) async => null);

      final quickAction = QuickAction(
        id: 'action1',
        label: 'Explain step by step',
        prompt: 'Can you explain the solution step by step?',
      );

      // The sendQuickAction should try to send the prompt
      expect(
        () => provider.sendQuickAction(quickAction),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('AiTutorProvider - clearConversation', () {
    test('should set clearing state during operation', () async {
      when(() => mockAuthService.getIdToken()).thenAnswer((_) async => null);

      var clearingStateObserved = false;
      provider.addListener(() {
        if (provider.isClearingConversation) {
          clearingStateObserved = true;
        }
      });

      try {
        await provider.clearConversation();
      } catch (_) {}

      expect(clearingStateObserved, true);
    });

    test('should throw error when auth token is null', () async {
      when(() => mockAuthService.getIdToken()).thenAnswer((_) async => null);

      expect(
        () => provider.clearConversation(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('AiTutorProvider - clearError', () {
    test('should clear error state', () async {
      when(() => mockAuthService.getIdToken()).thenAnswer((_) async => null);

      // Cause an error
      try {
        await provider.loadConversation();
      } catch (_) {}

      expect(provider.hasError, true);

      // Clear the error
      provider.clearError();

      expect(provider.hasError, false);
      expect(provider.error, null);
    });
  });

  group('AiTutorProvider - reset', () {
    test('should reset all state to initial values', () {
      // Reset should restore initial state
      provider.reset();

      expect(provider.messages, isEmpty);
      expect(provider.quickActions, isEmpty);
      expect(provider.currentContext, null);
      expect(provider.messageCount, 0);
      expect(provider.isNewConversation, true);
      expect(provider.isLoading, false);
      expect(provider.hasError, false);
    });
  });

  group('AiTutorProvider - isLoading', () {
    test('should return true when any operation is loading', () async {
      when(() => mockAuthService.getIdToken()).thenAnswer((_) async => null);

      var anyLoadingObserved = false;
      provider.addListener(() {
        if (provider.isLoading) {
          anyLoadingObserved = true;
        }
      });

      try {
        await provider.loadConversation();
      } catch (_) {}

      expect(anyLoadingObserved, true);
    });
  });

  group('AiTutorProvider - hasMessages', () {
    test('should return false for empty messages', () {
      expect(provider.hasMessages, false);
    });
  });

  group('AiTutorProvider - dispose', () {
    test('should handle operations after dispose gracefully', () async {
      provider.dispose();

      // Operations should not throw after dispose
      await provider.loadConversation(); // Should return early without throwing

      expect(provider.messages, isEmpty);
    });

    test('should throw if sendMessage called after dispose', () {
      provider.dispose();

      expect(
        () => provider.sendMessage('test'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('AiTutorProvider - notifyListeners', () {
    test('should notify listeners on state changes', () async {
      var notificationCount = 0;
      provider.addListener(() {
        notificationCount++;
      });

      when(() => mockAuthService.getIdToken()).thenAnswer((_) async => null);

      try {
        await provider.loadConversation();
      } catch (_) {}

      // Should have notified at least twice (loading start, loading end/error)
      expect(notificationCount, greaterThanOrEqualTo(2));
    });
  });

  group('AiTutorProvider - messages immutability', () {
    test('should return unmodifiable messages list', () {
      expect(
        () => provider.messages.add(ChatMessage(
          id: 'test',
          type: ChatMessageType.user,
          timestamp: DateTime.now(),
          content: 'test',
        )),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should return unmodifiable quick actions list', () {
      expect(
        () => provider.quickActions.add(QuickAction(
          id: 'test',
          label: 'test',
          prompt: 'test',
        )),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
