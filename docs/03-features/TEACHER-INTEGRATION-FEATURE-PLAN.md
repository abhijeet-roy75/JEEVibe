# Teacher Integration & Weekly Reporting - Implementation Plan

**Status:** Ready for Implementation
**Last Updated:** 2026-02-04
**Owner:** Product Team
**Architectural Review:** ✅ Approved (see review notes below)

---

## Overview
Integrate coaching class teachers into JEEVibe to enable weekly student performance reports. This feature allows teachers to track their students' engagement, identify struggling students, and receive data-driven insights via email.

## Architectural Review Notes

**Review Date:** 2026-02-04
**Status:** ✅ Approved for Implementation

**Key Fixes Applied:**
1. ✅ Use `lastActive` field instead of non-existent `last_quiz_completed_at`
2. ✅ Added Firestore indexes to `firestore.indexes.json` in Phase 1

**Validation Summary:**
- Database schema follows existing patterns
- All referenced services exist and patterns validated
- Security model matches existing admin auth
- Performance design is cost-effective ($0-$0.12/month)
- 70% code reuse from existing infrastructure

---

## Database Schema Changes

### New Collection: `teachers/{teacherId}`
```javascript
{
  teacher_id: "AUTO_GENERATED",
  email: "teacher@example.com",        // UNIQUE
  phone_number: "+919876543210",       // UNIQUE
  first_name: "Priya",
  last_name: "Sharma",
  coaching_institute_name: "Elite IIT Academy",
  coaching_institute_location: "Delhi",
  role: "teacher",
  is_active: true,
  student_ids: ["uid1", "uid2"],       // Denormalized for performance
  total_students: 42,
  email_preferences: {
    weekly_class_report: true,
    student_alerts: true
  },
  created_at: Timestamp,
  created_by: "admin@jeevibe.com",
  last_login_at: Timestamp
}
```

**Firestore Indexes:**
- `email ASC, is_active ASC`
- `coaching_institute_name ASC, is_active ASC`

### Update Existing: `users/{userId}`
Add these fields to associate students with teachers:
```javascript
{
  teacher_id: "teacherId123",                    // NEW
  coaching_institute_name: "Elite IIT Academy",  // NEW (denormalized)
  // ... existing fields remain unchanged
}
```

**Firestore Index:**
- `teacher_id ASC, isEnrolledInCoaching ASC`

### New Collection: `teacher_reports/{reportId}`
Cache weekly reports for performance and history:
```javascript
{
  report_id: "teacher_{teacherId}_week_{YYYY-Wnn}",
  teacher_id: "teacherId123",
  teacher_email: "teacher@example.com",
  week_start: "2026-01-27",
  week_end: "2026-02-02",
  generated_at: Timestamp,

  class_metrics: {
    total_students: 42,
    active_students: 35,
    total_questions_solved: 1250,
    avg_practice_time_minutes: 148,
    avg_attendance_percentage: 83
  },

  struggling_students: [
    {
      student_id: "uid1",
      student_name: "Rahul K",
      days_since_last_practice: 6,
      questions_this_week: 0,
      percentile: 42
    }
  ],

  struggling_topics: [
    {
      chapter_key: "physics_electrostatics",
      chapter_name: "Electrostatics",
      subject: "Physics",
      class_avg_accuracy: 42,
      students_struggling: 18
    }
  ],

  highlights: {
    top_performers: [...],
    most_improved_chapter: {...},
    longest_streak_student: {...}
  },

  email_sent: true,
  email_sent_at: Timestamp
}
```

**Firestore Index:**
- `teacher_id ASC, week_end DESC`

---

## Backend Implementation

### New Services

#### 1. `/backend/src/services/teacherService.js`
Teacher CRUD operations and student association management.

**Key Functions:**
- `createTeacher(teacherData, createdByAdmin)` - Create teacher account
- `getTeacherById(teacherId)` - Fetch teacher profile
- `getTeacherByEmail(email)` - Lookup by email
- `updateTeacher(teacherId, updates)` - Update profile
- `deactivateTeacher(teacherId)` - Soft delete
- `listTeachers({ filter, search, limit, offset })` - Paginated list
- `addStudentsToTeacher(teacherId, studentIds)` - Bulk association
- `removeStudentFromTeacher(teacherId, studentId)` - Remove association
- `getTeacherStudents(teacherId, options)` - Get teacher's students

