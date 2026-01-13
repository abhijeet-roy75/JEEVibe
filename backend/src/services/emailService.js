/**
 * Email Service
 * 
 * Handles sending emails for feedback notifications
 * Uses nodemailer with Gmail SMTP (or other SMTP provider)
 */

const logger = require('../utils/logger');

// Email configuration from environment variables
const getEmailConfig = () => {
  return {
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true', // true for 465, false for other ports
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASSWORD,
    },
  };
};

// Recipient emails (comma-separated in env, or default)
const getRecipientEmails = () => {
  const envEmails = process.env.FEEDBACK_EMAIL_RECIPIENTS;
  if (envEmails) {
    return envEmails.split(',').map(email => email.trim());
  }
  // Default recipients
  return ['aroy75@gmail.com', 'satishshetty@gmail.com'];
};

/**
 * Send feedback notification email
 * 
 * @param {Object} feedbackData - Feedback data
 * @param {string} feedbackData.feedbackId - Feedback document ID
 * @param {string} feedbackData.userId - User ID
 * @param {number} feedbackData.rating - Rating (1-5)
 * @param {string} feedbackData.description - Feedback description
 * @param {Object} feedbackData.context - Context data
 */
async function sendFeedbackEmail(feedbackData) {
  try {
    const emailConfig = getEmailConfig();
    
    // Check if email is configured
    if (!emailConfig.auth.user || !emailConfig.auth.pass) {
      logger.warn('Email service not configured. Skipping email notification.', {
        feedbackId: feedbackData.feedbackId,
      });
      return;
    }

    // Try to load nodemailer (optional dependency)
    let nodemailer;
    try {
      nodemailer = require('nodemailer');
    } catch (error) {
      logger.warn('nodemailer not installed. Install it to enable email notifications: npm install nodemailer', {
        feedbackId: feedbackData.feedbackId,
      });
      return;
    }

    // Create transporter
    const transporter = nodemailer.createTransport(emailConfig);

    // Verify connection
    await transporter.verify();

    // Prepare email content
    const recipientEmails = getRecipientEmails();
    const ratingStars = '⭐'.repeat(feedbackData.rating) + '☆'.repeat(5 - feedbackData.rating);
    
    const htmlContent = `
      <!DOCTYPE html>
      <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: linear-gradient(135deg, #9333EA 0%, #EC4899 100%); color: white; padding: 20px; border-radius: 8px 8px 0 0; }
            .content { background: #f9fafb; padding: 20px; border-radius: 0 0 8px 8px; }
            .section { margin-bottom: 20px; }
            .label { font-weight: bold; color: #9333EA; }
            .value { margin-top: 5px; }
            .rating { font-size: 24px; margin: 10px 0; }
            .description { background: white; padding: 15px; border-radius: 8px; border-left: 4px solid #9333EA; margin-top: 10px; }
            .context { background: white; padding: 15px; border-radius: 8px; margin-top: 10px; font-size: 12px; }
            .footer { text-align: center; margin-top: 20px; color: #6b7280; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h2>New Feedback from JEEVibe User</h2>
            </div>
            <div class="content">
              <div class="section">
                <div class="label">Rating:</div>
                <div class="rating">${ratingStars}</div>
              </div>
              
              <div class="section">
                <div class="label">Feedback:</div>
                <div class="description">${feedbackData.description.replace(/\n/g, '<br>')}</div>
              </div>
              
              <div class="section">
                <div class="label">User Information:</div>
                <div class="context">
                  <strong>User ID:</strong> ${feedbackData.userId}<br>
                  <strong>Feedback ID:</strong> ${feedbackData.feedbackId}<br>
                  ${feedbackData.context.userProfile ? `
                    <strong>Name:</strong> ${feedbackData.context.userProfile.firstName || ''} ${feedbackData.context.userProfile.lastName || ''}<br>
                    <strong>Email:</strong> ${feedbackData.context.userProfile.email || 'N/A'}<br>
                    <strong>Phone:</strong> ${feedbackData.context.userProfile.phoneNumber || 'N/A'}<br>
                  ` : ''}
                </div>
              </div>
              
              <div class="section">
                <div class="label">Device & App Info:</div>
                <div class="context">
                  <strong>App Version:</strong> ${feedbackData.context.appVersion || 'N/A'}<br>
                  <strong>Device Model:</strong> ${feedbackData.context.deviceModel || 'N/A'}<br>
                  <strong>OS Version:</strong> ${feedbackData.context.osVersion || 'N/A'}<br>
                  <strong>Current Screen:</strong> ${feedbackData.context.currentScreen || 'N/A'}<br>
                  <strong>Timestamp:</strong> ${feedbackData.context.timestamp || 'N/A'}<br>
                </div>
              </div>
              
              ${feedbackData.context.recentActivity && feedbackData.context.recentActivity.length > 0 ? `
                <div class="section">
                  <div class="label">Recent Activity:</div>
                  <div class="context">
                    ${feedbackData.context.recentActivity.map(activity => 
                      `• ${JSON.stringify(activity)}`
                    ).join('<br>')}
                  </div>
                </div>
              ` : ''}
              
              <div class="footer">
                <p>This is an automated email from JEEVibe Feedback System</p>
              </div>
            </div>
          </div>
        </body>
      </html>
    `;

    const textContent = `
New Feedback from JEEVibe User

Rating: ${ratingStars}

Feedback:
${feedbackData.description}

User Information:
- User ID: ${feedbackData.userId}
- Feedback ID: ${feedbackData.feedbackId}
${feedbackData.context.userProfile ? `
- Name: ${feedbackData.context.userProfile.firstName || ''} ${feedbackData.context.userProfile.lastName || ''}
- Email: ${feedbackData.context.userProfile.email || 'N/A'}
- Phone: ${feedbackData.context.userProfile.phoneNumber || 'N/A'}
` : ''}

Device & App Info:
- App Version: ${feedbackData.context.appVersion || 'N/A'}
- Device Model: ${feedbackData.context.deviceModel || 'N/A'}
- OS Version: ${feedbackData.context.osVersion || 'N/A'}
- Current Screen: ${feedbackData.context.currentScreen || 'N/A'}
- Timestamp: ${feedbackData.context.timestamp || 'N/A'}
`;

    // Send email
    const info = await transporter.sendMail({
      from: `"JEEVibe Feedback" <${emailConfig.auth.user}>`,
      to: recipientEmails.join(', '),
      subject: `JEEVibe Feedback - ${ratingStars} Rating from User ${feedbackData.userId.substring(0, 8)}`,
      text: textContent,
      html: htmlContent,
    });

    logger.info('Feedback email sent successfully', {
      feedbackId: feedbackData.feedbackId,
      userId: feedbackData.userId,
      messageId: info.messageId,
      recipients: recipientEmails,
    });
  } catch (error) {
    logger.error('Error sending feedback email', {
      feedbackId: feedbackData.feedbackId,
      userId: feedbackData.userId,
      error: error.message,
      stack: error.stack,
    });
    throw error;
  }
}

module.exports = {
  sendFeedbackEmail,
};
