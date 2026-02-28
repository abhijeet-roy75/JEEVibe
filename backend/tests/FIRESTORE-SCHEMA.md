# Firestore Database Schema Reference

**Purpose:** Complete reference for all Firestore collections and document structures used in JEEVibe backend tests.

**Last Updated:** 2026-02-27

---

## Table of Contents

1. [User Collection](#user-collection)
2. [User Subcollections](#user-subcollections)
3. [Question Collections](#question-collections)
4. [Tier & Configuration](#tier--configuration)
5. [Mock Tests](#mock-tests)
6. [Cognitive Mastery](#cognitive-mastery)
7. [Admin & Metrics](#admin--metrics)

---

## User Collection

**Path:** `users/{userId}`

### Document Structure

```javascript
{
  // ===== IDENTITY =====
  uid: string,                          // Firebase Auth UID
  phoneNumber: string,                  // +1234567890 format
  email: string | null,                 // Optional email
  firstName: string,                    // User's first name
  lastName: string,                     // User's last name
  displayName: string,                  // Full name
  photoURL: string | null,              // Profile photo URL

  // ===== ACADEMIC INFO =====
  class: "11" | "12",                   // Current class
  targetExam: "JEE Main" | "JEE Advanced",
  targetYear: number,                   // Year of JEE exam (e.g., 2027)
  isEnrolledInCoaching: boolean,        // Whether student attends coaching

  // ===== THETA (ABILITY SCORES) =====
  overall_theta: number,                // Overall ability [-3, +3]
  overall_percentile: number,           // Overall percentile [0, 100]
  overall_se: number,                   // Overall standard error [0.15, 0.6]

  theta_by_subject: {
    physics: {
      theta: number,                    // Subject-level theta
      se: number,                       // Subject-level standard error
      percentile: number,               // Subject-level percentile
      chapters_tested: number,          // Number of chapters attempted
      questions_answered: number        // Total questions in this subject
    },
    chemistry: { /* same as physics */ },
    mathematics: { /* same as physics */ }
  },

  theta_by_chapter: {
    "physics_kinematics": {
      theta: number,                    // Chapter-level theta
      se: number,                       // Chapter-level standard error
      percentile: number,               // Chapter-level percentile
      attempts: number,                 // Number of questions attempted
      correct: number,                  // Number of correct answers
      total: number,                    // Total questions in chapter
      last_updated: Timestamp,          // Last time this chapter was practiced
      accuracy: number                  // Percentage accuracy (correct/total)
    },
    "chemistry_organic_chemistry": { /* same structure */ }
    // ... more chapters
  },

  // ===== SUBSCRIPTION =====
  subscription: {
    tier: "free" | "pro" | "ultra",     // Current tier
    status: "active" | "inactive" | "expired" | "trial",
    override: "free" | "pro" | "ultra" | null,  // Admin override (beta testers)

    // TRIAL
    trial: {
      is_active: boolean,               // Whether trial is currently active
      tier: "pro" | "ultra",            // Trial tier level
      starts_at: Timestamp,             // Trial start date
      ends_at: Timestamp,               // Trial end date
      days_remaining: number            // Computed field (ends_at - now)
    },

    // PAID SUBSCRIPTION
    razorpay_subscription_id: string | null,  // Razorpay sub ID (if paid)
    plan_id: string | null,             // Plan ID (monthly/quarterly/annual)
    current_start: Timestamp | null,    // Current period start
    current_end: Timestamp | null,      // Current period end
    auto_renew: boolean,                // Whether subscription auto-renews

    // METADATA
    created_at: Timestamp,
    updated_at: Timestamp
  },

  // ===== PROGRESS TRACKING =====
  completed_quiz_count: number,         // Total daily quizzes completed
  completed_chapter_practice_count: number,  // Total chapter practice sessions
  completed_mock_test_count: number,    // Total mock tests completed
  total_questions_solved: number,       // Total questions across all features

  // ===== ASSESSMENT =====
  assessment: {
    completed_at: Timestamp,            // When initial assessment was completed
    initial_theta: number,              // Initial theta from assessment
    initial_percentile: number,         // Initial percentile
    score: number,                      // Raw score (out of 30)
    accuracy: number                    // Percentage accuracy
  },

  // ===== TIMESTAMPS =====
  created_at: Timestamp,
  updated_at: Timestamp,
  last_active_at: Timestamp,            // Last time user was active

  // ===== FEATURE FLAGS =====
  feature_flags: {
    show_cognitive_mastery: boolean     // Whether to show cognitive mastery features
  }
}
```

---

## User Subcollections

### 1. Daily Usage Tracking

**Path:** `users/{userId}/daily_usage/{YYYY-MM-DD}`

```javascript
{
  date: string,                         // "2026-02-27" format
  usage: {
    snap_solve: number,                 // Number of snaps used today
    daily_quiz: number,                 // Number of quizzes completed today
    chapter_practice: number,           // Number of chapters practiced today
    ai_tutor_messages: number,          // Number of AI tutor messages today
    mock_tests: number                  // Number of mock tests started today
  },
  created_at: Timestamp,
  updated_at: Timestamp
}
```

### 2. Daily Quizzes

**Path:** `users/{userId}/daily_quizzes/{quizId}`

```javascript
{
  quiz_id: string,                      // Unique quiz ID
  started_at: Timestamp,
  completed_at: Timestamp | null,

  // QUESTIONS
  questions: [
    {
      question_id: string,
      question_type: "mcq_single" | "numerical",
      subject: string,
      chapter_key: string,
      difficulty_b: number,             // IRT difficulty parameter
      discrimination_a: number,         // IRT discrimination parameter
      guessing_c: number,               // IRT guessing parameter
      position: number,                 // Question position in quiz (1-5)
      selected_answer: string | null,   // User's answer
      correct_answer: string,           // Correct answer
      is_correct: boolean,              // Whether user answered correctly
      time_spent_seconds: number,       // Time spent on this question
      theta_before: number,             // Theta before this question
      theta_after: number               // Theta after this question
    }
    // ... 4 more questions (5 total)
  ],

  // RESULTS
  score: number,                        // Number of correct answers (0-5)
  accuracy: number,                     // Percentage accuracy
  theta_change: number,                 // Overall theta change from this quiz

  // METADATA
  is_completed: boolean,
  created_at: Timestamp,
  updated_at: Timestamp
}
```

### 3. Chapter Practice Sessions

**Path:** `users/{userId}/chapter_sessions/{sessionId}`

```javascript
{
  session_id: string,                   // Unique session ID
  chapter_key: string,                  // "physics_kinematics"
  subject: string,                      // "physics"
  tier: "free" | "pro" | "ultra",       // User's tier at session creation
  question_count: number,               // Number of questions (5 for Free, 15 for Pro/Ultra)

  started_at: Timestamp,
  completed_at: Timestamp | null,

  // QUESTIONS
  questions: [
    {
      question_id: string,
      question_type: "mcq_single" | "numerical",
      difficulty_b: number,
      discrimination_a: number,
      guessing_c: number,
      position: number,
      selected_answer: string | null,
      correct_answer: string,
      is_correct: boolean,
      time_spent_seconds: number,
      theta_before: number,
      theta_after: number
    }
    // ... more questions (5 or 15 depending on tier)
  ],

  // RESULTS
  score: number,                        // Correct answers
  accuracy: number,                     // Percentage
  theta_change: number,                 // Theta improvement

  // WEAK SPOT DETECTION (if feature enabled)
  weak_spot: {
    node_id: string,                    // Atlas node ID
    title: string,                      // "Projectile Motion"
    score: number,                      // Weakness score [0, 1]
    severity_level: "high" | "medium" | "low",
    node_state: "detected" | "improving" | "mastered",
    capsule_id: string                  // Associated learning capsule ID
  } | null,

  // METADATA
  is_completed: boolean,
  invalidated: boolean,                 // True if session was invalidated
  invalidation_reason: string | null,   // "exceeds_tier_limit" | "tier_downgrade"
  created_at: Timestamp,
  updated_at: Timestamp
}
```

### 4. Mock Test Sessions

**Path:** `users/{userId}/mock_test_sessions/{sessionId}`

```javascript
{
  session_id: string,
  template_id: string,                  // Mock test template ID

  started_at: Timestamp,
  completed_at: Timestamp | null,
  duration_seconds: number,             // Total time (max 10800 = 3 hours)

  // QUESTIONS (90 total: 30 Physics, 30 Chemistry, 30 Maths)
  questions: [
    {
      question_number: number,          // 1-90
      question_id: string,
      question_type: "mcq_single" | "numerical",
      subject: "physics" | "chemistry" | "mathematics",
      chapter_key: string,
      difficulty_b: number,
      discrimination_a: number,

      // USER INTERACTION
      selected_answer: string | null,
      correct_answer: string,
      is_correct: boolean,
      time_spent_seconds: number,

      // QUESTION STATE (JEE-style states)
      state: "not_visited" | "not_answered" | "answered" | "marked_for_review" | "answered_and_marked",
      visited_at: Timestamp | null,     // When question was first opened
      last_updated_at: Timestamp | null // Last time state changed
    }
    // ... 89 more questions
  ],

  // SCORING
  total_marks: number,                  // Out of 300 (90 * 4 - incorrect * 1)
  correct_answers: number,              // Count of correct
  incorrect_answers: number,            // Count of incorrect
  unattempted: number,                  // Count of unattempted

  subject_scores: {
    physics: { marks: number, correct: number, incorrect: number, unattempted: number },
    chemistry: { /* same */ },
    mathematics: { /* same */ }
  },

  // NTA PERCENTILE
  nta_percentile: number,               // Percentile based on NTA score lookup

  // METADATA
  is_completed: boolean,
  tier_at_submission: "free" | "pro" | "ultra",
  created_at: Timestamp,
  updated_at: Timestamp
}
```

### 5. Snap History

**Path:** `users/{userId}/snap_history/{snapId}`

```javascript
{
  snap_id: string,
  image_url: string,                    // Firebase Storage URL

  // OCR RESULTS
  ocr_text: string,                     // Raw OCR output
  detected_question: string,            // Cleaned question text

  // AI SOLUTION
  solution: {
    answer: string,                     // Final answer
    steps: [
      {
        step_number: number,
        description: string,
        formula: string | null
      }
    ],
    key_concepts: string[],             // Key concepts used
    difficulty: "easy" | "medium" | "hard"
  },

  // METADATA
  subject: string | null,               // Auto-detected subject
  chapter_key: string | null,           // Auto-detected chapter
  processing_time_ms: number,           // Time to generate solution

  // THETA UPDATE
  theta_multiplier: 0.4,                // Snap solve gets 40% theta weight
  theta_change: number,

  created_at: Timestamp
}
```

### 6. Theta Snapshots

**Path:** `users/{userId}/theta_snapshots/{snapshotId}`

```javascript
{
  snapshot_id: string,
  taken_at: Timestamp,

  overall_theta: number,
  overall_percentile: number,
  overall_se: number,
  overall_accuracy: number,             // Percentage accuracy across all questions

  theta_by_subject: {
    physics: { theta: number, se: number, percentile: number, accuracy: number },
    chemistry: { /* same */ },
    mathematics: { /* same */ }
  },

  // USAGE AT TIME OF SNAPSHOT
  completed_quiz_count: number,
  completed_chapter_practice_count: number,
  total_questions_solved: number,

  created_at: Timestamp
}
```

### 7. Streak Data

**Path:** `users/{userId}/streaks/current`

```javascript
{
  current_streak: number,               // Days in current streak
  longest_streak: number,               // All-time longest streak
  last_practice_date: Timestamp,        // Last date of practice
  streak_start_date: Timestamp,         // When current streak started

  // HISTORY
  streak_history: [
    {
      start_date: Timestamp,
      end_date: Timestamp,
      duration_days: number
    }
  ],

  updated_at: Timestamp
}
```

---

## Question Collections

### 1. Main Question Bank

**Path:** `questions/{questionId}`

```javascript
{
  question_id: string,                  // "PHY_KINE_001"
  subject: "physics" | "chemistry" | "mathematics",
  chapter: string,                      // "Kinematics"
  chapter_key: string,                  // "physics_kinematics"

  // QUESTION TYPE
  question_type: "mcq_single" | "numerical",
  difficulty: "easy" | "medium" | "hard",

  // CONTENT
  question_text: string,                // Plain text
  question_text_html: string,           // HTML with LaTeX
  question_text_latex: string,          // LaTeX-only version

  // OPTIONS (for MCQ only)
  options: [
    {
      option_id: "A" | "B" | "C" | "D",
      text: string,                     // Plain text
      html: string,                     // HTML with LaTeX
      latex: string                     // LaTeX-only
    }
  ],

  correct_answer: string,               // "B" or numerical value

  // SOLUTION
  solution_text: string,                // Plain text solution
  solution_text_html: string,           // HTML with LaTeX
  solution_steps: [
    {
      step_number: number,
      description: string,
      formula: string | null
    }
  ],
  key_insight: string,                  // Main concept
  common_mistakes: string[],            // Common errors students make

  // DISTRACTOR ANALYSIS (for MCQ)
  distractor_analysis: {
    "A": string,                        // Why this option is wrong
    "B": string,
    "C": string,
    "D": string
  },

  // IRT PARAMETERS
  irt_parameters: {
    difficulty_b: number,               // [-3, +3]
    discrimination_a: number,           // [0.5, 2.5]
    guessing_c: number                  // [0, 0.5] (usually 0.25 for 4-option MCQ)
  },

  // METADATA
  tags: string[],                       // ["jee_main", "2023", "mechanics"]
  source: string,                       // "JEE Main 2023"
  year: number,                         // 2023
  image_url: string | null,             // Firebase Storage URL for diagrams
  active: boolean,                      // Whether question is currently active

  // USAGE TRACKING
  times_shown: number,                  // How many times question has been shown
  times_correct: number,                // How many times answered correctly
  average_time_seconds: number,         // Average time to answer

  created_at: Timestamp,
  updated_at: Timestamp
}
```

### 2. Daily Quiz Question Pool

**Path:** `daily_quiz_questions/{questionId}`

**Structure:** Same as `questions/{questionId}` but filtered for daily quiz suitability.

### 3. Assessment Question Pool

**Path:** `assessment_questions/{questionId}`

**Structure:** Same as `questions/{questionId}` but:
- Fixed to 30 questions total (10 Physics, 10 Chemistry, 10 Maths)
- Broad chapter coverage for initial theta calculation

---

## Tier & Configuration

### 1. Tier Configuration

**Path:** `tier_config/active`

```javascript
{
  version: "1.0.0",

  feature_flags: {
    show_cognitive_mastery: boolean     // Global feature flag
  },

  tiers: {
    free: {
      tier_id: "free",
      display_name: "Free",
      is_active: true,
      is_purchasable: false,

      limits: {
        snap_solve_daily: 5,
        daily_quiz_daily: 1,
        solution_history_days: 7,
        ai_tutor_enabled: false,
        ai_tutor_messages_daily: 0,
        chapter_practice_enabled: true,
        chapter_practice_per_chapter: 5,       // 5 questions per chapter
        chapter_practice_daily_limit: 5,       // 5 chapters per day
        mock_tests_monthly: 1,
        pyq_years_access: 2,
        offline_enabled: false,
        max_devices: 1
      },

      features: {
        analytics_access: "basic"
      }
    },

    pro: {
      tier_id: "pro",
      display_name: "Pro",
      is_active: true,
      is_purchasable: true,

      limits: {
        snap_solve_daily: 15,
        daily_quiz_daily: 10,
        solution_history_days: 30,
        ai_tutor_enabled: false,
        ai_tutor_messages_daily: 0,
        chapter_practice_enabled: true,
        chapter_practice_per_chapter: 15,      // 15 questions per chapter
        chapter_practice_daily_limit: -1,      // Unlimited chapters per day
        mock_tests_monthly: 5,
        pyq_years_access: 5,
        offline_enabled: true,
        max_devices: 1
      },

      features: {
        analytics_access: "full"
      },

      pricing: {
        monthly: { price: 29900, display_price: "299", duration_days: 30 },
        quarterly: { price: 74700, display_price: "747", duration_days: 90 },
        annual: { price: 238800, display_price: "2,388", duration_days: 365 }
      }
    },

    ultra: {
      tier_id: "ultra",
      display_name: "Ultra",
      is_active: true,
      is_purchasable: true,

      limits: {
        snap_solve_daily: 50,                  // Soft cap (not truly unlimited)
        daily_quiz_daily: 25,
        solution_history_days: 365,
        ai_tutor_enabled: true,
        ai_tutor_messages_daily: 100,
        chapter_practice_enabled: true,
        chapter_practice_per_chapter: 15,
        chapter_practice_daily_limit: -1,
        mock_tests_monthly: 15,
        pyq_years_access: -1,                  // Unlimited
        offline_enabled: true,
        max_devices: 1
      },

      features: {
        analytics_access: "full"
      },

      pricing: {
        monthly: { price: 49900, display_price: "499", duration_days: 30 },
        quarterly: { price: 119700, display_price: "1,197", duration_days: 90 },
        annual: { price: 358800, display_price: "3,588", duration_days: 365 }
      }
    }
  },

  created_at: Timestamp,
  updated_at: Timestamp,
  updated_by: "system"
}
```

**Note:** `-1` means "unlimited" for limits.

---

## Mock Tests

### 1. Mock Test Templates

**Path:** `mock_test_templates/{templateId}`

```javascript
{
  template_id: string,                  // "jee_main_full_test_001"
  title: string,                        // "JEE Main Full Test - 1"
  description: string,
  exam_type: "jee_main" | "jee_advanced",

  duration_minutes: 180,                // 3 hours
  total_questions: 90,
  total_marks: 300,

  // QUESTION DISTRIBUTION
  question_distribution: {
    physics: { mcq_single: 20, numerical: 10 },
    chemistry: { mcq_single: 20, numerical: 10 },
    mathematics: { mcq_single: 20, numerical: 10 }
  },

  // MARKING SCHEME
  marking_scheme: {
    mcq_single_correct: 4,
    mcq_single_incorrect: -1,
    numerical_correct: 4,
    numerical_incorrect: -1
  },

  // QUESTIONS (pre-selected for this template)
  questions: [
    {
      question_id: string,
      question_number: number,          // 1-90
      subject: string,
      chapter_key: string,
      question_type: string,
      difficulty_b: number,
      discrimination_a: number
    }
    // ... 89 more
  ],

  // NTA PERCENTILE SCORE MAPPING
  percentile_map: {
    "300": 99.99,
    "296": 99.9,
    "292": 99.8,
    // ... mapping from total marks to NTA percentile
    "100": 75.0,
    "0": 0
  },

  active: boolean,
  created_at: Timestamp,
  updated_at: Timestamp
}
```

---

## Cognitive Mastery

### 1. Atlas Nodes

**Path:** `atlas_nodes/{nodeId}`

```javascript
{
  node_id: string,                      // "physics_projectile_motion"
  title: string,                        // "Projectile Motion"
  subject: "physics" | "chemistry" | "mathematics",
  chapter_key: string,                  // Parent chapter

  // LEARNING CONTENT
  capsule_id: string,                   // Associated learning capsule ID
  retrieval_pool_id: string,            // Associated retrieval question pool ID

  // MICRO-SKILLS
  micro_skill_ids: string[],            // List of micro-skill IDs covered

  // METADATA
  difficulty: "foundation" | "intermediate" | "advanced",
  jee_importance: "high" | "medium" | "low",

  created_at: Timestamp,
  updated_at: Timestamp
}
```

### 2. Learning Capsules

**Path:** `capsules/{capsuleId}`

```javascript
{
  capsule_id: string,
  node_id: string,                      // Parent atlas node
  title: string,                        // "Understanding Projectile Motion"

  // CONTENT
  sections: [
    {
      section_number: number,
      title: string,
      content_html: string,             // HTML with LaTeX
      key_formula: string | null,
      example: {
        problem: string,
        solution: string,
        key_insight: string
      } | null
    }
  ],

  // METADATA
  estimated_time_minutes: number,       // Time to read/understand
  difficulty: string,

  created_at: Timestamp,
  updated_at: Timestamp
}
```

### 3. Retrieval Question Pools

**Path:** `retrieval_pools/{poolId}`

```javascript
{
  pool_id: string,
  node_id: string,                      // Parent atlas node

  questions: [
    {
      question_id: string,              // Question ID from main question bank
      question_type: "mcq_single" | "numerical",
      difficulty: "easy" | "medium" | "hard",
      micro_skill_ids: string[]         // Micro-skills tested by this question
    }
    // Total: 10-15 questions per pool (3 selected randomly for each retrieval test)
  ],

  created_at: Timestamp,
  updated_at: Timestamp
}
```

### 4. Atlas Micro-Skills

**Path:** `atlas_micro_skills/{microSkillId}`

```javascript
{
  micro_skill_id: string,               // "resolve_2d_vectors"
  name: string,                         // "Resolve 2D vectors into components"
  description: string,

  node_ids: string[],                   // Nodes where this skill is used

  created_at: Timestamp,
  updated_at: Timestamp
}
```

### 5. Question-Skill Mapping

**Path:** `atlas_question_skill_map/{questionId}`

```javascript
{
  question_id: string,
  micro_skill_ids: string[],            // Skills required to solve this question
  primary_skill_id: string,             // Most important skill

  created_at: Timestamp,
  updated_at: Timestamp
}
```

### 6. User Weak Spots

**Path:** `user_weak_spots/{userId}/nodes/{nodeId}`

```javascript
{
  node_id: string,
  title: string,

  // DETECTION
  detected_at: Timestamp,
  detected_in_session_id: string,       // Chapter practice session ID
  score: number,                        // Weakness score [0, 1]
  severity_level: "high" | "medium" | "low",

  // CURRENT STATE
  node_state: "detected" | "improving" | "mastered",

  // ASSOCIATED CONTENT
  capsule_id: string,
  retrieval_pool_id: string,

  // PROGRESS TRACKING (derived from weak_spot_events)
  capsule_opened: boolean,
  capsule_completed: boolean,
  retrieval_attempts: number,
  retrieval_passed: boolean,

  updated_at: Timestamp
}
```

### 7. Weak Spot Events Log

**Path:** `weak_spot_events/{eventId}`

```javascript
{
  event_id: string,
  user_id: string,
  node_id: string,

  // EVENT TYPE
  event_type: "detected" | "capsule_opened" | "capsule_completed" | "retrieval_attempted" | "retrieval_passed" | "retrieval_failed" | "mastered",

  // CONTEXT
  session_id: string | null,            // Chapter practice session (for detection)
  capsule_id: string | null,            // Capsule (for engagement events)
  retrieval_score: number | null,       // Score on retrieval test (0-3 correct)

  // STATE CHANGE
  old_state: string | null,
  new_state: string | null,

  created_at: Timestamp
}
```

**Event Log Strategy:** Append-only log for all weak spot events. Capsule status (opened/completed) is derived by querying this log, not stored as mutable fields.

---

## Admin & Metrics

### 1. Promo Codes

**Path:** `promo_codes/{code}`

```javascript
{
  code: string,                         // "WELCOME50"
  discount_percent: number,             // 50
  max_uses: number,                     // 100
  uses_count: number,                   // 23
  valid_from: Timestamp,
  valid_until: Timestamp,
  active: boolean,

  // RESTRICTIONS
  applicable_tiers: string[],           // ["pro", "ultra"]
  applicable_durations: string[],       // ["monthly", "quarterly", "annual"]

  created_at: Timestamp,
  updated_at: Timestamp
}
```

---

## Index Requirements

### Composite Indexes (Firestore requires these for complex queries)

```javascript
// 1. User weak spots by state
Collection: user_weak_spots/{userId}/nodes
Fields: node_state (Ascending), updated_at (Descending)

// 2. Weak spot events for recurrence detection
Collection: weak_spot_events
Fields: user_id (Ascending), node_id (Ascending), session_id (Ascending), created_at (Descending)

// 3. Daily usage by tier
Collection: users
Fields: subscription.tier (Ascending), last_active_at (Descending)

// 4. Chapter practice sessions for analytics
Collection: users/{userId}/chapter_sessions
Fields: is_completed (Ascending), completed_at (Descending)

// 5. Mock test sessions for leaderboard
Collection: users/{userId}/mock_test_sessions
Fields: is_completed (Ascending), total_marks (Descending)
```

---

## Common Query Patterns

### 1. Get User's Current Tier

```javascript
const userDoc = await db.collection('users').doc(userId).get();
const subscription = userDoc.data().subscription;

// Priority: override > paid > trial > free
const effectiveTier =
  subscription.override ||
  (subscription.status === 'active' && subscription.tier) ||
  (subscription.trial?.is_active && subscription.trial.tier) ||
  'free';
```

### 2. Get Today's Daily Usage

```javascript
const today = new Date().toISOString().split('T')[0];  // "2026-02-27"
const usageDoc = await db.collection('users').doc(userId)
  .collection('daily_usage').doc(today).get();

const usage = usageDoc.exists ? usageDoc.data().usage : {
  snap_solve: 0,
  daily_quiz: 0,
  chapter_practice: 0,
  ai_tutor_messages: 0,
  mock_tests: 0
};
```

### 3. Get User's Weak Spots (All States)

```javascript
const weakSpotsSnapshot = await db.collection('user_weak_spots').doc(userId)
  .collection('nodes')
  .orderBy('updated_at', 'desc')
  .get();

const weakSpots = weakSpotsSnapshot.docs.map(doc => doc.data());
```

### 4. Get User's Weak Spots (Specific State)

```javascript
const detectedWeakSpots = await db.collection('user_weak_spots').doc(userId)
  .collection('nodes')
  .where('node_state', '==', 'detected')
  .orderBy('updated_at', 'desc')
  .get();
```

### 5. Check Capsule Status from Event Log

```javascript
const eventsSnapshot = await db.collection('weak_spot_events')
  .where('user_id', '==', userId)
  .where('node_id', '==', nodeId)
  .where('capsule_id', '==', capsuleId)
  .orderBy('created_at', 'desc')
  .limit(1)
  .get();

const latestEvent = eventsSnapshot.docs[0]?.data();
const capsuleOpened = latestEvent?.event_type === 'capsule_opened' ||
                      latestEvent?.event_type === 'capsule_completed';
const capsuleCompleted = latestEvent?.event_type === 'capsule_completed';
```

---

## Test User Data (for E2E Tests)

### Standard Test Users

```javascript
const TEST_USERS = [
  {
    uid: "test-user-free-001",
    phoneNumber: "+16505551001",
    firstName: "Test",
    lastName: "Free1",
    class: "12",
    tier: "free",
    trial_status: "expired",
    progress_level: "new_user",           // No quizzes
    overall_theta: 0,
    overall_percentile: 50
  },
  {
    uid: "test-user-free-002",
    phoneNumber: "+16505551002",
    firstName: "Test",
    lastName: "Free2",
    class: "12",
    tier: "free",
    trial_status: "expired",
    progress_level: "active",             // 50 quizzes
    overall_theta: 0.5,
    overall_percentile: 69.1
  },
  {
    uid: "test-user-pro-001",
    phoneNumber: "+16505551003",
    firstName: "Test",
    lastName: "Pro1",
    class: "12",
    tier: "pro",
    trial_status: null,
    progress_level: "advanced",           // 100 quizzes
    overall_theta: 1.0,
    overall_percentile: 84.1
  },
  {
    uid: "test-user-ultra-001",
    phoneNumber: "+16505551005",
    firstName: "Test",
    lastName: "Ultra1",
    class: "12",
    tier: "ultra",
    trial_status: null,
    progress_level: "expert",             // 200 quizzes
    overall_theta: 1.5,
    overall_percentile: 93.3
  },
  {
    uid: "test-user-trial-active",
    phoneNumber: "+16505551006",
    firstName: "Test",
    lastName: "TrialActive",
    class: "12",
    tier: "free",
    trial_status: "active",               // 29 days remaining
    trial_tier: "pro",
    progress_level: "beginner",           // 10 quizzes
    overall_theta: 0.2,
    overall_percentile: 57.9
  },
  {
    uid: "test-user-trial-expiring",
    phoneNumber: "+16505551007",
    firstName: "Test",
    lastName: "TrialExpiring",
    class: "12",
    tier: "free",
    trial_status: "expiring",             // 1 day remaining
    trial_tier: "pro",
    progress_level: "intermediate",       // 20 quizzes
    overall_theta: 0.3,
    overall_percentile: 61.8
  }
];
```

---

## Summary

**Total Collections:** 15+
**Total Subcollections:** 7 per user
**Total Composite Indexes Required:** 5+

**Key Design Principles:**
1. **Denormalization:** Theta data stored in user document for fast reads
2. **Subcollections:** Heavy data (quizzes, sessions) in subcollections to avoid doc size limits
3. **Event Sourcing:** Weak spot events are append-only log (immutable)
4. **Computed Fields:** Capsule status derived from event log, not stored
5. **Caching:** Tier config cached in-memory (5-min TTL) to reduce Firestore reads

**Last Updated:** 2026-02-27 by Claude Code
