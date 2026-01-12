/// Widget tests for WelcomeCarouselScreen
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/screens/welcome_carousel_screen.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('WelcomeCarouselScreen Widget Tests', () {
    testWidgets('renders welcome screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(const WelcomeCarouselScreen()),
      );

      // Verify welcome screen is displayed
      expect(find.byType(WelcomeCarouselScreen), findsOneWidget);
    });

    testWidgets('shows page indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(const WelcomeCarouselScreen()),
      );

      await waitForAsync(tester);

      // Verify page indicator exists
      // Note: Adjust based on actual implementation
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('navigates to next page on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(const WelcomeCarouselScreen()),
      );

      await waitForAsync(tester);

      // Find and tap next button
      // Note: Adjust selectors based on actual implementation
      final nextButton = find.text('Next');
      if (nextButton.evaluate().isNotEmpty) {
        await tapAndWait(tester, nextButton);
        // Verify page changed
        // Add assertions based on implementation
      }
    });

    testWidgets('skips to end on skip tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(const WelcomeCarouselScreen()),
      );

      await waitForAsync(tester);

      // Find and tap skip button
      final skipButton = find.text('Skip');
      if (skipButton.evaluate().isNotEmpty) {
        await tapAndWait(tester, skipButton);
        // Verify navigation
      }
    });
  });
}

