# JEEVibe Mobile App Screens Reference

**Last Updated:** 2026-02-13
**Total User-Facing Screens:** 54

This document provides a comprehensive reference for all mobile app screens, organized by feature category.

---

## 📱 AUTHENTICATION & ONBOARDING (8 screens)

### Auth Flow
| File Name | Class Name | Purpose | Route Name |
|-----------|-----------|---------|------------|
| `auth/welcome_screen.dart` | WelcomeScreen | Entry point with feature overview & "Get Started" button | `Welcome` |
| `auth/phone_entry_screen.dart` | PhoneEntryScreen | Phone number collection with country selector, OTP rate limiting | `PhoneEntry` |
| `auth/otp_verification_screen.dart` | OtpVerificationScreen | OTP verification for phone-based authentication | `OtpVerification` |
| `auth/pin_verification_screen.dart` | PinVerificationScreen | PIN entry for unlock (app resumption lock screen) | `PinVerification` |
| `auth/create_pin_screen.dart` | CreatePinScreen | PIN creation for app security | `CreatePin` |
| `auth/forgot_pin_screen.dart` | ForgotPinScreen | PIN recovery via OTP | `ForgotPin` |

### Onboarding Flow
| File Name | Class Name | Purpose | Route Name |
|-----------|-----------|---------|------------|
| `onboarding/onboarding_step1_screen.dart` | OnboardingStep1Screen | Collects name, email, phone (prefilled), JEE target date | `OnboardingStep1` |
| `onboarding/onboarding_step2_screen.dart` | OnboardingStep2Screen | Coaching enrollment status & additional profile info | `OnboardingStep2` |

**Key Flow:** Welcome → Phone Entry → OTP → Onboarding Step 1 → Onboarding Step 2 → Create PIN → Home

---

## 🏠 HOME & NAVIGATION (2 screens)

| File Name | Class Name | Purpose | Route Name |
|-----------|-----------|---------|------------|
| `main_navigation_screen.dart` | MainNavigationScreen | Bottom navigation shell (Home, History, Analytics, Profile) | `MainNavigation` |
| `home_screen.dart` | HomeScreen | Main dashboard showing Assessment, Daily Quiz, Chapter Practice, Mock Tests, Snap & Solve | `Home` |

**Bottom Navigation Tabs:**
- Tab 0: Home (HomeScreen)
- Tab 1: History (HistoryScreen)
- Tab 2: Analytics (AnalyticsScreen)
- Tab 3: Profile (ProfileViewScreen)

---

## 📚 DAILY ADAPTIVE QUIZ (5 screens)

| File Name | Class Name | Purpose | Route Name |
|-----------|-----------|---------|------------|
| `daily_quiz_home_screen.dart` | DailyQuizHomeScreen | Quiz selection & streak display | `DailyQuizHome` |
| `daily_quiz_loading_screen.dart` | DailyQuizLoadingScreen | Loading state while fetching quiz from backend | `DailyQuizLoading` |
| `daily_quiz_question_screen.dart` | DailyQuizQuestionScreen | Main quiz interface with timer, question card, options feedback | `DailyQuizQuestion` |
| `daily_quiz_result_screen.dart` | DailyQuizResultScreen | Quiz completion summary with performance breakdown | `DailyQuizResult` |
| `daily_quiz_review_screen.dart` | DailyQuizReviewScreen | Review answered questions with solutions | `DailyQuizReview` |

**Key Flow:** Daily Quiz Home → Loading → Question (×10) → Result → Review

**Provider:** `DailyQuizProvider`

---

## 🎯 INITIAL ASSESSMENT (3 screens)

| File Name | Class Name | Purpose | Route Name |
|-----------|-----------|---------|------------|
| `assessment_instructions_screen.dart` | AssessmentInstructionsScreen | Instructions before starting 30-question diagnostic | `AssessmentInstructions` |
| `assessment_loading_screen.dart` | AssessmentLoadingScreen | Loading state while fetching assessment questions | `AssessmentLoading` |
| `assessment_question_screen.dart` | AssessmentQuestionScreen | Assessment interface (forward-only, 45 min timer) | `AssessmentQuestion` |

**Key Flow:** Instructions → Loading → Question (×30) → Auto-process to Home with theta calculation

**Purpose:** One-time 30-question diagnostic to bootstrap student theta (ability score)

---

## 📖 CHAPTER PRACTICE (5 screens)

