# Trial-First Implementation Guide

> **Status**: Pending Implementation
>
> **Priority**: CRITICAL (Pre-Launch)
>
> **Created**: 2026-01-23
>
> **Related**: [BUSINESS-MODEL-REVIEW.md](../09-business/BUSINESS-MODEL-REVIEW.md), [TIER-SYSTEM-ARCHITECTURE.md](./TIER-SYSTEM-ARCHITECTURE.md)

## Overview

All new users automatically receive a **30-day Pro trial** upon signup. No credit card required. After 30 days, users either convert to paid or downgrade to Free tier.

```
SIGNUP → PRO TRIAL (30 days) → Day 30 → PAID or FREE
```

### Why Trial-First

| Benefit | Explanation |
|---------|-------------|
| **Loss aversion** | Users feel the pain of losing 15 → 5 snaps |
| **Full value demo** | Users experience everything before deciding |
| **Built-in urgency** | Trial countdown creates natural conversion pressure |
| **Higher engagement** | Pro features = more usage = more habit formation |

### Expected Metrics

| Metric | Target |
|--------|--------|
| Trial-to-Paid Conversion | 5-10% |
| Day 30 Upgrade Rate | Higher than cold paywall |

---

## Database Schema

### User Document Changes

**Path**: `users/{userId}`

```javascript
{
  // ... existing fields (phone, firstName, lastName, etc.) ...

  // NEW: Trial tracking
  trial: {
    is_active: true,                    // Currently in trial?
    tier_id: "pro",                     // What tier they're trialing
    started_at: Timestamp,              // When trial began
    ends_at: Timestamp,                 // When trial expires (started_at + 30 days)
    converted: false,                   // Did they pay before trial ended?
    notifications_sent: {
      day_7: false,
      day_25: false,
      day_28: false,
      day_30: false
    }
  },

  // EXISTING: subscription field (add 'source' field)
  subscription: {
    tier: "pro",                        // Effective tier (from trial OR paid)
    source: "trial",                    // NEW: "trial" | "subscription" | "override" | "default"
    active_subscription_id: null,
    effective_limits: { ... },
    last_synced: Timestamp
  }
}
```

### Trial Source Priority

When determining effective tier, check in this order:

```
1. Override (beta tester, promotional) - Highest
2. Active paid subscription
3. Active trial                        - NEW
4. Default to FREE                     - Lowest
```

---

## Backend Implementation

### 1. Create New User with Trial

**File**: `backend/src/services/authService.js`

```javascript
const TRIAL_DURATION_DAYS = 30;

async function createNewUser(userId, phoneNumber, deviceInfo) {
  const now = new Date();
  const trialEndDate = new Date(now.getTime() + TRIAL_DURATION_DAYS * 24 * 60 * 60 * 1000);

  const proLimits = await getTierLimits("pro");

  const userData = {
    phone: phoneNumber,
    created_at: admin.firestore.FieldValue.serverTimestamp(),

    // Trial setup
    trial: {
      is_active: true,
      tier_id: "pro",
      started_at: admin.firestore.Timestamp.fromDate(now),
      ends_at: admin.firestore.Timestamp.fromDate(trialEndDate),
      converted: false,
      notifications_sent: {
        day_7: false,
        day_25: false,
        day_28: false,
        day_30: false
      }
    },

    // Set effective tier to Pro (from trial)
    subscription: {
      tier: "pro",
      source: "trial",
      active_subscription_id: null,
      effective_limits: proLimits,
      last_synced: admin.firestore.FieldValue.serverTimestamp()
    },

    // Initialize usage counters
    daily_usage: {
      snap_solve_count: 0,
      daily_quiz_count: 0,
      ai_tutor_message_count: 0,
      last_reset: admin.firestore.FieldValue.serverTimestamp()
    }
  };

  await db.collection('users').doc(userId).set(userData, { merge: true });

  // Log analytics event
  await logEvent(userId, 'trial_started', {
    tier_id: 'pro',
    duration_days: TRIAL_DURATION_DAYS
  });

  return userData;
}
```

### 2. Update getEffectiveTier()

**File**: `backend/src/services/subscriptionService.js`

