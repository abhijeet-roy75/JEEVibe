# JEEVibe Flutter Web - Final Implementation Plan
**Status**: APPROVED - Ready for Implementation
**Timeline**: 11 weeks (1 developer)
**Approach**: Flutter Web with Responsive Design
**Code Reuse**: ~70%
**Date**: 2026-02-20

---

## Executive Summary

### ✅ GO Decision: Flutter Web
After testing and validation, we're proceeding with Flutter Web for the following reasons:

1. **Validated Performance**: 2.5s load time, 382 KB bundle for test page (acceptable)
2. **Fastest Time to Market**: 11 weeks vs 22 weeks for React rebuild
3. **Code Reuse**: 70% of mobile code works on web with responsive adjustments
4. **Desktop Ready**: Windows/macOS apps available if needed later (deferred for now)
5. **Unified Codebase**: Same team, same patterns, easier maintenance

### 🎯 What We're Building

**Primary Deliverable**: Web app at `app.jeevibe.com`

**Features Included**:
- Daily Quiz (IRT-adaptive, 10 questions)
- Chapter Practice (topic-wise question banks)
- Mock Tests (90 questions, 3 hours, full JEE simulation)
- Analytics Dashboard (theta tracking, percentile trends)
- AI Tutor (Priya Ma'am chat interface)
- Profile & Settings
- History screens (quiz, practice, mock test history)
- Snap & Solve (file upload only, no live camera)

**Features Excluded** (Deferred):
- Webcam capture for Snap & Solve
- Native desktop apps (Windows/macOS)
- Biometric authentication
- PIN authentication (web uses Firebase session persistence instead)

---

## ⚠️ Critical Pre-Development Work (Week 0)

**MUST COMPLETE BEFORE STARTING WEEK 1** (3 days)

### 1. Add Web Platform Guards (2 days)

The following files use platform-specific APIs that will crash on web without `kIsWeb` guards:

**Files requiring immediate changes**:

```dart
// mobile/lib/main.dart (line 55)
- await _initializeScreenProtection();
+ if (!kIsWeb) await _initializeScreenProtection();

// mobile/lib/services/firebase/auth_service.dart (lines 82-95)
String getDeviceId() async {
+  if (kIsWeb) return 'web-${DateTime.now().millisecondsSinceEpoch}';
   final deviceInfo = DeviceInfoPlugin();
   // ... existing Platform.isAndroid/iOS logic
}

// mobile/lib/theme/app_platform_sizing.dart (line 23)
- static final bool _isAndroid = Platform.isAndroid;
+ static final bool _isAndroid = kIsWeb ? false : Platform.isAndroid;

// mobile/lib/services/offline/connectivity_service.dart
+ import 'dart:html' as html show window;
+ import 'package:flutter/foundation.dart' show kIsWeb;

Future<bool> hasInternetAccess() async {
+  if (kIsWeb) return html.window.navigator.onLine ?? true;
   // ... existing socket logic for mobile
}

// mobile/lib/services/feedback_service.dart (lines 28-40)
Future<void> submitFeedback() async {
+  String deviceModel = kIsWeb ? 'Web Browser' : await _getDeviceModel();
+  String osVersion = kIsWeb ? 'Web' : await _getOSVersion();
   // ... rest of logic
}
```

**Rationale**: 16+ files use `dart:io` or platform-specific packages. Without these guards, app will throw `UnsupportedError` at runtime.

---

### 2. Fix Offline Database for Web (2 days)

**Problem**: Mobile uses `isar_flutter_libs` (native libraries). Web doesn't support this.

**Solution**:

```dart
// mobile/lib/services/offline/database_service.dart (lines 52-62)
+ import 'package:flutter/foundation.dart' show kIsWeb;

Future<Isar> _openDatabase() async {
+  if (kIsWeb) {
+    // Web: Use IndexedDB (no directory needed)
+    return await Isar.open([
+      CachedSolutionSchema,
+      CachedQuestionSchema,
+    ]);
+  }
+
   // Mobile: Use native Isar
   final dir = await getApplicationDocumentsDirectory();
   return await Isar.open([
     CachedSolutionSchema,
     CachedQuestionSchema,
   ], directory: dir.path);
}
```

**Also update pubspec.yaml**:
```yaml
dependencies:
  isar: ^3.1.0+1
-  isar_flutter_libs: ^3.1.0+1  # Remove (not web-compatible)
+  sentry_flutter: ^7.0.0        # Add (for web error tracking)
```

**Storage Limits**:
- Mobile: Unlimited (native Isar)
- Web: ~100 MB IndexedDB quota (browser limit)
- Implement auto-cleanup when approaching quota

---

### 3. Define Web Authentication Flow (1 day)

**Mobile Flow**: Phone + OTP → PIN Setup → PIN for subsequent logins

**Web Flow**: Phone + OTP → Firebase session persists → No PIN needed

---

#### Detailed Authentication Flow Comparison

**MOBILE (Current)**:

```
First Login:
1. User enters phone number
2. Receives SMS OTP
3. Enters OTP → Firebase Auth verifies
4. Creates PIN (4-6 digits)
5. PIN stored in Keychain/Keystore (flutter_secure_storage)
6. Redirects to Home Screen

Subsequent Logins:
1. App shows PIN entry screen
2. User enters PIN
3. PIN verified against Keychain
4. Redirects to Home Screen
   (Session persists in background via Firebase Auth)
```

**WEB (New)**:

```
First Login:
1. User enters phone number on web
2. Receives SMS OTP
3. Enters OTP → Firebase Auth verifies
4. ✅ Skip PIN setup (no secure storage on web)
5. Firebase Auth session stored in browser IndexedDB
6. Redirects to Home Screen

Subsequent Logins:
1. User visits app.jeevibe.com
2. Firebase Auth checks IndexedDB for session token
3. If valid session exists:
   → Auto-login, redirect to Home Screen
4. If session expired (30 days default):
   → Show phone number entry screen again
   → Repeat OTP flow

No PIN needed - browser handles session persistence
```

---

#### Why No PIN on Web?

1. **Technical Limitation**: `flutter_secure_storage` uses native Keychain/Keystore APIs (iOS Keychain, Android Keystore). These don't exist on web.

2. **Browser Security**: Modern browsers provide equivalent security:
   - **HTTPS**: All data encrypted in transit
   - **SameSite cookies**: Prevents CSRF attacks
   - **Secure Context**: IndexedDB only accessible on HTTPS
   - **Domain isolation**: Other sites can't access JEEVibe's storage

3. **User Expectation**: Web users expect standard login flows (Google, Facebook, etc. don't require PINs after login)

4. **Firebase Session Persistence**: Firebase Auth automatically:
   - Stores session tokens in IndexedDB (not localStorage - more secure)
   - Refreshes tokens automatically before expiry
   - Invalidates tokens on logout
   - Respects browser's "Clear cookies" action

---

#### Security Considerations

**Mobile PIN Benefits (Lost on Web)**:
- ✅ Quick unlock (convenience)
- ✅ Extra layer if phone is stolen but unlocked
- ⚠️ **NOT cryptographic** - PIN is just convenience layer

**Web Session Security (Equivalent)**:
- ✅ Firebase tokens are cryptographically signed (JWT)
- ✅ Short-lived access tokens (1 hour) auto-refresh
- ✅ HttpOnly storage (JavaScript can't access)
- ✅ HTTPS-only transmission
- ✅ SameSite=Strict (no cross-site leakage)

**Risk Comparison**:
- Mobile: If phone is stolen AND unlocked → attacker has access (until user reports theft)
- Web: If laptop is stolen AND browser is open → attacker has access (until session expires or user logs out remotely)

**Verdict**: Web security is equivalent to mobile. PIN was convenience, not cryptographic protection.

---

#### Implementation Details

```dart
// mobile/lib/services/firebase/auth_service.dart

Future<void> signInWithPhone(String phone, String otp) async {
  // Step 1: Verify OTP with Firebase (works identically on mobile and web)
  final credential = PhoneAuthProvider.credential(
    verificationId: _verificationId,
    smsCode: otp,
  );
  await FirebaseAuth.instance.signInWithCredential(credential);

  // Step 2: Setup PIN (mobile only)
  if (!kIsWeb) {
    await _setupPIN(); // Store in Keychain/Keystore
  }
  // Web: Firebase Auth automatically persists session in IndexedDB
}

// Skip PIN verification screens on web
Widget _getHomeScreen() {
  if (kIsWeb) {
    return HomeScreen(); // Direct to home on web
  } else {
    return PinVerificationScreen(); // Mobile requires PIN
  }
}

// Auto-login on web
Future<bool> isUserLoggedIn() async {
  final user = FirebaseAuth.instance.currentUser;

  if (kIsWeb) {
    // Web: Check Firebase Auth session
    return user != null;
  } else {
    // Mobile: Check both Firebase session AND PIN setup
    return user != null && await _hasPINSetup();
  }
}
```

---

#### Session Expiry & Re-login

**Firebase Auth Session Duration**:
- Access token: 1 hour (auto-refreshes silently)
- Refresh token: 30 days (user must re-login after this)
- User action: "Sign Out" invalidates immediately

**What Happens After 30 Days**:
1. User visits app.jeevibe.com
2. Firebase Auth checks session → expired
3. Shows phone number entry screen
4. User enters phone → receives OTP
5. Enters OTP → logged in again

**Mobile Behavior** (for comparison):
1. User opens app
2. PIN screen appears
3. PIN verification → Firebase session check → expired
4. Shows phone number entry screen
5. Same OTP flow

---

#### User Experience Differences

| Scenario | Mobile | Web |
|----------|--------|-----|
| **First login** | Phone + OTP + PIN setup | Phone + OTP only ✅ Faster |
| **Subsequent opens** | PIN entry (~5 sec) | Auto-login (instant) ✅ Better UX |
| **After 30 days** | PIN → OTP flow | Direct OTP flow ✅ Simpler |
| **Forgot PIN** | Reset flow (annoying) | N/A ✅ No forgot PIN issues |
| **Security** | Keychain | IndexedDB (equivalent) |

**Web UX is actually BETTER** - one less step for users!

---

#### Testing Checklist

- [ ] Web login with phone + OTP works
- [ ] Session persists after browser refresh
- [ ] Session persists after closing/reopening browser tab
- [ ] Session expires after 30 days (force expiry in Firebase Console to test)
- [ ] Logout clears session (can't access app after logout)
- [ ] Multiple tabs share same session (Nice-to-Have E: TabSyncService)
- [ ] Mobile app still uses PIN flow (no regression)

---

### 4. Add Sentry for Web Error Tracking (1 day)

**Problem**: Firebase Crashlytics doesn't officially support Flutter web.

**Solution**: Use Sentry

```dart
// mobile/lib/main.dart
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SentryFlutter.init(
    (options) {
      options.dsn = 'YOUR_SENTRY_DSN';
      options.environment = kReleaseMode ? 'production' : 'development';
      // Only enable on web
      options.enabled = kIsWeb;
    },
    appRunner: () => runApp(MyApp()),
  );
}
```

**Mobile continues to use Firebase Crashlytics** (existing setup).

---

### 5. Verify Backend CORS Configuration (2 hours)

**Current backend** (`backend/src/index.js`):
```javascript
app.use(cors({
  origin: [
    'https://app.jeevibe.com',        // ✅ Present
    'https://jeevibe-app.web.app'     // ✅ Present (Firebase default)
  ],
  credentials: true
}));
```

**Pre-deployment checklist**:
- [ ] Verify CORS config includes `app.jeevibe.com`
- [ ] Verify CORS config includes `jeevibe-app.web.app`
- [ ] Test OPTIONS preflight request from browser DevTools
- [ ] Test POST request with credentials from web app

**Test script** (run before Week 1):
```bash
curl -X OPTIONS https://api.jeevibe.com/api/daily-quiz/start \
  -H "Origin: https://app.jeevibe.com" \
  -H "Access-Control-Request-Method: POST" \
  -v
```

Expected response: `Access-Control-Allow-Origin: https://app.jeevibe.com`

---

## 🎯 Nice-to-Have Improvements (Reduces Risk)

### A. Setup E2E Test Framework Early (Week 2, not Week 7)

**Why**: Catch responsive bugs early, not in Week 7 when timeline is tight.

**Setup**:
```bash
cd mobile
flutter test integration_test/app_test.dart -d chrome
```

**Test files to create**:
```dart
// integration_test/quiz_flow_test.dart
testWidgets('Complete daily quiz flow on web', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();

  // Navigate to quiz
  await tester.tap(find.text('Start Today\'s Quiz'));
  await tester.pumpAndSettle();

  // Answer all 10 questions
  for (int i = 0; i < 10; i++) {
    await tester.tap(find.text('A'));
    await tester.tap(find.text('Submit Answer'));
    await tester.pumpAndSettle();
  }

  // Verify results screen
  expect(find.text('Quiz Complete'), findsOneWidget);
});

// integration_test/browser_back_test.dart
testWidgets('Browser back button protection works', (tester) async {
  // ... test browser back button shows confirmation dialog
});

// integration_test/practice_flow_test.dart
testWidgets('Chapter practice session completes', (tester) async {
  // ... test chapter practice flow
});
```

**Benefit**: Prevents "surprise" bugs in Week 7 that cascade timelines.

---

### B. Create Responsive Widget Abstraction (Week 2)

**Why**: Reduces refactoring from "per-widget" to "parameter standardization".

**Pattern**:
```dart
// lib/theme/responsive_params.dart
class ResponsiveParams {
  final double fontSize;
  final double padding;
  final double borderRadius;
  final double iconSize;
  final double spacing;

  ResponsiveParams({required bool isDesktop})
      : fontSize = isDesktop ? 20 : 18,
        padding = isDesktop ? 24 : 20,
        borderRadius = isDesktop ? 20 : 16,
        iconSize = isDesktop ? 28 : 24,
        spacing = isDesktop ? 20 : 16;

  // Desktop-specific getters
  double get cardPadding => padding;
  double get sectionSpacing => spacing * 1.5;
  double get headerFontSize => fontSize * 1.2;
}

// Usage in widgets:
Widget _buildCard({required bool isDesktop}) {
  final params = ResponsiveParams(isDesktop: isDesktop);

  return Container(
    padding: EdgeInsets.all(params.cardPadding),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(params.borderRadius),
    ),
    child: Column([
      Text('Title', style: TextStyle(fontSize: params.headerFontSize)),
      SizedBox(height: params.sectionSpacing),
      // ... rest of content
    ]),
  );
}
```

**Benefit**: Standardizes responsive sizing across 50+ widgets. Change once, apply everywhere.

---

### C. Monitor Bundle Size Weekly (Week 3+)

**Why**: Prevents "oh no, we're at 4 MB" surprises in Week 7.

**Setup**:
```bash
# Run after each major feature addition
flutter build web --release --analyze-size

# Check output:
# flutter: ✓ Built build/web
# flutter:   main.dart.js: 1.9 MB
# flutter:   canvaskit.wasm: 800 KB
# flutter:   Total: 2.7 MB
```

**Weekly monitoring schedule**:
- **Week 3**: After Daily Quiz + Chapter Practice (expect ~1.5 MB)
- **Week 5**: After Analytics + Profile (expect ~2.0 MB)
- **Week 7**: After Snap & Solve (expect <2.5 MB)
- **Week 9**: Final optimization (target: <2.5 MB)

**Alert threshold**: If bundle exceeds 2.3 MB before Week 7, investigate and optimize immediately.

**Tools**:
```bash
# Detailed size breakdown
flutter build web --analyze-size --tree-shake-icons

# View dependency impact
flutter pub deps --style=compact
```

**Benefit**: Catch bundle bloat early, optimize incrementally instead of panic-optimizing in Week 7.

---

### D. Implement LocalStorage Cleanup Strategy (Week 3)

**Problem**: IndexedDB quota is ~100 MB on most browsers. Current mobile app caches 200 solutions.

**Solution**: Auto-cleanup when approaching quota.

```dart
// lib/services/offline/storage_quota_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

class StorageQuotaService {
  static const int MAX_WEB_CACHE_SIZE_MB = 80; // Leave 20 MB buffer
  static const int MAX_CACHED_SOLUTIONS = 100; // Web limit

  Future<bool> hasSpaceForCache() async {
    if (!kIsWeb) return true; // Mobile has unlimited space

    // Check IndexedDB quota (web only)
    final estimate = await html.window.navigator.storage?.estimate();
    if (estimate == null) return true;

    final usageMB = (estimate['usage'] as num) / (1024 * 1024);
    return usageMB < MAX_WEB_CACHE_SIZE_MB;
  }

  Future<void> cleanupOldestCaches() async {
    if (!kIsWeb) return;

    final db = await DatabaseService.instance.database;
    final solutions = await db.cachedSolutions
        .where()
        .sortByAccessedAt()
        .findAll();

    // Remove oldest 20% if over limit
    if (solutions.length > MAX_CACHED_SOLUTIONS) {
      final toRemove = solutions.take((solutions.length * 0.2).toInt());
      await db.writeTxn(() async {
        for (final solution in toRemove) {
          await db.cachedSolutions.delete(solution.id);
        }
      });
    }
  }
}
```

**Integration**:
```dart
// Before caching new solution
final quotaService = StorageQuotaService();
if (await quotaService.hasSpaceForCache()) {
  await _cacheSolution(solution);
} else {
  await quotaService.cleanupOldestCaches();
  await _cacheSolution(solution);
}
```

**Benefit**: Prevents storage quota errors, maintains oldest 100 solutions automatically.

---

### E. Add Tab Synchronization for Multi-Tab Users (Week 4)

**Problem**: Users may open multiple tabs. LocalStorage race conditions can corrupt state.

**Solution**: BroadcastChannel API for tab sync.

```dart
// lib/services/web/tab_sync_service.dart
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

class TabSyncService {
  html.BroadcastChannel? _channel;

  void initialize() {
    if (!kIsWeb) return;

    _channel = html.BroadcastChannel('jeevibe-sync');

    _channel!.onMessage.listen((event) {
      final data = event.data as Map;

      switch (data['type']) {
        case 'quiz_progress':
          _handleQuizProgressUpdate(data);
          break;
        case 'logout':
          _handleLogout();
          break;
      }
    });
  }

  void broadcastQuizProgress(String quizId, int currentIndex) {
    if (!kIsWeb || _channel == null) return;

    _channel!.postMessage({
      'type': 'quiz_progress',
      'quizId': quizId,
      'currentIndex': currentIndex,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _handleQuizProgressUpdate(Map data) {
    // Update local state if this tab is showing same quiz
    // Prevents user from losing progress if switching tabs
  }
}
```

**Benefit**: Prevents data corruption when user has multiple tabs open. Sync quiz progress across tabs.

---

### F. Keyboard Shortcuts for Power Users (Week 5-6)

**Why**: Web users expect keyboard navigation (arrows, numbers, Enter, Esc).

**Implementation**:
```dart
// lib/widgets/keyboard_shortcuts_handler.dart
import 'package:flutter/services.dart';

class KeyboardShortcutsHandler extends StatefulWidget {
  final Widget child;
  final Function(String) onOptionSelected; // 'A', 'B', 'C', 'D'
  final VoidCallback onSubmit;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          // Numbers 1-4 → Select options A-D
          if (event.logicalKey == LogicalKeyboardKey.digit1) {
            onOptionSelected('A');
            return KeyEventResult.handled;
          }
          // ... digit2-4 for B-D

          // Enter → Submit answer
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            onSubmit();
            return KeyEventResult.handled;
          }

          // Esc → Show exit confirmation
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            onExit();
            return KeyEventResult.handled;
          }

          // Arrow keys → Navigate options
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _selectNextOption();
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
```

**Usage**:
```dart
// Wrap quiz screen
KeyboardShortcutsHandler(
  onOptionSelected: (option) => _selectOption(option),
  onSubmit: () => _submitAnswer(),
  onExit: () => _showExitConfirmation(),
  child: QuizQuestionCard(...),
)
```

**Benefit**: Power users can answer questions faster (no mouse needed). Competitive advantage over mobile-only apps.

---

## Key Architectural Decisions

### 1. Navigation Pattern ✅ LOCKED

**Desktop**: Left sidebar navigation (NavigationRail)
- Modern web-native feel (like Notion, Figma, Linear)
- Maximizes vertical space for content
- Always visible, collapsible

**Mobile Web**: Bottom navigation bar (BottomNavigationBar)
- Reuses existing mobile component
- Familiar thumb-friendly experience
- 4 tabs: Home, History, Analytics, Profile

**Implementation**:
```dart
Widget build(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isDesktop = constraints.maxWidth > 900;

      return Scaffold(
        body: Row([
          if (isDesktop) NavigationRail(...), // Left sidebar
          Expanded(child: _currentScreen),
        ]),
        bottomNavigationBar: isDesktop ? null : BottomNavigationBar(...),
      );
    },
  );
}
```

---

### 2. Browser Back Button Protection ✅ LOCKED

**Critical Screens**: Daily Quiz, Chapter Practice, Mock Tests, Snap & Solve (active sessions)

**Implementation**:
```dart
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

class QuizScreen extends StatefulWidget {
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  StreamSubscription? _backButtonSubscription;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _setupBrowserBackProtection();
    }
  }

  void _setupBrowserBackProtection() {
    // Push dummy state to history
    html.window.history.pushState(null, '', html.window.location.href);

    // Listen for back button
    _backButtonSubscription = html.window.onPopState.listen((event) {
      _showExitConfirmation();
      // Re-push state to prevent actual navigation
      html.window.history.pushState(null, '', html.window.location.href);
    });
  }

  Future<void> _showExitConfirmation() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Exit Quiz?'),
        content: Text('Your progress will be lost if you exit now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Exit'),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      // Allow navigation by removing protection
      _backButtonSubscription?.cancel();
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _backButtonSubscription?.cancel();
    super.dispose();
  }
}
```

**Effort**: 1 day (Week 2)

---

### 3. Auto-Save Quiz Progress ✅ LOCKED

**Strategy**: Save after each question submission (NOT every keystroke)

**When**: After student selects answer and taps "Submit"

**Why**:
- ✅ Prevents data loss on browser refresh/tab close
- ✅ Non-blocking (fire-and-forget pattern)
- ✅ Zero perceived latency (happens in background)

**Backend Support**: Already exists
```javascript
// Existing endpoint
POST /api/daily-quiz/:quizId/save-progress
{
  currentQuestionIndex: 3,
  responses: [
    { questionId: 'Q1', answer: 'A', isCorrect: true, timeSpent: 45 },
    { questionId: 'Q2', answer: 'C', isCorrect: false, timeSpent: 62 },
    { questionId: 'Q3', answer: 'B', isCorrect: true, timeSpent: 38 }
  ],
  timeSpent: 145
}
```

**Mobile Implementation**:
```dart
class DailyQuizProvider extends ChangeNotifier {
  Future<void> submitAnswer(String answer) async {
    // 1. Update local state
    _currentQuestion.selectedAnswer = answer;
    _currentQuestion.isCorrect = _checkAnswer(answer);
    notifyListeners();

    // 2. Save to backend (non-blocking, fire-and-forget)
    _saveProgressInBackground();

    // 3. Move to next question (don't wait for save)
    _moveToNextQuestion();
  }

  void _saveProgressInBackground() async {
    try {
      await _apiService.saveQuizProgress(
        quizId: _quizId,
        currentIndex: _currentQuestionIndex,
        responses: _responses,
        timeSpent: _totalTimeSpent,
      );
    } catch (e) {
      // Silent fail - will retry on next question submission
      // All responses are included, so previous ones get saved too
      debugPrint('Auto-save failed: $e');
    }
  }
}
```

**Performance**:
- API call: ~200-300ms (background, doesn't block UI)
- User perception: 0ms lag (immediate transition to next question)
- Retry logic: Next submission includes all previous responses

**Effort**: 2 days (Week 4)

---

### 4. Responsive Design Strategy ✅ LOCKED

**Breakpoint**: 900px
- `<900px` = Mobile layout (1-column, bottom nav)
- `≥900px` = Desktop layout (2-column, left sidebar)

**Shared Code**: ~70%
- All Provider state management (100% shared)
- All API calls (100% shared)
- All business logic (100% shared)
- Core widgets (70% shared, with responsive parameters)

**Web-Specific Code**: ~30%
- Layout grids (2-column desktop)
- Navigation (sidebar desktop, bottom nav mobile)
- Spacing/sizing (larger on desktop)

**Pattern**:
```dart
Widget _buildCard({required bool isDesktop}) {
  return Container(
    padding: EdgeInsets.all(isDesktop ? 24 : 20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
      // ... shared decoration
    ),
    child: Column([
      // Shared content with responsive params
      _buildHeader(fontSize: isDesktop ? 20 : 18),
      SizedBox(height: isDesktop ? 20 : 16),
      _buildBody(fontSize: isDesktop ? 15 : 14),
    ]),
  );
}
```

---

## 11-Week Implementation Timeline

### **Week 0: Pre-Development (MANDATORY - 3 days)**

**⚠️ CRITICAL**: Must complete before Week 1 starts. See "Critical Pre-Development Work" section above for full details.

**Tasks**:
1. Add `kIsWeb` guards to 6 files (2 days)
2. Fix offline database for web (2 days)
3. Implement web auth flow - skip PIN on web (1 day)
4. Verify backend CORS (2 hours)
5. Setup Sentry error tracking (1 day)

**Deliverable**: App compiles on web without crashes, auth works, CORS verified

---

### **Week 1-2: Foundation & Core Setup**

**Goals**: Platform-agnostic core package + browser back protection + test framework

**Tasks**:
1. Create `jeevibe_core` package (3 days)
   - Extract models (daily_quiz_models, chapter_practice_models, etc.)
   - Extract providers (daily_quiz_provider, chapter_practice_provider, etc.)
   - Extract services (api_service, storage_service - web-compatible versions)
   - Remove platform-specific dependencies

2. Enable web platform (1 day)
   ```bash
   cd mobile
   flutter create . --platforms=web
   flutter pub get
   ```

3. Setup conditional imports (1 day)
   ```dart
   // lib/services/storage_service.dart
   import 'package:flutter/foundation.dart' show kIsWeb;
   import 'storage_service_mobile.dart' if (dart.library.html) 'storage_service_web.dart';
   ```

4. **Implement browser back button protection** (1 day)
   - Add to: assessment_question_screen, daily_quiz_question_screen, chapter_practice_question_screen, mock_test_screen
   - Pattern: html.window.history + onPopState listener
   - Show confirmation dialog before exit

5. Build smart loading screen (1 day)
   ```dart
   // lib/widgets/web/smart_loading_screen.dart
   class SmartLoadingScreen extends StatefulWidget {
     @override
     Widget build(BuildContext context) {
       return Scaffold(
         body: Center(
           child: Column([
             AnimatedLogo(size: 120),
             LinearProgressIndicator(value: _progress),
             Text(_getLoadingMessage()), // "Loading 10,000+ JEE questions..."
           ]),
         ),
       );
     }
   }
   ```

6. **NEW: Setup E2E test framework** (2 days - Nice-to-Have A)
   - Create integration_test/ directory
   - Write quiz_flow_test.dart, browser_back_test.dart, practice_flow_test.dart
   - Configure Chrome driver for testing

7. **NEW: Create responsive widget abstraction** (1 day - Nice-to-Have B)
   - Create lib/theme/responsive_params.dart
   - Define ResponsiveParams class with fontSize, padding, borderRadius, iconSize
   - Document usage pattern for all developers

**Deliverable**: Web build compiles successfully, no platform-specific errors, test framework ready

---

### **Week 3-4: Core Features + Responsive UI**

**Goals**: Daily Quiz, Chapter Practice, Mock Tests with responsive layouts

**Tasks**:
1. Daily Quiz (4 days - was 3)
   - Responsive question card (2-column options on desktop)
   - **Auto-save after each answer** (2 days)
   - Gradient header (same on mobile/desktop)
   - Timer widget (top-right on desktop, top-center on mobile)
   - Use ResponsiveParams abstraction

2. Chapter Practice (3 days - was 2)
   - Responsive chapter selection grid (3 columns desktop, 1 column mobile)
   - Practice screen (same as Daily Quiz, already built)
   - Apply responsive parameters

3. Mock Tests (4 days - was 3)
   - Subject tabs (horizontal on desktop, vertical on mobile)
   - Question palette (right sidebar desktop, bottom sheet mobile)
   - Timer (sticky top-right on desktop)
   - Fullscreen toggle button
   - Responsive testing across breakpoints

4. **Left sidebar navigation** (1 day)
   ```dart
   NavigationRail(
     selectedIndex: _selectedIndex,
     labelType: NavigationRailLabelType.all,
     destinations: [
       NavigationRailDestination(
         icon: Icon(Icons.home_outlined),
         selectedIcon: Icon(Icons.home),
         label: Text('Home'),
       ),
       // ... History, Analytics, Profile
     ],
     onDestinationSelected: (index) => setState(() => _selectedIndex = index),
   )
   ```

5. **NEW: Monitor bundle size** (ongoing - Nice-to-Have C)
   - Run `flutter build web --analyze-size` weekly
   - Track: Week 3 baseline, Week 5 after features, Week 7 final

6. **NEW: Implement storage quota cleanup** (1 day - Nice-to-Have D)
   - Create StorageQuotaService
   - Auto-cleanup when approaching 100 MB limit
   - Test on Chrome/Firefox/Safari

**Deliverable**: Core quiz/practice/mock features work on web, responsive layouts tested

---

### **Week 3-4: Core Features + Responsive UI**

**Goals**: Daily Quiz, Chapter Practice, Mock Tests with responsive layouts

**Tasks**:
1. Daily Quiz (3 days)
   - Responsive question card (2-column options on desktop)
   - **Auto-save after each answer** (2 days)
   - Gradient header (same on mobile/desktop)
   - Timer widget (top-right on desktop, top-center on mobile)

2. Chapter Practice (2 days)
   - Responsive chapter selection grid (3 columns desktop, 1 column mobile)
   - Practice screen (same as Daily Quiz, already built)

3. Mock Tests (3 days)
   - Subject tabs (horizontal on desktop, vertical on mobile)
   - Question palette (right sidebar desktop, bottom sheet mobile)
   - Timer (sticky top-right on desktop)
   - Fullscreen toggle button

4. **Left sidebar navigation** (1 day)
   ```dart
   NavigationRail(
     selectedIndex: _selectedIndex,
     labelType: NavigationRailLabelType.all,
     destinations: [
       NavigationRailDestination(
         icon: Icon(Icons.home_outlined),
         selectedIcon: Icon(Icons.home),
         label: Text('Home'),
       ),
       // ... History, Analytics, Profile
     ],
     onDestinationSelected: (index) => setState(() => _selectedIndex = index),
   )
   ```

**Deliverable**: Core quiz/practice features work on web, responsive layouts tested

---

### **Week 5-6: Additional Features**

**Goals**: Analytics, Profile, History with responsive dashboards

**Tasks**:
1. Analytics Dashboard (3 days)
   - Theta trend chart (responsive width, larger on desktop)
   - Subject breakdown cards (2-column desktop, 1-column mobile)
   - Percentile meter (larger on desktop)
   - Apply ResponsiveParams

2. Profile & Settings (2 days)
   - Profile edit form (centered max-width 600px on desktop)
   - Settings toggles (same mobile/desktop)
   - Subscription card (responsive layout)

3. History Screens (4 days - was 3)
   - Quiz history list (table view desktop, card list mobile)
   - Chapter practice history (same)
   - Mock test history (same)
   - Detailed review screens (reuse question_review_screen with responsive params)

4. Keyboard Navigation (3 days - was 2, Nice-to-Have F)
   - Create KeyboardShortcutsHandler widget
   - Arrow keys: Navigate between options
   - Enter: Submit answer
   - Numbers 1-4: Select option A-D
   - Esc: Show exit confirmation
   - Tab: Focus next element
   - Test on all 6 browsers (Chrome, Firefox, Safari, Edge, Mobile Chrome, Mobile Safari)

5. **NEW: Add tab synchronization** (1 day - Nice-to-Have E)
   - Create TabSyncService using BroadcastChannel API
   - Sync quiz progress across multiple tabs
   - Prevent LocalStorage race conditions

**Deliverable**: Full feature parity with mobile (except Snap & Solve)

---

### **Week 7-8: Testing, Optimization, Deployment**

**Goals**: Comprehensive testing, bundle optimization, Firebase deployment

---

#### **Day 1-3: Automated Testing** (3 days)

**Unit Tests** (Backend - already exists, verify web compatibility):
```bash
cd backend
npm test  # Verify all 384 tests still pass
```

**Widget Tests** (Flutter - NEW for web):
```dart
// test/widgets/responsive_quiz_card_test.dart
testWidgets('Quiz card adapts to desktop width', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(1200, 800)), // Desktop
        child: DailyQuizCard(isDesktop: true),
      ),
    ),
  );

  expect(find.byType(DailyQuizCard), findsOneWidget);
  // Verify desktop padding (24px not 20px)
  final container = tester.widget<Container>(find.byType(Container).first);
  expect(container.padding, EdgeInsets.all(24));
});
```

**Integration Tests** (Critical user flows):
```dart
// integration_test/quiz_flow_test.dart
testWidgets('Complete daily quiz flow on web', (tester) async {
  // 1. Load app
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();

  // 2. Navigate to quiz
  await tester.tap(find.text('Start Today\'s Quiz'));
  await tester.pumpAndSettle();

  // 3. Answer all 10 questions
  for (int i = 0; i < 10; i++) {
    await tester.tap(find.text('A')); // Select option A
    await tester.tap(find.text('Submit Answer'));
    await tester.pumpAndSettle();
  }

  // 4. Verify results screen
  expect(find.text('Quiz Complete'), findsOneWidget);
});
```

**Test Coverage Goal**: 70% (matching mobile app)

**Tasks**:
- [ ] Write widget tests for responsive cards (quiz, practice, mock test)
- [ ] Write integration tests for critical flows (quiz, practice, mock test)
- [ ] Test browser back button protection
- [ ] Test auto-save functionality (mock API calls)
- [ ] Run tests on GitHub Actions (add web to CI/CD)

---

#### **Day 4-6: Cross-Browser Testing** (3 days)

**Test Matrix**:

| Feature | Chrome | Firefox | Safari | Edge | Mobile Chrome | Mobile Safari |
|---------|--------|---------|--------|------|---------------|---------------|
| Daily Quiz | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Chapter Practice | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Mock Tests | ✅ | ✅ | ✅ | ✅ | ⚠️ (simple) | ⚠️ (simple) |
| Analytics | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Profile | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| History | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| LaTeX Rendering | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Browser Back | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Auto-Save | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Offline Mode | ✅ | ✅ | ✅ | ✅ | ⚠️ (limited) | ⚠️ (limited) |

**Tools**:
- Chrome DevTools (primary testing)
- Firefox Developer Tools
- Safari Web Inspector
- BrowserStack (for cross-device testing)

**Manual Test Checklist** (per browser):
- [ ] Sign in with phone + OTP
- [ ] Complete daily quiz (10 questions)
- [ ] Start chapter practice session
- [ ] Press browser back button (verify protection)
- [ ] Refresh during quiz (verify auto-save restoration)
- [ ] Complete mock test (90 questions)
- [ ] View analytics dashboard
- [ ] Edit profile
- [ ] View history screens
- [ ] Test keyboard navigation (arrows, enter, numbers)
- [ ] Verify LaTeX renders correctly
- [ ] Test responsive breakpoints (375px, 768px, 1200px, 1920px)

**Bug Tracking**: GitHub Issues with labels `web`, `browser:chrome`, `browser:firefox`, etc.

---

#### **Day 7-8: Performance Optimization** (2 days)

**Bundle Size Analysis**:
```bash
flutter build web --release --analyze-size
```

**Optimization Techniques**:

1. **Code Splitting** (lazy loading):
```dart
// lib/main.dart
final mockTestsRoute = GoRoute(
  path: '/mock-tests',
  builder: (context, state) {
    // Lazy load MockTestsScreen
    return FutureBuilder(
      future: () async {
        await Future.delayed(Duration.zero); // Deferred import
        return MockTestsScreen();
      }(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SmartLoadingScreen();
        }
        return snapshot.data!;
      },
    );
  },
);
```

2. **Tree Shaking** (verify unused code removed):
```bash
flutter build web --release --tree-shake-icons
```

3. **Image Optimization**:
```dart
Image.network(
  'https://firebasestorage.googleapis.com/...',
  cacheWidth: 800, // Resize for web display
  cacheHeight: 600,
)
```

4. **Font Subsetting** (Google Fonts):
```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: Roboto
      fonts:
        - asset: fonts/Roboto-Regular.woff2
          weight: 400
        # Only include weights actually used (400, 600, 700)
```

**Performance Budget**:
- Initial bundle: <2.5 MB uncompressed
- Transferred (gzipped): <1 MB
- Time to Interactive (TTI): <3s on 10 Mbps
- First Contentful Paint (FCP): <1.5s

**Lighthouse Score Targets**:
- Performance: >80
- Accessibility: >90
- Best Practices: >90
- SEO: N/A (app.jeevibe.com is authenticated app, not public)

---

#### **Day 9-10: Firebase Hosting Deployment** (2 days)

**Step 1: Build Production Bundle**
```bash
cd mobile
flutter build web --release --web-renderer canvaskit
```

**Step 2: Configure Firebase Hosting**

Create/update `firebase.json`:
```json
{
  "hosting": [
    {
      "site": "jeevibe-app",
      "public": "mobile/build/web",
      "ignore": [
        "firebase.json",
        "**/.*",
        "**/node_modules/**"
      ],
      "rewrites": [
        {
          "source": "**",
          "destination": "/index.html"
        }
      ],
      "headers": [
        {
          "source": "**/*.@(js|wasm)",
          "headers": [
            {
              "key": "Cache-Control",
              "value": "public, max-age=31536000, immutable"
            }
          ]
        },
        {
          "source": "**/*.@(jpg|jpeg|png|svg|webp|gif)",
          "headers": [
            {
              "key": "Cache-Control",
              "value": "public, max-age=86400"
            }
          ]
        },
        {
          "source": "index.html",
          "headers": [
            {
              "key": "Cache-Control",
              "value": "no-cache, no-store, must-revalidate"
            }
          ]
        },
        {
          "source": "**",
          "headers": [
            {
              "key": "X-Content-Type-Options",
              "value": "nosniff"
            },
            {
              "key": "X-Frame-Options",
              "value": "DENY"
            },
            {
              "key": "X-XSS-Protection",
              "value": "1; mode=block"
            }
          ]
        }
      ]
    }
  ]
}
```

**Step 3: Setup PWA Manifest**

Update `mobile/web/manifest.json`:
```json
{
  "name": "JEEVibe - AI-Powered JEE Preparation",
  "short_name": "JEEVibe",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#FFFFFF",
  "theme_color": "#9333EA",
  "description": "Adaptive learning platform for JEE Main & Advanced preparation",
  "orientation": "any",
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any maskable"
    }
  ]
}
```

**Step 4: Configure Service Worker** (PWA offline support)

`mobile/web/flutter_service_worker.js` is auto-generated, but verify it includes:
- Cached assets (fonts, images, icons)
- Cache strategy (cache-first for assets, network-first for API)

**Step 5: Deploy to Firebase**

```bash
# Initialize Firebase (if not done)
firebase login
firebase use jeevibe

# Deploy to staging first
firebase hosting:channel:deploy preview --only hosting:jeevibe-app
# Test at: https://jeevibe-app--preview-XXXXX.web.app

# Deploy to production (app.jeevibe.com)
firebase deploy --only hosting:jeevibe-app

# Verify deployment
curl -I https://app.jeevibe.com
```

**Step 6: DNS Configuration**

In Firebase Console (Hosting):
- Add custom domain: `app.jeevibe.com`
- Add DNS records (provided by Firebase):
  ```
  Type: A
  Name: app
  Value: 151.101.1.195 (Firebase IP)

  Type: A
  Name: app
  Value: 151.101.65.195 (Firebase IP)
  ```

**Step 7: SSL Certificate**

Firebase automatically provisions SSL via Let's Encrypt:
- Wait 24-48 hours for propagation
- Verify: `https://app.jeevibe.com` (should show green lock)

**Step 8: Post-Deployment Checklist**

- [ ] Test `app.jeevibe.com` loads correctly
- [ ] Verify SSL certificate is valid
- [ ] Test sign-in flow (Firebase Auth works)
- [ ] Check API calls (CORS configured for app.jeevibe.com)
- [ ] Test PWA installation (browser shows "Install" prompt)
- [ ] Verify service worker caching (offline mode works)
- [ ] Check cache headers (view in Network tab)
- [ ] Test on mobile devices (PWA manifest works)
- [ ] Verify Google Analytics tracking (if configured)

**Rollback Plan** (if deployment fails):
```bash
# Revert to previous version
firebase hosting:rollback --only hosting:jeevibe-app
```

---

**Deliverable**: Production web app deployed to `app.jeevibe.com` with:
- ✅ All automated tests passing
- ✅ Cross-browser testing complete
- ✅ Bundle size optimized (<2.5 MB)
- ✅ Performance benchmarks met
- ✅ Firebase Hosting configured with caching
- ✅ PWA manifest and service worker working
- ✅ SSL certificate active
- ✅ DNS pointing to app.jeevibe.com

---

### **Week 9-11: Snap & Solve (File Upload)**

**Goals**: File upload implementation for Snap & Solve

**Tasks**:
1. File Upload UI (Week 9 - 5 days)
   ```dart
   import 'dart:html' as html;

   Future<void> _uploadPhoto() async {
     if (kIsWeb) {
       final uploadInput = html.FileUploadInputElement()
         ..accept = 'image/*';
       uploadInput.click();

       await uploadInput.onChange.first;
       final file = uploadInput.files!.first;

       // Convert to bytes
       final reader = html.FileReader();
       reader.readAsDataUrl(file);
       await reader.onLoad.first;

       final bytes = reader.result as String;
       _processImage(bytes);
     } else {
       // Mobile: use image_picker (existing code)
     }
   }
   ```

2. Image Preview & Crop (Week 10 - 3 days)
   - Display uploaded image
   - Add crop tool (use `image_cropper_for_web` package)
   - Zoom/rotate controls
   - "Use This Photo" / "Retake" buttons

3. Backend Integration (Week 10 - 2 days)
   - Upload to Firebase Storage
   - Call Vision API (existing endpoint)
   - Show solution screen (existing component)

4. Testing & Polish (Week 11 - 5 days)
   - Test on all browsers
   - Test various image formats (JPG, PNG, HEIC)
   - Test large images (compression)
   - Error handling (upload failed, processing failed)

**Deliverable**: Snap & Solve works via file upload on web

---

## Platform-Specific Adaptations

### 1. Camera / Image Input

**Mobile**: `camera` package (live camera)
**Web**: HTML file input (upload from device)

```dart
Future<File?> getImage() async {
  if (kIsWeb) {
    return _getImageFromFileInput();
  } else {
    return _getImageFromCamera();
  }
}
```

---

### 2. Navigation

**Mobile**: Bottom navigation bar (4 tabs)
**Desktop Web**: Left sidebar (NavigationRail)

```dart
Widget build(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isDesktop = constraints.maxWidth > 900;
      return Scaffold(
        body: Row([
          if (isDesktop) _buildSidebar(),
          Expanded(child: _screens[_selectedIndex]),
        ]),
        bottomNavigationBar: isDesktop ? null : _buildBottomNav(),
      );
    },
  );
}
```

---

### 3. Text Selection

**Mobile**: Disabled during active quiz (prevent cheating)
**Web**: Same behavior

```dart
SelectionArea(
  child: SelectionContainer.disabled(
    child: QuestionText(question.text),
  ),
)
```

---

### 4. Offline Storage

**Mobile**: Isar (native database)
**Web**: Isar (IndexedDB backend)

```dart
// Same code works on both!
final isar = await Isar.open([QuestionSchema, UserProgressSchema]);
```

**Limit**: 100 cached solutions (vs 200 on mobile) to respect browser storage limits

---

### 5. Auto-Save & Session Recovery

**Mobile**: App lifecycle preserved by OS (minimal risk)
**Web**: Browser refresh = lost state (high risk)

**Solution**: Auto-save after each question (implemented in Week 4)

---

## Bundle Size Targets

| Metric | Target | Actual (Home Screen Test) |
|--------|--------|---------------------------|
| Initial Load (compressed) | 500 KB - 1 MB | 382 KB ✅ |
| Initial Load (uncompressed) | 1.5 - 2.5 MB | 1.9 MB ✅ |
| Load Time (10 Mbps) | <2s | 2.5s ⚠️ (needs optimization) |
| Load Time (50 Mbps) | <1s | ~1s ✅ |
| Cache Hit (returning users) | <500ms | TBD (Week 7 testing) |

**Optimization Strategies** (Week 7):
1. Code splitting (deferred imports for Mock Tests, Analytics)
2. Lazy loading images
3. Tree-shaking unused code
4. Service worker caching (PWA)

---

## Success Metrics

### Phase 1 (Week 8 - Web MVP)
- [ ] 90% feature parity with mobile (excluding Snap & Solve camera)
- [ ] Works on Chrome, Firefox, Safari, Edge (latest versions)
- [ ] Responsive design (mobile web, tablet, desktop)
- [ ] Load time <2s on 10 Mbps connection
- [ ] Browser back button protection works (no accidental quiz exit)

### Phase 2 (Week 11 - Snap & Solve)
- [ ] File upload success rate >95%
- [ ] Image processing accuracy matches mobile camera
- [ ] Works on all tested browsers

### Post-Launch
- [ ] <10% users report "slow loading" (user surveys)
- [ ] Cache hit rate >80% (returning users load instantly)
- [ ] Zero reports of "lost quiz progress" (auto-save works)

---

## Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Bundle grows >3 MB | Medium | Medium | Code splitting, lazy loading, monitoring |
| Tier-2/3 cities complain about speed | Medium | Medium | Smart loading screen, aggressive caching |
| Browser back button bypass | Low | High | Extensive testing across browsers |
| Auto-save causes lag | Low | Medium | Fire-and-forget pattern, silent fail retry |
| Offline mode quota exceeded | Medium | Low | Limit to 100 cached items, clear error |

---

## Code Reuse Breakdown (Final Estimate)

| Component | Lines of Code | Reuse % | Notes |
|-----------|---------------|---------|-------|
| **Backend API** | N/A | 100% | Zero changes needed |
| **Models** | ~2,000 | 100% | Pure Dart, platform-agnostic |
| **Providers (State)** | ~3,500 | 100% | Provider works on all platforms |
| **API Service** | ~2,500 | 100% | HTTP calls, no platform dependency |
| **Business Logic** | ~1,500 | 100% | IRT, theta, scoring |
| **Core Widgets** | ~8,000 | 75% | Add `isDesktop` params, responsive sizing |
| **Navigation** | ~500 | 60% | Left sidebar (desktop) + bottom nav (mobile) |
| **Screen Layouts** | ~5,000 | 50% | 2-column desktop, 1-column mobile |
| **Platform Adapters** | ~500 | 0% | NEW: Browser back, file input, storage |
| **TOTAL** | ~23,500 | **~70%** | **~16,500 lines reused, ~7,000 new** |

---

## Firebase Deployment Guide

### Production Deployment (Week 8, Day 9-10)

#### Step 1: Build Production Bundle

```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile

# Clean previous builds
flutter clean

# Get latest dependencies
flutter pub get

# Build for web (production mode, CanvasKit renderer)
flutter build web \
  --release \
  --web-renderer canvaskit \
  --source-maps \
  --dart-define=API_URL=https://api.jeevibe.com

# Verify build output
ls -lh build/web/
# Expected: ~2-3 MB total, main.dart.js should be largest file
```

**Build Output Structure**:
```
build/web/
├── index.html (entry point)
├── main.dart.js (Flutter app code, ~1.5 MB)
├── flutter.js (Flutter loader)
├── flutter_service_worker.js (PWA service worker)
├── manifest.json (PWA manifest)
├── version.json (build metadata)
├── assets/
│   ├── AssetManifest.bin
│   ├── AssetManifest.json
│   ├── FontManifest.json
│   ├── NOTICES
│   ├── fonts/ (Google Fonts, ~200 KB)
│   └── packages/
├── canvaskit/ (~800 KB, Flutter renderer)
│   ├── canvaskit.js
│   ├── canvaskit.wasm
│   └── profiling/
└── icons/ (PWA icons, 192px + 512px)
```

---

#### Step 2: Configure Firebase Hosting

**Update `firebase.json`** (in project root):
```json
{
  "hosting": [
    {
      "site": "jeevibe",
      "public": "website",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"]
    },
    {
      "site": "jeevibe-admin",
      "public": "admin-dashboard/dist",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
      "rewrites": [
        {
          "source": "**",
          "destination": "/index.html"
        }
      ]
    },
    {
      "site": "jeevibe-app",
      "public": "mobile/build/web",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
      "rewrites": [
        {
          "source": "**",
          "destination": "/index.html"
        }
      ],
      "headers": [
        {
          "source": "**/*.@(js|wasm)",
          "headers": [
            {
              "key": "Cache-Control",
              "value": "public, max-age=31536000, immutable"
            },
            {
              "key": "Access-Control-Allow-Origin",
              "value": "*"
            }
          ]
        },
        {
          "source": "**/*.@(jpg|jpeg|png|svg|webp|gif|ico)",
          "headers": [
            {
              "key": "Cache-Control",
              "value": "public, max-age=86400"
            }
          ]
        },
        {
          "source": "**/*.@(woff|woff2|ttf|otf|eot)",
          "headers": [
            {
              "key": "Cache-Control",
              "value": "public, max-age=2592000"
            },
            {
              "key": "Access-Control-Allow-Origin",
              "value": "*"
            }
          ]
        },
        {
          "source": "index.html",
          "headers": [
            {
              "key": "Cache-Control",
              "value": "no-cache, no-store, must-revalidate"
            }
          ]
        },
        {
          "source": "**",
          "headers": [
            {
              "key": "X-Content-Type-Options",
              "value": "nosniff"
            },
            {
              "key": "X-Frame-Options",
              "value": "DENY"
            },
            {
              "key": "X-XSS-Protection",
              "value": "1; mode=block"
            },
            {
              "key": "Referrer-Policy",
              "value": "strict-origin-when-cross-origin"
            }
          ]
        }
      ]
    }
  ],
  "functions": {
    "source": "functions"
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "storage": {
    "rules": "storage.rules"
  }
}
```

---

#### Step 3: Update PWA Manifest

**Edit `mobile/web/manifest.json`**:
```json
{
  "name": "JEEVibe - AI-Powered JEE Preparation",
  "short_name": "JEEVibe",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#FFFFFF",
  "theme_color": "#9333EA",
  "description": "Adaptive learning platform for JEE Main & Advanced preparation with IRT-based personalized quizzes",
  "orientation": "any",
  "categories": ["education", "productivity"],
  "lang": "en-IN",
  "dir": "ltr",
  "scope": "/",
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "icons/Icon-maskable-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "maskable"
    },
    {
      "src": "icons/Icon-maskable-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "maskable"
    }
  ],
  "screenshots": [
    {
      "src": "screenshots/home.png",
      "sizes": "1280x720",
      "type": "image/png",
      "form_factor": "wide"
    },
    {
      "src": "screenshots/quiz.png",
      "sizes": "750x1334",
      "type": "image/png",
      "form_factor": "narrow"
    }
  ],
  "shortcuts": [
    {
      "name": "Daily Quiz",
      "short_name": "Quiz",
      "description": "Start today's adaptive quiz",
      "url": "/daily-quiz",
      "icons": [{ "src": "icons/quiz-shortcut.png", "sizes": "96x96" }]
    },
    {
      "name": "Chapter Practice",
      "short_name": "Practice",
      "description": "Practice specific chapters",
      "url": "/chapter-practice",
      "icons": [{ "src": "icons/practice-shortcut.png", "sizes": "96x96" }]
    }
  ]
}
```

---

#### Step 4: Deploy to Staging (Preview Channel)

```bash
# Login to Firebase (if not already logged in)
firebase login

# Verify you're using the correct project
firebase use jeevibe
# Output: Now using project jeevibe

# Deploy to preview channel for testing
firebase hosting:channel:deploy preview \
  --only hosting:jeevibe-app \
  --expires 7d

# Output will include preview URL:
# ✔ Deploy complete!
# Channel URL (jeevibe-app): https://jeevibe-app--preview-xxxxx.web.app
# Expires at: 2026-02-27 12:00:00
```

**Test on Preview**:
- [ ] Visit preview URL
- [ ] Test sign-in flow
- [ ] Complete daily quiz
- [ ] Check browser back protection
- [ ] Test on mobile devices
- [ ] Verify API calls work (CORS configured)
- [ ] Check service worker caching
- [ ] Test PWA installation

---

#### Step 5: Deploy to Production

```bash
# Deploy to production (app.jeevibe.com)
firebase deploy --only hosting:jeevibe-app

# Output:
# === Deploying to 'jeevibe'...
#
# i  deploying hosting
# i  hosting[jeevibe-app]: beginning deploy...
# i  hosting[jeevibe-app]: found 156 files in mobile/build/web
# ✔  hosting[jeevibe-app]: file upload complete
# i  hosting[jeevibe-app]: finalizing version...
# ✔  hosting[jeevibe-app]: version finalized
# i  hosting[jeevibe-app]: releasing new version...
# ✔  hosting[jeevibe-app]: release complete
#
# ✔  Deploy complete!
#
# Project Console: https://console.firebase.google.com/project/jeevibe/overview
# Hosting URL: https://jeevibe-app.web.app
```

**Verify Deployment**:
```bash
# Check deployed files
curl -I https://jeevibe-app.web.app

# Output should show:
# HTTP/2 200
# cache-control: no-cache, no-store, must-revalidate
# content-type: text/html; charset=utf-8
# x-content-type-options: nosniff
# x-frame-options: DENY
```

---

#### Step 6: Configure Custom Domain (app.jeevibe.com)

**In Firebase Console** (console.firebase.google.com):

1. Navigate to **Hosting** → **jeevibe-app**
2. Click **Add custom domain**
3. Enter: `app.jeevibe.com`
4. Firebase will provide DNS records:
   ```
   Type: A
   Name: app
   Value: 151.101.1.195

   Type: A
   Name: app
   Value: 151.101.65.195
   ```

**In Cloudflare/Domain Registrar**:

1. Add A records pointing `app.jeevibe.com` to Firebase IPs
2. Wait 10-60 minutes for DNS propagation
3. Firebase will auto-provision SSL certificate (Let's Encrypt)
4. Wait 24-48 hours for full SSL propagation

**Verify DNS**:
```bash
# Check DNS records
dig app.jeevibe.com

# Check SSL certificate
curl -vI https://app.jeevibe.com 2>&1 | grep -i "SSL\|TLS"
```

---

#### Step 7: Update Backend CORS

**In `backend/src/index.js`**, add `app.jeevibe.com` to allowed origins:

```javascript
const cors = require('cors');

app.use(cors({
  origin: [
    'http://localhost:3000',
    'https://jeevibe.com',
    'https://www.jeevibe.com',
    'https://admin.jeevibe.com',
    'https://jeevibe-admin.web.app',
    'https://app.jeevibe.com',        // ADD THIS
    'https://jeevibe-app.web.app'     // ADD THIS (Firebase default)
  ],
  credentials: true
}));
```

**Deploy backend**:
```bash
cd backend
git add .
git commit -m "feat: Add app.jeevibe.com to CORS allowed origins"
git push origin main
# Wait for Render.com auto-deploy (2-3 minutes)
```

---

#### Step 8: Post-Deployment Checklist

**Functionality Tests**:
- [ ] Visit https://app.jeevibe.com (loads correctly)
- [ ] SSL certificate is valid (green lock icon)
- [ ] Sign in with phone + OTP works
- [ ] Complete daily quiz (10 questions)
- [ ] API calls succeed (check Network tab, no CORS errors)
- [ ] Browser back protection works
- [ ] Auto-save restores progress after refresh
- [ ] PWA install prompt appears (desktop Chrome)
- [ ] Service worker caches assets (check Application tab)
- [ ] Offline mode works (disconnect internet, reload)

**Performance Tests**:
- [ ] Lighthouse score: Performance >80
- [ ] Initial load <2s (10 Mbps throttle)
- [ ] Cached load <500ms
- [ ] LaTeX renders correctly
- [ ] No console errors

**Mobile Tests**:
- [ ] Visit on mobile Chrome (Android)
- [ ] Visit on mobile Safari (iOS)
- [ ] PWA "Add to Home Screen" works
- [ ] Installed PWA launches in standalone mode
- [ ] Bottom navigation works on mobile web

---

#### Step 9: Rollback Plan (if needed)

**If critical bug found after deployment**:

```bash
# View deployment history
firebase hosting:channel:list --only jeevibe-app

# Rollback to previous version
firebase hosting:rollback --only jeevibe-app

# Or deploy specific version
firebase hosting:clone jeevibe-app:previous_version_id jeevibe-app:live
```

**Alternative: Deploy hotfix to preview, then promote**:
```bash
# Fix bug locally
# Test locally: flutter run -d chrome

# Build and deploy to preview
flutter build web --release
firebase hosting:channel:deploy hotfix --only jeevibe-app

# Test on preview URL
# If OK, promote to production
firebase hosting:clone jeevibe-app:hotfix jeevibe-app:live
```

---

#### Step 10: Monitoring & Analytics

**Firebase Performance Monitoring**:
```dart
// Add to mobile/pubspec.yaml
dependencies:
  firebase_performance: ^0.9.3

// Initialize in main.dart (web only)
if (kIsWeb) {
  await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
}
```

**Google Analytics 4** (already configured):
- Verify events tracked: `quiz_started`, `quiz_completed`, `chapter_practice_started`
- Check Real-time reports in Firebase Console

**Error Tracking**:
- Firebase Crashlytics (web not supported, use Sentry instead)
- Check browser console for runtime errors

---

### Deployment Architecture

**Current Structure**:
```
Firebase Hosting
├── jeevibe.com (marketing site)
│   └── website/ (HTML + Tailwind)
│
├── admin.jeevibe.com (admin dashboard)
│   └── admin-dashboard/dist/ (React + Vite)
│
└── app.jeevibe.com (Flutter Web app) ← NEW
    └── mobile/build/web/ (Flutter compiled)

Backend API
└── api.jeevibe.com (Node.js on Render.com)
```

**CDN & Caching**:
- Firebase Hosting uses Google's global CDN
- Assets cached for 1 year (immutable files)
- HTML cached for 0s (always fresh)
- Fonts cached for 30 days

---

### CI/CD Pipeline (Optional - Post-Launch)

**GitHub Actions** (`.github/workflows/deploy-web.yml`):
```yaml
name: Deploy Flutter Web

on:
  push:
    branches: [main]
    paths:
      - 'mobile/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'

      - name: Install dependencies
        run: |
          cd mobile
          flutter pub get

      - name: Run tests
        run: |
          cd mobile
          flutter test

      - name: Build web
        run: |
          cd mobile
          flutter build web --release --web-renderer canvaskit

      - name: Deploy to Firebase
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          projectId: jeevibe
          channelId: live
          target: jeevibe-app
```

---

### Cache Headers Reference

**Aggressive Caching** (Week 8 deployment):
```
JavaScript/WASM: 1 year (immutable, content-hashed filenames)
Images: 1 day (may update occasionally)
Fonts: 30 days (rarely change)
index.html: 0s (always fresh, entry point)
```

**Security Headers**:
- `X-Content-Type-Options: nosniff` - Prevent MIME sniffing
- `X-Frame-Options: DENY` - Prevent clickjacking
- `X-XSS-Protection: 1; mode=block` - XSS protection
- `Referrer-Policy: strict-origin-when-cross-origin` - Referrer control

---

## Testing Strategy

### Automated Testing (Continuous)

**Unit Tests** (Backend):
- 384 existing tests (maintain 100% pass rate)
- Add web-specific CORS tests
- Test tier limits work for web sessions
- Run on every commit via GitHub Actions

**Widget Tests** (Flutter):
```bash
# Run all widget tests
flutter test

# Run with coverage
flutter test --coverage
lcov --summary coverage/lcov.info
```

**Coverage Targets**:
- Critical widgets (quiz card, question card): 90%+
- Providers (state management): 80%+
- Services (API, storage): 70%+
- Overall: 70%+ (matching mobile)

**Integration Tests** (E2E):
```bash
# Run integration tests on Chrome
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  -d chrome
```

**Test Suites**:
1. `quiz_flow_test.dart` - Complete daily quiz (10 questions)
2. `practice_flow_test.dart` - Chapter practice session
3. `mock_test_flow_test.dart` - Full 90-question mock test
4. `browser_back_test.dart` - Browser back protection
5. `auto_save_test.dart` - Progress restoration after refresh

---

### Manual Testing Checklist

**Responsive Design** (all features):
- [ ] 375px (mobile web)
- [ ] 768px (tablet)
- [ ] 900px (breakpoint)
- [ ] 1200px (desktop)
- [ ] 1920px (large desktop)

**Browser Compatibility**:
- [ ] Chrome (latest, Win/Mac/Linux)
- [ ] Firefox (latest, Win/Mac/Linux)
- [ ] Safari (latest, Mac/iOS)
- [ ] Edge (latest, Win)
- [ ] Mobile Chrome (Android)
- [ ] Mobile Safari (iOS)

**Critical User Flows**:
- [ ] Sign in (phone + OTP)
- [ ] Complete daily quiz (all 10 questions)
- [ ] Start chapter practice
- [ ] Complete mock test (full 90 questions)
- [ ] View analytics dashboard
- [ ] Edit profile
- [ ] View history screens
- [ ] Upload image (Snap & Solve)

**Web-Specific Features**:
- [ ] Browser back button protection works
- [ ] Auto-save restores progress after refresh
- [ ] Keyboard navigation (arrows, enter, numbers)
- [ ] Text selection disabled during quiz
- [ ] PWA install prompt appears
- [ ] Offline mode (100 cached solutions)
- [ ] Service worker caches assets

**Performance Benchmarks**:
- [ ] Initial load <2s (10 Mbps throttle)
- [ ] Cached load <500ms
- [ ] Quiz transitions <100ms
- [ ] Auto-save non-blocking (<50ms perceived)
- [ ] LaTeX renders <200ms

---

### Testing Tools

**Performance**:
- Chrome DevTools (Lighthouse, Network, Performance)
- WebPageTest (multi-location testing)
- Firebase Performance Monitoring

**Cross-Browser**:
- BrowserStack (paid service for multi-device testing)
- Local VMs (Windows, Linux, macOS)

**Automated**:
- GitHub Actions (CI/CD for tests)
- Firebase Test Lab (mobile web testing)

---

## Implementation Checklist

### Pre-Implementation (Week 0)
- [x] UI/UX validation test completed
- [x] Responsive design approved
- [x] Navigation pattern decided (left sidebar)
- [x] Browser back protection planned
- [x] Auto-save strategy finalized
- [x] Bundle size target set (<2.5 MB)
- [x] Testing strategy defined
- [x] Firebase deployment plan created
- [ ] **Begin implementation** ← READY WHEN YOU SAY GO

### Week 1-2: Foundation
- [ ] `jeevibe_core` package created
- [ ] Web platform enabled (`flutter create . --platforms=web`)
- [ ] Browser back protection implemented
- [ ] Smart loading screen built
- [ ] Test build compiles successfully
- [ ] **Testing**: Widget tests for responsive components

### Week 3-4: Core Features
- [ ] Daily Quiz responsive (with auto-save)
- [ ] Chapter Practice responsive
- [ ] Mock Tests responsive
- [ ] Left sidebar navigation implemented
- [ ] Test on 1920px, 900px, 375px screens
- [ ] **Testing**: Integration tests for quiz/practice flows

### Week 5-6: Additional Features
- [ ] Analytics Dashboard responsive
- [ ] Profile & Settings responsive
- [ ] History screens responsive
- [ ] Keyboard navigation implemented
- [ ] **Testing**: Cross-browser smoke tests

### Week 7-8: Testing & Deployment
- [ ] **Day 1-3**: Automated tests (unit, widget, integration)
- [ ] **Day 4-6**: Cross-browser testing (Chrome, Firefox, Safari, Edge)
- [ ] **Day 7-8**: Performance optimization (<2.5 MB bundle)
- [ ] **Day 9-10**: Firebase Hosting deployment
- [ ] Bundle size optimized (<2.5 MB) ✅
- [ ] Performance benchmarks met ✅
- [ ] Deployed to `app.jeevibe.com` ✅
- [ ] SSL certificate active ✅
- [ ] PWA manifest working ✅
- [ ] Service worker caching verified ✅

### Week 9-11: Snap & Solve
- [ ] Snap & Solve file upload working
- [ ] Image preview & crop functional
- [ ] Cross-browser testing for file upload
- [ ] Full feature parity achieved
- [ ] **Final Testing**: Regression test all features

---

## Team Requirements

**Developer**: 1 full-time (Flutter + web experience)

**Skills Needed**:
- Flutter (intermediate to advanced)
- Responsive design (LayoutBuilder, MediaQuery)
- Web APIs (dart:html for browser back button)
- Firebase Hosting deployment
- Performance optimization

**Tools**:
- Flutter SDK (latest stable)
- VS Code / Android Studio
- Chrome DevTools (performance profiling)
- Firebase CLI
- Git

---

## Next Steps

1. **Review this plan** with stakeholders
2. **Get final approval** to begin implementation
3. **Week 1 Day 1**: Create `jeevibe_core` package and enable web platform
4. **Weekly check-ins**: Review progress, address blockers
5. **Week 8 demo**: Show web MVP to users for feedback
6. **Week 11 launch**: Deploy to production

---

## Questions to Resolve Before Starting

✅ All questions resolved! Ready to proceed.

**Decisions Made**:
1. ✅ Navigation: Left sidebar (desktop) + bottom nav (mobile)
2. ✅ Browser back: Full protection on quiz/practice screens
3. ✅ Auto-save: After each question submission (non-blocking)
4. ✅ Colors: Purple brand palette (validated in test)
5. ✅ Background: Clean white (no light purple tint)
6. ✅ Bundle size: <2.5 MB target (current test: 1.9 MB)
7. ✅ Code reuse: ~70% realistic estimate

**GO / NO-GO**: ✅ **GO** - Approved to proceed with implementation

---

## Appendix: Test Results

### Validation Test (2026-02-20)

**Test Project**: `flutter_web_ui_test`

**Results**:
- Bundle Size: 1.9 MB uncompressed, 382 KB transferred ✅
- Load Time: ~2.5s on first load, <1s cached
- LaTeX Rendering: Works correctly ✅
- Responsive Layout: 2-column desktop, 1-column mobile ✅
- Color Palette: Purple brand colors validated ✅
- User Feedback: "Not as snappy as pure web app, but not a deal breaker YET"

**Conclusion**: Flutter Web UI/UX is acceptable for JEEVibe web app

---

## Appendix B: Web-Specific QA Plan

### Overview

**Key Finding**: JEEVibe has **STRONG existing test coverage**:
- ✅ Backend: 431 unit tests passing (21 services tested)
- ✅ Mobile: 56 test files covering models, services, widgets, flows
- ✅ CI/CD: GitHub Actions running on every PR

**What's Needed for Web**: Only **WEB-SPECIFIC** testing (15-20 tests), not duplicating existing coverage.

---

### Existing Test Coverage (100% Reusable)

#### ✅ **Backend Tests** (431 tests - NO web testing needed)

**Services Already Tested** (work identically on web):
- `thetaUpdateService` - Bayesian theta updates ✅
- `questionSelectionService` - IRT question selection ✅
- `dailyQuizService` - Quiz generation ✅
- `chapterPracticeService` - Chapter practice flow ✅
- `mockTestService` - Mock test generation ✅
- `authService` - Phone OTP (works on web) ✅
- `subscriptionService` - Tier management ✅
- `weakSpotScoringService` - Cognitive Mastery ✅
- `aiTutorService` - AI tutor responses ✅
- `spacedRepetitionService` - Spaced repetition ✅
- **+ 11 more services** (all platform-agnostic)

**Integration Tests** (8 API flows):
- Authentication flow ✅
- Daily quiz API ✅
- Chapter practice API ✅
- Snap & Solve API ✅
- Analytics endpoints ✅

**CI/CD**: `.github/workflows/backend-tests.yml` runs all 431 tests on every PR

**Conclusion**: ✅ **NO backend testing needed for web** - already covered.

---

#### ✅ **Mobile Tests** (56 files - 85% reusable)

**Models** (8 tested - 100% reusable):
- Assessment question/response ✅
- User profile ✅
- Solution model ✅
- AI tutor models ✅
- Chapter practice models ✅

**Services** (12 tested - 95% reusable):
- `api_service` - HTTP client (web-compatible) ✅
- `latex_parser` - LaTeX rendering (web-compatible) ✅
- `chemistry_formatter` - Chemistry formulas ✅
- `image_compressor` - Image optimization ✅
- `storage_service` - Needs web adapter ⚠️
- `pin_service` - Skip on web ⚠️
- Offline services - Need web variants ⚠️

**Widgets** (18 tested):
- `latex_widget` - Works on web ✅
- `chemistry_text` - Works on web ✅
- `priya_avatar` - AI avatar ✅
- Buttons, cards, dialogs - Need responsive variants ⚠️

**CI/CD**: `.github/workflows/mobile-tests.yml` runs Flutter tests on every PR

**Conclusion**: ✅ **85% of mobile tests reusable** - only need web-specific variants.

---

### Web-Specific Tests Needed (15 Core Tests)

#### **Category 1: Browser Back Button Protection** (5 tests)

```dart
// integration_test/web/browser_back_test.dart
testWidgets('Browser back during quiz shows confirmation', (tester) async {
  await tester.tap(find.text('Start Quiz'));
  await tester.pumpAndSettle();

  if (kIsWeb) {
    html.window.history.back();
    await tester.pump();
    expect(find.text('Exit Quiz?'), findsOneWidget);
  }
});
```

**Test Cases**:
- TC001: Back button during quiz shows confirmation dialog
- TC002: "Stay" button keeps quiz open
- TC003: "Exit" button closes quiz and clears protection
- TC004: Back button during mock test
- TC005: Back button during chapter practice

---

#### **Category 2: Responsive Breakpoints** (4 tests)

```dart
// test/widgets/responsive_test.dart
testWidgets('Navigation switches at 900px breakpoint', (tester) async {
  // Desktop (≥900px)
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(1200, 800)),
        child: HomeScreen(),
      ),
    ),
  );
  expect(find.byType(NavigationRail), findsOneWidget);
  expect(find.byType(BottomNavigationBar), findsNothing);

  // Mobile (<900px)
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(375, 667)),
        child: HomeScreen(),
      ),
    ),
  );
  expect(find.byType(NavigationRail), findsNothing);
  expect(find.byType(BottomNavigationBar), findsOneWidget);
});
```

**Test Cases**:
- TC006: NavigationRail visible at ≥900px (desktop)
- TC007: BottomNavigationBar visible at <900px (mobile)
- TC008: Quiz card shows 2-column options on desktop
- TC009: Quiz card shows 1-column options on mobile

---

#### **Category 3: Keyboard Shortcuts** (4 tests)

```dart
// test/widgets/keyboard_shortcuts_test.dart
testWidgets('Number keys select options', (tester) async {
  await tester.pumpWidget(QuizScreen());

  // Press '1' key
  await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
  await tester.pump();

  // Verify option A selected
  expect(find.byWidgetPredicate(
    (widget) => widget is OptionCard &&
                 widget.isSelected &&
                 widget.option == 'A'
  ), findsOneWidget);
});
```

**Test Cases**:
- TC010: Numbers 1-4 select options A-D
- TC011: Enter key submits answer
- TC012: Esc key shows exit confirmation
- TC013: Arrow keys navigate between options

---

#### **Category 4: Web Storage** (2 tests)

```dart
// test/services/web_storage_test.dart
testWidgets('IndexedDB quota cleanup triggers at 80MB', (tester) async {
  final quotaService = StorageQuotaService();

  // Mock storage at 81 MB (over limit)
  when(mockNavigator.storage.estimate())
    .thenAnswer((_) async => {'usage': 81 * 1024 * 1024});

  final hasSpace = await quotaService.hasSpaceForCache();
  expect(hasSpace, false);

  // Verify cleanup called
  verify(quotaService.cleanupOldestCaches()).called(1);
});
```

**Test Cases**:
- TC014: Cleanup triggers when approaching 80 MB
- TC015: Maximum 100 cached solutions on web

---

### Cross-Browser Testing Strategy

**Approach**: Automated via Playwright (NOT manual)

**Test Matrix**: 15 web-specific tests × 6 browsers = **90 test executions**

```yaml
Browsers to Test:
  Chrome (Windows, macOS, Linux):
    - All 15 web-specific tests
    - Expected: 100% pass rate

  Firefox (Windows, macOS):
    - All 15 web-specific tests
    - Expected: 100% pass rate
    - Note: Keyboard events may behave slightly differently

  Safari (macOS, iOS):
    - All 15 web-specific tests
    - Expected: 95%+ pass rate
    - Note: Browser back may have quirks

  Edge (Windows):
    - All 15 web-specific tests
    - Expected: 100% pass rate

  Mobile Chrome (Android):
    - Responsive tests (TC006-TC009)
    - Touch events
    - Expected: 100% pass rate

  Mobile Safari (iOS):
    - Responsive tests (TC006-TC009)
    - Touch events
    - Expected: 95%+ pass rate
    - Note: Limited keyboard support
```

**Automation Setup**:
```bash
# Install Playwright
npm install -D @playwright/test

# Run cross-browser tests
npx playwright test --project=chromium
npx playwright test --project=firefox
npx playwright test --project=webkit
```

**Estimated Time**: 2-3 hours automated (vs 72 hours manual)

---

### Week 0.5: QA Infrastructure Setup (2 days)

**Goal**: Setup web-specific test infrastructure BEFORE Week 1

**Day 1: Web Test Setup**
```yaml
Tasks:
  ✅ Create test directory: integration_test/web/
  ✅ Setup Flutter web test driver
     flutter drive --driver=test_driver/integration_test.dart \
       --target=integration_test/web/browser_back_test.dart \
       -d chrome

  ✅ Install Playwright for cross-browser testing
     npm install -D @playwright/test

  ✅ Update CI/CD for web tests
     # .github/workflows/flutter-web-ci.yml
     - Run web-specific tests on Chrome
     - Upload web coverage to Codecov
```

**Day 2: Write Web-Specific Test Cases**
```yaml
Tasks:
  ✅ Write 5 browser back button tests
  ✅ Write 4 responsive breakpoint tests
  ✅ Write 4 keyboard shortcut tests
  ✅ Write 2 IndexedDB storage tests

  ✅ Create test fixtures for web
     # Test users with different thetas
     # Test questions for web scenarios

  ✅ Verify existing backend tests still pass
     cd backend && npm test
```

**Deliverable**: Web test infrastructure ready for Week 1

---

### Performance Testing (Week 7)

**Web-Specific Performance Tests** (backend already tested):

```yaml
1. Bundle Size Check (CI/CD automated):
   Tool: flutter build web --analyze-size
   Target: <2.5 MB uncompressed
   Fail build: If exceeded

2. Load Time Check:
   Tool: Lighthouse CI
   Target: <2s on 10 Mbps
   Metrics: TTI, FCP, LCP, CLS

3. Service Worker Caching:
   Verify: Assets cached (fonts, JS, WASM)
   Test: Offline mode (disconnect internet)

4. IndexedDB Performance:
   Write: 100 solutions
   Read: All solutions
   Cleanup: 20% oldest
   Target: <1s total
```

**Lighthouse CI Setup**:
```bash
# Install Lighthouse CI
npm install -g @lhci/cli

# Run automated checks
lhci autorun --config=lighthouserc.json

# Fail if score < 80
if [ $LIGHTHOUSE_SCORE -lt 80 ]; then
  exit 1
fi
```

**Performance Budget** (lighthouserc.json):
```json
{
  "ci": {
    "assert": {
      "assertions": {
        "categories:performance": ["error", {"minScore": 0.8}],
        "first-contentful-paint": ["error", {"maxNumericValue": 1500}],
        "interactive": ["error", {"maxNumericValue": 3000}]
      }
    }
  }
}
```

---

### CI/CD Pipeline for Web Tests

**GitHub Actions Workflow** (`.github/workflows/flutter-web-ci.yml`):

```yaml
name: Flutter Web CI

on:
  push:
    branches: [main, develop]
    paths: ['mobile/**']
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: 'stable'

      - name: Install dependencies
        run: |
          cd mobile
          flutter pub get

      - name: Run unit tests
        run: |
          cd mobile
          flutter test --coverage

      - name: Build web
        run: |
          cd mobile
          flutter build web --release

      - name: Run web-specific tests
        run: |
          cd mobile
          flutter drive \
            --driver=test_driver/integration_test.dart \
            --target=integration_test/web/ \
            -d chrome

      - name: Check bundle size
        run: |
          cd mobile/build/web
          BUNDLE_SIZE=$(du -sk . | cut -f1)
          if [ $BUNDLE_SIZE -gt 2560 ]; then
            echo "Bundle exceeds 2.5 MB: ${BUNDLE_SIZE}KB"
            exit 1
          fi

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: mobile/coverage/lcov.info

  lighthouse:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Run Lighthouse CI
        uses: treosh/lighthouse-ci-action@v9
        with:
          uploadArtifacts: true
```

**Quality Gates**:
- ✅ All existing tests pass (backend 431 + mobile 56)
- ✅ 15 web-specific tests pass
- ✅ Bundle size <2.5 MB
- ✅ Lighthouse score >80
- ✅ Test coverage >70%

---

### Smoke Test Suite (Production Deploy)

**Post-Deployment Smoke Tests** (15-20 minutes):

```yaml
1. Health Check:
   - GET https://app.jeevibe.com → 200 OK
   - SSL certificate valid
   - Service worker registered

2. Authentication:
   - Sign in with test account (+919999999999)
   - Session persists after refresh
   - Logout clears session

3. Daily Quiz:
   - Load quiz screen
   - Answer 1 question
   - Verify auto-save triggered

4. API Connectivity:
   - All API calls succeed (no CORS errors)
   - Response time <1s

5. Analytics:
   - Dashboard loads
   - Theta chart renders

6. Responsive:
   - Mobile view works (375px)
   - Desktop view works (1200px)

7. Browser Back:
   - Start quiz
   - Press back button
   - Verify confirmation shown
```

**Automation** (Cypress):
```javascript
// cypress/e2e/smoke-test.cy.js
describe('Production Smoke Test', () => {
  it('loads app successfully', () => {
    cy.visit('https://app.jeevibe.com');
    cy.contains('JEEVibe').should('be.visible');
  });

  it('signs in', () => {
    cy.get('[data-cy=phone-input]').type('9999999999');
    cy.get('[data-cy=request-otp]').click();
    // OTP entry...
    cy.url().should('include', '/home');
  });

  // ... remaining smoke tests
});
```

---

### QA Effort Summary

**Total QA Work Breakdown**:

| Week | QA Tasks | Effort |
|------|----------|--------|
| **Week 0.5** | Web test setup | 2 days |
| **Week 1-2** | Responsive tests | 1 day |
| **Week 3-4** | Keyboard/storage tests | 0.5 day |
| **Week 5-6** | Reuse existing tests | 0 days |
| **Week 7-8** | Cross-browser + perf | 5 days |
| **Week 9-11** | File upload test | 0.5 day |
| **Total** | | **9 days** |

**Comparison**:
- Original plan (no existing tests): 21 days
- Revised plan (leveraging 487+ existing tests): **9 days**
- **Savings**: 12 days (57% reduction)

---

### What We're NOT Duplicating

**Already Covered by Existing Tests**:

1. ❌ Backend API Testing
   - 431 unit tests already cover all backend logic
   - 8 integration tests cover API flows
   - Action: REUSE existing tests

2. ❌ Business Logic Testing
   - IRT calculations ✅
   - Theta updates ✅
   - Question selection ✅
   - Spaced repetition ✅
   - Action: Trust existing backend tests

3. ❌ Model/Data Parsing
   - 8 mobile model tests already cover this
   - Action: REUSE existing mobile tests

4. ❌ Widget Rendering
   - 18 mobile widget tests already cover rendering
   - Action: Only add responsive VARIANTS

5. ❌ Integration Flows
   - Auth, quiz, practice already tested
   - Action: Verify they work on web (no rewrite)

---

### Final QA Checklist

**Pre-Implementation (Week 0)**:
- [x] Existing backend tests documented (431 tests)
- [x] Existing mobile tests documented (56 files)
- [x] Web-specific test plan created (15 tests)
- [ ] QA infrastructure setup (Week 0.5)

**During Implementation**:
- [ ] Week 1-2: Write 9 responsive + browser back tests
- [ ] Week 3-4: Write 6 keyboard + storage tests
- [ ] Week 5-6: Verify existing tests work on web
- [ ] Week 7-8: Cross-browser automation + performance

**Pre-Production (Week 8)**:
- [ ] All 431 backend tests passing
- [ ] All 56 mobile test files passing
- [ ] All 15 web-specific tests passing
- [ ] Cross-browser tests passing (90 executions)
- [ ] Bundle size <2.5 MB
- [ ] Lighthouse score >80
- [ ] Smoke tests passing on staging

**Post-Production (Week 8+)**:
- [ ] Smoke tests passing on production
- [ ] Monitoring alerts configured (Sentry)
- [ ] Performance tracking active (Lighthouse CI)

---

**QA Plan Status**: APPROVED
**Total Tests**: 487+ existing + 15 web-specific = **502+ tests**
**Estimated QA Effort**: 9 days (vs 21 days without existing tests)
**Quality Level**: Production-ready with comprehensive coverage

---

**Document Version**: 1.1
**Last Updated**: 2026-02-20
**Status**: FINAL - APPROVED FOR IMPLEMENTATION (with QA additions)