| File Name | Class Name | Purpose | Route Name |
|-----------|-----------|---------|------------|
| `chapter_list_screen.dart` | ChapterListScreen | 24-month countdown timeline showing unlocked/locked chapters | `ChapterList` |
| `chapter_practice/chapter_practice_loading_screen.dart` | ChapterPracticeLoadingScreen | Loading state while fetching chapter questions | `ChapterPracticeLoading` |
| `chapter_practice/chapter_practice_question_screen.dart` | ChapterPracticeQuestionScreen | Main question interface (no timer, practice mode) | `ChapterPracticeQuestion` |
| `chapter_practice/chapter_practice_result_screen.dart` | ChapterPracticeResultScreen | Session completion with subject breakdown | `ChapterPracticeResult` |
| `chapter_practice/chapter_practice_review_screen.dart` | ChapterPracticeReviewScreen | Review answered questions with detailed solutions | `ChapterPracticeReview` |

**Key Flow:** Chapter List → Loading → Question (×5-15) → Result → Review

**Tier Limits:**
- Free: 5 chapters/day, 5 questions/chapter
- Pro: 10 chapters/day, 15 questions/chapter
- Ultra: 25 chapters/day, 15 questions/chapter

**Provider:** `ChapterPracticeProvider`

---

## 🧪 MOCK TESTS (5 screens)

| File Name | Class Name | Purpose | Route Name |
|-----------|-----------|---------|------------|
| `mock_test/mock_test_home_screen.dart` | MockTestHomeScreen | Mock test selection & usage display | `MockTestHome` |
| `mock_test/mock_test_instructions_screen.dart` | MockTestInstructionsScreen | JEE Main exam format instructions | `MockTestInstructions` |
| `mock_test/mock_test_screen.dart` | MockTestScreen | Full JEE simulation (90 questions, 3 hours) | `MockTestScreen` |
| `mock_test/mock_test_results_screen.dart` | MockTestResultsScreen | Test completion with score, percentile, rank | `MockTestResults` |
| `mock_test/mock_test_review_screen.dart` | MockTestReviewScreen | Review questions organized by subject | `MockTestReview` |

**Key Flow:** Mock Test Home → Instructions → Test (90Q, 3hr) → Results → Review

**Tier Limits:**
- Free: 1 test/month
- Pro: 5 tests/month
- Ultra: Unlimited

**Provider:** `MockTestProvider`

**Note:** Mock Test feature is currently disabled with "Coming Soon" message (as of Feb 11, 2026)

---

## 📷 SNAP & SOLVE (6 screens)

| File Name | Class Name | Purpose | Route Name |
|-----------|-----------|---------|------------|
| `snap_home_screen.dart` | SnapHomeScreen | Camera/gallery picker & daily snap counter (hero feature) | `SnapHome` |
| `camera_screen.dart` | CameraScreen | Camera interface for capturing question photos | `Camera` |
| `photo_review_screen.dart` | PhotoReviewScreen | Review captured photo before submission | `PhotoReview` |
| `processing_screen.dart` | ProcessingScreen | Generic loading/processing screen with animations | `Processing` |
| `solution_review_screen.dart` | SolutionReviewScreen | Display snap solution with detailed explanation | `SolutionReview` |
| `all_solutions_screen.dart` | AllSolutionsScreen | Browse all snap history with filters (by subject) | `AllSolutions` |

**Key Flow:** Snap Home → Camera/Gallery → Photo Review → Processing → Solution Review

**Tier Limits:**
- Free: 5 snaps/day, 7-day history
- Pro: 15 snaps/day, 30-day history
- Ultra: 50 snaps/day, unlimited history

**Provider:** State managed via `SnapCounterService` and API calls

---

## 🤖 AI TUTOR (1 screen)

| File Name | Class Name | Purpose | Route Name |
|-----------|-----------|---------|------------|
| `ai_tutor_chat_screen.dart` | AiTutorChatScreen | Chat with Priya Ma'am (AI tutor) with context injection | `AiTutorChat` |

**Tier Gate:** Ultra tier only

**Features:**
- Context injection from snap solutions, quiz questions, chapter practice
- Conversation history
- Math rendering support (LaTeX)

**Provider:** `AiTutorProvider`

---

## 📊 HISTORY & ANALYTICS (5 screens)

### History Hub
| File Name | Class Name | Purpose | Route Name |
|-----------|-----------|---------|------------|
| `history/history_screen.dart` | HistoryScreen | Hub with scrollable tabs (Daily Quiz, Chapter Practice, Mock Tests) | `History` |
| `history/daily_quiz_history_screen.dart` | DailyQuizHistoryScreen | List of completed daily quizzes with metrics | `DailyQuizHistory` |
| `history/chapter_practice_history_screen.dart` | ChapterPracticeHistoryScreen | List of completed chapter practice sessions | `ChapterPracticeHistory` |
| `history/mock_test_history_screen.dart` | MockTestHistoryScreen | List of completed mock tests | `MockTestHistory` |

