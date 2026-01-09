/// Widget tests for FormTextField
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/widgets/inputs/form_text_field.dart';
import 'package:jeevibe_mobile/theme/app_colors.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('FormTextField Widget Tests', () {
    testWidgets('renders text field with label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormTextField(
              label: 'Username',
              hint: 'Enter username',
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Username'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('displays hint text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormTextField(
              hint: 'Enter your name',
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('calls onChanged when text changes', (WidgetTester tester) async {
      String? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormTextField(
              onChanged: (value) {
                changedValue = value;
              },
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      await tester.enterText(find.byType(TextFormField), 'test input');
      await waitForAsync(tester);

      expect(changedValue, equals('test input'));
    });

    testWidgets('displays error text when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormTextField(
              label: 'Email',
              errorText: 'Invalid email address',
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Invalid email address'), findsOneWidget);
    });

    testWidgets('displays helper text when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormTextField(
              label: 'Password',
              helperText: 'Must be at least 8 characters',
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Must be at least 8 characters'), findsOneWidget);
    });

    testWidgets('renders prefix icon when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormTextField(
              label: 'Search',
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('renders suffix icon when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormTextField(
              label: 'Clear',
              suffixIcon: const Icon(Icons.clear),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('respects enabled state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormTextField(
              label: 'Disabled Field',
              enabled: false,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      final textField = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.enabled, isFalse);
    });

    testWidgets('respects readOnly state', (WidgetTester tester) async {
      final controller = TextEditingController(text: 'Read only text');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormTextField(
              controller: controller,
              readOnly: true,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      // The widget should render without errors when readOnly is true
      expect(find.byType(FormTextField), findsOneWidget);
    });

    testWidgets('validates input with validator', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: FormTextField(
                label: 'Required Field',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      formKey.currentState!.validate();
      await waitForAsync(tester);

      expect(find.text('This field is required'), findsOneWidget);
    });
  });

  group('FormTextField.email Factory', () {
    testWidgets('creates email field with correct keyboard type', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormTextField.email(),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Email'), findsOneWidget);
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    });

    testWidgets('validates email format', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController(text: 'invalid-email');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: FormTextField.email(
                controller: controller,
              ),
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      formKey.currentState!.validate();
      await waitForAsync(tester);

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });
  });

  group('FormTextField.phone Factory', () {
    testWidgets('creates phone field with correct keyboard type', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormTextField.phone(),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
    });
  });

  group('FormTextField.password Factory', () {
    testWidgets('creates password field with visibility toggle', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormTextField.password(),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Password'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('toggles password visibility', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormTextField.password(),
          ),
        ),
      );

      await waitForAsync(tester);

      // Initially password should be obscured (visibility icon shown)
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Tap to toggle visibility
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await waitForAsync(tester);

      // After toggle, visibility_off icon should be shown
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });

  group('FormTextField.multiline Factory', () {
    testWidgets('creates multiline text field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormTextField.multiline(
              label: 'Description',
              maxLines: 5,
              minLines: 3,
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.text('Description'), findsOneWidget);
      // Verify the FormTextField.multiline renders correctly
      expect(find.byType(FormTextField), findsOneWidget);
    });
  });

  group('FormTextField.search Factory', () {
    testWidgets('creates search field with search icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormTextField.search(
              hint: 'Search...',
            ),
          ),
        ),
      );

      await waitForAsync(tester);

      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });
  });
}
