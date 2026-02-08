# Chapter Unlock Quiz Feature - Implementation Plan

## Overview
Students can unlock any locked chapter by completing a 5-question mini-quiz. Getting 3+ correct unlocks the chapter; <3 keeps it locked with encouragement to retry.

## User Decisions Summary
- **Question Source**: Separate JSON files (5 questions per chapter) → `chapter_exposure` collection
- **Theta Impact**: No theta updates (purely evaluative)
- **Retry Policy**: Immediate retry with different questions (no cooldown)
- **Unlock Scope**: All locked chapters eligible (no timeline restrictions)
- **Question Difficulty**: Fixed 5 questions per chapter from JSON files
- **UI Entry Point**: Tap locked chapter → show unlock quiz CTA
- **Tier Limits**: No restrictions - all users unlimited unlocks

---

## Architecture Overview

### Data Flow
```
1. User taps locked chapter → ChapterListTile (mobile)
2. Show "Unlock this chapter" dialog with quiz CTA
3. Generate unlock quiz session → POST /api/unlock-quiz/generate
4. Navigate to UnlockQuizScreen (reuse ChapterPracticeQuestionScreen pattern)
5. Submit 5 answers → POST /api/unlock-quiz/submit-answer (no theta updates)
6. Complete quiz → POST /api/unlock-quiz/complete
7. If 3+ correct → unlock chapter via chapterUnlockOverrides + update stats
8. Show result → UnlockQuizResultScreen (success/retry message)
9. Track attempt in user profile (unlock_quiz_stats)
```

### Collections
```
chapter_exposure/{chapter_key}/questions/{question_id}
  - Stores 5 questions per chapter from JSON imports
  - Same schema as main questions collection
  - Separate pool from daily quiz/chapter practice

unlock_quiz_sessions/{userId}/sessions/{session_id}
  - Stores unlock quiz attempts (like chapter_practice_sessions)
  - Tracks: chapter_key, status, questions, pass/fail, attempt_number

unlock_quiz_responses/{userId}/responses/{response_id}
  - Stores individual answers (no theta updates)
  - Used to select different questions on retry

users/{userId}/unlock_quiz_stats (NEW field in user profile)
  - total_attempts: int
  - successful_unlocks: int
  - chapters_unlocked_via_quiz: [chapter_key1, chapter_key2, ...]
  - attempt_history: {
      chapter_key: {
        total_attempts: int,
        successful: bool,
        last_attempt_at: Timestamp,
        scores: [3, 2, 4] // scores from each attempt
      }
    }
```

---

## Implementation Tasks

### Phase 1: Backend - Data Import & Storage

#### 1.1 Create `chapter_exposure` Collection Schema

**File**: `backend/src/services/chapterExposureService.js` (NEW)

```javascript
// Firestore structure:
// chapter_exposure/{chapter_key}/questions/{question_id}

const EXPOSURE_QUESTIONS_PER_CHAPTER = 5;

async function getExposureQuestions(chapterKey) {
  // Fetch all 5 questions for this chapter
  const questionsSnapshot = await db
    .collection('chapter_exposure')
    .doc(chapterKey)
    .collection('questions')
    .where('active', '==', true)
    .get();

  return questionsSnapshot.docs.map(doc => doc.data());
}

async function validateChapterHasExposureQuestions(chapterKey) {
  const questions = await getExposureQuestions(chapterKey);
  return questions.length === EXPOSURE_QUESTIONS_PER_CHAPTER;
}
```

**Reuse Pattern**: Based on `questionSelectionService.js` query patterns

---

#### 1.2 Create Import Script for Exposure Questions

**File**: `backend/scripts/import-exposure-questions.js` (NEW)

Adaptation of `import-question-bank.js`:

```javascript
/**
 * Imports exposure questions from JSON files
 *
 * Input: inputs/chapter_exposure/*.json (63 files found)
 * Each file contains object map with 5 questions as keys
 *
 * Actual format (from 11PHY_Electrostatics_Exposure_Questions_FIXED.json):
 * {
 *   "PHY_ELEC_EXP_001": { question_id: "PHY_ELEC_EXP_001", ... },
 *   "PHY_ELEC_EXP_002": { question_id: "PHY_ELEC_EXP_002", ... },
 *   // ... 5 questions total
 * }
 */

const path = require('path');
const fs = require('fs');

async function importExposureQuestions() {
  const inputDir = path.join(__dirname, '../../inputs/chapter_exposure');
  const files = fs.readdirSync(inputDir).filter(f => f.endsWith('.json'));

  console.log(`Found ${files.length} exposure question files`);

  let totalImported = 0;
  let errors = [];

  for (const file of files) {
    try {
      const filePath = path.join(inputDir, file);
      const fileData = JSON.parse(fs.readFileSync(filePath, 'utf8'));

      // Extract questions from object map
      const questions = Object.values(fileData);

      if (questions.length !== 5) {
        errors.push(`${file}: Expected 5 questions, found ${questions.length}`);
        continue;
      }

      // Derive chapter_key from first question
      const firstQuestion = questions[0];
      const chapterKey = computeChapterKey(firstQuestion.subject, firstQuestion.chapter);

      console.log(`Importing ${file} → chapter_key: ${chapterKey}`);

      // Batch write to chapter_exposure/{chapterKey}/questions/
      const batch = db.batch();
      questions.forEach(q => {
        const docRef = db.collection('chapter_exposure')
          .doc(chapterKey)
          .collection('questions')
          .doc(q.question_id);

        batch.set(docRef, {
          ...q,
          chapter_key: chapterKey, // Ensure consistent key
          active: true,
          created_at: admin.firestore.FieldValue.serverTimestamp()
        });
      });

      await batch.commit();
      totalImported += questions.length;

    } catch (error) {
      errors.push(`${file}: ${error.message}`);
    }
  }

  console.log(`\n✅ Import Complete`);
  console.log(`   - Total files processed: ${files.length}`);
  console.log(`   - Total questions imported: ${totalImported}`);
  console.log(`   - Expected: ${files.length * 5}`);

  if (errors.length > 0) {
    console.log(`\n⚠️ Errors (${errors.length}):`);
    errors.forEach(e => console.log(`   - ${e}`));
  }
}

function computeChapterKey(subject, chapter) {
  const subjectLower = subject.toLowerCase().trim();
  const chapterLower = chapter.toLowerCase().trim();
  const normalizedSubject = subjectLower.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  const normalizedChapter = chapterLower.replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  return `${normalizedSubject}_${normalizedChapter}`;
}

importExposureQuestions()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Import failed:', err);
    process.exit(1);
  });
```

