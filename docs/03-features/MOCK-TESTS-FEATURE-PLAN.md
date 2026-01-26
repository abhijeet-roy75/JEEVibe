# Full Mock Tests Feature - Implementation Plan

## Overview

Implement full-length mock tests that simulate JEE Main (3 hours, 90 questions) exam conditions. The feature will leverage JEEVibe's existing IRT-based adaptive learning while providing realistic exam simulation.

> **Scope Note**: This plan focuses on **JEE Main only**. JEE Advanced support is deferred to a future phase due to its complexity (multi-correct MCQs, matrix matching, partial marking, 2-paper format).

## Prerequisites & Sequencing

**Important**: This feature should be implemented AFTER the question bank reload is complete.

**Rationale**:
- Mock test question pool mirrors the `questions` collection schema
- Validation pipeline compares against the main question bank
- IRT parameters may be recalibrated in the new bank

**Implementation Order**:
1. Complete question bank reload (in progress)
2. **Phase 0 (DATA FIRST)**: Create 2-3 mock test templates from existing `questions` collection
3. **Phase 1A**: Implement mock test backend services + backend tests
4. **Phase 1B**: Implement mobile UI (reuses existing components) + widget tests
5. **Phase 1C**: Integration testing (end-to-end flow)
6. **Phase 2+**: AI question pool generation (parallel effort)
7. Add test history feature (benefits all quiz types)

> **Critical**: Phase 0 must be completed first. We cannot build or test the feature without mock test data.

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
- **Marking Scheme** (matches actual JEE Main):
  - **MCQ (Single Correct)**:
    - Correct: +4 marks
    - Incorrect: -1 mark
    - Unattempted: 0 marks
  - **NVQ (Numerical Value)**:
    - Correct: +4 marks
    - Incorrect: **0 marks** (no negative marking)
    - Unattempted: 0 marks
- **Max Score**: 300 marks (75 × 4)

### JEE Advanced Mock Test (DEFERRED)

> **Status**: Deferred to future phase. JEE Main covers 80%+ of target market.
>
> **Complexity reasons for deferral**:
> - Multi-correct MCQs with partial marking (+4 full, +3/+2/+1 partial, -2 wrong)
> - Matrix matching question types
> - Paragraph-based questions
> - 2-paper format with break handling
> - Variable marking schemes by section

When implemented:
- **Duration**: 6 hours total (2 papers × 3 hours each)
- **Paper 1**: 48 questions (16 per subject)
- **Paper 2**: 48 questions (16 per subject)
- **Total Questions**: 96 questions

## Question States (Matching JEE Main CBT Interface)

The mock test UI must match the actual JEE Main computer-based test interface exactly:

| State | Color | Icon | Meaning |
|-------|-------|------|---------|
| **Not Visited** | Gray | Empty circle | Question never opened |
| **Not Answered** | Red | Red circle | Visited but no answer selected |
| **Answered** | Green | Green circle | Answer selected and saved |
| **Marked for Review** | Purple | Purple flag | Flagged for review, no answer |
| **Answered & Marked** | Purple + Green border | Purple flag + green dot | Has answer AND flagged for review |

```dart
enum MockTestQuestionState {
  notVisited,        // Gray - default state
  notAnswered,       // Red - visited but no answer
  answered,          // Green - has answer
  markedForReview,   // Purple - flagged, no answer
  answeredAndMarked, // Purple+Green - has answer AND flagged
}
```

**State Transition Rules**:
1. All questions start as `notVisited`
2. Opening a question → `notAnswered` (if no answer selected)
3. Selecting an answer → `answered`
4. Clicking "Mark for Review" without answer → `markedForReview`
5. Clicking "Mark for Review" with answer → `answeredAndMarked`
6. Clearing answer from `answered` → `notAnswered`
7. Clearing flag from `answeredAndMarked` → `answered`

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
async function retireOverusedQuestions(usageThreshold = 100) // Auto-retire after 100 uses
async function refreshQuestionPool() // Weekly batch job
async function trackQuestionUsage(questionIds) // Increment usage count after test
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
async function updateUserStatsFromMockTest(userId, mockTestId, results)
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

#### 2.1 Mock Tests Collection (Chunked for Performance)

**Path**: `mock_tests/{userId}/tests/{mockTestId}`

> **Important**: Questions are stored in **subcollection chunks** to avoid Firestore document size limits (1MB).
> With 90 questions × ~5KB each = ~450KB, embedding all questions risks hitting limits when images/solutions are included.

**Document Structure** (Main Document - Metadata Only):

```javascript
{
  mock_test_id: "mock_main_2025_01_15_abc123",
  user_id: "user123",
  exam_type: "jee_main",
  template_id: "jee_main_template_1", // Which template was used (Phase 1)
  status: "not_started" | "in_progress" | "completed" | "abandoned",

  // Timing
  started_at: Timestamp | null,
  completed_at: Timestamp | null,
  time_taken_seconds: number | null,
  paused_duration_seconds: number, // Total time paused
  pauses_used: number, // Track pause count
  server_start_time: Timestamp, // For server-side timer validation

  // Question references (IDs only, not full content)
  question_ids: ["PHY_MOCK_001", "PHY_MOCK_002", ...], // 90 IDs
  total_questions: 90,
  chunks_count: 6, // 90 questions / 15 per chunk
```

**Subcollection for Questions** (Chunked):

**Path**: `mock_tests/{userId}/tests/{mockTestId}/questions/{chunkId}`

```javascript
// Chunk 0: Questions 1-15
// Chunk 1: Questions 16-30
// ... up to Chunk 5: Questions 76-90

{
  chunk_id: "chunk_0",
  chunk_index: 0,
  questions: [
    {
      question_id: "PHY_MOCK_001",
      position: 1,
      subject: "Physics",
      chapter: "Mechanics",
      chapter_key: "physics_mechanics",
      question_type: "mcq_single" | "numerical",
      question_text: "...",
      question_text_html: "...",
      image_url: "gs://...", // If has image
      options: [...], // For MCQ
      correct_answer: "...",
      solution_text: "...",
      solution_steps: [...],
      irt_parameters: { a, b, c },
      selection_theta: 0.5,
    },
    // ... 14 more questions
  ]
}
```

**Chunk Loading Strategy** (Mobile):

