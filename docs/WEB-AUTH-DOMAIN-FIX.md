# Web Authentication Domain Fix

**Error**: "Verification Failed: Hostname match not found"
**Platform**: Web app at https://jeevibe-app.web.app/
**Location**: India tester
**Root Cause**: Domain `jeevibe-app.web.app` not added to Firebase authorized domains

## Immediate Fix (2 minutes)

### Step 1: Add Authorized Domain in Firebase Console

1. Go to **Firebase Console**: https://console.firebase.google.com/project/jeevibe/authentication/settings
2. Scroll to **Authorized domains** section
3. Click **Add domain**
4. Enter: `jeevibe-app.web.app`
5. Click **Add**

### Step 2: Verify

Ask Indian tester to:
1. **Hard refresh** the web app: `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R` (Windows)
2. Clear browser cache (optional)
3. Try sign-in again

**Expected**: Sign-in should now work immediately (no rebuild needed)

---

## Why This Happened

When we deployed the Flutter web app to Firebase Hosting with a new site (`jeevibe-app`), Firebase Authentication didn't automatically authorize the new domain.

**Authorized by default**:
- ✅ `localhost` (for development)
- ✅ `jeevibe.web.app` (original marketing site domain)
- ❌ `jeevibe-app.web.app` (**NEW** - not added yet)

**Firebase blocks authentication** from unauthorized domains for security.

---

## Additional Domains to Add (For Future)

If you plan to use custom domains or other subdomains, add these now:

1. **Production custom domain** (when ready):
   - `app.jeevibe.com`

2. **Admin dashboard**:
   - `jeevibe-admin.web.app` (if using phone auth on admin)

3. **Staging/Testing**:
   - `jeevibe-app-staging.web.app` (if you create staging environment)

---

## Verification Steps

### 1. Check Authorized Domains List

Go to: https://console.firebase.google.com/project/jeevibe/authentication/settings

Should see:
```
✅ localhost
✅ jeevibe.web.app
✅ jeevibe-app.web.app  ← NEW
```

### 2. Test Phone Authentication

1. Open https://jeevibe-app.web.app/
2. Enter Indian phone number: `+91 XXXXXXXXXX`
3. Click "Send OTP"
4. Should receive OTP without "Hostname match" error

### 3. Check Browser Console

Open browser DevTools (F12) → Console tab:
- **Before fix**: `auth/unauthorized-domain`
- **After fix**: No auth errors

---

## Alternative: Add via Firebase CLI

If you prefer CLI:

```bash
# Install Firebase CLI (if not already)
npm install -g firebase-tools

# Login
firebase login

# List current authorized domains
firebase auth:export --project jeevibe

# Add new domain (NOT RECOMMENDED - use console instead)
# Firebase CLI doesn't have direct command for this
# Use Firebase Console UI instead
```

---

## Common Mistakes

### ❌ Adding wrong domain format:
- `https://jeevibe-app.web.app` (includes protocol - WRONG)
- `jeevibe-app.web.app/` (trailing slash - WRONG)
- `*.web.app` (wildcard - won't work)

### ✅ Correct format:
- `jeevibe-app.web.app` (just the domain)

### ❌ Adding to wrong place:
- Don't add to **API key restrictions** (different setting)
- Add to **Firebase Authentication** → **Settings** → **Authorized domains**

---

## Security Note

**Why Firebase requires authorized domains:**
- Prevents phishing attacks
- Stops unauthorized sites from using your Firebase project
- Protects your Firebase quota from abuse

**Best practices:**
- Only add domains you own/control
- Remove test domains before production launch
- Use separate Firebase projects for staging/production

---

## Quick Reference

| Domain | Purpose | Status |
|--------|---------|--------|
| `localhost` | Development | ✅ Auto-added |
| `jeevibe.web.app` | Marketing website | ✅ Auto-added |
| `jeevibe-admin.web.app` | Admin dashboard | ✅ Auto-added |
| `jeevibe-app.web.app` | Mobile web app | ❌ **NEEDS TO BE ADDED** |
| `app.jeevibe.com` | Custom domain (future) | ⏸️ Add when ready |

---

## Next Steps After Fix

1. **Inform India tester**: "Issue fixed! Please refresh and try again"
2. **Test yourself**: Visit https://jeevibe-app.web.app/ and test phone auth
3. **Document**: Add `jeevibe-app.web.app` to deployment checklist
4. **Monitor**: Check Firebase Authentication → Users for successful sign-ins

---

**Fix Time**: ~2 minutes
**Impact**: Fixes web authentication for ALL geographic locations
**Requires Rebuild**: ❌ No - just add domain in Firebase Console

---

**Last Updated**: 2026-02-21
**Status**: Ready to apply fix
