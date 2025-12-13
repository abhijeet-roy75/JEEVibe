#!/bin/bash
set -e

echo "🚀 Building JEEVibe for iOS (TestFlight)"
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

echo "🍎 Building IPA directly..."
flutter build ipa --release

echo ""
echo "✅ Build complete!"
echo ""
echo "📦 IPA location:"
echo "   $(pwd)/build/ios/ipa/jeevibe_mobile.ipa"
echo ""
echo "📤 Upload using Transporter app:"
echo "   1. Open Transporter app (from Mac App Store)"
echo "   2. Drag the .ipa file into Transporter"
echo "   3. Click 'Deliver'"
echo ""
echo "💡 Note: This creates an IPA file, not an Xcode archive."
echo "   To see archive in Xcode Organizer, use: ./scripts/build_ios_archive.sh"
echo ""

