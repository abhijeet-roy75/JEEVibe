# Full Mock Tests Feature - Implementation Plan

## Overview

Implement full-length mock tests that simulate JEE Main (3 hours, 90 questions) and JEE Advanced (6 hours, 96 questions) exam conditions. The feature will leverage JEEVibe's existing IRT-based adaptive learning while providing realistic exam simulation.

## Prerequisites & Sequencing

**Important**: This feature should be implemented AFTER the question bank reload is complete.

**Rationale**:
- Mock test question pool mirrors the `questions` collection schema
- Validation pipeline compares against the main question bank
- IRT parameters may be recalibrated in the new bank

**Implementation Order**:
1. Complete question bank reload (in progress)
2. Implement mock test backend services
3. Generate mock test question pool (uses new schema)
4. Implement mobile UI (reuses existing components)
5. Add test history feature (benefits all quiz types)

## Key Differentiators

1. **Hybrid Question Strategy**: Pre-generated question pools with Claude AI, combined with on-the-fly IRT-based selection for personalization
2. **Adaptive Difficulty**: Questions calibrated to student's current ability (theta) while maintaining realistic exam distribution
3. **Personalized Analysis**: Post-test analysis uses IRT insights to identify specific weak areas and recommend targeted practice
4. **Smart Question Selection**: Balance between realistic exam pattern and personalized difficulty using IRT parameters
5. **Offline-First Design**: Local storage ensures test continuity even with network issues
6. **Full Review Mode**: Review all 90 questions with detailed explanations post-test

## Exam Format Specifications

### JEE Main Mock Test

- **Duration**: 3 hours (10,800 seconds)
- **Total Questions**: 90 displayed, 75 to attempt
- **Subject Distribution**:
  - Physics: 30 questions (20 MCQ + 10 NVQ) → attempt 25 (20 MCQ + 5 NVQ)
  - Chemistry: 30 questions (20 MCQ + 10 NVQ) → attempt 25 (20 MCQ + 5 NVQ)
  - Mathematics: 30 questions (20 MCQ + 10 NVQ) → attempt 25 (20 MCQ + 5 NVQ)
- **Marking Scheme**:
  - Correct: +4 marks
  - Incorrect: -1 mark
  - Unattempted: 0 marks
- **Max Score**: 300 marks (75 × 4)

### JEE Advanced Mock Test

- **Duration**: 6 hours total (2 papers × 3 hours each)
- **Paper 1**: 48 questions (16 per subject)
- **Paper 2**: 48 questions (16 per subject)
- **Total Questions**: 96 questions
- **Question Types**: Mix of single-correct MCQ, multi-correct MCQ, numerical, integer, matching
- **Marking Scheme**: Variable (partial marking, negative marking in some sections)
- **Max Score**: 360 marks (180 per paper)

## Architecture Components

### 1. Backend Services

#### 1.1 Mock Test Question Pool Service (NEW)

**File**: `backend/src/services/mockTestQuestionPoolService.js`

**Responsibilities**:

- Manage pre-generated question pool in Firestore
- Generate new questions via Claude AI (batch process)
- Validate and calibrate IRT parameters for generated questions
- Track question usage and retire overused questions

**Key Functions**:

```javascript
async function generateQuestionBatch(subject, chapter, count, difficulty)
async function validateGeneratedQuestion(question) // Multi-stage validation
async function calibrateIRTParameters(question, difficulty, questionType)
async function getAvailableQuestions(subject, chapter, filters)
async function retireOverusedQuestions(usageThreshold)
async function refreshQuestionPool() // Weekly batch job
```

##### When Does Generation Run?

| Trigger | When | What |
|---------|------|------|
| **Initial Population** | Manual, before feature launch | Generate 900 questions (300/subject) |
| **Weekly Refresh** | Every Sunday 2:00 AM IST (cron) | Add 50 new questions, retire overused |
| **On-Demand** | Manual via admin endpoint | Generate for specific chapter if pool < 10 |
| **Emergency** | Automatic if pool drops below threshold | Generate 20 questions for depleted chapter |

**Batch Job Script**: `backend/scripts/generateMockTestQuestionPool.js`

```javascript
// Cron schedule: 0 2 * * 0 (Sunday 2 AM IST)
// Can also run manually: node scripts/generateMockTestQuestionPool.js --initial
// Or for specific subject: node scripts/generateMockTestQuestionPool.js --subject Physics --count 50
```

##### Multi-Stage Validation Pipeline

Every AI-generated question passes through 5 validation stages before entering the pool:

```
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 1: SCHEMA VALIDATION                                      │
├─────────────────────────────────────────────────────────────────┤
│  ✓ All required fields present (matches existing question bank) │
│  ✓ subject ∈ ['Physics', 'Chemistry', 'Mathematics']            │
│  ✓ question_type ∈ ['mcq_single', 'numerical']                  │
│  ✓ MCQ has exactly 4 options (A, B, C, D)                       │
│  ✓ Numerical has answer_range {min, max} or correct_answer_exact│
│  ✓ chapter_key follows format: {subject}_{chapter} lowercase    │
│  Reject if: Missing required fields                              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 2: LATEX VALIDATION (uses existing latex-validator.js)   │
├─────────────────────────────────────────────────────────────────┤
│  ✓ Run validateAndNormalizeLaTeX() on question_text             │
│  ✓ Run on all option texts                                       │
│  ✓ Run on solution text                                          │
│  ✓ Fix common AI errors (\\( → \(, missing backslashes)         │
│  ✓ Balance delimiters                                            │
│  ✓ Remove nested delimiters                                      │
│  Reject if: LaTeX cannot be normalized after 10 iterations       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 3: CONTENT QUALITY CHECK (Claude Haiku - fast/cheap)     │
├─────────────────────────────────────────────────────────────────┤
│  Prompt: "Review this JEE question for quality issues..."        │
│  ✓ Question is clear and unambiguous                             │
│  ✓ All options are plausible (no obviously wrong distractors)   │
│  ✓ Correct answer is actually correct                            │
│  ✓ Difficulty matches claimed level                              │
│  ✓ No factual errors in physics/chemistry/math                  │
│  ✓ Appropriate for JEE Main/Advanced level                       │
│  Returns: { valid: boolean, issues: string[], confidence: 0-1 } │
│  Reject if: valid=false OR confidence < 0.8                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 4: ANSWER VERIFICATION (Claude Haiku)                     │
├─────────────────────────────────────────────────────────────────┤
│  Prompt: "Solve this question step-by-step, what's the answer?" │
│  ✓ AI solves the question independently                          │
│  ✓ Compare AI answer with provided correct_answer                │
│  ✓ For numerical: check if within answer_range                   │
│  ✓ For MCQ: exact match required                                 │
│  Reject if: AI answer ≠ provided answer                          │
│  Flag for manual review if: AI uncertain (hedging language)      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 5: UNIQUENESS CHECK                                       │
├─────────────────────────────────────────────────────────────────┤
│  ✓ Compute text similarity with existing pool questions          │
│  ✓ Check against daily quiz question bank (questions collection)│
│  ✓ Use simple Jaccard similarity on tokenized text               │
│  Reject if: Similarity > 0.7 with any existing question          │
│  Log: Similar questions for manual review                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ✅ ADD TO POOL
```

