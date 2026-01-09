# JEEVibe Pre-Launch - Action Items Checklist

**Last Updated**: December 31, 2025

Use this checklist to track fixes before launch. Check off items as you complete them.

---

## 🚨 P0: MUST FIX (Launch Blockers) - 16-19 hours

These **MUST** be completed before launch. Estimated total: **2-3 days**.

### [ ] 1. Fix Theta Updates Transaction (6-8 hours) 🔴

**Priority**: P0 - CRITICAL
**File**: `backend/src/routes/dailyQuiz.js` (lines 403-488)
**Issue**: Theta updates happen outside transaction → can fail silently

**Current Code**:
```javascript
// Transaction completes
await db.runTransaction(async (transaction) => {
  transaction.update(quizRef, { status: 'completed' });
});

// Theta updates AFTER transaction (can fail)
await updateChapterTheta(userId, chapterKey, responses);
```

**Fix**:
Move theta calculations inside the transaction. Calculate new theta values inline and update `theta_by_chapter` field atomically.

**Test Plan**:
1. Complete a quiz with network disabled after transaction
2. Verify quiz is NOT marked complete if theta update fails
3. Verify theta values update correctly
4. Test with 10 concurrent quiz completions

**Acceptance Criteria**:
- [ ] Theta updates happen inside transaction
- [ ] Quiz only marked complete if ALL updates succeed
- [ ] No race conditions under concurrent load
- [ ] Existing quizzes still work (backward compatible)

---

### [ ] 2. Fix Progress API Efficiency (6-8 hours) 🔴

**Priority**: P0 - CRITICAL (Cost Blocker)
**File**: `backend/src/services/progressService.js` (lines 238-297)
**Issue**: Reads 500+ documents per request = $90/month for 100 users

**Current Cost**:
```
100 users × 10 app opens/day × 500 reads = $90/month
1,000 users = $900/month (unsustainable)
```

**Fix**:
Denormalize cumulative stats to user document. Update incrementally on quiz completion.

**Changes Required**:
1. Add fields to user document:
   ```javascript
   {
     total_questions_solved: 0,
     total_correct: 0,
     overall_accuracy: 0.0,
     last_stats_update: timestamp
   }
   ```

2. Update these fields incrementally in quiz completion transaction:
   ```javascript
   transaction.update(userRef, {
     total_questions_solved: FieldValue.increment(10),
     total_correct: FieldValue.increment(correctCount),
     overall_accuracy: (userData.total_correct + correctCount) / (userData.total_questions_solved + 10)
   });
   ```

3. Update `getCumulativeStats()` to read from user document (1 read instead of 500)

**Migration Plan**:
1. Deploy new schema fields (default to 0)
2. Run one-time migration script to backfill stats for existing users
3. Update API to use new fields
4. Monitor Firestore costs for 24 hours
5. Remove old code after verification

**Test Plan**:
1. Complete 10 quizzes, verify stats increment correctly
2. Check accuracy calculation precision
3. Verify progress screen loads <200ms
4. Load test: 100 concurrent /progress requests

**Acceptance Criteria**:
- [ ] Progress API reads ≤5 documents (down from 500+)
- [ ] Stats accuracy matches old calculation (±0.1%)
- [ ] Firestore costs reduced by 99%
- [ ] Migration script tested on staging

**Expected Savings**: $90/month → $0.18/month = **$89.82/month saved**

---

### [ ] 3. Add Error Tracking (2-3 hours) 🔴

**Priority**: P0 - CRITICAL (Operations Blocker)
**Issue**: No production error monitoring (flying blind)

**Add Sentry for Backend**:

1. Install Sentry:
   ```bash
   cd backend
   npm install @sentry/node @sentry/profiling-node
   ```

2. Initialize in `backend/src/server.js`:
   ```javascript
   const Sentry = require("@sentry/node");

   Sentry.init({
     dsn: process.env.SENTRY_DSN,
     environment: process.env.NODE_ENV || 'development',
     tracesSampleRate: 1.0, // 100% during beta, reduce to 0.1 at scale
   });

   // Error handler middleware (AFTER all routes)
   app.use(Sentry.Handlers.errorHandler());
   ```

3. Add to error handlers:
   ```javascript
   catch (error) {
     Sentry.captureException(error);
     logger.error('Error occurred', { error });
   }
   ```

**Add Firebase Crashlytics for Mobile**:

1. Add to `mobile/pubspec.yaml`:
   ```yaml
   dependencies:
     firebase_crashlytics: ^3.4.0
   ```

2. Initialize in `mobile/lib/main.dart`:
   ```dart
   await Firebase.initializeApp();
   FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
   ```

3. Test crash reporting:
   ```dart
   FirebaseCrashlytics.instance.crash(); // Should appear in Firebase Console
   ```

