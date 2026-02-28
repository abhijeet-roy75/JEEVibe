# End-to-End Testing Scripts

This directory contains scripts for setting up and managing the end-to-end testing environment for JEEVibe.

## Scripts

### 1. setup-test-users.js

Creates 10 standard test users across all tiers for testing.

**Usage:**
```bash
cd backend
node scripts/e2e/setup-test-users.js
```

**What it does:**
- Creates 10 Firebase Auth accounts (if they don't exist)
- Creates Firestore user documents with proper structure
- Generates realistic theta data based on user progress
- Sets up subscription tiers (free, pro, ultra, trial)
- Creates testing overrides for pro/ultra users

**Test Users Created:**
- 3 Free tier users (with varying progress levels)
- 3 Pro tier users (with testing overrides)
- 2 Ultra tier users (with testing overrides)
- 2 Trial users (active with 25 days, expiring with 1 day)

**Prerequisites:**
- Firebase test phone numbers configured in Firebase Console
- All phones should use OTP code: `123456`

---

### 2. reset-test-data.js

Resets all test user data to a clean state.

**Usage:**
```bash
cd backend
node scripts/e2e/reset-test-data.js
```

**What it does:**
- Deletes all subcollections for test users:
  - `daily_usage`
  - `daily_quizzes`
  - `chapter_sessions`
  - `assessments`
  - `mock_test_sessions`
  - `snap_history`
  - `theta_snapshots`
- Deletes main user documents
- Recreates user documents with fresh data
- Keeps Firebase Auth accounts intact

**When to use:**
- Before starting a new round of testing
- After tests have polluted user data
- To restore users to known initial state

---

### 3. validate-test-env.js

Validates that the test environment is properly configured.

**Usage:**
```bash
cd backend
node scripts/e2e/validate-test-env.js
```

**What it checks:**
1. ✅ Firebase credentials are valid
2. ✅ Firestore is reachable
3. ✅ Question bank has minimum 500 questions
4. ✅ Assessment questions exist (30+)
5. ✅ Mock test templates exist (1+)
6. ✅ `tier_config` collection exists with valid data
7. ✅ All 10 test users exist in Firebase Auth
8. ✅ All 10 test users exist in Firestore
9. ⚠️  Firebase test phones (manual verification needed)
10. ✅ All test fixtures exist (8 files)
11. ✅ All test factories exist (5 files)

**Exit codes:**
- `0` - All checks passed (ready for testing)
- `1` - One or more checks failed (fix issues before testing)

**When to use:**
- Before running test suite
- After setting up new test environment
- When debugging test failures

---

## Test Environment Structure

```
backend/
├── scripts/
│   └── e2e/
│       ├── setup-test-users.js      ← Create test users
│       ├── reset-test-data.js       ← Reset to clean state
│       └── validate-test-env.js     ← Validate setup
├── tests/
│   ├── fixtures/                    ← Static test data (JSON)
│   │   ├── questions-100.json
│   │   ├── mock-test-template.json
│   │   ├── quiz-responses-valid.json
│   │   └── ... (8 files total)
│   └── factories/                   ← Dynamic test data (JS)
│       ├── userFactory.js
│       ├── questionFactory.js
│       ├── quizFactory.js
│       └── ... (5 files total)
└── docs/05-testing/e2e/            ← Testing documentation
    ├── COMPREHENSIVE-TESTING-PLAN.md
    ├── TESTING-USERS.md
    └── ...
```

---

## Common Workflows

### Initial Setup

```bash
# 1. Configure Firebase test phones in Firebase Console
#    https://console.firebase.google.com/project/_/authentication/providers
#    Add phones: +16505551001 through +16505551010
#    OTP code: 123456

# 2. Create test users
cd backend
node scripts/e2e/setup-test-users.js

# 3. Validate environment
node scripts/e2e/validate-test-env.js

# 4. Run tests
npm test
```

### Between Test Runs

```bash
# Reset test data to clean state
cd backend
node scripts/e2e/reset-test-data.js

# Validate before running tests again
node scripts/e2e/validate-test-env.js

# Run tests
npm test
```

### Troubleshooting

```bash
# Check what's wrong with test environment
cd backend
node scripts/e2e/validate-test-env.js

# If test users are corrupted, recreate them
node scripts/e2e/reset-test-data.js

# If that doesn't work, delete and recreate
# (Note: Firebase Auth accounts will be preserved)
node scripts/e2e/setup-test-users.js
```

---

## Test User Credentials

See [docs/05-testing/e2e/TESTING-USERS.md](../../../docs/05-testing/e2e/TESTING-USERS.md) for complete list of test users, phone numbers, and tier details.

**Quick reference:**
- Free users: `test-user-free-001`, `test-user-free-002`, `test-user-free-003`
- Pro users: `test-user-pro-001`, `test-user-pro-002`, `test-user-pro-003`
- Ultra users: `test-user-ultra-001`, `test-user-ultra-002`
- Trial users: `test-user-trial-active`, `test-user-trial-expiring`

**Phone numbers:** `+16505551001` through `+16505551010`
**OTP code:** `123456` (for all test phones)

---

## Related Documentation

- [COMPREHENSIVE-TESTING-PLAN.md](../../../docs/05-testing/e2e/COMPREHENSIVE-TESTING-PLAN.md) - Full testing strategy
- [TESTING-USERS.md](../../../docs/05-testing/e2e/TESTING-USERS.md) - Test user credentials
- [BACKEND-TESTING-PRIORITY.md](../../../docs/05-testing/e2e/BACKEND-TESTING-PRIORITY.md) - Week 1 execution plan

---

**Last Updated:** 2026-02-27
**Maintained By:** Testing Infrastructure Team
