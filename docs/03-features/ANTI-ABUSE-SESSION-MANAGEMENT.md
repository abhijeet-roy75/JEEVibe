# Anti-Abuse & Session Management

> **Status**: ✅ P0 Complete (Backend + Mobile)
>
> **Priority**: Critical (Pre-Launch)
>
> **Created**: 2026-01-23
>
> **Last Updated**: 2026-01-24
>
> **Related**: [TIER-SYSTEM-ARCHITECTURE.md](./TIER-SYSTEM-ARCHITECTURE.md), [BUSINESS-MODEL-REVIEW.md](../09-business/BUSINESS-MODEL-REVIEW.md)

---

## Implementation Status

### ✅ P0: Single Active Session - COMPLETE

**What's Implemented:**
- Custom session tokens (not Firebase tokens) for instant invalidation
- Only ONE session valid at any time - new login invalidates all previous sessions
- Session token stored securely on mobile (Flutter Secure Storage)
- Device ID generated persistently using device_info_plus
- All API calls include `x-session-token` and `x-device-id` headers
- Session expiry detection with force logout dialog
- Server-side session cleared on explicit logout

**Backend Files Created:**
- `backend/src/services/authService.js` - Session creation, token generation, validation
- `backend/src/middleware/sessionValidator.js` - Session validation middleware
- `backend/src/routes/auth.js` - Session endpoints (POST /session, POST /logout)

**Mobile Files Modified:**
- `mobile/lib/services/firebase/auth_service.dart` - Session token & device ID management
- `mobile/lib/services/api_service.dart` - Session headers on all API calls, expiry handling
- `mobile/lib/screens/auth/otp_verification_screen.dart` - Create session after OTP
- `mobile/lib/main.dart` - Session expiry callback and force logout dialog

**Backend Commit:** `9c6ce85` (2026-01-24)

### 🔮 Future Work (Not Yet Implemented)

| Priority | Feature | Description | When to Implement |
|----------|---------|-------------|-------------------|
| **P1** | Device Limits | Allow 1 device (Free) or 2 devices (Pro/Ultra) instead of single session | Post-launch, if users request multi-device |
| **P2** | Session Expiry | Auto-expire sessions after 30 days, require re-OTP | Post-launch |
| **P3** | Soft Caps | Replace -1 (unlimited) with high caps (50/day) for Ultra | Already done in tier config |

**Note on P1:** P0 (single session) is MORE restrictive than P1 (multi-device). P1 is a UX convenience feature for paying users (phone + tablet), NOT additional security. P0 alone prevents account sharing effectively.

## Problem Statement

The Ultra tier offers "unlimited" access to premium features (Snap & Solve, AI Tutor, Daily Quiz). Without session controls, account sharing undermines the business model:

```
1 Ultra Annual = ₹3,588
Shared among 10 friends = ₹359/person/year = ₹30/month

vs Pro tier = ₹299/month
```

**Risk**: Account sharing kills Pro tier conversions and reduces Ultra revenue by 90%.

---

## Current Authentication Flow (P0 Complete)

```
SIGNUP (first time):
├── User enters phone number
├── OTP sent via SMS
├── User verifies OTP
├── Account created in Firebase Auth
├── ✅ Session token created on server (invalidates any existing session)
├── ✅ Session token stored locally (Flutter Secure Storage)
├── User sets local 4-digit PIN
└── Firebase token stored on device

NEW DEVICE LOGIN:
├── User enters phone number
├── OTP sent via SMS (phone ownership verification)
├── User verifies OTP
├── ✅ New session token created (old device's session immediately invalid)
├── ✅ Old device's next API call returns SESSION_EXPIRED → force logout
├── User sets local PIN on new device
└── Firebase token stored on device

RETURNING USER (same device):
├── App opens → PIN screen
├── User enters local PIN
├── PIN verified locally
├── ✅ Session token already stored → included in API calls
└── Firebase token already stored → API calls work
    (No OTP required, no new session created)

EXPLICIT LOGOUT:
├── User taps "Sign Out" in profile
├── ✅ Backend /api/auth/logout called (clears server session)
├── ✅ Local session token cleared
├── Local PIN cleared
└── Navigate to welcome screen
```

**Key insight**: OTP is only required for signup or new device login. Returning users on the same device only use their local PIN. Session invalidation (kicking out old device) happens when someone logs into a NEW device with OTP - the old device is kicked out immediately on their next API call.

### Current Protections

