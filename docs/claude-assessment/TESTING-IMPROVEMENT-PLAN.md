# JEEVibe Testing Improvement Plan

**Date**: December 31, 2025
**Status**: Comprehensive Testing Strategy
**Target Coverage**: 80% (Unit) | 60% (Integration) | Critical Paths (E2E)

---

## 📊 Current Testing Status

### Backend Testing (Node.js/Express)

**Current State**:
- ✅ **5 test files** (excluding node_modules)
  - 3 unit tests (questionSelectionService, thetaUpdateService, spacedRepetitionService)
  - 1 integration test (dailyQuiz API)
  - 1 utility test (latex-validator)
- ✅ Jest configured with coverage support
- ⚠️ **Low coverage** (~15-20% estimated)

**Services**:
- Total: **17 service files**
- Tested: **3 services** (18%)
- Untested: 14 services

**Routes/Controllers**:
- Total: **8 route files**
- Tested: **1 route** (12.5%)
- Untested: 7 routes

**Testing Infrastructure**:
- ✅ Jest setup complete
- ✅ Supertest for API testing
- ⚠️ No Firebase Emulator integration
- ❌ No CI/CD test automation
- ❌ No test coverage reporting
- ❌ No E2E tests

---

### Mobile Testing (Flutter/Dart)

**Current State**:
- ✅ **25 test files**
  - 11 unit tests (models, services, utils)
  - 4 integration tests (auth, assessment, snap_solve, profile flows)
  - 10 widget tests (screens and components)
- ✅ Test helpers and mocks setup
- ✅ Fixture data for testing
- ⚠️ **Medium coverage** (~40-50% estimated)

**Services**:
- Tested: api_service, storage_service, pin_service, snap_counter_service
- Partially tested: Some providers

**Test Categories**:
- ✅ Unit tests: Models, utils, services
- ✅ Widget tests: Key UI components
- ✅ Integration tests: User flows
- ⚠️ Many tests have placeholder implementations (expect(true, true))
- ❌ No golden tests for UI regression
- ❌ No performance tests

---

## 🎯 Testing Strategy Overview

### Testing Pyramid

```
           /\
          /  \         E2E Tests (10%)
         /    \        - Critical user journeys
        /------\       - Real Firebase + OpenAI
       /        \
      /  Integ.  \     Integration Tests (30%)
     /   Tests    \    - API contracts
    /--------------\   - Service interactions
   /                \
  /   Unit Tests     \ Unit Tests (60%)
 /                    \- Pure functions
/______________________\- Business logic
```

### Coverage Targets

| Layer | Target | Current | Gap |
|-------|--------|---------|-----|
| **Backend Unit** | 80% | ~15% | +65% |
| **Backend Integration** | 60% | ~5% | +55% |
| **Mobile Unit** | 75% | ~40% | +35% |
| **Mobile Widget** | 70% | ~30% | +40% |
| **E2E Critical Paths** | 100% | 0% | +100% |

---

## 🔥 Priority 1: Fix Critical Gaps (Week 1) - 16-20 hours

### Backend: Critical Service Tests

**MUST TEST** (these have critical business logic):

#### 1.1 thetaCalculationService.js (HIGH PRIORITY) - 4-5 hours

**File**: `backend/src/services/thetaCalculationService.js`

**Why Critical**:
- Theta calculation is foundation of adaptive learning
- Complex math (Normal CDF, percentile conversion)
- We found a critical bug (theta updates outside transaction)

**Tests to Add**:
```javascript
// tests/unit/services/thetaCalculationService.test.js

describe('Theta Calculation Service', () => {
  describe('calculateTheta', () => {
    test('should calculate theta correctly for all correct answers');
    test('should calculate theta correctly for all incorrect answers');
    test('should handle mixed correct/incorrect answers');
    test('should converge to correct theta after multiple iterations');
    test('should respect theta bounds [-3, 3]');
  });

  describe('percentile conversion', () => {
    test('theta 0 should convert to 50th percentile');
    test('theta +1 should convert to ~84th percentile');
    test('theta -1 should convert to ~16th percentile');
    test('theta +2 should convert to ~98th percentile');
    test('extreme values should clamp to [0.1%, 99.9%]');
  });

  describe('weighted overall theta', () => {
    test('should weight chapters correctly (JEE weights)');
    test('should handle missing chapters gracefully');
    test('should calculate weighted average accurately');
  });

  describe('edge cases', () => {
    test('should handle zero attempts gracefully');
    test('should handle all questions with same difficulty');
    test('should handle numerical instability (very high/low theta)');
  });
});
```

