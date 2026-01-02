# JEEVibe Database Schema - Complete Design

## Overview

This document defines the complete Firestore database schema for JEEVibe, including:
- User profiles and assessment data
- Question banks (initial assessment + daily quiz)
- Response tracking (assessment + daily quiz)
- Progress tracking and analytics

**All collections use backend API access only** (no direct client access per security rules).

---

## Collections

### 1. `users/{userId}` - User Profile & Learning State

**Purpose:** Central user document containing profile, assessment results, and daily quiz state.

**Document Structure:**
```javascript
{
  // ========================================
  // USER PROFILE (from mobile app)
  // ========================================
  uid: "user123",                    // Firebase Auth UID (document ID)
  phoneNumber: "+91-9876543210",
  profileCompleted: true,
  
  // Basic Profile
  firstName: "Rajesh",
  lastName: "Kumar",
  email: "rajesh@example.com",
  dateOfBirth: Timestamp,           // Firestore Timestamp
  gender: "male",
  currentClass: "12",
  targetExam: "JEE Main",
  targetYear: "2025",
  
  // Advanced Profile
  schoolName: "ABC School",
  city: "Mumbai",
  state: "Maharashtra",
  coachingInstitute: "XYZ Coaching",
  coachingBranch: "Andheri",
  studyMode: "online",
  preferredLanguage: "english",
  weakSubjects: ["chemistry"],
  strongSubjects: ["mathematics"],
  
  // Metadata
  createdAt: Timestamp,
  lastActive: Timestamp,
  
  // ========================================
  // INITIAL ASSESSMENT DATA
  // ========================================
  assessment: {
    status: "completed" | "in_progress" | "not_started" | "error",
    started_at: "2024-12-03T09:00:00Z",
    completed_at: "2024-12-03T09:45:00Z",
    time_taken_seconds: 2700,
    responses: [                     // Summary only (full data in assessment_responses)
      { question_id: "...", is_correct: true, time_taken_seconds: 95 }
    ]
  },
  
  // ========================================
  // THETA TRACKING (Chapter-Level - PRIMARY)
  // ========================================
  // CURRENT VALUES (updated after each quiz)
  theta_by_chapter: {
    "physics_electrostatics": {
      theta: 0.5,                    // [-3.0, +3.0] - CURRENT value
      percentile: 69.15,              // 0-100 - CURRENT value
      confidence_SE: 0.25,            // Standard error (uncertainty)
      attempts: 12,                   // Total questions answered
      accuracy: 0.67,                 // Cumulative accuracy (0-1)
      last_updated: "2024-12-10T14:30:00Z"
    },
    "chemistry_organic": {
      theta: -0.8,
      percentile: 21.19,
      confidence_SE: 0.42,
      attempts: 5,
      accuracy: 0.40,
      last_updated: "2024-12-09T10:15:00Z"
    }
    // ... all chapters tested
  },
  
  // BASELINE SNAPSHOT (from initial assessment - never updated)
  assessment_baseline: {
    theta_by_chapter: {
      "physics_electrostatics": {
        theta: 0.3,                   // Baseline from assessment
        percentile: 61.79,
        attempts: 3,
        accuracy: 0.67
      },
      // ... all chapters from assessment
    },
    theta_by_subject: {
      physics: { theta: 0.1, percentile: 53.98 },
      chemistry: { theta: -0.4, percentile: 34.46 },
      mathematics: { theta: 0.3, percentile: 61.79 }
    },
    overall_theta: 0.1,
    overall_percentile: 53.98,
    captured_at: "2024-12-03T09:00:00Z"  // Assessment completion time
  },
  
  // ========================================
  // THETA TRACKING (Subject-Level - DERIVED)
  // ========================================
  // CURRENT VALUES (recalculated after each quiz)
  theta_by_subject: {
    physics: {
      theta: 0.2,                    // CURRENT value
      percentile: 57.93,              // CURRENT value
      chapters_tested: 8,
      status: "tested" | "not_tested"
    },
    chemistry: {
      theta: -0.3,
      percentile: 38.21,
      chapters_tested: 6,
      status: "tested"
    },
    mathematics: {
      theta: 0.5,
      percentile: 69.15,
      chapters_tested: 7,
      status: "tested"
    }
  },
  
  // Subject-level accuracy (percentage)
  subject_accuracy: {
    physics: { accuracy: 65, correct: 13, total: 20 },    // 65% accuracy
    chemistry: { accuracy: 55, correct: 11, total: 20 },
    mathematics: { accuracy: 70, correct: 14, total: 20 }
  },
  
  // ========================================
  // OVERALL METRICS
  // ========================================
  overall_theta: 0.2,
  overall_percentile: 57.93,
  
  // ========================================
  // DAILY QUIZ STATE
  // ========================================
  completed_quiz_count: 8,              // PRIMARY: Used for phase transition
  current_day: 5,                       // Days since assessment (analytics)
  learning_phase: "exploration",        // "exploration" | "exploitation"
  phase_switched_at_quiz: null,          // Will be 14 when switching
  assessment_completed_at: "2024-12-03T09:00:00Z",
  last_quiz_completed_at: "2024-12-10T13:45:00Z",
  
  // Chapter attempt counts (for exploration tracking)
  chapter_attempt_counts: {
    "physics_electrostatics": 12,
    "chemistry_organic": 5,
    // ... all chapters
  },
  
  // Coverage metrics
  chapters_explored: 28,                 // Chapters with ≥1 attempt
  chapters_confident: 15,                // Chapters with ≥2 attempts
  
  // Subject balance (for exploration prioritization)
  subject_balance: {
    physics: 0.35,      // 35% of questions
    chemistry: 0.30,     // 30%
    mathematics: 0.35   // 35%
  },
  
  // Progress tracking
  total_questions_solved: 110,           // Cumulative (includes assessment)
  total_time_spent_minutes: 2340,        // Cumulative
  quizzes_per_day_avg: 1.6,              // Analytics
  
  // Circuit breaker state
  circuit_breaker_active: false,
  consecutive_failures: 0,
  last_circuit_breaker_trigger: null
}
```

