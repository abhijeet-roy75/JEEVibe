# Test Users Documentation

**Created:** 2026-02-27
**Script:** `backend/scripts/e2e/setup-test-users.js`

---

## Test Phone Numbers

All test phone numbers are configured in Firebase Console with OTP code: **`123456`**

## Test User Credentials

### Free Tier Users (3)

| User ID | Phone | Display Name | Progress | Coaching | Usage |
|---------|-------|--------------|----------|----------|-------|
| `test-user-free-001` | +16505551001 | Test Free User 1 | ❌ None | ❌ No | New user, no history |
| `test-user-free-002` | +16505551002 | Test Free User 2 | ✅ Active | ✅ Yes | 20 quizzes, 10 practice sessions |
| `test-user-free-003` | +16505551003 | Test Free User 3 | ✅ Light | ❌ No | 5 quizzes, 3 practice sessions |

**Free Tier Limits:**
- Daily Quiz: 1/day (5 questions)
- Chapter Practice: 5 chapters/day, 5 questions/chapter
- Snap & Solve: 5/day
- Mock Tests: 1/month

---

### Pro Tier Users (3)

| User ID | Phone | Display Name | Progress | Coaching | Usage |
|---------|-------|--------------|----------|----------|-------|
| `test-user-pro-001` | +16505551004 | Test Pro User 1 | ❌ None | ❌ No | New Pro subscriber |
| `test-user-pro-002` | +16505551005 | Test Pro User 2 | ✅ Active | ✅ Yes | 50 quizzes, 30 practice sessions |
| `test-user-pro-003` | +16505551006 | Test Pro User 3 | ✅ Very Active | ❌ No | 100 quizzes, 60 practice sessions |

**Pro Tier Limits:**
- Daily Quiz: 10/day (5 questions each)
- Chapter Practice: Unlimited chapters, 15 questions/chapter
- Snap & Solve: 15/day
- Mock Tests: 5/month
- Offline Mode: ✅ Enabled

---

### Ultra Tier Users (2)

| User ID | Phone | Display Name | Progress | Coaching | Usage |
|---------|-------|--------------|----------|----------|-------|
| `test-user-ultra-001` | +16505551007 | Test Ultra User 1 | ✅ Very Active | ✅ Yes | 150 quizzes, 80 practice sessions |
| `test-user-ultra-002` | +16505551008 | Test Ultra User 2 | ✅ Power User | ❌ No | 200 quizzes, 100 practice sessions |

**Ultra Tier Limits:**
- Daily Quiz: 25/day (5 questions each)
- Chapter Practice: Unlimited chapters, 15 questions/chapter
- Snap & Solve: 50/day
- Mock Tests: Unlimited
- AI Tutor: ✅ Enabled
- Offline Mode: ✅ Enabled

---

### Trial Users (2)

| User ID | Phone | Display Name | Trial Status | Usage |
|---------|-------|--------------|--------------|-------|
| `test-user-trial-active` | +16505551009 | Test Trial Active | ✅ 25 days remaining | 10 quizzes, 5 practice sessions |
| `test-user-trial-expiring` | +16505551010 | Test Trial Expiring | ⚠️ 1 day remaining | 30 quizzes, 15 practice sessions |

**Trial Tier (Pro features):**
- Duration: 30 days
- Features: Same as Pro tier
- Expires to: Free tier

---

## How to Use Test Users

### 1. Authentication

Sign in with any test phone number using OTP `123456`:

```javascript
// Mobile app
await FirebaseAuth.signInWithPhoneNumber('+16505551001');
// Enter OTP: 123456

// Or use Firebase test phone in emulator
// OTP is automatically verified
```

### 2. Testing Tier Limits

**Free Tier Testing:**
```bash
# Test daily quiz limit (1/day)
curl -X POST https://your-backend/api/daily-quiz/generate \
  -H "Authorization: Bearer <token-from-test-user-free-001>"

# Should succeed once, fail on second attempt same day
```

**Pro Tier Testing:**
```bash
# Test chapter practice limit (15 questions)
curl -X POST https://your-backend/api/chapter-practice/start \
  -H "Authorization: Bearer <token-from-test-user-pro-001>" \
  -d '{"chapterKey": "physics_kinematics", "questionCount": 15}'

# Should succeed (Pro limit is 15)
```

### 3. Testing Theta Calculations

Users with progress have varied theta values:

- `test-user-free-002`: Overall theta ~ -0.4 (lower skill, 20 quizzes)
- `test-user-pro-002`: Overall theta ~ -0.25 (moderate skill, 50 quizzes)
- `test-user-pro-003`: Overall theta ~ 0.0 (average skill, 100 quizzes)
- `test-user-ultra-001`: Overall theta ~ +0.25 (above average, 150 quizzes)
- `test-user-ultra-002`: Overall theta ~ +0.5 (high skill, 200 quizzes)

