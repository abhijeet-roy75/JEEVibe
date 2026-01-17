# Chapter Practice Feature Implementation Plan

**Created:** 2026-01-17
**Status:** Planned
**Feature:** Pro/Ultra tier feature for focused chapter practice

## Overview

Build a Chapter Practice feature that allows students to practice questions from specific chapters they need to focus on. Entry point is the Focus Areas card on the home page.

## Key Requirements

- Entry from Focus Areas card (tap on chapter → start practice)
- Up to 15 questions from selected chapter only
- Question selection based on IRT theta with difficulty matching
- Prioritize questions user hasn't seen or got wrong before
- No timer (practice mode, not test)
- Answer flow: select → submit → see feedback (same as daily quiz)
- Review screen after last question
- **0.5 multiplier on theta delta** (vs 1.0 for daily quiz)
- Mid-exit: save partial progress and update theta for completed questions
- Re-practice: prioritize unseen/wrong questions

## Architecture Decision

**Create NEW dedicated screens and services** (not reuse daily quiz with mode parameter):

- Cleaner separation of concerns
- Easier to customize UI/UX for practice context
- No risk of regression to daily quiz
- More maintainable long-term

---

## Backend Changes

### 1. New Service: `backend/src/services/chapterPracticeService.js`

```javascript
// Core functions:
// - generateChapterPractice(userId, chapterId, questionCount = 15)
// - submitAnswer(userId, sessionId, questionId, selectedOption)
// - completeSession(userId, sessionId)
// - getSessionProgress(userId, sessionId)
```

Key logic:
- Query questions filtered by `chapter_key`
- Use `questionSelectionService.selectQuestions()` with chapter filter
- Prioritize questions where user has `seen_count === 0` or `last_correct === false`
- Store session in `users/{userId}/chapter_practice_sessions/{sessionId}`

### 2. New Routes: `backend/src/routes/chapterPractice.js`

```
POST /api/chapter-practice/generate
  Body: { chapter_key: string, question_count?: number }
  Returns: { session_id, questions[], chapter_info }

POST /api/chapter-practice/submit-answer
  Body: { session_id, question_id, selected_option }
  Returns: { is_correct, correct_option, explanation, theta_delta }

POST /api/chapter-practice/complete
  Body: { session_id }
  Returns: { summary, updated_stats }

GET /api/chapter-practice/session/:sessionId
  Returns: { session data for resume }
```

### 3. Modify: `backend/src/services/thetaUpdateService.js`

Add multiplier parameter to `updateTheta()`:

```javascript
async updateTheta(userId, subtopicId, isCorrect, questionDifficulty, options = {}) {
  const multiplier = options.multiplier ?? 1.0; // Default 1.0 for daily quiz
  // ... existing calculation ...
  const adjustedDelta = thetaDelta * multiplier;
  // ... apply to user theta ...
}
```

### 4. Register Routes: `backend/src/index.js`

```javascript
const chapterPracticeRoutes = require('./routes/chapterPractice');
app.use('/api/chapter-practice', authenticate, chapterPracticeRoutes);
```

---

## Mobile Changes

### 1. New Provider: `mobile/lib/providers/chapter_practice_provider.dart`

```dart
class ChapterPracticeProvider extends ChangeNotifier {
  ChapterPracticeSession? _session;
  int _currentQuestionIndex = 0;
  bool _isLoading = false;
  List<QuestionResult> _results = [];

  // Methods:
  Future<void> startPractice(String chapterKey, String authToken);
  Future<AnswerResult> submitAnswer(int selectedOption);
  void nextQuestion();
  Future<void> completeSession();
  void reset();
}
```

### 2. New Models: `mobile/lib/models/chapter_practice_models.dart`

```dart
class ChapterPracticeSession {
  final String sessionId;
  final String chapterId;
  final String chapterName;
  final String subject;
  final List<PracticeQuestion> questions;
  final DateTime startedAt;
}

class PracticeQuestion {
  final String id;
  final String text;
  final List<String> options;
  final String? imageUrl;
  final String subtopicId;
  final String subtopicName;
}

class PracticeAnswerResult {
  final bool isCorrect;
  final int correctOption;
  final String explanation;
  final double thetaDelta;
}
```

### 3. New Storage: `mobile/lib/services/chapter_practice_storage_service.dart`

Local persistence for mid-exit recovery:

```dart
class ChapterPracticeStorageService {
  Future<void> saveSession(ChapterPracticeSession session);
  Future<ChapterPracticeSession?> loadSession(String sessionId);
  Future<void> clearSession(String sessionId);
  Future<void> saveProgress(String sessionId, int questionIndex, List<QuestionResult> results);
}
```

### 4. New Screens

#### `mobile/lib/screens/chapter_practice/chapter_practice_loading_screen.dart`

- Shows "Preparing Chapter Practice..."
- Displays chapter name and subject
- Calls API to generate questions
- Navigates to question screen on success

#### `mobile/lib/screens/chapter_practice/chapter_practice_question_screen.dart`

- Similar layout to daily quiz question screen
- Header: "Chapter Practice - {ChapterName}"
- Progress: "Question X of Y"
- No timer
- Option selection → Submit → Show feedback → Next
- "End Practice" button to exit early (with confirmation)