| Measure | Status | Location |
|---------|--------|----------|
| Phone # validation via SMS | ✅ Done | `mobile/lib/services/firebase/auth_service.dart` |
| Screenshot blocking | ✅ Done | Mobile app |
| API authentication (Firebase tokens) | ✅ Done | `backend/src/middleware/auth.js` |
| Firestore security rules (deny all client) | ✅ Done | `backend/firebase/firestore.rules` |
| Tier-based feature gating | ✅ Done | `backend/src/middleware/featureGate.js` |
| Local PIN for app unlock | ✅ Done | `mobile/lib/services/firebase/pin_service.dart` |
| **Single active session (P0)** | ✅ Done | `backend/src/services/authService.js`, `backend/src/middleware/sessionValidator.js` |
| **Session token in all API calls** | ✅ Done | `mobile/lib/services/api_service.dart` |
| **Logout clears server session** | ✅ Done | `mobile/lib/services/firebase/auth_service.dart` |
| Device limits (P1) | 🔮 Future | Not yet implemented |

### Current Vulnerability

```
Day 1: Student A signs up on Phone 1
Day 2: A logs into Phone 2 with OTP (gives Phone 1 to friend B)
Day 3: A logs into Tablet with OTP (gives Phone 2 to friend C)
...
Result: Multiple devices with valid sessions, shared among friends
```

---

## Codebase Validation (2026-01-24)

### What Currently Exists

| Component | Status | File |
|-----------|--------|------|
| Firebase Auth middleware | Done | `backend/src/middleware/auth.js` |
| Firestore rules (deny all client) | Done | `backend/firebase/firestore.rules` |
| Tier config system | Done | `backend/src/services/tierConfigService.js` |
| Tier config in Firestore | Done | `tier_config/active` document |
| Feature gating middleware | Done | `backend/src/middleware/featureGate.js` |
| Mobile API service | Done | `mobile/lib/services/api_service.dart` |
| Local PIN service | Done | `mobile/lib/services/firebase/pin_service.dart` |
| Sign-out button | Done | `mobile/lib/screens/profile/profile_view_screen.dart` |

### What Was Created (P0 Complete)

| Component | File | Status |
|-----------|------|--------|
| Session validation middleware | `backend/src/middleware/sessionValidator.js` | ✅ Created |
| Auth service (session management) | `backend/src/services/authService.js` | ✅ Created |
| Auth routes | `backend/src/routes/auth.js` | ✅ Created |

### What Was Modified (P0 Complete)

| Component | File | Changes Made |
|-----------|------|--------------|
| App entry point | `backend/src/index.js` | ✅ Registered `/api/auth` routes |
| Tier config defaults | `backend/src/services/tierConfigService.js` | ✅ Added `max_devices: 1` for all tiers, ultra soft caps |
| Tier config Firestore | `tier_config/active` | ✅ Added `max_devices: 1` for all tiers, ultra soft caps |
| API service | `mobile/lib/services/api_service.dart` | ✅ Added `x-session-token` and `x-device-id` headers |
| Auth service | `mobile/lib/services/firebase/auth_service.dart` | ✅ Session token storage, device ID generation |
| OTP verification | `mobile/lib/screens/auth/otp_verification_screen.dart` | ✅ Call `createSession()` after OTP |
| Main app | `mobile/lib/main.dart` | ✅ Session expiry callback and force logout dialog |

### What's Left for P1 (Future)

**Code Changes:**

| Component | File | Changes Needed |
|-----------|------|----------------|
| Device registration | `backend/src/services/authService.js` | Add `registerDevice()`, `getDevices()`, `removeDevice()` |
| Device limit check | `backend/src/middleware/sessionValidator.js` | Check registered devices against tier limit |
| Device endpoints | `backend/src/routes/auth.js` | GET `/devices`, DELETE `/devices/:id` |
| Device manager UI | Mobile app | New screen to view and remove devices |

**Tier Config Changes for P1:**

Update `max_devices` in both `tierConfigService.js` and Firestore `tier_config/active`:

| Tier | P0 (Current) | P1 (Future) |
|------|--------------|-------------|
| free | 1 | 1 (no change) |
| pro | 1 | **2** (phone + tablet) |
| ultra | 1 | **2** (phone + tablet) |

### Why Custom Session Tokens (Not Firebase Tokens)

| Aspect | Firebase Tokens | Custom Session Token |
|--------|-----------------|---------------------|
| Invalidation speed | Async (up to 1 hour) | Instant (single Firestore read) |
| Multi-device control | Unlimited concurrent | Exactly ONE valid |
| Implementation | Need `revokeRefreshTokens()` | Simple string comparison |

Firebase tokens prove *identity*. Session tokens control *access*. When User A logs into Phone 2, Phone 1 should be kicked out **immediately**.

---

## Solution: Session Management

### Priority Levels

