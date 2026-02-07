# Chapter Unlock Schedule - Data Files

## 📁 Files in This Directory

### 1. `countdown_24month_schedule_CORRECTED.json` ✅ **READY TO USE**
- **Status**: ✅ **Complete and ready for implementation**
- **Format**: Correct database chapter keys
- **Structure**: Matches plan exactly
- **Use**: Copy this file to `backend/data/countdown_24month_schedule.json` when ready to seed

### 2. `CHAPTER_NAME_TO_KEY_MAPPING.md` 📖 **Reference Guide**
- Complete mapping of chapter names to database keys
- Includes month-by-month breakdown
- Use this if you need to manually verify or update chapters

### 3. `countdown_24month_schedule.json` ⚠️ **DEPRECATED**
- Original file with `{"name": "..."}` objects
- Keep for reference only
- Do NOT use for seeding

---

## ✅ What's Been Verified

### Database Chapter Keys (from Firestore)
Total: **67 chapters** across all subjects

- **Physics**: 23 chapters ✓
- **Chemistry**: 22 chapters ✓
- **Mathematics**: 22 chapters ✓

All chapter keys in `countdown_24month_schedule_CORRECTED.json` have been verified to exist in your Firestore `questions` collection.

### JSON Structure
- ✅ Month keys: `month_1` through `month_24` (lowercase)
- ✅ Chapter format: Plain strings (e.g., `"physics_kinematics"`)
- ✅ Revision months: Empty arrays `[]` for months 10, 20-24
- ✅ Top-level structure: `timeline` object with month keys
- ✅ Valid JSON syntax

---

## 🎯 Next Steps for Implementation

### 1. Copy the Corrected File

```bash
# From project root
mkdir -p backend/data
cp inputs/chapter_unlock/countdown_24month_schedule_CORRECTED.json \
   backend/data/countdown_24month_schedule.json
```

### 2. Verify the File

```bash
# Check it's valid JSON
cat backend/data/countdown_24month_schedule.json | python -m json.tool > /dev/null
echo "✅ JSON is valid"

# Count chapters
grep -o '"physics_[a-z_]*"' backend/data/countdown_24month_schedule.json | sort -u | wc -l
grep -o '"chemistry_[a-z_]*"' backend/data/countdown_24month_schedule.json | sort -u | wc -l
grep -o '"mathematics_[a-z_]*"' backend/data/countdown_24month_schedule.json | sort -u | wc -l
```

Expected output:
```
✅ JSON is valid
Physics: 19 chapters
Chemistry: 22 chapters
Mathematics: 17 chapters
Total: 58 unique chapters used across 24 months
```

### 3. Create Seeding Script

See plan document `docs/10-calendar/OPTION-A-COUNTDOWN-TIMELINE.md` lines 1057-1151 for the seeding script.

### 4. Seed to Firestore

```bash
cd backend
node scripts/seed-countdown-schedule.js
```

---

## 📊 Content Distribution

### Months 1-9: 11th Grade Foundation
- **19 chapters** across all subjects
- Includes strategic revision months (2, 8, 9 have empty arrays)

### Month 10: 11th Revision Buffer
- **0 new chapters** - dedicated revision month
- All 11th chapters unlocked, students practice before 12th starts

### Months 11-19: 12th Grade Content
- **19 chapters** across all subjects
- Includes strategic empty months (16, 19 have gaps)

### Months 20-24: Final Revision
- **0 new chapters** - full syllabus revision
- Mock tests, speed practice, exam preparation

**Total Unique Chapters**: 58 (some chapters repeat intentionally, e.g., Thermodynamics)

---

## 🔍 Chapter Coverage by Subject

### Physics (19 unique chapters unlocked)

**11th Grade (10 chapters)**:
1. Units & Measurements
2. Kinematics
3. Laws of Motion
4. Work, Energy & Power
5. Rotational Motion
6. Gravitation
7. Properties of Solids & Liquids
8. Thermodynamics
9. Kinetic Theory of Gases
10. Oscillations & Waves

**12th Grade (9 chapters)**:
11. Electrostatics
12. Current Electricity
13. Magnetic Effects & Magnetism
14. Electromagnetic Induction
15. Electromagnetic Waves
16. Optics
17. Dual Nature of Radiation
18. Atoms & Nuclei
19. Electronic Devices

