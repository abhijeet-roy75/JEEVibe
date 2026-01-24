/**
 * Alert Service
 *
 * Monitors key metrics and sends alerts when thresholds are breached.
 * Alerts are sent via email to admins.
 */

const { Resend } = require('resend');
const { db } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const { toIST, formatDateIST } = require('../utils/dateUtils');
const logger = require('../utils/logger');

// Initialize Resend client
const resend = process.env.RESEND_API_KEY ? new Resend(process.env.RESEND_API_KEY) : null;

// Alert recipients (admins)
const ALERT_RECIPIENTS = process.env.ADMIN_EMAILS
  ? process.env.ADMIN_EMAILS.split(',').map(e => e.trim())
  : [];

// Sender email
const FROM_EMAIL = process.env.RESEND_FROM_EMAIL || 'JEEVibe Alerts <alerts@jeevibe.com>';

// Alert thresholds
const THRESHOLDS = {
  DAU_DROP_PERCENT: 30, // Alert if DAU drops more than 30% vs 7-day average
  ASSESSMENT_COMPLETION_MIN: 50, // Alert if assessment completion drops below 50%
  PRO_USER_INACTIVE_DAYS: 5, // Alert if Pro/Ultra user inactive for 5+ days
  QUESTION_ACCURACY_MIN: 15, // Flag questions with <15% accuracy
  QUESTION_ACCURACY_MAX: 98 // Flag questions with >98% accuracy
};

/**
 * Get date string in IST (YYYY-MM-DD)
 */
function getDateString(date) {
  return formatDateIST(toIST(date));
}

/**
 * Get start of day in IST
 */
function getStartOfDay(date) {
  const istDate = toIST(date);
  istDate.setHours(0, 0, 0, 0);
  return istDate;
}

/**
 * Calculate DAU for a specific date
 */
async function getDailyActiveUsers(date) {
  const dateStr = getDateString(date);
  const startOfDay = getStartOfDay(date);
  const endOfDay = new Date(startOfDay);
  endOfDay.setHours(23, 59, 59, 999);

  // Get users with quiz activity
  const quizzesSnapshot = await retryFirestoreOperation(async () => {
    return await db.collectionGroup('quizzes')
      .where('generated_at', '>=', startOfDay)
      .where('generated_at', '<=', endOfDay)
      .get();
  });

  const activeUserIds = new Set();
  quizzesSnapshot.docs.forEach(doc => {
    const data = doc.data();
    if (data.user_id) activeUserIds.add(data.user_id);
  });

  return activeUserIds.size;
}

/**
 * Get 7-day average DAU
 */
async function getSevenDayAverageDAU() {
  const today = new Date();
  let totalDAU = 0;

  for (let i = 1; i <= 7; i++) {
    const date = new Date(today);
    date.setDate(date.getDate() - i);
    const dau = await getDailyActiveUsers(date);
    totalDAU += dau;
  }

  return Math.round(totalDAU / 7);
}

/**
 * Check DAU drop alert
 */
async function checkDAUDropAlert() {
  try {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);

    const yesterdayDAU = await getDailyActiveUsers(yesterday);
    const avgDAU = await getSevenDayAverageDAU();

    if (avgDAU === 0) {
      return { triggered: false, reason: 'No 7-day average (new app)' };
    }

    const dropPercent = ((avgDAU - yesterdayDAU) / avgDAU) * 100;

    if (dropPercent >= THRESHOLDS.DAU_DROP_PERCENT) {
      return {
        triggered: true,
        alert: {
          type: 'DAU_DROP',
          severity: 'high',
          title: `DAU Dropped ${Math.round(dropPercent)}%`,
          message: `Yesterday's DAU (${yesterdayDAU}) is ${Math.round(dropPercent)}% below the 7-day average (${avgDAU}).`,
          data: { yesterdayDAU, avgDAU, dropPercent: Math.round(dropPercent) }
        }
      };
    }

    return { triggered: false, data: { yesterdayDAU, avgDAU } };
  } catch (error) {
    logger.error('Error checking DAU drop alert', { error: error.message });
    return { triggered: false, error: error.message };
  }
}

/**
 * Check assessment completion alert
 */
