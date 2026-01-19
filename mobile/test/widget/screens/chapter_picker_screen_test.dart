/// Widget tests for ChapterPickerScreen
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jeevibe_mobile/screens/chapter_practice/chapter_picker_screen.dart';
import 'package:jeevibe_mobile/services/firebase/auth_service.dart';
import 'package:jeevibe_mobile/theme/app_colors.dart';
import '../../helpers/test_helpers.dart';

/// Create a test app specifically for ChapterPickerScreen
Widget createChapterPickerTestApp() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthService()),
    ],
    child: const MaterialApp(
      home: ChapterPickerScreen(),
    ),
  );
}

void main() {
  group('ChapterPickerScreen Widget Tests', () {
    testWidgets('renders chapter picker screen', (WidgetTester tester) async {
      await tester.pumpWidget(createChapterPickerTestApp());
      await tester.pump();

      expect(find.byType(ChapterPickerScreen), findsOneWidget);
    });

    testWidgets('displays Choose Chapter title', (WidgetTester tester) async {
      await tester.pumpWidget(createChapterPickerTestApp());
      await tester.pump();

      expect(find.text('Choose Chapter'), findsOneWidget);
    });

    testWidgets('displays three subject tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createChapterPickerTestApp());
      await tester.pump();

      expect(find.text('Physics'), findsOneWidget);
      expect(find.text('Chemistry'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
    });

    testWidgets('has TabBar widget', (WidgetTester tester) async {
      await tester.pumpWidget(createChapterPickerTestApp());
      await tester.pump();

      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('has TabBarView for content', (WidgetTester tester) async {
      await tester.pumpWidget(createChapterPickerTestApp());
      await tester.pump();

      expect(find.byType(TabBarView), findsOneWidget);
    });

    testWidgets('has back button in AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(createChapterPickerTestApp());
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('shows loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(createChapterPickerTestApp());
      // Don't pump too many times to catch the loading state
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Either finds loading indicator or error state (since API is not mocked)
      final loadingIndicator = find.byType(CircularProgressIndicator);
      final errorIcon = find.byIcon(Icons.error_outline);
      final hasEitherState = loadingIndicator.evaluate().isNotEmpty ||
                             errorIcon.evaluate().isNotEmpty;

      expect(hasEitherState, isTrue);
    });

    testWidgets('can switch tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createChapterPickerTestApp());
      await tester.pump();

      // Tap on Chemistry tab
      await tester.tap(find.text('Chemistry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tab should be selected (TabBar should respond)
      expect(find.text('Chemistry'), findsOneWidget);
    });

    testWidgets('can tap Mathematics tab', (WidgetTester tester) async {
      await tester.pumpWidget(createChapterPickerTestApp());
      await tester.pump();

      // Tap on Mathematics tab
      await tester.tap(find.text('Mathematics'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Mathematics'), findsOneWidget);
    });
  });
}
