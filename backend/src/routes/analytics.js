/**
 * Analytics Routes
 *
 * API endpoints for student analytics and progress tracking.
 *
 * Endpoints:
 * - GET /api/analytics/overview - Get analytics overview (for Overview tab)
 * - GET /api/analytics/mastery/:subject - Get subject mastery details (for Mastery tab)
 * - GET /api/analytics/mastery-timeline - Get mastery/percentile progression over time (for charts)
 * - GET /api/analytics/accuracy-timeline - Get accuracy progression over time (for charts)
 * - GET /api/analytics/all-chapters - Get all chapters mastery status
 * - GET /api/analytics/weekly-activity - Get weekly activity data
 */

const express = require('express');
const router = express.Router();
const { authenticateUser } = require('../middleware/auth');
const logger = require('../utils/logger');
const { db } = require('../config/firebase');

const analyticsService = require('../services/analyticsService');
const thetaSnapshotService = require('../services/thetaSnapshotService');
const progressService = require('../services/progressService');
const { getAnalyticsAccess } = require('../middleware/featureGate');
const { getEffectiveTier, getSubscriptionStatus } = require('../services/subscriptionService');
const { getCurrentWeekIST } = require('../utils/dateUtils');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');

// ============================================================================
// BATCHED ANALYTICS DASHBOARD (NEW - Reduces 4 API calls to 1)
// ============================================================================

/**
 * GET /api/analytics/dashboard
 *
 * Batched endpoint that returns all data needed for analytics dashboard.
 * Replaces 4 separate API calls with 1 call:
 * - User profile
 * - Subscription status
 * - Analytics overview
 * - Weekly activity
 *
 * This reduces rate limiting issues and improves performance.
 *
 * Authentication: Required
 */
router.get('/dashboard', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;

    // Fetch all data in parallel for maximum performance
    const [userDoc, subscriptionStatus, overview, weeklyActivity] = await Promise.all([
      retryFirestoreOperation(() => db.collection('users').doc(userId).get()),
      getSubscriptionStatus(userId),
      analyticsService.getAnalyticsOverview(userId),
      analyticsService.getWeeklyActivity(userId)
    ]);

    const userData = userDoc.exists ? userDoc.data() : {};

    // Build user profile response (matching /api/users/profile format)
    const profile = {
      uid: userId,
      phoneNumber: userData.phone_number || userData.phoneNumber || null,
      firstName: userData.first_name || userData.firstName || null,
      lastName: userData.last_name || userData.lastName || null,
      email: userData.email || null,
      dateOfBirth: userData.date_of_birth?.toDate?.()?.toISOString() || userData.dateOfBirth || null,
      targetExam: userData.target_exam || userData.targetExam || null,
      targetYear: userData.target_year || userData.targetYear || null,
      coachingName: userData.coaching_name || userData.coachingName || null,
      isEnrolledInCoaching: userData.is_enrolled_in_coaching ?? userData.isEnrolledInCoaching ?? false,
      profileCompleted: userData.profile_completed ?? userData.profileCompleted ?? false,
      createdAt: userData.created_at?.toDate?.()?.toISOString() || userData.createdAt || null,
      lastActive: userData.last_active?.toDate?.()?.toISOString() || userData.lastActive || null
    };

    // Return all data in single response
    res.json({
      success: true,
      data: {
        profile,
        subscription: subscriptionStatus,
        overview,
        weeklyActivity
      }
    });
  } catch (error) {
    logger.error('Error fetching analytics dashboard', {
      userId: req.userId,
      error: error.message,
      stack: error.stack
    });
    next(error);
  }
});

// ============================================================================
// ANALYTICS OVERVIEW
// ============================================================================

/**
 * GET /api/analytics/overview
 *
 * Get complete analytics overview for the Overview tab.
 * Returns: user info, stats, subject progress, focus areas, Priya Ma'am message
 *
 * Authentication: Required
 */