**Estimated**: 4-5 hours (complex math requires careful validation)

---

#### 1.2 dailyQuizService.js (CRITICAL) - 5-6 hours

**File**: `backend/src/services/dailyQuizService.js`

**Why Critical**:
- Core feature of the app
- Complex business logic (exploration vs exploitation)
- Multiple fallback mechanisms

**Tests to Add**:
```javascript
// tests/unit/services/dailyQuizService.test.js

describe('Daily Quiz Service', () => {
  describe('quiz generation', () => {
    test('exploration phase: should select diverse chapters');
    test('exploitation phase: should focus on weak chapters');
    test('should respect chapter diversity requirements');
    test('should filter recently answered questions');
    test('should handle insufficient questions gracefully');
  });

  describe('learning phase transition', () => {
    test('should use exploration for quizzes 0-13');
    test('should switch to exploitation at quiz 14');
    test('should calculate weak chapters correctly');
  });

  describe('circuit breaker', () => {
    test('should trigger after 3 consecutive low scores');
    test('should select easier questions in recovery quiz');
    test('should reset after recovery quiz completion');
  });

  describe('fallback mechanisms', () => {
    test('should fallback to any questions if no chapter match');
    test('should proceed with partial quiz if <10 questions');
    test('should handle empty question bank gracefully');
  });

  describe('edge cases', () => {
    test('should handle new user (no quiz history)');
    test('should handle user with all questions answered');
    test('should handle concurrent quiz generation');
  });
});
```

**Estimated**: 5-6 hours

---

#### 1.3 Transaction Tests (CRITICAL BUG FIX) - 3-4 hours

**File**: `backend/tests/integration/api/quizCompletion.test.js` (NEW)

**Why Critical**:
- We found critical bug: theta updates outside transaction
- MUST verify fix works correctly

**Tests to Add**:
```javascript
// tests/integration/api/quizCompletion.test.js

describe('Quiz Completion Transaction', () => {
  describe('atomic updates', () => {
    test('quiz should NOT be marked complete if theta update fails');
    test('all theta updates should succeed or transaction rolls back');
    test('concurrent completions should not cause race conditions');
  });

  describe('rollback scenarios', () => {
    test('network error during theta calc should rollback quiz status');
    test('Firestore error should rollback entire transaction');
  });

  describe('data consistency', () => {
    test('completed_quiz_count should match theta update count');
    test('quiz status and user stats should be in sync');
  });
});
```

**Estimated**: 3-4 hours (requires Firebase Emulator setup)

---

#### 1.4 progressService.js (COST OPTIMIZATION) - 2-3 hours

**File**: `backend/tests/unit/services/progressService.test.js` (NEW)

**Why Critical**:
- We found critical issue: 500 reads per request
- Must verify optimization works

**Tests to Add**:
```javascript
// tests/unit/services/progressService.test.js

describe('Progress Service', () => {
  describe('getCumulativeStats (BEFORE optimization)', () => {
    test('should query responses collection (500 reads)');
    test('should calculate accuracy from responses');
  });

  describe('getCumulativeStats (AFTER optimization)', () => {
    test('should read stats from user document (1 read)');
    test('should return same accuracy as before');
    test('should handle missing fields gracefully');
  });

  describe('stats incremental update', () => {
    test('should increment total_questions_solved correctly');
    test('should increment total_correct correctly');
    test('should recalculate overall_accuracy correctly');
  });

  describe('migration validation', () => {
    test('backfilled stats should match calculated stats');
    test('old and new methods should produce identical results');
  });
});
```

**Estimated**: 2-3 hours

---

### Mobile: Critical Provider Tests

#### 1.5 DailyQuizProvider Tests (MEMORY LEAK FIX) - 2-3 hours

**File**: `mobile/test/unit/providers/daily_quiz_provider_test.dart` (NEW)

**Why Critical**:
- We found critical bug: missing dispose() method
- Must verify fix doesn't break functionality

**Tests to Add**:
```dart
// test/unit/providers/daily_quiz_provider_test.dart

void main() {
  group('DailyQuizProvider', () {
    late DailyQuizProvider provider;
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
      provider = DailyQuizProvider(mockAuthService);
    });

    tearDown(() {
      provider.dispose(); // ✓ Verify no errors on dispose
    });

    test('should initialize without errors', () {
      expect(provider, isNotNull);
    });

    test('dispose should clean up resources', () {
      // Verify _storageService is disposed
      // Verify listeners are removed
      expect(() => provider.dispose(), returnsNormally);
    });

    test('should not allow operations after dispose', () {
      provider.dispose();
      // Attempt operations after dispose should fail gracefully
    });

    group('quiz generation', () {
      test('should fetch active quiz if exists');
      test('should generate new quiz if none active');
      test('should handle API errors gracefully');
    });

    group('quiz submission', () {
      test('should submit quiz successfully');
      test('should update local state after submission');
      test('should handle submission errors');
    });

    group('state management', () {
      test('should notify listeners on state change');
      test('should handle concurrent state updates');
    });
  });
}
```

