# Fix Code Signing Issues

## Issue 1: Program License Agreement (PLA)

**Error:** "You currently don't have access to this membership resource. To resolve this issue, agree to the latest Program License Agreement"

**Fix:**
1. Go to: https://developer.apple.com/account
2. Sign in with your Apple ID
3. Accept the latest Program License Agreement
4. Wait a few minutes for it to propagate

## Issue 2: Provisioning Profiles

**Error:** "No profiles for 'com.jeevibe.jeevibeMobile' were found"

**Fix in Xcode:**
1. Xcode should be opening now (or open: `open ios/Runner.xcworkspace`)
2. In Xcode, select **Runner** in the left sidebar (blue icon)
3. Select the **Runner** target (under TARGETS)
4. Go to **Signing & Capabilities** tab
5. Check **"Automatically manage signing"**
6. Select your **Team** (your Apple ID/Developer account)
7. Xcode will automatically:
   - Create a provisioning profile
   - Set up code signing
   - Update the bundle identifier if needed

**If you don't have a team:**
- Click "Add Account" next to Team
- Sign in with your Apple ID
- Free Apple Developer account works for development

## After Fixing

1. Close Xcode
2. Run: `flutter clean` (in mobile directory)
3. Run: `flutter run` again

## Quick Checklist

- [ ] Accepted Program License Agreement on developer.apple.com
- [ ] Opened Xcode workspace
- [ ] Selected Runner target
- [ ] Enabled "Automatically manage signing"
- [ ] Selected your Team
- [ ] Xcode created provisioning profile (check for green checkmark)
- [ ] Closed Xcode
- [ ] Ran `flutter clean`
- [ ] Ran `flutter run`

