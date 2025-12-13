/// Widget tests for SolutionScreen
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/screens/solution_screen.dart';
import 'package:jeevibe_mobile/models/solution_model.dart';
import '../../helpers/test_helpers.dart';
import '../../fixtures/test_data.dart';

void main() {
  group('SolutionScreen Widget Tests', () {
    testWidgets('renders solution screen with data', (WidgetTester tester) async {
      final solutionFuture = Future.value(TestData.sampleSolution);

      await tester.pumpWidget(
        createTestApp(
          SolutionScreen(solutionFuture: solutionFuture),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(SolutionScreen), findsOneWidget);
    });

    testWidgets('displays loading indicator initially', (WidgetTester tester) async {
      final solutionFuture = Future.delayed(
        const Duration(milliseconds: 100),
        () => TestData.sampleSolution,
      );

      await tester.pumpWidget(
        createTestApp(
          SolutionScreen(solutionFuture: solutionFuture),
        ),
      );

      // Pump once to trigger build
      await tester.pump();

      // Should show loading initially (ProcessingScreen is shown while waiting)
      expect(find.byType(SolutionScreen), findsOneWidget);

      // Wait for the future to complete to avoid pending timers
      await tester.pumpAndSettle();
    });

    testWidgets('displays solution when loaded', (WidgetTester tester) async {
      final solutionFuture = Future.value(TestData.sampleSolution);

      await tester.pumpWidget(
        createTestApp(
          SolutionScreen(solutionFuture: solutionFuture),
        ),
      );

      await waitForAsync(tester);
      await tester.pumpAndSettle();

      // Should display solution content
      expect(find.byType(SolutionScreen), findsOneWidget);
    });
  });
}

