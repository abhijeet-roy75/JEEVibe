# Promo & Referral Code System

> **Status**: Pending Implementation
>
> **Priority**: HIGH (Pre-Launch)
>
> **Created**: 2026-01-23
>
> **Related**: [GTM-EXECUTION-PLAN.md](../09-business/GTM-EXECUTION-PLAN.md), [TRIAL-FIRST-IMPLEMENTATION.md](./TRIAL-FIRST-IMPLEMENTATION.md)

## Overview

Two distinct code types with different purposes:

| Type | Purpose | Example | Who Creates |
|------|---------|---------|-------------|
| **Promo Code** | Marketing campaigns, influencers, coaching partners | `KOTA50`, `PHYSICS20` | Admin |
| **Referral Code** | User-to-user viral growth | `RAHUL123` | Auto-generated per user |

---

## Database Schema

### 1. Promo Codes Collection

**Path**: `promo_codes/{code}`

```javascript
{
  // Code identifier (uppercase, alphanumeric)
  code: "KOTA50",

  // Code type
  type: "percentage" | "fixed" | "trial_extension" | "bonus_snaps",

  // Discount details (depends on type)
  discount: {
    percentage: 50,           // For type: "percentage" (50% off)
    fixed_amount: 100,        // For type: "fixed" (₹100 off)
    trial_days: 14,           // For type: "trial_extension" (+14 days trial)
    bonus_snaps: 10,          // For type: "bonus_snaps" (+10 snaps for 7 days)
    bonus_duration_days: 7    // How long bonus lasts
  },

  // Applicability
  applies_to: {
    tiers: ["pro", "ultra"],  // Which tiers (empty = all)
    plans: ["quarterly", "annual"],  // Which billing cycles (empty = all)
    new_users_only: true,     // First purchase only?
    min_purchase: 0           // Minimum cart value (₹)
  },

  // Limits
  limits: {
    max_uses: 1000,           // Total redemptions allowed (-1 = unlimited)
    max_uses_per_user: 1,     // Per user limit
    current_uses: 42          // Counter
  },

  // Validity
  validity: {
    starts_at: Timestamp,
    expires_at: Timestamp,
    is_active: true
  },

  // Attribution
  attribution: {
    source: "influencer",     // "influencer" | "coaching" | "campaign" | "internal"
    partner_id: "physics_wallah_guy",
    partner_name: "Alakh Pandey",
    revenue_share_percent: 20  // If partner gets commission
  },

  // Metadata
  created_at: Timestamp,
  created_by: "admin_user_id",
  notes: "Summer campaign for Kota students"
}
```

### 2. Referral Codes Collection

**Path**: `referral_codes/{code}`

```javascript
{
  // Code identifier (auto-generated or custom)
  code: "RAHUL123",

  // Owner
  owner_user_id: "user_abc123",
  owner_phone: "+919876543210",

  // Rewards
  rewards: {
    // What referrer gets
    referrer: {
      type: "bonus_snaps",
      bonus_snaps: 5,
      duration_days: 7
    },
    // What referee gets
    referee: {
      type: "discount",
      discount_amount: 50,     // ₹50 off first purchase
      bonus_snaps: 3,
      bonus_duration_days: 7
    }
  },

  // Stats
  stats: {
    total_referrals: 15,
    successful_conversions: 3,  // Referrals who paid
    total_earnings: 150         // If cash rewards enabled
  },

  // Limits
  limits: {
    max_referrals: -1,         // -1 = unlimited
    is_active: true
  },

  created_at: Timestamp
}
```

### 3. Redemptions Collection

**Path**: `code_redemptions/{redemptionId}`

```javascript
{
  // Reference
  redemption_id: "red_abc123",
  code: "KOTA50",
  code_type: "promo" | "referral",

  // User who redeemed
  user_id: "user_xyz789",
  user_phone: "+919876543210",

  // What was applied
  applied_to: {
    subscription_id: "sub_123",  // If discount on purchase
    tier: "pro",
    plan: "quarterly",
    original_price: 597,
    discount_amount: 298,
    final_price: 299
  },

  // For referral codes
  referral_info: {
    referrer_user_id: "user_abc123",
    referrer_rewarded: true,
    referrer_reward_type: "bonus_snaps"
  },

  // Timestamps
  redeemed_at: Timestamp,
  expires_at: Timestamp  // When the benefit expires
}
```

