/**
 * Email Service using Resend
 *
 * Sends email notifications for feedback submissions
 */

const { Resend } = require('resend');
const logger = require('../utils/logger');

// Initialize Resend client
const resend = process.env.RESEND_API_KEY ? new Resend(process.env.RESEND_API_KEY) : null;

// Email recipients for feedback notifications
const FEEDBACK_RECIPIENTS = process.env.FEEDBACK_EMAIL_RECIPIENTS
  ? process.env.FEEDBACK_EMAIL_RECIPIENTS.split(',').map((e) => e.trim())
  : [];

// Sender email (must be verified in Resend or use onboarding@resend.dev for testing)
const FROM_EMAIL = process.env.RESEND_FROM_EMAIL || 'JEEVibe <onboarding@resend.dev>';

/**
 * Send feedback notification email
 */
async function sendFeedbackEmail(feedbackData) {
  // Check if email is configured
  if (!resend) {
    logger.debug('Email notifications disabled - RESEND_API_KEY not configured', {
      feedbackId: feedbackData.feedbackId,
    });
    return { sent: false, reason: 'RESEND_API_KEY not configured' };
  }

  if (FEEDBACK_RECIPIENTS.length === 0) {
    logger.debug('Email notifications disabled - no recipients configured', {
      feedbackId: feedbackData.feedbackId,
    });
    return { sent: false, reason: 'No recipients configured' };
  }

  try {
    const { feedbackId, userId, userName, userEmail, rating, description, context } = feedbackData;

    // Build email content
    const stars = '★'.repeat(rating) + '☆'.repeat(5 - rating);
    const timestamp = context?.submittedAt || new Date().toISOString();
    const displayName = userName || 'Anonymous User';

    const htmlContent = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #1a73e8;">New Feedback Received</h2>

        <div style="background: #f5f5f5; padding: 16px; border-radius: 8px; margin: 16px 0;">
          <p style="margin: 0 0 8px 0;"><strong>Rating:</strong> ${stars} (${rating}/5)</p>
          <p style="margin: 0 0 8px 0;"><strong>From:</strong> ${displayName}${userEmail ? ` (${userEmail})` : ''}</p>
          <p style="margin: 0;"><strong>User ID:</strong> ${userId}</p>
        </div>

        ${
          description
            ? `
        <div style="margin: 16px 0;">
          <h3 style="margin: 0 0 8px 0;">Description:</h3>
          <p style="background: #fff; padding: 12px; border-left: 4px solid #1a73e8; margin: 0;">${description}</p>
        </div>
        `
            : ''
        }

        <div style="margin: 16px 0;">
          <h3 style="margin: 0 0 8px 0;">Context:</h3>
          <table style="width: 100%; border-collapse: collapse;">
            ${context?.currentScreen ? `<tr><td style="padding: 4px 8px; border-bottom: 1px solid #eee;"><strong>Screen:</strong></td><td style="padding: 4px 8px; border-bottom: 1px solid #eee;">${context.currentScreen}</td></tr>` : ''}
            ${context?.appVersion ? `<tr><td style="padding: 4px 8px; border-bottom: 1px solid #eee;"><strong>App Version:</strong></td><td style="padding: 4px 8px; border-bottom: 1px solid #eee;">${context.appVersion}</td></tr>` : ''}
            ${context?.deviceModel ? `<tr><td style="padding: 4px 8px; border-bottom: 1px solid #eee;"><strong>Device:</strong></td><td style="padding: 4px 8px; border-bottom: 1px solid #eee;">${context.deviceModel}</td></tr>` : ''}
            ${context?.osVersion ? `<tr><td style="padding: 4px 8px; border-bottom: 1px solid #eee;"><strong>OS Version:</strong></td><td style="padding: 4px 8px; border-bottom: 1px solid #eee;">${context.osVersion}</td></tr>` : ''}
          </table>
        </div>

        <p style="color: #666; font-size: 12px; margin-top: 24px;">
          Submitted at: ${timestamp}
        </p>
      </div>
    `;

    const textContent = `
New Feedback Received

Rating: ${stars} (${rating}/5)
From: ${displayName}${userEmail ? ` (${userEmail})` : ''}
User ID: ${userId}

${description ? `Description:\n${description}\n` : ''}
Context:
- Screen: ${context?.currentScreen || 'N/A'}
- App Version: ${context?.appVersion || 'N/A'}
- Device: ${context?.deviceModel || 'N/A'}
- OS Version: ${context?.osVersion || 'N/A'}

Submitted at: ${timestamp}
    `.trim();

    // Send email
    const { data, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: FEEDBACK_RECIPIENTS,
      subject: `[JEEVibe] New Feedback: ${rating}/5 stars`,
      html: htmlContent,
      text: textContent,
    });

    if (error) {
      logger.error('Failed to send feedback email', {
        feedbackId,
        error: error.message,
      });
      return { sent: false, reason: error.message };
    }

    logger.info('Feedback email sent successfully', {
      feedbackId,
      emailId: data?.id,
      recipients: FEEDBACK_RECIPIENTS.length,
    });

    return { sent: true, emailId: data?.id };
  } catch (error) {
    logger.error('Error sending feedback email', {
      feedbackId: feedbackData.feedbackId,
      error: error.message,
    });
    return { sent: false, reason: error.message };
  }
}

module.exports = {
  sendFeedbackEmail,
};
