# Weekly & Daily MPA Report Implementation Plan

**Document Version:** 1.0
**Date:** February 10, 2026
**Owner:** Development Team
**Purpose:** Implementation plan for Mistake Pattern Analytics (MPA) reports for both daily and weekly student emails

---

## Overview
Implement the Weekly Mistake Pattern Analytics (MPA) Report as specified in `JEEVibe_Weekly_MPA_Report_Specification.md` to replace the current email system. Additionally, create a condensed Daily MPA Report using the same analytics engine.

---

## Current State Analysis

### Existing Email Infrastructure ✅
- **Email Provider**: Resend API (`studentEmailService.js`)
- **Cron Endpoints**:
  - Daily: `https://jeevibe-thzi.onrender.com/api/cron/daily-student-emails` (8 AM IST)
  - Weekly: `https://jeevibe-thzi.onrender.com/api/cron/weekly-student-emails` (Sunday 6 PM IST)
- **Security**: CRON_SECRET token required
- **Current Weekly Email**: Basic summary (questions solved, accuracy, focus areas)

### Data Availability ✅
- **User Answers**: `student_answer` field captured in both `daily_quiz_responses` and `chapter_practice_responses`
- **Question Metadata**: Denormalized (subject, chapter, IRT params) - NO JOIN NEEDED
- **Solution Data**: `solution_steps`, `key_insight`, `distractor_analysis`, `common_mistakes` stored with responses
- **Weekly Snapshots**: Created every Sunday at 11:59 PM with historical theta data

### Gap Analysis ❌
**What's Missing for MPA Report:**

1. **Wins Detection Algorithm**: No logic to identify mastery, improvement, consistency wins
2. **Issue Pattern Detection**: No ROI-based issue clustering (chapter gaps, concept gaps, error patterns)
3. **Personalized Content Generation**: No adaptive tone/messaging by student level
4. **Detailed Study Recommendations**: Current focus areas are simple, not actionable 4-bullet guidance
5. **Potential Improvement Calculations**: No projection of accuracy gains if issues fixed
6. **Report Storage**: Weekly reports not saved to Firestore for tracking
7. **Email Templates**: Current HTML is basic summary, need full MPA template

---

## Implementation Plan

### Phase 1: MPA Analytics Engine (Week 1-2)
**Goal**: Build core pattern detection and ROI scoring algorithms

#### 1.1 Create MPA Service (`backend/src/services/mpaReportService.js`)
**New Service**: Pattern detection, win identification, ROI calculation

```javascript
// Key functions to implement:
- generateWeeklyReport(userId, weekStart, weekEnd)
- generateDailyReport(userId, date)
- detectWins(studentData, timeframe) → [win1, win2, win3]
- identifyTopIssues(incorrectQuestions) → [issue1, issue2, issue3]
- calculateROIScore(pattern) → number (0-1)
- estimateImprovement(pattern, totalQuestions) → % gain
- adaptContentToStudentLevel(accuracy) → tone adjustments
```

**Data Sources**:
- `daily_quiz_responses/{userId}/responses` (filtered by answered_at)
- `chapter_practice_responses/{userId}/responses` (filtered by answered_at)
- `users/{userId}` (theta data, percentile, streak info)
- `theta_history/{userId}/snapshots` (baseline comparison)

**Pattern Detection Logic**:
```javascript
// Chapter Clusters: Group by related chapters (mechanics, electricity, etc.)
// Concept Gaps: Group by concepts_tested field
// Error Patterns: Group by distractor_analysis (why they picked wrong answer)

// ROI Formula:
ROI = (frequency × 0.4) + (impact × 0.3) + (ease_of_fix × 0.3)
```

#### 1.2 Create Win Detection Algorithm
**Win Types to Detect** (spec section 4.1):
1. Subject/Chapter Mastery (60%+ subject, 80%+ chapter)
2. Improvement (10%+ from baseline)
3. Consistency (3+ days practiced)
4. Milestones (100 questions, 5-day streak, etc.)
5. Tough Questions (2+ correct with IRT > 2.0)
6. Recovery Pattern (accuracy trending up)

**Fallback**: If no wins, show effort win ("You Showed Up")

