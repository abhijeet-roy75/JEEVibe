# Setup Test Phone Numbers in Firebase

Firebase Auth phone authentication has rate limiting to prevent abuse. To bypass this for testing, you need to configure test phone numbers in the Firebase Console.

## Steps to Configure Test Phone Numbers

### 1. Go to Firebase Console
- URL: https://console.firebase.google.com
- Select your JEEVibe project

### 2. Navigate to Authentication Settings
1. Click **Authentication** in the left sidebar
2. Click **Sign-in method** tab
3. Find **Phone** in the providers list
4. Click the pencil icon to edit

### 3. Add Test Phone Numbers
Scroll down to the section **"Phone numbers for testing"** and add:

| Phone Number | Verification Code | Notes |
|--------------|-------------------|-------|
| `+16505551234` | `123456` | Primary test number (US) |
| `+919876543210` | `654321` | Test number (India) |
| `+12025551234` | `111111` | Additional test number |

### 4. Save Changes
Click **Save** at the bottom of the page.

## Benefits of Test Phone Numbers

1. **No SMS Sent**: Firebase doesn't send actual SMS messages
2. **No Rate Limits**: Bypass all rate limiting restrictions
3. **Fixed OTP Code**: Use the configured code instead of random OTP
4. **Unlimited Testing**: Test login flow as many times as needed
5. **No Cost**: No SMS charges

## Using Test Phone Numbers in the App

When using a test phone number:
1. Enter the test phone number (e.g., `+16505551234`)
2. Click "Send OTP"
3. Firebase will NOT send an SMS
4. Enter the configured verification code (e.g., `123456`)
5. Click "Verify"

The app will work exactly like a real phone number, but without SMS and rate limits.

## Rate Limit Issues

If you see "Rate limit reached, try after some time":
- You've exceeded Firebase's phone auth rate limit (too many OTP attempts)
- **Solution 1**: Configure test phone numbers (as described above)
- **Solution 2**: Wait 1-24 hours for the rate limit to reset
- **Solution 3**: Use a different phone number temporarily

## Current Test Configuration Status

❌ **Not configured yet** - Test phone numbers need to be added in Firebase Console

To check current status, see:
https://console.firebase.google.com/project/[YOUR_PROJECT_ID]/authentication/providers

## Security Note

⚠️ **IMPORTANT**: Test phone numbers should only be used in development/staging environments. Never add test phone numbers to production Firebase projects, as they bypass security measures.

## Alternative: Firebase Emulator Suite

For local development, consider using the Firebase Auth Emulator:
```bash
firebase emulators:start --only auth
```

The emulator automatically bypasses rate limits and doesn't require actual phone numbers.
