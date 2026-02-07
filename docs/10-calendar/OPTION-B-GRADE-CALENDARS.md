# Option B: Two Grade-Based Calendars

## Concept

Separate calendars for 11th and 12th grade, aligned with school academic year (April-March).

```
Example:
- Student selects: JEE 2027
- Today: May 2025
- Academic year: 2025 (starts April)
- Years until JEE: 2027 - 2025 = 2
- Grade: 11th
- Unlocked: 11th grade chapters up to May
```

## Pros & Cons

### Pros
- Aligns with school/coaching structure
- Familiar mental model (11th/12th)
- Can use existing coaching schedule data directly
- Marketing advantage: "Follow your coaching schedule"

### Cons
- Two calendars to maintain
- Grade calculation logic needed
- Dropdown options may need yearly review
- More complex edge case handling (academic year boundaries)

### When to Choose Option B
Choose this option **only if** you want to explicitly display "You're in 11th grade" or "You're in 12th grade" in the UI for familiarity with school structure.

**Note:** If using "X months to JEE" messaging (recommended), Option A provides identical user experience with simpler implementation.

---

## Data Model

### User Profile (`users/{userId}`)
```javascript
{
  jeeTargetYear: 2027,            // Just the year
  onboardingCompletedAt: Timestamp,
  chapterUnlockOverrides: {       // For future force-unlock feature
    "physics_electrostatics": {
      unlockedAt: Timestamp,
      unlockedBy: "admin" | "promo" | "quiz_unlock",
      reason: "Passed 5-question unlock quiz"
    }
  }
}
```

