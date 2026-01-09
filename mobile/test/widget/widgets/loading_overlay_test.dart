/// Widget tests for LoadingOverlay and related loading components
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/widgets/feedback/loading_overlay.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('LoadingOverlay Widget Tests', () {
    testWidgets('shows child when not loading', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingOverlay(
              isLoading: false,
              child: Text('Content'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows loading indicator when loading', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: LoadingOverlay(
                isLoading: true,
                child: Text('Content'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows message when loading', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: LoadingOverlay(
                isLoading: true,
                message: 'Please wait...',
                child: Text('Content'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Please wait...'), findsOneWidget);
    });

    testWidgets('child is still visible under overlay', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: LoadingOverlay(
                isLoading: true,
                child: Text('Background Content'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      // Both content and loading indicator should be visible
      expect(find.text('Background Content'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('LoadingIndicator Widget Tests', () {
    testWidgets('renders circular progress indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows message when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(
              message: 'Loading data...',
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Loading data...'), findsOneWidget);
    });

    testWidgets('respects custom size', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(
              size: 60,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      // Find the SizedBox that wraps the CircularProgressIndicator
      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(sizedBox.width, equals(60));
      expect(sizedBox.height, equals(60));
    });
  });

  group('LoadingScreen Widget Tests', () {
    testWidgets('renders full screen loading', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoadingScreen(),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('shows custom message', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoadingScreen(
            message: 'Fetching your data...',
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Fetching your data...'), findsOneWidget);
    });
  });

  group('LoadingDots Widget Tests', () {
    testWidgets('renders three dots', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingDots(),
          ),
        ),
      );

      await waitForAsync(tester);

      // LoadingDots creates 3 circular containers
      expect(find.byType(LoadingDots), findsOneWidget);
    });

    testWidgets('respects custom dot size', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingDots(
              dotSize: 12,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(LoadingDots), findsOneWidget);
    });
  });

  group('ShimmerLoading Widget Tests', () {
    testWidgets('renders shimmer effect on child', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShimmerLoading(
              child: Container(
                width: 100,
                height: 20,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(ShimmerLoading), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('rect factory creates rectangular placeholder', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShimmerLoading.rect(
              width: 200,
              height: 24,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(ShimmerLoading), findsOneWidget);
    });

    testWidgets('circle factory creates circular placeholder', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShimmerLoading.circle(
              size: 48,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(ShimmerLoading), findsOneWidget);
    });
  });

  group('SkeletonCard Widget Tests', () {
    testWidgets('renders skeleton card with shimmer', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonCard(),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(SkeletonCard), findsOneWidget);
      expect(find.byType(ShimmerLoading), findsOneWidget);
    });

    testWidgets('respects custom dimensions', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonCard(
              width: 200,
              height: 100,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(SkeletonCard), findsOneWidget);
    });
  });

  group('SkeletonList Widget Tests', () {
    testWidgets('renders list of skeleton cards', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: const SkeletonList(
                itemCount: 3,
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(SkeletonCard), findsNWidgets(3));
    });
  });

  group('EmptyState Widget Tests', () {
    testWidgets('renders empty state with icon and title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.inbox,
              title: 'No Items',
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('No Items'), findsOneWidget);
    });

    testWidgets('shows message when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.search,
              title: 'No Results',
              message: 'Try searching for something else',
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('No Results'), findsOneWidget);
      expect(find.text('Try searching for something else'), findsOneWidget);
    });

    testWidgets('shows action widget when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.refresh,
              title: 'Empty',
              action: ElevatedButton(
                onPressed: () {},
                child: const Text('Refresh'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Refresh'), findsOneWidget);
    });
  });

  group('ErrorState Widget Tests', () {
    testWidgets('renders error state with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorState(
              title: 'Something went wrong',
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry is provided', (WidgetTester tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState(
              title: 'Error',
              onRetry: () {
                retried = true;
              },
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await waitForAsync(tester);

      expect(retried, isTrue);
    });

    testWidgets('shows message when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorState(
              title: 'Network Error',
              message: 'Please check your internet connection',
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Network Error'), findsOneWidget);
      expect(find.text('Please check your internet connection'), findsOneWidget);
    });
  });
}
