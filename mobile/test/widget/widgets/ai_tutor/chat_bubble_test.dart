import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/models/ai_tutor_models.dart';
import 'package:jeevibe_mobile/widgets/ai_tutor/chat_bubble.dart';
import 'package:jeevibe_mobile/widgets/priya_avatar.dart';

void main() {
  Widget createWidgetUnderTest(ChatMessage message, {bool showAvatar = true}) {
    return MaterialApp(
      home: Scaffold(
        body: ChatBubble(
          message: message,
          showAvatar: showAvatar,
        ),
      ),
    );
  }

  group('ChatBubble - User Messages', () {
    testWidgets('should display user message content', (tester) async {
      final message = ChatMessage(
        id: '1',
        type: ChatMessageType.user,
        timestamp: DateTime.now(),
        content: 'What is projectile motion?',
      );

      await tester.pumpWidget(createWidgetUnderTest(message));

      expect(find.text('What is projectile motion?'), findsOneWidget);
    });

    testWidgets('should align user message to the right', (tester) async {
      final message = ChatMessage(
        id: '1',
        type: ChatMessageType.user,
        timestamp: DateTime.now(),
        content: 'Test message',
      );

      await tester.pumpWidget(createWidgetUnderTest(message));

      // Find the Row that contains the user bubble
      final rowFinder = find.byType(Row);
      expect(rowFinder, findsWidgets);

      // The first Row should have mainAxisAlignment.end for user messages
      final row = tester.widget<Row>(rowFinder.first);
      expect(row.mainAxisAlignment, MainAxisAlignment.end);
    });

    testWidgets('should not show avatar for user messages', (tester) async {
      final message = ChatMessage(
        id: '1',
        type: ChatMessageType.user,
        timestamp: DateTime.now(),
        content: 'Test message',
      );

      await tester.pumpWidget(createWidgetUnderTest(message));

      expect(find.byType(PriyaAvatar), findsNothing);
    });

    testWidgets('should handle empty content gracefully', (tester) async {
      final message = ChatMessage(
        id: '1',
        type: ChatMessageType.user,
        timestamp: DateTime.now(),
        content: '',
      );

      await tester.pumpWidget(createWidgetUnderTest(message));

      // Should not crash with empty content
      expect(find.byType(ChatBubble), findsOneWidget);
    });

    testWidgets('should handle null content gracefully', (tester) async {
      final message = ChatMessage(
        id: '1',
        type: ChatMessageType.user,
        timestamp: DateTime.now(),
        content: null,
      );

      await tester.pumpWidget(createWidgetUnderTest(message));

      // Should not crash with null content
      expect(find.byType(ChatBubble), findsOneWidget);
    });
  });

  group('ChatBubble - Assistant Messages', () {
    testWidgets('should display assistant message content', (tester) async {
      final message = ChatMessage(
        id: '1',
        type: ChatMessageType.assistant,
        timestamp: DateTime.now(),
        content: 'Projectile motion is the motion of an object thrown into the air.',
      );

      await tester.pumpWidget(createWidgetUnderTest(message));

      expect(
        find.text('Projectile motion is the motion of an object thrown into the air.'),
        findsOneWidget,
      );
    });

    testWidgets('should show PriyaAvatar when showAvatar is true', (tester) async {
      final message = ChatMessage(
        id: '1',
        type: ChatMessageType.assistant,
        timestamp: DateTime.now(),
        content: 'Hello!',
      );

      await tester.pumpWidget(createWidgetUnderTest(message, showAvatar: true));

      expect(find.byType(PriyaAvatar), findsOneWidget);
    });

    testWidgets('should not show PriyaAvatar when showAvatar is false', (tester) async {
      final message = ChatMessage(
        id: '1',
        type: ChatMessageType.assistant,
        timestamp: DateTime.now(),
        content: 'Hello!',
      );

      await tester.pumpWidget(createWidgetUnderTest(message, showAvatar: false));

      expect(find.byType(PriyaAvatar), findsNothing);
    });

    testWidgets('should align assistant message to the left', (tester) async {
      final message = ChatMessage(
        id: '1',
        type: ChatMessageType.assistant,
        timestamp: DateTime.now(),
        content: 'Test message',
      );

      await tester.pumpWidget(createWidgetUnderTest(message));

      // Find the Row that contains the assistant bubble
      final rowFinder = find.byType(Row);
      expect(rowFinder, findsWidgets);

      // The first Row should have default (start) alignment for assistant messages
      final row = tester.widget<Row>(rowFinder.first);
      expect(row.mainAxisAlignment, MainAxisAlignment.start);
    });
  });

  group('ChatBubble - LaTeX Support', () {
    testWidgets('should render text with potential LaTeX', (tester) async {
      final message = ChatMessage(
        id: '1',
        type: ChatMessageType.assistant,
        timestamp: DateTime.now(),
        content: r'The formula is $v = u + at$',
      );

      await tester.pumpWidget(createWidgetUnderTest(message));

      // The LaTeXWidget should be present and handle the LaTeX
      expect(find.byType(ChatBubble), findsOneWidget);
    });
  });
}
