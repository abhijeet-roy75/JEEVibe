# Chapter Practice Feature

## Overview

Chapter Practice allows students to focus on specific chapters they're weak in, identified through the "Your Focus Areas" section on the home dashboard. Unlike the Daily Adaptive Quiz which covers multiple chapters, Chapter Practice targets a single chapter with 15 questions designed to help students improve their understanding.

## Feature Access

### Prerequisites
- Student must have completed the Initial Assessment
- Student must have completed **at least 1 Daily Adaptive Quiz** (validates calibration)

### Tier-Based Limits

| Tier | Access | Weekly Limit |
|------|--------|--------------|
| **Free** | Enabled | 1 chapter per subject per week (7-day cooldown) |
| **Pro** | Enabled | Unlimited |
| **Ultra** | Enabled | Unlimited |

**Free Tier Behavior:**
- After completing a chapter practice for Physics, the student cannot practice another Physics chapter for 7 days
- They CAN still practice Chemistry or Mathematics chapters (each subject has independent cooldown)
- Shows "Unlocks in X days" when a subject is on cooldown

## Question Selection Algorithm

### Difficulty-Progressive Selection (v2.0)

Questions are ordered to "ease students into" the chapter:

1. **Easy Questions First** (5 questions): `difficulty_b ≤ 0.7`
2. **Medium Questions** (5 questions): `0.7 < difficulty_b ≤ 1.2`
3. **Hard Questions** (5 questions): `difficulty_b > 1.2`

Within each difficulty band, questions are prioritized by:
1. **Unseen** (priority 3) - Questions the student has never attempted
2. **Previously Wrong** (priority 2) - Questions answered incorrectly before
3. **Previously Correct** (priority 1) - Questions answered correctly before

**Fallback Logic:**
- If a difficulty band has insufficient questions, borrow from adjacent bands
- Maintain overall progression from easier to harder
- Total questions: 15 (configurable, max 20)

### Question History Tracking

The system checks both:
- `daily_quiz_responses` - Questions answered in daily quizzes
- `chapter_practice_responses` - Questions answered in previous chapter practice sessions

This ensures questions are prioritized correctly across all practice modes.

## IRT Parameters

Questions use the 3-Parameter Logistic (3PL) IRT model:

| Parameter | Field | Range | Description |
|-----------|-------|-------|-------------|
| **a** | `discrimination_a` | 0.5-2.5 | How well the question differentiates ability levels |
| **b** | `difficulty_b` | -3.0 to +3.0 | Question difficulty (matches student theta) |
| **c** | `guessing_c` | 0.0-0.25 | Probability of guessing correctly (0.25 for MCQ, 0 for numerical) |

## Theta Update (0.5x Multiplier)

Chapter Practice uses a **0.5x theta multiplier** compared to Daily Quiz (1.0x):

```
adjusted_theta_delta = raw_theta_delta × 0.5
```

**Rationale:**
- Chapter Practice is lower-stakes (no timer, unlimited time per question)
- Prevents artificial theta inflation from repeated practice
- Encourages students to also take Daily Quizzes for full credit

## User Experience Flow

### Entry Point
1. Student navigates to Home Dashboard
2. Clicks on a chapter in "Your Focus Areas" card
3. If prerequisites not met → Shows unlock message
4. If on weekly cooldown (free tier) → Shows "Unlocks in X days"
5. Otherwise → Navigates to Chapter Practice Loading Screen

### Practice Session
1. **Loading Screen**: Generates session, shows chapter info
2. **Question Screen**:
   - Shows question with options (MCQ) or input field (Numerical)
   - No timer (practice mode badge shown)
   - Student selects/enters answer and submits
