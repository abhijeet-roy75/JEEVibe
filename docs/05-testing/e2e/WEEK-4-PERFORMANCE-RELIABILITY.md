# Week 4: Performance, Reliability & Scalability Testing

**Date:** 2026-02-27
**Phase:** Non-Functional Testing
**Prerequisites:** Week 1-3 functional testing complete
**Timeline:** 7 days (56 hours)

---

## Overview

Week 4 focuses on **non-functional requirements**: performance, reliability, and scalability. This phase validates that the system not only works correctly (functional) but also performs well under load, recovers gracefully from failures, and scales to handle growth.

### Testing Categories

1. **Performance Testing** - How fast does it respond?
2. **Reliability Testing** - How well does it handle failures?
3. **Scalability Testing** - How much load can it handle?
4. **Observability** - Can we detect and diagnose issues?

---

## Day 22-24: Performance Testing (24 hours)

### Backend API Performance (12 hours)

#### Load Testing with Artillery/k6 (6 hours)

**Setup (1 hour):**
```bash
# Install Artillery
npm install -g artillery

# Or k6 (alternative)
brew install k6  # macOS
# sudo apt install k6  # Linux
```

**Create load test scenarios** in `backend/tests/performance/`:

1. **`quiz-generation.yml`** (Artillery scenario)
```yaml
config:
  target: "https://your-backend.onrender.com"
  phases:
    - duration: 60
      arrivalRate: 10  # 10 users/second
      name: "Warm up"
    - duration: 300
      arrivalRate: 50  # 50 users/second
      name: "Sustained load"
    - duration: 120
      arrivalRate: 100  # 100 users/second
      name: "Peak load"
  plugins:
    expect: {}
scenarios:
  - name: "Daily Quiz Generation"
    flow:
      - post:
          url: "/api/daily-quiz/generate"
          headers:
            Authorization: "Bearer {{ authToken }}"
            x-session-token: "{{ sessionToken }}"
          json:
            userId: "{{ userId }}"
          expect:
            - statusCode: 200
            - contentType: json
            - hasProperty: questions
      - think: 5
```

2. **`chapter-practice.yml`**
```yaml
config:
  target: "https://your-backend.onrender.com"
  phases:
    - duration: 300
      arrivalRate: 20
scenarios:
  - name: "Chapter Practice Start"
    flow:
      - post:
          url: "/api/chapter-practice/start"
          json:
            userId: "{{ userId }}"
            chapterKey: "physics_laws_of_motion"
            questionCount: 15
          expect:
            - statusCode: 200
            - maxResponseTime: 1000  # P95 < 1s
```

3. **`mock-test.yml`** - 90-question generation (expensive)
4. **`analytics.yml`** - Dashboard data aggregation
5. **`snap-solve.yml`** - AI-powered solution generation

**Run tests (3 hours):**
```bash
artillery run backend/tests/performance/quiz-generation.yml --output report-quiz.json
artillery report report-quiz.json  # Generate HTML report
```

**Analyze results (2 hours):**
- Extract metrics: P50, P90, P95, P99 latencies
- Identify slow endpoints (> 1s P95)
- Check error rates (should be < 0.1%)
- Identify bottlenecks:
  - CPU usage (top/htop during test)
  - Database query times (Firebase Console)
  - External API calls (OpenAI, Claude)
- Document findings in `docs/05-testing/PERFORMANCE-TEST-RESULTS.md`

**Target SLAs:**
| Endpoint | P95 Latency | P99 Latency | Error Rate |
|----------|-------------|-------------|------------|
| Daily Quiz Generate | < 500ms | < 1s | < 0.1% |
| Chapter Practice Start | < 500ms | < 1s | < 0.1% |
| Mock Test Start | < 2s | < 3s | < 0.1% |
| Analytics Overview | < 200ms | < 500ms | < 0.1% |
| Snap & Solve | < 5s | < 10s | < 1% |

