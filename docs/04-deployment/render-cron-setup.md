# Render.com Cron Job Setup

## Overview

Since we're using Render.com for hosting (not cloud functions), we need to set up scheduled jobs using Render's Cron Jobs feature or an external cron service.

## Option 1: Render.com Cron Jobs (Recommended)

Render.com supports cron jobs that can call HTTP endpoints.

### Setup Steps

1. **Go to Render Dashboard** → Your Service → Cron Jobs

2. **Create New Cron Job:**
   - **Name:** `weekly-snapshots`
   - **Schedule:** `59 23 * * 0` (Every Sunday at 23:59)
   - **Command:** `curl -X POST https://your-app.onrender.com/api/cron/weekly-snapshots -H "X-Cron-Secret: YOUR_SECRET"`
   - Or use GET: `curl https://your-app.onrender.com/api/cron/weekly-snapshots?secret=YOUR_SECRET`

3. **Set Environment Variable:**
   - Add `CRON_SECRET` to your Render service environment variables
   - Generate a secure random string (e.g., `openssl rand -hex 32`)

4. **Test the Endpoint:**
   ```bash
   curl -X POST https://your-app.onrender.com/api/cron/weekly-snapshots \
     -H "X-Cron-Secret: YOUR_SECRET"
   ```

## Option 2: External Cron Service (Alternative)

If Render doesn't support cron jobs, use an external service:

### cron-job.org (Free)

1. **Sign up at** https://cron-job.org
2. **Create New Cron Job:**
   - **Title:** Weekly Theta Snapshots
   - **URL:** `https://your-app.onrender.com/api/cron/weekly-snapshots?secret=YOUR_SECRET`
   - **Schedule:** Every Sunday at 23:59
   - **Request Method:** GET or POST
   - **Add Header:** `X-Cron-Secret: YOUR_SECRET` (if using POST)

### EasyCron (Alternative)

Similar setup to cron-job.org

## Security

The cron endpoints are protected by `CRON_SECRET`:

1. **Set in Environment Variables:**
   ```bash
   CRON_SECRET=your-secure-random-string-here
   ```

2. **Pass in Request:**
   - **Header:** `X-Cron-Secret: YOUR_SECRET`
   - **Query Param:** `?secret=YOUR_SECRET`

3. **Generate Secure Secret:**
   ```bash
   # Using OpenSSL
   openssl rand -hex 32
   
   # Using Node.js
   node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
   ```

## Testing

### Manual Test

```bash
# Test with secret in header
curl -X POST https://your-app.onrender.com/api/cron/weekly-snapshots \
  -H "X-Cron-Secret: YOUR_SECRET" \
  -H "Content-Type: application/json"

# Test with secret in query
curl "https://your-app.onrender.com/api/cron/weekly-snapshots?secret=YOUR_SECRET"

# Test health endpoint (no auth required)
curl https://your-app.onrender.com/api/cron/health
```

### Expected Response

```json
{
  "success": true,
  "message": "Weekly snapshots created",
  "results": {
    "total": 150,
    "created": 148,
    "errors": 2
  },
  "requestId": "..."
}
```

## Cron Schedule Examples

- **Every Sunday at 23:59:** `59 23 * * 0`
- **Every Monday at 00:00:** `0 0 * * 1`
- **Every day at midnight:** `0 0 * * *`
- **Every hour:** `0 * * * *`

## Monitoring

1. **Check Logs:**
   - Render Dashboard → Your Service → Logs
   - Look for "Weekly snapshot cron job triggered"

2. **Verify Snapshots:**
   - Check Firestore `theta_history/{userId}/snapshots/` collection
   - Should see new snapshot every Sunday

3. **Error Handling:**
   - Errors are logged but don't fail the cron job
   - Check `results.errors` in response
   - Review error details in logs

## Troubleshooting

### Cron Job Not Running

1. **Check Render Dashboard:**
   - Verify cron job is enabled
   - Check execution history

2. **Test Endpoint Manually:**
   ```bash
   curl -X POST https://your-app.onrender.com/api/cron/weekly-snapshots \
     -H "X-Cron-Secret: YOUR_SECRET"
   ```

3. **Check Logs:**
   - Look for authentication errors
   - Check for application errors

### Authentication Errors

- Verify `CRON_SECRET` is set in environment variables
- Ensure secret matches in cron job command
- Check request headers/query params

### Performance Issues

- Weekly snapshots process all users sequentially
- For large user bases, consider:
  - Processing in batches
  - Using background jobs
  - Splitting by timezone

## Alternative: Background Worker

If cron jobs are unreliable, consider:

1. **Create a separate Worker service on Render**
2. **Run the script continuously with sleep:**
   ```javascript
   // Worker that runs weekly
   setInterval(async () => {
     const now = new Date();
     if (now.getDay() === 0 && now.getHours() === 23 && now.getMinutes() === 59) {
       await createWeeklySnapshotsForAllUsers();
     }
   }, 60000); // Check every minute
   ```

## What the Weekly Job Does

The weekly cron job performs two main tasks:

1. **Creates Weekly Theta Snapshots**
   - Creates snapshot of each user's theta values at end of week
   - Calculates changes from previous week
   - Stores in `theta_history/{userId}/snapshots/`

2. **Updates Question Statistics**
   - Aggregates question usage stats from all responses
   - Updates `questions/{questionId}.usage_stats` with:
     - `times_shown`: Total times question was presented
     - `times_correct`: Times answered correctly
     - `times_incorrect`: Times answered incorrectly
     - `avg_time_taken`: Average time taken
     - `accuracy_rate`: Percentage correct
   - Processes all questions in batches for performance

**Note:** Question stats are updated weekly (not real-time) for better performance.

## Summary

**Recommended Setup:**
1. Use Render.com Cron Jobs (if available)
2. Set `CRON_SECRET` environment variable
3. Schedule: Every Sunday at 23:59 (`59 23 * * 0`)
4. Endpoint: `POST /api/cron/weekly-snapshots` with `X-Cron-Secret` header

**Fallback:**
- Use external cron service (cron-job.org)
- Or create a background worker service

**Performance Note:**
- Weekly job processes all users and all questions
- For large datasets, may take several minutes
- Consider running during off-peak hours
- Monitor execution time and adjust if needed

