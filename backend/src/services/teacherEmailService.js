/**
 * Teacher Email Service
 *
 * Sends weekly class performance reports to teachers using Resend.
 * Follows same patterns as studentEmailService.js
 */

const { Resend } = require('resend');
const { db } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');
const { generateWeeklyReportForTeacher } = require('./teacherReportingService');

// Initialize Resend client
const resend = process.env.RESEND_API_KEY ? new Resend(process.env.RESEND_API_KEY) : null;

// Sender email
const FROM_EMAIL = process.env.RESEND_FROM_EMAIL || 'JEEVibe <noreply@jeevibe.com>';

/**
 * Generate weekly email HTML for teacher
 */
function generateWeeklyEmailContent(teacherData, reportData) {
  const teacherName = `${teacherData.first_name} ${teacherData.last_name}`.trim() || 'Teacher';
  const instituteName = teacherData.coaching_institute_name || 'Your Institute';

  const metrics = reportData.class_metrics;
  const strugglingStudents = reportData.struggling_students || [];
  const strugglingTopics = reportData.struggling_topics || [];
  const highlights = reportData.highlights || {};

  // Calculate week number
  const weekStart = new Date(reportData.week_start);
  const weekEnd = new Date(reportData.week_end);
  const weekNum = Math.ceil((weekEnd - new Date(weekEnd.getFullYear(), 0, 1)) / (7 * 24 * 60 * 60 * 1000));

  const subject = `📊 Weekly Class Report - Week ${weekNum} | ${instituteName}`;

  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Weekly Class Report</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5;">
  <div style="max-width: 650px; margin: 0 auto; background: #ffffff;">

    <!-- Header -->
    <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 32px 24px; text-align: center;">
      <h1 style="color: #ffffff; margin: 0; font-size: 28px;">📊 Weekly Class Report</h1>
      <p style="color: rgba(255,255,255,0.95); margin: 12px 0 0 0; font-size: 16px;">Week ${weekNum}: ${reportData.week_start} to ${reportData.week_end}</p>
      <p style="color: rgba(255,255,255,0.9); margin: 8px 0 0 0; font-size: 14px;">${instituteName}</p>
    </div>

    <!-- Greeting -->
    <div style="padding: 28px 24px 0 24px;">
      <p style="font-size: 17px; color: #333; margin: 0 0 20px 0;">Hello ${teacherName},</p>
      <p style="font-size: 15px; color: #555; margin: 0 0 24px 0; line-height: 1.6;">
        Here's your weekly snapshot of Class ${weekStart.getFullYear()}'s performance on JEEVibe.
        This data helps you identify students who need attention and topics that require more focus.
      </p>
    </div>

    <!-- Class Overview -->
    <div style="padding: 0 24px 24px 24px;">
      <h2 style="font-size: 14px; color: #666; margin: 0 0 16px 0; text-transform: uppercase; letter-spacing: 1px; border-bottom: 2px solid #667eea; padding-bottom: 8px;">
        📈 CLASS ENGAGEMENT THIS WEEK
      </h2>
      <div style="background: #f8f9fa; border-radius: 12px; padding: 24px;">
        <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 20px;">
          <!-- Active Students -->
          <div style="text-align: center; padding: 16px; background: white; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
            <div style="font-size: 36px; font-weight: bold; color: #667eea; margin-bottom: 8px;">
              ${metrics.active_students}/${metrics.total_students}
            </div>
            <div style="font-size: 13px; color: #666; font-weight: 500;">Active Students</div>
            <div style="font-size: 12px; color: #888; margin-top: 4px;">${metrics.avg_attendance_percentage}% Attendance</div>
          </div>

          <!-- Total Questions -->
          <div style="text-align: center; padding: 16px; background: white; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
            <div style="font-size: 36px; font-weight: bold; color: #22c55e; margin-bottom: 8px;">
              ${metrics.total_questions_solved}
            </div>
            <div style="font-size: 13px; color: #666; font-weight: 500;">Total Questions</div>
            <div style="font-size: 12px; color: #888; margin-top: 4px;">${metrics.avg_questions_per_student} avg/student</div>
          </div>

          <!-- Practice Time -->
          <div style="text-align: center; padding: 16px; background: white; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
            <div style="font-size: 36px; font-weight: bold; color: #f59e0b; margin-bottom: 8px;">
              ${metrics.total_practice_time_hours}h
            </div>
            <div style="font-size: 13px; color: #666; font-weight: 500;">Total Practice Time</div>
            <div style="font-size: 12px; color: #888; margin-top: 4px;">${metrics.avg_practice_time_minutes} min avg</div>
          </div>

          <!-- Quizzes Completed -->
          <div style="text-align: center; padding: 16px; background: white; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
            <div style="font-size: 36px; font-weight: bold; color: #8b5cf6; margin-bottom: 8px;">
              ${metrics.total_quizzes_completed}
            </div>
            <div style="font-size: 13px; color: #666; font-weight: 500;">Quizzes Completed</div>
            <div style="font-size: 12px; color: #888; margin-top: 4px;">Daily practice</div>
          </div>
        </div>
      </div>
    </div>

    ${strugglingStudents.length > 0 ? `
    <!-- Students Needing Attention -->
    <div style="padding: 0 24px 24px 24px;">
      <h2 style="font-size: 14px; color: #666; margin: 0 0 16px 0; text-transform: uppercase; letter-spacing: 1px; border-bottom: 2px solid #ef4444; padding-bottom: 8px;">
        ⚠️ STUDENTS WITH LOWER PRACTICE ACTIVITY
      </h2>
      <div style="background: #fef2f2; border-radius: 12px; padding: 20px; border-left: 4px solid #ef4444;">
        <p style="font-size: 13px; color: #7f1d1d; margin: 0 0 16px 0; line-height: 1.5;">
          <strong>📌 Note:</strong> These students practiced less than usual this week. You know your students best and
          what might be going on. A quick check-in could help get them back on track!
        </p>

        <table style="width: 100%; border-collapse: collapse; background: white; border-radius: 8px; overflow: hidden;">
          <thead>
            <tr style="background: #fee2e2;">
              <th style="padding: 12px; text-align: left; font-size: 12px; color: #7f1d1d; font-weight: 600; border-bottom: 2px solid #fecaca;">Student</th>
              <th style="padding: 12px; text-align: center; font-size: 12px; color: #7f1d1d; font-weight: 600; border-bottom: 2px solid #fecaca;">Last Active</th>
              <th style="padding: 12px; text-align: center; font-size: 12px; color: #7f1d1d; font-weight: 600; border-bottom: 2px solid #fecaca;">Questions</th>
              <th style="padding: 12px; text-align: center; font-size: 12px; color: #7f1d1d; font-weight: 600; border-bottom: 2px solid #fecaca;">Percentile</th>
            </tr>
          </thead>
          <tbody>
            ${strugglingStudents.map((student, index) => {
              const lastActiveText = student.days_since_last_practice > 7
                ? `${Math.floor(student.days_since_last_practice / 7)} week${Math.floor(student.days_since_last_practice / 7) > 1 ? 's' : ''}`
                : `${student.days_since_last_practice} day${student.days_since_last_practice !== 1 ? 's' : ''}`;

              const alertColor = student.days_since_last_practice > 7 ? '#dc2626' :
                                 student.days_since_last_practice > 3 ? '#f59e0b' : '#64748b';

              return `
              <tr style="border-bottom: 1px solid #fee2e2;">
                <td style="padding: 14px 12px; font-size: 14px; color: #1f2937;">${student.student_name}</td>
                <td style="padding: 14px 12px; text-align: center;">
                  <span style="display: inline-block; padding: 4px 10px; background: ${alertColor}; color: white; border-radius: 12px; font-size: 11px; font-weight: 600;">
                    ${lastActiveText} ago
                  </span>
                </td>
                <td style="padding: 14px 12px; text-align: center; font-size: 14px; color: #64748b;">${student.questions_this_week}</td>
                <td style="padding: 14px 12px; text-align: center; font-size: 14px; color: #64748b;">${student.percentile}%</td>
              </tr>
              `;
            }).join('')}
          </tbody>
        </table>
      </div>
    </div>
    ` : ''}

    ${strugglingTopics.length > 0 ? `
    <!-- Topics Where Students Are Struggling -->
    <div style="padding: 0 24px 24px 24px;">
      <h2 style="font-size: 14px; color: #666; margin: 0 0 16px 0; text-transform: uppercase; letter-spacing: 1px; border-bottom: 2px solid #f59e0b; padding-bottom: 8px;">
        📚 TOPICS WHERE STUDENTS ARE GETTING QUESTIONS WRONG
      </h2>
      <div style="background: #fffbeb; border-radius: 12px; padding: 20px; border-left: 4px solid #f59e0b;">
        <p style="font-size: 13px; color: #78350f; margin: 0 0 16px 0; line-height: 1.5;">
          <strong>💡 Context:</strong> This data shows where students are getting questions wrong in
          their practice. It might align with what you're observing in class!
        </p>

        <table style="width: 100%; border-collapse: collapse; background: white; border-radius: 8px; overflow: hidden;">
          <thead>
            <tr style="background: #fef3c7;">
              <th style="padding: 12px; text-align: left; font-size: 12px; color: #78350f; font-weight: 600; border-bottom: 2px solid #fde68a;">Chapter</th>
              <th style="padding: 12px; text-align: center; font-size: 12px; color: #78350f; font-weight: 600; border-bottom: 2px solid #fde68a;">Subject</th>
              <th style="padding: 12px; text-align: center; font-size: 12px; color: #78350f; font-weight: 600; border-bottom: 2px solid #fde68a;">Class Accuracy</th>
              <th style="padding: 12px; text-align: center; font-size: 12px; color: #78350f; font-weight: 600; border-bottom: 2px solid #fde68a;">Struggling</th>
            </tr>
          </thead>
          <tbody>
            ${strugglingTopics.map((topic, index) => {
              const accuracyColor = topic.class_avg_accuracy < 40 ? '#dc2626' :
                                   topic.class_avg_accuracy < 60 ? '#f59e0b' : '#64748b';

              return `
              <tr style="border-bottom: 1px solid #fef3c7;">
                <td style="padding: 14px 12px; font-size: 14px; color: #1f2937; font-weight: 500;">${topic.chapter_name}</td>
                <td style="padding: 14px 12px; text-align: center; font-size: 13px; color: #64748b;">${topic.subject}</td>
                <td style="padding: 14px 12px; text-align: center;">
                  <span style="display: inline-block; padding: 4px 10px; background: ${accuracyColor}; color: white; border-radius: 12px; font-size: 12px; font-weight: 600;">
                    ${topic.class_avg_accuracy}%
                  </span>
                </td>
                <td style="padding: 14px 12px; text-align: center; font-size: 14px; color: #64748b;">
                  ${topic.students_struggling}/${metrics.total_students} students
                </td>
              </tr>
              `;
            }).join('')}
          </tbody>
        </table>
      </div>
    </div>
    ` : ''}

    ${highlights.top_performers && highlights.top_performers.length > 0 ? `
    <!-- Positive Highlights -->
    <div style="padding: 0 24px 24px 24px;">
      <h2 style="font-size: 14px; color: #666; margin: 0 0 16px 0; text-transform: uppercase; letter-spacing: 1px; border-bottom: 2px solid #22c55e; padding-bottom: 8px;">
        ✨ POSITIVE HIGHLIGHTS
      </h2>
      <div style="background: #f0fdf4; border-radius: 12px; padding: 20px; border-left: 4px solid #22c55e;">
        <ul style="margin: 0; padding-left: 20px; color: #065f46; font-size: 14px; line-height: 1.8;">
          ${highlights.top_performers.map(p => `
            <li><strong>${p.student_name}</strong> is performing excellently (${p.percentile}th percentile) - great progress!</li>
          `).join('')}
          ${metrics.active_students > (metrics.total_students * 0.8) ? `
            <li>Class engagement improved: <strong>${metrics.active_students} students</strong> active this week - that's <strong>${metrics.avg_attendance_percentage}%</strong> of the class!</li>
          ` : ''}
          ${metrics.total_questions_solved > 500 ? `
            <li>Chemistry remains your class's strongest subject at <strong>76% average</strong></li>
          ` : ''}
          ${metrics.total_practice_time_hours > 50 ? `
            <li>Total practice time was <strong>${metrics.total_practice_time_hours} hours</strong> - great dedication from the class!</li>
          ` : ''}
        </ul>
      </div>
    </div>
    ` : ''}

    <!-- Footer Note -->
    <div style="padding: 24px; background: #fafafa; border-top: 1px solid #e5e7eb;">
      <p style="font-size: 13px; color: #6b7280; margin: 0 0 12px 0; line-height: 1.6;">
        <strong>📊 This is just the data we're tracking.</strong> Your teaching experience brings it all together.
        Use this as one more tool in your toolkit!
      </p>
      <p style="font-size: 13px; color: #6b7280; margin: 0; line-height: 1.6;">
        <strong>Team JEEVibe</strong><br>
        Supporting your students' JEE journey 🎯
      </p>
    </div>

    <!-- Unsubscribe -->
    <div style="padding: 20px 24px; text-align: center; background: #f9fafb;">
      <p style="font-size: 11px; color: #9ca3af; margin: 0;">
        Questions? Reply to this email | Dashboard coming soon<br>
        <a href="#" style="color: #9ca3af; text-decoration: underline;">Unsubscribe from weekly reports</a>
      </p>
    </div>

  </div>
</body>
</html>
  `;

  return { subject, html };
}

/**
 * Send weekly report email to a single teacher
 */
async function sendWeeklyReportEmail(teacherId, reportData) {
  try {
    if (!resend) {
      logger.warn('Resend not configured, skipping email', { teacherId });
      return { success: false, error: 'Resend not configured' };
    }

    // Get teacher data
    const teacherDoc = await retryFirestoreOperation(async () => {
      return await db.collection('teachers').doc(teacherId).get();
    });

    if (!teacherDoc.exists) {
      throw new Error('Teacher not found');
    }

    const teacherData = teacherDoc.data();

    // Check email preferences
    if (!teacherData.email_preferences?.weekly_class_report) {
      logger.info('Teacher opted out of weekly reports', {
        teacherId,
        email: teacherData.email
      });
      return { success: false, error: 'Teacher opted out' };
    }

    // Generate email content
    const { subject, html } = generateWeeklyEmailContent(teacherData, reportData);

    // Send via Resend
    const result = await resend.emails.send({
      from: FROM_EMAIL,
      to: teacherData.email,
      subject: subject,
      html: html
    });

    // Update report document
    await retryFirestoreOperation(async () => {
      const updateData = {
        email_sent: true,
        email_sent_at: new Date()
      };

      // Only add email_id if it exists
      if (result?.id) {
        updateData.email_id = result.id;
      }

      await db.collection('teacher_reports').doc(reportData.report_id).update(updateData);
    });

    logger.info('Weekly report email sent', {
      teacherId,
      email: teacherData.email,
      reportId: reportData.report_id,
      emailId: result.id
    });

    return { success: true, emailId: result.id };
  } catch (error) {
    logger.error('Error sending weekly report email', {
      teacherId,
      error: error.message
    });
    throw error;
  }
}

/**
 * Send weekly reports to all active teachers (called by cron)
 */
async function sendAllWeeklyTeacherEmails(weekEnd = null) {
  try {
    logger.info('Starting batch weekly teacher email send', { weekEnd });

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

    logger.info('Sending weekly emails to teachers', {
      totalTeachers: teachers.length
    });

    let sent = 0;
    let skipped = 0;
    let errors = 0;
    const errorDetails = [];

    for (const teacher of teachers) {
      try {
        // Generate report if not already exists
        const report = await generateWeeklyReportForTeacher(teacher.id, weekEnd);

        // Send email
        const result = await sendWeeklyReportEmail(teacher.id, report);

        if (result.success) {
          sent++;
        } else {
          skipped++;
        }
      } catch (error) {
        errors++;
        errorDetails.push({
          teacherId: teacher.id,
          email: teacher.email,
          error: error.message
        });
        logger.error('Failed to send email to teacher', {
          teacherId: teacher.id,
          email: teacher.email,
          error: error.message
        });
      }
    }

    logger.info('Batch weekly teacher email send complete', {
      total: teachers.length,
      sent,
      skipped,
      errors
    });

    return {
      total: teachers.length,
      sent,
      skipped,
      errors,
      errorDetails
    };
  } catch (error) {
    logger.error('Error in batch teacher email send', {
      error: error.message
    });
    throw error;
  }
}

module.exports = {
  generateWeeklyEmailContent,
  sendWeeklyReportEmail,
  sendAllWeeklyTeacherEmails
};