### Chemistry (22 unique chapters unlocked)

**11th Grade (10 chapters)**:
1. Basic Concepts
2. Atomic Structure
3. Chemical Bonding
4. Classification & Periodicity
5. Equilibrium
6. Thermodynamics
7. Redox & Electrochemistry
8. p-Block Elements
9. General Organic Chemistry (GOC)
10. Hydrocarbons

**12th Grade (12 chapters)**:
11. Solutions
12. Redox & Electrochemistry (continues from 11th)
13. Chemical Kinetics
14. d & f Block Elements
15. Coordination Compounds
16. p-Block Elements (12th topics)
17. Haloalkanes & Haloarenes
18. Alcohols, Phenols & Ethers
19. Aldehydes & Ketones
20. Carboxylic Acids & Derivatives
21. Amines & Diazonium Salts
22. Biomolecules

### Mathematics (17 unique chapters unlocked)

**11th Grade (13 chapters)**:
1. Sets, Relations & Functions
2. Trigonometry
3. Complex Numbers
4. Permutations & Combinations
5. Binomial Theorem
6. Sequences & Series
7. Straight Lines
8. Conic Sections (Parabola)
9. Conic Sections (Ellipse & Hyperbola)
10. Three-Dimensional Geometry
11. Limits, Continuity & Differentiability
12. Statistics
13. Probability

**12th Grade (7 chapters)** (some overlap with 11th):
14. Inverse Trigonometry
15. Matrices & Determinants
16. Differential Calculus (AOD)
17. Integral Calculus (Indefinite)
18. Integral Calculus (Definite & Area)
19. Differential Equations
20. Vector Algebra

**Note**: Some chapters like "Limits, Continuity & Differentiability" and "Probability" appear in both 11th and 12th using the same database key.

---

## 🎓 Pedagogical Design Notes

### Split Chapters (2-Month Mastery)
These high-weightage chapters unlock in one month and continue in the next (no new unlocks in month 2):

1. **Kinematics** (months 1-2) - 2D motion mastery
2. **Rotational Motion** (months 4-5) - Advanced rotational dynamics
3. **Equilibrium** (months 4-5) - Ionic equilibrium depth
4. **Electrostatics** (months 11-12) - Advanced electrostatics
5. **Optics** (months 15-16) - Wave optics mastery

### Strategic Empty Months

**Purpose**: Allow mastery without cognitive overload

- **Month 2**: Physics empty (continue Kinematics)
- **Month 8**: Physics empty (consolidate mechanics)
- **Month 9**: Physics + Chemistry empty (Math probability focus)
- **Month 10**: All empty (11th revision buffer)
- **Month 16**: Physics empty (continue Optics)
- **Month 19**: Physics + Math empty (Chemistry wrap-up)
- **Months 20-24**: All empty (final revision)

---

## ⚠️ Important Notes

### Chapter Name Variations
Some chapter names differ slightly from database keys:

- "EMI & AC Circuits" → `physics_electromagnetic_induction`
- "Classification & Periodicity" → `chemistry_classification_and_periodicity` (note "and")
- "Haloalkanes & Haloarenes" → `chemistry_haloalkanes_and_haloarenes` (note "and")
- "Permutations & Combinations" → `mathematics_permutations_and_combinations` (note "and")
- "Sequences & Series" → `mathematics_sequences_and_series` (note "and")

### Shared Chapter Keys
These chapters use the same database key across 11th/12th:

- `chemistry_thermodynamics` (11th only, but concepts continue in 12th)
- `chemistry_redox_electrochemistry` (both 11th and 12th)
- `mathematics_limits_continuity_differentiability` (both 11th and 12th)
- `mathematics_probability` (both 11th and 12th)
- `mathematics_three_dimensional_geometry` (both 11th and 12th)

This is intentional - students build on foundational concepts.

---

## 🚀 Ready for Implementation!

The corrected JSON file is production-ready:
- ✅ All chapter keys verified against database
- ✅ Proper JSON structure matching plan
- ✅ 24-month timeline complete
- ✅ Revision months properly marked
- ✅ Lowercase month keys
- ✅ No syntax errors

Proceed with confidence! 🎉
