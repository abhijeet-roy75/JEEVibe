# JEEVibe Database Schema - Initial Assessment System

**Version:** 1.0  
**Date:** December 12, 2024  
**Status:** Production Ready

---

## Table of Contents

1. [Overview](#overview)
2. [Collection: `initial_assessment_questions`](#collection-initial_assessment_questions)
3. [Collection: `assessment_responses/{userId}/responses`](#collection-assessment_responses)
4. [Collection: `users/{uid}` (Extended)](#collection-users-extended)
5. [Firebase Storage Structure](#firebase-storage-structure)
6. [Topic Mapping](#topic-mapping)
7. [Firestore Indexes](#firestore-indexes)
8. [Data Types Reference](#data-types-reference)

---

## Overview

This schema defines the database structure for the **Initial Assessment** feature, which is the foundation for the adaptive learning system. The assessment uses IRT (Item Response Theory) to estimate student ability (theta) per chapter.

### Key Principles

1. **Backend Writes**: All writes go through backend API (Admin SDK bypasses security rules)
2. **Direct Reads**: Mobile app can read directly from Firestore for performance
3. **Chapter-Level Theta**: Ability estimates stored per chapter (not per topic or subject)
4. **Image Storage**: Question images stored in Firebase Storage, URLs in Firestore
5. **Stratified Randomization**: Questions randomized within subject+difficulty groups

---

## Collection: `initial_assessment_questions`

**Purpose**: Store the 30 pre-defined assessment questions  
**Document ID**: Question ID (e.g., `ASSESS_PHY_MECH_001`)  
**Total Documents**: 30 (fixed set)

### Document Structure

```javascript
{
  // ========================================
  // IDENTIFIERS
  // ========================================
  "question_id": "ASSESS_PHY_MECH_001",  // Primary key, matches document ID
  "assessment_id": "initial_diagnostic_v1",
  "version": "1.0",
  
  // ========================================
  // CLASSIFICATION
  // ========================================
  "subject": "Physics",  // "Physics", "Chemistry", "Mathematics"
  "chapter": "Mechanics",
  "unit": "Unit 2",
  "sub_topics": [
    "Newton's Laws of Motion",
    "Force Analysis"
  ],
      // Note: No "topic" field - theta calculated at chapter level
      // Chapter key format: {subject}_{chapter} (e.g., "physics_mechanics")
  
  // ========================================
  // DIFFICULTY & PRIORITY
  // ========================================
  "difficulty": "medium",  // "easy", "medium", "hard"
  "difficulty_irt": 0.8,   // IRT difficulty (0.4-2.6 range)
  "priority": "HIGH",      // "HIGH", "MEDIUM", "LOW"
  "weightage_marks": 4,    // JEE marks weightage
  
  // ========================================
  // QUESTION CONTENT
  // ========================================
  "question_type": "mcq_single",  // "mcq_single", "numerical"
  "question_text": "A block of mass 5 kg is placed...",
  "question_text_html": "A block of mass <strong>5 kg</strong>...",
  "question_latex": null,  // LaTeX string if applicable
  
  // Options (for MCQ only, null for numerical)
  "options": [
    {
      "option_id": "A",
      "text": "2.0 m/s²",
      "html": "<strong>2.0 m/s²</strong>"
    },
    {
      "option_id": "B",
      "text": "2.5 m/s²",
      "html": "<strong>2.5 m/s²</strong>"
    },
    {
      "option_id": "C",
      "text": "3.0 m/s²",
      "html": "<strong>3.0 m/s²</strong>"
    },
    {
      "option_id": "D",
      "text": "3.5 m/s²",
      "html": "<strong>3.5 m/s²</strong>"
    }
  ],
  
  // ========================================
  // ANSWER
  // ========================================
  "correct_answer": "A",  // Option ID for MCQ, number string for numerical
  "correct_answer_text": "2.0 m/s²",
  "correct_answer_exact": "2.0",
  "correct_answer_unit": "m/s²",
  "answer_type": "single_choice",  // "single_choice", "decimal", "integer"
  "answer_range": null,  // For numerical: {min: 48, max: 52}
  "alternate_correct_answers": ["1.86", "1.9"],  // Acceptable variations
  
  // ========================================
  // SOLUTION
  // ========================================
  "solution_text": "Horizontal component of force: F_x = 20cos30° = 17.32 N...",
  "solution_steps": [
    {
      "step_number": 1,
      "description": "Resolve applied force into components",
      "formula": "F_x = Fcos θ, F_y = Fsin θ",
      "calculation": "F_x = 20cos30° = 17.32 N, F_y = 20sin30° = 10 N",
      "explanation": "Break the 20 N force into horizontal and vertical components",
      "result": "F_x = 17.32 N, F_y = 10 N"
    }
    // ... more steps
  ],
  "concepts_tested": [
    "Force resolution",
    "Newton's laws",
    "Friction",
    "Multi-step problem solving"
  ],
  
  // ========================================
  // IRT PARAMETERS (CRITICAL)
  // ========================================
  "irt_parameters": {
    "difficulty_b": 0.8,        // [0.4, 2.6] - Question difficulty
    "discrimination_a": 1.4,    // [1.0, 2.0] - How well it differentiates ability
    "guessing_c": 0.25,         // 0.25 for MCQ (4 options), 0.0 for numerical
    "calibration_status": "estimated",  // "estimated" or "calibrated"
    "calibration_method": "rule_based",
    "calibration_sample_size": 0,
    "last_calibration": null,
    "calibration_notes": "Excellent MCQ: 4 options, 7 concepts, strong distractors"
  },
  
  // ========================================
  // IMAGE (if applicable)
  // ========================================
  "has_image": false,  // true for 4 questions with diagrams
  "image_url": null,   // Firebase Storage URL after upload
  // Format: "https://firebasestorage.googleapis.com/v0/b/jeevibe.appspot.com/o/questions%2Finitial_assessment%2FASSESS_PHY_MECH_003.svg?alt=media&token=..."
  "image_type": null,  // "diagram" if has_image is true
  "image_description": null,
  "image_alt_text": null,
  "image_generation_method": null,
  "diagram_code_python": null,  // Python code to generate diagram (if applicable)
  "diagram_config": null,
  
  // ========================================
  // METADATA
  // ========================================
  "time_estimate": 120,  // seconds
  "jee_year_similar": "2023",
  "jee_pattern": "Multi-step mechanics problem with friction",
  "created_date": "2025-01-05T00:00:00Z",
  "created_by": "claude_ai",
  "validated_by": "gemini_ai",
  "validation_status": "approved",
  "validation_date": "2025-01-05T00:00:00Z",
  "validation_notes": "Gemini validated. Approved without changes",
  
  "metadata": {
    "formula_used": "F_net = ma, f = μN",
    "common_mistakes": [
      "Forgetting to subtract vertical component from normal force",
      "Not resolving force into components",
      "Wrong friction direction"
    ],
    "hint": "First resolve the applied force, then calculate normal force considering vertical component",
    "key_insight": "Tests understanding of force resolution, friction, and Newton's second law in combination",
    "elimination_strategy": "Rough estimate: If no friction, a ≈ 17/5 ≈ 3.4 m/s². With friction, must be less. Eliminates D."
  },
  
  "distractor_analysis": {
    "B": "Incorrect normal force calculation",
    "C": "Forgot friction or wrong friction value",
    "D": "Used full 20 N without resolving components"
  },
  
  "tags": [
    "mechanics",
    "newtons-laws",
    "friction",
    "force-resolution",
    "medium",
    "initial-assessment"
  ],
  
  // ========================================
  // USAGE STATISTICS (updated after each use)
  // ========================================
  "usage_stats": {
    "times_shown": 0,
    "times_correct": 0,
    "times_incorrect": 0,
    "avg_time_taken": null,  // seconds
    "accuracy_rate": null,   // 0.0 to 1.0
    "last_shown": null       // Timestamp
  }
}
```

### Required Indexes

```javascript
// Index 1: By subject and difficulty (for stratified randomization)
Collection: initial_assessment_questions
Fields: subject (Ascending), difficulty (Ascending)

// Index 2: By chapter (for grouping responses)
Collection: initial_assessment_questions
Fields: subject (Ascending), chapter (Ascending)

// Index 3: By IRT difficulty (for querying by difficulty range)
Collection: initial_assessment_questions
Fields: irt_parameters.difficulty_b (Ascending)

// Index 4: Composite for stratified randomization
Collection: initial_assessment_questions
Fields: subject (Ascending), difficulty (Ascending), question_id (Ascending)
```

---

## Collection: `assessment_responses/{userId}/responses`

**Purpose**: Store individual question responses during assessment  
**Document ID**: Auto-generated (e.g., `resp_abc123_001`)  
**Structure**: Subcollection under user ID

### Document Structure

```javascript
{
  // ========================================
  // IDENTIFIERS
  // ========================================
  "response_id": "resp_abc123_001",  // Auto-generated: resp_{userId}_{questionId}_{timestamp}
  "student_id": "4WcwbU4zSsa3PZFq26Rt4Kad8I62",  // Firebase Auth UID
  "question_id": "ASSESS_PHY_MECH_001",
  
  // ========================================
  // RESPONSE DETAILS
  // ========================================
  "student_answer": "A",  // User's selected answer
  "correct_answer": "A",  // Correct answer from question
  "is_correct": true,     // Boolean
  "time_taken_seconds": 95,  // Time spent on question
  
  // ========================================
  // QUESTION METADATA (denormalized for analytics)
  // ========================================
  "subject": "Physics",
  "chapter": "Mechanics",
  "chapter_key": "physics_mechanics",  // CRITICAL: For grouping ({subject}_{chapter})
  "difficulty_b": 0.8,      // From question's irt_parameters
  "discrimination_a": 1.4,   // From question's irt_parameters
  "guessing_c": 0.25,        // From question's irt_parameters
  
  // ========================================
  // TIMESTAMPS
  // ========================================
  "answered_at": "2025-01-10T10:30:00Z",  // ISO 8601 timestamp
  "created_at": "2025-01-10T10:30:00Z"     // Same as answered_at
}
```

### Required Indexes

```javascript
// Index 1: By student and timestamp (chronological order)
Collection: assessment_responses/{userId}/responses
Fields: answered_at (Descending)

// Index 2: By question_id (for duplicate checking)
Collection: assessment_responses/{userId}/responses
Fields: question_id (Ascending)

// Index 3: By topic (for grouping by topic)
Collection: assessment_responses/{userId}/responses
Fields: topic (Ascending)
```

---

## Collection: `users/{uid}` (Extended)

**Purpose**: Store user profile with assessment results and theta estimates  
**Document ID**: Firebase Auth UID  
**Note**: This extends the existing `users` collection schema

### Existing Fields (Keep As-Is)

```javascript
{
  // Existing user profile fields
  "uid": "4WcwbU4zSsa3PZFq26Rt4Kad8I62",
  "phoneNumber": "+919876543210",
  "profileCompleted": true,
  "firstName": "Rahul",
  "lastName": "Sharma",
  "email": "rahul@example.com",
  "dateOfBirth": "2006-05-15",
  "gender": "Male",
  "currentClass": "12",
  "targetExam": "JEE Main + Advanced",
  "targetYear": "2025",
  "schoolName": "Delhi Public School",
  "city": "Mumbai",
  "state": "Maharashtra",
  "coachingInstitute": "FIITJEE",
  "coachingBranch": "Kalu Sarai, Delhi",
  "studyMode": "Coaching + Self-study",
  "preferredLanguage": "English",
  "weakSubjects": ["Physics", "Mathematics"],  // Keep this
  // "strongSubjects": ["Chemistry"],  // REMOVE THIS FIELD
  "createdAt": Timestamp,
  "lastActive": Timestamp
}
```

### New Fields (Add for Assessment)

```javascript
{
  // ========================================
  // INITIAL ASSESSMENT STATUS
  // ========================================
  "assessment": {
    "status": "not_started",  // "not_started", "in_progress", "completed"
    "started_at": null,       // Timestamp when assessment started
    "completed_at": null,     // Timestamp when assessment completed
    "time_taken_seconds": null,  // Total time to complete assessment
    
    // Assessment responses reference (lightweight)
    "responses": [
      {
        "question_id": "ASSESS_PHY_MECH_001",
        "response_id": "resp_abc123_001",
        "is_correct": true,
        "time_taken_seconds": 95
      }
      // ... 30 total responses
    ]
  },
  
  // ========================================
  // IRT-BASED ABILITY ESTIMATES (Chapter-Level)
  // ========================================
  "theta_by_chapter": {
    "physics_mechanics": {
      "theta": -0.5,              // [-3.0, +3.0] - Student ability
      "percentile": 30.85,        // [0, 100] - Percentile rank
      "confidence_SE": 0.35,      // [0.1, 0.6] - Standard error (lower = more confident)
      "attempts": 4,              // Number of questions answered in this chapter
      "accuracy": 0.50,           // [0.0, 1.0] - Cumulative accuracy
      "last_updated": "2025-01-10T10:30:00Z"  // ISO 8601 timestamp
    },
    "physics_electrostatics": {
      "theta": -1.5,
      "percentile": 6.68,
      "confidence_SE": 0.48,
      "attempts": 3,
      "accuracy": 0.33,
      "last_updated": "2025-01-10T10:30:00Z"
    },
    "chemistry_organic_chemistry": {
      "theta": 0.5,
      "percentile": 69.15,
      "confidence_SE": 0.42,
      "attempts": 3,
      "accuracy": 0.67,
      "last_updated": "2025-01-10T10:30:00Z"
    }
    // ... all tested chapters (approximately 10-15 from initial assessment)
    // Format: {subject}_{chapter} (e.g., "physics_mechanics", "chemistry_organic_chemistry")
  },
  
  // ========================================
  // OVERALL ABILITY METRICS
  // ========================================
  "overall_theta": 0.2,          // [-3.0, +3.0] - Simple average (equal weights)
  "overall_percentile": 57.93,   // [0, 100]
  
  // ========================================
  // LEARNING STATE
  // ========================================
  "completed_quiz_count": 0,     // PRIMARY: Used for phase transition (0-indexed)
  "current_day": 0,               // Analytics: Days since assessment completion
  "learning_phase": "exploration", // "exploration" or "exploitation"
  "phase_switched_at_quiz": null,  // Will be 14 when switching to exploitation
  
  // ========================================
  // ASSESSMENT METADATA
  // ========================================
  "assessment_completed_at": null,      // Timestamp when assessment completed
  "last_quiz_completed_at": null,       // Timestamp of last daily quiz
  "total_questions_solved": 0,          // Total questions across all quizzes
  "total_time_spent_minutes": 0,        // Total study time
  
  // ========================================
  // CHAPTER TRACKING
  // ========================================
  "chapter_attempt_counts": {
    "physics_mechanics": 4,
    "chemistry_organic_chemistry": 3,
    // ... all chapters (initially 0, updated as student practices)
    // Format: {subject}_{chapter}
  },
  
  // ========================================
  // COVERAGE METRICS
  // ========================================
  "chapters_explored": 10,        // Chapters with ≥1 attempt
  "chapters_confident": 8,        // Chapters with ≥2 attempts
  
  // ========================================
  // SUBJECT BALANCE (for exploration prioritization)
  // ========================================
  "subject_balance": {
    "physics": 0.35,      // 35% of questions attempted
    "chemistry": 0.30,    // 30% of questions attempted
    "mathematics": 0.35  // 35% of questions attempted
  }
}
```

### Required Indexes

```javascript
// Index 1: By assessment status (for finding users who need assessment)
Collection: users
Fields: assessment.status (Ascending)

// Index 2: By assessment completion date (analytics)
Collection: users
Fields: assessment.completed_at (Descending)

// Index 3: By learning phase (analytics)
Collection: users
Fields: learning_phase (Ascending), completed_quiz_count (Ascending)
```

---

## Firebase Storage Structure

**Purpose**: Store question images (SVG files)  
**Bucket**: `jeevibe.appspot.com` (or your Firebase project bucket)

### Directory Structure

```
firebase_storage/
  └── questions/
      └── initial_assessment/
          ├── ASSESS_PHY_MECH_003.svg
          ├── ASSESS_PHY_EMI_001.svg
          ├── ASSESS_CHEM_ORG_001.svg
          └── ASSESS_MATH_COORD_001.svg
```

### Storage Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Question images - public read
    match /questions/initial_assessment/{imageId} {
      allow read: if true;  // Public read for authenticated users
      allow write: if false;  // Backend only (Admin SDK)
    }
    
    // Future: Daily practice question images
    match /questions/daily_practice/{imageId} {
      allow read: if request.auth != null;
      allow write: if false;  // Backend only
    }
  }
}
```

### Image URL Format

After uploading to Firebase Storage, store the public URL in Firestore:

```javascript
// Public URL format
"image_url": "https://firebasestorage.googleapis.com/v0/b/jeevibe.appspot.com/o/questions%2Finitial_assessment%2FASSESS_PHY_MECH_003.svg?alt=media&token=..."

// Or use download URL (if private)
"image_url": "gs://jeevibe.appspot.com/questions/initial_assessment/ASSESS_PHY_MECH_003.svg"
```

---

## Chapter Mapping

**Critical**: Theta is calculated at the **chapter level**, not topic level.

### Chapter Key Naming Convention

Format: `{subject}_{chapter}` (lowercase, spaces replaced with underscores)

Examples:
- `physics_mechanics`
- `physics_electrostatics`
- `chemistry_organic_chemistry`
- `mathematics_calculus`
- `mathematics_coordinate_geometry`

### Chapter Mapping from Assessment Questions

Based on the 30 assessment questions, here's how they group by chapter:

#### Physics (10 questions)

| Question IDs | Chapter | Chapter Key | Count |
|-------------|---------|-------------|-------|
| ASSESS_PHY_MECH_001-004 | Mechanics | `physics_mechanics` | 4 |
| ASSESS_PHY_ELEC_001-002 | Electrostatics | `physics_electrostatics` | 2 |
| ASSESS_PHY_CURR_001 | Current Electricity | `physics_current_electricity` | 1 |
| ASSESS_PHY_MAG_001 | Magnetism | `physics_magnetism` | 1 |
| ASSESS_PHY_EMI_001 | Electromagnetic Induction | `physics_electromagnetic_induction` | 1 |
| ASSESS_PHY_MOD_001 | Modern Physics | `physics_modern_physics` | 1 |

#### Chemistry (10 questions)

| Question IDs | Chapter | Chapter Key | Count |
|-------------|---------|-------------|-------|
| ASSESS_CHEM_ORG_001-003 | Organic Chemistry | `chemistry_organic_chemistry` | 3 |
| ASSESS_CHEM_PHY_001-004 | Physical Chemistry | `chemistry_physical_chemistry` | 4 |
| ASSESS_CHEM_INORG_001-003 | Inorganic Chemistry | `chemistry_inorganic_chemistry` | 3 |

#### Mathematics (10 questions)

| Question IDs | Chapter | Chapter Key | Count |
|-------------|---------|-------------|-------|
| ASSESS_MATH_CALC_001-004 | Calculus | `mathematics_calculus` | 4 |
| ASSESS_MATH_ALG_001-004 | Algebra | `mathematics_algebra` | 4 |
| ASSESS_MATH_COORD_001-002 | Coordinate Geometry | `mathematics_coordinate_geometry` | 2 |

### Chapter Key Generation Logic

When processing questions, generate chapter key from:
1. **Subject**: Use `subject` field (e.g., "Physics")
2. **Chapter**: Use `chapter` field (e.g., "Mechanics")
3. **Format**: Convert to lowercase, replace spaces with underscores: `{subject}_{chapter}`

Example:
```javascript
// Question: ASSESS_PHY_MECH_001
subject = "Physics"  // Already in JSON
chapter = "Mechanics"  // Already in JSON
chapter_key = "physics_mechanics"  // Generated: {subject}_{chapter}
```

**Note**: No topic extraction needed - we use the existing `subject` and `chapter` fields directly.

---

## Firestore Indexes

### Required Composite Indexes

Create these in Firebase Console → Firestore → Indexes:

#### 1. Initial Assessment Questions

```javascript
// Index: By subject and difficulty (for stratified randomization)
Collection: initial_assessment_questions
Fields:
  - subject (Ascending)
  - difficulty (Ascending)
  - question_id (Ascending)
```

#### 2. Assessment Responses

```javascript
// Index: By student and timestamp (chronological retrieval)
Collection: assessment_responses/{userId}/responses
Fields:
  - answered_at (Descending)
```

```javascript
// Index: By chapter_key (for grouping by chapter)
Collection: assessment_responses/{userId}/responses
Fields:
  - chapter_key (Ascending)
  - answered_at (Descending)
```

#### 3. Users Collection

```javascript
// Index: By assessment status (find users who need assessment)
Collection: users
Fields:
  - assessment.status (Ascending)
```

```javascript
// Index: By learning phase and quiz count (analytics)
Collection: users
Fields:
  - learning_phase (Ascending)
  - completed_quiz_count (Ascending)
```

---

## Data Types Reference

### Timestamps
- **Format**: ISO 8601 string or Firestore Timestamp
- **Example**: `"2025-01-10T10:30:00Z"` or `Timestamp(seconds=1736509800, nanoseconds=0)`

### Numbers
- **Theta**: Float, range [-3.0, +3.0]
- **Percentile**: Float, range [0.0, 100.0]
- **Standard Error**: Float, range [0.1, 0.6]
- **Accuracy**: Float, range [0.0, 1.0]
- **IRT Parameters**: Float
  - `difficulty_b`: [0.4, 2.6]
  - `discrimination_a`: [1.0, 2.0]
  - `guessing_c`: [0.0, 0.25]

### Strings
- **Question IDs**: Format `ASSESS_{SUBJECT}_{CHAPTER}_{NUMBER}`
- **Chapter Keys**: Format `{subject}_{chapter}` (snake_case, lowercase)
- **Subject**: "Physics", "Chemistry", "Mathematics"
- **Difficulty**: "easy", "medium", "hard"
- **Question Type**: "mcq_single", "numerical"

### Arrays
- **Options**: Array of objects with `option_id`, `text`, `html`
- **Solution Steps**: Array of step objects
- **Sub-topics**: Array of strings
- **Tags**: Array of strings

---

## Migration Notes

### Existing Users

When adding assessment fields to existing users:

1. **Default Values**:
   ```javascript
   assessment: {
     status: "not_started",
     started_at: null,
     completed_at: null,
     time_taken_seconds: null,
     responses: []
   },
   theta_by_chapter: {},
   overall_theta: 0.0,
   overall_percentile: 50.0,
   completed_quiz_count: 0,
   current_day: 0,
   learning_phase: "exploration",
   chapter_attempt_counts: {},
   chapters_explored: 0,
   chapters_confident: 0,
   subject_balance: {
     physics: 0.33,
     chemistry: 0.33,
     mathematics: 0.33
   }
   ```

2. **Backward Compatibility**: 
   - All new fields are optional
   - Check `assessment.status` before showing assessment
   - Default to `"not_started"` if field doesn't exist

### Remove `strongSubjects` Field

**Action Required**: 
- Remove `strongSubjects` from UserProfile model (mobile)
- Remove from Firestore writes
- Handle in `fromMap()` - ignore if present in old data

---

## Next Steps

1. ✅ Review this schema
2. Create Firestore collections
3. Create indexes
4. Populate initial assessment questions
5. Upload images to Firebase Storage
6. Test data structure

---

**End of Schema Document**