#### 1.3 Create Issue Detection Algorithm
**Pattern Groups** (spec section 4.2):
1. **Chapter Clusters**: Mistakes across related chapters (min 2 mistakes)
2. **Concept Gaps**: Mistakes on same concept across chapters (min 2)
3. **Error Patterns**: Same mistake type (distractor pattern, min 3)

**Priority Assignment**:
- Sort by ROI score (descending)
- Return top 3
- Assign icons: 🥇 🥈 🥉

#### 1.4 Study Recommendation Generator
**For each issue, generate**:
- **What's wrong**: Student-friendly description
- **Root cause**: Why pattern is happening (contrast with strong areas)
- **What to study**: 3-4 specific topics with guidance
- **Suggested practice**: Quantity + specific focus

**Use existing data**:
- `common_mistakes` field from responses
- `key_insight` field
- `distractor_analysis` for error type identification

---

### Phase 2: Report Storage & Tracking (Week 2)
**Goal**: Store generated reports for analytics and user history

#### 2.1 Create Firestore Collection Structure
**New Collection**: `users/{userId}/weekly_reports/{weekId}`

```javascript
{
  week_id: "2026-02-10",
  week_start: "2026-02-03",
  week_end: "2026-02-09",
  generated_at: Timestamp,

  summary: {
    total_questions: 60,
    correct: 31,
    incorrect: 29,
    accuracy: 51.7,
    days_practiced: 3,
    total_time_seconds: 2700
  },

  by_subject: {
    physics: { total: 22, correct: 9, accuracy: 41 },
    chemistry: { total: 19, correct: 13, accuracy: 68 },
    mathematics: { total: 19, correct: 9, accuracy: 47 }
  },

  wins: [
    { rank: 1, type: "mastery", title: "Chemistry Mastery", ... },
    { rank: 2, type: "improvement", title: "Visible Improvement", ... },
    { rank: 3, type: "consistency", title: "Practice Consistency", ... }
  ],

  top_issues: [
    {
      rank: 1,
      priority: "highest",
      title: "Physics Mechanics Fundamentals",
      frequency: 8,
      percentage: 28,
      potential_gain: 15,
      roi_score: 0.85,
      what_wrong: "...",
      root_cause: "...",
      what_to_study: ["...", "...", "...", "..."],
      suggested_practice: "...",
      affected_chapters: ["Electrostatics", "Laws of Motion", ...]
    },
    // issue 2, 3...
  ],

  potential_improvement: {
    current_accuracy: 52,
    potential_accuracy: 80,
    percentile_projection: 15 // top X%
  },

  email_sent: true,
  email_sent_at: Timestamp,
  email_opened: false,
  email_clicked: false
}
```

#### 2.2 Add Daily Report Storage (Optional)
**New Collection**: `users/{userId}/daily_reports/{dateId}`

Similar structure to weekly, but simplified:
- 1 win instead of 3
- 1 issue instead of 3
- Yesterday's summary only

---

### Phase 3: Email Template System (Week 2-3)
**Goal**: Create MPA email templates for both weekly and daily reports

#### 3.1 Weekly Email Template
**Update** `studentEmailService.js` - Add `sendWeeklyMPAReport()`

**Template Structure** (from spec section 2.1):
```
━━━ JEEVIBE WEEKLY REPORT ━━━
Week of [Date Range]

👩‍🏫 Hi [Name],
Great week of practice! You completed [N] questions...

━━━ 🎉 YOUR WINS THIS WEEK ━━━
[Win 1 with metrics and encouragement]
─────────────────────────────
[Win 2]
─────────────────────────────
[Win 3]

━━━ 📊 OVERALL PERFORMANCE ━━━
[N] questions | [X]% accuracy
By Subject: [breakdown with status icons]

━━━ 🎯 YOUR TOP 3 ISSUES TO FIX ━━━
🥇 PRIORITY 1: [Issue Name]
Impact: [N] mistakes ([X]%)
Potential gain: +[Y]% accuracy

What's wrong: [...]
Root cause: [...]
What to study:
• [Topic 1 - specific guidance]
• [Topic 2]
• [Topic 3]
• [Topic 4]
Suggested practice: [...]

─────────────────────────────
🥈 PRIORITY 2: [...]
🥉 PRIORITY 3: [...]

━━━ 💡 HOW TO USE THIS REPORT ━━━
Option 1: Fix Priority 1 first (recommended)
Option 2: Work on all 3 simultaneously
Option 3: Pick what feels right

━━━ 📈 POTENTIAL IMPROVEMENT ━━━
Current accuracy:    52% [progress bar]
Potential accuracy:  80% [progress bar]
This would put you in the top 15% of students.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Three priorities. Your timeline. Real improvement.
[CTA Buttons]
```

