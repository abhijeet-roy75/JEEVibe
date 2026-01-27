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

### Backend (8 files)

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

### Mobile (8 files)

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

- Backend: 1.5 weeks
- Mobile: 1.5 weeks
- Testing & QA: 1 week (overlapping)

**Lines of Code:** ~2,500 total
- Backend: ~1,200 LOC
- Mobile: ~1,000 LOC
- Tests: ~300 LOC

---

## Notes

- **Good News:** `getEffectiveTier()` already checks for trials (lines 210-226)! Only needs minor import update.
- **Firebase Cloud Messaging (FCM):** Completely FREE with unlimited push notifications. No cost for sending trial notifications.
- **cron-job.org:** Using external cron service saves ₹580/month vs Render.com paid cron, plus provides better monitoring.
- **Critical:** Always invalidate tier cache after trial state changes
- **Security:** Protect admin endpoints with proper authentication
- **Compliance:** Trial terms must be clear in signup flow (legal requirement)
- **Monitoring:** Set up alerts for trial expiry errors and low conversion rates
- **Cost Estimate:** Monthly notification costs ~₹300-400 (email only), push notifications are FREE via FCM

This plan provides a complete, production-ready implementation that integrates seamlessly with JEEVibe's existing architecture.