**Estimated**: 2-3 hours

---

## 🚀 Priority 2: Expand Coverage (Week 2) - 20-24 hours

### Backend: Service Layer Coverage

#### 2.1 openai.js Service Tests - 4-5 hours

**File**: `backend/tests/unit/services/openai.test.js` (NEW)

**Why Important**:
- OpenAI API is expensive ($276/month)
- LaTeX validation is complex
- Hindi language detection critical

**Tests to Add**:
```javascript
describe('OpenAI Service', () => {
  describe('solveQuestionFromImage', () => {
    test('should extract question from image (mocked)');
    test('should detect subject correctly (Math/Physics/Chemistry)');
    test('should detect difficulty correctly');
    test('should detect language (en/hi)');
    test('should generate solution in same language as question');
  });

  describe('LaTeX validation', () => {
    test('should normalize LaTeX delimiters to \\(...\\)');
    test('should validate balanced delimiters');
    test('should strip LaTeX for Hindi fallback');
    test('should handle malformed LaTeX gracefully');
  });

  describe('follow-up questions', () => {
    test('should generate 3 follow-up questions');
    test('should increase difficulty progressively (Q1 < Q2 < Q3)');
    test('should maintain same topic');
    test('should handle API errors gracefully');
  });

  describe('cost optimization', () => {
    test('system prompt should be under 1200 chars (optimization)');
    test('should use gpt-4o for vision, gpt-4o-mini for follow-ups');
  });
});
```

**Mock Strategy**: Use nock or similar to mock OpenAI API responses

**Estimated**: 4-5 hours

---

#### 2.2 snapHistoryService.js Tests - 2-3 hours

**File**: `backend/tests/unit/services/snapHistoryService.test.js` (NEW)

**Tests to Add**:
```javascript
describe('Snap History Service', () => {
  describe('daily usage limits', () => {
    test('should return correct usage count');
    test('should enforce 5 snaps/day limit');
    test('should reset limit at midnight');
  });

  describe('saveSnapRecord', () => {
    test('should save snap with all fields');
    test('should increment daily count');
    test('should store image URL correctly');
  });

  describe('history retrieval', () => {
    test('should return snaps in reverse chronological order');
    test('should paginate results');
    test('should filter by date range');
  });
});
```

**Estimated**: 2-3 hours

---

#### 2.3 assessmentService.js Tests - 3-4 hours

**File**: `backend/tests/unit/services/assessmentService.test.js` (NEW)

**Tests to Add**:
```javascript
describe('Assessment Service', () => {
  describe('getRandomizedAssessmentQuestions', () => {
    test('should select 50 questions (10 Physics, 20 Chemistry, 20 Math)');
    test('should distribute difficulty evenly');
    test('should randomize question order');
    test('should not repeat questions');
  });

  describe('theta baseline calculation', () => {
    test('should calculate initial theta by chapter');
    test('should store baseline for future comparison');
    test('should handle incomplete assessments');
  });

  describe('assessment validation', () => {
    test('should validate all 50 questions answered');
    test('should reject invalid answers');
    test('should calculate score correctly');
  });
});
```

**Estimated**: 3-4 hours

---

### Backend: Route/Controller Tests

#### 2.4 solve.js API Tests - 3-4 hours

**File**: `backend/tests/integration/api/solve.test.js` (NEW)

**Tests to Add**:
```javascript
describe('Snap & Solve API', () => {
  describe('POST /api/solve', () => {
    test('should upload image and return solution (200)');
    test('should reject request without auth token (401)');
    test('should reject non-image files (400)');
    test('should reject files >5MB (400)');
    test('should enforce daily limit (429)');
    test('should handle OpenAI API errors (500/502)');
    test('should timeout after 2 minutes (504)');
  });

  describe('POST /api/generate-practice-questions', () => {
    test('should generate 3 follow-up questions (200)');
    test('should validate request body (400)');
    test('should handle OpenAI errors gracefully (500)');
  });

  describe('image validation', () => {
    test('should validate magic numbers (file signature)');
    test('should reject spoofed MIME types');
  });
});
```

