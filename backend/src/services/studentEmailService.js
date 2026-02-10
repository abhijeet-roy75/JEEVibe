/**
 * Student Email Service
 *
 * Sends daily and weekly progress emails to students using Resend.
 */

const { Resend } = require('resend');
const { db } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const { toIST, formatDateIST, getStartOfDayIST, getEndOfDayIST, getDayOfWeekIST } = require('../utils/dateUtils');
const logger = require('../utils/logger');
const {
  calculateFocusAreas,
  generatePriyaMaamMessage,
  getMasteryStatus,
  getSubjectDisplayName,
  countMasteredChapters
} = require('./analyticsService');
const { initializeMappings } = require('./chapterMappingService');

// Initialize Resend client
const resend = process.env.RESEND_API_KEY ? new Resend(process.env.RESEND_API_KEY) : null;

// Sender email
const FROM_EMAIL = process.env.RESEND_FROM_EMAIL || 'JEEVibe <noreply@jeevibe.com>';

/**
 * Get yesterday's date range in IST (returns UTC timestamps for Firestore queries)
 */
function getYesterdayRange() {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);

  return {
    start: getStartOfDayIST(yesterday),
    end: getEndOfDayIST(yesterday)
  };
}

/**
 * Get last week's date range in IST (Mon-Sun, returns UTC timestamps for Firestore queries)
 */
function getLastWeekRange() {
  const now = new Date();

  // Use IST day of week, not local machine's day of week
  const dayOfWeekIST = getDayOfWeekIST(now); // 0 = Sunday

  // Find last Sunday (end of last week)
  // If today (in IST) is Sunday, go back 7 days; otherwise go back to last Sunday
  const daysToLastSunday = dayOfWeekIST === 0 ? 7 : dayOfWeekIST;
  const lastSunday = new Date(now);
  lastSunday.setDate(lastSunday.getDate() - daysToLastSunday);

  // Find last Monday (start of last week)
  const lastMonday = new Date(lastSunday);
  lastMonday.setDate(lastMonday.getDate() - 6);

  return {
    start: getStartOfDayIST(lastMonday),
    end: getEndOfDayIST(lastSunday)
  };
}

/**
 * Get user's yesterday activity stats
 */
async function getYesterdayStats(userId) {
  const { start, end } = getYesterdayRange();

  // Query responses for yesterday
  const responsesSnapshot = await retryFirestoreOperation(async () => {
    return await db.collectionGroup('responses')
      .where('student_id', '==', userId)
      .where('answered_at', '>=', start)
      .where('answered_at', '<=', end)
      .get();
  });

  let totalQuestions = 0;
  let correctAnswers = 0;
  let totalTimeSeconds = 0;

  responsesSnapshot.docs.forEach(doc => {
    const data = doc.data();
    totalQuestions++;
    if (data.is_correct) correctAnswers++;
    totalTimeSeconds += data.time_taken_seconds || 0;
  });

  const accuracy = totalQuestions > 0 ? Math.round((correctAnswers / totalQuestions) * 100) : 0;
  const timeMinutes = Math.round(totalTimeSeconds / 60);

  return {
    questions: totalQuestions,
    correct: correctAnswers,
    accuracy,
    timeMinutes
  };
}

/**
 * Get user's weekly activity stats
 */
async function getWeeklyStats(userId) {
  const { start, end } = getLastWeekRange();

  // Query responses for last week
  const responsesSnapshot = await retryFirestoreOperation(async () => {
    return await db.collectionGroup('responses')
      .where('student_id', '==', userId)
      .where('answered_at', '>=', start)
      .where('answered_at', '<=', end)
      .get();
  });

  let totalQuestions = 0;
  let correctAnswers = 0;
  let totalTimeSeconds = 0;
  const dailyQuestions = {};

  responsesSnapshot.docs.forEach(doc => {
    const data = doc.data();
    totalQuestions++;
    if (data.is_correct) correctAnswers++;
    totalTimeSeconds += data.time_taken_seconds || 0;

    // Track daily questions for activity chart
    const day = formatDateIST(toIST(data.answered_at.toDate()));
    dailyQuestions[day] = (dailyQuestions[day] || 0) + 1;
  });

  const accuracy = totalQuestions > 0 ? Math.round((correctAnswers / totalQuestions) * 100) : 0;
  const totalHours = Math.floor(totalTimeSeconds / 3600);
  const remainingMinutes = Math.round((totalTimeSeconds % 3600) / 60);
  const activeDays = Object.keys(dailyQuestions).length;

  return {
    questions: totalQuestions,
    correct: correctAnswers,
    accuracy,
    totalHours,
    totalMinutes: remainingMinutes,
    activeDays,
    dailyQuestions
  };
}

/**
 * Generate daily email content
 */
