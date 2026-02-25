# Rate Limiting Middleware Order Issue - Root Cause Analysis

**Date:** 2026-02-25
**Issue:** Authenticated mobile users getting "Too many requests" errors when accessing Daily Quiz
**Severity:** HIGH - Affects all authenticated endpoints, not just Daily Quiz

---

## Executive Summary

**The Problem:**
All authenticated requests are incorrectly rate-limited by IP address instead of user ID, causing mobile users (especially those on carrier networks sharing IPs) to hit rate limits prematurely.

**Root Cause:**
Middleware execution order is wrong. Rate limiters run BEFORE authentication middleware, so `req.userId` is not set when rate limiting decisions are made.

**Impact:**
- 100 req/15min per-user limit becomes 20 req/15min per-IP limit for ALL users
- Multiple users behind same NAT/carrier IP exhaust shared rate limit quickly
- Affects ALL authenticated endpoints across entire API

**Fix:**
Reorder middleware so authentication runs BEFORE rate limiting, or redesign rate limiting strategy.

---

## Technical Analysis

### 1. Current Middleware Execution Order

**File:** `/Users/abhijeetroy/Documents/JEEVibe/backend/src/index.js`

```javascript
// Line 208: Rate limiter applied GLOBALLY to /api
app.use('/api', apiLimiter);

// Line 248: Daily quiz routes registered
app.use('/api/daily-quiz', dailyQuizRouter);
```

**Route-level pattern (all authenticated routes):**
```javascript
// backend/src/routes/dailyQuiz.js:104
router.get('/generate', authenticateUser, async (req, res, next) => {
  // handler
});
```

**Middleware execution sequence for `/api/daily-quiz/generate`:**
```
1. apiLimiter runs         → req.userId = undefined (not set yet!)
2. authenticateUser runs   → req.userId = "abc123" (NOW set)
3. Route handler runs      → Business logic
```

### 2. Rate Limiter Implementation

**File:** `/Users/abhijeetroy/Documents/JEEVibe/backend/src/middleware/rateLimiter.js`

```javascript
// Lines 22-27: getUserKey() function
const getUserKey = (req) => {
  if (req.userId) {
    return `user:${req.userId}`;  // 100 req/15min
  }
  return `ip:${req.ip}`;           // 20 req/15min
};

// Lines 30-41: apiLimiter configuration
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  keyGenerator: getUserKey,  // ← Called BEFORE req.userId exists!
  max: (req) => {
    if (req.userId) {
      return 100;  // Never reached for authenticated requests!
    }
    return 20;     // Always used instead
  },
  // ...
});
```

