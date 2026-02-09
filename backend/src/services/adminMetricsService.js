/**
 * Admin Metrics Service
 *
 * Aggregation queries for admin dashboard analytics.
 * All metrics are computed from Firestore collections.
 */

const { db } = require('../config/firebase');
const logger = require('../utils/logger');
const { getTodayIST, getYesterdayIST, formatDateIST, toIST } = require('../utils/dateUtils');

/**
 * Convert Firestore Timestamp to ISO string
 */
function convertTimestamp(timestamp) {
  if (!timestamp) return null;
  if (timestamp.toDate) return timestamp.toDate().toISOString();
  if (timestamp instanceof Date) return timestamp.toISOString();
  return new Date(timestamp).toISOString();
}

/**
 * Get daily health metrics for the dashboard
 *
 * @returns {Object} Health metrics including DAU, signups, completions, at-risk users
 */
async function getDailyHealth() {
  const today = getTodayIST();
  const yesterday = getYesterdayIST();
  const threeDaysAgo = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000);

  // Get all users for various calculations
  const usersSnapshot = await db.collection('users').get();
  const users = [];
  usersSnapshot.forEach(doc => {
    users.push({ uid: doc.id, ...doc.data() });
  });

  // Calculate metrics
  const totalUsers = users.length;

  // DAU - users with lastActive today
  const todayStart = new Date(today + 'T00:00:00+05:30');
  const dau = users.filter(u => {
    if (!u.lastActive) return false;
    const lastActive = u.lastActive.toDate ? u.lastActive.toDate() : new Date(u.lastActive);
    return lastActive >= todayStart;
  }).length;

  // Yesterday's DAU for comparison
  const yesterdayStart = new Date(yesterday + 'T00:00:00+05:30');
  const yesterdayEnd = todayStart;
  const dauYesterday = users.filter(u => {
    if (!u.lastActive) return false;
    const lastActive = u.lastActive.toDate ? u.lastActive.toDate() : new Date(u.lastActive);
    return lastActive >= yesterdayStart && lastActive < yesterdayEnd;
  }).length;

  const dauChange = dauYesterday > 0 ? dau - dauYesterday : 0;

  // New signups today
  const newSignups = users.filter(u => {
    if (!u.createdAt) return false;
    const createdAt = u.createdAt.toDate ? u.createdAt.toDate() : new Date(u.createdAt);
    return createdAt >= todayStart;
  }).length;

  // Assessment completions today
  const assessmentCompletions = users.filter(u => {
    if (!u.assessment?.completed_at) return false;
    const completedAt = u.assessment.completed_at.toDate
      ? u.assessment.completed_at.toDate()
      : new Date(u.assessment.completed_at);
    return completedAt >= todayStart;
  }).length;

  // Quiz completion rate (last 7 days)
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  let totalQuizzes = 0;
  let completedQuizzes = 0;

  // Query quizzes from all users
  for (const user of users.slice(0, 100)) { // Limit to avoid timeout
    try {
      const quizzesSnapshot = await db
        .collection('users')
        .doc(user.uid)
        .collection('quizzes')
        .where('generated_at', '>=', sevenDaysAgo)
        .get();

      quizzesSnapshot.forEach(doc => {
        totalQuizzes++;
        if (doc.data().status === 'completed') {
          completedQuizzes++;
        }
      });
    } catch (err) {
      // Skip users without quizzes subcollection
    }
  }

  const quizCompletionRate = totalQuizzes > 0
    ? Math.round((completedQuizzes / totalQuizzes) * 100) / 100
    : 0;

  // At-risk users (no activity in 3+ days, excluding brand new users)
  const atRiskUsers = users.filter(u => {
    if (!u.lastActive) return false;
    const lastActive = u.lastActive.toDate ? u.lastActive.toDate() : new Date(u.lastActive);
    const createdAt = u.createdAt?.toDate ? u.createdAt.toDate() : new Date(u.createdAt || 0);
    // User must be at least 3 days old and inactive for 3+ days
    return lastActive < threeDaysAgo && createdAt < threeDaysAgo;
  }).length;

  // DAU trend (last 7 days)
  const dauTrend = [];
  for (let i = 6; i >= 0; i--) {
    const date = new Date(Date.now() - i * 24 * 60 * 60 * 1000);
    const dateStr = formatDateIST(toIST(date));
    const dayStart = new Date(dateStr + 'T00:00:00+05:30');
    const dayEnd = new Date(dateStr + 'T23:59:59+05:30');

    const dayDau = users.filter(u => {
      if (!u.lastActive) return false;
      const lastActive = u.lastActive.toDate ? u.lastActive.toDate() : new Date(u.lastActive);
      return lastActive >= dayStart && lastActive <= dayEnd;
    }).length;

    dauTrend.push({ date: dateStr, value: dayDau });
  }

  return {
    dau,
    dauChange,
    newSignups,
    totalUsers,
    assessmentCompletions,
    quizCompletionRate,
    atRiskUsers,
    dauTrend,
    generatedAt: new Date().toISOString()
  };
}

