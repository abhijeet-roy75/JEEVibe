# Test Fixtures

This directory contains JSON fixtures for testing JEEVibe backend services and routes.

## Files

### 1. questions-100.json
**Purpose:** Sample questions across Physics, Chemistry, and Mathematics with full IRT parameters

**Contents:**
- 5 sample questions (expandable to 100)
- Complete question structure with options, solutions, and IRT parameters
- Covers easy, medium, and hard difficulties
- All three subjects represented

**Usage:**
```javascript
const questions = require('./fixtures/questions-100.json');
const easyQuestion = questions.find(q => q.difficulty === 'easy');
```

---

### 2. mock-test-template.json
**Purpose:** Full JEE Main mock test template with 90 questions

**Contents:**
- 90 question IDs (30 per subject)
- Question type breakdown (20 MCQ + 10 Numerical per subject)
- Marking scheme (+4/-1/0)
- Duration: 10,800 seconds (3 hours)
- Maximum marks: 300

**Usage:**
```javascript
const template = require('./fixtures/mock-test-template.json');
const physicsQuestions = template.subjects.physics.question_ids;
```

---

### 3. assessment-questions-30.json
**Purpose:** Initial assessment questions for theta calculation

**Contents:**
- 6 sample questions (expandable to 30)
- Broad chapter mapping (Mechanics, Electromagnetism, Physical Chemistry, etc.)
- Mix of easy and medium difficulties
- IRT parameters for adaptive selection

**Usage:**
```javascript
const assessmentQuestions = require('./fixtures/assessment-questions-30.json');
const physicsQuestion = assessmentQuestions.find(q => q.subject === 'Physics');
```

---

### 4. quiz-responses-valid.json
**Purpose:** Valid quiz submission examples for testing daily quiz flow

**Contents:**
- 3 submission scenarios: valid (4/5 correct), perfect (5/5), poor (0/5)
- Complete response structure with time spent
- Different user IDs and quiz IDs

**Usage:**
```javascript
const validResponses = require('./fixtures/quiz-responses-valid.json');
const perfectQuiz = validResponses.perfect_quiz_submission;
```

---

### 5. quiz-responses-invalid.json
**Purpose:** Invalid quiz submissions for error handling tests

**Contents:**
- 7 invalid scenarios:
  - Missing user_id
  - Missing quiz_id
  - Empty responses array
  - Invalid answer format (number instead of string)
  - Missing question_id
  - Negative time_spent
  - Malformed JSON

**Usage:**
```javascript
const invalidResponses = require('./fixtures/quiz-responses-invalid.json');
const missingUserId = invalidResponses.missing_user_id;
```

---

### 6. user-theta-data.json
**Purpose:** Sample theta data for different skill levels

**Contents:**
- 3 user profiles: beginner (-0.5 theta), intermediate (-0.2 theta), advanced (0.5 theta)
- Overall theta, percentile, subject theta, chapter theta
- Varying standard errors and question counts
- Realistic progression data

**Usage:**
```javascript
const thetaData = require('./fixtures/user-theta-data.json');
const beginnerTheta = thetaData.beginner_user.overall_theta;
```

---

### 7. weak-spot-event-log.json
**Purpose:** Cognitive mastery weak spot event log samples

**Contents:**
- 13 events across 4 users
- Event types: weak_spot_detected, capsule_opened, capsule_completed, retrieval_attempted, state_change
- Complete flow examples (detected → improving → mastered)
- Different severity levels (low, moderate, high)

**Usage:**
```javascript
const events = require('./fixtures/weak-spot-event-log.json');
const detectionEvents = events.filter(e => e.event_type === 'weak_spot_detected');
```

---

### 8. subscription-data.json
**Purpose:** Subscription tier data for all tier types

**Contents:**
- 7 subscription scenarios:
  - Free tier (default)
  - Pro tier (paid subscription)
  - Pro tier (testing override)
  - Ultra tier (testing override)
  - Trial active (25 days remaining)
  - Trial expiring (1 day remaining)
  - Trial expired (now free)

**Usage:**
```javascript
const subscriptionData = require('./fixtures/subscription-data.json');
const freeUser = subscriptionData.free_tier;
const proOverride = subscriptionData.pro_tier_override;
```

---

## Best Practices

### 1. Loading Fixtures in Tests

**Option A: Direct require (simple)**
```javascript
describe('Quiz Service', () => {
  const validQuiz = require('../fixtures/quiz-responses-valid.json').valid_quiz_submission;

  test('should accept valid quiz submission', async () => {
    const result = await quizService.submitQuiz(validQuiz);
    expect(result.success).toBe(true);
  });
});
```

**Option B: Helper function (reusable)**
```javascript
const loadFixture = (filename) => require(`../fixtures/${filename}`);

describe('Quiz Service', () => {
  test('should reject invalid quiz', async () => {
    const invalidQuiz = loadFixture('quiz-responses-invalid.json').missing_user_id;
    await expect(quizService.submitQuiz(invalidQuiz)).rejects.toThrow();
  });
});
```

---

### 2. Modifying Fixtures for Tests

**Don't mutate original fixture:**
```javascript
// ❌ Bad - mutates original
const question = require('../fixtures/questions-100.json')[0];
question.difficulty = 'hard'; // Affects other tests!

// ✅ Good - create copy
const originalQuestion = require('../fixtures/questions-100.json')[0];
const question = { ...originalQuestion, difficulty: 'hard' };
```

---

### 3. Creating Dynamic Test Data

**Combine fixtures with factories:**
```javascript
const baseQuestion = require('../fixtures/questions-100.json')[0];
const questionFactory = require('../factories/questionFactory');

const customQuestion = questionFactory.create({
  ...baseQuestion,
  difficulty: 'hard',
  irt_parameters: { difficulty_b: 1.5, discrimination_a: 2.0, guessing_c: 0.25 }
});
```

---

## Maintenance

### Adding New Fixtures

1. Create JSON file in this directory
2. Follow existing naming convention (kebab-case)
3. Add documentation section in this README
4. Include usage example
5. Add to relevant test files

### Updating Fixtures

1. Check if any tests depend on exact values
2. Update fixture file
3. Run all tests to ensure no breakage
4. Update documentation if structure changes

---

## Related Files

- `backend/tests/factories/` - Programmatic test data generation
- `backend/scripts/setup-test-users.js` - Creates test users in Firestore
- `docs/05-testing/e2e/TESTING-USERS.md` - Test user credentials

---

**Last Updated:** 2026-02-27
**Maintained By:** Testing Infrastructure Team
