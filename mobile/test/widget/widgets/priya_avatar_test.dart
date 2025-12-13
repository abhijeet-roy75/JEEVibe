/// Widget tests for PriyaAvatar
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/widgets/priya_avatar.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('PriyaAvatar Widget Tests', () {
    testWidgets('renders Priya avatar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriyaAvatar(size: 50),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(PriyaAvatar), findsOneWidget);
    });

    testWidgets('renders with custom size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriyaAvatar(size: 100),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(PriyaAvatar), findsOneWidget);
    });
  });
}

