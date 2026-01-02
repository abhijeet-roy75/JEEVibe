# iOS Build Methods - IPA vs Archive

There are two ways to build iOS apps for TestFlight. Here's the difference:

---

## Method 1: Build IPA Directly (Faster)

**Command:**
```bash
flutter build ipa --release
```

**What it does:**
- Creates an `.ipa` file directly
- Signs the app automatically
- Ready to upload immediately

**Output:**
- `build/ios/ipa/jeevibe_mobile.ipa`

**Upload:**
- Use **Transporter** app (Mac App Store)
- OR use command line with `xcrun altool`

**Pros:**
- ✅ Faster (single command)
- ✅ No Xcode needed for upload
- ✅ Automated signing

**Cons:**
- ❌ Doesn't appear in Xcode Organizer
- ❌ Can't review archive before upload

---

## Method 2: Build Archive in Xcode (Shows in Organizer)

**Steps:**

1. **Build iOS app (no codesign):**
   ```bash
   flutter build ios --release --no-codesign
   ```

2. **Open Xcode:**
   ```bash
   open ios/Runner.xcworkspace
   ```

3. **In Xcode:**
   - Select **"Any iOS Device"** (not a simulator) from device dropdown
   - **Product → Archive**
   - Wait for archive to complete

4. **View in Organizer:**
   - **Window → Organizer** (Cmd+Shift+O)
   - Your archive will appear here
   - Select archive → **Distribute App**

**Pros:**
- ✅ Appears in Xcode Organizer
- ✅ Can review before uploading
- ✅ Better for debugging build issues
- ✅ Can export in different formats

**Cons:**
- ❌ Requires Xcode
- ❌ More steps
- ❌ Manual signing configuration

---

## Which Method to Use?

### Use Method 1 (IPA) if:
- You want the fastest workflow
- You're comfortable with Transporter app
- You don't need to review the archive
- You're doing automated builds

### Use Method 2 (Archive) if:
- You want to see the archive in Organizer
- You need to review the build before upload
- You're debugging build issues
- You prefer Xcode's interface

---

## Quick Reference

### Build IPA (Method 1):
```bash
cd mobile
flutter build ipa --release
# Upload with Transporter app
```

### Build Archive (Method 2):
```bash
cd mobile
flutter build ios --release --no-codesign
open ios/Runner.xcworkspace
# Then: Product → Archive in Xcode
```

---

## Uploading to TestFlight

### Using Transporter (for IPA):
1. Download [Transporter](https://apps.apple.com/app/transporter/id1450874784)
2. Open Transporter
3. Drag `.ipa` file into Transporter
4. Click **"Deliver"**

### Using Xcode Organizer (for Archive):
1. Window → Organizer (Cmd+Shift+O)
2. Select archive
3. Click **"Distribute App"**
4. Choose **"App Store Connect"**
5. Follow wizard

---

## Troubleshooting

### "Archive not showing in Organizer"
- Make sure you selected "Any iOS Device" (not simulator)
- Check that Archive completed successfully
- Try: Product → Clean Build Folder (Shift+Cmd+K), then Archive again

### "IPA build fails"
- Check signing configuration in Xcode
- Verify Apple Developer account is set up
- Check bundle identifier matches App Store Connect

### "Transporter upload fails"
- Verify you're using the correct Apple ID
- Check app is registered in App Store Connect
- Ensure bundle ID matches

