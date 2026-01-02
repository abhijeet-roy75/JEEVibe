# Paywall System - Complete Design

## Overview

Implementing a subscription paywall with:
- **Free Trial**: 7 days unlimited access (all features)
- **Free Tier**: 5 snaps/day, 10 questions/day (after trial or immediate downgrade)
- **Pro Tier**: Unlimited snaps, unlimited quizzes, analytics, study recommendations
- **Payment**: Web-based (Razorpay) to avoid app store fees
- **Platforms**: Android + iOS (via WebView)

**Status**: 🎯 **DESIGN PHASE** - Ready for Implementation

---

## Business Model

### Tier Structure

| Feature | Free Tier | Pro Tier |
|---------|-----------|----------|
| **Trial Duration** | 7 days unlimited | - |
| **Daily Snaps** | 5/day | Unlimited ♾️ |
| **Daily Quizzes** | 1 quiz/day (10 questions) | Unlimited ♾️ |
| **Solutions** | Basic explanations | Detailed step-by-step |
| **Doubt Library** | ❌ | ✅ Personal library |
| **Analytics** | ❌ | ✅ Performance tracking |
| **Study Recommendations** | ❌ | ✅ AI-powered suggestions |

### Pricing (INR)

| Plan | Price | Savings | Badge |
|------|-------|---------|-------|
| **Monthly** | ₹299/month | - | - |
| **Quarterly** | ₹249/month (₹747 total) | 17% off (₹150) | MOST POPULAR |
| **Annual** | ₹199/month (₹2,388 total) | 33% off (₹1,200) | SAVE 33% |

### Free Trial Logic

**New User Journey**:
```
Day 0: Sign up → Start 7-day trial (unlimited everything)
Day 5: In-app reminder: "2 days left of unlimited access!"
Day 7: Trial expires → Revert to Free tier
Day 7+: Hit limit → Show paywall
```

**Hybrid Benefits**:
- Users experience full product (builds habit)
- Soft landing on free tier (reduces churn)
- Clear conversion trigger (daily limit reached)

---

## Database Schema

### 1. Users Collection Enhancement

**Path**: `users/{userId}`

**New Fields**:
```javascript
{
  // ... existing fields ...

  // Subscription fields (NEW)
  subscription_tier: 'free' | 'trial' | 'pro',  // Current tier
  trial_start_date: Timestamp | null,           // When trial started
  trial_end_date: Timestamp | null,             // When trial ends (7 days after start)
  subscription_id: string | null,               // Reference to active subscription

  // Usage tracking (NEW)
  daily_snaps_count: number,                    // Reset at midnight IST
  daily_questions_count: number,                // Reset at midnight IST
  last_usage_reset: Timestamp,                  // Last midnight reset

  // Referral tracking (NEW)
  referral_code: string,                        // User's unique code
  referred_by: string | null,                   // Who referred this user
  referral_credits: number,                     // Credits earned (future use)
}
```

**Indexes Required**:
- `subscription_tier` (for queries)
- `trial_end_date` (for batch expiry jobs)
- `referral_code` (unique, for referral lookups)

---

### 2. Subscriptions Subcollection (NEW)

**Path**: `users/{userId}/subscriptions/{subscriptionId}`

**Purpose**: Track all subscription purchases and history

**Schema**:
```javascript
{
  subscription_id: string,                     // Auto-generated or Razorpay order_id
  plan_type: 'monthly' | 'quarterly' | 'annual',
  status: 'active' | 'expired' | 'cancelled' | 'pending_payment',

  // Pricing
  amount: number,                              // Amount paid (e.g., 747 for quarterly)
  currency: 'INR',
  per_month_rate: number,                      // e.g., 249 for quarterly

  // Lifecycle
  created_at: Timestamp,                       // When subscription created
  start_date: Timestamp,                       // When subscription becomes active
  end_date: Timestamp,                         // When subscription expires
  cancelled_at: Timestamp | null,              // When user cancelled (if applicable)
  auto_renew: boolean,                         // Whether to auto-renew (future)

  // Payment tracking
  payment_id: string | null,                   // Razorpay payment_id
  payment_status: 'pending' | 'success' | 'failed' | 'refunded',
  payment_method: 'upi' | 'card' | 'netbanking' | null,

  // Metadata
  purchased_via: 'android' | 'ios' | 'web',    // Platform
  referral_applied: string | null,             // Referral code used (if any)
  discount_amount: number,                     // Discount applied (if any)
}
```

**Indexes Required**:
- `status` (for active subscription queries)
- `end_date` (for expiry checks)

---

### 3. Transactions Collection (NEW)

**Path**: `transactions/{transactionId}`

**Purpose**: Audit log for all payment events (webhook events, refunds, etc.)

