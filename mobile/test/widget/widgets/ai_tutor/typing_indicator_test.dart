import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/widgets/ai_tutor/typing_indicator.dart';
import 'package:jeevibe_mobile/widgets/priya_avatar.dart';

void main() {
  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: Scaffold(
        body: TypingIndicator(),
      ),
    );
  }

  group('TypingIndicator', () {
    testWidgets('should render without errors', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(TypingIndicator), findsOneWidget);
    });

    testWidgets('should display PriyaAvatar', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(PriyaAvatar), findsOneWidget);
    });

    testWidgets('should display three animated dots', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // The typing indicator should have 3 dot containers
      // Each dot is a Container with BoxDecoration circle shape
      final containerFinder = find.descendant(
        of: find.byType(TypingIndicator),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );

      expect(containerFinder, findsNWidgets(3));
    });

    testWidgets('should animate dots', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Pump a frame to start animation
      await tester.pump(const Duration(milliseconds: 100));

      // Animation should be running - pump more frames
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Should still render correctly after animation frames
      expect(find.byType(TypingIndicator), findsOneWidget);
    });

    testWidgets('should have correct layout structure', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Should have a Row containing avatar and dots container
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('should dispose animation controller without errors', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Advance some animation frames
      await tester.pump(const Duration(milliseconds: 500));

      // Dispose by pumping a different widget
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SizedBox()),
      ));

      // Should not throw any errors during disposal
    });

    testWidgets('should handle rapid rebuilds', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Rapid rebuilds should not cause issues
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(TypingIndicator), findsOneWidget);
    });
  });
}
