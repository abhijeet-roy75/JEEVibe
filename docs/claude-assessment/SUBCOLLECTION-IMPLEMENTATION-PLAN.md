# Quiz Subcollection Implementation Plan

**Date**: January 1, 2026
**Status**: READY TO IMPLEMENT
**Estimated Time**: 3-4 hours (includes testing)
**Risk Level**: LOW (with clean DB, comprehensive tests)

---

## Overview

Refactor quiz storage from embedded questions array to subcollection pattern to eliminate 1MB document size risk and enable better scalability.

### Current Structure
```
daily_quizzes/{userId}/quizzes/{quizId}
  ├── questions: [10 question objects]  // 20-30 KB embedded
  └── other quiz metadata
```

### New Structure
```
daily_quizzes/{userId}/quizzes/{quizId}
  ├── quiz metadata (NO questions array)
  └── questions/{position}  // Subcollection
      ├── 0/ (question data)
      ├── 1/ (question data)
      └── ... (10 documents)
```

---

## Implementation Phases

### Phase 1: Cleanup Script Update ✅ COMPLETED

**File**: `backend/scripts/cleanup-user.js`

**Changes Made**:
1. Added `deleteQuizzesWithSubcollections()` function
2. Updated cleanup flow to delete question subcollections recursively
3. Enhanced preview mode to show question document counts

**What It Does**:
```javascript
// For each quiz:
// 1. Delete questions subcollection (all 10 documents)
// 2. Delete quiz document itself
// 3. Track total count for logging
```

**Testing**:
```bash
# Preview mode (dry run)
node scripts/cleanup-user.js <userId> --preview

# Actual cleanup
node scripts/cleanup-user.js <userId>
```

---

### Phase 2: Service Layer Refactoring (2 hours)

#### A. Create Quiz with Subcollection

**File**: `backend/src/services/dailyQuizService.js`

**Current Code** (~line 200):
```javascript
// Create quiz document with embedded questions
const quizData = {
  quiz_id: quizId,
  status: 'in_progress',
  questions: selectedQuestions,  // ← Remove this
  total_questions: selectedQuestions.length,
  // ... other fields
};

await quizRef.set(quizData);
```

**New Code**:
```javascript
// 1. Create quiz metadata (without questions)
const quizMetadata = {
  quiz_id: quizId,
  quiz_number: quizNumber,
  status: 'in_progress',
  learning_phase: learningPhase,

  // Summary fields
  total_questions: selectedQuestions.length,
  answered_questions: 0,
  score: 0,
  accuracy: 0,
  total_time_seconds: 0,

  // Metadata
  generated_at: new Date().toISOString(),
  is_recovery_quiz: isRecoveryQuiz || false,
  chapters_covered: [...new Set(selectedQuestions.map(q => q.chapter_key))],

  // NO questions array!
};

// 2. Create questions in subcollection using batch write
const batch = db.batch();

// Add quiz metadata
batch.set(quizRef, quizMetadata);

// Add each question to subcollection
const questionsRef = quizRef.collection('questions');
selectedQuestions.forEach((question, index) => {
  const questionRef = questionsRef.doc(String(index));

  // Strip sensitive fields (answers, solutions)
  const { correct_answer, correct_answer_text, solution_text, solution_steps, ...sanitized } = question;

  batch.set(questionRef, {
    position: index,
    ...sanitized,
    answered: false,
    student_answer: null,
    is_correct: null,
    time_taken_seconds: 0
  });
});

// 3. Commit atomically (all or nothing)
await batch.commit();

logger.info('Quiz created with subcollection', {
  userId,
  quizId,
  total_questions: selectedQuestions.length
});
```

**Error Handling**:
```javascript
try {
  await batch.commit();
} catch (error) {
  logger.error('Failed to create quiz with subcollection', {
    userId,
    quizId,
    error: error.message
  });

  // Batch write is atomic - if it fails, nothing is written
  throw new Error('Quiz creation failed: ' + error.message);
}
```

---

#### B. Fetch Quiz with Questions

**File**: `backend/src/routes/dailyQuiz.js`

