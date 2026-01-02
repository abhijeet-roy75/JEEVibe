# State Persistence Implementation

## Overview

State persistence has been implemented for the Daily Quiz feature, allowing users to resume their quiz progress even after app restarts or crashes.

## Implementation Details

### 1. Quiz Storage Service

**File:** `mobile/lib/services/quiz_storage_service.dart`

**Features:**
- Saves complete quiz state to local storage (SharedPreferences)
- Stores:
  - Quiz data (questions, answers, feedback)
  - Current question index
  - Question states (timers, selected answers, feedback)
  - Quiz start time
- Automatic state expiration (24 hours)
- State restoration on app launch

**Key Methods:**
- `saveQuizState()` - Saves current quiz state
- `loadQuizState()` - Loads saved quiz state
- `clearQuizState()` - Clears saved state (on completion)
- `hasSavedQuizState()` - Checks if state exists
- `isStateExpired()` - Checks if state has expired

### 2. Provider Integration

**File:** `mobile/lib/providers/daily_quiz_provider.dart`

**Changes:**
- Added `QuizStorageService` integration
- Automatic state saving on:
  - Quiz generation
  - Quiz start
  - Answer submission
  - Question navigation
  - Timer updates (every 5 seconds)
- Automatic state restoration on provider initialization
- State clearing on quiz completion

**New Methods:**
- `_saveQuizState()` - Internal method to save state
- `_restoreQuizState()` - Internal method to restore state
- `hasSavedState()` - Public method to check for saved state
- `isRestoringState` - Getter for restoration status

### 3. Screen Updates

**Files Modified:**
- `mobile/lib/screens/daily_quiz_question_screen.dart`
  - Added state restoration check on init
  - Handles restored quiz state gracefully
  - Resumes from saved position

- `mobile/lib/screens/daily_quiz_loading_screen.dart`
  - Checks for saved state before generating new quiz
  - Restores existing quiz if available

## Data Model

### QuizStateData
```dart
class QuizStateData {
  final DailyQuiz quiz;
  final int currentIndex;
  final Map<int, QuestionStateData> questionStates;
  final DateTime startedAt;
}
```

### QuestionStateData
```dart
class QuestionStateData {
  final DateTime startTime;
  final int elapsedSeconds;
  final String? selectedAnswer;
  final bool isAnswered;
  final bool showDetailedExplanation;
  final AnswerFeedback? feedback;
}
```

## Storage Keys

All keys use prefix `jeevibe_quiz_`:
- `jeevibe_quiz_current_quiz` - Quiz JSON data
- `jeevibe_quiz_current_index` - Current question index
- `jeevibe_quiz_question_states` - Question states JSON
- `jeevibe_quiz_started_at` - Quiz start timestamp
- `jeevibe_quiz_last_saved_at` - Last save timestamp

## State Expiration

- **Expiration Time:** 24 hours from last save
- **Behavior:** Expired state is automatically cleared
- **Rationale:** Prevents stale quiz data from being restored

## Usage Flow

### Normal Flow:
1. User starts quiz → State saved
2. User answers questions → State saved after each answer
3. User navigates questions → State saved
4. User completes quiz → State cleared

### App Restart Flow:
1. App launches → Provider initializes
2. Provider checks for saved state
3. If valid state exists → Restore quiz
4. User continues from saved position
5. If state expired → Clear and start fresh

### Error Recovery:
- If state restoration fails → Start fresh quiz
- If state is corrupted → Clear and start fresh
- If quiz ID mismatch → Clear and start fresh

## Benefits

1. **User Experience:**
   - No progress loss on app restart
   - Seamless quiz continuation
   - Better offline support

2. **Reliability:**
   - Handles app crashes gracefully
   - Prevents data loss
   - Automatic cleanup of expired state

3. **Performance:**
   - Periodic saves (every 5 seconds for timers)
   - Efficient JSON serialization
   - Minimal storage overhead

## Testing Considerations

**Test Cases:**
1. Start quiz → Close app → Reopen → Verify restoration
2. Answer questions → Close app → Reopen → Verify answers saved
3. Complete quiz → Verify state cleared
4. Wait 24+ hours → Verify state expired
5. Corrupt state → Verify graceful handling

## Future Enhancements

1. **Offline Mode:**
   - Queue answer submissions when offline
   - Sync when connection restored

2. **State Compression:**
   - Compress large quiz data
   - Reduce storage footprint

3. **Backup to Cloud:**
   - Sync state to Firebase
   - Restore across devices

---

**Status:** ✅ Complete  
**Last Updated:** December 2024

