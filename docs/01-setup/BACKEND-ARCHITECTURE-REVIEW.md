# JEEVibe Backend Architecture Review

**Review Date:** 2026-02-13
**Reviewer:** Senior Architecture Review
**Scope:** Backend services, database design, API architecture, scalability assessment

---

## Executive Summary

JEEVibe is a **Node.js/Express backend** with **Firebase Firestore** serving a Flutter mobile app for JEE exam preparation. The system implements an **Item Response Theory (IRT) adaptive learning engine** with sophisticated theta tracking, question selection algorithms, and subscription tier management.

### Overall Assessment

**Status:** ✅ **Production-ready with caveats**

The architecture is well-structured for an MVP with:
- ✅ Strong separation of concerns (81 service files, 15 route handlers)
- ✅ Comprehensive error handling and logging (Sentry integration)
- ✅ Thoughtful performance optimizations (multi-tier caching)
- ✅ Proper authentication and input validation
- ⚠️ **Critical issues require immediate attention** (session validation disabled, race conditions)
- ⚠️ **Scaling concerns** around single-instance caching and manual cache invalidation
- ⚠️ **Some N+1 query risks** in analytics endpoints

### Scorecard

| Dimension | Score | Assessment |
|-----------|-------|------------|
| **Architecture & Design** | 8/10 | Well-organized service layer, clear separation of concerns |
| **Data Consistency** | 7/10 | Good transaction usage, but race conditions exist |
| **Performance** | 7/10 | Multi-tier caching implemented, some N+1 risks remain |
| **Reliability** | 7/10 | Retry logic present, but session validation disabled |
| **Scalability** | 5/10 | **Major concern**: Single-instance caching breaks horizontal scaling |
| **Security** | 8/10 | Strong auth validation, comprehensive input validation |
| **Code Quality** | 7/10 | Consistent patterns, but some 1000+ LOC files |
| **Testing** | 6/10 | Test infrastructure exists (384 tests), coverage unclear |
| **Observability** | 8/10 | Winston logging, Sentry monitoring, health checks |
| **Deployment** | 8/10 | Graceful shutdown, proper environment detection |

**Overall:** 7.1/10 - **Solid foundation with architectural debt to address**

---

## Architecture Overview

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Mobile App (Flutter)                      │
└─────────────────────────────────────────────────────────────┘
                            ↓ HTTPS
