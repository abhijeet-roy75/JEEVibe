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

module.exports = {
  sendDailyEmail,
  sendWeeklyEmail,
  sendAllDailyEmails,
  sendAllWeeklyEmails,
  generateDailyEmailContent,
  generateWeeklyEmailContent
};
