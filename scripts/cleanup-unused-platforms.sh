#!/bin/bash
# Clean up watchOS and tvOS to save space
# Keeps iOS simulators and runtimes

echo "🧹 Cleaning up unused watchOS and tvOS components..."
echo ""

# Check what will be deleted
echo "📋 Current runtimes:"
xcrun simctl list runtimes 2>/dev/null
echo ""

# Delete watchOS runtime
echo "🗑️  Removing watchOS runtime..."
xcrun simctl runtime delete "com.apple.CoreSimulator.SimRuntime.watchOS-26-1" 2>/dev/null || echo "   watchOS runtime not found or already deleted"

# Delete tvOS runtime (if exists)
echo "🗑️  Removing tvOS runtime (if exists)..."
xcrun simctl runtime list 2>/dev/null | grep tvOS | awk '{print $NF}' | xargs -I {} xcrun simctl runtime delete {} 2>/dev/null || echo "   tvOS runtime not found"

# Delete Developer Disk Images for watchOS and tvOS
echo "🗑️  Removing watchOS Developer Disk Images..."
rm -rf ~/Library/Developer/DeveloperDiskImages/watchOS_DDI.dmg 2>/dev/null && echo "   ✅ Deleted watchOS_DDI.dmg" || echo "   ⚠️  watchOS_DDI.dmg not found"
rm -rf ~/Library/Developer/DeveloperDiskImages/watchOS_DDI-version.plist 2>/dev/null && echo "   ✅ Deleted watchOS_DDI-version.plist" || echo "   ⚠️  watchOS_DDI-version.plist not found"

echo "🗑️  Removing tvOS Developer Disk Images..."
rm -rf ~/Library/Developer/DeveloperDiskImages/tvOS_DDI.dmg 2>/dev/null && echo "   ✅ Deleted tvOS_DDI.dmg" || echo "   ⚠️  tvOS_DDI.dmg not found"
rm -rf ~/Library/Developer/DeveloperDiskImages/tvOS_DDI-version.plist 2>/dev/null && echo "   ✅ Deleted tvOS_DDI-version.plist" || echo "   ⚠️  tvOS_DDI-version.plist not found"

# Check for any other watchOS/tvOS files
echo ""
echo "🔍 Checking for other watchOS/tvOS files..."
OTHER_FILES=$(find ~/Library/Developer -name "*watchOS*" -o -name "*tvOS*" 2>/dev/null | grep -v "iOS DeviceSupport" | head -5)
if [ -z "$OTHER_FILES" ]; then
    echo "   ✅ No other watchOS/tvOS files found"
else
    echo "   Found additional files:"
    echo "$OTHER_FILES"
    echo "   (These are likely small metadata files, safe to keep)"
fi

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "📊 Remaining runtimes:"
xcrun simctl list runtimes 2>/dev/null | grep -E "iOS|== Runtimes"
echo ""
echo "💾 Space saved: watchOS and tvOS components removed"
echo "✅ iOS simulators and runtimes preserved"

