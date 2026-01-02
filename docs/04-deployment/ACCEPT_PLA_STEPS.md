# Accept Program License Agreement - Step by Step

## Quick Steps

1. **Go to Apple Developer Account:**
   - I've opened it for you, or go to: https://developer.apple.com/account
   - Sign in with your Apple ID (the same one you use for Xcode)

2. **Accept the Agreement:**
   - Look for a banner or notification about "Program License Agreement"
   - Or go to: **Membership** → **Agreements, Tax, and Banking**
   - Find the latest **Program License Agreement**
   - Click **"Review Agreement"** or **"Accept"**
   - Read and accept the terms

3. **Wait for Propagation:**
   - After accepting, wait 2-5 minutes
   - The agreement needs to sync to Apple's servers

4. **Refresh in Xcode:**
   - Go back to Xcode
   - Click the **"Try Again"** button in the Signing section
   - Or close and reopen Xcode

5. **Alternative: Accept via Xcode:**
   - In Xcode, go to: **Xcode → Settings → Accounts**
   - Select your Apple ID
   - Click **"Manage Certificates"** or look for agreement notices
   - Accept any agreements shown there

## After Accepting

Once the agreement is accepted and propagated:

1. In Xcode, click **"Try Again"** button
2. Xcode should automatically:
   - Create the provisioning profile
   - Set up code signing
   - Show green checkmarks

3. Then run:
   ```bash
   cd mobile
   flutter clean
   flutter run
   ```

## Troubleshooting

If "Try Again" still shows errors after 5 minutes:
- Sign out and sign back into your Apple ID in Xcode Settings
- Or try changing the Bundle Identifier temporarily, then change it back

