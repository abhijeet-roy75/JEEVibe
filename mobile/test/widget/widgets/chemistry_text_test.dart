/// Widget tests for ChemistryText
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/widgets/chemistry_text.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('ChemistryText', () {
    testWidgets('renders simple formula', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChemistryText(
              'H2O',
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(ChemistryText), findsOneWidget);
    });

    testWidgets('renders complex formula', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChemistryText(
              'C6H12O6',
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(ChemistryText), findsOneWidget);
    });

    testWidgets('handles empty formula', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChemistryText(
              '',
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(ChemistryText), findsOneWidget);
    });
  });
}