/**
 * Get engagement metrics
 *
 * @returns {Object} Engagement metrics including averages and distributions
 */
async function getEngagement() {
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

  // Get users with activity
  const usersSnapshot = await db.collection('users').get();
  const users = [];
  usersSnapshot.forEach(doc => {
    users.push({ uid: doc.id, ...doc.data() });
  });

  // Get streak data
  const streaksSnapshot = await db.collection('practice_streaks').get();
  const streaks = {};
  streaksSnapshot.forEach(doc => {
    streaks[doc.id] = doc.data();
  });

  // Calculate active users (last 7 days)
  const activeUsers = users.filter(u => {
    if (!u.lastActive) return false;
    const lastActive = u.lastActive.toDate ? u.lastActive.toDate() : new Date(u.lastActive);
    return lastActive >= sevenDaysAgo;
  });

  // Avg quizzes per user (from completed_quiz_count)
  const totalQuizzes = activeUsers.reduce((sum, u) => sum + (u.completed_quiz_count || 0), 0);
  const avgQuizzesPerUser = activeUsers.length > 0
    ? Math.round((totalQuizzes / activeUsers.length) * 10) / 10
    : 0;

  // Avg questions per user
  const totalQuestions = activeUsers.reduce((sum, u) => sum + (u.total_questions_solved || 0), 0);
  const avgQuestionsPerUser = activeUsers.length > 0
    ? Math.round(totalQuestions / activeUsers.length)
    : 0;

  // Avg session time (from total_time_spent_minutes)
  const totalTime = activeUsers.reduce((sum, u) => sum + (u.total_time_spent_minutes || 0), 0);
  const avgSessionMinutes = activeUsers.length > 0
    ? Math.round(totalTime / activeUsers.length)
    : 0;

  // Feature usage (aggregate from daily_usage for last 7 days)
  const featureUsage = {
    daily_quiz: 0,
    snap_solve: 0,
    ai_tutor: 0,
    chapter_practice: 0
  };

  // Sample feature usage from recent users
  for (const user of activeUsers.slice(0, 50)) {
    try {
      // Get daily_usage for daily_quiz, snap_solve, ai_tutor
      const usageSnapshot = await db
        .collection('users')
        .doc(user.uid)
        .collection('daily_usage')
        .orderBy('last_updated', 'desc')
        .limit(7)
        .get();

      usageSnapshot.forEach(doc => {
        const data = doc.data();
        featureUsage.daily_quiz += data.daily_quiz || 0;
        featureUsage.snap_solve += data.snap_solve || 0;
        featureUsage.ai_tutor += data.ai_tutor || 0;
      });

      // Get chapter_practice from chapter_practice_sessions (corrected source)
      // Query completed sessions in last 7 days
      const practiceSnapshot = await db
        .collection('chapter_practice_sessions')
        .doc(user.uid)
        .collection('sessions')
        .where('status', '==', 'completed')
        .where('completed_at', '>=', sevenDaysAgo)
        .get();

      // Count total questions answered in chapter practice sessions
      practiceSnapshot.forEach(doc => {
        const data = doc.data();
        featureUsage.chapter_practice += data.final_total_answered || data.questions_answered || 0;
      });

    } catch (err) {
      // Skip users without usage data
      logger.warn('Failed to get usage for user in engagement metrics', {
        userId: user.uid,
        error: err.message
      });
    }
  }

  // Streak distribution
  const streakDistribution = {
    '0': 0,
    '1-3': 0,
    '4-7': 0,
    '8-14': 0,
    '15+': 0
  };

  Object.values(streaks).forEach(s => {
    const streak = s.current_streak || 0;
    if (streak === 0) streakDistribution['0']++;
    else if (streak <= 3) streakDistribution['1-3']++;
    else if (streak <= 7) streakDistribution['4-7']++;
    else if (streak <= 14) streakDistribution['8-14']++;
    else streakDistribution['15+']++;
  });

  return {
    activeUsers: activeUsers.length,
    avgQuizzesPerUser,
    avgQuestionsPerUser,
    avgSessionMinutes,
    featureUsage,
    streakDistribution,
    generatedAt: new Date().toISOString(),
    metadata: {
      featureUsageSampleSize: Math.min(50, activeUsers.length),
      featureUsageSampled: activeUsers.length > 50,
      streakDistributionIncludesInactive: true
    }
  };
}

