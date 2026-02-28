# Test Factories

This directory contains programmatic test data generators for JEEVibe backend testing.

## Why Factories?

Factories provide:
- **Consistency**: Same data structure every time
- **Flexibility**: Easy to customize specific fields
- **Readability**: Self-documenting test intent
- **Maintainability**: Single source of truth for test data

## Files

### 1. userFactory.js
Creates user profile data with theta values and subscription status.

**Functions:**
- `createUser(overrides)` - Base user with defaults
- `createFreeUser(overrides)` - Free tier user
- `createProUser(overrides)` - Pro tier with testing override
- `createUltraUser(overrides)` - Ultra tier with testing override
- `createTrialUser(daysRemaining, overrides)` - Trial user
- `createUserWithProgress(skillLevel, quizzesCompleted, overrides)` - User with specific theta
- `generateThetaData(skillLevel, quizzesCompleted)` - Standalone theta generator

**Usage:**
```javascript
const { createProUser, createUserWithProgress } = require('./factories/userFactory');

// Create Pro user with custom phone
const proUser = createProUser({
  phoneNumber: '+16505551234',
  displayName: 'John Doe'
});

// Create advanced user with 150 quizzes
const advancedUser = createUserWithProgress('advanced', 150, {
  isEnrolledInCoaching: true
});
```

---

### 2. questionFactory.js
Creates questions with proper IRT parameters.

**Functions:**
- `createQuestion(overrides)` - Base question
- `createPhysicsQuestion(overrides)` - Physics question
- `createChemistryQuestion(overrides)` - Chemistry question
- `createMathematicsQuestion(overrides)` - Math question
- `createEasyQuestion(overrides)` - Easy difficulty (b < -0.3)
- `createMediumQuestion(overrides)` - Medium difficulty (-0.3 < b < 0.3)
- `createHardQuestion(overrides)` - Hard difficulty (b > 0.3)
- `createNumericalQuestion(overrides)` - Numerical type (no options)
- `createQuestionWithIRT(difficulty_b, discrimination_a, guessing_c, overrides)` - Custom IRT
- `createMultipleQuestions(count, template)` - Batch creation
- `createAssessmentQuestion(overrides)` - Assessment format

**Usage:**
```javascript
const { createHardQuestion, createQuestionWithIRT } = require('./factories/questionFactory');

// Create hard physics question
const hardPhysics = createHardQuestion({
  subject: 'Physics',
  chapter_key: 'physics_electrostatics'
});

// Create question with specific IRT parameters
const customQuestion = createQuestionWithIRT(1.2, 1.8, 0.25, {
  question_text: 'Custom question text'
});
```

---

### 3. quizFactory.js
Creates quiz sessions, responses, and submissions.

**Functions:**
- `createQuizSession(overrides)` - In-progress quiz
- `createCompletedQuizSession(overrides)` - Completed quiz
- `createQuizResponse(overrides)` - Single question response
- `createQuizSubmission(totalQuestions, correctCount, overrides)` - Full submission
- `createPerfectQuizSubmission(totalQuestions, overrides)` - All correct
- `createFailedQuizSubmission(totalQuestions, overrides)` - All incorrect
- `createInvalidQuizSubmission(missingField)` - Invalid for error testing
- `createDailyQuizHistory(overrides)` - Historical entry
- `createChapterPracticeSession(overrides)` - Chapter practice
- `createCompletedChapterPracticeSession(overrides)` - Completed practice

**Usage:**
```javascript
const { createPerfectQuizSubmission, createInvalidQuizSubmission } = require('./factories/quizFactory');

// Test perfect score
const perfectQuiz = createPerfectQuizSubmission(5, {
  user_id: 'test-user-pro-001'
});

// Test error handling
const invalidQuiz = createInvalidQuizSubmission('user_id'); // missing user_id
```

---

### 4. mockTestFactory.js
Creates mock test data (90 questions, 3 hours, 300 marks).

**Functions:**
- `createMockTestTemplate(overrides)` - Test template
- `createMockTestSession(overrides)` - In-progress session
- `createQuestionState(state, selectedAnswer)` - Question state object
- `createMockTestResponse(overrides)` - Single question response
- `createMockTestSubmission(correctCount, incorrectCount, overrides)` - Full submission
- `createExcellentMockTestSubmission(overrides)` - 75 correct, 10 incorrect
- `createAverageMockTestSubmission(overrides)` - 50 correct, 20 incorrect
- `createPoorMockTestSubmission(overrides)` - 30 correct, 30 incorrect
- `createMockTestResult(overrides)` - Result summary

**Usage:**
```javascript
const { createExcellentMockTestSubmission } = require('./factories/mockTestFactory');

// Test excellent performance
const excellentResult = createExcellentMockTestSubmission({
  user_id: 'test-user-ultra-001'
});
// Returns: 75 correct, 10 incorrect, 5 unattempted → 290 marks
```

---

### 5. subscriptionFactory.js
Creates subscription data for all tier types.