**Pattern to Follow:** Admin CRUD operations from existing services

---

#### 2. `/backend/src/services/teacherReportingService.js`
Weekly report generation and class-level analytics aggregation.

**Key Functions:**
- `generateWeeklyReportForTeacher(teacherId, weekEnd)` - Single teacher report
- `generateWeeklyReportsForAllTeachers(weekEnd)` - Batch for all active teachers
- `getClassEngagementMetrics(studentIds, weekStart, weekEnd)` - Activity metrics
- `getStrugglingStudents(studentIds, weekStart, weekEnd)` - Identify at-risk students
- `getStrugglingTopics(studentIds, weekStart, weekEnd)` - Low-accuracy chapters
- `getClassHighlights(studentIds, weekStart, weekEnd)` - Top performers, improvements

**Optimization Strategy:**
- Use denormalized fields from `users/{userId}` to avoid subcollection queries:
  - `cumulative_stats` - total questions, accuracy
  - `total_questions_solved` - cumulative question count
  - `theta_by_chapter` - chapter-level performance
  - `lastActive` - last activity timestamp (for active student detection)
- Single batch read for all students (e.g., 150 students = 150 reads)
- Aggregate in-memory
- Cache results in `teacher_reports` collection

**Important:** Use `lastActive` field to determine active students (checked in architectural review - this field exists in user schema).

**Reuse Patterns From:**
- `/backend/src/services/analyticsService.js` - Student metrics aggregation
- `/backend/src/services/weeklySnapshotService.js` - Week bounds calculation
- `/backend/src/services/progressService.js` - Student data retrieval

---

#### 3. `/backend/src/services/teacherEmailService.js`
Email report generation and delivery to teachers.

**Key Functions:**
- `sendWeeklyReportEmail(teacherId, reportData)` - Send to single teacher
- `sendAllWeeklyTeacherEmails()` - Batch send (called by cron)
- `generateWeeklyEmailContent(teacherData, reportData)` - HTML email template

**Email Template Sections:**
1. Header with week number and date range
2. Class overview card (active students, total questions, avg practice time)
3. Students needing attention table (sorted by days inactive)
4. Topics to focus on table (sorted by class accuracy)
5. Positive highlights (top performers, improvements, streaks)
6. Footer with unsubscribe link

**Reuse Patterns From:**
- `/backend/src/services/studentEmailService.js` - HTML structure, Resend integration, gradient headers
- Use same Resend API configuration and error handling

---

#### 4. `/backend/src/middleware/teacherAuth.js`
Authentication middleware for teacher-specific endpoints (future teacher portal).

**Logic:**
1. Verify Firebase ID token
2. Lookup teacher by email in `teachers` collection
3. Check `is_active` status
4. Attach `req.teacherId`, `req.teacherEmail`, `req.isTeacher` to request

**Pattern to Follow:** `/backend/src/middleware/adminAuth.js`

---

### New API Routes

#### `/backend/src/routes/teachers.js`

**Admin Endpoints (require `authenticateAdmin`):**
- `POST /api/teachers` - Create teacher
- `GET /api/teachers` - List all teachers (paginated, searchable)
- `GET /api/teachers/:teacherId` - Get teacher details
- `PATCH /api/teachers/:teacherId` - Update teacher
- `DELETE /api/teachers/:teacherId` - Deactivate teacher
- `POST /api/teachers/:teacherId/students` - Bulk add students
- `DELETE /api/teachers/:teacherId/students/:studentId` - Remove student

**Teacher Portal Endpoints (require `authenticateTeacher` - FUTURE):**
- `GET /api/teachers/me` - Current teacher profile
- `GET /api/teachers/me/students` - My students
- `GET /api/teachers/me/reports` - My weekly reports
- `GET /api/teachers/me/reports/:reportId` - Specific report

---

### Cron Job Integration

#### New Endpoint: `POST /api/cron/weekly-teacher-reports`