#### 3.2 Daily Email Template
**Add** `sendDailyMPAReport()` to `studentEmailService.js`

**Structure**:
```
━━━ JEEVIBE DAILY REPORT ━━━
Day [X] | [Date]

👩‍🏫 Hi [Name],
Yesterday you completed [N] questions with [X]% accuracy.

━━━ 🎉 YESTERDAY'S WIN ━━━
[Top win from yesterday - 1 only]

━━━ 🎯 TOP ISSUE TO FIX TODAY ━━━
[Highest ROI issue from yesterday]
Impact: [N] mistakes
Quick fix: [2-3 bullet study tips]
Practice: [specific recommendation]

━━━ 📊 YOUR STREAK ━━━
[X] days 🔥 | Keep going!

[Start Today's Quiz] [Practice Focus Chapter]
```

**Key Differences from Weekly**:
- **Scope**: Yesterday's data only (not 7 days)
- **Length**: ~200 words (vs 750 for weekly)
- **Content**: 1 win + 1 issue (vs 3 wins + 3 issues)
- **Read time**: 1 minute (vs 3-4 minutes)
- **Minimum threshold**: 5+ questions (vs 40+ for weekly)

#### 3.3 Adaptive Tone by Student Level
**High Performer (75%+)**:
- Greeting: "Excellent week!"
- Tone: Challenging
- Encouragement: Moderate

**Average (55-75%)**:
- Greeting: "Great week!"
- Tone: Balanced
- Encouragement: High

**Struggling (<55%)**:
- Greeting: "Good effort!"
- Tone: Supportive
- Encouragement: Very high
- Extra message: "Every question you practice is progress..."

#### 3.4 Email Metadata
```javascript
// Weekly
{
  from: { email: process.env.RESEND_FROM_EMAIL, name: "Priya Ma'am" },
  subject: `Your JEEVibe Weekly Report - ${dateRange}`,
  tracking: { track_opens: true, track_clicks: true }
}

// Daily
{
  from: { email: process.env.RESEND_FROM_EMAIL, name: "Priya Ma'am" },
  subject: `Day ${streak} 🔥 | Found your top mistake from yesterday`,
  tracking: { track_opens: true, track_clicks: true }
}
```

---

### Phase 4: Cron Endpoint Updates (Week 3)
**Goal**: Integrate MPA service into both daily and weekly cron jobs

#### 4.1 Update Weekly Cron (`/api/cron/weekly-student-emails`)
**File**: `backend/src/routes/cron.js`

**Current Flow**:
```javascript
1. Fetch users who practiced this week (40+ questions)
2. Call studentEmailService.sendWeeklyEmail(user)
3. Log results
```

**New Flow**:
```javascript
1. Fetch eligible users (40+ questions, email_preferences.weekly_digest = true)
2. For each user:
   a. Call mpaReportService.generateWeeklyReport(userId, weekStart, weekEnd)
   b. Store report: mpaReportService.storeWeeklyReport(userId, report)
   c. Send email: studentEmailService.sendWeeklyMPAReport(user, report)
   d. Log success/failure
3. Return summary: { sent: X, failed: Y, skipped: Z }
```

#### 4.2 Update Daily Cron (`/api/cron/daily-student-emails`)
**File**: `backend/src/routes/cron.js`

**New Flow**:
```javascript
1. Fetch eligible users (email_preferences.daily_digest = true)
2. For each user:
   a. Call mpaReportService.generateDailyReport(userId, yesterday)
   b. If report exists (5+ questions):
      - Send email: studentEmailService.sendDailyMPAReport(user, report)
   c. Else:
      - Send streak reminder: studentEmailService.sendStreakReminder(user)
3. Return summary: { sent: X, failed: Y, skipped: Z }
```