### 4. User Document Updates

**Path**: `users/{userId}`

```javascript
{
  // ... existing fields ...

  // User's own referral code
  referral: {
    code: "RAHUL123",
    created_at: Timestamp,
    total_referrals: 15,
    successful_conversions: 3
  },

  // Codes this user has used
  applied_codes: [
    {
      code: "KOTA50",
      type: "promo",
      applied_at: Timestamp,
      benefit: "50% off quarterly Pro"
    }
  ],

  // Who referred this user (if any)
  referred_by: {
    code: "RAHUL123",
    referrer_user_id: "user_abc123",
    applied_at: Timestamp
  },

  // Active bonuses
  bonuses: {
    snap_solve: {
      extra_daily: 5,
      expires_at: Timestamp,
      source: "referral_reward"
    }
  }
}
```

---

## Backend Implementation

### 1. Promo Code Service

**File**: `backend/src/services/promoCodeService.js`

```javascript
const admin = require('firebase-admin');
const db = admin.firestore();

/**
 * Validate a promo code
 */
async function validatePromoCode(code, userId, purchaseContext) {
  const codeUpper = code.toUpperCase().trim();
  const codeDoc = await db.collection('promo_codes').doc(codeUpper).get();

  if (!codeDoc.exists) {
    return { valid: false, error: 'Invalid promo code', code: 'INVALID_CODE' };
  }

  const promoCode = codeDoc.data();
  const now = new Date();

  // Check if active
  if (!promoCode.validity.is_active) {
    return { valid: false, error: 'This code is no longer active', code: 'INACTIVE' };
  }

  // Check expiry
  if (promoCode.validity.expires_at && promoCode.validity.expires_at.toDate() < now) {
    return { valid: false, error: 'This code has expired', code: 'EXPIRED' };
  }

  // Check start date
  if (promoCode.validity.starts_at && promoCode.validity.starts_at.toDate() > now) {
    return { valid: false, error: 'This code is not yet active', code: 'NOT_STARTED' };
  }

  // Check max uses
  if (promoCode.limits.max_uses !== -1 &&
      promoCode.limits.current_uses >= promoCode.limits.max_uses) {
    return { valid: false, error: 'This code has reached its usage limit', code: 'MAX_USES' };
  }

  // Check per-user limit
  const userRedemptions = await db.collection('code_redemptions')
    .where('code', '==', codeUpper)
    .where('user_id', '==', userId)
    .get();

  if (userRedemptions.size >= promoCode.limits.max_uses_per_user) {
    return { valid: false, error: 'You have already used this code', code: 'ALREADY_USED' };
  }

  // Check new users only
  if (promoCode.applies_to.new_users_only) {
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (userData.subscription?.active_subscription_id) {
      return { valid: false, error: 'This code is for new subscribers only', code: 'NOT_NEW_USER' };
    }
  }

  // Check tier applicability
  if (promoCode.applies_to.tiers.length > 0 &&
      !promoCode.applies_to.tiers.includes(purchaseContext.tier)) {
    return {
      valid: false,
      error: `This code only applies to ${promoCode.applies_to.tiers.join(', ')} plans`,
      code: 'WRONG_TIER'
    };
  }

  // Check plan applicability
  if (promoCode.applies_to.plans.length > 0 &&
      !promoCode.applies_to.plans.includes(purchaseContext.plan)) {
    return {
      valid: false,
      error: `This code only applies to ${promoCode.applies_to.plans.join(', ')} billing`,
      code: 'WRONG_PLAN'
    };
  }

  // Check minimum purchase
  if (purchaseContext.amount < promoCode.applies_to.min_purchase) {
    return {
      valid: false,
      error: `Minimum purchase of ₹${promoCode.applies_to.min_purchase} required`,
      code: 'MIN_PURCHASE'
    };
  }

  // Calculate discount
  const discount = calculateDiscount(promoCode, purchaseContext.amount);

  return {
    valid: true,
    code: codeUpper,
    type: promoCode.type,
    discount: discount,
    description: getDiscountDescription(promoCode)
  };
}

/**
 * Calculate discount amount
 */
function calculateDiscount(promoCode, originalAmount) {
  switch (promoCode.type) {
    case 'percentage':
      return Math.round(originalAmount * (promoCode.discount.percentage / 100));
    case 'fixed':
      return Math.min(promoCode.discount.fixed_amount, originalAmount);
    case 'trial_extension':
      return 0; // No monetary discount
    case 'bonus_snaps':
      return 0; // No monetary discount
    default:
      return 0;
  }
}

/**
 * Get human-readable description
 */
function getDiscountDescription(promoCode) {
  switch (promoCode.type) {
    case 'percentage':
      return `${promoCode.discount.percentage}% off`;
    case 'fixed':
      return `₹${promoCode.discount.fixed_amount} off`;
    case 'trial_extension':
      return `+${promoCode.discount.trial_days} days free trial`;
    case 'bonus_snaps':
      return `+${promoCode.discount.bonus_snaps} bonus snaps for ${promoCode.discount.bonus_duration_days} days`;
    default:
      return '';
  }
}

/**
 * Apply promo code after successful payment
 */
async function applyPromoCode(code, userId, subscriptionId, purchaseDetails) {
  const codeUpper = code.toUpperCase().trim();

  const batch = db.batch();

  // 1. Increment usage counter
  const codeRef = db.collection('promo_codes').doc(codeUpper);
  batch.update(codeRef, {
    'limits.current_uses': admin.firestore.FieldValue.increment(1)
  });

  // 2. Create redemption record
  const redemptionRef = db.collection('code_redemptions').doc();
  batch.set(redemptionRef, {
    redemption_id: redemptionRef.id,
    code: codeUpper,
    code_type: 'promo',
    user_id: userId,
    applied_to: {
      subscription_id: subscriptionId,
      tier: purchaseDetails.tier,
      plan: purchaseDetails.plan,
      original_price: purchaseDetails.originalPrice,
      discount_amount: purchaseDetails.discountAmount,
      final_price: purchaseDetails.finalPrice
    },
    redeemed_at: admin.firestore.FieldValue.serverTimestamp()
  });

  // 3. Update user's applied codes
  const userRef = db.collection('users').doc(userId);
  batch.update(userRef, {
    applied_codes: admin.firestore.FieldValue.arrayUnion({
      code: codeUpper,
      type: 'promo',
      applied_at: new Date(),
      benefit: purchaseDetails.benefitDescription
    })
  });

  await batch.commit();

  // 4. Apply non-monetary benefits (trial extension, bonus snaps)
  const promoDoc = await codeRef.get();
  const promoCode = promoDoc.data();

  if (promoCode.type === 'trial_extension') {
    await extendTrial(userId, promoCode.discount.trial_days);
  } else if (promoCode.type === 'bonus_snaps') {
    await addBonusSnaps(userId, promoCode.discount.bonus_snaps, promoCode.discount.bonus_duration_days);
  }

  // 5. Log analytics
  await logEvent(userId, 'promo_code_applied', {
    code: codeUpper,
    type: promoCode.type,
    discount_amount: purchaseDetails.discountAmount,
    source: promoCode.attribution?.source
  });

  return { success: true, redemption_id: redemptionRef.id };
}

module.exports = {
  validatePromoCode,
  applyPromoCode,
  calculateDiscount,
  getDiscountDescription
};
```

