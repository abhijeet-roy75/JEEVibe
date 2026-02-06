# Option A: 24-Month Countdown Timeline

## Concept

One unified 24-month curriculum that ends at the target JEE exam (January or April). No grade calculation needed.

```
Example:
- Student selects: JEE January 2027
- Today: February 2025
- Months until exam: 23
- Position: Month 1 of 24
- Unlocked: Chapters scheduled for month 1
```

**Key Decision: Support Both January and April Sessions**
- JEE Main has 2 sessions per year: January and April
- Students can target either session
- April exams give students 3 extra months of preparation automatically

## Pros & Cons

### Pros
- Single calendar to maintain
- No grade calculation logic
- Dropdown dynamically shows available Jan and April exams
- Late joiners naturally fit (auto-placed at current month, all prior chapters unlocked)
- "X months to JEE" messaging is more actionable than grade terminology
- Works identically for 11th, 12th, droppers, or anyone
- **High-water mark pattern**: Chapters never re-lock when target date changes
- Supports both January and April sessions seamlessly

### Cons
- Doesn't use familiar 11th/12th terminology (but this is a UI choice, not a limitation)
- Need to transform existing coaching schedule data to month-based format

### Late Joiner Example
A 12th grade student joining in May 2026 targeting JEE January 2027:
```
Months until exam: ~8 months
Position: 24 - 8 + 1 = Month 17 of 24
Unlocked: All chapters from months 1-17 (all 11th + early 12th)
UI shows: "8 months to JEE" (not "Month 17 of 24")
```

---

## Recommended UI Messaging

Use "X months to JEE" instead of "Month X of 24" for better user experience:

| UI Element | Example Message |
|------------|-----------------|
| Dashboard header | "8 months to JEE January 2027" |
| Progress indicator | "17 of 40 chapters unlocked" |
| Chapter card (locked) | "Unlocks in 2 weeks" |
| Chapter card (unlocked) | "Available now" |
| Onboarding confirmation | "Great! We'll prepare you for JEE January 2027" |

This messaging works universally for all students regardless of when they join or what grade they're in.

---

## Why 24 Months?

The 24-month timeline is a **universal buffer** that accommodates different coaching schedules:

**For JEE January 2027:**
```
Month 1-2:  Jan-Feb 2025  → Buffer for early/foundation batches
Month 3:    Mar 2025      → Allen, Resonance coaching starts
Month 4-5:  Apr-May 2025  → FIITJEE, schools, PW start
Month 6-12: Jun-Dec 2025  → 11th grade core chapters
Month 13:   Jan 2026      → 11th revision / early 12th
Month 14-15: Feb-Mar 2026 → Transition period
Month 16:   Apr 2026      → 12th grade starts
Month 17-20: May-Aug 2026 → 12th grade chapters
Month 21:   Sep 2026      → Syllabus completion
Month 22-23: Oct-Dec 2026 → Full revision mode
Month 24:   Jan 2027      → JEE exam month
```

**Key insight:** Most students join in March-May and are auto-placed at month 3-5. The extra months at the start provide flexibility for early starters without affecting the core experience.

---

## Date-to-Month Mapping (JSON → 24-Month Timeline)

The seeding script transforms the existing `coaching_unlock_schedule_updated.json` (date-based, grade-based) into the 24-month timeline format.

### Mapping Logic

**11th Grade Calendar → Months 1-12:**

| JSON Date Key | Month # | Calendar Month (for JEE Jan 2027) |
|---------------|---------|-----------------------------------|
| (buffer) | 1 | Jan 2025 |
| (buffer) | 2 | Feb 2025 |
| `may_1` (11th) | 3-4 | Mar-Apr 2025 |
| `may_1` (11th) | 5 | May 2025 |
| `june_15` (11th) | 6 | Jun 2025 |
| `august_1` (11th) | 7-8 | Jul-Aug 2025 |
| `september_1` (11th) | 9 | Sep 2025 |
| `october_1` (11th) | 10 | Oct 2025 |
| `november_1` (11th) | 11 | Nov 2025 |
| `december_1` (11th) | 12 | Dec 2025 |

**12th Grade Calendar → Months 13-24:**

| JSON Date Key | Month # | Calendar Month (for JEE Jan 2027) |
|---------------|---------|-----------------------------------|
| `january_1` (11th) / `february_1` (11th) | 13 | Jan 2026 |
| (transition) | 14-15 | Feb-Mar 2026 |
| `april_1` (12th) | 16 | Apr 2026 |
| `may_1` (12th) | 17 | May 2026 |
| `june_1` (12th) | 18 | Jun 2026 |
| `july_1` (12th) | 19 | Jul 2026 |
| `august_1` (12th) | 20 | Aug 2026 |
| `september_1` (12th) | 21 | Sep 2026 |
| `october_1` (12th) | 22 | Oct 2026 |
| `november_1` (12th) | 23 | Nov 2026 |
| `december_1` / `january_1` (12th) | 24 | Dec 2026 - Jan 2027 |

### Chapter ID Mapping

The JSON uses IDs like `PHY_11_CH01`, but the database uses `physics_units_measurements`. The seeding script maps these:

