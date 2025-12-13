#!/bin/bash
set -e

echo "🚀 Building JEEVibe for Android (Play Store)"
echo ""

# Navigate to mobile directory
cd "$(dirname "$0")/.." || exit

# Check if key.properties exists
if [ ! -f "android/key.properties" ]; then
  echo "❌ Error: android/key.properties not found!"
  echo ""
  echo "📝 Setup instructions:"
  echo "   1. Generate keystore:"
  echo "      keytool -genkey -v -keystore ~/upload-keystore.jks \\"
  echo "        -keyalg RSA -keysize 2048 -validity 10000 -alias upload"
  echo ""
  echo "   2. Copy template:"
  echo "      cp android/key.properties.template android/key.properties"
  echo ""
  echo "   3. Edit android/key.properties with your keystore details"
  echo ""
  exit 1
fi

echo "🧹 Cleaning previous builds..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🤖 Building Android App Bundle (AAB)..."
flutter build appbundle --release

echo ""
echo "✅ Build complete!"
echo ""
echo "📦 AAB location:"
echo "   $(pwd)/build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "📤 Next steps:"
echo "   1. Go to Google Play Console"
echo "   2. Select your app → Production (or Testing)"
echo "   3. Create new release"
echo "   4. Upload app-release.aab"
echo "   5. Fill in release notes"
echo "   6. Review and roll out"
echo ""

