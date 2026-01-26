# Deployment Checklist - Crash Fixes

## Pre-Deployment

- [x] All changes committed to main branch
- [x] Firestore indexes deployed
- [ ] Backend tests passing (if applicable)
- [ ] Mobile app builds successfully

## Backend Deployment

The backend will auto-deploy to Render when you push to main:

```bash
git push origin main
```

**Monitor:** https://dashboard.render.com/

**Expected changes:**
- Session creation will use `.set({merge:true})` instead of `.update()`
- Invalid question errors will be logged instead of throwing
- No code that requires manual intervention

## Mobile Deployment

### 1. Install Dependencies
```bash
cd mobile
flutter pub get
```

### 2. Test Build
```bash
flutter clean
flutter build ios --release
flutter build apk --release
```

### 3. Test Locally (Optional)
```bash
flutter run --release
```

Test scenarios:
- [ ] New user signup and daily quiz flow
- [ ] Existing user daily quiz flow
- [ ] Verify crashes are reported to Crashlytics

### 4. Deploy to App Stores

**iOS:**
```bash
flutter build ios --release
# Open Xcode and submit to App Store Connect
```

**Android:**
```bash
flutter build appbundle --release
# Upload to Google Play Console
```

## Post-Deployment Verification

### 1. Backend (Render)
- [ ] Check Render logs for successful deployment
- [ ] Verify no new errors in logs
- [ ] Test session creation API endpoint

### 2. Firebase
- [ ] Verify Crashlytics is receiving data: https://console.firebase.google.com/project/jeevibe/crashlytics
- [ ] Check Firestore indexes are all green: https://console.firebase.google.com/project/jeevibe/firestore/indexes

### 3. User Testing
- [ ] Test with user `YkgWqLZA68WUG0D6fOkC4XqYVxh2` (if possible)
- [ ] New user signup → Daily Quiz flow
- [ ] Verify no crashes reported

### 4. Monitoring (24-48 hours)
- [ ] Monitor Crashlytics for new crashes
- [ ] Check Render logs for "invalid correct_answer_exact" errors
- [ ] Monitor user reports/support tickets

## Rollback Plan

If critical issues arise:

### Backend
1. Revert commit: `git revert f82209e`
2. Push: `git push origin main`
3. Render will auto-deploy the revert

### Mobile
1. Previous version still in app stores (no immediate action needed)
2. Don't submit new version to stores until issues resolved

### Firestore Indexes
1. Indexes are additive (safe to keep)
2. If needed to remove: Update `firestore.indexes.json` and redeploy

## Known Issues to Monitor

1. **Question CHEM_PURC_E_028** - Has invalid data, needs manual fix
   - Currently handled gracefully (marks as incorrect)
   - Admin should fix in Firestore: See `backend/QUESTION_FIXES_NEEDED.md`

2. **User profile creation** - May need improvement
   - Current fix handles missing docs gracefully
   - Consider atomic profile creation with auth in future

## Success Criteria

- [x] Code committed and pushed
- [x] Indexes deployed
- [ ] Backend deployed to Render (auto)
- [ ] Mobile apps built successfully
- [ ] No new crashes in Crashlytics (24hrs after mobile deployment)
- [ ] Test user reports crash is fixed

## Timeline

- **Backend:** Auto-deploys within 5-10 minutes of push
- **Mobile:** Requires manual app store submission
  - iOS: 1-2 days for review
  - Android: Few hours to 1 day for review

## Contact

If issues arise:
- Check Render logs: https://dashboard.render.com/
- Check Crashlytics: https://console.firebase.google.com/project/jeevibe/crashlytics
- Check Firebase indexes: https://console.firebase.google.com/project/jeevibe/firestore/indexes