┌─────────────────────────────────────────────────────────────┐
│              API Gateway (Express on Render.com)             │
│                                                              │
│  Middleware Chain:                                           │
│  1. CORS & Security                                          │
│  2. Body Parsing (1MB limit) + Gzip Compression              │
│  3. Request ID (UUID correlation)                            │
│  4. Health Check (bypass rate limiting)                      │
│  5. Rate Limiting (3 tiers: API, Strict, Image)              │
│  6. Authentication (Firebase Auth token validation)          │
│  7. Session Validation ⚠️ DISABLED                           │
│  8. Feature Gating (tier-based access control)               │
│  9. Error Handling (standardized ApiError responses)         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Service Layer (81 Services)               │
│                                                              │
│  Core Learning Engine:                                       │
│  • thetaCalculationService - Initial theta bootstrapping     │
│  • thetaUpdateService - Bayesian updates after responses     │
│  • questionSelectionService - IRT-optimized selection        │
│  • spacedRepetitionService - SRS scheduling                  │
│                                                              │
│  Quiz & Assessment:                                          │
│  • dailyQuizService (1038 LOC) - Daily quiz state machine    │
│  • chapterPracticeService - Topic practice sessions          │
│  • assessmentService - Initial 30-question diagnostic        │
│  • mockTestService - Full 90-question JEE simulation         │
│                                                              │
│  Subscription & Access:                                      │
│  • subscriptionService - Effective tier calculation (60s)    │
│  • tierConfigService - Tier limits & features (5m cache)     │
│  • usageTrackingService - Daily/monthly usage tracking       │
│                                                              │
│  Analytics & Progress:                                       │
│  • analyticsService - Dashboard metrics & overview           │
│  • progressService - Chapter/subject progress tracking       │
│  • adminMetricsService - Admin dashboard aggregations        │
│  • thetaSnapshotService - Historical theta snapshots         │
│                                                              │
│  AI & Content:                                               │
│  • aiTutorService - Conversational tutoring (Ultra tier)     │
│  • contentModerationService - Prompt injection prevention    │
│  • openai.js - OpenAI API wrapper (retries + rate limits)    │
│  • claude.js - Claude API wrapper (fallbacks + errors)       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│            Firebase Firestore Database (NoSQL)               │
│                                                              │
│  In-Memory Caching:                                          │
│  • Tier config (5-minute TTL, global)                        │
│  • Subscription tier (60-second TTL, per-user)               │
│  • Generic cache (10-minute TTL, key-value)                  │
│                                                              │
│  Retry Logic:                                                │
│  • Max retries: 3                                            │
│  • Exponential backoff: 100ms → 5000ms                       │
│  • Retryable errors: UNAVAILABLE, DEADLINE_EXCEEDED, etc.    │
└─────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
backend/
├── src/
│   ├── config/              # Firebase admin initialization
│   ├── middleware/          # 9 middleware files (auth, rate limit, errors)
│   ├── routes/              # 15 API route handlers (~3K LOC)
│   ├── services/            # 81 service files (~24.7K LOC)
│   ├── utils/               # Utilities (cache, logger, validation)
│   └── prompts/             # AI tutor prompt templates
├── scripts/                 # DB migrations, cleanup, tier management
├── tests/                   # Unit + integration tests (384 tests passing)
└── package.json
```

**Key Metrics:**
- **81 service files** (~24,700 lines of code)
- **15 route handlers** (~3,000 LOC)
- **9 middleware files** (~1,500 LOC)
- **384 unit tests** (all passing as of 2026-02-13)

---

## Database Schema & Design

### Firestore Collection Architecture

```
Firestore Collections:
├── users/{userId}                          # User profile, theta, subscription
│   ├── daily_usage/{YYYY-MM-DD}           # Usage tracking (resets midnight IST)
│   ├── monthly_usage/{YYYY-MM}            # Monthly aggregations
│   ├── daily_quizzes/quizzes/{quizId}     # Quiz history
│   ├── chapter_practice/sessions/{sid}    # Practice sessions
│   ├── subscriptions/{subscriptionId}     # Payment subscriptions
│   ├── tutor_conversation/active/messages # AI Tutor chat history
│   └── chapter_practice_weekly/{subject}  # Weekly chapter rotation (Free tier)
│
├── questions/                              # Master question bank (~5K questions)
├── daily_quiz_questions/                   # Daily quiz pool (subset)
├── assessment_responses/{userId}/responses # Initial assessment history
├── daily_quiz_responses/{userId}/responses # Daily quiz answers
├── mock_tests/{userId}/attempts            # Mock test history (90 Qs)
├── tier_config/active                      # Subscription tier configuration
├── promo_codes/                            # Promotional codes & discounts
└── practice_streaks/{userId}               # Current & longest streak
```

### User Document Schema

```javascript
// users/{userId}
{
  // Profile
  phone: "+919876543210",
  isEnrolledInCoaching: true,  // Affects chapter unlock schedule
  created_at: Timestamp,

  // Subscription
  tier: "free" | "pro" | "ultra",
  subscription: {
    override: { tier: "ultra", expires_at: Timestamp },  // Beta/promo
    status: "active" | "expired",
    start_date: Timestamp,
    end_date: Timestamp
  },
  trial: {
    is_active: true,
    tier: "pro" | "ultra",
    ends_at: Timestamp
  },
  trialEndsAt: Timestamp,  // Legacy field (migration remnant)

  // Theta Tracking (IRT scores)
  theta_by_chapter: {
    "physics_laws_of_motion": {
      theta: 0.5,           // Range: [-3, +3]
      se: 0.3,              // Standard error: [0.15, 0.6]
      questions_answered: 15
    },
    // ... ~50 chapters
  },
  theta_by_subject: {
    "physics": { theta: 0.4, se: 0.25 },
    "chemistry": { theta: 0.2, se: 0.28 },
    "mathematics": { theta: 0.6, se: 0.22 }
  },
  overall_theta: 0.4,
  overall_percentile: 65.2,  // Converted from theta via normal CDF

  // Progress
  progress: {
    overallAccuracy: 68.5,  // Current accuracy %
    subjectAccuracy: { physics: 65, chemistry: 70, mathematics: 72 }
  },
  accuracyHistory: [
    { timestamp: Timestamp, accuracy: 65.2 }
  ],

  // Assessment
  assessment_completed: true,
  assessment_results: { /* 30-question results */ }
}
```

### Question Document Schema

```javascript
// questions/{questionId}
{
  question_id: "PHY_LOM_001",
  subject: "Physics",
  chapter: "Laws of Motion",
  chapter_key: "physics_laws_of_motion",
  question_type: "mcq_single" | "numerical",
  difficulty: "easy" | "medium" | "hard",

  // Content
  question_text: "A block of mass 5 kg...",
  question_text_html: "<p>A block...</p>",
  options: [
    { option_id: "A", text: "10 N", html: "<p>10 N</p>" },
    { option_id: "B", text: "20 N", html: "<p>20 N</p>" },
    { option_id: "C", text: "30 N", html: "<p>30 N</p>" },
    { option_id: "D", text: "40 N", html: "<p>40 N</p>" }
  ],
  correct_answer: "B",

  // Solution
  solution_text: "Using F = ma...",
  solution_steps: [
    { step_number: 1, description: "...", formula: "..." }
  ],
  key_insight: "Direct application of Newton's second law",
  common_mistakes: ["Dividing mass by force instead of multiplying"],
  distractor_analysis: {
    "A": "Incorrect - forgot to multiply by acceleration",
    "C": "Incorrect - added mass and acceleration instead of multiplying",
    "D": "Incorrect - multiplied mass by wrong value"
  },

  // IRT Parameters (3-Parameter Logistic Model)
  irt_parameters: {
    difficulty_b: 0.8,      // Difficulty parameter [-3, +3]
    discrimination_a: 1.5,  // Discrimination [0.5, 2.5]
    guessing_c: 0.25        // Guessing parameter [0, 0.5]
  },

  // Metadata
  image_url: "gs://bucket/question-images/PHY_LOM_001.png",
  active: true,
  tags: ["newton_laws", "force", "acceleration"],
  created_at: Timestamp,
  last_used: Timestamp
}
```

### Daily Usage Tracking Schema

```javascript
// users/{userId}/daily_usage/{YYYY-MM-DD}
{
  date: "2026-02-13",
  snap_solve: 3,        // Used 3 out of 5 (free tier)
  daily_quiz: 1,        // Used 1 out of 1 (free tier)
  ai_tutor: 0,          // Disabled for free tier
  chapter_practice: 2,  // Used 2 chapters out of 5 (free tier)
  last_reset: Timestamp,
  created_at: Timestamp
}
```

**Design Strengths:**

✅ **Date-keyed documents** for natural midnight IST resets
✅ **Hierarchical theta tracking** (chapter → subject → overall)
✅ **Nested subcollections** avoid high-cardinality queries
✅ **Server timestamps** prevent clock skew issues
✅ **Soft deletes** (invalidated flags) preserve history
✅ **IRT parameters** stored directly with questions (no joins needed)

**Design Concerns:**

⚠️ **Trial data inconsistency**: Both `trial.ends_at` and `trialEndsAt` exist (migration remnant)
⚠️ **No composite indexes documented**: Risk of rejected queries
⚠️ **Chapter normalization scattered**: `formatChapterKey()` logic duplicated across services
⚠️ **Large user documents**: ~50 chapters × theta data could approach document size limits (1MB)

---

## Caching Architecture

### Three-Tier Caching Strategy

#### 1. Tier Configuration Cache (Global, 5-minute TTL)

```javascript
// File: tierConfigService.js
const cachedConfig = null;
const cacheTimestamp = null;
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

async function getTierConfig() {
  if (cachedConfig && Date.now() - cacheTimestamp < CACHE_TTL) {
    return cachedConfig;
  }

  // Fetch from Firestore tier_config/active
  const doc = await db.collection('tier_config').doc('active').get();
  cachedConfig = doc.data();
  cacheTimestamp = Date.now();

  return cachedConfig;
}
```

**Purpose:** Tier limits (snap_solve, daily_quiz, etc.) change rarely
**Impact:** Reduces Firestore reads by ~99% (from 1000s/day to ~288/day)
**Invalidation:** Manual via `invalidateTierConfigCache()` after admin changes

#### 2. Subscription Tier Cache (Per-user, 60-second TTL)

```javascript
// File: subscriptionService.js
const tierCache = new Map(); // { userId → { data, expiresAt } }

async function getEffectiveTier(userId) {
  const cached = tierCache.get(userId);
  if (cached && Date.now() < cached.expiresAt) {
    return cached.data;
  }

  // Priority chain: Override → Subscription → Trial → Free
  const tier = await calculateEffectiveTier(userId);
  tierCache.set(userId, { data: tier, expiresAt: Date.now() + 60000 });

  return tier;
}
```

**Purpose:** `getEffectiveTier()` called 100+ times per request (feature gating, usage checks)
**Impact:** Reduces redundant Firestore user doc reads by ~95%
**Invalidation:** Manual via `invalidateTierCache(userId)` after subscription changes

#### 3. Generic In-Memory Cache (10-minute default TTL)

```javascript
// File: utils/cache.js
const NodeCache = require('node-cache');
const cache = new NodeCache({
  stdTTL: 600,        // 10 minutes default
  checkperiod: 60,    // Check for expired keys every 60s
  maxKeys: 10000,
  maxSize: 10 * 1024 * 1024  // 10MB total size
});

// Key format: {env}:{category}:{id}
// Example: "production:question:PHY_LOM_001"
```

**Purpose:** Generic caching for questions, user profiles, etc.
**Usage:** Currently underutilized (mostly manual caching in services)

### Caching Concerns

🔴 **CRITICAL: Single-instance caching breaks horizontal scaling**

```javascript
// Problem: All caches are in-memory within a single Node.js process
// If deployed to 3 instances:
// - Instance 1 has tierCache for user A
// - Instance 2 has no cache for user A
// - Instance 3 has stale cache for user A