**Schema**:
```javascript
{
  transaction_id: string,                      // Auto-generated
  user_id: string,                             // Reference to user
  subscription_id: string,                     // Reference to subscription

  // Event details
  event_type: 'payment_initiated' | 'payment_success' | 'payment_failed' | 'subscription_expired' | 'subscription_cancelled' | 'refund',
  timestamp: Timestamp,

  // Payment gateway data
  razorpay_order_id: string | null,
  razorpay_payment_id: string | null,
  razorpay_signature: string | null,           // For webhook verification

  // Amount
  amount: number,
  currency: 'INR',

  // Metadata
  metadata: {
    error_code: string | null,                 // If payment failed
    error_description: string | null,
    webhook_payload: object | null,            // Full webhook data
  },
}
```

**Indexes Required**:
- `user_id` (for user transaction history)
- `timestamp` (for chronological queries)
- `event_type` (for analytics)

---

### 4. Paywall Events Collection (NEW)

**Path**: `paywall_events/{eventId}`

**Purpose**: Track conversion funnel for analytics

**Schema**:
```javascript
{
  event_id: string,                            // Auto-generated
  user_id: string,
  event_type: 'paywall_shown' | 'plan_selected' | 'payment_initiated' | 'payment_completed' | 'trial_started' | 'trial_reminder_shown' | 'trial_expired',
  timestamp: Timestamp,

  // Context
  trigger: 'daily_snap_limit' | 'daily_quiz_limit' | 'feature_locked' | 'trial_expiring' | 'manual',
  screen: string,                              // Which screen triggered paywall

  // Plan details (if applicable)
  plan_type: 'monthly' | 'quarterly' | 'annual' | null,
  amount: number | null,

  // Metadata
  metadata: {
    platform: 'android' | 'ios',
    app_version: string,
  },
}
```

**Indexes Required**:
- `user_id` + `timestamp` (user funnel analysis)
- `event_type` + `timestamp` (aggregate analytics)

---

## Backend API Design

### Base URL: `/api/subscriptions`

---

### 1. **GET** `/api/subscriptions/status`

**Purpose**: Get current user's subscription status and usage limits

**Auth**: Required (Firebase Auth token)

**Response**:
```javascript
{
  subscription_tier: 'trial' | 'free' | 'pro',

  // Trial info (if applicable)
  trial_active: boolean,
  trial_days_remaining: number | null,
  trial_end_date: Timestamp | null,

  // Current subscription (if pro)
  subscription: {
    plan_type: 'monthly' | 'quarterly' | 'annual',
    start_date: Timestamp,
    end_date: Timestamp,
    auto_renew: boolean,
  } | null,

  // Usage limits
  daily_limits: {
    snaps: {
      limit: 5 | 999999,                       // 999999 = unlimited
      used: number,
      remaining: number,
      resets_at: Timestamp,                    // Next midnight IST
    },
    questions: {
      limit: 10 | 999999,
      used: number,
      remaining: number,
      resets_at: Timestamp,
    },
  },

  // Feature flags
  features: {
    unlimited_snaps: boolean,
    unlimited_quizzes: boolean,
    detailed_solutions: boolean,
    doubt_library: boolean,
    analytics: boolean,
    study_recommendations: boolean,
  },
}
```

**Logic**:
1. Check user's `subscription_tier`
2. If trial, check if expired (compare `trial_end_date` to now)
3. If pro, check if subscription expired (query active subscription)
4. Return usage counts from `daily_snaps_count`, `daily_questions_count`
5. Calculate `resets_at` (next midnight IST)

---

### 2. **POST** `/api/subscriptions/start-trial`

**Purpose**: Start 7-day free trial for new users

**Auth**: Required

**Request Body**: None

**Response**:
```javascript
{
  success: true,
  trial_start_date: Timestamp,
  trial_end_date: Timestamp,              // 7 days from now
  message: "Enjoy 7 days of unlimited access!"
}
```

**Logic**:
1. Verify user hasn't used trial before (check `trial_start_date`)
2. Set `subscription_tier: 'trial'`
3. Set `trial_start_date: now`
4. Set `trial_end_date: now + 7 days`
5. Reset usage counters
6. Log `paywall_events`: `trial_started`

**Errors**:
- 400: Trial already used
- 400: Already Pro subscriber

---

### 3. **POST** `/api/subscriptions/create-order`

**Purpose**: Create Razorpay order for payment

**Auth**: Required

**Request Body**:
```javascript
{
  plan_type: 'monthly' | 'quarterly' | 'annual',
  referral_code: string | null,               // Optional referral code
}
```

