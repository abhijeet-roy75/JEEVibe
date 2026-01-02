# Daily Quiz UI Readiness Checklist

## ✅ COMPLETED - Ready for UI

### Database Schema
- ✅ User profile with theta tracking
- ✅ Daily quiz collection structure
- ✅ Response tracking structure
- ✅ Progress tracking fields
- ✅ Firestore indexes configured

### Core API Endpoints
- ✅ `GET /api/daily-quiz/generate` - Generate new quiz
- ✅ `POST /api/daily-quiz/start` - Start a quiz
- ✅ `POST /api/daily-quiz/submit-answer` - Submit answer with immediate feedback
- ✅ `POST /api/daily-quiz/complete` - Complete quiz and update theta
- ✅ `GET /api/daily-quiz/active` - Get active quiz
- ✅ `GET /api/daily-quiz/progress` - Get progress data
- ✅ `GET /api/daily-quiz/stats` - Get detailed statistics

### Backend Services
- ✅ Quiz generation service
- ✅ Question selection (IRT-based)
- ✅ Theta update service
- ✅ Progress tracking service
- ✅ Streak tracking service
- ✅ Circuit breaker service
- ✅ Spaced repetition service

### Data Quality & Security
- ✅ Transaction protection (race conditions fixed)
- ✅ Input validation
- ✅ Error handling
- ✅ Authentication middleware
- ✅ Data sanitization (answers removed from responses)

---

## 🔴 CRITICAL - Must Build Before UI

### 1. Quiz History Endpoint
**Priority:** Critical  
**Why:** Users need to see their past quiz performance

**Endpoint:** `GET /api/daily-quiz/history`

**Query Params:**
- `limit` (default: 20)
- `offset` (default: 0)
- `start_date` (optional)
- `end_date` (optional)

**Response:**
```json
{
  "success": true,
  "quizzes": [
    {
      "quiz_id": "quiz_5_2024-12-10",
      "quiz_number": 5,
      "completed_at": "2024-12-10T14:30:00Z",
      "accuracy": 0.7,
      "score": 7,
      "total": 10,
      "total_time_seconds": 1200,
      "learning_phase": "exploration",
      "is_recovery_quiz": false,
      "chapters_covered": ["physics_electrostatics", "chemistry_organic"]
    }
  ],
  "total": 45,
  "has_more": true
}
```

---

### 2. Individual Quiz Result Endpoint
**Priority:** Critical  
**Why:** Users need to review completed quizzes with answers and explanations

**Endpoint:** `GET /api/daily-quiz/result/:quiz_id`

**Response:**
```json
{
  "success": true,
  "quiz": {
    "quiz_id": "quiz_5_2024-12-10",
    "quiz_number": 5,
    "completed_at": "2024-12-10T14:30:00Z",
    "accuracy": 0.7,
    "score": 7,
    "total": 10,
    "total_time_seconds": 1200,
    "learning_phase": "exploration",
    "is_recovery_quiz": false,
    "questions": [
      {
        "question_id": "PHY_ELEC_E_001",
        "position": 1,
        "question_text": "...",
        "options": [...],
        "student_answer": "A",
        "correct_answer": "B",
        "is_correct": false,
        "time_taken_seconds": 120,
        "solution_text": "...",
        "solution_steps": [...],
        "explanation": "..."
      }
    ]
  }
}
```

---

### 3. Question Details Endpoint (for Review)
**Priority:** High  
**Why:** Users may want to review specific questions with full solution

**Endpoint:** `GET /api/daily-quiz/question/:question_id`

**Query Params:**
- `include_solution` (default: true)

**Response:**
```json
{
  "success": true,
  "question": {
    "question_id": "PHY_ELEC_E_001",
    "subject": "Physics",
    "chapter": "Electrostatics",
    "question_text": "...",
    "question_text_html": "...",
    "options": [...],
    "correct_answer": "B",
    "solution_text": "...",
    "solution_steps": [...],
    "concepts_tested": [...],
    "image_url": "..."
  }
}
```

---

## 🟡 HIGH PRIORITY - Should Build Before UI

### 4. Quiz Summary Endpoint
**Priority:** High  
**Why:** Quick summary for dashboard/home screen

**Endpoint:** `GET /api/daily-quiz/summary`

**Response:**
```json
{
  "success": true,
  "summary": {
    "has_active_quiz": true,
    "active_quiz": {
      "quiz_id": "...",
      "quiz_number": 5,
      "questions_answered": 3,
      "total_questions": 10
    },
    "today_stats": {
      "quizzes_completed": 1,
      "questions_solved": 10,
      "accuracy": 0.7,
      "time_spent_minutes": 20
    },
    "streak": {
      "current": 5,
      "longest": 12
    },
    "next_quiz_available": true
  }
}
```

---

### 5. Chapter Progress Details Endpoint
**Priority:** High  
**Why:** Detailed chapter-level progress for progress screen

**Endpoint:** `GET /api/daily-quiz/chapter-progress/:chapter_key`

