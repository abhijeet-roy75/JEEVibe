# JEEVibe UI Refactoring Plan

## Executive Summary

A comprehensive plan to establish a robust, maintainable design system for the JEEVibe mobile app. This refactoring will reduce code duplication by ~40%, improve consistency, and set up the codebase for future scalability.

**Branch:** `refactor/ui-design-system`
**Estimated Effort:** ~10-12 days
**Screens to Update:** 35
**New Components:** 6

---

## Current State Assessment

### What We Have (Design System Foundation)
| Component | File | Status |
|-----------|------|--------|
| Colors | `lib/theme/app_colors.dart` | ✅ Good - needs minor additions |
| Typography | `lib/theme/app_text_styles.dart` | ⚠️ Conflicts with ContentConfig |
| Spacing | `AppSpacing` in app_colors.dart | ✅ Good - needs more presets |
| Shadows | `AppShadows` in app_colors.dart | ✅ Good - underutilized |
| Radius | `AppRadius` in app_colors.dart | ✅ Good |

### What's Missing (Components to Create)
| Component | Purpose | Impact |
|-----------|---------|--------|
| `GradientButton` | CTA buttons | -500 lines duplication |
| `AppIconButton` | Circular icon buttons | -100 lines |
| `AppCard` | Card containers | -200 lines |
| `FormTextField` | Input fields | Consistent validation |
| `AppDialog` | Modals/alerts | Consistent dialogs |
| `LoadingOverlay` | Loading states | Consistent loading |

### Key Problems to Solve
1. **51+ custom button implementations** - Container + InkWell pattern repeated everywhere
2. **Two typography systems** - AppTextStyles vs ContentConfig causing confusion
3. **~10 hardcoded colors** - Color(0xFFxxxxxx) instead of AppColors constants
4. **Inline shadows/spacing** - Not using AppShadows/AppSpacing consistently
5. **No reusable card component** - Same decoration repeated ~20 times
6. **Tests failing** - Broken imports and missing mocks

---

## Implementation Phases

> **Note:** Tests are written LAST (Phase 5) after all code changes are stable. This avoids wasted effort rewriting tests during refactoring.

---

## Phase 1: Design System Foundation

### 1.1 Enhance AppColors
**File:** `lib/theme/app_colors.dart`

**Add missing constants:**
```dart
// Border states
static const Color borderFocus = primaryPurple;
static const Color borderError = errorRed;
static const Color borderSuccess = successGreen;

// UI states
static const Color disabledBackground = Color(0xFFF3F4F6);
static const Color disabledText = Color(0xFF9CA3AF);
static const Color overlayDark = Color(0x80000000);  // 50% black
static const Color overlayLight = Color(0x33FFFFFF); // 20% white

// Subject backgrounds (for cards)
static const Color subjectPhysicsLight = Color(0xFFF3E8FF);
static const Color subjectChemistryLight = Color(0xFFDCFCE7);
static const Color subjectMathematicsLight = Color(0xFFDBEAFE);
```

---

### 1.2 Enhance AppSpacing
**File:** `lib/theme/app_colors.dart` (AppSpacing class)

**Add common patterns:**
```dart
// Horizontal spacing
static const EdgeInsets horizontalSmall = EdgeInsets.symmetric(horizontal: 12);
static const EdgeInsets horizontalMedium = EdgeInsets.symmetric(horizontal: 16);
static const EdgeInsets horizontalLarge = EdgeInsets.symmetric(horizontal: 24);

// Vertical spacing
static const EdgeInsets verticalSmall = EdgeInsets.symmetric(vertical: 8);
static const EdgeInsets verticalMedium = EdgeInsets.symmetric(vertical: 16);
static const EdgeInsets verticalLarge = EdgeInsets.symmetric(vertical: 24);

// Card/container presets
static const EdgeInsets cardPadding = EdgeInsets.all(16);
static const EdgeInsets cardPaddingLarge = EdgeInsets.all(20);
static const EdgeInsets listItemPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
```

---

### 1.3 Add Icon Size Constants
**File:** `lib/theme/app_colors.dart` (new class)