### 2. Referral Code Service

**File**: `backend/src/services/referralService.js`

```javascript
const admin = require('firebase-admin');
const db = admin.firestore();

/**
 * Generate a unique referral code for a user
 */
async function generateReferralCode(userId) {
  const userDoc = await db.collection('users').doc(userId).get();
  const userData = userDoc.data();

  // If user already has a code, return it
  if (userData.referral?.code) {
    return userData.referral.code;
  }

  // Generate code from name or phone
  let baseCode = '';
  if (userData.firstName) {
    baseCode = userData.firstName.toUpperCase().slice(0, 6);
  } else if (userData.phone) {
    baseCode = 'JEE' + userData.phone.slice(-4);
  } else {
    baseCode = 'REF';
  }

  // Add random suffix to ensure uniqueness
  let code = baseCode + Math.random().toString(36).substring(2, 5).toUpperCase();

  // Check for collision
  let attempts = 0;
  while (attempts < 10) {
    const existing = await db.collection('referral_codes').doc(code).get();
    if (!existing.exists) break;
    code = baseCode + Math.random().toString(36).substring(2, 5).toUpperCase();
    attempts++;
  }

  // Create referral code document
  const batch = db.batch();

  const codeRef = db.collection('referral_codes').doc(code);
  batch.set(codeRef, {
    code: code,
    owner_user_id: userId,
    owner_phone: userData.phone,
    rewards: {
      referrer: {
        type: 'bonus_snaps',
        bonus_snaps: 5,
        duration_days: 7
      },
      referee: {
        type: 'discount',
        discount_amount: 50,
        bonus_snaps: 3,
        bonus_duration_days: 7
      }
    },
    stats: {
      total_referrals: 0,
      successful_conversions: 0,
      total_earnings: 0
    },
    limits: {
      max_referrals: -1,
      is_active: true
    },
    created_at: admin.firestore.FieldValue.serverTimestamp()
  });

  // Update user document
  const userRef = db.collection('users').doc(userId);
  batch.update(userRef, {
    'referral.code': code,
    'referral.created_at': admin.firestore.FieldValue.serverTimestamp(),
    'referral.total_referrals': 0,
    'referral.successful_conversions': 0
  });

  await batch.commit();

  return code;
}

/**
 * Apply referral code during signup
 */
async function applyReferralOnSignup(newUserId, referralCode) {
  const codeUpper = referralCode.toUpperCase().trim();
  const codeDoc = await db.collection('referral_codes').doc(codeUpper).get();

  if (!codeDoc.exists) {
    return { success: false, error: 'Invalid referral code' };
  }

  const referral = codeDoc.data();

  // Can't refer yourself
  if (referral.owner_user_id === newUserId) {
    return { success: false, error: 'Cannot use your own referral code' };
  }

  // Check if code is active
  if (!referral.limits.is_active) {
    return { success: false, error: 'This referral code is no longer active' };
  }

  const batch = db.batch();

  // 1. Update new user with referral info
  const newUserRef = db.collection('users').doc(newUserId);
  batch.update(newUserRef, {
    referred_by: {
      code: codeUpper,
      referrer_user_id: referral.owner_user_id,
      applied_at: admin.firestore.FieldValue.serverTimestamp()
    }
  });

  // 2. Give referee their bonus snaps
  if (referral.rewards.referee.bonus_snaps > 0) {
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + referral.rewards.referee.bonus_duration_days);

    batch.update(newUserRef, {
      'bonuses.snap_solve': {
        extra_daily: referral.rewards.referee.bonus_snaps,
        expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
        source: 'referral_signup'
      }
    });
  }

  // 3. Increment referral stats
  const codeRef = db.collection('referral_codes').doc(codeUpper);
  batch.update(codeRef, {
    'stats.total_referrals': admin.firestore.FieldValue.increment(1)
  });

  // 4. Update referrer's stats
  const referrerRef = db.collection('users').doc(referral.owner_user_id);
  batch.update(referrerRef, {
    'referral.total_referrals': admin.firestore.FieldValue.increment(1)
  });

  await batch.commit();

  // 5. Give referrer their reward
  await rewardReferrer(referral.owner_user_id, referral.rewards.referrer, newUserId);

  // 6. Log analytics
  await logEvent(newUserId, 'referral_code_applied', {
    code: codeUpper,
    referrer_user_id: referral.owner_user_id
  });

  return {
    success: true,
    bonus_snaps: referral.rewards.referee.bonus_snaps,
    discount_on_purchase: referral.rewards.referee.discount_amount
  };
}

/**
 * Reward referrer when referee signs up
 */
async function rewardReferrer(referrerId, reward, refereeId) {
  if (reward.type === 'bonus_snaps' && reward.bonus_snaps > 0) {
    await addBonusSnaps(referrerId, reward.bonus_snaps, reward.duration_days);

    // Send push notification to referrer
    await sendPushNotification(referrerId, {
      title: 'Your friend joined JEEVibe!',
      body: `You earned +${reward.bonus_snaps} bonus snaps for 7 days!`,
      data: { action: 'REFERRAL_REWARD', referee_id: refereeId }
    });
  }
}

/**
 * Handle referral conversion (referee makes first payment)
 */
async function handleReferralConversion(userId, subscriptionId) {
  const userDoc = await db.collection('users').doc(userId).get();
  const userData = userDoc.data();

  if (!userData.referred_by?.code) {
    return; // Not a referred user
  }

  const batch = db.batch();

  // 1. Update referral code stats
  const codeRef = db.collection('referral_codes').doc(userData.referred_by.code);
  batch.update(codeRef, {
    'stats.successful_conversions': admin.firestore.FieldValue.increment(1)
  });

  // 2. Update referrer stats
  const referrerRef = db.collection('users').doc(userData.referred_by.referrer_user_id);
  batch.update(referrerRef, {
    'referral.successful_conversions': admin.firestore.FieldValue.increment(1)
  });

  // 3. Create conversion record
  const redemptionRef = db.collection('code_redemptions').doc();
  batch.set(redemptionRef, {
    redemption_id: redemptionRef.id,
    code: userData.referred_by.code,
    code_type: 'referral',
    user_id: userId,
    referral_info: {
      referrer_user_id: userData.referred_by.referrer_user_id,
      referrer_rewarded: true,
      conversion_type: 'first_payment'
    },
    redeemed_at: admin.firestore.FieldValue.serverTimestamp()
  });

  await batch.commit();

  // 4. Check for streak bonus (3 successful referrals = 1 week Pro free)
  const referrerDoc = await referrerRef.get();
  const referrerData = referrerDoc.data();

  if (referrerData.referral.successful_conversions === 3) {
    await grantProWeekFree(userData.referred_by.referrer_user_id);

    await sendPushNotification(userData.referred_by.referrer_user_id, {
      title: 'Streak Bonus Unlocked!',
      body: '3 friends converted! You got 1 week of Pro FREE!',
      data: { action: 'STREAK_BONUS' }
    });
  }

  // 5. Log analytics
  await logEvent(userId, 'referral_converted', {
    code: userData.referred_by.code,
    referrer_user_id: userData.referred_by.referrer_user_id,
    subscription_id: subscriptionId
  });
}

/**
 * Get user's referral stats
 */
async function getReferralStats(userId) {
  const userDoc = await db.collection('users').doc(userId).get();
  const userData = userDoc.data();

  if (!userData.referral?.code) {
    // Generate code if doesn't exist
    const code = await generateReferralCode(userId);
    return {
      code: code,
      total_referrals: 0,
      successful_conversions: 0,
      pending_rewards: 0
    };
  }

  const codeDoc = await db.collection('referral_codes').doc(userData.referral.code).get();
  const codeData = codeDoc.data();

  return {
    code: userData.referral.code,
    total_referrals: codeData.stats.total_referrals,
    successful_conversions: codeData.stats.successful_conversions,
    pending_rewards: codeData.stats.total_referrals - codeData.stats.successful_conversions,
    share_url: `https://jeevibe.app/r/${userData.referral.code}`
  };
}

