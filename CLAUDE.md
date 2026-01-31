# JEEVibe - Claude Code Instructions

## Project Overview

JEEVibe is an AI-powered JEE (Joint Entrance Examination) preparation app for Indian students. It's a mobile-first Flutter app with a Node.js/Firebase backend.

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Mobile** | Flutter (Dart) |
| **Backend** | Node.js + Express |
| **Database** | Firebase Firestore |
| **Auth** | Firebase Auth (Phone + OTP) |
| **Payments** | Razorpay |
| **AI/ML** | OpenAI API (GPT-4), Google Vision |
| **Hosting** | Firebase Cloud Functions |

## Project Structure

```
/backend          - Node.js backend services
/mobile           - Flutter mobile app
/functions        - Firebase Cloud Functions
/docs             - Documentation
  /03-features    - Feature specs and technical docs
  /09-business    - Business strategy and GTM docs
```

## Key Features

1. **Snap & Solve** - Photo-based doubt solving (hero feature)
2. **Daily Quiz** - IRT-adaptive spaced repetition quizzes
3. **Chapter Practice** - Topic-wise question banks with IRT selection
4. **Mock Tests** - Full JEE simulation tests (90 questions, 3 hours)
5. **AI Tutor** - Conversational tutoring (Ultra tier)
6. **Initial Assessment** - 30-question diagnostic to bootstrap student theta

---

## IRT-Based Adaptive Learning System

JEEVibe uses **Item Response Theory (IRT)** with the **3-Parameter Logistic (3PL) model** for adaptive question selection and student ability tracking.

### Core Concepts

| Term | Description |
|------|-------------|
| **Theta (θ)** | Student ability score, range [-3, +3], 0 = average |
| **Difficulty (b)** | Question difficulty parameter, same range as theta |
| **Discrimination (a)** | How well question differentiates ability levels (typically 0.5-2.5) |
| **Guessing (c)** | Probability of guessing correctly (0.25 for 4-option MCQ) |
| **Standard Error (SE)** | Confidence in theta estimate, range [0.15, 0.6] |
| **Fisher Information** | Information gain from a question at given theta |

### 3PL Probability Formula

```
P(θ) = c + (1-c) / (1 + e^(-1.702 * a * (θ - b)))
```

### Question Selection Algorithm

1. Filter questions by chapter and recency (not shown in last 30 days)
2. Match difficulty: select questions where `|b - θ| ≤ threshold`
3. Calculate Fisher Information for each candidate
4. Select question with highest information × discrimination

### Theta Update (Bayesian)

After each response, theta is updated using gradient descent:
```
θ_new = θ_old + learning_rate × (is_correct - P(θ)) × a
SE_new = clamp(SE × decay_factor, 0.15, 0.6)
```

### Theta Hierarchy

```
overall_theta ← weighted average of subject thetas
subject_theta ← weighted average of chapter thetas (by JEE importance)
chapter_theta ← updated directly from question responses
```

### Key Services

| Service | Purpose |
|---------|---------|
| `thetaCalculationService.js` | Initial theta calculation, chapter mappings |
| `thetaUpdateService.js` | Bayesian theta updates after responses |
| `questionSelectionService.js` | IRT-optimized question selection |
| `spacedRepetitionService.js` | Spaced repetition scheduling |

---

## Question Bank Schema

Questions are stored in Firestore with IRT parameters:

```javascript
{
  question_id: "PHY_LOM_001",
  subject: "Physics",
  chapter: "Laws of Motion",
  chapter_key: "physics_laws_of_motion",
  question_type: "mcq_single" | "numerical",
  difficulty: "easy" | "medium" | "hard",

  // Content
  question_text: "A block of mass 5 kg...",
  question_text_html: "<p>A block...</p>",
  options: [
    { option_id: "A", text: "10 N", html: "<p>10 N</p>" },
    // ...
  ],
  correct_answer: "B",

  // Solution
  solution_text: "Using F = ma...",
  solution_steps: [{ step_number: 1, description: "...", formula: "..." }],
  key_insight: "Direct application of Newton's second law",
  common_mistakes: ["Dividing mass by force"],
  distractor_analysis: { "A": "Incorrect calculation...", ... },

  // IRT Parameters
  irt_parameters: {
    difficulty_b: 0.8,      // [-3, +3]
    discrimination_a: 1.5,  // [0.5, 2.5]
    guessing_c: 0.25        // [0, 0.5]
  },

  // Metadata
  image_url: "gs://...",
  active: true,
  created_at: Timestamp
}
```