async function checkAssessmentCompletionAlert() {
  try {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const startOfDay = getStartOfDay(yesterday);
    const endOfDay = new Date(startOfDay);
    endOfDay.setHours(23, 59, 59, 999);

    // Get users who signed up yesterday
    const usersSnapshot = await retryFirestoreOperation(async () => {
      return await db.collection('users')
        .where('createdAt', '>=', startOfDay)
        .where('createdAt', '<=', endOfDay)
        .get();
    });

    const newUsers = usersSnapshot.docs.length;
    let completedAssessments = 0;

    usersSnapshot.docs.forEach(doc => {
      const data = doc.data();
      if (data.assessment?.status === 'completed') {
        completedAssessments++;
      }
    });

    if (newUsers === 0) {
      return { triggered: false, reason: 'No new signups yesterday' };
    }

    const completionRate = (completedAssessments / newUsers) * 100;

    if (completionRate < THRESHOLDS.ASSESSMENT_COMPLETION_MIN) {
      return {
        triggered: true,
        alert: {
          type: 'ASSESSMENT_COMPLETION_LOW',
          severity: 'medium',
          title: `Assessment Completion Low: ${Math.round(completionRate)}%`,
          message: `Only ${completedAssessments} of ${newUsers} new users (${Math.round(completionRate)}%) completed the assessment yesterday.`,
          data: { newUsers, completedAssessments, completionRate: Math.round(completionRate) }
        }
      };
    }

    return { triggered: false, data: { newUsers, completedAssessments, completionRate: Math.round(completionRate) } };
  } catch (error) {
    logger.error('Error checking assessment completion alert', { error: error.message });
    return { triggered: false, error: error.message };
  }
}

/**
 * Check for inactive Pro/Ultra users
 */
async function checkInactiveProUsersAlert() {
  try {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - THRESHOLDS.PRO_USER_INACTIVE_DAYS);

    // Get Pro/Ultra users
    const proUsersSnapshot = await retryFirestoreOperation(async () => {
      return await db.collection('users')
        .where('subscriptions.tier', 'in', ['pro', 'ultra'])
        .get();
    });

    const inactiveUsers = [];

    proUsersSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const lastActive = data.lastActive?.toDate?.();

      if (lastActive && lastActive < cutoffDate) {
        const daysSinceActive = Math.floor((new Date() - lastActive) / (1000 * 60 * 60 * 24));
        inactiveUsers.push({
          userId: doc.id,
          email: data.email,
          firstName: data.firstName,
          tier: data.subscriptions?.tier,
          daysSinceActive,
          lastActive: formatDateIST(lastActive)
        });
      }
    });

    if (inactiveUsers.length > 0) {
      return {
        triggered: true,
        alert: {
          type: 'INACTIVE_PRO_USERS',
          severity: 'high',
          title: `${inactiveUsers.length} Pro/Ultra Users Inactive`,
          message: `${inactiveUsers.length} paying user(s) haven't been active for ${THRESHOLDS.PRO_USER_INACTIVE_DAYS}+ days.`,
          data: { count: inactiveUsers.length, users: inactiveUsers }
        }
      };
    }

    return { triggered: false };
  } catch (error) {
    logger.error('Error checking inactive Pro users alert', { error: error.message });
    return { triggered: false, error: error.message };
  }
}

/**
 * Check for question accuracy anomalies
 */
async function checkQuestionAccuracyAnomalies() {
  try {
    const anomalies = [];

    // Get all active questions with accuracy data
    const questionsSnapshot = await retryFirestoreOperation(async () => {
      return await db.collection('questions')
        .where('active', '==', true)
        .where('total_attempts', '>=', 10) // Only check questions with enough data
        .limit(500)
        .get();
    });

    questionsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const accuracy = data.accuracy_rate || 0;
      const totalAttempts = data.total_attempts || 0;

      if (accuracy < THRESHOLDS.QUESTION_ACCURACY_MIN) {
        anomalies.push({
          questionId: doc.id,
          chapter: data.chapter_key,
          accuracy: Math.round(accuracy),
          attempts: totalAttempts,
          issue: 'TOO_HARD'
        });
      } else if (accuracy > THRESHOLDS.QUESTION_ACCURACY_MAX) {
        anomalies.push({
          questionId: doc.id,
          chapter: data.chapter_key,
          accuracy: Math.round(accuracy),
          attempts: totalAttempts,
          issue: 'TOO_EASY'
        });
      }
    });

    if (anomalies.length > 0) {
      return {
        triggered: true,
        alert: {
          type: 'QUESTION_ACCURACY_ANOMALIES',
          severity: 'low',
          title: `${anomalies.length} Question Accuracy Anomalies`,
          message: `${anomalies.length} question(s) have unusual accuracy rates (too hard or too easy).`,
          data: { count: anomalies.length, questions: anomalies.slice(0, 10) } // Limit to 10 in email
        }
      };
    }

    return { triggered: false };
  } catch (error) {
    logger.error('Error checking question accuracy anomalies', { error: error.message });
    return { triggered: false, error: error.message };
  }
}

/**
 * Send alert email
 */