**Response**:
```javascript
{
  order_id: string,                           // Razorpay order_id
  amount: number,                             // Amount in paise (e.g., 74700 for ₹747)
  currency: 'INR',
  payment_url: string,                        // URL to open in WebView
  subscription_id: string,                    // Internal subscription ID
}
```

**Logic**:
1. Validate plan_type
2. Calculate amount based on plan:
   - Monthly: 29900 paise (₹299)
   - Quarterly: 74700 paise (₹747)
   - Annual: 238800 paise (₹2,388)
3. Apply referral discount if valid (future enhancement)
4. Create Razorpay order via API:
   ```javascript
   const order = await razorpay.orders.create({
     amount: 74700,                          // Amount in paise
     currency: 'INR',
     receipt: `receipt_${userId}_${timestamp}`,
     notes: {
       user_id: userId,
       plan_type: 'quarterly',
     },
   });
   ```
5. Create subscription document in Firestore (status: `pending_payment`)
6. Log `paywall_events`: `payment_initiated`
7. Return order details + payment URL

---

### 4. **POST** `/api/subscriptions/verify-payment`

**Purpose**: Verify payment signature after Razorpay callback

**Auth**: Required

**Request Body**:
```javascript
{
  razorpay_order_id: string,
  razorpay_payment_id: string,
  razorpay_signature: string,
}
```

**Response**:
```javascript
{
  success: true,
  subscription: {
    subscription_id: string,
    plan_type: 'quarterly',
    start_date: Timestamp,
    end_date: Timestamp,
  }
}
```

**Logic**:
1. Verify signature using Razorpay SDK:
   ```javascript
   const isValid = razorpay.validateWebhookSignature(
     razorpay_order_id + '|' + razorpay_payment_id,
     razorpay_signature,
     process.env.RAZORPAY_KEY_SECRET
   );
   ```
2. If invalid → 400 error
3. Update subscription document:
   - `status: 'active'`
   - `start_date: now`
   - `end_date: now + plan_duration`
   - `payment_id: razorpay_payment_id`
   - `payment_status: 'success'`
4. Update user document:
   - `subscription_tier: 'pro'`
   - `subscription_id: subscriptionId`
5. Log transaction in `transactions` collection
6. Log `paywall_events`: `payment_completed`
7. Send confirmation email (future)

---

### 5. **POST** `/api/subscriptions/cancel`

**Purpose**: Cancel subscription (remains active until end_date)

**Auth**: Required

**Request Body**: None

**Response**:
```javascript
{
  success: true,
  message: "Subscription cancelled. Pro access until [end_date]",
  access_until: Timestamp,
}
```

**Logic**:
1. Find active subscription for user
2. Update subscription:
   - `auto_renew: false`
   - `cancelled_at: now`
3. Log `paywall_events`: `subscription_cancelled`
4. Do NOT change `subscription_tier` (user keeps Pro until expiry)

---

### 6. **POST** `/api/subscriptions/upgrade`

**Purpose**: Upgrade from Monthly → Quarterly/Annual (immediate upgrade, prorated)

**Auth**: Required

**Request Body**:
```javascript
{
  new_plan_type: 'quarterly' | 'annual',
}
```

**Response**:
```javascript
{
  order_id: string,
  prorated_amount: number,                   // Amount to pay (adjusted for unused days)
  payment_url: string,
}
```

**Logic**:
1. Find current active subscription
2. Calculate unused days: `(end_date - now) / 86400`
3. Calculate credit: `(unused_days / total_days) * amount_paid`
4. Calculate new amount: `new_plan_price - credit`
5. Create new Razorpay order for prorated amount
6. Return payment URL

**Note**: Implement in Phase 2 (MVP can skip proration, just allow immediate upgrade at full price)

---

### 7. **POST** `/api/webhooks/razorpay`

**Purpose**: Handle Razorpay webhooks (payment success, failure, etc.)

**Auth**: None (verified via signature)

**Request Body**: Razorpay webhook payload

**Logic**:
1. Verify webhook signature
2. Parse event type: `payment.captured`, `payment.failed`, etc.
3. Extract `order_id` from payload
4. Find subscription by `razorpay_order_id`
5. Update subscription status accordingly
6. Log to `transactions` collection
7. If payment failed → send notification to user

**Webhook Events to Handle**:
- `payment.captured` → Activate subscription
- `payment.failed` → Mark subscription failed
- `subscription.charged` → Auto-renewal (future)

---

### 8. **POST** `/api/usage/increment`

**Purpose**: Increment daily usage counter (called from mobile)

**Auth**: Required

**Request Body**:
```javascript
{
  usage_type: 'snap' | 'question',
  count: number,                             // How many to increment
}
```

**Response**:
```javascript
{
  success: true,
  new_count: number,
  limit: number,
  remaining: number,
  limit_reached: boolean,
}
```