---

## LaTeX Validation

All mathematical content passes through the LaTeX validator (`latex-validator.js`):

**Pipeline:**
1. Fix common AI generation errors
2. Remove nested delimiters
3. Fix chemical formulas (subscripts, superscripts)
4. Ensure math expressions have delimiters (`\( \)` or `\[ \]`)
5. Remove invalid LaTeX commands
6. Balance delimiters
7. Final cleanup

**Usage:** Import and call `validateAndNormalizeLaTeX(text)` before storing/displaying math content.

**Mobile Rendering:** Use `LatexWidget` for rendering LaTeX in Flutter.

---

## Mock Tests Specifications

Full JEE Main simulation tests with real exam parameters:

| Specification | Value |
|---------------|-------|
| Duration | 3 hours (10,800 seconds) |
| Total Questions | 90 (30 per subject) |
| Question Types | MCQ Single (20/subject) + Numerical (10/subject) |
| Marking Scheme | +4 correct, -1 incorrect, 0 unattempted |
| Maximum Marks | 300 |
| Questions to Attempt | 75 (25 per subject) |

**Question States (Real JEE-style):**
- Not Visited (Gray) - Never opened
- Not Answered (Red) - Visited but no answer
- Answered (Green) - Answer selected
- Marked for Review (Purple) - Flagged, no answer
- Answered & Marked (Purple+Green) - Has answer AND flagged

**Navigation:** Free navigation between all subjects (like real JEE Main)

**Data Source:** Pre-prepared JSON files loaded into Firestore (`mock_test_templates/`)

**Tier Limits:** Free: 1/month, Pro: 5/month, Ultra: Unlimited

## Subscription Tiers

- **FREE**: 5 snaps/day, 1 quiz/day
- **PRO**: 15 snaps/day, 10 quizzes/day, offline mode
- **ULTRA**: 50 snaps/day, 25 quizzes/day, AI tutor access

## Business Model

- Trial-first: All users start with 30-day Pro trial
- Quarterly-first pricing (₹499/quarter recommended)
- Target: JEE Main aspirants (price-sensitive segment)

## Code Conventions

### Flutter/Dart
- Use `snake_case` for file names
- Use `camelCase` for variables and functions
- Use `PascalCase` for classes and widgets
- Prefer `const` constructors where possible
- Use Riverpod for state management

### Node.js/Backend
- Use `camelCase` for variables and functions
- Use async/await (not callbacks)
- All API responses follow: `{ success: boolean, data?: any, error?: string }`
- Use Firebase Admin SDK for Firestore operations

### Firestore
- Collection names: `snake_case` (e.g., `daily_usage`, `promo_codes`)
- Document fields: `snake_case` (e.g., `created_at`, `user_id`)
- Always use server timestamps for `created_at`, `updated_at`

**Key Collections:**
```
users/{userId}                    - User profile, subscription, theta data
users/{userId}/daily_quizzes/     - Daily quiz history
users/{userId}/chapter_sessions/  - Chapter practice sessions
users/{userId}/assessments/       - Initial assessment results
questions/                        - Question bank with IRT parameters
daily_quiz_questions/             - Daily quiz question pool
tier_config/                      - Feature flags and tier limits
promo_codes/                      - Promotional codes
```

**User Theta Storage (in users/{userId}):**
```javascript
{
  theta_by_chapter: {
    "physics_laws_of_motion": { theta: 0.5, se: 0.3, questions_answered: 15 },
    // ...
  },
  theta_by_subject: {
    "physics": { theta: 0.4, se: 0.25 },
    "chemistry": { theta: 0.2, se: 0.28 },
    "mathematics": { theta: 0.6, se: 0.22 }
  },
  overall_theta: 0.4,
  overall_percentile: 65.2
}
```

