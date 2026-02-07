/**
 * Student Data Extraction Script
 *
 * Extracts all data collected for a student across all learning activities:
 * - User Profile & Subscription
 * - Initial Assessment
 * - Daily Quiz History
 * - Chapter Practice Sessions
 * - Mock Tests
 * - AI Tutor Conversations
 * - Snap & Solve History
 * - Theta Evolution (Learning Progress)
 * - Usage & Engagement Metrics
 *
 * Firestore Collection Paths:
 * - User Profile: users/{userId}
 * - Assessments: assessment_responses/{userId}/responses/
 * - Daily Quizzes: daily_quizzes/{userId}/quizzes/
 * - Daily Quiz Responses: daily_quiz_responses/{userId}/responses/
 * - Chapter Practice: chapter_practice_sessions/{userId}/sessions/
 * - Chapter Practice Responses: chapter_practice_responses/{userId}/responses/
 * - Mock Tests: users/{userId}/mock_tests/
 * - Snaps: users/{userId}/snaps/
 * - AI Tutor: users/{userId}/tutor_conversation/current/messages/
 * - Theta Snapshots: theta_snapshots/{userId}/daily/
 * - Daily Usage: users/{userId}/daily_usage/
 *
 * Usage:
 *   node backend/scripts/extract-student-data.js +919876543210
 *   node backend/scripts/extract-student-data.js +919876543210 --format json
 *   node backend/scripts/extract-student-data.js +919876543210 --output student_data.json
 */

const { db, admin } = require('../src/config/firebase');
const fs = require('fs');
const path = require('path');

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Format timestamp to readable date string
 */
function formatDate(timestamp) {
  if (!timestamp) return null;

  try {
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toISOString();
  } catch (err) {
    return timestamp;
  }
}

/**
 * Clean Firestore data (convert timestamps, remove undefined)
 */
function cleanFirestoreData(data) {
  if (!data) return data;

  const cleaned = {};
  for (const [key, value] of Object.entries(data)) {
    if (value === undefined) continue;

    if (value && typeof value === 'object') {
      if (value.toDate && typeof value.toDate === 'function') {
        cleaned[key] = formatDate(value);
      } else if (Array.isArray(value)) {
        cleaned[key] = value.map(item =>
          typeof item === 'object' ? cleanFirestoreData(item) : item
        );
      } else {
        cleaned[key] = cleanFirestoreData(value);
      }
    } else {
      cleaned[key] = value;
    }
  }

  return cleaned;
}

/**
 * Calculate statistics from an array of numeric values
 */
function calculateStats(values) {
  if (!values || values.length === 0) {
    return { min: null, max: null, avg: null, count: 0 };
  }

  const numericValues = values.filter(v => typeof v === 'number' && !isNaN(v));
  if (numericValues.length === 0) {
    return { min: null, max: null, avg: null, count: 0 };
  }

  const min = Math.min(...numericValues);
  const max = Math.max(...numericValues);
  const avg = numericValues.reduce((a, b) => a + b, 0) / numericValues.length;

  return {
    min: parseFloat(min.toFixed(3)),
    max: parseFloat(max.toFixed(3)),
    avg: parseFloat(avg.toFixed(3)),
    count: numericValues.length
  };
}

// ============================================================================
// DATA EXTRACTION FUNCTIONS
// ============================================================================

/**
 * 1. Extract User Profile & Subscription Data
 */