```javascript
async function getEffectiveTier(userId) {
  const userDoc = await db.collection('users').doc(userId).get();

  if (!userDoc.exists) {
    return { tier: 'free', source: 'default', expires_at: null };
  }

  const userData = userDoc.data();
  const now = new Date();

  // 1. Check override (beta testers) - highest priority
  if (userData.subscription?.override) {
    const override = userData.subscription.override;
    if (override.expires_at && override.expires_at.toDate() > now) {
      return {
        tier: override.tier_id || 'ultra',
        source: 'override',
        expires_at: override.expires_at,
        override_type: override.type
      };
    }
  }

  // 2. Check active paid subscription
  if (userData.subscription?.active_subscription_id) {
    const subDoc = await db.collection('users').doc(userId)
      .collection('subscriptions')
      .doc(userData.subscription.active_subscription_id)
      .get();

    if (subDoc.exists) {
      const sub = subDoc.data();
      if (sub.status === 'active' && sub.end_date.toDate() > now) {
        return {
          tier: sub.tier_id,
          source: 'subscription',
          expires_at: sub.end_date,
          subscription_id: sub.subscription_id
        };
      }
    }
  }

  // 3. Check active trial (NEW)
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

  // 4. Default to free
  return {
    tier: 'free',
    source: 'default',
    expires_at: null
  };
}

// Non-blocking trial expiry
function expireTrialAsync(userId) {
  setImmediate(async () => {
    try {
      await expireTrial(userId);
    } catch (error) {
      console.error(`Failed to expire trial for ${userId}:`, error);
    }
  });
}
```

### 3. Trial Service

**File**: `backend/src/services/trialService.js` (NEW)

```javascript
const admin = require('firebase-admin');
const db = admin.firestore();
const { getTierLimits } = require('./tierConfigService');
const { logEvent } = require('./analyticsService');

/**
 * Expire a user's trial and downgrade to free
 */
async function expireTrial(userId) {
  const freeLimits = await getTierLimits('free');

  await db.collection('users').doc(userId).update({
    'trial.is_active': false,
    'subscription.tier': 'free',
    'subscription.source': 'default',
    'subscription.effective_limits': freeLimits,
    'subscription.last_synced': admin.firestore.FieldValue.serverTimestamp()
  });

  await logEvent(userId, 'trial_expired', {
    converted: false
  });

  console.log(`Trial expired for user ${userId}, downgraded to free`);
}

/**
 * Convert trial to paid subscription
 * Called when user pays during or after trial
 */
async function convertTrial(userId, subscriptionId, tierId) {
  const tierLimits = await getTierLimits(tierId);

  await db.collection('users').doc(userId).update({
    'trial.is_active': false,
    'trial.converted': true,
    'subscription.tier': tierId,
    'subscription.source': 'subscription',
    'subscription.active_subscription_id': subscriptionId,
    'subscription.effective_limits': tierLimits,
    'subscription.last_synced': admin.firestore.FieldValue.serverTimestamp()
  });

  await logEvent(userId, 'trial_converted', {
    subscription_id: subscriptionId,
    tier_id: tierId
  });

  console.log(`Trial converted for user ${userId} to ${tierId}`);
}

/**
 * Check if user is eligible for trial
 * (prevents abuse - one trial per phone number)
 */
async function isEligibleForTrial(userId) {
  const userDoc = await db.collection('users').doc(userId).get();

  if (!userDoc.exists) {
    return true; // New user
  }

  const userData = userDoc.data();

  // Already had a trial
  if (userData.trial?.started_at) {
    return false;
  }

  // Already has/had a paid subscription
  if (userData.subscription?.active_subscription_id) {
    return false;
  }

  return true;
}

/**
 * Get trial status for a user
 */
async function getTrialStatus(userId) {
  const userDoc = await db.collection('users').doc(userId).get();

  if (!userDoc.exists) {
    return { has_trial: false };
  }

  const userData = userDoc.data();
  const trial = userData.trial;

  if (!trial) {
    return { has_trial: false };
  }

  const now = new Date();
  const endsAt = trial.ends_at?.toDate();
  const isActive = trial.is_active && endsAt && endsAt > now;

  return {
    has_trial: true,
    is_active: isActive,
    tier_id: trial.tier_id,
    started_at: trial.started_at,
    ends_at: trial.ends_at,
    days_remaining: isActive ? Math.ceil((endsAt - now) / (1000 * 60 * 60 * 24)) : 0,
    converted: trial.converted || false
  };
}

module.exports = {
  expireTrial,
  convertTrial,
  isEligibleForTrial,
  getTrialStatus
};
```

