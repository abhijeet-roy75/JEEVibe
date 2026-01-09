/// Widget tests for GradientButton, AppOutlinedButton, and AppTextButton
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/widgets/buttons/gradient_button.dart';
import 'package:jeevibe_mobile/theme/app_colors.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('GradientButton Widget Tests', () {
    testWidgets('renders gradient button with text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradientButton(
              text: 'Test Button',
              onPressed: () {},
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(GradientButton), findsOneWidget);
      expect(find.text('Test Button'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradientButton(
              text: 'Tap Me',
              onPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.byType(GradientButton));
      await waitForAsync(tester);

      expect(wasPressed, isTrue);
    });

    testWidgets('does not call onPressed when disabled', (WidgetTester tester) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradientButton(
              text: 'Disabled',
              onPressed: null,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.byType(GradientButton));
      await waitForAsync(tester);

      expect(wasPressed, isFalse);
    });

    testWidgets('shows loading indicator when isLoading is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradientButton(
              text: 'Loading',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Text should be hidden when loading
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('renders leading icon when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradientButton(
              text: 'With Icon',
              onPressed: () {},
              leadingIcon: Icons.camera_alt,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('renders trailing icon when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradientButton(
              text: 'With Arrow',
              onPressed: () {},
              trailingIcon: Icons.arrow_forward,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('renders different sizes correctly', (WidgetTester tester) async {
      // Test small size
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradientButton(
              text: 'Small',
              onPressed: () {},
              size: GradientButtonSize.small,
            ),
          ),
        ),
      );

      await waitForAsync(tester);
      expect(find.byType(GradientButton), findsOneWidget);

      // Test medium size
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradientButton(
              text: 'Medium',
              onPressed: () {},
              size: GradientButtonSize.medium,
            ),
          ),
        ),
      );

      await waitForAsync(tester);
      expect(find.byType(GradientButton), findsOneWidget);

      // Test large size
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradientButton(
              text: 'Large',
              onPressed: () {},
              size: GradientButtonSize.large,
            ),
          ),
        ),
      );

      await waitForAsync(tester);
      expect(find.byType(GradientButton), findsOneWidget);
    });

    testWidgets('applies opacity when disabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradientButton(
              text: 'Disabled',
              onPressed: null,
              isDisabled: true,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      final animatedOpacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      expect(animatedOpacity.opacity, equals(0.6));
    });
  });

  group('AppOutlinedButton Widget Tests', () {
    testWidgets('renders outlined button with text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppOutlinedButton(
              text: 'Outlined Button',
              onPressed: () {},
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppOutlinedButton), findsOneWidget);
      expect(find.text('Outlined Button'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppOutlinedButton(
              text: 'Tap Me',
              onPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.byType(AppOutlinedButton));
      await waitForAsync(tester);

      expect(wasPressed, isTrue);
    });

    testWidgets('renders with leading icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppOutlinedButton(
              text: 'With Icon',
              onPressed: () {},
              leadingIcon: Icons.refresh,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppOutlinedButton(
              text: 'Loading',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AppTextButton Widget Tests', () {
    testWidgets('renders text button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextButton(
              text: 'Skip for now',
              onPressed: () {},
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppTextButton), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextButton(
              text: 'Tap Me',
              onPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.byType(AppTextButton));
      await waitForAsync(tester);

      expect(wasPressed, isTrue);
    });

    testWidgets('renders with custom text color', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextButton(
              text: 'Custom Color',
              onPressed: () {},
              textColor: Colors.red,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppTextButton), findsOneWidget);
    });

    testWidgets('renders with leading icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextButton(
              text: 'With Icon',
              onPressed: () {},
              leadingIcon: Icons.info,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byIcon(Icons.info), findsOneWidget);
    });
  });
}