**Logic**:
1. Check if new day (compare `last_usage_reset` to current date IST)
2. If new day → reset counters to 0
3. Check user's tier:
   - Trial/Pro → limit = 999999 (unlimited)
   - Free → limit = 5 (snaps) or 10 (questions)
4. Increment counter: `daily_snaps_count += count`
5. Check if limit exceeded → return `limit_reached: true`
6. If limit reached → log `paywall_events`: `paywall_shown`

**Server-side validation** prevents client-side bypass.

---

## Web Payment Page Design

### Tech Stack
- **Framework**: Next.js (React) - lightweight, fast
- **Styling**: Tailwind CSS (matches mobile design)
- **Payment**: Razorpay Checkout.js

### Pages

#### 1. `/payment/plans` - Plan Selection
**URL**: `https://jeevibe.com/payment/plans?userId={userId}&token={token}`

**UI** (matches mockup):
```
┌─────────────────────────────────────┐
│  Choose Your Plan                   │
├─────────────────────────────────────┤
│  ○ Monthly        ₹299/month        │
│  ● Quarterly      ₹249/month        │
│     [MOST POPULAR]                  │
│     ₹747 total • Save ₹150 (17% off)│
│  ○ Annual         ₹199/month        │
│     [SAVE 33%]                      │
│     ₹2,388 total • Save ₹1,200      │
├─────────────────────────────────────┤
│  Referral Code: [____________]      │
│  [Apply]                            │
├─────────────────────────────────────┤
│  Total: ₹747                        │
│  [Proceed to Payment] →             │
└─────────────────────────────────────┘
```

**Logic**:
1. Verify `token` via backend (JWT signed by backend)
2. Display plans with pricing
3. On "Proceed" → Call `/api/subscriptions/create-order`
4. Redirect to payment page with `order_id`

---

#### 2. `/payment/checkout` - Razorpay Payment
**URL**: `https://jeevibe.com/payment/checkout?orderId={orderId}`

**UI**:
```
┌─────────────────────────────────────┐
│  Complete Payment                   │
├─────────────────────────────────────┤
│  Plan: Quarterly Pro                │
│  Amount: ₹747                       │
├─────────────────────────────────────┤
│  [Razorpay Checkout Modal]          │
│  - UPI                              │
│  - Cards                            │
│  - NetBanking                       │
└─────────────────────────────────────┘
```

**Logic**:
1. Fetch order details from backend
2. Initialize Razorpay Checkout:
   ```javascript
   const options = {
     key: process.env.NEXT_PUBLIC_RAZORPAY_KEY_ID,
     amount: 74700,
     currency: 'INR',
     order_id: orderId,
     name: 'JEEVibe Pro',
     description: 'Quarterly Subscription',
     handler: function(response) {
       // Payment success callback
       verifyPayment(response);
     },
     prefill: {
       contact: user.phoneNumber,
       email: user.email,
     },
     theme: {
       color: '#7C3AED',                     // AppColors.primaryPurple
     },
   };
   const rzp = new Razorpay(options);
   rzp.open();
   ```
3. On success → Call `/api/subscriptions/verify-payment`
4. Redirect to success page

---

#### 3. `/payment/success` - Success Screen
**URL**: `https://jeevibe.com/payment/success?subscriptionId={id}`

**UI** (matches mockup):
```
┌─────────────────────────────────────┐
│         ✓ Payment Successful!       │
├─────────────────────────────────────┤
│  Welcome to JEEVibe Pro!            │
│                                     │
│  Your subscription is now active.   │
│  Enjoy unlimited access to:         │
│  ✓ Unlimited Snaps                  │
│  ✓ Unlimited Daily Quizzes          │
│  ✓ Detailed Solutions               │
│  ✓ Performance Analytics            │
│                                     │
│  [Return to App] →                  │
└─────────────────────────────────────┘
```

**Logic**:
1. Display success message
2. Button triggers WebView close (via custom URL scheme)
3. Mobile app detects close → refreshes subscription status → shows in-app success

---

### Mobile WebView Integration

**Package**: `flutter_inappwebview: ^6.0.0`

**Implementation**:
```dart
// mobile/lib/screens/subscription/payment_webview_screen.dart

class PaymentWebViewScreen extends StatefulWidget {
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upgrade to Pro')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: Uri.parse('https://jeevibe.com/payment/plans?userId=$userId&token=$authToken'),
        ),
        onLoadStart: (controller, url) {
          // Detect success redirect
          if (url.toString().contains('/payment/success')) {
            // Close WebView, return to app
            Navigator.pop(context, {'success': true});
          }
        },
        onConsoleMessage: (controller, message) {
          // Listen for custom messages from web
          if (message.message == 'payment_cancelled') {
            Navigator.pop(context, {'success': false});
          }
        },
      ),
    );
  }
}
```