**Run Command**:
```bash
node backend/scripts/import-exposure-questions.js
```

**Expected Output**: ~315 questions imported (63 files × 5 questions each)

---

### Phase 2: Backend - Unlock Quiz Service

#### 2.1 Create Unlock Quiz Service

**File**: `backend/src/services/unlockQuizService.js` (NEW)

**Reuse Pattern**: Heavily based on `chapterPracticeService.js`, simplified (no theta updates, no IRT selection)

```javascript
const { getExposureQuestions } = require('./chapterExposureService');
const { isChapterUnlocked, addChapterUnlockOverride } = require('./chapterUnlockService');

const QUESTIONS_PER_QUIZ = 5;
const PASS_THRESHOLD = 3; // 3 out of 5 correct

/**
 * Generate unlock quiz session
 * - Fetch 5 exposure questions for chapter
 * - Exclude questions already answered in previous attempts
 * - If <5 available, allow retry with same questions
 */
async function generateUnlockQuiz(userId, chapterKey) {
  // Check if chapter is already unlocked
  const isUnlocked = await isChapterUnlocked(userId, chapterKey);
  if (isUnlocked) {
    throw new Error('Chapter is already unlocked');
  }

  // Fetch all 5 exposure questions
  const allQuestions = await getExposureQuestions(chapterKey);

  if (allQuestions.length !== QUESTIONS_PER_QUIZ) {
    throw new Error(`Chapter ${chapterKey} does not have ${QUESTIONS_PER_QUIZ} exposure questions`);
  }

  // Get previously answered questions (for this chapter only)
  const answeredQuestionIds = await getPreviouslyAnsweredQuestionIds(userId, chapterKey);

  // Select 5 questions: prefer unanswered, fallback to all
  let selectedQuestions = allQuestions.filter(q => !answeredQuestionIds.has(q.question_id));

  if (selectedQuestions.length < QUESTIONS_PER_QUIZ) {
    // Not enough unanswered → allow retry with same questions
    selectedQuestions = allQuestions.slice(0, QUESTIONS_PER_QUIZ);
  }

  // Shuffle questions
  selectedQuestions = shuffleArray(selectedQuestions);

  // Create session
  const sessionId = `unlock_${userId}_${Date.now()}`;
  const session = {
    session_id: sessionId,
    student_id: userId,
    chapter_key: chapterKey,
    chapter_name: selectedQuestions[0].chapter,
    subject: selectedQuestions[0].subject,
    status: 'in_progress',
    total_questions: QUESTIONS_PER_QUIZ,
    questions_answered: 0,
    correct_count: 0,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
  };

  // Save session + questions (sanitized)
  await saveUnlockQuizSession(userId, session, selectedQuestions);

  return {
    sessionId,
    chapterKey,
    questions: sanitizeQuestions(selectedQuestions)
  };
}

/**
 * Submit answer (no theta updates)
 */
async function submitUnlockQuizAnswer(userId, sessionId, questionId, selectedOption, timeTakenSeconds) {
  // Validate session exists and is in_progress
  const session = await getUnlockQuizSession(userId, sessionId);
  if (session.status !== 'in_progress') {
    throw new Error('Session is not in progress');
  }

  // Fetch question to check correct answer
  const question = session.questions.find(q => q.question_id === questionId);
  if (!question) {
    throw new Error('Question not found in session');
  }

  const isCorrect = selectedOption === question.correct_answer;

  // Transaction: update session + save response
  await db.runTransaction(async (transaction) => {
    const sessionRef = db.collection('unlock_quiz_sessions').doc(userId).collection('sessions').doc(sessionId);

    transaction.update(sessionRef, {
      questions_answered: admin.firestore.FieldValue.increment(1),
      correct_count: isCorrect ? admin.firestore.FieldValue.increment(1) : session.correct_count
    });

    // Save response (no theta updates)
    const responseRef = db.collection('unlock_quiz_responses').doc(userId).collection('responses').doc(`${sessionId}_${questionId}`);
    transaction.set(responseRef, {
      session_id: sessionId,
      question_id: questionId,
      chapter_key: session.chapter_key,
      student_answer: selectedOption,
      correct_answer: question.correct_answer,
      is_correct: isCorrect,
      time_taken_seconds: timeTakenSeconds,
      answered_at: admin.firestore.FieldValue.serverTimestamp()
    });
  });

  // Return feedback (solution steps, etc.)
  return {
    isCorrect,
    correctAnswer: question.correct_answer,
    correctAnswerText: getCorrectAnswerText(question),
    solutionText: question.solution_text,
    solutionSteps: question.solution_steps || [],
    keyInsight: question.key_insight,
    distractorAnalysis: question.distractor_analysis || {},
    commonMistakes: question.common_mistakes || []
  };
}

/**
 * Complete unlock quiz
 * - Check if passed (3+ correct)
 * - If passed: add chapter unlock override
 * - Update user unlock_quiz_stats
 * - Return result
 */
async function completeUnlockQuiz(userId, sessionId) {
  const session = await getUnlockQuizSession(userId, sessionId);

  if (session.status === 'completed') {
    throw new Error('Session already completed');
  }

  const passed = session.correct_count >= PASS_THRESHOLD;

  // Transaction: Update session + stats atomically
  await db.runTransaction(async (transaction) => {
    const userRef = db.collection('users').doc(userId);
    const sessionRef = db.collection('unlock_quiz_sessions')
      .doc(userId)
      .collection('sessions')
      .doc(sessionId);

    // Update session status
    transaction.update(sessionRef, {
      status: 'completed',
      passed,
      completed_at: admin.firestore.FieldValue.serverTimestamp()
    });

    // Update user unlock_quiz_stats
    const chapterStatsPath = `unlock_quiz_stats.attempt_history.${session.chapter_key}`;

    transaction.update(userRef, {
      'unlock_quiz_stats.total_attempts': admin.firestore.FieldValue.increment(1),
      'unlock_quiz_stats.successful_unlocks': passed
        ? admin.firestore.FieldValue.increment(1)
        : admin.firestore.FieldValue.increment(0),
      [`${chapterStatsPath}.total_attempts`]: admin.firestore.FieldValue.increment(1),
      [`${chapterStatsPath}.successful`]: passed,
      [`${chapterStatsPath}.last_attempt_at`]: admin.firestore.FieldValue.serverTimestamp(),
      [`${chapterStatsPath}.scores`]: admin.firestore.FieldValue.arrayUnion(session.correct_count)
    });

    // If passed: add to chapters_unlocked_via_quiz array
    if (passed) {
      transaction.update(userRef, {
        'unlock_quiz_stats.chapters_unlocked_via_quiz': admin.firestore.FieldValue.arrayUnion(session.chapter_key)
      });
    }
  });

  // If passed: unlock chapter via override (outside transaction)
  if (passed) {
    await addChapterUnlockOverride(
      userId,
      session.chapter_key,
      'unlock_quiz',
      `Passed unlock quiz with ${session.correct_count}/${session.total_questions} correct`
    );

    logger.info('Chapter unlocked via quiz', {
      userId,
      chapterKey: session.chapter_key,
      score: `${session.correct_count}/${session.total_questions}`
    });
  }

  return {
    sessionId,
    chapterKey: session.chapter_key,
    chapterName: session.chapter_name,
    subject: session.subject,
    totalQuestions: session.total_questions,
    correctCount: session.correct_count,
    passed,
    canRetry: !passed
  };
}
```