### Analytics
| File Name | Class Name | Purpose | Route Name |
|-----------|-----------|---------|------------|
| `analytics_screen.dart` | AnalyticsScreen | Overview & Mastery tabs with charts, tier-based feature gating | `Analytics` |

**History Tabs:**
1. Daily Quiz
2. Chapter Practice
3. Mock Tests

**Analytics Tabs:**
1. Overview (theta trends, percentile, accuracy)
2. Mastery (subject-wise performance)

---

## 👤 PROFILE & ACCOUNT (3 screens)

| File Name | Class Name | Purpose | Route Name |
|-----------|-----------|---------|------------|
| `profile/profile_view_screen.dart` | ProfileViewScreen | User profile with tier info, offline mode toggle, logout | `ProfileView` |
| `profile/profile_edit_screen.dart` | ProfileEditScreen | Edit name, email, phone, JEE target date | `ProfileEdit` |
| `subscription/paywall_screen.dart` | PaywallScreen | Upgrade prompt showing Pro & Ultra pricing with tab selector | `Paywall` |

**Provider:** `UserProfileProvider`, `SubscriptionService`

---

## 🔓 UNLOCK SYSTEM (3 screens)

| File Name | Class Name | Purpose | Route Name |
|-----------|-----------|---------|------------|
| `unlock_quiz/unlock_quiz_loading_screen.dart` | UnlockQuizLoadingScreen | Loading state while fetching unlock quiz | `UnlockQuizLoading` |
| `unlock_quiz/unlock_quiz_question_screen.dart` | UnlockQuizQuestionScreen | 5-question quiz to unlock locked chapters | `UnlockQuizQuestion` |
| `unlock_quiz/unlock_quiz_result_screen.dart` | UnlockQuizResultScreen | Result of unlock attempt (3+ correct = unlock) | `UnlockQuizResult` |

**Key Flow:** Chapter List (tap locked chapter) → Loading → Question (×5) → Result

**Purpose:** Allow Free tier users to unlock timeline-locked chapters early by passing a 5-question quiz (need 3+ correct)

**Provider:** `UnlockQuizProvider`

---

## 🛠️ UTILITY & SUPPORT (5 screens)

| File Name | Class Name | Purpose | Route Name |
|-----------|-----------|---------|------------|
| `daily_limit_screen.dart` | DailyLimitScreen | Message when daily snap/quiz limits reached | `DailyLimit` |
| `feedback/feedback_form_screen.dart` | FeedbackFormScreen | User feedback collection form | `FeedbackForm` |
| `ocr_failed_screen.dart` | OCRFailedScreen | Error message when OCR processing fails | `OCRFailed` |
| `solution_screen.dart` | SolutionScreen | Generic solution display screen | `Solution` |
| `image_preview_screen.dart` | ImagePreviewScreen | Image preview with crop functionality | `ImagePreview` |

---

## 🗂️ DEPRECATED SCREENS

| File Name | Status | Reason |
|-----------|--------|--------|
| `daily_quiz_question_screen_old.dart` | Deprecated | Replaced by refactored `daily_quiz_question_screen.dart` |
| `review_questions_screen.dart` | Legacy | Replaced by feature-specific review screens |
| `practice_results_screen.dart` | Legacy | Replaced by `chapter_practice_result_screen.dart` |
| `followup_quiz_screen.dart` | Legacy | Follow-up quiz feature removed |
| `token_display_screen.dart` | Legacy | Snap tokens replaced by daily limits |
| `welcome_carousel_screen.dart` | Deprecated | Replaced by new welcome flow |

---

## 🎨 KEY ARCHITECTURE PATTERNS

### State Management
- **Providers:** DailyQuizProvider, ChapterPracticeProvider, MockTestProvider, AiTutorProvider, UnlockQuizProvider
- **Services:** AuthService, FirestoreUserService, SubscriptionService, ApiService
- **Storage:** StorageService (SharedPreferences), DatabaseService (SQLite for offline)

### Navigation Structure
```
MainNavigationScreen (Bottom Nav Shell)
├── Tab 0: HomeScreen
├── Tab 1: HistoryScreen (with sub-tabs)
├── Tab 2: AnalyticsScreen (with sub-tabs)
└── Tab 3: ProfileViewScreen
```