/**
 * Get learning outcomes metrics
 *
 * @returns {Object} Learning metrics including theta changes and mastery progression
 */
async function getLearning() {
  // Get users with theta data
  const usersSnapshot = await db.collection('users').get();
  const users = [];
  usersSnapshot.forEach(doc => {
    const data = doc.data();
    if (data.theta_by_chapter || data.overall_theta !== undefined) {
      users.push({ uid: doc.id, ...data });
    }
  });

  // Calculate mastery status counts
  const masteryProgression = {
    mastered: 0, // >= 80 percentile
    growing: 0,  // 40-79 percentile
    focus: 0     // < 40 percentile
  };

  // Track chapter focus areas
  const focusChapterCounts = {};

  users.forEach(user => {
    const percentile = user.overall_percentile || 0;
    if (percentile >= 80) masteryProgression.mastered++;
    else if (percentile >= 40) masteryProgression.growing++;
    else masteryProgression.focus++;

    // Count focus chapters (low percentile chapters)
    const thetaByChapter = user.theta_by_chapter || {};
    Object.entries(thetaByChapter).forEach(([chapter, data]) => {
      if ((data.percentile || 0) < 40 && (data.attempts || 0) > 0) {
        focusChapterCounts[chapter] = (focusChapterCounts[chapter] || 0) + 1;
      }
    });
  });

  // Get most common focus chapters
  const mostCommonFocusChapters = Object.entries(focusChapterCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([chapter, count]) => ({ chapter, count }));

  // Calculate avg theta change (would need weekly snapshots for accurate calculation)
  // For now, estimate from baseline comparison
  let totalImprovement = 0;
  let usersWithBaseline = 0;

  users.forEach(user => {
    if (user.assessment_baseline?.overall_theta !== undefined && user.overall_theta !== undefined) {
      totalImprovement += user.overall_theta - user.assessment_baseline.overall_theta;
      usersWithBaseline++;
    }
  });

  const avgThetaImprovement = usersWithBaseline > 0
    ? Math.round((totalImprovement / usersWithBaseline) * 100) / 100
    : 0;

  // Percentage of students improving
  const improvingStudents = users.filter(user => {
    if (user.assessment_baseline?.overall_theta === undefined) return false;
    return (user.overall_theta || 0) > user.assessment_baseline.overall_theta;
  }).length;

  const percentImproving = users.length > 0
    ? Math.round((improvingStudents / users.length) * 100)
    : 0;

  return {
    totalStudentsWithProgress: users.length,
    masteryProgression,
    avgThetaImprovement,
    percentImproving,
    mostCommonFocusChapters,
    generatedAt: new Date().toISOString()
  };
}

/**
 * Get content quality metrics
 *
 * @returns {Object} Content metrics including question accuracy anomalies
 */