async function extractUserProfile(userId) {
  console.log('📋 Extracting user profile...');

  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    throw new Error(`User not found: ${userId}`);
  }

  const userData = userDoc.data();

  return {
    basic_info: {
      uid: userId,
      phone_number: userData.phoneNumber,
      first_name: userData.firstName,
      last_name: userData.lastName,
      email: userData.email,
      profile_completed: userData.profileCompleted,
      created_at: formatDate(userData.createdAt),
      last_active: formatDate(userData.lastActive),
    },
    jee_info: {
      target_exam_date: userData.jeeTargetExamDate,
      is_enrolled_in_coaching: userData.isEnrolledInCoaching,
      state: userData.state,
      dream_branch: userData.dreamBranch,
    },
    subscription: {
      tier: userData.subscriptionTier || 'FREE',
      status: userData.subscriptionStatus,
      trial_status: userData.trialStatus,
      trial_start: formatDate(userData.trialStartDate),
      trial_end: formatDate(userData.trialEndDate),
      subscription_start: formatDate(userData.subscriptionStartDate),
      subscription_end: formatDate(userData.subscriptionEndDate),
    },
    learning_metrics: {
      overall_theta: userData.overall_theta,
      overall_percentile: userData.overall_percentile,
      subject_theta: userData.theta_by_subject || {},
      chapter_theta: userData.theta_by_chapter || {},
      total_questions_answered: userData.totalQuestionsAnswered || 0,
      total_correct: userData.totalCorrectAnswers || 0,
      accuracy: userData.totalQuestionsAnswered > 0
        ? parseFloat(((userData.totalCorrectAnswers / userData.totalQuestionsAnswered) * 100).toFixed(2))
        : null,
    },
    engagement: {
      streak: userData.currentStreak || 0,
      longest_streak: userData.longestStreak || 0,
      last_quiz_date: formatDate(userData.lastQuizDate),
      total_daily_quizzes: userData.totalDailyQuizzes || 0,
      total_chapter_sessions: userData.totalChapterSessions || 0,
      total_mock_tests: userData.totalMockTests || 0,
    }
  };
}

/**
 * 2. Extract Initial Assessment Data
 */
async function extractAssessment(userId) {
  console.log('📝 Extracting initial assessment...');

  try {
    const assessmentsSnapshot = await db
      .collection('assessment_responses')
      .where('user_id', '==', userId)
      .orderBy('completed_at', 'desc')
      .get();

    console.log(`  Found ${assessmentsSnapshot.size} assessment documents`);

    const assessments = [];

    // Also check for responses in assessment_responses/{userId}/responses/ subcollection
    const assessmentResponsesRef = db.collection('assessment_responses').doc(userId);
    const responsesSnapshot = await assessmentResponsesRef.collection('responses').get();

    console.log(`  Found ${responsesSnapshot.size} assessment responses in subcollection`);

    if (responsesSnapshot.size > 0) {
      // Aggregate responses into an assessment object
      const responses = responsesSnapshot.docs.map(doc => {
        const data = doc.data();
        return {
          question_id: data.question_id,
          subject: data.subject,
          chapter: data.chapter,
          difficulty: data.difficulty,
          user_answer: data.user_answer,
          correct_answer: data.correct_answer,
          is_correct: data.is_correct,
          time_spent_seconds: data.time_spent_seconds || 0,
          answered_at: formatDate(data.answered_at),
        };
      });

      // Calculate stats from responses
      const totalQuestions = responses.length;
      const correctAnswers = responses.filter(r => r.is_correct).length;

      assessments.push({
        assessment_id: 'from_responses_subcollection',
        completed_at: responses[0]?.answered_at || null,
        total_questions: totalQuestions,
        correct_answers: correctAnswers,
        overall_accuracy: parseFloat(((correctAnswers / totalQuestions) * 100).toFixed(2)),
        responses: responses,
      });
    }

  for (const doc of assessmentsSnapshot.docs) {
    const data = doc.data();

    // Extract response details
    const responses = (data.responses || []).map(r => ({
      question_id: r.question_id,
      subject: r.subject,
      chapter: r.chapter,
      difficulty: r.difficulty,
      user_answer: r.user_answer,
      correct_answer: r.correct_answer,
      is_correct: r.is_correct,
      time_spent_seconds: r.time_spent_seconds,
    }));

    // Calculate per-subject stats
    const subjectStats = {};
    for (const response of responses) {
      const subject = response.subject?.toLowerCase();
      if (!subject) continue;

      if (!subjectStats[subject]) {
        subjectStats[subject] = { total: 0, correct: 0, time_spent: 0 };
      }

      subjectStats[subject].total++;
      if (response.is_correct) subjectStats[subject].correct++;
      subjectStats[subject].time_spent += response.time_spent_seconds || 0;
    }

    // Calculate accuracy for each subject
    for (const subject in subjectStats) {
      const stats = subjectStats[subject];
      stats.accuracy = parseFloat(((stats.correct / stats.total) * 100).toFixed(2));
      stats.avg_time_per_question = parseFloat((stats.time_spent / stats.total).toFixed(1));
    }

    assessments.push({
      assessment_id: doc.id,
      completed_at: formatDate(data.completed_at),
      total_questions: data.total_questions,
      correct_answers: data.correct_answers,
      overall_accuracy: parseFloat(((data.correct_answers / data.total_questions) * 100).toFixed(2)),
      initial_theta: data.initial_theta,
      initial_percentile: data.initial_percentile,
      subject_accuracy: data.subject_accuracy,
      chapter_accuracy: data.chapter_accuracy,
      subject_stats: subjectStats,
      responses: responses,
    });
  }

    return {
      count: assessments.length,
      assessments: assessments,
    };
  } catch (error) {
    console.error('  ❌ Error extracting assessments:', error.message);
    if (error.message.includes('index')) {
      console.error('  💡 Hint: Deploy Firestore indexes with: firebase deploy --only firestore:indexes');
    }
    return {
      count: 0,
      assessments: [],
      error: error.message,
    };
  }
}

