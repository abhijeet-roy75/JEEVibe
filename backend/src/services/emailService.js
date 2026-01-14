/**
 * Email Service
 *
 * Handles sending emails for feedback notifications
 * Uses nodemailer with Gmail SMTP (or other SMTP provider)
 */

const logger = require('../utils/logger');

// Email configuration from environment variables
const getEmailConfig = () => {
  const config = {
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true', // true for 465, false for other ports
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASSWORD,
    },
  };

  // Debug log the config (mask password)
  logger.debug('Email config loaded', {
    host: config.host,
    port: config.port,
    secure: config.secure,
    user: config.auth.user || '(not set)',
    passwordSet: !!config.auth.pass,
    passwordLength: config.auth.pass ? config.auth.pass.length : 0,
  });

  return config;
};

// Recipient emails (comma-separated in env, or default)
const getRecipientEmails = () => {
  const envEmails = process.env.FEEDBACK_EMAIL_RECIPIENTS;
  if (envEmails) {
    const emails = envEmails.split(',').map(email => email.trim());
    logger.debug('Using custom recipient emails from env', { recipients: emails });
    return emails;
  }
  // Default recipients
  const defaultEmails = ['aroy75@gmail.com', 'satishshetty@gmail.com'];
  logger.debug('Using default recipient emails', { recipients: defaultEmails });
  return defaultEmails;
};

/**
 * Check email configuration status
 * Returns diagnostic information about email setup
 */
function getEmailDiagnostics() {
  const config = getEmailConfig();
  const recipients = getRecipientEmails();

  let nodemailerInstalled = false;
  let nodemailerVersion = null;
  try {
    const nodemailer = require('nodemailer');
    nodemailerInstalled = true;
    nodemailerVersion = require('nodemailer/package.json').version;
  } catch (e) {
    // nodemailer not installed
  }

  return {
    nodemailerInstalled,
    nodemailerVersion,
    smtpHost: config.host,
    smtpPort: config.port,
    smtpSecure: config.secure,
    smtpUserConfigured: !!config.auth.user,
    smtpUser: config.auth.user ? `${config.auth.user.substring(0, 3)}***` : '(not set)',
    smtpPasswordConfigured: !!config.auth.pass,
    smtpPasswordLength: config.auth.pass ? config.auth.pass.length : 0,
    recipients,
    feedbackFeatureEnabled: process.env.ENABLE_FEEDBACK_FEATURE === 'true' || process.env.ENABLE_FEEDBACK_FEATURE === '1',
  };
}

/**
 * Test email configuration by verifying SMTP connection
 * @returns {Object} Test result with success status and details
 */
async function testEmailConnection() {
  const diagnostics = getEmailDiagnostics();
  const result = {
    timestamp: new Date().toISOString(),
    diagnostics,
    tests: [],
  };

  // Test 1: Check nodemailer installation
  if (!diagnostics.nodemailerInstalled) {
    result.tests.push({
      name: 'nodemailer_installed',
      passed: false,
      error: 'nodemailer is not installed. Run: npm install nodemailer',
    });
    result.overallStatus = 'FAILED';
    return result;
  }
  result.tests.push({
    name: 'nodemailer_installed',
    passed: true,
    version: diagnostics.nodemailerVersion,
  });

  // Test 2: Check SMTP credentials
  if (!diagnostics.smtpUserConfigured || !diagnostics.smtpPasswordConfigured) {
    result.tests.push({
      name: 'smtp_credentials',
      passed: false,
      error: 'SMTP credentials not configured. Set SMTP_USER and SMTP_PASSWORD environment variables.',
      smtpUserSet: diagnostics.smtpUserConfigured,
      smtpPasswordSet: diagnostics.smtpPasswordConfigured,
    });
    result.overallStatus = 'FAILED';
    return result;
  }
  result.tests.push({
    name: 'smtp_credentials',
    passed: true,
  });

  // Test 3: Verify SMTP connection
  try {
    const nodemailer = require('nodemailer');
    const config = getEmailConfig();
    const transporter = nodemailer.createTransport(config);

    logger.info('Testing SMTP connection...', {
      host: config.host,
      port: config.port,
    });

    await transporter.verify();

    result.tests.push({
      name: 'smtp_connection',
      passed: true,
      message: 'SMTP connection verified successfully',
    });
    result.overallStatus = 'PASSED';
  } catch (error) {
    result.tests.push({
      name: 'smtp_connection',
      passed: false,
      error: error.message,
      errorCode: error.code,
      errorCommand: error.command,
      hint: getSmtpErrorHint(error),
    });
    result.overallStatus = 'FAILED';
  }

  return result;
}

