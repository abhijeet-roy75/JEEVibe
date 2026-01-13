# Feedback Feature Implementation

## Overview

The feedback feature allows users to submit feedback directly from the app with automatic context capture. This feature is designed to be easily toggleable via environment variables.

## Features

1. **Session Tracking**: Tracks app opens (sessions) to show tooltip for first 3 sessions
2. **Feedback FAB**: Floating Action Button on the dashboard with tooltip behavior
3. **Auto-Context Capture**: Automatically captures:
   - Current screen/route name
   - User ID and profile data
   - App version, device model, OS version
   - Timestamp
   - Recent activity log (placeholder for future implementation)
4. **Email Notifications**: Sends formatted email notifications to configured recipients
5. **Feature Flag**: Easy on/off toggle via environment variable

## Mobile Implementation

### Files Created/Modified

1. **`mobile/lib/services/session_tracking_service.dart`**
   - Tracks app sessions (app opens)
   - Manages tooltip visibility for first 3 sessions

2. **`mobile/lib/services/feedback_service.dart`**
   - Handles feedback submission
   - Auto-captures device and app context

3. **`mobile/lib/widgets/feedback/feedback_fab.dart`**
   - Floating Action Button with tooltip
   - Shows tooltip for first 3 sessions (auto-dismisses after 5 seconds)

4. **`mobile/lib/screens/feedback/feedback_form_screen.dart`**
   - Feedback form with rating (1-5 stars) and text input
   - Auto-submits context with feedback

5. **`mobile/lib/services/api_service.dart`**
   - Added `submitFeedback()` method

6. **`mobile/lib/screens/assessment_intro_screen.dart`**
   - Integrated FeedbackFAB
   - Added session tracking on screen load

### Dependencies Added

- `device_info_plus: ^10.1.0` - For device model and OS version

## Backend Implementation

### Files Created/Modified

1. **`backend/src/routes/feedback.js`**
   - POST `/api/feedback` endpoint
   - Validates feedback data
   - Saves to Firestore `feedback` collection
   - Sends email notification (async)

2. **`backend/src/services/emailService.js`**
   - Email service using nodemailer
   - Sends formatted HTML emails
   - Configurable via environment variables

3. **`backend/src/index.js`**
   - Added feedback router

4. **`backend/package.json`**
   - Added `nodemailer: ^6.9.8` dependency

## Configuration

### Backend Environment Variables

Add these to your `.env` file or Render.com environment variables:

```bash
# Feature Flag (required)
ENABLE_FEEDBACK_FEATURE=true  # Set to 'true' or '1' to enable, anything else to disable

# Email Configuration (optional - emails won't send if not configured)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password  # Use App Password for Gmail

# Email Recipients (optional - defaults to aroy75@gmail.com, satishshetty@gmail.com)
FEEDBACK_EMAIL_RECIPIENTS=aroy75@gmail.com,satishshetty@gmail.com
```

### Gmail Setup (if using Gmail SMTP)

1. Enable 2-Step Verification on your Google account
2. Generate an App Password:
   - Go to Google Account → Security → 2-Step Verification → App passwords
   - Create a new app password for "Mail"
   - Use this password in `SMTP_PASSWORD`

### Firestore Collection

The feedback is stored in a `feedback` collection with the following structure:

```javascript
{
  userId: string,
  rating: number (1-5),
  description: string,
  context: {
    currentScreen: string,
    userId: string,
    userProfile: object,
    appVersion: string,
    deviceModel: string,
    osVersion: string,
    timestamp: string,
    recentActivity: array,
    submittedAt: Timestamp
  },
  status: 'new',
  createdAt: Timestamp
}
```

## Usage

### Enabling/Disabling the Feature

**To Enable:**
```bash
ENABLE_FEEDBACK_FEATURE=true
```

**To Disable:**
```bash
ENABLE_FEEDBACK_FEATURE=false
# or simply don't set it (defaults to disabled)
```

When disabled, the API returns a 503 error with message "Feedback feature is currently disabled".

### Mobile App Behavior

1. **First 3 Sessions**: 
   - Tooltip appears automatically for 5 seconds when dashboard loads
   - Tooltip can be dismissed by tapping the X or tapping outside
   - After 3 sessions, tooltip no longer appears

2. **After 3 Sessions**:
   - FAB is always visible (no tooltip, no animations)
   - User can tap FAB anytime to submit feedback

3. **Feedback Submission**:
   - User selects rating (1-5 stars)
   - User enters description (optional but recommended)
   - Context is automatically captured and sent
   - Success/error message is shown

## Email Notification Format

The email includes:
- Rating (visual stars)
- Feedback description
- User information (ID, name, email, phone)
- Device & app info (version, model, OS, screen)
- Recent activity (if available)
- Timestamp

## Testing

### Test Feedback Submission

1. Enable the feature flag: `ENABLE_FEEDBACK_FEATURE=true`
2. Open the app and navigate to the dashboard
3. Tap the feedback FAB (bottom right)
4. Select a rating and enter feedback
5. Submit
6. Check Firestore `feedback` collection for the new document
7. Check email inbox for notification (if email is configured)

### Test Feature Flag

1. Set `ENABLE_FEEDBACK_FEATURE=false`
2. Try to submit feedback
3. Should receive 503 error: "Feedback feature is currently disabled"

### Test Session Tracking

1. Reset app data or use a new device
2. Open app 3 times (each time dashboard loads = 1 session)
3. First 3 times: Tooltip should appear
4. 4th time and beyond: No tooltip, just FAB

## Future Enhancements

1. **Recent Activity Tracking**: Implement activity logging to capture last 3 user actions
2. **Feedback Management**: Admin dashboard to view and respond to feedback
3. **Feedback Categories**: Allow users to categorize feedback (bug, feature request, etc.)
4. **Screenshot Capture**: Allow users to attach screenshots with feedback
5. **In-App Notifications**: Show feedback status updates in the app

## Troubleshooting

### Email Not Sending

- Check SMTP credentials are correct
- Verify App Password is used (not regular password) for Gmail
- Check logs for email service errors
- Email service fails gracefully - feedback is still saved to Firestore

### Tooltip Not Showing

- Check session count: `SessionTrackingService().getSessionCount()`
- Check if tooltip was already seen: `SessionTrackingService().hasSeenFeedbackTooltip()`
- Reset if needed: `SessionTrackingService().reset()`

### Feature Not Working

- Verify `ENABLE_FEEDBACK_FEATURE=true` is set
- Check backend logs for errors
- Verify Firestore permissions allow writing to `feedback` collection
- Check mobile app logs for API errors