/**
 * 3. Extract Daily Quiz History
 */
async function extractDailyQuizzes(userId) {
  console.log('📅 Extracting daily quiz history...');

  try {
    const quizzesSnapshot = await db
      .collection('daily_quizzes')
      .doc(userId)
      .collection('quizzes')
      .orderBy('date', 'desc')
      .get();

    console.log(`  Found ${quizzesSnapshot.size} quiz documents`);

    const quizzes = [];
    const monthlyStats = {};

    // Check for responses in daily_quiz_responses/{userId}/responses/ subcollection
    const quizResponsesRef = db.collection('daily_quiz_responses').doc(userId);
    const responsesSnapshot = await quizResponsesRef.collection('responses').get();

    console.log(`  Found ${responsesSnapshot.size} quiz responses in subcollection`);

    if (responsesSnapshot.size > 0) {
      // Group responses by quiz_id or date
      const responsesByQuiz = {};

      for (const doc of responsesSnapshot.docs) {
        const data = doc.data();
        const quizId = data.quiz_id || 'unknown';

        if (!responsesByQuiz[quizId]) {
          responsesByQuiz[quizId] = [];
        }

        responsesByQuiz[quizId].push({
          question_id: data.question_id,
          subject: data.subject,
          chapter: data.chapter,
          difficulty: data.difficulty,
          user_answer: data.user_answer,
          correct_answer: data.correct_answer,
          is_correct: data.is_correct,
          time_spent_seconds: data.time_spent_seconds || 0,
          answered_at: formatDate(data.answered_at),
        });
      }

      // Create quiz objects from grouped responses
      for (const [quizId, responses] of Object.entries(responsesByQuiz)) {
        const correctCount = responses.filter(r => r.is_correct).length;

        quizzes.push({
          quiz_id: quizId,
          date: responses[0]?.answered_at || null,
          completed: true,
          score: correctCount,
          total_questions: responses.length,
          accuracy: parseFloat(((correctCount / responses.length) * 100).toFixed(2)),
          responses: responses,
          source: 'responses_subcollection',
        });
      }
    }

    for (const doc of quizzesSnapshot.docs) {
    const data = doc.data();

    const quiz = {
      quiz_id: doc.id,
      date: formatDate(data.date),
      completed: data.completed,
      score: data.score,
      total_questions: data.total_questions,
      accuracy: data.total_questions > 0
        ? parseFloat(((data.score / data.total_questions) * 100).toFixed(2))
        : null,
      time_taken_seconds: data.time_taken_seconds,
      subject_breakdown: data.subject_breakdown || {},
      responses: (data.responses || []).map(r => ({
        question_id: r.question_id,
        subject: r.subject,
        chapter: r.chapter,
        difficulty: r.difficulty,
        user_answer: r.user_answer,
        correct_answer: r.correct_answer,
        is_correct: r.is_correct,
        time_spent_seconds: r.time_spent_seconds,
        theta_before: r.theta_before,
        theta_after: r.theta_after,
      })),
    };

    quizzes.push(quiz);

    // Aggregate monthly stats
    if (data.date) {
      const dateObj = data.date.toDate ? data.date.toDate() : new Date(data.date);
      const monthKey = `${dateObj.getFullYear()}-${String(dateObj.getMonth() + 1).padStart(2, '0')}`;

      if (!monthlyStats[monthKey]) {
        monthlyStats[monthKey] = {
          total_quizzes: 0,
          completed_quizzes: 0,
          total_questions: 0,
          correct_answers: 0,
          total_time_seconds: 0,
        };
      }

      monthlyStats[monthKey].total_quizzes++;
      if (data.completed) monthlyStats[monthKey].completed_quizzes++;
      monthlyStats[monthKey].total_questions += data.total_questions || 0;
      monthlyStats[monthKey].correct_answers += data.score || 0;
      monthlyStats[monthKey].total_time_seconds += data.time_taken_seconds || 0;
    }
  }

  // Calculate accuracy for monthly stats
  for (const month in monthlyStats) {
    const stats = monthlyStats[month];
    stats.accuracy = stats.total_questions > 0
      ? parseFloat(((stats.correct_answers / stats.total_questions) * 100).toFixed(2))
      : null;
    stats.avg_time_per_quiz = stats.completed_quizzes > 0
      ? parseFloat((stats.total_time_seconds / stats.completed_quizzes).toFixed(1))
      : null;
  }

    return {
      total_quizzes: quizzes.length,
      completed_quizzes: quizzes.filter(q => q.completed).length,
      monthly_stats: monthlyStats,
      quizzes: quizzes,
    };
  } catch (error) {
    console.error('  ❌ Error extracting daily quizzes:', error.message);
    if (error.message.includes('index')) {
      console.error('  💡 Hint: Deploy Firestore indexes with: firebase deploy --only firestore:indexes');
    }
    return {
      total_quizzes: 0,
      completed_quizzes: 0,
      monthly_stats: {},
      quizzes: [],
      error: error.message,
    };
  }
}

