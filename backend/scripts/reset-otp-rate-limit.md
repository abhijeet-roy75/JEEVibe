# Reset OTP Rate Limit

## Problem
The mobile app has client-side rate limiting that allows only **3 OTP requests per hour**. This is stored locally in SharedPreferences/UserDefaults on the device.

**Location in code:**
- File: `mobile/lib/services/storage_service.dart`
- Constant: `maxOtpRequestsPerHour = 3` (line 29)

When you hit this limit, you see: **"Rate limit reached. Please try again later."**

## Solutions

### Solution 1: Clear App Data on Device (Recommended)

This is the quickest way to reset the counter:

**iOS:**
1. Delete and reinstall the app, OR
2. Settings → General → iPhone Storage → JEEVibe → Delete App → Reinstall

**Android:**
1. Settings → Apps → JEEVibe → Storage → Clear Data, OR
2. Uninstall and reinstall

### Solution 2: Wait 1 Hour
The rate limit automatically resets after 1 hour from your first OTP request.

### Solution 3: Increase Rate Limit for Testing

Temporarily increase the limit in the code:

**File:** `mobile/lib/services/storage_service.dart`

**Change line 29 from:**
```dart
static const int maxOtpRequestsPerHour = 3;
```

**To:**
```dart
static const int maxOtpRequestsPerHour = 100; // Increased for testing
```

Then rebuild and run the app:
```bash
cd mobile
flutter run
```

**Don't forget to change it back before production!**

### Solution 4: Setup Firebase Test Phone Numbers (Best for Development)

Configure test phone numbers in Firebase Console to bypass OTP entirely:

1. Go to: https://console.firebase.google.com
2. Select your project
3. Authentication → Sign-in method → Phone
4. Scroll to "Phone numbers for testing"
5. Add: `+16505551234` with code `123456`

Benefits:
- No SMS sent
- No rate limits (client or server)
- Fixed verification code
- Free (no SMS charges)

See: `backend/scripts/setup-test-phones.md` for detailed instructions

## Rate Limit Logic

The app tracks OTP request timestamps in local storage:

1. **Record timestamp** when "Send OTP" is clicked
2. **Count requests** in the last 60 minutes
3. **Block if ≥ 3** requests in last hour
4. **Auto-cleanup** old timestamps (>1 hour old)

**Storage key:** `otp_requests` (JSON array of Unix timestamps)

## Why This Rate Limit Exists

1. **Prevent abuse**: Stop users from spamming OTP requests
2. **Reduce SMS costs**: Each OTP costs money to send
3. **Firebase protection**: Firebase also has server-side rate limits
4. **Better UX**: Encourages users to wait for OTP instead of re-requesting

## Current Status

✅ Rate limit is **working as designed**
- 3 requests per hour is reasonable for production
- For testing: Use Solution 3 (increase limit) or Solution 4 (test phone numbers)

## Recommendation

For development/testing:
1. **Setup Firebase test phone numbers** (Solution 4) - No rate limits, no SMS
2. **Increase client rate limit** (Solution 3) - Quick temporary fix

For production:
- Keep current 3/hour limit - Good balance between security and UX