**Helper Function** (add at top of file):
```javascript
/**
 * Load quiz with questions from subcollection
 * @param {string} userId
 * @param {string} quizId
 * @returns {Promise<Object>} Quiz with questions array
 */
async function getQuizWithQuestions(userId, quizId) {
  const quizRef = db
    .collection('daily_quizzes')
    .doc(userId)
    .collection('quizzes')
    .doc(quizId);

  // Fetch quiz metadata
  const quizDoc = await quizRef.get();

  if (!quizDoc.exists) {
    throw new Error('Quiz not found');
  }

  const quizMetadata = quizDoc.data();

  // Fetch questions subcollection
  const questionsSnapshot = await quizRef
    .collection('questions')
    .orderBy('position')
    .get();

  if (questionsSnapshot.empty) {
    throw new Error('Quiz questions not loaded');
  }

  const questions = questionsSnapshot.docs.map(doc => doc.data());

  // Verify we have all questions
  if (questions.length !== quizMetadata.total_questions) {
    logger.warn('Question count mismatch', {
      userId,
      quizId,
      expected: quizMetadata.total_questions,
      actual: questions.length
    });
  }

  return {
    ...quizMetadata,
    questions: questions
  };
}
```

**Usage in GET /api/daily-quiz/active**:
```javascript
// Before (current)
const activeQuizDoc = await db
  .collection('daily_quizzes')
  .doc(userId)
  .collection('quizzes')
  .where('status', '==', 'in_progress')
  .limit(1)
  .get();

const activeQuiz = activeQuizDoc.docs[0]?.data();

// After (with subcollection)
const activeQuizDoc = await db
  .collection('daily_quizzes')
  .doc(userId)
  .collection('quizzes')
  .where('status', '==', 'in_progress')
  .limit(1)
  .get();

if (activeQuizDoc.empty) {
  return res.json({ quiz: null });
}

const quizRef = activeQuizDoc.docs[0].ref;
const activeQuiz = await getQuizWithQuestions(userId, quizRef.id);

res.json({ quiz: activeQuiz });
```

---

#### C. Submit Answer (Update Single Question)

**File**: `backend/src/services/quizResponseService.js`

**Current Code** (~line 240):
```javascript
// Update question in embedded array → rewrite entire quiz doc
const quizData = await quizRef.get();
const questions = quizData.questions;
questions[questionIndex] = {
  ...questions[questionIndex],
  answered: true,
  student_answer: answer,
  is_correct: isCorrect
};

await quizRef.update({
  questions: questions  // ← Rewrite entire 30 KB array
});
```

**New Code**:
```javascript
// Update only the specific question document
const questionRef = quizRef
  .collection('questions')
  .doc(String(questionIndex));

// Update question and quiz summary in parallel
await Promise.all([
  // Update question document
  questionRef.update({
    answered: true,
    student_answer: answer,
    is_correct: isCorrect,
    time_taken_seconds: timeTaken,
    answered_at: admin.firestore.FieldValue.serverTimestamp()
  }),

  // Update quiz summary stats
  quizRef.update({
    answered_questions: admin.firestore.FieldValue.increment(1),
    last_answered_at: admin.firestore.FieldValue.serverTimestamp()
  })
]);

logger.info('Answer submitted to subcollection', {
  userId,
  quizId,
  questionIndex,
  isCorrect
});
```

---

#### D. Complete Quiz (Fetch All Responses)

**File**: `backend/src/routes/dailyQuiz.js` (completeQuiz endpoint)

**Current Code**:
```javascript
// Quiz already has all questions with answers
const quizData = await quizRef.get();
const responses = quizData.questions.filter(q => q.answered);
```

**New Code**:
```javascript
// Fetch all answered questions from subcollection
const questionsSnapshot = await quizRef
  .collection('questions')
  .where('answered', '==', true)
  .orderBy('position')
  .get();

const responses = questionsSnapshot.docs.map(doc => doc.data());

// Verify all questions answered
const quizMetadata = await quizRef.get();
if (responses.length !== quizMetadata.data().total_questions) {
  throw new Error('Not all questions answered');
}

// Calculate score
const correctCount = responses.filter(r => r.is_correct).length;
const accuracy = correctCount / responses.length;

// Update quiz as completed
await quizRef.update({
  status: 'completed',
  score: correctCount,
  accuracy: accuracy,
  completed_at: admin.firestore.FieldValue.serverTimestamp()
});
```

---

### Phase 3: API Route Updates (30 minutes)

**Files to Update**:
- `backend/src/routes/dailyQuiz.js`

**Endpoints to Modify**:

1. **POST /api/daily-quiz/generate** ✓ (uses dailyQuizService)
2. **GET /api/daily-quiz/active** ✓ (uses getQuizWithQuestions helper)
3. **POST /api/daily-quiz/submit-answer** ✓ (uses quizResponseService)
4. **POST /api/daily-quiz/complete** ✓ (updated above)
5. **GET /api/daily-quiz/result/:quizId** (needs update):
```javascript
router.get('/result/:quizId', verifyToken, async (req, res, next) => {
  try {
    const userId = req.user.uid;
    const { quizId } = req.params;

    // Load quiz with questions
    const quiz = await getQuizWithQuestions(userId, quizId);

    // Return result (same format as before)
    res.json({
      quiz: quiz,
      // ... other result data
    });
  } catch (error) {
    next(error);
  }
});
```

