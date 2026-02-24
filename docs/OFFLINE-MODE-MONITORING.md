# Offline Mode - Isar Update Monitoring

**Status:** Waiting for `isar_flutter_libs` SDK 36 compatibility (as of Feb 2026)

## Quick Reference

### Check for Updates
```bash
# From backend directory
node scripts/check-isar-update.js
```

**Run this:** Every 1-2 weeks until update is available

### What We're Waiting For

**Package:** `isar_flutter_libs`
**Current:** 3.1.0+1 (published Apr 2023)
**Issue:** Incompatible with Android SDK 36 (lStar attribute error)
**Need:** Version 3.1.0+2 or 3.2.0 with SDK 36 support

## Monitoring Channels

### 1. Automated Script (Recommended)
```bash
node backend/scripts/check-isar-update.js
```
- Checks pub.dev API for new versions
- Shows changelog and next steps
- Run weekly or set calendar reminder

### 2. GitHub Watch
- URL: https://github.com/isar/isar
- Click "Watch" → "Custom" → Check "Releases"
- Get email on new releases

### 3. Pub.dev Direct
- URL: https://pub.dev/packages/isar_flutter_libs/versions
- Check manually when you think of it

### 4. GitHub Issues Search
- Search: "Android SDK 36" or "compileSdk 36" or "lStar"
- URL: https://github.com/isar/isar/issues
- Consider creating issue if none exists after 1 month

## When Update Is Available

### Step 1: Update pubspec.yaml
```yaml
# In mobile/pubspec.yaml, uncomment and update:
isar_flutter_libs: ^3.1.0+2  # Or whatever new version
```

### Step 2: Test Android Build
```bash
cd mobile
flutter clean
flutter pub get
flutter build apk
```

### Step 3: If Build Succeeds
1. Remove the "DISABLED" comment in pubspec.yaml
2. Update CLAUDE.md to mark as resolved
3. Test offline mode on physical device
4. Update this document with resolution date

### Step 4: If Build Still Fails
- Check error logs
- Verify changelog mentions SDK 36 support
- May need to wait for another version
- Consider alternatives (sqflite, Drift)

## Alternative Solutions

If Isar doesn't update within 6-8 weeks:

### Option A: sqflite
- Pros: Battle-tested, SDK 36 compatible
- Cons: No web support, SQL strings, manual migrations
- Effort: ~3 hours migration

### Option B: Drift (formerly Moor)
- Pros: Type-safe SQL, web support, migrations
- Cons: More complex, steeper learning curve
- Effort: ~4 hours migration

### Option C: Accept Online-Only
- Pros: No work needed, Firebase caches recent data
- Cons: No true offline mode
- Impact: Most users don't notice (competitors are online-only)

## Current Workaround

The app gracefully degrades to online-only:
- `database_service.dart` returns early on web (unchanged)
- Offline features disabled but don't crash
- Users can still use all core features online
- Firebase provides basic caching for recent data

## Why We Chose to Wait

1. **Isar is superior** - Better performance, web support, DX
2. **Code already written** - Schemas and logic in place
3. **No urgent need** - Users haven't complained about offline mode
4. **Update likely soon** - SDK 36 is standard, Isar is maintained
5. **Avoid throwaway work** - Migration to sqflite then back to Isar wastes time

## Communication

If users ask about offline mode:
> "Offline mode is temporarily unavailable while we wait for a library update to support the latest Android version. We expect this to be resolved within the next few weeks. All core features work perfectly online, and Firebase provides caching for recent content."

## Timeline Estimate

- **Week 1-2:** Check weekly, monitor GitHub
- **Week 3-4:** If no update, create GitHub issue
- **Week 5-6:** If no response, consider sqflite migration
- **Week 7-8:** If still nothing, migrate or accept online-only

Last updated: February 24, 2026
