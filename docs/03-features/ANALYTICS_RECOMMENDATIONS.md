# JEEVibe Analytics Recommendations

*Created: January 2026*

## Current Data Assets

Based on your Firestore schema, you're capturing excellent data:
- **Performance**: Theta (ability estimates) per chapter/subject, percentiles, accuracy rates
- **Engagement**: Streaks, daily usage, time spent, quiz completions
- **Granular**: Per-question responses with time taken, difficulty, correctness
- **Progress**: Weekly snapshots, baseline comparisons, mastery status
- **Behavioral**: Day-of-week patterns, learning phase (exploration vs exploitation)

---

## A. Student-Facing Analytics (Email Reports)

### Daily Email: "Your JEE Prep Snapshot"

| Metric | Data Source | Why It Matters |
|--------|-------------|----------------|
| **Questions solved yesterday** | `responses` collection (count) | Accountability, sense of progress |
| **Accuracy rate** | `is_correct` aggregation | Quick performance check |
| **Time invested** | `time_taken_seconds` sum | Validates effort |
| **Streak status** | `practice_streaks.current_streak` | Gamification, habit building |
| **Today's focus chapter** | `calculateFocusAreas()` | Actionable next step |
| **Quick win** | Highest percentile chapter from yesterday | Motivation boost |

**Sample subject line**: "Day 12 🔥 | 47 questions | 78% accuracy | Focus: Thermodynamics"

---

### Weekly Email: "Your Week in Review"

| Section | Metrics | Data Source |
|---------|---------|-------------|
| **Summary Stats** | Total questions, total time, avg daily accuracy | Aggregate from `responses` |
| **Progress Chart** | Theta/percentile change vs last week | `theta_history/snapshots` |
| **Subject Breakdown** | Physics/Chemistry/Maths accuracy & percentile | `theta_by_subject` |
| **Top 3 Improving Chapters** | Biggest percentile gains | Compare current vs `week_end` snapshot |
| **Focus Areas** | Chapters needing attention with reasons | `calculateFocusAreas()` logic |
| **Comparison to Baseline** | Progress since assessment | `assessment_baseline` vs current `theta_by_chapter` |
| **Streak Milestone** | Current streak, longest streak, total days | `practice_streaks` |
| **Personalized Message** | Priya Ma'am encouragement | Existing `generatePriyaMaamMessage()` |

**Advanced (for Pro/Ultra):**
- Time-of-day performance analysis (when you study best)
- Question type breakdown (MCQ vs Numerical accuracy)
- Predicted JEE rank range based on overall_percentile

---

## B. Business Analytics Dashboard (Daily Monitoring)

### Tier 1: Health Metrics (Check Daily)

| Metric | Query | Red Flag |
|--------|-------|----------|
| **DAU** | Distinct users with activity today | <X% of MAU |
| **New signups** | Users with `createdAt` = today | Sudden drops |
| **Assessment completion rate** | `assessment.status = 'completed'` / total signups | <70% |
| **Quiz completion rate** | `status = 'completed'` / `status = 'active'` | <80% |
| **Churn signal** | Users with `lastActive` > 3 days ago | Rising trend |

### Tier 2: Engagement Depth (Check Daily)

| Metric | Query | What It Tells You |
|--------|-------|-------------------|
| **Avg quizzes/user/day** | `completed_quiz_count` delta | Engagement intensity |
| **Avg questions/user/day** | Sum of responses / active users | Learning volume |
| **Avg session time** | `quiz_duration_minutes` aggregation | Quality of engagement |
| **Feature adoption** | `daily_usage` by feature type | Which features drive value |
| **Streak distribution** | Histogram of `current_streak` | Habit formation health |

### Tier 3: Learning Outcomes (Check Weekly)

| Metric | Query | Insight |
|--------|-------|---------|
| **Avg theta improvement/week** | Week-over-week `overall_theta` change | Is learning happening? |
| **% students improving** | Users where theta increased | Product effectiveness |
| **Mastery progression** | Users moving FOCUS→GROWING→MASTERED | Goal achievement |
| **Chapter completion** | Chapters with >10 attempts per user | Content consumption |
| **Focus area distribution** | Which chapters are most common focus areas | Content gaps |

### Tier 4: Product Quality (Check Weekly)