```dart
class AppIconSizes {
  static const double xs = 16.0;
  static const double small = 20.0;
  static const double medium = 24.0;
  static const double large = 32.0;
  static const double xl = 48.0;
  static const double xxl = 64.0;
}
```

---

### 1.4 Consolidate Typography System
**Problem:** Two parallel systems exist - `AppTextStyles` and `ContentConfig`

**Action:**
1. Merge `ContentConfig` text sizes into `AppTextStyles`
2. Add content-specific styles:
```dart
// Content text styles (for questions, solutions, quizzes)
static TextStyle get contentQuestion => GoogleFonts.inter(
  fontSize: 18,
  fontWeight: FontWeight.w400,
  height: 1.6,
  color: AppColors.textDark,
);

static TextStyle get contentOption => GoogleFonts.inter(
  fontSize: 16,
  fontWeight: FontWeight.w400,
  height: 1.5,
  color: AppColors.textDark,
);

static TextStyle get contentStep => GoogleFonts.inter(
  fontSize: 16,
  fontWeight: FontWeight.w400,
  height: 1.6,
  color: AppColors.textDark,
);

static TextStyle get contentAnswer => GoogleFonts.inter(
  fontSize: 17,
  fontWeight: FontWeight.w600,
  color: AppColors.textDark,
);

static TextStyle get contentPriyaTip => GoogleFonts.inter(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  height: 1.8,
  letterSpacing: 0.3,
  color: AppColors.textDark,
);
```

3. Mark `ContentConfig` as `@Deprecated` with migration message
4. Update all usages in screens

**Files affected:**
- `lib/theme/app_text_styles.dart` (enhance)
- `lib/config/content_config.dart` (deprecate)
- `solution_screen.dart`, `followup_quiz_screen.dart`, `review_questions_screen.dart`, `solution_review_screen.dart`, `practice_results_screen.dart`

---

## Phase 2: Core Component Extraction

### 2.1 GradientButton Component
**File:** `lib/widgets/buttons/gradient_button.dart`

**API Design:**
```dart
enum GradientButtonVariant { primary, secondary, outline, text }
enum GradientButtonSize { small, medium, large }

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final GradientButtonVariant variant;
  final GradientButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool fullWidth;

  const GradientButton({
    required this.label,
    this.onPressed,
    this.variant = GradientButtonVariant.primary,
    this.size = GradientButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = true,
  });
}
```

**Variants:**
| Variant | Background | Text | Border | Shadow |
|---------|------------|------|--------|--------|
| Primary | Purple-pink gradient | White | None | Yes |
| Secondary | White | Purple | Purple | No |
| Outline | Transparent | Purple | Purple | No |
| Text | Transparent | Purple | None | No |

**Sizes:**
| Size | Height | Font Size | Padding |
|------|--------|-----------|---------|
| Small | 40px | 14px | 12px |
| Medium | 48px | 16px | 16px |
| Large | 56px | 18px | 20px |

**Screens to update:** ~20 screens with CTA buttons

---

### 2.2 AppIconButton Component
**File:** `lib/widgets/buttons/app_icon_button.dart`

```dart
enum AppIconButtonVariant { filled, outline, ghost }

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final AppIconButtonVariant variant;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
}
```

---

### 2.3 AppCard Component
**File:** `lib/widgets/cards/app_card.dart`

```dart
enum AppCardVariant { elevated, flat, outlined, gradient }

class AppCard extends StatelessWidget {
  final Widget child;
  final AppCardVariant variant;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? borderRadius;
  final Color? backgroundColor;
  final Gradient? gradient;
  final VoidCallback? onTap;
}
```

**Variants:**
| Variant | Background | Shadow | Border |
|---------|------------|--------|--------|
| Elevated | White | AppShadows.cardShadow | None |
| Flat | White | None | None |
| Outlined | White | None | borderGray |
| Gradient | Gradient | Optional | None |

---

### 2.4 FormTextField Component
**File:** `lib/widgets/inputs/form_text_field.dart`

```dart
class FormTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final int? maxLines;
  final FocusNode? focusNode;
}
```

