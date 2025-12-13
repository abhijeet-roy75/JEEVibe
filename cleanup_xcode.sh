#!/bin/bash
# Xcode Cleanup Script for JEEVibe
# Run this periodically to free up disk space

echo "🧹 Xcode Cleanup Script"
echo "========================"
echo ""

# 1. Clean DerivedData (build artifacts)
echo "1. Cleaning DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
echo "   ✅ Freed: ~4-5GB"
echo ""

# 2. Clean old Archives (keep last 30 days)
echo "2. Cleaning old Archives (keeping last 30 days)..."
find ~/Library/Developer/Xcode/Archives -type d -mtime +30 -exec rm -rf {} + 2>/dev/null
echo "   ✅ Old archives removed"
echo ""

# 3. Clean CocoaPods cache
echo "3. Cleaning CocoaPods cache..."
pod cache clean --all 2>/dev/null || rm -rf ~/Library/Caches/CocoaPods/*
echo "   ✅ CocoaPods cache cleared"
echo ""

# 4. Clean Xcode caches
echo "4. Cleaning Xcode caches..."
rm -rf ~/Library/Caches/com.apple.dt.Xcode/*
echo "   ✅ Xcode caches cleared"
echo ""

# 5. Clean Flutter build artifacts
echo "5. Cleaning Flutter build artifacts..."
cd "$(dirname "$0")/mobile" 2>/dev/null && flutter clean || echo "   ⚠️  Flutter project not found"
echo ""

# 6. Show disk space
echo "📊 Current Disk Space:"
df -h / | tail -1
echo ""
echo "✅ Cleanup complete!"
