# Fresh Data Load Scripts

Scripts for completely refreshing the question bank in Firebase (Firestore + Storage).

## Quick Start

```bash
cd backend

# Step 1: Preview what will be deleted
node scripts/data-load/cleanup-all-questions.js --preview
node scripts/data-load/cleanup-storage.js --preview

# Step 2a: Delete everything with backup (for fresh load)
node scripts/data-load/cleanup-all-questions.js --backup
node scripts/data-load/cleanup-storage.js --force

# Step 2b: OR Archive instead of delete (recommended for production)
node scripts/data-load/cleanup-all-questions.js --archive --reason "Replaced with v2 question bank"

# Step 3: Import new questions
node scripts/data-load/batch-import-questions.js --dir inputs/fresh_load --preview
node scripts/data-load/batch-import-questions.js --dir inputs/fresh_load

# Step 4: Verify
node scripts/cleanup-questions.js --list
```

## Question Lifecycle Management

All imported questions include an `active` field for soft delete support:

| Field | Type | Description |
|-------|------|-------------|
| `active` | boolean | `true` = question is active and can be served |
| `archived_at` | Timestamp | When the question was archived |
| `archived_reason` | string | Why the question was archived |

**Best Practices:**
- In production: Use `--archive` mode instead of delete
- Archived questions remain in DB but won't be served
- Can reactivate by setting `active: true`

---

## Folder Structure

### Expected Input Structure

```
inputs/
└── fresh_load/                    # Root folder for fresh data
    ├── Physics/                   # Subject folder
    │   ├── Mechanics/             # Chapter folder
    │   │   ├── question_list.json # Questions JSON
    │   │   ├── PHY_MECH_001.svg   # Image files (matching question IDs)
    │   │   └── PHY_MECH_002.svg
    │   ├── Thermodynamics/
    │   │   ├── question_list.json
    │   │   └── *.svg
    │   └── ...
    ├── Chemistry/
    │   ├── Chemical Bonding/
    │   │   ├── question_list.json
    │   │   └── *.svg
    │   └── ...
    ├── Mathematics/
    │   └── ...
    └── InitialAssessment/         # Special folder for diagnostic assessment
        ├── assessment_questions.json
        └── ASSESS_*.svg
```

### JSON File Names

The import script looks for these file names in each chapter folder:
- `question_list.json` (preferred)
- `questions.json`
- `question_bank.json`
- `assessment_questions.json`

---

## Scripts Reference

### 1. cleanup-all-questions.js

Deletes or archives all questions from Firestore collections.

**Collections affected:**
- `questions` (daily quiz / chapter practice)
- `initial_assessment_questions` (diagnostic assessment)

**Usage:**

```bash
# Preview (safe, no changes)
node scripts/data-load/cleanup-all-questions.js --preview

# Delete with backup (for dev/staging)
node scripts/data-load/cleanup-all-questions.js --backup

# Archive instead of delete (RECOMMENDED for production)
node scripts/data-load/cleanup-all-questions.js --archive --reason "Replaced with new question bank"

# Preview archive
node scripts/data-load/cleanup-all-questions.js --archive --preview

# Delete specific collection only
node scripts/data-load/cleanup-all-questions.js --collection questions --backup
node scripts/data-load/cleanup-all-questions.js --collection initial_assessment_questions --backup

# Force delete without confirmation (DANGEROUS)
node scripts/data-load/cleanup-all-questions.js --backup --force
```

**Archive vs Delete:**
| Mode | What happens | Use case |
|------|--------------|----------|
| `--archive` | Sets `active: false`, preserves data | Production - keeps history |
| (default) | Permanently deletes documents | Dev/staging fresh load |

**Backups saved to:** `backups/data-load/`

---

### 2. cleanup-storage.js

Deletes all files from Firebase Storage folders.

**Folders affected:**
- `questions/daily_quiz/`
- `questions/initial_assessment/`

**Usage:**

```bash
# Preview (safe, no changes)
node scripts/data-load/cleanup-storage.js --preview

# Delete all question images
node scripts/data-load/cleanup-storage.js

# Delete specific folder only
node scripts/data-load/cleanup-storage.js --folder questions/daily_quiz
node scripts/data-load/cleanup-storage.js --folder questions/initial_assessment

# Force delete without confirmation
node scripts/data-load/cleanup-storage.js --force
```

---

### 3. batch-import-questions.js

Imports questions from nested Subject/Chapter folder structure.

**Collections affected:**
- `questions` - For all Subject/Chapter folders
- `initial_assessment_questions` - For InitialAssessment folder

**Usage:**

```bash
# Preview (safe, no changes)
node scripts/data-load/batch-import-questions.js --dir inputs/fresh_load --preview

# Import all questions
node scripts/data-load/batch-import-questions.js --dir inputs/fresh_load

# Import specific subject only
node scripts/data-load/batch-import-questions.js --dir inputs/fresh_load --subject Physics

# Skip image uploads (just import JSON data)
node scripts/data-load/batch-import-questions.js --dir inputs/fresh_load --skip-images
```

---

## JSON Format

### Question JSON Structure