#### 4.3 Error Handling
```javascript
try {
  const report = await generateWeeklyReport(userId, weekStart, weekEnd);
  await storeWeeklyReport(userId, report);
  await sendWeeklyMPAReport(user, report);
} catch (error) {
  console.error(`MPA report failed for ${userId}:`, error);
  // Fallback to basic weekly email or skip
}
```

---

### Phase 5: Testing & Validation (Week 3-4)
**Goal**: Test with real user data before full rollout

#### 5.1 Manual Test Script
**Create**: `backend/scripts/test-mpa-report.js`

```javascript
// Test weekly report
const userId = 'test_user_id';
const weekStart = new Date('2026-02-03');
const weekEnd = new Date('2026-02-09');

const weeklyReport = await generateWeeklyReport(userId, weekStart, weekEnd);
console.log(JSON.stringify(weeklyReport, null, 2));

// Test daily report
const dailyReport = await generateDailyReport(userId, new Date('2026-02-09'));
console.log(JSON.stringify(dailyReport, null, 2));
```

#### 5.2 Test Cases
1. **High performer (78% accuracy)**: Challenging tone, polish-focused issues
2. **Average student (52% accuracy)**: Balanced tone, foundational issues
3. **Struggling (38% accuracy)**: Supportive tone, basic formula/reading issues
4. **New student (first week)**: Simplified report, habit-building focus
5. **Inactive student (<40 questions)**: Should skip or send encouragement

#### 5.3 Email Preview
- Test HTML rendering on mobile (Gmail, iOS Mail)
- Check progress bar rendering (ASCII fallback)
- Verify CTA button links work
- Test unsubscribe flow

---

### Phase 6: Gradual Rollout (Week 4-5)
**Goal**: Launch to subset, monitor, then scale

#### 6.1 Beta Launch (100 users)
```javascript
// In cron endpoint, add beta filter:
const eligibleUsers = allUsers.filter(user =>
  user.beta_features?.mpa_reports === true &&
  weekData.total_questions >= 40
);
```

#### 6.2 Monitoring Metrics
**Track in admin dashboard**:
- Reports sent/failed/skipped
- Email open rates (via Resend)
- Email click rates (CTA buttons)
- Student behavior after email (next-day practice, priority chapter practice)
- Accuracy improvement week-over-week

#### 6.3 Full Rollout
- Remove beta filter
- Monitor server load (Render.com)
- Set up alerts for failed email batches

---

## Daily vs Weekly MPA Comparison

| Dimension | Daily MPA | Weekly MPA |
|-----------|-----------|------------|
| **Time Window** | Yesterday (24 hours) | Last 7 days |
| **Questions Threshold** | 5+ questions | 40+ questions |
| **Wins** | 1 win (top only) | 2-3 wins (variety) |
| **Issues** | 1 issue (highest ROI) | 3 issues (prioritized) |
| **Word Count** | ~200 words | ~750 words |
| **Read Time** | 1 minute | 3-4 minutes |
| **Tone** | Quick & actionable | Comprehensive & strategic |
| **Send Time** | 8 AM IST (before quiz) | Sunday 6 PM IST (weekend planning) |
| **CTA** | "Fix this today" | "Plan your week" |
| **Purpose** | Immediate feedback | Strategic planning |

---

## Critical Files to Modify

### New Files
1. **`backend/src/services/mpaReportService.js`** - Core MPA analytics engine (weekly + daily)
2. **`backend/scripts/test-mpa-report.js`** - Manual testing script

### Modified Files
1. **`backend/src/services/studentEmailService.js`** - Add `sendWeeklyMPAReport()` and `sendDailyMPAReport()`
2. **`backend/src/routes/cron.js`** - Update both daily and weekly endpoints
3. **`backend/src/services/analyticsService.js`** - May need helper functions for focus area analysis

