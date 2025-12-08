# Google Play Privacy Policy Requirement

## Issue
Google Play requires a privacy policy URL for apps that use certain permissions, including:
- `android.permission.CAMERA` (which JEEVibe uses)

## Solution

You have two options:

### Option 1: Add Privacy Policy URL in Play Console (Recommended)

1. **Create a Privacy Policy** (if you don't have one):
   - Host it on your website, GitHub Pages, or a privacy policy generator
   - Must be publicly accessible via HTTPS URL
   - Should explain how you use camera permissions

2. **Add URL in Play Console**:
   - Go to [Google Play Console](https://play.google.com/console)
   - Select your JEEVibe app
   - Navigate to: **Policy** → **App content** → **Privacy Policy**
   - Enter your privacy policy URL
   - Click **"Save"**

### Option 2: Remove Camera Permission (Not Recommended)

This would break the app's core functionality (Snap & Solve feature).

## Privacy Policy Requirements

Your privacy policy should cover:
- What data you collect (camera images)
- How you use the data (processing questions, generating solutions)
- Where data is stored (temporarily on device, sent to backend)
- Data retention policies
- User rights (data deletion, etc.)

## Quick Privacy Policy Template

You can use services like:
- [Privacy Policy Generator](https://www.privacypolicygenerator.info/)
- [Termly](https://termly.io/)
- [iubenda](https://www.iubenda.com/)

Or host a simple HTML page with your privacy policy.

## Important Notes

- **You cannot delete a version once uploaded** - version codes are permanent
- **You must increment version code** for each new release (we've updated to 1.0.0+4)
- **Privacy policy is mandatory** for apps with camera permission
- The privacy policy URL must be added before you can publish to production

## Next Steps

1. ✅ Version code updated to 4 (done)
2. Build new app bundle with version 4
3. Create/host privacy policy
4. Add privacy policy URL in Play Console
5. Upload new app bundle
6. Complete store listing requirements
7. Submit for review