```dart
class MockTestQuestionLoader {
  final Map<int, List<MockTestQuestion>> _loadedChunks = {};

  Future<MockTestQuestion> getQuestion(int position) async {
    final chunkIndex = position ~/ 15;  // 0-5

    if (!_loadedChunks.containsKey(chunkIndex)) {
      _loadedChunks[chunkIndex] = await _loadChunk(chunkIndex);
      // Prefetch next chunk for smooth navigation
      _prefetchChunk(chunkIndex + 1);
    }

    return _loadedChunks[chunkIndex]![position % 15];
  }

  Future<void> _prefetchChunk(int chunkIndex) async {
    if (chunkIndex < 6 && !_loadedChunks.containsKey(chunkIndex)) {
      // Load in background, don't await
      _loadChunk(chunkIndex).then((chunk) {
        _loadedChunks[chunkIndex] = chunk;
      });
    }
  }
}
```

**Main Document Continues**:

```javascript
  // (continuing mock_tests/{userId}/tests/{mockTestId})

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

#### 3.0 Rate Limiting & Security

**Rate Limiting Middleware**: `backend/src/middleware/mockTestRateLimiter.js`

```javascript
const rateLimit = require('express-rate-limit');

// Prevent spam generation requests
const mockTestGenerationLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 1, // 1 request per 5 minutes per user
  keyGenerator: (req) => req.user.uid,
  message: {
    success: false,
    error: 'Please wait 5 minutes before generating another mock test'
  },
  standardHeaders: true,
  legacyHeaders: false
});

// Prevent rapid submissions (accidental double-click)
const mockTestSubmissionLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 2, // 2 submissions per minute
  keyGenerator: (req) => `${req.user.uid}_${req.params.mockTestId}`,
  message: {
    success: false,
    error: 'Submission already in progress'
  }
});

module.exports = { mockTestGenerationLimiter, mockTestSubmissionLimiter };
```

**Apply to Routes**:
```javascript
router.post('/generate', authenticate, mockTestGenerationLimiter, generateMockTest);
router.post('/:mockTestId/submit', authenticate, mockTestSubmissionLimiter, submitMockTest);
```

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

#### 4.0 Home Screen Entry Point

**Location**: Mock Tests card will be a **primary feature** on the home screen.

**Placement Order** (top to bottom):
1. Focus Chapter card (existing)
2. **Mock Tests card** ← NEW (prominent placement)
3. Snap & Solve card (existing hero feature)
4. Recent Solutions (existing)
5. Quick Tips (existing)

**Mock Tests Card Design**:

```
┌─────────────────────────────────────────┐
│  📋  Full JEE Main Mock Test            │
│                                         │
│  Simulate the real exam experience      │
│  90 questions • 3 hours • Real pattern  │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │     [Start Mock Test]           │   │ ← Primary CTA
│  └─────────────────────────────────┘   │
│                                         │
│  4 remaining this month (Pro)           │ ← Tier limit indicator
└─────────────────────────────────────────┘
```

**Card States**:

| State | UI Treatment |
|-------|--------------|
| **Locked** (assessment not done) | Grayed out, "Complete Assessment to Unlock" |
| **Available** | Full color, "Start Mock Test" + remaining count |
| **In Progress** | Yellow banner, "Continue Mock Test (2:15:32 remaining)" |
| **Limit Reached** | Muted, "Upgrade to Pro for more mock tests" |
| **No Questions Available** | Hidden or "Coming Soon" |

**History Tab Integration**:
- History screen already has Tab 3 for Mock Tests (currently "Coming Soon" placeholder)
- Will show completed mock tests with scores, dates, and "Review" button
- Tier-based history retention (Free: 7 days, Pro: 30 days, Ultra: unlimited)

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

**Color Coding** (Matches JEE Main CBT):
- ⬜ Gray: Not Visited (never opened)
- 🔴 Red: Not Answered (visited, no answer)
- 🟢 Green: Answered (has answer)
- 🟣 Purple: Marked for Review (flagged, no answer)
- 🟣+🟢 Purple with Green dot: Answered & Marked (has answer AND flagged)
- 🔵 Blue border: Current question

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

#### 6.1.1 Server-Side Timer Validation

> **Security**: Prevent timer manipulation by validating on server at submission.

```javascript
// In mockTestResponseService.js
async function validateSubmissionTiming(mockTest, submittedAt) {
  const allowedDuration = 10800; // 3 hours in seconds
  const pauseDuration = mockTest.paused_duration_seconds || 0;
  const graceBuffer = 300; // 5 minute grace for network latency

  const serverStartTime = mockTest.server_start_time.toMillis();
  const actualDuration = (submittedAt - serverStartTime) / 1000;
  const maxAllowed = allowedDuration + pauseDuration + graceBuffer;

  if (actualDuration > maxAllowed) {
    // Flag for review but still process submission
    await flagTestForReview(mockTest.mock_test_id, 'timer_exceeded', {
      expected_max: maxAllowed,
      actual_duration: actualDuration,
      exceeded_by: actualDuration - maxAllowed
    });

    return {
      valid: false,
      warning: 'Test duration exceeded allowed time',
      overtime_seconds: actualDuration - (allowedDuration + pauseDuration)
    };
  }

  return { valid: true };
}
```

**Validation Points**:
1. Store `server_start_time` when test is generated (not client time)
2. On submission, compare server time difference
3. Account for pauses and grace buffer
4. Flag suspicious submissions but still score them (benefit of doubt)

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

#### 7.2 Image Prefetching

> **Note**: Reuses existing `ImageCacheService` from daily quiz. Prefetch images when test loads.

```dart
// In MockTestProvider - called after test is generated
Future<void> prefetchTestImages(List<MockTestQuestion> questions) async {
  final imageUrls = questions
      .where((q) => q.imageUrl != null)
      .map((q) => q.imageUrl!)
      .toList();

  // Prefetch in background (don't block test start)
  _imageCacheService.prefetchImages(imageUrls).then((_) {
    debugPrint('Prefetched ${imageUrls.length} images for mock test');
  }).catchError((e) {
    // Non-critical, images will load on-demand if prefetch fails
    debugPrint('Image prefetch partial failure: $e');
  });
}
```

**Cache Size Considerations**:
- ~90 questions × ~50KB average per image = ~4.5MB per test
- Pro tier has 100MB cache limit (sufficient for 20+ tests)
- Images use existing `jeevibe_solution_images` cache manager

#### 7.3 Offline Flow

1. **Test Generation**: Cache all 90 questions locally immediately (chunked)
2. **Image Prefetch**: Start background prefetch of all question images
3. **During Test**: Save all responses to local storage first
4. **Background Sync**: Push to Firestore on events (not time-based)
5. **App Crash**: Resume seamlessly from local storage
6. **Network Drop**: Continue test normally, queue syncs for later
7. **Submit**: Require connectivity, show retry UI if offline

### 8. Scoring and Analytics

#### 8.1 Scoring Algorithm

```javascript
/**
 * Calculate JEE Main mock test score with correct marking scheme:
 * - MCQ: +4 correct, -1 incorrect
 * - NVQ (Numerical): +4 correct, 0 incorrect (NO negative marking)
 */
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
      totalMarks += 4; // +4 for correct (both MCQ and NVQ)
      correctCount++;
    } else {
      // Negative marking ONLY for MCQ, not for Numerical Value Questions
      if (response.question_type === 'mcq_single') {
        totalMarks -= 1; // -1 for incorrect MCQ
      }
      // NVQ incorrect = 0 marks (no deduction)
      incorrectCount++;
    }
  });

  return {
    total_marks: totalMarks,
    max_marks: responses.length * 4,
    correct_count: correctCount,
    incorrect_count: incorrectCount,
    unattempted_count: unattemptedCount,
    accuracy: correctCount / (correctCount + incorrectCount),
    mcq_penalty: responses.filter(r =>
      r.question_type === 'mcq_single' && !r.is_correct && r.student_answer
    ).length // Track MCQ penalties separately
  };
}
```

#### 8.2 Post-Test User Updates

After a mock test submission, we update the user's profile with comprehensive stats for analytics:

**User Stats Update** (in `users/{userId}` document):

```javascript
async function updateUserStatsFromMockTest(userId, mockTestId, results) {
  const userRef = db.collection('users').doc(userId);

  // Atomic update with FieldValue operations
  await userRef.update({
    // Lifetime stats
    'stats.total_questions_attempted': admin.firestore.FieldValue.increment(results.total_attempted),
    'stats.total_questions_correct': admin.firestore.FieldValue.increment(results.correct_count),
    'stats.total_mock_tests_completed': admin.firestore.FieldValue.increment(1),

    // Subject-wise stats (for accuracy calculation)
    'stats.physics.questions_attempted': admin.firestore.FieldValue.increment(results.physics.attempted),
    'stats.physics.questions_correct': admin.firestore.FieldValue.increment(results.physics.correct),
    'stats.physics.total_marks': admin.firestore.FieldValue.increment(results.physics.marks),

    'stats.chemistry.questions_attempted': admin.firestore.FieldValue.increment(results.chemistry.attempted),
    'stats.chemistry.questions_correct': admin.firestore.FieldValue.increment(results.chemistry.correct),
    'stats.chemistry.total_marks': admin.firestore.FieldValue.increment(results.chemistry.marks),

    'stats.mathematics.questions_attempted': admin.firestore.FieldValue.increment(results.mathematics.attempted),
    'stats.mathematics.questions_correct': admin.firestore.FieldValue.increment(results.mathematics.correct),
    'stats.mathematics.total_marks': admin.firestore.FieldValue.increment(results.mathematics.marks),

    // Mock test specific tracking
    'mock_test_usage.jee_main.total_attempts': admin.firestore.FieldValue.increment(1),
    'mock_test_usage.jee_main.last_attempt_date': new Date().toISOString().split('T')[0],
    'mock_test_usage.jee_main.best_score': results.obtained_marks > (currentBestScore || 0)
      ? results.obtained_marks : currentBestScore,
    'mock_test_usage.jee_main.best_percentile': results.percentile > (currentBestPercentile || 0)
      ? results.percentile : currentBestPercentile,

    // Chapter-wise accuracy (for analytics dashboard)
    ...buildChapterStatsUpdate(results.chapter_wise_performance),

    // Last activity
    'last_mock_test_at': admin.firestore.FieldValue.serverTimestamp()
  });
}

