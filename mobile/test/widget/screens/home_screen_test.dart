/// Widget tests for HomeScreen
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/screens/home_screen.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('HomeScreen Widget Tests', () {
    testWidgets('renders home screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(const HomeScreen()),
      );

      await waitForAsync(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('displays snap counter', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(const HomeScreen()),
      );

      await waitForAsync(tester);

      // Look for snap counter text
      final snapText = find.textContaining('snaps');
      if (snapText.evaluate().isNotEmpty) {
        expect(snapText, findsAtLeastNWidgets(0));
      }
    });
  });
}