---

## Mobile UI Screens

### 1. Paywall Screen (Matches Mockup Screen 1)

**Path**: `mobile/lib/screens/subscription/paywall_screen.dart`

**Trigger**:
- Daily snap limit reached
- Daily quiz limit reached
- Trial expiring (day 5)
- Manual tap on "Upgrade to Pro" in settings

**UI Structure**:
```
┌─────────────────────────────────────┐
│  Unlock Your Full Potential         │
├─────────────────────────────────────┤
│  ✓ Unlimited Snaps                  │
│    Never stop learning              │
│                                     │
│  ✓ Unlimited Daily Quizzes          │
│    Practice makes perfect           │
│                                     │
│  ✓ Detailed Step-by-Step Solutions  │
│    Understand every concept         │
│                                     │
│  ✓ Personal Doubt Library           │
│    Track your learning journey      │
│                                     │
│  ✓ Performance Analytics            │
│    Know your strengths & weaknesses │
│                                     │
│  ✓ Smart Study Recommendations      │
│    AI-powered personalized tips     │
├─────────────────────────────────────┤
│  [See Plans] →                      │
│  [Maybe Later]                      │
└─────────────────────────────────────┘
```

**Logic**:
1. Display benefits list
2. "See Plans" → Navigate to ComparisonScreen
3. "Maybe Later" → Close (only if free tier, not during trial expiry)
4. Log `paywall_events`: `paywall_shown` with trigger context

---

### 2. Comparison Screen (Matches Mockup Screen 1b)

**Path**: `mobile/lib/screens/subscription/comparison_screen.dart`

**UI Structure**:
```
┌─────────────────────────────────────┐
│  Free vs Pro                        │
├─────────────────────────────────────┤
│  Feature         | Free    | Pro    │
│  ────────────────┼─────────┼────────│
│  Daily Snaps     | 5       | ∞      │
│  Daily Quizzes   | 1       | ∞      │
│  Solutions       | Basic   | Full   │
│  Doubt Library   | ✗       | ✓      │
│  Analytics       | ✗       | ✓      │
│  Recommendations | ✗       | ✓      │
├─────────────────────────────────────┤
│  [Choose Plan] →                    │
└─────────────────────────────────────┘
```

**Logic**:
1. Display comparison table
2. "Choose Plan" → Open PaymentWebView

---

### 3. Trial Reminder (In-App Alert)

**Trigger**: Day 5 of trial (2 days remaining)

**UI** (Alert Dialog):
```
┌─────────────────────────────────────┐
│  2 Days Left of Unlimited Access!   │
├─────────────────────────────────────┤
│  Your trial ends on [date].         │
│  Upgrade now to continue enjoying:  │
│  • Unlimited snaps & quizzes        │
│  • Performance analytics            │
│  • And more!                        │
├─────────────────────────────────────┤
│  [Upgrade Now]   [Remind Me Later]  │
└─────────────────────────────────────┘
```

**Logic**:
1. Backend sends push notification on day 5
2. App shows dialog
3. "Upgrade Now" → Open PaymentWebView
4. "Remind Me Later" → Show again tomorrow
5. Log `paywall_events`: `trial_reminder_shown`

---

### 4. Limit Reached Screen

**Trigger**: User hits daily snap/quiz limit (free tier only)

**UI**:
```
┌─────────────────────────────────────┐
│  Daily Limit Reached                │
├─────────────────────────────────────┤
│  You've used all 5 snaps for today. │
│                                     │
│  Resets in: 4h 32m                  │
│                                     │
│  Want unlimited access?             │
│  Upgrade to Pro for just ₹199/month │
│                                     │
│  [Upgrade to Pro] →                 │
│  [I'll Wait]                        │
└─────────────────────────────────────┘
```

**Logic**:
1. Display limit reached message
2. Show countdown to midnight IST reset
3. "Upgrade to Pro" → Open PaymentWebView
4. "I'll Wait" → Close, return to home
5. Log `paywall_events`: `paywall_shown` with trigger `daily_snap_limit`

---

### 5. Settings - Subscription Management

**Path**: `mobile/lib/screens/settings/subscription_settings_screen.dart`

**UI** (Pro user):
```
┌─────────────────────────────────────┐
│  Subscription                       │
├─────────────────────────────────────┤
│  Current Plan: Quarterly Pro        │
│  Renews on: Jan 15, 2026            │
│  Amount: ₹747                       │
├─────────────────────────────────────┤
│  [Upgrade Plan]                     │
│  [Cancel Subscription]              │
└─────────────────────────────────────┘
```