**Estimated**: 3-4 hours

---

#### 2.5 users.js API Tests - 2-3 hours

**File**: `backend/tests/integration/api/users.test.js` (NEW)

**Tests to Add**:
```javascript
describe('Users API', () => {
  describe('GET /api/users/profile', () => {
    test('should return user profile (200)');
    test('should require authentication (401)');
  });

  describe('POST /api/users/profile', () => {
    test('should update profile successfully (200)');
    test('should validate input fields (400)');
    test('should sanitize input (XSS protection)');
  });

  describe('POST /api/users/onboarding', () => {
    test('should save onboarding data (200)');
    test('should mark user as onboarded');
  });
});
```

**Estimated**: 2-3 hours

---

### Mobile: Widget & Integration Tests

#### 2.6 Complete Placeholder Tests - 4-5 hours

**Files**: Multiple files with `expect(true, true)` placeholders

**Current Issue**: Many mobile tests have placeholder implementations

**Action**: Implement all placeholder tests properly

**Example** (api_service_test.dart):
```dart
// BEFORE (placeholder)
test('handles success response', () async {
  expect(true, true); // Placeholder
});

// AFTER (real test)
test('handles success response', () async {
  final client = MockClient((request) async {
    return http.Response(jsonEncode({
      'success': true,
      'data': TestData.solutionResponse
    }), 200);
  });

  final apiService = ApiService(client: client);
  final result = await apiService.solveQuestion(File('test.jpg'));

  expect(result.success, true);
  expect(result.data, isNotNull);
});
```

**Files to Fix**:
- api_service_test.dart (20 placeholder tests)
- Other service tests with placeholders

**Estimated**: 4-5 hours

---

#### 2.7 Daily Quiz Flow Integration Test - 3-4 hours

**File**: `mobile/test/integration/daily_quiz_flow_test.dart` (NEW)

**Tests to Add**:
```dart
void main() {
  group('Daily Quiz Flow', () {
    testWidgets('complete quiz flow', (tester) async {
      // 1. Open app
      // 2. Navigate to daily quiz
      // 3. Generate quiz
      // 4. Answer all 10 questions
      // 5. Submit quiz
      // 6. View results
      // 7. Verify theta updated
    });

    testWidgets('resume incomplete quiz', (tester) async {
      // 1. Start quiz
      // 2. Answer 5 questions
      // 3. Close app
      // 4. Reopen app
      // 5. Verify quiz restored
      // 6. Complete remaining questions
    });

    testWidgets('handle timer expiration', (tester) async {
      // 1. Start quiz
      // 2. Wait for timer to expire
      // 3. Verify auto-submission
    });
  });
}
```

**Estimated**: 3-4 hours

---

## 🎨 Priority 3: UI/Widget Testing (Week 3) - 12-16 hours

### Golden Tests for UI Regression

#### 3.1 Golden Tests Setup - 2-3 hours

**Purpose**: Catch UI regressions automatically

**Setup**:
```dart
// test/golden/golden_test.dart

void main() {
  testWidgets('home screen golden test', (tester) async {
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('golden/home_screen.png'),
    );
  });

  testWidgets('daily quiz question golden test', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DailyQuizQuestionScreen(/*...*/),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DailyQuizQuestionScreen),
      matchesGoldenFile('golden/daily_quiz_question.png'),
    );
  });
}
```

**Screens to Test**:
- HomeScreen
- DailyQuizQuestionScreen
- DailyQuizResultScreen
- SolutionScreen
- AssessmentQuestionScreen
- ProfileScreen

**Estimated**: 2-3 hours (setup + 6 screens)

---

#### 3.2 Theme Consistency Tests - 2-3 hours

**Purpose**: Validate design system usage (catch hardcoded colors)

**File**: `mobile/test/widget/theme_consistency_test.dart` (NEW)

**Tests**:
```dart
void main() {
  group('Theme Consistency', () {
    test('no hardcoded colors in screens', () {
      // Use regex to find Color(0xFF...) in screen files
      final screenFiles = Directory('lib/screens').listSync();
      final hardcodedColors = <String>[];

      for (final file in screenFiles) {
        final content = File(file.path).readAsStringSync();
        final matches = RegExp(r'Color\(0x[A-F0-9]{8}\)').allMatches(content);
        if (matches.isNotEmpty) {
          hardcodedColors.add(file.path);
        }
      }

      expect(hardcodedColors, isEmpty,
          reason: 'Found hardcoded colors in: ${hardcodedColors.join(', ')}');
    });

    test('all screens use JVColors or AppColors', () {
      // Verify all color references use design system
    });

    test('spacing follows 8px grid', () {
      // Verify padding/margin values are multiples of 4 or 8
    });
  });
}
```