### Firestore Collection: `unlock_schedules/v1_grade_based`
```javascript
{
  version: "v1_grade_based",
  type: "grade_calendar",
  active: true,

  jee_dates: {
    session_1: { start: "2027-01-20", end: "2027-01-30" },
    session_2: { start: "2027-04-01", end: "2027-04-15" }
  },

  calendars: {
    "11th_grade": {
      "may_1": {
        physics: ["physics_units_measurements", "physics_kinematics"],
        chemistry: ["chemistry_basic_concepts", "chemistry_atomic_structure"],
        mathematics: ["mathematics_sets_relations_functions", "mathematics_trigonometry"]
      },
      "june_15": {
        physics: ["physics_laws_of_motion"],
        chemistry: ["chemistry_chemical_bonding", "chemistry_classification_periodicity"],
        mathematics: ["mathematics_complex_numbers"]
      },
      "august_1": {
        physics: ["physics_work_energy_power", "physics_rotational_motion"],
        chemistry: ["chemistry_equilibrium", "chemistry_thermodynamics"],
        mathematics: ["mathematics_permutations_and_combinations"]
      },
      "september_1": {
        physics: ["physics_gravitation"],
        chemistry: ["chemistry_redox_electrochemistry"],
        mathematics: ["mathematics_binomial_theorem", "mathematics_sequences_and_series"]
      },
      "october_1": {
        physics: ["physics_properties_of_solids_liquids", "physics_thermodynamics"],
        chemistry: ["chemistry_p_block_elements"],
        mathematics: ["mathematics_straight_lines", "mathematics_conic_sections_parabola"]
      },
      "november_1": {
        physics: ["physics_oscillations_waves"],
        chemistry: ["chemistry_general_organic_chemistry"],
        mathematics: ["mathematics_conic_sections_ellipse_hyperbola", "mathematics_3d_geometry"]
      },
      "december_1": {
        physics: ["physics_kinetic_theory_of_gases"],
        chemistry: ["chemistry_hydrocarbons"],
        mathematics: ["mathematics_limits_continuity_differentiability", "mathematics_statistics"]
      },
      "january_1": {
        physics: [],
        chemistry: [],
        mathematics: ["mathematics_probability"]
      },
      "february_1": {
        note: "Full revision month - all 11th chapters unlocked",
        all_11th_unlocked: true
      }
    },
    "12th_grade": {
      "april_1": {
        note: "All 11th chapters unlocked immediately for 12th students",
        unlock_all_11th: true,
        physics: ["physics_electrostatics"],
        chemistry: ["chemistry_solutions"],
        mathematics: ["mathematics_inverse_trigonometry"]
      },
      "may_1": {
        physics: ["physics_current_electricity"],
        chemistry: ["chemistry_redox_electrochemistry", "chemistry_chemical_kinetics"],
        mathematics: ["mathematics_matrices_determinants"]
      },
      "june_1": {
        physics: ["physics_magnetic_effects_magnetism"],
        chemistry: ["chemistry_d_f_block_elements", "chemistry_coordination_compounds"],
        mathematics: ["mathematics_limits_continuity_differentiability", "mathematics_differential_calculus_aod"]
      },
      "july_1": {
        physics: ["physics_electromagnetic_induction", "physics_electromagnetic_waves"],
        chemistry: ["chemistry_p_block_elements_12"],
        mathematics: ["mathematics_integral_calculus_indefinite", "mathematics_integral_calculus_definite_area"]
      },
      "august_1": {
        physics: ["physics_optics"],
        chemistry: ["chemistry_haloalkanes_and_haloarenes", "chemistry_alcohols_phenols_ethers"],
        mathematics: ["mathematics_differential_equations", "mathematics_vector_algebra"]
      },
      "september_1": {
        physics: ["physics_dual_nature_of_radiation", "physics_atoms_nuclei"],
        chemistry: ["chemistry_aldehydes_ketones", "chemistry_carboxylic_acids_derivatives"],
        mathematics: ["mathematics_3d_geometry_12"]
      },
      "october_1": {
        physics: ["physics_electronic_devices"],
        chemistry: ["chemistry_amines_diazonium_salts", "chemistry_biomolecules"],
        mathematics: ["mathematics_probability_12"]
      },
      "november_1": {
        note: "Syllabus complete - all chapters unlocked",
        all_unlocked: true
      },
      "december_1": {
        note: "Full 12th revision + JEE Main PYQs",
        mode: "revision",
        all_unlocked: true
      },
      "january_1": {
        note: "Speed tests, mocks, Main Attempt 1 preparation",
        mode: "jee_main_prep",
        all_unlocked: true
      }
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

const ACADEMIC_YEAR_START_MONTH = 4; // April

// Month name to number mapping
const MONTH_MAP = {
  january: 0, february: 1, march: 2, april: 3, may: 4, june: 5,
  july: 6, august: 7, september: 8, october: 9, november: 10, december: 11
};

/**
 * Determine grade timeline from target year and current date
 *
 * Logic:
 * - Academic year starts in April
 * - If targetYear - academicYear >= 2: 11th grade
 * - If targetYear - academicYear == 1: 12th grade
 * - If targetYear <= academicYear: Post-12th (all unlocked)
 */
function determineGradeTimeline(jeeTargetYear, currentDate = new Date()) {
  const currentYear = currentDate.getFullYear();
  const currentMonth = currentDate.getMonth() + 1; // 1-indexed

  // Academic year starts in April
  // If before April, we're still in previous academic year
  const academicYear = currentMonth >= ACADEMIC_YEAR_START_MONTH
    ? currentYear
    : currentYear - 1;

  const yearsUntilJEE = jeeTargetYear - academicYear;

  if (yearsUntilJEE >= 2) return "11th_grade";
  if (yearsUntilJEE === 1) return "12th_grade";
  return "post_12th"; // JEE year or past
}

/**
 * Parse date key from schedule format to Date object
 * Format: "month_day" (e.g., "may_1", "june_15")
 */
function parseDateKey(dateKey, year) {
  const [monthStr, dayStr] = dateKey.split('_');
  const month = MONTH_MAP[monthStr.toLowerCase()];
  const day = parseInt(dayStr, 10);

  if (month === undefined || isNaN(day)) {
    return null; // Invalid date key (e.g., "note")
  }

  return new Date(year, month, day);
}

/**
 * Get the academic year for unlock date calculation
 */
function getAcademicYearForGrade(currentDate, gradeTimeline, jeeTargetYear) {
  if (gradeTimeline === '11th_grade') {
    // 11th grade academic year is 2 years before JEE
    return jeeTargetYear - 2;
  } else if (gradeTimeline === '12th_grade') {
    // 12th grade academic year is 1 year before JEE
    return jeeTargetYear - 1;
  }
  return currentDate.getFullYear();
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
    .where('type', '==', 'grade_calendar')
    .where('active', '==', true)
    .limit(1)
    .get();

  if (snapshot.empty) {
    throw new Error('No active grade-based unlock schedule found');
  }

  scheduleCache = snapshot.docs[0].data();
  scheduleCacheTimestamp = now;
  return scheduleCache;
}

/**
 * Get all chapter keys from 11th grade calendar
 */
function getAll11thChapters(schedule) {
  const chapters = new Set();
  const calendar = schedule.calendars['11th_grade'];

  for (const [dateKey, data] of Object.entries(calendar)) {
    ['physics', 'chemistry', 'mathematics'].forEach(subject => {
      if (Array.isArray(data[subject])) {
        data[subject].forEach(ch => chapters.add(ch));
      }
    });
  }

  return Array.from(chapters);
}

/**
 * Get all chapter keys (for post-12th or all_unlocked)
 */
async function getAllChapterKeys() {
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
 */
async function getUnlockedChapters(userId, referenceDate = new Date()) {
  // Get user data
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    throw new Error(`User ${userId} not found`);
  }

  const userData = userDoc.data();

  // Backward compatibility: users without jeeTargetYear get all chapters
  if (!userData.jeeTargetYear) {
    logger.info('User has no jeeTargetYear, unlocking all chapters', { userId });
    return {
      unlockedChapterKeys: await getAllChapterKeys(),
      gradeTimeline: 'post_12th',
      isLegacyUser: true
    };
  }

  const schedule = await getActiveSchedule();
  const gradeTimeline = determineGradeTimeline(userData.jeeTargetYear, referenceDate);

  // Post-12th: unlock everything
  if (gradeTimeline === 'post_12th') {
    return {
      unlockedChapterKeys: await getAllChapterKeys(),
      gradeTimeline
    };
  }

  const calendar = schedule.calendars[gradeTimeline];
  const unlockedChapters = new Set();
  const academicYear = getAcademicYearForGrade(referenceDate, gradeTimeline, userData.jeeTargetYear);

  // If 12th grade, include all 11th chapters
  if (gradeTimeline === '12th_grade') {
    getAll11thChapters(schedule).forEach(ch => unlockedChapters.add(ch));
  }

  // Add chapters from calendar entries up to today's date
  for (const [dateKey, data] of Object.entries(calendar)) {
    // Skip non-date entries
    if (data.note && !data.physics && !data.chemistry && !data.mathematics) {
      continue;
    }

    // Handle special flags
    if (data.all_unlocked || data.all_11th_unlocked) {
      if (data.all_unlocked) {
        return {
          unlockedChapterKeys: await getAllChapterKeys(),
          gradeTimeline
        };
      }
      // all_11th_unlocked is already handled above for 12th grade
    }

    const unlockDate = parseDateKey(dateKey, academicYear);
    if (!unlockDate) continue;

    // For dates in next calendar year (Jan-Mar of 11th grade)
    // We need to check if we're past that date
    if (unlockDate <= referenceDate) {
      ['physics', 'chemistry', 'mathematics'].forEach(subject => {
        if (Array.isArray(data[subject])) {
          data[subject].forEach(ch => unlockedChapters.add(ch));
        }
      });
    }
  }

  // Add override chapters (manually unlocked)
  if (userData.chapterUnlockOverrides) {
    Object.keys(userData.chapterUnlockOverrides).forEach(ch => {
      unlockedChapters.add(ch);
    });
  }

  logger.info('Calculated unlocked chapters (grade-based)', {
    userId,
    gradeTimeline,
    academicYear,
    unlockedCount: unlockedChapters.size
  });

  return {
    unlockedChapterKeys: Array.from(unlockedChapters),
    gradeTimeline
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
  determineGradeTimeline,
  getUnlockedChapters,
  isChapterUnlocked,
  addChapterUnlockOverride,
  getActiveSchedule
};
```