// Result: Cache inconsistency across instances
```

**Impact:**
- Can't horizontally scale without distributed cache (Redis)
- Cache invalidation only affects single instance
- Tier changes may not propagate to all instances for 60 seconds

🟠 **HIGH: Manual cache invalidation is error-prone**

```javascript
// Cache invalidation is scattered across codebase:
// 1. subscriptionService.js (override grant/revoke)
// 2. trialService.js (trial expiry)
// 3. Admin routes (manual tier changes)
// 4. manage-tier.js script

// Risk: If developer forgets to call invalidateTierCache(),
// user keeps old tier for 60 seconds
```

**Recommendation:**
1. **P0:** Implement distributed cache (Redis) for horizontal scaling
2. **P1:** Centralize cache invalidation via event system (Pub/Sub or Redis channels)
3. **P2:** Add cache hit/miss metrics to monitor effectiveness

---

## IRT-Based Adaptive Learning Engine

### Item Response Theory (IRT) Implementation

JEEVibe implements the **3-Parameter Logistic (3PL) model** for adaptive question selection and student ability tracking.

#### 3PL Probability Formula

```javascript
// Probability student with ability θ answers question correctly
P(θ) = c + (1 - c) / (1 + e^(-1.702 * a * (θ - b)))

where:
  θ (theta) = Student ability [-3, +3]
  b = Question difficulty [-3, +3]
  a = Discrimination parameter [0.5, 2.5]
  c = Guessing parameter [0, 0.5] (typically 0.25 for 4-option MCQ)
```

**Example:**
- Student theta = 0.5
- Question difficulty b = 0.8
- Discrimination a = 1.5
- Guessing c = 0.25

```javascript
P(0.5) = 0.25 + (0.75) / (1 + e^(-1.702 * 1.5 * (0.5 - 0.8)))
       = 0.25 + 0.75 / (1 + e^(0.765))
       = 0.25 + 0.75 / 3.147
       = 0.488 (48.8% probability of correct answer)
```

### Question Selection Algorithm

```javascript
// File: questionSelectionService.js

async function selectNextQuestion(userId, subject, chapterKey, previousQuestionIds) {
  // 1. Get student's current theta for this chapter
  const userDoc = await db.collection('users').doc(userId).get();
  const chapterTheta = userDoc.data().theta_by_chapter[chapterKey]?.theta || 0;

  // 2. Filter question pool
  const questions = await db.collection('questions')
    .where('chapter_key', '==', chapterKey)
    .where('active', '==', true)
    .get();

  // 3. Remove recently shown questions (last 30 days)
  const candidates = questions.filter(q =>
    !previousQuestionIds.includes(q.question_id) &&
    !wasShownRecently(userId, q.question_id, 30)
  );

  // 4. Match difficulty (adaptive threshold based on pool size)
  const poolSize = candidates.length;
  const threshold = poolSize > 100 ? 0.5 : poolSize > 50 ? 0.8 : 1.2;

  const matched = candidates.filter(q =>
    Math.abs(q.irt_parameters.difficulty_b - chapterTheta) <= threshold
  );

  // 5. Calculate Fisher Information for each candidate
  const scored = matched.map(q => ({
    question: q,
    information: calculateFisherInformation(chapterTheta, q.irt_parameters)
  }));

  // 6. Select question with highest information × discrimination
  scored.sort((a, b) =>
    (b.information * b.question.irt_parameters.discrimination_a) -
    (a.information * a.question.irt_parameters.discrimination_a)
  );

  return scored[0].question;
}
```

**Key Features:**
- ✅ Adaptive difficulty thresholds (tight when many questions, loose when few)
- ✅ Fisher Information maximization (most informative question)
- ✅ Recency filtering (no repeated questions within 30 days)
- ✅ Discrimination weighting (prioritize high-discrimination questions)

### Theta Update Algorithm

```javascript
// File: thetaUpdateService.js

async function updateTheta(userId, questionId, isCorrect, timeTaken) {
  const userDoc = await db.collection('users').doc(userId).get();
  const questionDoc = await db.collection('questions').doc(questionId).get();

  const { difficulty_b, discrimination_a, guessing_c } = questionDoc.data().irt_parameters;
  const chapterKey = questionDoc.data().chapter_key;
  const currentTheta = userDoc.data().theta_by_chapter[chapterKey]?.theta || 0;
  const currentSE = userDoc.data().theta_by_chapter[chapterKey]?.se || 0.6;

  // Bayesian update using gradient descent
  const probability = guessing_c + (1 - guessing_c) /
    (1 + Math.exp(-1.702 * discrimination_a * (currentTheta - difficulty_b)));

  const learningRate = 0.1;
  const residual = (isCorrect ? 1 : 0) - probability;
  const thetaChange = learningRate * residual * discrimination_a;

  const newTheta = clamp(currentTheta + thetaChange, -3, 3);
  const newSE = clamp(currentSE * 0.95, 0.15, 0.6); // SE decreases over time

  // Update chapter theta
  await db.runTransaction(async (transaction) => {
    // 1. Update chapter-level theta
    transaction.update(userRef, {
      [`theta_by_chapter.${chapterKey}.theta`]: newTheta,
      [`theta_by_chapter.${chapterKey}.se`]: newSE,
      [`theta_by_chapter.${chapterKey}.questions_answered`]:
        FieldValue.increment(1)
    });

    // 2. Recalculate subject theta (weighted average of chapters)
    const subjectTheta = calculateSubjectTheta(
      userDoc.data().theta_by_chapter,
      subject
    );
    transaction.update(userRef, {
      [`theta_by_subject.${subject}.theta`]: subjectTheta
    });

    // 3. Recalculate overall theta (weighted average of subjects)
    const overallTheta = calculateOverallTheta(
      userDoc.data().theta_by_subject
    );
    const overallPercentile = thetaToPercentile(overallTheta);

    transaction.update(userRef, {
      overall_theta: overallTheta,
      overall_percentile: overallPercentile
    });
  });
}
```

**Key Features:**
- ✅ Bayesian gradient descent update (statistically sound)
- ✅ Standard Error (SE) decreases over time (confidence increases)
- ✅ Multi-level updates in single transaction (chapter → subject → overall)
- ✅ JEE-weighted chapter importance factors

**Concern:**
⚠️ Transaction may approach **25-write limit** for users with many chapters updated simultaneously

### Percentile Conversion

```javascript
// File: thetaUpdateService.js (Fixed 2026-02-09)