**Logic:**
1. Query all active teachers (`is_active = true`)
2. For each teacher:
   - Get students (`teacher_id` filter)
   - Calculate week bounds (previous Mon-Sun)
   - Generate report via `teacherReportingService.generateWeeklyReportForTeacher()`
   - Send email via `teacherEmailService.sendWeeklyReportEmail()`
   - Save report to `teacher_reports` collection
3. Log success/errors

**Render.com Cron Config:**
- Schedule: `0 0 * * 1` (Monday midnight UTC = 5:30 AM IST)
- Timeout: 5 minutes

**Pattern to Follow:** Existing cron patterns for student weekly emails

---

## Onboarding Scripts

### 1. `/backend/scripts/onboard-teachers-bulk.js`
Bulk import teachers from CSV file.

**Usage:**
```bash
node scripts/onboard-teachers-bulk.js teachers.csv [--dry-run]
```

**CSV Format:**
```csv
email,phone,first_name,last_name,institute_name,institute_location
priya@example.com,+919876543210,Priya,Sharma,Elite IIT Academy,Delhi
```

**Features:**
- Validate email/phone format
- Check for duplicates (by email)
- Batch writes (500 per batch)
- Create Firebase Auth accounts (auto-generate password)
- Send welcome email with login instructions
- Progress logging every 10 teachers
- Dry-run mode for testing

**Pattern to Follow:** `/backend/scripts/migrate-add-coaching-enrollment.js`

---

### 2. `/backend/scripts/associate-students-to-teacher.js`
Associate students with teachers from CSV mapping.

**Usage:**
```bash
node scripts/associate-students-to-teacher.js mapping.csv [--dry-run]
```

**CSV Format:**
```csv
student_phone,teacher_email
+919998887770,priya@example.com
+919998887771,priya@example.com
```

**Logic:**
1. Lookup teacher by email → get `teacher_id`
2. Lookup student by phone → get `user_id`
3. Update `users/{userId}` with `teacher_id` and `coaching_institute_name`
4. Update `teachers/{teacherId}` - add to `student_ids` array, increment `total_students`
5. Batch operations (500 per batch)

**Validation:**
- Teacher exists and is active
- Student exists
- Warn if student already has different teacher (use `--force` to override)

**Pattern to Follow:** Same batch operation pattern as teacher onboarding script

---

## Admin Dashboard UI

### New Pages

#### 1. `/admin-dashboard/src/pages/Teachers.jsx`
Teacher management dashboard.

**Features:**
- Teacher list table with columns: Name, Email, Institute, Students, Status, Created
- Search bar (filter by name/email/institute)
- Filter dropdown (by institute)
- Actions per row: Edit, View Students, Deactivate
- "Add Teacher" button (opens form modal)
- "Bulk Import" button (CSV upload widget)
- Pagination (50 per page)

**API Integration:**
```javascript
GET /api/teachers?limit=50&offset=0&search=...&filter=...
```

---

#### 2. `/admin-dashboard/src/pages/TeacherDetail.jsx`
Individual teacher detail view.

**Features:**
- Teacher profile card (name, email, phone, institute, student count)
- Student list table (Name, Phone, Percentile, Last Active)
- "Add Students" button (multi-select dropdown or CSV upload)
- Remove student action per row
- Recent reports section (last 4 weeks with download links)

**API Integration:**
```javascript
GET /api/teachers/:teacherId
GET /api/teachers/:teacherId/students
GET /api/teachers/:teacherId/reports
```

---

### Enhanced Existing Pages

#### `/admin-dashboard/src/pages/Dashboard.jsx`
Add metric cards:
- "Active Teachers" (total count)
- "Reports Generated This Week" (count)

#### `/admin-dashboard/src/pages/Users.jsx`
- Add "Teacher" column (show teacher name if `teacher_id` exists)
- Add filter dropdown: "Filter by Teacher"

---

## Implementation Phases

