# Question Bank Management Guide

This guide explains how to manage your question bank: importing new questions and cleaning up old ones.

## Table of Contents

1. [Importing Questions](#importing-questions)
2. [Cleaning Up Questions](#cleaning-up-questions)
3. [Workflow: Replacing Old Questions with New Ones](#workflow-replacing-old-questions-with-new-ones)
4. [Backup and Recovery](#backup-and-recovery)

---

## Importing Questions

### Script: `import-question-bank.js`

This script reads JSON files from the `inputs/question_bank` folder and imports them into Firestore.

### How It Works

1. **Reads JSON files** from `inputs/question_bank/` folder
2. **Validates** question structure (required fields, IRT parameters, etc.)
3. **Uploads SVG images** to Firebase Storage (if `has_image: true`)
4. **Writes to Firestore** in batches (efficient)
5. **Idempotent**: Skips questions that already exist
6. **Moves processed files** (JSON + images) to `inputs/question_bank/processed/` folder

### Usage

#### Import all question files in the default directory

```bash
cd backend
node scripts/import-question-bank.js
```

#### Import a specific file

```bash
node scripts/import-question-bank.js --file inputs/question_bank/questions_math_algebra.json
```

#### Import from a custom directory

```bash
node scripts/import-question-bank.js --dir inputs/question_bank
```

### JSON File Format

Your JSON files should be named with the pattern: `questions_*.json`

Supported formats:

**Format 1: Object with question IDs as keys**
```json
{
  "MATH_ALG_E_001": {
    "subject": "Math",
    "chapter": "Algebra",
    "question_type": "mcq_single",
    "question_text": "Solve for x: 2x + 5 = 15",
    "correct_answer": "A",
    "options": ["5", "10", "15", "20"],
    "difficulty_irt": 0.5,
    "has_image": false
  },
  "MATH_ALG_E_002": { ... }
}
```

**Format 2: Array of questions**
```json
[
  {
    "question_id": "MATH_ALG_E_001",
    "subject": "Math",
    "chapter": "Algebra",
    ...
  },
  {
    "question_id": "MATH_ALG_E_002",
    ...
  }
]
```

**Format 3: Object with questions array**
```json
{
  "questions": [
    {
      "question_id": "MATH_ALG_E_001",
      "subject": "Math",
      ...
    }
  ]
}
```

### Required Fields

- `subject`: Subject name (e.g., "Physics", "Chemistry", "Math")
- `chapter`: Chapter name (e.g., "Algebra", "Chemical Bonding")
- `question_type`: "mcq_single" or "numerical"
- `question_text`: The question text
- `correct_answer`: The correct answer
- `difficulty_irt`: IRT difficulty parameter (or `irt_parameters.difficulty_b`)

### Images

If your question has an image:
1. Set `has_image: true` in the JSON
2. Place the SVG file in the same directory as the JSON file
3. Name the SVG file with the question ID: `{question_id}.svg`
   - Example: `MATH_ALG_E_001.svg`

The script will automatically upload images to Firebase Storage and set the `image_url` field.

---

## Cleaning Up Questions

### Script: `cleanup-questions.js`

This script helps you delete questions from Firestore safely, with preview and backup options.

### Features

✅ **Preview mode**: See what will be deleted without actually deleting  
✅ **Backup option**: Export questions to JSON before deletion  
✅ **Multiple filters**: Delete by subject, chapter, chapter_key, IDs, or pattern  
✅ **Safe confirmation**: Requires typing "DELETE" to confirm  
✅ **List mode**: View all subjects and chapters in your database  

### Usage

#### 1. List all subjects and chapters

```bash
cd backend
node scripts/cleanup-questions.js --list
```

This shows you:
- All subjects and their question counts
- All chapters within each subject
- Chapter keys for each chapter

#### 2. Preview what will be deleted (SAFE - doesn't delete anything)

```bash
# Preview by subject
node scripts/cleanup-questions.js --subject Chemistry --preview

# Preview by chapter
node scripts/cleanup-questions.js --chapter "Chemical Bonding" --preview

# Preview by chapter key
node scripts/cleanup-questions.js --chapter-key chemistry_chemical_bonding --preview

# Preview by ID pattern (RegEx)
node scripts/cleanup-questions.js --pattern "^CHEM_BOND_.*" --preview
```

#### 3. Delete with backup (RECOMMENDED)

```bash
# Delete all Chemistry questions with backup
node scripts/cleanup-questions.js --subject Chemistry --backup

# Delete specific chapter with backup
node scripts/cleanup-questions.js --chapter-key math_matrices_determinants --backup
```

This will:
1. Save all questions to a backup JSON file in `backups/questions/`
2. Ask for confirmation (type "DELETE")
3. Delete the questions

#### 4. Delete without backup (BE CAREFUL!)

```bash
# You'll still be asked to confirm
node scripts/cleanup-questions.js --subject Math

# Force delete without confirmation (DANGEROUS!)
node scripts/cleanup-questions.js --subject Math --force
```

#### 5. Delete specific question IDs

```bash
# Single ID
node scripts/cleanup-questions.js --ids CHEM_BOND_E_001

# Multiple IDs (comma-separated)
node scripts/cleanup-questions.js --ids CHEM_BOND_E_001,CHEM_BOND_E_002,CHEM_BOND_E_003 --backup
```

#### 6. Delete by pattern (RegEx on question IDs)

```bash
# Delete all easy chemistry bonding questions
node scripts/cleanup-questions.js --pattern "^CHEM_BOND_E_.*" --preview

# Delete all medium physics magnetism questions
node scripts/cleanup-questions.js --pattern "^PHY_MAGN_M_.*" --backup
```

### Command Options

| Option | Description | Example |
|--------|-------------|---------|
| `--list` | List all subjects and chapters | `--list` |
| `--subject <name>` | Filter by subject | `--subject Chemistry` |
| `--chapter <name>` | Filter by chapter | `--chapter "Chemical Bonding"` |
| `--chapter-key <key>` | Filter by chapter_key | `--chapter-key chemistry_chemical_bonding` |
| `--ids <id1,id2>` | Delete specific IDs | `--ids CHEM_001,CHEM_002` |
| `--pattern <regex>` | Delete by ID pattern | `--pattern "^CHEM_.*"` |
| `--preview` | Preview without deleting | `--preview` |
| `--backup` | Backup before deleting | `--backup` |
| `--force` | Skip confirmation | `--force` (dangerous!) |

---

## Workflow: Replacing Old Questions with New Ones

Let's say you have new Math and Chemistry question files and want to replace the old ones.

### Step 1: List current questions

```bash
cd backend
node scripts/cleanup-questions.js --list
```

Output example:
```
📚 Total Questions: 450

📖 Breakdown by Subject and Chapter:

Chemistry (150 questions)
  └─ Chemical Bonding
     • Count: 75
     • Chapter Key: chemistry_chemical_bonding
  └─ Organic Chemistry
     • Count: 75
     • Chapter Key: chemistry_organic_chemistry

Math (150 questions)
  └─ Algebra
     • Count: 50
     • Chapter Key: math_algebra
  └─ Calculus
     • Count: 100
     • Chapter Key: math_calculus

Physics (150 questions)
  └─ Mechanics
     • Count: 75
     • Chapter Key: physics_mechanics
```

### Step 2: Preview what you'll delete

```bash
# Preview Math questions to be deleted
node scripts/cleanup-questions.js --subject Math --preview

# Preview Chemistry questions to be deleted
node scripts/cleanup-questions.js --subject Chemistry --preview
```

### Step 3: Backup and delete old questions

```bash
# Delete Math questions with backup
node scripts/cleanup-questions.js --subject Math --backup

# Delete Chemistry questions with backup
node scripts/cleanup-questions.js --subject Chemistry --backup
```

You'll be prompted:
```
⚠️  You are about to delete 150 questions. This action cannot be undone!
   Type 'DELETE' to confirm (or anything else to cancel): DELETE
```

### Step 4: Place new question files

```bash
# Copy your new files to the question_bank folder
cp ~/Downloads/questions_math_*.json inputs/question_bank/
cp ~/Downloads/questions_chem_*.json inputs/question_bank/
cp ~/Downloads/*.svg inputs/question_bank/  # If you have images
```

### Step 5: Import new questions

```bash
# Import all new questions
node scripts/import-question-bank.js
```

The script will:
- Process all `questions_*.json` files
- Upload any SVG images
- Move processed files to `inputs/question_bank/processed/`

### Step 6: Verify

```bash
# List questions again to verify
node scripts/cleanup-questions.js --list
```

---

## Backup and Recovery

### Backup Locations

- **Import backups**: Not needed - original files are moved to `inputs/question_bank/processed/`
- **Deletion backups**: Stored in `backups/questions/` with timestamp
  - Example: `cleanup_chemistry_2024-12-17T10-30-45-123Z.json`

### Recovering from Backup

If you accidentally deleted questions and have a backup:

1. **Find your backup file** in `backups/questions/`
2. **Move it to the import directory**:
   ```bash
   cp backups/questions/cleanup_chemistry_*.json inputs/question_bank/questions_chemistry_recovery.json
   ```
3. **Import it back**:
   ```bash
   node scripts/import-question-bank.js --file inputs/question_bank/questions_chemistry_recovery.json
   ```

### Backup Format

Backup files are JSON objects with question IDs as keys:

```json
{
  "CHEM_BOND_E_001": {
    "subject": "Chemistry",
    "chapter": "Chemical Bonding",
    ...
  },
  "CHEM_BOND_E_002": { ... }
}
```

This format is compatible with the import script!

---

## Tips and Best Practices

### ✅ Do's

1. **Always preview first**: Use `--preview` to see what will be deleted
2. **Always backup**: Use `--backup` when deleting questions
3. **Use specific filters**: Delete by `chapter_key` for precision
4. **Test with small batches**: Try deleting a few questions first
5. **Keep original files**: Don't delete files in `inputs/question_bank/processed/`

### ❌ Don'ts

1. **Don't use `--force`**: Unless you're 100% sure
2. **Don't delete without preview**: Always check first
3. **Don't use broad patterns**: Be specific with `--pattern`
4. **Don't skip backups**: You might need them later

### Common Scenarios

#### Scenario 1: Update a specific chapter

```bash
# Preview
node scripts/cleanup-questions.js --chapter-key math_algebra --preview

# Delete with backup
node scripts/cleanup-questions.js --chapter-key math_algebra --backup

# Import new file
node scripts/import-question-bank.js --file inputs/question_bank/questions_math_algebra_v2.json
```

#### Scenario 2: Remove test questions

```bash
# Delete questions with "TEST" prefix
node scripts/cleanup-questions.js --pattern "^TEST_.*" --preview
node scripts/cleanup-questions.js --pattern "^TEST_.*" --backup
```

#### Scenario 3: Clean up duplicates

```bash
# Delete specific duplicate IDs
node scripts/cleanup-questions.js --ids CHEM_001_DUP,CHEM_002_DUP --backup
```

---

## Troubleshooting

### Import Script Issues

**Issue**: "Image file not found"
- **Solution**: Make sure the SVG file is in the same directory as the JSON file and named correctly (`{question_id}.svg`)

**Issue**: "Validation failed: Missing subject"
- **Solution**: Check your JSON file - all required fields must be present

**Issue**: "Firebase Storage not enabled"
- **Solution**: Enable Firebase Storage in your Firebase Console

### Cleanup Script Issues

**Issue**: "No questions found matching criteria"
- **Solution**: Use `--list` to see available subjects and chapters. Check for exact spelling and case.

**Issue**: Script seems stuck
- **Solution**: For large deletions, it may take time. The script processes in batches of 500.

**Issue**: "Permission denied" when creating backup
- **Solution**: Make sure the `backups/questions/` directory is writable

---

## Summary

### Quick Reference

```bash
# LIST questions
node scripts/cleanup-questions.js --list

# PREVIEW deletion
node scripts/cleanup-questions.js --subject Math --preview

# DELETE with backup (RECOMMENDED)
node scripts/cleanup-questions.js --subject Math --backup

# IMPORT new questions
node scripts/import-question-bank.js
```

### Files and Directories

```
backend/
├── scripts/
│   ├── import-question-bank.js       # Import questions
│   ├── cleanup-questions.js           # Delete questions
│   └── QUESTION_BANK_MANAGEMENT.md   # This guide
├── backups/
│   └── questions/                     # Deletion backups
└── ...

inputs/
└── question_bank/
    ├── questions_*.json              # New files to import
    ├── *.svg                          # Question images
    └── processed/                     # Processed files (keep as backup)
```

---

## Need Help?

If you encounter any issues:

1. Check this guide first
2. Use `--preview` to understand what will happen
3. Always keep backups of your original files
4. Test with a small subset of questions first

Happy question bank management! 🎓