| JSON Chapter ID | Database chapter_key |
|-----------------|---------------------|
| **Physics 11th** | |
| PHY_11_CH01 | physics_units_measurements |
| PHY_11_CH02 | physics_kinematics |
| PHY_11_CH03 | physics_laws_of_motion |
| PHY_11_CH04 | physics_work_energy_power |
| PHY_11_CH05 | physics_rotational_motion |
| PHY_11_CH06 | physics_gravitation |
| PHY_11_CH07 | physics_properties_of_solids_liquids |
| PHY_11_CH08 | physics_thermodynamics |
| PHY_11_CH09 | physics_oscillations_waves |
| PHY_11_CH10 | physics_kinetic_theory_of_gases |
| **Physics 12th** | |
| PHY_12_CH01 | physics_electrostatics |
| PHY_12_CH02 | physics_current_electricity |
| PHY_12_CH03 | physics_magnetic_effects_magnetism |
| PHY_12_CH04 | physics_electromagnetic_induction |
| PHY_12_CH05 | physics_electromagnetic_waves |
| PHY_12_CH06 | physics_optics |
| PHY_12_CH07 | physics_dual_nature_of_radiation |
| PHY_12_CH08 | physics_atoms_nuclei |
| PHY_12_CH09 | physics_electronic_devices |
| **Chemistry 11th** | |
| CHEM_11_CH01 | chemistry_basic_concepts |
| CHEM_11_CH02 | chemistry_atomic_structure |
| CHEM_11_CH03 | chemistry_chemical_bonding |
| CHEM_11_CH04 | chemistry_classification_periodicity |
| CHEM_11_CH05 | chemistry_equilibrium |
| CHEM_11_CH06 | chemistry_thermodynamics |
| CHEM_11_CH07 | chemistry_redox_electrochemistry |
| CHEM_11_CH08 | chemistry_p_block_elements |
| CHEM_11_CH09 | chemistry_general_organic_chemistry |
| CHEM_11_CH10 | chemistry_hydrocarbons |
| **Chemistry 12th** | |
| CHEM_12_CH01 | chemistry_solutions |
| CHEM_12_CH02 | chemistry_electrochemistry |
| CHEM_12_CH03 | chemistry_chemical_kinetics |
| CHEM_12_CH04 | chemistry_d_f_block_elements |
| CHEM_12_CH05 | chemistry_coordination_compounds |
| CHEM_12_CH06 | chemistry_p_block_elements_12 |
| CHEM_12_CH07 | chemistry_haloalkanes_haloarenes |
| CHEM_12_CH08 | chemistry_alcohols_phenols_ethers |
| CHEM_12_CH09 | chemistry_aldehydes_ketones |
| CHEM_12_CH10 | chemistry_carboxylic_acids_derivatives |
| CHEM_12_CH11 | chemistry_amines_diazonium_salts |
| CHEM_12_CH12 | chemistry_biomolecules |
| **Mathematics 11th** | |
| MATH_11_CH01 | mathematics_sets_relations_functions |
| MATH_11_CH02 | mathematics_trigonometry |
| MATH_11_CH03 | mathematics_complex_numbers |
| MATH_11_CH04 | mathematics_permutations_combinations |
| MATH_11_CH05 | mathematics_binomial_theorem |
| MATH_11_CH06 | mathematics_sequences_series |
| MATH_11_CH07 | mathematics_straight_lines |
| MATH_11_CH08 | mathematics_conic_sections_parabola |
| MATH_11_CH09 | mathematics_conic_sections_ellipse_hyperbola |
| MATH_11_CH10 | mathematics_3d_geometry |
| MATH_11_CH11 | mathematics_limits_continuity_differentiability |
| MATH_11_CH12 | mathematics_statistics |
| MATH_11_CH13 | mathematics_probability |
| **Mathematics 12th** | |
| MATH_12_CH01 | mathematics_relations_functions_12 |
| MATH_12_CH02 | mathematics_inverse_trigonometry |
| MATH_12_CH03 | mathematics_matrices_determinants |
| MATH_12_CH04 | mathematics_continuity_differentiability_12 |
| MATH_12_CH05 | mathematics_differential_calculus_aod |
| MATH_12_CH06 | mathematics_integral_calculus_indefinite |
| MATH_12_CH07 | mathematics_integral_calculus_definite_area |
| MATH_12_CH08 | mathematics_differential_equations |
| MATH_12_CH09 | mathematics_vector_algebra |
| MATH_12_CH10 | mathematics_3d_geometry_12 |
| MATH_12_CH11 | mathematics_probability_12 |

### Transformation Summary

```
coaching_unlock_schedule_updated.json
        │
        ▼
┌─────────────────────────────────┐
│  Seeding Script                 │
│  - Map 11th dates → months 1-12 │
│  - Map 12th dates → months 13-24│
│  - Convert chapter IDs          │
│  - Handle "all_unlocked" flags  │
└─────────────────────────────────┘
        │
        ▼
Firestore: unlock_schedules/v1_countdown
```

**No changes needed to the source JSON file** - the seeding script handles all transformations.

---

## Data Model

### User Profile (`users/{userId}`)
```javascript
{
  jeeTargetExamDate: "2027-01",   // Format: YYYY-MM (01 = January, 04 = April)
  onboardingCompletedAt: Timestamp,

  // NEW: High-water mark for progressive unlock
  chapterUnlockHighWaterMark: 14,  // Highest month number ever reached
  chapterUnlockHighWaterMarkUpdatedAt: Timestamp,

  // NEW: Target date change history
  jeeTargetExamDateHistory: [
    {
      targetDate: "2027-04",
      setAt: Timestamp,
      previousTargetDate: null,
      reason: "initial_onboarding"
    },
    {
      targetDate: "2027-01",
      setAt: Timestamp,
      previousTargetDate: "2027-04",
      reason: "user_updated_profile"
    }
  ],

  chapterUnlockOverrides: {       // For future force-unlock feature
    "physics_electrostatics": {
      unlockedAt: Timestamp,
      unlockedBy: "admin" | "promo" | "quiz_unlock",
      reason: "Passed 5-question unlock quiz"
    }
  }
}
```

### Firestore Collection: `unlock_schedules/v1_countdown`
```javascript
{
  version: "v1_countdown",
  type: "countdown_24month",
  active: true,

  jee_dates: {
    session_1: { start: "2027-01-20", end: "2027-01-30" },
    session_2: { start: "2027-04-01", end: "2027-04-15" }
  },

  // Single 24-month timeline
  // Month 1 = 24 months before exam, Month 24 = exam month
  timeline: {
    "month_1": {
      // ~24 months before Jan exam (roughly Feb of year before 11th starts)
      physics: ["physics_units_measurements", "physics_kinematics"],
      chemistry: ["chemistry_basic_concepts", "chemistry_atomic_structure"],
      mathematics: ["mathematics_sets_relations_functions", "mathematics_trigonometry"]
    },
    "month_2": {
      physics: ["physics_laws_of_motion"],
      chemistry: ["chemistry_chemical_bonding"],
      mathematics: ["mathematics_complex_numbers"]
    },
    "month_3": {
      physics: ["physics_work_energy_power"],
      chemistry: ["chemistry_classification_periodicity"],
      mathematics: ["mathematics_permutations_and_combinations"]
    },
    // ... months 4-22 (map from coaching schedule)
    "month_23": {
      note: "Final new chapters + revision begins",
      physics: ["physics_electronic_devices"],
      chemistry: ["chemistry_biomolecules"],
      mathematics: ["mathematics_probability"]
    },
    "month_24": {
      note: "Final revision - all chapters unlocked",
      all_unlocked: true
    }
  }
}
```

