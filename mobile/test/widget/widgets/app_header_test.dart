/// Widget tests for AppHeader
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/widgets/app_header.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('AppHeader Widget Tests', () {
    testWidgets('renders app header', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppHeader(title: const Text('Test Title')),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppHeader), findsOneWidget);
    });

    testWidgets('displays title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppHeader(title: const Text('Test Title')),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Test Title'), findsOneWidget);
    });

    testWidgets('handles leading widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppHeader(
              title: const Text('Test'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      // Find and tap back button if present
      final backButton = find.byIcon(Icons.arrow_back);
      if (backButton.evaluate().isNotEmpty) {
        await tapAndWait(tester, backButton);
      }
    });
  });
}

