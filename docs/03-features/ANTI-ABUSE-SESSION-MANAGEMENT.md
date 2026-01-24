# Anti-Abuse & Session Management

> **Status**: Pending Implementation
>
> **Priority**: Critical (Pre-Launch)
>
> **Created**: 2026-01-23
>
> **Related**: [TIER-SYSTEM-ARCHITECTURE.md](./TIER-SYSTEM-ARCHITECTURE.md), [BUSINESS-MODEL-REVIEW.md](../09-business/BUSINESS-MODEL-REVIEW.md)

## Problem Statement

The Ultra tier offers "unlimited" access to premium features (Snap & Solve, AI Tutor, Daily Quiz). Without session controls, account sharing undermines the business model:

```
1 Ultra Annual = ₹3,588
Shared among 10 friends = ₹359/person/year = ₹30/month

vs Pro tier = ₹299/month
```

**Risk**: Account sharing kills Pro tier conversions and reduces Ultra revenue by 90%.

---

## Current Authentication Flow

```
SIGNUP (first time):
├── User enters phone number
├── OTP sent via SMS
├── User verifies OTP
├── Account created in Firebase Auth
└── Session token stored on device

LOGIN (new device):
├── User enters phone number
├── OTP sent via SMS
├── User verifies OTP
└── Session token stored on device

EXISTING DEVICE:
└── Token persists → No OTP required
```

### Current Protections

| Measure | Status |
|---------|--------|
| Phone # validation via SMS | Done |
| Screenshot blocking | Done |
| API authentication | Done |
| Device limits | Not implemented |
| Session limits | Not implemented |
| Concurrent session control | Not implemented |

### Current Vulnerability

```
Day 1: Student A signs up on Phone 1
Day 2: A logs into Phone 2 with OTP (gives Phone 1 to friend B)
Day 3: A logs into Tablet with OTP (gives Phone 2 to friend C)
...
Result: Multiple devices with valid sessions, shared among friends
```

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

#### On Successful OTP Verification (Login/Signup)

```javascript
// backend/src/services/authService.js

async function createSession(userId, deviceInfo) {
  const sessionToken = generateSecureToken(); // UUID v4 or similar

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

### User Experience

**When kicked out:**
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

## API Changes Summary

### New Headers Required

| Header | Description |
|--------|-------------|
| `x-session-token` | Session token from login response |
| `x-device-id` | Unique device identifier |

### New Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/auth/devices` | GET | List registered devices |
| `/api/auth/devices/:deviceId` | DELETE | Remove a device |
| `/api/auth/session` | GET | Get current session info |

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

### Storage

- [ ] Store session token securely (Flutter Secure Storage)
- [ ] Generate consistent device ID (persist across app reinstalls if possible)
- [ ] Store device name (from device_info_plus package)

### API Layer

- [ ] Add `x-session-token` header to all authenticated requests
- [ ] Add `x-device-id` header to all requests
- [ ] Handle 401 responses with appropriate UI flows

### UI Screens

- [ ] Session expired dialog (force logout)
- [ ] Device limit reached screen (with device manager)
- [ ] Device manager in Settings (list and remove devices)

---

## Rollout Plan

### Phase 1: Backend (Pre-Launch)

1. Add `auth.active_session` field to user schema
2. Implement session creation on login
3. Implement session validation middleware
4. Deploy to staging, test thoroughly

### Phase 2: Mobile (Pre-Launch)

1. Store and send session token
2. Handle session expired responses
3. Test forced logout flow

### Phase 3: Device Limits (Post-Launch Week 2)

1. Add device registration logic
2. Build device manager UI
3. Gradual rollout with monitoring

### Phase 4: Soft Caps (Post-Launch Week 4)

1. Update tier config in Firestore
2. Monitor for legitimate users hitting caps
3. Adjust caps based on data

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
