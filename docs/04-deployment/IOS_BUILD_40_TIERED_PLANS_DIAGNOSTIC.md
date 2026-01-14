# iOS Build 40 - Tiered Plans Feature Diagnostic

**Date**: 2026-01-14  
**Build Number**: 40  
**Issue**: Build stuck in "Processing" state for >30 minutes  
**Feature Added**: Tiered subscription system (FREE, PRO, ULTRA)

---

## Potential Causes

### 1. **Privacy Manifest - Subscription Data Types** ⚠️ **MOST LIKELY**

Apple may be flagging the app because it collects subscription/payment data but doesn't declare it in the Privacy Manifest.

**What to check:**
- The app now collects subscription tier, usage limits, and payment-related data
- Privacy Manifest (`PrivacyInfo.xcprivacy`) may need to declare:
  - `NSPrivacyCollectedDataTypePurchaseHistory` (if tracking purchases)
  - `NSPrivacyCollectedDataTypeFinancialInfo` (if collecting payment data)

**Solution:**
Update `mobile/ios/Runner/PrivacyInfo.xcprivacy` to include subscription-related data types if applicable.

---

### 2. **App Store Connect - Subscription Declaration**

Apple may be waiting for you to declare whether the app uses:
- **In-App Purchases** (via App Store)
- **External Subscriptions** (via web/Razorpay)

**What to check in App Store Connect:**
1. Go to your app → **App Information**
2. Check **Subscription Status** section
3. If using external subscriptions (Razorpay), you may need to:
   - Declare that subscriptions are managed externally
   - Provide subscription terms and pricing information

**Solution:**
- If using **external subscriptions** (Razorpay), ensure App Store Connect reflects this
- If using **in-app purchases**, you need StoreKit configuration

---

### 3. **Export Compliance - Payment Encryption**

If the subscription feature uses payment processing, Apple may need updated Export Compliance information.

**What to check:**
- Current `Info.plist` has `ITSAppUsesNonExemptEncryption = false`
- If Razorpay uses additional encryption beyond HTTPS, this may need updating

**Solution:**
- Verify that payment processing only uses standard HTTPS/TLS (exempt encryption)
- If so, ensure Export Compliance is set to "Yes" with "Standard encryption" selected

---

### 4. **Build Processing Time**

Sometimes builds legitimately take 30-60 minutes, especially:
- During peak hours
- When Apple's servers are busy
- For first build after significant changes

**What to check:**
- Wait up to 60 minutes before assuming it's stuck
- Check App Store Connect for any error messages (even if build isn't clickable)

---

### 5. **Missing Capabilities or Entitlements**

If the app references subscription APIs but doesn't have proper entitlements.

**What to check:**
- No new entitlements files found (good - means no StoreKit)
- No In-App Purchase capability enabled (good - using external payments)

**Solution:**
- This is likely NOT the issue since we're using external subscriptions

---

## Immediate Actions

### Step 1: Check Build Status (Wait)
- Wait up to **60 minutes total** before taking action
- Check if build becomes clickable after processing completes

### Step 2: Update Privacy Manifest (If Needed)
If the app collects subscription data, update `PrivacyInfo.xcprivacy`:

```xml
<!-- Add if collecting subscription/purchase data -->
<dict>
  <key>NSPrivacyCollectedDataType</key>
  <string>NSPrivacyCollectedDataTypePurchaseHistory</string>
  <key>NSPrivacyCollectedDataTypeLinked</key>
  <false/>
  <key>NSPrivacyCollectedDataTypeTracking</key>
  <false/>
  <key>NSPrivacyCollectedDataTypePurposes</key>
  <array>
    <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
  </array>
</dict>
```

### Step 3: Verify App Store Connect Settings
1. Go to **App Store Connect** → Your App
2. Check **App Information** → **Subscription Status**
3. If prompted, declare that subscriptions are managed externally (Razorpay)

### Step 4: Check Export Compliance
1. Go to **App Information** → **Export Compliance**
2. Ensure it's set to:
   - "Does your app use encryption?" → **Yes**
   - "Does your app use exempt encryption?" → **Yes**
   - Select: **"Standard encryption algorithms (HTTPS/TLS)"**

### Step 5: If Still Stuck After 60 Minutes
1. **Cancel the build** in App Store Connect
2. **Increment build number** to 41
3. **Make any Privacy Manifest updates** if needed
4. **Re-upload** the build

---

## Code Changes in Build 40

### New Files:
- `mobile/lib/services/subscription_service.dart` - Subscription management
- `mobile/lib/models/subscription_models.dart` - Subscription data models
- `mobile/lib/screens/subscription/paywall_screen.dart` - Paywall UI

### Modified Files:
- `mobile/lib/services/api_service.dart` - Added subscription API calls
- `mobile/lib/screens/analytics_screen.dart` - Tier-based analytics gating
- `mobile/lib/services/snap_counter_service.dart` - Tier-based limits

### No iOS-Specific Changes:
- ✅ No new native dependencies
- ✅ No new permissions in `Info.plist`
- ✅ No new capabilities or entitlements
- ✅ No StoreKit or In-App Purchase code

---

## Recommended Fix

**Most likely issue**: Privacy Manifest needs subscription data type declaration.

**Action**: Update `mobile/ios/Runner/PrivacyInfo.xcprivacy` to include purchase/subscription data types if the app collects this information.

---

## Prevention for Future Builds

1. **Always update Privacy Manifest** when adding new data collection
2. **Declare subscription model** in App Store Connect before uploading
3. **Test builds locally** before uploading to App Store Connect
4. **Monitor build status** - don't assume it's stuck until 60+ minutes

---

## References

- [Apple Privacy Manifest Documentation](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [App Store Connect Subscription Guidelines](https://developer.apple.com/app-store/subscriptions/)
- [Export Compliance Guide](./IOS_BUILD_STUCK_EXPORT_COMPLIANCE_FIX.md)
