# Testing JEEVibe on Android Emulator via Google Play Internal Testing

## Step 1: Set Up Android Emulator

### Option A: Using Android Studio (Recommended)

1. **Open Android Studio**
   - If you don't have it: Download from [developer.android.com/studio](https://developer.android.com/studio)

2. **Open Device Manager**
   - Go to: **Tools** → **Device Manager** (or click the device manager icon in the toolbar)

3. **Create Virtual Device**
   - Click **"Create Device"**
   - Select a device (recommended: **Pixel 5** or **Pixel 6**)
   - Click **"Next"**

4. **Select System Image**
   - Choose an API level (recommended: **API 33** or **API 34** - Android 13/14)
   - If not downloaded, click **"Download"** next to the system image
   - Click **"Next"**

5. **Configure Device**
   - Verify settings (defaults are usually fine)
   - Click **"Finish"**

6. **Start Emulator**
   - Click the **Play** button (▶) next to your virtual device
   - Wait for emulator to boot (may take 1-2 minutes first time)

### Option B: Using Flutter Command Line

```bash
# List available emulators
flutter emulators

# Launch an emulator (if you have one set up)
flutter emulators --launch <emulator_id>
```

## Step 2: Set Up Google Play Services on Emulator

**Important**: The default Android emulator images don't include Google Play Store. You need a **Google Play** system image.

1. **In Android Studio Device Manager**:
   - When creating/editing a device, make sure to select a system image that has **"Google Play"** in the name
   - Example: "Tiramisu (API 33) with Google Play" instead of just "Tiramisu (API 33)"

2. **If you already created an emulator without Google Play**:
   - Delete it and create a new one with a Google Play system image
   - Or use the Play Store-enabled emulator from Android Studio

## Step 3: Add Yourself as Tester in Play Console

1. **Go to Google Play Console**
   - Navigate to: [play.google.com/console](https://play.google.com/console)
   - Select your JEEVibe app

2. **Add Testers**
   - Go to: **Testing** → **Internal testing** → **Testers** tab
   - Click **"Create tester list"** or use existing list
   - Add your Google account email address
   - Click **"Save changes"**

3. **Get Opt-in Link**
   - In the **Testers** tab, find the **"Opt-in URL"**
   - Copy this link (it looks like: `https://play.google.com/apps/internaltest/...`)

## Step 4: Install App on Emulator

### Method 1: Using Play Store Link (Recommended)

1. **Open Chrome/Browser on Emulator**
   - In the emulator, open the browser app
   - Navigate to the opt-in URL you copied from Play Console

2. **Join Testing Program**
   - You'll see a page saying "You're invited to test..."
   - Click **"Become a tester"** or **"Join"** button

3. **Install from Play Store**
   - After joining, you'll be redirected to Play Store
   - Click **"Install"** button
   - Wait for installation to complete

4. **Launch App**
   - Open the app from the app drawer or Play Store

### Method 2: Direct APK Installation (Alternative)

If Play Store doesn't work on emulator:

1. **Download APK from Play Console** (if available)
   - Go to Play Console → Your app → Release → Testing → Internal testing
   - Some releases may have a "Download" option

2. **Install via ADB**
   ```bash
   # Make sure emulator is running and connected
   adb devices
   
   # Install APK (if you have one)
   adb install path/to/app.apk
   ```

### Method 3: Using Flutter Run (For Development)

For quick testing during development (not from Play Store):

```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile
flutter run
```

This installs directly to the emulator but won't test the Play Store version.

## Step 5: Verify Installation

1. **Check App is Installed**
   - Look for "JEEVibe" in the app drawer
   - App icon should be visible

2. **Test App Functionality**
   - Open the app
   - Test camera functionality
   - Test image upload
   - Verify all features work as expected

## Troubleshooting

### Emulator Doesn't Have Play Store

**Solution**: Create a new emulator with a Google Play system image:
- In Android Studio Device Manager, look for system images with "Google Play" in the name
- Delete old emulator and create new one

### Can't Access Opt-in Link

**Solution**: 
- Make sure you're signed into the same Google account on the emulator that you added as a tester
- Open Play Store app on emulator and sign in first
- Then try the opt-in link

### "App not available" in Play Store

**Possible causes**:
- You haven't joined the testing program yet (use opt-in link first)
- The release hasn't been rolled out yet (check Play Console)
- Wrong Google account signed in on emulator

**Solution**:
- Verify you clicked "Become a tester" from the opt-in link
- Check Play Console → Internal testing → Release to see if it's active
- Make sure the Google account on emulator matches the tester email

### Emulator is Slow

**Solutions**:
- Enable hardware acceleration in emulator settings
- Reduce emulator RAM/CPU allocation if your machine is limited
- Close other applications
- Use a smaller screen resolution

### ADB Not Recognizing Emulator

```bash
# Check if emulator is connected
adb devices

# If not showing, restart ADB
adb kill-server
adb start-server
```

## Quick Reference Commands

```bash
# List available emulators
flutter emulators

# Launch emulator
flutter emulators --launch <emulator_id>

# Check connected devices
adb devices

# Install APK directly (if needed)
adb install path/to/app.apk

# View logs
adb logcat | grep flutter

# Uninstall app
adb uninstall com.jeevibe.jeevibe_mobile
```

## Next Steps After Testing

Once you've verified the app works on the emulator:

1. **Test on Physical Device** (if available)
   - Use the same opt-in link on a real Android device
   - Install from Play Store

2. **Gather Feedback**
   - Test all features thoroughly
   - Note any issues or bugs

3. **Prepare for Production**
   - Fix any issues found
   - Update version number for next release
   - Build new app bundle
   - Upload to Production track when ready