---

## Mobile Onboarding Changes

### File: `mobile/lib/screens/onboarding/onboarding_step1_screen.dart`

Replace `currentClass` dropdown with JEE target year dropdown:

```dart
// State variable
int? _jeeTargetYear;

// In build method - replace currentClass dropdown with:
DropdownButtonFormField<int>(
  value: _jeeTargetYear,
  isExpanded: true,
  decoration: InputDecoration(
    hintText: 'Which year are you appearing for JEE?',
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  ),
  items: _getTargetYearOptions().map((year) {
    return DropdownMenuItem<int>(
      value: year,
      child: Text('JEE $year'),
    );
  }).toList(),
  onChanged: (value) => setState(() => _jeeTargetYear = value),
  validator: (value) {
    if (value == null) {
      return 'Please select your JEE target year';
    }
    return null;
  },
),

// Helper method
List<int> _getTargetYearOptions() {
  final now = DateTime.now();
  final currentYear = now.year;
  final currentMonth = now.month;

  // If before April (academic year hasn't started), include current year
  final startYear = currentMonth < 4 ? currentYear : currentYear + 1;

  return [
    startYear,
    startYear + 1,
    startYear + 2,
  ];
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
        'jeeTargetYear': _jeeTargetYear,  // NEW (int)
        'isEnrolledInCoaching': _isEnrolledInCoaching,
      },
    ),
  ),
);
```

