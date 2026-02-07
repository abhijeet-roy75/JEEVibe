# Student Data Extraction Script

## Overview

This script extracts **all data** collected for a student across the JEEVibe platform, including:

- ✅ User Profile & Subscription
- ✅ Initial Assessment (30-question diagnostic)
- ✅ Daily Quiz History (all quizzes with responses)
- ✅ Chapter Practice Sessions (all sessions with responses)
- ✅ Mock Tests (all tests with 90-question responses)
- ✅ Snap & Solve History (all snaps with solutions)
- ✅ AI Tutor Conversations (all conversations with messages)
- ✅ Theta Evolution (weekly snapshots)
- ✅ Usage & Engagement Metrics (daily usage logs)

## Prerequisites

### Required Firestore Indexes

This script requires 4 composite indexes to be deployed to Firestore. Deploy them once before using the script:

```bash
# From project root
firebase deploy --only firestore:indexes
```

See [INDEX-CHANGES.md](../firebase/INDEX-CHANGES.md) for details on the required indexes.

## Usage

### Basic Usage

```bash
# Extract data for a student by phone number
node backend/scripts/extract-student-data.js +919876543210
```

This will:
1. Search for the user by phone number
2. Extract all data from Firestore
3. Generate a JSON file: `student_data_<timestamp>.json`
4. Print a summary to console

### Custom Output File

```bash
# Save to a specific file
node backend/scripts/extract-student-data.js +919876543210 --output john_doe_data.json
```

### Pretty Print

```bash
# Format JSON with indentation (easier to read)
node backend/scripts/extract-student-data.js +919876543210 --format pretty
```

### Help

```bash
# Show usage instructions
node backend/scripts/extract-student-data.js --help
```

## Output Format

The script generates a comprehensive JSON file with this structure:

```json
{
  "extraction_timestamp": "2026-02-07T10:30:00.000Z",
  "user_id": "abc123",
  "phone_number": "+919876543210",

  "profile": {
    "basic_info": { /* name, email, phone, dates */ },
    "jee_info": { /* target exam, coaching, state */ },
    "subscription": { /* tier, status, trial dates */ },
    "learning_metrics": { /* theta, percentile, accuracy */ },
    "engagement": { /* streak, quiz count, test count */ }
  },

  "assessment": {
    "count": 1,
    "assessments": [
      {
        "assessment_id": "assessment_123",
        "completed_at": "2026-01-15T08:00:00.000Z",
        "total_questions": 30,
        "correct_answers": 18,
        "overall_accuracy": 60.0,
        "initial_theta": 0.2,
        "initial_percentile": 57.9,
        "subject_accuracy": { /* physics, chemistry, math */ },
        "subject_stats": { /* per-subject breakdown */ },
        "responses": [ /* 30 response objects */ ]
      }
    ]
  },

  "daily_quizzes": {
    "total_quizzes": 45,
    "completed_quizzes": 42,
    "monthly_stats": {
      "2026-01": { /* aggregated stats for January */ },
      "2026-02": { /* aggregated stats for February */ }
    },
    "quizzes": [ /* array of all quiz objects */ ]
  },

  "chapter_practice": {
    "total_sessions": 23,
    "completed_sessions": 20,
    "chapter_stats": {
      "physics_laws_of_motion": {
        "total_sessions": 5,
        "accuracy": 72.5,
        "theta_improvement": { "min": -0.1, "max": 0.3, "avg": 0.15 }
      },
      /* ... other chapters ... */
    },
    "sessions": [ /* array of all session objects */ ]
  },

  "mock_tests": {
    "total_tests": 3,
    "completed_tests": 2,
    "tests": [ /* array of all test objects with 90 responses each */ ]
  },

  "snap_history": {
    "total_snaps": 67,
    "successful_solutions": 64,
    "subject_breakdown": { "physics": 25, "chemistry": 20, "mathematics": 22 },
    "snaps": [ /* array of all snap objects */ ]
  },

  "ai_tutor": {
    "total_conversations": 8,
    "total_messages": 42,
    "conversations": [ /* array of all conversation objects */ ]
  },

  "theta_evolution": {
    "total_snapshots": 12,
    "snapshots": [ /* weekly theta snapshots */ ]
  },

  "usage_metrics": {
    "total_days": 45,
    "daily_usage": [ /* daily usage log for each day */ ]
  }
}
```

## Example Output

When you run the script, you'll see:

```
═══════════════════════════════════════════════════════
           STUDENT DATA EXTRACTION TOOL
═══════════════════════════════════════════════════════

🔍 Searching for student with phone: +919876543210

✅ Found user: abc123def456

📋 Extracting user profile...
📝 Extracting initial assessment...
📅 Extracting daily quiz history...
📚 Extracting chapter practice sessions...
🎯 Extracting mock test data...
📸 Extracting snap & solve history...
🤖 Extracting AI tutor conversations...
📈 Extracting theta evolution...
📊 Extracting usage metrics...

═══════════════════════════════════════════════════════
           EXTRACTION SUMMARY
═══════════════════════════════════════════════════════
Name: John Doe
Email: john.doe@example.com
Subscription: PRO
Overall Theta: 0.45
Percentile: 67.3%

Data Collected:
  - Initial Assessments: 1
  - Daily Quizzes: 45 (42 completed)
  - Chapter Practice: 23 sessions
  - Mock Tests: 3 (2 completed)
  - Snap & Solve: 67
  - AI Tutor: 8 conversations
  - Theta Snapshots: 12
  - Daily Usage Logs: 45 days
═══════════════════════════════════════════════════════

✅ Data saved to: /path/to/student_data_1707304800000.json
📦 File size: 245.67 KB
```

## Use Cases

### 1. Student Performance Analysis

Extract a student's data to analyze:
- Learning progress over time (theta evolution)
- Subject-wise strengths and weaknesses
- Chapter mastery levels
- Quiz and test performance trends

### 2. Support & Debugging

When a student reports an issue:
- Extract their complete data for investigation
- Verify subscription status and tier limits
- Check question history and responses
- Review theta calculation accuracy

### 3. Data Export (GDPR/DPDPA)

If a student requests their data:
- Extract all their data in a portable format
- Provide a comprehensive JSON file
- Ensure compliance with data protection laws

### 4. Analytics & Research

For building analytics dashboards:
- Extract sample student data
- Identify patterns and trends
- Test analytics algorithms
- Generate sample reports

### 5. Migration & Backup

Before making schema changes:
- Extract data for backup
- Test migration scripts
- Verify data integrity

## Data Privacy

⚠️ **Important Security Notes:**

1. **Phone Number Required**: The script requires a phone number to identify the user (no direct user ID access for security)

2. **Authentication**: The script uses Firebase Admin SDK, which requires proper credentials

3. **Data Sensitivity**: The extracted JSON contains personally identifiable information (PII). Handle with care:
   - Do not commit to version control
   - Do not share publicly
   - Store securely
   - Delete after use

4. **Access Control**: Only authorized personnel (admins, support staff) should run this script

## Technical Details

### Dependencies

- Node.js 16+
- Firebase Admin SDK
- Firestore database access

### Collections Accessed

The script reads from these Firestore collections:

- `users/{userId}` - User profile
- `users/{userId}/assessments/` - Initial assessments
- `users/{userId}/daily_quizzes/` - Daily quizzes
- `users/{userId}/chapter_sessions/` - Chapter practice
- `users/{userId}/mock_tests/` - Mock tests
- `users/{userId}/snap_history/` - Snap & solve
- `users/{userId}/tutor_conversations/` - AI tutor
- `users/{userId}/theta_snapshots/` - Theta evolution
- `daily_usage` - Usage metrics

### Performance

- **Extraction Time**: ~5-15 seconds (depends on data volume)
- **File Size**: ~100-500 KB per student (varies by activity)
- **Rate Limiting**: No rate limits (uses Admin SDK)

## Troubleshooting

### Error: User not found

```
❌ Error: No user found with phone number: +919876543210
```

**Solution**: Verify the phone number format includes country code (e.g., `+91` for India)

### Error: Permission denied

```
❌ Error: Insufficient permissions to access collection
```

**Solution**: Ensure Firebase Admin SDK credentials are properly configured in `backend/src/config/firebase.js`

### Error: Module not found

```
❌ Error: Cannot find module '../src/config/firebase'
```

**Solution**: Run the script from the project root directory:
```bash
cd /path/to/JEEVibe
node backend/scripts/extract-student-data.js +919876543210
```

## Related Documentation

- [Data Collection Reference](../../docs/DATA-COLLECTION-REFERENCE.md) - Complete data schema reference
- [Analytics Guide](../../docs/03-features/ANALYTICS-GUIDE.md) - How to use extracted data for analytics
- [Firestore Schema](../../docs/FIRESTORE-SCHEMA.md) - Database schema documentation

## Future Enhancements

Planned improvements:

- [ ] Export to CSV format
- [ ] Filter by date range
- [ ] Export specific data categories only
- [ ] Batch export for multiple users
- [ ] Anonymization option for research
- [ ] Direct upload to analytics platforms

---

**Script Version:** 1.0
**Last Updated:** 2026-02-07
**Maintained By:** JEEVibe Engineering Team