#### Database Query Performance (4 hours)

**Firestore Query Profiling (2 hours):**
- Go to Firebase Console → Firestore → Usage tab
- Identify slow queries (> 100ms)
- Common slow queries:
  - `questions` collection scans (no index on `chapter_key + difficulty + active`)
  - `weak_spot_events` time-range queries (no index on `user_id + timestamp`)
  - `daily_quiz_questions` random selection (inefficient sampling)

**Add composite indexes** (1 hour):
```javascript
// firestore.indexes.json
{
  "indexes": [
    {
      "collectionGroup": "questions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "chapter_key", "order": "ASCENDING" },
        { "fieldPath": "difficulty", "order": "ASCENDING" },
        { "fieldPath": "active", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "weak_spot_events",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "user_id", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    }
  ]
}
```

**Test pagination performance** (1 hour):
```javascript
// Test large result sets (1000+ documents)
const startTime = Date.now();
const snapshot = await db.collection('questions')
  .where('chapter_key', '==', 'physics_kinematics')
  .limit(100)
  .get();
const queryTime = Date.now() - startTime;
console.log(`Query time: ${queryTime}ms`);
// Target: < 50ms for 100 docs
```

#### IRT Algorithm Performance (2 hours)

**Profile question selection** (`questionSelectionService.js`):
```javascript
// Add performance markers
console.time('questionSelection');
const question = await selectNextQuestion(userId, chapterKey);
console.timeEnd('questionSelection');
// Target: < 50ms
```

**Test with large datasets:**
- 10,000+ questions in pool
- 100+ student responses in history
- Verify Fisher Information calculation efficiency
- Verify IRT probability calculation (3PL model)

**Optimize if needed:**
- Cache IRT parameters (in-memory, 5-minute TTL)
- Pre-filter questions by difficulty range
- Use database indexes for recency checks

---

### Mobile App Performance (8 hours)

#### Startup Performance (3 hours)

**Measure startup times** (Flutter DevTools):
```dart
// In main.dart
void main() {
  final startTime = DateTime.now();

  runApp(MyApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    print('App startup time: ${duration.inMilliseconds}ms');
  });
}
```

**Test scenarios:**
1. **Cold start** (first launch after install)
   - Target: < 3 seconds
   - Profile with: `flutter run --profile --trace-startup`
   - Check: Firebase initialization, Provider setup, route generation

2. **Warm start** (app backgrounded < 1 hour)
   - Target: < 1 second
   - State should be preserved

3. **Hot start** (app resumed from background)
   - Target: < 500ms
   - No re-initialization needed

**Optimize heavy operations:**
- Lazy-load Firebase initialization
- Defer non-critical Provider initialization
- Use `FutureBuilder` for async data loading

#### Runtime Performance (3 hours)

**Frame rendering** (60fps target):
```bash
flutter run --profile
# In DevTools: Performance → Timeline
# Look for jank (frames > 16ms)
```

**Test scenarios:**
1. **Quiz question rendering** with LaTeX
   - 5 questions with complex equations
   - Target: First frame < 100ms, subsequent < 16ms

2. **List scrolling** (history screens)
   - 1000+ items in `ListView.builder`
   - Target: Smooth 60fps scrolling
   - Use: `ListView.builder` not `ListView` (lazy loading)

3. **Image loading** (Snap & Solve)
   - Test 5MB image upload
   - Target: Upload < 2s, compression < 500ms
   - Use: `flutter_image_compress` for optimization

**Memory profiling:**
```bash
flutter run --profile
# DevTools → Memory → Record
# Complete quiz flow → Check for leaks
# Target: < 200MB during normal operation
```

**Common leaks:**
- Unclosed StreamSubscriptions
- Retained listeners (addListener without removeListener)
- Cached images not disposed

#### Battery Usage (2 hours)

**Test long-running sessions:**
1. **Mock test (3 hours)**
   - Full 90-question test with timer
   - Target: < 5% battery per hour
   - Test on: iPhone 8, Android (2GB RAM device)