module.exports = {
  generateReferralCode,
  applyReferralOnSignup,
  handleReferralConversion,
  getReferralStats
};
```

### 3. Bonus Snaps Helper

**File**: `backend/src/services/bonusService.js`

```javascript
const admin = require('firebase-admin');
const db = admin.firestore();

/**
 * Add bonus snaps to a user
 */
async function addBonusSnaps(userId, bonusCount, durationDays) {
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + durationDays);

  const userRef = db.collection('users').doc(userId);
  const userDoc = await userRef.get();
  const userData = userDoc.data();

  // Stack with existing bonus if present
  const existingBonus = userData.bonuses?.snap_solve;
  let newBonusCount = bonusCount;

  if (existingBonus && existingBonus.expires_at?.toDate() > new Date()) {
    // Stack the bonuses, use later expiry
    newBonusCount = existingBonus.extra_daily + bonusCount;
    if (existingBonus.expires_at.toDate() > expiresAt) {
      expiresAt.setTime(existingBonus.expires_at.toDate().getTime());
    }
  }

  await userRef.update({
    'bonuses.snap_solve': {
      extra_daily: newBonusCount,
      expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
      source: 'referral_reward',
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    }
  });

  return { bonus_count: newBonusCount, expires_at: expiresAt };
}

/**
 * Get user's effective daily snap limit (base + bonus)
 */
