# JEEVibe Student Data Collection Reference

**Last Updated:** 2026-02-07

This document provides a comprehensive overview of all data collected for students across the JEEVibe platform, organized by learning activity and data type.

---

## Table of Contents

1. [User Profile & Subscription](#1-user-profile--subscription)
2. [Initial Assessment](#2-initial-assessment)
3. [Daily Quiz](#3-daily-quiz)
4. [Chapter Practice](#4-chapter-practice)
5. [Mock Tests](#5-mock-tests)
6. [Snap & Solve](#6-snap--solve)
7. [AI Tutor](#7-ai-tutor)
8. [Theta Evolution](#8-theta-evolution)
9. [Usage & Engagement](#9-usage--engagement)
10. [Data Extraction Script](#10-data-extraction-script)
11. [Analytics Use Cases](#11-analytics-use-cases)

---

## 1. User Profile & Subscription

**Firestore Collection:** `users/{userId}`

### Basic Information
| Field | Type | Description |
|-------|------|-------------|
| `uid` | string | Firebase user ID |
| `phoneNumber` | string | Phone number (verified via OTP) |
| `firstName` | string | Student's first name |
| `lastName` | string | Student's last name |
| `email` | string | Email address |
| `profileCompleted` | boolean | Whether onboarding is complete |
| `createdAt` | timestamp | Account creation date |
| `lastActive` | timestamp | Last activity timestamp |

### JEE Preparation Details
| Field | Type | Description |
|-------|------|-------------|
| `jeeTargetExamDate` | string | Target JEE exam (e.g., "2027-01" for Jan 2027) |
| `isEnrolledInCoaching` | boolean | Whether student attends coaching |
| `state` | string | Student's state (optional) |
| `dreamBranch` | string | Desired engineering branch (optional) |

### Subscription & Tier
| Field | Type | Description |
|-------|------|-------------|
| `subscriptionTier` | string | FREE, PRO, or ULTRA |
| `subscriptionStatus` | string | active, expired, cancelled |
| `trialStatus` | string | active, expired, not_started |
| `trialStartDate` | timestamp | Trial start date |
| `trialEndDate` | timestamp | Trial end date |
| `subscriptionStartDate` | timestamp | Paid subscription start |
| `subscriptionEndDate` | timestamp | Paid subscription end |

### Learning Metrics (Summary)
| Field | Type | Description |
|-------|------|-------------|
| `overall_theta` | number | Overall ability score [-3, +3] |
| `overall_percentile` | number | Percentile rank [0-100] |
| `theta_by_subject` | object | Theta for Physics, Chemistry, Math |
| `theta_by_chapter` | object | Theta for each chapter |
| `totalQuestionsAnswered` | number | Total questions attempted |
| `totalCorrectAnswers` | number | Total correct answers |

### Engagement Metrics
| Field | Type | Description |
|-------|------|-------------|
| `currentStreak` | number | Current daily quiz streak |
| `longestStreak` | number | Longest streak achieved |
| `lastQuizDate` | timestamp | Last daily quiz date |
| `totalDailyQuizzes` | number | Total daily quizzes taken |
| `totalChapterSessions` | number | Total chapter practice sessions |
| `totalMockTests` | number | Total mock tests attempted |

---

## 2. Initial Assessment

**Firestore Collection:** `users/{userId}/assessments/{assessmentId}`

The 30-question diagnostic test taken during onboarding to bootstrap student theta.

### Assessment Summary
| Field | Type | Description |
|-------|------|-------------|
| `assessment_id` | string | Document ID |
| `completed_at` | timestamp | When assessment was completed |
| `total_questions` | number | Total questions (30) |
| `correct_answers` | number | Number of correct answers |
| `overall_accuracy` | number | Overall accuracy percentage |
| `initial_theta` | number | Calculated initial overall theta |
| `initial_percentile` | number | Initial percentile rank |

### Subject-Level Performance
| Field | Type | Description |
|-------|------|-------------|
| `subject_accuracy` | object | Accuracy per subject (Physics, Chemistry, Math) |
| `subject_accuracy[subject].accuracy` | number | Accuracy percentage for subject |
| `subject_accuracy[subject].correct` | number | Correct answers in subject |
| `subject_accuracy[subject].total` | number | Total questions in subject |

### Chapter-Level Performance
| Field | Type | Description |
|-------|------|-------------|
| `chapter_accuracy` | object | Accuracy per chapter |
| `chapter_accuracy[chapter_key].accuracy` | number | Accuracy percentage for chapter |
| `chapter_accuracy[chapter_key].correct` | number | Correct answers in chapter |
| `chapter_accuracy[chapter_key].total` | number | Total questions in chapter |

### Individual Responses
| Field | Type | Description |
|-------|------|-------------|
| `responses` | array | Array of response objects |
| `responses[].question_id` | string | Question identifier |
| `responses[].subject` | string | Physics, Chemistry, or Mathematics |
| `responses[].chapter` | string | Broad chapter name |
| `responses[].difficulty` | string | easy, medium, or hard |
| `responses[].user_answer` | string | Student's answer |
| `responses[].correct_answer` | string | Correct answer |
| `responses[].is_correct` | boolean | Whether answer was correct |
| `responses[].time_spent_seconds` | number | Time spent on question |

---

## 3. Daily Quiz

**Firestore Collection:** `users/{userId}/daily_quizzes/{quizId}`

Daily adaptive quizzes with 15 questions (5 per subject).

### Quiz Summary
| Field | Type | Description |
|-------|------|-------------|
| `quiz_id` | string | Document ID (YYYY-MM-DD format) |
| `date` | timestamp | Quiz date |
| `completed` | boolean | Whether quiz was completed |
| `score` | number | Number of correct answers |
| `total_questions` | number | Total questions (15) |
| `accuracy` | number | Accuracy percentage |
| `time_taken_seconds` | number | Total time spent |

### Subject Breakdown
| Field | Type | Description |
|-------|------|-------------|
| `subject_breakdown` | object | Performance per subject |
| `subject_breakdown[subject].correct` | number | Correct answers |
| `subject_breakdown[subject].total` | number | Total questions |
| `subject_breakdown[subject].accuracy` | number | Accuracy percentage |

### Individual Responses
| Field | Type | Description |
|-------|------|-------------|
| `responses` | array | Array of response objects |
| `responses[].question_id` | string | Question identifier |
| `responses[].subject` | string | Physics, Chemistry, or Mathematics |
| `responses[].chapter` | string | Specific chapter (e.g., "Laws of Motion") |
| `responses[].difficulty` | string | easy, medium, or hard |
| `responses[].user_answer` | string | Student's answer |
| `responses[].correct_answer` | string | Correct answer |
| `responses[].is_correct` | boolean | Whether answer was correct |
| `responses[].time_spent_seconds` | number | Time spent on question |
| `responses[].theta_before` | number | Chapter theta before this question |
| `responses[].theta_after` | number | Chapter theta after this question |

---

## 4. Chapter Practice

**Firestore Collection:** `users/{userId}/chapter_sessions/{sessionId}`

Topic-wise practice sessions with adaptive question selection.

### Session Summary
| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Document ID (UUID) |
| `subject` | string | Physics, Chemistry, or Mathematics |
| `chapter` | string | Chapter name |
| `chapter_key` | string | Normalized chapter key |
| `started_at` | timestamp | Session start time |
| `completed_at` | timestamp | Session end time |
| `completed` | boolean | Whether session was completed |
| `questions_attempted` | number | Number of questions attempted |
| `correct_answers` | number | Number of correct answers |
| `accuracy` | number | Accuracy percentage |
| `time_taken_seconds` | number | Total time spent |

### Theta Tracking
| Field | Type | Description |
|-------|------|-------------|
| `theta_before` | number | Chapter theta at session start |
| `theta_after` | number | Chapter theta at session end |
| `theta_change` | number | Theta improvement in session |

### Individual Responses
| Field | Type | Description |
|-------|------|-------------|
| `responses` | array | Array of response objects |
| `responses[].question_id` | string | Question identifier |
| `responses[].difficulty` | string | easy, medium, or hard |
| `responses[].user_answer` | string | Student's answer |
| `responses[].correct_answer` | string | Correct answer |
| `responses[].is_correct` | boolean | Whether answer was correct |
| `responses[].time_spent_seconds` | number | Time spent on question |

---

## 5. Mock Tests

**Firestore Collection:** `users/{userId}/mock_tests/{testId}`

Full JEE Main simulation tests (90 questions, 3 hours).

### Test Summary
| Field | Type | Description |
|-------|------|-------------|
| `test_id` | string | Document ID (UUID) |
| `template_id` | string | Mock test template reference |
| `test_name` | string | Test name (e.g., "Mock Test 1") |
| `started_at` | timestamp | Test start time |
| `submitted_at` | timestamp | Test submission time |
| `completed` | boolean | Whether test was completed |
| `total_questions` | number | Total questions (90) |
| `attempted` | number | Questions attempted |
| `correct` | number | Correct answers |
| `incorrect` | number | Incorrect answers |
| `unattempted` | number | Unattempted questions |

### Scoring
| Field | Type | Description |
|-------|------|-------------|
| `total_marks` | number | Maximum possible marks (300) |
| `obtained_marks` | number | Marks obtained (+4 correct, -1 incorrect) |
| `accuracy` | number | Accuracy percentage (of attempted) |
| `time_taken_seconds` | number | Total time spent |

### Subject-Wise Performance
| Field | Type | Description |
|-------|------|-------------|
| `subject_wise_performance` | object | Performance per subject |
| `subject_wise_performance[subject].total` | number | Total questions (30) |
| `subject_wise_performance[subject].attempted` | number | Questions attempted |
| `subject_wise_performance[subject].correct` | number | Correct answers |
| `subject_wise_performance[subject].marks` | number | Marks obtained in subject |

### Individual Responses
| Field | Type | Description |
|-------|------|-------------|
| `responses` | array | Array of response objects (90 items) |
| `responses[].question_id` | string | Question identifier |
| `responses[].subject` | string | Physics, Chemistry, or Mathematics |
| `responses[].chapter` | string | Chapter name |
| `responses[].question_type` | string | mcq_single or numerical |
| `responses[].difficulty` | string | easy, medium, or hard |
| `responses[].user_answer` | string/null | Student's answer (null if unattempted) |
| `responses[].correct_answer` | string | Correct answer |
| `responses[].is_correct` | boolean | Whether answer was correct |
| `responses[].marks_awarded` | number | Marks awarded (+4, -1, or 0) |
| `responses[].time_spent_seconds` | number | Time spent on question |
| `responses[].state` | string | not_visited, answered, marked_for_review, etc. |

---

## 6. Snap & Solve

**Firestore Collection:** `users/{userId}/snap_history/{snapId}`

Photo-based doubt solving (hero feature).

### Snap Summary
| Field | Type | Description |
|-------|------|-------------|
| `snap_id` | string | Document ID (UUID) |
| `created_at` | timestamp | When snap was created |
| `image_url` | string | Firebase Storage URL for image |
| `question_text` | string | Extracted question text (OCR) |
| `solution_generated` | boolean | Whether solution was generated |

### Classification
| Field | Type | Description |
|-------|------|-------------|
| `subject` | string | Physics, Chemistry, or Mathematics |
| `chapter` | string | Detected chapter |

### Solution
| Field | Type | Description |
|-------|------|-------------|
| `solution_text` | string | Generated solution text |
| `solution_steps` | array | Step-by-step solution |
| `key_concepts` | array | Key concepts used |

### Feedback
| Field | Type | Description |
|-------|------|-------------|
| `feedback` | string | Student feedback (optional) |
| `rating` | number | Solution rating 1-5 (optional) |

---

## 7. AI Tutor

**Firestore Collection:** `users/{userId}/tutor_conversations/{conversationId}`

Conversational tutoring (Ultra tier feature).

### Conversation Summary
| Field | Type | Description |
|-------|------|-------------|
| `conversation_id` | string | Document ID (UUID) |
| `created_at` | timestamp | Conversation start time |
| `last_message_at` | timestamp | Last message timestamp |
| `message_count` | number | Total messages in conversation |
| `status` | string | active or closed |

### Context
| Field | Type | Description |
|-------|------|-------------|
| `subject` | string | Physics, Chemistry, or Mathematics |
| `chapter` | string | Chapter context (optional) |
| `question_context` | string | Related question (optional) |

### Messages
| Field | Type | Description |
|-------|------|-------------|
| `messages` | array | Array of message objects |
| `messages[].role` | string | user or assistant |
| `messages[].content` | string | Message content |
| `messages[].timestamp` | timestamp | Message timestamp |

---

## 8. Theta Evolution

**Firestore Collection:** `users/{userId}/theta_snapshots/{snapshotId}`

Weekly snapshots of learning progress.

### Snapshot Summary
| Field | Type | Description |
|-------|------|-------------|
| `snapshot_id` | string | Document ID (week identifier) |
| `snapshot_date` | timestamp | Snapshot date (Sunday) |
| `overall_theta` | number | Overall theta at snapshot time |
| `overall_percentile` | number | Percentile rank at snapshot time |

### Subject Theta
| Field | Type | Description |
|-------|------|-------------|
| `theta_by_subject` | object | Theta for each subject |
| `theta_by_subject[subject].theta` | number | Subject theta |
| `theta_by_subject[subject].se` | number | Standard error |

### Chapter Theta
| Field | Type | Description |
|-------|------|-------------|
| `theta_by_chapter` | object | Theta for each chapter |
| `theta_by_chapter[chapter_key].theta` | number | Chapter theta |
| `theta_by_chapter[chapter_key].se` | number | Standard error |
| `theta_by_chapter[chapter_key].questions_answered` | number | Questions answered in chapter |

### Weekly Activity
| Field | Type | Description |
|-------|------|-------------|
| `total_questions_answered` | number | Total lifetime questions |
| `weekly_questions` | number | Questions answered this week |
| `weekly_accuracy` | number | Accuracy this week |

---

## 9. Usage & Engagement

**Firestore Collection:** `daily_usage`

Daily usage logs for each user.

### Daily Usage Summary
| Field | Type | Description |
|-------|------|-------------|
| `user_id` | string | User ID |
| `date` | timestamp | Date |
| `snaps_used` | number | Snaps used today |
| `quizzes_taken` | number | Quizzes taken today |
| `chapter_sessions` | number | Chapter practice sessions today |
| `tutor_conversations` | number | AI tutor conversations today |
| `total_time_spent_seconds` | number | Total time spent on platform today |

---

## 10. Data Extraction Script

**Script Location:** `backend/scripts/extract-student-data.js`

### Usage

```bash
# Extract all data for a student by phone number
node backend/scripts/extract-student-data.js +919876543210

# Save to specific file
node backend/scripts/extract-student-data.js +919876543210 --output student.json

# Pretty-print JSON
node backend/scripts/extract-student-data.js +919876543210 --format pretty

# Show help
node backend/scripts/extract-student-data.js --help
```

### Output Structure

The script generates a comprehensive JSON file with the following structure:

```json
{
  "extraction_timestamp": "2026-02-07T10:30:00.000Z",
  "user_id": "userId",
  "phone_number": "+919876543210",

  "profile": { /* User profile & subscription */ },
  "assessment": { /* Initial assessment data */ },
  "daily_quizzes": { /* Daily quiz history */ },
  "chapter_practice": { /* Chapter practice sessions */ },
  "mock_tests": { /* Mock test data */ },
  "snap_history": { /* Snap & solve history */ },
  "ai_tutor": { /* AI tutor conversations */ },
  "theta_evolution": { /* Weekly theta snapshots */ },
  "usage_metrics": { /* Daily usage logs */ }
}
```

### Features

- ✅ **Complete data extraction** across all learning activities
- ✅ **Aggregated statistics** (monthly, chapter-wise, subject-wise)
- ✅ **Theta evolution tracking** over time
- ✅ **Clean JSON output** with formatted timestamps
- ✅ **CLI interface** with customizable output
- ✅ **Detailed summary** printed to console

---

## 11. Analytics Use Cases

### Student Performance Dashboard

**Data Sources:** Profile, Daily Quizzes, Chapter Practice, Theta Evolution

**Key Metrics:**
- Overall theta & percentile rank
- Subject-wise theta comparison
- Weekly progress (theta change)
- Accuracy trends over time
- Questions answered per week
- Current streak & longest streak

**Visualizations:**
- Line chart: Theta evolution over time
- Bar chart: Subject-wise performance
- Heatmap: Chapter mastery
- Progress gauge: Percentile rank

### Learning Patterns Analysis

**Data Sources:** Daily Quizzes, Chapter Practice, Usage Metrics

**Key Metrics:**
- Most practiced chapters
- Weakest chapters (lowest theta)
- Time spent per subject
- Peak activity hours
- Quiz completion rate
- Average time per question

**Visualizations:**
- Bar chart: Chapter practice frequency
- Pie chart: Time distribution by subject
- Line chart: Daily activity patterns
- Scatter plot: Time vs accuracy

### Mock Test Performance

**Data Sources:** Mock Tests

**Key Metrics:**
- Test scores over time
- Subject-wise performance in tests
- Question state distribution (answered, marked, unattempted)
- Time management (time per question)
- Accuracy in different difficulty levels

**Visualizations:**
- Line chart: Mock test scores over time
- Stacked bar chart: Subject-wise marks
- Pie chart: Question state distribution
- Histogram: Time spent per question

### Engagement & Retention

**Data Sources:** Usage Metrics, Profile, Daily Quizzes

**Key Metrics:**
- Daily active users
- Streak distribution
- Feature usage breakdown (snaps, quizzes, practice, tutor)
- Time spent on platform
- Subscription tier distribution
- Trial conversion rate

**Visualizations:**
- Line chart: Daily active users
- Bar chart: Feature usage
- Funnel chart: Trial to paid conversion
- Cohort analysis: Retention over time

### AI Tutor Effectiveness

**Data Sources:** AI Tutor, Chapter Practice, Theta Evolution

**Key Metrics:**
- Conversations per user
- Messages per conversation
- Theta improvement after tutor sessions
- Most discussed topics
- User satisfaction (if feedback collected)

**Visualizations:**
- Bar chart: Conversation frequency
- Word cloud: Popular topics
- Line chart: Theta before/after tutor usage

### Snap & Solve Insights

**Data Sources:** Snap History

**Key Metrics:**
- Snaps per day
- Subject distribution
- Chapter distribution
- Solution success rate
- User ratings (if collected)

**Visualizations:**
- Pie chart: Subject distribution
- Bar chart: Chapter distribution
- Line chart: Daily snap usage
- Histogram: Solution ratings

---

## Data Privacy & Security

### Storage
- All data stored in Firebase Firestore with security rules
- Images stored in Firebase Storage with access controls
- User data accessible only to authenticated users and admins

### Compliance
- Phone number verified via OTP (Firebase Auth)
- No sensitive payment data stored (Razorpay handles payments)
- Data retention policies enforced
- GDPR/DPDPA compliant (user data deletion on request)

### Access Control
- Students can only access their own data
- Teachers can access aggregated, anonymized data
- Admins have full access for support and analytics

---

## Future Enhancements

### Planned Data Collection

1. **Video Lectures**: Track video watch time, completion rate
2. **Study Plans**: Track study plan adherence, goal completion
3. **Peer Comparison**: Anonymous percentile-based comparisons
4. **Error Patterns**: Identify common mistake patterns
5. **Question Difficulty Calibration**: Track question performance across users

### Planned Analytics

1. **Predictive Models**: Predict JEE scores based on theta evolution
2. **Recommendation Engine**: Suggest chapters to practice
3. **Learning Path Optimization**: Identify optimal study sequences
4. **Early Warning System**: Flag students at risk of dropping out
5. **A/B Testing**: Test feature effectiveness

---

## Appendix: Key Formulas

### Theta Calculation (3PL Model)

```
P(θ) = c + (1-c) / (1 + e^(-1.702 * a * (θ - b)))
```

Where:
- `P(θ)` = Probability of correct answer at ability θ
- `θ` = Student ability (theta)
- `a` = Discrimination (0.5 - 2.5)
- `b` = Difficulty (-3 to +3)
- `c` = Guessing parameter (0.25 for MCQ)

### Theta Update (Bayesian)

```
θ_new = θ_old + learning_rate × (is_correct - P(θ)) × a
SE_new = clamp(SE × decay_factor, 0.15, 0.6)
```

### Overall Theta (Weighted Average)

```
overall_theta = Σ(subject_theta × subject_weight) / Σ(subject_weight)
```

### Subject Theta (Weighted Average)

```
subject_theta = Σ(chapter_theta × chapter_weight) / Σ(chapter_weight)
```

---

**Document Version:** 1.0
**Last Updated:** 2026-02-07
**Maintained By:** JEEVibe Engineering Team