function thetaToPercentile(theta) {
  // Proper normal CDF using Abramowitz & Stegun approximation
  // Error < 1.5e-7

  const z = theta; // Assume theta ~ N(0, 1)

  if (z < 0) {
    return 100 * (1 - normalCDF(-z));
  }

  const t = 1 / (1 + 0.2316419 * z);
  const poly = t * (0.319381530 + t * (-0.356563782 + t *
    (1.781477937 + t * (-1.821255978 + t * 1.330274429))));

  const cdf = 1 - (1 / Math.sqrt(2 * Math.PI)) * Math.exp(-z * z / 2) * poly;
  return Math.round(cdf * 100);
}
```

**Impact of Fix:**
- Theta -0.2 → 42% (was 49% with old formula)
- Theta 1.0 → 84% (was 70% with old formula)
- Now matches standard normal distribution exactly

---

## API Architecture

### API Endpoint Organization

```
/api
├── /auth                    # Authentication & sessions
│   ├── POST /session        # Login (create session)
│   ├── GET /session         # Get current session
│   └── POST /logout         # Logout
│
├── /daily-quiz              # Daily adaptive quiz (1 quiz/day Free)
│   ├── POST /generate       # Generate today's quiz
│   ├── POST /start          # Start quiz session
│   ├── POST /submit-answer  # Submit single answer
│   ├── POST /complete       # Complete quiz
│   └── GET /history         # Quiz history
│
├── /chapter-practice        # Chapter-specific practice (5/day Free)
│   ├── POST /generate       # Generate practice session
│   ├── POST /submit-answer  # Submit answer
│   └── POST /complete       # Complete session
│
├── /assessment              # Initial 30-question assessment
│   ├── GET /questions       # Get assessment questions
│   ├── POST /submit         # Submit all answers
│   └── GET /results         # Get results
│
├── /mock-tests              # Full JEE simulation (90 Qs, 3 hrs)
│   ├── GET /available       # Available mock tests
│   ├── GET /active          # Active test for user
│   ├── POST /start          # Start mock test
│   ├── POST /save-answer    # Save answer (can change)
│   └── POST /submit         # Submit entire test
│
├── /analytics               # Progress analytics
│   ├── GET /overview        # Dashboard overview
│   ├── GET /mastery/:subject # Subject mastery details
│   ├── GET /mastery-timeline # Historical progression
│   └── GET /all-chapters    # All chapters status
│
├── /subscriptions           # Subscription & tier management
│   ├── GET /status          # Tier + usage limits
│   ├── GET /plans           # Available plans
│   └── GET /usage           # Usage breakdown
│
├── /solve                   # Snap & Solve (image upload)
│   ├── POST /               # Upload image + get solution
│   └── GET /snap-history    # Solution history
│
├── /admin                   # Admin dashboard (admin auth required)
│   ├── GET /users           # List all users
│   ├── GET /users/:userId   # User details
│   ├── POST /users/:userId/tier # Override tier
│   └── GET /metrics         # System metrics
│
└── /health                  # Health check (no auth, no rate limit)
```

### Response Format Standardization

All API endpoints follow this response format:

```javascript
// Success response
{
  success: true,
  data: { /* endpoint-specific data */ },
  requestId: "uuid-v4",
  timestamp: "2026-02-13T10:30:00.000Z"
}

// Error response
{
  success: false,
  error: {
    code: "VALIDATION_ERROR" | "TIER_LIMIT_EXCEEDED" | "QUESTION_NOT_FOUND" | ...,
    message: "Human-readable error message",
    details: { /* optional error details */ }
  },
  requestId: "uuid-v4",
  timestamp: "2026-02-13T10:30:00.000Z"
}
```

**Error Codes:**
- `VALIDATION_ERROR` - Invalid request parameters
- `TIER_LIMIT_EXCEEDED` - Daily/monthly limit reached
- `QUESTION_NOT_FOUND` - Question ID doesn't exist
- `ASSESSMENT_ALREADY_COMPLETED` - Cannot retake assessment
- `QUIZ_ALREADY_ACTIVE` - Complete current quiz first
- `UNAUTHORIZED` - Invalid or missing auth token
- `FEATURE_NOT_AVAILABLE` - Feature not in user's tier

### Rate Limiting Configuration

```javascript
// File: middleware/rateLimiter.js

// 1. API-wide rate limit (applies to all /api/* routes)
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 100,                   // 100 requests per IP
  message: {
    success: false,
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many requests, please try again later'
    }
  }
});

// 2. Strict rate limit (expensive operations)
const strictLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,  // 1 hour
  max: 10,                    // 10 requests per IP
  message: {
    success: false,
    error: {
      code: 'STRICT_LIMIT_EXCEEDED',
      message: 'Too many submissions, please wait before trying again'
    }
  }
});

// 3. Image processing rate limit (Snap & Solve)
const imageProcessingLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,  // 1 hour
  max: 20,                    // 20 image uploads per IP
  message: {
    success: false,
    error: {
      code: 'IMAGE_LIMIT_EXCEEDED',
      message: 'Too many image uploads, please try again later'
    }
  }
});
```

**⚠️ Concern: IP-based rate limiting**

In production with mobile networks (NAT, carrier-grade NAT), multiple legitimate users share the same public IP. This can cause:
- False positives (blocking legitimate users in same network)
- Reduced limits per user (if 10 users share 1 IP, each gets 10% of limit)

**Recommendation:**
Implement **user-based rate limiting** after authentication:

```javascript
// Improved rate limiting strategy
const getUserId = (req) => req.userId || req.ip;

const userRateLimiter = rateLimit({
  keyGenerator: getUserId,  // Use userId if authenticated, else IP
  windowMs: 15 * 60 * 1000,
  max: (req, res) => {
    if (req.userId) return 100;  // Authenticated users: 100/15min
    return 20;                    // Anonymous users: 20/15min
  }
});
```

---

## Critical Issues

### 🔴 P0 (Critical - Fix Immediately)

#### 1. Session Validation Completely Disabled

**File:** `src/index.js` line 233

```javascript
// ⚠️ Session validation DISABLED temporarily - breaks login flow
// TODO: Re-enable after investigating why it prevents login
// app.use(sessionValidator);
```

**Impact:**
- Single-device enforcement (P1 security feature) is not active
- Users can have unlimited simultaneous sessions across devices
- No session expiry or invalidation

**Root Cause:** Unknown - marked as "breaks login flow"

**Recommendation:**
1. Investigate why `sessionValidator` middleware breaks login
2. Likely causes:
   - Session created after validation check (timing issue)
   - Session token not passed correctly in auth flow
   - Firebase Auth token vs custom session token mismatch
3. Fix underlying issue and re-enable
4. If intentionally disabled, remove middleware code and document decision

---

#### 2. Trial Expiry Race Condition

**File:** `src/services/subscriptionService.js` lines 245-246

```javascript
async function getEffectiveTier(userId) {
  // ... check override, subscription ...

  // Check for active trial
  if (userData.trial?.is_active && trialEndsAt > now) {
    return {
      tier: userData.trial.tier || 'pro',
      source: 'trial',
      expiresAt: trialEndsAt
    };
  }

  // If trial expired, expire it asynchronously (NOT AWAITED!)
  if (userData.trial?.is_active && trialEndsAt <= now) {
    expireTrialAsync(userId);  // ⚠️ NOT AWAITED
    return { tier: 'free', source: 'default' };
  }
}