**UI** (Free user):
```
┌─────────────────────────────────────┐
│  Subscription                       │
├─────────────────────────────────────┤
│  Current Plan: Free                 │
│  • 5 snaps/day (3 remaining)        │
│  • 1 quiz/day (0 remaining)         │
├─────────────────────────────────────┤
│  [Upgrade to Pro] →                 │
└─────────────────────────────────────┘
```

---

## Feature Gating Logic

### Client-Side (Mobile)

**Purpose**: Fast UX, show limits immediately

**Implementation**:
```dart
// mobile/lib/services/subscription_service.dart

class SubscriptionService {
  Future<bool> canTakeSnap() async {
    final status = await getSubscriptionStatus();

    if (status.subscriptionTier == 'pro' || status.subscriptionTier == 'trial') {
      return true; // Unlimited
    }

    // Free tier - check limit
    if (status.dailyLimits.snaps.remaining > 0) {
      return true;
    }

    // Limit reached - show paywall
    _showPaywall(trigger: 'daily_snap_limit');
    return false;
  }

  Future<bool> canStartQuiz() async {
    final status = await getSubscriptionStatus();

    if (status.subscriptionTier == 'pro' || status.subscriptionTier == 'trial') {
      return true;
    }

    if (status.dailyLimits.questions.remaining > 0) {
      return true;
    }

    _showPaywall(trigger: 'daily_quiz_limit');
    return false;
  }
}
```

**Usage**:
```dart
// Before taking snap
final canProceed = await subscriptionService.canTakeSnap();
if (!canProceed) return;

// Proceed with snap...
```

---

### Server-Side (Backend)

**Purpose**: Security, prevent bypass

**Implementation** (modify existing endpoints):

#### `POST /api/snaps/create`
```javascript
// BEFORE creating snap
const user = await db.collection('users').doc(userId).get();
const userData = user.data();

// Check tier
if (userData.subscription_tier === 'free') {
  // Check if new day (reset counters)
  const lastReset = userData.last_usage_reset.toDate();
  const now = new Date();
  if (!isSameDay(lastReset, now)) {
    // Reset counters
    await user.ref.update({
      daily_snaps_count: 0,
      daily_questions_count: 0,
      last_usage_reset: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // Check limit
  const currentCount = userData.daily_snaps_count || 0;
  if (currentCount >= 5) {
    throw new ApiError(403, 'Daily snap limit reached. Upgrade to Pro for unlimited access.');
  }

  // Increment counter
  await user.ref.update({
    daily_snaps_count: admin.firestore.FieldValue.increment(1),
  });
}

// Proceed with snap creation...
```

#### `POST /api/quiz/start`
```javascript
// Similar logic for quiz limit (10 questions/day)
if (userData.subscription_tier === 'free') {
  const currentCount = userData.daily_questions_count || 0;
  if (currentCount >= 10) {
    throw new ApiError(403, 'Daily quiz limit reached. Upgrade to Pro for unlimited access.');
  }

  // Will increment by 10 after quiz completion
}
```

---

## Offline Support (24-hour Trust)

**Problem**: User has no internet but has active Pro subscription

**Solution**: Cache subscription status locally, trust for 24 hours

**Implementation**:
```dart
// mobile/lib/services/subscription_service.dart

class SubscriptionService {
  static const String _cacheKey = 'subscription_status_cache';
  static const Duration _cacheTTL = Duration(hours: 24);

  Future<SubscriptionStatus> getSubscriptionStatus({bool forceRefresh = false}) async {
    // Try cache first
    if (!forceRefresh) {
      final cached = await _getCachedStatus();
      if (cached != null && !cached.isExpired) {
        return cached.status;
      }
    }

    try {
      // Fetch from backend
      final response = await http.get('/api/subscriptions/status');
      final status = SubscriptionStatus.fromJson(response.data);

      // Cache for 24 hours
      await _cacheStatus(status);

      return status;
    } catch (e) {
      // Network error - use cached if available
      final cached = await _getCachedStatus();
      if (cached != null) {
        // Show warning to user
        _showOfflineWarning();
        return cached.status;
      }

      // No cache, no network - default to free tier (safe default)
      return SubscriptionStatus.defaultFree();
    }
  }

  Future<void> _cacheStatus(SubscriptionStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = {
      'status': status.toJson(),
      'cached_at': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_cacheKey, jsonEncode(cache));
  }
}
```

**User Experience**:
- Online: Always fetch fresh status
- Offline (< 24h): Use cached status, show banner "You're offline"
- Offline (> 24h): Force free tier, show "Connect to verify subscription"

---

## Analytics Tracking

### Events to Track

**Tool**: Firebase Analytics (already integrated) + Mixpanel (future)

