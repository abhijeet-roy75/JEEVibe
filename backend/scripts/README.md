# Backend Scripts

This directory contains utility scripts for managing the JEEVibe backend, particularly for question bank management, testing, and maintenance.

## Quick Links

- **[Question Bank Management Guide](QUESTION_BANK_MANAGEMENT.md)** - Complete guide for importing and managing questions

## Scripts Overview

### Question Bank Management

#### `import-question-bank.js` ⭐
Import questions from JSON files into Firestore.

**Key Features:**
- Reads JSON files from `inputs/question_bank/`
- Validates question structure
- Uploads SVG images to Firebase Storage
- Idempotent (skips existing questions)
- Moves processed files to `processed/` folder

**Usage:**
```bash
# Import all questions
node scripts/import-question-bank.js

# Import specific file
node scripts/import-question-bank.js --file inputs/question_bank/questions_math.json
```

#### `cleanup-questions.js` ⭐ NEW!
Safely delete questions from Firestore with preview and backup options.

**Key Features:**
- Preview mode (dry run)
- Backup before deletion
- Multiple filter options (subject, chapter, IDs, pattern)
- Safe confirmation prompts
- List all subjects and chapters

**Usage:**
```bash
# List all questions
node scripts/cleanup-questions.js --list

# Preview deletion
node scripts/cleanup-questions.js --subject Math --preview

# Delete with backup
node scripts/cleanup-questions.js --subject Math --backup
```

**See [QUESTION_BANK_MANAGEMENT.md](QUESTION_BANK_MANAGEMENT.md) for complete documentation.**

---

### Assessment Management

#### `populate-assessment-questions.js`
Populate the assessment question pool.

**Usage:**
```bash
node scripts/populate-assessment-questions.js
```

#### `create-weekly-snapshots.js`
Create weekly snapshots of student theta parameters.

**Usage:**
```bash
node scripts/create-weekly-snapshots.js
```

---

### Utilities

#### `check-question-count.js`
Check the number of questions in the database.

**Usage:**
```bash
node scripts/check-question-count.js
```

#### `update-question-images.js`
Update or fix question image URLs.

**Usage:**
```bash
node scripts/update-question-images.js
```

---

### Testing Scripts

#### `test-assessment-api.js`
Test the assessment API endpoints.

**Usage:**
```bash
node scripts/test-assessment-api.js
```

#### `test-assessment-theta.js`
Test theta parameter calculations.

**Usage:**
```bash
node scripts/test-assessment-theta.js
```

#### `test-circuit-breaker.js`
Test circuit breaker functionality.

**Usage:**
```bash
node scripts/test-circuit-breaker.js
```

#### `test-scenarios-simulation.js`
Run scenario simulations for testing.

**Usage:**
```bash
node scripts/test-scenarios-simulation.js
```

#### `test-multiple-scenarios.js`
Test multiple assessment scenarios.

**Usage:**
```bash
node scripts/test-multiple-scenarios.js
```

---

### Server Management

#### `kill-server.sh`
Kill any running backend server processes.

**Usage:**
```bash
./scripts/kill-server.sh
```

---

## Common Workflows

### 1. Replace Old Questions with New Ones

```bash
# Step 1: List current questions
node scripts/cleanup-questions.js --list

# Step 2: Preview deletion
node scripts/cleanup-questions.js --subject Math --preview

# Step 3: Delete with backup
node scripts/cleanup-questions.js --subject Math --backup

# Step 4: Copy new files to inputs/question_bank/
cp ~/Downloads/questions_math_*.json ../inputs/question_bank/

# Step 5: Import new questions
node scripts/import-question-bank.js

# Step 6: Verify
node scripts/cleanup-questions.js --list
```

**Or use the automated workflow:**
```bash
./scripts/example-workflow.sh
```

### 2. Update a Specific Chapter

```bash
# Preview
node scripts/cleanup-questions.js --chapter-key math_algebra --preview

# Delete with backup
node scripts/cleanup-questions.js --chapter-key math_algebra --backup

# Import new file
node scripts/import-question-bank.js --file inputs/question_bank/questions_math_algebra_v2.json
```

### 3. Check Question Bank Status

```bash
# Count questions
node scripts/check-question-count.js

# List by subject/chapter
node scripts/cleanup-questions.js --list
```

### 4. Run Tests

```bash
# Run all tests
cd backend
npm test

# Run specific test script
node scripts/test-assessment-api.js
```

---

## File Locations

### Input Files
```
inputs/
└── question_bank/
    ├── questions_*.json          # New question files to import
    ├── *.svg                      # Question images
    └── processed/                 # Processed files (moved after import)
```

### Output Files
```
backend/
├── backups/
│   └── questions/                # Deletion backups (timestamped JSON files)
└── logs/
    ├── combined.log              # All logs
    └── error.log                 # Error logs only
```

---

## Environment Setup

All scripts use Firebase configuration from:
- `backend/src/config/firebase.js`
- `backend/serviceAccountKey.json` (not in git)

Make sure Firebase is properly configured before running scripts.

---

## Tips

### ✅ Best Practices

1. **Always preview first**: Use `--preview` with cleanup script
2. **Always backup**: Use `--backup` when deleting questions
3. **Test with small batches**: Import/delete a few questions first to test
4. **Keep processed files**: Don't delete `inputs/question_bank/processed/`
5. **Check logs**: Review `logs/` after running scripts

### ⚠️ Common Issues

**Issue**: "Firebase not initialized"
- **Solution**: Make sure `serviceAccountKey.json` exists and is valid

**Issue**: "Image not found"
- **Solution**: Place SVG files in same directory as JSON file, named `{question_id}.svg`

**Issue**: "No questions found"
- **Solution**: Use `--list` to see available subjects/chapters. Check spelling/case.

---

## Need Help?

1. Check **[QUESTION_BANK_MANAGEMENT.md](QUESTION_BANK_MANAGEMENT.md)** for detailed documentation
2. Use `--preview` to understand what will happen before making changes
3. Always keep backups of your original files
4. Review logs in `backend/logs/` for error details

---

## Script Index

| Script | Purpose | Documentation |
|--------|---------|---------------|
| `import-question-bank.js` | Import questions from JSON | [Guide](QUESTION_BANK_MANAGEMENT.md#importing-questions) |
| `cleanup-questions.js` | Delete questions safely | [Guide](QUESTION_BANK_MANAGEMENT.md#cleaning-up-questions) |
| `example-workflow.sh` | Automated workflow | [Guide](QUESTION_BANK_MANAGEMENT.md#workflow-replacing-old-questions-with-new-ones) |
| `populate-assessment-questions.js` | Setup assessment pool | Run with `node` |
| `create-weekly-snapshots.js` | Create theta snapshots | Run with `node` |
| `check-question-count.js` | Count questions | Run with `node` |
| `update-question-images.js` | Fix image URLs | Run with `node` |
| `test-*.js` | Various tests | Run with `node` |
| `kill-server.sh` | Kill server processes | Run with `./` |

---

Last Updated: December 17, 2024