// Separate async function (fires and forgets)
async function expireTrialAsync(userId) {
  await db.collection('users').doc(userId).update({
    'trial.is_active': false
  });
}
```

**Impact:**
1. User's trial expires at 2026-02-13 10:00:00
2. User makes request at 10:00:01
3. `getEffectiveTier()` detects expired trial, returns `tier: 'free'`
4. `expireTrialAsync()` starts updating Firestore
5. Second request arrives at 10:00:02
6. `getEffectiveTier()` reads from cache (60-second TTL)
7. **Cache still shows `trial.is_active = true`** (update not complete)
8. User gets premium access for up to 60 more seconds

**Root Cause:** Async update without awaiting + caching creates race condition

**Fix:**
```javascript
// Option 1: Await the expiry (blocks request but ensures consistency)
if (userData.trial?.is_active && trialEndsAt <= now) {
  await expireTrialAsync(userId);
  invalidateTierCache(userId);  // Clear cache immediately
  return { tier: 'free', source: 'default' };
}

// Option 2: Use task queue (better for production)
if (userData.trial?.is_active && trialEndsAt <= now) {
  await queueTrialExpiryTask(userId);  // Pub/Sub or Cloud Tasks
  invalidateTierCache(userId);
  return { tier: 'free', source: 'default' };
}
```

---

#### 3. Missing Firestore Composite Indexes

**Risk:** Firestore rejects queries that require composite indexes not created

**Evidence:** No `.indexes.json` file found in repository

**Queries Requiring Indexes:**

```javascript
// 1. Question selection by chapter + difficulty
db.collection('questions')
  .where('chapter_key', '==', 'physics_laws_of_motion')
  .where('active', '==', true)
  .orderBy('irt_parameters.difficulty_b')
  .limit(50)
// Index: questions (chapter_key ASC, active ASC, irt_parameters.difficulty_b ASC)

// 2. Quiz history by user + date
db.collection('daily_quiz_responses')
  .where('user_id', '==', userId)
  .orderBy('answered_at', 'desc')
  .limit(30)
// Index: daily_quiz_responses (user_id ASC, answered_at DESC)

// 3. Chapter practice sessions by user + status
db.collection('users').doc(userId)
  .collection('chapter_practice')
  .where('status', '==', 'active')
  .orderBy('created_at', 'desc')
// Index: chapter_practice (status ASC, created_at DESC)
```

**Action:**
1. Check Firestore Console for "Index Required" errors
2. Create `.indexes.json` file with all required composite indexes
3. Deploy indexes: `firebase deploy --only firestore:indexes`

---

#### 4. Distributed Cache Invalidation

**Problem:** Tier cache invalidation only affects single instance

```javascript
// Current behavior (single instance):
invalidateTierCache(userId) → tierCache.delete(userId) → ✅ Works

// With 3 instances behind load balancer:
Instance 1: invalidateTierCache(userId) → Cache cleared on Instance 1 only
Instance 2: tierCache still has stale data for 60 seconds
Instance 3: tierCache still has stale data for 60 seconds

// User hits Instance 2 → Gets old tier for 60 seconds
```

**Impact:**
- Tier changes (subscription purchase, trial expiry, admin override) don't propagate immediately
- Users may get wrong tier access for up to 60 seconds across instances

**Fix Options:**

**Option 1: Redis Pub/Sub (Recommended)**
```javascript
// When tier changes:
await redisClient.publish('tier-invalidation', JSON.stringify({ userId }));

// All instances subscribe:
redisClient.subscribe('tier-invalidation', (message) => {
  const { userId } = JSON.parse(message);
  tierCache.delete(userId);
});
```

**Option 2: Firestore Listeners (Not Recommended - High Cost)**
```javascript
// Each instance listens to user doc changes
db.collection('users').doc(userId).onSnapshot((snapshot) => {
  invalidateTierCache(userId);
});
// Problem: 1000 users × 3 instances = 3000 real-time listeners
```

**Option 3: Sticky Sessions (Temporary Workaround)**
```javascript
// Route users to same instance based on userId hash
// Pros: No infrastructure change
// Cons: Uneven load distribution, doesn't fully solve problem
```

---

### 🟠 P1 (High - Address Before Production Scaling)

#### 5. User-Based Rate Limiting

**Current:** Rate limiting is IP-based
**Problem:** Mobile networks (NAT) group many users under single IP
**Impact:** Legitimate users hit rate limits prematurely

**Recommendation:**
```javascript
// Hybrid approach: Use userId if authenticated, else IP
const getUserKey = (req) => req.userId || req.ip;

const smartRateLimiter = rateLimit({
  keyGenerator: getUserKey,
  windowMs: 15 * 60 * 1000,
  max: (req) => {
    if (req.userId) {
      // Authenticated users: Higher limits
      const tierLimits = { free: 100, pro: 500, ultra: 1000 };
      return tierLimits[req.userTier] || 100;
    }
    // Anonymous/IP-based: Lower limits
    return 20;
  }
});
```

---

#### 6. Large Service Files (Code Organization)

**Files Exceeding 1000 LOC:**

| File | Lines | Recommendation |
|------|-------|----------------|
| `dailyQuizService.js` | 1,038 | Split into: QuizGeneration, QuizSubmission, QuizHistory |
| `mockTestService.js` | 1,055 | Split into: TestGeneration, TestExecution, TestScoring |
| `analyticsService.js` | 925 | Split into: OverviewAnalytics, SubjectAnalytics, ChapterAnalytics |
| `adminMetricsService.js` | 863 | Split into: UserMetrics, SystemMetrics, AggregationMetrics |
| `contentModerationService.js` | 801 | OK (single-purpose service) |

**Impact:**
- Harder to test individual functions
- Increased merge conflict risk
- Slower code comprehension for new developers

**Refactoring Pattern:**
```javascript
// Before: dailyQuizService.js (1038 LOC)
module.exports = {
  generateDailyQuiz,
  startDailyQuiz,
  submitQuizAnswer,
  completeQuiz,
  getQuizHistory,
  // ... 20+ more functions
};

// After: Split into modules
services/dailyQuiz/
├── index.js           // Exports all functions
├── generation.js      // generateDailyQuiz, selectQuestions
├── submission.js      // submitQuizAnswer, validateAnswer
├── completion.js      // completeQuiz, calculateScore
└── history.js         // getQuizHistory, getQuizStats
```

---

#### 7. Chapter Normalization Logic Duplication

**Problem:** `formatChapterKey()` logic is duplicated across multiple services

**Found in:**
- `thetaCalculationService.js` (lines 50-65)
- `assessmentService.js` (lines 30-45)
- `chapterPracticeService.js` (lines 25-40)
- `questionSelectionService.js` (lines 15-30)

**Current Implementation (duplicated):**
```javascript
function formatChapterKey(chapterName) {
  return chapterName
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')  // Replace non-alphanumeric with underscore
    .replace(/^_+|_+$/g, '')       // Trim leading/trailing underscores
    .replace(/_+/g, '_');          // Collapse multiple underscores
}
```

**Impact:**
- Inconsistent normalization if implementations drift
- Already caused bugs: `'laws_of_motion'` vs `'lawsofmotion'` (see test fix 2026-02-13)
- Hard to update normalization rules

**Fix:**
```javascript
// Create: src/utils/chapterKeyFormatter.js
module.exports = {
  formatChapterKey,
  normalizeSubjectName,
  // Centralized chapter mapping logic
};

