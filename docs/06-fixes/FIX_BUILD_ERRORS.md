# Fix Build Errors

## PhaseScriptExecution Error

If you see "Command PhaseScriptExecution failed with a nonzero exit code", try:

1. **Clean everything:**
   ```bash
   cd mobile/ios
   rm -rf Pods Podfile.lock build/
   pod install --repo-update
   cd ..
   flutter clean
   flutter pub get
   ```

2. **In Xcode:**
   - Close Xcode completely
   - Reopen: `cd mobile/ios && open Runner.xcworkspace`
   - Product > Clean Build Folder (Shift+Cmd+K)
   - Product > Build (Cmd+B)

3. **If still failing, check script phases:**
   - In Xcode: Select Runner target > Build Phases
   - Check "Run Script" phases
   - Make sure paths are correct
   - Try unchecking "Based on dependency analysis" for script phases

## Provisioning Profile Error

If you see "Provisioning profile doesn't include the currently selected device":

1. **In Xcode:**
   - Select Runner target
   - Go to "Signing & Capabilities" tab
   - Make sure "Automatically manage signing" is checked
   - Select your Team
   - Make sure your device is selected (not Mac)

2. **Select correct device:**
   - In Xcode toolbar, click device selector
   - Choose your iPhone (not "My Mac" or simulator)
   - Make sure device is connected and trusted

3. **If device not showing:**
   - Unlock your iPhone
   - Trust the computer when prompted
   - In Xcode: Window > Devices and Simulators
   - Verify device is listed

## Common Build Issues

### Pods Out of Sync
```bash
cd mobile/ios
pod install --repo-update
```

### Flutter Clean
```bash
cd mobile
flutter clean
flutter pub get
```

### Xcode DerivedData
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

### Complete Nuclear Clean
```bash
./scripts/clean-rebuild.sh
```