**Key Differences from Chapter Practice**:
- ✅ No IRT theta updates
- ✅ Fixed 5 questions (no adaptive selection)
- ✅ Questions from `chapter_exposure` collection
- ✅ Pass/fail based on simple threshold (3/5)
- ✅ Unlocks chapter via `chapterUnlockOverrides`

---

#### 2.2 Create API Routes

**File**: `backend/src/routes/unlockQuiz.js` (NEW)

**Reuse Pattern**: Based on `chapterPractice.js` routes

```javascript
const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const {
  generateUnlockQuiz,
  submitUnlockQuizAnswer,
  completeUnlockQuiz,
  getUnlockQuizSession
} = require('../services/unlockQuizService');

// POST /api/unlock-quiz/generate
router.post('/generate', authenticateToken, async (req, res) => {
  try {
    const { chapterKey } = req.body;
    const userId = req.user.uid;

    const result = await generateUnlockQuiz(userId, chapterKey);

    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
});

// POST /api/unlock-quiz/submit-answer
router.post('/submit-answer', authenticateToken, async (req, res) => {
  try {
    const { sessionId, questionId, selectedOption, timeTakenSeconds } = req.body;
    const userId = req.user.uid;

    const result = await submitUnlockQuizAnswer(userId, sessionId, questionId, selectedOption, timeTakenSeconds);

    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
});

// POST /api/unlock-quiz/complete
router.post('/complete', authenticateToken, async (req, res) => {
  try {
    const { sessionId } = req.body;
    const userId = req.user.uid;

    const result = await completeUnlockQuiz(userId, sessionId);

    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
});

// GET /api/unlock-quiz/session/:sessionId
router.get('/session/:sessionId', authenticateToken, async (req, res) => {
  try {
    const { sessionId } = req.params;
    const userId = req.user.uid;

    const session = await getUnlockQuizSession(userId, sessionId);

    res.json({
      success: true,
      data: session
    });
  } catch (error) {
    res.status(404).json({ success: false, error: error.message });
  }
});

module.exports = router;
```

**Register in `backend/src/index.js`**:
```javascript
const unlockQuizRoutes = require('./routes/unlockQuiz');
app.use('/api/unlock-quiz', unlockQuizRoutes);
```

---

### Phase 3: Mobile - Data Models & Provider

#### 3.1 Create Data Models

**File**: `mobile/lib/models/unlock_quiz_models.dart` (NEW)

**Reuse Pattern**: Adapted from `chapter_practice_models.dart`