**States:**
- Default: Gray border (`AppColors.borderGray`)
- Focused: Purple border (`AppColors.primaryPurple`)
- Error: Red border + error message (`AppColors.errorRed`)
- Disabled: Gray background (`AppColors.disabledBackground`)

---

### 2.5 AppDialog Component
**File:** `lib/widgets/dialogs/app_dialog.dart`

```dart
class AppDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final Widget? content;
  final List<Widget>? actions;
  final bool dismissible;
}

// Helper functions
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
});

Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
});

Future<void> showErrorDialog({
  required BuildContext context,
  required String title,
  required String message,
});
```

---

### 2.6 LoadingOverlay Component
**File:** `lib/widgets/loading/loading_overlay.dart`

```dart
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final Color? overlayColor;
}

class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;
}
```

---

## Phase 3: Screen-by-Screen Refactoring

### 3.1 Fix Hardcoded Colors
**Search:** `Color(0xFF` across all files

**Replace:**
| Hardcoded | Replace With |
|-----------|--------------|
| `Color(0xFF7C3AED)` | `AppColors.primaryPurpleDark` |
| `Color(0xFF6B21A8)` | `AppColors.primaryPurpleDark` |
| `Color(0xFFE9D5FF)` | `AppColors.cardLightPurple` |
| `Color(0xFFF3F4F6)` | `AppColors.borderLight` |
| Amber colors | `AppColors.warningAmber` |

**Screens to check:**
- `home_screen.dart`
- `phone_entry_screen.dart`
- `create_pin_screen.dart`
- `pin_verification_screen.dart`
- `welcome_carousel_screen.dart`
- All other screens

---

### 3.2 Replace Inline BoxShadow
**Search:** `BoxShadow(` pattern

**Replace with:**
- Button shadows → `AppShadows.buttonShadow`
- Card shadows → `AppShadows.cardShadow`
- Elevated cards → `AppShadows.cardShadowElevated`

---

### 3.3 Replace Inline EdgeInsets
**Search:** `EdgeInsets.all(`, `EdgeInsets.symmetric(`

**Replace:**
| Inline | Replace With |
|--------|--------------|
| `EdgeInsets.all(24)` | `AppSpacing.paddingXL` |
| `EdgeInsets.all(20)` | `AppSpacing.paddingLarge` |
| `EdgeInsets.all(16)` | `AppSpacing.paddingMedium` |
| `EdgeInsets.all(12)` | `AppSpacing.paddingSmall` |
| `EdgeInsets.symmetric(horizontal: 24)` | `AppSpacing.screenPadding` |

---

### 3.4 Replace Inline BorderRadius
**Search:** `BorderRadius.circular(`

**Replace:**
| Inline | Replace With |
|--------|--------------|
| `BorderRadius.circular(8)` | `BorderRadius.circular(AppRadius.radiusSmall)` |
| `BorderRadius.circular(12)` | `BorderRadius.circular(AppRadius.radiusMedium)` |
| `BorderRadius.circular(16)` | `BorderRadius.circular(AppRadius.radiusLarge)` |
| `BorderRadius.circular(20)` | `BorderRadius.circular(AppRadius.radiusXL)` |

---

### 3.5 Replace Custom Buttons with GradientButton
**Target:** All screens with CTA buttons (estimated 51+ instances)

**Before:**
```dart
Container(
  height: 56,
  decoration: BoxDecoration(
    gradient: AppColors.ctaGradient,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [...],
  ),
  child: Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: _onPressed,
      child: Center(child: Text('Button')),
    ),
  ),
)
```

**After:**
```dart
GradientButton(
  label: 'Button',
  onPressed: _onPressed,
)
```

---

### 3.6 Replace Custom Cards with AppCard
**Target:** All card-like containers (~20 instances)

---

## Phase 4: Cleanup & Organization

### 4.1 Reorganize Widget Directory Structure

**Current:**
```
lib/widgets/
├── app_header.dart
├── chemistry_text.dart
├── latex_widget.dart
├── priya_avatar.dart
├── safe_svg_widget.dart
├── subject_icon_widget.dart
└── daily_quiz/
```

