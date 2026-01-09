/// Widget tests for AppDialog and AppBottomSheet
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/widgets/dialogs/app_dialog.dart';
import 'package:jeevibe_mobile/widgets/buttons/gradient_button.dart';
import 'package:jeevibe_mobile/theme/app_colors.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('AppDialog Widget Tests', () {
    testWidgets('renders dialog with title and message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AppDialog(
                      title: 'Test Title',
                      message: 'Test message content',
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      // Tap button to show dialog
      await tester.tap(find.text('Show Dialog'));
      await waitForAsync(tester);

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test message content'), findsOneWidget);
    });

    testWidgets('renders dialog with icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AppDialog(
                      title: 'Info',
                      icon: Icons.info_outline,
                      iconColor: AppColors.primary,
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.text('Show Dialog'));
      await waitForAsync(tester);

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('renders dialog with custom content', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AppDialog(
                      content: Text('Custom widget content'),
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.text('Show Dialog'));
      await waitForAsync(tester);

      expect(find.text('Custom widget content'), findsOneWidget);
    });

    testWidgets('renders close button when showCloseButton is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AppDialog(
                      title: 'Closeable',
                      showCloseButton: true,
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.text('Show Dialog'));
      await waitForAsync(tester);

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('close button dismisses dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AppDialog(
                      title: 'Closeable',
                      showCloseButton: true,
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.text('Show Dialog'));
      await waitForAsync(tester);

      expect(find.text('Closeable'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await waitForAsync(tester);

      expect(find.text('Closeable'), findsNothing);
    });

    testWidgets('renders dialog with actions', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AppDialog(
                      title: 'With Actions',
                      actions: [
                        Expanded(
                          child: GradientButton(
                            text: 'Action',
                            onPressed: () {},
                            size: GradientButtonSize.medium,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.text('Show Dialog'));
      await waitForAsync(tester);

      expect(find.text('Action'), findsOneWidget);
    });
  });

  group('AppDialog.confirm Static Method', () {
    testWidgets('shows confirmation dialog with Yes/No buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppDialog.confirm(
                    context: context,
                    title: 'Confirm Action',
                    message: 'Are you sure?',
                  );
                },
                child: const Text('Confirm'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.text('Confirm'));
      await waitForAsync(tester);

      expect(find.text('Confirm Action'), findsOneWidget);
      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
    });

    testWidgets('returns true when Yes is tapped', (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await AppDialog.confirm(
                    context: context,
                    title: 'Confirm',
                    message: 'Proceed?',
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.text('Show'));
      await waitForAsync(tester);

      await tester.tap(find.text('Yes'));
      await waitForAsync(tester);

      expect(result, isTrue);
    });

    testWidgets('returns false when No is tapped', (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await AppDialog.confirm(
                    context: context,
                    title: 'Confirm',
                    message: 'Proceed?',
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.text('Show'));
      await waitForAsync(tester);

      await tester.tap(find.text('No'));
      await waitForAsync(tester);

      expect(result, isFalse);
    });

    testWidgets('shows destructive styling when isDestructive is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppDialog.confirm(
                    context: context,
                    title: 'Delete Item',
                    message: 'This cannot be undone',
                    isDestructive: true,
                  );
                },
                child: const Text('Delete'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.text('Delete'));
      await waitForAsync(tester);

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });

  group('AppDialog.alert Static Method', () {
    testWidgets('shows alert dialog with OK button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppDialog.alert(
                    context: context,
                    title: 'Alert Title',
                    message: 'Alert message',
                  );
                },
                child: const Text('Alert'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.text('Alert'));
      await waitForAsync(tester);

      expect(find.text('Alert Title'), findsOneWidget);
      expect(find.text('Alert message'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });
  });

  group('AppDialog.success Static Method', () {
    testWidgets('shows success dialog with check icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppDialog.success(
                    context: context,
                    title: 'Success!',
                    message: 'Operation completed',
                  );
                },
                child: const Text('Success'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.text('Success'));
      await waitForAsync(tester);

      expect(find.text('Success!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });
  });

  group('AppDialog.error Static Method', () {
    testWidgets('shows error dialog with error icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppDialog.error(
                    context: context,
                    title: 'Error!',
                    message: 'Something went wrong',
                  );
                },
                child: const Text('Error'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.text('Error'));
      await waitForAsync(tester);

      expect(find.text('Error!'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('AppDialog.showLoading Static Method', () {
    testWidgets('shows loading dialog with spinner', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppDialog.showLoading(
                    context: context,
                    message: 'Please wait...',
                  );
                },
                child: const Text('Load'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.text('Load'));
      await waitForAsync(tester);

      expect(find.text('Please wait...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AppBottomSheet Widget Tests', () {
    testWidgets('renders bottom sheet with handle', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppBottomSheet.show(
                    context: context,
                    child: const Text('Sheet Content'),
                  );
                },
                child: const Text('Show Sheet'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.text('Show Sheet'));
      await waitForAsync(tester);

      expect(find.text('Sheet Content'), findsOneWidget);
    });

    testWidgets('renders bottom sheet with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppBottomSheet.show(
                    context: context,
                    title: 'Sheet Title',
                    child: const Text('Content'),
                  );
                },
                child: const Text('Show Sheet'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.text('Show Sheet'));
      await waitForAsync(tester);

      expect(find.text('Sheet Title'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('renders bottom sheet with close button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppBottomSheet.show(
                    context: context,
                    showCloseButton: true,
                    child: const Text('Closeable Sheet'),
                  );
                },
                child: const Text('Show Sheet'),
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.tap(find.text('Show Sheet'));
      await waitForAsync(tester);

      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
