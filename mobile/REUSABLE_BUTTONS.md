# Reusable Button Components

This document describes the reusable button components created for consistent UI across the JEEVibe mobile app.

## Components Created

### 1. PrimaryButton
**Location**: `lib/widgets/buttons/primary_button.dart`

**Purpose**: Primary actions (Submit, Next, Complete, Continue, etc.)

**Features**:
- ✅ Platform-adaptive sizing (48px height with `PlatformSizing.buttonHeight(48)`)
- ✅ Platform-adaptive border radius (12px with `PlatformSizing.radius(12)`)
- ✅ Built-in loading state
- ✅ Optional icon support
- ✅ Customizable background color
- ✅ Consistent text style (16px, bold, white)
- ✅ Automatic disabled state handling

**Usage**:
```dart
import 'package:jeevibe_mobile/widgets/buttons/primary_button.dart';

// Basic usage
PrimaryButton(
  text: 'Submit Answer',
  onPressed: () => _handleSubmit(),
)

// With custom color
PrimaryButton(
  text: 'Complete Quiz',
  onPressed: () => _completeQuiz(),
  backgroundColor: Colors.green,
)

// With loading state
PrimaryButton(
  text: 'Next Question',
  onPressed: isLoading ? null : () => _nextQuestion(),
  isLoading: isLoading,
)

// With icon
PrimaryButton(
  text: 'Continue',
  onPressed: () => _continue(),
  icon: Icons.arrow_forward,
)
```

**Parameters**:
- `text` (required): Button text
- `onPressed`: Callback function (null = disabled)
- `backgroundColor`: Custom background color (default: `AppColors.primaryPurple`)
- `isLoading`: Show loading spinner (default: false)
- `icon`: Optional icon to display
- `width`: Custom width (default: `double.infinity`)
- `height`: Custom height (default: `PlatformSizing.buttonHeight(48)`)

---

### 2. SecondaryButton
**Location**: `lib/widgets/buttons/secondary_button.dart`

**Purpose**: Secondary actions (Cancel, Back, Skip, etc.)

**Features**:
- ✅ Platform-adaptive sizing (48px height)
- ✅ Platform-adaptive border radius (12px)
- ✅ Outlined style with 2px border
- ✅ Optional icon support
- ✅ Customizable border and text color
- ✅ Consistent text style (16px, bold)

**Usage**:
```dart
import 'package:jeevibe_mobile/widgets/buttons/secondary_button.dart';

// Basic usage
SecondaryButton(
  text: 'Back to Chapters',
  onPressed: () => Navigator.pop(context),
)

// With custom colors
SecondaryButton(
  text: 'Cancel',
  onPressed: () => Navigator.pop(context),
  borderColor: AppColors.error,
  textColor: AppColors.error,
)

// With icon
SecondaryButton(
  text: 'Skip',
  onPressed: () => _skip(),
  icon: Icons.skip_next,
)
```

**Parameters**:
- `text` (required): Button text
- `onPressed`: Callback function
- `borderColor`: Custom border color (default: `AppColors.borderDefault`)
- `textColor`: Custom text color (default: `AppColors.primary`)
- `icon`: Optional icon to display
- `width`: Custom width (default: `double.infinity`)
- `height`: Custom height (default: `PlatformSizing.buttonHeight(48)`)

---

## Migration Guide

### Screens Already Updated ✅

**Quiz & Practice Screens:**
1. **Unlock Quiz Question Screen** - Uses `PrimaryButton` for Next/Complete
2. **Unlock Quiz Result Screen** - Uses `PrimaryButton` and `SecondaryButton`
3. **Daily Quiz Question Screen** - Uses `PrimaryButton` for Next/Complete Quiz
4. **Chapter Practice Question Screen** - Uses `PrimaryButton` for Next/Complete/Skip
5. **Assessment Question Screen** - Uses `PrimaryButton` with icon for Next/Submit
6. **Follow-up Quiz Screen** - Uses `PrimaryButton` (Go Back) + `SecondaryButton` (Try Again)
7. **Chapter Practice Result Screen** - Uses `PrimaryButton` (Upgrade) + `SecondaryButton` (Practice Again)
8. **Daily Quiz Result Screen** - Uses `PrimaryButton` (Go Back) + `SecondaryButton` (Discuss with Priya)
9. **Daily Quiz Loading Screen** - Uses `PrimaryButton`/`SecondaryButton` in error states + `QuizLoadingScreen` widget
10. **Chapter Practice Loading Screen** - Uses `PrimaryButton`/`SecondaryButton` in error states + `QuizLoadingScreen` widget
11. **Unlock Quiz Loading Screen** - Uses `QuizLoadingScreen` widget

