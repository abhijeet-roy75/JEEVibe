# Tier System Architecture

> **Companion document to**: [PAYWALL-SYSTEM-DESIGN.md](./PAYWALL-SYSTEM-DESIGN.md)
>
> **Status**: ✅ **IMPLEMENTED** - Live in Production
>
> **Last Updated**: 2026-01-18

## Overview

This document describes the **3-tier subscription system** (FREE, PRO, ULTRA) with flexible, Firestore-driven configuration.

**Key Architectural Decisions**:
1. **Firestore-driven tier config** - All tier definitions stored in Firestore with 5-minute cache
2. **All 3 tiers publicly available** - Free, Pro, and Ultra are all purchasable
3. **Admin override system** - Beta testers and promotional grants via admin API
4. **IST timezone for daily resets** - Usage counters reset at midnight IST (UTC+5:30)

---

## Tier Feature Matrix

### Current Features

| Feature | FREE | PRO | ULTRA |
|---------|------|-----|-------|
| **Snap & Solve** | 5/day | 10/day | Unlimited |
| **Practice after Snap & Solve** | ❌ | 3/snap | 3/snap |
| **Daily Quiz** | 1/day | 10/day | Unlimited |
| **Chapter Practice** | 1 chapter/subject/week | Unlimited | Unlimited |
| **Chapter Selection for Practice** | Fixed | Full Repository | Full Repository |
| **Solution History** | Last 7 days | Last 30 days | Unlimited |
| **Analytics** | Basic (streak, total) | Full access | Full access |
| **AI Tutor (Priya Ma'am)** | ❌ | ❌ | ✅ Unlimited |
| **Offline Mode** | ❌ | ✅ Yes | ✅ Yes |

> **Note**: All tiers receive full step-by-step solutions. We don't gate solution quality.

### Future Features (Roadmap)

| Feature | FREE | PRO | ULTRA |
|---------|------|-----|-------|
| **Full Mock Tests** | 1/month | 5/month | Unlimited |
| **PYQ Bank** | Last 2 years | Last 5 years | All years (10+) |
| **Video Lessons** | ❌ | ❌ | ✅ Unlimited |

### Pricing

#### Pro Tier

| Plan | Price | Per Month | Savings | Badge |
|------|-------|-----------|---------|-------|
| Monthly | ₹299 | ₹299 | - | - |
| Quarterly | ₹747 | ₹249 | 17% | MOST POPULAR |
| Annual | ₹2,388 | ₹199 | 33% | SAVE 33% |

#### Ultra Tier

| Plan | Price | Per Month | Savings | Badge |
|------|-------|-----------|---------|-------|
| Monthly | ₹499 | ₹499 | - | - |
| Quarterly | ₹1,197 | ₹399 | 20% | MOST POPULAR |
| Annual | ₹3,588 | ₹299 | 40% | BEST VALUE |

---

## Feature Descriptions

### Built Features (✅)

| Feature | Description | Gating |
|---------|-------------|--------|
| **Snap & Solve** | Take photo of question, get AI-generated solution with steps | Daily limit per tier |
| **Practice after Snap & Solve** | AI-generated questions to solidify knowledge of area, additional practise for target area | Pro/Ultra only |
| **Daily Quiz** | Adaptive quiz using IRT algorithm, personalized difficulty | Daily limit per tier |
| **Solutions** | Full step-by-step explanations with approach, steps, final answer | No gating (full for all) |
| **Analytics** | Performance tracking, theta scores, mastery levels, focus areas | Basic (free) vs Full (pro+) |
| **Solution History** | View past snapped questions and solutions | Days limit per tier |
| **AI Tutor (Priya Ma'am)** | Chatbot for doubt resolution, concept learning, personalized coaching | Ultra only |
| **Chapter Practice** | Topic-wise problem sets organized by JEE syllabus | Per-chapter limit + weekly cooldown (free) |
| **Chapter Selection for Practice** | Chapters to practise for, from JEE syllabus | Fixed for free, full repository for Pro/Ultra |
| **Offline Mode** | Download solutions for offline viewing. Sync when back online. | Pro/Ultra only |

### Future Features (🔮 Roadmap)

| Feature | Description | Gating Strategy |
|---------|-------------|-----------------|
| **Full Mock Tests** | Complete JEE Main (3hr, 90Q) and JEE Advanced (6hr, 54Q) mock tests with timer, marking scheme, analysis. | Limit tests per month |
| **PYQ Bank** | Previous Year Questions from JEE Main/Advanced (2010-2025+) with solutions, filters by year/chapter/difficulty. | Limit years accessible |
| **Video Lessons** | Curated video explanations for concepts, problem-solving techniques, and chapter summaries. | Ultra only |

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
        // Core features
        snap_solve_daily: 5,
        daily_quiz_daily: 1,
        solution_history_days: 7,

        // AI features
        ai_tutor_enabled: false,
        ai_tutor_messages_daily: 0,

        // Chapter Practice (with weekly cooldown)
        chapter_practice_enabled: true,
        chapter_practice_per_chapter: 15,
        chapter_practice_weekly_per_subject: 1,  // 1 chapter per subject per week (7-day cooldown)

        // Future features
        mock_tests_monthly: 1,
        pyq_years_access: 2,
        offline_enabled: false,
        offline_solutions_limit: 0
      },

      features: {
        analytics_access: "basic"  // "basic" | "full"
      },

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
      is_purchasable: true,

      limits: {
        // Core features
        snap_solve_daily: 10,
        daily_quiz_daily: 10,
        solution_history_days: 30,

        // AI features
        ai_tutor_enabled: false,
        ai_tutor_messages_daily: 0,

        // Chapter Practice (no weekly limit)
        chapter_practice_enabled: true,
        chapter_practice_per_chapter: 20,
        chapter_practice_weekly_per_subject: -1,  // Unlimited

        // Future features
        mock_tests_monthly: 5,
        pyq_years_access: 5,
        offline_enabled: true,
        offline_solutions_limit: -1
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
      is_purchasable: true,  // Now publicly available

      limits: {
        // Core features - All unlimited
        snap_solve_daily: -1,
        daily_quiz_daily: -1,
        solution_history_days: -1,

        // AI features - Enabled
        ai_tutor_enabled: true,
        ai_tutor_messages_daily: -1,

        // Chapter Practice - Unlimited
        chapter_practice_enabled: true,
        chapter_practice_per_chapter: -1,
        chapter_practice_weekly_per_subject: -1,

        // Future features - All unlimited
        mock_tests_monthly: -1,
        pyq_years_access: -1,
        offline_enabled: true,
        offline_solutions_limit: -1
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

      pricing: {
        monthly: {
          price: 49900,
          display_price: "499",
          per_month_price: "499",
          duration_days: 30,
          savings_percent: 0,
          badge: null
        },
        quarterly: {
          price: 119700,
          display_price: "1,197",
          per_month_price: "399",
          duration_days: 90,
          savings_percent: 20,
          badge: "MOST POPULAR"
        },
        annual: {
          price: 358800,
          display_price: "3,588",
          per_month_price: "299",
          duration_days: 365,
          savings_percent: 40,
          badge: "BEST VALUE"
        }
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

### Gating Overview

| Feature | Middleware | Limit Key | Error Code |
|---------|------------|-----------|------------|
| Snap & Solve | `checkUsageLimit('snap_solve')` | `snap_solve_daily` | `LIMIT_REACHED` |
| Daily Quiz | `checkUsageLimit('daily_quiz')` | `daily_quiz_daily` | `LIMIT_REACHED` |
| AI Tutor | `requireFeature('ai_tutor_enabled')` + `checkUsageLimit('ai_tutor')` | `ai_tutor_messages_daily` | `FEATURE_NOT_AVAILABLE` |
| Chapter Practice | Custom weekly check | `chapter_practice_weekly_per_subject` | `WEEKLY_LIMIT_REACHED` |
| Analytics | Route-level check | `analytics_access` | N/A (returns basic data) |
| Offline Mode | `requireFeature('offline_enabled')` | `offline_enabled` | `FEATURE_NOT_AVAILABLE` |

### Solutions (No Gating)

**All tiers receive full step-by-step solutions.** We don't gate solution quality because:
- Students learn best with complete explanations
- Partial solutions create frustration, not conversion
- The value proposition is usage limits, not quality limits

### Chapter Practice Weekly Limits (Free Tier)

Free tier users can only practice **1 chapter per subject per week** (7-day cooldown). This is tracked in Firestore:

**Storage**: `users/{userId}/chapter_practice_weekly/{subject}`

```javascript
{
  last_chapter_key: "physics_mechanics_kinematics",
  last_chapter_name: "Kinematics",
  last_completed_at: Timestamp,
  expires_at: Timestamp  // 7 days after last_completed_at
}
```

**Behavior**:
- After completing a chapter practice session, the subject is locked for 7 days
- User can practice different subjects (e.g., Physics locked, but Chemistry available)
- Pro/Ultra users have no weekly restriction (`chapter_practice_weekly_per_subject: -1`)

### AI Tutor Feature Gate

AI Tutor requires **Ultra tier** (`ai_tutor_enabled: true`). The feature gate checks both:
1. Feature enabled (`requireFeature('ai_tutor_enabled')`)
2. Daily message limit (`checkUsageLimit('ai_tutor')`)

### Offline Mode Feature Gate

Offline Mode requires **Pro or Ultra tier** (`offline_enabled: true`). This allows users to:
- Download solutions for offline viewing
- Access previously viewed content without internet
- Sync changes when back online

Free tier users see an upgrade prompt when trying to access offline features.

### Analytics Gating

Free tier sees basic stats only. Pro/Ultra see full analytics.

```javascript
// Backend: In analytics route
async function getAnalyticsResponse(userId, tierConfig) {
  const analyticsAccess = tierConfig.features.analytics_access;

  if (analyticsAccess === 'basic') {
    // FREE tier: Basic stats only
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

Daily usage resets at **midnight IST (UTC+5:30)**.

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
        error: `Daily limit of ${limit} reached for ${usageType}`,
        code: 'LIMIT_REACHED',
        usage: {
          type: usageType,
          used: currentUsage,
          limit: limit,
          remaining: 0,
          resets_at: getNextMidnightIST()
        },
        upgrade: {
          message: `Upgrade to ${getNextTier(tierInfo.tier)} for more daily usage`,
          current_tier: tierInfo.tier
        }
      });
    }

    await incrementUsageCounter(userId, usageType);
    next();
  };
}
```

### Feature Not Available Response

```javascript
// When feature is disabled for tier (e.g., AI Tutor for Free/Pro)
{
  success: false,
  error: "ai_tutor_enabled is not available on your current plan",
  code: "FEATURE_NOT_AVAILABLE",
  current_tier: "free",
  required_tier: "ultra"
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

### Implemented Services

| File | Purpose | Status |
|------|---------|--------|
| `backend/src/services/tierConfigService.js` | Fetch/cache tier config from Firestore (5-min cache) | ✅ Implemented |
| `backend/src/services/subscriptionService.js` | Core subscription logic (getEffectiveTier, tier caching) | ✅ Implemented |
| `backend/src/services/usageTrackingService.js` | Daily usage tracking with IST timezone handling | ✅ Implemented |
| `backend/src/services/weeklyChapterPracticeService.js` | Weekly chapter practice limits (free tier) | ✅ Implemented |
| `backend/src/middleware/featureGate.js` | Feature access middleware (requireFeature, checkUsageLimit) | ✅ Implemented |
| `backend/src/routes/subscriptions.js` | Subscription status, plans, admin overrides | ✅ Implemented |
| `backend/src/routes/aiTutor.js` | AI Tutor routes with Ultra-only gating | ✅ Implemented |
| `backend/src/routes/chapterPractice.js` | Chapter practice with weekly limits | ✅ Implemented |

### Routes with Feature Gating

| Route | Middleware | Description |
|-------|------------|-------------|
| `POST /api/solve` | `checkUsageLimit('snap_solve')` | Snap & Solve with daily limit |
| `GET /api/daily-quiz/generate` | `checkUsageLimit('daily_quiz')` | Daily Quiz generation with limit |
| `GET /api/ai-tutor/conversation` | `requireFeature('ai_tutor_enabled')` | AI Tutor (Ultra only) |
| `POST /api/ai-tutor/message` | `requireFeature('ai_tutor_enabled')` + `checkUsageLimit('ai_tutor')` | AI Tutor messages |
| `POST /api/ai-tutor/inject-context` | `requireFeature('ai_tutor_enabled')` + `checkUsageLimit('ai_tutor')` | AI Tutor context injection |
| `POST /api/chapter-practice/generate` | Custom weekly limit check | Chapter practice with weekly cooldown |

### Future Files to Create

| File | Purpose | Status |
|------|---------|--------|
| `backend/src/services/paymentService.js` | Razorpay integration | 🔮 Future |
| `backend/src/routes/webhooks.js` | Razorpay webhook handler | 🔮 Future |

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

### Phase 1: Database & Core Services ✅ COMPLETE
- [x] Create `tier_config/active` document in Firestore
- [x] Implement `tierConfigService.js` with 5-minute cache
- [x] Implement `subscriptionService.js` with `getEffectiveTier()`
- [x] Implement `usageTrackingService.js` with IST timezone
- [x] Add subscription fields to user documents

### Phase 2: Backend Feature Gating ✅ COMPLETE
- [x] Create `featureGate.js` middleware
- [x] Modify `solve.js` for usage limits
- [x] Modify `dailyQuiz.js` for usage limits
- [x] Create subscription API routes
- [x] Implement AI Tutor routes with Ultra-only gating
- [x] Implement Chapter Practice with weekly limits

### Phase 3: Payment Integration 🔮 FUTURE
- [ ] Set up Razorpay test account
- [ ] Implement `paymentService.js`
- [ ] Create webhook handler
- [ ] Build web payment pages
- [ ] Test payment flow in sandbox

### Phase 4: Mobile Implementation 📋 IN PROGRESS
- [x] Create subscription service and models
- [x] Add gating to existing screens
- [ ] Build paywall screens
- [ ] Implement payment WebView
- [ ] Test on Android and iOS

### Phase 5: Beta & Launch ✅ COMPLETE
- [x] Grant beta testers Ultra access via admin API
- [x] All 3 tiers publicly available
- [x] Admin override system working

---

## Testing Checklist

### Unit Tests ✅
- [x] `getEffectiveTier()` returns correct tier for: free, pro, ultra, trial, override
- [x] Usage limits enforced correctly per tier
- [x] Override takes priority over subscription
- [x] Expired override falls back to subscription or free

### Integration Tests
- [ ] Payment flow works end-to-end in Razorpay sandbox
- [ ] Subscription activates after successful payment
- [x] Usage counters reset at midnight IST

### Manual Testing ✅
- [x] Free user hits 5 snap limit → upgrade prompt shown
- [x] Pro user can take 10 snaps
- [x] Ultra user has unlimited snaps
- [x] All users see full step-by-step solutions (no gating)
- [x] Free user sees basic analytics (streak, total)
- [x] Pro/Ultra user sees full analytics
- [x] Beta tester gets Ultra access via admin override
- [x] AI Tutor only available for Ultra tier
- [x] Chapter Practice weekly limit works for Free tier (7-day cooldown)
- [x] Pro/Ultra users have no chapter practice weekly limit
- [x] Offline Mode available for Pro/Ultra only
- [x] Free user sees upgrade prompt for Offline Mode
- [x] Tier config changes in Firestore reflect within 5 minutes (cache TTL)

---

## Future Enhancements

Completed:
- ✅ **Admin API Endpoints** - `/api/subscriptions/admin/*` for grant/revoke overrides
- ✅ **Ultra Public Launch** - Now purchasable

Planned:
1. **Payment Integration** - Razorpay for subscription purchases
2. **Admin Dashboard** - When non-technical team needs UI access
3. **Referral System** - Discounts for referrals
4. **Promo Codes** - Time-limited discounts
5. **Auto-Renewal** - Via Razorpay Subscriptions API

---

## Related Documents

- [PAYWALL-SYSTEM-DESIGN.md](./PAYWALL-SYSTEM-DESIGN.md) - Detailed payment flow, UI screens, web page design
- Paywall UI Mockups: `/inputs/paywall/`
