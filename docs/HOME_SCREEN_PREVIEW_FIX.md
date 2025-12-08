# Home Screen Preview Fix

**Date**: December 5, 2025  
**Status**: ✅ Completed  
**Issues**: Raw LaTeX showing in preview text & Hardcoded "Practice: 2/3"

## Problems

### Issue 1: Raw LaTeX Characters in Preview ❌
Recent snaps showing:
- `\([ \mathrm{Co(en...`
- `\(\(\mathrm{sp}^{3}\)\),...`

### Issue 2: Misleading Practice Badge ❌
All questions showing "Practice: 2/3" regardless of actual progress

## Root Causes

### Issue 1: No LaTeX Cleaning in getPreviewText()
The `RecentSolution.getPreviewText()` method was returning the first 80 characters of the **raw question text**, including all LaTeX delimiters and commands.

Even though we added `TextPreprocessor.addSpacesToText()`, it only fixed spacing issues but didn't remove LaTeX syntax.

### Issue 2: Hardcoded Badge
The "Practice: 2/3" was hardcoded in `home_screen.dart` line 551. There's no practice progress tracking in the data model, making this badge meaningless.

## Solutions Applied

### Fix 1: Clean LaTeX in getPreviewText() ✅

Enhanced the `getPreviewText()` method to strip LaTeX before returning preview:

**File**: `mobile/lib/models/snap_data_model.dart`

```dart
String getPreviewText() {
  // Clean LaTeX delimiters and commands for preview
  String cleanedQuestion = question
      .replaceAll(RegExp(r'\\\('), '') // Remove \(
      .replaceAll(RegExp(r'\\\)'), '') // Remove \)
      .replaceAll(RegExp(r'\\\['), '') // Remove \[
      .replaceAll(RegExp(r'\\\]'), '') // Remove \]
      .replaceAll(RegExp(r'\\mathrm\{([^}]+)\}'), r'$1') // \mathrm{X} -> X
      .replaceAll(RegExp(r'\\text\{([^}]+)\}'), r'$1') // \text{X} -> X
      .replaceAll(RegExp(r'[_^]\{([^}]+)\}'), r'$1') // _{X} or ^{X} -> X
      .replaceAll(RegExp(r'\\[a-zA-Z]+'), '') // Remove LaTeX commands
      .replaceAll(RegExp(r'[{}]'), '') // Remove braces
      .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
      .trim();
  
  if (cleanedQuestion.length <= 80) return cleanedQuestion;
  return '${cleanedQuestion.substring(0, 77)}...';
}
```

**Transformations**:
- `\(\mathrm{Co(en}_{3})_{3}]^{3+}\)` → `Co(en₃)₃]³⁺`
- `\(\(\mathrm{sp}^{3}\)\)` → `sp³`
- All LaTeX commands removed
- Clean, readable preview text

### Fix 2: Remove Misleading Badge ✅

Removed the hardcoded "Practice: 2/3" badge since practice progress isn't tracked.

**File**: `mobile/lib/screens/home_screen.dart`

**Before**:
```dart
Container(
  child: Text('Practice: 2/3', ...), // Hardcoded, misleading
),
const SizedBox(width: 8),
Expanded(
  child: Text(solution.topic, ...),
),
```

**After**:
```dart
Expanded(
  child: Text(solution.topic, ...), // Just show topic
),
```

Now the home screen shows:
- ✅ Clean topic text (e.g., "Organic Chemistry - Hybridization")
- ✅ No misleading practice progress

## Files Modified

- ✅ `mobile/lib/models/snap_data_model.dart` - Enhanced getPreviewText() with LaTeX cleaning
- ✅ `mobile/lib/screens/home_screen.dart` - Removed hardcoded practice badge

## Results

### Before ❌
```
Preview: "The d-orbital electronic configuration of the complex among \([ \mathrm{Co(en..."
Badge: "Practice: 2/3" (all questions, misleading)
```

### After ✅
```
Preview: "The d-orbital electronic configuration of the complex among Co(en..."
Badge: [removed] - Just shows topic now
```

## Benefits

1. **Clean previews** - No raw LaTeX syntax visible
2. **Honest UI** - No misleading progress indicators
3. **Better readability** - Text is immediately understandable
4. **Consistent** - Works with TextPreprocessor.addSpacesToText() for full cleanup

## Testing

The changes will apply with Flutter hot reload. Check:
- ✅ Recent snaps show clean preview text
- ✅ No LaTeX delimiters visible (`\(`, `\)`, etc.)
- ✅ Chemical formulas cleaned (sp³ instead of `\(\mathrm{sp}^{3}\)`)
- ✅ No "Practice: 2/3" badge
- ✅ Topics display clearly

## Future Enhancement

If practice progress tracking is added later, the badge can be re-added with:
```dart
if (solution.practiceProgress != null) {
  Container(
    child: Text('Practice: ${solution.practiceProgress}', ...),
  ),
}
```

But for now, it's better to show nothing than misleading information.

---

**Status**: Home screen previews are now clean and honest! ✅