function buildChapterStatsUpdate(chapterPerformance) {
  const updates = {};
  for (const [chapterKey, data] of Object.entries(chapterPerformance)) {
    updates[`stats.chapters.${chapterKey}.questions_attempted`] =
      admin.firestore.FieldValue.increment(data.total);
    updates[`stats.chapters.${chapterKey}.questions_correct`] =
      admin.firestore.FieldValue.increment(data.correct);
  }
  return updates;
}
```

**Theta Updates** (using existing `thetaUpdateService.js` patterns):

```javascript
async function updateThetaFromMockTest(userId, responses) {
  const { updateThetaAfterResponse, calculateSubjectTheta } = require('./thetaUpdateService');

  // Group responses by chapter
  const responsesByChapter = groupBy(responses, 'chapter_key');

  // Update chapter thetas
  for (const [chapterKey, chapterResponses] of Object.entries(responsesByChapter)) {
    for (const response of chapterResponses) {
      // Use existing theta update logic (Bayesian update)
      await updateThetaAfterResponse(userId, {
        chapter_key: chapterKey,
        is_correct: response.is_correct,
        irt_parameters: response.irt_parameters,
        source: 'mock_test' // Track source for analytics
      });
    }
  }

  // Recalculate subject thetas (weighted average of chapter thetas)
  for (const subject of ['physics', 'chemistry', 'mathematics']) {
    await calculateSubjectTheta(userId, subject);
  }

  // Recalculate overall theta
  await calculateOverallTheta(userId);

  console.log(`Updated theta for user ${userId} after mock test`);
}
```

**User Document Structure After Mock Test**:

```javascript
// users/{userId}
{
  // ... existing fields ...

  // Lifetime stats (aggregated)
  stats: {
    total_questions_attempted: 1250,
    total_questions_correct: 875,
    total_mock_tests_completed: 5,

    physics: {
      questions_attempted: 420,
      questions_correct: 310,
      total_marks: 1180,  // Cumulative marks earned
      accuracy: 0.738    // Computed: correct/attempted
    },
    chemistry: { /* same structure */ },
    mathematics: { /* same structure */ },

    chapters: {
      'physics_mechanics': {
        questions_attempted: 45,
        questions_correct: 35,
        accuracy: 0.778
      },
      // ... all chapters
    }
  },

  // Theta data (existing structure, updated after mock test)
  theta_by_chapter: {
    'physics_mechanics': { theta: 0.65, se: 0.22, questions_answered: 95 },
    // ...
  },
  theta_by_subject: {
    'physics': { theta: 0.55, se: 0.18 },
    'chemistry': { theta: 0.42, se: 0.20 },
    'mathematics': { theta: 0.68, se: 0.17 }
  },
  overall_theta: 0.55,
  overall_percentile: 72.5,

  // Mock test specific
  mock_test_usage: {
    jee_main: {
      total_attempts: 5,
      last_attempt_date: '2025-01-25',
      best_score: 245,
      best_percentile: 85.2,
      attempts_this_month: 2,
      score_history: [220, 235, 228, 240, 245] // Last 5 scores for trend
    }
  },

  last_mock_test_at: Timestamp
}
```

**Analytics Queries Enabled**:

```javascript
// Subject accuracy over time
const physicsAccuracy = user.stats.physics.questions_correct / user.stats.physics.questions_attempted;