```json
{
  "PHY_MECH_001": {
    "question_id": "PHY_MECH_001",
    "subject": "Physics",
    "chapter": "Mechanics",
    "sub_topics": ["Newton's Laws", "Free Body Diagrams"],
    "question_type": "mcq_single",
    "question_text": "A block of mass 5 kg...",
    "options": ["10 N", "20 N", "30 N", "40 N"],
    "correct_answer": "B",
    "difficulty": "medium",
    "difficulty_irt": 0.5,
    "irt_parameters": {
      "difficulty_b": 0.5,
      "discrimination_a": 1.5,
      "guessing_c": 0.25,
      "calibration_status": "estimated"
    },
    "solution_text": "Using F = ma...",
    "solution_steps": [
      {
        "step_number": 1,
        "description": "Identify given values",
        "calculation": "m = 5 kg, a = 4 m/s²"
      }
    ],
    "has_image": true,
    "time_estimate": 90,
    "tags": ["newton-laws", "force"]
  }
}
```

### Required Fields

| Field | Description |
|-------|-------------|
| `subject` | Subject name (Physics, Chemistry, Mathematics) |
| `chapter` | Chapter name |
| `question_type` | "mcq_single" or "numerical" |
| `question_text` | The question text |
| `correct_answer` | Correct answer (A/B/C/D for MCQ, number for numerical) |
| `difficulty_irt` | IRT difficulty parameter (-3 to +3, 0 = medium) |

### Optional Fields

| Field | Description |
|-------|-------------|
| `options` | Array of 4 options (required for MCQ) |
| `solution_text` | Solution explanation |
| `solution_steps` | Step-by-step solution array |
| `has_image` | true if question has an SVG image |
| `sub_topics` | Array of subtopics |
| `tags` | Array of tags |
| `time_estimate` | Expected time in seconds (default: 90) |

### Auto-Generated Fields

These fields are automatically added by the import script:

| Field | Description |
|-------|-------------|
| `active` | `true` - question is active and can be served |
| `archived_at` | `null` - timestamp when archived |
| `archived_reason` | `null` - reason for archiving |
| `chapter_key` | Computed from subject + chapter (lowercase, normalized) |
| `created_date` | Server timestamp |
| `usage_stats` | Initialized with zeros |

---

## Image Files

- **Format:** SVG only
- **Naming:** Must match question_id exactly (e.g., `PHY_MECH_001.svg`)
- **Location:** Same folder as the question JSON file

### Storage Paths

| Collection | Storage Path |
|------------|--------------|
| questions | `questions/daily_quiz/{questionId}.svg` |
| initial_assessment_questions | `questions/initial_assessment/{questionId}.svg` |

---

## Complete Workflow Example

### 1. Download from Google Drive

```bash
# Download Subject folders from Google Drive to local
# Structure: Subject/Chapter/question_list.json + *.svg
```

### 2. Organize into fresh_load folder

```bash
mkdir -p inputs/fresh_load
cp -r ~/Downloads/Physics inputs/fresh_load/
cp -r ~/Downloads/Chemistry inputs/fresh_load/
cp -r ~/Downloads/Mathematics inputs/fresh_load/
cp -r ~/Downloads/InitialAssessment inputs/fresh_load/  # If applicable
```

### 3. Preview and verify structure

```bash
cd backend
node scripts/data-load/batch-import-questions.js --dir inputs/fresh_load --preview
```

### 4. Cleanup existing data

```bash
# Preview first
node scripts/data-load/cleanup-all-questions.js --preview
node scripts/data-load/cleanup-storage.js --preview

# Delete with backup
node scripts/data-load/cleanup-all-questions.js --backup
node scripts/data-load/cleanup-storage.js --force
```

### 5. Import new data

```bash
node scripts/data-load/batch-import-questions.js --dir inputs/fresh_load
```

### 6. Verify import

```bash
node scripts/cleanup-questions.js --list
```

---

## Troubleshooting

### "No question file found"

Ensure JSON file is named one of:
- `question_list.json`
- `questions.json`
- `question_bank.json`

### "Validation failed: Missing subject"

Check that all required fields are present in the JSON.

### Image upload fails

1. Ensure Firebase Storage is enabled
2. Check that SVG files are named exactly as `{question_id}.svg`
3. Verify SVG files are in the same folder as the JSON

### Permission errors

Run from the `backend` directory and ensure Firebase credentials are configured.

---

## Backup Recovery

If you need to restore from backup:

```bash
# Backups are in: backups/data-load/backup_{collection}_{timestamp}.json

# Move backup to import folder
cp backups/data-load/backup_questions_*.json inputs/question_bank/questions_recovery.json

# Import using existing script
node scripts/import-question-bank.js --file inputs/question_bank/questions_recovery.json
```

---

## Files

```
backend/scripts/data-load/
├── README.md                      # This file
├── cleanup-all-questions.js       # Delete Firestore collections
├── cleanup-storage.js             # Delete Storage files
└── batch-import-questions.js      # Import from nested folders

backups/data-load/                 # Backup files saved here
├── backup_questions_*.json
└── backup_initial_assessment_questions_*.json
```
