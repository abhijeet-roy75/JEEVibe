/**
 * Send Test MPA Emails
 *
 * Generates and sends MPA reports to a specific email for testing
 *
 * Usage:
 *   node backend/scripts/send-test-mpa-email.js <userId> <testEmail> <weekStart> [daily|weekly]
 *
 * Example:
 *   node backend/scripts/send-test-mpa-email.js user123 test@example.com 2026-01-27 weekly
 *   node backend/scripts/send-test-mpa-email.js user123 test@example.com 2026-01-30 daily
 */

const admin = require('firebase-admin');
const moment = require('moment-timezone');

// Initialize Firebase Admin
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();
const { generateWeeklyReport, generateDailyReport } = require('../src/services/mpaReportService');
const {
  generateWeeklyMPAEmailContent,
  generateDailyMPAEmailContent
} = require('../src/services/studentEmailService');

// Resend configuration
const { Resend } = require('resend');
const resend = process.env.RESEND_API_KEY ? new Resend(process.env.RESEND_API_KEY) : null;
const FROM_EMAIL = process.env.RESEND_FROM_EMAIL || 'JEEVibe <noreply@jeevibe.com>';

async function sendTestWeeklyEmail(userId, testEmail, weekStartStr) {
  try {
    console.log('\n════════════════════════════════════════');
    console.log('Sending Test Weekly MPA Email');
    console.log('════════════════════════════════════════\n');

    // Parse dates
    const weekStart = moment(weekStartStr).startOf('day').toDate();
    const weekEnd = moment(weekStart).add(6, 'days').endOf('day').toDate();

    console.log(`User ID: ${userId}`);
    console.log(`Week: ${moment(weekStart).format('YYYY-MM-DD')} to ${moment(weekEnd).format('YYYY-MM-DD')}`);
    console.log(`Test Email: ${testEmail}\n`);

    // Get user data
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.log('❌ User not found');
      return;
    }

    const userData = userDoc.data();
    console.log(`User Name: ${userData.firstName || 'Unknown'}\n`);

    // Generate report
    console.log('Generating weekly MPA report...');
    const report = await generateWeeklyReport(userId, weekStart, weekEnd);

    if (!report) {
      console.log('❌ No report generated (insufficient data - need 40+ questions)');
      return;
    }

    console.log(`✅ Report generated: ${report.summary.total_questions} questions, ${report.summary.accuracy}% accuracy\n`);

    // Generate email content
    console.log('Generating email content...');
    const testUserData = {
      ...userData,
      email: testEmail // Override email for testing
    };
    const { subject, html, text } = await generateWeeklyMPAEmailContent(testUserData, report);

    console.log(`Subject: ${subject}\n`);

    // Send email
    if (!resend) {
      console.log('❌ Resend not configured. Set RESEND_API_KEY environment variable.');
      console.log('\nEmail preview saved to console:\n');
      console.log('='.repeat(60));
      console.log(text);
      console.log('='.repeat(60));
      return;
    }

    console.log('Sending email via Resend...');
    const result = await resend.emails.send({
      from: FROM_EMAIL,
      to: testEmail,
      subject,
      html,
      text
    });

    console.log(`✅ Email sent successfully!`);
    console.log(`Message ID: ${result.id}`);
    console.log(`Check inbox: ${testEmail}\n`);

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error.stack);
  }
}

async function sendTestDailyEmail(userId, testEmail, dateStr) {
  try {
    console.log('\n════════════════════════════════════════');
    console.log('Sending Test Daily MPA Email');
    console.log('════════════════════════════════════════\n');

    const date = moment(dateStr).toDate();

    console.log(`User ID: ${userId}`);
    console.log(`Date: ${moment(date).format('YYYY-MM-DD')}`);
    console.log(`Test Email: ${testEmail}\n`);

    // Get user data
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.log('❌ User not found');
      return;
    }

    const userData = userDoc.data();
    console.log(`User Name: ${userData.firstName || 'Unknown'}\n`);

    // Get streak data
    const streakDoc = await db.collection('practice_streaks').doc(userId).get();
    const streakData = streakDoc.exists ? streakDoc.data() : { current_streak: 0 };

    // Generate report
    console.log('Generating daily MPA report...');
    const report = await generateDailyReport(userId, date);

    if (!report) {
      console.log('❌ No report generated (insufficient data - need 5+ questions)');
      return;
    }

    console.log(`✅ Report generated: ${report.summary.total_questions} questions, ${report.summary.accuracy}% accuracy\n`);

    // Generate email content
    console.log('Generating email content...');
    const testUserData = {
      ...userData,
      email: testEmail // Override email for testing
    };
    const { subject, html, text } = await generateDailyMPAEmailContent(testUserData, report, streakData);

    console.log(`Subject: ${subject}\n`);

    // Send email
    if (!resend) {
      console.log('❌ Resend not configured. Set RESEND_API_KEY environment variable.');
      console.log('\nEmail preview saved to console:\n');
      console.log('='.repeat(60));
      console.log(text);
      console.log('='.repeat(60));
      return;
    }

    console.log('Sending email via Resend...');
    const result = await resend.emails.send({
      from: FROM_EMAIL,
      to: testEmail,
      subject,
      html,
      text
    });

    console.log(`✅ Email sent successfully!`);
    console.log(`Message ID: ${result.id}`);
    console.log(`Check inbox: ${testEmail}\n`);

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error.stack);
  }
}

// Main execution
async function main() {
  const args = process.argv.slice(2);

  if (args.length < 4) {
    console.log(`
Usage:
  Weekly: node send-test-mpa-email.js <userId> <testEmail> <weekStart> weekly
  Daily:  node send-test-mpa-email.js <userId> <testEmail> <date> daily

Examples:
  node send-test-mpa-email.js user123 test@example.com 2026-01-27 weekly
  node send-test-mpa-email.js user123 test@example.com 2026-01-30 daily
    `);
    process.exit(1);
  }

  const userId = args[0];
  const testEmail = args[1];
  const dateStr = args[2];
  const reportType = args[3];

  if (reportType === 'daily') {
    await sendTestDailyEmail(userId, testEmail, dateStr);
  } else if (reportType === 'weekly') {
    await sendTestWeeklyEmail(userId, testEmail, dateStr);
  } else {
    console.log('❌ Invalid report type. Use "weekly" or "daily"');
    process.exit(1);
  }

  console.log('════════════════════════════════════════');
  console.log('Test Complete!');
  console.log('════════════════════════════════════════\n');

  process.exit(0);
}

main();