// Weakest chapters (sorted by accuracy)
const weakChapters = Object.entries(user.stats.chapters)
  .map(([key, data]) => ({
    chapter_key: key,
    accuracy: data.questions_correct / data.questions_attempted
  }))
  .sort((a, b) => a.accuracy - b.accuracy)
  .slice(0, 5);

// Mock test improvement trend
const scoreTrend = user.mock_test_usage.jee_main.score_history;
const improvement = scoreTrend[scoreTrend.length - 1] - scoreTrend[0];

// Readiness indicator (compare theta to JEE difficulty)
const readiness = calculateReadiness(user.theta_by_subject, JEE_DIFFICULTY_THRESHOLD);
```

#### 8.3 Analytics Components

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

**Percentile Calculation** (Using NTA Official Data):

> **Decision**: Use NTA's officially published percentile brackets, NOT app-calculated percentile.
> This is more meaningful to students as they compare against actual JEE takers.

```javascript
// NTA JEE Main 2026 Official Percentile Lookup Table
// Source: NTA JEE Main 2026 Official Results
// Using upper bound of each range for lookup

const NTA_PERCENTILE_TABLE = {
  // Score ranges mapped to percentile (using upper bound of percentile range)
  300: 100.00,        // 300-281: 100 – 99.99989145
  281: 99.99989,
  280: 99.997394,     // 271-280: 99.994681 – 99.997394
  271: 99.994681,
  270: 99.994029,     // 263-270: 99.990990 – 99.994029
  263: 99.990990,
  262: 99.988819,     // 250-262: 99.977205 – 99.988819
  250: 99.975034,     // 241-250: 99.960163 – 99.975034
  241: 99.960163,
  240: 99.956364,     // 231-240: 99.934980 – 99.956364
  231: 99.934980,
  230: 99.928901,     // 221-230: 99.901113 – 99.928901
  221: 99.901113,
  220: 99.893732,     // 211-220: 99.851616 – 99.893732
  211: 99.851616,
  200: 99.782472,     // 191-200: 99.710831 – 99.782472
  191: 99.710831,
  190: 99.688579,     // 181-190: 99.597399 – 99.688579
  181: 99.597399,
  180: 99.573193,     // 171-180: 99.456939 – 99.573193
  171: 99.456939,
  170: 99.431214,     // 161-170: 99.272084 – 99.431214
  161: 99.272084,
  160: 99.239737,     // 151-160: 99.028614 – 99.239737
  151: 99.028614,
  150: 98.990296,     // 141-150: 98.732389 – 98.990296
  141: 98.732389,
  140: 98.666935,     // 131-140: 98.317414 – 98.666935
  131: 98.317414,
  130: 98.254132,     // 121-130: 97.811260 – 98.254132
  121: 97.811260,
  120: 97.685672,     // 111-120: 97.142937 – 97.685672
  111: 97.142937,
  110: 96.978272,     // 101-110: 96.204550 – 96.978272
  101: 96.204550,
  100: 96.064850,     // 91-100: 94.998594 – 96.064850
  91: 94.998594,
  90: 94.749479,      // 81-90: 93.471231 – 94.749479
  81: 93.471231,
  80: 93.152971,      // 71-80: 91.072128 – 93.152971
  71: 91.072128,
  70: 90.702200,      // 61-70: 87.512225 – 90.702200
  61: 87.512225,
  60: 86.907944,      // 51-60: 82.016062 – 86.907944
  51: 82.016062,
  50: 80.982153,      // 41-50: 73.287808 – 80.982153
  41: 73.287808,
  40: 71.302052,      // 31-40: 58.151490 – 71.302052
  31: 58.151490,
  30: 56.569310,      // 21-30: 37.694529 – 56.569310
  21: 37.694529,
  20: 33.229128,      // 11-20: 13.495849 – 33.229128
  11: 13.495849,
  10: 9.6954066,      // 0-10: 0.8435177 – 9.6954066
  0: 0.8435177
};