---

### Phase 4: Testing (1.5 hours)

#### A. Unit Tests

**File**: `backend/tests/unit/services/quizSubcollection.test.js` (NEW)

```javascript
const { createQuizWithSubcollection, getQuizWithQuestions } = require('../../src/services/dailyQuizService');

describe('Quiz Subcollection Pattern', () => {
  let userId;
  let mockQuestions;

  beforeEach(() => {
    userId = 'test-user-123';
    mockQuestions = Array(10).fill(null).map((_, i) => ({
      question_id: `q${i}`,
      subject: 'Physics',
      chapter: 'Kinematics',
      question_text: `Question ${i}`,
      position: i
    }));
  });

  test('should create quiz with questions in subcollection', async () => {
    const quiz = await createQuizWithSubcollection(userId, mockQuestions);

    expect(quiz.total_questions).toBe(10);
    expect(quiz.questions).toBeUndefined(); // No embedded questions

    // Verify subcollection exists
    const questionsSnapshot = await db
      .collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .doc(quiz.quiz_id)
      .collection('questions')
      .get();

    expect(questionsSnapshot.size).toBe(10);
  });

  test('should fetch quiz with questions', async () => {
    const created = await createQuizWithSubcollection(userId, mockQuestions);
    const loaded = await getQuizWithQuestions(userId, created.quiz_id);

    expect(loaded.questions).toHaveLength(10);
    expect(loaded.questions[0].position).toBe(0);
    expect(loaded.total_questions).toBe(10);
  });

  test('should throw error if questions missing', async () => {
    // Create quiz without questions subcollection
    const quizRef = db.collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .doc('test-quiz');

    await quizRef.set({
      quiz_id: 'test-quiz',
      total_questions: 10,
      status: 'in_progress'
    });

    await expect(
      getQuizWithQuestions(userId, 'test-quiz')
    ).rejects.toThrow('Quiz questions not loaded');
  });

  test('should update single question without affecting others', async () => {
    const quiz = await createQuizWithSubcollection(userId, mockQuestions);

    // Submit answer to question 2
    await submitAnswerToSubcollection(userId, quiz.quiz_id, 2, 'B', true);

    // Check question 2 updated
    const q2 = await db
      .collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .doc(quiz.quiz_id)
      .collection('questions')
      .doc('2')
      .get();

    expect(q2.data().answered).toBe(true);
    expect(q2.data().student_answer).toBe('B');

    // Check question 3 unaffected
    const q3 = await db
      .collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .doc(quiz.quiz_id)
      .collection('questions')
      .doc('3')
      .get();

    expect(q3.data().answered).toBe(false);
  });
});
```

#### B. Integration Tests

**File**: `backend/tests/integration/api/quizSubcollection.test.js` (NEW)

```javascript
describe('Quiz Subcollection API Integration', () => {
  test('POST /api/daily-quiz/generate creates subcollection', async () => {
    const response = await request(app)
      .post('/api/daily-quiz/generate')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    const quiz = response.body.quiz;

    // Verify response has questions
    expect(quiz.questions).toHaveLength(10);

    // Verify Firestore has subcollection
    const questionsSnapshot = await db
      .collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .doc(quiz.quiz_id)
      .collection('questions')
      .get();

    expect(questionsSnapshot.size).toBe(10);
  });

  test('GET /api/daily-quiz/active loads from subcollection', async () => {
    // Create quiz first
    await request(app)
      .post('/api/daily-quiz/generate')
      .set('Authorization', `Bearer ${token}`);

    // Get active quiz
    const response = await request(app)
      .get('/api/daily-quiz/active')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(response.body.quiz.questions).toHaveLength(10);
  });

  test('POST /api/daily-quiz/submit-answer updates subcollection', async () => {
    const quiz = await createTestQuiz(userId);

    await request(app)
      .post('/api/daily-quiz/submit-answer')
      .set('Authorization', `Bearer ${token}`)
      .send({
        quiz_id: quiz.quiz_id,
        question_index: 0,
        answer: 'A'
      })
      .expect(200);

    // Verify question document updated
    const questionDoc = await db
      .collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .doc(quiz.quiz_id)
      .collection('questions')
      .doc('0')
      .get();

    expect(questionDoc.data().answered).toBe(true);
  });
});
```