---

## Core Logic

### Service: `backend/src/services/chapterUnlockService.js`

```javascript
const { db } = require('../config/firebase');
const logger = require('../utils/logger');

// Cache for schedule (5-minute TTL)
let scheduleCache = null;
let scheduleCacheTimestamp = 0;
const CACHE_TTL_MS = 5 * 60 * 1000;

const TOTAL_TIMELINE_MONTHS = 24;

/**
 * Get timeline position from target exam date
 * @param {string} jeeTargetExamDate - Format: "YYYY-MM" (e.g., "2027-01" or "2027-04")
 * @param {Date} currentDate - Current date
 * @returns {Object} { currentMonth, monthsUntilExam, isPostExam, examSession }
 */
function getTimelinePosition(jeeTargetExamDate, currentDate = new Date()) {
  // Parse target (e.g., "2027-01" -> Jan 2027, "2027-04" -> April 2027)
  const [targetYear, targetMonth] = jeeTargetExamDate.split('-').map(Number);
  const examDate = new Date(targetYear, targetMonth - 1, 20); // 20th of exam month

  // Calculate months until exam
  const monthsUntilExam = Math.max(0,
    (examDate.getFullYear() - currentDate.getFullYear()) * 12 +
    (examDate.getMonth() - currentDate.getMonth())
  );

  // Timeline position (month 1 = 24 months before, month 24 = exam month)
  // For April exams, students get 3 extra months automatically (they're "further along")
  const currentMonth = Math.max(1, Math.min(TOTAL_TIMELINE_MONTHS,
    TOTAL_TIMELINE_MONTHS - monthsUntilExam + 1));

  return {
    currentMonth,        // 1-24
    monthsUntilExam,
    isPostExam: monthsUntilExam <= 0,
    examSession: targetMonth === 1 ? 'January' : 'April'
  };
}

/**
 * Get active unlock schedule (with caching)
 */
async function getActiveSchedule() {
  const now = Date.now();
  if (scheduleCache && (now - scheduleCacheTimestamp < CACHE_TTL_MS)) {
    return scheduleCache;
  }

  const snapshot = await db.collection('unlock_schedules')
    .where('type', '==', 'countdown_24month')
    .where('active', '==', true)
    .limit(1)
    .get();

  if (snapshot.empty) {
    throw new Error('No active countdown unlock schedule found');
  }

  scheduleCache = snapshot.docs[0].data();
  scheduleCacheTimestamp = now;
  return scheduleCache;
}

/**
 * Get all chapter keys (for post-exam or all_unlocked)
 */
async function getAllChapterKeys() {
  // Query distinct chapter keys from questions collection
  // Or use a cached master list
  const snapshot = await db.collection('questions')
    .where('active', '==', true)
    .select('chapter_key')
    .get();

  const keys = new Set();
  snapshot.docs.forEach(doc => keys.add(doc.data().chapter_key));
  return Array.from(keys);
}

/**
 * Get unlocked chapters for a user
 * @param {string} userId - User ID
 * @param {Date} referenceDate - Date to use (defaults to now)
 * @returns {Object} { unlockedChapterKeys, currentMonth, monthsUntilExam, isPostExam, usingHighWaterMark }
 */
async function getUnlockedChapters(userId, referenceDate = new Date()) {
  // Get user data
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    throw new Error(`User ${userId} not found`);
  }

  const userData = userDoc.data();

  // Backward compatibility: users without jeeTargetExamDate get all chapters
  if (!userData.jeeTargetExamDate) {
    logger.info('User has no jeeTargetExamDate, unlocking all chapters', { userId });
    return {
      unlockedChapterKeys: await getAllChapterKeys(),
      currentMonth: TOTAL_TIMELINE_MONTHS,
      monthsUntilExam: 0,
      isPostExam: true,
      isLegacyUser: true
    };
  }

  const schedule = await getActiveSchedule();
  const position = getTimelinePosition(userData.jeeTargetExamDate, referenceDate);

  // If post-exam, unlock everything
  if (position.isPostExam) {
    return {
      unlockedChapterKeys: await getAllChapterKeys(),
      ...position
    };
  }

  // NEW: High-water mark pattern - chapters never re-lock
  const highWaterMark = userData.chapterUnlockHighWaterMark || 0;
  const currentMonthForUnlock = Math.max(position.currentMonth, highWaterMark);

  // If this is a new high, update it
  if (position.currentMonth > highWaterMark) {
    await db.collection('users').doc(userId).update({
      chapterUnlockHighWaterMark: position.currentMonth,
      chapterUnlockHighWaterMarkUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    logger.info('Updated high-water mark', {
      userId,
      oldHighWaterMark: highWaterMark,
      newHighWaterMark: position.currentMonth
    });
  }

  // Collect chapters from month 1 to currentMonthForUnlock (NOT position.currentMonth)
  const unlockedChapters = new Set();

  for (let m = 1; m <= currentMonthForUnlock; m++) {
    const monthData = schedule.timeline[`month_${m}`];
    if (!monthData) continue;

    if (monthData.all_unlocked) {
      return {
        unlockedChapterKeys: await getAllChapterKeys(),
        ...position,
        usingHighWaterMark: currentMonthForUnlock > position.currentMonth
      };
    }

    // Add chapters from each subject
    // NOTE: Empty arrays are expected - they mean "no new chapters this month"
    // Students continue mastering previously unlocked chapters
    ['physics', 'chemistry', 'mathematics'].forEach(subject => {
      if (Array.isArray(monthData[subject]) && monthData[subject].length > 0) {
        monthData[subject].forEach(ch => unlockedChapters.add(ch));
      }
      // If monthData[subject] is [] (empty), skip - no new chapters for this subject this month
    });
  }

  // Add override chapters (manually unlocked)
  if (userData.chapterUnlockOverrides) {
    Object.keys(userData.chapterUnlockOverrides).forEach(ch => {
      unlockedChapters.add(ch);
    });
  }

  logger.info('Calculated unlocked chapters', {
    userId,
    currentMonth: position.currentMonth,
    highWaterMark,
    usingHighWaterMark: currentMonthForUnlock > position.currentMonth,
    monthsUntilExam: position.monthsUntilExam,
    unlockedCount: unlockedChapters.size
  });

  return {
    unlockedChapterKeys: Array.from(unlockedChapters),
    ...position,
    usingHighWaterMark: currentMonthForUnlock > position.currentMonth
  };
}

/**
 * Check if a specific chapter is unlocked
 */
async function isChapterUnlocked(userId, chapterKey) {
  const result = await getUnlockedChapters(userId);
  return result.unlockedChapterKeys.includes(chapterKey);
}

/**
 * Add a manual chapter unlock override
 */
async function addChapterUnlockOverride(userId, chapterKey, unlockedBy, reason) {
  await db.collection('users').doc(userId).update({
    [`chapterUnlockOverrides.${chapterKey}`]: {
      unlockedAt: admin.firestore.FieldValue.serverTimestamp(),
      unlockedBy,
      reason
    }
  });

  logger.info('Added chapter unlock override', { userId, chapterKey, unlockedBy });
}

module.exports = {
  getTimelinePosition,
  getUnlockedChapters,
  isChapterUnlocked,
  addChapterUnlockOverride,
  getActiveSchedule,
  TOTAL_TIMELINE_MONTHS
};
```