function getPercentile(score) {
  // Linear interpolation between known brackets
  const sortedScores = Object.keys(NTA_PERCENTILE_TABLE)
    .map(Number)
    .sort((a, b) => b - a);

  for (let i = 0; i < sortedScores.length - 1; i++) {
    const upper = sortedScores[i];
    const lower = sortedScores[i + 1];

    if (score >= lower && score <= upper) {
      const ratio = (score - lower) / (upper - lower);
      const lowerPercentile = NTA_PERCENTILE_TABLE[lower];
      const upperPercentile = NTA_PERCENTILE_TABLE[upper];
      return lowerPercentile + ratio * (upperPercentile - lowerPercentile);
    }
  }

  return score >= 300 ? 100.00 : 0.00;
}
```

**Benefits of NTA Percentile**:
- More meaningful to students (compares against real JEE takers)
- No dependency on app user base size
- Consistent and trusted reference point
- Helps students understand actual JEE standing

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

### 11.3 Question Retirement Strategy

> **Policy**: Auto-retire questions after 100 uses to maintain freshness and prevent over-exposure.

```javascript
// In mockTestResponseService.js - called after test submission
async function updateQuestionUsageAndRetirement(questionIds) {
  const RETIREMENT_THRESHOLD = 100;
  const batch = db.batch();

  for (const questionId of questionIds) {
    const questionRef = db.collection('mock_test_question_pool').doc(questionId);
    const question = await questionRef.get();

    if (!question.exists) continue;

    const currentUsage = question.data().mock_test_metadata?.usage_count || 0;
    const newUsage = currentUsage + 1;

    if (newUsage >= RETIREMENT_THRESHOLD) {
      // Retire the question
      batch.update(questionRef, {
        'mock_test_metadata.usage_count': newUsage,
        'mock_test_metadata.retired': true,
        'mock_test_metadata.retirement_reason': 'usage_threshold',
        'mock_test_metadata.retired_at': admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`Retired question ${questionId} after ${newUsage} uses`);
    } else {
      // Just increment usage
      batch.update(questionRef, {
        'mock_test_metadata.usage_count': newUsage,
        'mock_test_metadata.last_used_at': admin.firestore.FieldValue.serverTimestamp()
      });
    }
  }

  await batch.commit();
}
```

**Retirement Reasons**:
- `usage_threshold` - Used 100+ times
- `quality_issue` - Manual retirement due to errors found
- `outdated` - Syllabus/format changes

**Pool Health Monitoring**:
```javascript
// Weekly check via cron
async function checkPoolHealth() {
  const stats = await db.collection('mock_test_question_pool')
    .where('mock_test_metadata.retired', '==', false)
    .get();

  const bySubject = { physics: 0, chemistry: 0, mathematics: 0 };

  stats.forEach(doc => {
    const subject = doc.data().subject.toLowerCase();
    bySubject[subject]++;
  });

  // Alert if any subject drops below 150 active questions
  const MIN_POOL_SIZE = 150;
  for (const [subject, count] of Object.entries(bySubject)) {
    if (count < MIN_POOL_SIZE) {
      await alertLowPoolSize(subject, count, MIN_POOL_SIZE);
    }
  }
}
```

### 11.4 Error Handling

#### Chunk Load Failures

```dart
// In MockTestQuestionLoader (mobile)
Future<List<MockTestQuestion>> _loadChunk(int chunkIndex) async {
  try {
    final chunk = await _api.getMockTestChunk(mockTestId, chunkIndex);
    return chunk;
  } catch (e) {
    // Log error for monitoring
    await _analyticsService.logError('chunk_load_failure', {
      'mock_test_id': mockTestId,
      'chunk_index': chunkIndex,
      'error': e.toString(),
    });

    // Alert backend for investigation
    await _api.reportChunkLoadFailure(mockTestId, chunkIndex, e.toString());

    // Show user-friendly error with retry option
    throw MockTestLoadException(
      message: 'Unable to load questions ${chunkIndex * 15 + 1}-${(chunkIndex + 1) * 15}. '
               'Please check your internet connection.',
      chunkIndex: chunkIndex,
      isRetryable: true,
      originalError: e,
    );
  }
}
```

**UI Treatment for Chunk Errors**:

```dart
// In MockTestQuestionScreen
void _handleChunkError(MockTestLoadException error) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('Loading Error'),
      content: Text(error.message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _retryChunkLoad(error.chunkIndex);
          },
          child: Text('Retry'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _skipToNextChunk(error.chunkIndex);
          },
          child: Text('Skip to Next Section'),
        ),
      ],
    ),
  );
}
```

**Backend Error Tracking**:

```javascript
// Log chunk failures for monitoring
async function reportChunkLoadFailure(mockTestId, chunkIndex, errorMessage) {
  await db.collection('error_logs').add({
    type: 'mock_test_chunk_failure',
    mock_test_id: mockTestId,
    chunk_index: chunkIndex,
    error_message: errorMessage,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    severity: 'high' // Chunk failures are critical
  });

  // Alert if multiple failures in short time
  const recentFailures = await db.collection('error_logs')
    .where('type', '==', 'mock_test_chunk_failure')
    .where('timestamp', '>', new Date(Date.now() - 15 * 60 * 1000)) // Last 15 min
    .get();

  if (recentFailures.size >= 5) {
    await sendSlackAlert('Multiple mock test chunk failures detected');
  }
}
```

### 12. Testing Requirements

#### 12.1 Backend Unit Tests

**File**: `backend/tests/services/mockTestService.test.js`

```javascript
describe('MockTestService', () => {
  describe('generateMockTest', () => {
    it('should generate 90 questions (30 per subject)', async () => {});
    it('should include 20 MCQ + 10 NVQ per subject', async () => {});
    it('should respect chapter quotas from jee_chapter_weightage.js', async () => {});
    it('should not repeat questions from recent tests (60-day lookback)', async () => {});
    it('should fail if user has reached tier limit', async () => {});
    it('should fail if user has not completed assessment', async () => {});
    it('should rotate between available templates', async () => {});
  });
});
```

**File**: `backend/tests/services/mockTestResponseService.test.js`

```javascript
describe('MockTestResponseService', () => {
  describe('calculateMockTestScore', () => {
    it('should award +4 for correct MCQ', async () => {});
    it('should deduct -1 for incorrect MCQ', async () => {});
    it('should award +4 for correct NVQ', async () => {});
    it('should award 0 for incorrect NVQ (no negative marking)', async () => {});
    it('should award 0 for unattempted questions', async () => {});
    it('should calculate max score as 300 for 75 questions', async () => {});
    it('should calculate accuracy correctly', async () => {});
  });

  describe('submitMockTest', () => {
    it('should validate server-side timing', async () => {});
    it('should flag submissions exceeding allowed time', async () => {});
    it('should update user stats after submission', async () => {});
    it('should update chapter thetas after submission', async () => {});
    it('should update subject thetas after submission', async () => {});
    it('should increment question usage counts', async () => {});
    it('should retire questions after 100 uses', async () => {});
  });

  describe('getPercentile', () => {
    it('should return 100 for score of 300', async () => {});
    it('should return ~99.99 for score of 280', async () => {});
    it('should return ~90 for score of 200', async () => {});
    it('should interpolate between known brackets', async () => {});
  });
});
```

**File**: `backend/tests/services/mockTestAnalyticsService.test.js`

```javascript
describe('MockTestAnalyticsService', () => {
  describe('generatePerformanceReport', () => {
    it('should calculate subject-wise scores', async () => {});
    it('should calculate chapter-wise accuracy', async () => {});
    it('should identify top 5 weak chapters', async () => {});
    it('should calculate time management stats', async () => {});
  });
});
```

**File**: `backend/tests/middleware/mockTestRateLimiter.test.js`

```javascript
describe('MockTestRateLimiter', () => {
  it('should allow first request', async () => {});
  it('should block second request within 5 minutes', async () => {});
  it('should allow request after 5 minutes', async () => {});
});
```

#### 12.2 Backend Integration Tests

**File**: `backend/tests/integration/mockTests.integration.test.js`

```javascript
describe('Mock Test API Integration', () => {
  describe('POST /api/mock-tests/generate', () => {
    it('should generate mock test for authenticated user', async () => {});
    it('should return 401 for unauthenticated request', async () => {});
    it('should return 403 if tier limit reached', async () => {});
    it('should return 403 if assessment not completed', async () => {});
    it('should return 429 if rate limited', async () => {});
  });

  describe('POST /api/mock-tests/:id/submit', () => {
    it('should accept valid submission', async () => {});
    it('should calculate score correctly', async () => {});
    it('should return percentile in response', async () => {});
    it('should update user document with stats', async () => {});
  });

  describe('GET /api/mock-tests/active', () => {
    it('should return in-progress test if exists', async () => {});
    it('should return null if no active test', async () => {});
  });

  describe('GET /api/mock-tests/history', () => {
    it('should return history within tier retention limit', async () => {});
    it('should respect days parameter based on tier', async () => {});
  });

  describe('Full Flow', () => {
    it('should complete generate → answer → submit → review flow', async () => {});
  });
});
```

#### 12.3 Mobile Widget Tests (Flutter)

**File**: `mobile/test/widgets/mock_test/mock_test_home_card_test.dart`

```dart
void main() {
  group('MockTestHomeCard', () {
    testWidgets('shows "Start Mock Test" when available', (tester) async {});
    testWidgets('shows "Complete Assessment" when locked', (tester) async {});
    testWidgets('shows "Continue Mock Test" when in progress', (tester) async {});
    testWidgets('shows remaining count for tier', (tester) async {});
    testWidgets('shows upgrade prompt when limit reached', (tester) async {});
  });
}
```

**File**: `mobile/test/widgets/mock_test/question_navigator_widget_test.dart`

```dart
void main() {
  group('QuestionNavigatorWidget', () {
    testWidgets('displays 90 question buttons', (tester) async {});
    testWidgets('shows gray for not visited', (tester) async {});
    testWidgets('shows red for not answered', (tester) async {});
    testWidgets('shows green for answered', (tester) async {});
    testWidgets('shows purple for marked for review', (tester) async {});
    testWidgets('shows purple+green for answered and marked', (tester) async {});
    testWidgets('highlights current question with blue border', (tester) async {});
    testWidgets('navigates to question on tap', (tester) async {});
  });
}
```

**File**: `mobile/test/widgets/mock_test/question_state_indicator_test.dart`

```dart
void main() {
  group('QuestionStateIndicator', () {
    testWidgets('renders correct color for each state', (tester) async {});
  });
}
```

#### 12.4 Mobile Provider Tests

**File**: `mobile/test/providers/mock_test_provider_test.dart`

```dart
void main() {
  group('MockTestProvider', () {
    test('initializes with empty state', () {});
    test('loads mock test and sets questions', () {});
    test('updates question state when visited', () {});
    test('updates question state when answered', () {});
    test('updates question state when marked for review', () {});
    test('clears answer correctly', () {});
    test('clears mark correctly', () {});
    test('navigates to next question', () {});
    test('navigates to previous question', () {});
    test('filters questions by subject', () {});
    test('calculates progress correctly', () {});
    test('handles pause correctly', () {});
    test('handles resume correctly', () {});
    test('auto-saves on answer selection', () {});
    test('auto-saves on navigation', () {});
    test('loads chunks on demand', () {});
    test('prefetches next chunk', () {});
  });
}
```

**File**: `mobile/test/services/mock_test_question_loader_test.dart`

```dart
void main() {
  group('MockTestQuestionLoader', () {
    test('loads chunk 0 for questions 1-15', () {});
    test('loads chunk 1 for questions 16-30', () {});
    test('caches loaded chunks', () {});
    test('prefetches next chunk', () {});
    test('handles chunk load failure gracefully', () {});
    test('allows retry on failure', () {});
  });
}
```

#### 12.5 Mobile Integration Tests

**File**: `mobile/integration_test/mock_test_flow_test.dart`

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Mock Test Flow', () {
    testWidgets('complete mock test flow', (tester) async {
      // 1. Tap Mock Test card on home screen
      // 2. Verify selection screen shows
      // 3. Tap "Start Mock Test"
      // 4. Verify question screen loads
      // 5. Answer a few questions
      // 6. Navigate between questions
      // 7. Mark question for review
      // 8. Submit test
      // 9. Verify results screen shows score
      // 10. Tap "Review Questions"
      // 11. Verify review screen works
    });

    testWidgets('resume in-progress test', (tester) async {
      // 1. Start mock test
      // 2. Answer some questions
      // 3. Background app (simulate)
      // 4. Return to app
      // 5. Verify "Continue" prompt
      // 6. Verify answers preserved
    });

    testWidgets('handles offline gracefully', (tester) async {
      // 1. Start mock test
      // 2. Go offline
      // 3. Answer questions
      // 4. Verify local save works
      // 5. Go online
      // 6. Submit test
      // 7. Verify sync works
    });
  });
}
```