2. **Daily quiz marathon (10 quizzes)**
   - Complete 10 quizzes back-to-back
   - Target: < 3% battery total

**Profile battery usage:**
- **Android:** `adb shell dumpsys batterystats` → Battery Historian
- **iOS:** Xcode → Instruments → Energy Log

**Optimize CPU-intensive operations:**
- LaTeX rendering (cache rendered SVGs)
- IRT calculations (defer to backend)
- Image processing (use native compression)

---

### Web Performance (4 hours)

#### Lighthouse Audit (2 hours)

**Run Lighthouse on all routes:**
```bash
npm install -g lighthouse

lighthouse https://jeevibe-app.web.app --output html --output-path=./lighthouse-home.html
lighthouse https://jeevibe-app.web.app/quiz --output html --output-path=./lighthouse-quiz.html
lighthouse https://jeevibe-app.web.app/analytics --output html --output-path=./lighthouse-analytics.html
```

**Target scores:**
- **Performance:** 90+ (green)
- **Accessibility:** 95+ (green)
- **Best Practices:** 100 (green)
- **SEO:** 90+ (green)

**Common issues & fixes:**
- Unused CSS/JS → Remove or defer
- Large images → Compress, use WebP
- No lazy loading → Add `loading="lazy"` to images
- No code splitting → Use `deferred` imports in Dart

#### Bundle Size Analysis (2 hours)

**Analyze Flutter web build:**
```bash
cd mobile
flutter build web --web-renderer html --analyze-size

# Output shows:
# - main.dart.js size (target: < 2MB gzipped)
# - Largest dependencies
```

**Optimize bundle:**
1. **Tree shaking** (automatic in release mode)
2. **Code splitting** by route:
```dart
// Use deferred imports for heavy screens
import 'package:jeevibe/screens/mock_test_screen.dart' deferred as mock_test;

// Load on demand
await mock_test.loadLibrary();
Navigator.push(context, MaterialPageRoute(
  builder: (_) => mock_test.MockTestScreen()
));
```

3. **Analyze large dependencies:**
```bash
flutter pub deps --style=tree | grep -A 5 "http\|firebase\|charts"
```

4. **Remove unused packages** from `pubspec.yaml`

**Test load time on slow network:**
```bash
# Chrome DevTools → Network → Throttle to "Slow 3G"
# Reload page
# Target: < 5 seconds to interactive
```

---

## Day 25-26: Reliability Testing (16 hours)

### Chaos Engineering (8 hours)

#### Simulated Service Failures (4 hours)

**Test Firebase timeout:**
```javascript
// Mock Firebase delay in tests
jest.mock('../config/firebase', () => ({
  db: {
    collection: jest.fn(() => ({
      doc: jest.fn(() => ({
        get: jest.fn(() => {
          return new Promise((resolve) => {
            setTimeout(() => resolve({ exists: false }), 10000); // 10s delay
          });
        })
      }))
    }))
  }
}));

// Verify:
// - Request times out after 30s
// - User sees error message
// - Retry logic kicks in
// - No data corruption
```

**Test OpenAI API timeout:**
```javascript
// Simulate 30+ second response
nock('https://api.openai.com')
  .post('/v1/chat/completions')
  .delayConnection(35000)
  .reply(200, { /* response */ });

// Verify:
// - Circuit breaker opens after 3 failures
// - User sees "High demand, try again" message
// - Snap & Solve falls back to Claude API
```

**Test token expiry mid-session:**
```dart
// In mobile test
test('handles 401 during quiz submission', () async {
  // Start quiz
  await tester.pumpWidget(MyApp());

  // Expire token
  mockAuthService.expireToken();

  // Submit quiz
  await tester.tap(find.byKey(Key('submit_button')));
  await tester.pump();

  // Verify:
  // - Token auto-refreshes
  // - Quiz submits successfully
  // - No data loss
});
```