async function getContent() {
  // Get questions with stats
  const questionsSnapshot = await db.collection('questions').get();
  const questions = [];
  questionsSnapshot.forEach(doc => {
    const data = doc.data();
    if (data.times_shown && data.times_shown > 10) { // Only questions with enough data
      questions.push({
        question_id: doc.id,
        ...data
      });
    }
  });

  // Find accuracy anomalies
  const lowAccuracyQuestions = questions
    .filter(q => q.accuracy_rate !== undefined && q.accuracy_rate < 0.20)
    .sort((a, b) => a.accuracy_rate - b.accuracy_rate)
    .slice(0, 20)
    .map(q => ({
      question_id: q.question_id,
      subject: q.subject,
      chapter: q.chapter,
      accuracy_rate: Math.round(q.accuracy_rate * 100),
      times_shown: q.times_shown,
      difficulty_b: q.irt_parameters?.difficulty_b || q.difficulty_b
    }));

  const highAccuracyQuestions = questions
    .filter(q => q.accuracy_rate !== undefined && q.accuracy_rate > 0.95)
    .sort((a, b) => b.accuracy_rate - a.accuracy_rate)
    .slice(0, 20)
    .map(q => ({
      question_id: q.question_id,
      subject: q.subject,
      chapter: q.chapter,
      accuracy_rate: Math.round(q.accuracy_rate * 100),
      times_shown: q.times_shown,
      difficulty_b: q.irt_parameters?.difficulty_b || q.difficulty_b
    }));

  // Avg time by difficulty
  const timeByDifficulty = {
    easy: { total: 0, count: 0 },
    medium: { total: 0, count: 0 },
    hard: { total: 0, count: 0 }
  };

  questions.forEach(q => {
    const difficulty = q.irt_parameters?.difficulty_b || q.difficulty_b || 0;
    const avgTime = q.avg_time_taken || 0;
    if (avgTime > 0) {
      if (difficulty < -0.5) {
        timeByDifficulty.easy.total += avgTime;
        timeByDifficulty.easy.count++;
      } else if (difficulty < 0.5) {
        timeByDifficulty.medium.total += avgTime;
        timeByDifficulty.medium.count++;
      } else {
        timeByDifficulty.hard.total += avgTime;
        timeByDifficulty.hard.count++;
      }
    }
  });

  const avgTimeByDifficulty = {
    easy: timeByDifficulty.easy.count > 0
      ? Math.round(timeByDifficulty.easy.total / timeByDifficulty.easy.count)
      : 0,
    medium: timeByDifficulty.medium.count > 0
      ? Math.round(timeByDifficulty.medium.total / timeByDifficulty.medium.count)
      : 0,
    hard: timeByDifficulty.hard.count > 0
      ? Math.round(timeByDifficulty.hard.total / timeByDifficulty.hard.count)
      : 0
  };

  return {
    totalQuestionsWithStats: questions.length,
    lowAccuracyQuestions,
    highAccuracyQuestions,
    avgTimeByDifficulty,
    generatedAt: new Date().toISOString()
  };
}

/**
 * Get user list with filters
 *
 * @param {Object} options - Filter options
 * @returns {Object} Paginated user list
 */
async function getUsers(options = {}) {
  const { filter = 'all', search = '', limit = 50, offset = 0, isEnrolledInCoaching = false, hasNoTeacher = false } = options;

  // Get all users
  const usersSnapshot = await db.collection('users').get();
  let users = [];
  usersSnapshot.forEach(doc => {
    const userData = doc.data();
    // Apply teacher filters early to reduce data processing
    if (isEnrolledInCoaching && !userData.isEnrolledInCoaching) return;
    if (hasNoTeacher && userData.teacher_id) return;

    users.push({ uid: doc.id, ...userData });
  });

  // Get streak data
  const streaksSnapshot = await db.collection('practice_streaks').get();
  const streaks = {};
  streaksSnapshot.forEach(doc => {
    streaks[doc.id] = doc.data();
  });

  // Enrich users with streak and subscription data
  // Note: Subscription data is stored inside the user document at user.subscription.tier
  users = users.map(user => {
    const streak = streaks[user.uid] || {};
    // Get tier from user.subscription.tier (set by subscriptionService.syncUserTier)
    // or from user.subscription.override.tier_id for beta testers
    const subscriptionData = user.subscription || {};
    const effectiveTier = subscriptionData.tier ||
                          subscriptionData.override?.tier_id ||
                          'free';
    return {
      id: user.uid,
      uid: user.uid,
      firstName: user.firstName || user.first_name || '',
      lastName: user.lastName || user.last_name || '',
      email: user.email || '',
      phoneNumber: user.phoneNumber || user.phone_number || user.phone || '',
      phone: user.phoneNumber || user.phone_number || user.phone || '',
      currentClass: user.currentClass || user.current_class || '',
      tier: effectiveTier,
      currentStreak: streak.current_streak || 0,
      longestStreak: streak.longest_streak || 0,
      totalQuestions: user.total_questions_solved || 0,
      quizzesCompleted: user.completed_quiz_count || 0,
      lastActive: user.lastActive,
      createdAt: user.createdAt,
      overall_percentile: user.overall_percentile || 0,
      overallPercentile: Math.round(user.overall_percentile || 0),
      assessmentCompleted: user.assessment?.status === 'completed',
      isEnrolledInCoaching: user.isEnrolledInCoaching || false,
      teacher_id: user.teacher_id || null
    };
  });

  // Filter out incomplete/orphaned users (no phone AND no email)
  // These are typically test accounts or corrupted records
  users = users.filter(u => u.phone || u.email);

  // Apply filters
  const threeDaysAgo = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000);

  if (filter === 'active') {
    users = users.filter(u => {
      if (!u.lastActive) return false;
      const lastActive = u.lastActive.toDate ? u.lastActive.toDate() : new Date(u.lastActive);
      return lastActive >= threeDaysAgo;
    });
  } else if (filter === 'at-risk') {
    users = users.filter(u => {
      if (!u.lastActive) return true;
      const lastActive = u.lastActive.toDate ? u.lastActive.toDate() : new Date(u.lastActive);
      return lastActive < threeDaysAgo;
    });
  } else if (filter === 'pro') {
    users = users.filter(u => u.tier === 'pro');
  } else if (filter === 'ultra') {
    users = users.filter(u => u.tier === 'ultra');
  }

  // Apply search
  if (search) {
    const searchLower = search.toLowerCase();
    users = users.filter(u =>
      (u.firstName || '').toLowerCase().includes(searchLower) ||
      (u.lastName || '').toLowerCase().includes(searchLower) ||
      (u.email || '').toLowerCase().includes(searchLower) ||
      (u.phone || '').includes(search)
    );
  }

  // Sort by lastActive (most recent first)
  users.sort((a, b) => {
    const aTime = a.lastActive?.toDate ? a.lastActive.toDate() : new Date(a.lastActive || 0);
    const bTime = b.lastActive?.toDate ? b.lastActive.toDate() : new Date(b.lastActive || 0);
    return bTime - aTime;
  });

  // Format dates for response
  const formattedUsers = users.slice(offset, offset + limit).map(u => ({
    ...u,
    lastActive: u.lastActive?.toDate ? u.lastActive.toDate().toISOString() : u.lastActive,
    createdAt: u.createdAt?.toDate ? u.createdAt.toDate().toISOString() : u.createdAt
  }));

  return {
    users: formattedUsers,
    total: users.length,
    limit,
    offset,
    hasMore: offset + limit < users.length
  };
}

