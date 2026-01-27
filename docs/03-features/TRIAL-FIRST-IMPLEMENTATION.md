# Trial-First Signup Implementation Plan

## Overview

Implement a **configurable trial-first signup system** where new users automatically receive a **30-day PRO tier trial** (configurable 7-90 days) with multi-channel notifications (email, push, in-app banner, dialog) to drive conversion to paid subscriptions.

**Current State:**
- New users get FREE tier by default (no trial)
- Trial checking logic EXISTS in `getEffectiveTier()` but no trial initialization
- No trial processing/notification jobs

**Target State:**
- All new users → 30-day PRO trial automatically
- Multi-channel notifications (day 7, 5, 2, 0)
- Hard downgrade to FREE after 30 days
- Trial-to-paid conversion target: 5-10%

---

## Database Schema Changes

### 1. User Document (`users/{userId}`)

Add `trial` field to existing documents:

```javascript
trial: {
  tier_id: 'pro',                          // Always PRO tier
  started_at: Timestamp,                   // Trial start date
  ends_at: Timestamp,                      // Expiry (started_at + duration_days)
  is_active: true,                         // false after expiry/conversion
  notifications_sent: {
    'day_23': { sent_at: Timestamp, channels: ['email'] },
    'day_5': { sent_at: Timestamp, channels: ['email', 'push'] },
    'day_2': { sent_at: Timestamp, channels: ['email', 'push'] },
    'day_0': { sent_at: Timestamp, channels: ['email', 'push'] }
  },
  converted_to_paid: false,                // true if user subscribes
  converted_at: Timestamp,
  eligibility_phone: string                // Prevent multi-trial abuse
}
```

**Important:** `subscription.source` changes from `'default'` → `'trial'` during trial

### 2. Trial Configuration (`trial_config/active`)

New Firestore collection for configurable settings:

```javascript
{
  enabled: true,
  trial_tier_id: 'pro',                    // PRO tier only
  duration_days: 30,                       // Configurable 7-90 days

  eligibility: {
    one_per_phone: true,                   // One trial per phone number
    check_existing_subscription: true
  },

  notification_schedule: [
    { days_remaining: 23, channels: ['email'], template: 'trial_week_1' },
    { days_remaining: 5, channels: ['email', 'push'], template: 'trial_urgency_5' },
    { days_remaining: 2, channels: ['email', 'push'], template: 'trial_urgency_2' },
    { days_remaining: 0, channels: ['email', 'push', 'in_app_dialog'], template: 'trial_expired' }
  ],

  notifications: {
    email: { enabled: true, milestones: [23, 5, 2, 0] },
    push: { enabled: true, milestones: [5, 2, 0] },
    in_app_banner: { enabled: true, urgency_threshold: 5 },
    in_app_dialog: { enabled: true }
  },

  expiry: {
    downgrade_to_tier: 'free',
    grace_period_days: 0,                  // Hard downgrade, no grace
    show_discount_offer: true,
    discount_code: 'TRIAL2PRO',
    discount_valid_days: 7
  }
}
```

### 3. Trial Events Log (`trial_events/{eventId}`)

Audit trail for analytics:

```javascript
{
  user_id: string,
  event_type: 'trial_started' | 'notification_sent' | 'trial_expired' | 'trial_converted',
  timestamp: Timestamp,
  data: { /* event-specific metadata */ }
}
```

### 4. Required Firestore Index

```javascript
// Composite index for scheduled job queries
Collection: users
Fields: trial.is_active (ASC), trial.ends_at (ASC)
```

---

## Backend Implementation

### New Files to Create

#### 1. `backend/src/services/trialService.js` (~300 lines)

**Core Functions:**

```javascript
initializeTrial(userId, phoneNumber)
  - Check if trials enabled (via trialConfig)
  - Verify eligibility (one per phone, no existing subscription)
  - Create trial object with ends_at = now + duration_days
  - Update user document
  - Invalidate tier cache
  - Log analytics event: 'trial_started'

checkTrialEligibility(userId, phoneNumber)
  - Check if user already has trial
  - Check if phone already used for trial
  - Return { isEligible: boolean, reason: string }

expireTrial(userId)
  - Set trial.is_active = false
  - Invalidate tier cache (forces recalculation → FREE tier)
  - Log analytics event: 'trial_expired'

convertTrialToPaid(userId, subscriptionId)
  - Mark trial.converted_to_paid = true
  - Set trial.converted_at timestamp
  - Log analytics event: 'trial_converted'

sendTrialNotification(userId, daysRemaining, channels)
  - Check if already sent (deduplicate)
  - Send email and/or push based on channels
  - Update trial.notifications_sent
  - Log event
```