| Priority | Measure | Effort | Impact |
|----------|---------|--------|--------|
| **P0 - Critical** | Single active session | Low | Blocks 90% of sharing |
| **P1 - High** | Device limit (2 max) | Medium | Blocks 95% of sharing |
| **P2 - Medium** | Session expiry (30 days) | Low | Blocks long-term abuse |
| **P3 - Low** | Soft caps on "unlimited" | Low | Prevents bot abuse |

---

## P0: Single Active Session (Pre-Launch Required)

### Concept

Only ONE session token is valid at any time. New login = all previous sessions invalidated.

### Database Schema

**Path**: `users/{userId}`

```javascript
{
  // ... existing fields ...

  auth: {
    // Single active session (only one valid at a time)
    active_session: {
      token: "sess_abc123xyz",           // Current valid session token
      device_id: "device_xyz789",        // Device identifier
      device_name: "iPhone 14 Pro",      // Human-readable name
      created_at: Timestamp,             // When session was created
      last_active_at: Timestamp,         // Last API call timestamp
      ip_address: "192.168.1.1"          // Optional: for anomaly detection
    }
  }
}
```

### Implementation

#### Session Token Format

Use cryptographically secure random tokens:

```javascript
// backend/src/services/authService.js
const crypto = require('crypto');

function generateSecureToken() {
  // 32 bytes = 64 hex characters, cryptographically secure
  return 'sess_' + crypto.randomBytes(32).toString('hex');
  // Example: sess_a1b2c3d4e5f6...
}
```

#### On Successful OTP Verification (Login/Signup)

```javascript
// backend/src/services/authService.js

async function createSession(userId, deviceInfo) {
  const sessionToken = generateSecureToken();

  const sessionData = {
    token: sessionToken,
    device_id: deviceInfo.deviceId,
    device_name: deviceInfo.deviceName || 'Unknown Device',
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    last_active_at: admin.firestore.FieldValue.serverTimestamp(),
    ip_address: deviceInfo.ipAddress || null
  };

  // This REPLACES any existing session (single session enforcement)
  await db.collection('users').doc(userId).update({
    'auth.active_session': sessionData
  });

  return sessionToken;
}
```

#### Session Validation Middleware

```javascript
// backend/src/middleware/sessionValidator.js

async function validateSession(req, res, next) {
  const userId = req.userId; // From Firebase Auth
  const requestToken = req.headers['x-session-token'];

  if (!requestToken) {
    return res.status(401).json({
      success: false,
      error: 'Session token required',
      code: 'SESSION_TOKEN_MISSING'
    });
  }

  const userDoc = await db.collection('users').doc(userId).get();
  const activeSession = userDoc.data()?.auth?.active_session;

  if (!activeSession || activeSession.token !== requestToken) {
    return res.status(401).json({
      success: false,
      error: 'Session expired. Please login again.',
      code: 'SESSION_EXPIRED',
      action: 'FORCE_LOGOUT'
    });
  }

  // Update last_active_at (debounce to avoid excessive writes)
  // Only update if last_active_at is > 5 minutes ago
  const lastActive = activeSession.last_active_at?.toDate();
  const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);

  if (!lastActive || lastActive < fiveMinutesAgo) {
    await db.collection('users').doc(userId).update({
      'auth.active_session.last_active_at': admin.firestore.FieldValue.serverTimestamp()
    });
  }

  next();
}

module.exports = { validateSession };
```

#### Mobile App: Handle Session Expiry

```dart
// mobile/lib/services/api_service.dart

Future<Response> makeAuthenticatedRequest(String endpoint, ...) async {
  final response = await http.post(
    endpoint,
    headers: {
      'Authorization': 'Bearer $firebaseToken',
      'x-session-token': await getStoredSessionToken(),
    },
    ...
  );

  if (response.statusCode == 401) {
    final body = jsonDecode(response.body);
    if (body['code'] == 'SESSION_EXPIRED') {
      // Clear local session
      await clearLocalSession();

      // Show user-friendly message
      showSessionExpiredDialog(
        message: 'You\'ve been logged in on another device. Please login again.',
        onConfirm: () => navigateToLogin(),
      );

      return;
    }
  }

  return response;
}
```

#### Logout Endpoint (Clear Session)

```javascript
// backend/src/routes/auth.js

router.post('/logout', authenticate, async (req, res) => {
  const userId = req.userId;

  try {
    await db.collection('users').doc(userId).update({
      'auth.active_session': admin.firestore.FieldValue.delete()
    });

    // Log for monitoring
    console.log(`Session cleared for user ${userId} (explicit logout)`);

    res.json({ success: true });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({ success: false, error: 'Failed to logout' });
  }
});
```

