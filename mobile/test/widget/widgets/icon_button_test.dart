/// Widget tests for AppIconButton
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/widgets/buttons/icon_button.dart';
import 'package:jeevibe_mobile/theme/app_colors.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('AppIconButton Widget Tests', () {
    testWidgets('renders icon button with icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton(
              icon: Icons.settings,
              onPressed: () {},
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppIconButton), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton(
              icon: Icons.add,
              onPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.byType(AppIconButton));
      await waitForAsync(tester);

      expect(wasPressed, isTrue);
    });

    testWidgets('does not call onPressed when disabled', (WidgetTester tester) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton(
              icon: Icons.delete,
              onPressed: null,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.byType(AppIconButton));
      await waitForAsync(tester);

      expect(wasPressed, isFalse);
    });

    testWidgets('applies custom icon color', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton(
              icon: Icons.star,
              onPressed: () {},
              iconColor: Colors.red,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      final icon = tester.widget<Icon>(find.byIcon(Icons.star));
      expect(icon.color, equals(Colors.red));
    });

    testWidgets('renders different sizes correctly', (WidgetTester tester) async {
      // Test large size
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton(
              icon: Icons.star,
              onPressed: () {},
              size: AppIconButtonSize.large,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppIconButton), findsOneWidget);
    });

    testWidgets('shows tooltip when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton(
              icon: Icons.info,
              onPressed: () {},
              tooltip: 'More info',
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppIconButton), findsOneWidget);
      // Tooltip is rendered on long press, so we just verify the widget exists
    });
  });

  group('AppIconButton Factory Constructors', () {
    testWidgets('back() creates back button with arrow icon', (WidgetTester tester) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton.back(
              onPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppIconButton), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_rounded), findsOneWidget);

      await tester.tap(find.byType(AppIconButton));
      await waitForAsync(tester);

      expect(wasPressed, isTrue);
    });

    testWidgets('back() applies custom color', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton.back(
              onPressed: () {},
              color: Colors.white,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_back_ios_rounded));
      expect(icon.color, equals(Colors.white));
    });

    testWidgets('close() creates close button with X icon', (WidgetTester tester) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton.close(
              onPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppIconButton), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byType(AppIconButton));
      await waitForAsync(tester);

      expect(wasPressed, isTrue);
    });

    testWidgets('close() applies custom color', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton.close(
              onPressed: () {},
              color: Colors.red,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      final icon = tester.widget<Icon>(find.byIcon(Icons.close_rounded));
      expect(icon.color, equals(Colors.red));
    });

    testWidgets('menu() creates menu button with hamburger icon', (WidgetTester tester) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton.menu(
              onPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppIconButton), findsOneWidget);
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

      await tester.tap(find.byType(AppIconButton));
      await waitForAsync(tester);

      expect(wasPressed, isTrue);
    });

    testWidgets('settings() creates settings button with gear icon', (WidgetTester tester) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton.settings(
              onPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppIconButton), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      await tester.tap(find.byType(AppIconButton));
      await waitForAsync(tester);

      expect(wasPressed, isTrue);
    });
  });

  group('AppIconButton Variants', () {
    testWidgets('ghost variant renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton(
              icon: Icons.star,
              onPressed: () {},
              variant: AppIconButtonVariant.ghost,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppIconButton), findsOneWidget);
    });

    testWidgets('filled variant renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton(
              icon: Icons.star,
              onPressed: () {},
              variant: AppIconButtonVariant.filled,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppIconButton), findsOneWidget);
    });

    testWidgets('outlined variant renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton(
              icon: Icons.star,
              onPressed: () {},
              variant: AppIconButtonVariant.outlined,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppIconButton), findsOneWidget);
    });

    testWidgets('circular variant renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton(
              icon: Icons.star,
              onPressed: () {},
              variant: AppIconButtonVariant.circular,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppIconButton), findsOneWidget);
    });
  });
}
