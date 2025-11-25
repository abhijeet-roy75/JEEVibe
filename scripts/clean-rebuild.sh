#!/bin/bash
# Complete cleanup and rebuild script for JEEVibe iOS app

set -e

echo "🧹 Starting complete cleanup..."

# 1. Clean Flutter
echo "📱 Cleaning Flutter build..."
cd "$(dirname "$0")/mobile"
flutter clean

# 2. Clean Xcode DerivedData
echo "🔨 Cleaning Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 3. Clean iOS build folder
echo "📦 Cleaning iOS build folder..."
cd ios
rm -rf build/
rm -rf Pods/
rm -f Podfile.lock

# 4. Clean pod cache
echo "🧼 Cleaning CocoaPods cache..."
pod cache clean --all 2>/dev/null || true

# 5. Reinstall pods
echo "📥 Reinstalling CocoaPods dependencies..."
pod install --repo-update

# 6. Get Flutter dependencies
echo "📚 Getting Flutter dependencies..."
cd ..
flutter pub get

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Open Xcode: cd mobile/ios && open Runner.xcworkspace"
echo "2. In Xcode: Product > Clean Build Folder (Shift+Cmd+K)"
echo "3. In Xcode: Product > Build (Cmd+B)"
echo "4. In Xcode: Product > Run (Cmd+R)"
echo ""
echo "Or use Flutter CLI:"
echo "  cd mobile && flutter run"