#### 12.6 Performance Tests

- Mock test generation time: **< 2 seconds** for 90 questions
- Chunk loading time: **< 500ms** per chunk (15 questions)
- Analytics calculation time: **< 1 second**
- Large response submission: **< 3 seconds**
- Image prefetch: **< 10 seconds** for all 90 question images

#### 12.7 Test Data Requirements

Before running tests, ensure:
- [ ] 2-3 mock test templates exist in `mock_test_templates` collection
- [ ] Test user accounts with different tiers (Free, Pro, Ultra)
- [ ] Test user with completed assessment
- [ ] Test user without completed assessment

### 13. Implementation Phases

#### Phase 0: CREATE MOCK TEST DATA (FIRST!)

> **CRITICAL**: This phase must be completed before ANY code is written. We cannot build or test the feature without mock test data.

**Current State**: 0 mock test templates exist. We need 2-3 templates.

**Step 0.1: Verify Question Bank Has Enough Questions**

**Script**: `backend/scripts/verifyMockTestReadiness.js`

```bash
# Run this first
cd backend && node scripts/verifyMockTestReadiness.js
```

```javascript
async function verifyMockTestReadiness() {
  const requirements = {
    minQuestionsPerSubject: 90,   // 30 × 3 templates
    minMCQPerSubject: 60,         // 20 MCQ × 3 templates
    minNVQPerSubject: 30,         // 10 NVQ × 3 templates
  };

  const counts = await countQuestionsBySubjectAndType();

  console.log('Question Bank Status for Mock Tests:');
  console.log('=====================================');

  let ready = true;
  for (const subject of ['Physics', 'Chemistry', 'Mathematics']) {
    const mcq = counts[subject]?.mcq_single || 0;
    const nvq = counts[subject]?.numerical || 0;

    console.log(`${subject}:`);
    console.log(`  MCQ: ${mcq}/${requirements.minMCQPerSubject} ${mcq >= requirements.minMCQPerSubject ? '✓' : '✗'}`);
    console.log(`  NVQ: ${nvq}/${requirements.minNVQPerSubject} ${nvq >= requirements.minNVQPerSubject ? '✓' : '✗'}`);

    if (mcq < requirements.minMCQPerSubject || nvq < requirements.minNVQPerSubject) {
      ready = false;
    }
  }

  console.log('=====================================');
  console.log(ready ? '✓ Ready for Mock Tests!' : '✗ Need more questions');
  return ready;
}
```

