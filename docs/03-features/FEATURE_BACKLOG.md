# JEEVibe Feature Backlog

This document tracks features that are planned, partially implemented, or identified as future enhancements.

*Last Updated: January 2026*

---

## Priority Legend

- **P0 - Critical**: Must have before production launch
- **P1 - High**: Should have for V1.0
- **P2 - Medium**: Nice to have for V1.0, can defer to V1.1
- **P3 - Low**: Future enhancement

---

## 1. Data & Analytics Features

### 1.1 Theta History Tracking
**Priority:** P1 - High
**Status:** Not Implemented
**Description:**
Track historical theta values over time to show users their progress journey.

**Current State:**
- We only store `assessment_baseline` (snapshot at assessment completion)
- `theta_by_chapter` is overwritten after each quiz
- Cannot show "your progress over the last 30 days"

**Proposed Implementation:**
- Create `theta_history/{userId}/snapshots` collection
- Save snapshot after each quiz completion:
  ```javascript
  {
    captured_at: Timestamp,
    quiz_number: number,
    overall_theta: number,
    overall_percentile: number,
    theta_by_chapter: { ... },
    theta_by_subject: { ... }
  }
  ```
- Enable weekly/monthly trend graphs in the app
- Calculate improvement rates and predict future performance

**Files to Modify:**
- `backend/src/routes/dailyQuiz.js` - Add snapshot after quiz completion
- Create `backend/src/services/thetaHistoryService.js`
- Mobile app: Add progress charts

---

### 1.2 Detailed Performance Analytics
**Priority:** P2 - Medium
**Status:** Partial
**Description:**
Provide deeper insights beyond basic accuracy:
- Time-per-question trends
- Difficulty mastery curves
- Peak performance times (morning vs evening)
- Error pattern analysis (careless mistakes vs conceptual gaps)

**Current State:**
- Basic stats in `progressService.js`
- No time-based analysis
- No error categorization

---

### 1.3 Predictive JEE Score
**Priority:** P3 - Low
**Status:** Not Implemented
**Description:**
Use ML model to predict expected JEE score based on:
- Current theta values
- Practice consistency
- Historical performance trends
- Comparison with past successful students

---

## 2. Learning Features

### 2.1 Topic-Specific Practice Mode
**Priority:** P2 - Medium
**Status:** Not Implemented
**Description:**
Allow users to practice specific chapters/topics on demand, not just daily adaptive quizzes.

**Proposed Features:**
- Select subject → chapter → difficulty
- Generate focused practice set
- Track separate from daily quiz theta

---

### 2.2 Custom Quiz Generation
**Priority:** P2 - Medium
**Status:** Not Implemented
**Description:**
Let users create custom quizzes with:
- Specific topics
- Difficulty range
- Question count
- Time limit (optional)

---

### 2.3 Challenge/Timed Mode
**Priority:** P2 - Medium
**Status:** Not Implemented
**Description:**
Competitive timed quizzes simulating JEE exam pressure:
- Strict time limits
- No hints or solutions during quiz
- Leaderboard ranking

---

### 2.4 Concept Linking
**Priority:** P3 - Low
**Status:** Not Implemented
**Description:**
Show how concepts relate to each other:
- Prerequisite mapping
- "You struggled with X, which is needed for Y"
- Recommended learning order

---

### 2.5 Video Explanations
**Priority:** P2 - Medium
**Status:** Not Implemented
**Description:**
Integrate video explanations for:
- Concept introductions
- Solution walkthroughs
- Common mistake explanations

---

## 3. Gamification & Engagement

### 3.1 Achievement Badges
**Priority:** P3 - Low
**Status:** Not Implemented
**Description:**
Award badges for milestones:
- First quiz completed
- 7-day streak
- 100% accuracy on a quiz
- Mastered a chapter (theta > 2.0)
- Completed 100 questions

---

### 3.2 Leaderboards
**Priority:** P3 - Low
**Status:** Not Implemented
**Description:**
Global and friends leaderboards:
- Weekly rankings by theta improvement
- Subject-specific leaderboards
- School/coaching institute boards

---

### 3.3 Progress Milestones
**Priority:** P2 - Medium
**Status:** Not Implemented
**Description:**
Celebrate when users reach skill thresholds:
- "You've moved from 30th to 50th percentile in Physics!"
- "You've mastered 5 chapters this month"

---

### 3.4 Daily Goals
**Priority:** P2 - Medium
**Status:** Not Implemented
**Description:**
Customizable daily learning goals:
- Questions to solve
- Time to spend
- Chapters to practice

---

## 4. Review & Remediation

### 4.1 Smart Review Recommendations
**Priority:** P1 - High
**Status:** Partial
**Description:**
Current spaced repetition is basic (fixed intervals). Enhance with:
- Adaptive intervals based on performance
- Priority scoring for review questions
- "You haven't practiced X in 2 weeks"

**Current State:**
- `spacedRepetitionService.js` exists
- Basic interval calculation
- Not personalized to learning speed

---

### 4.2 Weakness Diagnostic Reports
**Priority:** P2 - Medium
**Status:** Not Implemented
**Description:**
Generate detailed diagnostic reports:
- Top 5 weak chapters with specific sub-topics
- Recommended study plan
- Estimated time to improve
- Similar questions for practice