### Configuration
1. **Firestore**: Add `users/{userId}/weekly_reports` and `users/{userId}/daily_reports` collection indexes
2. **Resend**: Ensure tracking enabled for open/click rates
3. **cron-job.org**: No changes needed (same schedule)

---

## Verification Plan

### End-to-End Test
1. **Generate report manually**: Run `test-mpa-report.js` with real user data
2. **Verify report structure**: Check all sections (wins, issues, recommendations)
3. **Verify storage**: Confirm report saved to Firestore with correct schema
4. **Send test email**: Use Resend sandbox to preview HTML
5. **Trigger cron manually**: POST to cron endpoints with CRON_SECRET
6. **Check logs**: Verify reports sent, track failures
7. **Monitor metrics**: Open rates, click rates, student behavior changes

### Data Quality Checks
- [ ] User answers captured correctly (`student_answer` field)
- [ ] Question metadata complete (subject, chapter, IRT params)
- [ ] Distractor analysis available for error pattern detection
- [ ] Weekly snapshots created for baseline comparison
- [ ] Streak data accurate for consistency wins

### Email Quality Checks
- [ ] Mobile rendering (Gmail app, iOS Mail)
- [ ] Progress bar displays correctly (or fallback text)
- [ ] CTA buttons link to correct screens
- [ ] Unsubscribe link works
- [ ] Subject lines A/B tested (if applicable)

---

## Success Criteria

### Engagement Metrics (from spec section 8.5)
- Email open rate: **>40%**
- Email click rate: **>15%**
- Reply rate: **>5%**

### Behavioral Metrics
- Next-day practice: **>60%** (students practice within 24 hours)
- Priority chapter practice: **>40%** (practice Priority 1 issue)

### Learning Outcomes
- Average improvement: **>5%** (week-over-week accuracy)
- Students improving: **>70%** (majority show improvement)

### Negative Metrics
- Unsubscribe rate: **<1%**
- Spam complaints: **<0.1%**

---

## Timeline Estimate

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Phase 1: MPA Analytics Engine | 5-7 days | `mpaReportService.js` working for both daily and weekly |
| Phase 2: Report Storage | 2-3 days | Firestore collections created |
| Phase 3: Email Templates | 4-5 days | HTML templates for both daily and weekly |
| Phase 4: Cron Integration | 2-3 days | Both endpoints updated |
| Phase 5: Testing | 3-4 days | All test cases pass |
| Phase 6: Beta Rollout | 3-4 days | 100 users receiving reports |
| **Total** | **~3-4 weeks** | Production-ready MPA reports (daily + weekly) |

---

## Open Questions for Discussion

1. **Subject line A/B testing**: Which variant to start with? (Personal vs Curiosity vs Direct vs Action)
2. **Send time optimization**: Keep Sunday 6 PM or test alternatives (Sunday 8 AM, Monday 6 AM)?
3. **Report history UI**: Should students view past weekly reports in the app? (mobile screens needed)
4. **Minimum questions threshold**: Keep 40 for weekly, 5 for daily?
5. **Beta cohort selection**: Random 100 or target specific segment (e.g., average performers)?
6. **Priya Ma'am voice**: Generate messages using OpenAI API or use template strings?
7. **Daily report storage**: Store all daily reports or skip storage to save Firestore reads?

---

## Dependencies & Prerequisites

### Backend Ready ✅
- Response data captures `student_answer` ✅
- Question metadata denormalized ✅
- Weekly snapshots created ✅
- Email service (Resend) configured ✅
- Cron endpoints secured ✅

### Needs Implementation ❌
- MPA analytics algorithms (weekly + daily logic) ❌
- ROI scoring logic ❌
- Win detection system ❌
- Issue clustering ❌
- Study recommendation generator ❌
- HTML email templates (2 versions) ❌
- Report storage collections ❌

---

## Next Steps

1. **Discuss open questions** above to finalize scope
2. **Review spec examples** (section 5) to align on output format
3. **Start Phase 1**: Build MPA analytics engine (`mpaReportService.js`)
4. **Set up test environment**: Identify 5-10 test users with varied performance levels
5. **Create Firestore indexes**: For `weekly_reports` and `daily_reports` collection queries

---

**End of Implementation Plan**

Version 1.0 | February 10, 2026