async function getEffectiveSnapLimit(userId) {
  const userDoc = await db.collection('users').doc(userId).get();
  const userData = userDoc.data();

  // Get base limit from tier
  const tierInfo = await getEffectiveTier(userId);
  const tierConfig = await getTierConfig(tierInfo.tier);
  const baseLimit = tierConfig.limits.snap_solve_daily;

  // Check for active bonus
  const bonus = userData.bonuses?.snap_solve;
  if (bonus && bonus.expires_at?.toDate() > new Date()) {
    return {
      base_limit: baseLimit,
      bonus: bonus.extra_daily,
      total_limit: baseLimit + bonus.extra_daily,
      bonus_expires_at: bonus.expires_at
    };
  }

  return {
    base_limit: baseLimit,
    bonus: 0,
    total_limit: baseLimit,
    bonus_expires_at: null
  };
}

module.exports = {
  addBonusSnaps,
  getEffectiveSnapLimit
};
```

---

## API Endpoints

### 1. Validate Code

**POST** `/api/codes/validate`

```javascript
// Request
{
  "code": "KOTA50",
  "purchase_context": {
    "tier": "pro",
    "plan": "quarterly",
    "amount": 597
  }
}

// Response (success)
{
  "success": true,
  "data": {
    "valid": true,
    "code": "KOTA50",
    "type": "percentage",
    "discount": 298,
    "description": "50% off",
    "final_price": 299
  }
}