---

### 4.3 Error Pattern Analysis
**Priority:** P2 - Medium
**Status:** Not Implemented
**Description:**
Categorize errors:
- Conceptual misunderstanding
- Calculation mistakes
- Time pressure errors
- Careless mistakes
- Provide targeted remediation

---

## 5. Content & Questions

### 5.1 Question Bank Expansion Tracking
**Priority:** P1 - High
**Status:** Partial
**Description:**
Track which chapters need more questions.

**Current State:**
- Manual script `analyze_question_coverage.js`
- No automated alerts

**Proposed:**
- Dashboard showing question counts by chapter
- Alert when chapter has < 20 questions
- Track question usage rates

---

### 5.2 Question Difficulty Calibration
**Priority:** P2 - Medium
**Status:** Partial
**Description:**
Auto-calibrate question difficulty from student responses.

**Current State:**
- Fixed IRT parameters per question
- Scripts exist for manual calibration

**Proposed:**
- Track actual P(correct) per question
- Auto-adjust difficulty_b parameter
- Flag questions with unexpected performance

---

### 5.3 Solution Quality Tracking
**Priority:** P3 - Low
**Status:** Not Implemented
**Description:**
Track solution helpfulness:
- "Was this solution helpful?" button
- Flag confusing solutions for review
- Track which solutions lead to improvement

---

## 6. Social & Collaboration

### 6.1 Doubt Resolution System
**Priority:** P2 - Medium
**Status:** Not Implemented
**Description:**
Allow students to ask questions about:
- Specific quiz questions
- Concepts they don't understand
- Solutions they find confusing

Could integrate with:
- AI chatbot
- Peer-to-peer help
- Expert tutors

---

### 6.2 Share Progress
**Priority:** P3 - Low
**Status:** Not Implemented
**Description:**
Share achievements on social media:
- Streak milestones
- Rank improvements
- Chapter mastery

---

### 6.3 Study Groups
**Priority:** P3 - Low
**Status:** Not Implemented
**Description:**
Collaborative features:
- Create study groups
- Group challenges
- Compare progress with friends

---

## 7. Technical Improvements

### 7.1 Offline Mode
**Priority:** P3 - Low
**Status:** Not Implemented
**Description:**
Enable offline functionality:
- Download questions for offline practice
- Sync responses when online
- Cache recent quizzes

---

### 7.2 Push Notifications
**Priority:** P2 - Medium
**Status:** Not Implemented
**Description:**
Reminder notifications:
- Daily quiz reminder
- Streak at risk warning
- Weekly progress summary

---

### 7.3 Firestore Index Optimization
**Priority:** P1 - High
**Status:** Partial
**Description:**
Deploy all required composite indexes.

**Current State:**
- Some indexes defined in `firestore.indexes.json`
- Not all deployed

**Action:**
```bash
firebase deploy --only firestore:indexes
```

---

### 7.4 Analytics Pipeline
**Priority:** P2 - Medium
**Status:** Partial
**Description:**
Aggregate analytics for admin dashboard:
- Daily active users
- Quiz completion rates
- Average accuracy by chapter
- User retention metrics

**Current State:**
- Weekly snapshots exist
- No admin dashboard

---

## 8. Admin & Operations

### 8.1 Admin Dashboard
**Priority:** P2 - Medium
**Status:** Not Implemented
**Description:**
Web dashboard for:
- User statistics
- Question bank management
- Content moderation
- System health monitoring

---

### 8.2 A/B Testing Framework
**Priority:** P3 - Low
**Status:** Not Implemented
**Description:**
Test different:
- Quiz sizes
- Algorithm parameters
- UI variations
- Notification strategies

---

### 8.3 User Feedback Collection
**Priority:** P2 - Medium
**Status:** Not Implemented
**Description:**
In-app feedback:
- Rate the app
- Report issues
- Suggest features

---

## Summary by Priority

### P0 - Critical (Before Production)
*See [TEMPORARY_TEST_CONFIGURATIONS.md](../05-testing/TEMPORARY_TEST_CONFIGURATIONS.md)*

### P1 - High (V1.0)
1. Theta History Tracking
2. Smart Review Recommendations (enhance)
3. Question Bank Expansion Tracking
4. Firestore Index Optimization

### P2 - Medium (V1.0 or V1.1)
1. Topic-Specific Practice Mode
2. Custom Quiz Generation
3. Challenge/Timed Mode
4. Progress Milestones
5. Daily Goals
6. Weakness Diagnostic Reports
7. Push Notifications
8. Video Explanations
9. Doubt Resolution System
10. Admin Dashboard

### P3 - Low (Future)
1. Predictive JEE Score
2. Achievement Badges
3. Leaderboards
4. Concept Linking
5. Offline Mode
6. Share Progress
7. Study Groups
8. A/B Testing Framework

---

## Implementation Notes

When implementing new features:
1. Update this document with status changes
2. Create feature-specific documentation in `docs/03-features/`
3. Add API endpoints to `docs/01-setup/API_ENDPOINTS_COMPLETE.md`
4. Update mobile app screens as needed
5. Add tests for new functionality

---

*Document maintained by the development team. Update when features are implemented or priorities change.*
