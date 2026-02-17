/**
 * Test MPA Report Generation
 *
 * Usage:
 *   node backend/scripts/test-mpa-report.js <userId> [weekStartDate]
 *
 * Example:
 *   node backend/scripts/test-mpa-report.js user123 2026-02-03
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

const { generateWeeklyReport, generateDailyReport } = require('../src/services/mpaReportService');

async function testWeeklyReport(userId, weekStartStr) {
  try {
    console.log('\n════════════════════════════════════════');
    console.log('Testing Weekly MPA Report Generation');
    console.log('════════════════════════════════════════\n');

    // Parse dates
    const weekStart = weekStartStr
      ? moment(weekStartStr).startOf('day').toDate()
      : moment().subtract(7, 'days').startOf('week').toDate();

    const weekEnd = moment(weekStart).add(6, 'days').endOf('day').toDate();

    console.log(`User ID: ${userId}`);
    console.log(`Week: ${moment(weekStart).format('YYYY-MM-DD')} to ${moment(weekEnd).format('YYYY-MM-DD')}\n`);

    // Generate report
    console.log('Generating report...\n');
    const report = await generateWeeklyReport(userId, weekStart, weekEnd);

    if (!report) {
      console.log('❌ No report generated (likely insufficient data - need 40+ questions)');
      return;
    }

    // Display report
    console.log('✅ Report Generated Successfully!\n');
    console.log('━━━ SUMMARY ━━━');
    console.log(`Total Questions: ${report.summary.total_questions}`);
    console.log(`Accuracy: ${report.summary.accuracy}%`);
    console.log(`Days Practiced: ${report.summary.days_practiced}/7`);
    console.log(`\nBy Subject:`);
    Object.entries(report.summary.by_subject).forEach(([subject, stats]) => {
      console.log(`  ${subject}: ${Math.round(stats.accuracy)}% (${stats.correct}/${stats.total})`);
    });

    console.log('\n━━━ WINS ━━━');
    report.wins.forEach((win, i) => {
      console.log(`\n${i + 1}. ${win.title}`);
      console.log(`   Type: ${win.type}`);
      console.log(`   Metric: ${win.metric}`);
      if (win.details) console.log(`   Details: ${win.details}`);
      console.log(`   Insight: ${win.insight}`);
    });

    console.log('\n━━━ TOP 3 ISSUES ━━━');
    report.top_issues.forEach((issue, i) => {
      console.log(`\n${issue.icon} PRIORITY ${i + 1}: ${issue.title}`);
      console.log(`   Frequency: ${issue.frequency} mistakes (${issue.percentage}%)`);
      console.log(`   Potential Gain: +${issue.potential_gain}% accuracy`);
      console.log(`   ROI Score: ${issue.roi_score}`);
      console.log(`   What's wrong: ${issue.what_wrong}`);
      console.log(`   Root cause: ${issue.root_cause}`);
      console.log(`   What to study:`);
      issue.what_to_study.forEach(topic => console.log(`     • ${topic}`));
      console.log(`   Suggested practice: ${issue.suggested_practice}`);
    });

    console.log('\n━━━ POTENTIAL IMPROVEMENT ━━━');
    console.log(`Current accuracy: ${report.potential_improvement.current_accuracy}%`);
    console.log(`Potential accuracy: ${report.potential_improvement.potential_accuracy}%`);
    console.log(`Percentile projection: Top ${report.potential_improvement.percentile_projection}%`);

    console.log('\n━━━ ADAPTIVE TONE ━━━');
    console.log(`Greeting: ${report.tone.greeting}`);
    console.log(`Tone: ${report.tone.tone}`);
    console.log(`Encouragement level: ${report.tone.encouragement_level}`);
    if (report.tone.extra_message) {
      console.log(`Extra message: ${report.tone.extra_message}`);
    }

    console.log('\n━━━ FULL REPORT JSON ━━━');
    console.log(JSON.stringify(report, null, 2));

  } catch (error) {
    console.error('❌ Error generating weekly report:', error);
    console.error(error.stack);
  }
}

async function testDailyReport(userId, dateStr) {
  try {
    console.log('\n════════════════════════════════════════');
    console.log('Testing Daily MPA Report Generation');
    console.log('════════════════════════════════════════\n');

    const date = dateStr
      ? moment(dateStr).toDate()
      : moment().subtract(1, 'day').toDate();

    console.log(`User ID: ${userId}`);
    console.log(`Date: ${moment(date).format('YYYY-MM-DD')}\n`);

    // Generate report
    console.log('Generating daily report...\n');
    const report = await generateDailyReport(userId, date);

    if (!report) {
      console.log('❌ No report generated (likely insufficient data - need 5+ questions)');
      return;
    }

    // Display report
    console.log('✅ Daily Report Generated Successfully!\n');
    console.log('━━━ SUMMARY ━━━');
    console.log(`Questions: ${report.summary.total_questions}`);
    console.log(`Accuracy: ${report.summary.accuracy}%`);
    console.log(`Streak: ${report.streak} days`);

    if (report.win) {
      console.log('\n━━━ YESTERDAY\'S WIN ━━━');
      console.log(`Title: ${report.win.title}`);
      console.log(`Metric: ${report.win.metric}`);
      console.log(`Insight: ${report.win.insight}`);
    }

    if (report.issue) {
      console.log('\n━━━ TOP ISSUE ━━━');
      console.log(`Title: ${report.issue.title}`);
      console.log(`Frequency: ${report.issue.frequency} mistakes`);
      console.log(`What's wrong: ${report.issue.what_wrong}`);
      console.log(`Quick fixes:`);
      report.issue.what_to_study.slice(0, 3).forEach(topic => console.log(`  • ${topic}`));
      console.log(`Practice: ${report.issue.suggested_practice}`);
    }

    console.log('\n━━━ FULL REPORT JSON ━━━');
    console.log(JSON.stringify(report, null, 2));

  } catch (error) {
    console.error('❌ Error generating daily report:', error);
    console.error(error.stack);
  }
}

// Main execution
async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.log(`
Usage:
  Weekly Report: node test-mpa-report.js <userId> [weekStartDate]
  Daily Report:  node test-mpa-report.js <userId> daily [date]

Examples:
  node test-mpa-report.js user123 2026-02-03
  node test-mpa-report.js user123 daily 2026-02-09
  node test-mpa-report.js user123  (uses last week)
    `);
    process.exit(1);
  }

  const userId = args[0];
  const isDailyReport = args[1] === 'daily';

  if (isDailyReport) {
    const date = args[2];
    await testDailyReport(userId, date);
  } else {
    const weekStart = args[1];
    await testWeeklyReport(userId, weekStart);
  }

  console.log('\n════════════════════════════════════════');
  console.log('Test Complete!');
  console.log('════════════════════════════════════════\n');

  process.exit(0);
}

main();