### Phase 1: Backend Infrastructure (Days 1-3)
**Tasks:**
1. **Add Firestore indexes to `backend/firebase/firestore.indexes.json`:**
   ```json
   {
     "comment": "Teacher lookup by email and active status",
     "collectionGroup": "teachers",
     "queryScope": "COLLECTION",
     "fields": [
       { "fieldPath": "email", "order": "ASCENDING" },
       { "fieldPath": "is_active", "order": "ASCENDING" }
     ]
   },
   {
     "comment": "Teacher filtering by institute",
     "collectionGroup": "teachers",
     "queryScope": "COLLECTION",
     "fields": [
       { "fieldPath": "coaching_institute_name", "order": "ASCENDING" },
       { "fieldPath": "is_active", "order": "ASCENDING" }
     ]
   },
   {
     "comment": "Student lookup by teacher and coaching status",
     "collectionGroup": "users",
     "queryScope": "COLLECTION",
     "fields": [
       { "fieldPath": "teacher_id", "order": "ASCENDING" },
       { "fieldPath": "isEnrolledInCoaching", "order": "ASCENDING" }
     ]
   },
   {
     "comment": "Teacher reports by teacher and week",
     "collectionGroup": "teacher_reports",
     "queryScope": "COLLECTION",
     "fields": [
       { "fieldPath": "teacher_id", "order": "ASCENDING" },
       { "fieldPath": "week_end", "order": "DESCENDING" }
     ]
   }
   ```
2. Deploy indexes: `firebase deploy --only firestore:indexes`
3. Create Firestore collections (will be auto-created on first write, but document structure for reference)
4. Implement `teacherService.js` (CRUD operations)
5. Implement `teacherAuth.js` middleware
6. Create `/api/teachers` routes (admin endpoints only)
7. Write unit tests for teacher CRUD

**Verification:**
- Firestore indexes deployed successfully
- Use Postman to create, read, update, deactivate teachers via API

---

### Phase 2: Student Association (Days 3-5)
**Tasks:**
1. Add `teacher_id` field to users schema (migration if needed)
2. Implement student association functions in `teacherService.js`
3. Create `onboard-teachers-bulk.js` script
4. Create `associate-students-to-teacher.js` script
5. Test scripts with sample CSV files (5 teachers, 50 students)
6. Run dry-run on staging data

**Verification:**
- Scripts execute without errors
- Students have `teacher_id` field populated
- Teachers have `student_ids` array populated

---

### Phase 3: Report Generation (Days 5-8)
**Tasks:**
1. Implement `teacherReportingService.js` (all aggregation functions)
2. Implement `teacherEmailService.js` (email templates)
3. Create HTML email template (reuse student email styles)
4. Test report generation with real data (generate sample report for 1 teacher)
5. Test email sending in Resend sandbox mode

**Verification:**
- Generate report for test teacher → verify metrics are accurate
- Send test email → verify formatting and content

---

### Phase 4: Cron Integration (Days 8-10)
**Tasks:**
1. Add cron endpoint: `POST /api/cron/weekly-teacher-reports`
2. Implement batch report generation (`generateWeeklyReportsForAllTeachers()`)
3. Configure Render.com cron job (Monday 5:30 AM IST)
4. Add error handling and retry logic
5. Set up monitoring/alerting for failed reports

**Verification:**
- Manually trigger cron endpoint → verify all active teachers receive emails
- Check Render.com cron logs
- Monitor Resend dashboard for delivery status

---

### Phase 5: Admin UI (Days 10-13)
**Tasks:**
1. Create `Teachers.jsx` page (teacher list)
2. Create `TeacherDetail.jsx` page (individual teacher view)
3. Add "Teachers" navigation item to admin dashboard
4. Implement CSV upload widget for bulk import
5. Add teacher metrics to `Dashboard.jsx`
6. Enhance `Users.jsx` with teacher filter

**Verification:**
- Admin can view teacher list
- Admin can create/edit/deactivate teachers via UI
- Admin can associate students to teachers
- CSV bulk import works end-to-end

---

### Phase 6: Production Rollout (Days 13-15)
**Tasks:**
1. Onboard first 10 teachers (pilot group)
2. Associate students (from teacher-provided lists)
3. Monitor first weekly report batch
4. Collect feedback from teachers
5. Iterate on email template based on feedback

**Verification:**
- 10 teachers receive weekly emails
- Teachers can understand the report metrics
- No data privacy violations

---

## Critical Files Reference