**Functions:**
- `createSubscription(overrides)` - Base subscription
- `createFreeSubscription(overrides)` - Free tier
- `createProSubscription(overrides)` - Pro tier (paid)
- `createUltraSubscription(overrides)` - Ultra tier (paid)
- `createSubscriptionWithOverride(tier, daysValid, overrides)` - Testing override
- `createBetaSubscription(tier, daysValid, overrides)` - Beta tester override
- `createTrialSubscription(daysRemaining, overrides)` - Active trial
- `createExpiredTrialSubscription(overrides)` - Expired trial
- `createUserSubscriptionData(tier, overrides)` - Complete user subscription
- `createSubscriptionDocument(overrides)` - Firestore subscription doc
- `createCancelledSubscription(overrides)` - Cancelled subscription

**Usage:**
```javascript
const { createTrialSubscription, createSubscriptionWithOverride } = require('./factories/subscriptionFactory');

// Create expiring trial (1 day remaining)
const expiringTrial = createTrialSubscription(1, {
  user_id: 'test-user-trial-expiring'
});

// Create Pro override for testing
const proOverride = createSubscriptionWithOverride('pro', 90, {
  override: { reason: 'Testing tier enforcement' }
});
```

---

## Best Practices

### 1. Use Factories in Tests

**❌ Bad: Manual object creation**
```javascript
test('should accept valid quiz', async () => {
  const quiz = {
    user_id: 'test-user-001',
    quiz_id: 'quiz_123',
    responses: [
      {
        question_id: 'Q1',
        selected_answer: 'A',
        is_correct: true,
        time_spent_seconds: 45
      },
      // ... repeat manually for 5 questions
    ]
  };

  const result = await quizService.submitQuiz(quiz);
  expect(result.success).toBe(true);
});
```

**✅ Good: Factory usage**
```javascript
test('should accept valid quiz', async () => {
  const quiz = createPerfectQuizSubmission(5, {
    user_id: 'test-user-001'
  });

  const result = await quizService.submitQuiz(quiz);
  expect(result.success).toBe(true);
});
```

---

### 2. Override Only What's Necessary

**❌ Bad: Overriding too many fields**
```javascript
const user = createUser({
  userId: 'test-user-001',
  phoneNumber: '+16505551001',
  displayName: 'Test User',
  overall_theta: 0.0,
  overall_percentile: 50.0,
  // ... 20 more fields
});
```

**✅ Good: Override only what matters for test**
```javascript
const user = createUser({
  userId: 'test-user-001',
  overall_theta: 0.5 // Only override what's being tested
});
```

---

### 3. Combine Factories and Fixtures

**Use fixtures for static data, factories for dynamic variations**

```javascript
const baseQuestion = require('../fixtures/questions-100.json')[0];
const questionFactory = require('../factories/questionFactory');

// Create 10 variations of the base question with different difficulties
const easyVariant = questionFactory.createQuestion({
  ...baseQuestion,
  irt_parameters: { difficulty_b: -0.5, discrimination_a: 1.2, guessing_c: 0.25 }
});

const hardVariant = questionFactory.createQuestion({
  ...baseQuestion,
  irt_parameters: { difficulty_b: 1.2, discrimination_a: 1.9, guessing_c: 0.25 }
});
```

---

### 4. Testing Edge Cases

**Use factories to generate edge case data**

```javascript
describe('Subscription Service', () => {
  test('should handle expiring trial (1 day remaining)', async () => {
    const expiringTrial = createTrialSubscription(1);
    // Test warning notification logic
  });

  test('should handle expired trial', async () => {
    const expiredTrial = createExpiredTrialSubscription();
    // Test downgrade to free tier
  });

  test('should handle expired override', async () => {
    const expiredOverride = createSubscriptionWithOverride('pro', -1); // Expired yesterday
    // Test fallback to default tier
  });
});
```

---

### 5. Factory Composition

**Build complex scenarios by combining factories**

```javascript
const { createUserWithProgress } = require('./userFactory');
const { createPerfectQuizSubmission } = require('./quizFactory');

describe('Theta Update Service', () => {
  test('should increase theta after perfect quiz', async () => {
    // Create intermediate user
    const user = createUserWithProgress('intermediate', 50);
    expect(user.overall_theta).toBe(0.0);

    // Submit perfect quiz
    const quiz = createPerfectQuizSubmission(5, {
      user_id: user.userId
    });

    const result = await thetaUpdateService.updateTheta(user.userId, quiz);

    // Theta should increase
    expect(result.theta_after).toBeGreaterThan(user.overall_theta);
  });
});
```

---

## Testing the Factories

To ensure factories produce valid data, create a simple test:

```javascript
// backend/tests/factories/factories.test.js
describe('Factory Tests', () => {
  test('userFactory creates valid user', () => {
    const user = createUser();
    expect(user).toHaveProperty('userId');
    expect(user).toHaveProperty('subscriptionStatus');
    expect(user.overall_theta).toBeGreaterThanOrEqual(-3);
    expect(user.overall_theta).toBeLessThanOrEqual(3);
  });

  test('questionFactory creates valid question', () => {
    const question = createQuestion();
    expect(question).toHaveProperty('question_id');
    expect(question.irt_parameters.difficulty_b).toBeGreaterThanOrEqual(-3);
    expect(question.irt_parameters.guessing_c).toBe(0.25);
  });
});
```

---

## Related Files

- `backend/tests/fixtures/` - Static JSON test data
- `backend/scripts/setup-test-users.js` - Creates real test users in Firestore
- `docs/05-testing/e2e/TESTING-USERS.md` - Test user credentials

---

**Last Updated:** 2026-02-27
**Maintained By:** Testing Infrastructure Team
