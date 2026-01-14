# Disable Email Notifications for Feedback

## Quick Disable

To disable email notifications for feedback, simply **don't set** the SMTP environment variables on your backend:

**On Render.com (or your hosting):**
- Remove or leave empty: `SMTP_USER`
- Remove or leave empty: `SMTP_PASSWORD`

**The feedback will still be saved to Firestore** - you just won't get email notifications.

## How It Works

The code already checks if SMTP is configured:
- ✅ If `SMTP_USER` and `SMTP_PASSWORD` are set → Emails are sent
- ✅ If they're not set → Emails are skipped, feedback still saved

## Important Note

**Disabling email will NOT fix the iOS build processing issue** because:
- Email sending happens on the backend (Node.js)
- The iOS app still uses encryption via Firebase and HTTPS
- Apple checks what the iOS app uses, not the backend

**To fix the build issue, you still need to:**
1. Answer Export Compliance in App Store Connect (App Information level)
2. Wait for processing to complete

## Re-enable Later

When you want to re-enable email notifications:
1. Set `SMTP_USER` and `SMTP_PASSWORD` in your backend environment
2. Restart the backend service
3. Emails will automatically start sending again