/**
 * 4. Extract Chapter Practice Sessions
 */
async function extractChapterPractice(userId) {
  console.log('📚 Extracting chapter practice sessions...');

  try {
    const sessionsSnapshot = await db
      .collection('chapter_practice_sessions')
      .doc(userId)
      .collection('sessions')
      .orderBy('started_at', 'desc')
      .get();

    console.log(`  Found ${sessionsSnapshot.size} chapter practice sessions`);

    const sessions = [];
  const chapterStats = {};

  for (const doc of sessionsSnapshot.docs) {
    const data = doc.data();

    const session = {
      session_id: doc.id,
      subject: data.subject,
      chapter: data.chapter,
      chapter_key: data.chapter_key,
      started_at: formatDate(data.started_at),
      completed_at: formatDate(data.completed_at),
      completed: data.completed,
      questions_attempted: data.questions_attempted,
      correct_answers: data.correct_answers,
      accuracy: data.questions_attempted > 0
        ? parseFloat(((data.correct_answers / data.questions_attempted) * 100).toFixed(2))
        : null,
      time_taken_seconds: data.time_taken_seconds,
      theta_before: data.theta_before,
      theta_after: data.theta_after,
      theta_change: data.theta_after && data.theta_before
        ? parseFloat((data.theta_after - data.theta_before).toFixed(3))
        : null,
      responses: (data.responses || []).map(r => ({
        question_id: r.question_id,
        difficulty: r.difficulty,
        user_answer: r.user_answer,
        correct_answer: r.correct_answer,
        is_correct: r.is_correct,
        time_spent_seconds: r.time_spent_seconds,
      })),
    };

    sessions.push(session);

    // Aggregate chapter stats
    const chapterKey = data.chapter_key;
    if (chapterKey) {
      if (!chapterStats[chapterKey]) {
        chapterStats[chapterKey] = {
          subject: data.subject,
          chapter: data.chapter,
          total_sessions: 0,
          completed_sessions: 0,
          total_questions: 0,
          correct_answers: 0,
          total_time_seconds: 0,
          theta_changes: [],
        };
      }

      chapterStats[chapterKey].total_sessions++;
      if (data.completed) chapterStats[chapterKey].completed_sessions++;
      chapterStats[chapterKey].total_questions += data.questions_attempted || 0;
      chapterStats[chapterKey].correct_answers += data.correct_answers || 0;
      chapterStats[chapterKey].total_time_seconds += data.time_taken_seconds || 0;

      if (session.theta_change !== null) {
        chapterStats[chapterKey].theta_changes.push(session.theta_change);
      }
    }
  }

  // Calculate stats for each chapter
  for (const chapterKey in chapterStats) {
    const stats = chapterStats[chapterKey];
    stats.accuracy = stats.total_questions > 0
      ? parseFloat(((stats.correct_answers / stats.total_questions) * 100).toFixed(2))
      : null;
    stats.avg_time_per_session = stats.completed_sessions > 0
      ? parseFloat((stats.total_time_seconds / stats.completed_sessions).toFixed(1))
      : null;
    stats.theta_improvement = calculateStats(stats.theta_changes);
    delete stats.theta_changes; // Remove raw array
  }

    return {
      total_sessions: sessions.length,
      completed_sessions: sessions.filter(s => s.completed).length,
      chapter_stats: chapterStats,
      sessions: sessions,
    };
  } catch (error) {
    console.error('  ❌ Error extracting chapter practice:', error.message);
    if (error.message.includes('index')) {
      console.error('  💡 Hint: Deploy Firestore indexes with: firebase deploy --only firestore:indexes');
    }
    return {
      total_sessions: 0,
      completed_sessions: 0,
      chapter_stats: {},
      sessions: [],
      error: error.message,
    };
  }
}