**Test Plan**:
1. Trigger test error in backend (throw new Error('Test Sentry'))
2. Verify error appears in Sentry dashboard within 60s
3. Trigger Flutter error (throw Exception('Test Crashlytics'))
4. Verify crash appears in Firebase Console within 60s
5. Test breadcrumbs show user actions before crash

**Acceptance Criteria**:
- [ ] Sentry configured for backend (staging + production)
- [ ] Firebase Crashlytics configured for mobile
- [ ] Test errors appear in dashboards
- [ ] Source maps uploaded for stack traces
- [ ] Alert rules configured (>10 errors/min → email)

**Cost**: Free tier sufficient for <10K users

---

### [ ] 4. Add Provider Disposal (1-2 hours) 🔴

**Priority**: P0 - MUST FIX (Memory Leak)
**File**: `mobile/lib/providers/daily_quiz_provider.dart`
**Issue**: No dispose() method → memory leak

**Fix**:
```dart
class DailyQuizProvider extends ChangeNotifier {
  final AuthService _authService;
  final QuizStorageService _storageService = QuizStorageService();

  // ... existing code

  @override
  void dispose() {
    // Dispose storage service if it has disposable resources
    _storageService.dispose();

    // Remove any listeners
    // Example: _authService.removeListener(...)

    super.dispose();
  }
}
```

**Test Plan**:
1. Open quiz screen 20 times (navigate back and forth)
2. Use Flutter DevTools → Memory tab
3. Verify no memory growth after stabilization
4. Run `flutter analyze` to check for warnings

**Acceptance Criteria**:
- [ ] dispose() method implemented
- [ ] QuizStorageService resources cleaned up
- [ ] No memory leaks in DevTools profiler
- [ ] No analyzer warnings

---

## ⚠️ P1: SHOULD FIX (Quality Issues) - 12-17 hours

Recommended before launch for quality and UX. Can technically launch without these, but not recommended.

### [ ] 5. Increase Difficulty Threshold (1-2 hours)

**File**: `backend/src/services/questionSelectionService.js` (line 149)
**Issue**: Threshold of 0.5 SD too restrictive for high performers

**Change**:
```javascript
// Before
const DIFFICULTY_MATCH_THRESHOLD = 0.5;

// After (Option 1: Simple)
const DIFFICULTY_MATCH_THRESHOLD = 1.0;

// After (Option 2: Adaptive - RECOMMENDED)
function getDifficultyThreshold(availableCount) {
  if (availableCount < 10) return 1.5; // Relaxed when few questions
  if (availableCount < 30) return 1.0; // Moderate
  return 0.5; // Strict when many questions
}
```

**Test Plan**:
1. Test with theta = 2.5 (top 0.62%)
2. Verify ≥10 questions selected
3. Test with theta = -2.5 (bottom 0.62%)
4. Verify ≥10 questions selected

**Acceptance Criteria**:
- [ ] Users with extreme theta get sufficient questions
- [ ] Fallback still triggers if <10 questions available

---

### [ ] 6. Consolidate Theme Systems (4-6 hours)

**Files**:
- `mobile/lib/theme/app_colors.dart` (AppColors)
- `mobile/lib/theme/jeevibe_theme.dart` (JVColors)

**Issue**: Two competing color systems (duplicate definitions)

**Fix**:
1. Choose one system (recommend `JVColors` - more concise)
2. Deprecate the other with `@Deprecated()` annotation
3. Find-replace all `AppColors.` → `JVColors.` in codebase
4. Delete deprecated file after migration

**Migration Script**:
```bash
# Find all usages
grep -r "AppColors\." mobile/lib/

# Replace with JVColors
find mobile/lib -name "*.dart" -exec sed -i '' 's/AppColors\./JVColors\./g' {} +

# Verify
flutter analyze
```

**Acceptance Criteria**:
- [ ] Only one color system remains
- [ ] All screens use unified system
- [ ] No compilation errors
- [ ] App visual appearance unchanged

---

### [ ] 7. Fix Hardcoded Colors (3-4 hours)

**Files**: 22 screen files with `Color(0xFF...)`

**Issue**: Hardcoded colors instead of design system

**Migration**:
```dart
// Before
Container(color: Color(0xFF9333EA))

// After
Container(color: JVColors.primary)
```

**Automated Fix**:
1. Create mapping of common hex codes to theme colors:
   ```
   0xFF9333EA → JVColors.primary
   0xFFFAF5FF → JVColors.background
   0xFFFFFFFF → JVColors.surface
   ```

2. Run find-replace across affected files

**Acceptance Criteria**:
- [ ] Zero `Color(0xFF...)` in screen files (check with grep)
- [ ] All colors come from `JVColors.*`
- [ ] Visual regression test passes

---

### [ ] 8. Create Firestore Indexes (2-3 hours)

**File to create**: `backend/firestore.indexes.json`

