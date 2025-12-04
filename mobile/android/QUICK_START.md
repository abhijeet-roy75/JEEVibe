# Quick Start: Deploy to Google Play Internal Testing

## Step 1: Generate Upload Keystore

Run this command in your terminal (you'll be prompted for passwords and details):

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Important**: 
- Save the keystore password and key password securely
- The keystore will be saved at `~/upload-keystore.jks`

## Step 2: Create key.properties

1. Copy the template:
```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile/android
cp key.properties.template key.properties
```

2. Edit `key.properties` and replace with your actual values:
```properties
storePassword=YOUR_ACTUAL_KEYSTORE_PASSWORD
keyPassword=YOUR_ACTUAL_KEY_PASSWORD
keyAlias=upload
storeFile=/Users/abhijeetroy/upload-keystore.jks
```

## Step 3: Build App Bundle

```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile
flutter build appbundle --release
```

The output will be at: `build/app/outputs/bundle/release/app-release.aab`

## Step 4: Upload to Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app (or create new one)
3. Navigate to: **Release** → **Testing** → **Internal testing**
4. Click **"Create new release"**
5. Upload the `.aab` file from Step 3
6. Add release notes
7. Click **"Save"** then **"Review release"**
8. Click **"Start rollout to Internal testing"**

## Step 5: Add Testers

1. Go to **Testing** → **Internal testing** → **Testers** tab
2. Add your email address (or create a testers list)
3. Copy the opt-in link
4. Open the link on your Android emulator or share with testers

## Testing Without Physical Device

You can test via:
- **Android Emulator**: Install from the Play Store link
- **Play Console**: Download APK directly (if available)

