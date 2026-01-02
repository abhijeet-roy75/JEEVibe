# Daily Quiz API Endpoints - Complete Reference

## Base URL
`/api/daily-quiz`

All endpoints require authentication via Bearer token in `Authorization` header.

---

## Core Quiz Flow

### 1. Generate Quiz
**`GET /api/daily-quiz/generate`**

Generate a new daily quiz or return existing active quiz.

**Response:**
```json
{
  "success": true,
  "quiz": {
    "quiz_id": "quiz_5_2024-12-10",
    "quiz_number": 5,
    "learning_phase": "exploration",
    "questions": [
      {
        "question_id": "PHY_ELEC_E_001",
        "position": 1,
        "subject": "Physics",
        "chapter": "Electrostatics",
        "question_text": "...",
        "question_type": "numerical",
        "options": [],
        "image_url": "...",
        "time_estimate": 75
      }
    ],
    "generated_at": "2024-12-10T14:00:00Z",
    "is_recovery_quiz": false
  },
  "requestId": "..."
}
```

---

### 2. Start Quiz
**`POST /api/daily-quiz/start`**

Mark a quiz as started (starts timer).

**Request Body:**
```json
{
  "quiz_id": "quiz_5_2024-12-10"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Quiz started",
  "quiz_id": "quiz_5_2024-12-10",
  "started_at": "2024-12-10T14:05:00Z",
  "requestId": "..."
}
```

**Error Codes:**
- `MISSING_QUIZ_ID` - quiz_id not provided
- `QUIZ_NOT_FOUND` - Quiz doesn't exist
- `QUIZ_NOT_IN_PROGRESS` - Quiz is not in progress status

---

### 3. Submit Answer
**`POST /api/daily-quiz/submit-answer`**

Submit answer for a question and get immediate feedback.

**Request Body:**
```json
{
  "quiz_id": "quiz_5_2024-12-10",
  "question_id": "PHY_ELEC_E_001",
  "student_answer": "0.03375",
  "time_taken_seconds": 120
}
```

**Response:**
```json
{
  "success": true,
  "question_id": "PHY_ELEC_E_001",
  "is_correct": true,
  "correct_answer": "0.03375",
  "correct_answer_text": "0.03375 N",
  "explanation": "...",
  "solution_text": "...",
  "time_taken_seconds": 120,
  "requestId": "..."
}
```

**Error Codes:**
- `MISSING_REQUIRED_FIELDS` - Missing required fields
- `QUIZ_NOT_FOUND` - Quiz doesn't exist
- `QUIZ_NOT_IN_PROGRESS` - Quiz is not in progress
- `QUESTION_NOT_FOUND` - Question not found in quiz

---

### 4. Complete Quiz
**`POST /api/daily-quiz/complete`**

Complete a quiz and trigger theta updates.

**Request Body:**
```json
{
  "quiz_id": "quiz_5_2024-12-10"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Quiz completed",
  "quiz_id": "quiz_5_2024-12-10",
  "quiz_number": 5,
  "accuracy": 0.7,
  "score": 7,
  "total": 10,
  "chapters_updated": 3,
  "requestId": "..."
}
```

**Error Codes:**
- `MISSING_QUIZ_ID` - quiz_id not provided
- `QUIZ_NOT_FOUND` - Quiz doesn't exist
- `QUIZ_ALREADY_COMPLETED` - Quiz already completed
- `NO_RESPONSES_FOUND` - No answers submitted
- `USER_NOT_FOUND` - User not found

---

### 5. Get Active Quiz
**`GET /api/daily-quiz/active`**

Get the user's active (in-progress) quiz if any.

**Response:**
```json
{
  "success": true,
  "has_active_quiz": true,
  "quiz": {
    "quiz_id": "quiz_5_2024-12-10",
    "quiz_number": 5,
    "learning_phase": "exploration",
    "questions": [...],
    "generated_at": "2024-12-10T14:00:00Z",
    "started_at": "2024-12-10T14:05:00Z",
    "is_recovery_quiz": false
  },
  "requestId": "..."
}
```

---

## Quiz History & Results

### 6. Quiz History
**`GET /api/daily-quiz/history`**

Get list of completed quizzes with pagination.

