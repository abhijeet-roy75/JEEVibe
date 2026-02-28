# Backend Testing Priority Plan

**Date:** 2026-02-27
**Approach:** Backend First → Test Infrastructure First (Option A)
**Timeline:** Week 1 (7 days)

---

## Why Backend First?

1. **Foundation for all tests** - Mobile and web tests depend on stable backend APIs
2. **Highest business risk** - Backend bugs affect ALL users across ALL platforms
3. **Test infrastructure reusability** - Fixtures/factories built for backend can be used for integration tests
4. **Coverage metrics most actionable** - Backend coverage directly maps to API reliability

## Why Test Infrastructure First?

1. **3x faster test writing** - No need to manually create test data in each test
2. **Consistent test patterns** - All tests use same fixtures/factories
3. **Easier maintenance** - Update fixture once, all tests benefit
4. **Realistic test scenarios** - Pre-built data matches production patterns

---

## Week 1 Execution Plan (Backend Only)

### Day 1: Setup Firebase Test Phones + Test Users (8 hours)

**Firebase Test Phones (1 hour)**
- Go to Firebase Console → Authentication → Phone Auth → Test Phone Numbers
- Add 10 test numbers: `+16505551001` through `+16505551010`
- Set OTP code to `123456` for all
- Test one number works

**Standard Test Users Script (3 hours)**
Create `backend/scripts/e2e/setup-test-users.js`:
```javascript
// Generates 10 test users across tiers:
// - test-user-free-001, test-user-free-002, test-user-free-003
// - test-user-pro-001, test-user-pro-002, test-user-pro-003
// - test-user-ultra-001, test-user-ultra-002
// - test-user-trial-active, test-user-trial-expiring

// Each user includes:
// - Firebase Auth account (linked to test phone)
// - Firestore user document with theta, subscription, trial data
// - Sample quiz/practice history (varies by user)
```

**Test Fixtures (4 hours)**
Create 8 JSON files in `backend/tests/fixtures/`:

1. **questions-100.json** - Sample questions for testing
2. **mock-test-template.json** - Full 90-question mock test
3. **assessment-questions-30.json** - Initial assessment questions
4. **quiz-responses-valid.json** - Valid quiz submissions
5. **quiz-responses-invalid.json** - Invalid submissions (edge cases)
6. **user-theta-data.json** - Sample theta calculations
7. **weak-spot-event-log.json** - Cognitive mastery events
8. **subscription-data.json** - Free/Pro/Ultra/Trial samples

---

### Day 2: Test Factories + Management Scripts (8 hours)

**Test Factories (4 hours)**
Create 5 factory files in `backend/tests/factories/`:

1. **userFactory.js**
```javascript
// createUser({ tier: 'free', hasProgress: true })
// createWithTheta({ overall: 0.5, subject: {...} })
// createWithTrial({ daysRemaining: 7 })
```

2. **questionFactory.js**
```javascript
// createMCQ({ subject: 'Physics', difficulty: 'medium' })
// createNumerical({ chapter: 'Kinematics', irtParams: {...} })
// createBatch(50, { subject: 'Chemistry' })
```

3. **quizFactory.js**
```javascript
// createQuizSession({ userId, questionCount: 5 })
// createCompletedQuiz({ correctAnswers: 3, totalQuestions: 5 })
```

4. **mockTestFactory.js**
```javascript
// createMockTestSession({ userId, questionsAnswered: 45 })
// createCompletedMockTest({ score: 240, maxScore: 300 })
```

5. **subscriptionFactory.js**
```javascript
// createFreeSubscription()
// createProSubscription({ expiresIn: '30 days' })
// createTrialSubscription({ daysRemaining: 7 })
```

**Management Scripts (4 hours)**

1. **reset-test-data.js**
```javascript
// Deletes all test users (IDs starting with 'test-user-')
// Recreates 10 standard test users
// Loads question fixtures
// Validates tier_config exists
// Confirms Firebase test phones configured
```

2. **validate-test-env.js**
```javascript
// Checks:
// - Firebase credentials valid
// - Firestore reachable
// - Question bank has 500+ questions
// - Assessment has 30+ questions
// - Mock test templates exist (2+)
// - tier_config collection exists
// - Test users exist (10 users)
// - Firebase test phones configured (10 numbers)
// Returns: ✅ Ready or 🔴 Issues found
```

3. **run-all-backend-tests.sh**
```bash
#!/bin/bash
echo "Running backend unit tests..."
npm run test:unit

echo "Running backend integration tests..."
npm run test:integration

echo "Generating coverage report..."
npm run test:coverage

echo "Backend tests complete!"
```

---

### Day 3-4: Critical Service Tests Part 1 (16 hours)