| Metric | Query | Action |
|--------|-------|--------|
| **Question accuracy rates** | `questions.accuracy_rate` | Flag questions with <20% or >95% accuracy |
| **Avg time per question by difficulty** | Group by `difficulty_b` ranges | Identify too hard/easy questions |
| **Quiz abandonment** | `status = 'active'` with old `generated_at` | UX friction points |
| **AI Tutor usage correlation** | Tutor messages vs accuracy improvement | Feature value validation |

### Tier 5: Business Metrics (Check Weekly)

| Metric | Query | Why |
|--------|-------|-----|
| **Tier distribution** | Count by `subscriptions.tier` | Revenue mix |
| **Free→Pro conversion** | Users upgrading | Monetization health |
| **Pro/Ultra retention** | Active Pro/Ultra users vs total | Subscription stickiness |
| **Feature limit hits** | Users hitting daily limits | Upgrade signals |
| **Cohort retention** | Week 1/2/4/8 retention by signup week | Long-term viability |

---

## C. Alert-Worthy Conditions

Set up automated alerts for:

1. **DAU drops >20%** day-over-day
2. **Assessment completion <60%** for a day
3. **Quiz abandonment >25%** for a day
4. **Avg accuracy <40%** for new users (content/difficulty issue)
5. **Zero activity** from any Pro/Ultra user for 5+ days
6. **Question accuracy anomaly** (<15% or >98%)
7. **Streak breaks** for users with 7+ day streaks (win-back opportunity)

---

## D. Other Considerations

### 1. Data Infrastructure
- **Current gap**: No dedicated analytics database
- **Recommendation**: Set up BigQuery export from Firestore for complex queries (when at 5,000+ users)
- Benefits: SQL-based analysis, historical trends, ML-ready data

### 2. Email Infrastructure
- You have Resend integrated but only for feedback
- Can reuse `emailService.js` pattern for student reports
- Consider digest email service like Customer.io or Loops for templated campaigns

### 3. Admin Dashboard
- **Current gap**: No admin endpoints
- **Recommendation**: Build `/api/admin/` routes for:
  - User lookup and support
  - Content management (question flagging)
  - Real-time metrics dashboard

### 4. Cohort Analysis
- Track users by signup week/month
- Measure retention at 1, 7, 30, 60, 90 days
- Segment by: assessment score range, subscription tier, geography

### 5. A/B Testing Infrastructure
- Test different quiz lengths (10 vs 15 questions)
- Test focus area algorithms
- Test Priya Ma'am message styles

### 6. Predictive Analytics (Future)
- JEE score prediction based on theta trajectory
- Churn prediction (users likely to stop using)
- Optimal study time recommendations

