/**
 * Teacher Reporting Service
 *
 * Generates weekly performance reports for coaching class teachers.
 * Aggregates student activity, performance, and engagement metrics.
 *
 * Features:
 * - Class-level engagement metrics
 * - Identification of struggling students
 * - Topic-level class performance analysis
 * - Positive highlights and improvements
 * - Report caching for performance
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { getWeekBounds, formatDate } = require('./weeklySnapshotService');

// ============================================================================
// CLASS ENGAGEMENT METRICS
// ============================================================================

/**
 * Calculate class-level engagement metrics for a week
 *
 * @param {string[]} studentIds - Array of student user IDs
 * @param {Date} weekStart - Week start date (Monday)
 * @param {Date} weekEnd - Week end date (Sunday)
 * @returns {Promise<Object>} Engagement metrics
 */
async function getClassEngagementMetrics(studentIds, weekStart, weekEnd) {
  try {
    if (!studentIds || studentIds.length === 0) {
      return {
        total_students: 0,
        active_students: 0,
        total_questions_solved: 0,
        avg_questions_per_student: 0,
        total_practice_time_hours: 0,
        avg_practice_time_minutes: 0,
        avg_attendance_percentage: 0,
        total_quizzes_completed: 0
      };
    }

    // Fetch all student documents in batch
    const studentsSnapshot = await retryFirestoreOperation(async () => {
      // Firestore 'in' query supports max 10 items, so batch if needed
      if (studentIds.length <= 10) {
        return await db.collection('users')
          .where(admin.firestore.FieldPath.documentId(), 'in', studentIds)
          .get();
      } else {
        // For > 10 students, make multiple queries
        const batches = [];
        for (let i = 0; i < studentIds.length; i += 10) {
          const batch = studentIds.slice(i, i + 10);
          const snapshot = await db.collection('users')
            .where(admin.firestore.FieldPath.documentId(), 'in', batch)
            .get();
          batches.push(...snapshot.docs);
        }
        return { docs: batches };
      }
    });

    const students = studentsSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    let totalQuestionsThisWeek = 0;
    let totalPracticeTimeMinutes = 0;
    let activeStudents = 0;
    let totalQuizzesCompleted = 0;
    let activeDaysSum = 0;

    // Aggregate metrics from denormalized fields
    for (const student of students) {
      const lastActive = student.lastActive?.toDate?.() || student.lastActive;

      // Check if student was active this week
      if (lastActive && new Date(lastActive) >= weekStart && new Date(lastActive) <= weekEnd) {
        activeStudents++;
      }

      // Note: For accurate weekly metrics, we would need to query subcollections
      // For now, use cumulative stats as approximation
      // In production, consider adding weekly snapshots or daily_usage tracking

      // Cumulative stats (denormalized on user document)
      const cumulativeStats = student.cumulative_stats || {};
      const totalQuestions = student.total_questions_solved || cumulativeStats.total_questions || 0;

      // For this week, we estimate based on last active
      // TODO: Query responses subcollection for accurate weekly count
      if (lastActive && new Date(lastActive) >= weekStart) {
        totalQuestionsThisWeek += Math.min(totalQuestions, 50); // Cap to avoid inflating with cumulative
      }

      // Estimate practice time (if available in cumulative stats)
      const practiceTimeMinutes = cumulativeStats.total_time_minutes || 0;
      if (practiceTimeMinutes > 0) {
        totalPracticeTimeMinutes += practiceTimeMinutes;
      }
    }

    // Calculate averages
    const avgQuestionsPerStudent = students.length > 0
      ? Math.round(totalQuestionsThisWeek / students.length)
      : 0;

    const avgPracticeTimeMinutes = students.length > 0
      ? Math.round(totalPracticeTimeMinutes / students.length)
      : 0;

    const avgAttendancePercentage = students.length > 0
      ? Math.round((activeStudents / students.length) * 100)
      : 0;

    return {
      total_students: students.length,
      active_students: activeStudents,
      total_questions_solved: totalQuestionsThisWeek,
      avg_questions_per_student: avgQuestionsPerStudent,
      total_practice_time_hours: Math.round(totalPracticeTimeMinutes / 60),
      avg_practice_time_minutes: avgPracticeTimeMinutes,
      avg_attendance_percentage: avgAttendancePercentage,
      total_quizzes_completed: totalQuizzesCompleted
    };
  } catch (error) {
    logger.error('Error calculating class engagement metrics', {
      studentCount: studentIds?.length,
      error: error.message
    });
    throw error;
  }
}