**Estimated**: 2-3 hours

---

#### 3.3 Accessibility Tests - 2-3 hours

**Purpose**: Ensure app is accessible (semantic labels, contrast, etc.)

**File**: `mobile/test/widget/accessibility_test.dart` (NEW)

**Tests**:
```dart
void main() {
  group('Accessibility', () {
    testWidgets('all buttons have semantic labels', (tester) async {
      await tester.pumpWidget(MyApp());

      final buttons = find.byType(ElevatedButton);
      final count = buttons.evaluate().length;

      for (int i = 0; i < count; i++) {
        final semantics = tester.getSemantics(buttons.at(i));
        expect(semantics.label, isNotNull,
            reason: 'Button at index $i missing semantic label');
      }
    });

    testWidgets('images have alt text', (tester) async {
      await tester.pumpWidget(MyApp());

      final images = find.byType(Image);
      // Verify all images have Semantics wrapper
    });

    testWidgets('text contrast meets WCAG AA', (tester) async {
      // Verify text colors have sufficient contrast ratio
    });

    testWidgets('tap targets are at least 48x48', (tester) async {
      // Verify all interactive elements meet minimum size
    });
  });
}
```

**Estimated**: 2-3 hours

---

#### 3.4 Performance Tests - 3-4 hours

**Purpose**: Catch performance regressions

**File**: `mobile/test/performance/performance_test.dart` (NEW)

**Tests**:
```dart
void main() {
  group('Performance', () {
    testWidgets('home screen builds in <16ms (60fps)', (tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(16),
          reason: 'Home screen should build in <16ms for 60fps');
    });

    testWidgets('daily quiz list scrolls smoothly', (tester) async {
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // Measure jank during scroll
      await tester.fling(find.byType(ListView), Offset(0, -500), 1000);
      await tester.pumpAndSettle();

      // Verify no dropped frames
    });

    test('provider notifyListeners count is reasonable', () {
      final provider = DailyQuizProvider(MockAuthService());
      int notifyCount = 0;

      provider.addListener(() {
        notifyCount++;
      });

      // Perform typical operations
      provider.loadQuiz();

      // Verify listeners not called excessively
      expect(notifyCount, lessThan(10),
          reason: 'Provider should not spam listeners');
    });
  });
}
```

**Estimated**: 3-4 hours

---

#### 3.5 Error State Tests - 2-3 hours

**Purpose**: Verify error handling UI

**File**: `mobile/test/widget/error_states_test.dart` (NEW)

**Tests**:
```dart
void main() {
  group('Error States', () {
    testWidgets('displays error when API fails', (tester) async {
      final provider = DailyQuizProvider(MockAuthService());

      // Mock API failure
      when(mockApiService.generateQuiz()).thenThrow(Exception('Network error'));

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: DailyQuizHomeScreen(),
        ),
      );

      await tester.pump();

      expect(find.text('Network error'), findsOneWidget);
      expect(find.byType(ErrorWidget), findsOneWidget);
    });

    testWidgets('retry button appears on error', (tester) async {
      // Verify retry mechanism works
    });

    testWidgets('offline mode shows appropriate message', (tester) async {
      // Test offline handling
    });
  });
}
```

**Estimated**: 2-3 hours

---

## 🌐 Priority 4: E2E Tests (Week 4) - 16-20 hours

### Critical User Journeys

#### 4.1 E2E Test Infrastructure Setup - 4-5 hours

**Tools**:
- Backend: Firebase Emulator Suite
- Mobile: Flutter integration_test package
- Optional: Appium/Detox for real device testing

**Setup Firebase Emulator**:
```bash
# backend/firebase.json
{
  "emulators": {
    "auth": {
      "port": 9099
    },
    "firestore": {
      "port": 8080
    },
    "storage": {
      "port": 9199
    }
  }
}
```

**Start emulator**:
```bash
cd backend
firebase emulators:start
```

**Configure tests to use emulator**:
```dart
// mobile/integration_test/e2e_test.dart
void main() {
  setUpAll(() async {
    // Connect to Firebase Emulator
    await Firebase.initializeApp();
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  });
}
```

**Estimated**: 4-5 hours

---

#### 4.2 Onboarding → Assessment E2E - 3-4 hours

