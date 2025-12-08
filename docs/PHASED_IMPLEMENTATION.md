# JEEVibe - Phased Implementation Plan (What We Can Build Now)

## Current Status

### ✅ Already Built:
- Snap & Solve feature (camera, OCR, AI solutions)
- Daily snap counter (5/day limit)
- Local storage with SharedPreferences
- UI/UX for snap flow

### ❌ Not Ready Yet:
- Initial assessment screens
- Daily adaptive learning screens
- Adaptive algorithm logic
- Question bank (being built by product team)

---

## Phase 1: Foundation (Can Build NOW) ⭐

### 1.1 Firebase Setup & Authentication

**What**: Complete authentication flow (6 screens)

**Why Build Now**: 
- No dependency on question bank
- No dependency on adaptive logic
- Foundation for everything else

**Screens to Build**:
1. ✅ Welcome Splash
2. ✅ Phone Number Entry
3. ✅ OTP Verification
4. ✅ Create PIN (local encrypted)
5. ✅ Profile Setup - Basics
6. ✅ Profile Setup - Advanced

**What You Get**:
- Users can register and login
- User profiles stored in Firestore
- PIN lock for app security
- User ID (UID) for all future features

**Estimated Time**: 2 weeks

---

### 1.2 Firebase Services Layer

**What**: Core Firebase services (no adaptive logic needed)

**Services to Build**:
```
lib/services/firebase/
├── auth_service.dart           # Phone auth, sign in/out
├── firestore_user_service.dart # User CRUD operations
├── firestore_snap_service.dart # Snap history operations
└── pin_service.dart            # Local PIN storage
```

**What You Get**:
- Reusable Firebase services
- Clean separation of concerns
- Ready for future features

**Estimated Time**: 3 days

---

### 1.3 Snap & Solve Firebase Integration

**What**: Integrate existing snap flow with Firestore

**Changes**:
- Save snap history to Firestore
- Save daily snap counter to Firestore
- Store images locally (already confirmed)
- Update user stats in Firestore

**What You Get**:
- Snap history synced to cloud
- Multi-device snap counter
- User stats tracked in Firestore
- Foundation for analytics

**Estimated Time**: 3 days

---

## Phase 2: Question Bank Infrastructure (Can Build NOW) ⭐

### 2.1 Question Bank Schema & Upload Script

**What**: Database structure + upload tool (no screens needed)

**Even Without Questions, You Can**:
- Define Firestore schema
- Create upload script
- Test with sample questions (from your Physics JSON)
- Set up indexes

**Script**: `scripts/upload_question_bank.js`

```javascript
// Upload questions to Firestore
// Can run this whenever product team provides questions
const questions = require('./questions.json');

questions.forEach(async (question) => {
  await firestore
    .collection('questionBank')
    .doc(question.subject)
    .collection('questions')
    .doc(question.id)
    .set(question);
});
```

**What You Get**:
- Ready to upload questions anytime
- Can test with sample data
- Infrastructure ready for adaptive learning

**Estimated Time**: 2 days

---

### 2.2 Question Fetching Service

**What**: Service to fetch questions from Firestore

**Even Without Adaptive Logic**:
- Fetch questions by subject
- Fetch questions by chapter
- Fetch questions by difficulty
- Random question selection

```dart
class QuestionBankService {
  // Simple random selection (no adaptive logic)
  Future<List<Question>> getRandomQuestions({
    required String subject,
    required int count,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('questionBank')
        .doc(subject)
        .collection('questions')
        .limit(count * 2)  // Get more, then shuffle
        .get();
    
    final questions = snapshot.docs
        .map((doc) => Question.fromJson(doc.data()))
        .toList();
    
    questions.shuffle();
    return questions.take(count).toList();
  }
}
```

**What You Get**:
- Can show questions to users
- Can build practice screens
- Can test question rendering
- Easy to add adaptive logic later

**Estimated Time**: 2 days

---

## Phase 3: Basic Practice Mode (Can Build NOW) ⭐

### 3.1 Simple Practice Screen

**What**: Practice screen WITHOUT adaptive logic

**How It Works**:
- User selects subject (Physics/Chemistry/Math)
- App shows 10 random questions
- User answers questions
- App shows results
- No adaptive difficulty (just random)

**Why Build Now**:
- Tests question bank integration
- Tests question rendering (LaTeX)
- Tests answer checking
- Gets user feedback
- Can add adaptive logic later

**Screen Flow**:
```
Select Subject → Random 10 Questions → Answer → Results
```

**What You Get**:
- Working practice feature
- User engagement
- Data on question difficulty
- Foundation for adaptive learning

**Estimated Time**: 4 days

---

### 3.2 Practice History & Stats

**What**: Track practice sessions in Firestore

**What to Track** (no adaptive logic needed):
- Questions attempted
- Correct/incorrect answers
- Time spent
- Subject-wise breakdown
- Daily practice count

**Firestore Collection**: `users/{uid}/practiceHistory/{sessionId}`

```javascript
{
  "sessionId": "practice_1234567890",
  "date": "2024-12-07",
  "subject": "Physics",
  "questionsAttempted": 10,
  "correct": 7,
  "incorrect": 3,
  "accuracy": 70.0,
  "timeSpent": 600,  // seconds
  "questions": [...]
}
```

**What You Get**:
- User progress tracking
- Stats for dashboard
- Data for future adaptive algorithm
- User engagement metrics