**Response:**
```json
{
  "success": true,
  "chapter": {
    "chapter_key": "physics_electrostatics",
    "subject": "Physics",
    "chapter": "Electrostatics",
    "current_theta": 0.5,
    "current_percentile": 69.15,
    "baseline_theta": 0.3,
    "baseline_percentile": 61.79,
    "theta_change": 0.2,
    "percentile_change": 7.36,
    "attempts": 12,
    "accuracy": 0.67,
    "questions_solved": 12,
    "last_updated": "2024-12-10T14:30:00Z",
    "status": "strong"
  },
  "recent_quizzes": [
    {
      "quiz_id": "...",
      "completed_at": "...",
      "accuracy": 0.75,
      "questions_count": 2
    }
  ]
}
```

---

### 6. Error Response Standardization
**Priority:** High  
**Why:** Consistent error handling for frontend

**Current:** Errors are inconsistent  
**Needed:** Standard error response format

**Standard Format:**
```json
{
  "success": false,
  "error": {
    "code": "QUIZ_NOT_FOUND",
    "message": "Quiz not found",
    "details": {}
  },
  "requestId": "..."
}
```

**Error Codes Needed:**
- `QUIZ_NOT_FOUND`
- `QUIZ_ALREADY_COMPLETED`
- `QUIZ_NOT_STARTED`
- `INSUFFICIENT_QUESTIONS`
- `ASSESSMENT_NOT_COMPLETED`
- `INVALID_ANSWER_FORMAT`
- `TIMEOUT_ERROR`

---

## 🟢 MEDIUM PRIORITY - Nice to Have

### 7. API Documentation
**Priority:** Medium  
**Why:** Frontend team needs clear API docs

**Format:** OpenAPI/Swagger or Markdown

**Should Include:**
- All endpoints with request/response examples
- Error codes and handling
- Authentication requirements
- Rate limiting info
- Data models

---

### 8. Quiz Analytics Endpoint
**Priority:** Medium  
**Why:** Advanced analytics for analytics screen

**Endpoint:** `GET /api/daily-quiz/analytics`

**Query Params:**
- `period` (7d, 30d, 90d, all)
- `subject` (optional filter)

**Response:**
```json
{
  "success": true,
  "analytics": {
    "accuracy_trend": [...],
    "theta_trend": [...],
    "subject_comparison": {...},
    "chapter_heatmap": {...},
    "time_analysis": {...}
  }
}
```

---

### 9. Question Review List Endpoint
**Priority:** Medium  
**Why:** Show questions due for review (spaced repetition)

**Endpoint:** `GET /api/daily-quiz/review-questions`

**Response:**
```json
{
  "success": true,
  "review_questions": [
    {
      "question_id": "...",
      "last_answered_at": "...",
      "review_interval": 7,
      "days_overdue": 2,
      "chapter": "...",
      "subject": "..."
    }
  ],
  "total_due": 5
}
```

---

### 10. Quiz Performance Comparison
**Priority:** Low  
**Why:** Compare performance over time periods

**Endpoint:** `GET /api/daily-quiz/compare`

**Query Params:**
- `period1` (e.g., "2024-12-01 to 2024-12-07")
- `period2` (e.g., "2024-12-08 to 2024-12-14")

---

## 📋 Database Considerations

### Indexes Needed
- ✅ Quiz history query index (already configured)
- ⚠️ Verify: `daily_quizzes/{userId}/quizzes` collection needs:
  - `status` + `completed_at` (descending) - for history
  - `status` + `generated_at` (descending) - for active quiz

### Data Validation
- ✅ User must complete assessment before daily quizzes
- ✅ Quiz size validation (10 questions)
- ⚠️ Add: Quiz completion time validation (max time limit?)

---

## 🧪 Testing Requirements

### Before UI Development
1. ✅ Unit tests for core services
2. ⚠️ Integration tests for all endpoints
3. ⚠️ Load testing for quiz generation
4. ⚠️ Error scenario testing

---

## 📝 Documentation Needed

### For Frontend Team
1. **API Endpoint Documentation**
   - Request/response formats
   - Error handling
   - Authentication
   - Rate limits

2. **Data Models**
   - Quiz object structure
   - Question object structure
   - Progress object structure
   - Response object structure

3. **User Flows**
   - Quiz generation flow
   - Quiz taking flow
   - Quiz completion flow
   - Progress tracking flow

4. **Error Scenarios**
   - What happens when quiz generation fails?
   - What happens when answer submission fails?
   - How to handle network errors?
   - How to handle expired sessions?

---

## 🚀 Recommended Development Order

### Phase 1: Critical (Before UI)
1. Quiz History Endpoint
2. Individual Quiz Result Endpoint
3. Question Details Endpoint
4. Error Response Standardization

### Phase 2: High Priority (Parallel with UI)
5. Quiz Summary Endpoint
6. Chapter Progress Details Endpoint
7. API Documentation

### Phase 3: Medium Priority (After UI MVP)
8. Quiz Analytics Endpoint
9. Question Review List Endpoint
10. Performance Comparison

---

## ✅ Summary

### Ready for UI Development
- Core quiz flow (generate, start, submit, complete)
- Progress tracking
- Stats and analytics

### Must Build First
- Quiz history endpoint
- Quiz result endpoint
- Question details endpoint
- Error standardization

### Estimated Time
- **Critical items:** 1-2 days
- **High priority:** 1 day
- **Total before UI:** 2-3 days

---

**Status:** 70% Ready - Need critical endpoints before UI development