**Proposed:**
```
lib/widgets/
├── buttons/
│   ├── gradient_button.dart       (NEW)
│   └── app_icon_button.dart       (NEW)
├── cards/
│   └── app_card.dart              (NEW)
├── inputs/
│   └── form_text_field.dart       (NEW)
├── dialogs/
│   └── app_dialog.dart            (NEW)
├── loading/
│   ├── loading_overlay.dart       (NEW)
│   └── loading_indicator.dart     (NEW)
├── layout/
│   └── app_header.dart            (MOVE)
├── content/
│   ├── latex_widget.dart          (MOVE)
│   └── chemistry_text.dart        (MOVE)
├── avatars/
│   └── priya_avatar.dart          (MOVE)
├── icons/
│   ├── subject_icon_widget.dart   (MOVE)
│   └── safe_svg_widget.dart       (MOVE)
├── daily_quiz/                    (KEEP)
│   └── ...
└── widgets.dart                   (NEW - barrel export)
```

---

### 4.2 Create Widget Export File
**File:** `lib/widgets/widgets.dart`

```dart
// Buttons
export 'buttons/gradient_button.dart';
export 'buttons/app_icon_button.dart';

// Cards
export 'cards/app_card.dart';

// Inputs
export 'inputs/form_text_field.dart';

// Dialogs
export 'dialogs/app_dialog.dart';

// Loading
export 'loading/loading_overlay.dart';
export 'loading/loading_indicator.dart';

// Layout
export 'layout/app_header.dart';

// Content
export 'content/latex_widget.dart';
export 'content/chemistry_text.dart';

// Avatars
export 'avatars/priya_avatar.dart';

// Icons
export 'icons/subject_icon_widget.dart';
export 'icons/safe_svg_widget.dart';
```

---

### 4.3 Delete Deprecated Code
- [ ] Delete `lib/config/content_config.dart` (after migration)
- [ ] Delete `lib/screens/daily_quiz_question_screen_old.dart`
- [ ] Remove unused methods in `welcome_carousel_screen.dart`:
  - `_buildTipItem`
  - `_buildTipItemWhite`
  - `_buildFeatureItem`
  - `_buildFeatureItemWhite`

---

### 4.4 Add Documentation
- [ ] Create `lib/theme/README.md` with:
  - Color palette with hex codes
  - Typography scale
  - Spacing system
  - Border radius scale
  - Shadow definitions
- [ ] Add inline documentation to all shared widgets
- [ ] Document component usage with examples

---

## Phase 5: Testing (After Code is Stable)

> **Important:** All tests are written/updated AFTER Phases 1-4 are complete. This ensures we don't waste effort rewriting tests during refactoring.

### 5.1 Test Infrastructure Setup

**Enhance `test/helpers/test_helpers.dart`:**
```dart
Widget createTestApp(Widget child, {
  bool isAuthenticated = false,
  UserProfile? userProfile,
  int remainingSnaps = 5,
});
```

**Create mock services:**
```
test/mocks/
├── mock_auth_service.dart          (enhance existing)
├── mock_firestore_service.dart     (NEW)
├── mock_storage_service.dart       (NEW)
├── mock_api_service.dart           (NEW)
├── mock_quiz_provider.dart         (NEW)
└── mock_app_state_provider.dart    (NEW)
```

---

### 5.2 Unit Tests for Design System

| Test File | Coverage |
|-----------|----------|
| `test/unit/theme/app_colors_test.dart` | Color values, gradients |
| `test/unit/theme/app_text_styles_test.dart` | Text styles, font sizes |
| `test/unit/theme/app_spacing_test.dart` | Spacing constants |

---

### 5.3 Widget Tests for New Components

| Test File | Test Cases |
|-----------|------------|
| `gradient_button_test.dart` | All variants, sizes, loading, disabled, icons |
| `app_card_test.dart` | All variants, onTap, padding |
| `form_text_field_test.dart` | States, validation, callbacks |
| `app_dialog_test.dart` | Rendering, dismiss, actions |
| `loading_overlay_test.dart` | Show/hide, message |

---

### 5.4 Widget Tests for Screens