**Day 3: tierConfigService.test.js (4 hours) + adminMetricsService.test.js (6 hours)**

**tierConfigService.test.js** - Simplest, foundational test
- Test `getTierLimits('free')` → Returns correct daily limits
- Test `getTierLimits('pro')` → Returns Pro limits
- Test `getTierLimits('ultra')` → Returns Ultra limits
- Test `getTierFeatures('free')` → Returns feature flags
- Test `getTierLimitsAndFeatures()` → Combined response
- Test cache behavior (5-minute TTL)
- Test Firestore failure fallback
- Uses: `subscription-data.json` fixture
- **Target:** 80%+ coverage (currently 12.3%)

**adminMetricsService.test.js** - Complex aggregations
- Test `getCognitiveMasteryMetrics()` → 7-day event aggregation
  - Detected weak spots count
  - Remediated weak spots count
  - Mastered weak spots count
  - Per-node breakdown
- Test `getUserProgress(userId)` → User metrics
  - Overall theta + percentile
  - Subject-wise theta
  - Chapter-wise theta
  - Accuracy (correct/total)
  - Streak count
- Test `getEngagementMetrics()` → Platform usage
  - Daily quiz usage (count, avg score)
  - Chapter practice usage
  - Snap solve usage
  - Mock test usage
- Test edge cases:
  - User with no data → Returns empty metrics
  - Corrupted weak_spot_events → Skips invalid events
  - Missing theta data → Returns null values
- Uses: `user-theta-data.json`, `weak-spot-event-log.json` fixtures
- Uses: `userFactory.createWithProgress()` factory
- **Target:** 80%+ coverage (currently 1.03%)

**Day 4: analyticsService.test.js (6 hours)**

**analyticsService.test.js** - User analytics
- Test `getAnalyticsOverview(userId)` → Dashboard data
  - Overall theta, percentile, accuracy
  - Subject-wise theta (Physics, Chemistry, Math)
  - Streak count
  - Questions answered (total)
- Test `getFocusAreas(userId)` → Weak chapters
  - Returns bottom 3 chapters by theta
  - Filters by unlocked chapters only (24-month timeline)
  - Returns chapter names, theta values, question counts
- Test `getProgressHistory(userId)` → Theta timeline
  - Returns theta snapshots (last 30 days)
  - Includes dates and theta values
  - Sorted by date ascending
- Test tier-based filtering:
  - Free tier → Limited data (basic analytics)
  - Pro tier → Full analytics
  - Ultra tier → Full analytics + AI insights
- Test missing data:
  - No theta data → Returns null for theta fields
  - No progress history → Returns empty array
  - No unlocked chapters → Focus areas returns empty
- Uses: `user-theta-data.json` fixture
- Uses: `userFactory.createWithTheta({ overall: 0.5, subjects: {...} })` factory
- **Target:** 80%+ coverage (currently 15.31%)

---

### Day 5-7: Critical Service Tests Part 2 (24 hours)

**Day 5-6: mockTestService.test.js (16 hours) - MOST COMPLEX**

**mockTestService.test.js** - Mock test generation and grading
- Test `generateMockTest(userId)` → Creates 90-question test
  - 30 Physics questions (20 MCQ + 10 Numerical)
  - 30 Chemistry questions (20 MCQ + 10 Numerical)
  - 30 Math questions (20 MCQ + 10 Numerical)
  - Questions stratified by difficulty (easy/medium/hard)
  - IRT difficulty balanced around user's theta
  - No duplicate questions from recent tests (30-day window)
- Test `getMockTestSession(userId, sessionId)` → Resume session
  - Returns session with 90 questions
  - Returns current progress (questions answered, time remaining)
  - Returns question states (NotVisited, NotAnswered, Answered, MarkedForReview)
- Test `submitMockTest(userId, sessionId, responses)` → Grade test
  - Marking scheme: +4 correct, -1 incorrect, 0 unattempted
  - Maximum score: 300 marks
  - Returns subject-wise scores (Physics, Chemistry, Math)
  - Returns total score
  - Returns percentile (compared to all users)
  - Returns time taken
- Test state transitions:
  - NotVisited (gray) → Open question → NotAnswered (red)
  - NotAnswered → Select answer → Answered (green)
  - Answered → Mark for review → AnsweredAndMarked (purple+green)
  - NotAnswered → Mark for review → MarkedForReview (purple)
- Test 3-hour timer:
  - Test started 2:59 → Submit succeeds
  - Test started 3:01 → Auto-submit with warning
- Test partial submission:
  - Submit with 45/90 answered → Grades 45, rest counted as unattempted
- Test invalid answers:
  - Answer out of range (e.g., option 'E' for 4-option MCQ) → Treated as unattempted
  - Numerical answer non-numeric → Treated as unattempted