**File**: `mobile/integration_test/onboarding_assessment_e2e_test.dart` (NEW)

**Test**:
```dart
void main() {
  testWidgets('new user completes onboarding and assessment', (tester) async {
    // 1. Launch app (first time)
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    // 2. Enter phone number
    await tester.enterText(find.byType(TextField), '+919876543210');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    // 3. Enter OTP
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    // 4. Create PIN
    await tester.enterText(find.byType(TextField).first, '1234');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 5. Complete profile (name, class, target exam)
    await tester.enterText(find.byKey(Key('name_field')), 'Test Student');
    await tester.tap(find.text('Class 12'));
    await tester.tap(find.text('JEE Main'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // 6. Start assessment
    await tester.tap(find.text('Start Assessment'));
    await tester.pumpAndSettle();

    // 7. Answer 50 questions
    for (int i = 0; i < 50; i++) {
      // Select option A for all questions (for test speed)
      await tester.tap(find.text('A'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    // 8. Verify assessment results screen
    expect(find.text('Assessment Complete'), findsOneWidget);
    expect(find.byType(ProgressChart), findsOneWidget);

    // 9. Verify theta calculated and stored
    // (check Firestore via emulator)
  });
}
```

**Estimated**: 3-4 hours

---

#### 4.3 Daily Quiz Journey E2E - 3-4 hours

**File**: `mobile/integration_test/daily_quiz_e2e_test.dart` (NEW)

**Test**:
```dart
void main() {
  testWidgets('user completes daily quiz successfully', (tester) async {
    // Setup: User already onboarded and assessed

    // 1. Launch app
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    // 2. Navigate to Daily Quiz
    await tester.tap(find.text('Daily Quiz'));
    await tester.pumpAndSettle();

    // 3. Verify quiz generation
    expect(find.text('Generating your quiz...'), findsOneWidget);
    await tester.pumpAndSettle(Duration(seconds: 5));

    // 4. Verify 10 questions loaded
    expect(find.text('Question 1 of 10'), findsOneWidget);

    // 5. Answer all 10 questions
    for (int i = 0; i < 10; i++) {
      // Answer each question
      await tester.tap(find.byType(RadioButton).first);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      if (i < 9) {
        await tester.tap(find.text('Next Question'));
        await tester.pumpAndSettle();
      }
    }

    // 6. Verify results screen
    expect(find.text('Quiz Complete'), findsOneWidget);
    expect(find.byType(ScoreDisplay), findsOneWidget);

    // 7. Verify theta updated in Firestore
    final user = FirebaseAuth.instance.currentUser!;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    expect(userDoc.data()!['completed_quiz_count'], greaterThan(0));
  });

  testWidgets('timer expires and auto-submits', (tester) async {
    // Test timer expiration scenario
  });
}
```

**Estimated**: 3-4 hours

---

#### 4.4 Snap & Solve Journey E2E - 4-5 hours

**File**: `mobile/integration_test/snap_solve_e2e_test.dart` (NEW)

**Challenge**: Requires mocking OpenAI API or using real API (expensive)

**Test**:
```dart
void main() {
  testWidgets('user snaps question and gets solution', (tester) async {
    // Setup: Mock OpenAI API response

    // 1. Launch app
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    // 2. Navigate to Snap & Solve
    await tester.tap(find.text('Snap & Solve'));
    await tester.pumpAndSettle();

    // 3. Tap camera button
    await tester.tap(find.byIcon(Icons.camera));
    await tester.pumpAndSettle();

    // 4. Capture image (mocked)
    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pumpAndSettle();

    // 5. Review and upload
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    // 6. Verify processing screen
    expect(find.text('Analyzing your question...'), findsOneWidget);
    await tester.pumpAndSettle(Duration(seconds: 5));

    // 7. Verify solution displayed
    expect(find.text('Solution'), findsOneWidget);
    expect(find.byType(LatexWidget), findsWidgets);

    // 8. Verify practice questions generated
    await tester.tap(find.text('Practice Questions'));
    await tester.pumpAndSettle();

    expect(find.text('Question 1'), findsOneWidget);

    // 9. Verify daily limit decremented
    final usage = await getDailyUsage(userId);
    expect(usage.used, equals(1));
    expect(usage.remaining, equals(4));
  });
}
```

**Estimated**: 4-5 hours

---

#### 4.5 Error Recovery E2E - 2-3 hours

**File**: `mobile/integration_test/error_recovery_e2e_test.dart` (NEW)