**Indexes:**
- None required (single document per user, accessed by document ID)

---

### 2. `initial_assessment_questions/{questionId}` - Initial Assessment Questions

**Purpose:** 30 pre-selected questions for initial assessment.

**Document Structure:**
```javascript
{
  question_id: "ASSESS_PHY_MECH_001",
  subject: "Physics",
  chapter: "Laws of Motion",
  // ... (same structure as questions collection, see below)
}
```

**Note:** These are a subset of questions, stored separately for assessment flow.

---

### 3. `questions/{questionId}` - Daily Quiz Question Bank

**Purpose:** Complete question bank for daily adaptive quizzes (~8000 questions).

**Document Structure:**
```javascript
{
  question_id: "PHY_ELEC_E_001",
  subject: "Physics",
  chapter: "Electrostatics",
  topic: "physics_electrostatics_coulomb", // For metadata, not theta tracking
  unit: "Unit 2",
  sub_topics: ["Coulomb's Law", "Point Charges"],
  
  // IRT Parameters (CRITICAL for algorithm)
  difficulty_irt: 0.45,                    // Legacy field (matches difficulty_b)
  irt_parameters: {
    difficulty_b: 0.45,                     // [-3, +3] scale
    discrimination_a: 1.5,                  // Higher = better question
    guessing_c: 0.25                       // MCQ: 0.25, Numerical: 0.0
  },
  
  // Question content
  question_type: "numerical" | "mcq_single",
  question_text: "Two point charges of +3 μC and +5 μC...",
  question_text_html: "Two point charges of +3 μC and +5 μC...",
  question_latex: null,
  options: [...],                          // For MCQ
  correct_answer: "0.03375",
  correct_answer_text: "0.03375 N",
  correct_answer_exact: "135/4000",
  correct_answer_unit: "N",
  answer_type: "decimal",
  answer_range: {                          // For numerical questions
    min: 0.0336,
    max: 0.0339
  },
  
  // Solution
  solution_steps: [
    {
      step_number: 1,
      description: "Apply Coulomb's law...",
      formula: "F = k|q₁q₂|/r²",
      calculation: null,
      explanation: "...",
      result: "Formula established"
    }
  ],
  solution_text: "Using formula for magnetic field...",
  concepts_tested: ["Coulomb's Law", "Electrostatic Force"],
  
  // Metadata
  difficulty: "easy" | "medium" | "hard",
  priority: "HIGH" | "MEDIUM" | "LOW",
  time_estimate: 75,                       // Seconds
  weightage_marks: 4,
  jee_year_similar: "2023",
  jee_pattern: "Direct application of Coulomb's law",
  tags: ["coulombs-law", "point-charges"],
  
  // Usage stats (updated after each use)
  usage_stats: {
    times_shown: 45,
    times_correct: 28,
    times_incorrect: 17,
    avg_time_taken: 135,
    accuracy_rate: 0.622,
    last_shown: "2024-12-10T14:22:15Z"
  },
  
  // Image metadata (if applicable)
  has_image: true,
  image_url: "https://storage.googleapis.com/...",
  image_type: "charge_diagram",
  image_description: "...",
  image_alt_text: "...",
  
  // Creation metadata
  created_date: "2024-12-09T00:00:00Z",
  created_by: "claude_ai",
  validation_status: "pending" | "validated" | "rejected",
  validated_by: null,
  validation_date: null
}
```