/**
 * 5. Extract Mock Test Data
 */
async function extractMockTests(userId) {
  console.log('🎯 Extracting mock test data...');

  const testsSnapshot = await db
    .collection('users')
    .doc(userId)
    .collection('mock_tests')
    .orderBy('started_at', 'desc')
    .get();

  const tests = [];

  for (const doc of testsSnapshot.docs) {
    const data = doc.data();

    const test = {
      test_id: doc.id,
      template_id: data.template_id,
      test_name: data.test_name,
      started_at: formatDate(data.started_at),
      submitted_at: formatDate(data.submitted_at),
      completed: data.completed,
      total_questions: data.total_questions,
      attempted: data.attempted,
      correct: data.correct,
      incorrect: data.incorrect,
      unattempted: data.unattempted,
      total_marks: data.total_marks,
      obtained_marks: data.obtained_marks,
      accuracy: data.attempted > 0
        ? parseFloat(((data.correct / data.attempted) * 100).toFixed(2))
        : null,
      time_taken_seconds: data.time_taken_seconds,
      subject_wise_performance: data.subject_wise_performance || {},
      responses: (data.responses || []).map(r => ({
        question_id: r.question_id,
        subject: r.subject,
        chapter: r.chapter,
        question_type: r.question_type,
        difficulty: r.difficulty,
        user_answer: r.user_answer,
        correct_answer: r.correct_answer,
        is_correct: r.is_correct,
        marks_awarded: r.marks_awarded,
        time_spent_seconds: r.time_spent_seconds,
        state: r.state, // not_visited, answered, marked_for_review, etc.
      })),
    };

    tests.push(test);
  }

  return {
    total_tests: tests.length,
    completed_tests: tests.filter(t => t.completed).length,
    tests: tests,
  };
}

/**
 * 6. Extract Snap & Solve History
 */
async function extractSnapHistory(userId) {
  console.log('📸 Extracting snap & solve history...');

  const snapsSnapshot = await db
    .collection('users')
    .doc(userId)
    .collection('snaps')
    .orderBy('created_at', 'desc')
    .get();

  const snaps = [];
  const subjectBreakdown = { physics: 0, chemistry: 0, mathematics: 0 };

  for (const doc of snapsSnapshot.docs) {
    const data = doc.data();

    const snap = {
      snap_id: doc.id,
      created_at: formatDate(data.created_at),
      image_url: data.image_url,
      question_text: data.question_text,
      subject: data.subject,
      chapter: data.chapter,
      solution_generated: data.solution_generated,
      solution_text: data.solution_text ? data.solution_text.substring(0, 200) + '...' : null, // Truncate for brevity
      feedback: data.feedback,
      rating: data.rating,
    };

    snaps.push(snap);

    if (data.subject) {
      const subjectLower = data.subject.toLowerCase();
      if (subjectBreakdown[subjectLower] !== undefined) {
        subjectBreakdown[subjectLower]++;
      }
    }
  }

  return {
    total_snaps: snaps.length,
    successful_solutions: snaps.filter(s => s.solution_generated).length,
    subject_breakdown: subjectBreakdown,
    snaps: snaps,
  };
}

/**
 * 7. Extract AI Tutor Conversations
 */