**Tests**:
```dart
void main() {
  testWidgets('app recovers from network errors gracefully', (tester) async {
    // 1. Start quiz
    // 2. Simulate network disconnect
    // 3. Attempt to submit
    // 4. Verify error message
    // 5. Reconnect network
    // 6. Retry submission
    // 7. Verify success
  });

  testWidgets('app handles API rate limiting', (tester) async {
    // Test 429 response handling
  });

  testWidgets('app handles session expiration', (tester) async {
    // Test token refresh flow
  });
}
```

**Estimated**: 2-3 hours

---

## 📊 Test Coverage Monitoring

### Setup Coverage Reporting

#### Backend Coverage

**Jest Configuration** (already setup):
```bash
# Run tests with coverage
npm run test:coverage

# View coverage report
open coverage/lcov-report/index.html
```

**CI/CD Integration**:
```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install dependencies
        run: cd backend && npm install
      - name: Run tests with coverage
        run: cd backend && npm run test:coverage
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./backend/coverage/lcov.info
          flags: backend
      - name: Fail if coverage below 70%
        run: |
          cd backend
          npm run test:coverage -- --coverageThreshold='{"global":{"lines":70}}'
```

---

#### Mobile Coverage

**Flutter Test Coverage**:
```bash
# Run tests with coverage
flutter test --coverage

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# View report
open coverage/html/index.html
```

**CI/CD Integration**:
```yaml
mobile-tests:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v2
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.24.0'
    - name: Install dependencies
      run: cd mobile && flutter pub get
    - name: Run tests with coverage
      run: cd mobile && flutter test --coverage
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        files: ./mobile/coverage/lcov.info
        flags: mobile
```

---

## 🎯 Testing Best Practices

### General Principles

1. **AAA Pattern**: Arrange, Act, Assert
```javascript
test('should calculate theta correctly', () => {
  // Arrange
  const responses = [true, true, false, true];
  const questions = [
    { difficulty_b: 0.5, discrimination_a: 1.2 },
    // ...
  ];

  // Act
  const theta = calculateTheta(responses, questions);

  // Assert
  expect(theta).toBeCloseTo(0.8, 1);
});
```

2. **Test Isolation**: Each test should be independent
```javascript
beforeEach(() => {
  // Reset state before each test
  jest.clearAllMocks();
});

afterEach(() => {
  // Clean up after each test
});
```

3. **Meaningful Test Names**:
```javascript
// BAD
test('test1', () => { /* ... */ });

// GOOD
test('should return 50th percentile for theta 0', () => { /* ... */ });
```

4. **Test Edge Cases**:
- Empty inputs
- Null/undefined
- Extreme values
- Boundary conditions

5. **Mock External Dependencies**:
- Firebase (use emulator or mocks)
- OpenAI API (mock responses)
- File system
- Network calls

---

### Code Coverage Goals

**NOT** aiming for 100% coverage (diminishing returns):

| Component | Target | Rationale |
|-----------|--------|-----------|
| Critical services | 90-95% | High-risk business logic |
| Business logic | 80-85% | Core features |
| Controllers/Routes | 70-75% | Integration tests cover most |
| Utilities | 85-90% | Reused across app |
| UI Components | 60-70% | Golden tests catch regressions |

**Focus on**:
- Code that handles money/costs (OpenAI API, Firestore reads)
- Code with complex math (IRT calculations)
- Code with security implications (auth, sanitization)
- Code that changes frequently

---

## 📅 Implementation Timeline

### Week 1: Critical Gaps (P0)
**Total**: 16-20 hours

- [ ] Day 1-2: thetaCalculationService tests (4-5h)
- [ ] Day 2-3: dailyQuizService tests (5-6h)
- [ ] Day 3: Transaction tests (3-4h)
- [ ] Day 4: progressService tests (2-3h)
- [ ] Day 5: DailyQuizProvider tests (2-3h)

**Deliverable**: Critical business logic fully tested

---

### Week 2: Expand Coverage (P1)
**Total**: 20-24 hours

- [ ] Day 1-2: OpenAI service tests (4-5h)
- [ ] Day 2: Snap history tests (2-3h)
- [ ] Day 3: Assessment service tests (3-4h)
- [ ] Day 3-4: Solve API tests (3-4h)
- [ ] Day 4: Users API tests (2-3h)
- [ ] Day 5: Complete placeholder tests (4-5h)
- [ ] Day 5: Daily quiz flow integration (3-4h)

**Deliverable**: 70%+ backend coverage, 60%+ mobile coverage

---

### Week 3: UI Testing (P2)
**Total**: 12-16 hours