**Failure scenarios to test:**
| Scenario | Expected Behavior |
|----------|-------------------|
| Firebase timeout (10s) | Retry 3x with exponential backoff, then error |
| OpenAI 429 (rate limit) | Wait 60s, retry, or fallback to Claude |
| Firestore write failure | Queue write, retry on reconnect |
| Token 401 mid-quiz | Auto-refresh token, retry request |
| Network unavailable | Show offline mode, queue requests |

#### Network Instability (2 hours)

**Test slow network (3G speed):**
```bash
# Chrome DevTools → Network → Throttle to "Slow 3G"
# - 400ms latency
# - 400 Kbps down
# - 400 Kbps up
```

**Verify:**
- App remains responsive (no freezing)
- Loading indicators appear
- User can navigate away from slow requests
- Requests timeout after 30s, not infinite

**Test intermittent connectivity:**
```dart
// Simulate airplane mode on/off
test('handles network disconnect/reconnect', () async {
  // Start quiz
  await startQuiz();

  // Disconnect network
  await networkService.disconnect();

  // Try to submit (should queue)
  await submitQuiz();

  // Reconnect network
  await networkService.reconnect();

  // Verify:
  // - Queued submission auto-retries
  // - Data syncs correctly
  // - No duplicate submissions
});
```

**Test packet loss:**
- 10% loss: App should work fine (HTTP retry)
- 30% loss: Slow but functional
- 50% loss: Degraded, show warning

#### Database Failure Scenarios (2 hours)

**Test Firestore write quota exceeded:**
```javascript
// Mock quota exceeded error
const error = new Error('Quota exceeded');
error.code = 'resource-exhausted';
db.collection('users').doc('test').update({})
  .mockRejectedValue(error);

// Verify:
// - Error logged to Sentry
// - User sees "Service temporarily unavailable"
// - Write queued for retry (after 5 minutes)
```

**Test concurrent write conflicts:**
```javascript
// Two users updating same document simultaneously
const userId = 'test-user-001';

// User A updates theta
await db.collection('users').doc(userId).update({
  'theta_by_subject.physics.theta': 0.5
});

// User B updates theta (conflict!)
await db.collection('users').doc(userId).update({
  'theta_by_subject.physics.theta': 0.6
});

// Verify:
// - Last write wins (Firebase default)
// - Consider optimistic locking for critical updates
```

---

### Long-Running Stability (8 hours)

#### 24-Hour Session Test (4 hours setup + 24h run)

**Automated test script:**
```javascript
// backend/tests/reliability/24h-stability.js
const { performance } = require('perf_hooks');

async function run24HourTest() {
  const startTime = performance.now();
  const userId = 'test-user-stability';
  let quizCount = 0;

  while ((performance.now() - startTime) < 86400000) { // 24 hours
    try {
      // Complete a quiz
      await completeQuiz(userId);
      quizCount++;

      // Wait 5 minutes
      await sleep(300000);

      console.log(`Quiz ${quizCount} completed. Memory: ${process.memoryUsage().heapUsed / 1024 / 1024} MB`);
    } catch (error) {
      console.error(`Error at quiz ${quizCount}:`, error);
    }
  }

  console.log(`24h test complete. Total quizzes: ${quizCount}`);
}
```

**Monitor during test:**
- Memory usage (should be stable, not growing)
- Token refresh cycles (every 60 minutes)
- Session persistence (survives app backgrounding)
- No crashes or errors

#### App Backgrounding Stress Test (2 hours)

**Test long background duration:**
```dart
test('app survives 24h backgrounding', () async {
  // Start mock test
  await startMockTest();

  // Background app for 24 hours (simulated)
  await tester.runAsync(() async {
    await Future.delayed(Duration(hours: 24));
  });

  // Resume app
  await resumeApp();

  // Verify:
  // - Mock test timer resumes correctly
  // - Session data preserved
  // - Questions still load
  // - Can submit test
});
```

