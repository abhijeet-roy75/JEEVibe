/// Widget tests for AppCard, PriyaCard, and SectionCard
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/widgets/cards/app_card.dart';
import 'package:jeevibe_mobile/theme/app_colors.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('AppCard Widget Tests', () {
    testWidgets('renders card with child content', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: const Text('Card Content'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppCard), findsOneWidget);
      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: const Text('Tappable Card'),
              onTap: () {
                wasTapped = true;
              },
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.byType(AppCard));
      await waitForAsync(tester);

      expect(wasTapped, isTrue);
    });

    testWidgets('renders with custom padding', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: const Text('Padded Card'),
              padding: const EdgeInsets.all(32),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppCard), findsOneWidget);
    });

    testWidgets('renders with custom margin', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: const Text('Card with Margin'),
              margin: const EdgeInsets.all(16),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppCard), findsOneWidget);
    });

    testWidgets('renders header when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              header: const Text('Header Text'),
              child: const Text('Card Content'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Header Text'), findsOneWidget);
      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('renders footer when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: const Text('Card Content'),
              footer: const Text('Footer Text'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Card Content'), findsOneWidget);
      expect(find.text('Footer Text'), findsOneWidget);
    });

    testWidgets('renders selected state correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: const Text('Selected Card'),
              isSelected: true,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppCard), findsOneWidget);
      // The card should render with selection styling
    });
  });

  group('AppCard Variants', () {
    testWidgets('elevated variant renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              variant: AppCardVariant.elevated,
              child: const Text('Elevated Card'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppCard), findsOneWidget);
    });

    testWidgets('outlined variant renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              variant: AppCardVariant.outlined,
              child: const Text('Outlined Card'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppCard), findsOneWidget);
    });

    testWidgets('gradient variant renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              variant: AppCardVariant.gradient,
              child: const Text('Gradient Card'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppCard), findsOneWidget);
    });

    testWidgets('success variant renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              variant: AppCardVariant.success,
              child: const Text('Success Card'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppCard), findsOneWidget);
    });

    testWidgets('error variant renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              variant: AppCardVariant.error,
              child: const Text('Error Card'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppCard), findsOneWidget);
    });

    testWidgets('warning variant renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              variant: AppCardVariant.warning,
              child: const Text('Warning Card'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppCard), findsOneWidget);
    });

    testWidgets('info variant renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              variant: AppCardVariant.info,
              child: const Text('Info Card'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppCard), findsOneWidget);
    });

    testWidgets('flat variant renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              variant: AppCardVariant.flat,
              child: const Text('Flat Card'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppCard), findsOneWidget);
    });
  });

  group('AppCard.listItem Factory', () {
    testWidgets('creates list item card', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard.listItem(
              child: const Text('List Item'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppCard), findsOneWidget);
      expect(find.text('List Item'), findsOneWidget);
    });

    testWidgets('renders with leading widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard.listItem(
              leading: const Icon(Icons.star),
              child: const Text('List Item with Leading'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('List Item with Leading'), findsOneWidget);
    });

    testWidgets('renders with trailing widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard.listItem(
              child: const Text('List Item with Trailing'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('List Item with Trailing'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  group('AppCard.stat Factory', () {
    testWidgets('creates stat card with label and value', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard.stat(
              label: 'Questions',
              value: '42',
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(AppCard), findsOneWidget);
      expect(find.text('Questions'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('renders with icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard.stat(
              label: 'Accuracy',
              value: '85%',
              icon: Icons.check_circle,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);
    });
  });

  group('PriyaCard Widget Tests', () {
    testWidgets('renders Priya card with gradient', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriyaCard(
              child: const Text('Priya Tip'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(PriyaCard), findsOneWidget);
      expect(find.text('Priya Tip'), findsOneWidget);
    });

    testWidgets('renders with custom padding', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriyaCard(
              padding: const EdgeInsets.all(24),
              child: const Text('Padded Priya Card'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(PriyaCard), findsOneWidget);
    });
  });

  group('SectionCard Widget Tests', () {
    testWidgets('renders section card with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionCard(
              title: 'Section Title',
              child: const Text('Section Content'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(SectionCard), findsOneWidget);
      expect(find.text('Section Title'), findsOneWidget);
      expect(find.text('Section Content'), findsOneWidget);
    });

    testWidgets('renders with trailing widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionCard(
              title: 'Section with Action',
              trailing: TextButton(
                onPressed: () {},
                child: const Text('See All'),
              ),
              child: const Text('Content'),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Section with Action'), findsOneWidget);
      expect(find.text('See All'), findsOneWidget);
    });
  });
}