---

## Mobile Onboarding Changes

### Summary of Changes

| Screen | Current | New |
|--------|---------|-----|
| **Step 1** | First Name, Last Name, Email, Phone, Current Class, Coaching Enrollment | First Name, Last Name, Email, Phone, **JEE Target Date** |
| **Step 2** | State, Exam Type, Dream Branch (all optional) | State, Exam Type, Dream Branch, **Coaching Enrollment** (all optional) |

**Rationale:**
- `currentClass` is removed - no longer needed (JEE target date determines everything)
- `isEnrolledInCoaching` moved to Step 2 - it's not essential for the core unlock logic, making Step 1 simpler

---

### File: `mobile/lib/screens/onboarding/onboarding_step1_screen.dart`

Replace `currentClass` dropdown with JEE target exam dropdown, remove coaching question:

```dart
// State variable
String? _jeeTargetExamDate;

// In build method - replace currentClass dropdown with:
DropdownButtonFormField<String>(
  value: _jeeTargetExamDate,
  isExpanded: true,
  decoration: InputDecoration(
    hintText: 'When are you appearing for JEE?',
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  ),
  items: _getJeeExamOptions().map((date) {
    final year = date.split('-')[0];
    return DropdownMenuItem<String>(
      value: date,
      child: Text('JEE January $year'),
    );
  }).toList(),
  onChanged: (value) => setState(() => _jeeTargetExamDate = value),
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Please select your JEE target date';
    }
    return null;
  },
),

// Helper method - generates available January and April exam dates
List<Map<String, String>> _getJeeExamOptions() {
  final now = DateTime.now();
  final currentYear = now.year;
  final currentMonth = now.month;

  List<Map<String, String>> options = [];

  // April of current year (only if we're before April)
  if (currentMonth <= 3) {
    options.add({
      'value': '$currentYear-04',
      'label': 'JEE April $currentYear',
      'monthsAway': '${4 - currentMonth} ${4 - currentMonth == 1 ? 'month' : 'months'} away'
    });
  }

  // January of next year (always available)
  final nextYear = currentYear + 1;
  final monthsToNextJan = (13 - currentMonth) % 12;
  options.add({
    'value': '$nextYear-01',
    'label': 'JEE January $nextYear',
    'monthsAway': '$monthsToNextJan months away'
  });

  // April of next year (always available)
  final monthsToNextApril = ((nextYear * 12 + 4) - (currentYear * 12 + currentMonth));
  options.add({
    'value': '$nextYear-04',
    'label': 'JEE April $nextYear',
    'monthsAway': '$monthsToNextApril months away'
  });

  // January of year after next
  final yearAfterNext = currentYear + 2;
  final monthsToNextNextJan = ((yearAfterNext * 12 + 1) - (currentYear * 12 + currentMonth));
  options.add({
    'value': '$yearAfterNext-01',
    'label': 'JEE January $yearAfterNext',
    'monthsAway': '$monthsToNextNextJan months away'
  });

  return options;
}
```

### Update step1Data passed to Step 2:
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => OnboardingStep2Screen(
      step1Data: {
        'firstName': _firstName,
        'lastName': _lastName,
        'email': _email,
        'phoneNumber': _phoneNumber,
        'jeeTargetExamDate': _jeeTargetExamDate,  // NEW - replaces currentClass
        // REMOVED: currentClass (no longer needed)
        // REMOVED: isEnrolledInCoaching (moved to Step 2)
      },
    ),
  ),
);
```

---

### File: `mobile/lib/screens/onboarding/onboarding_step2_screen.dart`

Add coaching enrollment question (now optional):

```dart
// Add state variable
bool? _isEnrolledInCoaching;

// Add to the form (after Dream Branch dropdown):
const SizedBox(height: 16),
Text(
  'Are you enrolled in coaching?',
  style: AppTextStyles.body1,
),
const SizedBox(height: 8),
Row(
  children: [
    Expanded(
      child: RadioListTile<bool>(
        title: const Text('Yes'),
        value: true,
        groupValue: _isEnrolledInCoaching,
        onChanged: (value) => setState(() => _isEnrolledInCoaching = value),
      ),
    ),
    Expanded(
      child: RadioListTile<bool>(
        title: const Text('No'),
        value: false,
        groupValue: _isEnrolledInCoaching,
        onChanged: (value) => setState(() => _isEnrolledInCoaching = value),
      ),
    ),
  ],
),

// Update profile data to include optional coaching field:
final profileData = {
  ...widget.step1Data,
  'state': _state,
  'targetExam': _targetExam,
  'dreamBranch': _dreamBranch,
  'isEnrolledInCoaching': _isEnrolledInCoaching,  // Now optional (can be null)
};
```

---

## Daily Quiz Integration

### File: `backend/src/services/dailyQuizService.js`

Add import and filtering:

```javascript
const { getUnlockedChapters } = require('./chapterUnlockService');