### 7. Privacy & Compliance
- Student data is sensitive (minors)
- Ensure DPDP Act compliance (India's data protection law)
- Consider anonymization for aggregate analytics

### 8. Competitive Benchmarking
- "You're in the top X% of JEEVibe students"
- Subject-wise ranking among peers
- Optional: anonymous comparison to users at target colleges

---

## Implementation Plan (for <1,000 users, Firebase-only)

At your current scale, Firestore queries are sufficient. No need for BigQuery yet.

### Phase 1: Business Dashboard API (Backend)

Create `/api/admin/metrics` endpoints in `backend/src/routes/admin.js`:

```
GET /api/admin/metrics/daily-health
- DAU (users with activity today)
- New signups today
- Assessment completions today
- Quiz completions vs starts
- Users at risk (no activity 3+ days)

GET /api/admin/metrics/engagement
- Avg quizzes/user/day (last 7 days)
- Avg questions/user/day
- Feature usage breakdown (snap_solve, daily_quiz, ai_tutor)
- Streak distribution histogram

GET /api/admin/metrics/learning
- Avg theta change this week
- Mastery progression (FOCUS→GROWING→MASTERED counts)
- Most common focus chapters

GET /api/admin/metrics/content
- Questions with <20% or >95% accuracy
- Avg time per difficulty level
```

**Data source**: Query Firestore directly using collectionGroup queries (already have indexes)

**Frontend**: Simple admin page or export to Google Sheets initially

---

### Phase 2: Student Email System

#### 2a. Daily Email ("Your JEE Prep Snapshot")

Create `backend/src/services/studentEmailService.js`:
- Reuse existing `emailService.js` pattern with Resend
- Trigger: Cloud Scheduler at 8 AM IST daily

**Template content:**
```
Subject: Day {streak} 🔥 | {questions} questions | {accuracy}% | Focus: {chapter}

Hi {firstName},

Yesterday you solved {questions} questions with {accuracy}% accuracy.
{streak_message}

📍 Today's Focus: {focus_chapter}
   Reason: {focus_reason}

{priya_maam_message}

Keep going!
```

**Data needed** (all available):
- Yesterday's responses count and accuracy
- Current streak from `practice_streaks`
- Focus chapter from existing `calculateFocusAreas()`
- Priya Ma'am message from existing `generatePriyaMaamMessage()`

#### 2b. Weekly Email ("Your Week in Review")

Trigger: Cloud Scheduler on Sunday 6 PM IST

**Template content:**
```
Subject: Week {week_number} Report | {total_questions} questions | {percentile_change} percentile

Hi {firstName},

WEEKLY SUMMARY
━━━━━━━━━━━━━
Questions: {total} | Time: {hours}h {mins}m | Accuracy: {accuracy}%

SUBJECT PROGRESS
━━━━━━━━━━━━━━━
Physics:    {physics_percentile}% ({physics_change})
Chemistry:  {chem_percentile}% ({chem_change})
Maths:      {maths_percentile}% ({maths_change})

TOP IMPROVEMENTS 🚀
{improving_chapters_list}

FOCUS AREAS THIS WEEK
{focus_areas_list}

SINCE YOU STARTED
━━━━━━━━━━━━━━━━
Overall progress: {baseline_percentile}% → {current_percentile}%
Total questions: {lifetime_questions}
Streak record: {longest_streak} days

{priya_maam_message}
```

**Data needed** (all available):
- Weekly snapshot from `theta_history/snapshots`
- Comparison to previous week
- Assessment baseline comparison
- Streak data

---

### Phase 3: Automated Alerts

Create `backend/src/services/alertService.js`:
- Check conditions during daily cron
- Send Slack/email alerts to admin

**Alerts to implement:**
1. DAU drops >30% vs 7-day average
2. Assessment completion <50% for 2+ consecutive days
3. Any Pro/Ultra user inactive 5+ days (list them)
4. Question accuracy anomalies (auto-flag in Firestore)

---

### Cron Job Setup

Add to `backend/src/routes/cron.js`:

```javascript
// Existing: POST /api/cron/weekly-snapshots (Sundays 23:59 IST)

// New endpoints:
POST /api/cron/daily-student-emails   // 8 AM IST daily
POST /api/cron/weekly-student-emails  // Sunday 6 PM IST
POST /api/cron/daily-admin-report     // 9 AM IST daily (health metrics to Slack/email)
POST /api/cron/check-alerts           // Every 6 hours
```

Use Google Cloud Scheduler or Render Cron Jobs to trigger these.

---

### Files to Create/Modify

| File | Action |
|------|--------|
| `backend/src/routes/admin.js` | Create - admin metrics endpoints |
| `backend/src/services/adminMetricsService.js` | Create - aggregation queries |
| `backend/src/services/studentEmailService.js` | Create - student email generation |
| `backend/src/services/alertService.js` | Create - alert checking |
| `backend/src/templates/dailyEmail.html` | Create - daily email template |
| `backend/src/templates/weeklyEmail.html` | Create - weekly email template |
| `backend/src/routes/cron.js` | Modify - add new cron endpoints |
| `backend/src/routes/index.js` | Modify - register admin routes |

---

### Verification

1. **Admin metrics**: Call endpoints manually, verify counts match Firebase Console
2. **Student emails**: Send test emails to team accounts first
3. **Alerts**: Manually trigger threshold conditions in test environment
4. **Cron jobs**: Test with manual HTTP calls before scheduling

---

### Future Enhancements (when you grow)

- BigQuery export for complex cohort analysis (at 5,000+ users)
- Predictive churn scoring with ML
- JEE rank prediction based on theta trajectory
- A/B testing infrastructure

---

## E. Infrastructure Recommendations

### Cron Jobs (Render Free Tier Limitation)

Render's free tier doesn't support cron jobs. Here are alternatives:

| Option | Cost | Complexity | Notes |
|--------|------|------------|-------|
| **cron-job.org** | Free | Very Easy | Just provide URL + schedule. Calls your Render endpoints |
| **GitHub Actions** | Free | Easy | Add workflow YAML, uses `schedule` trigger |
| **Google Cloud Scheduler** | ~$0.10/mo | Medium | Already have GCP via Firebase |
| **Firebase Cloud Functions** | Pay-as-you-go | Medium | Requires Blaze plan upgrade |

**Recommendation: Start with cron-job.org**

Setup (5 minutes):
1. Go to https://cron-job.org
2. Create free account
3. Add jobs:
   - `POST https://your-render-url/api/cron/daily-student-emails` at 8:00 AM IST (2:30 AM UTC)
   - `POST https://your-render-url/api/cron/weekly-student-emails` on Sundays 6:00 PM IST (12:30 PM UTC)
   - `POST https://your-render-url/api/cron/check-alerts` every 6 hours
4. Add header: `Authorization: Bearer YOUR_CRON_SECRET`

**Alternative: GitHub Actions (free, in your repo)**

Create `.github/workflows/cron-jobs.yml`:
```yaml
name: Scheduled Analytics Jobs
on:
  schedule:
    - cron: '30 2 * * *'  # Daily 8 AM IST
    - cron: '30 12 * * 0' # Sunday 6 PM IST
jobs:
  trigger-emails:
    runs-on: ubuntu-latest
    steps:
      - run: |
          curl -X POST "${{ secrets.BACKEND_URL }}/api/cron/daily-student-emails" \
            -H "Authorization: Bearer ${{ secrets.CRON_SECRET }}"
```

---

### Admin Dashboard Hosting

**Recommendation: Firebase Hosting (already configured!)**

Your `firebase.json` already has hosting set up. You can:

1. **Single domain**: Add admin routes to existing website
   - Host at `jeevibe.web.app/admin`
   - Simple, no extra config

2. **Separate subdomain**: Multi-site hosting
   - Host at `admin.jeevibe.com`
   - Add to `firebase.json`:
   ```json
   {
     "hosting": [
       {
         "target": "website",
         "public": "website"
       },
       {
         "target": "admin",
         "public": "admin/dist"
       }
     ]
   }
   ```

**Tech stack for admin dashboard:**
- **React + Vite** (simple, fast builds) or
- **Next.js** (if you want SSR) - export as static

**Firebase Hosting free tier:**
- 10 GB storage
- 360 MB/day bandwidth
- Custom domains
- SSL included

This is plenty for an admin dashboard with a few users.

---

### Firebase Features You Could Leverage

| Feature | Current Status | Analytics Use |
|---------|---------------|---------------|
| **Firestore** | ✅ Active | Query user data directly |
| **Firebase Hosting** | ✅ Active | Host admin dashboard |
| **Firebase Auth** | ✅ Active | Admin authentication |
| **Cloud Functions** | ❌ Not set up | Could run scheduled jobs |
| **Firebase Analytics** | ⚠️ In mobile app | Could track admin usage |

**To add Cloud Functions (optional, requires Blaze):**
```bash
firebase init functions
```

Then create scheduled functions:
```javascript
// functions/index.js
const functions = require('firebase-functions');

exports.dailyStudentEmails = functions.pubsub
  .schedule('30 2 * * *')  // 8 AM IST
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    // Call your existing backend or run logic here
  });
```

**Note:** Blaze plan is pay-as-you-go with generous free quotas. You'd likely pay <$1/month for scheduled functions.

---

### Admin Dashboard Authentication

**Recommendation: Firebase Auth with Google Sign-in + Allowlist**

Since you already have Firebase Auth, add Google Sign-in for admin access:

**Why Google Sign-in:**
- No passwords to manage
- 2FA built-in (if your Google account has it)
- Takes 10 minutes to set up
- You control access via an allowlist

**Setup Steps:**

1. **Enable Google Sign-in** in Firebase Console:
   - Authentication → Sign-in method → Google → Enable

2. **Allowlist approach (simplest):**
```javascript
// admin-dashboard/src/config/auth.js
export const ALLOWED_ADMINS = [
  'abhijeet@yourdomain.com',
  'cofounder@yourdomain.com'
];

// In your auth check
import { getAuth, signInWithPopup, GoogleAuthProvider } from 'firebase/auth';

const auth = getAuth();
const provider = new GoogleAuthProvider();

export async function signInAdmin() {
  const result = await signInWithPopup(auth, provider);
  const user = result.user;

  if (!ALLOWED_ADMINS.includes(user.email)) {
    await auth.signOut();
    throw new Error('Access denied. Not an authorized admin.');
  }

  return user;
}
```

3. **Or store allowlist in Firestore (more flexible):**
```
Collection: admins
Document: {email} → { role: 'owner', name: 'Abhijeet', addedAt: timestamp }
```

```javascript
// Check admin access
async function isAdmin(email) {
  const adminDoc = await getDoc(doc(db, 'admins', email));
  return adminDoc.exists();
}
```

**Protected Route Component:**
```jsx
// admin-dashboard/src/components/ProtectedRoute.jsx
function ProtectedRoute({ children }) {
  const [user, loading] = useAuthState(auth);
  const [isAdmin, setIsAdmin] = useState(false);

  useEffect(() => {
    if (user) {
      // Check allowlist
      setIsAdmin(ALLOWED_ADMINS.includes(user.email));
    }
  }, [user]);

  if (loading) return <Loading />;
  if (!user) return <Navigate to="/login" />;
  if (!isAdmin) return <AccessDenied />;

  return children;
}
```

---

## F. Implementation Summary

### What to Build (Launch Scope)

| Component | Priority | Effort | Files |
|-----------|----------|--------|-------|
| **Admin API endpoints** | P0 | Medium | `admin.js`, `adminMetricsService.js` |
| **Admin dashboard UI** | P0 | Medium | New `admin-dashboard/` folder (React + Vite) |
| **Daily admin report email** | P0 | Low | `alertService.js`, cron endpoint |
| **Student daily email** | P1 | Medium | `studentEmailService.js`, template |
| **Student weekly email** | P1 | Medium | `studentEmailService.js`, template |
| **Automated alerts** | P1 | Low | `alertService.js` |

**All items above are in scope for launch.**

### Cron Jobs to Set Up (cron-job.org)

| Job | Schedule (IST) | UTC Cron | Endpoint |
|-----|---------------|----------|----------|
| Daily student emails | 8:00 AM daily | `30 2 * * *` | `/api/cron/daily-student-emails` |
| Weekly student emails | Sunday 6:00 PM | `30 12 * * 0` | `/api/cron/weekly-student-emails` |
| Daily admin report | 9:00 AM daily | `30 3 * * *` | `/api/cron/daily-admin-report` |
| Alert check | Every 6 hours | `0 */6 * * *` | `/api/cron/check-alerts` |

### Tech Stack Summary

| Layer | Technology | Status |
|-------|------------|--------|
| **Backend API** | Node.js + Express (Render) | Existing |
| **Database** | Firestore | Existing |
| **Email** | Resend | Existing |
| **Admin Hosting** | Firebase Hosting | Existing (add admin route) |
| **Admin Auth** | Firebase Auth + Google Sign-in | Enable Google provider |
| **Cron Jobs** | cron-job.org | New (free) |

### Files to Create

```
backend/
├── src/
│   ├── routes/
│   │   └── admin.js              # NEW: Admin metrics endpoints
│   ├── services/
│   │   ├── adminMetricsService.js    # NEW: Aggregation queries
│   │   ├── studentEmailService.js    # NEW: Student email generation
│   │   └── alertService.js           # NEW: Alert checking & notifications
│   └── templates/
│       ├── dailyEmail.html           # NEW: Daily email template
│       └── weeklyEmail.html          # NEW: Weekly email template

admin-dashboard/                      # NEW: Separate folder or in website/admin
├── src/
│   ├── components/
│   │   ├── DailyHealth.jsx
│   │   ├── EngagementMetrics.jsx
│   │   ├── LearningOutcomes.jsx
│   │   └── UserList.jsx
│   ├── services/
│   │   └── api.js                    # Calls backend /api/admin/*
│   └── App.jsx
├── package.json
└── vite.config.js

.github/
└── workflows/
    └── cron-jobs.yml                 # OPTIONAL: Alternative to cron-job.org
```

---

## G. Admin Dashboard Build Plan

### Project Setup

```bash
# From project root
mkdir admin-dashboard && cd admin-dashboard
npm create vite@latest . -- --template react
npm install firebase react-router-dom recharts date-fns
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

### Folder Structure

```
admin-dashboard/
├── src/
│   ├── components/
│   │   ├── layout/
│   │   │   ├── Sidebar.jsx
│   │   │   ├── Header.jsx
│   │   │   └── Layout.jsx
│   │   ├── charts/
│   │   │   ├── LineChart.jsx
│   │   │   ├── BarChart.jsx
│   │   │   └── PieChart.jsx
│   │   ├── cards/
│   │   │   ├── MetricCard.jsx
│   │   │   └── AlertCard.jsx
│   │   └── auth/
│   │       ├── LoginPage.jsx
│   │       ├── ProtectedRoute.jsx
│   │       └── AccessDenied.jsx
│   ├── pages/
│   │   ├── Dashboard.jsx          # Main overview
│   │   ├── Engagement.jsx         # Detailed engagement metrics
│   │   ├── Learning.jsx           # Learning outcomes
│   │   ├── Users.jsx              # User list & search
│   │   ├── Content.jsx            # Question quality metrics
│   │   └── Alerts.jsx             # Alert history & config
│   ├── services/
│   │   ├── api.js                 # Backend API calls
│   │   └── firebase.js            # Firebase config
│   ├── hooks/
│   │   ├── useAuth.js             # Auth state hook
│   │   └── useMetrics.js          # Data fetching hooks
│   ├── config/
│   │   └── auth.js                # Admin allowlist
│   ├── App.jsx
│   ├── main.jsx
│   └── index.css
├── public/
├── .env                           # Firebase config, API URL
├── package.json
├── vite.config.js
├── tailwind.config.js
└── index.html
```

### Pages & Components

#### 1. Dashboard (Main Overview)

```jsx
// src/pages/Dashboard.jsx
export default function Dashboard() {
  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-6">Daily Health</h1>

      {/* Key Metrics Row */}
      <div className="grid grid-cols-4 gap-4 mb-6">
        <MetricCard title="DAU" value={dau} change={dauChange} />
        <MetricCard title="New Signups" value={signups} />
        <MetricCard title="Quiz Completion" value={`${quizRate}%`} />
        <MetricCard title="At Risk Users" value={atRisk} alert={atRisk > 5} />
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-2 gap-4 mb-6">
        <Card title="DAU Trend (7 days)">
          <LineChart data={dauTrend} />
        </Card>
        <Card title="Feature Usage">
          <BarChart data={featureUsage} />
        </Card>
      </div>

      {/* Active Alerts */}
      <Card title="Active Alerts">
        <AlertsList alerts={activeAlerts} />
      </Card>
    </div>
  );
}
```

#### 2. Users Page

```jsx
// src/pages/Users.jsx
export default function Users() {
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('all'); // all, active, at-risk, pro, ultra

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-6">Users</h1>

      {/* Search & Filters */}
      <div className="flex gap-4 mb-4">
        <input
          placeholder="Search by name, email, or phone..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select value={filter} onChange={(e) => setFilter(e.target.value)}>
          <option value="all">All Users</option>
          <option value="active">Active (last 3 days)</option>
          <option value="at-risk">At Risk (inactive 3+ days)</option>
          <option value="pro">Pro Tier</option>
          <option value="ultra">Ultra Tier</option>
        </select>
      </div>

      {/* User Table */}
      <table>
        <thead>
          <tr>
            <th>Name</th>
            <th>Tier</th>
            <th>Streak</th>
            <th>Questions</th>
            <th>Last Active</th>
            <th>Overall %ile</th>
          </tr>
        </thead>
        <tbody>
          {users.map(user => (
            <tr key={user.uid} onClick={() => openUserDetail(user.uid)}>
              <td>{user.firstName} {user.lastName}</td>
              <td><TierBadge tier={user.tier} /></td>
              <td>{user.currentStreak} days</td>
              <td>{user.totalQuestions}</td>
              <td>{formatRelative(user.lastActive)}</td>
              <td>{user.overallPercentile}%</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

#### 3. API Service

```javascript
// src/services/api.js
const API_URL = import.meta.env.VITE_API_URL;

async function fetchWithAuth(endpoint, options = {}) {
  const token = await getAuth().currentUser?.getIdToken();

  const response = await fetch(`${API_URL}${endpoint}`, {
    ...options,
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...options.headers,
    },
  });

  if (!response.ok) throw new Error(`API error: ${response.status}`);
  return response.json();
}

export const api = {
  // Health metrics
  getDailyHealth: () => fetchWithAuth('/api/admin/metrics/daily-health'),
  getEngagement: () => fetchWithAuth('/api/admin/metrics/engagement'),
  getLearning: () => fetchWithAuth('/api/admin/metrics/learning'),
  getContent: () => fetchWithAuth('/api/admin/metrics/content'),

  // Users
  getUsers: (params) => fetchWithAuth(`/api/admin/users?${new URLSearchParams(params)}`),
  getUser: (uid) => fetchWithAuth(`/api/admin/users/${uid}`),

  // Alerts
  getAlerts: () => fetchWithAuth('/api/admin/alerts'),
  dismissAlert: (id) => fetchWithAuth(`/api/admin/alerts/${id}/dismiss`, { method: 'POST' }),
};
```

#### 4. Firebase Config

```javascript
// src/services/firebase.js
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  // ... other config
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
```

#### 5. Environment Variables

```bash
# admin-dashboard/.env
VITE_API_URL=https://your-render-url.onrender.com
VITE_FIREBASE_API_KEY=your-api-key
VITE_FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=your-project-id
```

### Deployment

```bash
# Build
cd admin-dashboard
npm run build

# Deploy to Firebase Hosting
# Option 1: Add to existing website
cp -r dist/* ../website/admin/

# Option 2: Separate hosting target
firebase deploy --only hosting:admin
```

### Firebase Hosting Config (for separate admin site)

```json
// firebase.json
{
  "hosting": [
    {
      "target": "website",
      "public": "website",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"]
    },
    {
      "target": "admin",
      "public": "admin-dashboard/dist",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
      "rewrites": [
        {
          "source": "**",
          "destination": "/index.html"
        }
      ]
    }
  ]
}
```

Then link targets:
```bash
firebase target:apply hosting website jeevibe-web
firebase target:apply hosting admin jeevibe-admin
firebase deploy --only hosting:admin
```

### UI Components Library

**Recommendation: Use shadcn/ui for fast, professional components**

```bash
# After Vite setup
npx shadcn-ui@latest init
npx shadcn-ui@latest add card button input table badge
```

This gives you pre-built, customizable components that look professional.

### Dashboard Screens Summary

| Screen | Purpose | Key Components |
|--------|---------|----------------|
| **Dashboard** | Daily health overview | MetricCards, LineChart, AlertsList |
| **Engagement** | Deep dive into user activity | BarChart, Histogram, TrendLines |
| **Learning** | Theta progression, mastery stats | SubjectBreakdown, ChapterTable |
| **Users** | Search, filter, view user details | DataTable, UserDetailModal |
| **Content** | Question quality metrics | FlaggedQuestions, AccuracyTable |
| **Alerts** | Alert history, configuration | AlertHistory, ThresholdConfig |

### Backend Endpoints Needed

These need to be created in `backend/src/routes/admin.js`:

```javascript
// GET /api/admin/metrics/daily-health
{
  dau: 127,
  dauChange: +5,  // vs yesterday
  newSignups: 12,
  assessmentCompletions: 10,
  quizCompletionRate: 0.85,
  atRiskUsers: 8,  // inactive 3+ days
  dauTrend: [{ date: '2026-01-13', value: 120 }, ...],
}

// GET /api/admin/metrics/engagement
{
  avgQuizzesPerUser: 2.3,
  avgQuestionsPerUser: 23,
  avgSessionMinutes: 18,
  featureUsage: {
    daily_quiz: 156,
    snap_solve: 89,
    ai_tutor: 45,
    chapter_practice: 23,
  },
  streakDistribution: {
    '0': 45,
    '1-3': 67,
    '4-7': 34,
    '8-14': 12,
    '15+': 5,
  },
}

// GET /api/admin/users?filter=at-risk&limit=50
{
  users: [
    {
      uid: 'abc123',
      firstName: 'Rahul',
      lastName: 'Sharma',
      email: 'rahul@example.com',
      tier: 'pro',
      currentStreak: 0,
      totalQuestions: 234,
      lastActive: '2026-01-15T10:30:00Z',
      overallPercentile: 67,
    },
    ...
  ],
  total: 156,
  hasMore: true,
}
```