// ============================================================================
// STRUGGLING STUDENTS IDENTIFICATION
// ============================================================================

/**
 * Identify students who need attention
 *
 * @param {string[]} studentIds - Array of student user IDs
 * @param {Date} weekStart - Week start date
 * @param {Date} weekEnd - Week end date
 * @returns {Promise<Array>} List of struggling students (max 10)
 */
async function getStrugglingStudents(studentIds, weekStart, weekEnd) {
  try {
    if (!studentIds || studentIds.length === 0) {
      return [];
    }

    // Fetch all student documents
    let students = [];
    for (let i = 0; i < studentIds.length; i += 10) {
      const batch = studentIds.slice(i, i + 10);
      const snapshot = await retryFirestoreOperation(async () => {
        return await db.collection('users')
          .where(admin.firestore.FieldPath.documentId(), 'in', batch)
          .get();
      });
      students.push(...snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })));
    }

    const strugglingStudents = [];

    for (const student of students) {
      const lastActive = student.lastActive?.toDate?.() || student.lastActive;
      const lastActiveDate = lastActive ? new Date(lastActive) : null;

      // Calculate days since last practice
      const daysSinceLastPractice = lastActiveDate
        ? Math.floor((new Date() - lastActiveDate) / (1000 * 60 * 60 * 24))
        : 999;

      // Criteria for struggling:
      // 1. Inactive for > 3 days
      // 2. OR percentile < 40
      // 3. OR very few questions answered
      const isInactive = daysSinceLastPractice > 3;
      const percentile = student.overall_percentile || 50;
      const isLowPercentile = percentile < 40;
      const totalQuestions = student.total_questions_solved || 0;
      const hasLowEngagement = totalQuestions < 10;

      if (isInactive || isLowPercentile || hasLowEngagement) {
        // Anonymize name: first name + last initial
        const firstName = student.firstName || student.first_name || 'Student';
        const lastName = student.lastName || student.last_name || '';
        const anonymizedName = lastName
          ? `${firstName} ${lastName.charAt(0)}.`
          : firstName;

        strugglingStudents.push({
          student_id: student.id,
          student_name: anonymizedName,
          days_since_last_practice: daysSinceLastPractice,
          questions_this_week: 0, // TODO: Query responses for accurate count
          percentile: Math.round(percentile),
          subjects_at_risk: [] // TODO: Identify from theta_by_subject
        });
      }
    }

    // Sort by days inactive (descending) and return top 10
    strugglingStudents.sort((a, b) => b.days_since_last_practice - a.days_since_last_practice);
    return strugglingStudents.slice(0, 10);
  } catch (error) {
    logger.error('Error identifying struggling students', {
      studentCount: studentIds?.length,
      error: error.message
    });
    return [];
  }
}

// ============================================================================
// STRUGGLING TOPICS ANALYSIS
// ============================================================================

/**
 * Identify topics where class is struggling
 *
 * @param {string[]} studentIds - Array of student user IDs
 * @param {Date} weekStart - Week start date
 * @param {Date} weekEnd - Week end date
 * @returns {Promise<Array>} List of struggling topics (max 10)
 */