```dart
class UnlockQuizSession {
  final String sessionId;
  final String chapterKey;
  final String chapterName;
  final String subject;
  final List<UnlockQuizQuestion> questions;
  final int totalQuestions;
  final int questionsAnswered;

  UnlockQuizSession({
    required this.sessionId,
    required this.chapterKey,
    required this.chapterName,
    required this.subject,
    required this.questions,
    this.totalQuestions = 5,
    this.questionsAnswered = 0,
  });

  factory UnlockQuizSession.fromJson(Map<String, dynamic> json) {
    return UnlockQuizSession(
      sessionId: json['sessionId'],
      chapterKey: json['chapterKey'],
      chapterName: json['chapterName'] ?? '',
      subject: json['subject'] ?? '',
      questions: (json['questions'] as List)
          .map((q) => UnlockQuizQuestion.fromJson(q))
          .toList(),
      totalQuestions: json['totalQuestions'] ?? 5,
      questionsAnswered: json['questionsAnswered'] ?? 0,
    );
  }
}

class UnlockQuizQuestion {
  final String questionId;
  final int position;
  final String subject;
  final String chapter;
  final String chapterKey;
  final String questionType;
  final String questionText;
  final String? questionTextHtml;
  final List<UnlockQuizOption> options;
  final String? imageUrl;

  // Answer state (mutable)
  bool answered;
  String? studentAnswer;
  String? correctAnswer;
  bool? isCorrect;
  int? timeTakenSeconds;

  UnlockQuizQuestion({
    required this.questionId,
    required this.position,
    required this.subject,
    required this.chapter,
    required this.chapterKey,
    required this.questionType,
    required this.questionText,
    this.questionTextHtml,
    required this.options,
    this.imageUrl,
    this.answered = false,
    this.studentAnswer,
    this.correctAnswer,
    this.isCorrect,
    this.timeTakenSeconds,
  });

  bool get isNumerical => questionType.toLowerCase() == 'numerical';

  factory UnlockQuizQuestion.fromJson(Map<String, dynamic> json) {
    return UnlockQuizQuestion(
      questionId: json['question_id'],
      position: json['position'] ?? 0,
      subject: json['subject'] ?? '',
      chapter: json['chapter'] ?? '',
      chapterKey: json['chapter_key'] ?? '',
      questionType: json['question_type'] ?? 'mcq_single',
      questionText: json['question_text'] ?? '',
      questionTextHtml: json['question_text_html'],
      options: (json['options'] as List?)
              ?.map((o) => UnlockQuizOption.fromJson(o))
              .toList() ?? [],
      imageUrl: json['image_url'],
      answered: json['answered'] ?? false,
      studentAnswer: json['student_answer'],
      correctAnswer: json['correct_answer'],
      isCorrect: json['is_correct'],
      timeTakenSeconds: json['time_taken_seconds'],
    );
  }
}

class UnlockQuizOption {
  final String optionId;
  final String text;
  final String? html;

  UnlockQuizOption({
    required this.optionId,
    required this.text,
    this.html,
  });

  factory UnlockQuizOption.fromJson(Map<String, dynamic> json) {
    return UnlockQuizOption(
      optionId: json['option_id'],
      text: json['text'] ?? '',
      html: json['html'],
    );
  }
}

class UnlockQuizAnswerResult {
  final bool isCorrect;
  final String studentAnswer;
  final String correctAnswer;
  final String? correctAnswerText;
  final String? solutionText;
  final List<SolutionStep> solutionSteps;
  final String? keyInsight;
  final Map<String, String> distractorAnalysis;
  final List<String> commonMistakes;

  UnlockQuizAnswerResult({
    required this.isCorrect,
    required this.studentAnswer,
    required this.correctAnswer,
    this.correctAnswerText,
    this.solutionText,
    this.solutionSteps = const [],
    this.keyInsight,
    this.distractorAnalysis = const {},
    this.commonMistakes = const [],
  });

  factory UnlockQuizAnswerResult.fromJson(Map<String, dynamic> json) {
    return UnlockQuizAnswerResult(
      isCorrect: json['isCorrect'],
      studentAnswer: json['studentAnswer'],
      correctAnswer: json['correctAnswer'],
      correctAnswerText: json['correctAnswerText'],
      solutionText: json['solutionText'],
      solutionSteps: (json['solutionSteps'] as List?)
              ?.map((s) => SolutionStep.fromJson(s))
              .toList() ?? [],
      keyInsight: json['keyInsight'],
      distractorAnalysis: Map<String, String>.from(json['distractorAnalysis'] ?? {}),
      commonMistakes: List<String>.from(json['commonMistakes'] ?? []),
    );
  }
}

class UnlockQuizResult {
  final String sessionId;
  final String chapterKey;
  final String chapterName;
  final String subject;
  final int totalQuestions;
  final int correctCount;
  final bool passed;
  final bool canRetry;

  UnlockQuizResult({
    required this.sessionId,
    required this.chapterKey,
    required this.chapterName,
    required this.subject,
    this.totalQuestions = 5,
    required this.correctCount,
    required this.passed,
    this.canRetry = false,
  });

  double get accuracy => correctCount / totalQuestions;

  factory UnlockQuizResult.fromJson(Map<String, dynamic> json) {
    return UnlockQuizResult(
      sessionId: json['sessionId'],
      chapterKey: json['chapterKey'],
      chapterName: json['chapterName'],
      subject: json['subject'],
      totalQuestions: json['totalQuestions'] ?? 5,
      correctCount: json['correctCount'],
      passed: json['passed'],
      canRetry: json['canRetry'] ?? false,
    );
  }
}
```

**Reuse**: `SolutionStep` model from `daily_quiz_models.dart`

---

#### 3.2 Create Unlock Quiz Provider

**File**: `mobile/lib/providers/unlock_quiz_provider.dart` (NEW)

**Reuse Pattern**: Simplified version of `chapter_practice_provider.dart` (no resume logic, no local storage)

