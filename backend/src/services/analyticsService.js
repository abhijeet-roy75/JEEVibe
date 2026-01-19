/**
 * Analytics Service
 *
 * Provides analytics data for student progress screens.
 *
 * Features:
 * - Personalized Priya Ma'am messages (rule-based)
 * - Focus areas calculation
 * - Mastery status labels (MASTERED/GROWING/FOCUS)
 * - Analytics overview aggregation
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { getDatabaseNames, initializeMappings } = require('./chapterMappingService');
const fs = require('fs');
const path = require('path');

// Load templates from JSON file
const templatesPath = path.join(__dirname, '../templates/priyaMaamAnalytics.json');
let templates = JSON.parse(fs.readFileSync(templatesPath, 'utf8'));

// Watch for template file changes in development
if (process.env.NODE_ENV !== 'production') {
  fs.watchFile(templatesPath, () => {
    try {
      templates = JSON.parse(fs.readFileSync(templatesPath, 'utf8'));
      logger.info('Analytics templates reloaded');
    } catch (error) {
      logger.error('Error reloading analytics templates', { error: error.message });
    }
  });
}

// ============================================================================
// MASTERY STATUS CALCULATION
// ============================================================================

/**
 * Get mastery status label based on percentile
 *
 * @param {number} percentile - Current percentile (0-100)
 * @param {number} previousPercentile - Previous percentile for trend detection (optional)
 * @returns {string} 'MASTERED', 'GROWING', or 'FOCUS'
 */
function getMasteryStatus(percentile, previousPercentile = null) {
  const thresholds = templates.mastery_thresholds;

  if (percentile >= thresholds.mastered_min_percentile) {
    return 'MASTERED';
  }

  if (percentile >= thresholds.growing_min_percentile) {
    return 'GROWING';
  }

  return 'FOCUS';
}

/**
 * Get display name for a chapter (async - fetches from database)
 *
 * @param {string} chapterKey - Chapter key (e.g., 'physics_kinematics')
 * @returns {Promise<string>} Display name or formatted key
 */
async function getChapterDisplayNameAsync(chapterKey) {
  try {
    const mapping = await getDatabaseNames(chapterKey);
    if (mapping && mapping.chapter) {
      return mapping.chapter;
    }
  } catch (error) {
    logger.warn('Failed to get chapter display name from DB', { chapterKey, error: error.message });
  }

  // Fallback: convert key to title case
  return formatChapterKeyToDisplayName(chapterKey);
}

/**
 * Get display name for a chapter (sync - uses fallback formatting)
 * Use getChapterDisplayNameAsync when possible for accurate names
 *
 * @param {string} chapterKey - Chapter key (e.g., 'physics_kinematics')
 * @returns {string} Display name or formatted key
 */
function getChapterDisplayName(chapterKey) {
  return formatChapterKeyToDisplayName(chapterKey);
}

/**
 * Format chapter key to display name (fallback)
 *
 * @param {string} chapterKey - Chapter key
 * @returns {string} Formatted display name
 */