**iOS considerations:**
- App may be killed by OS after 3-5 hours
- Save state to `SharedPreferences` before backgrounding
- Restore state on app launch

**Android considerations:**
- Background task limits (Doze mode)
- Work Manager for background sync

#### Recovery Testing (2 hours)

**Force crash scenarios:**
```dart
test('recovers from crash during quiz', () async {
  // Answer 3/5 questions
  await answerQuestion(0, 'A');
  await answerQuestion(1, 'B');
  await answerQuestion(2, 'C');

  // Force crash (simulated)
  exit(1);

  // Restart app
  await restartApp();

  // Verify:
  // - Quiz state restored (3 answers preserved)
  // - Can continue from question 4
  // - Can submit quiz
  // - No data loss
});
```

**Test scenarios:**
| Scenario | Expected Recovery |
|----------|-------------------|
| Crash during quiz | Restore to last answered question |
| Crash during mock test | Resume with timer adjusted |
| Crash during Snap & Solve | Image preserved, can retry |
| Kill app during upload | Upload retries on relaunch |

---

## Day 27-28: Scalability & Observability (16 hours)

### Scalability Testing (8 hours)

#### Vertical Scaling Limits (3 hours)

**Test single instance capacity:**
```bash
# Use Artillery to gradually increase load
artillery quick --count 10 --num 100 https://your-backend.onrender.com/api/health
# 10 users, 100 requests each = 1000 requests

artillery quick --count 50 --num 100 https://your-backend.onrender.com/api/health
# 50 users = 5000 requests

artillery quick --count 100 --num 100 https://your-backend.onrender.com/api/health
# 100 users = 10000 requests

artillery quick --count 200 --num 100 https://your-backend.onrender.com/api/health
# 200 users = 20000 requests
```

**Monitor during test:**
- CPU usage (Render.com dashboard)
- Memory usage (should stay < 80%)
- Response times (P95, P99)
- Error rate (should stay < 1%)

**Identify breaking point:**
- When does P95 latency exceed 2s?
- When does error rate exceed 5%?
- When does instance CPU hit 100%?

**Document maximum capacity:**
- Example: "Single instance handles 100 concurrent users at 1000 req/min with P95 < 500ms"

#### Firebase Limits (2 hours)

**Document current usage vs limits:**
| Resource | Current Usage | Firebase Limit | Headroom |
|----------|---------------|----------------|----------|
| Firestore writes | ~100/min | 10K/sec | 99.98% |
| Firestore reads | ~500/min | 100K/sec | 99.99% |
| Document size | ~50KB avg | 1MB | 95% |
| Collection size | ~10K docs | 1M docs | 99% |
| Auth logins | ~10/min | 100/IP/hour | 99.9% |

**Test at scale:**
```javascript
// Simulate 1000 concurrent quiz submissions
const promises = [];
for (let i = 0; i < 1000; i++) {
  promises.push(submitQuiz(`test-user-${i}`));
}
await Promise.all(promises);

// Monitor:
// - Write success rate (should be 100%)
// - Write latency (should be < 100ms)
```

**Plan for scaling:**
- **Sharding:** Split users across multiple Firestore databases (not needed until 100K+ users)
- **Caching:** Redis for frequently read data (tier limits, question metadata)
- **Read replicas:** Not supported by Firestore (use caching instead)

#### External API Rate Limits (3 hours)

**OpenAI API limits:**
- Free tier: 3 RPM, 40K TPM
- Tier 1: 500 RPM, 200K TPM ($5+ spent)
- Tier 2: 5000 RPM, 2M TPM ($100+ spent)

**Claude API limits:**
- Free tier: 5 RPM, 100K TPM
- Paid tier: 100 RPM, 1M TPM