### 4. Testing Trial Expiry

**Active Trial:**
```bash
# Test user with 25 days remaining
# Should have Pro features enabled
# Use: test-user-trial-active
```

**Expiring Trial:**
```bash
# Test user with 1 day remaining
# Should trigger trial expiry warning
# Use: test-user-trial-expiring
```

---

## Resetting Test Data

To reset all test users to a clean state:

```bash
cd backend
node scripts/e2e/reset-test-data.js
```

This will:
1. Delete all test user data (Firestore, daily_usage, quiz history)
2. Keep Firebase Auth accounts intact
3. Recreate Firestore user documents with fresh data
4. Reset daily usage counters

---

## Validating Test Environment

Before running tests, validate the test environment:

```bash
cd backend
node scripts/e2e/validate-test-env.js
```

Checks:
- ✅ Firebase credentials valid
- ✅ Firestore reachable
- ✅ All 10 test users exist in Firebase Auth
- ✅ All 10 test users have Firestore documents
- ✅ Firebase test phones configured (10 numbers)
- ✅ Question bank has sufficient questions (500+)

---

## Test User Data Structure

### Firestore User Document

```javascript
{
  // Identity
  phoneNumber: '+16505551001',
  displayName: 'Test Free User 1',
  isEnrolledInCoaching: false,

  // Subscription
  subscriptionStatus: 'free', // or 'pro', 'ultra', 'pro_trial'
  subscriptionTier: 'Free', // or 'Pro', 'Ultra'
  subscription: {
    tier: 'free',
    status: 'active',
    last_synced: Timestamp,
    // Pro/Ultra users have override for testing:
    override: {
      type: 'testing',
      tier_id: 'pro',
      granted_by: 'setup-test-users-script',
      granted_at: Timestamp,
      expires_at: Timestamp,  // 90 days from creation
      reason: 'Test user for automated testing'
    }
  },

  // Trial data (trial users only)
  trial: {
    ends_at: Timestamp,
    started_at: Timestamp,
    is_active: true,
    tier_id: 'pro'
  },
  trialEndsAt: Timestamp,

  // Theta data
  overall_theta: 0.0,
  overall_percentile: 50.0,
  theta_by_subject: {
    physics: { theta: 0.0, se: 0.6, questions_answered: 0 },
    chemistry: { theta: 0.0, se: 0.6, questions_answered: 0 },
    mathematics: { theta: 0.0, se: 0.6, questions_answered: 0 }
  },
  theta_by_chapter: {
    physics_kinematics: { theta: 0.1, se: 0.25, questions_answered: 10 },
    // ...
  },

  // Usage stats
  quizzes_completed: 20,
  chapter_practice_completed: 10,

  // Timestamps
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Daily Usage Document

```javascript
{
  date: Timestamp, // Today 00:00:00
  snap_solve_count: 2, // Current usage (free: 2, pro: 5, ultra: 10)
  daily_quiz_count: 0, // Current usage
  chapter_practice_count: 2, // Current usage
  last_updated: Timestamp
}
```

---

## Security Note

⚠️ **These are test users only!** Do NOT use in production.

- Test phone numbers (+1650555xxxx) are for development only
- OTP code `123456` is hardcoded in Firebase Console
- Test users have `subscription.override.type = 'testing'` for easy identification
- Delete test users before production launch

---

## Troubleshooting

### Test user authentication fails

**Problem:** Cannot sign in with test phone number

**Solution:**
1. Verify Firebase test phones configured in Firebase Console
2. Check OTP code is `123456` for all test numbers
3. Verify Firebase Auth is enabled for phone authentication

### Test user not found in Firestore

**Problem:** User authenticates but no Firestore document

**Solution:**
1. Run `node scripts/e2e/setup-test-users.js` again
2. Check Firestore permissions (serviceAccountKey.json)
3. Verify Firestore database exists

### Tier limits not enforced correctly

**Problem:** Free user can access Pro features

**Solution:**
1. Check `tierConfigService` is reading correct limits
2. Verify subscription cache TTL (60 seconds)
3. Invalidate cache: Use `manage-tier.js` script to reset tier

---

## Related Scripts

- **`backend/scripts/e2e/setup-test-users.js`** - Create 10 test users (this script)
- **`backend/scripts/e2e/reset-test-data.js`** - Reset test data to clean state
- **`backend/scripts/e2e/validate-test-env.js`** - Validate test environment
- **`backend/scripts/manage-tier.js`** - Manually change user tiers

---

**Last Updated:** 2026-02-27
**Maintained By:** Testing Infrastructure Team