**Query Parameters:**
- `limit` (default: 20, max: 50) - Number of quizzes to return
- `offset` (default: 0) - Number of quizzes to skip
- `start_date` (optional) - Filter from date (ISO string)
- `end_date` (optional) - Filter until date (ISO string)

**Response:**
```json
{
  "success": true,
  "quizzes": [
    {
      "quiz_id": "quiz_5_2024-12-10",
      "quiz_number": 5,
      "completed_at": "2024-12-10T14:35:00Z",
      "accuracy": 0.7,
      "score": 7,
      "total": 10,
      "total_time_seconds": 1200,
      "learning_phase": "exploration",
      "is_recovery_quiz": false,
      "chapters_covered": ["physics_electrostatics", "chemistry_organic"],
      "exploration_questions": 5,
      "deliberate_practice_questions": 4,
      "review_questions": 1
    }
  ],
  "pagination": {
    "limit": 20,
    "offset": 0,
    "total": 45,
    "has_more": true
  },
  "requestId": "..."
}
```

---

### 7. Quiz Result (Detailed)
**`GET /api/daily-quiz/result/:quiz_id`**

Get detailed result of a completed quiz with all questions, answers, and solutions.

**Response:**
```json
{
  "success": true,
  "quiz": {
    "quiz_id": "quiz_5_2024-12-10",
    "quiz_number": 5,
    "completed_at": "2024-12-10T14:35:00Z",
    "started_at": "2024-12-10T14:05:00Z",
    "generated_at": "2024-12-10T14:00:00Z",
    "accuracy": 0.7,
    "score": 7,
    "total": 10,
    "total_time_seconds": 1200,
    "avg_time_per_question": 120,
    "learning_phase": "exploration",
    "is_recovery_quiz": false,
    "chapters_covered": ["physics_electrostatics"],
    "questions": [
      {
        "question_id": "PHY_ELEC_E_001",
        "position": 1,
        "subject": "Physics",
        "chapter": "Electrostatics",
        "question_text": "...",
        "question_text_html": "...",
        "question_type": "numerical",
        "options": [],
        "image_url": "...",
        "student_answer": "0.03375",
        "correct_answer": "0.03375",
        "correct_answer_text": "0.03375 N",
        "is_correct": true,
        "time_taken_seconds": 120,
        "solution_text": "...",
        "solution_steps": [...],
        "concepts_tested": ["Coulomb's Law"],
        "selection_reason": "exploration",
        "chapter_key": "physics_electrostatics"
      }
    ]
  },
  "requestId": "..."
}
```

**Error Codes:**
- `QUIZ_NOT_FOUND` - Quiz doesn't exist
- `QUIZ_NOT_COMPLETED` - Quiz is not completed yet

---

## Question Details

### 8. Question Details
**`GET /api/daily-quiz/question/:question_id`**

Get full details of a question including solution.

**Query Parameters:**
- `include_solution` (default: true) - Include solution text and steps

**Response:**
```json
{
  "success": true,
  "question": {
    "question_id": "PHY_ELEC_E_001",
    "subject": "Physics",
    "chapter": "Electrostatics",
    "topic": "physics_electrostatics_coulomb",
    "question_type": "numerical",
    "question_text": "...",
    "question_text_html": "...",
    "options": [],
    "correct_answer": "0.03375",
    "correct_answer_text": "0.03375 N",
    "image_url": "...",
    "difficulty": "easy",
    "time_estimate": 75,
    "concepts_tested": ["Coulomb's Law"],
    "irt_parameters": {
      "difficulty_b": 0.45,
      "discrimination_a": 1.5,
      "guessing_c": 0.0
    },
    "solution_text": "...",
    "solution_steps": [...]
  },
  "requestId": "..."
}
```

**Error Codes:**
- `QUESTION_NOT_FOUND` - Question doesn't exist

---

## Progress & Analytics

### 9. Progress Overview
**`GET /api/daily-quiz/progress`**

Get progress data for home page display.

