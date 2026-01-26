# Questions That Need Fixing

This document tracks questions with invalid data that need to be fixed in Firestore.

## Invalid Questions

### CHEM_PURC_E_028
**Issue:** Has `correct_answer_exact: "C2H4O2"` (chemical formula string) instead of a numeric value.

**Fix needed:**
1. Check if this is an MCQ or numerical question
2. If MCQ: Remove `correct_answer_exact` field, use `correct_answer` instead
3. If numerical: Replace `correct_answer_exact` with the correct numeric value

**To fix manually in Firestore console:**
```
Collection: questions
Document ID: CHEM_PURC_E_028

Option 1 (if MCQ): Delete the correct_answer_exact field
Option 2 (if numerical): Update correct_answer_exact to a number
```

**Or run the fix script:**
```bash
node backend/scripts/fix-invalid-question.js
```

**Status:** Temporarily handled by graceful degradation (marks as incorrect without crashing)

---

## How to Prevent This

1. Add validation when uploading questions
2. Ensure `correct_answer_exact` is always numeric if present
3. For chemical formulas, use `correct_answer` field (string-based MCQ answer)
