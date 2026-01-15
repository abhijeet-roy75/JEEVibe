import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/models/ai_tutor_models.dart';
import 'package:jeevibe_mobile/widgets/ai_tutor/quick_actions_row.dart';

void main() {
  Widget createWidgetUnderTest({
    required List<QuickAction> actions,
    required Function(QuickAction) onActionTap,
    bool isLoading = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: QuickActionsRow(
          actions: actions,
          onActionTap: onActionTap,
          isLoading: isLoading,
        ),
      ),
    );
  }

  final testActions = [
    QuickAction(id: '1', label: 'Explain step by step', prompt: 'Prompt 1'),
    QuickAction(id: '2', label: 'Why this approach?', prompt: 'Prompt 2'),
    QuickAction(id: '3', label: 'Similar practice', prompt: 'Prompt 3'),
  ];

  group('QuickActionsRow - Rendering', () {
    testWidgets('should render all actions as chips', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        actions: testActions,
        onActionTap: (_) {},
      ));

      expect(find.text('Explain step by step'), findsOneWidget);
      expect(find.text('Why this approach?'), findsOneWidget);
      expect(find.text('Similar practice'), findsOneWidget);
    });

    testWidgets('should render nothing when actions list is empty', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        actions: [],
        onActionTap: (_) {},
      ));

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('should render horizontally scrollable', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        actions: testActions,
        onActionTap: (_) {},
      ));

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('QuickActionsRow - Interactions', () {
    testWidgets('should call onActionTap when chip is tapped', (tester) async {
      QuickAction? tappedAction;

      await tester.pumpWidget(createWidgetUnderTest(
        actions: testActions,
        onActionTap: (action) {
          tappedAction = action;
        },
      ));

      await tester.tap(find.text('Explain step by step'));
      await tester.pump();

      expect(tappedAction, isNotNull);
      expect(tappedAction!.id, '1');
      expect(tappedAction!.label, 'Explain step by step');
      expect(tappedAction!.prompt, 'Prompt 1');
    });

    testWidgets('should disable taps when isLoading is true', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(createWidgetUnderTest(
        actions: testActions,
        onActionTap: (_) {
          tapCount++;
        },
        isLoading: true,
      ));

      await tester.tap(find.text('Explain step by step'));
      await tester.pump();

      expect(tapCount, 0);
    });

    testWidgets('should allow taps when isLoading is false', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(createWidgetUnderTest(
        actions: testActions,
        onActionTap: (_) {
          tapCount++;
        },
        isLoading: false,
      ));

      await tester.tap(find.text('Explain step by step'));
      await tester.pump();

      expect(tapCount, 1);
    });
  });

  group('QuickActionsRow - Single Action', () {
    testWidgets('should render correctly with single action', (tester) async {
      final singleAction = [
        QuickAction(id: '1', label: 'Only Action', prompt: 'Prompt'),
      ];

      await tester.pumpWidget(createWidgetUnderTest(
        actions: singleAction,
        onActionTap: (_) {},
      ));

      expect(find.text('Only Action'), findsOneWidget);
    });
  });

  group('QuickActionsRow - Multiple Actions', () {
    testWidgets('should handle many actions', (tester) async {
      final manyActions = List.generate(
        10,
        (i) => QuickAction(id: '$i', label: 'Action $i', prompt: 'Prompt $i'),
      );

      await tester.pumpWidget(createWidgetUnderTest(
        actions: manyActions,
        onActionTap: (_) {},
      ));

      // First few should be visible
      expect(find.text('Action 0'), findsOneWidget);
      expect(find.text('Action 1'), findsOneWidget);
    });

    testWidgets('should be scrollable with many actions', (tester) async {
      final manyActions = List.generate(
        10,
        (i) => QuickAction(id: '$i', label: 'Action $i', prompt: 'Prompt $i'),
      );

      await tester.pumpWidget(createWidgetUnderTest(
        actions: manyActions,
        onActionTap: (_) {},
      ));

      // Scroll to see more actions
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-200, 0),
      );
      await tester.pump();

      // Should still render correctly after scrolling
      expect(find.byType(QuickActionsRow), findsOneWidget);
    });
  });

  group('QuickActionsRow - Loading State', () {
    testWidgets('should render chips in disabled state when loading', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        actions: testActions,
        onActionTap: (_) {},
        isLoading: true,
      ));

      // Chips should still be visible but not tappable
      expect(find.text('Explain step by step'), findsOneWidget);
    });
  });
}