// Update all services to import from centralized utility
```

---

#### 8. Email Service Idempotency

**Files:** `studentEmailService.js`, `teacherEmailService.js`

**Problem:** No deduplication if email sending is retried

```javascript
async function sendWelcomeEmail(userId, email) {
  // No check if email already sent
  await sendEmail({
    to: email,
    subject: 'Welcome to JEEVibe',
    template: 'welcome'
  });
}
```

**Scenario:**
1. API request to send welcome email
2. Email sent successfully
3. API timeout before response returned
4. Client retries request
5. **Duplicate email sent**

**Fix:**
```javascript
// Add idempotency key tracking
async function sendWelcomeEmail(userId, email, idempotencyKey) {
  const sentKey = `email:welcome:${userId}`;

  // Check if already sent
  const alreadySent = await cache.get(sentKey);
  if (alreadySent) {
    return { success: true, alreadySent: true };
  }

  await sendEmail({ to: email, subject: 'Welcome to JEEVibe' });

  // Mark as sent (7-day TTL)
  await cache.set(sentKey, true, 7 * 24 * 60 * 60);

  return { success: true, alreadySent: false };
}
```

---

### 🟡 P2 (Medium - Performance & Scalability)

#### 9. N+1 Query Risk in Analytics Service

**File:** `analyticsService.js`

```javascript
async function getAnalyticsOverview(userId) {
  // Single user doc read ✅
  const userDoc = await db.collection('users').doc(userId).get();
  const thetaByChapter = userDoc.data().theta_by_chapter;

  // ⚠️ Potential N+1: If fetching chapter details separately
  const chapterDetails = [];
  for (const chapterKey in thetaByChapter) {
    // This would be N+1 if we fetch chapter metadata individually
    const chapterMeta = await getChapterMetadata(chapterKey);  // ⚠️
    chapterDetails.push({ ...thetaByChapter[chapterKey], ...chapterMeta });
  }

  return { chapters: chapterDetails };
}
```

**Fix:**
```javascript
// Batch read all chapter metadata at once
const chapterKeys = Object.keys(thetaByChapter);
const chapterMetaBatch = await db.collection('chapters')
  .where('chapter_key', 'in', chapterKeys.slice(0, 10))  // Firestore 'in' limit: 10
  .get();

// For more than 10 chapters, batch in groups of 10
const allChapterMeta = await Promise.all(
  chunk(chapterKeys, 10).map(batch =>
    db.collection('chapters').where('chapter_key', 'in', batch).get()
  )
);
```

**Note:** Code review indicates this is already partially fixed with comment "FIX N+1 QUERY: Batch read all questions at once"

---

#### 10. Mock Test Question Validation

**File:** `mockTestService.js`

```javascript
async function startMockTest(userId, testTemplateId) {
  // Assumes JSON file was pre-loaded into Firestore
  const template = await db.collection('mock_test_templates')
    .doc(testTemplateId)
    .get();

  // ⚠️ No validation that all 90 questions are present
  const questions = template.data().questions; // Assumes length === 90

  return { testId, questions };
}
```

**Risk:** Incomplete tests if question upload failed

**Fix:**
```javascript
async function startMockTest(userId, testTemplateId) {
  const template = await db.collection('mock_test_templates')
    .doc(testTemplateId)
    .get();

  const questions = template.data().questions;

  // Validate test structure
  if (questions.length !== 90) {
    throw new ApiError(500, 'INVALID_TEST_TEMPLATE',
      `Expected 90 questions, found ${questions.length}`);
  }

  // Validate subject distribution
  const subjectCounts = {
    physics: questions.filter(q => q.subject === 'Physics').length,
    chemistry: questions.filter(q => q.subject === 'Chemistry').length,
    mathematics: questions.filter(q => q.subject === 'Mathematics').length
  };

  if (subjectCounts.physics !== 30 ||
      subjectCounts.chemistry !== 30 ||
      subjectCounts.mathematics !== 30) {
    throw new ApiError(500, 'INVALID_TEST_DISTRIBUTION',
      `Expected 30 questions per subject, got ${JSON.stringify(subjectCounts)}`);
  }

  return { testId, questions };
}
```

---

#### 11. Theta Update Transaction Size

**File:** `thetaUpdateService.js`

**Concern:** Updating many chapters in single transaction may approach 25-write limit

```javascript
async function updateTheta(userId, responses) {
  await db.runTransaction(async (transaction) => {
    // For each response (could be 30 for assessment):
    for (const response of responses) {
      // 1. Update chapter theta (1 write)
      transaction.update(userRef, {
        [`theta_by_chapter.${chapterKey}.theta`]: newTheta
      });

      // 2. Update subject theta (1 write per subject)
      transaction.update(userRef, {
        [`theta_by_subject.${subject}.theta`]: subjectTheta
      });

      // 3. Update overall theta (1 write)
      transaction.update(userRef, {
        overall_theta: overallTheta
      });
    }
    // Total: 30 responses × 3 updates = 90 writes ⚠️ EXCEEDS LIMIT
  });
}
```

**Firestore Limit:** Maximum **25 writes per transaction**

**Fix:**
```javascript
// Aggregate updates before transaction
async function updateTheta(userId, responses) {
  const updates = {};

  // Calculate all theta changes first
  for (const response of responses) {
    const { chapterKey, subject } = response;
    updates[`theta_by_chapter.${chapterKey}.theta`] = calculateNewTheta(response);
  }

  // Recalculate subject and overall theta
  updates['theta_by_subject.physics.theta'] = aggregateSubjectTheta('physics');
  updates['theta_by_subject.chemistry.theta'] = aggregateSubjectTheta('chemistry');
  updates['theta_by_subject.mathematics.theta'] = aggregateSubjectTheta('mathematics');
  updates['overall_theta'] = aggregateOverallTheta();

  // Single transaction with aggregated updates
  await db.runTransaction(async (transaction) => {
    transaction.update(userRef, updates);  // 1 write with all updates
  });
}
```

---

## Security Assessment

### Authentication & Authorization

#### Token Validation Flow

```javascript
// middleware/auth.js
async function authenticateUser(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');

  if (!token) {
    return res.status(401).json({
      success: false,
      error: { code: 'UNAUTHORIZED', message: 'No auth token provided' }
    });
  }

  try {
    // Verify Firebase ID token
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.userId = decodedToken.uid;
    req.userPhone = decodedToken.phone_number;
    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      error: { code: 'INVALID_TOKEN', message: 'Invalid or expired token' }
    });
  }
}
```

**✅ Strengths:**
- Uses Firebase Auth token verification (cryptographically secure)
- Token expiry handled automatically by Firebase
- No custom JWT implementation (reduces security risk)

**⚠️ Concerns:**
- Session validation disabled (see Critical Issue #1)
- No token refresh mechanism documented
- No protection against token theft (would need device fingerprinting)

---

### Input Validation

```javascript
// Example: Daily quiz submission validation
const { body, validationResult } = require('express-validator');