### User Experience

**When kicked out (another device logged in):**
```
┌─────────────────────────────────────┐
│                                     │
│     Session Expired                 │
│                                     │
│  You've been logged in on another   │
│  device. For security, only one     │
│  device can be active at a time.    │
│                                     │
│         [ Login Again ]             │
│                                     │
└─────────────────────────────────────┘
```

**Note**: "Login Again" requires OTP since the user needs to verify phone ownership on the new device. The local PIN is cleared when session expires.

---

## P1: Device Limit (Post-Launch OK)

### Concept

Device limits vary by tier. User must remove a device to add a new one.

| Tier | Max Devices | Rationale |
|------|-------------|-----------|
| FREE | 1 | Single device prevents casual sharing |
| PRO | 2 | Phone + tablet for paying users |
| ULTRA | 2 | Same as Pro |

### Database Schema

**Path**: `users/{userId}`

```javascript
{
  // ... existing fields ...

  auth: {
    active_session: { ... },  // From P0

    // Registered devices
    registered_devices: [
      {
        device_id: "device_abc123",
        device_name: "iPhone 14 Pro",
        registered_at: Timestamp,
        last_used_at: Timestamp
      },
      {
        device_id: "device_xyz789",
        device_name: "Samsung Galaxy S23",
        registered_at: Timestamp,
        last_used_at: Timestamp
      }
    ]
    // Note: max_devices is derived from tier, not stored here
  }
}
```

**Path**: `tier_config/active` (already exists)

```javascript
{
  tiers: {
    free: {
      limits: {
        max_devices: 1,
        // ... other limits
      }
    },
    pro: {
      limits: {
        max_devices: 2,
        // ... other limits
      }
    },
    ultra: {
      limits: {
        max_devices: 2,
        // ... other limits
      }
    }
  }
}
```

### Implementation

#### Get Device Limit from Tier

```javascript
// backend/src/services/authService.js

async function getMaxDevicesForUser(userId) {
  const tierInfo = await getEffectiveTier(userId);
  const tierConfig = await getTierConfig(tierInfo.tier);
  return tierConfig.limits.max_devices || 1; // Default to 1 if not set
}
```

#### On Login: Check Device Limit

```javascript
// backend/src/services/authService.js

async function registerDevice(userId, deviceInfo) {
  const userDoc = await db.collection('users').doc(userId).get();
  const authData = userDoc.data()?.auth || {};
  const registeredDevices = authData.registered_devices || [];

  // Get max devices from user's current tier
  const maxDevices = await getMaxDevicesForUser(userId);

  // Check if device already registered
  const existingDevice = registeredDevices.find(
    d => d.device_id === deviceInfo.deviceId
  );

  if (existingDevice) {
    // Update last_used_at and continue
    await updateDeviceLastUsed(userId, deviceInfo.deviceId);
    return { success: true };
  }

  // Check device limit
  if (registeredDevices.length >= maxDevices) {
    return {
      success: false,
      error: 'Device limit reached',
      code: 'DEVICE_LIMIT_REACHED',
      registered_devices: registeredDevices.map(d => ({
        device_id: d.device_id,
        device_name: d.device_name,
        registered_at: d.registered_at
      })),
      max_devices: maxDevices
    };
  }

  // Register new device
  const newDevice = {
    device_id: deviceInfo.deviceId,
    device_name: deviceInfo.deviceName || 'Unknown Device',
    registered_at: admin.firestore.FieldValue.serverTimestamp(),
    last_used_at: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('users').doc(userId).update({
    'auth.registered_devices': admin.firestore.FieldValue.arrayUnion(newDevice)
  });

  return { success: true };
}
```

#### Remove Device Endpoint

```javascript
// backend/src/routes/auth.js

router.post('/remove-device', authenticate, async (req, res) => {
  const { deviceId } = req.body;
  const userId = req.userId;

  const userDoc = await db.collection('users').doc(userId).get();
  const registeredDevices = userDoc.data()?.auth?.registered_devices || [];

  const updatedDevices = registeredDevices.filter(
    d => d.device_id !== deviceId
  );

  await db.collection('users').doc(userId).update({
    'auth.registered_devices': updatedDevices
  });

  // If removed device had active session, invalidate it
  const activeSession = userDoc.data()?.auth?.active_session;
  if (activeSession?.device_id === deviceId) {
    await db.collection('users').doc(userId).update({
      'auth.active_session': null
    });
  }

  res.json({ success: true, devices_remaining: updatedDevices.length });
});
```

### User Experience

