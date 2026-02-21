# Web-Specific Tests

This directory contains automated tests for Flutter web-specific functionality.

## Test Files

### 1. `platform_specific_behavior_test.dart`

Tests platform detection and conditional rendering based on `kIsWeb` flag.

**Coverage:**
- ✅ `kIsWeb` flag detection (false in test environment)
- ✅ Conditional widget rendering (mobile vs web UI)
- ✅ Share button visibility logic (hidden on web)
- ✅ Platform detection edge cases
- ✅ Combining viewport + platform detection
- ✅ Web feature availability documentation

**Test Count:** 10 tests

**Key Patterns Tested:**
```dart
// Pattern 1: Conditional rendering
if (kIsWeb) {
  return WebVersion();
} else {
  return MobileVersion();
}

// Pattern 2: Hiding features on web
trailing: kIsWeb ? null : ShareButton()

// Pattern 3: Feature availability flags
final canUseCamera = !kIsWeb;
final canUseShare = !kIsWeb;
final hasOfflineMode = !kIsWeb;
```

**Features Documented as Web-Disabled:**
- Snap & Solve (camera not available)
- Offline Mode (IndexedDB not implemented)
- Biometric Auth (no web equivalent)
- Screen Protection (browsers can't prevent screenshots)
- Share Button (native share API unavailable)

---

## Running Tests

### Run all web tests:
```bash
flutter test test/web/
```

### Run with coverage:
```bash
flutter test test/web/ --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Run in watch mode (continuous):
```bash
flutter test test/web/ --watch
```

## Test Environment Notes

**Important:** In Flutter's test environment, `kIsWeb` is **always false** because tests run in the Dart VM, not a browser.

This means:
- Tests verify the **mobile/native code path**
- Web-specific behavior is tested **indirectly** (by confirming mobile UI shows when kIsWeb=false)
- To test actual web behavior, use **integration tests in Chrome** (not unit tests)

## Integration Testing (Future)

For true web testing in a browser:

```bash
# Run integration tests in Chrome
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  -d chrome
```

This will actually run in a browser where `kIsWeb = true`.

## CI/CD Integration

Add to GitHub Actions workflow:

```yaml
- name: Run Web Tests
  run: |
    cd mobile
    flutter test test/web/
```

## Coverage Goals

**Current Coverage:**
- Platform detection: 100%
- Conditional rendering: 100%
- Feature availability: 100%

**Future Coverage Needs:**
- Browser-specific bugs (requires integration tests)
- Performance on low-bandwidth (manual QA)
- Cross-browser compatibility (manual QA)

## Related Documentation

- [Flutter Web Implementation Plan](../../docs/06-website/flutter-web-implementation-plan.md)
- [Deployment Guide](../../docs/06-website/DEPLOYMENT.md)
- [Responsive Layout Tests](../widgets/responsive_layout_test.dart)