---

## Daily Quiz Integration

Same as Option A - add to `dailyQuizService.js`:

```javascript
const { getUnlockedChapters } = require('./chapterUnlockService');

async function generateDailyQuizInternal(userId) {
  // ... existing code ...

  // Get unlocked chapters
  const unlockResult = await getUnlockedChapters(userId);
  const unlockedChapterKeys = new Set(unlockResult.unlockedChapterKeys);

  logger.info('Chapter unlock status for quiz generation', {
    userId,
    gradeTimeline: unlockResult.gradeTimeline,
    unlockedChapterCount: unlockedChapterKeys.size
  });

  // Filter chapter mappings
  if (allChapterMappings && allChapterMappings.size > 0) {
    const filteredMappings = new Map();
    for (const [chapterKey, value] of allChapterMappings.entries()) {
      if (unlockedChapterKeys.has(chapterKey)) {
        filteredMappings.set(chapterKey, value);
      }
    }
    allChapterMappings = filteredMappings;
  }

  // ... rest of existing code ...
}
```

---

## Backend Route Updates

### File: `backend/src/routes/users.js`

```javascript
// In POST /api/users/profile validation
body('jeeTargetYear')
  .optional()
  .isInt({ min: 2024, max: 2035 })
  .withMessage('jeeTargetYear must be a valid year between 2024 and 2035'),
```

---

## API Endpoints

### Route: `backend/src/routes/chapters.js`

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
        gradeTimeline: result.gradeTimeline
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

---

## Schedule Seeding Script

### File: `backend/scripts/seed-grade-schedule.js`