### 4. Subscription Status API

**File**: `backend/src/routes/subscriptions.js`

Add trial info to the status endpoint:

```javascript
const { getTrialStatus } = require('../services/trialService');

// GET /api/subscriptions/status
router.get('/status', authenticate, async (req, res) => {
  try {
    const userId = req.userId;
    const tierInfo = await getEffectiveTier(userId);
    const trialStatus = await getTrialStatus(userId);

    const response = {
      success: true,
      data: {
        tier: tierInfo.tier,
        source: tierInfo.source,
        expires_at: tierInfo.expires_at || null,

        // Trial-specific info
        trial: trialStatus.is_active ? {
          is_active: true,
          tier_id: trialStatus.tier_id,
          days_remaining: trialStatus.days_remaining,
          ends_at: trialStatus.ends_at,
          started_at: trialStatus.started_at
        } : null,

        // Limits for current tier
        limits: await getTierLimits(tierInfo.tier)
      }
    };

    res.json(response);
  } catch (error) {
    console.error('Error getting subscription status:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});
```

---

## Scheduled Jobs

### Trial Notifications & Expiry

**File**: `functions/src/scheduledJobs/trialProcessor.js`

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();
const { sendPushNotification } = require('../services/notificationService');
const { expireTrial } = require('../services/trialService');

// Run daily at 9 AM IST (3:30 UTC)
exports.processTrials = functions.pubsub
  .schedule('30 3 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    console.log('Starting daily trial processing...');

    const now = new Date();
    let processed = 0;
    let expired = 0;
    let notified = 0;

    // Query users with active trials
    const trialsSnapshot = await db.collection('users')
      .where('trial.is_active', '==', true)
      .get();

    console.log(`Found ${trialsSnapshot.size} active trials`);

    for (const doc of trialsSnapshot.docs) {
      const user = doc.data();
      const userId = doc.id;
      const trialEndsAt = user.trial.ends_at?.toDate();

      if (!trialEndsAt) continue;

      const daysRemaining = Math.ceil((trialEndsAt - now) / (1000 * 60 * 60 * 24));
      processed++;

      // Trial expired
      if (daysRemaining <= 0) {
        await expireTrial(userId);
        await sendTrialExpiredNotification(userId);
        expired++;
        continue;
      }

      // Send milestone notifications
      const sent = await processTrialNotifications(userId, user, daysRemaining);
      if (sent) notified++;
    }

    console.log(`Trial processing complete: ${processed} processed, ${expired} expired, ${notified} notified`);
    return null;
  });

async function processTrialNotifications(userId, user, daysRemaining) {
  const notifications = user.trial.notifications_sent || {};

  // Day 7 (23 days remaining)
  if (daysRemaining === 23 && !notifications.day_7) {
    await sendTrialNotification(userId, 'day_7', daysRemaining, user);
    return true;
  }

  // Day 25 (5 days remaining)
  if (daysRemaining === 5 && !notifications.day_25) {
    await sendTrialNotification(userId, 'day_25', daysRemaining, user);
    return true;
  }

  // Day 28 (2 days remaining)
  if (daysRemaining === 2 && !notifications.day_28) {
    await sendTrialNotification(userId, 'day_28', daysRemaining, user);
    return true;
  }

  return false;
}

