#!/bin/bash
# Fix iOS App Icons and Launch Image for TestFlight
# This script fixes the app icon naming and launch image issues

set -e

IOS_ASSETS_DIR="mobile/ios/Runner/Assets.xcassets"
APP_ICON_DIR="${IOS_ASSETS_DIR}/AppIcon.appiconset"
LAUNCH_IMAGE_DIR="${IOS_ASSETS_DIR}/LaunchImage.imageset"

echo "🔧 Fixing iOS App Icons and Launch Image..."
echo ""

# Check if we have a source logo
SOURCE_LOGO="mobile/assets/images/jeevibe_logo.jpeg"
if [ ! -f "$SOURCE_LOGO" ]; then
    echo "⚠️  Warning: Source logo not found at $SOURCE_LOGO"
    echo "   Please ensure you have a 1024x1024 source image"
    exit 1
fi

# Step 1: Regenerate app icons with proper naming
echo "📱 Step 1: Regenerating app icons with proper sizes..."
echo "   Using source: $SOURCE_LOGO"

# Create a temporary 1024x1024 PNG from the source
TEMP_1024="${APP_ICON_DIR}/temp_1024.png"
sips -s format png -z 1024 1024 "$SOURCE_LOGO" --out "$TEMP_1024" > /dev/null 2>&1

# Generate all required icon sizes with proper names
echo "   Generating iPhone icons..."
sips -z 40 40 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-20x20@2x.png" > /dev/null 2>&1
sips -z 60 60 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-20x20@3x.png" > /dev/null 2>&1
sips -z 29 29 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-29x29@1x.png" > /dev/null 2>&1
sips -z 58 58 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-29x29@2x.png" > /dev/null 2>&1
sips -z 87 87 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-29x29@3x.png" > /dev/null 2>&1
sips -z 80 80 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-40x40@2x.png" > /dev/null 2>&1
sips -z 120 120 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-40x40@3x.png" > /dev/null 2>&1
sips -z 120 120 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-60x60@2x.png" > /dev/null 2>&1
sips -z 180 180 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-60x60@3x.png" > /dev/null 2>&1

echo "   Generating iPad icons..."
sips -z 20 20 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-20x20@1x-iPad.png" > /dev/null 2>&1
sips -z 40 40 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-20x20@2x-iPad.png" > /dev/null 2>&1
sips -z 29 29 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-29x29@1x-iPad.png" > /dev/null 2>&1
sips -z 58 58 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-29x29@2x-iPad.png" > /dev/null 2>&1
sips -z 40 40 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-40x40@1x-iPad.png" > /dev/null 2>&1
sips -z 80 80 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-40x40@2x-iPad.png" > /dev/null 2>&1
sips -z 76 76 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-76x76@1x-iPad.png" > /dev/null 2>&1
sips -z 152 152 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-76x76@2x-iPad.png" > /dev/null 2>&1
sips -z 167 167 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-83.5x83.5@2x-iPad.png" > /dev/null 2>&1

# App Store icon
sips -z 1024 1024 "$TEMP_1024" --out "${APP_ICON_DIR}/Icon-App-1024x1024@1x.png" > /dev/null 2>&1
cp "$TEMP_1024" "${APP_ICON_DIR}/1024.png"

# Step 2: Update Contents.json with proper filenames
echo "📝 Step 2: Updating AppIcon Contents.json..."

cat > "${APP_ICON_DIR}/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "Icon-App-20x20@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-App-20x20@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-App-29x29@1x.png",
      "idiom" : "iphone",
      "scale" : "1x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-App-29x29@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-App-29x29@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-App-40x40@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-App-40x40@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-App-60x60@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "filename" : "Icon-App-60x60@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "filename" : "Icon-App-20x20@1x-iPad.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-App-20x20@2x-iPad.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-App-29x29@1x-iPad.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-App-29x29@2x-iPad.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-App-40x40@1x-iPad.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-App-40x40@2x-iPad.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-App-76x76@1x-iPad.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "76x76"
    },
    {
      "filename" : "Icon-App-76x76@2x-iPad.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "76x76"
    },
    {
      "filename" : "Icon-App-83.5x83.5@2x-iPad.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "83.5x83.5"
    },
    {
      "filename" : "Icon-App-1024x1024@1x.png",
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# Step 3: Fix Launch Image
echo "🚀 Step 3: Fixing Launch Image..."

# Generate launch images from source
LAUNCH_2X="${LAUNCH_IMAGE_DIR}/LaunchImage@2x.png"
LAUNCH_3X="${LAUNCH_IMAGE_DIR}/LaunchImage@3x.png"

# Generate launch images (typically 828x1792 for @2x and 1242x2688 for @3x)
# But we'll use a simpler approach - generate from logo centered
echo "   Generating launch images..."
sips -z 828 828 "$TEMP_1024" --out "$LAUNCH_2X" > /dev/null 2>&1
sips -z 1242 1242 "$TEMP_1024" --out "$LAUNCH_3X" > /dev/null 2>&1

# Update LaunchImage Contents.json to remove JPEG and use PNGs
cat > "${LAUNCH_IMAGE_DIR}/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "LaunchImage@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "filename" : "LaunchImage@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# Clean up temp file
rm -f "$TEMP_1024"

echo ""
echo "✅ iOS assets fixed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Open Xcode: cd mobile/ios && open Runner.xcworkspace"
echo "2. In Xcode: Product > Clean Build Folder (Shift+Cmd+K)"
echo "3. Verify icons: Runner > Runner target > General tab > App Icons"
echo "4. Build and archive: Product > Archive"
echo ""
echo "⚠️  Note: Old icon files with incorrect names are still in the directory."
echo "   You may want to remove them manually or they'll be ignored by Xcode."