async function extractAITutorConversations(userId) {
  console.log('🤖 Extracting AI tutor conversations...');

  // AI Tutor uses a single conversation document with messages subcollection
  const conversationRef = db
    .collection('users')
    .doc(userId)
    .collection('tutor_conversation')
    .doc('current');

  const conversationDoc = await conversationRef.get();

  if (!conversationDoc.exists) {
    return {
      total_conversations: 0,
      total_messages: 0,
      conversations: [],
    };
  }

  const conversationData = conversationDoc.data();

  // Get all messages from the messages subcollection
  const messagesSnapshot = await conversationRef
    .collection('messages')
    .orderBy('timestamp', 'asc')
    .get();

  const messages = messagesSnapshot.docs.map(doc => {
    const data = doc.data();
    return {
      message_id: doc.id,
      role: data.role, // user or assistant
      content: data.content,
      timestamp: formatDate(data.timestamp),
    };
  });

  const conversation = {
    conversation_id: 'current',
    created_at: formatDate(conversationData.created_at),
    last_message_at: formatDate(conversationData.last_message_at),
    total_messages: messages.length,
    context: conversationData.context || {},
    messages: messages,
  };

  return {
    total_conversations: messages.length > 0 ? 1 : 0,
    total_messages: messages.length,
    conversations: messages.length > 0 ? [conversation] : [],
  };
}

/**
 * 8. Extract Theta Evolution (Weekly Snapshots)
 */
async function extractThetaEvolution(userId) {
  console.log('📈 Extracting theta evolution...');

  try {
    const snapshotsSnapshot = await db
      .collection('theta_snapshots')
      .doc(userId)
      .collection('daily')
      .orderBy('captured_at', 'desc')
      .get();

    console.log(`  Found ${snapshotsSnapshot.size} theta snapshots`);

    const snapshots = [];

  for (const doc of snapshotsSnapshot.docs) {
    const data = doc.data();

    snapshots.push({
      snapshot_id: doc.id,
      quiz_id: data.quiz_id,
      quiz_number: data.quiz_number,
      snapshot_type: data.snapshot_type,
      captured_at: formatDate(data.captured_at),
      overall_theta: data.overall_theta,
      overall_percentile: data.overall_percentile,
      theta_by_subject: data.theta_by_subject || {},
      theta_by_chapter: data.theta_by_chapter || {},
      quiz_performance: data.quiz_performance,
      chapter_updates: data.chapter_updates,
    });
  }

    return {
      total_snapshots: snapshots.length,
      snapshots: snapshots,
    };
  } catch (error) {
    console.error('  ❌ Error extracting theta evolution:', error.message);
    if (error.message.includes('index')) {
      console.error('  💡 Hint: Deploy Firestore indexes with: firebase deploy --only firestore:indexes');
    }
    return {
      total_snapshots: 0,
      snapshots: [],
      error: error.message,
    };
  }
}

/**
 * 9. Extract Usage & Engagement Metrics
 */
async function extractUsageMetrics(userId) {
  console.log('📊 Extracting usage metrics...');

  try {
    const usageSnapshot = await db
      .collection('users')
      .doc(userId)
      .collection('daily_usage')
      .get();

    console.log(`  Found ${usageSnapshot.size} daily usage logs`);

    const dailyUsage = [];

    for (const doc of usageSnapshot.docs) {
      const data = doc.data();
      const dateStr = doc.id; // Document ID is the date (YYYY-MM-DD)

      dailyUsage.push({
        date: dateStr,
        snap_solve: data.snap_solve || 0,
        daily_quiz: data.daily_quiz || 0,
        ai_tutor: data.ai_tutor || 0,
        mock_tests: data.mock_tests || 0,
      });
    }

    // Sort by date descending (most recent first)
    dailyUsage.sort((a, b) => b.date.localeCompare(a.date));

    return {
      total_days: dailyUsage.length,
      daily_usage: dailyUsage,
    };
  } catch (error) {
    console.error('  ❌ Error extracting usage metrics:', error.message);
    if (error.message.includes('index')) {
      console.error('  💡 Hint: Deploy Firestore indexes with: firebase deploy --only firestore:indexes');
    }
    return {
      total_days: 0,
      daily_usage: [],
      error: error.message,
    };
  }
}

// ============================================================================
// MAIN EXTRACTION FUNCTION
// ============================================================================

/**
 * Extract all data for a student
 */