```dart
import 'package:flutter/foundation.dart';
import '../models/unlock_quiz_models.dart';
import '../services/api_service.dart';

class UnlockQuizProvider with ChangeNotifier {
  UnlockQuizSession? _session;
  int _currentQuestionIndex = 0;
  UnlockQuizAnswerResult? _lastAnswerResult;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Getters
  UnlockQuizSession? get session => _session;
  int get currentQuestionIndex => _currentQuestionIndex;
  UnlockQuizQuestion? get currentQuestion =>
      _session?.questions.elementAtOrNull(_currentQuestionIndex);
  UnlockQuizAnswerResult? get lastAnswerResult => _lastAnswerResult;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  bool get currentQuestionIsAnswered =>
      currentQuestion?.answered ?? false || _lastAnswerResult != null;
  bool get hasMoreQuestions =>
      _currentQuestionIndex < (_session?.totalQuestions ?? 0) - 1;

  // Start unlock quiz
  Future<void> startUnlockQuiz(String chapterKey, String authToken) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.post(
        '/unlock-quiz/generate',
        {'chapterKey': chapterKey},
        authToken,
      );

      if (response['success']) {
        _session = UnlockQuizSession.fromJson(response['data']);
        _currentQuestionIndex = 0;
        _lastAnswerResult = null;
      } else {
        throw Exception(response['error'] ?? 'Failed to generate unlock quiz');
      }
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Submit answer
  Future<UnlockQuizAnswerResult> submitAnswer(
    String selectedOption,
    String authToken,
    int timeTakenSeconds,
  ) async {
    if (_session == null || currentQuestion == null) {
      throw Exception('No active session or question');
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.post(
        '/unlock-quiz/submit-answer',
        {
          'sessionId': _session!.sessionId,
          'questionId': currentQuestion!.questionId,
          'selectedOption': selectedOption,
          'timeTakenSeconds': timeTakenSeconds,
        },
        authToken,
      );

      if (response['success']) {
        final result = UnlockQuizAnswerResult.fromJson(response['data']);
        _lastAnswerResult = result;

        // Update question state
        currentQuestion!.answered = true;
        currentQuestion!.studentAnswer = selectedOption;
        currentQuestion!.correctAnswer = result.correctAnswer;
        currentQuestion!.isCorrect = result.isCorrect;
        currentQuestion!.timeTakenSeconds = timeTakenSeconds;

        notifyListeners();
        return result;
      } else {
        throw Exception(response['error'] ?? 'Failed to submit answer');
      }
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // Navigate to next question
  void goToNextQuestion() {
    if (hasMoreQuestions) {
      _currentQuestionIndex++;
      _lastAnswerResult = null;
      notifyListeners();
    }
  }

  // Complete unlock quiz
  Future<UnlockQuizResult> completeQuiz(String authToken) async {
    if (_session == null) {
      throw Exception('No active session');
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.post(
        '/unlock-quiz/complete',
        {'sessionId': _session!.sessionId},
        authToken,
      );

      if (response['success']) {
        final result = UnlockQuizResult.fromJson(response['data']);
        _session = null; // Clear session
        notifyListeners();
        return result;
      } else {
        throw Exception(response['error'] ?? 'Failed to complete quiz');
      }
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _session = null;
    _currentQuestionIndex = 0;
    _lastAnswerResult = null;
    _isLoading = false;
    _isSubmitting = false;
    _errorMessage = null;
    notifyListeners();
  }
}
```

---

### Phase 4: Mobile - UI Screens

#### 4.1 Update Chapter List Screen - Add Unlock CTA

**File**: `mobile/lib/screens/chapter_practice/chapter_picker_screen.dart` (MODIFY)

Update the locked chapter tap handler:

```dart
// In ChapterListTile widget
void _handleChapterTap(BuildContext context, Chapter chapter) {
  if (chapter.isUnlocked) {
    // Navigate to chapter practice
    _navigateToChapterPractice(context, chapter);
  } else {
    // Show unlock quiz dialog
    _showUnlockQuizDialog(context, chapter);
  }
}

Future<void> _showUnlockQuizDialog(BuildContext context, Chapter chapter) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock_open, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(child: Text('Unlock "${chapter.name}"?')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Take a 5-question quiz to unlock this chapter.',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.quiz, 'Answer 3 out of 5 correctly to unlock'),
                SizedBox(height: 8),
                _buildInfoRow(Icons.refresh, 'Can retry immediately with new questions'),
                SizedBox(height: 8),
                _buildInfoRow(Icons.star_outline, 'No time limit, no pressure!'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: Text('Start Quiz'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    // Navigate to unlock quiz loading screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnlockQuizLoadingScreen(
          chapterKey: chapter.chapterKey,
          chapterName: chapter.name,
          subject: chapter.subject,
        ),
      ),
    );
  }
}

Widget _buildInfoRow(IconData icon, String text) {
  return Row(
    children: [
      Icon(icon, size: 16, color: AppColors.textSecondary),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ),
    ],
  );
}
```

---

#### 4.2 Create Unlock Quiz Loading Screen

**File**: `mobile/lib/screens/unlock_quiz/unlock_quiz_loading_screen.dart` (NEW)

**Reuse Pattern**: Copy `chapter_practice_loading_screen.dart` and simplify

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/unlock_quiz_provider.dart';
import '../../providers/auth_provider.dart';
import 'unlock_quiz_question_screen.dart';

class UnlockQuizLoadingScreen extends StatefulWidget {
  final String chapterKey;
  final String chapterName;
  final String subject;

  const UnlockQuizLoadingScreen({
    Key? key,
    required this.chapterKey,
    required this.chapterName,
    required this.subject,
  }) : super(key: key);

  @override
  State<UnlockQuizLoadingScreen> createState() => _UnlockQuizLoadingScreenState();
}

