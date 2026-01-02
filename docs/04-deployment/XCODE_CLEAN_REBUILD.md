# Xcode Clean Rebuild Guide

## Quick Clean & Rebuild Steps

### Option 1: Use the Clean Script (Recommended)

```bash
cd /Users/abhijeetroy/Documents/JEEVibe
./scripts/clean-rebuild.sh
```

Then in Xcode:
1. **Product > Clean Build Folder** (Shift+Cmd+K)
2. **Product > Build** (Cmd+B)
3. **Product > Run** (Cmd+R)

### Option 2: Manual Clean in Xcode

1. **Close Xcode** (if open)

2. **Clean Flutter:**
   ```bash
   cd mobile
   flutter clean
   flutter pub get
   ```

3. **Open Xcode:**
   ```bash
   cd mobile/ios
   open Runner.xcworkspace
   ```

4. **In Xcode:**
   - **Product > Clean Build Folder** (Shift+Cmd+K)
   - Wait for it to complete
   - **Product > Build** (Cmd+B)
   - **Product > Run** (Cmd+R)

### Option 3: Complete Nuclear Clean

If you're still not seeing changes:

```bash
cd /Users/abhijeetroy/Documents/JEEVibe

# 1. Clean Flutter
cd mobile
flutter clean
rm -rf build/
rm -rf .dart_tool/

# 2. Clean iOS
cd ios
rm -rf build/
rm -rf Pods/
rm -f Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 3. Reinstall everything
pod install --repo-update
cd ..
flutter pub get

# 4. Open Xcode
cd ios
open Runner.xcworkspace
```

Then in Xcode:
- **Product > Clean Build Folder** (Shift+Cmd+K)
- **Product > Build** (Cmd+B)
- **Product > Run** (Cmd+R)

## App Icon Setup

### If Icon Still Not Showing:

1. **In Xcode:**
   - Click on `Runner` in left sidebar
   - Select `Runner` target
   - Go to `General` tab
   - Scroll to `App Icons and Launch Screen`
   - Click on `AppIcon` under `App Icons Source`

2. **Verify Icons:**
   - You should see a grid with all icon sizes
   - Each slot should have an image
   - If any are empty, drag your logo onto the 1024x1024 slot and Xcode will auto-generate

3. **Regenerate Icons (if needed):**
   ```bash
   cd /Users/abhijeetroy/Documents/JEEVibe
   ./scripts/generate-app-icons.sh mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/jeevibe_logo.jpeg
   ```

4. **Force Refresh:**
   - In Xcode: **Product > Clean Build Folder** (Shift+Cmd+K)
   - Delete app from device/simulator
   - Rebuild and reinstall

## Troubleshooting

### Changes Not Appearing:
- ✅ Always do **Clean Build Folder** after code changes
- ✅ Delete app from device before reinstalling
- ✅ Check that you're building the correct scheme (Runner, not Flutter)

### Icon Not Showing:
- ✅ Verify all icon files exist in `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- ✅ Check `Contents.json` references correct filenames
- ✅ Ensure icons are PNG format (not JPEG for individual sizes)
- ✅ Try deleting app from device and reinstalling

### Build Errors:
- ✅ Run `pod install` in `mobile/ios/` directory
- ✅ Check Xcode version compatibility
- ✅ Verify signing certificates in Xcode

## Best Practices

1. **Always clean before building** when you make UI/code changes
2. **Use Xcode for iOS builds** - it's more reliable than `flutter run` for iOS
3. **Check device logs** in Xcode Console if app crashes
4. **Keep Xcode updated** to latest stable version