- [ ] Day 1: Golden tests setup (2-3h)
- [ ] Day 2: Theme consistency tests (2-3h)
- [ ] Day 3: Accessibility tests (2-3h)
- [ ] Day 4: Performance tests (3-4h)
- [ ] Day 5: Error state tests (2-3h)

**Deliverable**: UI regression prevention, design system enforcement

---

### Week 4: E2E Tests (P3)
**Total**: 16-20 hours

- [ ] Day 1: E2E infrastructure setup (4-5h)
- [ ] Day 2: Onboarding/assessment E2E (3-4h)
- [ ] Day 3: Daily quiz E2E (3-4h)
- [ ] Day 4: Snap & Solve E2E (4-5h)
- [ ] Day 5: Error recovery E2E (2-3h)

**Deliverable**: Critical user journeys validated

---

## 💰 ROI: Why Testing Matters

### Cost of Bugs in Production

**Scenario**: Theta transaction bug goes unfixed

- **Impact**: Quiz marked complete but theta not updated
- **User impact**: 1,000 users get wrong difficulty questions
- **User churn**: 20% leave due to poor experience = 200 users lost
- **Revenue loss**: 200 users × $5/month × 12 months = **$12,000/year**
- **Reputation damage**: 1-star reviews, word-of-mouth

**Cost to fix**:
- Pre-launch (with tests): 6-8 hours
- Post-launch (in production): 40-60 hours (hotfix + rollback + user support + data migration)

**Testing ROI**: 5-7x effort savings + zero user impact

---

### Cost of Progress API Bug

**Current**: $90/month for 100 users (500 reads per request)

**At Scale**:
- 1,000 users = $900/month = $10,800/year
- 10,000 users = $9,000/month = $108,000/year

**Tests prevent**: Regressions after optimization (ensure 1 read, not 500)

**ROI**: $100,000+/year at scale

---

## ✅ Success Criteria

### Definition of Done

**Week 1 Complete**:
- [ ] All critical services tested (theta, dailyQuiz, progress)
- [ ] Transaction bug fix verified with tests
- [ ] Coverage reports generated
- [ ] No failing tests

**Week 2 Complete**:
- [ ] Backend coverage ≥70%
- [ ] Mobile unit test coverage ≥60%
- [ ] All placeholders replaced with real tests
- [ ] CI/CD pipeline running tests automatically

**Week 3 Complete**:
- [ ] Golden tests capturing 10+ screens
- [ ] Theme consistency validated
- [ ] Accessibility standards met (WCAG AA)
- [ ] Performance benchmarks established

**Week 4 Complete**:
- [ ] E2E tests covering 3+ critical journeys
- [ ] Firebase Emulator integrated
- [ ] Error recovery scenarios tested
- [ ] All tests passing in CI/CD

---

## 📚 Resources & Tools

### Backend Testing

- **Jest**: https://jestjs.io/
- **Supertest**: https://github.com/ladjs/supertest
- **Firebase Emulator**: https://firebase.google.com/docs/emulator-suite
- **Nock** (HTTP mocking): https://github.com/nock/nock

### Mobile Testing

- **Flutter Testing Guide**: https://docs.flutter.dev/testing
- **Integration Test Package**: https://pub.dev/packages/integration_test
- **Golden Toolkit**: https://pub.dev/packages/golden_toolkit
- **Mockito**: https://pub.dev/packages/mockito

### Coverage Tools

- **Codecov**: https://codecov.io/
- **Coveralls**: https://coveralls.io/
- **Istanbul** (JS coverage): https://istanbul.js.org/

### CI/CD

- **GitHub Actions**: https://docs.github.com/en/actions
- **CircleCI**: https://circleci.com/
- **GitLab CI**: https://docs.gitlab.com/ee/ci/

---

## 🎬 Next Steps

1. **Read this plan** and prioritize based on your timeline
2. **Start with Week 1** (critical tests) - immediate ROI
3. **Setup CI/CD** early to catch regressions
4. **Track coverage** - aim for steady improvement
5. **Make testing a habit** - write tests for all new features

**Recommended Start**: Fix the 3 critical bugs (P0 issues) from the main assessment, then immediately add tests to prevent regressions.

---

**Document Created**: December 31, 2025
**Status**: Comprehensive Testing Strategy
**Estimated Total Effort**: 64-80 hours (4-5 weeks part-time, 2 weeks full-time)
**Expected Coverage After**: Backend 75%+ | Mobile 65%+ | E2E: Critical Paths

Good luck! 🚀 Testing is an investment that pays dividends in reliability, confidence, and cost savings.