// Response (error)
{
  "success": false,
  "error": "This code has expired",
  "code": "EXPIRED"
}
```

### 2. Get Referral Stats

**GET** `/api/referrals/stats`

```javascript
// Response
{
  "success": true,
  "data": {
    "code": "RAHUL123",
    "total_referrals": 15,
    "successful_conversions": 3,
    "pending_rewards": 12,
    "share_url": "https://jeevibe.app/r/RAHUL123",
    "rewards": {
      "per_signup": "+5 bonus snaps",
      "per_conversion": "Progress toward streak",
      "streak_bonus": "3 conversions = 1 week Pro free"
    }
  }
}
```

### 3. Apply Referral Code (Signup)

**POST** `/api/referrals/apply`

```javascript
// Request
{
  "code": "RAHUL123"
}

// Response
{
  "success": true,
  "data": {
    "bonus_snaps": 3,
    "bonus_duration": "7 days",
    "discount_on_purchase": 50,
    "message": "You got +3 bonus snaps and ₹50 off your first purchase!"
  }
}
```

---

## Mobile Implementation

### 1. Promo Code Entry (Paywall)

**File**: `mobile/lib/widgets/promo_code_input.dart`

```dart
class PromoCodeInput extends StatefulWidget {
  final Function(PromoValidationResult) onCodeApplied;
  final PurchaseContext purchaseContext;

  const PromoCodeInput({
    Key? key,
    required this.onCodeApplied,
    required this.purchaseContext,
  }) : super(key: key);

  @override
  State<PromoCodeInput> createState() => _PromoCodeInputState();
}

class _PromoCodeInputState extends State<PromoCodeInput> {
  final _controller = TextEditingController();
  bool _isValidating = false;
  String? _error;
  PromoValidationResult? _result;

