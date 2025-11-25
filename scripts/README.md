# Scripts Directory

This directory contains utility scripts for the JEEVibe project.

## Available Scripts

### `clean-rebuild.sh`
Complete cleanup and rebuild script for iOS app.
- Cleans Flutter build cache
- Cleans Xcode DerivedData
- Reinstalls CocoaPods
- Regenerates Flutter dependencies

**Usage:**
```bash
./scripts/clean-rebuild.sh
```

### `generate-app-icons.sh`
Generates all required iOS app icon sizes from a single 1024x1024 source image.

**Usage:**
```bash
./scripts/generate-app-icons.sh <source_image> [output_dir]
```

**Example:**
```bash
./scripts/generate-app-icons.sh mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/jeevibe_logo.jpeg
```

### `setup-xcode.sh`
Sets up Xcode for Flutter development.
- Switches to Xcode command-line tools
- Accepts Xcode license
- Runs first launch setup

**Usage:**
```bash
./scripts/setup-xcode.sh
```

### `cleanup-unused-platforms.sh`
Removes unused Xcode platform downloads (watchOS, tvOS) to save disk space.

**Usage:**
```bash
./scripts/cleanup-unused-platforms.sh
```

## Backend Scripts

Backend-specific scripts are located in the `backend/` directory:
- `backend/start.sh` - Start backend server in interactive mode
- `backend/start-background.sh` - Start backend server in background
- `backend/kill-server.sh` - Kill any running backend server

## Notes

- All scripts are executable (`chmod +x`)
- Scripts should be run from the project root directory
- Some scripts require macOS-specific tools (e.g., `sips` for image processing)