**Template Creation Script**: `backend/scripts/createMockTestTemplates.js`

```javascript
/**
 * Creates 2-3 pre-curated mock test templates from existing questions collection.
 * Each template: 90 questions (30 per subject, 20 MCQ + 10 NVQ each)
 * Questions are selected based on chapter weights from jee_chapter_weightage.js
 */
async function createMockTestTemplates(templateCount = 3) {
  const templates = [];

  for (let templateNum = 1; templateNum <= templateCount; templateNum++) {
    const template = {
      template_id: `jee_main_template_${templateNum}`,
      exam_type: 'jee_main',
      version: '1.0',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      question_ids: [],
      questions_by_subject: { physics: [], chemistry: [], mathematics: [] }
    };

    for (const subject of ['Physics', 'Chemistry', 'Mathematics']) {
      // Get chapter quotas based on JEE weights
      const quotas = calculateChapterQuotas(subject, 30);

      // Select questions avoiding overlap with previous templates
      const selectedQuestions = await selectQuestionsWithQuotas({
        subject,
        mcqCount: 20,
        nvqCount: 10,
        chapterQuotas: quotas,
        excludeQuestionIds: templates.flatMap(t => t.question_ids)
      });

      template.question_ids.push(...selectedQuestions.map(q => q.question_id));
      template.questions_by_subject[subject.toLowerCase()] = selectedQuestions;
    }

    // Save template to Firestore
    await db.collection('mock_test_templates').doc(template.template_id).set(template);
    templates.push(template);

    console.log(`Created template ${templateNum}: ${template.question_ids.length} questions`);
  }

  return templates;
}
```

**Chapter Quota Calculation** (using existing `jee_chapter_weightage.js`):

```javascript
const { JEE_CHAPTER_WEIGHTS } = require('../../docs/engine/jee_chapter_weightage');

function calculateChapterQuotas(subject, totalQuestions = 30) {
  const subjectChapters = Object.entries(JEE_CHAPTER_WEIGHTS)
    .filter(([key]) => key.startsWith(subject.toLowerCase()))
    .map(([key, weight]) => ({ chapter_key: key, weight }));

  const totalWeight = subjectChapters.reduce((sum, ch) => sum + ch.weight, 0);

  return subjectChapters.map(ch => ({
    chapter_key: ch.chapter_key,
    quota: Math.max(1, Math.round((ch.weight / totalWeight) * totalQuestions)),
    weight: ch.weight
  }));
}
```

**Step 0.2: Create Mock Test Templates**

**Script**: `backend/scripts/createMockTestTemplates.js`

```bash
# Run after verifying question bank
cd backend && node scripts/createMockTestTemplates.js
```

**Phase 0 Deliverables (MUST COMPLETE BEFORE PHASE 1)**:
- [ ] Run `verifyMockTestReadiness.js` - confirm question count
- [ ] Run `createMockTestTemplates.js` - create 2-3 templates
- [ ] Verify templates in Firebase console: `mock_test_templates` collection
- [ ] Each template has 90 questions (30 per subject, 20 MCQ + 10 NVQ)

---

#### Phase 1A: Backend Services + Tests

**Backend Code**:
- [ ] Create `mockTestService.js` - Generation from templates
- [ ] Create `mockTestResponseService.js` - Submission, scoring (NVQ no-negative), user stats update
- [ ] Create `mockTestAnalyticsService.js` - NTA percentile, subject/chapter breakdown
- [ ] Create API routes: generate, submit, get-active, pause, resume, abandon
- [ ] Add `mockTestRateLimiter.js` middleware
- [ ] Add server-side timer validation

**Backend Tests** (run with `npm test`):
- [ ] `mockTestService.test.js` - Generation logic tests
- [ ] `mockTestResponseService.test.js` - Scoring algorithm tests (MCQ -1, NVQ 0)
- [ ] `mockTestAnalyticsService.test.js` - Percentile calculation tests
- [ ] `mockTestRateLimiter.test.js` - Rate limiting tests
- [ ] `mockTests.integration.test.js` - API integration tests

---

#### Phase 1B: Mobile UI + Tests

**Mobile Code**:
- [ ] Add Mock Tests card to home screen (above Snap & Solve, below Focus Chapter)
- [ ] Create `mock_test_selection_screen.dart`
- [ ] Create `mock_test_question_screen.dart` with chunked loading
- [ ] Create `MockTestProvider` with question state management
- [ ] Create `MockTestQuestionLoader` for chunk loading
- [ ] Implement JEE-accurate question states (Gray/Red/Green/Purple/Purple+Green)
- [ ] Reuse QuestionCardWidget, DetailedExplanationWidget
- [ ] Local storage service for offline-first

**Mobile Widget Tests** (run with `flutter test`):
- [ ] `mock_test_home_card_test.dart`
- [ ] `question_navigator_widget_test.dart`
- [ ] `question_state_indicator_test.dart`

**Mobile Provider Tests**:
- [ ] `mock_test_provider_test.dart`
- [ ] `mock_test_question_loader_test.dart`

---

#### Phase 1C: Results, History & Integration Tests

**Mobile Code**:
- [ ] Create `mock_test_results_screen.dart` with NTA percentile
- [ ] Update `mock_test_history_screen.dart` (replace "Coming Soon")
- [ ] Create `mock_test_review_screen.dart` (reuse QuestionReviewScreen)

**Integration Tests** (run with `flutter test integration_test/`):
- [ ] `mock_test_flow_test.dart` - Complete end-to-end flow
- [ ] Test: generate → answer → submit → view results → review questions
- [ ] Test: resume in-progress test
- [ ] Test: offline handling

**Acceptance Criteria for Phase 1 Complete**:
- [ ] All backend unit tests pass
- [ ] All mobile widget tests pass
- [ ] Integration test completes successfully
- [ ] Manual QA: Complete a full mock test on real device

---

#### Phase 2: AI Question Pool Generation (Parallel/Future)

- [ ] Create `generateMockTestQuestionPool.js` batch script
- [ ] Implement 5-stage validation pipeline
- [ ] Generate 900 questions (300/subject)
- [ ] IRT parameter calibration

---

#### Phase 3: Enhanced Analytics