**Firestore Indexes Required:**
```
Collection: questions
- subject (Ascending) + chapter (Ascending) + irt_parameters.difficulty_b (Ascending)
- subject (Ascending) + chapter (Ascending) + irt_parameters.discrimination_a (Descending)
- subject (Ascending) + chapter (Ascending) + question_id (Ascending)
```

---

### 4. `assessment_responses/{userId}/responses/{responseId}` - Initial Assessment Responses

**Purpose:** Individual responses from initial assessment (30 questions).

**Document Structure:**
```javascript
{
  response_id: "resp_abc123_xyz789",
  student_id: "user123",
  question_id: "ASSESS_PHY_MECH_001",
  
  // Chapter-level metadata (denormalized)
  subject: "Physics",
  chapter: "Laws of Motion",
  chapter_key: "physics_laws_of_motion",
  
  // Response details
  student_answer: "A",
  correct_answer: "A",
  is_correct: true,
  time_taken_seconds: 95,
  
  // Timestamps
  answered_at: Timestamp,
  created_at: Timestamp
}
```

**Firestore Indexes:**
```
Collection Group: assessment_responses/{userId}/responses
- student_id (Ascending) + answered_at (Descending)
- student_id (Ascending) + chapter_key (Ascending) + answered_at (Descending)
```

---

### 5. `daily_quiz_responses/{userId}/responses/{responseId}` - Daily Quiz Responses

**Purpose:** Individual responses from daily quizzes (10 questions per quiz).

**Document Structure:**
```javascript
{
  response_id: "resp_xyz789",
  student_id: "user123",
  question_id: "PHY_ELEC_E_001",
  
  // Chapter-level metadata (denormalized)
  subject: "Physics",
  chapter: "Electrostatics",
  chapter_key: "physics_electrostatics",
  
  // Question metadata (denormalized for analytics)
  difficulty_b: 0.45,
  discrimination_a: 1.5,
  guessing_c: 0.25,
  
  // Response details
  student_answer: "0.03375",
  correct_answer: "0.03375",
  is_correct: true,
  time_taken_seconds: 142,
  
  // IRT state at time of attempt
  theta_before: 0.35,
  theta_after: 0.42,
  theta_delta: 0.07,
  confidence_SE_before: 0.30,
  confidence_SE_after: 0.285,
  
  // Quiz context
  quiz_id: "quiz_8_2024-12-10",
  quiz_number: 8,
  question_position: 4,                  // 4th question in quiz
  learning_phase: "exploration",
  selection_reason: "exploration" | "deliberate_practice" | "maintenance" | "review",
  
  // Timestamps
  answered_at: Timestamp,
  created_at: Timestamp
}
```

**Firestore Indexes:**
```
Collection Group: daily_quiz_responses/{userId}/responses
- student_id (Ascending) + answered_at (Descending)
- student_id (Ascending) + chapter_key (Ascending) + answered_at (Descending)
- student_id (Ascending) + is_correct (Ascending) + answered_at (Descending)
- student_id (Ascending) + quiz_id (Ascending) + question_position (Ascending)
```

---

### 6. `daily_quizzes/{userId}/quizzes/{quizId}` - Daily Quiz History

**Purpose:** Complete quiz records for analytics and progress tracking.

**Document Structure:**
```javascript
{
  quiz_id: "quiz_8_2024-12-10",
  student_id: "user123",
  
  // Quiz metadata
  quiz_number: 8,                        // 8th quiz completed (0-indexed internally)
  current_day: 5,                        // Day 5 since assessment (analytics)
  learning_phase: "exploration",
  generated_at: "2024-12-10T14:00:00Z",
  started_at: "2024-12-10T14:05:00Z",
  completed_at: "2024-12-10T14:35:20Z",
  total_time_seconds: 2120,
  status: "completed" | "in_progress" | "abandoned",
  
  // Questions in quiz (summary)
  questions: [
    {
      question_id: "PHY_ELEC_E_001",
      chapter_key: "physics_electrostatics",
      difficulty_b: 0.45,
      position: 1,
      selection_reason: "exploration",
      is_correct: true,
      time_taken_seconds: 95,
      student_answer: "0.03375",
      correct_answer: "0.03375"
    },
    // ... 9 more questions
  ],
  
  // Performance summary
  score: 7,                               // Out of 10
  accuracy: 0.70,
  avg_time_per_question: 212,
  
  // Chapter distribution
  chapters_covered: [
    "physics_electrostatics",
    "chemistry_organic",
    "mathematics_calculus"
  ],
  
  // Phase-specific metadata
  exploration_questions: 5,
  deliberate_practice_questions: 4,
  review_questions: 1,
  
  // Circuit breaker
  is_recovery_quiz: false,
  circuit_breaker_triggered: false
}
```

