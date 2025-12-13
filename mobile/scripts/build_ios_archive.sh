#!/bin/bash
set -e

echo "🚀 Building JEEVibe for iOS Archive (Xcode Organizer)"
echo ""

# Navigate to mobile directory
cd "$(dirname "$0")/.." || exit

echo "🧹 Cleaning previous builds..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🍎 Installing CocoaPods dependencies..."
cd ios
pod install
cd ..

echo "📦 Building iOS app for Xcode Archive..."
flutter build ios --release --no-codesign

echo ""
echo "✅ Build complete!"
echo ""
echo "📤 Next steps:"
echo ""
echo "1. Open Xcode workspace:"
echo "   open ios/Runner.xcworkspace"
echo ""
echo "2. In Xcode:"
echo "   - Select 'Any iOS Device' from device dropdown (top left)"
echo "   - Product → Archive (or Cmd+B then Product → Archive)"
echo "   - Wait for archive to complete"
echo ""
echo "3. View in Organizer:"
echo "   - Window → Organizer (Cmd+Shift+O)"
echo "   - Your archive will appear here"
echo "   - Select archive → 'Distribute App'"
echo "   - Choose 'App Store Connect'"
echo "   - Follow the wizard to upload"
echo ""