  Future<void> _validateCode() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isValidating = true;
      _error = null;
    });

    try {
      final result = await api.validatePromoCode(
        code: code,
        purchaseContext: widget.purchaseContext,
      );

      if (result.valid) {
        setState(() {
          _result = result;
          _error = null;
        });
        widget.onCodeApplied(result);
      } else {
        setState(() {
          _error = result.error;
          _result = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to validate code';
      });
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Promo code',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  suffixIcon: _result != null
                    ? Icon(Icons.check_circle, color: Colors.green)
                    : null,
                ),
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isValidating ? null : _validateCode,
              child: _isValidating
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Apply'),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        if (_result != null)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '${_result!.description} applied!',
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
```

### 2. Referral Screen

**File**: `mobile/lib/screens/referral_screen.dart`

```dart
class ReferralScreen extends StatefulWidget {
  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  ReferralStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await api.getReferralStats();
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  Future<void> _shareCode() async {
    final code = _stats!.code;
    final shareText = '''
Hey! I'm using JEEVibe to solve JEE doubts instantly.

Use my code $code to get +3 bonus snaps and ₹50 off!

Download: https://jeevibe.app/r/$code
''';

    await Share.share(shareText);

    // Log analytics
    analytics.logEvent('referral_shared', {
      'code': code,
      'method': 'share_sheet',
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text('Invite Friends')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Text(
              'Earn rewards for every friend who joins!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),

            // Referral code card
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                children: [
                  Text('Your code', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _stats!.code,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _stats!.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Code copied!')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Share button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _shareCode,
                icon: Icon(Icons.share),
                label: Text('Share with Friends'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.purple,
                ),
              ),
            ),
            SizedBox(height: 32),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCard(
                  value: _stats!.totalReferrals.toString(),
                  label: 'Friends Joined',
                ),
                _StatCard(
                  value: _stats!.successfulConversions.toString(),
                  label: 'Conversions',
                ),
              ],
            ),
            SizedBox(height: 32),

            // Rewards explanation
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rewards', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  _RewardRow(icon: Icons.person_add, text: 'You get: +5 bonus snaps for 7 days'),
                  _RewardRow(icon: Icons.card_giftcard, text: 'Friend gets: +3 snaps + ₹50 off'),
                  _RewardRow(icon: Icons.emoji_events, text: '3 conversions = 1 week Pro FREE!'),
                ],
              ),
            ),

            // Progress to streak
            if (_stats!.successfulConversions < 3)
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    Text('${3 - _stats!.successfulConversions} more conversions to unlock streak bonus!'),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _stats!.successfulConversions / 3,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation(Colors.purple),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _RewardRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RewardRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.purple),
          SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
```

### 3. Referral Code Entry (Signup)

**File**: `mobile/lib/screens/signup_screen.dart`

```dart
// Add to signup flow after phone verification

class ReferralCodeStep extends StatefulWidget {
  final VoidCallback onSkip;
  final Function(String) onApply;

  @override
  State<ReferralCodeStep> createState() => _ReferralCodeStepState();
}

class _ReferralCodeStepState extends State<ReferralCodeStep> {
  final _controller = TextEditingController();
  bool _applying = false;
  String? _error;

  Future<void> _applyCode() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      widget.onSkip();
      return;
    }

    setState(() {
      _applying = true;
      _error = null;
    });

    try {
      final result = await api.applyReferralCode(code);
      if (result.success) {
        widget.onApply(code);
      } else {
        setState(() {
          _error = result.error;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to apply code';
      });
    } finally {
      setState(() {
        _applying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_giftcard, size: 64, color: Colors.purple),
          SizedBox(height: 24),
          Text(
            'Have a referral code?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Get bonus snaps and ₹50 off your first purchase!',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, letterSpacing: 2),
            decoration: InputDecoration(
              hintText: 'Enter code',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              errorText: _error,
            ),
          ),
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applying ? null : _applyCode,
              child: _applying
                ? CircularProgressIndicator(color: Colors.white)
                : Text('Apply Code'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          SizedBox(height: 12),
          TextButton(
            onPressed: widget.onSkip,
            child: Text('Skip for now'),
          ),
        ],
      ),
    );
  }
}
```

---

## Admin Portal

### Create Promo Code UI

```
┌─────────────────────────────────────────────────────────┐
│  Create Promo Code                                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Code: [KOTA50_____________]  (auto-uppercase)          │
│                                                         │
│  Type: [▼ Percentage Discount ]                         │
│        • Percentage Discount                            │
│        • Fixed Amount                                   │
│        • Trial Extension                                │
│        • Bonus Snaps                                    │
│                                                         │
│  Discount: [50___] %                                    │
│                                                         │
│  ─── Applicability ───                                  │
│                                                         │
│  Tiers: [✓] Pro  [✓] Ultra                             │
│  Plans: [✓] Monthly [✓] Quarterly [ ] Annual           │
│  New users only: [✓]                                    │
│                                                         │
│  ─── Limits ───                                         │
│                                                         │
│  Max uses: [1000____]  (-1 for unlimited)               │
│  Per user: [1_______]                                   │
│                                                         │
│  ─── Validity ───                                       │
│                                                         │
│  Starts: [2026-01-25]  Expires: [2026-03-31]           │
│                                                         │
│  ─── Attribution ───                                    │
│                                                         │
│  Source: [▼ Influencer ]                                │
│  Partner: [Alakh Pandey_______]                         │
│  Revenue share: [20__] %                                │
│                                                         │
│  Notes: [Summer campaign for Kota students____]         │
│                                                         │
│              [ Cancel ]  [ Create Code ]                │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Analytics Events