**Firestore Indexes:**
```
Collection Group: daily_quizzes/{userId}/quizzes
- student_id (Ascending) + quiz_number (Descending)
- student_id (Ascending) + completed_at (Descending)
- student_id (Ascending) + learning_phase (Ascending) + completed_at (Descending)
```

---

### 7. `theta_history/{userId}/snapshots/{snapshotId}` - Weekly Theta Snapshots

**Purpose:** Historical snapshots of theta values for trend analysis and progress visualization.

**Document Structure:**
```javascript
{
  snapshot_id: "snapshot_week_2024-12-10",
  student_id: "user123",
  snapshot_type: "weekly",
  
  // Week information
  week_start: "2024-12-04",              // Monday (YYYY-MM-DD)
  week_end: "2024-12-10",                // Sunday (YYYY-MM-DD)
  week_number: 2,                         // Week number since assessment
  quiz_count: 7,                          // Quizzes completed this week
  
  // Theta state at end of week (snapshot)
  theta_by_chapter: {
    "physics_electrostatics": {
      theta: 0.5,
      percentile: 69.15,
      confidence_SE: 0.25,
      attempts: 12,
      accuracy: 0.67,
      last_updated: "2024-12-10T14:30:00Z"
    },
    // ... all chapters
  },
  theta_by_subject: {
    physics: { theta: 0.2, percentile: 57.93 },
    chemistry: { theta: -0.3, percentile: 38.21 },
    mathematics: { theta: 0.5, percentile: 69.15 }
  },
  overall_theta: 0.2,
  overall_percentile: 57.93,
  
  // Changes from previous week
  changes_from_previous: {
    chapters_improved: 3,
    chapters_declined: 1,
    chapters_new: 2,
    overall_theta_delta: 0.1,
    overall_percentile_delta: 4.5,
    chapter_changes: {
      "physics_electrostatics": {
        theta_delta: 0.2,
        percentile_delta: 7.3,
        status: "improved"
      }
    }
  },
  
  // Week summary statistics
  week_summary: {
    questions_answered: 70,
    accuracy: 0.71,
    time_spent_minutes: 245,
    chapters_explored: 8,
    chapters_new: 2,
    chapters_improved: 3,
    chapters_reached_confident: 1
  },
  
  // Timestamp
  captured_at: "2024-12-10T23:59:59Z"     // End of week
}
```

**Firestore Indexes:**
```
Collection Group: theta_history/{userId}/snapshots
- student_id (Ascending) + week_end (Descending)
- student_id (Ascending) + week_number (Ascending)
```

---

### 8. `practice_streaks/{userId}` - Practice Streaks & Usage Analytics

**Purpose:** Track practice streaks, weekly patterns, and cumulative statistics.

**Document Structure:**
```javascript
{
  student_id: "user123",
  
  // Current streak
  current_streak: 5,                     // Consecutive days
  longest_streak: 12,
  last_practice_date: "2024-12-10",      // YYYY-MM-DD format
  
  // Weekly practice pattern (last 7 days)
  practice_days: {
    "2024-12-04": {
      quizzes: 1,
      questions: 10,
      accuracy: 0.70,
      time_spent_minutes: 35
    },
    "2024-12-05": {
      quizzes: 1,
      questions: 10,
      accuracy: 0.80,
      time_spent_minutes: 28
    },
    "2024-12-06": {
      quizzes: 0,
      questions: 0,
      accuracy: null,                    // Missed day
      time_spent_minutes: 0
    },
    // ... 4 more days
  },
  
  // Cumulative stats
  total_days_practiced: 45,
  total_quizzes_completed: 67,
  total_questions_answered: 670,
  total_time_spent_minutes: 2340,
  
  // Week-over-week progress (last 4 weeks)
  weekly_stats: [
    {
      week_start: "2024-12-04",          // Monday of week
      week_end: "2024-12-10",            // Sunday of week
      questions_answered: 70,
      accuracy: 0.71,
      chapters_improved: 3,               // Chapters with theta increase
      quizzes_completed: 7
    }
    // ... 3 more weeks
  ],
  
  // Day-of-week pattern (for analytics)
  day_of_week_pattern: {
    monday: { practiced: true, avg_accuracy: 0.72 },
    tuesday: { practiced: true, avg_accuracy: 0.68 },
    wednesday: { practiced: false, avg_accuracy: null },
    thursday: { practiced: true, avg_accuracy: 0.75 },
    friday: { practiced: true, avg_accuracy: 0.70 },
    saturday: { practiced: true, avg_accuracy: 0.65 },
    sunday: { practiced: false, avg_accuracy: null }
  },
  
  // Last updated
  last_updated: Timestamp
}
```