**FREE tier (1 device) - Device limit reached:**
```
┌─────────────────────────────────────┐
│                                     │
│     Device Limit Reached            │
│                                     │
│  Free accounts can only use         │
│  JEEVibe on 1 device.               │
│                                     │
│  Your device:                       │
│  ┌─────────────────────────────┐    │
│  │ iPhone 14 Pro        [ X ]  │    │
│  │ Added Jan 15, 2026          │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 💎 Upgrade to Pro for 2     │    │
│  │    devices + more features  │    │
│  └─────────────────────────────┘    │
│                                     │
│    [ Remove Device ]  [ Upgrade ]   │
│                                     │
└─────────────────────────────────────┘
```

**PRO/ULTRA tier (2 devices) - Device limit reached:**
```
┌─────────────────────────────────────┐
│                                     │
│     Device Limit Reached            │
│                                     │
│  You can use JEEVibe on up to 2     │
│  devices. Remove a device to        │
│  continue on this one.              │
│                                     │
│  Your devices:                      │
│  ┌─────────────────────────────┐    │
│  │ iPhone 14 Pro        [ X ]  │    │
│  │ Added Jan 15, 2026          │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ Samsung Galaxy S23   [ X ]  │    │
│  │ Added Jan 10, 2026          │    │
│  └─────────────────────────────┘    │
│                                     │
│         [ Cancel ]                  │
│                                     │
└─────────────────────────────────────┘
```

### Tier Change Handling

#### Upgrade: FREE → PRO/ULTRA

When a free user upgrades:
- Device limit increases from 1 → 2
- User can now add a second device
- No action needed on existing device

#### Downgrade: PRO/ULTRA → FREE

When a paid user downgrades (subscription expires):
- Device limit decreases from 2 → 1
- **Do NOT auto-remove devices** - this feels punitive
- User keeps existing registered devices
- On next login attempt from 2nd device: show "Your plan allows 1 device. Upgrade to continue using this device."

```javascript
// On login from registered device that exceeds tier limit
if (registeredDevices.length > maxDevices) {
  const deviceIndex = registeredDevices.findIndex(
    d => d.device_id === deviceInfo.deviceId
  );

  // Allow if this is the first/primary device
  if (deviceIndex === 0) {
    return { success: true };
  }

  // Block secondary devices for downgraded users
  return {
    success: false,
    error: 'Your plan allows 1 device. Upgrade or use your primary device.',
    code: 'DEVICE_OVER_LIMIT',
    current_tier: 'free',
    max_devices: 1,
    upgrade_prompt: true
  };
}
```

**UX for downgraded user on 2nd device:**
```
┌─────────────────────────────────────┐
│                                     │
│     Subscription Expired            │
│                                     │
│  Your plan now allows 1 device.     │
│  You're logged in on:               │
│                                     │
│  📱 iPhone 14 Pro (primary)         │
│                                     │
│  To use this device, upgrade your   │
│  plan or login from your primary    │
│  device.                            │
│                                     │
│    [ Upgrade ]  [ Switch Device ]   │
│                                     │
└─────────────────────────────────────┘
```

---

## P2: Session Expiry (30 Days)

### Concept

Sessions expire after 30 days, requiring re-verification with OTP.

### Implementation

```javascript
// backend/src/middleware/sessionValidator.js

const SESSION_MAX_AGE_DAYS = 30;

async function validateSession(req, res, next) {
  // ... existing token validation ...

  // Check session age
  const sessionCreatedAt = activeSession.created_at?.toDate();
  const maxAge = SESSION_MAX_AGE_DAYS * 24 * 60 * 60 * 1000;

  if (sessionCreatedAt && Date.now() - sessionCreatedAt.getTime() > maxAge) {
    return res.status(401).json({
      success: false,
      error: 'Session expired. Please verify your phone number.',
      code: 'SESSION_EXPIRED_AGE',
      action: 'REQUIRE_OTP'
    });
  }

  next();
}
```

---

## P3: Soft Caps on "Unlimited"

### Concept

"Unlimited" features have high caps that no legitimate user would hit, but prevent bot abuse.

### Implementation

Update `tier_config/active` in Firestore:

```javascript
{
  tiers: {
    free: {
      limits: {
        snap_solve_daily: 5,
        daily_quiz_daily: 1,
        chapter_practice_daily: 1,  // 1 per week per subject
        mock_tests_monthly: 1,
        max_devices: 1
      }
    },
    pro: {
      limits: {
        snap_solve_daily: 15,
        daily_quiz_daily: 10,
        chapter_practice_daily: 5,
        mock_tests_monthly: 5,
        max_devices: 2
      }
    },
    ultra: {
      limits: {
        // Change from -1 (truly unlimited) to high caps
        snap_solve_daily: 50,         // Was -1
        daily_quiz_daily: 25,         // Was -1
        ai_tutor_messages_daily: 100, // Was -1
        chapter_practice_daily: 15,
        mock_tests_monthly: 15,
        solution_history_days: 365,   // Was -1 (1 year = effectively unlimited)
        max_devices: 2
      }
    }
  }
}
```