## Important Files

### Backend Services

| File | Purpose |
|------|---------|
| `backend/src/services/tierConfigService.js` | Tier limits and feature gating |
| `backend/src/services/subscriptionService.js` | Subscription management |
| `backend/src/services/thetaCalculationService.js` | Initial theta calculation, chapter mappings |
| `backend/src/services/thetaUpdateService.js` | Bayesian theta updates after responses |
| `backend/src/services/questionSelectionService.js` | IRT-optimized question selection |
| `backend/src/services/dailyQuizService.js` | Daily quiz generation and submission |
| `backend/src/services/chapterPracticeService.js` | Chapter practice sessions |
| `backend/src/services/assessmentService.js` | Initial 30-question assessment |
| `backend/src/services/spacedRepetitionService.js` | Spaced repetition scheduling |
| `backend/src/services/latex-validator.js` | LaTeX validation and normalization |
| `backend/src/services/aiTutorService.js` | AI Tutor conversations |
| `backend/src/services/openai.js` | OpenAI API integration |
| `backend/src/services/claude.js` | Claude API integration |

### Mobile Core

| File | Purpose |
|------|---------|
| `mobile/lib/services/api_service.dart` | API client |
| `mobile/lib/providers/` | State management providers |
| `mobile/lib/providers/daily_quiz_provider.dart` | Daily quiz state management |

### Reusable Widgets

| Widget | Purpose |
|--------|---------|
| `mobile/lib/widgets/daily_quiz/question_card_widget.dart` | Question display with options |
| `mobile/lib/widgets/daily_quiz/detailed_explanation_widget.dart` | Solution steps display |
| `mobile/lib/widgets/question_review/question_review_screen.dart` | Full question review |
| `mobile/lib/widgets/latex_widget.dart` | LaTeX rendering |
| `mobile/lib/widgets/chemistry_text.dart` | Chemical formula rendering |
| `mobile/lib/widgets/subject_icon_widget.dart` | Subject icons (Physics/Chemistry/Math) |

### Documentation

| File | Purpose |
|------|---------|
| `docs/03-features/TIER-SYSTEM-ARCHITECTURE.md` | Tier system spec |
| `docs/03-features/MOCK-TESTS-FEATURE-PLAN.md` | Mock tests implementation plan |

## Testing

- Backend: `npm test` in `/backend`
- Mobile: `flutter test` in `/mobile`
- Always run tests before committing

## Common Tasks

### Adding a new feature flag
1. Add to `tier_config` collection in Firestore
2. Update `tierConfigService.js` to read the flag
3. Update mobile to check the flag via subscription status

### Adding a new API endpoint
1. Create route in `backend/src/routes/`
2. Add authentication middleware
3. Check tier permissions if feature-gated
4. Update mobile API service

## Do NOT

- Commit `.env` files or credentials
- Use `git push --force` on main
- Skip the trial system for new users
- Hardcode tier limits (use Firestore config)
- Store payment data outside India (RBI compliance)

## Do
- check-in and commit backend changes to remote repository immedidately so they deploy on render.com
- check-in mobile files only if asked

## JEE Chapter Weights

Subject and overall theta are weighted by JEE importance (from `thetaCalculationService.js`):

**Weight Scale:** 1.0 = High Priority, 0.8 = Medium-High, 0.6 = Medium, 0.4 = Low-Medium, 0.3 = Low

High-priority chapters (weight 1.0):
- Physics: Mechanics, Electrostatics, Current Electricity, Electromagnetic Induction
- Chemistry: Organic Chemistry, Chemical Bonding, Thermodynamics
- Mathematics: Calculus (all), Coordinate Geometry, Algebra

The `BROAD_TO_SPECIFIC_CHAPTER_MAP` maps assessment chapters to specific daily quiz chapters.

---