**Required Indexes**:
```json
{
  "indexes": [
    {
      "collectionGroup": "quizzes",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "completed_at", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "quizzes",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "quiz_number", "order": "DESCENDING" }
      ]
    },
    {
      "collection": "questions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "chapter", "order": "ASCENDING" },
        { "fieldPath": "is_active", "order": "ASCENDING" },
        { "fieldPath": "difficulty_b", "order": "ASCENDING" }
      ]
    }
  ]
}
```

**Deploy**:
```bash
firebase deploy --only firestore:indexes
```

**Verify**:
Check Firebase Console → Firestore → Indexes tab

**Acceptance Criteria**:
- [ ] All indexes created successfully
- [ ] Indexes status = "Enabled" (not "Building")
- [ ] No slow queries in production logs

---

### [ ] 9. Add Input Validation (2 hours)

**Files**: `backend/src/routes/dailyQuiz.js`, `backend/src/routes/assessment.js`

**Add express-validator**:
```javascript
const { body, validationResult } = require('express-validator');

router.post('/start',
  authenticateUser,
  [
    body('quiz_id')
      .isString()
      .trim()
      .isLength({ min: 1, max: 100 })
      .matches(/^[a-zA-Z0-9_-]+$/)
  ],
  async (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    // ... proceed
  }
);
```

**Endpoints to validate**:
- [ ] POST /daily-quiz/start
- [ ] POST /daily-quiz/submit
- [ ] POST /assessment/start
- [ ] POST /assessment/submit

**Acceptance Criteria**:
- [ ] All POST/PUT endpoints have validation
- [ ] Test invalid inputs (SQL injection attempts, long strings, XSS)
- [ ] Proper 400 errors with validation messages

---

## 💡 P2: NICE TO HAVE (Post-Launch) - 7-10 hours

These can wait until after launch. Do them when you have time.

### [ ] 10. Migrate .withOpacity() (2-3 hours)

**Issue**: 193 uses of deprecated `.withOpacity()` API

**Migration Script**:
```dart
// Before
Colors.black.withOpacity(0.05)

// After
Colors.black.withValues(alpha: 0.05)
```

**Run**:
```bash
find mobile/lib -name "*.dart" -exec sed -i '' 's/withOpacity(\([0-9.]*\))/withValues(alpha: \1)/g' {} +
flutter analyze
```

---

### [ ] 11. Optimize System Prompts (1-2 hours)

**File**: `backend/src/services/openai.js`

**Reduce from 1800 → 1200 characters** (see assessment doc for example)

**Savings**: $22.50/month for 100 users

---

### [ ] 12. Add Image Compression (3-4 hours)

**Add to mobile**:
```yaml
dependencies:
  flutter_image_compress: ^2.0.0
```

**Compress before upload**:
```dart
final result = await FlutterImageCompress.compressWithFile(
  image.path,
  minWidth: 1024,
  minHeight: 1024,
  quality: 85,
);
```

**Savings**: 5-10% on OpenAI vision API costs

---

### [ ] 13. Add Global Rate Limiting (1-2 hours)

**Add to backend**:
```bash
npm install express-rate-limit
```

```javascript
const rateLimit = require('express-rate-limit');

const apiLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 100, // 100 requests/min/IP
});

app.use('/api/', apiLimiter);
```

---

## Launch Checklist

After completing P0 and P1 items:

### Pre-Deployment

- [ ] All P0 items complete (4 items)
- [ ] All P1 items complete (5 items) *or* documented as known issues
- [ ] Code reviewed
- [ ] All tests passing
- [ ] Staging environment deployed and tested

### Deployment

- [ ] Backend deployed to production
- [ ] Mobile app built and uploaded to TestFlight/Play Console (Internal Testing)
- [ ] Firestore indexes deployed
- [ ] Environment variables set (SENTRY_DSN, OPENAI_API_KEY, etc.)
- [ ] Firebase security rules deployed

### Monitoring Setup

- [ ] Sentry receiving errors (test with intentional error)
- [ ] Firebase Crashlytics receiving crashes
- [ ] Firestore cost alerts configured (>$50/day)
- [ ] OpenAI API cost alerts configured (>$200/month)

### Beta Launch (50 Users, 1 Week)

- [ ] Invite 50 beta users
- [ ] Monitor error rates (<1% errors)
- [ ] Monitor costs (should be <$20 for 50 users)
- [ ] Collect feedback on UX issues
- [ ] Fix critical bugs found in beta

### Full Launch

- [ ] Beta period complete (7 days)
- [ ] All critical bugs from beta fixed
- [ ] Cost model validated (<$5/user/month)
- [ ] Announce launch 🎉

---

## Questions / Blockers?

If you get stuck on any item, refer to the detailed technical documentation:

- **Full Assessment**: `docs/claude-assessment/architectural-assessment.md`
- **Executive Summary**: `docs/claude-assessment/EXECUTIVE-SUMMARY.md`

Each issue includes:
- Exact file location and line numbers
- Code showing the problem
- Recommended fix with code examples
- Test plan
- Acceptance criteria

Good luck! 🚀
