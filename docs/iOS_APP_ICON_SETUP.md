# iOS App Icon Setup Guide

## Steps to Set App Icon in Xcode

1. **Open Xcode Project:**
   ```bash
   cd mobile/ios
   open Runner.xcworkspace
   ```

2. **Navigate to App Icon:**
   - In Xcode, click on `Runner` in the left sidebar
   - Select the `Runner` target
   - Go to the `General` tab
   - Scroll down to `App Icons and Launch Screen`
   - Click on `AppIcon` under `App Icons Source`

3. **Add Your Icon:**
   - You'll see a grid of icon sizes
   - Drag and drop your logo image (1024x1024px recommended) onto the `1024pt` slot
   - Xcode will automatically generate all required sizes
   - OR manually add images for each size:
     - 20x20 @1x, @2x, @3x
     - 29x29 @1x, @2x, @3x
     - 40x40 @1x, @2x, @3x
     - 60x60 @2x, @3x
     - 76x76 @1x, @2x
     - 83.5x83.5 @2x
     - 1024x1024 @1x

4. **Alternative: Use Asset Catalog:**
   - Right-click on `Assets.xcassets` in the project navigator
   - Select `New Image Set`
   - Name it `AppIcon`
   - Add your images to the appropriate slots

5. **Build and Run:**
   - Clean build folder: `Product > Clean Build Folder` (Shift+Cmd+K)
   - Build: `Product > Build` (Cmd+B)
   - Run on device/simulator

## Recommended Icon Specifications

- **Format**: PNG (no transparency for app icon)
- **Size**: 1024x1024px (square)
- **Background**: Solid color or gradient (no transparency)
- **Content**: Your JEEVibe logo centered

## Quick Command Line Method

If you have a 1024x1024 PNG file:

```bash
# Place your icon at: mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/
# Then update Contents.json to reference it
```

Note: The easiest way is through Xcode's interface as described above.

