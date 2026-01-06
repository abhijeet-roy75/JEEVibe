# Android Snap-and-Solve Crash Diagnosis

**Device:** Samsung Galaxy A16
**Platform:** Android
**Issue:** App crashes when using snap-and-solve feature
**Status:** iOS works fine, Android crashes

---

## 🔴 Critical Issues to Check (Most Likely Causes)

### 1. **Missing FileProvider Configuration** ⚠️ HIGH PRIORITY

**Problem:** `image_picker` and `image_cropper` require FileProvider for Android to access camera/gallery on modern Android versions.

**Symptoms:**
- App crashes when opening camera
- App crashes when picking from gallery
- Works on iOS, fails on Android
- **Crashes on Samsung devices** (Knox security + Scoped Storage)

**Current Status:** ❌ **NOT CONFIGURED**
- No `file_paths.xml` found
- No FileProvider in AndroidManifest.xml

**Solution Required:**

#### Step 1: Create `android/app/src/main/res/xml/file_paths.xml`
```xml
<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <external-files-path name="my_images" path="Pictures" />
    <external-files-path name="my_files" path="." />
    <cache-path name="cache" path="." />
    <external-cache-path name="external_cache" path="." />
</paths>
```

#### Step 2: Add to `AndroidManifest.xml` (inside `<application>` tag)
```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

---

### 2. **Image Cropper Android Configuration** ⚠️ HIGH PRIORITY

**Problem:** `image_cropper` 8.0.2 requires specific Android configuration.

**Current Issue:** Missing UCrop Activity declaration

**Solution Required:**

Add to `AndroidManifest.xml` (inside `<application>` tag):
```xml
<activity
    android:name="com.yalantis.ucrop.UCropActivity"
    android:screenOrientation="portrait"
    android:theme="@style/Theme.AppCompat.Light.NoActionBar"/>
```

---

### 3. **Android 13+ (API 33) Photo Picker Issues** ⚠️ MEDIUM PRIORITY

**Problem:** Samsung Galaxy A16 likely runs Android 13 or 14, which has new photo picker requirements.

**Current Permissions:**
```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" /> ✅ Good
```

**Additional Required:**
```xml
<!-- For Android 13+ (API 33+) -->
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
```

---

### 4. **Scoped Storage & Samsung Knox** ⚠️ MEDIUM PRIORITY

**Problem:** Samsung devices have additional security (Knox) + Android Scoped Storage.

**Solution Required:**

Add to `AndroidManifest.xml` inside `<application>`:
```xml
android:requestLegacyExternalStorage="true"
```

Update to:
```xml
<application
    android:label="JEEVibe"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:requestLegacyExternalStorage="true">
```

---

### 5. **minSdkVersion Too Low** ⚠️ LOW PRIORITY

**Current:** Uses `flutter.minSdkVersion` (likely 21)

**Problem:**
- `image_cropper` 8.0.2 requires minSdk 21+
- Modern camera features work better with minSdk 23+

**Check:** Verify actual minSdk in Flutter SDK

---

### 6. **Memory Issues with Large Images** ⚠️ MEDIUM PRIORITY

**Problem:** Android has stricter memory limits than iOS.

**Current Code:**
```dart
final XFile? image = await _picker.pickImage(
  source: ImageSource.camera,
  imageQuality: 85, // ✅ Good, reduces size
);
```

**Potential Issue:** No maxWidth/maxHeight set

**Recommended:**
```dart
final XFile? image = await _picker.pickImage(
  source: ImageSource.camera,
  imageQuality: 85,
  maxWidth: 1920,    // Add this
  maxHeight: 1920,   // Add this
);
```

---

### 7. **ProGuard/R8 Issues (Release Build Only)** ⚠️ LOW PRIORITY

**If crashes only in release build:**

Add to `android/app/proguard-rules.pro`:
```proguard
-keep class androidx.core.content.FileProvider { *; }
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**
```

---

## 🔧 Step-by-Step Fix Guide

### Priority 1: FileProvider (CRITICAL)

1. **Create file_paths.xml:**
```bash
mkdir -p android/app/src/main/res/xml
```

2. **Create the file** (see content above)

3. **Update AndroidManifest.xml** with FileProvider

### Priority 2: Image Cropper Activity

1. **Add UCropActivity** to AndroidManifest.xml

### Priority 3: Test

1. Run on Samsung Galaxy A16
2. Try camera capture
3. Try gallery pick
4. Check if crash persists

---

## 📊 Diagnostic Commands

### Check Android Logs:
```bash
# Connect device via USB, enable Developer Mode + USB Debugging
adb logcat | grep -E "FATAL|AndroidRuntime|jeevibe"

# Clear logs and reproduce crash
adb logcat -c
adb logcat > crash_log.txt
```

### Check Current Permissions:
```bash
adb shell dumpsys package com.jeevibe.jeevibe_mobile | grep permission
```

### Check minSdkVersion:
```bash
grep -r "minSdk" android/
```

---

## 🎯 Most Likely Root Cause

Based on symptoms (works on iOS, crashes on Android, Samsung device):

**Top 3 Suspects:**
1. **Missing FileProvider** (90% confidence) ← Fix this first
2. **Missing UCrop Activity** (80% confidence) ← Fix this second
3. **Samsung Knox + Scoped Storage** (60% confidence) ← Fix this third

---

## 📝 Implementation Checklist

### Immediate Fixes (Do These First):
- [ ] Create `file_paths.xml`
- [ ] Add FileProvider to AndroidManifest.xml
- [ ] Add UCropActivity to AndroidManifest.xml
- [ ] Add `android:requestLegacyExternalStorage="true"`
- [ ] Add READ_MEDIA_VIDEO permission

### Testing:
- [ ] Test camera capture on Samsung Galaxy A16
- [ ] Test gallery pick on Samsung Galaxy A16
- [ ] Test image cropper on Samsung Galaxy A16
- [ ] Collect crash logs if still failing

### Optional Optimizations:
- [ ] Add maxWidth/maxHeight to image picker
- [ ] Add ProGuard rules (if release build issue)
- [ ] Increase minSdkVersion to 23 (if needed)

---

## 🚨 Red Flags in Current Setup

1. ❌ **No FileProvider** - Required for camera/gallery on Android 7+
2. ❌ **No UCrop Activity** - Required for image_cropper on Android
3. ⚠️ **No error handling for image size** - Could cause OOM on Android
4. ⚠️ **Samsung Knox** - Additional security layer not accounted for

---

## 📚 Reference Documentation

- [image_picker Android Setup](https://pub.dev/packages/image_picker#android)
- [image_cropper Android Setup](https://pub.dev/packages/image_cropper#android)
- [Android FileProvider Guide](https://developer.android.com/reference/androidx/core/content/FileProvider)
- [Android Photo Picker](https://developer.android.com/training/data-storage/shared/photopicker)

---

## 🔍 Next Steps

1. **Implement FileProvider** (highest priority)
2. **Add UCrop Activity** (second priority)
3. **Test on Samsung Galaxy A16**
4. **If still crashing:** Collect adb logcat and analyze stack trace
5. **Report findings** and iterate

---

## 💡 Expected Outcome

After implementing FileProvider + UCrop configuration:
- ✅ Camera should work on Samsung Galaxy A16
- ✅ Gallery should work on Samsung Galaxy A16
- ✅ Image cropping should work
- ✅ No more crashes
- ✅ Parity with iOS behavior