class _UnlockQuizLoadingScreenState extends State<UnlockQuizLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _initializeQuiz();
  }

  Future<void> _initializeQuiz() async {
    final unlockQuizProvider = context.read<UnlockQuizProvider>();
    final authProvider = context.read<AuthProvider>();
    final authToken = await authProvider.getAuthToken();

    if (authToken == null) {
      // Handle auth error
      return;
    }

    try {
      await unlockQuizProvider.startUnlockQuiz(widget.chapterKey, authToken);

      // Navigate to question screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UnlockQuizQuestionScreen(),
          ),
        );
      }
    } catch (e) {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load quiz: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text('Preparing unlock quiz...'),
            SizedBox(height: 8),
            Text(
              widget.chapterName,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

#### 4.3 Create Unlock Quiz Question Screen

**File**: `mobile/lib/screens/unlock_quiz/unlock_quiz_question_screen.dart` (NEW)

**Reuse Pattern**: Copy `chapter_practice_question_screen.dart` and adapt

**Key Differences**:
- Show "Unlock Quiz" badge instead of "Practice"
- Progress: "Question X of 5"
- No timer
- Header: "Unlock: {Chapter Name}"
- Reuse: `FeedbackBannerWidget`, `DetailedExplanationWidget`, `QuestionCard`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/unlock_quiz_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/daily_quiz/feedback_banner_widget.dart';
import '../../widgets/daily_quiz/detailed_explanation_widget.dart';
import 'unlock_quiz_result_screen.dart';

class UnlockQuizQuestionScreen extends StatefulWidget {
  const UnlockQuizQuestionScreen({Key? key}) : super(key: key);

  @override
  State<UnlockQuizQuestionScreen> createState() => _UnlockQuizQuestionScreenState();
}

class _UnlockQuizQuestionScreenState extends State<UnlockQuizQuestionScreen> {
  String? _selectedOption;
  final _numericalController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Consumer<UnlockQuizProvider>(
      builder: (context, provider, _) {
        final question = provider.currentQuestion;
        final isAnswered = provider.currentQuestionIsAnswered;
        final answerResult = provider.lastAnswerResult;

        if (question == null) {
          return Scaffold(body: Center(child: Text('No question loaded')));
        }

        return PopScope(
          canPop: false, // Prevent back navigation
          child: Scaffold(
            appBar: _buildAppBar(context, provider),
            body: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  // Question Card
                  _buildQuestionCard(question, isAnswered),

                  // Feedback Banner (if answered)
                  if (isAnswered && answerResult != null)
                    FeedbackBannerWidget(
                      isCorrect: answerResult.isCorrect,
                      correctAnswer: answerResult.correctAnswerText ?? answerResult.correctAnswer,
                      studentAnswer: answerResult.studentAnswer,
                    ),

                  // Detailed Explanation (if answered)
                  if (isAnswered && answerResult != null)
                    DetailedExplanationWidget(
                      solutionSteps: answerResult.solutionSteps,
                      keyInsight: answerResult.keyInsight,
                      distractorAnalysis: answerResult.distractorAnalysis,
                      commonMistakes: answerResult.commonMistakes,
                      motivationalMessage: _getMotivationalMessage(answerResult.isCorrect),
                    ),

                  // Action Buttons
                  if (isAnswered) _buildNavigationButtons(context, provider),

                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, UnlockQuizProvider provider) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Unlock Quiz', style: TextStyle(fontSize: 16)),
          Text(
            provider.session?.chapterName ?? '',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
          ),
        ],
      ),
      actions: [
        Center(
          child: Padding(
            padding: EdgeInsets.only(right: 16),
            child: Text(
              'Question ${provider.currentQuestionIndex + 1} of 5',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(question, bool isAnswered) {
    // Reuse question card from chapter practice
    // Show options, handle selection, show submit button
    // ... (similar to chapter_practice_question_screen.dart)
  }

  Widget _buildNavigationButtons(BuildContext context, UnlockQuizProvider provider) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          if (provider.hasMoreQuestions)
            ElevatedButton(
              onPressed: () {
                provider.goToNextQuestion();
                _scrollToTop();
              },
              child: Text('Next Question'),
            )
          else
            ElevatedButton(
              onPressed: () => _completeQuiz(context, provider),
              child: Text('Complete Quiz'),
            ),
        ],
      ),
    );
  }

  Future<void> _completeQuiz(BuildContext context, UnlockQuizProvider provider) async {
    final authProvider = context.read<AuthProvider>();
    final authToken = await authProvider.getAuthToken();

    if (authToken == null) return;

    try {
      final result = await provider.completeQuiz(authToken);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UnlockQuizResultScreen(result: result),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete quiz: $e')),
      );
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String _getMotivationalMessage(bool isCorrect) {
    if (isCorrect) {
      return "Great job! You're on track to unlock this chapter.";
    } else {
      return "Don't worry! Review the solution and keep trying.";
    }
  }
}
```

---

#### 4.4 Create Unlock Quiz Result Screen

**File**: `mobile/lib/screens/unlock_quiz/unlock_quiz_result_screen.dart` (NEW)

**Reuse Pattern**: Adapt `chapter_practice_result_screen.dart`

**Key Differences**:
- If `passed = true`: Show "Chapter Unlocked!" with confetti animation
- If `passed = false`: Show encouragement + "Try Again" button
- No theta/percentile display (unlock quiz doesn't update theta)

```dart
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../models/unlock_quiz_models.dart';
import '../../constants/app_colors.dart';

class UnlockQuizResultScreen extends StatefulWidget {
  final UnlockQuizResult result;

  const UnlockQuizResultScreen({Key? key, required this.result}) : super(key: key);

  @override
  State<UnlockQuizResultScreen> createState() => _UnlockQuizResultScreenState();
}

class _UnlockQuizResultScreenState extends State<UnlockQuizResultScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: Duration(seconds: 3));

    if (widget.result.passed) {
      Future.delayed(Duration(milliseconds: 500), () {
        _confettiController.play();
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.result.passed ? 'Chapter Unlocked!' : 'Keep Trying!'),
        ),
        body: Stack(
          children: [
            _buildContent(),
            if (widget.result.passed) _buildConfetti(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(height: 24),

          // Icon & Title
          Icon(
            widget.result.passed ? Icons.lock_open : Icons.lock,
            size: 80,
            color: widget.result.passed ? Colors.green : Colors.orange,
          ),
          SizedBox(height: 16),

          Text(
            widget.result.passed
                ? '🎉 Chapter Unlocked!'
                : 'Almost there!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),

          Text(
            widget.result.chapterName,
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),

          // Score Card
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.result.passed
                    ? [Colors.green.shade300, Colors.green.shade500]
                    : [Colors.orange.shade300, Colors.orange.shade500],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Score',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  '${widget.result.correctCount} / ${widget.result.totalQuestions}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  widget.result.passed
                      ? 'You passed! 🎊'
                      : 'Need ${3 - widget.result.correctCount} more correct',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          SizedBox(height: 32),

          // Message
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getMessage(),
              style: TextStyle(fontSize: 16, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 32),

          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  String _getMessage() {
    if (widget.result.passed) {
      return "Excellent work! You've unlocked \"${widget.result.chapterName}\". "
             "You can now practice all questions from this chapter. Keep up the great work! 🚀";
    } else {
      return "You got ${widget.result.correctCount} out of ${widget.result.totalQuestions} correct. "
             "Don't give up! Review the solutions, practice a bit more, and try again. "
             "You'll unlock this chapter soon! 💪";
    }
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (!widget.result.passed)
          ElevatedButton(
            onPressed: () {
              // Retry with new questions
              Navigator.pop(context); // Back to loading screen
              // Loading screen will regenerate quiz
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: Size(double.infinity, 50),
            ),
            child: Text('Try Again with New Questions'),
          ),

        SizedBox(height: 12),

        OutlinedButton(
          onPressed: () {
            // Navigate back to chapter list
            Navigator.popUntil(context, (route) => route.isFirst);
          },
          style: OutlinedButton.styleFrom(
            minimumSize: Size(double.infinity, 50),
          ),
          child: Text('Back to Chapters'),
        ),

        if (widget.result.passed) ...[
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              // Navigate to chapter practice for this chapter
              // TODO: Navigate to ChapterPracticeLoadingScreen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              minimumSize: Size(double.infinity, 50),
            ),
            child: Text('Start Practicing Now!'),
          ),
        ],
      ],
    );
  }

  Widget _buildConfetti() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: _confettiController,
        blastDirectionality: BlastDirectionality.explosive,
        particleDrag: 0.05,
        emissionFrequency: 0.05,
        numberOfParticles: 20,
        gravity: 0.1,
        shouldLoop: false,
      ),
    );
  }
}
```

**Dependencies**: Add to `pubspec.yaml`:
```yaml
dependencies:
  confetti: ^0.7.0
