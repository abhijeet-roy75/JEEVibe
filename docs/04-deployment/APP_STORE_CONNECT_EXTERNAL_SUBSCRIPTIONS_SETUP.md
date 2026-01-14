# App Store Connect - External Subscriptions Setup Guide

**Date**: 2026-01-14  
**Payment Provider**: Razorpay (External, not App Store In-App Purchases)  
**Tiers**: FREE, PRO, ULTRA

---

## Quick Summary: What You Actually Need to Do

**If you don't see "Subscription Status" section** (which is normal):
1. ✅ **Add subscription info to App Description** (in App Store tab)
2. ✅ **Add Privacy Policy URL** (in App Information)
3. ✅ **Add Terms of Service URL** (in App Information, if you have one)
4. ✅ **Ensure in-app subscription management works**

**You do NOT need to:**
- ❌ Create subscription groups
- ❌ Set up subscription products
- ❌ Find a "Subscription Status" section that doesn't exist

---

## Important: External vs In-App Purchases

Since you're using **Razorpay (external subscriptions)**, you do **NOT** need to:
- ❌ Create subscription groups in App Store Connect
- ❌ Create subscription products
- ❌ Set up StoreKit configuration
- ❌ Use App Store's subscription management
- ❌ Find a "Subscription Status" section (it may not exist)

However, Apple **still requires** you to:
- ✅ Provide subscription information in your app description
- ✅ Link to external subscription management
- ✅ Provide terms of service and privacy policy links

---

## Step-by-Step Setup

### Step 1: App Information → Subscriptions

**Important**: The "Subscription Status" section may **NOT appear** in App Store Connect for external subscriptions. This is normal and expected.

**What this means:**
- ✅ You don't need to declare subscriptions in App Store Connect if the section doesn't exist
- ✅ Apple doesn't require you to set up subscription groups for external subscriptions
- ✅ The section is primarily for App Store In-App Purchases

**If you DO see a subscription section:**
- Look for it in: **App Store Connect** → Your App → **App Information**
- If present, you can optionally note that subscriptions are external
- But it's **not required** if the section doesn't exist

---

### Step 2: Where to Provide Subscription Information

Since the "Subscription Status" section may not appear, provide subscription information in these locations:

1. **Subscription Name**: "JEEVibe Pro"
2. **Description**: 
   ```
   JEEVibe Pro subscription provides unlimited access to:
   - Unlimited Snap & Solve questions
   - Unlimited Daily Quizzes
   - Full Performance Analytics
   - Detailed Solutions
   ```
3. **Pricing**:
   - Monthly: ₹299/month
   - Quarterly: ₹249/month (₹747 total)
   - Annual: ₹199/month (₹2,388 total)
4. **Subscription Management URL**: 
   - Link to your web portal where users can manage subscriptions
   - Example: `https://jeevibe.com/subscription/manage`
   - Or: Link to your app's subscription settings screen

---

### Step 3: App Store Listing → App Description (REQUIRED)

**This is the most important step** - Add subscription information to your app description:

1. Go to **App Store Connect** → Your App → **App Store** tab
2. Select your app version (or create a new version)
3. Go to **App Information** section
4. In the **Description** field, add subscription details:

**Recommended App Description Addition:**
```
Subscriptions:
JEEVibe offers a Pro subscription with unlimited access to all features.

Pricing:
• Monthly: ₹299/month
• Quarterly: ₹249/month (₹747 total) - Save 17%
• Annual: ₹199/month (₹2,388 total) - Save 33%

Subscription Management:
Manage your subscription at: https://jeevibe.com/subscription/manage
Or in-app: Settings → Subscription

Payment is processed securely via Razorpay. Subscriptions are managed externally and can be cancelled anytime.
```

---

### Step 4: Terms of Service & Privacy Policy (REQUIRED)

Apple requires links to:
1. **Terms of Service**: Link to your terms page
2. **Privacy Policy**: Link to your privacy policy page

**Where to add:**
1. Go to **App Store Connect** → Your App → **App Information**
2. Scroll to **App Privacy** section
3. Add your **Privacy Policy URL** (required)
4. Add your **Terms of Service URL** (if you have one)

**Alternative locations:**
- **App Store** tab → **App Information** → Look for "Privacy Policy" and "Terms" fields
- **App Information** → Scroll down to find privacy/terms fields

**Example Links:**
- Terms: `https://jeevibe.com/terms` (or your existing terms URL)
- Privacy: `https://jeevibe.com/privacy` (or your existing privacy policy URL)

**Important**: Ensure your privacy policy mentions that you collect subscription/purchase data.

---

### Step 5: In-App Subscription Management

Your app should provide:
1. **Subscription Status Screen**: Show current tier, expiry date
2. **Manage Subscription Button**: Link to web portal or in-app management
3. **Cancel Subscription Option**: Clear instructions on how to cancel

**Implementation in App:**
- Add a "Manage Subscription" button in Settings
- Link to: `https://jeevibe.com/subscription/manage?userId={userId}&token={token}`
- Or implement in-app cancellation flow