**Response:**
```json
{
  "success": true,
  "progress": {
    "chapters": {
      "physics_electrostatics": {
        "chapter_key": "physics_electrostatics",
        "current_theta": 0.5,
        "current_percentile": 69.15,
        "baseline_theta": 0.3,
        "baseline_percentile": 61.79,
        "theta_change": 0.2,
        "percentile_change": 7.36,
        "attempts": 12,
        "accuracy": 0.67,
        "status": "strong"
      }
    },
    "subjects": {
      "physics": {
        "theta": 0.4,
        "percentile": 65.54,
        "accuracy": 0.65,
        "questions_solved": 45
      }
    },
    "overall": {
      "theta": 0.3,
      "percentile": 61.79,
      "accuracy": 0.68
    },
    "cumulative": {
      "total_quizzes": 15,
      "total_questions": 150,
      "overall_accuracy": 0.68,
      "total_time_minutes": 300
    },
    "streak": {
      "current": 5,
      "longest": 12,
      "last_practice_date": "2024-12-10"
    }
  },
  "requestId": "..."
}
```

---

### 10. Detailed Statistics
**`GET /api/daily-quiz/stats`**

Get detailed statistics and trends.

**Query Parameters:**
- `days` (default: 30) - Number of days for trends

**Response:**
```json
{
  "success": true,
  "stats": {
    "accuracy_trends": [...],
    "chapter_progress": {...},
    "subject_progress": {...},
    "chapter_improvements": [
      {
        "chapter_key": "physics_electrostatics",
        "theta_change": 0.5,
        "percentile_change": 15.2
      }
    ],
    "cumulative": {...},
    "streak": {...}
  },
  "requestId": "..."
}
```

---

### 11. Quiz Summary
**`GET /api/daily-quiz/summary`**

Get quick summary for dashboard/home screen.

**Response:**
```json
{
  "success": true,
  "summary": {
    "has_active_quiz": true,
    "active_quiz": {
      "quiz_id": "quiz_5_2024-12-10",
      "quiz_number": 5,
      "questions_answered": 3,
      "total_questions": 10,
      "started_at": "2024-12-10T14:05:00Z"
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
    "next_quiz_available": false,
    "assessment_completed": true,
    "last_quiz_completed_at": "2024-12-10T14:35:00Z"
  },
  "requestId": "..."
}
```

---

### 12. Chapter Progress Details
**`GET /api/daily-quiz/chapter-progress/:chapter_key`**

Get detailed progress for a specific chapter.

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
    "confidence_SE": 0.25,
    "questions_solved": 12,
    "last_updated": "2024-12-10T14:30:00Z",
    "status": "strong"
  },
  "recent_quizzes": [
    {
      "quiz_id": "quiz_5_2024-12-10",
      "quiz_number": 5,
      "completed_at": "2024-12-10T14:35:00Z",
      "accuracy": 0.75,
      "questions_count": 2,
      "correct_count": 2
    }
  ],
  "requestId": "..."
}
```

**Error Codes:**
- `USER_NOT_FOUND` - User doesn't exist
- `CHAPTER_NOT_FOUND` - Chapter not found in user progress

---

## Error Response Format

All errors follow this standardized format:

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

### Common Error Codes

- `MISSING_QUIZ_ID` - quiz_id parameter missing
- `MISSING_REQUIRED_FIELDS` - Required fields missing
- `QUIZ_NOT_FOUND` - Quiz doesn't exist
- `QUIZ_NOT_IN_PROGRESS` - Quiz is not in progress
- `QUIZ_ALREADY_COMPLETED` - Quiz already completed
- `QUIZ_NOT_COMPLETED` - Quiz not completed yet
- `NO_RESPONSES_FOUND` - No responses in quiz
- `QUESTION_NOT_FOUND` - Question doesn't exist
- `USER_NOT_FOUND` - User doesn't exist
- `CHAPTER_NOT_FOUND` - Chapter not found
- `ASSESSMENT_NOT_COMPLETED` - User hasn't completed assessment
- `VALIDATION_ERROR` - Input validation failed
- `AUTHENTICATION_FAILED` - Authentication failed
- `INTERNAL_ERROR` - Internal server error

---

## Authentication

All endpoints require authentication via Firebase ID token:

```
Authorization: Bearer <firebase-id-token>
```

---

## Rate Limiting

- General API: 100 requests per 15 minutes per IP
- Quiz generation: 10 requests per hour per user
- Answer submission: 100 requests per 15 minutes per user

---

## Notes

1. All timestamps are in ISO 8601 format
2. All quiz questions are sanitized (answers removed) until quiz completion
3. Quiz completion triggers automatic theta updates
4. Quiz history supports pagination for large datasets
5. Error responses include requestId for debugging

---

**Last Updated:** 2024-12-13  
**Version:** 1.0.0