**Validation Statistics Tracking**:

```javascript
// Logged after each batch generation
{
  batch_id: "batch_2025_01_21_abc",
  generated_count: 50,
  stage1_passed: 48,  // Schema validation
  stage2_passed: 47,  // LaTeX validation
  stage3_passed: 42,  // Quality check
  stage4_passed: 40,  // Answer verification
  stage5_passed: 38,  // Uniqueness check
  final_added: 38,
  rejection_reasons: {
    "missing_options": 2,
    "latex_error": 1,
    "quality_low_confidence": 5,
    "wrong_answer": 2,
    "too_similar": 2
  }
}
```

##### Question Pool Schema (Aligned with Existing Question Bank)

```javascript
// Collection: mock_test_question_pool/{questionId}
// Schema matches existing `questions` collection for consistency
{
  // Identifiers (same as questions collection)
  question_id: "MOCK_PHY_MECH_001",

  // Classification (same as questions collection)
  subject: "Physics",
  chapter: "Mechanics",
  chapter_key: "physics_mechanics", // Computed: {subject}_{chapter} lowercase
  unit: "Unit 3",
  sub_topics: ["Newton's Laws", "Free Body Diagrams"],

  // Question type (same as questions collection)
  question_type: "mcq_single" | "numerical",
  difficulty: "easy" | "medium" | "hard",

  // IRT Parameters (same structure as questions collection)
  irt_parameters: {
    difficulty_b: 0.5,           // Range: [-3, +3], JEEVibe uses [0.4, 2.6]
    discrimination_a: 1.5,       // Range: [1.0, 2.0], default 1.5
    guessing_c: 0.25,            // 0.25 for MCQ, 0.0 for numerical
    calibration_status: "estimated" | "calibrated",
    calibration_method: "rule_based" | "ai_estimated",
    calibration_sample_size: 0,
    last_calibration: Timestamp | null
  },
  difficulty_irt: 0.5, // Legacy field for backwards compatibility

  // Question Content (same as questions collection)
  question_text: "A block of mass 5 kg...",
  question_text_html: "<p>A block of mass 5 kg...</p>",
  question_latex: "\\( F = ma \\)",
  options: [  // Array format (same as questions collection)
    { option_id: "A", text: "10 N", html: "<p>10 N</p>" },
    { option_id: "B", text: "20 N", html: "<p>20 N</p>" },
    { option_id: "C", text: "30 N", html: "<p>30 N</p>" },
    { option_id: "D", text: "40 N", html: "<p>40 N</p>" }
  ],

  // Answer (same as questions collection)
  correct_answer: "B",
  correct_answer_text: "20 N",
  correct_answer_exact: 20,      // For numerical
  correct_answer_unit: "N",      // For numerical
  answer_type: "single_choice" | "decimal" | "integer",
  answer_range: { min: 19.5, max: 20.5 }, // For numerical tolerance
  alternate_correct_answers: [],

  // Solution (same as questions collection)
  solution_text: "Using F = ma, F = 5 × 4 = 20 N",
  solution_steps: [
    { step_number: 1, description: "Identify given values", formula: "m = 5 kg, a = 4 m/s²", explanation: "..." },
    { step_number: 2, description: "Apply Newton's second law", formula: "F = ma = 5 × 4 = 20 N", explanation: "..." }
  ],
  concepts_tested: ["Newton's second law", "Force calculation"],

  // Usage Statistics (same as questions collection)
  usage_stats: {
    times_presented: 0,
    times_correct: 0,
    times_incorrect: 0,
    avg_time_seconds: null,
    last_updated: Timestamp
  },

  // Mock Test Specific Fields (NEW)
  mock_test_metadata: {
    generated_by: "claude-sonnet-4-20250514",
    generated_at: Timestamp,
    validation_passed_at: Timestamp,
    validation_stages_passed: ["schema", "latex", "quality", "answer", "uniqueness"],
    quality_confidence: 0.92,
    usage_count: 0,           // Times used in mock tests
    last_used_at: Timestamp | null,
    retired: false,
    retirement_reason: null,  // "overused" | "quality_issue" | "outdated"
    jee_main_suitable: true,
    jee_advanced_suitable: true
  },

  // Audit (same as questions collection)
  created_at: Timestamp,
  updated_at: Timestamp,
  created_by: "system:batch_generator",
  validation_status: "approved" | "pending_review" | "rejected",
  validation_notes: ""
}

#### 1.2 Mock Test Generation Service

**File**: `backend/src/services/mockTestService.js`

**Responsibilities**:

- Generate mock test by selecting from question pool
- Balance realistic exam distribution with adaptive difficulty
- Select questions using IRT parameters while maintaining subject/chapter distribution
- Handle question type distribution (MCQ vs NVQ)

**Key Functions**:

```javascript
async function generateMockTest(userId, examType, difficultyLevel)
async function selectQuestionsForMockTest(examType, subjectDistribution, thetaByChapter)
async function validateMockTestPattern(questions, examType)
```

**Question Selection Strategy**:

- Use existing `questionSelectionService.js` patterns but query from `mock_test_question_pool`:
  - Subject distribution: 33.3% each (Physics, Chemistry, Math)
  - Question type distribution: 66.7% MCQ, 33.3% NVQ (for JEE Main)
  - Chapter distribution: Weighted by JEE exam frequency (use existing chapter weights)
  - Difficulty range: ±1.0 SD from student's average theta (wider than daily quiz ±0.5)
  - Ensure no duplicate questions from recent mock tests (60-day lookback)

##### IRT Parameter Calibration for AI-Generated Questions

Since AI-generated questions don't have historical response data, we use rule-based calibration:

```javascript
function calibrateIRTParameters(question, requestedDifficulty, questionType) {
  // Difficulty (b) - based on requested difficulty tier
  const difficultyMap = {
    easy:   { b: 0.5,  range: [0.4, 0.7] },   // JEEVibe easy range
    medium: { b: 1.0,  range: [0.8, 1.3] },   // JEEVibe medium range
    hard:   { b: 1.8,  range: [1.4, 2.6] }    // JEEVibe hard range
  };

  // Add slight randomization within range for variety
  const { b: baseB, range } = difficultyMap[requestedDifficulty];
  const difficulty_b = baseB + (Math.random() - 0.5) * (range[1] - range[0]);

  // Discrimination (a) - default 1.5, adjust based on question characteristics
  // Higher for questions with clear right/wrong (calculations)
  // Lower for conceptual questions with plausible distractors
  const discrimination_a = questionType === 'numerical' ? 1.6 : 1.4;

  // Guessing (c) - fixed based on question type
  const guessing_c = questionType === 'mcq_single' ? 0.25 : 0.0;

  return {
    difficulty_b: Math.max(0.4, Math.min(2.6, difficulty_b)), // Clamp to JEEVibe range
    discrimination_a,
    guessing_c,
    calibration_status: 'estimated',
    calibration_method: 'ai_rule_based',
    calibration_sample_size: 0,
    last_calibration: null
  };
}
```

**Post-Usage Calibration** (Future Enhancement):

After questions accumulate response data (100+ responses), recalibrate using actual performance:

```javascript
// Run monthly to update IRT parameters based on real response data
async function recalibrateFromResponses(questionId) {
  const responses = await getQuestionResponses(questionId);
  if (responses.length < 100) return; // Not enough data

  // Calculate actual difficulty from response accuracy
  const accuracy = responses.filter(r => r.is_correct).length / responses.length;
  const new_difficulty_b = -Math.log(accuracy / (1 - accuracy)); // Simple logit transform

  // Update calibration
  await updateQuestionIRT(questionId, {
    difficulty_b: new_difficulty_b,
    calibration_status: 'calibrated',
    calibration_method: 'response_based',
    calibration_sample_size: responses.length,
    last_calibration: new Date()
  });
}
```

#### 1.3 Mock Test Response Service

**File**: `backend/src/services/mockTestResponseService.js`

**Responsibilities**:

- Handle mock test submission
- Calculate scores with negative marking
- Generate comprehensive analytics
- Update user theta estimates based on performance

**Key Functions**:

```javascript
async function submitMockTest(userId, mockTestId, responses)
async function calculateMockTestScore(responses, examType)
async function generateMockTestAnalytics(userId, mockTestId)
async function updateThetaFromMockTest(userId, responses)
```

#### 1.4 Mock Test Analytics Service

**File**: `backend/src/services/mockTestAnalyticsService.js`

**Responsibilities**:

- Generate detailed performance reports
- Compare against previous attempts
- Provide percentile rankings (if enough data)
- Identify weak chapters/concepts
- Recommend next steps

**Key Functions**:

```javascript
async function generatePerformanceReport(userId, mockTestId)
async function calculatePercentile(userId, mockTestId, examType)
async function identifyWeakAreas(responses, thetaByChapter)
async function generateRecommendations(userId, mockTestId)
```

### 2. Database Schema

#### 2.1 Mock Tests Collection

**Path**: `mock_tests/{userId}/tests/{mockTestId}`

**Document Structure**:

```javascript
{
  mock_test_id: "mock_main_2025_01_15_abc123",
  user_id: "user123",
  exam_type: "jee_main" | "jee_advanced",
  status: "not_started" | "in_progress" | "completed" | "abandoned",

  // Timing
  started_at: Timestamp | null,
  completed_at: Timestamp | null,
  time_taken_seconds: number | null,
  paused_duration_seconds: number, // Total time paused
  pauses_used: number, // Track pause count

  // Questions (embedded for quick access)
  questions: [
    {
      question_id: "PHY_MOCK_001",
      position: 1,
      subject: "Physics",
      chapter: "Mechanics",
      chapter_key: "physics_mechanics",
      question_type: "mcq_single" | "numerical",
      question_text: "...",
      options: [...], // For MCQ
      correct_answer: "...",
      irt_parameters: { a, b, c },
      selection_theta: 0.5, // Student's theta when selected
    }
  ],

  // Responses (after submission)
  responses: [
    {
      question_id: "...",
      student_answer: "A",
      is_correct: true,
      time_taken_seconds: 120,
      answered_at: Timestamp
    }
  ],

  // Scoring
  total_marks: 300,
  obtained_marks: 245,
  correct_count: 62,
  incorrect_count: 8,
  unattempted_count: 5,
  accuracy: 0.886,

  // Analytics (computed after submission)
  subject_wise_scores: {
    physics: { marks: 85, correct: 21, incorrect: 3, unattempted: 1 },
    chemistry: { marks: 80, correct: 20, incorrect: 4, unattempted: 1 },
    mathematics: { marks: 80, correct: 20, incorrect: 1, unattempted: 4 }
  },

  chapter_wise_performance: {
    "physics_mechanics": { correct: 5, incorrect: 1, accuracy: 0.833 },
    // ... other chapters
  },

  // Metadata
  created_at: Timestamp,
  tier_at_attempt: "pro", // User's tier when they started
  version: "1.0" // For future schema migrations
}
```

#### 2.2 Mock Test Usage Tracking

**Path**: `users/{userId}` (add to existing document)

**New Fields**:

```javascript
{
  mock_test_usage: {
    jee_main: {
      attempts_this_month: 2,
      last_attempt_date: "2025-01-15",
      total_attempts: 5,
      best_score: 285,
      best_percentile: 78
    },
    jee_advanced: {
      attempts_this_month: 0,
      last_attempt_date: null,
      total_attempts: 0,
      best_score: null,
      best_percentile: null
    }
  },
  mock_test_limits: {
    jee_main: {
      monthly_limit: 5, // Based on tier
      remaining_this_month: 3
    },
    jee_advanced: {
      monthly_limit: 5,
      remaining_this_month: 5
    }
  }
}
```

#### 2.3 Mock Test Responses (Individual)

**Path**: `mock_test_responses/{userId}/responses/{responseId}`

**Document Structure** (similar to `daily_quiz_responses`):

```javascript
{
  response_id: "resp_mock_abc123_q001",
  user_id: "user123",
  mock_test_id: "mock_main_2025_01_15_abc123",
  question_id: "PHY_MOCK_001",

  // Question context
  subject: "Physics",
  chapter: "Mechanics",
  chapter_key: "physics_mechanics",
  question_type: "mcq_single",

  // Response
  student_answer: "A",
  correct_answer: "A",
  is_correct: true,
  time_taken_seconds: 120,

  // Scoring
  marks_awarded: 4,
  marks_deducted: 0,

  // IRT context
  theta_before: 0.5,
  theta_after: 0.52,
  irt_parameters: { a: 1.5, b: 0.3, c: 0.25 },

  // Timestamps
  answered_at: Timestamp,
  created_at: Timestamp
}
```

### 3. API Endpoints

#### 3.1 Generate Mock Test

**Endpoint**: `POST /api/mock-tests/generate`

**Request**:

```javascript
{
  exam_type: "jee_main" | "jee_advanced",
  difficulty_level?: "easy" | "medium" | "hard" | "adaptive" // Default: adaptive
}
```

**Response**:

```javascript
{
  mock_test_id: "mock_main_2025_01_15_abc123",
  exam_type: "jee_main",
  questions: [
    // Questions without answers (same format as daily quiz)
  ],
  total_questions: 90,
  duration_seconds: 10800,
  started_at: "2025-01-15T10:00:00Z"
}
```

#### 3.2 Get Active Mock Test

**Endpoint**: `GET /api/mock-tests/active`

**Response**: Returns in-progress mock test if exists, null otherwise

#### 3.3 Submit Mock Test

**Endpoint**: `POST /api/mock-tests/{mockTestId}/submit`

**Request**:

```javascript
{
  responses: [
    {
      question_id: "PHY_MOCK_001",
      student_answer: "A",
      time_taken_seconds: 120
    }
    // ... all 75-90 responses
  ],
  completed_at: "2025-01-15T13:00:00Z"
}
```

**Response**:

```javascript
{
  mock_test_id: "mock_main_2025_01_15_abc123",
  total_marks: 300,
  obtained_marks: 245,
  correct_count: 62,
  incorrect_count: 8,
  unattempted_count: 5,
  accuracy: 0.886,
  percentile: 72, // If enough data available
  subject_wise_scores: { ... },
  chapter_wise_performance: { ... },
  weak_areas: [ ... ],
  recommendations: [ ... ]
}
```

#### 3.4 Get Mock Test Analytics

**Endpoint**: `GET /api/mock-tests/{mockTestId}/analytics`

**Response**: Detailed performance report with charts data

#### 3.5 Get Mock Test History

**Endpoint**: `GET /api/mock-tests/history`

**Query Params**: `exam_type?`, `limit?`, `offset?`

**Response**: List of completed mock tests with summary scores

### 4. Mobile App Implementation

#### 4.1 Component Reuse Strategy

**Critical**: Maximize reuse to maintain consistency and reduce development time. Also prepares architecture for future PYQ (Previous Year Questions) feature.

| Existing Component | File Path | Reuse Level | Modifications |
|-------------------|-----------|-------------|---------------|
| **QuestionCardWidget** | `widgets/daily_quiz/question_card_widget.dart` | 100% | None needed |
| **DetailedExplanationWidget** | `widgets/daily_quiz/detailed_explanation_widget.dart` | 100% | None needed |
| **FeedbackBannerWidget** | `widgets/daily_quiz/feedback_banner_widget.dart` | 100% | None needed |
| **QuestionReviewScreen** | `widgets/question_review/question_review_screen.dart` | 100% | None needed |
| **LaTeXWidget** | `widgets/latex_widget.dart` | 100% | None needed |
| **SafeSvgWidget** | `widgets/safe_svg_widget.dart` | 100% | None needed |
| **ReviewQuestionData** | `models/review_question_data.dart` | 95% | Add `fromMockTest()` factory |
| **DailyQuizProvider** | `providers/daily_quiz_provider.dart` | Pattern only | New MockTestProvider |

#### 4.2 Mock Test Screen Flow

**New Screens**:

1. `mock_test_selection_screen.dart` - Choose exam type, see limits, unlock status
2. `mock_test_question_screen.dart` - Main test-taking interface with 90-question navigation
3. `mock_test_results_screen.dart` - Results, analytics, and review entry
4. `mock_test_review_screen.dart` - Full 90-question review with explanations
5. `test_history_screen.dart` - Unified history (Mock tests + Daily quiz + Chapter practice)

**Screen Flow Diagram**:

```
Home → Mock Test Selection → [Locked: Show unlock progress]
                          → [Unlocked: Show exam type selection]
                                    ↓
                          Mock Test Question Screen
                          (3 hours, 90 questions)
                                    ↓
                          Mock Test Results Screen
                          (Score, analytics, percentile)
                                    ↓
                          [Review All Questions] → Mock Test Review Screen
                                                   (Reuses QuestionReviewScreen)