```javascript
/**
 * Seed the grade-based unlock schedule to Firestore
 * Based on inputs/guides/coaching_unlock_schedule_updated.json
 *
 * Run with: node backend/scripts/seed-grade-schedule.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('../config/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Load and transform the coaching schedule
const coachingSchedule = JSON.parse(
  fs.readFileSync(
    path.join(__dirname, '../../inputs/guides/coaching_unlock_schedule_updated.json'),
    'utf8'
  )
);

// Chapter ID to chapter_key mapping
const CHAPTER_ID_MAP = {
  // Physics 11th
  "PHY_11_CH01": "physics_units_measurements",
  "PHY_11_CH02": "physics_kinematics",
  "PHY_11_CH03": "physics_laws_of_motion",
  "PHY_11_CH04": "physics_work_energy_power",
  "PHY_11_CH05": "physics_rotational_motion",
  "PHY_11_CH06": "physics_gravitation",
  "PHY_11_CH07": "physics_properties_of_solids_liquids",
  "PHY_11_CH08": "physics_thermodynamics",
  "PHY_11_CH09": "physics_oscillations_waves",
  "PHY_11_CH10": "physics_kinetic_theory_of_gases",

  // Physics 12th
  "PHY_12_CH01": "physics_electrostatics",
  "PHY_12_CH02": "physics_current_electricity",
  "PHY_12_CH03": "physics_magnetic_effects_magnetism",
  "PHY_12_CH04": "physics_electromagnetic_induction",
  "PHY_12_CH05": "physics_electromagnetic_waves",
  "PHY_12_CH06": "physics_optics",
  "PHY_12_CH07": "physics_dual_nature_of_radiation",
  "PHY_12_CH08": "physics_atoms_nuclei",
  "PHY_12_CH09": "physics_electronic_devices",

  // Chemistry 11th
  "CHEM_11_CH01": "chemistry_basic_concepts",
  "CHEM_11_CH02": "chemistry_atomic_structure",
  "CHEM_11_CH03": "chemistry_chemical_bonding",
  "CHEM_11_CH04": "chemistry_classification_periodicity",
  "CHEM_11_CH05": "chemistry_equilibrium",
  "CHEM_11_CH06": "chemistry_thermodynamics",
  "CHEM_11_CH07": "chemistry_redox_electrochemistry",
  "CHEM_11_CH08": "chemistry_p_block_elements",
  "CHEM_11_CH09": "chemistry_general_organic_chemistry",
  "CHEM_11_CH10": "chemistry_hydrocarbons",

  // Chemistry 12th
  "CHEM_12_CH01": "chemistry_solutions",
  "CHEM_12_CH02": "chemistry_redox_electrochemistry",
  "CHEM_12_CH03": "chemistry_chemical_kinetics",
  "CHEM_12_CH04": "chemistry_d_f_block_elements",
  "CHEM_12_CH05": "chemistry_coordination_compounds",
  "CHEM_12_CH06": "chemistry_p_block_elements_12",
  "CHEM_12_CH07": "chemistry_haloalkanes_and_haloarenes",
  "CHEM_12_CH08": "chemistry_alcohols_phenols_ethers",
  "CHEM_12_CH09": "chemistry_aldehydes_ketones",
  "CHEM_12_CH10": "chemistry_carboxylic_acids_derivatives",
  "CHEM_12_CH11": "chemistry_amines_diazonium_salts",
  "CHEM_12_CH12": "chemistry_biomolecules",

  // Mathematics 11th
  "MATH_11_CH01": "mathematics_sets_relations_functions",
  "MATH_11_CH02": "mathematics_trigonometry",
  "MATH_11_CH03": "mathematics_complex_numbers",
  "MATH_11_CH04": "mathematics_permutations_and_combinations",
  "MATH_11_CH05": "mathematics_binomial_theorem",
  "MATH_11_CH06": "mathematics_sequences_and_series",
  "MATH_11_CH07": "mathematics_straight_lines",
  "MATH_11_CH08": "mathematics_conic_sections_parabola",
  "MATH_11_CH09": "mathematics_conic_sections_ellipse_hyperbola",
  "MATH_11_CH10": "mathematics_3d_geometry",
  "MATH_11_CH11": "mathematics_limits_continuity_differentiability",
  "MATH_11_CH12": "mathematics_statistics",
  "MATH_11_CH13": "mathematics_probability",

  // Mathematics 12th
  "MATH_12_CH01": "mathematics_sets_relations_functions_12",
  "MATH_12_CH02": "mathematics_inverse_trigonometry",
  "MATH_12_CH03": "mathematics_matrices_determinants",
  "MATH_12_CH04": "mathematics_limits_continuity_differentiability_12",
  "MATH_12_CH05": "mathematics_differential_calculus_aod",
  "MATH_12_CH06": "mathematics_integral_calculus_indefinite",
  "MATH_12_CH07": "mathematics_integral_calculus_definite_area",
  "MATH_12_CH08": "mathematics_differential_equations",
  "MATH_12_CH09": "mathematics_vector_algebra",
  "MATH_12_CH10": "mathematics_3d_geometry_12",
  "MATH_12_CH11": "mathematics_probability_12"
};

/**
 * Transform chapter IDs to chapter_keys
 */
function transformChapters(chaptersArray) {
  if (!Array.isArray(chaptersArray)) return [];
  return chaptersArray
    .map(ch => CHAPTER_ID_MAP[ch.id])
    .filter(Boolean);
}

/**
 * Transform the coaching schedule to our format
 */
function transformSchedule(source) {
  const result = {
    version: "v1_grade_based",
    type: "grade_calendar",
    active: true,
    created_at: admin.firestore.FieldValue.serverTimestamp(),

    jee_dates: {
      session_1: { start: "2027-01-20", end: "2027-01-30" },
      session_2: { start: "2027-04-01", end: "2027-04-15" }
    },

    calendars: {}
  };

  for (const [grade, calendar] of Object.entries(source.unlock_calendars)) {
    result.calendars[grade] = {};

    for (const [dateKey, data] of Object.entries(calendar)) {
      const transformed = {};

      // Copy flags
      if (data.note) transformed.note = data.note;
      if (data.unlock_all_11th) transformed.unlock_all_11th = true;
      if (data.mode) transformed.mode = data.mode;

      // Handle special "all unlocked" cases
      if (data.physics === 'all_11th_unlocked' || data.physics === 'all_12th_unlocked') {
        transformed.all_unlocked = true;
      } else {
        // Transform chapter arrays
        transformed.physics = transformChapters(data.physics);
        transformed.chemistry = transformChapters(data.chemistry);
        transformed.mathematics = transformChapters(data.mathematics);
      }

      result.calendars[grade][dateKey] = transformed;
    }
  }

  return result;
}

async function seedSchedule() {
  try {
    const schedule = transformSchedule(coachingSchedule);
    await db.collection('unlock_schedules').doc('v1_grade_based').set(schedule);
    console.log('Successfully seeded grade-based schedule');
    console.log('Calendars:', Object.keys(schedule.calendars));
  } catch (error) {
    console.error('Error seeding schedule:', error);
  } finally {
    process.exit();
  }
}

seedSchedule();
```