**Test rate limiting:**
```javascript
// Simulate 100 concurrent Snap & Solve requests
const promises = [];
for (let i = 0; i < 100; i++) {
  promises.push(snapSolve(image));
}

try {
  await Promise.all(promises);
} catch (error) {
  if (error.status === 429) {
    console.log('Rate limited! Implement queue...');
  }
}
```

**Implement rate limiting strategies:**
1. **Queue requests** (BullMQ with Redis)
```javascript
const Queue = require('bull');
const snapQueue = new Queue('snap-solve', {
  redis: { host: 'localhost', port: 6379 }
});

// Add to queue
await snapQueue.add({ userId, imageUrl });

// Process with rate limiting
snapQueue.process(async (job) => {
  const { userId, imageUrl } = job.data;
  return await processSnap(imageUrl);
}, {
  limiter: {
    max: 5,  // 5 requests
    duration: 60000  // per minute
  }
});
```

2. **Exponential backoff**
```javascript
async function callOpenAI WithRetry(prompt, maxRetries = 5) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await openai.chat.completions.create(prompt);
    } catch (error) {
      if (error.status === 429) {
        const delay = Math.pow(2, i) * 1000; // 1s, 2s, 4s, 8s, 16s
        await sleep(delay);
      } else {
        throw error;
      }
    }
  }
  throw new Error('Max retries exceeded');
}
```

3. **Circuit breaker** (already exists in `circuitBreakerService.js`)

---

### Observability Setup (8 hours)

#### Monitoring Dashboards (4 hours)

**Firebase Performance Monitoring (mobile):**
```dart
// In main.dart
import 'package:firebase_performance/firebase_performance.dart';

void main() async {
  WidgetsBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Enable performance monitoring
  FirebasePerformance.instance.setPerformanceCollectionEnabled(true);

  runApp(MyApp());
}
```

**Backend monitoring options:**
1. **Firebase Crashlytics** (free, basic)
2. **Datadog** (paid, comprehensive)
3. **New Relic** (paid, APM)
4. **Open-source:** Prometheus + Grafana

**Create dashboards:**
1. **API Performance**
   - Chart: P50/P95/P99 latency per endpoint
   - Chart: Request volume per endpoint
   - Chart: Error rate per endpoint

2. **Database Performance**
   - Chart: Firestore read/write counts
   - Chart: Slowest queries (> 100ms)
   - Chart: Document sizes

3. **User Experience**
   - Chart: Crash-free session rate (target: 99.9%)
   - Chart: App startup time (P50, P95)
   - Chart: Screen load time per route

4. **Business Metrics**
   - Chart: Daily active users (DAU)
   - Chart: Quiz completion rate
   - Chart: Snap & Solve success rate
   - Chart: Subscription conversion rate

#### Alerting Rules (2 hours)

**Define SLAs:**
```yaml
# alerting-rules.yml
alerts:
  - name: "High API Latency"
    condition: "p95_latency > 2000ms"
    severity: "critical"
    channels: ["slack", "pagerduty"]

  - name: "High Error Rate"
    condition: "error_rate > 5%"
    severity: "critical"
    channels: ["slack", "email"]

  - name: "Slow Database Queries"
    condition: "query_time > 500ms"
    severity: "warning"
    channels: ["slack"]

  - name: "High Crash Rate"
    condition: "crash_rate > 0.1%"
    severity: "warning"
    channels: ["slack", "email"]
```

**Configure notification channels:**
- Slack webhook for immediate alerts
- Email for non-critical warnings
- PagerDuty for 24/7 on-call (if needed)

**Test alert delivery:**
```bash
# Trigger test alert
curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -H 'Content-Type: application/json' \
  -d '{"text":"Test alert: High API latency detected"}'
```

#### Logging Improvements (2 hours)

**Structured logging (JSON format):**
```javascript
// Before (unstructured)
console.log(`User ${userId} completed quiz with score ${score}`);

// After (structured)
logger.info('quiz_completed', {
  userId,
  score,
  questionCount: 5,
  timeSpent: 120,
  correctAnswers: 3,
  correlationId: req.id  // Trace across services
});
```