/**
 * Get single user details
 *
 * @param {string} userId - User ID
 * @returns {Object} User details with all analytics
 */
async function getUserDetails(userId) {
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    throw new Error('User not found');
  }

  const userData = userDoc.data();

  // Get streak
  const streakDoc = await db.collection('practice_streaks').doc(userId).get();
  const streakData = streakDoc.exists ? streakDoc.data() : {};

  // Get subscription from user document (not a separate collection)
  const subscriptionData = userData.subscription || {};
  const effectiveTier = subscriptionData.tier ||
                        subscriptionData.override?.tier_id ||
                        'free';

  // Get initial assessment data
  const assessmentData = userData.assessment || {};
  let assessmentDetails = null;
  if (assessmentData.status === 'completed') {
    const cumulativeStats = userData.cumulative_stats || {};
    const totalQuestions = assessmentData.responses?.length || 30;
    const correctAnswers = cumulativeStats.total_correct || 0;

    assessmentDetails = {
      completedAt: assessmentData.completed_at,
      score: correctAnswers,
      totalQuestions: totalQuestions,
      timeSpentSeconds: assessmentData.time_taken_seconds || 0,
      accuracy: totalQuestions > 0 ? correctAnswers / totalQuestions : 0,
      subjectScores: userData.subject_accuracy || {}
    };
  }

  // Get daily quizzes
  let dailyQuizzes = [];
  try {
    const dailyQuizzesSnapshot = await db
      .collection('users')
      .doc(userId)
      .collection('daily_quizzes')
      .orderBy('completed_at', 'desc')
      .limit(50)
      .get();

    dailyQuizzesSnapshot.forEach(doc => {
      const quiz = doc.data();
      dailyQuizzes.push({
        id: doc.id,
        date: quiz.date,
        completedAt: quiz.completed_at,
        score: quiz.score || 0,
        totalQuestions: quiz.questions?.length || 0,
        timeSpentSeconds: quiz.time_spent_seconds || 0,
        accuracy: quiz.accuracy || (quiz.score / (quiz.questions?.length || 1)),
        subjects: quiz.subjects || []
      });
    });
  } catch (err) {
    logger.warn('Failed to fetch daily quizzes for user', { userId, error: err.message });
  }

  // Get chapter practice sessions
  let chapterPractice = [];
  try {
    const chapterPracticeSnapshot = await db
      .collection('users')
      .doc(userId)
      .collection('chapter_sessions')
      .orderBy('completed_at', 'desc')
      .limit(50)
      .get();

    chapterPracticeSnapshot.forEach(doc => {
      const session = doc.data();
      chapterPractice.push({
        id: doc.id,
        chapterKey: session.chapter_key,
        chapterName: session.chapter_name || session.chapter_key,
        subject: session.subject,
        completedAt: session.completed_at,
        score: session.score || 0,
        totalQuestions: session.questions?.length || 0,
        timeSpentSeconds: session.time_spent_seconds || 0,
        accuracy: session.accuracy || 0
      });
    });
  } catch (err) {
    logger.warn('Failed to fetch chapter practice for user', { userId, error: err.message });
  }

  // Get mock tests
  let mockTests = [];
  try {
    const mockTestsSnapshot = await db
      .collection('users')
      .doc(userId)
      .collection('mock_tests')
      .orderBy('completed_at', 'desc')
      .limit(20)
      .get();

    mockTestsSnapshot.forEach(doc => {
      const test = doc.data();
      mockTests.push({
        id: doc.id,
        testName: test.test_name || 'JEE Main Mock Test',
        completedAt: test.completed_at,
        score: test.total_score || 0,
        maxScore: test.max_score || 300,
        totalQuestions: test.total_questions || 90,
        timeSpentSeconds: test.time_spent_seconds || 0,
        accuracy: test.overall_accuracy || 0,
        subjectScores: test.subject_scores || {}
      });
    });
  } catch (err) {
    logger.warn('Failed to fetch mock tests for user', { userId, error: err.message });
  }

  // Calculate percentile history (from daily quizzes over time)
  const percentileHistory = [];
  if (dailyQuizzes.length > 0) {
    // Group by month and calculate average percentile
    const monthlyData = {};
    dailyQuizzes.forEach(quiz => {
      if (quiz.completedAt) {
        const date = quiz.completedAt.toDate ? quiz.completedAt.toDate() : new Date(quiz.completedAt);
        const monthKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
        if (!monthlyData[monthKey]) {
          monthlyData[monthKey] = { total: 0, count: 0 };
        }
        monthlyData[monthKey].total += quiz.accuracy * 100;
        monthlyData[monthKey].count += 1;
      }
    });

    Object.keys(monthlyData).sort().forEach(month => {
      percentileHistory.push({
        month,
        averagePercentile: Math.round(monthlyData[month].total / monthlyData[month].count)
      });
    });
  }

  // Convert assessment timestamps
  if (assessmentDetails) {
    assessmentDetails.completedAt = convertTimestamp(assessmentDetails.completedAt);
  }

  // Convert daily quiz timestamps
  dailyQuizzes = dailyQuizzes.map(q => ({
    ...q,
    completedAt: convertTimestamp(q.completedAt)
  }));

  // Convert chapter practice timestamps
  chapterPractice = chapterPractice.map(s => ({
    ...s,
    completedAt: convertTimestamp(s.completedAt)
  }));

  // Convert mock test timestamps
  mockTests = mockTests.map(t => ({
    ...t,
    completedAt: convertTimestamp(t.completedAt)
  }));

  return {
    uid: userId,
    profile: {
      firstName: userData.firstName || userData.first_name || '',
      lastName: userData.lastName || userData.last_name || '',
      email: userData.email || '',
      phone: userData.phone || '',
      createdAt: convertTimestamp(userData.createdAt),
      lastActive: convertTimestamp(userData.lastActive),
      isEnrolledInCoaching: userData.isEnrolledInCoaching || false
    },
    subscription: {
      tier: effectiveTier,
      source: subscriptionData.override ? 'override' : (subscriptionData.active_subscription_id ? 'subscription' : 'default'),
      overrideType: subscriptionData.override?.type,
      overrideExpires: convertTimestamp(subscriptionData.override?.expires_at)
    },
    progress: {
      totalQuestions: userData.total_questions_solved || 0,
      quizzesCompleted: userData.completed_quiz_count || 0,
      overallTheta: userData.overall_theta,
      overallPercentile: userData.overall_percentile,
      thetaBySubject: userData.theta_by_subject,
      thetaByChapter: userData.theta_by_chapter,
      assessmentCompleted: userData.assessment?.status === 'completed'
    },
    streak: {
      current: streakData.current_streak || 0,
      longest: streakData.longest_streak || 0,
      totalDays: streakData.total_days_practiced || 0
    },
    assessment: assessmentDetails,
    dailyQuizzes,
    chapterPractice,
    mockTests,
    percentileHistory
  };
}

module.exports = {
  getDailyHealth,
  getEngagement,
  getLearning,
  getContent,
  getUsers,
  getUserDetails
};
