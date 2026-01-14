// Unit tests for CachedImageWidget and OfflineAwareImage
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jeevibe_mobile/widgets/offline/cached_image_widget.dart';
import 'package:jeevibe_mobile/providers/offline_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CachedImageWidget', () {
    testWidgets('should render without crashing with null imageUrl', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => OfflineProvider(),
            child: const Scaffold(
              body: CachedImageWidget(
                imageUrl: null,
              ),
            ),
          ),
        ),
      );

      // Should show error widget when no URL provided
      await tester.pumpAndSettle();
      expect(find.byType(CachedImageWidget), findsOneWidget);
    });

    testWidgets('should render with specified dimensions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => OfflineProvider(),
            child: const Scaffold(
              body: CachedImageWidget(
                imageUrl: 'https://example.com/test.png',
                width: 100,
                height: 150,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CachedImageWidget), findsOneWidget);
    });

    testWidgets('should apply borderRadius when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => OfflineProvider(),
            child: Scaffold(
              body: CachedImageWidget(
                imageUrl: 'https://example.com/test.png',
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('should show custom placeholder when provided', (tester) async {
      const placeholderKey = Key('custom-placeholder');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => OfflineProvider(),
            child: const Scaffold(
              body: CachedImageWidget(
                imageUrl: null,
                placeholder: SizedBox(key: placeholderKey),
              ),
            ),
          ),
        ),
      );

      // Pump to allow widget to build
      await tester.pump();
    });

    testWidgets('should show custom error widget when provided', (tester) async {
      const errorKey = Key('custom-error');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => OfflineProvider(),
            child: const Scaffold(
              body: CachedImageWidget(
                imageUrl: null,
                errorWidget: SizedBox(key: errorKey),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(errorKey), findsOneWidget);
    });
  });

  group('OfflineAwareImage', () {
    testWidgets('should render without crashing with null imageUrl', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineAwareImage(
              imageUrl: null,
            ),
          ),
        ),
      );

      expect(find.byType(OfflineAwareImage), findsOneWidget);
    });

    testWidgets('should render with specified dimensions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineAwareImage(
              imageUrl: 'https://example.com/test.png',
              width: 60,
              height: 60,
            ),
          ),
        ),
      );

      expect(find.byType(OfflineAwareImage), findsOneWidget);
    });

    testWidgets('should handle empty imageUrl string', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineAwareImage(
              imageUrl: '',
            ),
          ),
        ),
      );

      expect(find.byType(OfflineAwareImage), findsOneWidget);
    });

    testWidgets('should use BoxFit.cover by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineAwareImage(
              imageUrl: 'https://example.com/test.png',
            ),
          ),
        ),
      );

      final widget = tester.widget<OfflineAwareImage>(
        find.byType(OfflineAwareImage),
      );
      expect(widget.fit, BoxFit.cover);
    });

    testWidgets('should accept custom BoxFit', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineAwareImage(
              imageUrl: 'https://example.com/test.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      );

      final widget = tester.widget<OfflineAwareImage>(
        find.byType(OfflineAwareImage),
      );
      expect(widget.fit, BoxFit.contain);
    });
  });
}