#### C. Cleanup Script Testing

```bash
# 1. Create test user with quizzes
node scripts/create-test-user.js test-user-123

# 2. Preview cleanup (verify counts)
node scripts/cleanup-user.js test-user-123 --preview

# Expected output:
#   [DRY RUN] Would delete 5 quiz documents...
#   [DRY RUN] Would delete 50 question documents from quiz subcollections...

# 3. Actual cleanup
node scripts/cleanup-user.js test-user-123

# 4. Verify all deleted
# Check Firestore Console - no documents should remain
```

---

### Phase 5: Deployment (30 minutes)

#### Step 1: Clean Database
```bash
# Run cleanup for all test users
node scripts/cleanup-user.js <test-user-1>
node scripts/cleanup-user.js <test-user-2>
# ... etc

# Verify DB is clean in Firestore Console
```

#### Step 2: Deploy Backend
```bash
cd backend
npm test                    # Run all tests
git add .
git commit -m "feat: migrate quiz storage to subcollection pattern

- Split quiz questions into subcollection (eliminates 1MB size risk)
- Update cleanup script to handle nested subcollections
- Add helper functions for loading quizzes with questions
- Comprehensive test coverage (unit + integration)

Breaking change: Requires clean database (quiz structure changed)
"

git push
./deploy.sh                 # Deploy to production
```

#### Step 3: Verify Deployment
```bash
# 1. Create test quiz
curl -X POST https://api.jeevibe.com/api/daily-quiz/generate \
  -H "Authorization: Bearer $TOKEN"

# 2. Check Firestore Console
# Verify quiz has questions subcollection

# 3. Submit answer
curl -X POST https://api.jeevibe.com/api/daily-quiz/submit-answer \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"quiz_id": "...", "question_index": 0, "answer": "A"}'

# 4. Complete quiz
curl -X POST https://api.jeevibe.com/api/daily-quiz/complete \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"quiz_id": "..."}'
```

---

## Validation Checklist

Before deploying to production:

### Code Quality ✅
- [ ] All unit tests passing
- [ ] All integration tests passing
- [ ] No console.log statements (use logger)
- [ ] Error handling on all async operations
- [ ] Input validation on all API endpoints

### Data Integrity ✅
- [ ] Quiz metadata has `total_questions` field
- [ ] All questions have `position` field (0-9)
- [ ] Question order preserved
- [ ] No duplicate positions
- [ ] Atomic writes (batch.commit for quiz creation)

### API Compatibility ✅
- [ ] Response format unchanged (questions array in response)
- [ ] Mobile app works without changes
- [ ] All existing endpoints functional
- [ ] Error messages clear and helpful

### Performance ✅
- [ ] Quiz generation <3 seconds
- [ ] Quiz fetch <500ms
- [ ] Answer submission <200ms
- [ ] No N+1 query problems
- [ ] Batch writes used where possible

### Cleanup Script ✅
- [ ] Preview mode shows accurate counts
- [ ] Deletes all question subcollections
- [ ] No orphaned documents left behind
- [ ] Works with `--force` flag
- [ ] Clear console output

---

## Rollback Plan

If critical issues detected after deployment:

### Immediate Rollback
```bash
# 1. Revert code
git revert HEAD
git push

# 2. Redeploy
./deploy.sh

# 3. Clean database (if partial migration occurred)
node scripts/cleanup-all-users.js
```

### Data Recovery
Since we're cleaning the DB before deployment:
- No data migration needed
- No data loss risk
- Fresh start with new structure

---

## Summary

### Changes Made ✅
1. **Cleanup Script Updated** - Handles question subcollections recursively
2. **Service Layer** - Quiz creation/fetching uses subcollection pattern
3. **API Routes** - Updated to load questions from subcollection
4. **Tests** - Comprehensive unit + integration coverage

### Benefits
- ✅ **No size limits** - Each question separate document
- ✅ **Efficient updates** - Update single question (2 KB vs 30 KB)
- ✅ **Scalable** - Can handle 100+ questions if needed
- ✅ **Future-proof** - Standard Firestore pattern

### Risk Mitigation
- ✅ Clean DB = No migration complexity
- ✅ Comprehensive tests = Catch regressions
- ✅ Atomic writes = Data consistency
- ✅ Helper functions = Code maintainability

**Status**: READY TO IMPLEMENT ✅

**Next Step**: Implement Phase 2 (Service Layer Refactoring)