**Events**:
```javascript
// 1. Trial events
analytics.logEvent('trial_started', {
  user_id: userId,
  timestamp: now,
});

analytics.logEvent('trial_reminder_shown', {
  user_id: userId,
  days_remaining: 2,
});

analytics.logEvent('trial_expired', {
  user_id: userId,
  converted_to_pro: false,
});

// 2. Paywall funnel
analytics.logEvent('paywall_shown', {
  trigger: 'daily_snap_limit',
  screen: 'snap_camera',
});

analytics.logEvent('plan_selected', {
  plan_type: 'quarterly',
  amount: 747,
});

analytics.logEvent('payment_initiated', {
  plan_type: 'quarterly',
  amount: 747,
  payment_method: 'upi',
});

analytics.logEvent('payment_completed', {
  plan_type: 'quarterly',
  amount: 747,
  transaction_id: 'pay_xyz123',
});

// 3. Usage events
analytics.logEvent('daily_limit_reached', {
  limit_type: 'snaps',
  user_tier: 'free',
});

analytics.logEvent('feature_locked', {
  feature: 'analytics',
  user_tier: 'free',
});

// 4. Subscription lifecycle
analytics.logEvent('subscription_cancelled', {
  plan_type: 'quarterly',
  days_remaining: 45,
  reason: 'too_expensive', // from user survey
});

analytics.logEvent('subscription_expired', {
  plan_type: 'quarterly',
  renewed: false,
});
```

### Conversion Funnel Analysis

**Metrics to Track**:
```
Trial Started → Trial Completed → Paywall Shown → Plan Selected → Payment Initiated → Payment Success

Targets:
- Trial → Paywall: 70% (70% hit limits during trial)
- Paywall → Plan Selected: 30%
- Plan Selected → Payment Success: 80%
- **Overall Trial → Paid**: ~17% (industry benchmark for education apps)
```

---

## Referral System (Future Enhancement)

**Flow**:
1. User gets unique referral code: `JOHN2024`
2. New user enters code during payment
3. Both users get reward:
   - Referrer: ₹100 credit or 1 month free
   - Referee: 10% discount on first purchase

**Database**:
```javascript
// users/{userId}
{
  referral_code: 'JOHN2024',              // Unique code
  referred_by: 'userId_xyz',              // Who referred them
  referral_credits: 100,                  // Credits earned (₹)
  referrals_count: 5,                     // How many referred
}

// referrals/{referralId}
{
  referrer_id: 'userId_abc',
  referee_id: 'userId_xyz',
  referral_code: 'JOHN2024',
  reward_amount: 100,
  reward_status: 'pending' | 'credited',
  created_at: Timestamp,
}
```

**Implementation**: Phase 2 (after MVP)

---

## Security Considerations

### 1. Payment Security
- **Razorpay webhook signature verification** (HMAC SHA256)
- **Never trust client** - always verify payment server-side
- **Store sensitive keys** in environment variables (never commit)

### 2. Subscription Verification
- **JWT tokens** for WebView authentication
- **Expire tokens** after 5 minutes
- **Server-side subscription checks** before granting Pro features

### 3. Usage Limit Bypass Prevention
- **Double validation**: Client (UX) + Server (security)
- **Rate limiting** on usage endpoints (prevent API abuse)
- **Audit logs** in transactions collection

### 4. Referral Fraud Prevention
- **Limit referral rewards** (max 10 referrals/month)
- **Verify unique devices** (prevent self-referrals)
- **Manual review** for high-volume referrers

---

## Testing Strategy

### Unit Tests

**Backend**:
```javascript
// tests/unit/subscriptionService.test.js

describe('Subscription Service', () => {
  test('should create trial for new user', async () => {
    const result = await subscriptionService.startTrial(userId);
    expect(result.trial_end_date).toBeDefined();
    expect(result.subscription_tier).toBe('trial');
  });

  test('should reject trial if already used', async () => {
    await subscriptionService.startTrial(userId);
    await expect(subscriptionService.startTrial(userId))
      .rejects.toThrow('Trial already used');
  });

  test('should calculate prorated upgrade correctly', async () => {
    const result = await subscriptionService.calculateUpgrade(userId, 'annual');
    expect(result.prorated_amount).toBeLessThan(238800);
  });
});
```

**Mobile**:
```dart
// mobile/test/unit/services/subscription_service_test.dart

void main() {
  group('SubscriptionService', () => {
    test('should return true for Pro user taking snap', () async {
      // Mock Pro user
      final service = SubscriptionService();
      final canTake = await service.canTakeSnap();
      expect(canTake, true);
    });

    test('should return false when free user hits limit', () async {
      // Mock free user with 5 snaps used
      final service = SubscriptionService();
      final canTake = await service.canTakeSnap();
      expect(canTake, false);
    });
  });
}
```

---

### Integration Tests