**Reusable Loading Widget Created:**
- **QuizLoadingScreen** (`lib/widgets/quiz_loading_screen.dart`) - Reusable loading widget with:
  - Priya Ma'am avatar with pulsing animation
  - Purple-to-pink gradient background
  - Subject badge and chapter name
  - Custom message and badge
  - Used by all 3 quiz loading screens (Daily, Chapter Practice, Unlock Quiz)
  - Eliminated ~350 lines of duplicate code

**Notes:**
- Review Questions Screen: No buttons to update (navigation only)
- Profile Edit Screen: Already uses custom `GradientButton` widget
- Feedback Form Screen: No ElevatedButton/OutlinedButton found
- Onboarding Screens: Already uses custom `GradientButton` widget

### Migration Complete! 🎉

All quiz, practice, and result screens now use the reusable button components. This ensures:
- ✅ Consistent platform-adaptive sizing (48px iOS → ~42px Android)
- ✅ Unified button styling across all flows
- ✅ Built-in loading states and disabled handling
- ✅ Unified quiz loading UX with Priya Ma'am avatar
- ✅ ~85% reduction in button boilerplate code (~512 lines eliminated)
- ✅ Easier maintenance (update one file, fixes everywhere)

---

## Design Specifications

### Button Dimensions
- **Height**: 48px (iOS) / ~42px (Android with 0.88 scaling)
- **Border Radius**: 12px (iOS) / ~9.6px (Android with 0.80 scaling)
- **Width**: Full width by default (`double.infinity`)

### Typography
- **Font Size**: 16px
- **Font Weight**: Bold
- **Color**: White (primary), varies (secondary)

### Colors
**Primary Button**:
- Default: `AppColors.primaryPurple` (#6B4CE6)
- Success: `Colors.green`
- Primary Alt: `AppColors.primary` (#8B5CF6)
- Disabled: `AppColors.borderGray`

**Secondary Button**:
- Border: `AppColors.borderDefault` (#E5E7EB)
- Text: `AppColors.primary` (#8B5CF6)
- Background: Transparent

### States
1. **Enabled**: Full opacity, clickable
2. **Disabled**: Gray background (primary) or gray text (secondary), not clickable
3. **Loading**: Shows spinner, not clickable
4. **Pressed**: Platform default ripple effect

---

## Benefits of Using Reusable Buttons

✅ **Consistency**: All buttons look and behave the same
✅ **Platform-Adaptive**: Automatically adjusts for iOS/Android
✅ **Maintainability**: Update one file, fixes everywhere
✅ **Accessibility**: Built-in disabled and loading states
✅ **Less Code**: Reduces boilerplate by ~70%

### Before (Custom Implementation):
```dart
SizedBox(
  width: double.infinity,
  height: PlatformSizing.buttonHeight(48),
  child: ElevatedButton(
    onPressed: isLoading ? null : _submit,
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryPurple,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.borderGray,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
      ),
    ),
    child: isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : const Text(
            'Submit Answer',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
  ),
)
```

### After (Reusable Component):
```dart
PrimaryButton(
  text: 'Submit Answer',
  onPressed: _submit,
  isLoading: isLoading,
)
```

**Reduction**: ~25 lines → 4 lines (84% less code!)

---

## Migration Summary

1. ✅ Create `PrimaryButton` and `SecondaryButton` widgets
2. ✅ Create `QuizLoadingScreen` reusable widget
3. ✅ Update Unlock Quiz screens to use new buttons
4. ✅ Update Daily Quiz screen and loading screen
5. ✅ Update Chapter Practice screen and loading screen
6. ✅ Update Assessment screen
7. ✅ Update Follow-up Quiz screen
8. ✅ Update Chapter Practice Result screen
9. ✅ Update Daily Quiz Result screen
10. ✅ All quiz/practice screens migrated successfully!

**Code Reduction**: ~512 lines of boilerplate removed across 11 screens (85% reduction)
- Button code: ~162 lines eliminated (84% reduction)
- Loading screen code: ~350 lines eliminated (duplicate animations, gradients, avatars)

---

## Testing Checklist

After migrating a screen:
- [ ] Button height matches (48px)
- [ ] Border radius matches (12px)
- [ ] Colors are correct
- [ ] Loading state works
- [ ] Disabled state works
- [ ] Text is readable
- [ ] Button is clickable
- [ ] Ripple effect works
- [ ] Works on both iOS and Android
- [ ] Bottom padding clears OS nav bar

---

## Questions?

Contact the development team or refer to the implementation in:
- `lib/widgets/buttons/primary_button.dart`
- `lib/widgets/buttons/secondary_button.dart`
- `lib/screens/unlock_quiz/unlock_quiz_question_screen.dart` (example usage)