**Fix existing (broken):**
- [ ] `welcome_screen_test.dart` → rename to `welcome_carousel_screen_test.dart`
- [ ] `home_screen_test.dart` - fix provider setup
- [ ] `solution_screen_test.dart` - add proper mocks
- [ ] `assessment_question_screen_test.dart` - fix async issues

**Create new:**
- [ ] `phone_entry_screen_test.dart`
- [ ] `otp_verification_screen_test.dart`
- [ ] `create_pin_screen_test.dart`
- [ ] `daily_quiz_home_screen_test.dart`
- [ ] `daily_quiz_question_screen_test.dart`
- [ ] `daily_quiz_result_screen_test.dart`
- [ ] `profile_view_screen_test.dart`
- [ ] `assessment_intro_screen_test.dart`

---

### 5.5 Integration Tests

| Test File | Flow |
|-----------|------|
| `auth_flow_test.dart` | Welcome → Phone → OTP → PIN → Dashboard |
| `snap_solve_flow_test.dart` | Dashboard → Snap → Capture → Solution |
| `assessment_flow_test.dart` | Dashboard → Instructions → Questions → Results |
| `daily_quiz_flow_test.dart` | Dashboard → Quiz Home → Question → Result |
| `onboarding_flow_test.dart` | PIN → Step1 → Step2 → Carousel → Dashboard |

---

### 5.6 Test Coverage Targets

| Category | Current | Target |
|----------|---------|--------|
| Unit Tests | ~60% | 80% |
| Widget Tests | ~30% | 70% |
| Screen Tests | ~20% | 60% |
| Integration Tests | ~10% | 40% |
| **Overall** | **~35%** | **70%** |

---

## Phase 6: Final Validation

### 6.1 Static Analysis
```bash
cd mobile
flutter analyze
# Target: 0 errors, 0 warnings
```

### 6.2 Run All Tests
```bash
flutter test
# Target: All tests pass
```

### 6.3 Build Verification
```bash
flutter build ios --release
flutter build apk --release
# Target: Both build successfully
```

### 6.4 Manual Testing
- [ ] Test on physical iOS device
- [ ] Test on physical Android device
- [ ] Test all user flows end-to-end
- [ ] Verify no visual regressions

### 6.5 CI/CD Verification
- [ ] Push to branch
- [ ] Verify GitHub Actions pass
- [ ] Check coverage report

---

## Implementation Order (Revised)

### Week 1: Foundation + Components (Days 1-5)
| Day | Task |
|-----|------|
| 1 | Phase 1.1-1.3: Enhance AppColors, AppSpacing, AppIconSizes |
| 2 | Phase 1.4: Consolidate Typography |
| 3 | Phase 2.1: Create GradientButton |
| 4 | Phase 2.2-2.3: Create AppIconButton, AppCard |
| 5 | Phase 2.4-2.6: Create FormTextField, AppDialog, LoadingOverlay |

### Week 2: Screen Refactoring (Days 6-10)
| Day | Task |
|-----|------|
| 6 | Phase 3.1-3.2: Fix hardcoded colors, replace BoxShadow |
| 7 | Phase 3.3-3.4: Replace EdgeInsets, BorderRadius |
| 8 | Phase 3.5: Replace buttons in auth + onboarding screens (10 screens) |
| 9 | Phase 3.5: Replace buttons in quiz + assessment screens (10 screens) |
| 10 | Phase 3.5-3.6: Replace buttons + cards in remaining screens (15 screens) |

### Week 3: Cleanup + Testing (Days 11-15)
| Day | Task |
|-----|------|
| 11 | Phase 4: Reorganize directories, create exports, delete deprecated |
| 12 | Phase 5.1-5.2: Test infrastructure + design system tests |
| 13 | Phase 5.3: Widget tests for new components |
| 14 | Phase 5.4-5.5: Screen tests + integration tests |
| 15 | Phase 6: Final validation + PR |

---

## Screen Inventory (35 screens)

### Auth Screens (6)
- [ ] `auth/welcome_screen.dart`
- [ ] `auth/phone_entry_screen.dart`
- [ ] `auth/otp_verification_screen.dart`
- [ ] `auth/create_pin_screen.dart`
- [ ] `auth/pin_verification_screen.dart`
- [ ] `auth/forgot_pin_screen.dart`