**What actually happens:**
- `getUserKey(req)` is called when apiLimiter runs (line 208 of index.js)
- At this point, `req.userId` is `undefined` (authenticateUser hasn't run yet)
- Falls back to `ip:${req.ip}` → always returns IP-based key
- Limit defaults to 20 req/15min instead of intended 100 req/15min

### 3. Authentication Middleware

**File:** `/Users/abhijeetroy/Documents/JEEVibe/backend/src/middleware/auth.js`

```javascript
// Line 59: Token verification
const decodedToken = await admin.auth().verifyIdToken(token);

// Line 62: Sets req.userId
req.userId = decodedToken.uid;
```

This runs AFTER apiLimiter, so too late for rate limit key generation.

---

## Scope of Impact

### Affected Routes (ALL authenticated endpoints)

**Grep Results:** 50+ authenticated routes across the entire API

```bash
# All routes using authenticateUser middleware
router.get('/generate', authenticateUser, ...)          # Daily Quiz
router.post('/start', authenticateUser, ...)            # Mock Tests
router.get('/overview', authenticateUser, ...)          # Analytics
router.post('/solve', authenticateUser, ...)            # Snap & Solve
router.post('/submit', authenticateUser, ...)           # Assessment
router.get('/profile', authenticateUser, ...)           # User Profile
router.post('/generate', authenticateUser, ...)         # Chapter Practice
# ... and 40+ more routes
```

**ALL of these routes are affected** because they share the same middleware order problem.

### Real-World Scenarios

**Scenario 1: Mobile carrier network**
- 5 users on same Jio/Airtel cell tower → share 1 public IP
- Each user tries to access Daily Quiz
- After 4 requests total (across all 5 users), rate limit hit
- Error: "Too many requests from this IP"

**Scenario 2: School/College WiFi**
- 20 students preparing for JEE on same WiFi network
- All share 1 public IP from router
- First student uses Daily Quiz → consumes shared 20 req/15min pool
- Other 19 students immediately blocked

**Scenario 3: VPN users**
- Users behind VPN share exit node IPs
- Hundreds of users potentially sharing same IP
- Rate limit exhausted within seconds

---

## Why This Wasn't Caught Earlier

1. **Local development testing:**
   - Single user per IP during development
   - Never hit the 20 req/15min limit
   - Issue only appears in multi-user production scenarios

2. **Misleading logs:**
   - Rate limiter logs show `userId: null` or `ip: X.X.X.X`
   - Looks like anonymous traffic, not authenticated users

3. **Comment in rateLimiter.js suggests it works:**
   ```javascript
   // Line 8: "Rate limiting now uses userId (if authenticated)"
   ```
   This is **technically true** (code is written to support it), but **functionally false** (middleware order prevents it from working).

---

## Solution Options

### Option 1: Move Authentication BEFORE Rate Limiting (RECOMMENDED)

**Pros:**
- Fixes the root cause
- Leverages existing user-aware rate limiting logic
- No code changes to rateLimiter.js needed

**Cons:**
- Requires significant refactoring of index.js
- Authentication becomes global middleware (performance impact)
- Unauthenticated routes (health checks, CORS preflight) will fail

**Implementation:**
```javascript
// index.js (PROPOSED CHANGE)

// Move authentication BEFORE rate limiting
const { authenticateUserMiddleware } = require('./middleware/auth');
app.use('/api', authenticateUserMiddleware); // Run first

// THEN apply rate limiting
app.use('/api', apiLimiter); // Now sees req.userId

// Register routes
app.use('/api/daily-quiz', dailyQuizRouter);
```

**Challenge:** Some routes should NOT require authentication (e.g., `/api/health`, `/api/cron/*`, `/api/share/*`). Need conditional authentication middleware.

---

### Option 2: Route-Level Rate Limiting (ALTERNATIVE)

**Pros:**
- More granular control per route
- Authentication naturally runs first (already in route definitions)
- No global middleware order changes

**Cons:**
- Requires updating 50+ route files
- More boilerplate code
- Harder to maintain consistency

**Implementation:**
```javascript
// Example: dailyQuiz.js
const { createAuthenticatedRateLimiter } = require('../middleware/rateLimiter');
const quizLimiter = createAuthenticatedRateLimiter({ max: 100, windowMs: 15 * 60 * 1000 });

router.get('/generate',
  authenticateUser,      // Step 1: Auth (sets req.userId)
  quizLimiter,           // Step 2: Rate limit (uses req.userId)
  async (req, res, next) => {
    // handler
  }
);
```

---

### Option 3: Header-Based Pre-Authentication (HYBRID)

**Pros:**
- Minimal refactoring
- Works with existing middleware order
- Backwards compatible

**Cons:**
- Requires client changes (mobile app must send user ID in custom header)
- Security concern (client-provided user ID could be spoofed)
- Requires additional validation logic

**Implementation:**
```javascript
// rateLimiter.js (HYBRID APPROACH)
const getUserKey = (req) => {
  // 1. Try to get userId from req.userId (if already authenticated)
  if (req.userId) {
    return `user:${req.userId}`;
  }

  // 2. Try to extract userId from Authorization header BEFORE full auth
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.split('Bearer ')[1];
    try {
      // Decode token WITHOUT verification (just extract userId)
      const decoded = admin.auth().decodeToken(token, { complete: false });
      return `user:${decoded.uid}`;
    } catch (err) {
      // Token invalid, fall back to IP
      return `ip:${req.ip}`;
    }
  }

  // 3. Fall back to IP-based rate limiting
  return `ip:${req.ip}`;
};
```

**Security Risk:** If token decoding without verification is used, rate limiter accepts expired/invalid tokens. Need to balance security vs performance.

---

## Recommended Fix (Option 1 with Conditional Auth)

### Step 1: Create conditional authentication middleware

**File:** `backend/src/middleware/auth.js`

```javascript
// NEW: Conditional authentication (skips certain routes)
const conditionalAuthMiddleware = async (req, res, next) => {
  // Exempt routes that should NOT be authenticated
  const exemptPaths = [
    '/api/health',
    '/api/cron/',
    '/api/share/',
  ];

  const isExempt = exemptPaths.some(path => req.path.startsWith(path));
  if (isExempt) {
    return next(); // Skip authentication
  }

  // All other routes: authenticate
  return authenticateUser(req, res, next);
};

module.exports = {
  authenticateUser,
  conditionalAuthMiddleware  // Export new middleware
};
```

### Step 2: Reorder middleware in index.js

```javascript
// index.js

// ========================================
// AUTHENTICATION (Must run BEFORE rate limiting!)
// ========================================
const { conditionalAuthMiddleware } = require('./middleware/auth');
app.use('/api', conditionalAuthMiddleware);  // Sets req.userId for rate limiter

// ========================================
// RATE LIMITING (Now sees req.userId!)
// ========================================
const { apiLimiter, strictLimiter, imageProcessingLimiter } = require('./middleware/rateLimiter');
app.use('/api', apiLimiter);  // Now correctly uses user:${userId} key
app.use('/api/solve', imageProcessingLimiter);
app.use('/api/assessment/submit', strictLimiter);

// ========================================
// ROUTES (No changes needed!)
// ========================================
app.use('/api/daily-quiz', dailyQuizRouter);
// ... all other routes
```

### Step 3: Remove route-level authenticateUser (optional cleanup)

Since authentication now runs globally, route-level `authenticateUser` is redundant:

```javascript
// BEFORE
router.get('/generate', authenticateUser, async (req, res, next) => { ... });

// AFTER (authenticateUser is now redundant)
router.get('/generate', async (req, res, next) => { ... });
```

**However:** Keep `authenticateUser` at route level for clarity and defense-in-depth.

---

## Testing Strategy

### Unit Tests

```javascript
// test/middleware/rateLimiter.test.js

describe('Rate Limiter with Authentication', () => {
  it('should use user ID for authenticated requests', async () => {
    const req = { userId: 'test-user-123', ip: '1.2.3.4' };
    const key = getUserKey(req);
    expect(key).toBe('user:test-user-123');
  });

  it('should use IP for unauthenticated requests', async () => {
    const req = { ip: '1.2.3.4' };
    const key = getUserKey(req);
    expect(key).toBe('ip:1.2.3.4');
  });
});
```

### Integration Tests

```javascript
// test/routes/dailyQuiz.integration.test.js

describe('Daily Quiz Rate Limiting', () => {
  it('should allow 100 requests per user within 15 minutes', async () => {
    const token = await getAuthToken('user1');

    // Make 100 requests from same user
    for (let i = 0; i < 100; i++) {
      const res = await request(app)
        .get('/api/daily-quiz/generate')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
    }

    // 101st request should be rate limited
    const res = await request(app)
      .get('/api/daily-quiz/generate')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(429);
  });

  it('should rate limit users independently (not by IP)', async () => {
    const token1 = await getAuthToken('user1');
    const token2 = await getAuthToken('user2');

    // User 1 exhausts their limit
    for (let i = 0; i < 100; i++) {
      await request(app)
        .get('/api/daily-quiz/generate')
        .set('Authorization', `Bearer ${token1}`)
        .set('X-Forwarded-For', '1.2.3.4'); // Same IP
    }

    // User 2 should still have full quota (different user ID)
    const res = await request(app)
      .get('/api/daily-quiz/generate')
      .set('Authorization', `Bearer ${token2}`)
      .set('X-Forwarded-For', '1.2.3.4'); // Same IP as user1

    expect(res.status).toBe(200); // Should NOT be rate limited
  });
});
```

---

## Monitoring & Rollout

### 1. Enable verbose rate limit logging

```javascript
// rateLimiter.js
handler: (req, res, next, options) => {
  logger.warn('Rate limit exceeded', {
    userId: req.userId || null,
    ip: req.ip,
    path: req.path,
    key: getUserKey(req),  // Log actual key used
    limit: options.max,
  });
  // ...
}
```

### 2. Track rate limit metrics

**Datadog/Sentry metrics:**
- `rate_limit.hit` (counter) - Tagged by `key_type: user|ip`
- `rate_limit.user_based_percent` (gauge) - % of limits that used user ID
- `rate_limit.ip_collision_count` (counter) - Multiple users hit by same IP limit

### 3. Gradual rollout

1. **Week 1:** Deploy to staging, monitor for 3 days
2. **Week 2:** Deploy to 10% of production traffic (canary)
3. **Week 3:** Roll out to 50% of traffic
4. **Week 4:** Full rollout to 100%

### 4. Rollback plan

If issues arise:
```javascript
// EMERGENCY ROLLBACK: Revert to IP-only rate limiting
const getUserKey = (req) => {
  return `ip:${req.ip}`;  // Ignore userId temporarily
};
```

---

## Additional Affected Components

### 1. Analytics Rate Limiter
**File:** `backend/src/middleware/rateLimiter.js:164-212`

Same issue affects `analyticsLimiter` (200 req/15min for authenticated, 100 for anonymous).

### 2. Strict Rate Limiter
**File:** `backend/src/middleware/rateLimiter.js:68-99`

Affects expensive operations (10/hour for authenticated, 5/hour for anonymous).

### 3. Image Processing Limiter
**File:** `backend/src/middleware/rateLimiter.js:102-134`

Affects Snap & Solve (50/hour for authenticated, 5/hour for anonymous).

**ALL of these limiters have the same middleware order problem.**

---

## Conclusion

This is a **systemic issue** affecting the entire API surface, not just Daily Quiz. The rate limiting system was correctly designed to be user-aware, but the middleware execution order prevents it from functioning as intended.

**Recommended Action:** Implement Option 1 (Conditional Authentication Middleware) to fix the root cause across all endpoints simultaneously.

**Estimated Effort:**
- Development: 2-3 days
- Testing: 2-3 days
- Staged rollout: 2-4 weeks
- Total: ~3-4 weeks to full production deployment

**Risk Level:** Medium (requires careful testing of authentication bypass for exempt routes)

---

## Appendix: Middleware Order Diagram

### Current (Broken)

```
Request → Rate Limiter (req.userId undefined) → Auth Middleware (sets req.userId) → Route Handler
          ↓
          Uses IP-based key (20 req/15min)
```

### Proposed (Fixed)

```
Request → Auth Middleware (sets req.userId) → Rate Limiter (req.userId available) → Route Handler
                                               ↓
                                               Uses user-based key (100 req/15min)
```

---

**Document Version:** 1.0
**Last Updated:** 2026-02-25
**Author:** Claude Code Analysis