```

---

### Phase 5: Integration & Testing

#### 5.1 Update API Service

**File**: `mobile/lib/services/api_service.dart` (MODIFY)

No changes needed - reuse existing `post()` method

---

#### 5.2 Register Provider

**File**: `mobile/lib/main.dart` (MODIFY)

```dart
MultiProvider(
  providers: [
    // ... existing providers
    ChangeNotifierProvider(create: (_) => UnlockQuizProvider()),
  ],
  child: MyApp(),
)
```

---

#### 5.3 Testing Checklist

**Backend Tests**:
- [ ] Import 5 exposure questions per chapter (63 files found = ~315 questions)
- [ ] Verify chapter_key mapping matches existing unlock schedule
- [ ] Test `/generate` endpoint for locked chapter
- [ ] Test `/generate` endpoint returns error for already unlocked chapter
- [ ] Test `/submit-answer` with correct/incorrect answers
- [ ] Test `/complete` with 3+ correct → chapter unlocked + stats updated
- [ ] Test `/complete` with <3 correct → chapter remains locked + stats updated
- [ ] Test retry: new questions after failed attempt
- [ ] Verify `unlock_quiz_stats` fields created correctly on first attempt
- [ ] Verify `attempt_history` accumulates scores across retries

**Mobile Tests**:
- [ ] Tap locked chapter → unlock quiz dialog appears
- [ ] Start quiz → loading screen → question screen
- [ ] Answer 5 questions with feedback after each
- [ ] Complete quiz → result screen
- [ ] Pass (3+) → confetti animation + chapter unlocked
- [ ] Fail (<3) → encouragement message + retry button
- [ ] Retry → get different 5 questions
- [ ] Back navigation blocked during quiz
- [ ] Chapter list refreshes after unlock (shows chapter as unlocked)

**Edge Cases**:
- [ ] Network error during quiz generation
- [ ] Network error during answer submission
- [ ] App backgrounded → resume quiz
- [ ] Already unlocked chapter shows no unlock CTA
- [ ] Chapter with <5 exposure questions → error message

---

## Critical Files Summary

### New Backend Files
- `backend/src/services/chapterExposureService.js` - Query exposure questions
- `backend/src/services/unlockQuizService.js` - Core unlock quiz logic
- `backend/src/routes/unlockQuiz.js` - API endpoints
- `backend/scripts/import-exposure-questions.js` - Import script

### Modified Backend Files
- `backend/src/index.js` - Register unlock quiz routes

### New Mobile Files
- `mobile/lib/models/unlock_quiz_models.dart` - Data models
- `mobile/lib/providers/unlock_quiz_provider.dart` - State management
- `mobile/lib/screens/unlock_quiz/unlock_quiz_loading_screen.dart`
- `mobile/lib/screens/unlock_quiz/unlock_quiz_question_screen.dart`
- `mobile/lib/screens/unlock_quiz/unlock_quiz_result_screen.dart`

### Modified Mobile Files
- `mobile/lib/screens/chapter_practice/chapter_picker_screen.dart` - Add unlock CTA
- `mobile/lib/main.dart` - Register provider
- `mobile/pubspec.yaml` - Add confetti dependency

### Reused Components
- `FeedbackBannerWidget` - Answer feedback
- `DetailedExplanationWidget` - Solution display
- `chapterUnlockService.js` - `addChapterUnlockOverride()` method
- Question card widgets, option widgets, numerical input widgets

---

## Verification Steps

1. **Backend Deployment**:
   ```bash
   # Import exposure questions
   node backend/scripts/import-exposure-questions.js --dir inputs/chapter_exposure

   # Verify 335 questions imported (67 chapters × 5)
   # Check Firestore: chapter_exposure/{chapter_key}/questions/

   # Deploy backend
   git add backend/
   git commit -m "feat: Add chapter unlock quiz backend"
   git push
   ```

2. **Mobile Testing**:
   ```bash
   # Install dependencies
   cd mobile
   flutter pub get

   # Run on device
   flutter run
   ```

3. **End-to-End Test**:
   - Select student with locked chapters (e.g., Month 5 of 24)
   - Tap locked chapter (e.g., "Electrostatics")
   - See unlock quiz dialog
   - Start quiz → answer 5 questions
   - Complete with 3+ correct → see confetti + unlock confirmation
   - Verify chapter now appears unlocked in chapter list
   - Verify `users/{userId}/chapterUnlockOverrides` contains entry
   - **NEW**: Verify `unlock_quiz_stats.successful_unlocks = 1`
   - **NEW**: Verify `unlock_quiz_stats.chapters_unlocked_via_quiz` includes chapter_key
   - **NEW**: Verify `unlock_quiz_stats.attempt_history[chapter_key]` has scores array

4. **Retry Test**:
   - Create new test user
   - Attempt unlock quiz with 0-2 correct answers
   - See encouragement message
   - **NEW**: Verify `unlock_quiz_stats.total_attempts = 1`
   - **NEW**: Verify `unlock_quiz_stats.attempt_history[chapter_key].scores = [1 or 2]`
   - Tap "Try Again"
   - Verify new set of 5 questions appears
   - Complete with 3+ correct → unlock successful
   - **NEW**: Verify `unlock_quiz_stats.total_attempts = 2`
   - **NEW**: Verify `unlock_quiz_stats.attempt_history[chapter_key].scores = [1 or 2, 3 or 4 or 5]`
   - **NEW**: Verify `unlock_quiz_stats.successful_unlocks = 1`

---

## Analytics & Tracking

### User Profile Fields (NEW)

Added to `users/{userId}` document:

```javascript
{
  unlock_quiz_stats: {
    // Global stats
    total_attempts: 12,              // Total unlock quizzes attempted
    successful_unlocks: 7,           // Total chapters successfully unlocked
    chapters_unlocked_via_quiz: [    // Array of chapter_keys
      "physics_electrostatics",
      "chemistry_organic_chemistry",
      // ...
    ],

    // Per-chapter attempt history
    attempt_history: {
      "physics_electrostatics": {
        total_attempts: 2,           // Number of attempts for this chapter
        successful: true,            // Did they eventually unlock it?
        last_attempt_at: Timestamp,
        scores: [2, 4]              // Scores from each attempt (chronological)
      },
      "mathematics_calculus_limits": {
        total_attempts: 3,
        successful: false,           // Still locked after 3 attempts
        last_attempt_at: Timestamp,
        scores: [1, 2, 2]
      }
    }
  }
}
```

### Analytics Queries

**Dashboard metrics** (for admin/analytics):
```javascript
// Top unlocked chapters
db.collectionGroup('users')
  .select('unlock_quiz_stats.chapters_unlocked_via_quiz')
  .get()
  // Aggregate to find most frequently unlocked chapters