/**
 * Get helpful hints for common SMTP errors
 */
function getSmtpErrorHint(error) {
  if (error.code === 'EAUTH') {
    return 'Authentication failed. For Gmail: 1) Enable 2FA, 2) Create an App Password at https://myaccount.google.com/apppasswords, 3) Use the App Password (not your regular password) for SMTP_PASSWORD';
  }
  if (error.code === 'ESOCKET' || error.code === 'ECONNECTION') {
    return 'Could not connect to SMTP server. Check SMTP_HOST and SMTP_PORT. For Gmail use smtp.gmail.com:587';
  }
  if (error.code === 'ETIMEDOUT') {
    return 'Connection timed out. The SMTP server may be unreachable or blocked by firewall.';
  }
  if (error.message && error.message.includes('Invalid login')) {
    return 'Invalid credentials. For Gmail, you must use an App Password, not your regular password.';
  }
  return null;
}

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
  const logContext = {
    feedbackId: feedbackData.feedbackId,
    userId: feedbackData.userId,
  };

  logger.info('=== FEEDBACK EMAIL: Starting send process ===', logContext);

  try {
    // Step 1: Get email config
    logger.info('Step 1/5: Loading email configuration...', logContext);
    const emailConfig = getEmailConfig();

    // Check if email is configured
    if (!emailConfig.auth.user || !emailConfig.auth.pass) {
      logger.warn('=== FEEDBACK EMAIL: SKIPPED - Email service not configured ===', {
        ...logContext,
        reason: 'SMTP credentials missing',
        smtpUserSet: !!emailConfig.auth.user,
        smtpPasswordSet: !!emailConfig.auth.pass,
        hint: 'Set SMTP_USER and SMTP_PASSWORD environment variables',
      });
      return { sent: false, reason: 'SMTP not configured' };
    }
    logger.info('Step 1/5: Email config loaded successfully', {
      ...logContext,
      host: emailConfig.host,
      port: emailConfig.port,
    });

    // Step 2: Load nodemailer
    logger.info('Step 2/5: Loading nodemailer...', logContext);
    let nodemailer;
    try {
      nodemailer = require('nodemailer');
      logger.info('Step 2/5: nodemailer loaded successfully', {
        ...logContext,
        version: require('nodemailer/package.json').version,
      });
    } catch (error) {
      logger.error('=== FEEDBACK EMAIL: FAILED - nodemailer not installed ===', {
        ...logContext,
        error: error.message,
        hint: 'Run: npm install nodemailer',
      });
      return { sent: false, reason: 'nodemailer not installed' };
    }

    // Step 3: Create transporter
    logger.info('Step 3/5: Creating SMTP transporter...', logContext);
    const transporter = nodemailer.createTransport(emailConfig);

    // Step 4: Verify connection
    logger.info('Step 4/5: Verifying SMTP connection...', logContext);
    try {
      await transporter.verify();
      logger.info('Step 4/5: SMTP connection verified successfully', logContext);
    } catch (verifyError) {
      logger.error('=== FEEDBACK EMAIL: FAILED - SMTP verification failed ===', {
        ...logContext,
        error: verifyError.message,
        errorCode: verifyError.code,
        hint: getSmtpErrorHint(verifyError),
      });
      throw verifyError;
    }

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

    // Step 5: Send email
    logger.info('Step 5/5: Sending email...', {
      ...logContext,
      recipients: recipientEmails,
      subject: `JEEVibe Feedback - ${ratingStars} Rating`,
    });

    const info = await transporter.sendMail({
      from: `"JEEVibe Feedback" <${emailConfig.auth.user}>`,
      to: recipientEmails.join(', '),
      subject: `JEEVibe Feedback - ${ratingStars} Rating from User ${feedbackData.userId.substring(0, 8)}`,
      text: textContent,
      html: htmlContent,
    });

    logger.info('=== FEEDBACK EMAIL: SUCCESS ===', {
      ...logContext,
      messageId: info.messageId,
      response: info.response,
      accepted: info.accepted,
      rejected: info.rejected,
      recipients: recipientEmails,
    });

    return {
      sent: true,
      messageId: info.messageId,
      recipients: recipientEmails,
    };
  } catch (error) {
    logger.error('=== FEEDBACK EMAIL: FAILED ===', {
      ...logContext,
      error: error.message,
      errorCode: error.code,
      errorCommand: error.command,
      stack: error.stack,
      hint: getSmtpErrorHint(error),
    });
    throw error;
  }
}

module.exports = {
  sendFeedbackEmail,
  getEmailDiagnostics,
  testEmailConnection,
};