async function sendAlertEmail(alert) {
  if (!resend || ALERT_RECIPIENTS.length === 0) {
    logger.debug('Alert email disabled - no Resend or recipients configured');
    return { sent: false, reason: 'Not configured' };
  }

  const severityColors = {
    high: '#ef4444',
    medium: '#f59e0b',
    low: '#3b82f6'
  };

  const severityEmoji = {
    high: '🚨',
    medium: '⚠️',
    low: 'ℹ️'
  };

  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>JEEVibe Alert</title>
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f5f5f5;">
  <div style="max-width: 600px; margin: 0 auto; background: #ffffff;">
    <div style="background: ${severityColors[alert.severity]}; padding: 20px; text-align: center;">
      <h1 style="color: #ffffff; margin: 0; font-size: 20px;">${severityEmoji[alert.severity]} JEEVibe Alert</h1>
    </div>

    <div style="padding: 24px;">
      <h2 style="color: #333; margin: 0 0 16px 0;">${alert.title}</h2>
      <p style="color: #666; margin: 0 0 16px 0;">${alert.message}</p>

      ${alert.data ? `
      <div style="background: #f8f9fa; border-radius: 8px; padding: 16px; margin-bottom: 16px;">
        <h3 style="margin: 0 0 12px 0; font-size: 14px; color: #666;">Details</h3>
        <pre style="margin: 0; font-size: 12px; overflow-x: auto;">${JSON.stringify(alert.data, null, 2)}</pre>
      </div>
      ` : ''}

      <p style="color: #888; font-size: 12px; margin: 16px 0 0 0;">
        Alert Type: ${alert.type} | Severity: ${alert.severity.toUpperCase()}<br>
        Generated: ${formatDateIST(toIST(new Date()))}
      </p>
    </div>
  </div>
</body>
</html>
  `.trim();

  try {
    const { data, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: ALERT_RECIPIENTS,
      subject: `[JEEVibe ${alert.severity.toUpperCase()}] ${alert.title}`,
      html
    });

    if (error) {
      logger.error('Failed to send alert email', { alertType: alert.type, error: error.message });
      return { sent: false, reason: error.message };
    }

    logger.info('Alert email sent', { alertType: alert.type, emailId: data?.id });
    return { sent: true, emailId: data?.id };
  } catch (error) {
    logger.error('Error sending alert email', { alertType: alert.type, error: error.message });
    return { sent: false, reason: error.message };
  }
}

/**
 * Store alert in Firestore for dashboard display
 */
async function storeAlert(alert) {
  try {
    const alertDoc = {
      ...alert,
      created_at: new Date(),
      acknowledged: false
    };

    await db.collection('admin_alerts').add(alertDoc);
    logger.info('Alert stored', { alertType: alert.type });
  } catch (error) {
    logger.error('Error storing alert', { alertType: alert.type, error: error.message });
  }
}

/**
 * Run all alert checks
 */
async function runAlertChecks() {
  const results = {
    checked: 0,
    triggered: 0,
    alerts: [],
    errors: []
  };

  const checks = [
    { name: 'DAU_DROP', fn: checkDAUDropAlert },
    { name: 'ASSESSMENT_COMPLETION', fn: checkAssessmentCompletionAlert },
    { name: 'INACTIVE_PRO_USERS', fn: checkInactiveProUsersAlert },
    { name: 'QUESTION_ACCURACY', fn: checkQuestionAccuracyAnomalies }
  ];

  for (const check of checks) {
    results.checked++;

    try {
      const result = await check.fn();

      if (result.triggered) {
        results.triggered++;
        results.alerts.push(result.alert);

        // Store alert in Firestore
        await storeAlert(result.alert);

        // Send email for high/medium severity
        if (result.alert.severity === 'high' || result.alert.severity === 'medium') {
          await sendAlertEmail(result.alert);
        }
      }
    } catch (error) {
      results.errors.push({ check: check.name, error: error.message });
      logger.error('Alert check failed', { check: check.name, error: error.message });
    }
  }

  logger.info('Alert checks complete', {
    checked: results.checked,
    triggered: results.triggered,
    errors: results.errors.length
  });

  return results;
}

/**
 * Get recent alerts from Firestore
 */
async function getRecentAlerts(limit = 50) {
  try {
    const alertsSnapshot = await db.collection('admin_alerts')
      .orderBy('created_at', 'desc')
      .limit(limit)
      .get();

    return alertsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      created_at: doc.data().created_at?.toDate?.()?.toISOString()
    }));
  } catch (error) {
    logger.error('Error getting recent alerts', { error: error.message });
    return [];
  }
}

/**
 * Acknowledge an alert
 */
async function acknowledgeAlert(alertId) {
  try {
    await db.collection('admin_alerts').doc(alertId).update({
      acknowledged: true,
      acknowledged_at: new Date()
    });
    return { success: true };
  } catch (error) {
    logger.error('Error acknowledging alert', { alertId, error: error.message });
    return { success: false, error: error.message };
  }
}

module.exports = {
  runAlertChecks,
  getRecentAlerts,
  acknowledgeAlert,
  checkDAUDropAlert,
  checkAssessmentCompletionAlert,
  checkInactiveProUsersAlert,
  checkQuestionAccuracyAnomalies,
  sendAlertEmail
};