**Estimated Time**: 2 days

---

## Phase 4: Enhanced Home Screen (Can Build NOW) ⭐

### 4.1 Dashboard with Stats

**What**: Update home screen to show Firestore data

**Widgets to Add**:
- User profile card (name, class, target exam)
- Snap counter (X/5 snaps today)
- Practice stats (questions practiced, accuracy)
- Recent solutions (from Firestore)
- Quick actions (snap, practice)

**No Adaptive Logic Needed**:
- Just display aggregated stats
- Show recent activity
- Show daily limits

**What You Get**:
- Engaging home screen
- User sees their progress
- Encourages daily usage

**Estimated Time**: 3 days

---

## Phase 5: Placeholder Screens (Can Build NOW) ⭐

### 5.1 Initial Assessment Placeholder

**What**: Screen that says "Coming Soon"

**Why Build**:
- Shows users what's coming
- Can collect interest
- Easy to replace later

**Screen**:
```
┌─────────────────────────┐
│  Initial Assessment     │
│                         │
│  📊 Coming Soon!        │
│                         │
│  We're preparing a      │
│  personalized           │
│  assessment to gauge    │
│  your level.            │
│                         │
│  [Skip for Now]         │
└─────────────────────────┘
```

**Estimated Time**: 1 day

---

### 5.2 Daily Adaptive Questions Placeholder

**What**: Screen that shows "Coming Soon" or redirects to simple practice

**Temporary Solution**:
- Show simple practice mode instead
- Add banner: "Adaptive mode coming soon!"
- Collect user feedback

**Estimated Time**: 1 day

---

## What You Can Build in 4 Weeks (Without Adaptive Logic)

### Week 1: Authentication
- [ ] Firebase project setup
- [ ] 6 authentication screens
- [ ] PIN lock
- [ ] Profile setup

### Week 2: Firebase Integration
- [ ] Firebase services layer
- [ ] Snap & Solve Firestore integration
- [ ] Question bank schema + upload script
- [ ] Question fetching service

### Week 3: Basic Practice
- [ ] Simple practice screen (random questions)
- [ ] Practice history tracking
- [ ] Results screen
- [ ] Stats tracking

### Week 4: Polish & Dashboard
- [ ] Enhanced home screen
- [ ] User stats dashboard
- [ ] Placeholder screens
- [ ] Testing & bug fixes

---

## What You'll Have After 4 Weeks

### ✅ Fully Functional:
1. **Authentication** - Users can register, login, set PIN
2. **Snap & Solve** - Integrated with Firestore
3. **Question Bank** - Infrastructure ready, can upload questions anytime
4. **Basic Practice** - Random questions (no adaptive logic)
5. **Progress Tracking** - Stats, history, dashboard
6. **Multi-device Sync** - All data in Firestore

### 🔄 Ready to Add Later:
1. **Initial Assessment** - Just replace placeholder screen
2. **Adaptive Algorithm** - Just update question selection logic
3. **Daily Adaptive Questions** - Just replace placeholder screen

---

## Benefits of This Approach

### ✅ Pros:
1. **Ship Early** - Users can start using app in 4 weeks
2. **Get Feedback** - Learn what users want
3. **Iterate Fast** - Add adaptive logic based on real data
4. **Reduce Risk** - Test infrastructure before complex features
5. **Parallel Work** - Product team can build question bank while you build app

### ⚠️ Cons:
1. **Not Full Vision** - Missing adaptive learning initially
2. **Rework** - May need to adjust screens later

**Recommendation**: ✅ **Build this way!** Ship early, iterate based on feedback.

---

## Adaptive Logic - When You're Ready

### What You Need:
1. **Question Bank** - 300+ questions per subject
2. **Algorithm Decision** - Simple (0-100) or IRT
3. **Initial Assessment Design** - How to gauge level

### How to Add Later:
1. **Replace** placeholder screens with real screens
2. **Update** question selection logic in `QuestionBankService`
3. **Add** ability tracking in practice history
4. **Deploy** - No database migration needed!

---

## Recommended Next Steps

### Option A: Start with Authentication (Recommended)
**Why**: Foundation for everything, no dependencies

**Steps**:
1. Create Firebase project
2. Build 6 auth screens
3. Integrate with Firestore
4. Test auth flow

**Timeline**: 2 weeks

### Option B: Start with Question Bank Infrastructure
**Why**: Can work in parallel with auth

**Steps**:
1. Define Firestore schema
2. Create upload script
3. Upload sample questions (Physics JSON)
4. Build question fetching service

**Timeline**: 1 week

### Option C: Do Both in Parallel
**Why**: Fastest to market

**Steps**:
1. You build auth screens
2. Backend dev builds question bank infrastructure
3. Integrate both

**Timeline**: 2 weeks (parallel)

---

## Summary

### Can Build NOW (No Dependencies):
- ✅ Authentication (6 screens)
- ✅ Firebase services layer
- ✅ Snap & Solve Firestore integration
- ✅ Question bank infrastructure
- ✅ Simple practice mode (random questions)
- ✅ Progress tracking & dashboard
- ✅ Placeholder screens for future features

### Need to Wait For:
- ❌ Initial assessment screens (need design + logic)
- ❌ Daily adaptive questions (need algorithm)
- ❌ Full question bank (product team building)

### Recommendation:
**Build Phase 1-4 now (4 weeks), add adaptive logic later when ready.**

Ready to start? Which phase should we begin with?