// Students with most self-unlocks
db.collection('users')
  .orderBy('unlock_quiz_stats.successful_unlocks', 'desc')
  .limit(100)

// Chapters with highest failure rates
// Query all unlock_quiz_sessions where passed = false
// Group by chapter_key
```

**Student profile page**:
```javascript
// Show unlock achievements
const stats = userData.unlock_quiz_stats;
return {
  totalUnlocks: stats.successful_unlocks,
  chaptersUnlocked: stats.chapters_unlocked_via_quiz,
  badge: stats.successful_unlocks >= 5 ? "Early Explorer" : null
};
```

---

## Next Steps (Future Enhancements)

- ✅ **Analytics**: Implemented comprehensive tracking (total attempts, success rate, per-chapter history)
- Gamification: Badge for "Early Explorer" (unlocked X chapters ahead) - **data ready, just needs UI**
- Adaptive hints: Show hint after 2 failed attempts (use `unlock_quiz_stats.attempt_history[chapter].scores`)
- Limited daily unlocks for FREE tier: Consider 1 unlock/day limit
- Question quality feedback: Allow students to report bad questions
- Leaderboard: Students with most self-unlocked chapters (privacy-conscious)

---

## Dependencies & Prerequisites

- ✅ Countdown timeline feature already implemented (chapterUnlockService.js exists)
- ✅ Exposure questions ready: 63 JSON files in `inputs/chapter_exposure/` (~315 questions)
- ✅ File format: Object map with 5 questions per file (e.g., `PHY_ELEC_EXP_001: {...}`)
- ✅ Questions have proper schema: question_id, subject, chapter, options, correct_answer, solution_steps, etc.
- Confetti package for celebration animation
- All existing question display widgets available for reuse

**Note**: 63 chapters have exposure questions (vs 67 total chapters). Missing 4 chapters will need exposure questions created before enabling unlock quiz for those chapters.