3. **Feedback**:
   - Correct/Incorrect banner
   - Detailed explanation with step-by-step solution
   - Teacher message (Priya Ma'am)
4. **Navigation**: Next question or Complete session
5. **Review Screen**: Summary with accuracy, review all questions

### Session Persistence
- Sessions are saved locally for mid-exit recovery
- Backend tracks session status: `in_progress` → `completed`
- Sessions expire after 24 hours if not completed

## API Endpoints

### POST `/api/chapter-practice/generate`
Creates a new chapter practice session.

**Request:**
```json
{
  "chapter_key": "physics_kinematics",
  "question_count": 15
}
```

**Validations:**
1. User authenticated
2. Tier has `chapter_practice_enabled: true`
3. Weekly limit not exceeded (free tier only)
4. User has `completed_quiz_count >= 1`

**Response:**
```json
{
  "success": true,
  "session": {
    "session_id": "cp_abc123_1705600000",
    "chapter_key": "physics_kinematics",
    "chapter_name": "Kinematics",
    "subject": "Physics",
    "questions": [...],
    "total_questions": 15,
    "theta_at_start": 0.5
  },
  "is_existing_session": false
}
```

### POST `/api/chapter-practice/submit-answer`
Submit answer for a question (updates theta immediately).

**Request:**
```json
{
  "session_id": "cp_abc123_1705600000",
  "question_id": "q_xyz789",
  "student_answer": "B",
  "time_taken_seconds": 120
}
```

**Response:**
```json
{
  "success": true,
  "is_correct": true,
  "correct_answer": "B",
  "solution_text": "...",
  "solution_steps": [...],
  "theta_delta": 0.15,
  "theta_multiplier": 0.5
}
```

### POST `/api/chapter-practice/complete`
Complete the session and update aggregated stats.

**Response:**
```json
{
  "success": true,
  "summary": {
    "accuracy": 0.73,
    "correct_count": 11,
    "total_time_seconds": 1200,
    "theta_improvement": 0.45
  },
  "updated_stats": {
    "overall_theta": 0.95,
    "overall_percentile": 52.3
  }
}
```

## Data Schema

### Firestore Collections

```
users/{userId}/
├── theta_by_chapter/{chapterKey}    # Chapter-level theta
├── chapter_practice_stats           # Aggregated practice stats
└── chapter_practice_weekly/{subject} # Weekly limit tracking (free tier)

chapter_practice_sessions/{userId}/sessions/{sessionId}/
├── [session metadata]
└── questions/{position}             # Individual questions with state

chapter_practice_responses/{userId}/responses/{sessionId}_{questionId}
└── [response data with theta_delta]
```

### Weekly Limit Document
```json
{
  "subject": "physics",
  "last_chapter_key": "physics_kinematics",
  "last_chapter_name": "Kinematics",
  "last_completed_at": "2024-01-18T10:30:00Z",
  "expires_at": "2024-01-25T10:30:00Z"
}
```

## Mobile Implementation

### Screens
- `ChapterPracticeLoadingScreen` - Session initialization
- `ChapterPracticeQuestionScreen` - Main question interface
- `ChapterPracticeReviewScreen` - Session results

### Shared Widgets (from Daily Quiz)
- `FeedbackBannerWidget` - Correct/incorrect feedback
- `DetailedExplanationWidget` - Step-by-step solutions
- `QuestionCardWidget` - Question display and options

### Adapters
Model adapters convert between chapter practice and daily quiz models:
- `practiceQuestionToDailyQuiz()` - For question display
- `practiceResultToFeedback()` - For feedback/explanation display

## Error Codes

| Code | HTTP | Description |
|------|------|-------------|
| `DAILY_QUIZ_REQUIRED` | 403 | Must complete at least 1 daily quiz first |
| `FEATURE_NOT_ENABLED` | 403 | Chapter practice not available for tier |
| `WEEKLY_LIMIT_REACHED` | 403 | Free tier weekly limit exceeded |
| `SESSION_NOT_FOUND` | 404 | Session doesn't exist |
| `SESSION_EXPIRED` | 410 | Session expired (24h limit) |
| `QUESTION_ALREADY_ANSWERED` | 400 | Question was already answered |

## Configuration

### Tier Config (`tier_config/active`)
```json
{
  "tiers": {
    "free": {
      "limits": {
        "chapter_practice_enabled": true,
        "chapter_practice_per_chapter": 15,
        "chapter_practice_weekly_per_subject": 1
      }
    },
    "pro": {
      "limits": {
        "chapter_practice_enabled": true,
        "chapter_practice_per_chapter": 20,
        "chapter_practice_weekly_per_subject": -1
      }
    }
  }
}
```

Note: `-1` means unlimited.

## Testing

### Backend Tests
```bash
cd backend
npm test -- --grep "chapter-practice"
npm test -- --grep "selectDifficultyProgressiveQuestions"
```

### Mobile Tests
```bash
cd mobile
flutter test test/unit/utils/question_adapters_test.dart
flutter test test/unit/providers/chapter_practice_provider_test.dart
```

## Related Documentation
- [Daily Quiz Implementation](./DAILY_QUIZ_UI_READINESS.md)
- [IRT Algorithm Specification](../02-architecture/engine/JEEVibe_IIDP_Algorithm_Specification_v4_CALIBRATED.md)
- [Database Schema](../02-architecture/database-schema.md)