async function extractStudentData(phoneNumber) {
  console.log(`\n🔍 Searching for student with phone: ${phoneNumber}\n`);

  // Find user by phone number
  const usersSnapshot = await db
    .collection('users')
    .where('phoneNumber', '==', phoneNumber)
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    throw new Error(`No user found with phone number: ${phoneNumber}`);
  }

  const userId = usersSnapshot.docs[0].id;
  console.log(`✅ Found user: ${userId}\n`);

  // Extract all data categories
  const extractedData = {
    extraction_timestamp: new Date().toISOString(),
    user_id: userId,
    phone_number: phoneNumber,

    profile: await extractUserProfile(userId),
    assessment: await extractAssessment(userId),
    daily_quizzes: await extractDailyQuizzes(userId),
    chapter_practice: await extractChapterPractice(userId),
    mock_tests: await extractMockTests(userId),
    snap_history: await extractSnapHistory(userId),
    ai_tutor: await extractAITutorConversations(userId),
    theta_evolution: await extractThetaEvolution(userId),
    usage_metrics: await extractUsageMetrics(userId),
  };

  return cleanFirestoreData(extractedData);
}

// ============================================================================
// CLI EXECUTION
// ============================================================================

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    console.log(`
Usage: node backend/scripts/extract-student-data.js <phone_number> [options]

Arguments:
  phone_number        Student's phone number (e.g., +919876543210)

Options:
  --output <file>     Save to file (default: student_data_<timestamp>.json)
  --format <type>     Output format: json (default) or pretty
  --help, -h          Show this help message

Examples:
  node backend/scripts/extract-student-data.js +919876543210
  node backend/scripts/extract-student-data.js +919876543210 --output student.json
  node backend/scripts/extract-student-data.js +919876543210 --format pretty
    `);
    process.exit(0);
  }

  const phoneNumber = args[0];
  const outputIndex = args.indexOf('--output');
  const formatIndex = args.indexOf('--format');

  const outputFile = outputIndex >= 0 && args[outputIndex + 1]
    ? args[outputIndex + 1]
    : `student_data_${Date.now()}.json`;

  const format = formatIndex >= 0 && args[formatIndex + 1]
    ? args[formatIndex + 1]
    : 'json';

  try {
    console.log('═══════════════════════════════════════════════════════');
    console.log('           STUDENT DATA EXTRACTION TOOL');
    console.log('═══════════════════════════════════════════════════════\n');

    const data = await extractStudentData(phoneNumber);

    console.log('\n═══════════════════════════════════════════════════════');
    console.log('           EXTRACTION SUMMARY');
    console.log('═══════════════════════════════════════════════════════');
    console.log(`Name: ${data.profile.basic_info.first_name} ${data.profile.basic_info.last_name}`);
    console.log(`Email: ${data.profile.basic_info.email}`);
    console.log(`Subscription: ${data.profile.subscription.tier}`);
    console.log(`Overall Theta: ${data.profile.learning_metrics.overall_theta}`);
    console.log(`Percentile: ${data.profile.learning_metrics.overall_percentile}%`);
    console.log(`\nData Collected:`);
    console.log(`  - Initial Assessments: ${data.assessment.count}`);
    console.log(`  - Daily Quizzes: ${data.daily_quizzes.total_quizzes} (${data.daily_quizzes.completed_quizzes} completed)`);
    console.log(`  - Chapter Practice: ${data.chapter_practice.total_sessions} sessions`);
    console.log(`  - Mock Tests: ${data.mock_tests.total_tests} (${data.mock_tests.completed_tests} completed)`);
    console.log(`  - Snap & Solve: ${data.snap_history.total_snaps}`);
    console.log(`  - AI Tutor: ${data.ai_tutor.total_conversations} conversations`);
    console.log(`  - Theta Snapshots: ${data.theta_evolution.total_snapshots}`);
    console.log(`  - Daily Usage Logs: ${data.usage_metrics.total_days} days`);
    console.log('═══════════════════════════════════════════════════════\n');

    // Save to file
    const outputPath = path.resolve(outputFile);
    const jsonString = format === 'pretty'
      ? JSON.stringify(data, null, 2)
      : JSON.stringify(data);

    fs.writeFileSync(outputPath, jsonString, 'utf8');

    console.log(`✅ Data saved to: ${outputPath}`);
    console.log(`📦 File size: ${(fs.statSync(outputPath).size / 1024).toFixed(2)} KB\n`);

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = {
  extractStudentData,
  extractUserProfile,
  extractAssessment,
  extractDailyQuizzes,
  extractChapterPractice,
  extractMockTests,
  extractSnapHistory,
  extractAITutorConversations,
  extractThetaEvolution,
  extractUsageMetrics,
};