**Indexes:**
- None required (single document per user, accessed by document ID)

---

## Data Relationships

```
users/{userId}
  ├── References: assessment_responses/{userId}/responses/{responseId}
  ├── References: daily_quiz_responses/{userId}/responses/{responseId}
  ├── References: daily_quizzes/{userId}/quizzes/{quizId}
  ├── References: theta_history/{userId}/snapshots/{snapshotId}
  └── References: practice_streaks/{userId}

questions/{questionId}
  ├── Referenced by: assessment_responses (via question_id)
  └── Referenced by: daily_quiz_responses (via question_id)

initial_assessment_questions/{questionId}
  └── Referenced by: assessment_responses (via question_id)
```

---

## Key Design Decisions

### 1. **Single User Document**
- All user state in one document for atomic updates
- Fast reads (single document fetch)
- Firestore document size limit: 1MB (sufficient for our use case)

### 2. **Subcollections for Responses**
- `assessment_responses/{userId}/responses/{responseId}` - Scales per user
- `daily_quiz_responses/{userId}/responses/{responseId}` - Scales per user
- Allows efficient querying by user without affecting other users

### 3. **Denormalized Data**
- Chapter metadata stored in responses (faster queries)
- Question IRT parameters stored in responses (analytics)
- Trade-off: Slightly more storage, much faster queries

### 4. **Separate Question Banks**
- `initial_assessment_questions` - 30 pre-selected questions
- `questions` - Full question bank (8000 questions)
- Allows different validation/update cycles

### 5. **Chapter-Level Theta (Not Topic-Level)**
- Simplified tracking: `physics_electrostatics` instead of `physics_electrostatics_coulomb`
- Sufficient granularity for JEE preparation
- Easier to understand and maintain

---

## Migration Notes

### Existing Data Compatibility
- Current `users` collection already has `theta_by_chapter`, `theta_by_subject`, `completed_quiz_count`, etc.
- **No migration needed** - new fields will be added via merge operations

### New Collections
- `questions` - New collection (import from JSON files)
- `daily_quiz_responses` - New subcollection structure
- `daily_quizzes` - New subcollection structure
- `practice_streaks` - New collection

### Backward Compatibility
- Assessment flow remains unchanged
- Existing assessment data structure preserved
- Daily quiz is additive feature

---

## Security Rules

All collections use backend-only access (no direct client access):
```javascript
match /{document=**} {
  allow read, write: if false;  // All access via backend API
}
```

---

## Performance Considerations

### Read Patterns
- **User Profile:** Single document read (fast)
- **Quiz Generation:** Query questions by subject+chapter (indexed)
- **Progress Analytics:** Query responses by date range (indexed)

### Write Patterns
- **Quiz Completion:** Batch write (10 responses + 1 quiz document)
- **Theta Updates:** Single user document update (atomic)
- **Streak Updates:** Single document update (atomic)

### Scalability
- **Per-User Subcollections:** Scales linearly with user count
- **Question Bank:** Single collection with indexes (efficient queries)
- **User Document:** Size remains manageable (< 100KB per user)

---

## Index Summary

**Total Indexes Required:**
1. `questions`: 3 composite indexes
2. `assessment_responses`: 2 collection group indexes
3. `daily_quiz_responses`: 4 collection group indexes
4. `daily_quizzes`: 3 collection group indexes
5. `theta_history`: 2 collection group indexes

**Total: 14 indexes** (all composite/collection group indexes)

**See `docs/FIRESTORE_INDEXES_COMPLETE.md` for complete index definitions.**

---

## Next Steps

1. Create Firestore indexes via Firebase Console or `firebase.json`
2. Import question bank via import script
3. Update backend services to use new collections
4. Test with sample data
5. Monitor performance and adjust indexes as needed