### Loading Patterns
All major features follow the pattern:
1. Home/List Screen
2. Loading Screen (with cancellation)
3. Question/Content Screen
4. Result Screen
5. Review Screen

### Disposal Safety
Critical screens implement `_isDisposed` flag to prevent lifecycle crashes:
- `assessment_question_screen.dart`
- `chapter_practice_question_screen.dart`
- `daily_quiz_question_screen.dart`
- `mock_test_screen.dart`
- `ai_tutor_chat_screen.dart`
- `phone_entry_screen.dart`
- `profile_view_screen.dart`

### Platform-Adaptive Sizing
All screens use `PlatformSizing` utility for Android/iOS differences:
- **Android:** 12% smaller fonts (0.88×), 20% tighter spacing (0.80×)
- **iOS:** Base sizing
- **Minimum:** 12px iOS font → 10.56px Android (meets 10sp minimum)

### Tier-Based Feature Gating
Screens check tier via `SubscriptionService`:
- Free: Core features with daily limits
- Pro: Increased limits + offline mode
- Ultra: Unlimited + AI Tutor

---

## 📝 NAMING CONVENTIONS

### Screen File Naming
- **Pattern:** `{feature}_{screen_type}_screen.dart`
- **Examples:**
  - `daily_quiz_question_screen.dart`
  - `chapter_practice_result_screen.dart`
  - `mock_test_review_screen.dart`

### Class Naming
- **Pattern:** `{FeatureScreenType}Screen`
- **Examples:**
  - `DailyQuizQuestionScreen`
  - `ChapterPracticeResultScreen`
  - `MockTestReviewScreen`

### Route Naming
- **Pattern:** `{FeatureScreenType}` (PascalCase)
- **Examples:**
  - `DailyQuizQuestion`
  - `ChapterPracticeResult`
  - `MockTestReview`

### Folder Structure
```
screens/
├── auth/                  # Authentication flow
├── onboarding/            # New user onboarding
├── chapter_practice/      # Chapter practice feature
├── mock_test/             # Mock test feature
├── unlock_quiz/           # Chapter unlock quiz
├── history/               # History screens
├── profile/               # Profile management
├── subscription/          # Paywall and pricing
├── feedback/              # Feedback system
└── [feature]_screen.dart  # Root-level feature screens
```

---

## 🔄 COMMON SCREEN FLOWS

### First-Time User Flow
```
WelcomeScreen
→ PhoneEntryScreen
→ OtpVerificationScreen
→ OnboardingStep1Screen
→ OnboardingStep2Screen
→ CreatePinScreen
→ AssessmentInstructionsScreen
→ AssessmentLoadingScreen
→ AssessmentQuestionScreen (×30)
→ MainNavigationScreen (HomeScreen)
```

### Returning User Flow
```
PinVerificationScreen
→ MainNavigationScreen (HomeScreen)
```

### Daily Quiz Flow
```
HomeScreen
→ DailyQuizHomeScreen
→ DailyQuizLoadingScreen
→ DailyQuizQuestionScreen (×10)
→ DailyQuizResultScreen
→ DailyQuizReviewScreen (optional)
→ HomeScreen
```

### Chapter Practice Flow
```
HomeScreen
→ ChapterListScreen
→ ChapterPracticeLoadingScreen
→ ChapterPracticeQuestionScreen (×5-15)
→ ChapterPracticeResultScreen
→ ChapterPracticeReviewScreen (optional)
→ HomeScreen
```

### Snap & Solve Flow
```
HomeScreen (or SnapHomeScreen)
→ CameraScreen / Gallery Picker
→ PhotoReviewScreen
→ ProcessingScreen
→ SolutionReviewScreen
→ HomeScreen / AllSolutionsScreen
```

---

## 📚 REFERENCES

### Related Documentation
- [CLAUDE.md](../CLAUDE.md) - Main project documentation
- [TIER-SYSTEM-ARCHITECTURE.md](03-features/TIER-SYSTEM-ARCHITECTURE.md) - Subscription tier details
- [MOCK-TESTS-FEATURE-PLAN.md](03-features/MOCK-TESTS-FEATURE-PLAN.md) - Mock test specifications

### Key Files
- [mobile/lib/main.dart](../mobile/lib/main.dart) - App initialization and routing
- [mobile/lib/screens/main_navigation_screen.dart](../mobile/lib/screens/main_navigation_screen.dart) - Bottom nav shell
- [mobile/lib/providers/](../mobile/lib/providers/) - State management providers

---

**Maintained by:** Claude Code
**Version:** 1.0.0
**Last Audit:** 2026-02-13