```

#### 4.3 Mock Test Provider

**File**: `mobile/lib/providers/mock_test_provider.dart`

**Follow DailyQuizProvider pattern with extensions for:**

- Manage mock test state (questions, responses, timer)
- Handle pause/resume functionality (2 pauses, 5 min each)
- Event-driven auto-save (on answer selection, navigation, backgrounding)
- Handle app backgrounding (timer continues unless paused)
- 90-question navigation with flagging
- Subject filtering during test
- Submit mock test on completion
- Resume incomplete test on app restart

#### 4.4 Mock Test Question Screen

**Layout**:

```
┌─────────────────────────────────────────┐
│  ⏱️ 2:45:32          [Pause (2 left)]  │  ← Fixed header
├─────────────────────────────────────────┤
│  [Physics] [Chemistry] [Mathematics]    │  ← Subject tabs
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐   │
│  │   QuestionCardWidget            │   │  ← Reused 100%
│  │   (MCQ or Numerical)            │   │
│  │                                 │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [Flag Question]                        │
│                                         │
├─────────────────────────────────────────┤
│  Question Navigator (scrollable)        │
│  ┌───┬───┬───┬───┬───┬───┬───┬───┐    │
│  │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │...│90 │    │
│  └───┴───┴───┴───┴───┴───┴───┴───┘    │
│  🟢 Answered  ⚪ Unanswered  🟡 Flagged │
├─────────────────────────────────────────┤
│  [← Previous]  Q 15/90  [Next →]       │
│              [Submit Test]              │
└─────────────────────────────────────────┘
```

**Color Coding**:
- 🟢 Green: Answered
- ⚪ White/Gray: Unanswered
- 🟡 Yellow: Flagged for review
- 🔵 Blue: Current question

#### 4.5 Mock Test Results Screen

**Layout**:

```
┌─────────────────────────────────────────┐
│  🎉 Mock Test Complete!                 │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────┐   │
│  │  Score: 245/300 (81.6%)         │   │
│  │  Time: 2h 45m / 3h              │   │
│  │  Percentile: 72%                │   │
│  │  Accuracy: 86.1%                │   │
│  └─────────────────────────────────┘   │
├─────────────────────────────────────────┤
│  Subject Breakdown                      │
│  ┌─────────────────────────────────┐   │
│  │ Physics    ████████░░  82/100   │   │
│  │ Chemistry  ███████░░░  78/100   │   │
│  │ Math       █████████░  85/100   │   │
│  └─────────────────────────────────┘   │
├─────────────────────────────────────────┤
│  📊 Analytics Summary                   │
│  • Strongest: Thermodynamics (95%)     │
│  • Weakest: Organic Chemistry (62%)    │
│  • Time: 1.8 min avg (good pacing)     │
├─────────────────────────────────────────┤
│  💬 Priya Ma'am's Feedback              │
│  "Great improvement in Physics!..."     │
├─────────────────────────────────────────┤
│  [Review All 90 Questions]              │  ← Primary CTA
│  [Back to Dashboard]                    │
└─────────────────────────────────────────┘
```

#### 4.6 Mock Test Review Screen (90 Questions)

**Reuses**: `QuestionReviewScreen` with mock test data

**Layout**:

```
┌─────────────────────────────────────────┐
│  ← Back    Mock Test Review             │
├─────────────────────────────────────────┤
│  Filter: [All 90] [✓ 62] [✗ 8] [- 5]  │  ← Correct/Wrong/Unattempted
│  Subject: [All] [Phy] [Chem] [Math]    │
├─────────────────────────────────────────┤
│  Question 1 of 90 (filtered: 90)        │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │   QuestionCardWidget            │   │  ← reviewMode: true
│  │   Shows: Your answer, Correct   │   │
│  │   Color: Green/Red indicator    │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │   DetailedExplanationWidget     │   │  ← Expandable
│  │   • Quick Explanation           │   │
│  │   • Step-by-Step Solution       │   │
│  │   • Why You Got This Wrong      │   │
│  │   • Key Takeaway               │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [💬 Discuss with Priya Ma'am]         │  ← AI Tutor integration
├─────────────────────────────────────────┤
│  [← Prev]    15/90    [Next →]         │
└─────────────────────────────────────────┘
```

**Data Model Extension**:

```dart
// Add to ReviewQuestionData
factory ReviewQuestionData.fromMockTest(Map<String, dynamic> data) {
  return ReviewQuestionData(
    questionId: data['question_id'],
    position: data['position'],
    questionText: data['question_text'],
    // ... same fields as daily quiz
    sourceType: 'mock_test', // NEW: for analytics
    mockTestId: data['mock_test_id'], // NEW: reference
  );
}
```

#### 4.7 Test History Screen (NEW - Unified)

**Purpose**: Single screen for viewing all test/quiz history across types.

**Layout**:

```
┌─────────────────────────────────────────┐
│  ← Back        Test History             │
├─────────────────────────────────────────┤
│  [Mock Tests] [Daily Quiz] [Chapter]    │  ← Tabs
├─────────────────────────────────────────┤
│  Filter: [All] [JEE Main] [JEE Adv]    │  ← Mock test specific
│  Showing: Last 7 days (Free tier)       │  ← Tier indicator
│  [Upgrade for 30+ days history]         │  ← Upsell
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────┐   │
│  │ Jan 20, 2025 • JEE Main         │   │
│  │ Score: 245/300 (81.6%)          │   │
│  │ Time: 2h 45m • Rank: 72%ile     │   │
│  │ [View Details] [Review Questions]│   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Jan 18, 2025 • JEE Main         │   │
│  │ Score: 220/300 (73.3%)          │   │
│  │ [View Details] [Review Questions]│   │
│  └─────────────────────────────────┘   │
│                                         │
│  [Load More]                            │
└─────────────────────────────────────────┘
```

**API**:
```
GET /api/history?type=mock_test&days=7  // Enforced by tier
GET /api/history?type=daily_quiz&days=30
GET /api/history?type=chapter_practice&limit=20
```

### 5. Question Generation Strategy

#### 5.1 Hybrid Approach (Recommended)

**Why Hybrid?**

| Approach | Pros | Cons |
|----------|------|------|
| Pure AI on-the-fly | Always fresh | Slow (3-5 min), expensive (~$0.50-1/test), no IRT calibration |
| Pure curated bank | Fast, reliable | Stale questions, less personalized |
| **Hybrid** | Best of both | Moderate initial setup |

**Architecture**:

```
┌─────────────────────────────────────────────────────────────────┐
│                    OFFLINE (Background Job)                      │
├─────────────────────────────────────────────────────────────────┤
│  1. Generate questions using Claude Sonnet                       │
│  2. Calibrate IRT parameters (a, b, c) based on:                │
│     - Question complexity analysis                               │
│     - Target difficulty level                                    │
│     - Question type (MCQ vs NVQ)                                │
│  3. Store in Firestore: mock_test_question_pool/                │
│  4. Target: 300 questions per subject (900 total for JEE Main)  │
│  5. Refresh: Weekly batch job adds 50 new questions, retires old│
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    RUNTIME (User Request)                        │
├─────────────────────────────────────────────────────────────────┤
│  1. Retrieve user's theta_by_chapter from profile               │
│  2. Query question pool with IRT-based selection:               │
│     - Fisher Information maximization                            │
│     - Difficulty matching (±1.0 SD from theta)                  │
│     - Recency filter (no questions from last 60 days)           │
│  3. Ensure exam pattern compliance:                              │
│     - 30 Physics (20 MCQ + 10 NVQ)                              │
│     - 30 Chemistry (20 MCQ + 10 NVQ)                            │
│     - 30 Mathematics (20 MCQ + 10 NVQ)                          │
│  4. Return 90 questions in < 2 seconds                          │
└─────────────────────────────────────────────────────────────────┘
```

#### 5.2 AI Provider: Claude

**Integration**: Uses existing `backend/src/services/claude.js` service

- **Question Generation (batch)**: Claude Sonnet (`claude-sonnet-4-20250514`)
- **Validation (batch)**: Claude Haiku (`claude-3-haiku-20240307`) for cost efficiency
- **Fallback**: OpenAI (`gpt-4o`) if Claude unavailable

**Prompt Structure for Question Generation**:

```javascript
const prompt = `Generate a JEE ${examType} level ${questionType} question for:
Subject: ${subject}
Chapter: ${chapter}
Difficulty: ${difficulty} (on scale: easy/medium/hard)
Topic hints: ${topicHints}

Requirements:
- Question must be original and exam-appropriate
- Include 4 options (A, B, C, D) for MCQ
- Provide correct answer and detailed solution
- Use LaTeX for mathematical expressions: \\( inline \\) or \\[ display \\]
- Difficulty should match JEE ${examType} standards

Output JSON format:
{
  "question_text": "...",
  "options": { "A": "...", "B": "...", "C": "...", "D": "..." },
  "correct_answer": "B",
  "solution": "...",
  "difficulty_tier": "medium"
}`;
```

#### 5.3 Balancing Realism with Personalization

1. **Subject Distribution**: Strict (33.3% each subject)
2. **Question Type Distribution**: Strict (66.7% MCQ, 33.3% NVQ for JEE Main)
3. **Chapter Distribution**: Weighted by JEE exam frequency (use existing chapter weights from `JEE_SYLLABUS_INTEGRATION.md`)
4. **Difficulty Distribution**: Adaptive but realistic
   - 20% Easy (theta - 1.0 to theta - 0.5)
   - 50% Medium (theta - 0.5 to theta + 0.5)
   - 30% Hard (theta + 0.5 to theta + 1.0)
5. **Question Selection**: Use IRT Fisher Information but with wider difficulty range (±1.0 SD vs ±0.5 SD for daily quiz)

### 6. Timer and State Management

#### 6.1 Timer Implementation

- Reuse timer logic from `assessment_question_screen.dart`
- 3-hour countdown for JEE Main
- 6-hour total (3 hours per paper) for JEE Advanced
- Continue timer when app backgrounds (wall-clock based) unless paused
- Show warning at 30 minutes remaining
- Auto-submit when time expires (with confirmation)

#### 6.2 Pause Functionality

**Configuration**:

```javascript
const PAUSE_CONFIG = {
  max_pauses: 2,                    // Maximum pauses allowed per test
  max_pause_duration_seconds: 300,  // 5 minutes max per pause
  timer_behavior: 'STOPS',          // Timer STOPS during pause
  pause_cooldown_seconds: 600       // Must wait 10 min between pauses
};
```

**Behavior**:

- Timer **stops** during pause (more user-friendly)
- UI shows: "Pause 1/2 used. 4:32 remaining on this pause."
- After all pauses used: Pause button disabled
- State saved on pause

#### 6.3 Auto-Save (Event-Driven)

**Triggers** (NOT time-based):

```javascript
const SAVE_TRIGGERS = {
  ANSWER_SELECTED: true,      // User selects/changes an answer
  QUESTION_NAVIGATION: true,  // User navigates to different question
  QUESTION_FLAGGED: true,     // User flags/unflags a question
  APP_BACKGROUNDED: true,     // App goes to background
  PAUSE_REQUESTED: true,      // User requests pause
  NETWORK_RESTORED: true      // Coming back online
};
```

**Debouncing**: Max 1 save per 5 seconds to prevent excessive writes

**Storage**: Local first (Hive), sync to Firestore in background

**Expected Firestore Writes**: ~100-150 per student (vs ~360 with time-based saves)

### 7. Offline Handling

#### 7.1 Local-First Architecture

**New Service**: `mobile/lib/services/mock_test_local_storage_service.dart`

```dart
class MockTestLocalStorageService {
  // Store entire mock test locally when generated
  Future<void> cacheMockTest(MockTest test);

  // Save responses locally (primary storage)
  Future<void> saveResponse(String questionId, String answer, int timeSpent);

  // Sync to Firestore when online
  Future<void> syncToCloud();

  // Resume from local storage after app crash/restart
  Future<MockTestState?> loadInProgressTest();

  // Conflict resolution: Local wins (user's answers are source of truth)
  Future<void> resolveConflicts(LocalState local, CloudState cloud);
}
```

#### 7.2 Offline Flow

1. **Test Generation**: Cache all 90 questions locally immediately
2. **During Test**: Save all responses to local storage first
3. **Background Sync**: Push to Firestore every 30 seconds (if online)
4. **App Crash**: Resume seamlessly from local storage
5. **Network Drop**: Continue test normally, queue syncs for later
6. **Submit**: Require connectivity, show retry UI if offline

### 8. Scoring and Analytics

#### 8.1 Scoring Algorithm

```javascript
function calculateScore(responses, examType) {
  let totalMarks = 0;
  let correctCount = 0;
  let incorrectCount = 0;
  let unattemptedCount = 0;

  responses.forEach(response => {
    if (!response.student_answer) {
      unattemptedCount++;
      return;
    }

    if (response.is_correct) {
      totalMarks += 4; // +4 for correct
      correctCount++;
    } else {
      totalMarks -= 1; // -1 for incorrect
      incorrectCount++;
    }
  });

  return {
    total_marks: totalMarks,
    max_marks: responses.length * 4,
    correct_count: correctCount,
    incorrect_count: incorrectCount,
    unattempted_count: unattemptedCount,
    accuracy: correctCount / (correctCount + incorrectCount)
  };
}
```

#### 8.2 Analytics Components

**Subject-Wise Analysis**:

- Marks per subject
- Accuracy per subject
- Time spent per subject
- Comparison with previous attempts

**Chapter-Wise Analysis**:

- Performance heatmap (chapters with low accuracy highlighted)
- Identify top 5 weak chapters
- Recommend chapter practice sessions

**Time Management Analysis**:

- Average time per question
- Questions where too much time spent (>3 minutes)
- Questions rushed (<30 seconds)
- Recommendations for pacing

**Percentile Calculation**:

- Compare score against all JEEVibe users who took same exam type
- Update percentile as more users complete tests
- Show confidence interval if sample size < 100

### 9. Tier-Based Gating

#### 9.1 Mock Test Limits

| Tier | Mock Tests/Month | JEE Main | JEE Advanced |
|------|------------------|----------|--------------|
| **Free** | 1 total | 1 | 1 (shared limit) |
| **Pro** | 5 total | Any combination | Any combination |
| **Ultra** | Unlimited | Unlimited | Unlimited |

**Notes**:
- Limits reset at midnight IST on 1st of each month
- Show "X mock tests remaining this month" in UI

**Abandonment & Resume Policy** (Student-Friendly):

| Scenario | Behavior | Counts Against Limit? |
|----------|----------|----------------------|
| App crash / force close | Auto-saved, allow resume on next open | **No** (still in progress) |
| User backgrounds app | Save state, allow resume | **No** (still in progress) |
| User closes app mid-test | Save state, show "Continue test" prompt | **No** (still in progress) |
| User clicks "Abandon Test" | Confirm dialog, mark abandoned | **Yes** |
| Test inactive for 24 hours | Auto-mark as abandoned | **Yes** |
| Time expires (3 hrs) | Auto-submit answered questions | **Yes** (completed) |

**Implementation**:
```javascript
// Test states
status: "in_progress" | "completed" | "abandoned_user" | "abandoned_timeout"

// Only completed and explicitly abandoned count against limits
const COUNTS_AGAINST_LIMIT = ["completed", "abandoned_user", "abandoned_timeout"];

// Grace period before auto-abandonment
const ABANDONMENT_TIMEOUT_HOURS = 24;
```

**UX for Resume**:
- On app open with in-progress test: "Continue your JEE Main Mock Test? (2:15:32 remaining)"
- Warning after 12 hours: "Your mock test will expire in 12 hours"
- Explicit abandon requires confirmation: "Abandoning will count against your monthly limit. Continue?"

#### 9.2 Feature Unlock Criteria

Mock tests unlock after:
1. **Initial assessment completed** (baseline theta established)

**Rationale**:
- Assessment provides baseline theta for all chapters
- Immediate access for eager students who complete assessment
- Monitor abandonment rates; if high, may add "complete 3 daily quizzes" requirement later

**UI Treatment**:
- Before unlock: Show "Complete your assessment to unlock Mock Tests"
- After assessment: Mock tests immediately available

#### 9.3 Test History Retention (NEW FEATURE)

| Tier | History Retention | What's Visible |
|------|-------------------|----------------|
| **Free** | 7 days | Last week's tests only |
| **Pro** | 30 days | Last month's tests |
| **Ultra** | Unlimited | Full history since signup |

**Implementation Notes**:
- Don't delete old records - just gate API access by tier
- `GET /api/history?type=mock_test&days=7` (enforced server-side)
- Keep all data for tier upgrades (instant access to full history)
- History includes: Mock tests, Daily quizzes, Chapter practice

#### 9.4 Implementation

- Check tier limits before generating mock test
- Check unlock criteria (assessment + 3 quizzes)
- Track usage in `users/{userId}/mock_test_usage`
- Reset monthly limits at midnight IST
- Show remaining attempts in UI
- Gate history API by tier retention limits

### 10. Differentiation Features

#### 10.1 AI-Powered Insights

- Use IRT theta estimates to explain performance
- "Your theta in Mechanics improved from 0.3 to 0.5 after this test"
- Compare against predicted performance based on daily quiz theta

#### 10.2 Personalized Recommendations

- After mock test, recommend specific chapter practice sessions
- Suggest daily quiz focus areas based on weak chapters
- Recommend Snap & Solve practice for specific concepts

#### 10.3 Adaptive Difficulty Progression

- Track mock test performance over time
- Adjust next mock test difficulty based on performance trend
- Show progress: "Your mock test scores improved 15% over last 3 months"

### 11. Cost Analysis

#### 11.1 Question Pool Generation (One-Time + Maintenance)

| Item | Tokens | Cost |
|------|--------|------|
| Initial pool (900 questions) | ~450K output | ~$6.75 (Claude Sonnet) |
| Weekly refresh (150 questions) | ~75K output | ~$1.13/week |
| Monthly maintenance | ~300K output | ~$4.50/month |

#### 11.2 Runtime Costs (Per Mock Test)

| Approach | Cost per Test |
|----------|---------------|
| Pure AI on-the-fly | $0.50 - $1.00 |
| **Hybrid (recommended)** | ~$0.001 |

**Hybrid breakdown**:
- AI calls: $0.00 (selection is algorithmic)
- Firestore reads: ~100 reads = ~$0.00006
- Firestore writes: ~150 writes = ~$0.0003

### 12. Testing Requirements

#### 12.1 Unit Tests

- Question pool selection logic
- Scoring algorithm with negative marking
- Timer calculations
- State persistence
- Offline storage operations

#### 12.2 Integration Tests

- Full mock test flow (generate → take → submit → analytics)
- Tier limit enforcement
- Pause/resume functionality
- App backgrounding scenarios
- Offline mode: disconnect → answer → reconnect → sync

#### 12.3 Performance Tests

- Mock test generation time (< 2 seconds for 90 questions)
- Analytics calculation time (< 1 second)
- Large response submission (< 3 seconds)

### 13. Implementation Phases

#### Phase 1: Foundation (Backend + Basic Mobile)

- Create `mockTestQuestionPoolService.js` - Question pool management
- Create `mockTestService.js` - Generation using pool + IRT selection
- Create `mockTestResponseService.js` - Submission and scoring
- Create API routes: generate, submit, get-active
- Mobile: Basic test-taking UI (reuse daily quiz components)
- Mobile: Local storage service for offline-first

#### Phase 2: Question Pool Population

- Create batch job script for question generation
- Generate initial pool: 300 questions per subject (900 total)
- Implement IRT parameter calibration heuristics
- Add question quality validation (LaTeX, answer verification)

#### Phase 3: Enhanced Analytics

- `mockTestAnalyticsService.js` - Detailed reports
- Subject-wise and chapter-wise breakdown
- Time management analysis
- Percentile calculation
- Recommendations engine

#### Phase 4: JEE Advanced Mock Test

- 2-paper format support
- Complex marking schemes (partial marking, multi-correct)
- Paper 1/Paper 2 separation with break handling

#### Phase 5: Polish

- Pause functionality
- Question flagging
- Review mode (retake with solutions)
- Comparison with previous attempts

#### Phase 6: Test History & Unified Experience

- Unified test history screen (Mock tests + Daily quiz + Chapter practice)
- Tier-based history retention (7/30/unlimited days)
- Progress analytics dashboard

### 14. Future-Proofing for PYQ (Previous Year Questions)

**Critical**: Design architecture to support both Mock Tests and upcoming PYQ feature.

#### 14.1 Shared Patterns

| Component | Mock Test | PYQ | Shared? |
|-----------|-----------|-----|---------|
| Question display | ✓ | ✓ | Yes - `QuestionCardWidget` |
| Timer | 3 hours fixed | Per question or timed mode | Yes - configurable |
| Review | ✓ | ✓ | Yes - `QuestionReviewScreen` |
| Results | ✓ | ✓ | Yes - common pattern |
| History | ✓ | ✓ | Yes - unified history |
| Scoring | +4/-1 | Variable by year/exam | Abstract scoring interface |
| Question source | AI-generated pool | Curated PYQ bank | Different collections |

#### 14.2 Unified Database Schema

```javascript
// Abstract test session schema - works for Mock Tests, PYQ, and future test types
// Collection: test_sessions/{userId}/sessions/{sessionId}
{
  session_id: "...",
  session_type: "mock_test" | "pyq_practice" | "pyq_full_paper" | "chapter_practice",

  // Type-specific config
  config: {
    // For mock_test
    exam_type: "jee_main" | "jee_advanced",
    difficulty_level: "adaptive",

    // For PYQ
    year: 2024,
    paper: "jee_main_jan_session1",
    shift: "morning" | "evening",
    mode: "timed" | "practice"
  },

  // Common fields (same for all types)
  status: "in_progress" | "completed" | "abandoned",
  started_at: Timestamp,
  completed_at: Timestamp,
  time_taken_seconds: number,

  questions: [...],      // Embedded questions
  responses: [...],      // User responses
  scoring: {...},        // Marks, accuracy, etc.
  analytics: {...},      // Subject-wise, chapter-wise breakdown

  // Metadata
  created_at: Timestamp,
  version: "1.0"
}
```

#### 14.3 Backend Service Abstraction

```javascript
// Abstract base class for all test types
class BaseTestService {
  // Common methods (same implementation for all)
  async submitTest(userId, testId, responses) { /* common scoring logic */ }
  async getTestById(userId, testId) { /* common */ }
  async getHistory(userId, filters) { /* common with type filter */ }
  async getAnalytics(userId, testId) { /* common analytics */ }

  // Abstract methods (override per type)
  async generateTest(userId, config) { /* type-specific */ }
  async getScoringRules(config) { /* type-specific marking scheme */ }
}

class MockTestService extends BaseTestService {
  async generateTest(userId, config) {
    // Select from mock_test_question_pool using IRT
  }
}

class PYQService extends BaseTestService {
  async generateTest(userId, config) {
    // Load from pyq_questions collection by year/paper
  }

  async getScoringRules(config) {
    // Return actual JEE scoring rules for that year
  }
}
```

#### 14.4 Mobile Architecture for Reuse

```
lib/
├── models/
│   ├── base_test_session.dart      # Abstract base
│   ├── mock_test.dart              # Extends base
│   └── pyq_session.dart            # Extends base (future)
│
├── providers/
│   ├── base_test_provider.dart     # Abstract state management
│   ├── mock_test_provider.dart     # Extends base
│   └── pyq_provider.dart           # Extends base (future)
│
├── screens/
│   ├── test_common/
│   │   ├── question_screen.dart    # Shared question UI
│   │   ├── results_screen.dart     # Shared results UI
│   │   └── review_screen.dart      # Shared review UI
│   │
│   ├── mock_test/
│   │   └── mock_test_selection_screen.dart  # Mock-specific
│   │
│   └── pyq/                        # (future)
│       └── pyq_selection_screen.dart
│
└── widgets/
    └── question_review/            # Already exists, reuse 100%
```

### 15. Additional Considerations

#### 15.1 Proctoring / Anti-Cheat (Future Enhancement)

**Current**: Screenshot prevention already implemented (per git history)

**Future Considerations**:
- Detect app switching during mock test (log, don't block)
- Flag suspicious timing patterns (too fast = guessing)
- Optional: Camera-based proctoring for paid mock tests

**Recommendation**: Track behavior, don't enforce strictly. JEEVibe is for learning, not high-stakes proctored exams.

#### 15.2 Leaderboards & Comparison (Future Enhancement)

- "You scored better than 72% of students"
- Optional friend/peer comparison
- Monthly/all-time rankings per exam type
- School/coaching institute leaderboards (if data available)

**Implementation**: Add after Phase 3 when percentile calculation is stable.

#### 15.3 Scheduled Mock Tests (Future Enhancement)

- "Take mock test every Sunday at 9 AM"
- Push notification reminders
- Simulate real exam day experience (fixed start time)
- Group mock tests (compete with friends)

#### 15.4 Partial Submission & Recovery

**Already Planned** (offline-first design):
- App crash → Resume from local storage
- Time expires → Auto-submit answered questions
- Network drop → Continue test, sync later

**Additional**:
- "Continue incomplete test" prompt on app open
- Clear abandoned test after 24 hours (mark as abandoned)

#### 15.5 Analytics Dashboard (Future Enhancement)

**Post-MVP**: Dedicated analytics screen showing:
- Progress over time (mock test scores chart)
- Weak chapter trends across tests
- Time management insights
- Comparison: Daily quiz vs Mock test performance
- Readiness indicator: "You're 75% ready for JEE Main"

#### 15.6 Mock Test Recommendations

**Post-MVP**: Smart prompts:
- "Based on your daily quiz performance, you're ready for a mock test"
- "Focus on Mechanics before next mock test"
- "Your last mock test was 2 weeks ago - time for another?"

## Files to Create/Modify

### Backend

**New Services**:
- `backend/src/services/mockTestQuestionPoolService.js` - Question pool management
- `backend/src/services/mockTestService.js` - Test generation & lifecycle
- `backend/src/services/mockTestResponseService.js` - Submission & scoring
- `backend/src/services/mockTestAnalyticsService.js` - Performance reports
- `backend/src/services/mockTestQuestionValidationService.js` - 5-stage validation pipeline
- `backend/src/services/testHistoryService.js` - Unified history (Mock + Daily + Chapter)
- `backend/src/services/baseTestService.js` - Abstract base for PYQ reuse

**New Routes**:
- `backend/src/routes/mockTests.js` - Mock test endpoints
- `backend/src/routes/history.js` - Unified history endpoints

**New Middleware**:
- `backend/src/middleware/mockTestLimits.js` - Tier-based gating
- `backend/src/middleware/featureUnlock.js` - Unlock criteria check

**Scripts**:
- `backend/scripts/generateMockTestQuestionPool.js` - Batch generation (cron)

**Config Updates**:
- `backend/firebase/firestore.rules` - mock_tests, mock_test_question_pool, test_history
- `backend/firebase/firestore.indexes.json` - Required indexes

### Mobile

**New Models** (PYQ-ready architecture):
- `mobile/lib/models/base_test_session.dart` - Abstract base
- `mobile/lib/models/mock_test.dart` - Mock test specific
- `mobile/lib/models/mock_test_response.dart` - Response model

**New Providers**:
- `mobile/lib/providers/mock_test_provider.dart` - State management

**New Screens**:
- `mobile/lib/screens/mock_test/mock_test_selection_screen.dart` - Exam selection
- `mobile/lib/screens/mock_test/mock_test_question_screen.dart` - 90-question interface
- `mobile/lib/screens/mock_test/mock_test_results_screen.dart` - Results & analytics
- `mobile/lib/screens/mock_test/mock_test_review_screen.dart` - 90-question review
- `mobile/lib/screens/history/test_history_screen.dart` - Unified history (NEW)

**New Services**:
- `mobile/lib/services/mock_test_api_service.dart` - API client
- `mobile/lib/services/mock_test_local_storage_service.dart` - Offline-first

**Modifications**:
- `mobile/lib/models/review_question_data.dart` - Add `fromMockTest()` factory

### Documentation

- `docs/03-features/MOCK-TESTS-ARCHITECTURE.md` (new)
- `docs/03-features/TEST-HISTORY-FEATURE.md` (new)
- `docs/03-features/TIER-SYSTEM-ARCHITECTURE.md` (update - mark as implemented)

## Success Metrics

1. **Generation Time**: < 2 seconds for 90-question mock test
2. **User Completion Rate**: > 70% of started mock tests completed
3. **Analytics Accuracy**: Score calculation matches manual verification
4. **Performance**: Analytics generation < 1 second
5. **User Satisfaction**: Mock tests feel realistic and valuable
6. **Cost Efficiency**: < $0.01 per mock test (runtime)
7. **Review Engagement**: > 50% of users review at least 10 questions post-test

## Resolved Decisions

| Question | Decision |
|----------|----------|
| Question Source | **Hybrid**: Pre-generated pool + on-the-fly IRT selection |
| AI Provider | **Claude** (already integrated via `claude.js`) |
| Pause Behavior | Timer **stops** during pause (2 pauses max, 5 min each) |
| Auto-Save Strategy | **Event-driven** (on user actions, not time-based) |
| Auto-Submit | Warn at 0, allow continue but mark as overtime |
| Percentile Calculation | Real-time for small sample, batch for large |
| JEE Advanced | Start simplified, add complexity in Phase 4 |
| Implementation Timing | **After question bank reload** completes |
| LaTeX Handling | Store both Unicode + original LaTeX (generate Unicode at pool creation) |
| Tier Limits | Free: 1/month, Pro: 5/month, Ultra: Unlimited ✓ |
| Feature Unlock | After **assessment completed** (immediate access for eager students) ✓ |
| History Retention | Free: 7 days, Pro: 30 days, Ultra: Unlimited ✓ |
| Review All Questions | **Yes** - Full 90-question review with detailed explanations |
| Component Reuse | **Maximize** - QuestionCardWidget, DetailedExplanationWidget, ReviewScreen |
| PYQ Architecture | Design with **abstract base classes** for future PYQ reuse |
| Abandoned Tests | **Student-friendly**: Allow resume within 24hrs, only explicit abandon counts ✓ |

*All open questions resolved - plan ready for implementation after question bank reload.*