---

## Testing

### Unit Tests: `backend/src/services/__tests__/chapterUnlockService.test.js`

```javascript
const { determineGradeTimeline } = require('../chapterUnlockService');

describe('determineGradeTimeline', () => {
  test('May 2025, target 2027 = 11th grade', () => {
    const result = determineGradeTimeline(2027, new Date('2025-05-15'));
    expect(result).toBe('11th_grade');
  });

  test('March 2026, target 2027 = 11th grade (before April)', () => {
    // March 2026 is still academic year 2025
    const result = determineGradeTimeline(2027, new Date('2026-03-15'));
    expect(result).toBe('11th_grade');
  });

  test('April 2026, target 2027 = 12th grade', () => {
    // April 2026 is academic year 2026
    const result = determineGradeTimeline(2027, new Date('2026-04-15'));
    expect(result).toBe('12th_grade');
  });

  test('December 2026, target 2027 = 12th grade', () => {
    const result = determineGradeTimeline(2027, new Date('2026-12-15'));
    expect(result).toBe('12th_grade');
  });

  test('January 2027, target 2027 = post_12th (exam year)', () => {
    // January 2027 is still academic year 2026, but 2027-2026=1, so 12th
    // Wait, let me recalculate: Jan 2027, month < 4, so academic year = 2026
    // 2027 - 2026 = 1, so this should be 12th_grade
    const result = determineGradeTimeline(2027, new Date('2027-01-15'));
    expect(result).toBe('12th_grade');
  });

  test('April 2027, target 2027 = post_12th', () => {
    // April 2027 is academic year 2027
    // 2027 - 2027 = 0, so post_12th
    const result = determineGradeTimeline(2027, new Date('2027-04-15'));
    expect(result).toBe('post_12th');
  });

  test('Past target year = post_12th', () => {
    const result = determineGradeTimeline(2025, new Date('2026-05-15'));
    expect(result).toBe('post_12th');
  });
});
```
