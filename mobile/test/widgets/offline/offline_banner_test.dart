// Widget tests for OfflineBanner and related offline indicator widgets
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jeevibe_mobile/widgets/offline/offline_banner.dart';
import 'package:jeevibe_mobile/providers/offline_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineBanner', () {
    Widget createWidgetUnderTest({OfflineProvider? provider}) {
      return MaterialApp(
        home: ChangeNotifierProvider<OfflineProvider>(
          create: (_) => provider ?? OfflineProvider(),
          child: const Scaffold(
            body: Column(
              children: [
                OfflineBanner(),
                Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('should not show banner when provider is not initialized',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // When not initialized, banner should not show
      expect(find.byType(OfflineBanner), findsOneWidget);
      // The SizedBox.shrink() should be rendered (empty state)
      expect(find.text("You're offline"), findsNothing);
    });

    testWidgets('should not show banner when online', (tester) async {
      final provider = OfflineProvider();
      // Provider starts with isOnline = true

      await tester.pumpWidget(createWidgetUnderTest(provider: provider));

      // When online, banner should not be visible
      expect(find.text("You're offline"), findsNothing);
    });
  });

  group('OfflineIndicator', () {
    Widget createWidgetUnderTest({OfflineProvider? provider}) {
      return MaterialApp(
        home: ChangeNotifierProvider<OfflineProvider>(
          create: (_) => provider ?? OfflineProvider(),
          child: const Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: SafeArea(
                child: Row(
                  children: [
                    OfflineIndicator(),
                  ],
                ),
              ),
            ),
            body: SizedBox(),
          ),
        ),
      );
    }

    testWidgets('should not show indicator when not initialized',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // When not initialized, indicator should not show
      expect(find.text('Offline'), findsNothing);
    });

    testWidgets('should not show indicator when online', (tester) async {
      final provider = OfflineProvider();

      await tester.pumpWidget(createWidgetUnderTest(provider: provider));

      // When online, indicator should not be visible
      expect(find.text('Offline'), findsNothing);
    });
  });

  group('SyncStatusIndicator', () {
    Widget createWidgetUnderTest({OfflineProvider? provider}) {
      return MaterialApp(
        home: ChangeNotifierProvider<OfflineProvider>(
          create: (_) => provider ?? OfflineProvider(),
          child: const Scaffold(
            body: Center(
              child: SyncStatusIndicator(),
            ),
          ),
        ),
      );
    }

    testWidgets('should not show when not initialized', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // When not initialized, should not show
      expect(find.text('Syncing...'), findsNothing);
      expect(find.text('Ready'), findsNothing);
    });

    testWidgets('should not show when offline mode not enabled',
        (tester) async {
      final provider = OfflineProvider();
      // offlineEnabled defaults to false

      await tester.pumpWidget(createWidgetUnderTest(provider: provider));

      // When offline mode is disabled, should not show
      expect(find.text('Ready'), findsNothing);
    });
  });
}