| Event | When | Properties |
|-------|------|------------|
| `promo_code_entered` | User types code in input | `code` |
| `promo_code_validated` | Code validation attempted | `code`, `valid`, `error_code` |
| `promo_code_applied` | Code applied to purchase | `code`, `type`, `discount_amount`, `source` |
| `referral_code_generated` | User's referral code created | `code` |
| `referral_shared` | User shares referral link | `code`, `method` |
| `referral_code_applied` | New user applies referral | `code`, `referrer_user_id` |
| `referral_converted` | Referred user makes payment | `code`, `referrer_user_id` |
| `streak_bonus_unlocked` | User hits 3 conversions | `user_id` |

---

## Implementation Checklist

### Phase 1: Promo Codes (P0)

- [ ] Create `promo_codes` collection schema
- [ ] Create `code_redemptions` collection schema
- [ ] Implement `validatePromoCode()` service
- [ ] Implement `applyPromoCode()` service
- [ ] Create `/api/codes/validate` endpoint
- [ ] Build promo code input widget for paywall
- [ ] Integrate with payment flow
- [ ] Build admin UI to create promo codes

### Phase 2: Referral Codes (P1)

- [ ] Create `referral_codes` collection schema
- [ ] Update user schema with referral fields
- [ ] Implement `generateReferralCode()` service
- [ ] Implement `applyReferralOnSignup()` service
- [ ] Implement `handleReferralConversion()` service
- [ ] Create `/api/referrals/stats` endpoint
- [ ] Create `/api/referrals/apply` endpoint
- [ ] Build referral screen UI
- [ ] Add referral code step to signup flow
- [ ] Build share functionality

### Phase 3: Bonus System (P1)

- [ ] Implement `addBonusSnaps()` service
- [ ] Implement `getEffectiveSnapLimit()` service
- [ ] Update limit checking to include bonuses
- [ ] Show bonus indicator in UI
- [ ] Add bonus expiry notifications

### Phase 4: Analytics & Admin (P2)

- [ ] Add all analytics events
- [ ] Build promo code admin dashboard
- [ ] Build referral stats admin dashboard
- [ ] Create reports for partner attribution

---

## Testing Checklist

### Promo Codes

- [ ] Valid code applies correct discount
- [ ] Expired code rejected
- [ ] Max uses enforced
- [ ] Per-user limit enforced
- [ ] Tier restrictions work
- [ ] Plan restrictions work
- [ ] New user only restriction works

### Referral Codes

- [ ] Code generated on first access
- [ ] Referrer gets bonus snaps
- [ ] Referee gets bonus snaps + discount
- [ ] Can't use own code
- [ ] Conversion tracking works
- [ ] Streak bonus at 3 conversions
- [ ] Share functionality works

### Edge Cases

- [ ] Code with mixed case normalizes
- [ ] Code with spaces trimmed
- [ ] Simultaneous redemptions handled
- [ ] Bonus stacking works correctly
- [ ] Bonus expiry cleanup works
