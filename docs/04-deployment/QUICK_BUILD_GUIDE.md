# Quick Build Guide - iOS & Android

Quick reference for building and deploying JEEVibe.

---

## 🍎 iOS Build (TestFlight)

### Prerequisites
- Apple Developer Account
- Xcode installed
- App registered in App Store Connect

### Quick Steps

1. **Update version (if needed):**
   ```bash
   cd mobile
   ./scripts/bump_version.sh patch
   ```

2. **Build:**
   ```bash
   ./scripts/build_ios.sh
   ```

3. **Upload to TestFlight:**
   - Open Xcode → Window → Organizer (Cmd+Shift+O)
   - Select archive → **Distribute App**
   - Choose **App Store Connect** → Upload

**Output:** `build/ios/ipa/JEEVibe.ipa`

---

## 🤖 Android Build (Play Store)

### Prerequisites
- Google Play Console account
- Upload keystore generated

### First-Time Setup

1. **Generate keystore:**
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias upload
   ```

2. **Configure key.properties:**
   ```bash
   cd mobile/android
   cp key.properties.template key.properties
   # Edit key.properties with your keystore details
   ```

### Quick Steps

1. **Update version (if needed):**
   ```bash
   cd mobile
   ./scripts/bump_version.sh patch
   ```

2. **Build:**
   ```bash
   ./scripts/build_android.sh
   ```

3. **Upload to Play Store:**
   - Go to [Google Play Console](https://play.google.com/console/)
   - Select app → Production → Create new release
   - Upload `build/app/outputs/bundle/release/app-release.aab`

**Output:** `build/app/outputs/bundle/release/app-release.aab`

---

## 📝 Version Management

Current version format: `MAJOR.MINOR.PATCH+BUILD_NUMBER`

**Example:** `1.0.0+5`
- `1.0.0` = Version name (user-facing)
- `5` = Build number (increments each build)

**Update version:**
```bash
cd mobile
./scripts/bump_version.sh patch   # 1.0.0+5 → 1.0.1+6
./scripts/bump_version.sh minor   # 1.0.0+5 → 1.1.0+6
./scripts/bump_version.sh major   # 1.0.0+5 → 2.0.0+6
```

**Or manually edit `pubspec.yaml`:**
```yaml
version: 1.0.1+6
```

---

## 🚀 Build Scripts

All scripts are in `mobile/scripts/`:

- `build_ios.sh` - Build iOS archive for TestFlight
- `build_android.sh` - Build Android AAB for Play Store
- `bump_version.sh` - Increment version number

**Usage:**
```bash
cd mobile
./scripts/build_ios.sh
./scripts/build_android.sh
./scripts/bump_version.sh patch
```

---

## ⚠️ Important Notes

### iOS
- ✅ Bundle ID: `com.jeevibe.jeevibeMobile`
- ✅ Must sign with Apple Developer certificate
- ✅ Archive must be uploaded within 90 days

### Android
- ✅ Package name: `com.jeevibe.jeevibe_mobile`
- ✅ Keystore file must be backed up securely
- ✅ Never lose keystore - you can't update app without it!

---

## 🔍 Troubleshooting

### iOS: "No signing certificate"
- Xcode → Preferences → Accounts → Add Apple ID
- Download certificates automatically

### Android: "Keystore not found"
- Check `android/key.properties` exists
- Verify `storeFile` path is absolute (e.g., `/Users/name/upload-keystore.jks`)

### Build fails
```bash
flutter clean
flutter pub get
# Try again
```

---

## 📚 Full Documentation

See `docs/BUILD_AND_DEPLOY.md` for detailed instructions.

