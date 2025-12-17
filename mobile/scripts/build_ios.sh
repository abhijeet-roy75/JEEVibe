#!/bin/bash
set -e

echo "🚀 Building JEEVibe for iOS Archive (Xcode)"
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
flutter build ios --release

echo ""
echo "✅ Build complete!"
echo ""
echo "📤 Next steps to archive and upload:"
echo ""
echo "1. Open Xcode workspace:"
echo "   open ios/Runner.xcworkspace"
echo ""
echo "2. In Xcode:"
echo "   - Select 'Any iOS Device' from device dropdown (top left)"
echo "   - Product → Archive"
echo "   - Wait for archive to complete (~2-3 minutes)"
echo ""
echo "3. In the Organizer window that appears:"
echo "   - Select your archive"
echo "   - Click 'Distribute App'"
echo "   - Choose 'App Store Connect'"
echo "   - Follow the wizard to upload to TestFlight"
echo ""
echo "💡 Tip: You can also access Organizer anytime via Window → Organizer (Cmd+Shift+O)"
echo ""