router.post('/submit-answer', [
  authenticateUser,

  // Validation rules
  body('quiz_id')
    .isString()
    .isLength({ min: 1, max: 100 })
    .matches(/^[a-zA-Z0-9_-]+$/),

  body('question_id')
    .isString()
    .isLength({ min: 1, max: 100 }),

  body('student_answer')
    .isString()
    .isLength({ min: 1, max: 10 }),

  body('time_taken_seconds')
    .isInt({ min: 0, max: 3600 }),

], async (req, res, next) => {
  // Check validation errors
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid request parameters',
        details: errors.array()
      }
    });
  }

  // Continue to handler...
});
```

**✅ Strengths:**
- Express-validator used for type checking and sanitization
- Custom validators for domain-specific rules (chapter keys, question IDs)
- Length limits prevent oversized payloads
- Regex patterns prevent injection attacks

**⚠️ Concerns:**
- No validation of LaTeX content in user-generated input (AI Tutor questions)
- File upload validation unclear (Snap & Solve image uploads)

---

### Content Moderation (AI Tutor)

```javascript
// File: contentModerationService.js (801 LOC)

async function moderateUserMessage(message) {
  // 1. Prompt injection detection
  const promptInjectionPatterns = [
    /ignore (all )?previous instructions/i,
    /you are now|act as/i,
    /system prompt/i,
    /\[INST\]|\[\/INST\]/i,  // Llama/Mistral instruction tags
    /###\s*(System|User|Assistant)/i
  ];

  for (const pattern of promptInjectionPatterns) {
    if (pattern.test(message)) {
      throw new ApiError(400, 'INAPPROPRIATE_CONTENT',
        'Message contains prohibited content');
    }
  }

  // 2. LLM-based content moderation
  const moderationResult = await openai.moderations.create({
    input: message
  });

  if (moderationResult.results[0].flagged) {
    throw new ApiError(400, 'INAPPROPRIATE_CONTENT',
      'Message flagged by content moderation');
  }

  // 3. Subject relevance check
  const subjects = ['physics', 'chemistry', 'mathematics', 'jee'];
  const isRelevant = subjects.some(s => message.toLowerCase().includes(s));

  if (!isRelevant && message.length > 100) {
    // Long message not about JEE subjects
    throw new ApiError(400, 'OFF_TOPIC',
      'Please ask questions related to JEE Physics/Chemistry/Mathematics');
  }

  return { safe: true };
}
```

**✅ Strengths:**
- Multi-layer moderation (regex + LLM + subject relevance)
- Prevents prompt injection attacks
- Uses OpenAI Moderation API for hate speech, violence, etc.

**⚠️ Concerns:**
- Regex patterns can be bypassed with Unicode tricks (`ıgnore`, `ІGNORE` with Cyrillic)
- No rate limiting on AI Tutor specifically (only tier-based daily limits)
- No cost protection if user sends 1000-word messages repeatedly

---

### Error Handling & Information Disclosure

```javascript
// middleware/errorHandler.js

function errorHandler(err, req, res, next) {
  // Log full error server-side
  logger.error('API Error', {
    error: err.message,
    stack: err.stack,
    requestId: req.id,
    userId: req.userId,
    path: req.path
  });

  // Sanitize error for client response
  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({
      success: false,
      error: {
        code: err.code,
        message: err.message,
        // ✅ GOOD: No stack trace or internal details
      },
      requestId: req.id
    });
  }

  // Unknown errors: Generic message
  return res.status(500).json({
    success: false,
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred',  // ✅ GOOD: No details leaked
    },
    requestId: req.id
  });
}
```

**✅ Strengths:**
- No stack traces or internal paths leaked to clients
- Generic error messages for unhandled exceptions
- Request IDs for correlation (safe to expose)

---

### Sentry Integration (Error Tracking)

```javascript
// Sensitive data filtering
Sentry.init({
  beforeSend(event, hint) {
    // Remove sensitive headers
    if (event.request?.headers) {
      delete event.request.headers['authorization'];
      delete event.request.headers['cookie'];
    }

    // Remove sensitive body fields
    if (event.request?.data) {
      const sensitiveFields = ['password', 'token', 'apiKey'];
      sensitiveFields.forEach(field => {
        if (event.request.data[field]) {
          event.request.data[field] = '[REDACTED]';
        }
      });
    }

    return event;
  }
});
```

**✅ Strengths:**
- Authorization tokens removed before sending to Sentry
- Password fields redacted
- Sampling rate (10% in production) reduces data leakage risk

---

## Performance & Scalability

### Current Performance Optimizations

| Optimization | Implementation | Impact |
|--------------|----------------|--------|
| **Tier Config Caching** | 5-minute in-memory cache | 99% reduction in Firestore reads |
| **Subscription Tier Caching** | 60-second per-user cache | 95% reduction in user doc reads |
| **Gzip Compression** | `compression()` middleware | ~70% response size reduction |
| **Body Size Limits** | 1MB limit on JSON/form data | Prevents large payload DoS |
| **Firestore Retries** | Exponential backoff (3 retries) | Handles transient failures |
| **Question Selection Batching** | Single query with filters | Avoids N+1 queries |
| **Transaction Usage** | Atomic updates for critical ops | Prevents race conditions |

---

### Scalability Bottlenecks

#### 1. Single-Instance In-Memory Caching

**Current State:**
- All caches stored in Node.js process memory
- Works perfectly for single instance
- **Breaks with horizontal scaling** (2+ instances)

**Problem Scenarios:**

```
Scenario A: Cache Inconsistency
─────────────────────────────────
Instance 1: User A tier cache → "pro"
Instance 2: No cache for User A
Instance 3: No cache for User A

Request 1 → Instance 1 → Cache hit → "pro" ✅
Request 2 → Instance 2 → Cache miss → Firestore read → "pro" ✅
Request 3 → Instance 3 → Cache miss → Firestore read → "pro" ✅

Tier changes to "ultra":
Instance 1: invalidateTierCache() → Cache cleared
Instance 2: Still has no cache (will re-read "ultra") ✅
Instance 3: Still has no cache (will re-read "ultra") ✅

BUT if Instance 2/3 had cached "pro" before change:
Request 4 → Instance 2 → Cache hit → "pro" ❌ (Stale for 60s)
```

```
Scenario B: Cache Stampede
────────────────────────────
10,000 users hit app simultaneously
Load balancer distributes across 3 instances
Each instance has empty cache

Instance 1: 3,333 users → 3,333 Firestore reads
Instance 2: 3,334 users → 3,334 Firestore reads
Instance 3: 3,333 users → 3,333 Firestore reads
Total: 10,000 Firestore reads in first 60 seconds

With shared cache (Redis):
First request per user → Cache miss → Firestore read → Cache set
Subsequent requests → Cache hit
Total: ~10,000 Firestore reads (spread over time), but shared across instances
```

**Solution: Redis Migration**

```javascript
// Current (in-memory):
const tierCache = new Map();
tierCache.set(userId, { tier: 'pro', expiresAt: Date.now() + 60000 });

// Migrated (Redis):
const redis = require('redis').createClient();
await redis.setex(`tier:${userId}`, 60, JSON.stringify({ tier: 'pro' }));

