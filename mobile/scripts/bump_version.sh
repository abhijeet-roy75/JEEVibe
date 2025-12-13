#!/bin/bash

# Usage: ./bump_version.sh [major|minor|patch]
# Example: ./bump_version.sh patch

if [ -z "$1" ]; then
  echo "Usage: ./bump_version.sh [major|minor|patch]"
  echo ""
  echo "Examples:"
  echo "  ./bump_version.sh patch  # 1.0.0+5 → 1.0.1+6"
  echo "  ./bump_version.sh minor  # 1.0.0+5 → 1.1.0+6"
  echo "  ./bump_version.sh major  # 1.0.0+5 → 2.0.0+6"
  exit 1
fi

# Navigate to mobile directory
cd "$(dirname "$0")/.." || exit

# Get current version
CURRENT=$(grep "^version:" pubspec.yaml | cut -d " " -f 2)
VERSION_NAME=$(echo $CURRENT | cut -d "+" -f 1)
VERSION_CODE=$(echo $CURRENT | cut -d "+" -f 2)

# Parse version parts
MAJOR=$(echo $VERSION_NAME | cut -d "." -f 1)
MINOR=$(echo $VERSION_NAME | cut -d "." -f 2)
PATCH=$(echo $VERSION_NAME | cut -d "." -f 3)

# Increment based on argument
case $1 in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  *)
    echo "❌ Invalid argument: $1"
    echo "   Use: major, minor, or patch"
    exit 1
    ;;
esac

# Increment version code
VERSION_CODE=$((VERSION_CODE + 1))

# New version
NEW_VERSION="$MAJOR.$MINOR.$PATCH+$VERSION_CODE"

# Update pubspec.yaml (works on both macOS and Linux)
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  sed -i '' "s/^version:.*/version: $NEW_VERSION/" pubspec.yaml
else
  # Linux
  sed -i "s/^version:.*/version: $NEW_VERSION/" pubspec.yaml
fi

echo "✅ Version updated:"
echo "   $CURRENT → $NEW_VERSION"
echo ""
echo "📝 Updated pubspec.yaml"