### Onboarding Screens (3)
- [ ] `onboarding/onboarding_step1_screen.dart`
- [ ] `onboarding/onboarding_step2_screen.dart`
- [ ] `welcome_carousel_screen.dart`

### Main/Dashboard Screens (2)
- [ ] `assessment_intro_screen.dart`
- [ ] `profile/profile_view_screen.dart`

### Assessment Screens (3)
- [ ] `assessment_instructions_screen.dart`
- [ ] `assessment_question_screen.dart`
- [ ] `assessment_loading_screen.dart`

### Daily Quiz Screens (6)
- [ ] `daily_quiz_loading_screen.dart`
- [ ] `daily_quiz_home_screen.dart`
- [ ] `daily_quiz_question_screen.dart`
- [ ] `daily_quiz_result_screen.dart`
- [ ] `daily_quiz_review_screen.dart`
- [ ] `daily_quiz_question_review_screen.dart`

### Snap & Solve Screens (9)
- [ ] `home_screen.dart`
- [ ] `camera_screen.dart`
- [ ] `image_preview_screen.dart`
- [ ] `photo_review_screen.dart`
- [ ] `solution_screen.dart`
- [ ] `solution_review_screen.dart`
- [ ] `all_solutions_screen.dart`
- [ ] `ocr_failed_screen.dart`
- [ ] `followup_quiz_screen.dart`

### Other Screens (6)
- [ ] `processing_screen.dart`
- [ ] `daily_limit_screen.dart`
- [ ] `token_display_screen.dart`
- [ ] `practice_results_screen.dart`
- [ ] `review_questions_screen.dart`
- [ ] `daily_quiz_question_screen_old.dart` (DELETE)

---

## Success Metrics

| Metric | Before | After |
|--------|--------|-------|
| Duplicate button code | 51+ instances | 0 |
| Hardcoded colors | ~10 instances | 0 |
| Inline BoxShadow | ~30 instances | 0 |
| Typography systems | 2 | 1 |
| Shared button component | None | GradientButton |
| Shared card component | None | AppCard |
| Shared input component | None | FormTextField |
| Test coverage | ~35% | 70% |
| GitHub Actions | Failing | Passing |
| Code reduction | - | ~30-40% styling code |

---

## Commit Strategy

```
refactor/ui-design-system
│
├── "feat(theme): enhance AppColors with border and state colors"
├── "feat(theme): add spacing presets to AppSpacing"
├── "feat(theme): add AppIconSizes constants"
├── "refactor(theme): consolidate typography - merge ContentConfig into AppTextStyles"
│
├── "feat(widgets): create GradientButton component"
├── "feat(widgets): create AppIconButton component"
├── "feat(widgets): create AppCard component"
├── "feat(widgets): create FormTextField component"
├── "feat(widgets): create AppDialog component"
├── "feat(widgets): create LoadingOverlay component"
│
├── "refactor(screens): replace hardcoded colors with AppColors"
├── "refactor(screens): replace inline BoxShadow with AppShadows"
├── "refactor(screens): replace inline EdgeInsets with AppSpacing"
├── "refactor(screens): migrate auth screens to use GradientButton"
├── "refactor(screens): migrate quiz screens to use GradientButton"
├── "refactor(screens): migrate remaining screens to new components"
│
├── "chore(widgets): reorganize widget directory structure"
├── "chore: delete deprecated ContentConfig and unused code"
├── "docs: add design system documentation"
│
├── "test(theme): add design system unit tests"
├── "test(widgets): add tests for GradientButton"
├── "test(widgets): add tests for AppCard, FormTextField"
├── "test(screens): fix and update screen widget tests"
├── "test(integration): update integration tests with proper mocks"
│
└── "chore: final cleanup and validation"
```

---

## Notes

- Run `flutter analyze` after each commit
- Test affected screens manually after component changes
- Keep PR description updated with progress
- Request review when ready to merge
- All tests are written LAST after code is stable

---

*Created: January 2026*
*Last Updated: January 2026*
