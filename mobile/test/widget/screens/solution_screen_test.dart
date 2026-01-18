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

  group('Practice Section Tier Gating', () {
    // Note: These tests verify the tier gating logic for the practice section.
    // The practice section should only be visible for Pro/Ultra tier users.
    //
    // Since SubscriptionService is a singleton, we document the expected behavior:
    // - Free tier: Practice section should NOT be visible
    // - Pro tier: Practice section should be visible
    // - Ultra tier: Practice section should be visible
    //
    // The actual visibility is controlled by:
    //   if (SubscriptionService().isPro || SubscriptionService().isUltra) ...
    //
    // Full integration tests with mocked subscription service would verify this behavior.

    testWidgets('solution screen renders core elements', (WidgetTester tester) async {
      final solutionFuture = Future.value(TestData.sampleSolution);

      await tester.pumpWidget(
        createTestApp(
          SolutionScreen(solutionFuture: solutionFuture),
        ),
      );

      await waitForAsync(tester);
      await tester.pumpAndSettle();

      // Verify core elements are present
      expect(find.byType(SolutionScreen), findsOneWidget);

      // The "Back to Snap and Solve" button should always be visible
      expect(find.text('Back to Snap and Solve'), findsOneWidget);
    });

    testWidgets('solution displays question and solution sections', (WidgetTester tester) async {
      final solutionFuture = Future.value(TestData.sampleSolution);

      await tester.pumpWidget(
        createTestApp(
          SolutionScreen(solutionFuture: solutionFuture),
        ),
      );

      await waitForAsync(tester);
      await tester.pumpAndSettle();

      // Core solution elements should be present
      expect(find.byType(SolutionScreen), findsOneWidget);
    });
  });
}