async function sendTrialNotification(userId, milestone, daysRemaining, user) {
  const messages = {
    day_7: {
      title: "You're crushing it! 🎯",
      body: `You've been learning with Pro features for a week! ${daysRemaining} days left in your trial.`
    },
    day_25: {
      title: "5 days left in your trial ⏰",
      body: "Don't lose your Pro features! Upgrade for just ₹199/month."
    },
    day_28: {
      title: "2 days left! Your trial ends soon",
      body: "Keep your 15 daily snaps and offline access. Upgrade now!"
    }
  };

  const message = messages[milestone];
  if (!message) return;

  await sendPushNotification(userId, {
    title: message.title,
    body: message.body,
    data: {
      action: 'SHOW_PAYWALL',
      source: 'trial_notification',
      milestone: milestone
    }
  });

  // Mark notification as sent
  await db.collection('users').doc(userId).update({
    [`trial.notifications_sent.${milestone}`]: true
  });

  console.log(`Sent ${milestone} notification to ${userId}`);
}

async function sendTrialExpiredNotification(userId) {
  await sendPushNotification(userId, {
    title: "Your Pro trial has ended",
    body: "You're now on the Free plan. Upgrade to get your Pro features back!",
    data: {
      action: 'SHOW_PAYWALL',
      source: 'trial_expired'
    }
  });

  await db.collection('users').doc(userId).update({
    'trial.notifications_sent.day_30': true
  });
}
```

---

## Mobile Implementation

### 1. Trial Status Model

**File**: `mobile/lib/models/trial_status.dart`

```dart
class TrialStatus {
  final bool isActive;
  final String? tierId;
  final int daysRemaining;
  final DateTime? endsAt;
  final DateTime? startedAt;

  TrialStatus({
    required this.isActive,
    this.tierId,
    this.daysRemaining = 0,
    this.endsAt,
    this.startedAt,
  });

  factory TrialStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return TrialStatus(isActive: false);
    }
    return TrialStatus(
      isActive: json['is_active'] ?? false,
      tierId: json['tier_id'],
      daysRemaining: json['days_remaining'] ?? 0,
      endsAt: json['ends_at'] != null
        ? DateTime.parse(json['ends_at'])
        : null,
      startedAt: json['started_at'] != null
        ? DateTime.parse(json['started_at'])
        : null,
    );
  }

  bool get isExpiringSoon => isActive && daysRemaining <= 5;
  bool get isLastDay => isActive && daysRemaining <= 1;
}
```

### 2. Trial Banner Widget

**File**: `mobile/lib/widgets/trial_banner.dart`

```dart
import 'package:flutter/material.dart';
import '../models/trial_status.dart';

class TrialBanner extends StatelessWidget {
  final TrialStatus trialStatus;
  final VoidCallback onUpgrade;