async function generateDailyEmailContent(userId, userData, streakData) {
  const yesterdayStats = await getYesterdayStats(userId);
  const hadActivity = yesterdayStats.questions > 0;

  const thetaByChapter = userData.theta_by_chapter || {};
  const thetaBySubject = userData.theta_by_subject || {};

  // Get focus areas
  const chapterMappings = await initializeMappings();
  const focusAreas = await calculateFocusAreas(thetaByChapter, chapterMappings);
  const topFocus = focusAreas[0];

  // Build subject progress
  const subjectProgress = {};
  for (const [subject, data] of Object.entries(thetaBySubject)) {
    const outputKey = subject === 'mathematics' ? 'maths' : subject;
    subjectProgress[outputKey] = {
      ...data,
      display_name: getSubjectDisplayName(subject),
      status: getMasteryStatus(data.percentile || 0)
    };
  }

  // Generate Priya Ma'am message
  const priyaMaamMessage = generatePriyaMaamMessage(userData, streakData, subjectProgress, focusAreas);

  const currentStreak = streakData.current_streak || 0;
  const firstName = userData.firstName || 'Student';

  // Streak message
  let streakEmoji = '';
  if (currentStreak >= 30) streakEmoji = '🏆';
  else if (currentStreak >= 14) streakEmoji = '🌟';
  else if (currentStreak >= 7) streakEmoji = '🔥';
  else if (currentStreak > 0) streakEmoji = '✨';

  // Different subject based on activity
  const subject = hadActivity
    ? `Day ${currentStreak} ${streakEmoji} | ${yesterdayStats.questions} questions | ${yesterdayStats.accuracy}% | Focus: ${topFocus?.chapter_name || 'Practice more!'}`
    : `${firstName}, we missed you yesterday! 📚 Focus today: ${topFocus?.chapter_name || 'Start practicing!'}`;

  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Your JEE Prep Snapshot</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5;">
  <div style="max-width: 600px; margin: 0 auto; background: #ffffff;">
    <!-- Header -->
    <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 24px; text-align: center;">
      <h1 style="color: #ffffff; margin: 0; font-size: 24px;">Your JEE Prep Snapshot</h1>
      <p style="color: rgba(255,255,255,0.9); margin: 8px 0 0 0; font-size: 14px;">${formatDateIST(toIST(new Date()))}</p>
    </div>

    <!-- Greeting -->
    <div style="padding: 24px;">
      <p style="font-size: 16px; color: #333; margin: 0 0 16px 0;">Hi ${firstName},</p>

      <!-- Yesterday's Stats or Come Back Message -->
      ${hadActivity ? `
      <div style="background: #f8f9fa; border-radius: 12px; padding: 20px; margin-bottom: 20px;">
        <h2 style="font-size: 14px; color: #666; margin: 0 0 16px 0; text-transform: uppercase; letter-spacing: 1px;">Yesterday's Activity</h2>
        <div style="display: flex; justify-content: space-around; text-align: center;">
          <div style="flex: 1;">
            <div style="font-size: 32px; font-weight: bold; color: #667eea;">${yesterdayStats.questions}</div>
            <div style="font-size: 12px; color: #888;">Questions</div>
          </div>
          <div style="flex: 1;">
            <div style="font-size: 32px; font-weight: bold; color: ${yesterdayStats.accuracy >= 70 ? '#22c55e' : yesterdayStats.accuracy >= 50 ? '#eab308' : '#ef4444'};">${yesterdayStats.accuracy}%</div>
            <div style="font-size: 12px; color: #888;">Accuracy</div>
          </div>
          <div style="flex: 1;">
            <div style="font-size: 32px; font-weight: bold; color: #667eea;">${yesterdayStats.timeMinutes}</div>
            <div style="font-size: 12px; color: #888;">Minutes</div>
          </div>
        </div>
      </div>
      ` : `
      <div style="background: #fff3e0; border-radius: 12px; padding: 20px; margin-bottom: 20px; border-left: 4px solid #ff9800;">
        <h2 style="font-size: 14px; color: #e65100; margin: 0 0 12px 0; text-transform: uppercase; letter-spacing: 1px;">We Missed You!</h2>
        <p style="font-size: 15px; color: #bf360c; margin: 0; line-height: 1.5;">You didn't practice yesterday. Even 10 minutes of daily practice can make a huge difference in your JEE prep. Come back today!</p>
      </div>
      `}

      <!-- Streak -->
      ${currentStreak > 0 ? `
      <div style="background: linear-gradient(135deg, #fef3cd 0%, #fff3cd 100%); border-radius: 12px; padding: 16px; margin-bottom: 20px; border-left: 4px solid #ffc107;">
        <div style="display: flex; align-items: center; gap: 12px;">
          <span style="font-size: 32px;">${streakEmoji || '🔥'}</span>
          <div>
            <div style="font-size: 18px; font-weight: bold; color: #856404;">${currentStreak}-Day Streak!</div>
            <div style="font-size: 13px; color: #856404;">Keep it going!</div>
          </div>
        </div>
      </div>
      ` : ''}

      <!-- Focus Area -->
      ${topFocus ? `
      <div style="background: #e8f5e9; border-radius: 12px; padding: 16px; margin-bottom: 20px; border-left: 4px solid #4caf50;">
        <h3 style="font-size: 14px; color: #2e7d32; margin: 0 0 8px 0;">📍 Today's Focus</h3>
        <div style="font-size: 18px; font-weight: 600; color: #1b5e20;">${topFocus.chapter_name}</div>
        <div style="font-size: 13px; color: #388e3c;">${topFocus.subject_name} • ${Math.round(topFocus.percentile)}th percentile</div>
      </div>
      ` : ''}

      <!-- Priya Ma'am Message -->
      <div style="background: #fff3e0; border-radius: 12px; padding: 16px; margin-bottom: 20px;">
        <div style="display: flex; align-items: flex-start; gap: 12px;">
          <span style="font-size: 24px;">👩‍🏫</span>
          <div>
            <div style="font-size: 13px; font-weight: 600; color: #e65100; margin-bottom: 4px;">Priya Ma'am says:</div>
            <div style="font-size: 14px; color: #bf360c; line-height: 1.5;">${priyaMaamMessage}</div>
          </div>
        </div>
      </div>

      <!-- CTA -->
      <div style="text-align: center; margin-top: 24px;">
        <a href="https://jeevibe.com" style="display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: #ffffff; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-weight: 600; font-size: 16px;">Continue Practicing</a>
      </div>
    </div>

    <!-- Footer -->
    <div style="background: #f8f9fa; padding: 20px; text-align: center; border-top: 1px solid #eee;">
      <p style="font-size: 12px; color: #888; margin: 0;">JEEVibe - Your AI-Powered JEE Prep Companion</p>
    </div>
  </div>
</body>
</html>
  `.trim();

  const text = hadActivity ? `
Your JEE Prep Snapshot - ${formatDateIST(toIST(new Date()))}

Hi ${firstName},

Yesterday's Activity:
- Questions: ${yesterdayStats.questions}
- Accuracy: ${yesterdayStats.accuracy}%
- Time: ${yesterdayStats.timeMinutes} minutes

${currentStreak > 0 ? `🔥 ${currentStreak}-Day Streak! Keep it going!\n` : ''}
${topFocus ? `📍 Today's Focus: ${topFocus.chapter_name} (${topFocus.subject_name})\n` : ''}

Priya Ma'am says: ${priyaMaamMessage}

Keep practicing at https://jeevibe.com
  `.trim() : `
We Missed You! - ${formatDateIST(toIST(new Date()))}

Hi ${firstName},

You didn't practice yesterday. Even 10 minutes of daily practice can make a huge difference in your JEE prep!

${topFocus ? `📍 Today's Focus: ${topFocus.chapter_name} (${topFocus.subject_name})\n` : ''}

Priya Ma'am says: ${priyaMaamMessage}

Come back and practice at https://jeevibe.com
  `.trim();

  return { subject, html, text };
}

/**
 * Generate weekly email content
 */
async function generateWeeklyEmailContent(userId, userData, streakData) {
  const weeklyStats = await getWeeklyStats(userId);
  const hadActivity = weeklyStats.questions > 0;

  const thetaByChapter = userData.theta_by_chapter || {};
  const thetaBySubject = userData.theta_by_subject || {};
  const assessmentBaseline = userData.assessment_baseline || {};

  // Get focus areas
  const chapterMappings = await initializeMappings();
  const focusAreas = await calculateFocusAreas(thetaByChapter, chapterMappings);

  // Build subject progress with changes
  const subjects = ['physics', 'chemistry', 'mathematics'];
  const subjectProgress = [];

  for (const subject of subjects) {
    const data = thetaBySubject[subject] || {};
    const baseline = assessmentBaseline.theta_by_subject?.[subject] || {};
    const outputKey = subject === 'mathematics' ? 'maths' : subject;

    const currentPercentile = data.percentile || 0;
    const baselinePercentile = baseline.percentile || 0;
    const change = currentPercentile - baselinePercentile;

    subjectProgress.push({
      subject: outputKey,
      displayName: getSubjectDisplayName(subject),
      percentile: currentPercentile,
      change: change,
      status: getMasteryStatus(currentPercentile)
    });
  }

  // Generate Priya Ma'am message
  const subjectProgressForMessage = {};
  for (const [subject, data] of Object.entries(thetaBySubject)) {
    const outputKey = subject === 'mathematics' ? 'maths' : subject;
    subjectProgressForMessage[outputKey] = {
      ...data,
      display_name: getSubjectDisplayName(subject),
      status: getMasteryStatus(data.percentile || 0)
    };
  }
  const priyaMaamMessage = generatePriyaMaamMessage(userData, streakData, subjectProgressForMessage, focusAreas);

  const firstName = userData.firstName || 'Student';
  const currentStreak = streakData.current_streak || 0;
  const longestStreak = streakData.longest_streak || 0;
  const overallPercentile = userData.overall_percentile || 0;
  const baselinePercentile = assessmentBaseline.overall_percentile || 0;
  const totalQuestionsSolved = userData.total_questions_solved || 0;
  const chaptersMastered = countMasteredChapters(thetaByChapter);

  // Calculate week number since signup
  const createdAt = userData.createdAt?.toDate?.() || new Date();
  const weeksSinceSignup = Math.ceil((new Date() - createdAt) / (7 * 24 * 60 * 60 * 1000));

  // Different subject based on activity
  const subject = hadActivity
    ? `Week ${weeksSinceSignup} Report | ${weeklyStats.questions} questions | ${overallPercentile}th percentile`
    : `${firstName}, we missed you this week! 📚 Let's get back on track`;

  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Your Week in Review</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5;">
  <div style="max-width: 600px; margin: 0 auto; background: #ffffff;">
    <!-- Header -->
    <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 24px; text-align: center;">
      <h1 style="color: #ffffff; margin: 0; font-size: 24px;">Your Week in Review</h1>
      <p style="color: rgba(255,255,255,0.9); margin: 8px 0 0 0; font-size: 14px;">Week ${weeksSinceSignup}</p>
    </div>

    <div style="padding: 24px;">
      <p style="font-size: 16px; color: #333; margin: 0 0 24px 0;">Hi ${firstName},</p>

      <!-- Weekly Summary or Come Back Message -->
      ${hadActivity ? `
      <div style="background: #f8f9fa; border-radius: 12px; padding: 20px; margin-bottom: 20px;">
        <h2 style="font-size: 14px; color: #666; margin: 0 0 16px 0; text-transform: uppercase; letter-spacing: 1px;">Weekly Summary</h2>
        <table style="width: 100%; border-collapse: collapse;">
          <tr>
            <td style="padding: 8px 0; border-bottom: 1px solid #eee;">
              <span style="color: #666;">Questions Solved</span>
            </td>
            <td style="padding: 8px 0; border-bottom: 1px solid #eee; text-align: right; font-weight: 600; color: #333;">
              ${weeklyStats.questions}
            </td>
          </tr>
          <tr>
            <td style="padding: 8px 0; border-bottom: 1px solid #eee;">
              <span style="color: #666;">Time Invested</span>
            </td>
            <td style="padding: 8px 0; border-bottom: 1px solid #eee; text-align: right; font-weight: 600; color: #333;">
              ${weeklyStats.totalHours}h ${weeklyStats.totalMinutes}m
            </td>
          </tr>
          <tr>
            <td style="padding: 8px 0; border-bottom: 1px solid #eee;">
              <span style="color: #666;">Accuracy</span>
            </td>
            <td style="padding: 8px 0; border-bottom: 1px solid #eee; text-align: right; font-weight: 600; color: ${weeklyStats.accuracy >= 70 ? '#22c55e' : weeklyStats.accuracy >= 50 ? '#eab308' : '#ef4444'};">
              ${weeklyStats.accuracy}%
            </td>
          </tr>
          <tr>
            <td style="padding: 8px 0;">
              <span style="color: #666;">Active Days</span>
            </td>
            <td style="padding: 8px 0; text-align: right; font-weight: 600; color: #333;">
              ${weeklyStats.activeDays}/7
            </td>
          </tr>
        </table>
      </div>
      ` : `
      <div style="background: #fff3e0; border-radius: 12px; padding: 20px; margin-bottom: 20px; border-left: 4px solid #ff9800;">
        <h2 style="font-size: 14px; color: #e65100; margin: 0 0 12px 0; text-transform: uppercase; letter-spacing: 1px;">We Missed You This Week!</h2>
        <p style="font-size: 15px; color: #bf360c; margin: 0; line-height: 1.5;">You didn't practice at all this week. Consistency is key to JEE success - even 15 minutes a day adds up to over 90 hours by exam time!</p>
      </div>
      `}

      <!-- Subject Progress -->
      <div style="margin-bottom: 20px;">
        <h2 style="font-size: 14px; color: #666; margin: 0 0 16px 0; text-transform: uppercase; letter-spacing: 1px;">Subject Progress</h2>
        ${subjectProgress.map(s => `
        <div style="background: #f8f9fa; border-radius: 8px; padding: 12px 16px; margin-bottom: 8px; display: flex; justify-content: space-between; align-items: center;">
          <div>
            <span style="font-weight: 600; color: #333;">${s.displayName}</span>
          </div>
          <div style="text-align: right;">
            <span style="font-size: 18px; font-weight: bold; color: #667eea;">${Math.round(s.percentile)}%</span>
            ${s.change !== 0 ? `<span style="font-size: 12px; color: ${s.change > 0 ? '#22c55e' : '#ef4444'}; margin-left: 8px;">${s.change > 0 ? '↑' : '↓'}${Math.abs(s.change).toFixed(2)}</span>` : ''}
          </div>
        </div>
        `).join('')}
      </div>

      <!-- Focus Areas -->
      ${focusAreas.length > 0 ? `
      <div style="margin-bottom: 20px;">
        <h2 style="font-size: 14px; color: #666; margin: 0 0 16px 0; text-transform: uppercase; letter-spacing: 1px;">Focus Areas This Week</h2>
        ${focusAreas.slice(0, 3).map(f => `
        <div style="background: #fff3e0; border-radius: 8px; padding: 12px 16px; margin-bottom: 8px; border-left: 4px solid #ff9800;">
          <div style="font-weight: 600; color: #e65100;">${f.chapter_name}</div>
          <div style="font-size: 12px; color: #bf360c;">${f.subject_name} • ${Math.round(f.percentile)}th percentile</div>
        </div>
        `).join('')}
      </div>
      ` : ''}

      <!-- Since You Started -->
      <div style="background: linear-gradient(135deg, #e8f5e9 0%, #c8e6c9 100%); border-radius: 12px; padding: 20px; margin-bottom: 20px;">
        <h2 style="font-size: 14px; color: #2e7d32; margin: 0 0 16px 0; text-transform: uppercase; letter-spacing: 1px;">Since You Started</h2>
        <div style="display: flex; justify-content: space-around; text-align: center;">
          <div>
            <div style="font-size: 24px; font-weight: bold; color: #1b5e20;">${Math.round(baselinePercentile)}% → ${Math.round(overallPercentile)}%</div>
            <div style="font-size: 12px; color: #388e3c;">Percentile Growth</div>
          </div>
        </div>
        <div style="display: flex; justify-content: space-around; text-align: center; margin-top: 16px;">
          <div>
            <div style="font-size: 20px; font-weight: bold; color: #1b5e20;">${totalQuestionsSolved}</div>
            <div style="font-size: 12px; color: #388e3c;">Total Questions</div>
          </div>
          <div>
            <div style="font-size: 20px; font-weight: bold; color: #1b5e20;">${chaptersMastered}</div>
            <div style="font-size: 12px; color: #388e3c;">Chapters Mastered</div>
          </div>
          <div>
            <div style="font-size: 20px; font-weight: bold; color: #1b5e20;">${longestStreak}</div>
            <div style="font-size: 12px; color: #388e3c;">Best Streak</div>
          </div>
        </div>
      </div>

      <!-- Priya Ma'am Message -->
      <div style="background: #fff3e0; border-radius: 12px; padding: 16px; margin-bottom: 20px;">
        <div style="display: flex; align-items: flex-start; gap: 12px;">
          <span style="font-size: 24px;">👩‍🏫</span>
          <div>
            <div style="font-size: 13px; font-weight: 600; color: #e65100; margin-bottom: 4px;">Priya Ma'am says:</div>
            <div style="font-size: 14px; color: #bf360c; line-height: 1.5;">${priyaMaamMessage}</div>
          </div>
        </div>
      </div>

      <!-- CTA -->
      <div style="text-align: center; margin-top: 24px;">
        <a href="https://jeevibe.com" style="display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: #ffffff; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-weight: 600; font-size: 16px;">Keep Practicing</a>
      </div>
    </div>

    <!-- Footer -->
    <div style="background: #f8f9fa; padding: 20px; text-align: center; border-top: 1px solid #eee;">
      <p style="font-size: 12px; color: #888; margin: 0;">JEEVibe - Your AI-Powered JEE Prep Companion</p>
    </div>
  </div>
</body>
</html>
  `.trim();

  const text = hadActivity ? `
Your Week in Review - Week ${weeksSinceSignup}

Hi ${firstName},

WEEKLY SUMMARY
Questions: ${weeklyStats.questions} | Time: ${weeklyStats.totalHours}h ${weeklyStats.totalMinutes}m | Accuracy: ${weeklyStats.accuracy}%
Active Days: ${weeklyStats.activeDays}/7

SUBJECT PROGRESS
${subjectProgress.map(s => `${s.displayName}: ${Math.round(s.percentile)}% ${s.change !== 0 ? `(${s.change > 0 ? '+' : ''}${s.change.toFixed(2)})` : ''}`).join('\n')}

${focusAreas.length > 0 ? `FOCUS AREAS\n${focusAreas.slice(0, 3).map(f => `- ${f.chapter_name} (${f.subject_name})`).join('\n')}\n` : ''}

SINCE YOU STARTED
Overall progress: ${Math.round(baselinePercentile)}% → ${Math.round(overallPercentile)}%
Total questions: ${totalQuestionsSolved}
Chapters mastered: ${chaptersMastered}
Best streak: ${longestStreak} days

Priya Ma'am says: ${priyaMaamMessage}

Keep practicing at https://jeevibe.com
  `.trim() : `
We Missed You This Week! - Week ${weeksSinceSignup}

Hi ${firstName},

You didn't practice at all this week. Consistency is key to JEE success - even 15 minutes a day adds up to over 90 hours by exam time!

${focusAreas.length > 0 ? `SUGGESTED FOCUS AREAS\n${focusAreas.slice(0, 3).map(f => `- ${f.chapter_name} (${f.subject_name})`).join('\n')}\n` : ''}

YOUR PROGRESS SO FAR
Overall percentile: ${Math.round(overallPercentile)}%
Total questions: ${totalQuestionsSolved}
Chapters mastered: ${chaptersMastered}

Priya Ma'am says: ${priyaMaamMessage}

Come back and practice at https://jeevibe.com
  `.trim();

  return { subject, html, text };
}

/**
 * Send daily email to a specific user
 */
async function sendDailyEmail(userId) {
  if (!resend) {
    logger.debug('Email disabled - RESEND_API_KEY not configured');
    return { sent: false, reason: 'RESEND_API_KEY not configured' };
  }

  try {
    // Get user data
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return { sent: false, reason: 'User not found' };
    }

    const userData = userDoc.data();
    const email = userData.email;

    if (!email) {
      return { sent: false, reason: 'No email address' };
    }

    // Check email preference (default to true)
    if (userData.email_preferences?.daily_digest === false) {
      return { sent: false, reason: 'User opted out' };
    }

    // Get streak data
    const streakDoc = await db.collection('practice_streaks').doc(userId).get();
    const streakData = streakDoc.exists ? streakDoc.data() : { current_streak: 0, longest_streak: 0 };

    // Generate email content
    const emailContent = await generateDailyEmailContent(userId, userData, streakData);

    if (!emailContent) {
      return { sent: false, reason: 'No activity yesterday' };
    }

    // Send email
    const { data, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: email,
      subject: emailContent.subject,
      html: emailContent.html,
      text: emailContent.text
    });

    if (error) {
      logger.error('Failed to send daily email', { userId, error: error.message });
      return { sent: false, reason: error.message };
    }

    logger.info('Daily email sent', { userId, emailId: data?.id });
    return { sent: true, emailId: data?.id };

  } catch (error) {
    logger.error('Error sending daily email', { userId, error: error.message });
    return { sent: false, reason: error.message };
  }
}

/**
 * Send weekly email to a specific user
 */
async function sendWeeklyEmail(userId) {
  if (!resend) {
    logger.debug('Email disabled - RESEND_API_KEY not configured');
    return { sent: false, reason: 'RESEND_API_KEY not configured' };
  }

  try {
    // Get user data
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return { sent: false, reason: 'User not found' };
    }

    const userData = userDoc.data();
    const email = userData.email;

    if (!email) {
      return { sent: false, reason: 'No email address' };
    }

    // Check email preference (default to true)
    if (userData.email_preferences?.weekly_digest === false) {
      return { sent: false, reason: 'User opted out' };
    }

    // Get streak data
    const streakDoc = await db.collection('practice_streaks').doc(userId).get();
    const streakData = streakDoc.exists ? streakDoc.data() : { current_streak: 0, longest_streak: 0 };

    // Generate email content
    const emailContent = await generateWeeklyEmailContent(userId, userData, streakData);

    if (!emailContent) {
      return { sent: false, reason: 'No activity this week' };
    }

    // Send email
    const { data, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: email,
      subject: emailContent.subject,
      html: emailContent.html,
      text: emailContent.text
    });

    if (error) {
      logger.error('Failed to send weekly email', { userId, error: error.message });
      return { sent: false, reason: error.message };
    }

    logger.info('Weekly email sent', { userId, emailId: data?.id });
    return { sent: true, emailId: data?.id };

  } catch (error) {
    logger.error('Error sending weekly email', { userId, error: error.message });
    return { sent: false, reason: error.message };
  }
}

/**
 * Send daily emails to all active users
 */
async function sendAllDailyEmails() {
  const results = { sent: 0, skipped: 0, failed: 0, errors: [] };

  try {
    // Get all users (limit for now, paginate later if needed)
    const usersSnapshot = await db.collection('users').limit(1000).get();

    for (const doc of usersSnapshot.docs) {
      const result = await sendDailyEmail(doc.id);

      if (result.sent) {
        results.sent++;
        logger.info('Daily email sent to user', { userId: doc.id, emailId: result.emailId });
      } else if (result.reason === 'User opted out' || result.reason === 'No email address') {
        results.skipped++;
        logger.debug('Daily email skipped', { userId: doc.id, reason: result.reason });
      } else {
        results.failed++;
        results.errors.push({ userId: doc.id, reason: result.reason });
        logger.warn('Daily email failed', { userId: doc.id, reason: result.reason });
      }
    }

    logger.info('Daily emails batch complete', results);
    return results;

  } catch (error) {
    logger.error('Error in daily email batch', { error: error.message });
    throw error;
  }
}

/**
 * Send weekly emails to all active users
 */
async function sendAllWeeklyEmails() {
  const results = { sent: 0, skipped: 0, failed: 0, errors: [] };

  try {
    // Get all users
    const usersSnapshot = await db.collection('users').limit(1000).get();

    for (const doc of usersSnapshot.docs) {
      const result = await sendWeeklyEmail(doc.id);

      if (result.sent) {
        results.sent++;
        logger.info('Weekly email sent to user', { userId: doc.id, emailId: result.emailId });
      } else if (result.reason === 'User opted out' || result.reason === 'No email address') {
        results.skipped++;
        logger.debug('Weekly email skipped', { userId: doc.id, reason: result.reason });
      } else {
        results.failed++;
        results.errors.push({ userId: doc.id, reason: result.reason });
        logger.warn('Weekly email failed', { userId: doc.id, reason: result.reason });
      }
    }

    logger.info('Weekly emails batch complete', results);
    return results;

  } catch (error) {
    logger.error('Error in weekly email batch', { error: error.message });
    throw error;
  }
}

// ============================================================================
// TRIAL EMAILS
// ============================================================================

/**
 * Send trial notification email to user
 *
 * @param {string} userId - User ID
 * @param {Object} userData - User data
 * @param {number} daysRemaining - Days remaining in trial
 * @returns {Promise<Object>} { success, emailId, reason }
 */
async function sendTrialEmail(userId, userData, daysRemaining) {
  try {
    // Check if Resend is configured
    if (!resend) {
      logger.warn('Resend not configured, skipping trial email', { userId });
      return { success: false, reason: 'Resend not configured' };
    }

    // Check if user has email
    if (!userData.email) {
      return { success: false, reason: 'No email address' };
    }

    // Check if user opted out of emails
    if (userData.emailPreferences?.dailyProgress === false) {
      return { success: false, reason: 'User opted out' };
    }

    // Generate email content
    const emailContent = await generateTrialEmailContent(userId, userData, daysRemaining);

    // Send email via Resend
    const { data, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: userData.email,
      subject: emailContent.subject,
      html: emailContent.html,
      text: emailContent.text
    });

    if (error) {
      logger.error('Failed to send trial email', {
        userId,
        email: userData.email,
        error: error.message
      });
      return { success: false, reason: error.message };
    }

    logger.info('Trial email sent successfully', {
      userId,
      days_remaining: daysRemaining,
      email_id: data?.id
    });

    return { success: true, emailId: data?.id };
  } catch (error) {
    logger.error('Error sending trial email', {
      userId,
      error: error.message
    });
    return { success: false, reason: error.message };
  }
}

/**
 * Generate trial email content based on days remaining
 *
 * @param {string} userId - User ID
 * @param {Object} userData - User data
 * @param {number} daysRemaining - Days remaining in trial
 * @returns {Promise<Object>} { subject, html, text }
 */
async function generateTrialEmailContent(userId, userData, daysRemaining) {
  // Use firstName from user profile, fallback to email prefix or 'Student'
  const firstName = userData.firstName ||
                    (userData.email ? userData.email.split('@')[0] : null) ||
                    'Student';

  // Email templates based on days remaining
  const templates = {
    23: {
      subject: `🎯 Week 1 Complete - Keep Going, ${firstName}!`,
      emoji: '🎯',
      headline: 'Week 1 Complete - Keep Going!',
      message: `You're doing great! You have <strong>23 days left</strong> in your Pro trial.`,
      cta: 'Continue Learning',
      ctaUrl: `https://app.jeevibe.com`,
      tips: [
        'Daily quizzes help reinforce concepts',
        'Use Snap & Solve for quick doubt clearing',
        'Practice makes perfect - solve more questions!'
      ]
    },
    5: {
      subject: `⏰ Only 5 Days Left in Your Pro Trial, ${firstName}`,
      emoji: '⏰',
      headline: 'Only 5 Days Left in Your Pro Trial',
      message: `Don't lose access to your Pro features! You have <strong>5 days</strong> remaining. Upgrade now for just <strong>₹199/month</strong>.`,
      cta: 'Upgrade to Pro',
      ctaUrl: `https://app.jeevibe.com/upgrade`,
      features: [
        '10 daily Snap & Solve',
        '10 daily quiz questions',
        'Offline mode',
        '5 mock tests per month',
        '30-day solution history'
      ]
    },
    2: {
      subject: `⚠️ Trial Ending in 2 Days - Act Now, ${firstName}!`,
      emoji: '⚠️',
      headline: 'Trial Ending in 2 Days!',
      message: `Last chance to keep your Pro features! Your trial ends in <strong>2 days</strong>. Upgrade now for just <strong>₹199/month</strong>.`,
      cta: 'Upgrade Now',
      ctaUrl: `https://app.jeevibe.com/upgrade`,
      urgency: 'Don\'t lose your 10 daily snaps, offline access, and 5 monthly mock tests!',
      features: [
        '10 daily Snap & Solve',
        '10 daily quiz questions',
        'Offline mode',
        '5 mock tests per month'
      ]
    },
    0: {
      subject: `Your Trial Has Ended - Special Offer Inside, ${firstName} 🎁`,
      emoji: '🎁',
      headline: 'Your Trial Has Ended',
      message: `Your Pro trial has ended. But don't worry - we have a <strong>special offer</strong> just for you!`,
      cta: 'Claim Your Discount',
      ctaUrl: `https://app.jeevibe.com/upgrade?code=TRIAL2PRO`,
      discount: {
        code: 'TRIAL2PRO',
        percent: 20,
        validDays: 7
      },
      message2: 'Get <strong>20% off</strong> with code <strong>TRIAL2PRO</strong> (valid for 7 days)'
    }
  };

  const template = templates[daysRemaining] || templates[0];

  // Generate HTML email
  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f4f4f4; }
    .container { max-width: 600px; margin: 20px auto; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; }
    .emoji { font-size: 48px; margin-bottom: 10px; }
    .headline { font-size: 24px; font-weight: bold; margin: 0; }
    .content { padding: 30px; }
    .message { font-size: 16px; margin-bottom: 20px; }
    .features { background: #f8f9fa; border-radius: 8px; padding: 20px; margin: 20px 0; }
    .features ul { margin: 10px 0; padding-left: 20px; }
    .features li { margin: 8px 0; }
    .cta-button { display: inline-block; background: #667eea; color: white; padding: 14px 28px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 20px 0; }
    .cta-button:hover { background: #5568d3; }
    .discount-box { background: #fff3cd; border: 2px solid #ffc107; border-radius: 8px; padding: 20px; margin: 20px 0; text-align: center; }
    .discount-code { font-size: 24px; font-weight: bold; color: #856404; letter-spacing: 2px; margin: 10px 0; }
    .urgency { background: #fff3e0; border-left: 4px solid #ff9800; padding: 15px; margin: 20px 0; }
    .footer { background: #f8f9fa; padding: 20px; text-align: center; font-size: 14px; color: #666; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="emoji">${template.emoji}</div>
      <h1 class="headline">${template.headline}</h1>
    </div>

    <div class="content">
      <p>Hi ${firstName},</p>
      <div class="message">${template.message}</div>

      ${template.urgency ? `<div class="urgency">${template.urgency}</div>` : ''}

      ${template.features ? `
        <div class="features">
          <strong>Pro Features:</strong>
          <ul>
            ${template.features.map(f => `<li>${f}</li>`).join('')}
          </ul>
        </div>
      ` : ''}

      ${template.tips ? `
        <div class="features">
          <strong>Tips for Success:</strong>
          <ul>
            ${template.tips.map(t => `<li>${t}</li>`).join('')}
          </ul>
        </div>
      ` : ''}

      ${template.discount ? `
        <div class="discount-box">
          <strong>🎁 Special Offer</strong>
          <div class="discount-code">${template.discount.code}</div>
          <p>Get ${template.discount.percent}% off - Valid for ${template.discount.validDays} days</p>
        </div>
      ` : ''}

      ${template.message2 ? `<div class="message">${template.message2}</div>` : ''}

      <center>
        <a href="${template.ctaUrl}" class="cta-button">${template.cta}</a>
      </center>

      <p style="margin-top: 30px;">Keep up the great work! We're rooting for you.</p>
      <p>Team JEEVibe</p>
    </div>

    <div class="footer">
      <p>You're receiving this email because you're using JEEVibe.</p>
      <p><a href="https://jeevibe.com">Visit Website</a> | <a href="https://app.jeevibe.com/settings">Manage Preferences</a></p>
    </div>
  </div>
</body>
</html>
  `;

  // Generate plain text version
  const text = `
Hi ${firstName},

${template.headline}

${template.message.replace(/<[^>]*>/g, '')}

${template.features ? `Pro Features:\n${template.features.map(f => `- ${f}`).join('\n')}` : ''}

${template.tips ? `Tips for Success:\n${template.tips.map(t => `- ${t}`).join('\n')}` : ''}

${template.discount ? `Special Offer: Get ${template.discount.percent}% off with code ${template.discount.code} (valid for ${template.discount.validDays} days)` : ''}

${template.cta}: ${template.ctaUrl}

Keep up the great work! We're rooting for you.

Team JEEVibe
  `;

  return {
    subject: template.subject,
    html: html.trim(),
    text: text.trim()
  };
}

/**
 * Generate Weekly MPA Email Content
 * Based on: /docs/11-reports/JEEVibe_Weekly_MPA_Report_Specification.md
 */
async function generateWeeklyMPAEmailContent(userData, report) {
  const firstName = userData.firstName || 'Student';
  const { summary, wins, top_issues, potential_improvement, tone } = report;

  // Format date range
  const dateRange = `${report.week_start} to ${report.week_end}`;

  // Subject line
  const subject = `Your JEEVibe Weekly Report - ${dateRange}`;

  // Build HTML
  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>JEEVibe Weekly Report</title>
  <style>
    body { margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5; }
    .container { max-width: 600px; margin: 0 auto; background: #ffffff; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 24px; text-align: center; color: #ffffff; }
    .section { padding: 24px; border-bottom: 1px solid #eee; }
    .section-title { font-size: 16px; font-weight: 700; color: #9333EA; margin: 0 0 16px 0; text-transform: uppercase; letter-spacing: 1px; }
    .win-card { background: #f0fdf4; border-radius: 8px; padding: 16px; margin-bottom: 16px; border-left: 4px solid #22c55e; }
    .issue-card { background: #fef3c7; border-radius: 8px; padding: 16px; margin-bottom: 20px; border-left: 4px solid #f59e0b; }
    .priority-badge { display: inline-block; background: #9333EA; color: white; padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: 600; margin-right: 8px; }
    .stat-row { display: flex; justify-content: space-between; margin: 8px 0; }
    .cta-button { display: inline-block; background: linear-gradient(135deg, #9333EA 0%, #EC4899 100%); color: #ffffff; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 8px; }
    .progress-bar { height: 8px; background: #e5e7eb; border-radius: 4px; overflow: hidden; margin: 8px 0; }
    .progress-fill { height: 100%; background: linear-gradient(90deg, #9333EA 0%, #EC4899 100%); }
  </style>
</head>
<body>
  <div class="container">
    <!-- Header -->
    <div class="header">
      <h1 style="margin: 0; font-size: 24px;">━━━ JEEVIBE WEEKLY REPORT ━━━</h1>
      <p style="margin: 8px 0 0 0; font-size: 14px; opacity: 0.9;">Week of ${dateRange}</p>
    </div>

    <!-- Greeting -->
    <div class="section">
      <p style="font-size: 16px; color: #333; margin: 0 0 16px 0;">👩‍🏫 Hi ${firstName},</p>
      <p style="font-size: 15px; color: #666; margin: 0;">${tone.greeting} You completed ${summary.total_questions} questions and I found some clear wins and areas to focus on.</p>
      <p style="font-size: 15px; color: #666; margin: 8px 0 0 0;">Let me show you what's working and where to improve.</p>
      <p style="font-size: 14px; color: #888; margin: 16px 0 0 0; font-style: italic;">- Priya Ma'am</p>
    </div>

    <!-- Wins Section -->
    <div class="section">
      <div class="section-title">🎉 YOUR WINS THIS WEEK</div>
      ${wins.map(win => `
        <div class="win-card">
          <div style="font-size: 16px; font-weight: 600; color: #15803d; margin-bottom: 8px;">${win.title}</div>
          <div style="font-size: 14px; color: #166534; margin-bottom: 8px;">${win.metric}</div>
          <div style="font-size: 14px; color: #166534; line-height: 1.5;">${win.details || ''}</div>
          ${win.top_chapters && win.top_chapters.length > 0 ? `
            <div style="margin-top: 12px; font-size: 13px; color: #166534;">
              <strong>Top chapters:</strong><br>
              ${win.top_chapters.map(ch => `• ${ch.chapter}: ${ch.accuracy}%`).join('<br>')}
            </div>
          ` : ''}
          <div style="font-size: 13px; color: #166534; margin-top: 12px; font-style: italic;">${win.insight}</div>
        </div>
      `).join('')}
    </div>

    <!-- Overall Performance -->
    <div class="section">
      <div class="section-title">📊 OVERALL PERFORMANCE</div>
      <div style="font-size: 15px; color: #333; margin-bottom: 16px;">
        <strong>${summary.total_questions} questions</strong> | <strong>${summary.accuracy}% accuracy</strong> (${summary.correct} correct, ${summary.incorrect} incorrect)
      </div>
      <div style="font-size: 14px; color: #666;">
        <strong>By Subject:</strong><br>
        ${Object.entries(summary.by_subject).map(([subject, stats]) => {
          const statusIcon = stats.accuracy >= 60 ? '✓' : stats.accuracy >= 40 ? '⚠️' : '❌';
          return `• ${subject.charAt(0).toUpperCase() + subject.slice(1)}: ${Math.round(stats.accuracy)}% ${statusIcon} (${stats.correct}/${stats.total})`;
        }).join('<br>')}
      </div>
    </div>

    <!-- Top 3 Issues -->
    <div class="section">
      <div class="section-title">🎯 YOUR TOP 3 ISSUES TO FIX</div>
      <p style="font-size: 14px; color: #666; margin: 0 0 20px 0;">Fix these in priority order for maximum improvement:</p>

      ${top_issues.map((issue, index) => `
        <div class="issue-card">
          <div style="font-size: 18px; margin-bottom: 12px;">
            ${issue.icon} <strong>${issue.title}</strong>
          </div>
          <div style="font-size: 13px; color: #92400e; margin-bottom: 12px;">
            <strong>Impact:</strong> ${issue.frequency} out of ${summary.incorrect} mistakes (${issue.percentage}%)<br>
            <strong>Potential gain:</strong> +${issue.potential_gain}% accuracy
          </div>

          <div style="margin-bottom: 12px;">
            <strong style="color: #b45309;">What's wrong:</strong><br>
            <span style="color: #92400e;">${issue.what_wrong}</span>
          </div>

          <div style="margin-bottom: 12px;">
            <strong style="color: #b45309;">Root cause:</strong><br>
            <span style="color: #92400e;">${issue.root_cause}</span>
          </div>

          <div style="margin-bottom: 12px;">
            <strong style="color: #b45309;">What to study:</strong><br>
            ${issue.what_to_study.map(topic => `• ${topic}`).join('<br>')}
          </div>

          <div>
            <strong style="color: #b45309;">Suggested practice:</strong><br>
            <span style="color: #92400e;">${issue.suggested_practice}</span>
          </div>
        </div>
      `).join('')}
    </div>

    <!-- How to Use -->
    <div class="section">
      <div class="section-title">💡 HOW TO USE THIS REPORT</div>
      <div style="font-size: 14px; color: #666; line-height: 1.6;">
        <p><strong>Option 1: Fix Priority 1 first (recommended)</strong><br>
        Focus all your study time on Priority 1 until you see improvement, then move to Priority 2.</p>

        <p><strong>Option 2: Work on all 3 simultaneously</strong><br>
        Spend 60% time on Priority 1, 25% on Priority 2, 15% on Priority 3.</p>

        <p><strong>Option 3: Pick what feels right</strong><br>
        You know your strengths. Start where you feel most motivated or where you have upcoming tests.</p>

        <p style="margin-top: 16px;">No matter which approach you choose, these 3 areas give you the clearest path to improvement.</p>
      </div>
    </div>

    <!-- Potential Improvement -->
    <div class="section">
      <div class="section-title">📈 POTENTIAL IMPROVEMENT</div>
      <div style="font-size: 14px; color: #666;">
        <p>If you address these 3 issues:</p>
        <div style="margin: 16px 0;">
          <div style="margin-bottom: 8px;">Current accuracy: <strong>${potential_improvement.current_accuracy}%</strong></div>
          <div class="progress-bar">
            <div class="progress-fill" style="width: ${potential_improvement.current_accuracy}%;"></div>
          </div>
        </div>
        <div style="margin: 16px 0;">
          <div style="margin-bottom: 8px;">Potential accuracy: <strong>${potential_improvement.potential_accuracy}%</strong></div>
          <div class="progress-bar">
            <div class="progress-fill" style="width: ${potential_improvement.potential_accuracy}%;"></div>
          </div>
        </div>
        <p style="margin-top: 16px; font-weight: 600; color: #667eea;">This would put you in the top ${potential_improvement.percentile_projection}% of JEEVibe students.</p>
      </div>
    </div>

    <!-- Footer Message -->
    <div class="section" style="text-align: center; border-bottom: none;">
      <p style="font-size: 18px; font-weight: 600; color: #333; margin: 0 0 24px 0;">Three priorities. Your timeline. Real improvement.</p>
      <div>
        <a href="https://jeevibe.com" class="cta-button">Start Today's Quiz</a>
        <a href="https://jeevibe.com" class="cta-button">Practice Physics</a>
      </div>
      <p style="font-size: 14px; color: #666; margin-top: 24px;">Questions? Reply anytime.<br>- Priya Ma'am</p>
    </div>

    <!-- Footer -->
    <div style="background: #f8f9fa; padding: 20px; text-align: center; font-size: 12px; color: #888;">
      <p style="margin: 0 0 8px 0;">JEEVibe - Honest EdTech for JEE Preparation</p>
      <p style="margin: 0;">support@jeevibe.app | jeevibe.app</p>
    </div>
  </div>
</body>
</html>
  `.trim();

  // Plain text version
  const text = `
━━━ JEEVIBE WEEKLY REPORT ━━━
Week of ${dateRange}

👩‍🏫 Hi ${firstName},

${tone.greeting} You completed ${summary.total_questions} questions and I found some clear wins and areas to focus on.

━━━ 🎉 YOUR WINS THIS WEEK ━━━

${wins.map((win, i) => `
${i + 1}. ${win.title}
${win.metric}
${win.details || ''}
${win.insight}
`).join('\n')}

━━━ 📊 OVERALL PERFORMANCE ━━━

${summary.total_questions} questions | ${summary.accuracy}% accuracy (${summary.correct} correct, ${summary.incorrect} incorrect)

By Subject:
${Object.entries(summary.by_subject).map(([subject, stats]) =>
  `• ${subject.charAt(0).toUpperCase() + subject.slice(1)}: ${Math.round(stats.accuracy)}% (${stats.correct}/${stats.total})`
).join('\n')}

━━━ 🎯 YOUR TOP 3 ISSUES TO FIX ━━━

${top_issues.map((issue, i) => `
${issue.icon} PRIORITY ${i + 1}: ${issue.title}

Impact: ${issue.frequency} mistakes (${issue.percentage}%)
Potential gain: +${issue.potential_gain}% accuracy

What's wrong: ${issue.what_wrong}

Root cause: ${issue.root_cause}

What to study:
${issue.what_to_study.map(t => `• ${t}`).join('\n')}

Suggested practice: ${issue.suggested_practice}
`).join('\n─────────────────────────────\n')}

━━━ 💡 HOW TO USE THIS REPORT ━━━

Option 1: Fix Priority 1 first (recommended)
Option 2: Work on all 3 simultaneously
Option 3: Pick what feels right

━━━ 📈 POTENTIAL IMPROVEMENT ━━━

Current accuracy:    ${potential_improvement.current_accuracy}%
Potential accuracy:  ${potential_improvement.potential_accuracy}%

This would put you in the top ${potential_improvement.percentile_projection}% of JEEVibe students.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Three priorities. Your timeline. Real improvement.

Start Today's Quiz: https://jeevibe.com
Questions? Reply anytime.
- Priya Ma'am
  `.trim();

  return { subject, html, text };
}

/**
 * Generate Daily MPA Email Content
 */
async function generateDailyMPAEmailContent(userData, report, streakData) {
  const firstName = userData.firstName || 'Student';
  const { summary, win, issue, streak } = report;

  // Streak emoji
  let streakEmoji = '';
  if (streak >= 30) streakEmoji = '🏆';
  else if (streak >= 14) streakEmoji = '🌟';
  else if (streak >= 7) streakEmoji = '🔥';
  else if (streak > 0) streakEmoji = '✨';

  const subject = `Day ${streak} ${streakEmoji} | Found your top mistake from yesterday`;

  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>JEEVibe Daily Report</title>
  <style>
    body { margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5; }
    .container { max-width: 600px; margin: 0 auto; background: #ffffff; }
    .header { background: linear-gradient(135deg, #9333EA 0%, #EC4899 100%); padding: 20px; text-align: center; color: #ffffff; }
    .section { padding: 20px; border-bottom: 1px solid #eee; }
    .win-card { background: #f0fdf4; border-radius: 8px; padding: 16px; border-left: 4px solid #22c55e; }
    .issue-card { background: #fef3c7; border-radius: 8px; padding: 16px; border-left: 4px solid #f59e0b; }
    .streak-card { background: linear-gradient(135deg, #fef3cd 0%, #fff3cd 100%); border-radius: 8px; padding: 16px; border-left: 4px solid #ffc107; }
    .cta-button { display: inline-block; background: linear-gradient(135deg, #9333EA 0%, #EC4899 100%); color: #ffffff; text-decoration: none; padding: 12px 24px; border-radius: 8px; font-weight: 600; font-size: 14px; margin: 8px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1 style="margin: 0; font-size: 20px;">━━━ JEEVIBE DAILY REPORT ━━━</h1>
      <p style="margin: 8px 0 0 0; font-size: 14px; opacity: 0.9;">Day ${streak} | ${report.date}</p>
    </div>

    <div class="section">
      <p style="font-size: 16px; color: #333; margin: 0 0 12px 0;">👩‍🏫 Hi ${firstName},</p>
      <p style="font-size: 15px; color: #666; margin: 0;">Yesterday you completed ${summary.total_questions} questions with ${summary.accuracy}% accuracy.</p>
    </div>

    ${win ? `
    <div class="section">
      <div style="font-size: 14px; font-weight: 700; color: #667eea; margin: 0 0 12px 0;">🎉 YESTERDAY'S WIN</div>
      <div class="win-card">
        <div style="font-size: 15px; font-weight: 600; color: #15803d; margin-bottom: 8px;">${win.title}</div>
        <div style="font-size: 14px; color: #166534;">${win.metric}</div>
        <div style="font-size: 13px; color: #166534; margin-top: 8px; font-style: italic;">${win.insight}</div>
      </div>
    </div>
    ` : ''}

    ${issue ? `
    <div class="section">
      <div style="font-size: 14px; font-weight: 700; color: #667eea; margin: 0 0 12px 0;">🎯 TOP ISSUE TO FIX TODAY</div>
      <div class="issue-card">
        <div style="font-size: 15px; font-weight: 600; color: #b45309; margin-bottom: 8px;">${issue.title}</div>
        <div style="font-size: 13px; color: #92400e; margin-bottom: 12px;">
          <strong>Impact:</strong> ${issue.frequency} mistakes
        </div>
        <div style="margin-bottom: 12px;">
          <strong style="color: #b45309;">Quick fix:</strong><br>
          ${issue.what_to_study.slice(0, 3).map(topic => `• ${topic}`).join('<br>')}
        </div>
        <div>
          <strong style="color: #b45309;">Practice:</strong><br>
          <span style="color: #92400e;">${issue.suggested_practice}</span>
        </div>
      </div>
    </div>
    ` : ''}

    <div class="section">
      <div style="font-size: 14px; font-weight: 700; color: #667eea; margin: 0 0 12px 0;">📊 YOUR STREAK</div>
      <div class="streak-card">
        <div style="display: flex; align-items: center; gap: 12px;">
          <span style="font-size: 32px;">${streakEmoji}</span>
          <div>
            <div style="font-size: 18px; font-weight: bold; color: #856404;">${streak} days</div>
            <div style="font-size: 13px; color: #856404;">Keep going!</div>
          </div>
        </div>
      </div>
    </div>

    <div class="section" style="text-align: center; border-bottom: none;">
      <a href="https://jeevibe.com" class="cta-button">Start Today's Quiz</a>
      ${issue ? `<a href="https://jeevibe.com" class="cta-button">Practice ${issue.affected_chapters?.[0] || 'Focus Chapter'}</a>` : ''}
    </div>

    <div style="background: #f8f9fa; padding: 20px; text-align: center; font-size: 12px; color: #888;">
      <p style="margin: 0;">JEEVibe - Your AI-Powered JEE Prep Companion</p>
    </div>
  </div>
</body>
</html>
  `.trim();

  const text = `
━━━ JEEVIBE DAILY REPORT ━━━
Day ${streak} | ${report.date}

👩‍🏫 Hi ${firstName},
Yesterday you completed ${summary.total_questions} questions with ${summary.accuracy}% accuracy.

${win ? `
━━━ 🎉 YESTERDAY'S WIN ━━━
${win.title}
${win.metric}
${win.insight}
` : ''}

${issue ? `
━━━ 🎯 TOP ISSUE TO FIX TODAY ━━━
${issue.title}
Impact: ${issue.frequency} mistakes

Quick fix:
${issue.what_to_study.slice(0, 3).map(t => `• ${t}`).join('\n')}

Practice: ${issue.suggested_practice}
` : ''}

━━━ 📊 YOUR STREAK ━━━
${streak} days ${streakEmoji} | Keep going!

Start Today's Quiz: https://jeevibe.com
  `.trim();

  return { subject, html, text };
}

/**
 * Send Weekly MPA Email
 */
async function sendWeeklyMPAEmail(user, report) {
  if (!resend) {
    logger.warn('Resend client not initialized. Skipping weekly MPA email.');
    return { success: false, error: 'Resend not configured' };
  }

  try {
    const { subject, html, text } = await generateWeeklyMPAEmailContent(user, report);

    const emailData = {
      from: FROM_EMAIL,
      to: user.email,
      subject,
      html,
      text
    };

    const result = await resend.emails.send(emailData);
    logger.info(`Weekly MPA email sent to ${user.email}`, { messageId: result.id });

    return { success: true, messageId: result.id };
  } catch (error) {
    logger.error(`Error sending weekly MPA email to ${user.email}:`, error);
    return { success: false, error: error.message };
  }
}

/**
 * Send Weekly MPA Email to All Users
 * Replaces sendAllWeeklyEmails with MPA report generation
 */
async function sendAllWeeklyMPAEmails() {
  const mpaService = require('./mpaReportService');
  const results = { sent: 0, skipped: 0, failed: 0, errors: [] };

  try {
    logger.info('Starting weekly MPA email batch');

    // Get all users
    const usersSnapshot = await db.collection('users').limit(1000).get();

    // Calculate week range (last Monday to Sunday)
    const { start: weekStart, end: weekEnd } = require('./studentEmailService').getLastWeekRange?.() || getLastWeekRange();

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();

      try {
        // Check if user opted out
        if (userData.email_preferences?.weekly_digest === false) {
          results.skipped++;
          logger.debug('User opted out of weekly emails', { userId });
          continue;
        }

        // Check if user has email
        if (!userData.email) {
          results.skipped++;
          logger.debug('User has no email address', { userId });
          continue;
        }

        // Generate MPA report
        const report = await mpaService.generateWeeklyReport(userId, weekStart, weekEnd);

        if (!report) {
          results.skipped++;
          logger.debug('Insufficient data for weekly MPA report', { userId, reason: 'Less than 40 questions' });
          continue;
        }

        // Store report
        await mpaService.storeWeeklyReport(userId, report);

        // Send email
        const emailResult = await sendWeeklyMPAEmail(userData, report);

        if (emailResult.success) {
          results.sent++;
          // Update report with email sent status
          await db.collection('users').doc(userId)
            .collection('weekly_reports').doc(report.week_id)
            .update({
              email_sent: true,
              email_sent_at: require('firebase-admin').firestore.FieldValue.serverTimestamp()
            });
        } else {
          results.failed++;
          results.errors.push({ userId, reason: emailResult.error });
          logger.warn('Failed to send weekly MPA email', { userId, error: emailResult.error });
        }

      } catch (error) {
        results.failed++;
        results.errors.push({ userId, reason: error.message });
        logger.error('Error processing weekly MPA email for user', { userId, error: error.message });
      }
    }

    logger.info('Weekly MPA email batch complete', results);
    return results;

  } catch (error) {
    logger.error('Error in weekly MPA email batch', { error: error.message });
    throw error;
  }
}

/**
 * Send Daily MPA Email
 */
async function sendDailyMPAEmail(user, report, streakData) {
  if (!resend) {
    logger.warn('Resend client not initialized. Skipping daily MPA email.');
    return { success: false, error: 'Resend not configured' };
  }

  try {
    const { subject, html, text } = await generateDailyMPAEmailContent(user, report, streakData);

    const emailData = {
      from: FROM_EMAIL,
      to: user.email,
      subject,
      html,
      text
    };

    const result = await resend.emails.send(emailData);
    logger.info(`Daily MPA email sent to ${user.email}`, { messageId: result.id });

    return { success: true, messageId: result.id };
  } catch (error) {
    logger.error(`Error sending daily MPA email to ${user.email}:`, error);
    return { success: false, error: error.message };
  }
}

/**
 * Send Daily MPA Email to All Users
 * Replaces sendAllDailyEmails with MPA report generation
 */
async function sendAllDailyMPAEmails() {
  const mpaService = require('./mpaReportService');
  const results = { sent: 0, skipped: 0, failed: 0, errors: [] };

  try {
    logger.info('Starting daily MPA email batch');

    // Get all users
    const usersSnapshot = await db.collection('users').limit(1000).get();

    // Calculate yesterday's date
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();

      try {
        // Check if user opted out
        if (userData.email_preferences?.daily_digest === false) {
          results.skipped++;
          logger.debug('User opted out of daily emails', { userId });
          continue;
        }

        // Check if user has email
        if (!userData.email) {
          results.skipped++;
          logger.debug('User has no email address', { userId });
          continue;
        }

        // Get streak data
        const streakDoc = await db.collection('practice_streaks').doc(userId).get();
        const streakData = streakDoc.exists ? streakDoc.data() : { current_streak: 0 };

        // Generate daily MPA report
        const report = await mpaService.generateDailyReport(userId, yesterday);

        if (!report) {
          // No report generated (less than 5 questions yesterday)
          // Optionally send a streak reminder instead
          results.skipped++;
          logger.debug('Insufficient data for daily MPA report', { userId, reason: 'Less than 5 questions' });
          continue;
        }

        // Send email
        const emailResult = await sendDailyMPAEmail(userData, report, streakData);

        if (emailResult.success) {
          results.sent++;
        } else {
          results.failed++;
          results.errors.push({ userId, reason: emailResult.error });
          logger.warn('Failed to send daily MPA email', { userId, error: emailResult.error });
        }

      } catch (error) {
        results.failed++;
        results.errors.push({ userId, reason: error.message });
        logger.error('Error processing daily MPA email for user', { userId, error: error.message });
      }
    }

    logger.info('Daily MPA email batch complete', results);
    return results;

  } catch (error) {
    logger.error('Error in daily MPA email batch', { error: error.message });
    throw error;
  }
}

module.exports = {
  sendDailyEmail,
  sendWeeklyEmail,
  sendAllDailyEmails,
  sendAllWeeklyEmails,
  generateDailyEmailContent,
  generateWeeklyEmailContent,
  sendTrialEmail,
  generateTrialEmailContent,
  getLastWeekRange, // Export for use in MPA batch functions
  // MPA Email functions
  generateWeeklyMPAEmailContent,
  generateDailyMPAEmailContent,
  sendWeeklyMPAEmail,
  sendDailyMPAEmail,
  sendAllWeeklyMPAEmails,
  sendAllDailyMPAEmails
};
