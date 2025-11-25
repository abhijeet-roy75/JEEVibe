#!/bin/bash
# Xcode Setup Script for JEEVibe
# Run this after Xcode installation completes

echo "🔧 Setting up Xcode for Flutter development..."
echo ""

# Check if Xcode is installed
if [ ! -d "/Applications/Xcode.app" ]; then
    echo "❌ Xcode not found. Please install Xcode from App Store first."
    exit 1
fi

echo "✅ Xcode found at /Applications/Xcode.app"
echo ""

# Switch to Xcode
echo "📝 Switching to Xcode..."
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Accept license
echo "📝 Accepting Xcode license..."
sudo xcodebuild -license accept

# Run first launch
echo "📝 Running Xcode first launch (this may take a few minutes)..."
sudo xcodebuild -runFirstLaunch

# Skip platform downloads - not needed for physical device testing
# iOS simulators will download automatically if/when you use them
echo "⏭️  Skipping platform downloads (not needed for physical device)"

echo ""
echo "✅ Xcode setup complete!"
echo ""
echo "Next steps:"
echo "1. Open Xcode once to complete setup"
echo "2. Run: flutter doctor"
echo "3. Run: flutter devices (should show iOS simulators)"
echo "4. Run: flutter run (in mobile/ directory)"