- Test tier enforcement:
  - Free tier: Can start test if < 1 test this month
  - Pro tier: Can start test if < 5 tests this month
  - Ultra tier: Unlimited tests
  - Exceeded limit → Returns 402 Payment Required
- Uses: `mock-test-template.json`, `questions-100.json` fixtures
- Uses: `mockTestFactory.createSession()`, `questionFactory.createMCQ()` factories
- **Target:** 80%+ coverage (currently 3.57%)

**Day 7: Validation + Documentation (8 hours)**

**Backend Coverage Validation (2 hours)**
```bash
cd backend
npm run test:coverage

# Expected results:
# - tierConfigService: 80%+ (was 12.3%)
# - adminMetricsService: 80%+ (was 1.03%)
# - analyticsService: 80%+ (was 15.31%)
# - mockTestService: 80%+ (was 3.57%)
# - Overall backend: 40%+ (was 28.64%)
```

**Test Infrastructure Validation (2 hours)**
```bash
cd backend
node scripts/e2e/validate-test-env.js

# Expected checks:
# ✅ Firebase credentials valid
# ✅ Firestore reachable
# ✅ 10 test users exist
# ✅ 10 Firebase test phones configured
# ✅ 8 fixtures load correctly
# ✅ 5 factories produce valid data
# ✅ tier_config collection exists
# ✅ Question bank has 500+ questions
```

**Documentation (4 hours)**
- Update `backend/tests/README.md` with fixture usage
- Update `backend/tests/factories/README.md` with factory patterns
- Create `docs/05-testing/TESTING-USERS.md` with test user credentials
- Update `backend/scripts/README-TESTING.md` with script usage

---

## End of Week 1 Deliverables

**Test Infrastructure:**
- ✅ 10 Firebase test phones configured
- ✅ 10 standard test users functional
- ✅ 8 JSON fixtures created
- ✅ 5 test factories created
- ✅ 3 management scripts created

**Backend Tests:**
- ✅ tierConfigService.test.js (80%+ coverage)
- ✅ adminMetricsService.test.js (80%+ coverage)
- ✅ analyticsService.test.js (80%+ coverage)
- ✅ mockTestService.test.js (80%+ coverage)

**Coverage Increase:**
- ✅ Backend: 28.64% → 40%+ (11.36% increase)

**Foundation Ready:**
- ✅ Week 2 can start immediately with route integration tests
- ✅ Test patterns established for remaining backend tests
- ✅ Test infrastructure reusable for mobile/admin tests

---

## Week 2 Preview (Backend Completion)

**Days 8-9: Route Integration Tests**
- admin.js, mockTests.js, analytics.js, chapterPractice.js, weakSpots.js

**Days 10-11: Mobile Test Infrastructure**
- Mobile fixtures, mobile factories

**Days 12-13: Admin Dashboard Test Setup**
- Vitest installation, first component tests

**Day 14: Backend Coverage Push**
- weakSpotScoringService, chapterPracticeService, assessmentService, dailyQuizService

**End of Week 2 Target:**
- Backend: 70%+ coverage (from 40%)

---

## Success Criteria (Week 1)

**Must Have:**
- [ ] All 10 test users can authenticate
- [ ] All 4 critical services tested (80%+ coverage each)
- [ ] Backend overall coverage ≥ 40%
- [ ] Test infrastructure functional (fixtures, factories, scripts)

**Nice to Have:**
- [ ] Additional service tests started (weakSpotScoring, chapterPractice)
- [ ] Mobile test fixtures created early

**Blockers to Watch:**
- Firebase test phone configuration delays (need Firebase Console access)
- Firestore access issues (credentials, permissions)
- Test data generation complexity (question bank, theta calculations)

---

## Quick Commands Reference

**Setup:**
```bash
# Run once at start of Week 1
cd backend
node scripts/e2e/setup-test-users.js
node scripts/e2e/validate-test-env.js
```

**Daily Development:**
```bash
# Run tests as you write them
npm run test:unit -- tierConfigService.test.js
npm run test:unit -- adminMetricsService.test.js
npm run test:unit -- analyticsService.test.js
npm run test:unit -- mockTestService.test.js

# Check coverage
npm run test:coverage
```

**Reset Environment:**
```bash
# Reset test data to clean state
node scripts/e2e/reset-test-data.js
node scripts/e2e/validate-test-env.js
```

**End of Day:**
```bash
# Run all tests before committing
npm test
npm run test:coverage
git add .
git commit -m "test: add [service] tests (coverage: X%)"
git push origin main  # Triggers Render.com deployment
```

---

**Ready to start? Begin with Day 1, Task 1: Configure Firebase test phones.**