router.get('/overview', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;

    // Check analytics access level based on tier
    const analyticsAccess = await getAnalyticsAccess(userId);
    const tierInfo = await getEffectiveTier(userId);

    if (analyticsAccess === 'basic') {
      // FREE tier: Return basic stats with simple subject progress
      // Fetch user data and streak data in parallel
      const [userDoc, streakDoc] = await Promise.all([
        db.collection('users').doc(userId).get(),
        db.collection('practice_streaks').doc(userId).get()
      ]);
      const userData = userDoc.exists ? userDoc.data() : {};
      const streakData = streakDoc.exists ? streakDoc.data() : { current_streak: 0, longest_streak: 0 };

      // Format stats to match AnalyticsStats model expected by mobile
      const stats = {
        questions_solved: userData.total_questions_solved || 0,
        quizzes_completed: userData.completed_quiz_count || 0,
        chapters_mastered: 0, // Not tracked for basic
        current_streak: streakData.current_streak || 0,
        longest_streak: streakData.longest_streak || 0
      };

      // Basic user info
      const user = {
        first_name: userData.first_name || userData.firstName || 'Student',
        last_name: userData.last_name || userData.lastName || ''
      };

      // Basic subject progress - overall percentile and accuracy for each subject
      const thetaBySubject = userData.theta_by_subject || {};
      const subjectAccuracy = userData.subject_accuracy || {};
      const basicSubjectProgress = {};

      const subjects = ['physics', 'chemistry', 'maths'];
      for (const subject of subjects) {
        const subjectData = thetaBySubject[subject] || {};
        // Map 'maths' to 'mathematics' for subject_accuracy lookup
        const accuracyKey = subject === 'maths' ? 'mathematics' : subject;
        const accuracyData = subjectAccuracy[accuracyKey] || {};

        basicSubjectProgress[subject] = {
          display_name: subject.charAt(0).toUpperCase() + subject.slice(1),
          percentile: Math.round(subjectData.percentile || 0),
          accuracy: accuracyData.accuracy ?? null,
          correct: accuracyData.correct ?? 0,
          total: accuracyData.total ?? 0,
          // Don't include detailed chapter data for basic tier
          chapters_tested: 0, // Hidden for basic
          status: 'FOCUS' // Default status, detailed status is PRO feature
        };
      }

      // Calculate focus areas for free tier (needed for chapter practice feature)
      // This enables the Focus Areas card to show chapters to practice
      const thetaByChapter = userData.theta_by_chapter || {};
      const subtopicAccuracy = userData.subtopic_accuracy || {};
      const focusAreas = await analyticsService.calculateFocusAreas(
        thetaByChapter,
        null, // chapterMappings - will be fetched internally
        subtopicAccuracy
      );

      logger.info('Basic analytics overview retrieved', {
        requestId: req.id,
        userId,
        tier: tierInfo.tier,
        access: 'basic',
        questionsSolved: stats.questions_solved,
        quizzesCompleted: stats.quizzes_completed,
        currentStreak: stats.current_streak,
        focusAreasCount: focusAreas.length
      });

      return res.json({
        success: true,
        data: {
          access_level: 'basic',
          user: user,
          stats: stats,
          subject_progress: basicSubjectProgress,
          focus_areas: focusAreas, // Now included for free tier chapter practice
          priya_maam_message: 'Keep learning! Upgrade to Pro for detailed insights.',
          generated_at: new Date().toISOString(),
          upgrade_prompt: {
            message: 'Upgrade to Pro for detailed chapter mastery and focus areas',
            cta_text: 'Unlock Full Analytics',
            current_tier: tierInfo.tier
          }
        },
        requestId: req.id
      });
    }

    // PRO/ULTRA: Return full analytics
    const overview = await analyticsService.getAnalyticsOverview(userId);

    logger.info('Full analytics overview retrieved', {
      requestId: req.id,
      userId,
      tier: tierInfo.tier,
      access: 'full',
      questionsSolved: overview.stats.questions_solved,
      chaptersMastered: overview.stats.chapters_mastered
    });

    res.json({
      success: true,
      data: {
        access_level: 'full',
        ...overview
      },
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// SUBJECT MASTERY DETAILS
// ============================================================================

/**
 * GET /api/analytics/mastery/:subject
 *
 * Get detailed mastery information for a specific subject.
 * Returns: subject overview, all chapters with status labels
 *
 * Authentication: Required
 *
 * @param {string} subject - physics, chemistry, or maths
 */
router.get('/mastery/:subject', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { subject } = req.params;

    // Validate subject
    const validSubjects = ['physics', 'chemistry', 'maths', 'mathematics'];
    if (!validSubjects.includes(subject.toLowerCase())) {
      return res.status(400).json({
        success: false,
        error: 'Invalid subject. Must be physics, chemistry, or maths.',
        requestId: req.id
      });
    }

    const masteryDetails = await analyticsService.getSubjectMasteryDetails(userId, subject);

    logger.info('Subject mastery details retrieved', {
      requestId: req.id,
      userId,
      subject,
      overallPercentile: masteryDetails.overall_percentile
    });

    res.json({
      success: true,
      data: masteryDetails,
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// CHAPTERS BY SUBJECT (FOR CHAPTER PICKER)
// ============================================================================

/**
 * GET /api/analytics/chapters-by-subject/:subject
 *
 * Get ALL chapters for a subject, including ones the user hasn't practiced yet.
 * Used by the Chapter Picker feature for Pro/Ultra users.
 *
 * Authentication: Required
 *
 * @param {string} subject - physics, chemistry, or maths/mathematics
 */
router.get('/chapters-by-subject/:subject', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { subject } = req.params;

    // Validate subject
    const validSubjects = ['physics', 'chemistry', 'maths', 'mathematics'];
    if (!validSubjects.includes(subject.toLowerCase())) {
      return res.status(400).json({
        success: false,
        error: 'Invalid subject. Must be physics, chemistry, or maths.',
        requestId: req.id
      });
    }

    const chapters = await analyticsService.getAllChaptersForSubject(userId, subject);

    logger.info('All chapters by subject retrieved', {
      requestId: req.id,
      userId,
      subject,
      totalChapters: chapters.length
    });

    res.json({
      success: true,
      data: { chapters },
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// MASTERY TIMELINE (FOR CHARTS)
// ============================================================================

/**
 * GET /api/analytics/mastery-timeline
 *
 * Get mastery progression over time for charting.
 * Can filter by subject or get overall progression.
 *
 * Authentication: Required
 *
 * Query params:
 * - subject (optional): physics, chemistry, maths - filter to specific subject
 * - chapter (optional): chapter_key - filter to specific chapter
 * - limit (optional): number of data points (default: 30, max: 100)
 */
router.get('/mastery-timeline', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { subject, chapter, limit: limitStr } = req.query;

    const limit = Math.min(parseInt(limitStr) || 30, 100);

    let progression;

    if (chapter) {
      // Get chapter-specific progression
      progression = await thetaSnapshotService.getChapterThetaProgression(
        userId,
        chapter,
        { limit }
      );
    } else if (subject) {
      // Validate subject
      const validSubjects = ['physics', 'chemistry', 'maths', 'mathematics'];
      if (!validSubjects.includes(subject.toLowerCase())) {
        return res.status(400).json({
          success: false,
          error: 'Invalid subject. Must be physics, chemistry, or maths.',
          requestId: req.id
        });
      }

      // Get subject-specific progression
      progression = await thetaSnapshotService.getSubjectThetaProgression(
        userId,
        subject.toLowerCase(),
        { limit }
      );
    } else {
      // Get overall progression
      progression = await thetaSnapshotService.getOverallThetaProgression(
        userId,
        { limit }
      );
    }

    // Transform data for charting (simplify structure)
    const chartData = progression.map(point => ({
      date: point.date,
      percentile: point.percentile,
      theta: point.theta,
      quiz_number: point.quiz_number
    }));

    logger.info('Mastery timeline retrieved', {
      requestId: req.id,
      userId,
      subject: subject || 'overall',
      chapter: chapter || null,
      dataPoints: chartData.length
    });

    res.json({
      success: true,
      data: {
        filter: {
          subject: subject || null,
          chapter: chapter || null
        },
        data_points: chartData.length,
        timeline: chartData
      },
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// ACCURACY TIMELINE (FOR CHARTS)
// ============================================================================

/**
 * GET /api/analytics/accuracy-timeline
 *
 * Get accuracy progression over time for charting.
 * Returns daily accuracy data (correct/total questions) for a specific subject.
 *
 * Authentication: Required
 *
 * Query params:
 * - subject (required): physics, chemistry, maths - filter to specific subject
 * - days (optional): number of days to look back (default: 30, max: 90)
 */
router.get('/accuracy-timeline', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { subject, days: daysStr } = req.query;

    // Validate subject (required for this endpoint)
    if (!subject) {
      return res.status(400).json({
        success: false,
        error: 'Subject parameter is required.',
        requestId: req.id
      });
    }

    const validSubjects = ['physics', 'chemistry', 'maths', 'mathematics'];
    if (!validSubjects.includes(subject.toLowerCase())) {
      return res.status(400).json({
        success: false,
        error: 'Invalid subject. Must be physics, chemistry, or maths.',
        requestId: req.id
      });
    }

    const days = Math.min(parseInt(daysStr) || 30, 90);

    // Get subject-specific accuracy trends
    const trends = await progressService.getSubjectAccuracyTrends(
      userId,
      subject.toLowerCase(),
      days
    );

    logger.info('Accuracy timeline retrieved', {
      requestId: req.id,
      userId,
      subject: subject.toLowerCase(),
      days,
      dataPoints: trends.length
    });

    res.json({
      success: true,
      data: {
        subject: subject.toLowerCase(),
        days,
        data_points: trends.length,
        timeline: trends
      },
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// ALL CHAPTERS MASTERY (FOR MASTERY TAB)
// ============================================================================

/**
 * GET /api/analytics/all-chapters
 *
 * Get mastery status for all chapters across all subjects.
 * Useful for showing a complete mastery overview.
 *
 * Authentication: Required
 *
 * Query params:
 * - sort (optional): 'percentile' (default), 'alphabetical', 'status'
 */
router.get('/all-chapters', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;
    const { sort = 'percentile' } = req.query;

    // Get all three subjects
    const [physics, chemistry, maths] = await Promise.all([
      analyticsService.getSubjectMasteryDetails(userId, 'physics'),
      analyticsService.getSubjectMasteryDetails(userId, 'chemistry'),
      analyticsService.getSubjectMasteryDetails(userId, 'maths')
    ]);

    // Combine all chapters
    let allChapters = [
      ...physics.chapters.map(c => ({ ...c, subject: 'physics', subject_name: 'Physics' })),
      ...chemistry.chapters.map(c => ({ ...c, subject: 'chemistry', subject_name: 'Chemistry' })),
      ...maths.chapters.map(c => ({ ...c, subject: 'maths', subject_name: 'Maths' }))
    ];

    // Sort based on preference
    switch (sort) {
      case 'alphabetical':
        allChapters.sort((a, b) => a.chapter_name.localeCompare(b.chapter_name));
        break;
      case 'status':
        // Order: FOCUS first, then GROWING, then MASTERED
        const statusOrder = { 'FOCUS': 0, 'GROWING': 1, 'MASTERED': 2 };
        allChapters.sort((a, b) => statusOrder[a.status] - statusOrder[b.status]);
        break;
      case 'percentile':
      default:
        // Highest percentile first
        allChapters.sort((a, b) => b.percentile - a.percentile);
        break;
    }

    // Summary counts
    const summary = {
      total_chapters: allChapters.length,
      mastered: allChapters.filter(c => c.status === 'MASTERED').length,
      growing: allChapters.filter(c => c.status === 'GROWING').length,
      focus: allChapters.filter(c => c.status === 'FOCUS').length,
      by_subject: {
        physics: physics.summary,
        chemistry: chemistry.summary,
        maths: maths.summary
      }
    };

    logger.info('All chapters mastery retrieved', {
      requestId: req.id,
      userId,
      totalChapters: allChapters.length,
      mastered: summary.mastered
    });

    res.json({
      success: true,
      data: {
        summary,
        chapters: allChapters,
        subjects: {
          physics: {
            percentile: physics.overall_percentile,
            status: physics.status
          },
          chemistry: {
            percentile: chemistry.overall_percentile,
            status: chemistry.status
          },
          maths: {
            percentile: maths.overall_percentile,
            status: maths.status
          }
        }
      },
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================================
// WEEKLY ACTIVITY
// ============================================================================

/**
 * GET /api/analytics/weekly-activity
 *
 * Get daily questions answered for the current calendar week (Sun-Sat).
 * Returns data for each day with Sunday first and Saturday last.
 * Future days are marked with isFuture: true.
 *
 * Authentication: Required
 */
router.get('/weekly-activity', authenticateUser, async (req, res, next) => {
  try {
    const userId = req.userId;

    // Get activity trends for the last 7 days (uses IST for date keys)
    const trends = await progressService.getAccuracyTrends(userId, 7);

    // Create a map of existing data
    const dataByDate = {};
    trends.forEach(day => {
      dataByDate[day.date] = day;
    });

    // Generate current calendar week (Sun-Sat) in IST
    const currentWeek = getCurrentWeekIST();
    const weekData = currentWeek.map(day => {
      const existing = dataByDate[day.date];
      return {
        date: day.date,
        dayName: day.dayName,
        isToday: day.isToday,
        isFuture: day.isFuture,
        quizzes: existing?.quizzes || 0,
        questions: existing?.questions || 0,
        correct: existing?.correct || 0,
        accuracy: existing?.accuracy || 0
      };
    });

    // Only count questions up to today (exclude future days)
    const pastAndTodayData = weekData.filter(d => !d.isFuture);

    logger.info('Weekly activity retrieved', {
      requestId: req.id,
      userId,
      daysWithActivity: trends.length,
      timezone: 'IST'
    });

    res.json({
      success: true,
      data: {
        week: weekData,
        total_questions: pastAndTodayData.reduce((sum, d) => sum + d.questions, 0),
        total_quizzes: pastAndTodayData.reduce((sum, d) => sum + d.quizzes, 0)
      },
      requestId: req.id
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
