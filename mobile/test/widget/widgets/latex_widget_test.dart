/// Widget tests for LaTeXWidget
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/widgets/latex_widget.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('LaTeXWidget', () {
    testWidgets('renders simple LaTeX', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LaTeXWidget(
              text: r'\\(x^2 + y^2\\)',
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      // Verify widget is rendered
      expect(find.byType(LaTeXWidget), findsOneWidget);
    });

    testWidgets('renders empty LaTeX gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LaTeXWidget(
              text: '',
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(LaTeXWidget), findsOneWidget);
    });

    testWidgets('handles invalid LaTeX', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LaTeXWidget(
              text: r'\\(invalid latex\\)',
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      // Should render fallback
      expect(find.byType(LaTeXWidget), findsOneWidget);
    });
  });
}