---

## What NOT to Do

### ❌ Don't Create Subscription Groups

If you see "Subscription Groups" in App Store Connect:
- **Do NOT** create subscription groups
- **Do NOT** create subscription products
- **Do NOT** set up StoreKit configuration files

These are only for App Store In-App Purchases. Since you're using Razorpay, you don't need these.

### ❌ Don't Use StoreKit APIs

Your app should **NOT** use:
- `StoreKit` framework
- `SKProduct`, `SKPayment`, etc.
- In-App Purchase APIs

---

## Apple's Requirements for External Subscriptions

### 1. Clear Disclosure
- Users must understand subscriptions are managed externally
- Pricing must be clearly displayed
- Terms and cancellation policy must be accessible

### 2. Subscription Management
- Provide a way for users to manage/cancel subscriptions
- Link to external management portal
- Or provide in-app management

### 3. Privacy & Terms
- Privacy policy must mention subscription data
- Terms of service must include subscription terms
- Both must be accessible from the app

---

## Recommended Implementation

### In Your App (Flutter)

1. **Settings Screen** → Add "Subscription" section:
```dart
ListTile(
  leading: Icon(Icons.workspace_premium),
  title: Text('Manage Subscription'),
  subtitle: Text('Current: ${currentTier}'),
  onTap: () => _openSubscriptionManagement(),
)
```

2. **Subscription Management URL**:
```dart
void _openSubscriptionManagement() async {
  final userId = AuthService().currentUser?.uid;
  final token = await AuthService().getIdToken();
  final url = 'https://jeevibe.com/subscription/manage?userId=$userId&token=$token';
  
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url));
  }
}
```

3. **Paywall Screen** → Add disclaimer:
```dart
Text(
  'Subscriptions are managed externally via Razorpay. '
  'You can cancel anytime from Settings → Subscription.',
  style: TextStyle(fontSize: 12, color: Colors.grey),
)
```

---

## App Store Review Guidelines

When submitting for review, ensure:

1. **App Description** mentions:
   - Subscription pricing
   - How to manage subscriptions
   - Link to terms/privacy

2. **App Screenshots** (optional but recommended):
   - Show subscription pricing screen
   - Show subscription management screen

3. **Review Notes** (if submitting):
   ```
   Subscriptions are managed externally via Razorpay payment gateway.
   Users can manage subscriptions at: https://jeevibe.com/subscription/manage
   Terms of Service: https://jeevibe.com/terms
   Privacy Policy: https://jeevibe.com/privacy
   ```

---

## Troubleshooting

### Issue: "Subscription Status" Section Doesn't Appear

**This is NORMAL and EXPECTED** for external subscriptions.

**Solution**: 
- ✅ You don't need to do anything if this section doesn't exist
- ✅ Focus on adding subscription info to your app description instead
- ✅ Ensure Terms and Privacy Policy links are provided

### Issue: "Subscription Groups" Section Appears

**Solution**: Ignore it. You don't need to set up subscription groups for external subscriptions.

### Issue: Apple Asks About In-App Purchases

**Solution**: 
- Select "No" if asked "Does your app use In-App Purchases?"
- Or select "External subscriptions" if that option exists

### Issue: Build Stuck (Related to Subscriptions)

**Possible Causes**:
1. Privacy Manifest missing subscription data types (✅ Fixed in Build 40)
2. App Store Connect waiting for subscription information
3. Missing terms/privacy policy links

**Solution**: 
- Ensure Privacy Manifest includes `NSPrivacyCollectedDataTypePurchaseHistory`
- Provide subscription information in App Store Connect
- Add terms/privacy policy links

---

## Checklist

Before submitting your app:

- [ ] Privacy Manifest includes subscription data types (✅ Already done)
- [ ] **App description includes subscription pricing and management info** (REQUIRED)
- [ ] **Terms of Service link is provided in App Store Connect** (REQUIRED)
- [ ] **Privacy Policy link is provided in App Store Connect** (REQUIRED)
- [ ] Privacy Policy mentions subscription data collection
- [ ] In-app subscription management is accessible
- [ ] Users can cancel subscriptions easily
- [ ] Subscription pricing is clearly displayed in-app
- [ ] App description mentions that subscriptions are managed externally

---

## References

- [Apple App Store Review Guidelines - Subscriptions](https://developer.apple.com/app-store/review/guidelines/#subscriptions)
- [Apple Human Interface Guidelines - Subscriptions](https://developer.apple.com/design/human-interface-guidelines/subscriptions)
- [Razorpay Documentation](https://razorpay.com/docs/)

---

## Summary

**For External Subscriptions (Razorpay):**
1. ✅ Declare subscriptions in App Store Connect (if prompted)
2. ✅ Provide subscription information and pricing
3. ✅ Link to subscription management portal
4. ✅ Provide terms and privacy policy links
5. ❌ Don't create subscription groups/products
6. ❌ Don't use StoreKit APIs

**Key Point**: Apple allows external subscriptions, but you must provide clear information and management options to users.
