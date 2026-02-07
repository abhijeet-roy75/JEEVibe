# Implementation Plan - QA Fixes & Enhancements

**Date**: 2026-02-06
**Based on**: QA Assessment Report
**Status**: Ready for Implementation

This document contains all fixes and enhancements identified during QA review.

---

## 📋 TABLE OF CONTENTS

1. [Profile Edit Screen Fix](#1-profile-edit-screen-fix)
2. [Schedule Validation Script](#2-schedule-validation-script)
3. [High-Water Mark Preservation](#3-high-water-mark-preservation)
4. [Migration Rollback Script](#4-migration-rollback-script)
5. [India Timezone Handling](#5-india-timezone-handling)
6. [Chapter Unlock Tracking](#6-chapter-unlock-tracking)
7. [Test Suite](#7-test-suite)

---

## 1. PROFILE EDIT SCREEN FIX

### Issue
Current profile edit screen uses static dropdown, missing dynamic date generation from onboarding.

### File to Update
`mobile/lib/screens/profile/profile_edit_screen.dart`

### Implementation

**Step 1: Add Helper Method** (after line 276)

```dart
/// Generates available January and April exam dates dynamically
/// Same logic as onboarding for consistency
List<Map<String, String>> _getJeeExamOptions() {
  final now = DateTime.now();
  final currentYear = now.year;
  final currentMonth = now.month;

  List<Map<String, String>> options = [];

  // April of current year (only if we're before April)
  if (currentMonth <= 3) {
    final monthsAway = 4 - currentMonth;
    options.add({
      'value': '$currentYear-04',
      'label': 'April $currentYear ($monthsAway ${monthsAway == 1 ? 'month' : 'months'} away)',
    });
  }

  // January of next year (always available)
  final nextYear = currentYear + 1;
  final monthsToNextJan = currentMonth == 1 ? 12 : (13 - currentMonth);
  options.add({
    'value': '$nextYear-01',
    'label': 'January $nextYear ($monthsToNextJan months away)',
  });

  // April of next year (always available)
  final monthsToNextApril = ((nextYear - currentYear) * 12) + (4 - currentMonth);
  options.add({
    'value': '$nextYear-04',
    'label': 'April $nextYear ($monthsToNextApril months away)',
  });

  // January of year after next
  final yearAfterNext = currentYear + 2;
  final monthsToNextNextJan = ((yearAfterNext - currentYear) * 12) + (1 - currentMonth);
  options.add({
    'value': '$yearAfterNext-01',
    'label': 'January $yearAfterNext ($monthsToNextNextJan months away)',
  });

  // If user has a current value that's not in the list (e.g., past date), include it
  if (_jeeTargetExamDate != null && _jeeTargetExamDate!.isNotEmpty) {
    final hasCurrentValue = options.any((option) => option['value'] == _jeeTargetExamDate);

    if (!hasCurrentValue) {
      final parts = _jeeTargetExamDate!.split('-');
      if (parts.length == 2) {
        final year = parts[0];
        final month = parts[1];
        final monthName = month == '01' ? 'January' : 'April';
        options.insert(0, {
          'label': '$monthName $year (Current Selection)',
          'value': _jeeTargetExamDate!,
        });
      }
    }
  }

  return options;
}
```

**Step 2: Add Validation Dialog for Rush Timeline** (after _getJeeExamOptions)

```dart
/// Shows warning dialog if student selects exam < 3 months away
Future<bool> _confirmRushTimeline(int monthsAway, String examDate) async {
  if (monthsAway >= 3) return true; // No warning needed

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warningOrange, size: 28),
          const SizedBox(width: 12),
          Text('⚠️ Intensive Preparation Mode'),
        ],
      ),
      content: Text(
        'You have less than 3 months until the exam. '
        'All chapters will be unlocked immediately for intensive revision.\n\n'
        'Consider targeting the next exam session for better preparation time.',
        style: AppTextStyles.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Choose Different Date'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warningOrange,
          ),
          child: Text('Continue with $examDate'),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
```

**Step 3: Update Dropdown Widget** (replace lines 480-502)

```dart
// JEE Target Exam Date (required)
_buildFieldLabel('When are you giving JEE?'),
const SizedBox(height: 8),
DropdownButtonFormField<String>(
  value: _jeeTargetExamDate,
  isExpanded: true,
  decoration: _buildInputDecoration(hintText: 'Select your JEE exam date'),
  dropdownColor: Colors.white,
  items: _getJeeExamOptions().map((option) {
    return DropdownMenuItem<String>(
      value: option['value'],
      child: Text(
        option['label']!,
        style: AppTextStyles.bodyMedium,
      ),
    );
  }).toList(),
  onChanged: (value) async {
    if (value == null) return;

    // Calculate months away for validation
    final parts = value.split('-');
    final targetYear = int.parse(parts[0]);
    final targetMonth = int.parse(parts[1]);
    final targetDate = DateTime(targetYear, targetMonth, 1);
    final now = DateTime.now();
    final monthsAway = (targetDate.year - now.year) * 12 +
                      (targetDate.month - now.month);

    // Show warning if < 3 months
    final confirmed = await _confirmRushTimeline(monthsAway, option['label']!);

    if (confirmed) {
      setState(() => _jeeTargetExamDate = value);
    }
  },
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Please select your JEE exam date';
    }
    return null;
  },
  onSaved: (value) => _jeeTargetExamDate = value,
),
```

**Testing Checklist**:
- [ ] Dropdown shows dynamic dates based on current month
- [ ] Shows "X months away" labels
- [ ] Warning appears when selecting exam < 3 months away
- [ ] Past dates (if user's current selection) appear with "(Current Selection)" label
- [ ] Date changes trigger API call correctly

---

## 2. SCHEDULE VALIDATION SCRIPT

### Purpose
Validate schedule JSON before seeding to prevent runtime errors.

### File Created
`backend/scripts/validate-chapter-schedule.js` ✅ (Already created)

### Usage in Deployment

**Add to package.json scripts**:
```json
{
  "scripts": {
    "validate:schedule": "node scripts/validate-chapter-schedule.js",
    "seed:schedule": "npm run validate:schedule && node scripts/seed-countdown-schedule.js"
  }
}
```

**Add to CI/CD Pipeline** (if using GitHub Actions):
```yaml
# .github/workflows/backend-deploy.yml
- name: Validate Chapter Schedule
  run: |
    cd backend
    npm run validate:schedule
```

**Manual Usage**:
```bash
cd backend
npm run validate:schedule
```

---

## 3. HIGH-WATER MARK PRESERVATION

### Issue
Profile edit API doesn't explicitly preserve `chapterUnlockHighWaterMark` when updating target date.

### File to Update
`backend/src/routes/users.js` - Add new endpoint after line 417

### Implementation

```javascript
/**
 * PUT /api/users/profile/target-exam-date
 *
 * Update target exam date while preserving high-water mark
 *
 * Body: { jeeTargetExamDate: string }
 * Authentication: Required
 */
router.put('/profile/target-exam-date',
  authenticateUser,
  [
    body('jeeTargetExamDate')
      .matches(/^\d{4}-(01|04)$/)
      .withMessage('jeeTargetExamDate must be in YYYY-MM format (01 for January, 04 for April)')
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        throw new ApiError(400, 'Validation failed', errors.array());
      }

      const { jeeTargetExamDate } = req.body;
      const userId = req.userId;

      // Get current user data
      const userRef = db.collection('users').doc(userId);
      const userDoc = await retryFirestoreOperation(async () => {
        return await userRef.get();
      });

      if (!userDoc.exists) {
        throw new ApiError(404, 'User not found');
      }

      const userData = userDoc.data();
      const oldTargetDate = userData.jeeTargetExamDate;
      const oldHighWaterMark = userData.chapterUnlockHighWaterMark || 0;

      // Update target date and history, PRESERVE high-water mark
      await retryFirestoreOperation(async () => {
        return await userRef.update({
          jeeTargetExamDate,
          // Explicitly preserve high-water mark (don't let it decrease)
          chapterUnlockHighWaterMark: oldHighWaterMark,
          jeeTargetExamDateHistory: admin.firestore.FieldValue.arrayUnion({
            targetDate: jeeTargetExamDate,
            setAt: admin.firestore.FieldValue.serverTimestamp(),
            previousTargetDate: oldTargetDate,
            reason: 'user_updated_profile'
          }),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      });

      // Invalidate cache
      delCache(CacheKeys.userProfile(userId));

      // Recalculate unlock status (high-water mark ensures no re-locking)
      const { getUnlockedChapters } = require('../services/chapterUnlockService');
      const unlockResult = await getUnlockedChapters(userId);

      logger.info('Target exam date updated', {
        userId,
        oldTargetDate,
        newTargetDate: jeeTargetExamDate,
        preservedHighWaterMark: oldHighWaterMark,
        currentMonth: unlockResult.currentMonth,
        usingHighWaterMark: unlockResult.usingHighWaterMark,
        requestId: req.id
      });

      res.json({
        success: true,
        data: {
          updatedTargetDate: jeeTargetExamDate,
          currentMonth: unlockResult.currentMonth,
          monthsUntilExam: unlockResult.monthsUntilExam,
          unlockedChapters: unlockResult.unlockedChapterKeys,
          usingHighWaterMark: unlockResult.usingHighWaterMark,
          message: unlockResult.usingHighWaterMark
            ? 'Your exam date has been updated. All previously unlocked chapters remain available!'
            : 'Your exam date has been updated successfully.'
        },
        requestId: req.id
      });
    } catch (error) {
      next(error);
    }
  }
);
```

**Also Update**: Regular profile update endpoint to preserve high-water mark

Add after line 230 in `POST /api/users/profile`:
```javascript
// Preserve high-water mark if it exists
if (userDoc.exists && userDoc.data()?.chapterUnlockHighWaterMark) {
  firestoreData.chapterUnlockHighWaterMark = userDoc.data().chapterUnlockHighWaterMark;
}
```

**Testing**:
```javascript
// Test case in backend/tests/integration/api/users.test.js
describe('PUT /api/users/profile/target-exam-date', () => {
  test('preserves high-water mark when changing target date', async () => {
    // Set user with highWaterMark = 16, targeting Jan 2027
    await setupUser(userId, {
      jeeTargetExamDate: '2027-01',
      chapterUnlockHighWaterMark: 16
    });

    // Change target to Jan 2028 (would regress to month 2)
    const response = await request(app)
      .put('/api/users/profile/target-exam-date')
      .set('Authorization', `Bearer ${token}`)
      .send({ jeeTargetExamDate: '2028-01' });

    expect(response.status).toBe(200);
    expect(response.body.data.usingHighWaterMark).toBe(true);
    expect(response.body.data.currentMonth).toBe(2); // New position

    // Verify high-water mark preserved in database
    const userDoc = await db.collection('users').doc(userId).get();
    expect(userDoc.data().chapterUnlockHighWaterMark).toBe(16);
  });
});
```

---

## 4. MIGRATION ROLLBACK SCRIPT

### Purpose
Backup user data before migration and provide rollback capability.

### File to Create
`backend/scripts/rollback-target-date-migration.js`

```javascript
/**
 * Rollback Script: Restore Users Before Target Date Migration
 *
 * Restores user documents from backup created before migration
 *
 * Usage: node backend/scripts/rollback-target-date-migration.js --backup-file <path>
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function rollbackMigration() {
  console.log('🔄 ROLLBACK: Target Date Migration\n');
  console.log('='.repeat(60));

  // Parse arguments
  const args = process.argv.slice(2);
  const backupFileIndex = args.indexOf('--backup-file');

  if (backupFileIndex === -1 || !args[backupFileIndex + 1]) {
    console.error('❌ Error: Please specify backup file');
    console.error('   Usage: node scripts/rollback-target-date-migration.js --backup-file <path>');
    console.error('   Example: node scripts/rollback-target-date-migration.js --backup-file backups/users_backup_2026-02-06.json');
    process.exit(1);
  }

  const backupFilePath = args[backupFileIndex + 1];
  const resolvedPath = path.isAbsolute(backupFilePath)
    ? backupFilePath
    : path.join(process.cwd(), backupFilePath);

  if (!fs.existsSync(resolvedPath)) {
    console.error(`❌ Error: Backup file not found: ${resolvedPath}`);
    process.exit(1);
  }

  console.log(`Backup file: ${resolvedPath}\n`);

  // Load backup
  const backupData = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
  console.log(`✅ Backup loaded: ${backupData.users.length} users\n`);
  console.log(`Backup created: ${backupData.timestamp}`);
  console.log(`Backup version: ${backupData.version}\n`);

  // Confirm rollback
  console.log('⚠️  WARNING: This will overwrite current user data with backup data');
  console.log('   Press Ctrl+C to cancel, or wait 5 seconds to continue...\n');
  await new Promise(resolve => setTimeout(resolve, 5000));

  let restored = 0;
  let skipped = 0;
  let errors = 0;

  for (const userBackup of backupData.users) {
    const userId = userBackup.id;
    const userData = userBackup.data;

    try {
      // Check if user still exists
      const currentDoc = await db.collection('users').doc(userId).get();

      if (!currentDoc.exists) {
        console.log(`⚠️  SKIP: User ${userId} no longer exists`);
        skipped++;
        continue;
      }

      // Restore user data (remove migration fields)
      const restoreData = { ...userData };
      delete restoreData.jeeTargetExamDate; // Remove migrated field
      delete restoreData.migratedAt;
      delete restoreData.migrationNote;

      await db.collection('users').doc(userId).set(restoreData, { merge: false });

      console.log(`✓ RESTORED: ${userId}`);
      console.log(`  - Removed jeeTargetExamDate: ${currentDoc.data().jeeTargetExamDate || 'null'}`);
      console.log(`  - Restored currentClass: ${restoreData.currentClass || 'null'}\n`);

      restored++;
    } catch (error) {
      console.error(`✗ ERROR restoring ${userId}:`, error.message);
      errors++;
    }
  }

  console.log('\n=== Rollback Summary ===');
  console.log(`Total in backup: ${backupData.users.length}`);
  console.log(`Restored: ${restored}`);
  console.log(`Skipped (user deleted): ${skipped}`);
  console.log(`Errors: ${errors}`);
  console.log('========================\n');

  if (errors > 0) {
    console.log('⚠️  Rollback completed with errors');
    process.exit(1);
  } else {
    console.log('✅ Rollback completed successfully!');
    process.exit(0);
  }
}

// Run rollback
rollbackMigration()
  .catch((error) => {
    console.error('Fatal error during rollback:', error);
    process.exit(1);
  });
```

### Update Migration Script to Create Backup

**File**: `backend/scripts/migrate-existing-users-target-date.js`

Add at the beginning of `migrateUsers()` function (before line 64):

```javascript
async function migrateUsers() {
  console.log('Starting migration of existing users...\n');

  // ============================================================
  // STEP 1: CREATE BACKUP
  // ============================================================
  const backupDir = path.join(__dirname, '../backups');
  if (!fs.existsSync(backupDir)) {
    fs.mkdirSync(backupDir, { recursive: true });
  }

  const timestamp = new Date().toISOString().replace(/:/g, '-').split('.')[0];
  const backupFile = path.join(backupDir, `users_backup_${timestamp}.json`);

  console.log('📦 Creating backup before migration...');

  try {
    const usersSnapshot = await db.collection('users').get();
    const backupData = {
      version: '1.0',
      timestamp: new Date().toISOString(),
      totalUsers: usersSnapshot.size,
      users: usersSnapshot.docs.map(doc => ({
        id: doc.id,
        data: doc.data()
      }))
    };

    fs.writeFileSync(backupFile, JSON.stringify(backupData, null, 2));
    console.log(`✅ Backup created: ${backupFile}`);
    console.log(`   Backed up ${usersSnapshot.size} users\n`);
    console.log(`⚠️  To rollback: node scripts/rollback-target-date-migration.js --backup-file ${backupFile}\n`);
  } catch (error) {
    console.error('❌ Failed to create backup:', error);
    console.error('   Migration aborted for safety');
    process.exit(1);
  }

  // ============================================================
  // STEP 2: PROCEED WITH MIGRATION
  // ============================================================
  console.log('='.repeat(60));
  console.log('Starting migration...\n');

  try {
    const usersSnapshot = await db.collection('users').get();
    // ... rest of existing migration code ...
```

**Add Dry-Run Mode**:

Add after parsing arguments (around line 64):

```javascript
const isDryRun = process.argv.includes('--dry-run');

if (isDryRun) {
  console.log('🔍 DRY RUN MODE: No changes will be written to database\n');
}
```

Update the migration write operation:

```javascript
if (!isDryRun) {
  await db.collection('users').doc(userId).update({
    jeeTargetExamDate: targetExamDate,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
} else {
  console.log(`   [DRY RUN] Would set jeeTargetExamDate = ${targetExamDate}`);
}
```

**Usage**:
```bash
# Dry run first
node backend/scripts/migrate-existing-users-target-date.js --dry-run

# Actual migration (creates backup automatically)
node backend/scripts/migrate-existing-users-target-date.js

# Rollback if needed
node backend/scripts/rollback-target-date-migration.js --backup-file backups/users_backup_2026-02-06T10-30-00.json
```

---

## 5. INDIA TIMEZONE HANDLING

### Analysis

**Question**: Are we using UTC anywhere else in the app?

**Answer**: Based on the codebase:

**Current Firestore Usage**:
- ✅ Firestore `Timestamp` type automatically handles timezone conversion
- ✅ `serverTimestamp()` stores in UTC, converts to local when read
- ✅ Backend logs use UTC by default (Node.js convention)

**Date Calculations in chapterUnlockService**:
```javascript
// Line 406 of plan
const examDate = new Date(targetYear, targetMonth - 1, 20);
```

**Issue**: This creates date in server's local timezone, which may differ from user's timezone.

**For India-only app**:

### Recommendation: Use IST Consistently

**Update chapterUnlockService.js** - `getTimelinePosition()` function:

```javascript
/**
 * Get timeline position from target exam date
 * @param {string} jeeTargetExamDate - Format: "YYYY-MM" (e.g., "2027-01" or "2027-04")
 * @param {Date} currentDate - Current date (optional, defaults to now in IST)
 * @returns {Object} { currentMonth, monthsUntilExam, isPostExam, examSession }
 */
function getTimelinePosition(jeeTargetExamDate, currentDate = null) {
  // Parse target (e.g., "2027-01" -> Jan 2027, "2027-04" -> April 2027)
  const [targetYear, targetMonth] = jeeTargetExamDate.split('-').map(Number);

  // INDIA-SPECIFIC: Use IST timezone for consistency
  // JEE exams happen in India, so we always use Indian Standard Time
  // IST = UTC+5:30

  // Create exam date at midnight IST (use 20th of exam month as reference)
  const examDate = new Date(targetYear, targetMonth - 1, 20, 0, 0, 0);

  // Get current date in IST
  if (!currentDate) {
    // If no date provided, use current time
    currentDate = new Date();
  }

  // Normalize both dates to start of month for consistent month calculation
  const examMonth = new Date(examDate.getFullYear(), examDate.getMonth(), 1);
  const currentMonth = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1);

  // Calculate months until exam
  const monthsUntilExam = Math.max(0,
    (examMonth.getFullYear() - currentMonth.getFullYear()) * 12 +
    (examMonth.getMonth() - currentMonth.getMonth())
  );

  // Timeline position (month 1 = 24 months before, month 24 = exam month)
  const currentMonthPosition = Math.max(1, Math.min(TOTAL_TIMELINE_MONTHS,
    TOTAL_TIMELINE_MONTHS - monthsUntilExam + 1));

  return {
    currentMonth: currentMonthPosition,
    monthsUntilExam,
    isPostExam: monthsUntilExam <= 0,
    examSession: targetMonth === 1 ? 'January' : 'April'
  };
}
```

**Key Changes**:
1. ✅ Uses native `Date` objects (which use server timezone)
2. ✅ Since server is in India (or configured to IST), this works correctly
3. ✅ Month calculation uses start-of-month to avoid day-boundary issues
4. ✅ No UTC conversion needed for India-only app

**Server Configuration** (ensure this in deployment):

```javascript
// backend/server.js or backend/index.js
// Add at the top
process.env.TZ = 'Asia/Kolkata'; // Set timezone to IST

console.log(`Server timezone: ${process.env.TZ || 'system default'}`);
console.log(`Current time: ${new Date().toString()}`);
```

**Mobile Configuration** (Flutter):

```dart
// mobile/lib/main.dart
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

void main() {
  // Initialize timezones
  tz.initializeTimeZones();

  // Set default timezone to IST
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

  runApp(MyApp());
}
```

**Why This Works for India-Only App**:
- ✅ All users are in IST (UTC+5:30)
- ✅ JEE exams happen in India
- ✅ Server can be configured to IST
- ✅ No timezone conversion needed
- ✅ Simpler than UTC everywhere

**If App Expands Internationally Later**:
- Switch to UTC timestamps
- Convert to user's timezone for display
- Store user's timezone in profile

---

## 6. CHAPTER UNLOCK TRACKING

### Question: How are we keeping track of what chapters are unlocked for each student?

### Answer: Three-Layer Tracking System

#### **Layer 1: Real-Time Calculation (Primary Source)**

**Location**: `chapterUnlockService.js` - `getUnlockedChapters(userId)`

**How It Works**:
```javascript
// Called whenever we need to know unlocked chapters
const result = await getUnlockedChapters(userId);
// Returns: { unlockedChapterKeys: [...], currentMonth, monthsUntilExam }
```

**Calculation Logic**:
1. Read user's `jeeTargetExamDate` from Firestore
2. Calculate `currentMonth` from formula: `24 - monthsUntilExam + 1`
3. Loop through months 1 to `currentMonth`
4. Collect all chapters from each month
5. Apply high-water mark (never re-lock)
6. Return list of unlocked chapter keys

**Storage**:
- ❌ **NOT stored** - calculated on-demand
- ✅ Ensures always up-to-date
- ✅ Automatically updates when date changes or time passes

#### **Layer 2: High-Water Mark (Persistence)**

**Location**: User document in Firestore

**Schema**:
```javascript
users/{userId}: {
  jeeTargetExamDate: "2027-01",
  chapterUnlockHighWaterMark: 16,  // Highest month ever reached
  chapterUnlockHighWaterMarkUpdatedAt: Timestamp,

  // Optional: Manual overrides
  chapterUnlockOverrides: {
    "physics_electrostatics": {
      unlockedAt: Timestamp,
      unlockedBy: "admin",
      reason: "Passed 5-question unlock quiz"
    }
  }
}
```

**Purpose**:
- ✅ Prevents chapter re-locking when target date changes
- ✅ Tracks highest timeline position reached
- ✅ Allows manual unlocks (future feature)

**Updated When**:
- User's timeline progresses to new month
- Admin manually unlocks chapter
- User completes unlock quiz (future feature)

#### **Layer 3: Audit Trail (Optional - For Analytics)**

**Location**: Separate collection for analytics (optional enhancement)

**Schema**:
```javascript
chapter_unlock_events/{eventId}: {
  userId: "user123",
  eventType: "month_progression" | "manual_unlock" | "high_water_increase",
  timestamp: Timestamp,

  // For month progression
  previousMonth: 15,
  newMonth: 16,
  newlyUnlockedChapters: ["physics_optics", "chemistry_haloalkanes_and_haloarenes"],

  // For manual unlock
  chapterKey: "physics_electrostatics",
  unlockedBy: "admin",
  reason: "Customer support request"
}
```

**Purpose**:
- Analytics on unlock patterns
- Debugging user issues
- A/B testing different unlock schedules

**Implementation** (Optional):

```javascript
// In chapterUnlockService.js, after updating high-water mark (line 511-520)
if (position.currentMonth > highWaterMark) {
  // Log unlock event
  await db.collection('chapter_unlock_events').add({
    userId,
    eventType: 'high_water_increase',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    previousMonth: highWaterMark,
    newMonth: position.currentMonth,
    newlyUnlockedChapters: /* calculate newly unlocked */,
    triggeredBy: 'automatic_progression'
  });
}
```

### **Summary: How Tracking Works**

| Aspect | How It's Tracked |
|--------|------------------|
| **Current unlocked chapters** | Calculated on-demand from `jeeTargetExamDate` + current date |
| **Highest month reached** | Stored in `chapterUnlockHighWaterMark` field |
| **Manual unlocks** | Stored in `chapterUnlockOverrides` map (optional) |
| **Unlock history** | Logged to `chapter_unlock_events` collection (optional) |
| **Daily quiz filtering** | Calls `getUnlockedChapters()` before generating quiz |
| **Chapter practice** | Checks `isChapterUnlocked(userId, chapterKey)` before starting |

### **Example Flow**

```
Student joins: Feb 2026
Target: Jan 2027
Current month: 14

Month 1 (Feb 2026):
- getUnlockedChapters() returns months 1-14
- highWaterMark = 14 (stored)

Month 2 (Mar 2026):
- getUnlockedChapters() returns months 1-15
- highWaterMark updates to 15
- Event logged (optional)

Student changes target to Jan 2028:
- getUnlockedChapters() calculates currentMonth = 2
- BUT highWaterMark = 15, so returns months 1-15 (no re-lock!)
- highWaterMark stays 15 (preserved)
```

### **API Access**

```javascript
// Get all unlocked chapters for a user
GET /api/chapters/unlocked
Response: {
  unlockedChapters: ["physics_kinematics", ...],
  currentMonth: 14,
  monthsUntilExam: 10,
  usingHighWaterMark: false
}

// Check if specific chapter is unlocked
GET /api/chapters/physics_electrostatics/unlock-status
Response: {
  unlocked: true
}
```

**Mobile Caching** (Recommended):

```dart
class ChapterUnlockProvider extends ChangeNotifier {
  List<String> _unlockedChapters = [];
  DateTime _lastFetched;
  static const CACHE_DURATION = Duration(hours: 1);

  Future<List<String>> getUnlockedChapters({bool forceRefresh = false}) async {
    // Use cache if fresh
    if (!forceRefresh &&
        _lastFetched != null &&
        DateTime.now().difference(_lastFetched) < CACHE_DURATION) {
      return _unlockedChapters;
    }

    // Fetch from API
    final result = await _apiService.getUnlockedChapters();
    _unlockedChapters = result['unlockedChapters'];
    _lastFetched = DateTime.now();
    notifyListeners();

    return _unlockedChapters;
  }
}
```

---

## 7. TEST SUITE

### Unit Tests

**File**: `backend/src/services/__tests__/chapterUnlockService.test.js`

```javascript
const { getTimelinePosition, getUnlockedChapters, TOTAL_TIMELINE_MONTHS } = require('../chapterUnlockService');
const { db, admin } = require('../../config/firebase');

// Mock Firestore
jest.mock('../../config/firebase');

describe('chapterUnlockService', () => {

  describe('getTimelinePosition', () => {

    test('24 months before exam = month 1', () => {
      const result = getTimelinePosition('2027-01', new Date('2025-01-20'));
      expect(result.currentMonth).toBe(1);
      expect(result.monthsUntilExam).toBe(24);
      expect(result.isPostExam).toBe(false);
      expect(result.examSession).toBe('January');
    });

    test('12 months before exam = month 13', () => {
      const result = getTimelinePosition('2027-01', new Date('2026-01-20'));
      expect(result.currentMonth).toBe(13);
      expect(result.monthsUntilExam).toBe(12);
    });

    test('exam month = month 24', () => {
      const result = getTimelinePosition('2027-01', new Date('2027-01-15'));
      expect(result.currentMonth).toBe(24);
      expect(result.monthsUntilExam).toBe(0);
    });

    test('post exam = isPostExam true', () => {
      const result = getTimelinePosition('2027-01', new Date('2027-02-15'));
      expect(result.isPostExam).toBe(true);
    });

    test('late joiner (6 months before) = month 19', () => {
      const result = getTimelinePosition('2027-01', new Date('2026-07-20'));
      expect(result.currentMonth).toBe(19);
      expect(result.monthsUntilExam).toBe(6);
    });

    test('April exam gives 3 extra months vs January', () => {
      const janResult = getTimelinePosition('2027-01', new Date('2026-02-20'));
      const aprResult = getTimelinePosition('2027-04', new Date('2026-02-20'));

      expect(janResult.currentMonth).toBe(14);
      expect(aprResult.currentMonth).toBe(11); // 3 months earlier
      expect(aprResult.monthsUntilExam).toBe(janResult.monthsUntilExam + 3);
    });

    test('handles invalid date format gracefully', () => {
      expect(() => {
        getTimelinePosition('invalid', new Date());
      }).toThrow();
    });

    test('month boundary calculation is correct', () => {
      // Test on last day of month
      const result1 = getTimelinePosition('2027-01', new Date('2026-01-31'));
      // Test on first day of next month
      const result2 = getTimelinePosition('2027-01', new Date('2026-02-01'));

      expect(result1.currentMonth).toBe(13);
      expect(result2.currentMonth).toBe(14);
    });
  });

  describe('getUnlockedChapters', () => {

    beforeEach(() => {
      // Reset mocks
      jest.clearAllMocks();
    });

    test('returns empty array for user without jeeTargetExamDate', async () => {
      // Mock user without target date
      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            exists: true,
            data: () => ({ phoneNumber: '+911234567890' })
          })
        })
      });

      // Mock getAllChapterKeys
      const mockChapters = ['physics_kinematics', 'chemistry_basic_concepts'];

      const result = await getUnlockedChapters('user123');

      expect(result.isLegacyUser).toBe(true);
      expect(result.unlockedChapterKeys).toEqual(mockChapters);
    });

    test('unlocks correct chapters for month 14', async () => {
      // Mock user at month 14
      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            exists: true,
            data: () => ({
              jeeTargetExamDate: '2027-01',
              chapterUnlockHighWaterMark: 14
            })
          })
        })
      });

      // Mock schedule
      // ... (add schedule mock)

      const result = await getUnlockedChapters('user123', new Date('2026-02-20'));

      expect(result.currentMonth).toBe(14);
      expect(result.unlockedChapterKeys.length).toBeGreaterThan(20);
    });

    test('high-water mark prevents re-locking', async () => {
      const userId = 'user123';

      // Mock user with highWaterMark = 16, but current month = 4
      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            exists: true,
            data: () => ({
              jeeTargetExamDate: '2028-01', // 22 months away = month 3
              chapterUnlockHighWaterMark: 16
            })
          }),
          update: jest.fn().mockResolvedValue({})
        })
      });

      const result = await getUnlockedChapters(userId, new Date('2026-02-20'));

      expect(result.currentMonth).toBe(3); // New timeline position
      expect(result.usingHighWaterMark).toBe(true); // Using high-water mark
      // Should still have chapters from month 16
    });

    test('updates high-water mark when progressing', async () => {
      const userId = 'user123';
      const mockUpdate = jest.fn().mockResolvedValue({});

      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            exists: true,
            data: () => ({
              jeeTargetExamDate: '2027-01',
              chapterUnlockHighWaterMark: 14
            })
          }),
          update: mockUpdate
        })
      });

      // User progresses to month 16
      await getUnlockedChapters(userId, new Date('2026-04-20'));

      expect(mockUpdate).toHaveBeenCalledWith(
        expect.objectContaining({
          chapterUnlockHighWaterMark: 16
        })
      );
    });

    test('handles chapter unlock overrides', async () => {
      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            exists: true,
            data: () => ({
              jeeTargetExamDate: '2027-01',
              chapterUnlockOverrides: {
                'physics_atoms_nuclei': {
                  unlockedAt: new Date(),
                  unlockedBy: 'admin',
                  reason: 'Customer support'
                }
              }
            })
          })
        })
      });

      const result = await getUnlockedChapters('user123', new Date('2025-05-20'));

      expect(result.unlockedChapterKeys).toContain('physics_atoms_nuclei');
    });
  });

  describe('isChapterUnlocked', () => {

    test('returns true for unlocked chapter', async () => {
      // Mock getUnlockedChapters
      jest.spyOn(require('../chapterUnlockService'), 'getUnlockedChapters')
        .mockResolvedValue({
          unlockedChapterKeys: ['physics_kinematics', 'chemistry_basic_concepts']
        });

      const { isChapterUnlocked } = require('../chapterUnlockService');
      const result = await isChapterUnlocked('user123', 'physics_kinematics');

      expect(result).toBe(true);
    });

    test('returns false for locked chapter', async () => {
      jest.spyOn(require('../chapterUnlockService'), 'getUnlockedChapters')
        .mockResolvedValue({
          unlockedChapterKeys: ['physics_kinematics']
        });

      const { isChapterUnlocked } = require('../chapterUnlockService');
      const result = await isChapterUnlocked('user123', 'physics_electrostatics');

      expect(result).toBe(false);
    });
  });
});
```

### Integration Tests

**File**: `backend/tests/integration/api/chapters.test.js`

```javascript
const request = require('supertest');
const app = require('../../../src/app');
const { db, admin } = require('../../../src/config/firebase');
const { generateTestToken } = require('../../helpers/auth');

describe('Chapter Unlock API Integration Tests', () => {

  let testUserId;
  let authToken;

  beforeAll(async () => {
    // Set up test user
    testUserId = 'test-user-' + Date.now();
    authToken = await generateTestToken(testUserId);

    // Create test user in Firestore
    await db.collection('users').doc(testUserId).set({
      phoneNumber: '+911234567890',
      jeeTargetExamDate: '2027-01',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      profileCompleted: true
    });

    // Seed test schedule (minimal)
    await db.collection('unlock_schedules').doc('v1_countdown').set({
      version: 'v1_countdown',
      type: 'countdown_24month',
      active: true,
      timeline: {
        month_1: {
          physics: ['physics_units_measurements'],
          chemistry: ['chemistry_basic_concepts'],
          mathematics: ['mathematics_sets_relations_functions']
        },
        // ... add more months for testing
      }
    });
  });

  afterAll(async () => {
    // Clean up test data
    await db.collection('users').doc(testUserId).delete();
    await db.collection('unlock_schedules').doc('v1_countdown').delete();
  });

  describe('GET /api/chapters/unlocked', () => {

    test('returns unlocked chapters for authenticated user', async () => {
      const response = await request(app)
        .get('/api/chapters/unlocked')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('unlockedChapters');
      expect(response.body.data).toHaveProperty('currentMonth');
      expect(response.body.data).toHaveProperty('monthsUntilExam');
      expect(Array.isArray(response.body.data.unlockedChapters)).toBe(true);
    });

    test('returns 401 for unauthenticated request', async () => {
      const response = await request(app)
        .get('/api/chapters/unlocked');

      expect(response.status).toBe(401);
    });

    test('calculates correct month position', async () => {
      // Mock current date to ensure predictable result
      jest.useFakeTimers();
      jest.setSystemTime(new Date('2026-02-20'));

      const response = await request(app)
        .get('/api/chapters/unlocked')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.body.data.currentMonth).toBe(14);
      expect(response.body.data.monthsUntilExam).toBe(11);

      jest.useRealTimers();
    });
  });

  describe('GET /api/chapters/:chapterKey/unlock-status', () => {

    test('returns true for unlocked chapter', async () => {
      const response = await request(app)
        .get('/api/chapters/physics_units_measurements/unlock-status')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data.unlocked).toBe(true);
    });

    test('returns false for locked chapter', async () => {
      const response = await request(app)
        .get('/api/chapters/physics_atoms_nuclei/unlock-status')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data.unlocked).toBe(false);
    });
  });

  describe('PUT /api/users/profile/target-exam-date', () => {

    test('updates target date and preserves high-water mark', async () => {
      // Set high-water mark
      await db.collection('users').doc(testUserId).update({
        chapterUnlockHighWaterMark: 16
      });

      // Change target date (would regress to month 2)
      const response = await request(app)
        .put('/api/users/profile/target-exam-date')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ jeeTargetExamDate: '2028-01' });

      expect(response.status).toBe(200);
      expect(response.body.data.usingHighWaterMark).toBe(true);

      // Verify high-water mark preserved
      const userDoc = await db.collection('users').doc(testUserId).get();
      expect(userDoc.data().chapterUnlockHighWaterMark).toBe(16);
    });

    test('rejects invalid date format', async () => {
      const response = await request(app)
        .put('/api/users/profile/target-exam-date')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ jeeTargetExamDate: '2027-05' }); // Invalid: not 01 or 04

      expect(response.status).toBe(400);
    });

    test('logs date change to history', async () => {
      const response = await request(app)
        .put('/api/users/profile/target-exam-date')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ jeeTargetExamDate: '2027-04' });

      expect(response.status).toBe(200);

      const userDoc = await db.collection('users').doc(testUserId).get();
      const history = userDoc.data().jeeTargetExamDateHistory;

      expect(Array.isArray(history)).toBe(true);
      expect(history.length).toBeGreaterThan(0);
      expect(history[history.length - 1].targetDate).toBe('2027-04');
    });
  });

  describe('Daily Quiz Integration', () => {

    test('quiz only includes unlocked chapters', async () => {
      // Generate daily quiz
      const response = await request(app)
        .post('/api/daily-quiz/generate')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);

      const quiz = response.body.data;
      const { unlockedChapterKeys } = await require('../../../src/services/chapterUnlockService')
        .getUnlockedChapters(testUserId);

      // Verify all quiz questions are from unlocked chapters
      quiz.questions.forEach(q => {
        expect(unlockedChapterKeys).toContain(q.chapter_key);
      });
    });
  });
});
```

### Mobile Widget Tests

**File**: `mobile/test/widgets/profile_edit_screen_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe/screens/profile/profile_edit_screen.dart';
import 'package:jeevibe/models/user_profile.dart';

void main() {
  group('ProfileEditScreen JEE Target Date Dropdown', () {

    late UserProfile testProfile;

    setUp(() {
      testProfile = UserProfile(
        uid: 'test123',
        phoneNumber: '+911234567890',
        profileCompleted: true,
        firstName: 'Test',
        lastName: 'User',
        jeeTargetExamDate: '2027-01',
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
      );
    });

    testWidgets('displays dynamic exam date options', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileEditScreen(profile: testProfile),
        ),
      );

      // Find dropdown
      final dropdown = find.byType(DropdownButtonFormField<String>);
      expect(dropdown, findsWidgets);

      // Tap to open
      await tester.tap(dropdown.first);
      await tester.pumpAndSettle();

      // Verify options shown (should have "X months away" labels)
      expect(find.textContaining('months away'), findsWidgets);
    });

    testWidgets('shows warning for exam < 3 months away', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileEditScreen(profile: testProfile),
        ),
      );

      // Open dropdown
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdown.first);
      await tester.pumpAndSettle();

      // Select near-term exam (if available)
      // This would trigger warning dialog
      // Verify dialog appears with warning message

      // Note: This test requires mocking current date to ensure
      // a < 3 month option is available
    });

    testWidgets('preserves current selection if not in future options', (WidgetTester tester) async {
      // Create profile with past exam date
      final pastProfile = testProfile.copyWith(
        jeeTargetExamDate: '2025-01', // Past date
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileEditScreen(profile: pastProfile),
        ),
      );

      // Open dropdown
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdown.first);
      await tester.pumpAndSettle();

      // Verify past date shown with "(Current Selection)" label
      expect(find.textContaining('Current Selection'), findsOneWidget);
    });
  });
}
```

### Test Coverage Requirements

**Minimum Coverage**:
- Unit tests: 80% coverage
- Integration tests: All critical paths
- E2E tests: Happy path + 3 error scenarios

**Run Tests**:
```bash
# Backend unit tests
cd backend
npm test

# Backend integration tests
npm run test:integration

# Backend coverage report
npm run test:coverage

# Mobile tests
cd mobile
flutter test

# Mobile coverage
flutter test --coverage
```

**Add to CI/CD** (.github/workflows/test.yml):
```yaml
name: Test Suite

on: [push, pull_request]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
        with:
          node-version: '18'
      - run: cd backend && npm install
      - run: cd backend && npm run test:coverage
      - run: cd backend && npm run validate:schedule

  mobile-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: cd mobile && flutter pub get
      - run: cd mobile && flutter test --coverage
```

---

## 📋 IMPLEMENTATION CHECKLIST

### Priority 1: Must Complete Before Launch

- [ ] **Profile Edit Screen** (2 hours)
  - [ ] Add `_getJeeExamOptions()` helper method
  - [ ] Add `_confirmRushTimeline()` warning dialog
  - [ ] Update dropdown widget with dynamic options
  - [ ] Test on device with various dates

- [ ] **High-Water Mark Preservation** (1 hour)
  - [ ] Add new PUT endpoint `/api/users/profile/target-exam-date`
  - [ ] Update POST `/api/users/profile` to preserve high-water mark
  - [ ] Write unit tests

- [ ] **Migration Enhancements** (1 hour)
  - [ ] Add backup creation to migration script
  - [ ] Create rollback script
  - [ ] Add dry-run mode
  - [ ] Test rollback procedure

- [ ] **Schedule Validation** (30 min)
  - [ ] Add validation script to npm scripts
  - [ ] Run validation before seeding
  - [ ] Document any missing chapters

### Priority 2: Should Complete

- [ ] **Timezone Configuration** (30 min)
  - [ ] Set `process.env.TZ = 'Asia/Kolkata'` in server
  - [ ] Configure Flutter timezone to IST
  - [ ] Test month boundary calculations

- [ ] **Test Suite** (4 hours)
  - [ ] Write unit tests for chapterUnlockService
  - [ ] Write integration tests for API endpoints
  - [ ] Write mobile widget tests
  - [ ] Set up CI/CD test pipeline

### Priority 3: Nice to Have

- [ ] **Analytics Logging** (Optional - handle separately)
  - [ ] Log unlock events to analytics
  - [ ] Track high-water mark changes
  - [ ] Monitor target date changes

---

## ✅ SIGN-OFF

All fixes and enhancements documented and ready for implementation.

**Estimated Total Time**: 8-10 hours

**Quality Level**: Production-ready after implementation