  const TrialBanner({
    Key? key,
    required this.trialStatus,
    required this.onUpgrade,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!trialStatus.isActive) return SizedBox.shrink();

    final isUrgent = trialStatus.daysRemaining <= 5;
    final backgroundColor = isUrgent
      ? Colors.orange.shade600
      : Colors.purple.shade600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isUrgent ? Icons.timer : Icons.star,
            color: Colors.white,
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _getBannerText(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: onUpgrade,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Upgrade',
              style: TextStyle(
                color: backgroundColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getBannerText() {
    final days = trialStatus.daysRemaining;
    if (days <= 1) {
      return 'Last day of your Pro trial!';
    } else if (days <= 5) {
      return '$days days left in your Pro trial';
    } else {
      return 'Pro Trial • $days days remaining';
    }
  }
}
```

### 3. Trial Expired Dialog

**File**: `mobile/lib/widgets/trial_expired_dialog.dart`

```dart
import 'package:flutter/material.dart';

class TrialExpiredDialog extends StatelessWidget {
  final VoidCallback onUpgrade;
  final VoidCallback onContinueFree;

  const TrialExpiredDialog({
    Key? key,
    required this.onUpgrade,
    required this.onContinueFree,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_off,
              size: 48,
              color: Colors.orange,
            ),
            SizedBox(height: 16),
            Text(
              'Your Pro Trial Has Ended',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              "You're now on the Free plan:",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            _buildLimitRow('Snap & Solve', '15/day', '5/day'),
            _buildLimitRow('Daily Quiz', '10/day', '1/day'),
            _buildLimitRow('Offline Mode', 'Yes', 'No'),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Upgrade to Pro - ₹199/month',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            TextButton(
              onPressed: onContinueFree,
              child: Text(
                'Continue with Free',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitRow(String feature, String proLimit, String freeLimit) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(feature, style: TextStyle(fontSize: 13))),
          Text(
            proLimit,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
          SizedBox(width: 8),
          Text(
            freeLimit,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
```

### 4. Handle Trial Expiry in App

**File**: `mobile/lib/services/subscription_service.dart`

```dart
class SubscriptionService {
  // Check subscription status on app resume
  Future<void> checkSubscriptionStatus() async {
    final status = await api.getSubscriptionStatus();

    // If source changed from 'trial' to 'default', trial just expired
    final previousSource = _cachedStatus?.source;
    final currentSource = status.source;

    if (previousSource == 'trial' && currentSource == 'default') {
      // Show trial expired dialog
      _showTrialExpiredDialog();
    }

    _cachedStatus = status;
  }

  void _showTrialExpiredDialog() {
    // Navigate to show dialog
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => TrialExpiredScreen(),
        fullscreenDialog: true,
      ),
    );
  }
}
```

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| **User pays during trial** | Call `convertTrial()`, switch source to `subscription` |
| **User pays after trial expired** | Create subscription normally, trial stays `is_active: false` |
| **Beta tester signs up** | Override takes priority over trial in `getEffectiveTier()` |
| **Trial expires while app is open** | Check tier on app resume, show graceful dialog |
| **User reinstalls app** | Phone # tied to account - trial state persists in DB |
| **User tries to create new account** | Same phone # = same account, no new trial |

---

## Analytics Events

| Event | When | Properties |
|-------|------|------------|
| `trial_started` | User signs up | `tier_id`, `duration_days` |
| `trial_notification_sent` | Scheduled job sends notification | `milestone`, `days_remaining` |
| `trial_expired` | Trial ends without conversion | `converted: false` |
| `trial_converted` | User pays during/after trial | `subscription_id`, `tier_id` |
| `trial_paywall_shown` | User sees paywall from trial prompt | `source`, `days_remaining` |

---

## Implementation Checklist

### Phase 1: Backend (P0)

- [ ] Add `trial` field to user schema
- [ ] Update signup flow to create trial
- [ ] Update `getEffectiveTier()` to check trial
- [ ] Create `trialService.js` with expiry logic
- [ ] Update `/api/subscriptions/status` endpoint

### Phase 2: Scheduled Jobs (P1)

- [ ] Create Cloud Function for daily trial processing
- [ ] Implement notification sending at milestones
- [ ] Test notification delivery

### Phase 3: Mobile (P1)

- [ ] Add `TrialStatus` model
- [ ] Create `TrialBanner` widget
- [ ] Create `TrialExpiredDialog`
- [ ] Handle trial expiry on app resume
- [ ] Show trial countdown in settings

### Phase 4: Analytics (P2)

- [ ] Add trial analytics events
- [ ] Create dashboard for trial metrics
- [ ] Set up conversion funnel tracking

---

## Testing Checklist

### Unit Tests

- [ ] `getEffectiveTier()` returns correct tier for trial users
- [ ] `expireTrial()` downgrades to free correctly
- [ ] `convertTrial()` updates all fields correctly
- [ ] Trial notifications sent at correct milestones

### Integration Tests

- [ ] New signup gets Pro trial
- [ ] Trial expires after 30 days
- [ ] Notifications sent on schedule
- [ ] Payment during trial converts correctly

### Manual Testing

- [ ] Trial banner shows correct days remaining
- [ ] Trial expired dialog appears on app resume
- [ ] Upgrade from trial works end-to-end
- [ ] Free tier limits apply after trial expires

---

## Monitoring

### Metrics to Track

| Metric | Alert Threshold |
|--------|-----------------|
| Trial creation rate | <90% of signups |
| Trial-to-paid conversion | <3% (below target) |
| Notification delivery rate | <95% |
| Trial expiry errors | >1% failure rate |

### Logs to Monitor

```
[TRIAL] Created trial for user {userId}, expires {date}
[TRIAL] Sent {milestone} notification to {userId}
[TRIAL] Expired trial for user {userId}
[TRIAL] Converted trial for user {userId} to {tier}
```