- [ ] Subject-wise and chapter-wise breakdown UI
- [ ] Time management analysis
- [ ] Recommendations engine
- [ ] Progress tracking across multiple tests

---

#### Phase 4: Polish

- [ ] Pause functionality (2 pauses, 5 min each)
- [ ] Question flagging improvements
- [ ] Comparison with previous attempts
- [ ] Performance optimizations

---

#### Phase 5: JEE Advanced (DEFERRED)

- [ ] 2-paper format support
- [ ] Multi-correct MCQ with partial marking
- [ ] Matrix matching questions
- [ ] Paper 1/Paper 2 break handling

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
- `backend/src/services/mockTestService.js` - Test generation & lifecycle
- `backend/src/services/mockTestResponseService.js` - Submission, scoring, user stats update
- `backend/src/services/mockTestAnalyticsService.js` - Performance reports, NTA percentile
- `backend/src/services/mockTestQuestionPoolService.js` - Question pool management (Phase 2+)
- `backend/src/services/mockTestQuestionValidationService.js` - 5-stage validation pipeline (Phase 2+)
- `backend/src/services/testHistoryService.js` - Unified history (Mock + Daily + Chapter)
- `backend/src/services/baseTestService.js` - Abstract base for PYQ reuse (future)

**New Routes**:
- `backend/src/routes/mockTests.js` - Mock test endpoints (generate, submit, active, pause, resume, abandon)
- `backend/src/routes/history.js` - Unified history endpoints

**New Middleware**:
- `backend/src/middleware/mockTestRateLimiter.js` - Rate limiting (1 gen per 5 min)
- `backend/src/middleware/mockTestLimits.js` - Tier-based gating
- `backend/src/middleware/featureUnlock.js` - Unlock criteria check

**Scripts** (Phase 1):
- `backend/scripts/verifyMockTestReadiness.js` - Check question bank has enough questions
- `backend/scripts/createMockTestTemplates.js` - Create 2-3 templates from existing questions

**Scripts** (Phase 2+):
- `backend/scripts/generateMockTestQuestionPool.js` - AI batch generation (cron)

**Config Updates**:
- `backend/firebase/firestore.rules` - mock_tests, mock_test_templates, mock_test_question_pool
- `backend/firebase/firestore.indexes.json` - Required indexes

### Mobile

**New Models** (PYQ-ready architecture):
- `mobile/lib/models/base_test_session.dart` - Abstract base
- `mobile/lib/models/mock_test.dart` - Mock test specific
- `mobile/lib/models/mock_test_response.dart` - Response model
- `mobile/lib/models/mock_test_question_state.dart` - Enum for JEE CBT states

**New Providers**:
- `mobile/lib/providers/mock_test_provider.dart` - State management with chunked loading

**New Screens**:
- `mobile/lib/screens/mock_test/mock_test_selection_screen.dart` - Exam selection, limits
- `mobile/lib/screens/mock_test/mock_test_question_screen.dart` - 90-question interface with JEE states
- `mobile/lib/screens/mock_test/mock_test_results_screen.dart` - Results, NTA percentile, analytics
- `mobile/lib/screens/mock_test/mock_test_review_screen.dart` - 90-question review (reuses widgets)

**New Widgets**:
- `mobile/lib/widgets/mock_test/mock_test_home_card.dart` - Home screen entry card
- `mobile/lib/widgets/mock_test/question_navigator_widget.dart` - 90-question navigation panel
- `mobile/lib/widgets/mock_test/question_state_indicator.dart` - JEE CBT state colors

**New Services**:
- `mobile/lib/services/mock_test_api_service.dart` - API client with chunk loading
- `mobile/lib/services/mock_test_local_storage_service.dart` - Offline-first with chunked cache
- `mobile/lib/services/mock_test_question_loader.dart` - Chunked question loading with prefetch

**Modifications**:
- `mobile/lib/screens/home_screen.dart` - Add Mock Tests card (above Snap & Solve)
- `mobile/lib/screens/history/mock_test_history_screen.dart` - Replace "Coming Soon" placeholder
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
| **Scope** | **JEE Main only** (JEE Advanced deferred due to complexity) |
| Question Source | **Hybrid**: Phase 1 uses existing questions, Phase 2+ adds AI-generated pool |
| AI Provider | **Claude** (already integrated via `claude.js`) |
| **NVQ Marking** | **+4/0** (no negative marking for Numerical, matches actual JEE) |
| **Percentile** | **NTA Official Brackets** (not app-calculated, more meaningful to students) |
| **Question States** | **Match JEE CBT exactly**: Gray/Red/Green/Purple/Purple+Green |
| **Chapter Distribution** | **Explicit quotas** from `jee_chapter_weightage.js` |
| **Document Storage** | **Chunked subcollection** (15 questions/chunk, avoids size limits) |
| **Timer Validation** | **Server-side** on submission (prevent manipulation) |
| **Rate Limiting** | **1 generation per 5 minutes** per user |
| **Question Retirement** | **Auto-retire after 100 uses** |
| **Error Handling** | **User notification + backend alert** for chunk failures |
| **Home Screen Placement** | **Primary feature**: Above Snap & Solve, below Focus Chapter |
| **Phase 1 Strategy** | **Use existing questions** to create 2-3 templates (launch faster) |
| Pause Behavior | Timer **stops** during pause (2 pauses max, 5 min each) |
| Auto-Save Strategy | **Event-driven** (on user actions, not time-based) |
| Auto-Submit | Warn at 0, allow continue but mark as overtime |
| Implementation Timing | **After question bank reload** completes |
| LaTeX Handling | Store both Unicode + original LaTeX (generate Unicode at pool creation) |
| Tier Limits | Free: 1/month, Pro: 5/month, Ultra: Unlimited |
| Feature Unlock | After **assessment completed** (immediate access for eager students) |
| History Retention | Free: 7 days, Pro: 30 days, Ultra: Unlimited |
| Review All Questions | **Yes** - Full 90-question review with detailed explanations |
| Component Reuse | **Maximize** - QuestionCardWidget, DetailedExplanationWidget, ReviewScreen |
| Image Handling | **Reuse existing** ImageCacheService + prefetch on test load |
| PYQ Architecture | Design with **abstract base classes** for future PYQ reuse |
| Abandoned Tests | **Student-friendly**: Allow resume within 24hrs, only explicit abandon counts |
| **Post-Test Updates** | Update user stats, accuracy by subject/chapter, and theta values |

*All decisions finalized - plan ready for implementation (JEE Main only, Phase 1 with existing questions).*