**Log correlation IDs:**
```javascript
// Middleware to add correlation ID
app.use((req, res, next) => {
  req.id = uuidv4();
  res.setHeader('X-Correlation-ID', req.id);
  next();
});

// Use in all logs
logger.info('quiz_generated', {
  correlationId: req.id,
  userId: req.user.id,
  questionCount: 5
});
```

**Sensitive data redaction:**
```javascript
// Redact PII from logs
function sanitize(data) {
  const redacted = { ...data };
  if (redacted.phoneNumber) redacted.phoneNumber = '***';
  if (redacted.authToken) redacted.authToken = '***';
  return redacted;
}

logger.info('user_logged_in', sanitize(userData));
```

**Log retention policy:**
- Info logs: 30 days
- Error logs: 90 days
- Performance logs: 7 days

**Error aggregation:**
- Use Sentry for backend errors
- Use Firebase Crashlytics for mobile crashes
- Group similar errors (same stack trace)
- Alert on new error types

---

## End of Week 4 Deliverables

### Performance Test Results
- `docs/05-testing/PERFORMANCE-TEST-RESULTS.md`
  - API latency benchmarks (P50, P95, P99)
  - Mobile startup time (cold/warm/hot)
  - Database query performance
  - Bottleneck analysis

### Reliability Test Results
- `docs/05-testing/CHAOS-TEST-SCENARIOS.md`
  - Failure scenarios tested
  - Recovery behavior documented
  - 24-hour stability results

### Scalability Analysis
- `docs/02-architecture/SCALABILITY-LIMITS.md`
  - Current capacity (users, req/min)
  - Firebase limits vs usage
  - External API rate limits
  - Scaling strategies

### Observability Documentation
- `docs/02-architecture/OBSERVABILITY.md`
  - Monitoring dashboards (links, screenshots)
  - Alerting rules (SLAs, channels)
  - Logging standards (JSON format, correlation IDs)

### Tools & Scripts
```
backend/tests/performance/
├── quiz-generation.yml          [NEW] Artillery load test
├── chapter-practice.yml         [NEW] Practice load test
├── mock-test.yml                [NEW] Mock test load test
├── analytics.yml                [NEW] Analytics load test
└── snap-solve.yml               [NEW] Snap & Solve load test

backend/tests/reliability/
├── 24h-stability.js             [NEW] Long-running test
├── chaos-scenarios.js           [NEW] Failure injection tests
└── recovery-tests.js            [NEW] Crash recovery tests
```

---

## Success Criteria

**Performance:**
- ✅ API P95 latency < 1s for all endpoints
- ✅ Mobile startup < 3s (cold), < 1s (warm)
- ✅ Database queries < 100ms (95%)
- ✅ Lighthouse score: Performance 90+

**Reliability:**
- ✅ All chaos scenarios tested (5+)
- ✅ 24-hour stability test passed (no crashes)
- ✅ Recovery tests passed (all scenarios)
- ✅ Graceful degradation under failures

**Scalability:**
- ✅ Vertical scaling limits documented
- ✅ Firebase usage < 50% of limits
- ✅ External API rate limiting strategies implemented
- ✅ Scaling plan documented

**Observability:**
- ✅ Monitoring dashboards operational
- ✅ Alerting rules configured and tested
- ✅ Structured logging implemented
- ✅ Error aggregation operational (Sentry, Crashlytics)

---

## Next Steps (Post-Week 4)

1. **Launch with confidence** - Functional + Performance validated
2. **Monitor production** - Use dashboards to track real usage
3. **Optimize based on data** - Address bottlenecks found in production
4. **Iterate on performance** - Continuous improvement based on user feedback

**Timeline:** Week 4 adds 7 days to the 21-day functional testing plan, for a total of **28 days (4 weeks)** to complete comprehensive testing.