async function getStrugglingTopics(studentIds, weekStart, weekEnd) {
  try {
    if (!studentIds || studentIds.length === 0) {
      return [];
    }

    // Fetch all student documents with theta data
    let students = [];
    for (let i = 0; i < studentIds.length; i += 10) {
      const batch = studentIds.slice(i, i + 10);
      const snapshot = await retryFirestoreOperation(async () => {
        return await db.collection('users')
          .where(admin.firestore.FieldPath.documentId(), 'in', batch)
          .get();
      });
      students.push(...snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })));
    }

    // Aggregate chapter-level performance
    const chapterStats = {};

    for (const student of students) {
      const thetaByChapter = student.theta_by_chapter || {};

      for (const [chapterKey, chapterData] of Object.entries(thetaByChapter)) {
        if (!chapterStats[chapterKey]) {
          chapterStats[chapterKey] = {
            total_theta: 0,
            student_count: 0,
            below_threshold_count: 0,
            total_attempts: 0
          };
        }

        const theta = chapterData.theta || 0;
        const attempts = chapterData.attempts || chapterData.questions_answered || 0;

        chapterStats[chapterKey].total_theta += theta;
        chapterStats[chapterKey].student_count += 1;
        chapterStats[chapterKey].total_attempts += attempts;

        // Count students below threshold (theta < -0.5 or percentile < 50)
        if (theta < -0.5) {
          chapterStats[chapterKey].below_threshold_count += 1;
        }
      }
    }

    // Calculate average accuracy and identify struggling topics
    const strugglingTopics = [];

    for (const [chapterKey, stats] of Object.entries(chapterStats)) {
      if (stats.student_count === 0) continue;

      const avgTheta = stats.total_theta / stats.student_count;
      // Convert theta to approximate accuracy percentage (rough estimate)
      const estimatedAccuracy = Math.max(0, Math.min(100, 50 + (avgTheta * 15)));
      const strugglingStudentCount = stats.below_threshold_count;

      // Consider topic struggling if:
      // 1. Average accuracy < 50%
      // 2. OR >30% of students below threshold
      const isStruggling = estimatedAccuracy < 50 ||
        (strugglingStudentCount / stats.student_count) > 0.3;

      if (isStruggling) {
        // Parse chapter name from key
        const chapterName = chapterKey
          .replace(/^(physics|chemistry|mathematics|maths)_/, '')
          .split('_')
          .map(word => word.charAt(0).toUpperCase() + word.slice(1))
          .join(' ');

        const subject = chapterKey.startsWith('physics') ? 'Physics' :
          chapterKey.startsWith('chemistry') ? 'Chemistry' : 'Mathematics';

        strugglingTopics.push({
          chapter_key: chapterKey,
          chapter_name: chapterName,
          subject: subject,
          class_avg_accuracy: Math.round(estimatedAccuracy),
          students_struggling: strugglingStudentCount,
          total_attempts: stats.total_attempts,
          questions_answered: stats.total_attempts
        });
      }
    }

    // Sort by accuracy (ascending) and return top 10
    strugglingTopics.sort((a, b) => a.class_avg_accuracy - b.class_avg_accuracy);
    return strugglingTopics.slice(0, 10);
  } catch (error) {
    logger.error('Error identifying struggling topics', {
      studentCount: studentIds?.length,
      error: error.message
    });
    return [];
  }
}

// ============================================================================
// CLASS HIGHLIGHTS
// ============================================================================

/**
 * Generate positive highlights for the class
 *
 * @param {string[]} studentIds - Array of student user IDs
 * @param {Date} weekStart - Week start date
 * @param {Date} weekEnd - Week end date
 * @returns {Promise<Object>} Highlights object
 */
async function getClassHighlights(studentIds, weekStart, weekEnd) {
  try {
    if (!studentIds || studentIds.length === 0) {
      return {
        top_performers: [],
        most_improved_chapter: null,
        longest_streak_student: null
      };
    }

    // Fetch students
    let students = [];
    for (let i = 0; i < studentIds.length; i += 10) {
      const batch = studentIds.slice(i, i + 10);
      const snapshot = await retryFirestoreOperation(async () => {
        return await db.collection('users')
          .where(admin.firestore.FieldPath.documentId(), 'in', batch)
          .get();
      });
      students.push(...snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })));
    }

    // Find top performers (by percentile gain or absolute percentile)
    const topPerformers = students
      .filter(s => (s.overall_percentile || 0) > 70)
      .sort((a, b) => (b.overall_percentile || 0) - (a.overall_percentile || 0))
      .slice(0, 3)
      .map(s => {
        const firstName = s.firstName || s.first_name || 'Student';
        const lastName = s.lastName || s.last_name || '';
        const anonymizedName = lastName
          ? `${firstName} ${lastName.charAt(0)}.`
          : firstName;

        return {
          student_id: s.id,
          student_name: anonymizedName,
          percentile: Math.round(s.overall_percentile || 0),
          percentile_gain: 0 // TODO: Calculate from baseline or previous week
        };
      });

    // Most improved chapter (aggregate)
    // TODO: Implement by comparing theta deltas from previous week
    const mostImprovedChapter = null;

    // Longest streak student
    // TODO: Query practice_streaks collection
    const longestStreakStudent = null;

    return {
      top_performers: topPerformers,
      most_improved_chapter: mostImprovedChapter,
      longest_streak_student: longestStreakStudent
    };
  } catch (error) {
    logger.error('Error generating class highlights', {
      studentCount: studentIds?.length,
      error: error.message
    });
    return {
      top_performers: [],
      most_improved_chapter: null,
      longest_streak_student: null
    };
  }
}

// ============================================================================
// REPORT GENERATION
// ============================================================================