async function generateDailyQuizInternal(userId) {
  // ... existing code to get user data ...

  // NEW: Get unlocked chapters for this user
  const unlockResult = await getUnlockedChapters(userId);
  const unlockedChapterKeys = new Set(unlockResult.unlockedChapterKeys);

  logger.info('Chapter unlock status for quiz generation', {
    userId,
    currentMonth: unlockResult.currentMonth,
    monthsUntilExam: unlockResult.monthsUntilExam,
    unlockedChapterCount: unlockedChapterKeys.size
  });

  // ... existing code to get allChapterMappings ...

  // NEW: Filter chapter mappings to only include unlocked chapters
  if (allChapterMappings && allChapterMappings.size > 0) {
    const filteredMappings = new Map();
    for (const [chapterKey, value] of allChapterMappings.entries()) {
      if (unlockedChapterKeys.has(chapterKey)) {
        filteredMappings.set(chapterKey, value);
      }
    }

    logger.info('Filtered chapters by unlock status', {
      userId,
      originalCount: allChapterMappings.size,
      filteredCount: filteredMappings.size
    });

    allChapterMappings = filteredMappings;
  }

  // ... rest of existing code uses filtered allChapterMappings ...
}
```

---

## Backend Route Updates

### File: `backend/src/routes/users.js`

Add validation for new field:

```javascript
// In POST /api/users/profile validation
body('jeeTargetExamDate')
  .optional()
  .matches(/^\d{4}-(01|04)$/)
  .withMessage('jeeTargetExamDate must be in YYYY-MM format (01 for January, 04 for April)'),
```

---

## API Endpoints

### New route: `backend/src/routes/chapters.js`

```javascript
const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const { getUnlockedChapters, isChapterUnlocked } = require('../services/chapterUnlockService');

