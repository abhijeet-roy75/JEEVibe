# Bug Fix: Null Type Cast Error in Quiz Generation

## Issue
The Daily Questions and Assessment features were failing with the error:
```
Error: Failed to generate quiz: type 'Null' is not a subtype of type 'String' in type cast
```

## Root Cause
The issue was caused by unsafe type casting in the Flutter model classes. When the backend API returned `null` values for certain fields, the Flutter app attempted to cast them directly to `String` without proper null handling.

### Affected Files
1. `mobile/lib/models/assessment_question.dart`
2. `mobile/lib/models/daily_quiz_question.dart`

### Problematic Code Pattern
```dart
// BEFORE (Unsafe - causes crash on null):
questionId: json['question_id'] as String,
subject: json['subject'] as String,
chapter: json['chapter'] as String,
```

When the API returns `null` for these fields, Dart throws:
`type 'Null' is not a subtype of type 'String' in type cast`

## Solution
Changed all unsafe type casts to nullable casts with default values:

```dart
// AFTER (Safe - handles null gracefully):
questionId: json['question_id'] as String? ?? '',
subject: json['subject'] as String? ?? '',
chapter: json['chapter'] as String? ?? '',
```

## Changes Made

### 1. `assessment_question.dart`
**AssessmentQuestion.fromJson():**
- `questionId`: Changed from `as String` to `as String? ?? ''`
- `subject`: Changed from `as String` to `as String? ?? ''`
- `chapter`: Changed from `as String` to `as String? ?? ''`
- `questionType`: Changed from `as String` to `as String? ?? 'mcq_single'`

**QuestionOption.fromJson():**
- `optionId`: Changed from `as String` to `as String? ?? ''`
- `text`: Changed from `as String` to `as String? ?? ''`

### 2. `daily_quiz_question.dart`
**DailyQuizQuestion.fromJson():**
- `questionId`: Changed from `as String` to `as String? ?? ''`
- Already had safe defaults for other fields ✓

**DailyQuiz.fromJson():**
- `quizId`: Changed from `as String` to `as String? ?? ''`

**AnswerFeedback.fromJson():**
- `questionId`: Changed from `as String` to `as String? ?? ''`
- `isCorrect`: Changed from `as bool` to `as bool? ?? false`
- `timeTakenSeconds`: Changed from `as int` to `as int? ?? 0`

## Why This Happened
The backend's `normalizeQuestion` function in `questionSelectionService.js` uses `String()` to convert values:

```javascript
subject: String(data.subject || data.subject_id || 'Unknown'),
chapter: String(data.chapter || data.chapter_name || 'Unknown'),
```

While this provides defaults in most cases, if the database contains documents with truly `null` values (not just missing fields), or if there are edge cases in the API response handling, `null` can still be sent to the client.

## Prevention
This pattern should be followed for all model `fromJson()` methods:

1. **Required fields that should never be null:** Use nullable cast with default value
   ```dart
   field: json['field'] as String? ?? 'default_value',
   ```

2. **Optional fields that can be null:** Use nullable cast without default
   ```dart
   field: json['field'] as String?,
   ```

3. **Never use direct non-nullable cast unless 100% certain the value exists:**
   ```dart
   // AVOID THIS unless you're absolutely certain:
   field: json['field'] as String,
   ```

## Testing Recommendations
1. Test quiz generation with various user states
2. Test with users who have incomplete assessment data
3. Test with empty/null values in the question bank
4. Add error logging to track any remaining null value issues

## Related Code
- Backend: `backend/src/services/questionSelectionService.js` - normalizeQuestion()
- Backend: `backend/src/services/dailyQuizService.js` - generateDailyQuiz()
- Backend: `backend/src/routes/assessment.js` - assessment endpoints

## Status
✅ **FIXED** - All unsafe type casts in model classes have been updated with proper null handling.

---

## Follow-up Fix: Empty/Duplicate Option IDs

### Additional Issue Discovered
After the initial fix, some specific questions still couldn't be interacted with. Investigation revealed that certain questions had **missing or empty `option_id` values** in their data.

### Root Cause
When the backend returns options with null or empty `option_id` values, our null-safety fix converted them to empty strings `''`. If multiple options had empty IDs:
- All options would have the same ID (`''`)
- Clicking any option would "select" all options with that empty ID
- The UI would not respond correctly

### Solution
Added **validation and auto-correction** in both model `fromJson()` methods:

1. **Detect empty or duplicate option IDs** during parsing
2. **Auto-generate valid IDs** (A, B, C, D) based on position
3. **Log warnings** to help identify problematic questions in the database

#### Updated Files:
- `mobile/lib/models/assessment_question.dart` - Added option ID validation (generates A, B, C, D)
- `mobile/lib/models/daily_quiz_question.dart` - Added option ID validation (generates A, B, C, D)
- `mobile/lib/widgets/daily_quiz/question_card_widget.dart` - Added debug logging + display sanitization

#### Code Pattern:
```dart
// Validate and fix duplicate/empty option IDs
final seenIds = <String>{};
options = optionsList.map((opt) {
  String optionId = opt.optionId;
  
  // If empty or duplicate, generate a unique ID
  if (optionId.isEmpty || seenIds.contains(optionId)) {
    final index = optionsList.indexOf(opt);
    optionId = String.fromCharCode(65 + index); // A, B, C, D...
  }
  
  seenIds.add(optionId);
  return optionId != opt.optionId
      ? QuestionOption(optionId: optionId, text: opt.text, html: opt.html)
      : opt;
}).toList();
```

### Backend Investigation Needed
The backend's `normalizeQuestion()` function should ensure all options have valid `option_id` values. Check:
- `backend/src/services/questionSelectionService.js` - normalizeQuestion()
- Database questions with missing option_id fields

### UI Display Issue - Option ID Circles

**Additional Issue Found:** Even after fixing option IDs, some were displaying as `opt_813` instead of clean letters (A, B, C, D) in the option circles.

**Root Cause:** Initial fix in `QuestionOption.fromJson()` was generating hash-based IDs that were displaying in the UI.

**Solution:**
1. Removed hash-based ID generation from `QuestionOption.fromJson()`
2. Let parent validation assign proper A, B, C, D IDs
3. Added UI sanitization method `_getDisplayableOptionId()` as final safety net
4. Now displays clean single letters even if malformed IDs slip through

### Testing
1. **Hot restart** the app after this fix
2. Try the problematic question again - should now show **clean A, B, C, D letters** in circles
3. Options should be selectable and highlight properly
4. Check console logs for "WARNING: Fixed option ID" messages
5. These warnings indicate which questions in the database need to be fixed

---
Date: December 20, 2025 (Updated with option ID fix)

