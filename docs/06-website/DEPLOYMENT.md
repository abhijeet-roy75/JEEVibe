# JEEVibe Web App Deployment Guide

## Firebase Hosting Sites

JEEVibe uses Firebase Hosting with multiple sites:

| Site | URL | Purpose | Deploy Command |
|------|-----|---------|----------------|
| **Marketing Website** | https://jeevibe.web.app | Public marketing site | `firebase deploy --only hosting:website` |
| **Admin Dashboard** | https://jeevibe-admin.web.app | Internal admin panel | `firebase deploy --only hosting:admin` |
| **Web App** | https://jeevibe-app.web.app | Flutter web application | `firebase deploy --only hosting:app` |

## Deployment Steps

### 1. Build Flutter Web App

```bash
cd mobile
flutter build web --release
```

**Output**: `mobile/build/web/` directory

### 2. Deploy to Firebase Hosting

From project root:

```bash
firebase deploy --only hosting:app
```

### 3. Verify Deployment

Visit: https://jeevibe-app.web.app

**Expected behavior**:
- Login screen loads
- Responsive design works (900px max-width on desktop)
- All features work except Snap & Solve (shows "Mobile App Required")
- Share button hidden on web
- No console errors

## Build Configuration

### Firebase Configuration (`firebase.json`)

```json
{
  "target": "app",
  "public": "mobile/build/web",
  "rewrites": [
    {
      "source": "**",
      "destination": "/index.html"
    }
  ],
  "headers": [
    {
      "source": "**/*.html",
      "headers": [{ "key": "Cache-Control", "value": "no-cache" }]
    },
    {
      "source": "**/*.js",
      "headers": [{ "key": "Cache-Control", "value": "max-age=31536000" }]
    },
    {
      "source": "**/*.wasm",
      "headers": [
        { "key": "Cache-Control", "value": "max-age=31536000" },
        { "key": "Content-Type", "value": "application/wasm" }
      ]
    },
    {
      "source": "assets/**",
      "headers": [{ "key": "Cache-Control", "value": "max-age=31536000" }]
    },
    {
      "source": "canvaskit/**",
      "headers": [{ "key": "Cache-Control", "value": "max-age=31536000" }]
    }
  ]
}
```

### Firebase RC (`.firebaserc`)

```json
{
  "projects": {
    "default": "jeevibe"
  },
  "targets": {
    "jeevibe": {
      "hosting": {
        "website": ["jeevibe"],
        "admin": ["jeevibe-admin"],
        "app": ["jeevibe-app"]
      }
    }
  }
}
```

## Bundle Size

**Current production build** (2026-02-21):
- **Total transferred**: ~382 KB (gzipped)
- **Total size**: ~2.1 MB (uncompressed)
- **Files**: 639 files
- **Initial load**: 247ms on 50 Mbps (with cache)

### Breakdown
- `main.dart.js`: ~1.8 MB (270 KB gzipped) - Dart code
- `canvaskit/`: ~500 KB - Flutter rendering engine
- `assets/`: ~200 KB - Images, fonts, icons

## Cache Strategy

### Aggressive Caching
- **Assets, JS, WASM**: 1 year cache (`max-age=31536000`)
- **HTML**: No cache (`no-cache`) - always fresh
- **CanvasKit**: 1 year cache (rarely changes)

**Why**: Users get instant loads on repeat visits, but HTML always checks for new app versions.

## Performance Optimizations

### Current
1. ✅ Production build with tree-shaking
2. ✅ Asset compression
3. ✅ Aggressive browser caching
4. ✅ Lazy-loaded routes (Flutter auto-splits)
5. ✅ Responsive images

### Future (Post-Launch)
1. ⏸️ Code splitting for heavy features
2. ⏸️ WebAssembly build (`--wasm` flag - experimental)
3. ⏸️ Service worker for offline mode
4. ⏸️ Font subsetting (reduce font file sizes)

## Rollback Procedure

If deployment has issues:

```bash
# View deployment history
firebase hosting:channel:list

# Rollback to previous version
firebase hosting:clone SOURCE_SITE_ID:SOURCE_CHANNEL_ID TARGET_SITE_ID:live
```

Or manually via Firebase Console:
1. Go to Firebase Console → Hosting
2. Select "jeevibe-app" site
3. Click "Release History"
4. Click "..." on previous version → "Rollback"

## Custom Domain (Future)

When ready to use `app.jeevibe.com`:

```bash
firebase hosting:sites:get jeevibe-app
firebase hosting:channel:deploy live --only hosting:app
```

Then add custom domain in Firebase Console:
1. Hosting → jeevibe-app → Add custom domain
2. Enter `app.jeevibe.com`
3. Add DNS records (A/AAAA) provided by Firebase

## Monitoring

### Firebase Console
- **Hosting Dashboard**: https://console.firebase.google.com/project/jeevibe/hosting
- **Performance**: Check "Speed" tab for load times
- **Usage**: Monitor bandwidth and requests

### Key Metrics to Watch
- Load time (should be <2s on 10 Mbps)
- Bounce rate (users leaving before app loads)
- Cache hit rate (should be >80% for returning users)
- Error rate (check browser console logs)

## Troubleshooting

### "Failed to load module script" error
**Cause**: Stale cache or interrupted deployment
**Fix**: Hard refresh (Cmd+Shift+R) or clear browser cache

### "Firebase app not initialized" error
**Cause**: Missing Firebase config in `lib/firebase_options.dart`
**Fix**: Ensure `flutterfire configure` was run

### Blank white screen
**Cause**: JavaScript error or missing assets
**Fix**: Check browser console, rebuild app, redeploy

### Assets not loading (404)
**Cause**: Incorrect asset paths or missing files
**Fix**:
```bash
flutter clean
flutter pub get
flutter build web --release
firebase deploy --only hosting:app
```

## CI/CD (Future)

**GitHub Actions workflow** (to be added):

```yaml
name: Deploy Web App
on:
  push:
    branches: [main]
    paths: ['mobile/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build web --release
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          channelId: live
          projectId: jeevibe
          target: app
```

## Deployment Checklist

Before deploying to production:

- [ ] Run tests: `flutter test`
- [ ] Build release: `flutter build web --release`
- [ ] Test locally: Serve `mobile/build/web` and test
- [ ] Check bundle size: Should be <500 KB gzipped
- [ ] Deploy to Firebase: `firebase deploy --only hosting:app`
- [ ] Smoke test: Login, navigate screens, check console
- [ ] Monitor: Watch Firebase Analytics for errors

## Support

**Firebase Hosting Docs**: https://firebase.google.com/docs/hosting
**Flutter Web Docs**: https://docs.flutter.dev/platform-integration/web

---

**Last Updated**: 2026-02-21
**Deployed Version**: v1.0.0 (initial responsive web launch)
