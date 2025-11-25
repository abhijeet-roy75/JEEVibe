#!/bin/bash
# Generate all iOS app icon sizes from a single 1024x1024 source image
# Usage: ./generate-app-icons.sh <source_image> [output_dir]

set -e

SOURCE_IMAGE="$1"
OUTPUT_DIR="${2:-mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset}"

if [ -z "$SOURCE_IMAGE" ]; then
  echo "Usage: $0 <source_image> [output_dir]"
  echo "Example: $0 jeevibe_logo.jpeg"
  exit 1
fi

if [ ! -f "$SOURCE_IMAGE" ]; then
  echo "Error: Source image not found: $SOURCE_IMAGE"
  exit 1
fi

# Check if sips is available (macOS built-in)
if ! command -v sips &> /dev/null; then
  echo "Error: sips command not found. This script requires macOS."
  exit 1
fi

echo "🎨 Generating iOS app icons from: $SOURCE_IMAGE"
echo "📁 Output directory: $OUTPUT_DIR"
echo ""

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Convert source to PNG if needed (iOS requires PNG for icons)
TEMP_PNG="${OUTPUT_DIR}/temp_source.png"
sips -s format png "$SOURCE_IMAGE" --out "$TEMP_PNG" > /dev/null 2>&1

# Generate all required icon sizes
echo "Generating icon sizes..."

# iPhone icons
sips -z 40 40 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-20x20@2x.png" > /dev/null 2>&1
sips -z 60 60 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-20x20@3x.png" > /dev/null 2>&1
sips -z 29 29 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-29x29@1x.png" > /dev/null 2>&1
sips -z 58 58 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-29x29@2x.png" > /dev/null 2>&1
sips -z 87 87 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-29x29@3x.png" > /dev/null 2>&1
sips -z 80 80 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-40x40@2x.png" > /dev/null 2>&1
sips -z 120 120 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-40x40@3x.png" > /dev/null 2>&1
sips -z 120 120 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-60x60@2x.png" > /dev/null 2>&1
sips -z 180 180 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-60x60@3x.png" > /dev/null 2>&1

# iPad icons
sips -z 20 20 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-20x20@1x.png" > /dev/null 2>&1
sips -z 40 40 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-20x20@2x.png" > /dev/null 2>&1
sips -z 29 29 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-29x29@1x.png" > /dev/null 2>&1
sips -z 58 58 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-29x29@2x.png" > /dev/null 2>&1
sips -z 40 40 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-40x40@1x.png" > /dev/null 2>&1
sips -z 80 80 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-40x40@2x.png" > /dev/null 2>&1
sips -z 76 76 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-76x76@1x.png" > /dev/null 2>&1
sips -z 152 152 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-76x76@2x.png" > /dev/null 2>&1
sips -z 167 167 "$TEMP_PNG" --out "${OUTPUT_DIR}/Icon-App-83.5x83.5@2x.png" > /dev/null 2>&1

# App Store icon (1024x1024)
sips -z 1024 1024 "$TEMP_PNG" --out "${OUTPUT_DIR}/AppIcon-1024.png" > /dev/null 2>&1

# Clean up temp file
rm -f "$TEMP_PNG"

echo "✅ All icon sizes generated successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Open Xcode: cd mobile/ios && open Runner.xcworkspace"
echo "2. In Xcode: Click on Runner > Runner target > General tab"
echo "3. Scroll to 'App Icons and Launch Screen'"
echo "4. Click on 'AppIcon' - you should see all icons populated"
echo "5. Clean build: Product > Clean Build Folder (Shift+Cmd+K)"
echo "6. Build and run: Product > Run (Cmd+R)"

