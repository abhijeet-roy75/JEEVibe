# Single Question Update Guide

## Quick Start

Update a single question in Firestore from a JSON file.

### Usage

```bash
node backend/scripts/update-single-question.js <question-id> <json-file-path>
```

### Examples

**Example 1: Update CHEM_PURC_E_028**
```bash
# If your JSON file is at inputs/questions/CHEM_PURC_E_028.json
node backend/scripts/update-single-question.js CHEM_PURC_E_028 inputs/questions/CHEM_PURC_E_028.json
```

**Example 2: From a file with multiple questions**
```bash
# The script will find the question by ID in the array
node backend/scripts/update-single-question.js PHY_MECH_M_001 inputs/question_bank/physics_mechanics.json
```

## JSON File Formats Supported

### Format 1: Single Question Object
```json
{
  "question_id": "CHEM_PURC_E_028",
  "subject": "Chemistry",
  "chapter": "Purification and Characterisation of Organic Compounds",
  "question_type": "mcq_single",
  "question_text": "The question text...",
  "options": [
    { "option_id": "A", "text": "Option A" },
    { "option_id": "B", "text": "Option B" },
    { "option_id": "C", "text": "Option C" },
    { "option_id": "D", "text": "Option D" }
  ],
  "correct_answer": "B",
  "irt_parameters": {
    "difficulty_b": 0.5,
    "discrimination_a": 1.2,
    "guessing_c": 0.25
  }
}
```

### Format 2: Array of Questions
```json
[
  {
    "question_id": "CHEM_PURC_E_028",
    "subject": "Chemistry",
    ...
  },
  {
    "question_id": "CHEM_PURC_E_029",
    ...
  }
]
```

### Format 3: Object with Questions Array
```json
{
  "subject": "Chemistry",
  "chapter": "Purification",
  "questions": [
    {
      "question_id": "CHEM_PURC_E_028",
      ...
    }
  ]
}
```

## What the Script Does

1. **Reads** the JSON file
2. **Finds** the question by ID (if multiple questions in file)
3. **Validates** required fields
4. **Computes** `chapter_key` if not present (e.g., "chemistry_purification_and_characterisation_of_organic_compounds")
5. **Uploads** image to Firebase Storage (if `has_image: true` and image file exists)
6. **Updates** Firestore with `set({ merge: true })` (preserves existing fields not in JSON)
7. **Adds** `updated_at` timestamp

## Image Handling

If your question has an image:

1. Set `"has_image": true` in JSON
2. Place image file in same directory as JSON file
3. Name it: `{QUESTION_ID}.svg` (e.g., `CHEM_PURC_E_028.svg`)

The script will automatically upload it to Firebase Storage.

## Required Fields

### All Questions
- `subject` - "Physics", "Chemistry", or "Mathematics"
- `chapter` - Chapter name
- `question_type` - "mcq_single" or "numerical"

### MCQ Questions
- `options` - Array of option objects
- `correct_answer` - Correct option ID (e.g., "B")

### Numerical Questions
At least one of:
- `correct_answer` - The correct numeric answer
- `answer_range` - Object with `{ min, max }`
- `correct_answer_exact` - Exact numeric value (NOT a string!)

## Common Issues

### Issue 1: Question Not Found in JSON
**Error:** `Question CHEM_PURC_E_028 not found in JSON file`

**Solution:** Check that:
- The JSON file contains the question with that exact ID
- The `question_id` field matches exactly (case-sensitive)

### Issue 2: Invalid `correct_answer_exact`
**Error:** `correct_answer_exact must be numeric, not a string`

**Solution:** For numerical questions:
```json
// ❌ Wrong
"correct_answer_exact": "C2H4O2"

// ✅ Correct (for numerical questions)
"correct_answer_exact": 42.5

// ✅ Or for chemical formula (use MCQ format)
"question_type": "mcq_single",
"correct_answer": "C2H4O2"
```

### Issue 3: Image Not Found
**Warning:** `Image file not found: inputs/questions/CHEM_PURC_E_028.svg`

**Solution:**
- Place image in same directory as JSON file
- Name it exactly: `{QUESTION_ID}.svg`
- Or set `"has_image": false` if no image needed

## Checking the Result

After running the script, verify in Firebase Console:
1. Go to Firestore
2. Open `questions` collection
3. Find document with ID `CHEM_PURC_E_028`
4. Check that fields are updated correctly

## Example: Fixing CHEM_PURC_E_028

**Step 1:** Create JSON file `inputs/questions/CHEM_PURC_E_028.json`:
```json
{
  "question_id": "CHEM_PURC_E_028",
  "subject": "Chemistry",
  "chapter": "Purification and Characterisation of Organic Compounds",
  "question_type": "mcq_single",
  "question_text": "The molecular formula of acetic acid is:",
  "options": [
    { "option_id": "A", "text": "CH3OH" },
    { "option_id": "B", "text": "C2H4O2" },
    { "option_id": "C", "text": "C3H6O" },
    { "option_id": "D", "text": "C2H6O" }
  ],
  "correct_answer": "B",
  "irt_parameters": {
    "difficulty_b": 0.3,
    "discrimination_a": 1.5,
    "guessing_c": 0.25
  }
}
```

**Step 2:** Run the script:
```bash
node backend/scripts/update-single-question.js CHEM_PURC_E_028 inputs/questions/CHEM_PURC_E_028.json
```

**Step 3:** Verify the update in Firebase Console

Done! The question is now fixed in Firestore.
