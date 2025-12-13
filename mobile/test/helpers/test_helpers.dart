/// Test helpers and utilities for mobile tests
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jeevibe_mobile/services/storage_service.dart';
import 'package:jeevibe_mobile/services/snap_counter_service.dart';
import 'package:jeevibe_mobile/services/firebase/auth_service.dart';
import 'package:jeevibe_mobile/services/firebase/firestore_user_service.dart';
import 'package:jeevibe_mobile/providers/app_state_provider.dart';

/// Create a test app with all providers
Widget createTestApp(Widget child) {
  final storageService = StorageService();
  final snapCounterService = SnapCounterService(storageService);
  
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppStateProvider(storageService, snapCounterService)),
      ChangeNotifierProvider(create: (_) => AuthService()),
      Provider(create: (_) => FirestoreUserService()),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

/// Wait for async operations to complete
Future<void> waitForAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Find widget by type
Finder findWidgetByType<T>() {
  return find.byType(T);
}

/// Find widget by key
Finder findWidgetByKey(String key) {
  return find.byKey(Key(key));
}

/// Find text widget
Finder findText(String text) {
  return find.text(text);
}

/// Tap widget and wait
Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await waitForAsync(tester);
}

/// Enter text and wait
Future<void> enterTextAndWait(WidgetTester tester, Finder finder, String text) async {
  await tester.enterText(finder, text);
  await waitForAsync(tester);
}

/// Scroll until visible
Future<void> scrollUntilVisible(WidgetTester tester, Finder finder, {double delta = 0}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable),
  );
  await waitForAsync(tester);
}