// GET /api/chapters/unlocked
router.get('/unlocked', authenticateToken, async (req, res) => {
  try {
    const result = await getUnlockedChapters(req.user.uid);
    res.json({
      success: true,
      data: {
        unlockedChapters: result.unlockedChapterKeys,
        currentMonth: result.currentMonth,
        monthsUntilExam: result.monthsUntilExam,
        totalMonths: 24
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/chapters/:chapterKey/unlock-status
router.get('/:chapterKey/unlock-status', authenticateToken, async (req, res) => {
  try {
    const unlocked = await isChapterUnlocked(req.user.uid, req.params.chapterKey);
    res.json({
      success: true,
      data: { unlocked }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
```

### New route: Update target exam date

```javascript
// PUT /api/users/profile/target-exam-date
router.put('/profile/target-exam-date',
  authenticateToken,
  body('jeeTargetExamDate').matches(/^\d{4}-(01|04)$/),
  async (req, res) => {
    try {
      const { jeeTargetExamDate } = req.body;
      const userId = req.user.uid;

      const userRef = db.collection('users').doc(userId);
      const userDoc = await userRef.get();
      const oldTargetDate = userDoc.data()?.jeeTargetExamDate;

      await userRef.update({
        jeeTargetExamDate,
        jeeTargetExamDateHistory: admin.firestore.FieldValue.arrayUnion({
          targetDate: jeeTargetExamDate,
          setAt: admin.firestore.FieldValue.serverTimestamp(),
          previousTargetDate: oldTargetDate,
          reason: 'user_updated_profile'
        })
      });

      // Recalculate unlock status (high-water mark ensures no chapters re-lock)
      const unlockResult = await getUnlockedChapters(userId);

      res.json({
        success: true,
        data: {
          updatedTargetDate: jeeTargetExamDate,
          unlockedChapters: unlockResult.unlockedChapterKeys,
          currentMonth: unlockResult.currentMonth,
          monthsUntilExam: unlockResult.monthsUntilExam,
          usingHighWaterMark: unlockResult.usingHighWaterMark
        }
      });
    } catch (error) {
      res.status(500).json({ success: false, error: error.message });
    }
  }
);
```

---

## Schedule Seeding Script

### Source Data: 24-Month Chapter Schedule JSON

**Important:** We will receive a pre-formatted 24-month chapter schedule as a JSON file directly from the curriculum team. This file will already have:
- ✅ Chapters mapped by month (month_1 through month_24)
- ✅ Subject-wise breakdown (physics, chemistry, mathematics)
- ✅ Proper chapter_key format (e.g., `physics_units_measurements`)
- ✅ No need for ID mapping or transformation
- ✅ **Empty months are allowed** - If a subject has no chapters for a month, it means the previous month's chapters need longer to master

**File Location:** `backend/data/countdown_24month_schedule.json`

**JSON Structure:**
```javascript
{
  "version": "v1_countdown",
  "type": "countdown_24month",
  "timeline": {
    "month_1": {
      "physics": ["physics_units_measurements", "physics_kinematics"],
      "chemistry": ["chemistry_basic_concepts", "chemistry_atomic_structure"],
      "mathematics": ["mathematics_sets_relations_functions", "mathematics_trigonometry"]
    },
    "month_2": {
      "physics": ["physics_laws_of_motion"],
      "chemistry": [],  // Empty - mastering month_1 chemistry chapters
      "mathematics": ["mathematics_complex_numbers"]
    },
    "month_3": {
      "physics": [],  // Empty - continue practicing month_2 physics
      "chemistry": ["chemistry_periodic_table", "chemistry_chemical_bonding"],
      "mathematics": []  // Empty - continue with month_2 math
    },
    // ... months 4-19
    "month_20": {
      "physics": ["physics_modern_physics_advanced"],  // Last physics chapter
      "chemistry": [],  // Chemistry curriculum complete (finished at month 18)
      "mathematics": ["mathematics_probability_distributions"]
    },
    "month_21": {
      "physics": [],  // Physics curriculum complete - revision phase starts
      "chemistry": [],  // Revision phase
      "mathematics": ["mathematics_calculus_applications"]  // Last math chapter
    },
    "month_22": {
      "physics": [],  // Revision and mock tests
      "chemistry": [],  // Revision and mock tests
      "mathematics": []  // Math curriculum complete - revision phase starts
    },
    "month_23": {
      "physics": [],  // Intensive revision and full-length mock tests
      "chemistry": [],
      "mathematics": []
    },
    "month_24": {
      "physics": [],  // Final revision, exam strategies, last-minute tips
      "chemistry": [],
      "mathematics": []
    }
  }
}
```

**Handling Empty Months:**
- **Empty array (`[]`)**: No new chapters unlock for that subject in that month
- **Rationale**: Two scenarios for empty months:
  1. **Within the curriculum**: Chapter requires multiple months to master (e.g., Organic Chemistry, Calculus)
  2. **Post-curriculum**: All chapters completed, remaining time is for revision/practice/mock tests
- **Student Experience**: Students continue practicing the previously unlocked chapters
- **UI Message**:
  - During curriculum: "No new chapters this month - focus on mastering current topics!"
  - Post-curriculum: "All chapters completed! Focus on revision and mock tests."

**Variable-Length Subject Timelines:**
- **Not all subjects need 24 months of new content**
- Examples:
  - Physics: 20 months of chapters → months 21-24 are revision only
  - Chemistry: 18 months of chapters → months 19-24 are revision only
  - Mathematics: 22 months of chapters → months 23-24 are revision only
- **Implementation**: Empty arrays for all subjects after curriculum completion
  ```javascript
  "month_21": {
    "physics": [],  // Curriculum complete, revision phase
    "chemistry": [],  // Curriculum complete, revision phase
    "mathematics": ["mathematics_advanced_calculus_applications"]  // Still adding content
  }
  ```

**Mobile UI Handling:**
When displaying chapter unlock status to students, check if all chapters for a subject are unlocked:
```dart
// In chapter practice screen
String getSubjectStatusMessage(String subject, int currentMonth, List<String> unlockedChapters, int totalChapters) {
  if (unlockedChapters.length == totalChapters) {
    return 'All $subject chapters unlocked! 🎉\nFocus on revision and mock tests.';
  }

  // Check if current month has new chapters
  final currentMonthData = schedule['month_$currentMonth'][subject.toLowerCase()];
  if (currentMonthData.isEmpty) {
    return 'No new chapters this month.\nKeep practicing current topics!';
  }

  return '${unlockedChapters.length}/$totalChapters chapters unlocked';
}
```

### File: `backend/scripts/seed-countdown-schedule.js`

```javascript
/**
 * Seed the 24-month countdown unlock schedule to Firestore
 * Loads pre-formatted JSON directly (no transformation needed)
 * Run with: node backend/scripts/seed-countdown-schedule.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const serviceAccount = require('../config/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Load the pre-formatted 24-month schedule JSON
const scheduleFilePath = path.join(__dirname, '../data/countdown_24month_schedule.json');
const scheduleData = JSON.parse(fs.readFileSync(scheduleFilePath, 'utf8'));

const COUNTDOWN_SCHEDULE = {
  ...scheduleData,
  active: true,
  created_at: admin.firestore.FieldValue.serverTimestamp(),

  jee_dates: {
    session_1: { start: "2027-01-20", end: "2027-01-30" },
    session_2: { start: "2027-04-01", end: "2027-04-15" }
  },
  version: "v1_countdown",
  type: "countdown_24month",
  active: true,
  created_at: admin.firestore.FieldValue.serverTimestamp(),

  jee_dates: {
    session_1: { start: "2027-01-20", end: "2027-01-30" },
    session_2: { start: "2027-04-01", end: "2027-04-15" }
  },

  // Timeline data loaded from JSON file
  timeline: scheduleData.timeline
};

async function seedSchedule() {
  try {
    console.log(`Loading schedule from: ${scheduleFilePath}`);
    console.log(`Found ${Object.keys(scheduleData.timeline).length} months in timeline`);

    // Validate that we have months 1-24 (all must exist, even if empty)
    for (let i = 1; i <= 24; i++) {
      if (!scheduleData.timeline[`month_${i}`]) {
        throw new Error(`Missing month_${i} in timeline data`);
      }

      // Validate each month has all three subjects (can be empty arrays)
      const monthData = scheduleData.timeline[`month_${i}`];
      ['physics', 'chemistry', 'mathematics'].forEach(subject => {
        if (!Array.isArray(monthData[subject])) {
          throw new Error(`Month ${i} missing ${subject} array`);
        }
      });
    }

    // Count total chapters per subject (for logging)
    const chapterCounts = { physics: 0, chemistry: 0, mathematics: 0 };
    for (let i = 1; i <= 24; i++) {
      const monthData = scheduleData.timeline[`month_${i}`];
      chapterCounts.physics += monthData.physics.length;
      chapterCounts.chemistry += monthData.chemistry.length;
      chapterCounts.mathematics += monthData.mathematics.length;
    }

    await db.collection('unlock_schedules').doc('v1_countdown').set(COUNTDOWN_SCHEDULE);
    console.log('✅ Successfully seeded countdown schedule to Firestore');
    console.log('   - Version:', COUNTDOWN_SCHEDULE.version);
    console.log('   - Type:', COUNTDOWN_SCHEDULE.type);
    console.log('   - Months:', Object.keys(scheduleData.timeline).length);
    console.log('   - Total chapters:');
    console.log('     • Physics:', chapterCounts.physics);
    console.log('     • Chemistry:', chapterCounts.chemistry);
    console.log('     • Mathematics:', chapterCounts.mathematics);
  } catch (error) {
    console.error('❌ Error seeding schedule:', error);
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

seedSchedule();
```

---

## Migration Script for Existing Users

### File: `backend/scripts/migrate-existing-users-target-date.js`

For the ~7 existing users who don't have `jeeTargetExamDate`, we need to set a sensible default based on their `currentClass` field.

```javascript
/**
 * Migration script: Set jeeTargetExamDate for existing users
 *
 * Logic:
 * - If currentClass = "11" → target next year's January exam
 * - If currentClass = "12" → target this year's January exam (or next if past Jan)
 * - If currentClass = "Other" or missing → default to all chapters unlocked (no change needed)
 *
 * Run with: node backend/scripts/migrate-existing-users-target-date.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('../config/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateUsers() {
  const now = new Date();
  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth() + 1;

  // Get all users without jeeTargetExamDate
  const usersSnapshot = await db.collection('users')
    .where('profileCompleted', '==', true)
    .get();

  console.log(`Found ${usersSnapshot.size} users with completed profiles`);

  let migrated = 0;
  let skipped = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userData = userDoc.data();

    // Skip if already has target date
    if (userData.jeeTargetExamDate) {
      console.log(`Skipping ${userDoc.id}: already has jeeTargetExamDate`);
      skipped++;
      continue;
    }

    let targetExamDate = null;

    if (userData.currentClass === '11') {
      // 11th graders target next year's January (safe bet)
      const targetYear = currentMonth >= 4 ? currentYear + 2 : currentYear + 1;
      targetExamDate = `${targetYear}-01`;
    } else if (userData.currentClass === '12') {
      // 12th graders - be smart about Jan vs April
      if (currentMonth <= 3) {
        // Feb-Mar: Can target April of current year
        targetExamDate = `${currentYear}-04`;
      } else if (currentMonth >= 4 && currentMonth <= 12) {
        // Apr-Dec: Target next January
        targetExamDate = `${currentYear + 1}-01`;
      } else {
        // Jan: Target current Jan (or April if past Jan exam)
        targetExamDate = `${currentYear}-01`;
      }
    } else {
      // "Other" or missing - leave as null (all chapters unlocked)
      console.log(`Skipping ${userDoc.id}: currentClass is "${userData.currentClass}" - will have all chapters unlocked`);
      skipped++;
      continue;
    }

    // Update user
    await db.collection('users').doc(userDoc.id).update({
      jeeTargetExamDate: targetExamDate,
      migratedAt: admin.firestore.FieldValue.serverTimestamp(),
      migrationNote: `Auto-set from currentClass="${userData.currentClass}"`
    });

    console.log(`Migrated ${userDoc.id}: currentClass=${userData.currentClass} → jeeTargetExamDate=${targetExamDate}`);
    migrated++;
  }

  console.log(`\nMigration complete: ${migrated} migrated, ${skipped} skipped`);
}

migrateUsers()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Migration failed:', error);
    process.exit(1);
  });
```

### Migration Logic Summary

| Current Class | Today's Date | Target Exam Date | Reasoning |
|---------------|--------------|------------------|-----------|
| "11" | Feb 2026 | "2027-01" | Standard 11th grade timeline |
| "11" | May 2026 | "2028-01" | Started late in academic year |
| "12" | Feb 2026 | "2026-04" | Can target April (2 months away) |
| "12" | May 2026 | "2027-01" | Missed April, target next Jan |
| "12" | Dec 2026 | "2027-01" | Standard 12th grade timeline |
| "Other" / missing | Any | No change (all chapters unlocked) | Legacy/special cases |

### Running the Migration

```bash
# Dry run first (add --dry-run flag if you implement it)
node backend/scripts/migrate-existing-users-target-date.js

# Check results in Firestore console
```

---

## High-Water Mark Pattern: Handling Target Date Changes

### Problem Statement

Students may change their target exam date for various reasons:
- Postponing exam to get more preparation time
- Advancing exam because they feel confident
- Switching between January and April sessions
- Deciding to take a drop year

**Key Challenge:** If we re-lock chapters when students postpone exams, they lose access to content they've already studied, disrupting their progress and causing frustration.

### Design Decision: Progressive Unlock Only

**Principle:** Chapters unlock progressively based on timeline, but **NEVER re-lock** when target date changes.

**Implementation:** High-water mark pattern
- Track the highest month number ever reached (`chapterUnlockHighWaterMark`)
- Always use `max(currentMonth, highWaterMark)` for unlocking
- Chapters stay unlocked even if timeline regresses

### Examples

#### Example 1: Student Postpones Exam (Gets More Time)

```
Feb 2026: Join, target Jan 2027
- currentMonth: 14
- Unlocked: Months 1-14 (20 chapters)
- highWaterMark: 14

Apr 2026: Natural progression
- currentMonth: 16
- Unlocked: Months 1-16 (25 chapters)
- highWaterMark: 16

May 2026: Change target Jan 2027 → Jan 2028
- NEW currentMonth: 4 (regressed!)
- highWaterMark: 16 (preserved)
- ✅ Unlocked: Months 1-16 (no chapters re-locked!)
- usingHighWaterMark: true
- UI: "You're ahead of schedule! Keep practicing."

Jun-Dec 2026: Natural progression
- currentMonth continues: 5, 6, 7, 8, 9, 10, 11...
- Still using highWaterMark: 16 (student "coasts" on unlocked chapters)

Jan 2027: Natural progression
- currentMonth: 12
- highWaterMark: 16 (still ahead)

Apr 2027: Caught up!
- currentMonth: 16
- highWaterMark: 16 (equals currentMonth)
- usingHighWaterMark: false

Jun 2027: New progress
- currentMonth: 18
- highWaterMark: 18 (NEW HIGH!)
- Unlocked: Months 1-18
```

#### Example 2: Student Advances Exam (Less Time)

```
Feb 2026: Join, target Jan 2028
- currentMonth: 2
- Unlocked: Months 1-2 (6 chapters)
- highWaterMark: 2

Mar 2026: Change target Jan 2028 → April 2027
- NEW currentMonth: 11 (accelerated!)
- highWaterMark: 2 (old mark)
- ✅ Unlocked: Months 1-11 (15 chapters unlock immediately!)
- New highWaterMark: 11
- UI: "Your exam is sooner! We've unlocked more chapters."
```

#### Example 3: Switching Between January and April

```
Feb 2026: Join, target April 2027
- currentMonth: 11
- Unlocked: Months 1-11
- highWaterMark: 11

May 2026: Change April 2027 → Jan 2027
- NEW currentMonth: 17 (3 months jump!)
- highWaterMark: 11
- ✅ Unlocked: Months 1-17 (more chapters!)
- New highWaterMark: 17

Jun 2026: Change Jan 2027 → April 2027 (changed back)
- NEW currentMonth: 13 (regressed by 4 months)
- highWaterMark: 17 (preserved)
- ✅ Unlocked: Still months 1-17 (no re-locking!)
```

### Benefits of High-Water Mark Pattern

✅ **No loss of progress** - Students never lose access to chapters they've studied
✅ **Predictable UX** - "Chapters unlock, never lock" is easy to understand
✅ **Handles postponement gracefully** - Students who need more time aren't punished
✅ **Handles advancement gracefully** - Confident students get accelerated access
✅ **Prevents Daily Quiz breaks** - Quiz generation never fails due to locked chapters
✅ **Preserves theta data visibility** - All practiced chapters remain accessible

### Mobile UI Implementation

```dart
// In Profile Settings Screen
Future<void> _updateTargetExamDate(String newTargetDate) async {
  final oldTargetDate = _userData['jeeTargetExamDate'];

  // Update in Firestore
  await _apiService.updateProfile({
    'jeeTargetExamDate': newTargetDate,
  });

  // Fetch new unlock status
  final unlockStatus = await _apiService.getUnlockedChapters();

  // Show appropriate message
  if (unlockStatus['usingHighWaterMark'] == true) {
    _showInfoDialog(
      'Target Date Updated',
      'Your exam date has been updated. All previously unlocked chapters remain available!'
    );
  } else {
    final monthsUntilExam = unlockStatus['monthsUntilExam'];
    final currentMonth = unlockStatus['currentMonth'];

    if (monthsUntilExam < 6) {
      _showWarningDialog(
        'Intensive Preparation Mode',
        'Your exam is in $monthsUntilExam months. Make sure to focus on revision and mock tests!'
      );
    } else {
      _showInfoDialog(
        'Target Date Updated',
        'Your exam date has been updated to $newTargetDate. You\'re on track!'
      );
    }
  }

  setState(() {
    _unlockedChapters = unlockStatus['unlockedChapters'];
  });
}
```

### Analytics Tracking

Track target date changes to understand user behavior:

```javascript
// In backend when updating target date
analytics.logEvent('target_exam_date_changed', {
  userId,
  oldTargetDate,
  newTargetDate,
  oldMonthsUntilExam,
  newMonthsUntilExam,
  direction: newMonthsUntilExam > oldMonthsUntilExam ? 'postponed' : 'advanced',
  monthsDifference: Math.abs(newMonthsUntilExam - oldMonthsUntilExam),
  hadHighWaterMarkEffect: position.currentMonth < highWaterMark,
  daysIntoJourney: Math.floor((Date.now() - userData.onboardingCompletedAt) / (1000 * 60 * 60 * 24))
});
```

---

## January vs April Session: Key Differences

### Timeline Impact

| Student | Join Date | Target Exam | Months Until | Current Month | Chapters Unlocked |
|---------|-----------|-------------|--------------|---------------|-------------------|
| **Student A** | Feb 2026 | Jan 2027 | 11 months | 14 | ~20 chapters (all 11th + early 12th) |
| **Student B** | Feb 2026 | April 2027 | 14 months | 11 | ~15 chapters (all 11th foundation) |

**Key Insight:** April exam gives students 3 extra months of preparation time, which naturally places them "earlier" in the 24-month timeline.

### Dropdown Display

**Today: Feb 2026**

```
When are you appearing for JEE?

⚪ JEE April 2026 (2 months away) ⚠️ Intensive prep mode
⚪ JEE January 2027 (11 months away) ⭐ Recommended
⚪ JEE April 2027 (14 months away)
⚪ JEE January 2028 (23 months away)
```

**Today: April 2026**

```
When are you appearing for JEE?

⚪ JEE January 2027 (9 months away) ⭐ Recommended
⚪ JEE April 2027 (12 months away)
⚪ JEE January 2028 (21 months away)
```

### Warning for Rush Timeline

Show a confirmation dialog when students select an exam < 3 months away:

```dart
if (monthsUntilExam < 3) {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('⚠️ Intensive Preparation Mode'),
      content: Text(
        'You have less than 3 months until the exam. '
        'All chapters will be unlocked immediately for intensive revision.\n\n'
        'Consider targeting the next exam session for better preparation time.'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Choose Different Date'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Continue with $examDate'),
        ),
      ],
    ),
  );

  if (confirmed != true) {
    return; // User cancelled
  }
}
```

---

## Testing

### Unit Tests: `backend/src/services/__tests__/chapterUnlockService.test.js`

```javascript
const { getTimelinePosition, TOTAL_TIMELINE_MONTHS } = require('../chapterUnlockService');

describe('getTimelinePosition', () => {
  test('24 months before exam = month 1', () => {
    const result = getTimelinePosition('2027-01', new Date('2025-01-20'));
    expect(result.currentMonth).toBe(1);
    expect(result.monthsUntilExam).toBe(24);
    expect(result.isPostExam).toBe(false);
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
    // Student targeting April gets more prep time
    const janResult = getTimelinePosition('2027-01', new Date('2026-02-20'));
    const aprResult = getTimelinePosition('2027-04', new Date('2026-02-20'));

    expect(janResult.currentMonth).toBe(14);
    expect(aprResult.currentMonth).toBe(11); // 3 months earlier in timeline
    expect(aprResult.monthsUntilExam).toBe(janResult.monthsUntilExam + 3);
  });
});

describe('getUnlockedChapters with high-water mark', () => {
  test('high-water mark prevents re-locking when exam postponed', async () => {
    const userId = 'test-user-123';

    // Initial: user at month 16 (Feb 2026, targeting Jan 2027)
    await setUserData(userId, { jeeTargetExamDate: '2027-01' });
    let result = await getUnlockedChapters(userId, new Date('2026-04-20'));
    expect(result.currentMonth).toBe(16);
    const chaptersAtMonth16 = result.unlockedChapterKeys.length;
    expect(chaptersAtMonth16).toBeGreaterThan(20);

    // User postpones exam to Jan 2028 (regression to month 4)
    await setUserData(userId, { jeeTargetExamDate: '2028-01' });
    result = await getUnlockedChapters(userId, new Date('2026-04-20'));

    // Verify no re-locking
    expect(result.currentMonth).toBe(4); // New timeline position
    expect(result.usingHighWaterMark).toBe(true); // Using high-water mark
    expect(result.unlockedChapterKeys.length).toBe(chaptersAtMonth16); // No chapters lost!
  });

  test('high-water mark updates when advancing naturally', async () => {
    const userId = 'test-user-456';

    await setUserData(userId, { jeeTargetExamDate: '2027-01' });

    // Month 14
    let result = await getUnlockedChapters(userId, new Date('2026-02-20'));
    expect(result.currentMonth).toBe(14);
    const userData1 = await getUserData(userId);
    expect(userData1.chapterUnlockHighWaterMark).toBe(14);

    // Progress to month 16
    result = await getUnlockedChapters(userId, new Date('2026-04-20'));
    expect(result.currentMonth).toBe(16);
    const userData2 = await getUserData(userId);
    expect(userData2.chapterUnlockHighWaterMark).toBe(16); // Updated!
  });

  test('advancing exam date unlocks chapters immediately', async () => {
    const userId = 'test-user-789';

    // Start: targeting Jan 2028 (month 2)
    await setUserData(userId, { jeeTargetExamDate: '2028-01' });
    let result = await getUnlockedChapters(userId, new Date('2026-02-20'));
    expect(result.currentMonth).toBe(2);
    const chaptersAtMonth2 = result.unlockedChapterKeys.length;

    // Advance to April 2027 (month 11)
    await setUserData(userId, { jeeTargetExamDate: '2027-04' });
    result = await getUnlockedChapters(userId, new Date('2026-02-20'));

    expect(result.currentMonth).toBe(11);
    expect(result.unlockedChapterKeys.length).toBeGreaterThan(chaptersAtMonth2);
    expect(result.usingHighWaterMark).toBe(false); // Not using high-water mark
  });
});
```