function formatChapterKeyToDisplayName(chapterKey) {
  return chapterKey
    .replace(/^(physics|chemistry|maths|mathematics)_/, '')
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

/**
 * Get display name for a subject
 *
 * @param {string} subject - Subject key
 * @returns {string} Display name
 */
function getSubjectDisplayName(subject) {
  return templates.subject_display_names[subject.toLowerCase()] ||
    subject.charAt(0).toUpperCase() + subject.slice(1);
}

// ============================================================================
// FOCUS AREAS CALCULATION
// ============================================================================

/**
 * Calculate top focus areas for a student
 * Returns exactly 1 focus chapter per subject (physics, chemistry, maths)
 * for consistent display across Overview and Mastery tabs.
 *
 * @param {Object} thetaByChapter - Chapter theta data
 * @param {Map} chapterMappings - Pre-loaded chapter mappings (optional)
 * @param {Object} subtopicAccuracy - Subtopic accuracy data (source of truth for correct/total)
 * @returns {Promise<Array>} Array of focus area objects (1 per subject)
 */
async function calculateFocusAreas(thetaByChapter, chapterMappings = null, subtopicAccuracy = {}) {
  const thresholds = templates.mastery_thresholds;
  const subjects = ['physics', 'chemistry', 'mathematics'];

  // Pre-load chapter mappings if not provided
  if (!chapterMappings) {
    try {
      chapterMappings = await initializeMappings();
    } catch (error) {
      logger.warn('Failed to load chapter mappings, using fallback names', { error: error.message });
      chapterMappings = new Map();
    }
  }

  // Group chapters by subject and find the weakest (lowest percentile) for each
  const subjectFocusAreas = {};

  for (const [chapterKey, data] of Object.entries(thetaByChapter)) {
    const percentile = data.percentile || 0;
    const attempts = data.attempts || 0;

    // Extract subject from chapter key
    const subject = chapterKey.split('_')[0];

    // Only process known subjects
    if (!subjects.includes(subject)) {
      continue;
    }

    // Determine reason based on percentile
    let reason = 'low_percentile';
    if (percentile >= thresholds.mastered_min_percentile) {
      reason = 'mastered';
    } else if (attempts < 5 && percentile < 50) {
      reason = 'low_attempts';
    } else if (percentile >= 35 && percentile < thresholds.growing_min_percentile) {
      reason = 'close_to_breakthrough';
    } else if (percentile < 30) {
      reason = 'needs_attention';
    }

    // Get display name from mappings or fallback
    const mapping = chapterMappings.get(chapterKey);
    const chapterName = mapping?.chapter || formatChapterKeyToDisplayName(chapterKey);

    // Get correct/total from subtopic_accuracy (source of truth) like getMasteryDetails does
    const chapterSubtopics = subtopicAccuracy[chapterKey] || {};
    const subtopicEntries = Object.entries(chapterSubtopics);

    let correct = 0;
    let total = 0;
    let accuracy = 0;

    if (subtopicEntries.length > 0) {
      // Calculate accuracy from subtopic data (weighted average)
      const subtopicCorrect = subtopicEntries.reduce((sum, [, s]) => sum + (s.correct || 0), 0);
      const subtopicTotal = subtopicEntries.reduce((sum, [, s]) => sum + (s.total || 0), 0);
      accuracy = subtopicTotal > 0 ? Math.round((subtopicCorrect / subtopicTotal) * 100) : 0;

      // Use theta_by_chapter.attempts for actual question count (avoids double-counting
      // when questions cover multiple subtopics)
      total = attempts;
      correct = total > 0 ? Math.round((accuracy / 100) * total) : 0;
    } else {
      // Fall back to theta_by_chapter data if no subtopics
      accuracy = data.accuracy || 0;
      if (accuracy > 0 && accuracy <= 1) {
        accuracy = Math.round(accuracy * 100);
      }
      total = attempts;
      correct = total > 0 ? Math.round((accuracy / 100) * total) : 0;
    }

    const focusArea = {
      chapter_key: chapterKey,
      chapter_name: chapterName,
      subject: subject,
      subject_name: getSubjectDisplayName(subject),
      percentile: percentile,
      attempts: attempts,
      accuracy: accuracy,
      correct: correct,
      total: total,
      reason: reason,
      status: getMasteryStatus(percentile)
    };

    // Keep the chapter with lowest percentile for each subject
    if (!subjectFocusAreas[subject] || percentile < subjectFocusAreas[subject].percentile) {
      subjectFocusAreas[subject] = focusArea;
    }
  }

  // Ensure we have exactly 1 focus area per subject
  // For subjects with no data in thetaByChapter, pick from chapterMappings
  for (const subject of subjects) {
    if (!subjectFocusAreas[subject]) {
      // Find all chapters for this subject from mappings
      const subjectChapters = [];
      for (const [chapterKey, mapping] of chapterMappings.entries()) {
        const keySubject = chapterKey.split('_')[0];
        if (keySubject === subject) {
          // Check if user has any data for this chapter
          const userData = thetaByChapter[chapterKey];
          subjectChapters.push({
            chapterKey,
            chapterName: mapping.chapter,
            attempts: userData?.attempts || 0
          });
        }
      }

      if (subjectChapters.length > 0) {
        // Sort by attempts (descending), then alphabetically by chapter name
        subjectChapters.sort((a, b) => {
          if (b.attempts !== a.attempts) {
            return b.attempts - a.attempts; // Most attempts first
          }
          return a.chapterName.localeCompare(b.chapterName); // Alphabetical
        });

        const picked = subjectChapters[0];
        subjectFocusAreas[subject] = {
          chapter_key: picked.chapterKey,
          chapter_name: picked.chapterName,
          subject: subject,
          subject_name: getSubjectDisplayName(subject),
          percentile: 0,
          attempts: picked.attempts,
          accuracy: 0,
          correct: 0,
          total: 0,
          reason: 'not_started',
          status: 'focus'
        };
      }
    }
  }

  // Return focus areas in consistent order: physics, chemistry, maths
  const focusAreas = [];
  for (const subject of subjects) {
    if (subjectFocusAreas[subject]) {
      focusAreas.push(subjectFocusAreas[subject]);
    }
  }

  return focusAreas;
}

// ============================================================================
// PRIYA MA'AM MESSAGE GENERATION
// ============================================================================

/**
 * Get time-of-day based greeting
 *
 * @param {Date} now - Current time
 * @returns {string} Greeting template key
 */
function getTimeBasedGreetingKey(now) {
  const hour = now.getHours();

  if (hour >= 5 && hour < 12) return 'morning';
  if (hour >= 12 && hour < 17) return 'afternoon';
  if (hour >= 17 && hour < 21) return 'evening';
  return 'night';
}

/**
 * Find next upcoming milestone
 *
 * @param {number} current - Current count
 * @param {Array} milestones - Array of milestone values
 * @returns {Object|null} { milestone, remaining } or null
 */
function findNextMilestone(current, milestones) {
  for (const milestone of milestones) {
    if (current < milestone) {
      const remaining = milestone - current;
      // Only return if within 20% of milestone
      if (remaining <= milestone * 0.2) {
        return { milestone, remaining };
      }
      return null;
    }
  }
  return null;
}

/**
 * Replace template placeholders with values
 *
 * @param {string} template - Template string with {placeholder} syntax
 * @param {Object} values - Key-value pairs for replacement
 * @returns {string} Processed string
 */
function fillTemplate(template, values) {
  let result = template;
  for (const [key, value] of Object.entries(values)) {
    result = result.replace(new RegExp(`\\{${key}\\}`, 'g'), value);
  }
  return result;
}

/**
 * Generate personalized Priya Ma'am message
 *
 * @param {Object} userData - User document data
 * @param {Object} streakData - Streak document data
 * @param {Object} subjectProgress - Subject progress data
 * @param {Array} focusAreas - Calculated focus areas
 * @returns {string} Personalized message
 */
function generatePriyaMaamMessage(userData, streakData, subjectProgress, focusAreas) {
  const parts = [];
  const now = new Date();
  const firstName = userData.firstName || 'Student';

  // 1. GREETING
  let greetingKey = getTimeBasedGreetingKey(now);

  // Override for special cases
  const currentStreak = streakData.current_streak || 0;
  const lastPracticeDate = streakData.last_practice_date;

  // Check if returning after gap
  if (lastPracticeDate) {
    const lastDate = new Date(lastPracticeDate);
    const daysSinceLastPractice = Math.floor((now - lastDate) / (1000 * 60 * 60 * 24));

    if (daysSinceLastPractice > 7) {
      greetingKey = 'comeback';
    } else if (currentStreak >= 7) {
      greetingKey = 'streak_champion';
    }
  }

  const greetingTemplate = templates.greetings[greetingKey] || templates.greetings.afternoon;
  parts.push(fillTemplate(greetingTemplate, { firstName }));

  // 2. PROGRESS CELEBRATION
  const questionsSolved = Number(userData.total_questions_solved || 0);
  const chaptersMastered = Number(countMasteredChapters(userData.theta_by_chapter || {}));

  let progressTemplate;
  
  // Handle edge cases first - be explicit about the conditions
  if (questionsSolved === 0 && chaptersMastered === 0) {
    // Both are zero - new user
    progressTemplate = templates.progress_celebration.both_zero;
    parts.push(progressTemplate);
  } else if (questionsSolved === 0 && chaptersMastered > 0) {
    // Only chapters mastered (unlikely but handle it)
    progressTemplate = templates.progress_celebration.chapters_only;
    parts.push(fillTemplate(progressTemplate, {
      chaptersMastered
    }));
  } else if (questionsSolved > 0 && chaptersMastered === 0) {
    // Only questions solved, no chapters mastered yet - use questions_only template
    progressTemplate = templates.progress_celebration.questions_only;
    parts.push(fillTemplate(progressTemplate, {
      questionsSolved
    }));
  } else if (questionsSolved > 0 && chaptersMastered > 0) {
    // Both have values (questionsSolved > 0 && chaptersMastered > 0)
    // Check for milestone or use default
    const nextMilestone = findNextMilestone(questionsSolved, templates.question_milestones);
    
    if (nextMilestone) {
      progressTemplate = templates.progress_celebration.near_milestone_questions;
      parts.push(fillTemplate(progressTemplate, {
        remaining: nextMilestone.remaining,
        milestone: nextMilestone.milestone
      }));
    } else {
      progressTemplate = templates.progress_celebration.default;
      parts.push(fillTemplate(progressTemplate, {
        questionsSolved,
        chaptersMastered
      }));
    }
  }

  // 3. STRENGTH CALLOUT
  const subjects = Object.entries(subjectProgress)
    .filter(([key]) => ['physics', 'chemistry', 'maths', 'mathematics'].includes(key.toLowerCase()))
    .map(([subject, data]) => ({
      subject: getSubjectDisplayName(subject),
      percentile: data.percentile || data.current_percentile || 0
    }))
    .sort((a, b) => b.percentile - a.percentile);

  if (subjects.length > 0) {
    const best = subjects[0];
    const thresholds = templates.mastery_thresholds;

    if (best.percentile >= thresholds.exceptional_min_percentile) {
      parts.push(fillTemplate(templates.strength_callout.exceptional, {
        subject: best.subject,
        percent: Math.round(best.percentile)
      }));
    } else if (subjects.length >= 2) {
      const gap = best.percentile - subjects[1].percentile;

      if (gap < 10 && subjects.length >= 2) {
        // Check if all balanced
        const allBalanced = subjects.every(s =>
          Math.abs(s.percentile - best.percentile) < 10
        );

        if (allBalanced && subjects.length >= 3) {
          parts.push(templates.strength_callout.all_balanced);
        } else {
          parts.push(fillTemplate(templates.strength_callout.two_tied, {
            subject1: best.subject,
            subject2: subjects[1].subject
          }));
        }
      } else {
        parts.push(fillTemplate(templates.strength_callout.one_strongest, {
          bestSubject: best.subject,
          percent: Math.round(best.percentile)
        }));
      }
    } else {
      parts.push(fillTemplate(templates.strength_callout.one_strongest, {
        bestSubject: best.subject,
        percent: Math.round(best.percentile)
      }));
    }
  }

  // 4. FOCUS RECOMMENDATION
  if (focusAreas.length > 0) {
    const topFocus = focusAreas[0];
    let focusTemplate;

    switch (topFocus.reason) {
      case 'close_to_breakthrough':
        focusTemplate = templates.focus_recommendation.close_to_breakthrough;
        break;
      case 'low_attempts':
        focusTemplate = templates.focus_recommendation.low_attempts;
        break;
      case 'needs_attention':
        focusTemplate = templates.focus_recommendation.needs_attention;
        break;
      default:
        focusTemplate = templates.focus_recommendation.needs_attention;
    }

    parts.push(fillTemplate(focusTemplate, {
      subject: topFocus.subject_name,
      chapter: topFocus.chapter_name
    }));
  } else {
    parts.push(templates.focus_recommendation.no_weak_areas);
  }

  // 5. STREAK MOTIVATION
  let streakTemplate;

  if (currentStreak === 0) {
    streakTemplate = templates.streak_motivation.no_streak;
  } else if (currentStreak === 1) {
    streakTemplate = templates.streak_motivation.day_1;
  } else if (currentStreak <= 6) {
    streakTemplate = templates.streak_motivation.days_2_to_6;
  } else if (currentStreak <= 13) {
    streakTemplate = templates.streak_motivation.days_7_to_13;
  } else if (currentStreak <= 29) {
    streakTemplate = templates.streak_motivation.days_14_to_29;
  } else {
    streakTemplate = templates.streak_motivation.days_30_plus;
  }

  parts.push(fillTemplate(streakTemplate, { streak: currentStreak }));

  return parts.join(' ');
}

/**
 * Count chapters with MASTERED status
 *
 * @param {Object} thetaByChapter - Chapter theta data
 * @returns {number} Count of mastered chapters
 */
function countMasteredChapters(thetaByChapter) {
  const threshold = templates.mastery_thresholds.mastered_min_percentile;
  let count = 0;

  for (const data of Object.values(thetaByChapter)) {
    if ((data.percentile || 0) >= threshold) {
      count++;
    }
  }

  return count;
}

// ============================================================================
// ANALYTICS OVERVIEW
// ============================================================================

/**
 * Get complete analytics overview for a user
 *
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Analytics overview data
 */
async function getAnalyticsOverview(userId) {
  try {
    // Fetch user data
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    if (!userDoc.exists) {
      throw new Error(`User ${userId} not found`);
    }

    const userData = userDoc.data();

    // Fetch streak data
    const streakRef = db.collection('practice_streaks').doc(userId);
    const streakDoc = await retryFirestoreOperation(async () => {
      return await streakRef.get();
    });

    const streakData = streakDoc.exists ? streakDoc.data() : {
      current_streak: 0,
      longest_streak: 0,
      last_practice_date: null
    };

    // Calculate derived data
    const thetaByChapter = userData.theta_by_chapter || {};
    const thetaBySubject = userData.theta_by_subject || {};
    const subtopicAccuracy = userData.subtopic_accuracy || {};

    // Pre-load chapter mappings once for efficiency
    let chapterMappings;
    try {
      chapterMappings = await initializeMappings();
    } catch (error) {
      logger.warn('Failed to load chapter mappings', { error: error.message });
      chapterMappings = new Map();
    }

    const chaptersMastered = countMasteredChapters(thetaByChapter);
    const focusAreas = await calculateFocusAreas(thetaByChapter, chapterMappings, subtopicAccuracy);

    // Build subject progress with status labels and accuracy
    const subjectAccuracy = userData.subject_accuracy || {};
    const subjectProgress = {};
    for (const [subject, data] of Object.entries(thetaBySubject)) {
      // Map 'mathematics' to 'maths' for consistent frontend key
      const outputKey = subject === 'mathematics' ? 'maths' : subject;
      // subject_accuracy uses 'mathematics' key internally
      const accuracyKey = subject === 'maths' ? 'mathematics' : subject;
      const accuracyData = subjectAccuracy[accuracyKey] || {};

      subjectProgress[outputKey] = {
        ...data,
        display_name: getSubjectDisplayName(subject),
        status: getMasteryStatus(data.percentile || 0),
        accuracy: accuracyData.accuracy ?? null,
        correct: accuracyData.correct ?? 0,
        total: accuracyData.total ?? 0
      };
    }

    // Generate personalized message
    const priyaMaamMessage = generatePriyaMaamMessage(
      userData,
      streakData,
      subjectProgress,
      focusAreas
    );

    logger.info('Analytics overview generated', {
      userId,
      questionsSolved: userData.total_questions_solved || 0,
      chaptersMastered,
      currentStreak: streakData.current_streak || 0
    });

    return {
      user: {
        first_name: userData.firstName || 'Student',
        last_name: userData.lastName || ''
      },
      stats: {
        questions_solved: userData.total_questions_solved || 0,
        quizzes_completed: userData.completed_quiz_count || 0,
        chapters_mastered: chaptersMastered,
        current_streak: streakData.current_streak || 0,
        longest_streak: streakData.longest_streak || 0
      },
      subject_progress: subjectProgress,
      focus_areas: focusAreas,
      priya_maam_message: priyaMaamMessage,
      generated_at: new Date().toISOString()
    };
  } catch (error) {
    logger.error('Error generating analytics overview', {
      userId,
      error: error.message,
      stack: error.stack
    });
    throw error;
  }
}

// ============================================================================
// MASTERY DETAILS
// ============================================================================

/**
 * Get mastery details for a specific subject
 *
 * @param {string} userId - User ID
 * @param {string} subject - Subject (physics, chemistry, maths)
 * @returns {Promise<Object>} Subject mastery details
 */
async function getSubjectMasteryDetails(userId, subject) {
  try {
    const userRef = db.collection('users').doc(userId);
    const userDoc = await retryFirestoreOperation(async () => {
      return await userRef.get();
    });

    if (!userDoc.exists) {
      throw new Error(`User ${userId} not found`);
    }

    const userData = userDoc.data();
    const thetaByChapter = userData.theta_by_chapter || {};
    const thetaBySubject = userData.theta_by_subject || {};
    const subtopicAccuracy = userData.subtopic_accuracy || {};

    // Normalize subject name
    const normalizedSubject = subject.toLowerCase();
    const subjectPrefix = normalizedSubject === 'mathematics' ? 'maths' : normalizedSubject;

    // Get subject-level data
    const subjectData = thetaBySubject[normalizedSubject] || thetaBySubject[subjectPrefix] || {
      theta: 0,
      percentile: 50,
      chapters_tested: 0
    };

    // Pre-load chapter mappings once for efficiency
    let chapterMappings;
    try {
      chapterMappings = await initializeMappings();
    } catch (error) {
      logger.warn('Failed to load chapter mappings', { error: error.message });
      chapterMappings = new Map();
    }

    // Filter chapters for this subject
    // Note: Chapter keys are stored as "mathematics_*" in database, but UI uses "maths"
    // So we need to check for both "maths_" and "mathematics_" prefixes
    const chapters = [];
    const prefixesToCheck = [];
    if (normalizedSubject === 'maths' || normalizedSubject === 'mathematics') {
      prefixesToCheck.push('maths_', 'mathematics_');
    } else {
      prefixesToCheck.push(subjectPrefix + '_', normalizedSubject + '_');
    }
    
    for (const [chapterKey, data] of Object.entries(thetaByChapter)) {
      const matches = prefixesToCheck.some(prefix => chapterKey.startsWith(prefix));
      if (matches) {
        // Get display name from mappings or fallback
        const mapping = chapterMappings.get(chapterKey);
        const chapterName = mapping?.chapter || formatChapterKeyToDisplayName(chapterKey);

        // Get subtopic data for this chapter
        const chapterSubtopics = subtopicAccuracy[chapterKey] || {};
        const subtopics = Object.entries(chapterSubtopics).map(([name, subtopicData]) => ({
          name,
          correct: subtopicData.correct || 0,
          total: subtopicData.total || 0,
          accuracy: subtopicData.accuracy || 0
        })).sort((a, b) => a.accuracy - b.accuracy); // Sort by accuracy ascending (weakest first)

        // Calculate chapter-level correct/total from subtopics (single source of truth)
        let chapterCorrect = 0;
        let chapterTotal = 0;
        let chapterAccuracy = 0;

        if (subtopics.length > 0) {
          // Calculate accuracy from subtopic data (weighted average)
          const subtopicCorrect = subtopics.reduce((sum, s) => sum + s.correct, 0);
          const subtopicTotal = subtopics.reduce((sum, s) => sum + s.total, 0);
          chapterAccuracy = subtopicTotal > 0 ? Math.round((subtopicCorrect / subtopicTotal) * 100) : 0;

          // Use theta_by_chapter.attempts for actual question count (avoids double-counting
          // when questions cover multiple subtopics)
          chapterTotal = data.attempts || 0;
          chapterCorrect = chapterTotal > 0 ? Math.round((chapterAccuracy / 100) * chapterTotal) : 0;
        } else {
          // Fall back to theta_by_chapter data if no subtopics
          // Normalize: old data might be fraction (0-1), new data is percentage (0-100)
          chapterAccuracy = data.accuracy || 0;
          if (chapterAccuracy > 0 && chapterAccuracy <= 1) {
            chapterAccuracy = Math.round(chapterAccuracy * 100);
          }
          chapterTotal = data.attempts || 0;
          chapterCorrect = chapterTotal > 0 ? Math.round((chapterAccuracy / 100) * chapterTotal) : 0;
        }

        chapters.push({
          chapter_key: chapterKey,
          chapter_name: chapterName,
          percentile: data.percentile || 0,
          theta: data.theta || 0,
          attempts: chapterTotal, // Use subtopic-derived total
          accuracy: chapterAccuracy, // Use subtopic-derived accuracy
          correct: chapterCorrect, // Add correct count for frontend
          total: chapterTotal, // Add total count for frontend
          status: getMasteryStatus(data.percentile || 0),
          last_updated: data.last_updated,
          subtopics: subtopics
        });
      }
    }

    // Sort by percentile descending (strongest first)
    chapters.sort((a, b) => b.percentile - a.percentile);

    return {
      subject: normalizedSubject,
      subject_name: getSubjectDisplayName(subject),
      overall_percentile: subjectData.percentile || 0,
      overall_theta: subjectData.theta || 0,
      status: getMasteryStatus(subjectData.percentile || 0),
      chapters_tested: subjectData.chapters_tested || chapters.filter(c => c.attempts > 0).length,
      chapters: chapters,
      summary: {
        mastered: chapters.filter(c => c.status === 'MASTERED').length,
        growing: chapters.filter(c => c.status === 'GROWING').length,
        focus: chapters.filter(c => c.status === 'FOCUS').length
      }
    };
  } catch (error) {
    logger.error('Error getting subject mastery details', {
      userId,
      subject,
      error: error.message
    });
    throw error;
  }
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  getAnalyticsOverview,
  getSubjectMasteryDetails,
  calculateFocusAreas,
  getMasteryStatus,
  getChapterDisplayName,
  getChapterDisplayNameAsync,
  getSubjectDisplayName,
  generatePriyaMaamMessage,
  countMasteredChapters,
  formatChapterKeyToDisplayName
};