### Marketing

Continue to advertise as "Unlimited" - add fine print in Terms of Service:

> "Unlimited plans are subject to fair use. Daily limits apply to prevent automated abuse. See our Fair Use Policy for details."

---

## Tier Config Updates Required

Both `backend/src/services/tierConfigService.js` (defaults) and `tier_config/active` (Firestore) need these changes:

### Add `max_devices` to All Tiers

```javascript
// FREE tier
limits: {
  // ... existing ...
  max_devices: 1  // NEW
}

// PRO tier
limits: {
  // ... existing ...
  max_devices: 2  // NEW
}

// ULTRA tier
limits: {
  // ... existing ...
  max_devices: 2  // NEW
}
```

### Change Ultra from `-1` to High Caps

| Field | Current | New Value |
|-------|---------|-----------|
| `snap_solve_daily` | -1 | 50 |
| `daily_quiz_daily` | -1 | 25 |
| `ai_tutor_messages_daily` | -1 | 100 |
| `solution_history_days` | -1 | 365 |
| `mock_tests_monthly` | -1 | 15 |
| `chapter_practice_daily` | -1 | 15 |

---

## API Changes Summary

### New Headers Required

| Header | Description |
|--------|-------------|
| `x-session-token` | Session token from login response |
| `x-device-id` | Unique device identifier |

### New Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/auth/session` | POST | Create session (on OTP verification) |
| `/api/auth/session` | GET | Get current session info |
| `/api/auth/logout` | POST | Clear active session (explicit sign-out) |
| `/api/auth/devices` | GET | List registered devices (P1) |
| `/api/auth/devices/:deviceId` | DELETE | Remove a device (P1) |

### Modified Endpoints

All authenticated endpoints now require `x-session-token` header and will return:

```javascript
// 401 Response for invalid session
{
  success: false,
  error: 'Session expired. Please login again.',
  code: 'SESSION_EXPIRED',  // or 'SESSION_TOKEN_MISSING', 'DEVICE_LIMIT_REACHED'
  action: 'FORCE_LOGOUT'    // or 'REQUIRE_OTP', 'SHOW_DEVICE_MANAGER'
}
```

---

## Mobile Implementation Checklist

### Storage (P0 - ✅ Complete)

- [x] Store session token securely (Flutter Secure Storage)
- [x] Generate consistent device ID (persist across app reinstalls if possible)
- [x] Get device name (from device_info_plus package)

### API Layer (P0 - ✅ Complete)

- [x] Add `x-session-token` header to all authenticated requests in `api_service.dart`
- [x] Add `x-device-id` header to all requests
- [x] Handle 401 responses with SESSION_EXPIRED detection
- [x] Call `/api/auth/session` POST after successful OTP verification
- [x] Call `/api/auth/logout` on sign-out (in `auth_service.dart`)

### UI Screens (P0 - ✅ Complete)

- [x] Session expired dialog (force logout with "logged in on another device" message) - in `main.dart`

### UI Screens (P1 - 🔮 Future)

- [ ] Device limit reached screen (with device manager)
- [ ] Device manager in Settings (list and remove devices)

### Sign-Out Flow Update

Current sign-out in `profile_view_screen.dart` must be updated to:
```dart
Future<void> _signOut() async {
  // ... existing offline data clearing ...

  // NEW: Clear server-side session
  try {
    await apiService.post('/api/auth/logout');
  } catch (e) {
    // Continue with local sign-out even if backend call fails
    debugPrint('Error clearing server session: $e');
  }

  // NEW: Clear stored session token
  await clearStoredSessionToken();

  await authService.signOut();
  // ... rest of navigation ...
}
```

---

## Rollout Plan

> **Note**: Currently in alpha with 0 customers. All changes can be made without migration concerns.

### ✅ Phase 1: Backend P0 - COMPLETE (2026-01-24)

**Files created:**
- `backend/src/services/authService.js` - Session creation, token generation
- `backend/src/middleware/sessionValidator.js` - Session validation
- `backend/src/routes/auth.js` - Session and device endpoints

**Files modified:**
- `backend/src/index.js` - Registered auth routes
- `backend/src/services/tierConfigService.js` - Added `max_devices` to defaults

**Commit:** `9c6ce85`