/**
 * Generate weekly report for a single teacher
 *
 * @param {string} teacherId - Teacher ID
 * @param {Date} weekEnd - Week end date (defaults to last Sunday)
 * @returns {Promise<Object>} Generated report
 */
async function generateWeeklyReportForTeacher(teacherId, weekEnd = null) {
  try {
    // Get teacher document
    const teacherDoc = await retryFirestoreOperation(async () => {
      return await db.collection('teachers').doc(teacherId).get();
    });

    if (!teacherDoc.exists) {
      throw new Error('Teacher not found');
    }

    const teacher = teacherDoc.data();

    // Calculate week bounds
    const reportWeekEnd = weekEnd || new Date();
    const { weekStart, weekEnd: calculatedWeekEnd } = getWeekBounds(reportWeekEnd);

    // Get student IDs
    const studentIds = teacher.student_ids || [];

    logger.info('Generating weekly report', {
      teacherId,
      teacherEmail: teacher.email,
      studentCount: studentIds.length,
      weekStart: formatDate(weekStart),
      weekEnd: formatDate(calculatedWeekEnd)
    });

    // Generate all report sections
    const [classMetrics, strugglingStudents, strugglingTopics, highlights] = await Promise.all([
      getClassEngagementMetrics(studentIds, weekStart, calculatedWeekEnd),
      getStrugglingStudents(studentIds, weekStart, calculatedWeekEnd),
      getStrugglingTopics(studentIds, weekStart, calculatedWeekEnd),
      getClassHighlights(studentIds, weekStart, calculatedWeekEnd)
    ]);

    // Create report document
    const reportId = `teacher_${teacherId}_week_${formatDate(calculatedWeekEnd).replace(/-/g, '')}`;
    const report = {
      report_id: reportId,
      teacher_id: teacherId,
      teacher_email: teacher.email,
      week_start: formatDate(weekStart),
      week_end: formatDate(calculatedWeekEnd),
      generated_at: admin.firestore.FieldValue.serverTimestamp(),

      class_metrics: classMetrics,
      struggling_students: strugglingStudents,
      struggling_topics: strugglingTopics,
      highlights: highlights,

      email_sent: false,
      email_sent_at: null
    };

    // Save report to Firestore (cache)
    await retryFirestoreOperation(async () => {
      await db.collection('teacher_reports').doc(reportId).set(report);
    });

    logger.info('Weekly report generated', {
      teacherId,
      reportId,
      activeStudents: classMetrics.active_students,
      strugglingCount: strugglingStudents.length
    });

    return {
      ...report,
      generated_at: new Date()
    };
  } catch (error) {
    logger.error('Error generating weekly report', {
      teacherId,
      error: error.message
    });
    throw error;
  }
}

/**
 * Generate weekly reports for all active teachers
 *
 * @param {Date} weekEnd - Week end date (defaults to last Sunday)
 * @returns {Promise<Object>} Generation results
 */
async function generateWeeklyReportsForAllTeachers(weekEnd = null) {
  try {
    // Get all active teachers
    const teachersSnapshot = await retryFirestoreOperation(async () => {
      return await db.collection('teachers')
        .where('is_active', '==', true)
        .get();
    });

    const teachers = teachersSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    logger.info('Generating reports for all teachers', {
      totalTeachers: teachers.length,
      weekEnd: weekEnd ? formatDate(weekEnd) : 'current'
    });

    let generated = 0;
    let errors = 0;
    const errorDetails = [];

    for (const teacher of teachers) {
      try {
        await generateWeeklyReportForTeacher(teacher.id, weekEnd);
        generated++;
      } catch (error) {
        errors++;
        errorDetails.push({
          teacherId: teacher.id,
          email: teacher.email,
          error: error.message
        });
        logger.error('Failed to generate report for teacher', {
          teacherId: teacher.id,
          email: teacher.email,
          error: error.message
        });
      }
    }

    logger.info('Batch report generation complete', {
      total: teachers.length,
      generated,
      errors
    });

    return {
      total: teachers.length,
      generated,
      errors,
      errorDetails
    };
  } catch (error) {
    logger.error('Error in batch report generation', {
      error: error.message
    });
    throw error;
  }
}

module.exports = {
  getClassEngagementMetrics,
  getStrugglingStudents,
  getStrugglingTopics,
  getClassHighlights,
  generateWeeklyReportForTeacher,
  generateWeeklyReportsForAllTeachers
};