#### `mobile/lib/screens/chapter_practice/chapter_practice_review_screen.dart`

- Summary: X/Y correct
- List of all questions with correct/incorrect indicator
- Tap to expand and see explanation
- "Back to Home" button
- Option to "Practice Again" (same chapter)

### 5. Update Focus Areas Card: `mobile/lib/screens/assessment_intro_screen.dart`

Add tap handler to focus area items:

```dart
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChapterPracticeLoadingScreen(
        chapterKey: focusArea.chapterKey,
        chapterName: focusArea.chapterName,
        subject: focusArea.subject,
      ),
    ),
  );
}
```

### 6. Update API Service: `mobile/lib/services/api_service.dart`

Add chapter practice endpoints:

```dart
Future<Map<String, dynamic>> generateChapterPractice(String chapterKey, {int? questionCount});
Future<Map<String, dynamic>> submitChapterPracticeAnswer(String sessionId, String questionId, int selectedOption);
Future<Map<String, dynamic>> completeChapterPractice(String sessionId);
```

---

## Data Flow

```
User taps Focus Area chapter
    ↓
ChapterPracticeLoadingScreen
    ↓
POST /api/chapter-practice/generate { chapter_key }
    ↓
Backend: chapterPracticeService.generateChapterPractice()
  - Fetch user theta for chapter subtopics
  - Query questions with chapter_key filter
  - Prioritize unseen/wrong questions
  - Select up to 15 questions using IRT
  - Create session document
    ↓
Return session with questions
    ↓
ChapterPracticeQuestionScreen (loop through questions)
    ↓
POST /api/chapter-practice/submit-answer { session_id, question_id, selected_option }
    ↓
Backend:
  - Record answer in session
  - Calculate theta delta with 0.5 multiplier
  - Update user theta immediately
  - Return result
    ↓
After last question OR user exits
    ↓
POST /api/chapter-practice/complete { session_id }
    ↓
Backend:
  - Mark session complete
  - Recalculate focus areas
  - Return summary
    ↓
ChapterPracticeReviewScreen
```

---

## Files to Create

1. `backend/src/services/chapterPracticeService.js`
2. `backend/src/routes/chapterPractice.js`
3. `mobile/lib/models/chapter_practice_models.dart`
4. `mobile/lib/providers/chapter_practice_provider.dart`
5. `mobile/lib/services/chapter_practice_storage_service.dart`
6. `mobile/lib/screens/chapter_practice/chapter_practice_loading_screen.dart`
7. `mobile/lib/screens/chapter_practice/chapter_practice_question_screen.dart`
8. `mobile/lib/screens/chapter_practice/chapter_practice_review_screen.dart`

## Files to Modify

1. `backend/src/services/thetaUpdateService.js` - Add multiplier parameter
2. `backend/src/index.js` - Register routes
3. `mobile/lib/services/api_service.dart` - Add endpoints
4. `mobile/lib/screens/assessment_intro_screen.dart` - Add tap handler to Focus Areas
5. `mobile/lib/widgets/analytics/overview_tab.dart` - Add tap handler (if Focus Areas shown there)

---

## Offline Handling (Same Pattern as Daily Quiz)

**Approach:** Online-required to start, with mid-session resilience

1. **Requires online to START** - Loading screen checks connectivity via `ConnectivityService`; shows "No internet connection" error if offline
2. **Mid-session persistence** - Save session state locally via `ChapterPracticeStorageService` so user can resume if app closes
3. **Queue answers if connection lost** - Use existing `OfflineQueueService` to queue answer submissions during connection loss, sync when back online

This matches daily quiz behavior exactly. True offline mode (pre-caching questions per chapter for Pro/Ultra) would be a future enhancement.

---

## Subscription Gating

Chapter Practice is gated by subscription tier:

| Tier  | `chapter_practice_enabled` | `chapter_practice_per_chapter` |
|-------|---------------------------|-------------------------------|
| Free  | false                     | 0                             |
| Pro   | true                      | 20                            |
| Ultra | true                      | -1 (unlimited)                |

Related files already updated:
- `backend/src/services/tierConfigService.js`
- `mobile/lib/models/subscription_models.dart`
- `mobile/lib/services/subscription_service.dart`
- `mobile/lib/screens/subscription/paywall_screen.dart`

---

## Verification Plan

1. **Backend API testing:**
   - Test generate endpoint creates session with correct questions
   - Test submit-answer updates theta with 0.5 multiplier
   - Test complete endpoint marks session done

2. **Mobile flow testing:**
   - Tap Focus Area chapter → loading screen appears
   - Questions load and display correctly
   - Submit answer → feedback shown → next question
   - Complete all questions → review screen shown
   - Exit early → partial progress saved, theta updated

3. **Theta multiplier verification:**
   - Compare theta delta for same question in daily quiz vs chapter practice
   - Chapter practice delta should be 0.5x daily quiz delta

4. **Mid-exit recovery:**
   - Start practice, answer 5 questions, kill app
   - Reopen → can resume from question 6