**Payment Flow**:
```javascript
// tests/integration/payment.test.js

describe('Payment Integration', () => {
  test('complete payment flow - Razorpay mock', async () => {
    // 1. Create order
    const order = await api.post('/subscriptions/create-order', {
      plan_type: 'quarterly',
    });
    expect(order.order_id).toBeDefined();

    // 2. Mock Razorpay payment success
    const payment = mockRazorpayPayment(order.order_id);

    // 3. Verify payment
    const result = await api.post('/subscriptions/verify-payment', {
      razorpay_order_id: order.order_id,
      razorpay_payment_id: payment.payment_id,
      razorpay_signature: payment.signature,
    });
    expect(result.success).toBe(true);

    // 4. Check user is now Pro
    const user = await db.collection('users').doc(userId).get();
    expect(user.data().subscription_tier).toBe('pro');
  });
});
```

---

### Manual Testing Checklist

- [ ] Free trial: Start trial, verify 7 days added
- [ ] Trial expiry: Fast-forward time, verify reverts to free
- [ ] Payment flow: Complete payment on web, verify Pro activated
- [ ] Usage limits: Hit snap limit (5), verify paywall shown
- [ ] Usage limits: Hit quiz limit (10), verify paywall shown
- [ ] Offline mode: Disconnect internet, verify cached status used
- [ ] Subscription cancel: Cancel Pro, verify access until end_date
- [ ] Razorpay webhook: Trigger webhook, verify subscription updated
- [ ] Analytics: Check Firebase Analytics for funnel events

---

## Deployment Plan

### Phase 1: MVP (Week 1-2)
- [ ] Database schema implementation
- [ ] Backend API endpoints (create-order, verify-payment, status)
- [ ] Web payment page (Next.js + Razorpay)
- [ ] Mobile WebView integration
- [ ] Basic paywall screens (benefits, comparison)
- [ ] Usage limit enforcement (server-side)
- [ ] Analytics tracking (Firebase)

### Phase 2: Enhancements (Week 3-4)
- [ ] Referral system
- [ ] Subscription upgrade/downgrade
- [ ] Promo codes
- [ ] Email notifications (trial expiry, payment success)
- [ ] Advanced analytics (Mixpanel integration)
- [ ] A/B testing (paywall copy variations)

### Phase 3: Optimization (Ongoing)
- [ ] Conversion funnel optimization
- [ ] Pricing experiments
- [ ] Personalized paywall triggers
- [ ] Win-back campaigns (expired users)

---

## Success Metrics

### North Star Metric
**Paid Conversion Rate**: 15-20% of trial users convert to paid

### Supporting Metrics
- **Trial Activation**: 80%+ of new users start trial
- **Trial Completion**: 60%+ complete full 7 days
- **Paywall Engagement**: 40%+ of free users see paywall within 30 days
- **Payment Success Rate**: 85%+ of payment attempts succeed
- **Monthly Churn**: <5% of Pro users cancel per month
- **LTV:CAC Ratio**: >3:1 (lifetime value vs acquisition cost)

### Revenue Targets (Year 1)
- Month 1-3: ₹50,000/month (100 users @ ₹500 avg)
- Month 4-6: ₹2,00,000/month (400 users)
- Month 7-12: ₹5,00,000/month (1000 users)

---

## Known Limitations & Future Work

### MVP Limitations
1. **No auto-renewal**: Manual renewal required (add later via Razorpay subscriptions)
2. **No proration**: Upgrades charge full amount (add in Phase 2)
3. **No family plans**: Individual subscriptions only
4. **Web-only payment**: No native in-app purchase (future: add for iOS)
5. **Single currency**: INR only (future: multi-currency for international)

### Future Enhancements
1. **Lifetime plan**: One-time payment (₹9,999 for lifetime Pro)
2. **Group subscriptions**: Schools/coaching institutes (₹199/student/year)
3. **Dynamic pricing**: Based on usage patterns, exam proximity
4. **Payment installments**: EMI options via Razorpay
5. **Crypto payments**: For international users

---

## Next Steps

1. **Review this design doc** - Confirm all decisions align with vision
2. **Set up Razorpay account** - Get API keys (test + production)
3. **Create Next.js project** - For web payment pages
4. **Implement database schema** - Add new collections/fields
5. **Build backend APIs** - Start with `/status` and `/create-order`
6. **Build web payment page** - Plan selection + Razorpay integration
7. **Build mobile WebView** - Integrate payment flow
8. **Test end-to-end** - Complete payment in test mode
9. **Deploy to staging** - Test with real users
10. **Launch to production** - Monitor metrics closely

---

**Last Updated**: 2026-01-02
**Status**: 🎯 Ready for Implementation
**Estimated Effort**: 80-100 hours (2-3 weeks full-time)