// Invalidation (broadcasted to all instances):
await redis.del(`tier:${userId}`);
redis.publish('tier-invalidation', userId);  // All instances receive
```

---

#### 2. Transaction Write Limits

**Firestore Constraint:** Max **25 writes per transaction**

**At-Risk Operations:**
- Assessment submission (30 questions → 30 chapter theta updates)
- Bulk theta recalculation (admin operations)

**Current Workaround:** Aggregate updates into single write (see Recommendation #11)

---

#### 3. Rate Limiting Collision (IP-based)

**Problem:** Mobile carriers use NAT (many users → 1 public IP)

**Example:**
- Jio network in Mumbai: 1000 users share 10 public IPs
- Each IP gets 100 requests/15min
- 100 users per IP = 1 request per user per 15min ❌

**Impact:** Legitimate users blocked during peak hours (6-9 PM IST)

**Solution:** User-based rate limiting (see Recommendation #5)

---

#### 4. Large User Documents

**Current Size:**
- User doc: ~50 chapters × theta data
- Each chapter: `{ theta, se, questions_answered, last_updated }`
- Approximate size: 50 × 100 bytes = 5 KB

**Firestore Limit:** 1 MB per document

**At Risk:**
- Users with 200+ chapter practice sessions (future expansion)
- Adding more metadata (solution history, practice patterns)

**Recommendation:**
- Move `theta_by_chapter` to subcollection: `users/{userId}/theta_chapters/{chapterKey}`
- Keep only `overall_theta` and `theta_by_subject` in main user doc
- Use batch reads when full theta data needed

---

### Load Testing Recommendations

**Target Metrics:**
- 10,000 daily active users
- 50,000 API requests/day (~0.6 requests/second average, ~10 req/s peak)
- 95th percentile latency < 500ms
- 99th percentile latency < 1000ms

**Test Scenarios:**

1. **Tier Cache Stress Test**
   - Simulate 1000 simultaneous logins
   - Measure Firestore reads (should be ~1000, not 100,000)

2. **Rate Limiter Test**
   - Simulate 200 users from same IP
   - Verify legitimate users not blocked

3. **Theta Update Concurrency**
   - Submit 100 quiz answers simultaneously for same user
   - Verify no theta updates lost (transaction rollback detection)

4. **Mock Test Load**
   - 100 users start 90-question tests simultaneously
   - Measure question loading latency
   - Check for memory leaks (large payloads)

---

## Recommendations Summary

### 🔴 P0 (Critical - Fix Immediately)

| # | Issue | Impact | Effort | Timeline |
|---|-------|--------|--------|----------|
| 1 | **Re-enable session validation** | Security: Unlimited sessions allowed | Medium | 1 week |
| 2 | **Fix trial expiry race condition** | Revenue: Premium access after trial expires | Low | 2 days |
| 3 | **Create Firestore composite indexes** | Reliability: Queries may fail | Low | 1 day |
| 4 | **Implement distributed cache invalidation** | Scalability: Breaks with >1 instance | High | 2 weeks |

---

### 🟠 P1 (High - Before Production Scaling)

| # | Issue | Impact | Effort | Timeline |
|---|-------|--------|--------|----------|
| 5 | **User-based rate limiting** | UX: Legitimate users blocked (NAT) | Medium | 1 week |
| 6 | **Refactor large services (1000+ LOC)** | Maintainability: Hard to test/extend | Medium | 2 weeks |
| 7 | **Centralize chapter normalization** | Reliability: Inconsistent chapter keys | Low | 3 days |
| 8 | **Add email idempotency** | UX: Duplicate emails sent | Low | 2 days |

---

### 🟡 P2 (Medium - Performance & Scalability)

| # | Issue | Impact | Effort | Timeline |
|---|-------|--------|--------|----------|
| 9 | **Fix N+1 queries in analytics** | Performance: Slow dashboard load | Low | 3 days |
| 10 | **Validate mock test structure** | Reliability: Incomplete tests | Low | 1 day |
| 11 | **Aggregate theta updates** | Reliability: Transaction failures | Medium | 1 week |
| 12 | **Migrate to Redis cache** | Scalability: Enable horizontal scaling | High | 3 weeks |
| 13 | **Move theta to subcollection** | Scalability: Document size limits | Medium | 2 weeks |
| 14 | **Add load testing suite** | Reliability: Unknown breaking point | Medium | 1 week |

---

### 🟢 P3 (Nice to Have)

| # | Enhancement | Impact | Effort |
|---|-------------|--------|--------|
| 15 | Increase test coverage to 80%+ | Quality: Catch regressions | High |
| 16 | Add OpenAPI/Swagger docs | DevEx: API documentation | Medium |
| 17 | Implement request schema validation | Security: Type safety | Low |
| 18 | Add per-endpoint Firestore latency monitoring | Observability: Identify slow queries | Medium |
| 19 | Create admin system health dashboard | Operations: Proactive monitoring | High |

---

## Conclusion

### Overall Assessment

JEEVibe's backend is **architecturally sound for MVP** with strong foundations in:
- ✅ **IRT-based adaptive learning** (correct 3PL implementation)
- ✅ **Service-oriented architecture** (clear separation of concerns)
- ✅ **Comprehensive error handling** (Sentry integration, standardized responses)
- ✅ **Security** (Firebase Auth, input validation, content moderation)
- ✅ **Observability** (Winston logging, request IDs, health checks)

However, **critical issues must be addressed before production scale**:
- 🔴 **Session validation disabled** (security risk)
- 🔴 **Race condition in trial expiry** (revenue risk)
- 🔴 **Single-instance caching** (scalability blocker)
- 🟠 **IP-based rate limiting** (UX degradation in production)

### Scaling Readiness

**Current Capacity:** 1,000-5,000 DAU (single instance)
**Target Capacity:** 10,000-50,000 DAU (requires horizontal scaling)

**Blockers to Horizontal Scaling:**
1. In-memory caching (needs Redis migration)
2. Manual cache invalidation (needs Pub/Sub)
3. Session state (if re-enabled, needs shared storage)

**Estimated Timeline to Production-Ready:**
- **Minimum (P0 only):** 2-3 weeks
- **Recommended (P0 + P1):** 6-8 weeks
- **Full Optimization (P0 + P1 + P2):** 12-14 weeks

### Strengths to Preserve

1. **IRT Implementation** - Statistically sound, well-documented
2. **Tier System** - Clean abstraction, easy to extend
3. **Transaction Usage** - Prevents race conditions in critical flows
4. **Error Handling** - Comprehensive, secure, observable
5. **Code Organization** - Clear service boundaries (with noted exceptions)

### Technical Debt Prioritization

**Phase 1 (Weeks 1-3): Critical Fixes**
- Fix trial expiry race condition
- Create Firestore indexes
- Re-enable session validation
- Implement Redis for distributed caching

**Phase 2 (Weeks 4-8): Scaling Preparation**
- User-based rate limiting
- Refactor large services
- Centralize chapter normalization
- Add load testing suite

**Phase 3 (Weeks 9-14): Performance Optimization**
- Migrate theta to subcollection
- Fix N+1 queries
- Add monitoring dashboards
- Increase test coverage

---

**Review Completed:** 2026-02-13
**Next Review Recommended:** After P0 fixes (3 weeks)