### Study These Patterns:
1. [studentEmailService.js](../../backend/src/services/studentEmailService.js) - Email template structure, Resend integration
2. [analyticsService.js](../../backend/src/services/analyticsService.js) - Student metrics aggregation
3. [weeklySnapshotService.js](../../backend/src/services/weeklySnapshotService.js) - Week bounds, batch operations
4. [adminAuth.js](../../backend/src/middleware/adminAuth.js) - Authentication middleware pattern
5. [migrate-add-coaching-enrollment.js](../../backend/scripts/migrate-add-coaching-enrollment.js) - Migration script pattern

### New Files to Create:
1. `/backend/src/services/teacherService.js`
2. `/backend/src/services/teacherReportingService.js`
3. `/backend/src/services/teacherEmailService.js`
4. `/backend/src/middleware/teacherAuth.js`
5. `/backend/src/routes/teachers.js`
6. `/backend/scripts/onboard-teachers-bulk.js`
7. `/backend/scripts/associate-students-to-teacher.js`
8. `/admin-dashboard/src/pages/Teachers.jsx`
9. `/admin-dashboard/src/pages/TeacherDetail.jsx`

### Update These Files:
1. `/backend/src/routes/index.js` - Add teachers routes
2. `/backend/src/routes/cron.js` - Add weekly teacher reports endpoint
3. `/admin-dashboard/src/App.jsx` - Add Teachers route
4. `/admin-dashboard/src/components/Sidebar.jsx` - Add Teachers nav item

---

## Cost & Performance

**Firestore Costs (for 100 teachers, avg 150 students each):**
- Reads per report: ~151 (1 teacher + 150 students)
- Total weekly reads: 15,100
- Monthly reads: ~60,400 → **Free** (within 100K free tier)
- Writes: 400/month → **Free** (within 20K free tier)

**Email Costs (Resend):**
- 400 emails/month → **Free** (within 3,000/month free tier)

**Total Monthly Cost: $0** (for 100 teachers)

**Scaling to 500 teachers (75,000 students):**
- Firestore reads: ~300,000/month → **$0.12/month**
- Emails: 2,000/month → **Free**
- **Total: ~$0.12/month**

---

## Security & Privacy

**Access Control:**
- Teachers can only see their own students (enforced by `teacher_id` filter)
- Admin endpoints require `authenticateAdmin` middleware
- Teacher endpoints require `authenticateTeacher` middleware (future)

**Data Minimization:**
- Teachers see: Student name (first + last initial), practice metrics, percentile, last active
- Teachers CANNOT see: Phone number, email, payment history, Snap photos, AI Tutor chats

**Data Retention:**
- Teacher reports stored for 1 year
- Scheduled job archives old reports (implement in Phase 6+)

---

## Additional Considerations

### Items Addressed:
✅ Teacher onboarding (script + admin UI)
✅ Student association (script + admin UI)
✅ Weekly report generation (cron job)
✅ Email delivery (Resend integration)
✅ Data privacy (access control, data minimization)
✅ Scalability (optimized aggregation, caching)

### Future Enhancements (Not in Scope):
- Teacher self-service portal (view reports in dashboard instead of email)
- Parent access (separate parent accounts with read-only view)
- Custom report frequency (daily/bi-weekly options)
- Export reports as PDF
- In-app notifications for teachers
- Teacher collaboration features (share best practices)

---

## Verification Plan

After implementation, verify:

1. **Teacher CRUD:** Create, read, update, deactivate teachers via API and admin UI
2. **Student Association:** Bulk associate students to teachers via script and UI
3. **Report Generation:** Generate report for test teacher with 150+ students
4. **Email Delivery:** Verify email formatting, accuracy of metrics, deliverability
5. **Cron Job:** Manually trigger cron, verify all active teachers receive emails
6. **Performance:** Measure report generation time (should be <30 seconds per teacher)
7. **Cost:** Monitor Firestore reads/writes and Resend usage for first month
8. **Privacy:** Audit teacher view to ensure no sensitive student data exposed

---

## Success Metrics

- **Week 1:** Backend infrastructure complete, APIs functional
- **Week 2:** Scripts tested, 10 pilot teachers onboarded
- **Week 3:** First batch of weekly reports sent successfully (100% delivery rate)
- **Week 4:** Admin UI complete, admins can manage teachers without scripts
- **Month 1:** 100+ teachers receiving weekly reports, <0.5% email bounce rate
- **Month 3:** Teacher feedback score >4/5, report click-through rate >60%
