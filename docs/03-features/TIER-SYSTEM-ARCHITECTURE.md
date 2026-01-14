# Tier System Architecture

> **Companion document to**: [PAYWALL-SYSTEM-DESIGN.md](./PAYWALL-SYSTEM-DESIGN.md)
>
> **Status**: 🎯 **DESIGN PHASE** - Ready for Implementation
>
> **Last Updated**: 2026-01-14

## Overview

This document extends the paywall design to support a **3-tier subscription system** (FREE, PRO, ULTRA) with flexible, Firestore-driven configuration.

**Key Architectural Decisions**:
1. **Firestore-driven tier config** - No hardcoded limits; all tier definitions stored in Firestore
2. **Launch with 2 public tiers** - Free + Pro publicly available
3. **Ultra for beta testers** - Ultra tier exists but is not purchasable; granted via admin override
4. **Admin via Firebase Console** - No custom admin dashboard; manage tiers directly in Firestore

---

## Tier Feature Matrix

### Complete Feature Set (Current + Roadmap)

| Feature | Status | FREE | PRO | ULTRA |
|---------|--------|------|-----|-------|
| **CORE FEATURES** |||||
| Snap & Solve | ✅ Built | 5/day | 10/day | Unlimited |
| Daily Quiz (Adaptive) | ✅ Built | 1/day | 10/day | Unlimited |
| Solutions | ✅ Built | Full step-by-step | Full step-by-step | Full step-by-step |
| Analytics | ✅ Built | Basic (streak, total) | Full access | Full access |
| **AI FEATURES** |||||
| AI Tutor (Priya Ma'am) | 📋 Planned | No | No | Yes |
| **PRACTICE & TESTING** |||||
| Chapter Practice | 🔮 Future | 5 problems/chapter | 20/chapter | Unlimited |
| Full Mock Tests | 🔮 Future | 1/month | 5/month | Unlimited |
| PYQ Bank | 🔮 Future | Last 2 years | Last 5 years | All years (10+) |
| **UTILITY** |||||
| Offline Mode | 🔮 Future | No | Yes (unlimited) | Yes (unlimited) |
| Solution History | ✅ Built | Last 7 days | Last 30 days | Unlimited |

**Legend**: ✅ Built | 📋 Planned (design complete) | 🔮 Future (roadmap)

> **Note**: Solutions are always full step-by-step for all tiers. We don't gate solution quality - students learn best with complete explanations.

### Pricing (Pro Tier)

| Plan | Price | Per Month | Savings |
|------|-------|-----------|---------|
| Monthly | ₹299 | ₹299 | - |
| Quarterly | ₹747 | ₹249 | 17% (₹150) |
| Annual | ₹2,388 | ₹199 | 33% (₹1,200) |

**Ultra pricing**: TBD when publicly launched

---

## Feature Descriptions

### Built Features (✅)

| Feature | Description |
|---------|-------------|
| **Snap & Solve** | Take photo of question, get AI-generated solution with steps |
| **Daily Quiz** | Adaptive quiz using IRT algorithm, personalized difficulty |
| **Solutions** | Full step-by-step explanations with approach, steps, final answer |
| **Analytics** | Performance tracking, theta scores, mastery levels, focus areas |
| **Solution History** | View past snapped questions and solutions |

### Planned Features (📋)

| Feature | Description | Design Doc |
|---------|-------------|------------|
| **AI Tutor** | Priya Ma'am chatbot for doubt resolution, concept learning, personalized coaching | [AI-TUTOR-DESIGN.md](./AI-TUTOR-DESIGN.md) |

### Future Features (🔮 Roadmap)

| Feature | Description | Gating Strategy |
|---------|-------------|-----------------|
| **Chapter Practice** | Topic-wise problem sets organized by JEE syllabus. Filter by difficulty, type. | Limit problems per chapter |
| **Full Mock Tests** | Complete JEE Main (3hr, 90Q) and JEE Advanced (6hr, 54Q) mock tests with timer, marking scheme, analysis. | Limit tests per month |
| **PYQ Bank** | Previous Year Questions from JEE Main/Advanced (2010-2025+) with solutions, filters by year/chapter/difficulty. | Limit years accessible |
| **Offline Mode** | Download solutions for offline viewing. Sync when back online. | Enable/disable + limit count |

---

## Database Schema

### 1. Tier Configuration (Firestore-Driven)

**Path**: `tier_config/active`

This is the **single source of truth** for all tier definitions. Edit directly in Firebase Console to change limits, pricing, or features without code deployment.

```javascript
{
  // Metadata
  version: "1.0.0",
  updated_at: Timestamp,
  updated_by: "admin@jeevibe.com",

  // Tier definitions
  tiers: {
    "free": {
      tier_id: "free",
      display_name: "Free",
      display_order: 1,
      is_active: true,
      is_purchasable: false,

      // Limits (-1 = unlimited, 0 = disabled)
      limits: {
        // Core features (✅ Built)
        snap_solve_daily: 5,
        daily_quiz_daily: 1,
        solution_history_days: 7,

        // AI features (📋 Planned)
        ai_tutor_enabled: false,
        ai_tutor_messages_daily: 0,

        // Practice & Testing (🔮 Future)
        chapter_practice_per_chapter: 5,
        mock_tests_monthly: 1,
        pyq_years_access: 2,

        // Utility (🔮 Future)
        offline_enabled: false,
        offline_solutions_limit: 0
      },

      // Feature access
      features: {
        analytics_access: "basic"              // "basic" | "full"
      },

      // UI configuration
      ui_config: {
        badge_text: null,
        badge_color: null,
        highlight: false
      }
    },

    "pro": {
      tier_id: "pro",
      display_name: "Pro",
      display_order: 2,
      is_active: true,
      is_purchasable: true,  // Available for purchase

      limits: {
        // Core features (✅ Built)
        snap_solve_daily: 10,
        daily_quiz_daily: 10,
        solution_history_days: 30,

        // AI features (📋 Planned)
        ai_tutor_enabled: false,
        ai_tutor_messages_daily: 0,

        // Practice & Testing (🔮 Future)
        chapter_practice_per_chapter: 20,
        mock_tests_monthly: 5,
        pyq_years_access: 5,

        // Utility (🔮 Future)
        offline_enabled: true,
        offline_solutions_limit: -1  // Unlimited
      },

      features: {
        analytics_access: "full"
      },

      ui_config: {
        badge_text: "PRO",
        badge_color: "#7C3AED",
        highlight: true
      },

      // Pricing in paise (₹1 = 100 paise)
      pricing: {
        monthly: {
          price: 29900,
          display_price: "299",
          per_month_price: "299",
          duration_days: 30,
          savings_percent: 0,
          badge: null
        },
        quarterly: {
          price: 74700,
          display_price: "747",
          per_month_price: "249",
          duration_days: 90,
          savings_percent: 17,
          badge: "MOST POPULAR"
        },
        annual: {
          price: 238800,
          display_price: "2,388",
          per_month_price: "199",
          duration_days: 365,
          savings_percent: 33,
          badge: "SAVE 33%"
        }
      }
    },

    "ultra": {
      tier_id: "ultra",
      display_name: "Ultra",
      display_order: 3,
      is_active: true,
      is_purchasable: false,  // NOT publicly available (beta only)

      limits: {
        // Core features (✅ Built) - All unlimited
        snap_solve_daily: -1,
        daily_quiz_daily: -1,
        solution_history_days: -1,

        // AI features (📋 Planned)
        ai_tutor_enabled: true,
        ai_tutor_messages_daily: -1,

        // Practice & Testing (🔮 Future) - All unlimited
        chapter_practice_per_chapter: -1,
        mock_tests_monthly: -1,
        pyq_years_access: -1,  // All years

        // Utility (🔮 Future)
        offline_enabled: true,
        offline_solutions_limit: -1  // Unlimited
      },

      features: {
        analytics_access: "full"
      },

      ui_config: {
        badge_text: "ULTRA",
        badge_color: "#F59E0B",
        highlight: true,
        glow_effect: true
      },

      // Future pricing (when publicly launched)
      pricing: {
        monthly: { price: 49900, display_price: "499", duration_days: 30 },
        quarterly: { price: 119700, display_price: "1,197", duration_days: 90 },
        annual: { price: 358800, display_price: "3,588", duration_days: 365 }
      }
    }
  },

  // Override types for beta testers, promotions
  override_types: {
    "beta_tester": {
      tier_id: "ultra",
      default_duration_days: 90,
      is_auto_renewable: false
    },
    "promotional": {
      tier_id: "pro",
      default_duration_days: 30,
      is_auto_renewable: false
    }
  }
}
```

### 2. User Document Enhancement

**Path**: `users/{userId}`

Add these fields to existing user documents:

```javascript
{
  // ... existing fields (firstName, lastName, etc.) ...

  // NEW: Subscription state
  subscription: {
    tier: "free",  // Current effective tier

    // Override (for beta testers, promotions)
    override: {
      type: "beta_tester" | "promotional" | null,
      tier_id: "ultra",           // Tier granted by override
      granted_by: "admin_uid",    // Who granted it
      granted_at: Timestamp,
      expires_at: Timestamp,
      reason: "Beta Program Wave 1"
    } | null,

    // Active paid subscription reference
    active_subscription_id: "sub_xxx" | null,

    // Cached limits (denormalized for fast access)
    effective_limits: {
      snap_solve_daily: 3,
      daily_quiz_daily: 1,
      ai_tutor_enabled: false
    },

    // Last sync timestamp
    last_synced: Timestamp
  },

  // NEW: Daily usage tracking
  daily_usage: {
    snap_solve_count: 0,
    daily_quiz_count: 0,
    ai_tutor_message_count: 0,
    last_reset: Timestamp  // Midnight IST
  },

  // Existing trial fields (keep as-is)
  trial: {
    started_at: Timestamp | null,
    ends_at: Timestamp | null,
    is_used: boolean
  }
}
```

### 3. Subscriptions Subcollection

**Path**: `users/{userId}/subscriptions/{subscriptionId}`

```javascript
{
  subscription_id: "sub_xxx",
  tier_id: "pro",
  plan_type: "quarterly",
  status: "active" | "expired" | "cancelled" | "pending_payment",

  // Pricing
  amount_paid: 74700,  // In paise
  currency: "INR",

  // Lifecycle
  created_at: Timestamp,
  start_date: Timestamp,
  end_date: Timestamp,
  cancelled_at: Timestamp | null,
  auto_renew: false,

  // Razorpay
  razorpay_order_id: "order_xxx",
  payment_id: "pay_xxx",
  payment_status: "success",
  payment_method: "upi"
}
```

---

## Core Logic: Effective Tier Calculation

The `getEffectiveTier()` function determines a user's current tier with this priority:

```
1. Override (beta tester, promotional) - Highest priority
2. Active paid subscription
3. Active trial
4. Default to FREE - Lowest priority
```

```javascript
async function getEffectiveTier(userId) {
  const user = await db.collection('users').doc(userId).get();
  const userData = user.data();
  const now = new Date();

  // 1. Check override (beta testers take priority)
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

  // 3. Check active trial
  if (userData.trial?.ends_at && userData.trial.ends_at.toDate() > now) {
    return {
      tier: 'pro',  // Trial grants Pro access
      source: 'trial',
      expires_at: userData.trial.ends_at
    };
  }

  // 4. Default to free
  return {
    tier: 'free',
    source: 'default',
    expires_at: null
  };
}
```

---

## Feature Gating Implementation

### Solutions (No Gating)

**All tiers receive full step-by-step solutions.** We don't gate solution quality because:
- Students learn best with complete explanations
- Partial solutions create frustration, not conversion
- The value proposition is usage limits, not quality limits

### Analytics Gating

Free tier sees basic stats only. Pro/Ultra see full analytics.

```javascript
// Backend: In analytics route
async function getAnalyticsResponse(userId, tierConfig) {
  const analyticsAccess = tierConfig.features.analytics_access;

  if (analyticsAccess === 'basic') {
    // FREE tier: Basic stats only
    const userData = await getUser(userId);
    return {
      basic_stats: {
        streak: userData.streak || 0,
        total_questions_solved: userData.total_questions_solved || 0,
        total_quizzes_completed: userData.completed_quiz_count || 0
      },
      upgrade_prompt: {
        message: "Upgrade to Pro for detailed analytics and insights",
        cta_text: "Unlock Full Analytics"
      }
    };
  }

  // PRO/ULTRA: Full analytics
  return await analyticsService.getAnalyticsOverview(userId);
}
```

### Usage Limit Enforcement

```javascript
// Backend middleware
function checkUsageLimit(usageType) {
  return async (req, res, next) => {
    const userId = req.userId;
    const tierInfo = await getEffectiveTier(userId);
    const tierConfig = await getTierConfig(tierInfo.tier);
    const limit = tierConfig.limits[`${usageType}_daily`];

    // -1 means unlimited
    if (limit === -1) {
      await incrementUsageCounter(userId, usageType);
      return next();
    }

    const currentUsage = await getDailyUsage(userId, usageType);

    if (currentUsage >= limit) {
      return res.status(429).json({
        success: false,
        error: `Daily limit of ${limit} reached`,
        code: 'LIMIT_REACHED',
        usage: {
          used: currentUsage,
          limit: limit,
          remaining: 0,
          resets_at: getNextMidnightIST()
        }
      });
    }

    await incrementUsageCounter(userId, usageType);
    next();
  };
}
```

---

## Admin Management via Firebase Console

### Why Firebase Console?

- **Zero development effort** - Works immediately
- **Secure** - Uses Firebase Auth, role-based access
- **Audit trail** - Firestore automatically logs changes
- **Real-time** - Changes take effect within 5 minutes (cache TTL)

### How to Update Tier Configuration

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select JEEVibe project
3. Navigate to **Firestore Database**
4. Find document: `tier_config/active`
5. Edit the tier you want to modify
6. Save changes

**Example: Change Free tier snap limit from 3 to 5**
```
tier_config/active → tiers → free → limits → snap_solve_daily: 5
```

### How to Grant Beta Access

1. Go to Firebase Console → Firestore
2. Find the user: `users/{userId}`
3. Add/update the `subscription.override` field:

```javascript
{
  subscription: {
    // ... existing fields ...
    override: {
      type: "beta_tester",
      tier_id: "ultra",
      granted_by: "your_admin_uid",
      granted_at: Timestamp.now(),
      expires_at: Timestamp.fromDate(new Date('2026-04-14')),  // 90 days
      reason: "Beta Program Wave 1"
    }
  }
}
```

### How to Revoke Beta Access

Set `override` to `null`:
```javascript
{
  subscription: {
    override: null
  }
}
```

### Bulk Operations

For granting beta access to multiple users, use a simple Node.js script:

```javascript
// scripts/grant_beta_access.js
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

const betaUserIds = [
  'user_id_1',
  'user_id_2',
  // ... more user IDs
];

const expiresAt = new Date('2026-04-14');

async function grantBetaAccess() {
  const batch = db.batch();

  for (const userId of betaUserIds) {
    const userRef = db.collection('users').doc(userId);
    batch.update(userRef, {
      'subscription.override': {
        type: 'beta_tester',
        tier_id: 'ultra',
        granted_by: 'admin_script',
        granted_at: admin.firestore.FieldValue.serverTimestamp(),
        expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
        reason: 'Beta Program Wave 1'
      }
    });
  }

  await batch.commit();
  console.log(`Granted beta access to ${betaUserIds.length} users`);
}

grantBetaAccess();
```

---

## Backend Implementation Summary

### New Files to Create

| File | Purpose |
|------|---------|
| `backend/src/services/tierConfigService.js` | Fetch/cache tier config from Firestore |
| `backend/src/services/subscriptionService.js` | Core subscription logic (getEffectiveTier, etc.) |
| `backend/src/services/usageTrackingService.js` | Daily usage limit tracking |
| `backend/src/services/paymentService.js` | Razorpay integration |
| `backend/src/middleware/featureGate.js` | Feature access middleware |
| `backend/src/routes/subscriptions.js` | Subscription API endpoints |
| `backend/src/routes/webhooks.js` | Razorpay webhook handler |

### Files to Modify

| File | Changes |
|------|---------|
| `backend/src/routes/solve.js` | Add usage limit middleware, tier-based response |
| `backend/src/routes/dailyQuiz.js` | Add usage limit middleware |
| `backend/src/routes/analytics.js` | Gate full analytics by tier |
| `backend/src/index.js` | Register new routes |

---

## Mobile Implementation Summary

### New Files to Create

| File | Purpose |
|------|---------|
| `mobile/lib/services/subscription_service.dart` | Subscription state management |
| `mobile/lib/models/subscription_models.dart` | Data models |
| `mobile/lib/screens/subscription/paywall_screen.dart` | Paywall UI |
| `mobile/lib/screens/subscription/payment_webview_screen.dart` | Razorpay WebView |
| `mobile/lib/screens/subscription/subscription_settings_screen.dart` | Manage subscription |

### Files to Modify

| File | Changes |
|------|---------|
| `mobile/lib/screens/solution_screen.dart` | Show approach-only for free tier |
| `mobile/lib/screens/analytics_screen.dart` | Basic vs full analytics view |
| `mobile/lib/screens/home_screen.dart` | Gate snap capture by usage limit |
| `mobile/lib/screens/daily_quiz_home_screen.dart` | Gate quiz generation |

---

## Implementation Phases

### Phase 1: Database & Core Services (Week 1)
- [ ] Create `tier_config/active` document in Firestore
- [ ] Implement `tierConfigService.js` with 5-minute cache
- [ ] Implement `subscriptionService.js` with `getEffectiveTier()`
- [ ] Implement `usageTrackingService.js`
- [ ] Add subscription fields to user documents

### Phase 2: Backend Feature Gating (Week 2)
- [ ] Create `featureGate.js` middleware
- [ ] Modify `solve.js` for usage limits + tier-based response
- [ ] Modify `dailyQuiz.js` for usage limits
- [ ] Modify `analytics.js` for basic vs full gating
- [ ] Create subscription API routes

### Phase 3: Payment Integration (Week 3)
- [ ] Set up Razorpay test account
- [ ] Implement `paymentService.js`
- [ ] Create webhook handler
- [ ] Build web payment pages
- [ ] Test payment flow in sandbox

### Phase 4: Mobile Implementation (Week 4)
- [ ] Create subscription service and models
- [ ] Build paywall screens
- [ ] Add gating to existing screens
- [ ] Implement payment WebView
- [ ] Test on Android and iOS

### Phase 5: Beta & Launch (Week 5)
- [ ] Grant beta testers Ultra access via Firebase Console
- [ ] Production Razorpay setup
- [ ] Final testing
- [ ] Launch Free + Pro publicly

---

## Testing Checklist

### Unit Tests
- [ ] `getEffectiveTier()` returns correct tier for: free, pro, ultra, trial, override
- [ ] Usage limits enforced correctly per tier
- [ ] Override takes priority over subscription
- [ ] Expired override falls back to subscription or free

### Integration Tests
- [ ] Payment flow works end-to-end in Razorpay sandbox
- [ ] Subscription activates after successful payment
- [ ] Usage counters reset at midnight IST

### Manual Testing
- [ ] Free user hits 3 snap limit → paywall shown
- [ ] Pro user can take 10 snaps
- [ ] All users see full step-by-step solutions (no gating)
- [ ] Free user sees basic analytics (streak, total)
- [ ] Pro user sees full analytics
- [ ] Beta tester gets Ultra access via override
- [ ] Expired subscription reverts to free tier
- [ ] Tier config changes in Firestore reflect within 5 minutes

---

## Future Enhancements

When ready, these can be added without major refactoring:

1. **Admin API Endpoints** - For programmatic tier management
2. **Admin Dashboard** - When non-technical team needs UI access
3. **Referral System** - Discounts for referrals
4. **Promo Codes** - Time-limited discounts
5. **Auto-Renewal** - Via Razorpay Subscriptions API
6. **Ultra Public Launch** - Set `is_purchasable: true` in Firestore

---

## Related Documents

- [PAYWALL-SYSTEM-DESIGN.md](./PAYWALL-SYSTEM-DESIGN.md) - Detailed payment flow, UI screens, web page design
- Paywall UI Mockups: `/inputs/paywall/`
