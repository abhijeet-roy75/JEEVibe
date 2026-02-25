import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/widgets/responsive_layout.dart';

void main() {
  group('ResponsiveLayout Widget Tests', () {
    testWidgets('constrains content to default 480px on desktop viewport (>1200px width)',
        (WidgetTester tester) async {
      // Set desktop viewport size (1200px width)
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveLayout(
              child: Container(
                color: Colors.blue,
                child: const Text('Content'),
              ),
            ),
          ),
        ),
      );

      // Find the Center widget's child Container (the one with constraints)
      final centerWidget = find.byType(Center);
      expect(centerWidget, findsOneWidget);

      // Get the Container that's a child of Center
      final container = tester.widget<Container>(
        find.descendant(
          of: centerWidget,
          matching: find.byType(Container).first,
        ),
      );

      // Verify it has max-width constraint (default 480)
      expect(container.constraints, isNotNull);
      expect(container.constraints!.maxWidth, equals(480));

      // Reset to default size
      addTearDown(() => tester.view.resetPhysicalSize());
    });

    testWidgets('does NOT constrain content on mobile viewport (<1200px width)',
        (WidgetTester tester) async {
      // Set mobile viewport size (375px width)
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveLayout(
              child: Container(
                color: Colors.blue,
                child: const Text('Content'),
              ),
            ),
          ),
        ),
      );

      // Find the Center widget's child Container
      final centerWidget = find.byType(Center);
      final container = tester.widget<Container>(
        find.descendant(
          of: centerWidget,
          matching: find.byType(Container).first,
        ),
      );

      // Verify it has NO constraints (null) on mobile
      expect(container.constraints, isNull);

      // Reset to default size
      addTearDown(() => tester.view.resetPhysicalSize());
    });

    testWidgets('centers content horizontally on desktop',
        (WidgetTester tester) async {
      // Set desktop viewport
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveLayout(
              child: Container(
                color: Colors.blue,
                child: const Text('Centered Content'),
              ),
            ),
          ),
        ),
      );

      // Verify Center widget exists
      expect(find.byType(Center), findsOneWidget);

      // Reset to default size
      addTearDown(() => tester.view.resetPhysicalSize());
    });

    testWidgets('respects custom maxWidth parameter',
        (WidgetTester tester) async {
      // Set desktop viewport
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      const customMaxWidth = 900.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveLayout(
              maxWidth: customMaxWidth,
              child: Container(
                color: Colors.green,
                child: const Text('Custom Width'),
              ),
            ),
          ),
        ),
      );

      // Find the Container with constraints
      final centerWidget = find.byType(Center);
      final container = tester.widget<Container>(
        find.descendant(
          of: centerWidget,
          matching: find.byType(Container).first,
        ),
      );

      // Verify custom max-width
      expect(container.constraints, isNotNull);
      expect(container.constraints!.maxWidth, equals(customMaxWidth));

      // Reset to default size
      addTearDown(() => tester.view.resetPhysicalSize());
    });

    testWidgets('uses SafeArea by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveLayout(
              child: Container(child: const Text('Safe')),
            ),
          ),
        ),
      );

      // Verify SafeArea exists
      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('can disable SafeArea', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveLayout(
              useSafeArea: false,
              child: Container(child: const Text('Unsafe')),
            ),
          ),
        ),
      );

      // Verify SafeArea does NOT exist
      expect(find.byType(SafeArea), findsNothing);
    });
  });

  group('isDesktopViewport Helper Function Tests', () {
    testWidgets('returns true for viewport width > 1200px',
        (WidgetTester tester) async {
      // Set desktop viewport (must be > 1200, not >= 1200)
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1.0;

      bool? isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isDesktop = isDesktopViewport(context);
              return Container();
            },
          ),
        ),
      );

      expect(isDesktop, isTrue);

      // Reset to default size
      addTearDown(() => tester.view.resetPhysicalSize());
    });

    testWidgets('returns false for viewport width <= 1200px',
        (WidgetTester tester) async {
      // Set mobile viewport
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;

      bool? isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isDesktop = isDesktopViewport(context);
              return Container();
            },
          ),
        ),
      );

      expect(isDesktop, isFalse);

      // Reset to default size
      addTearDown(() => tester.view.resetPhysicalSize());
    });

    testWidgets('returns false for exactly 1200px width',
        (WidgetTester tester) async {
      // Set viewport to exactly 1200px
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      bool? isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isDesktop = isDesktopViewport(context);
              return Container();
            },
          ),
        ),
      );

      expect(isDesktop, isFalse); // > 1200, not >= 1200

      // Reset to default size
      addTearDown(() => tester.view.resetPhysicalSize());
    });

    testWidgets('returns true for 1201px width', (WidgetTester tester) async {
      // Set viewport to 1201px (just above threshold)
      tester.view.physicalSize = const Size(1201, 800);
      tester.view.devicePixelRatio = 1.0;

      bool? isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isDesktop = isDesktopViewport(context);
              return Container();
            },
          ),
        ),
      );

      expect(isDesktop, isTrue);

      // Reset to default size
      addTearDown(() => tester.view.resetPhysicalSize());
    });
  });
}