### ✅ Phase 2: Mobile P0 - COMPLETE (2026-01-24)

**Files modified:**
- `mobile/lib/services/api_service.dart` - Added session token headers to all API methods
- `mobile/lib/services/firebase/auth_service.dart` - Session token storage, device ID generation
- `mobile/lib/screens/auth/otp_verification_screen.dart` - Create session after OTP
- `mobile/lib/main.dart` - Session expiry callback and force logout dialog

**What was implemented:**
1. ✅ Session token storage using Flutter Secure Storage
2. ✅ `x-session-token` and `x-device-id` headers on all authenticated requests
3. ✅ Call `/api/auth/session` POST after OTP verification
4. ✅ Handle `SESSION_EXPIRED` 401 responses with force logout dialog
5. ✅ Sign-out calls `/api/auth/logout` to clear server session

### 🔮 Phase 3: Device Limits P1 (Post-Launch - Future)

1. Implement device registration in `authService.js`
2. Add device limit checking to session creation
3. Create device management endpoints
4. Build device manager UI in mobile app
5. Test tier downgrade scenarios

### Phase 4: Soft Caps P3 (Post-Launch)

1. Verify tier config has correct ultra caps (50/25/100)
2. Monitor for legitimate users hitting caps
3. Adjust caps based on usage data

---

## Testing Plan

### Backend Unit Tests

Create `backend/src/tests/authService.test.js`:

```javascript
describe('authService', () => {
  describe('generateSecureToken', () => {
    it('should generate token with sess_ prefix', () => {
      const token = generateSecureToken();
      expect(token.startsWith('sess_')).toBe(true);
    });

    it('should generate 64 hex characters after prefix', () => {
      const token = generateSecureToken();
      expect(token.length).toBe(5 + 64); // 'sess_' + 64 hex chars
    });

    it('should generate unique tokens', () => {
      const tokens = new Set();
      for (let i = 0; i < 100; i++) {
        tokens.add(generateSecureToken());
      }
      expect(tokens.size).toBe(100);
    });
  });

  describe('createSession', () => {
    it('should store session in user document', async () => {
      const token = await createSession('user123', { deviceId: 'dev1', deviceName: 'iPhone' });
      const user = await db.collection('users').doc('user123').get();
      expect(user.data().auth.active_session.token).toBe(token);
    });

    it('should replace existing session (single session enforcement)', async () => {
      await createSession('user123', { deviceId: 'dev1' });
      const newToken = await createSession('user123', { deviceId: 'dev2' });
      const user = await db.collection('users').doc('user123').get();
      expect(user.data().auth.active_session.device_id).toBe('dev2');
    });
  });

  describe('clearSession', () => {
    it('should remove active_session from user document', async () => {
      await createSession('user123', { deviceId: 'dev1' });
      await clearSession('user123');
      const user = await db.collection('users').doc('user123').get();
      expect(user.data().auth?.active_session).toBeUndefined();
    });
  });
});
```

### Backend Integration Tests

Create `backend/src/tests/authRoutes.test.js`:

```javascript
describe('Auth Routes', () => {
  describe('POST /api/auth/session', () => {
    it('should create session and return token', async () => {
      const res = await request(app)
        .post('/api/auth/session')
        .set('Authorization', `Bearer ${validFirebaseToken}`)
        .send({ deviceId: 'dev1', deviceName: 'Test Device' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.sessionToken).toMatch(/^sess_/);
    });

    it('should require Firebase auth', async () => {
      const res = await request(app)
        .post('/api/auth/session')
        .send({ deviceId: 'dev1' });

      expect(res.status).toBe(401);
    });
  });

  describe('POST /api/auth/logout', () => {
    it('should clear session', async () => {
      // Create session first
      await request(app)
        .post('/api/auth/session')
        .set('Authorization', `Bearer ${validFirebaseToken}`)
        .send({ deviceId: 'dev1' });

      // Logout
      const res = await request(app)
        .post('/api/auth/logout')
        .set('Authorization', `Bearer ${validFirebaseToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('Session Validation Middleware', () => {
    it('should reject requests without session token', async () => {
      const res = await request(app)
        .get('/api/daily-quiz/questions')
        .set('Authorization', `Bearer ${validFirebaseToken}`);

      expect(res.status).toBe(401);
      expect(res.body.code).toBe('SESSION_TOKEN_MISSING');
    });

    it('should reject requests with invalid session token', async () => {
      const res = await request(app)
        .get('/api/daily-quiz/questions')
        .set('Authorization', `Bearer ${validFirebaseToken}`)
        .set('x-session-token', 'sess_invalid');

      expect(res.status).toBe(401);
      expect(res.body.code).toBe('SESSION_EXPIRED');
    });

    it('should accept requests with valid session token', async () => {
      // Create session
      const sessionRes = await request(app)
        .post('/api/auth/session')
        .set('Authorization', `Bearer ${validFirebaseToken}`)
        .send({ deviceId: 'dev1' });

      const sessionToken = sessionRes.body.data.sessionToken;

      // Make authenticated request
      const res = await request(app)
        .get('/api/daily-quiz/questions')
        .set('Authorization', `Bearer ${validFirebaseToken}`)
        .set('x-session-token', sessionToken);

      expect(res.status).toBe(200);
    });
  });
});
```

### Manual Test Scenarios

#### P0: Single Active Session

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| 1 | Fresh signup | Sign up with new phone → Complete OTP | Session token stored, API calls work |
| 2 | Return to app | Close app → Reopen → Enter PIN | API calls work with stored session |
| 3 | Login on new device | Use same phone # on Device B → Complete OTP | Device B gets new session, Device A's next API call returns SESSION_EXPIRED |
| 4 | Session expired handling | Device A makes API call after Device B logged in | Shows "logged in on another device" dialog, clears local data, navigates to welcome |
| 5 | Explicit logout | Tap Sign Out in profile | Backend session cleared, local data cleared, welcome screen shown |
| 6 | Logout then login | Sign out → Sign up again with same phone | New session works, no issues |

#### P1: Device Limits (Future)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| 7 | FREE user - 1 device | Try to login on 2nd device | DEVICE_LIMIT_REACHED error, shows upgrade prompt |
| 8 | PRO user - 2 devices | Login on 3rd device | DEVICE_LIMIT_REACHED error, shows device manager |
| 9 | Remove device | In device manager, remove a device | Device removed, can now add new device |
| 10 | Downgrade with 2 devices | PRO expires with 2 registered devices | Primary device works, secondary shows upgrade prompt |

#### Edge Cases

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| 11 | Network error on logout | Sign out while offline | Local cleanup proceeds, backend call fails silently |
| 12 | Rapid session switches | Login A → Login B → Login A quickly | Each login invalidates previous, last one wins |
| 13 | Concurrent API calls during invalidation | Device A making requests while B logs in | Some requests may fail with SESSION_EXPIRED, app handles gracefully |
| 14 | Missing session token header | Old app version makes request | Returns SESSION_TOKEN_MISSING (401) |
| 15 | Corrupted session token in storage | Token stored but invalid/tampered | Returns SESSION_EXPIRED, force re-login |

### Test Environment Setup

```bash
# Run backend tests
cd backend
npm test -- --grep "authService|Auth Routes"

# Run with coverage
npm test -- --coverage --grep "auth"
```

### Acceptance Criteria

P0 Implementation Complete:

- [x] Session token generation and storage implemented
- [x] Session validation middleware created and registered
- [x] All API methods include session headers
- [x] Session expired dialog implemented in main.dart
- [x] Sign-out clears both local and server session
- [x] Code compiles without errors (`flutter analyze` passes)
- [ ] Manual scenarios 1-6 verified on physical device (testing pending)
- [ ] Unit tests for authService (testing pending)
- [ ] Integration tests for auth routes (testing pending)

---

## Monitoring & Alerts

### Metrics to Track

| Metric | Alert Threshold | Indicates |
|--------|-----------------|-----------|
| Session invalidations/day | >1000 | Possible sharing crackdown working |
| Device limit hits/day | >100 | Users attempting to share |
| Same account from 5+ IPs/day | Any | Definite account sharing |
| 401 errors spike | >50% increase | Possible implementation issue |

### Anomaly Detection (Future)

Flag accounts with suspicious patterns:
- Active from multiple cities in same day
- 50+ API calls in 1 minute (bot behavior)
- Login from known VPN/proxy IPs

---

## Success Criteria

| Metric | Before | Target After |
|--------|--------|--------------|
| Avg devices per Ultra account | Unknown (no limit) | <1.5 |
| Concurrent sessions per account | Multiple | 1 |
| Account sharing reports | N/A | <5% of Ultra users |
| Pro:Ultra conversion ratio | TBD | Healthy (not all going Ultra) |

---

## Related Documents

- [TIER-SYSTEM-ARCHITECTURE.md](./TIER-SYSTEM-ARCHITECTURE.md) - Tier definitions and limits
- [BUSINESS-MODEL-REVIEW.md](../09-business/BUSINESS-MODEL-REVIEW.md) - Business context for anti-abuse
- [PAYWALL-SYSTEM-DESIGN.md](./PAYWALL-SYSTEM-DESIGN.md) - Payment and subscription flow