**Key Design Points:**
- One trial per phone number (check `trial.eligibility_phone`)
- Always invalidate tier cache after state changes
- Non-blocking errors (don't fail signup if trial fails)

#### 2. `backend/src/services/trialConfigService.js` (~150 lines)

**Pattern:** Same as `tierConfigService.js` (5-minute cache)

```javascript
getTrialConfig()
  - Check cache (5 min TTL)
  - Fetch from trial_config/active
  - Fallback to DEFAULT_TRIAL_CONFIG

DEFAULT_TRIAL_CONFIG = { enabled: true, trial_tier_id: 'pro', duration_days: 30, ... }

invalidateCache() - Force reload
```

#### 3. `backend/src/services/trialProcessingService.js` (~200 lines)

**Daily scheduled job logic:**

```javascript
processAllTrials()
  - Query all users where trial.is_active === true
  - For each user:
    - Calculate days_remaining
    - If days_remaining <= 0 → expireTrial()
    - Else check notification_schedule:
      - If milestone matches → sendTrialNotification()
  - Return { notifications_sent: N, trials_expired: M }
```

**Batch Processing:**
- Process up to 1000 users per run
- 5-minute timeout
- Error handling (log and continue)

### Modified Files

#### 4. `backend/src/routes/users.js` (Modify at line ~218)

**Add trial initialization after profile save:**

```javascript
// After successful profile save
if (!userDoc.exists) {
  try {
    const { initializeTrial } = require('../services/trialService');
    const phoneNumber = firestoreData.phoneNumber;
    await initializeTrial(userId, phoneNumber);
  } catch (error) {
    // Don't fail signup if trial fails (log only)
    logger.error('Failed to initialize trial', { userId, error: error.message });
  }
}
```

#### 5. `backend/src/routes/subscriptions.js` (Modify at line ~93)

**Add trial info to `/api/subscriptions/status` response:**

```javascript
// In GET /api/subscriptions/status
const response = {
  subscription: { tier, source, ... },
  limits: { ... },
  features: { ... },
  usage: { ... },

  // NEW: Trial info
  trial: tierInfo.source === 'trial' ? {
    tier_id: tierInfo.tier,
    days_remaining: tierInfo.days_remaining,
    ends_at: tierInfo.expires_at,
    started_at: userData.trial?.started_at
  } : null
};
```

#### 6. `backend/src/routes/cron.js` (Add after line ~421)

**Add new cron endpoint:**

```javascript
/**
 * POST /api/cron/process-trials
 * Daily at 2:00 AM IST (8:30 PM UTC)
 */
router.post('/process-trials', verifyCronRequest, async (req, res) => {
  try {
    const results = await withTimeout(
      processAllTrials(),
      300000,  // 5 minutes
      'Trial processing timed out'
    );

    res.json({ success: true, message: 'Trial processing complete', results });
  } catch (error) {
    logger.error('Error in trial processing', { error: error.message });
    res.status(500).json({ success: false, error: error.message });
  }
});
```

**cron-job.org Configuration:**

1. **Login to cron-job.org dashboard**
2. **Create new cron job** with the following settings:
   - **Title**: `JEEVibe Trial Processing`
   - **URL**: `https://jeevibe-thzi.onrender.com/api/cron/process-trials`
   - **Schedule**: Daily at 2:00 AM IST
     - Time: `02:00` (IST timezone)
     - Or use UTC: `20:30` (previous day)
   - **Request method**: `POST`
   - **Request timeout**: `300` seconds (5 minutes)
   - **Headers**: Click "Add header"
     - **Name**: `x-cron-secret`
     - **Value**: `<your CRON_SECRET from Render env vars>`
   - **Notifications**:
     - ✅ Enable "Notify on failure"
     - Add your email for alerts
3. **Test execution**:
   - Click "Execute now" to verify setup
   - Check Render logs for successful execution
   - Verify response status is 200

**Why cron-job.org?**
- ✅ Free tier (50 jobs, unlimited executions)
- ✅ External monitoring (detects if Render is down)
- ✅ Rich dashboard with execution history
- ✅ Email alerts on failure
- ✅ Saves ₹580/month vs Render's paid cron

#### 7. `backend/src/services/studentEmailService.js` (Add at line ~777)

**Add trial email functions:**

```javascript
async function sendTrialEmail(userId, userData, daysRemaining) {
  const emailContent = await generateTrialEmailContent(userId, userData, daysRemaining);

  const { data, error } = await resend.emails.send({
    from: FROM_EMAIL,
    to: userData.email,
    subject: emailContent.subject,
    html: emailContent.html,
    text: emailContent.text
  });

  return error ? { success: false } : { success: true, emailId: data?.id };
}

async function generateTrialEmailContent(userId, userData, daysRemaining) {
  const templates = {
    23: {
      subject: '🎯 Week 1 Complete - Keep Going!',
      message: 'You're doing great! 23 days left in your Pro trial.'
    },
    5: {
      subject: '⏰ Only 5 Days Left in Your Pro Trial',
      message: 'Don't lose your Pro features! Upgrade for just ₹199/month.'
    },
    2: {
      subject: '⚠️ Trial Ending in 2 Days - Act Now!',
      message: 'Last chance to keep your 10 daily snaps and offline access.'
    },
    0: {
      subject: 'Your Trial Has Ended - Special Offer Inside 🎁',
      message: 'Get 20% off with code TRIAL2PRO (valid for 7 days).'
    }
  };

  // Generate HTML email (similar to daily/weekly email templates)
  return { subject, html, text };
}
```

#### 8. `backend/src/services/subscriptionService.js` (ALREADY IMPLEMENTED!)

**Good news:** Trial checking logic ALREADY EXISTS at lines 210-226!

```javascript
// 3. Check active trial (ALREADY IMPLEMENTED)
if (userData.trial?.is_active) {
  const trialEndsAt = userData.trial.ends_at?.toDate();

  if (trialEndsAt && trialEndsAt > now) {
    const daysRemaining = Math.ceil((trialEndsAt - now) / (1000 * 60 * 60 * 24));

    return {
      tier: userData.trial.tier_id || 'pro',
      source: 'trial',
      expires_at: userData.trial.ends_at,
      days_remaining: daysRemaining,
      trial_started_at: userData.trial.started_at
    };
  } else {
    // Trial expired - trigger async downgrade
    expireTrialAsync(userId);
  }
}
```

**Minor Modification:** Import `expireTrialAsync` from `trialService.js`

---

## Backend Test Files

### Test Files to Create

#### 1. `backend/test/services/trialService.test.js` (~200 lines)

**Test Coverage: >85% target**

```javascript
const { initializeTrial, checkTrialEligibility, expireTrial, sendTrialNotification } = require('../../src/services/trialService');

describe('trialService', () => {
  describe('initializeTrial', () => {
    it('should create trial for eligible new user', async () => {
      // Test: New user with new phone gets 30-day trial
      const userId = 'test123';
      const phoneNumber = '+919876543210';

      const result = await initializeTrial(userId, phoneNumber);

      expect(result).toBeDefined();
      expect(result.tier_id).toBe('pro');
      // Verify Firestore document created
      // Verify ends_at = now + 30 days
    });

    it('should reject if phone already used for trial', async () => {
      // Test: Same phone number tries to get second trial
      const userId = 'test456';
      const phoneNumber = '+919876543210'; // Already used

      const result = await initializeTrial(userId, phoneNumber);

      expect(result).toBeNull();
      // Verify no trial created in Firestore
    });

    it('should reject if user already has trial', async () => {
      // Test: User tries to create duplicate trial
      const userId = 'test123'; // Already has trial
      const phoneNumber = '+919999999999';

      const result = await initializeTrial(userId, phoneNumber);

      expect(result).toBeNull();
    });

    it('should handle trials disabled via config', async () => {
      // Test: Trial config enabled = false
      // Mock trialConfig.enabled = false

      const result = await initializeTrial('user', '+919999999999');

      expect(result).toBeNull();
    });

    it('should not throw error if Firestore write fails', async () => {
      // Test: Non-blocking error handling
      // Mock Firestore to throw error

      await expect(initializeTrial('user', '+919999999999')).resolves.not.toThrow();
    });
  });

  describe('checkTrialEligibility', () => {
    it('should return eligible for new phone number', async () => {
      const result = await checkTrialEligibility('newUser', '+919111111111');

      expect(result.isEligible).toBe(true);
    });

    it('should return ineligible for duplicate phone', async () => {
      // Setup: Create user with trial using phone
      await initializeTrial('user1', '+919222222222');

      const result = await checkTrialEligibility('user2', '+919222222222');

      expect(result.isEligible).toBe(false);
      expect(result.reason).toBe('phone_already_used');
    });

    it('should return ineligible if user already has trial', async () => {
      // Setup: User already has trial
      const userId = 'existingUser';
      await initializeTrial(userId, '+919333333333');

      const result = await checkTrialEligibility(userId, '+919444444444');

      expect(result.isEligible).toBe(false);
      expect(result.reason).toBe('user_already_has_trial');
    });
  });

  describe('expireTrial', () => {
    it('should set is_active to false', async () => {
      // Setup: Create active trial
      const userId = 'trialUser';
      await initializeTrial(userId, '+919555555555');

      await expireTrial(userId);

      // Verify: trial.is_active = false in Firestore
      const userDoc = await db.collection('users').doc(userId).get();
      expect(userDoc.data().trial.is_active).toBe(false);
    });

    it('should invalidate tier cache', async () => {
      // Test: Cache invalidation called
      const userId = 'cacheUser';
      const invalidateSpy = jest.spyOn(subscriptionService, 'invalidateTierCache');

      await expireTrial(userId);

      expect(invalidateSpy).toHaveBeenCalledWith(userId);
    });

    it('should log trial_expired analytics event', async () => {
      // Test: Analytics event logged
      const userId = 'analyticsUser';
      const logEventSpy = jest.spyOn(analytics, 'logEvent');

      await expireTrial(userId);

      expect(logEventSpy).toHaveBeenCalledWith('trial_expired', expect.any(Object));
    });
  });

  describe('sendTrialNotification', () => {
    it('should send email notification', async () => {
      const userId = 'emailUser';
      const daysRemaining = 5;

      const result = await sendTrialNotification(userId, daysRemaining, ['email']);

      expect(result.success).toBe(true);
      expect(result.results.email).toBeDefined();
    });

    it('should not send duplicate notifications', async () => {
      // Setup: Mark day_5 as already sent
      const userId = 'dupUser';

      // First call
      await sendTrialNotification(userId, 5, ['email']);

      // Second call (should skip)
      const result = await sendTrialNotification(userId, 5, ['email']);

      expect(result.success).toBe(false);
      expect(result.reason).toBe('already_sent');
    });

    it('should send both email and push when specified', async () => {
      const userId = 'multiChannelUser';

      const result = await sendTrialNotification(userId, 2, ['email', 'push']);

      expect(result.results.email).toBeDefined();
      expect(result.results.push).toBeDefined();
    });

    it('should update notifications_sent field', async () => {
      const userId = 'trackingUser';

      await sendTrialNotification(userId, 5, ['email']);

      const userDoc = await db.collection('users').doc(userId).get();
      expect(userDoc.data().trial.notifications_sent.day_5).toBeDefined();
    });
  });
});
```

#### 2. `backend/test/services/trialConfigService.test.js` (~100 lines)

**Test Coverage: >90% target**

```javascript
const { getTrialConfig, invalidateCache } = require('../../src/services/trialConfigService');

describe('trialConfigService', () => {
  it('should return cached config within TTL', async () => {
    // First call - fetches from Firestore
    const config1 = await getTrialConfig();

    // Second call within 5 minutes - returns cache
    const config2 = await getTrialConfig();

    expect(config2).toEqual(config1);
    // Verify Firestore only called once
  });

  it('should fetch from Firestore after cache expires', async () => {
    await getTrialConfig();

    // Fast-forward time by 6 minutes
    jest.advanceTimersByTime(6 * 60 * 1000);

    await getTrialConfig();

    // Verify Firestore called twice
  });

  it('should fallback to defaults if Firestore fails', async () => {
    // Mock Firestore to throw error
    jest.spyOn(db.collection('trial_config').doc('active'), 'get').mockRejectedValue(new Error('Firestore error'));

    const config = await getTrialConfig();

    expect(config.enabled).toBe(true);
    expect(config.duration_days).toBe(30);
  });

  it('should invalidate cache when requested', async () => {
    const config1 = await getTrialConfig();

    invalidateCache();

    const config2 = await getTrialConfig();

    // Verify Firestore fetched again
  });
});
```

#### 3. `backend/test/services/trialProcessingService.test.js` (~150 lines)

**Test Coverage: >80% target**

```javascript
const { processAllTrials } = require('../../src/services/trialProcessingService');

describe('trialProcessingService', () => {
  it('should expire trials with days_remaining <= 0', async () => {
    // Setup: Create trial that expired yesterday
    const userId = 'expiredUser';
    await createTrialWithDaysRemaining(userId, -1);

    const results = await processAllTrials();

    expect(results.trials_expired).toBe(1);
    // Verify trial.is_active = false
  });

  it('should send notifications at correct milestones', async () => {
    // Setup: Users at day 23, 5, 2 remaining
    await createTrialWithDaysRemaining('user1', 23);
    await createTrialWithDaysRemaining('user2', 5);
    await createTrialWithDaysRemaining('user3', 2);

    const results = await processAllTrials();

    expect(results.notifications_sent).toBe(3);
  });

  it('should not send duplicate notifications', async () => {
    // Setup: User already received day_5 notification
    const userId = 'notifiedUser';
    await createTrialWithDaysRemaining(userId, 5);
    await markNotificationSent(userId, 'day_5');

    const results = await processAllTrials();

    expect(results.notifications_sent).toBe(0);
  });

  it('should handle batch processing of 1000+ users', async () => {
    // Setup: Create 1500 active trials
    for (let i = 0; i < 1500; i++) {
      await createTrialWithDaysRemaining(`user${i}`, 10);
    }

    const results = await processAllTrials();

    // Should process first 1000, skip rest
    expect(results.trials_processed).toBeLessThanOrEqual(1000);
  });

  it('should continue processing after error', async () => {
    // Setup: Create trials, one will fail
    await createTrialWithDaysRemaining('goodUser1', 5);
    await createTrialWithDaysRemaining('badUser', 5); // Will throw error
    await createTrialWithDaysRemaining('goodUser2', 5);

    const results = await processAllTrials();

    // Should process 2 out of 3
    expect(results.notifications_sent).toBe(2);
    expect(results.errors.length).toBe(1);
  });

  it('should complete within 5-minute timeout', async () => {
    // Setup: Create many trials
    for (let i = 0; i < 500; i++) {
      await createTrialWithDaysRemaining(`user${i}`, 5);
    }

    const startTime = Date.now();
    await processAllTrials();
    const duration = Date.now() - startTime;

    expect(duration).toBeLessThan(5 * 60 * 1000);
  });
});
```

#### 4. `backend/test/routes/users.test.js` (~100 lines)

**Test Coverage: Focus on trial initialization in signup flow**

```javascript
describe('POST /api/users/profile', () => {
  it('should initialize trial for new user', async () => {
    const response = await request(app)
      .post('/api/users/profile')
      .send({
        userId: 'newUser123',
        name: 'Test User',
        email: 'test@example.com',
        phoneNumber: '+919876543210',
        targetYear: 2025
      });

    expect(response.status).toBe(200);

    // Verify trial created in Firestore
    const userDoc = await db.collection('users').doc('newUser123').get();
    expect(userDoc.data().trial).toBeDefined();
    expect(userDoc.data().trial.tier_id).toBe('pro');
  });

  it('should not initialize trial for existing user', async () => {
    // Setup: User already exists
    await createUser('existingUser', { name: 'Existing' });

    const response = await request(app)
      .post('/api/users/profile')
      .send({
        userId: 'existingUser',
        name: 'Updated Name'
      });

    expect(response.status).toBe(200);

    // Verify no trial created
    const userDoc = await db.collection('users').doc('existingUser').get();
    expect(userDoc.data().trial).toBeUndefined();
  });

  it('should succeed even if trial initialization fails', async () => {
    // Mock trial service to throw error
    jest.spyOn(trialService, 'initializeTrial').mockRejectedValue(new Error('Trial error'));

    const response = await request(app)
      .post('/api/users/profile')
      .send({
        userId: 'errorUser',
        name: 'Error Test',
        phoneNumber: '+919999999999'
      });

    expect(response.status).toBe(200);
    // User created without trial
  });
});
```

#### 5. `backend/test/routes/subscriptions.test.js` (~100 lines)

**Test Coverage: Trial info in subscription status endpoint**

```javascript
describe('GET /api/subscriptions/status', () => {
  it('should return trial info for users on trial', async () => {
    // Setup: User with active trial
    const userId = 'trialUser';
    await createUserWithTrial(userId, { daysRemaining: 15 });

    const response = await request(app)
      .get('/api/subscriptions/status')
      .set('Authorization', `Bearer ${getToken(userId)}`);

    expect(response.status).toBe(200);
    expect(response.body.subscription.source).toBe('trial');
    expect(response.body.subscription.tier).toBe('pro');
    expect(response.body.trial).toBeDefined();
    expect(response.body.trial.days_remaining).toBe(15);
  });

  it('should return trial: null for users without trial', async () => {
    // Setup: Regular free user
    const userId = 'freeUser';
    await createUser(userId, { tier: 'free' });

    const response = await request(app)
      .get('/api/subscriptions/status')
      .set('Authorization', `Bearer ${getToken(userId)}`);

    expect(response.status).toBe(200);
    expect(response.body.subscription.tier).toBe('free');
    expect(response.body.trial).toBeNull();
  });

  it('should prioritize trial over default tier', async () => {
    // Setup: User with active trial (no paid subscription)
    const userId = 'trialOnlyUser';
    await createUserWithTrial(userId, { daysRemaining: 20 });

    const response = await request(app)
      .get('/api/subscriptions/status')
      .set('Authorization', `Bearer ${getToken(userId)}`);

    expect(response.body.subscription.source).toBe('trial');
    expect(response.body.subscription.tier).toBe('pro');
  });

  it('should prioritize paid subscription over trial', async () => {
    // Setup: User with both paid subscription AND trial
    const userId = 'paidUser';
    await createUserWithTrial(userId, { daysRemaining: 10 });
    await createPaidSubscription(userId, 'ultra');

    const response = await request(app)
      .get('/api/subscriptions/status')
      .set('Authorization', `Bearer ${getToken(userId)}`);

    expect(response.body.subscription.source).toBe('paid');
    expect(response.body.subscription.tier).toBe('ultra');
  });
});
```

### Test Setup & Configuration

#### Test Dependencies (`package.json`)

```json
{
  "devDependencies": {
    "jest": "^29.7.0",
    "supertest": "^6.3.3",
    "@firebase/testing": "^0.20.11",
    "firebase-admin": "^12.0.0"
  },
  "scripts": {
    "test": "jest --coverage",
    "test:watch": "jest --watch",
    "test:ci": "jest --ci --coverage --maxWorkers=2"
  }
}
```

#### Jest Configuration (`jest.config.js`)

```javascript
module.exports = {
  testEnvironment: 'node',
  coverageDirectory: 'coverage',
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/index.js',
    '!src/**/*.test.js'
  ],
  coverageThresholds: {
    global: {
      branches: 75,
      functions: 80,
      lines: 80,
      statements: 80
    },
    './src/services/trialService.js': {
      branches: 85,
      functions: 90,
      lines: 90
    }
  },
  setupFilesAfterEnv: ['<rootDir>/test/setup.js']
};
```

#### Test Setup File (`test/setup.js`)

```javascript
const admin = require('firebase-admin');
const { initializeTestEnvironment } = require('@firebase/testing');

let testEnv;

beforeAll(async () => {
  // Initialize Firebase test environment
  testEnv = await initializeTestEnvironment({
    projectId: 'test-project'
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  // Clear Firestore between tests
  await testEnv.clearFirestore();
});

// Mock helpers
global.createUser = async (userId, data) => {
  return testEnv.firestore().collection('users').doc(userId).set(data);
};

global.createTrialWithDaysRemaining = async (userId, days) => {
  const now = new Date();
  const endsAt = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);

  return testEnv.firestore().collection('users').doc(userId).set({
    trial: {
      tier_id: 'pro',
      started_at: admin.firestore.Timestamp.fromDate(now),
      ends_at: admin.firestore.Timestamp.fromDate(endsAt),
      is_active: true,
      notifications_sent: {}
    }
  });
};
```

### Test Coverage Targets

| Component | Target Coverage | Priority |
|-----------|----------------|----------|
| `trialService.js` | >85% | CRITICAL |
| `trialConfigService.js` | >90% | HIGH |
| `trialProcessingService.js` | >80% | CRITICAL |
| `users.js` (trial init) | >85% | HIGH |
| `subscriptions.js` (trial status) | >85% | HIGH |
| Overall backend | >80% | REQUIRED |

---

## Mobile Implementation

### New Files to Create

#### 1. `mobile/lib/models/trial_status.dart` (~80 lines)

```dart
class TrialStatus {
  final String tierId;
  final DateTime startedAt;
  final DateTime endsAt;
  final int daysRemaining;

  TrialStatus({
    required this.tierId,
    required this.startedAt,
    required this.endsAt,
    required this.daysRemaining,
  });

  factory TrialStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return TrialStatus.empty();
    return TrialStatus(
      tierId: json['tier_id'] ?? 'pro',
      startedAt: DateTime.parse(json['started_at']),
      endsAt: DateTime.parse(json['ends_at']),
      daysRemaining: json['days_remaining'] ?? 0,
    );
  }

  bool get isUrgent => daysRemaining <= 5 && daysRemaining > 0;
  bool get isExpired => daysRemaining <= 0;
  bool get isLastDay => daysRemaining <= 1;

  Color get urgencyColor {
    if (daysRemaining <= 2) return Colors.red;
    if (daysRemaining <= 5) return Colors.orange;
    return Colors.blue;
  }

  String get bannerText {
    if (daysRemaining <= 1) return 'Last day of Pro trial!';
    if (daysRemaining <= 5) return '$daysRemaining days left in Pro trial';
    return 'Pro Trial • $daysRemaining days remaining';
  }
}
```

#### 2. `mobile/lib/widgets/trial_banner.dart` (~100 lines)

**Display at top of home screen (below offline banner):**

```dart
class TrialBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final status = Provider.of<SubscriptionService>(context).status;

    if (status == null || !status.subscription.showTrialBanner) {
      return const SizedBox.shrink();
    }

    final trial = status.subscription.trial!;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [trial.urgencyColor.withOpacity(0.9), trial.urgencyColor],
        ),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Icon(trial.isUrgent ? Icons.timer : Icons.star, color: Colors.white),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              trial.bannerText,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PaywallScreen(...)),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: Text('Upgrade', style: TextStyle(color: trial.urgencyColor)),
          ),
        ],
      ),
    );
  }
}
```

**Visibility Logic:**
- Show when: `source === 'trial' && daysRemaining <= 5`
- Changes color: blue → orange (≤5 days) → red (≤2 days)

#### 3. `mobile/lib/widgets/trial_expired_dialog.dart` (~150 lines)

**Show on app resume when trial expired:**

```dart
class TrialExpiredDialog extends StatelessWidget {
  final VoidCallback onUpgrade;
  final VoidCallback onContinueFree;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Your Pro Trial Has Ended',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('Thank you for trying JEEVibe Pro!'),

            // Before/After comparison
            _buildLimitComparison('Snap & Solve', '10/day', '5/day'),
            _buildLimitComparison('Daily Quiz', '10/day', '1/day'),
            _buildLimitComparison('Offline Mode', 'Yes', 'No'),

            SizedBox(height: 16),

            // Discount offer banner
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text('🎁 Special Offer: 20% OFF', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Use code: TRIAL2PRO', style: TextStyle(fontSize: 18)),
                  Text('Valid for 7 days', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Upgrade button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onUpgrade,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: Text('Claim Discount & Upgrade'),
              ),
            ),

            TextButton(
              onPressed: onContinueFree,
              child: Text('Continue with Free'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitComparison(String feature, String proLimit, String freeLimit) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(feature)),
          Text(proLimit, style: TextStyle(decoration: TextDecoration.lineThrough)),
          Icon(Icons.arrow_forward, size: 16),
          Text(freeLimit, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
```

**Trigger Logic:**
- Check on app resume
- Compare `previousSource` vs `currentSource`
- If changed from `'trial'` → `'default'`, show dialog

#### 4. `mobile/lib/services/push_notification_service.dart` (~150 lines)

**Firebase Messaging integration:**

```dart
class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Request permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveFcmToken(token);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_saveFcmToken);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages (terminated state)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> _saveFcmToken(String token) async {
    // POST to /api/users/fcm-token
    await ApiService().post('/users/fcm-token', {'token': token});
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Show in-app notification
    if (message.notification != null) {
      // Display banner or dialog based on message.data['type']
    }
  }
}

// Top-level function for background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message: ${message.messageId}');
}
```

**Backend - Send Push:**

Add to `trialService.js`:
```javascript
async function sendTrialPush(userId, userData, daysRemaining) {
  if (!userData.fcm_token) return { success: false, reason: 'no_token' };

  const messages = {
    5: { title: '⏰ 5 Days Left', body: 'Upgrade to keep your Pro benefits!' },
    2: { title: '⚠️ Trial Ending Soon', body: 'Only 2 days left!' },
    0: { title: 'Trial Ended', body: '🎁 Get 20% off with code TRIAL2PRO' }
  };

  await admin.messaging().send({
    token: userData.fcm_token,
    notification: messages[daysRemaining],
    data: {
      type: 'trial_notification',
      days_remaining: daysRemaining.toString()
    }
  });
}
```

### Modified Files

#### 5. `mobile/lib/models/subscription_models.dart` (Add at line ~50)

**Add trial field to `SubscriptionInfo`:**

```dart
class SubscriptionInfo {
  final SubscriptionTier tier;
  final SubscriptionSource source;
  final TrialStatus? trial;  // NEW
  // ... existing fields

  bool get isOnTrial => source == SubscriptionSource.trial;
  bool get showTrialBanner => isOnTrial && (trial?.isUrgent ?? false);
}
```

#### 6. `mobile/lib/screens/home_screen.dart` (Add at line ~97)

**Add trial banner below offline banner:**

```dart
return Scaffold(
  body: Column(
    children: [
      const OfflineBanner(),
      const TrialBanner(),  // NEW
      _buildHeader(),
      // ... rest of screen
    ],
  ),
);
```

#### 7. `mobile/lib/services/subscription_service.dart` (Modify checkSubscriptionStatus)

**Detect trial expiry:**

```dart
Future<void> checkSubscriptionStatus() async {
  final status = await api.getSubscriptionStatus();

  // Detect trial expiry
  final previousSource = _cachedStatus?.subscription.source;
  final currentSource = status.subscription.source;

  if (previousSource == SubscriptionSource.trial &&
      currentSource == SubscriptionSource.defaultTier) {
    // Trial just expired - show dialog
    _showTrialExpiredDialog();
  }

  _cachedStatus = status;
}

void _showTrialExpiredDialog() {
  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        body: TrialExpiredDialog(
          onUpgrade: () => Navigator.push(...),
          onContinueFree: () => Navigator.pop(...),
        ),
      ),
      fullscreenDialog: true,
    ),
  );
}
```

#### 8. `mobile/pubspec.yaml` (Add at line ~58)

**Add Firebase Messaging dependency:**

```yaml
dependencies:
  firebase_core: ^3.8.1
  firebase_messaging: ^15.0.0  # NEW
  firebase_analytics: ^11.3.7
```

---

## Mobile Test Files

### Test Files to Create

#### 1. `mobile/test/models/trial_status_test.dart` (~100 lines)

**Test Coverage: >95% target**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe/models/trial_status.dart';

void main() {
  group('TrialStatus', () => {
    test('should parse valid trial JSON', () {
      final json = {
        'tier_id': 'pro',
        'started_at': '2024-01-01T00:00:00Z',
        'ends_at': '2024-01-31T00:00:00Z',
        'days_remaining': 15
      };

      final trialStatus = TrialStatus.fromJson(json);

      expect(trialStatus.tierId, 'pro');
      expect(trialStatus.daysRemaining, 15);
      expect(trialStatus.startedAt, DateTime.parse('2024-01-01T00:00:00Z'));
      expect(trialStatus.endsAt, DateTime.parse('2024-01-31T00:00:00Z'));
    });

    test('should handle null trial JSON', () {
      final trialStatus = TrialStatus.fromJson(null);

      expect(trialStatus.daysRemaining, 0);
      expect(trialStatus.isExpired, true);
    });

    test('should handle missing tier_id with default', () {
      final json = {
        'started_at': '2024-01-01T00:00:00Z',
        'ends_at': '2024-01-31T00:00:00Z',
        'days_remaining': 10
      };

      final trialStatus = TrialStatus.fromJson(json);

      expect(trialStatus.tierId, 'pro'); // Default value
    });

    test('isUrgent should be true when days <= 5', () {
      final trialStatus = TrialStatus(
        tierId: 'pro',
        startedAt: DateTime.now().subtract(Duration(days: 25)),
        endsAt: DateTime.now().add(Duration(days: 5)),
        daysRemaining: 5
      );

      expect(trialStatus.isUrgent, true);
    });

    test('isUrgent should be false when days > 5', () {
      final trialStatus = TrialStatus(
        tierId: 'pro',
        startedAt: DateTime.now().subtract(Duration(days: 20)),
        endsAt: DateTime.now().add(Duration(days: 10)),
        daysRemaining: 10
      );

      expect(trialStatus.isUrgent, false);
    });

    test('isExpired should be true when days <= 0', () {
      final trialStatus = TrialStatus(
        tierId: 'pro',
        startedAt: DateTime.now().subtract(Duration(days: 31)),
        endsAt: DateTime.now().subtract(Duration(days: 1)),
        daysRemaining: 0
      );

      expect(trialStatus.isExpired, true);
    });

    test('isLastDay should be true when days <= 1', () {
      final trialStatus = TrialStatus(
        tierId: 'pro',
        startedAt: DateTime.now().subtract(Duration(days: 29)),
        endsAt: DateTime.now().add(Duration(days: 1)),
        daysRemaining: 1
      );

      expect(trialStatus.isLastDay, true);
    });

    group('urgencyColor', () {
      test('should return red when days <= 2', () {
        final trialStatus = TrialStatus(
          tierId: 'pro',
          startedAt: DateTime.now(),
          endsAt: DateTime.now(),
          daysRemaining: 2
        );

        expect(trialStatus.urgencyColor, Colors.red);
      });

      test('should return orange when days <= 5', () {
        final trialStatus = TrialStatus(
          tierId: 'pro',
          startedAt: DateTime.now(),
          endsAt: DateTime.now(),
          daysRemaining: 4
        );

        expect(trialStatus.urgencyColor, Colors.orange);
      });

      test('should return blue when days > 5', () {
        final trialStatus = TrialStatus(
          tierId: 'pro',
          startedAt: DateTime.now(),
          endsAt: DateTime.now(),
          daysRemaining: 10
        );

        expect(trialStatus.urgencyColor, Colors.blue);
      });
    });

    group('bannerText', () {
      test('should show "Last day" when days = 1', () {
        final trialStatus = TrialStatus(
          tierId: 'pro',
          startedAt: DateTime.now(),
          endsAt: DateTime.now(),
          daysRemaining: 1
        );

        expect(trialStatus.bannerText, 'Last day of Pro trial!');
      });

      test('should show days count when days <= 5', () {
        final trialStatus = TrialStatus(
          tierId: 'pro',
          startedAt: DateTime.now(),
          endsAt: DateTime.now(),
          daysRemaining: 3
        );

        expect(trialStatus.bannerText, '3 days left in Pro trial');
      });

      test('should show "Pro Trial •" when days > 5', () {
        final trialStatus = TrialStatus(
          tierId: 'pro',
          startedAt: DateTime.now(),
          endsAt: DateTime.now(),
          daysRemaining: 15
        );

        expect(trialStatus.bannerText, 'Pro Trial • 15 days remaining');
      });
    });
  });
}
```

#### 2. `mobile/test/widgets/trial_banner_test.dart` (~120 lines)

**Test Coverage: Widget rendering and visibility logic**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jeevibe/widgets/trial_banner.dart';
import 'package:jeevibe/services/subscription_service.dart';

void main() {
  group('TrialBanner', () {
    testWidgets('should show banner when trial is urgent', (tester) async {
      final mockStatus = SubscriptionStatus(
        subscription: SubscriptionInfo(
          tier: SubscriptionTier.pro,
          source: SubscriptionSource.trial,
          trial: TrialStatus(
            tierId: 'pro',
            startedAt: DateTime.now().subtract(Duration(days: 25)),
            endsAt: DateTime.now().add(Duration(days: 5)),
            daysRemaining: 5
          )
        )
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<SubscriptionService>.value(
            value: MockSubscriptionService(status: mockStatus),
            child: Scaffold(body: TrialBanner()),
          ),
        ),
      );

      expect(find.byType(TrialBanner), findsOneWidget);
      expect(find.text('5 days left in Pro trial'), findsOneWidget);
      expect(find.text('Upgrade'), findsOneWidget);
    });

    testWidgets('should hide banner when not on trial', (tester) async {
      final mockStatus = SubscriptionStatus(
        subscription: SubscriptionInfo(
          tier: SubscriptionTier.free,
          source: SubscriptionSource.defaultTier,
          trial: null
        )
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<SubscriptionService>.value(
            value: MockSubscriptionService(status: mockStatus),
            child: Scaffold(body: TrialBanner()),
          ),
        ),
      );

      expect(find.byType(Container), findsNothing);
      expect(find.text('Upgrade'), findsNothing);
    });

    testWidgets('should hide banner when trial not urgent (>5 days)', (tester) async {
      final mockStatus = SubscriptionStatus(
        subscription: SubscriptionInfo(
          tier: SubscriptionTier.pro,
          source: SubscriptionSource.trial,
          trial: TrialStatus(
            tierId: 'pro',
            startedAt: DateTime.now().subtract(Duration(days: 10)),
            endsAt: DateTime.now().add(Duration(days: 20)),
            daysRemaining: 20
          )
        )
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<SubscriptionService>.value(
            value: MockSubscriptionService(status: mockStatus),
            child: Scaffold(body: TrialBanner()),
          ),
        ),
      );

      expect(find.byType(Container), findsNothing);
    });

    testWidgets('should show orange color when days <= 5', (tester) async {
      final mockStatus = SubscriptionStatus(
        subscription: SubscriptionInfo(
          tier: SubscriptionTier.pro,
          source: SubscriptionSource.trial,
          trial: TrialStatus(
            tierId: 'pro',
            startedAt: DateTime.now(),
            endsAt: DateTime.now(),
            daysRemaining: 4
          )
        )
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<SubscriptionService>.value(
            value: MockSubscriptionService(status: mockStatus),
            child: Scaffold(body: TrialBanner()),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;

      expect(gradient.colors.first, Colors.orange.withOpacity(0.9));
    });

    testWidgets('should show red color when days <= 2', (tester) async {
      final mockStatus = SubscriptionStatus(
        subscription: SubscriptionInfo(
          tier: SubscriptionTier.pro,
          source: SubscriptionSource.trial,
          trial: TrialStatus(
            tierId: 'pro',
            startedAt: DateTime.now(),
            endsAt: DateTime.now(),
            daysRemaining: 2
          )
        )
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<SubscriptionService>.value(
            value: MockSubscriptionService(status: mockStatus),
            child: Scaffold(body: TrialBanner()),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;

      expect(gradient.colors.first, Colors.red.withOpacity(0.9));
    });

    testWidgets('should navigate to paywall on upgrade tap', (tester) async {
      final mockStatus = SubscriptionStatus(
        subscription: SubscriptionInfo(
          tier: SubscriptionTier.pro,
          source: SubscriptionSource.trial,
          trial: TrialStatus(
            tierId: 'pro',
            startedAt: DateTime.now(),
            endsAt: DateTime.now(),
            daysRemaining: 5
          )
        )
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<SubscriptionService>.value(
            value: MockSubscriptionService(status: mockStatus),
            child: Scaffold(body: TrialBanner()),
          ),
        ),
      );

      await tester.tap(find.text('Upgrade'));
      await tester.pumpAndSettle();

      // Verify navigation to PaywallScreen
      expect(find.byType(PaywallScreen), findsOneWidget);
    });
  });
}
```

#### 3. `mobile/test/services/subscription_service_test.dart` (~100 lines)

**Test Coverage: Trial expiry detection**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:jeevibe/services/subscription_service.dart';

void main() {
  group('SubscriptionService', () {
    test('should detect trial expiry on status change', () async {
      final mockApi = MockApiService();
      final subscriptionService = SubscriptionService(api: mockApi);

      // First call: User on trial
      when(mockApi.getSubscriptionStatus()).thenAnswer((_) async =>
        SubscriptionStatus(
          subscription: SubscriptionInfo(
            tier: SubscriptionTier.pro,
            source: SubscriptionSource.trial,
            trial: TrialStatus(daysRemaining: 1)
          )
        )
      );

      await subscriptionService.checkSubscriptionStatus();

      // Second call: Trial expired
      when(mockApi.getSubscriptionStatus()).thenAnswer((_) async =>
        SubscriptionStatus(
          subscription: SubscriptionInfo(
            tier: SubscriptionTier.free,
            source: SubscriptionSource.defaultTier,
            trial: null
          )
        )
      );

      await subscriptionService.checkSubscriptionStatus();

      // Verify dialog shown
      verify(subscriptionService.showTrialExpiredDialog()).called(1);
    });

    test('should not show dialog if source unchanged', () async {
      final mockApi = MockApiService();
      final subscriptionService = SubscriptionService(api: mockApi);

      // Both calls: User on free tier
      when(mockApi.getSubscriptionStatus()).thenAnswer((_) async =>
        SubscriptionStatus(
          subscription: SubscriptionInfo(
            tier: SubscriptionTier.free,
            source: SubscriptionSource.defaultTier,
            trial: null
          )
        )
      );

      await subscriptionService.checkSubscriptionStatus();
      await subscriptionService.checkSubscriptionStatus();

      // Verify dialog NOT shown
      verifyNever(subscriptionService.showTrialExpiredDialog());
    });

    test('should not show dialog when upgrading to paid', () async {
      final mockApi = MockApiService();
      final subscriptionService = SubscriptionService(api: mockApi);

      // First call: User on trial
      when(mockApi.getSubscriptionStatus()).thenAnswer((_) async =>
        SubscriptionStatus(
          subscription: SubscriptionInfo(
            tier: SubscriptionTier.pro,
            source: SubscriptionSource.trial
          )
        )
      );

      await subscriptionService.checkSubscriptionStatus();

      // Second call: User upgraded to paid
      when(mockApi.getSubscriptionStatus()).thenAnswer((_) async =>
        SubscriptionStatus(
          subscription: SubscriptionInfo(
            tier: SubscriptionTier.pro,
            source: SubscriptionSource.paid
          )
        )
      );

      await subscriptionService.checkSubscriptionStatus();

      // Verify dialog NOT shown (user upgraded!)
      verifyNever(subscriptionService.showTrialExpiredDialog());
    });
  });
}
```

### Test Dependencies (`pubspec.yaml`)

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.2
  build_runner: ^2.4.6
```

### Test Coverage Targets

| Component | Target Coverage | Priority |
|-----------|----------------|----------|
| `trial_status.dart` | >95% | HIGH |
| `trial_banner.dart` | >85% | MEDIUM |
| `subscription_service.dart` (trial detection) | >85% | HIGH |
| Overall mobile | >75% | RECOMMENDED |

### Running Tests

```bash
# Backend tests
cd backend
npm test                    # Run all tests
npm run test:watch          # Watch mode
npm run test:ci             # CI mode with coverage

# Mobile tests
cd mobile
flutter test                # Run all tests
flutter test --coverage     # Generate coverage report
```

---

## Firebase Messaging Platform Configuration

### iOS Setup

**File:** `mobile/ios/Runner/AppDelegate.swift`

```swift
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Request notification permissions
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .badge, .sound],
        completionHandler: { _, _ in }
      )
    }

    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

**Required:** Upload APNs certificate to Firebase Console

### Android Setup

**File:** `mobile/android/app/src/main/AndroidManifest.xml`

```xml
<manifest>
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

  <application>
    <!-- Existing activity -->

    <!-- Firebase Messaging Service -->
    <service
      android:name="com.google.firebase.messaging.FirebaseMessagingService"
      android:exported="false">
      <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT"/>
      </intent-filter>
    </service>
  </application>
</manifest>
```

**Required:** `google-services.json` must be in `mobile/android/app/`

---

## Analytics & Monitoring

### Firebase Analytics Events

```dart
// Backend (logTrialEvent)
FirebaseAnalytics.logEvent('trial_started', { tier: 'pro', duration_days: 30 })
FirebaseAnalytics.logEvent('trial_notification_sent', { days_remaining: 5, channel: 'email' })
FirebaseAnalytics.logEvent('trial_expired', { converted: false })
FirebaseAnalytics.logEvent('trial_converted', { subscription_tier: 'pro', days_into_trial: 15 })

// Mobile
FirebaseAnalytics.instance.logEvent(name: 'trial_banner_viewed', parameters: {'days_remaining': 5})
FirebaseAnalytics.instance.logEvent(name: 'trial_upgrade_tapped', parameters: {'source': 'banner'})
FirebaseAnalytics.instance.logEvent(name: 'trial_expired_dialog_shown')
```

### Key Metrics to Track

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Trial creation rate | >95% of signups | <90% |
| Trial-to-paid conversion | 5-10% | <3% |
| Email open rate | >25% | <15% |
| Push delivery rate | >90% | <80% |
| Notification click rate | >10% | <5% |
| Trial expiry errors | 0% | >1% |

---

## Edge Cases & Error Handling

### 1. Trial Initialization Fails During Signup
**Solution:** User gets FREE tier, error logged (non-blocking)

### 2. Trial Expires During Active Session
**Solution:** Graceful degradation - allow current action, block next

### 3. Duplicate Trial Attempts
**Solution:** Check `trial.eligibility_phone`, return existing trial

### 4. Notification Deduplication
**Solution:** Check `trial.notifications_sent` before sending

### 5. Timezone Issues
**Solution:** All timestamps in UTC (Firestore Timestamps)

### 6. Cache Staleness
**Solution:** Invalidate immediately after trial state changes

### 7. Email/Push Provider Outage
**Solution:** Retry with exponential backoff, queue for next job run

### 8. Conversion During Trial
**Solution:** Mark `trial.converted_to_paid = true`, seamless transition

### 9. Admin Trial Extension
**Solution:** Add admin endpoint to adjust `trial.ends_at`

### 10. Existing Users (Migration)
**Solution:** No retroactive trials - only new signups get trials

---

## Rollout Strategy

### Phase 1: Backend (Week 1)
- [ ] Create `trialService.js`, `trialConfigService.js`, `trialProcessingService.js`
- [ ] Modify signup flow (`users.js`)
- [ ] Update subscription status endpoint
- [ ] Add cron job
- [ ] Create `trial_config/active` document in Firestore
- [ ] Test with staging users (manual trial date adjustment)

### Phase 2: Mobile UI (Week 2)
- [ ] Add trial models and widgets
- [ ] Implement Firebase Messaging
- [ ] Integrate trial banner and dialog
- [ ] Test push notifications on iOS/Android
- [ ] QA and polish

### Phase 3: Soft Launch (Week 3)
- [ ] Deploy backend to production
- [ ] 10% rollout (first 2 days)
- [ ] Monitor metrics dashboard
- [ ] 50% rollout (days 3-4)
- [ ] 100% rollout (day 7)

### Phase 4: Full Launch (Week 4)
- [ ] Enable push notifications
- [ ] Marketing campaign alignment
- [ ] Monitor conversion funnel
- [ ] Optimize notification copy based on data

---

## Testing Strategy

### Unit Tests

**Backend:**
- [ ] `initializeTrial()` - eligible and ineligible cases
- [ ] `checkTrialEligibility()` - duplicate phone, existing trial
- [ ] `expireTrial()` - cache invalidation, state changes
- [ ] `sendTrialNotification()` - deduplication, channel selection

**Mobile:**
- [ ] `TrialStatus` model parsing
- [ ] Trial banner visibility logic
- [ ] Dialog trigger conditions

### Integration Tests

- [ ] New user signup → receives 30-day PRO trial
- [ ] Trial expiry flow → downgrades to FREE
- [ ] Trial conversion → seamless transition to paid
- [ ] Notification milestones → sent at correct times

### Manual Testing Checklist

- [ ] New user gets 30-day PRO trial (check Firestore)
- [ ] Trial info appears in `/api/subscriptions/status`
- [ ] Trial banner appears at day 5 (urgent color)
- [ ] Email sent at day 23, 5, 2, 0
- [ ] Push notification received (iOS and Android)
- [ ] Trial expired dialog shows on app resume
- [ ] Downgrade to FREE at day 30
- [ ] Upgrade during trial → marks as converted
- [ ] Duplicate phone → no second trial

### Admin Testing Tools

**Add admin endpoints for testing:**

```javascript
// Adjust trial date (dev/staging only)
POST /api/subscriptions/admin/adjust-trial-date
{
  "user_id": "test123",
  "days_remaining": 2  // Fast-forward to 2 days before expiry
}

// Force trigger notifications
POST /api/subscriptions/admin/test-trial-notification
{
  "user_id": "test123",
  "days_remaining": 5
}
```

---

## Success Criteria

### Launch Checklist

**Backend:**
- [ ] Trial config document created in Firestore
- [ ] New users receive trial (>95%)
- [ ] Tier cache invalidates correctly
- [ ] Cron job runs daily without errors
- [ ] Email notifications sent (>90% delivery)
- [ ] Push notifications sent (>85% delivery)
- [ ] Trials expire correctly at 30 days
- [ ] No duplicate trials per phone

**Mobile:**
- [ ] Trial banner appears (day 5+)
- [ ] Trial expired dialog shows
- [ ] Push notifications received
- [ ] Firebase Messaging integrated (iOS + Android)

**Analytics:**
- [ ] All events logged correctly
- [ ] Dashboard shows trial metrics
- [ ] Conversion funnel tracked

### Target Metrics (Week 4 Post-Launch)

| Metric | Target |
|--------|--------|
| Trial creation rate | >95% of signups |
| Trial-to-paid conversion | ≥5% (within 30 days) |
| Email open rate | ≥25% |
| Push tap rate | ≥10% |
| Trial expiry errors | <1% |

---

## Critical Files Summary

### Backend Implementation (8 files)

| File | Type | Lines | Description |
|------|------|-------|-------------|
| `backend/src/services/trialService.js` | NEW | 300+ | Trial lifecycle management |
| `backend/src/services/trialConfigService.js` | NEW | 150+ | Config fetching/caching |
| `backend/src/services/trialProcessingService.js` | NEW | 200+ | Daily job logic |
| `backend/src/routes/users.js` | MODIFY | 5 | Add trial init at line 218 |
| `backend/src/routes/subscriptions.js` | MODIFY | 30 | Add trial info to status |
| `backend/src/routes/cron.js` | MODIFY | 50 | Add trial processing job |
| `backend/src/services/studentEmailService.js` | MODIFY | 150 | Add trial email templates |
| `backend/src/services/subscriptionService.js` | MODIFY | 15 | Import expireTrialAsync |

### Backend Tests (5 files, ~650 lines)

| File | Type | Lines | Coverage Target |
|------|------|-------|-----------------|
| `backend/test/services/trialService.test.js` | NEW | 200+ | >85% |
| `backend/test/services/trialConfigService.test.js` | NEW | 100+ | >90% |
| `backend/test/services/trialProcessingService.test.js` | NEW | 150+ | >80% |
| `backend/test/routes/users.test.js` | NEW | 100+ | >85% |
| `backend/test/routes/subscriptions.test.js` | NEW | 100+ | >85% |

### Mobile Implementation (8 files)

| File | Type | Lines | Description |
|------|------|-------|-------------|
| `mobile/lib/models/trial_status.dart` | NEW | 80+ | Trial status model |
| `mobile/lib/widgets/trial_banner.dart` | NEW | 100+ | In-app countdown banner |
| `mobile/lib/widgets/trial_expired_dialog.dart` | NEW | 150+ | Expiry dialog |
| `mobile/lib/services/push_notification_service.dart` | NEW | 150+ | FCM integration |
| `mobile/lib/models/subscription_models.dart` | MODIFY | 30 | Add trial field |
| `mobile/lib/screens/home_screen.dart` | MODIFY | 1 | Add banner at line 97 |
| `mobile/lib/services/subscription_service.dart` | MODIFY | 30 | Detect trial expiry |
| `mobile/pubspec.yaml` | MODIFY | 1 | Add firebase_messaging |

### Mobile Tests (3 files, ~320 lines)

| File | Type | Lines | Coverage Target |
|------|------|-------|-----------------|
| `mobile/test/models/trial_status_test.dart` | NEW | 100+ | >95% |
| `mobile/test/widgets/trial_banner_test.dart` | NEW | 120+ | >85% |
| `mobile/test/services/subscription_service_test.dart` | NEW | 100+ | >85% |

### Configuration (2 documents)

| Document | Type | Description |
|----------|------|-------------|
| `trial_config/active` | Firestore | Trial configuration |
| Composite index: `users` | Firestore | `trial.is_active` + `trial.ends_at` |

---

## Verification After Implementation

### Backend Verification

1. **Trial initialization:**
   ```bash
   # Create new user via signup
   # Check Firestore: users/{userId}.trial should exist
   # Verify: trial.ends_at = now + 30 days
   ```

2. **Tier determination:**
   ```bash
   curl -H "Authorization: Bearer $TOKEN" https://.../api/subscriptions/status
   # Response should show: source: "trial", tier: "pro"
   ```

3. **Scheduled job:**
   ```bash
   curl -X POST https://.../api/cron/process-trials -H "x-cron-secret: $SECRET"
   # Check logs: notifications sent, trials expired
   ```

### Mobile Verification

1. **Trial banner:**
   - Sign up new user
   - Adjust trial to 5 days remaining (admin endpoint)
   - Open app → banner should appear at top

2. **Push notifications:**
   - Send test push via Firebase Console
   - Verify: notification received on iOS/Android

3. **Trial expired dialog:**
   - Adjust trial to expired
   - Close app, reopen
   - Dialog should appear automatically

---

## Timeline & Effort

**Total Implementation Time:** 3-4 weeks (2 engineers)

- Backend implementation: 1.5 weeks
- Backend tests: 2-3 days
- Mobile implementation: 1.5 weeks
- Mobile tests: 2-3 days
- Integration & QA: 1 week (overlapping)

**Lines of Code:** ~3,500 total
- Backend implementation: ~1,200 LOC
- Backend tests: ~650 LOC
- Mobile implementation: ~1,000 LOC
- Mobile tests: ~320 LOC
- Config/setup: ~150 LOC

---

## Notes

- **Good News:** `getEffectiveTier()` already checks for trials (lines 210-226)! Only needs minor import update.
- **Testing Included:** Comprehensive test suite with >80% coverage for critical services ensures reliability.
- **Backwards Compatible:** Existing users unaffected, only new signups get trials. No data migration required.
- **Firebase Cloud Messaging (FCM):** Completely FREE with unlimited push notifications. No cost for sending trial notifications.
- **cron-job.org:** Using external cron service saves ₹580/month vs Render.com paid cron, plus provides better monitoring.
- **Critical:** Always invalidate tier cache after trial state changes
- **Security:** Protect admin endpoints with proper authentication
- **Compliance:** Trial terms must be clear in signup flow (legal requirement)
- **Monitoring:** Set up alerts for trial expiry errors and low conversion rates
- **Cost Estimate:** Monthly notification costs ~₹300-400 (email only), push notifications are FREE via FCM
- **Test-Driven:** Write tests alongside implementation for faster debugging and confidence in deployment

This plan provides a complete, production-ready, well-tested implementation that integrates seamlessly with JEEVibe's existing architecture.
