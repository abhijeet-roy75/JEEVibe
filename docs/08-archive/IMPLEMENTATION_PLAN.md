# JEEVibe Implementation Plan - FINAL

## Confirmed Decisions (2024-12-07)

### ✅ Product Strategy:
1. **Adaptive Algorithm**: TBD (will discuss with product team)
2. **Initial Assessment**: Mandatory with skip option
3. **Question Bank**: Start with what product team builds, expand over time
4. **Offline Caching**: All questions (~10 MB)
5. **Tier Strategy**: Build for free tier with limits, add payment later

### ✅ Free Tier Limits (Enforced from Day 1):
- **Daily Adaptive Questions**: 10/day
- **Snap & Solve**: 5/day
- **Initial Assessment**: Unlimited (one-time)
- **Question Bank Access**: Full access
- **Progress Tracking**: Full access

### ✅ Pro Tier (Future - Not Building Now):
- **Daily Adaptive Questions**: Unlimited
- **Snap & Solve**: 20/day or unlimited
- **Payment Integration**: Add later (Stripe/Razorpay)

### ✅ Storage Strategy:
- **Images**: Local storage only (no cloud)
- **Question Bank**: Firestore with offline cache
- **User Data**: Firestore with offline persistence

---

## Database Schema - FINAL

### User Profile

```javascript
{
  // ... basic profile fields ...
  
  // Tier (always "free" for now)
  "tier": "free",
  
  // Daily Limits (hardcoded for free tier)
  "dailyLimits": {
    "adaptiveQuestions": 10,
    "snapAndSolve": 5
  },
  
  // Assessment
  "assessmentCompleted": false,
  "assessmentSkipped": false,  // Track if user skipped
  
  // Ability/Level (set after assessment or during practice)
  "currentLevel": {
    "physics": null,      // null until assessed
    "chemistry": null,
    "mathematics": null
  }
}
```

### Daily Limits Enforcement

**Collection**: `users/{uid}/dailyLimits/{date}`

```javascript
{
  "date": "2024-12-07",
  
  // Adaptive Questions
  "adaptiveQuestions": {
    "attempted": 7,
    "limit": 10,
    "remaining": 3
  },
  
  // Snap & Solve
  "snapAndSolve": {
    "attempted": 3,
    "limit": 5,
    "remaining": 2
  },
  
  // Reset time
  "resetAt": Timestamp  // Midnight local time
}
```

**Limit Check Logic**:
```dart
Future<bool> canTakeAdaptiveQuestion(String uid) async {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final limitsDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('dailyLimits')
      .doc(today)
      .get();
  
  final data = limitsDoc.data();
  if (data == null) {
    // First question of the day
    return true;
  }
  
  final attempted = data['adaptiveQuestions']['attempted'] ?? 0;
  final limit = data['adaptiveQuestions']['limit'] ?? 10;
  
  return attempted < limit;
}
```

---

## Implementation Phases - FINAL

### Phase 1: Firebase Setup & Authentication (Week 1-2)
**Goal**: Users can register and login

- [ ] Create Firebase project
- [ ] Add Firebase to Flutter app
- [ ] Implement 6 auth screens:
  - [ ] Welcome Splash
  - [ ] Phone Number Entry
  - [ ] OTP Verification
  - [ ] Create PIN (local encrypted)
  - [ ] Profile Setup - Basics
  - [ ] Profile Setup - Advanced
- [ ] Implement PIN lock screen
- [ ] Test auth flow (India + US numbers)

**Deliverable**: Working authentication with profile setup

---

### Phase 2: Question Bank Setup (Week 2-3)
**Goal**: Question bank in Firestore with offline access

- [ ] Create Firestore collections structure
- [ ] Upload initial question bank (from product team)
- [ ] Create question fetching service
- [ ] Implement offline caching (all questions)
- [ ] Create lookup values (dropdowns)

**Deliverable**: Question bank accessible offline

---

### Phase 3: Initial Assessment (Week 3-4)
**Goal**: New users take 30-question assessment

- [ ] Create assessment screen
- [ ] Implement question selection (10 per subject)
- [ ] Create answer tracking
- [ ] Calculate ability/level (simple algorithm for now)
- [ ] Show results screen
- [ ] Allow skip (but encourage completion)
- [ ] Save results to Firestore

**Deliverable**: Working initial assessment flow

---

### Phase 4: Daily Adaptive Questions (Week 4-5)
**Goal**: Users can practice adaptive questions daily

- [ ] Create daily practice screen
- [ ] Implement question selection logic
  - [ ] Filter by subject
  - [ ] Select appropriate difficulty
  - [ ] Avoid recent questions
- [ ] Implement daily limit enforcement (10/day)
- [ ] Track answers and update ability
- [ ] Show daily summary
- [ ] Update progress tracking

**Deliverable**: Working daily adaptive practice with limits

---

### Phase 5: Snap & Solve Update (Week 5-6)
**Goal**: Snap & Solve works with local storage and limits

- [ ] Update camera screen for limits check
- [ ] Save images locally (not cloud)
- [ ] Integrate with existing OCR/AI flow
- [ ] Save metadata to Firestore
- [ ] Implement daily limit (5/day)
- [ ] Show upgrade prompt when limit reached
- [ ] Track snap history

**Deliverable**: Snap & Solve with local storage and limits

---

### Phase 6: Progress Dashboard (Week 6-7)
**Goal**: Users can see their progress

- [ ] Update home screen with stats
- [ ] Create progress screen
  - [ ] Overall stats
  - [ ] Subject-wise breakdown
  - [ ] Weak/strong areas
  - [ ] Streak tracking
- [ ] Show daily limits remaining
- [ ] Show upgrade prompts (for future pro tier)

**Deliverable**: Complete progress tracking UI

---

### Phase 7: Testing & Polish (Week 7-8)
**Goal**: App is production-ready

- [ ] Test all flows end-to-end
- [ ] Test offline mode
- [ ] Test limit enforcement
- [ ] Test on iOS and Android
- [ ] Fix bugs
- [ ] Polish UI/UX
- [ ] Update privacy policy
- [ ] Prepare for TestFlight/Play Store

**Deliverable**: Production-ready app

---

## Limit Enforcement - Implementation Details

### 1. Check Limit Before Action

```dart
// Before showing adaptive question
if (!await canTakeAdaptiveQuestion(uid)) {
  showLimitReachedDialog(
    title: "Daily Limit Reached",
    message: "You've completed 10 questions today. Come back tomorrow or upgrade to Pro for unlimited questions!",
    upgradeButton: true  // Show upgrade button (disabled for now)
  );
  return;
}

// Before taking snap
if (!await canTakeSnap(uid)) {
  showLimitReachedDialog(
    title: "Daily Snap Limit Reached",
    message: "You've used 5 snaps today. Come back tomorrow or upgrade to Pro!",
    upgradeButton: true
  );
  return;
}
```

### 2. Increment Counter After Action

```dart
// After user answers adaptive question
await incrementAdaptiveQuestionCount(uid);

// After user takes snap
await incrementSnapCount(uid);
```

### 3. Reset at Midnight

```dart
// Cloud Function (Firebase Functions)
exports.resetDailyLimits = functions.pubsub
  .schedule('0 0 * * *')  // Every midnight
  .timeZone('Asia/Kolkata')  // IST
  .onRun(async (context) => {
    // Reset logic handled automatically by date-based documents
    // Old date documents are just not queried
  });
```

**Note**: No cloud function needed! Date-based documents auto-reset.

---

## Upgrade Prompt UI (For Future)

```dart
Widget buildUpgradePrompt() {
  return AlertDialog(
    title: Text('Upgrade to Pro'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Get unlimited adaptive questions and more snaps!'),
        SizedBox(height: 16),
        // Pro features list
        FeatureList(
          features: [
            'Unlimited daily adaptive questions',
            '20 snaps per day',
            'Advanced analytics',
            'Priority support',
          ],
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Maybe Later'),
      ),
      ElevatedButton(
        onPressed: () {
          // TODO: Implement payment flow
          showComingSoonDialog();
        },
        child: Text('Upgrade Now'),
      ),
    ],
  );
}
```

---

## Future: Adding Pro Tier (Phase 8+)

### When to Add:
- After 1000+ active users
- After validating product-market fit
- When ready to monetize

### What to Add:

1. **Payment Integration**
   - Razorpay (India) or Stripe (Global)
   - Subscription management
   - Receipt generation

2. **Database Changes**
   ```javascript
   {
     "tier": "pro",  // Change from "free"
     "proExpiryDate": Timestamp,
     "proStartDate": Timestamp,
     "dailyLimits": {
       "adaptiveQuestions": -1,  // -1 = unlimited
       "snapAndSolve": 20
     }
   }
   ```

3. **Limit Check Update**
   ```dart
   Future<bool> canTakeAdaptiveQuestion(String uid) async {
     final user = await getUser(uid);
     
     // Check if pro
     if (user.tier == 'pro' && user.proExpiryDate.isAfter(DateTime.now())) {
       return true;  // Unlimited for pro
     }
     
     // Check free tier limit
     final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
     // ... existing logic
   }
   ```

4. **UI Changes**
   - Add "Upgrade" button in app bar
   - Show pro badge for pro users
   - Enable upgrade prompts

---

## Cost Estimate - FINAL

### Firebase Free Tier (1000 users):

| Resource | Free Limit | Usage | Status |
|----------|-----------|-------|--------|
| Firestore Reads | 50K/day | 35K/day | ✅ Safe |
| Firestore Writes | 20K/day | 15K/day | ✅ Safe |
| Firestore Storage | 1 GB | 600 MB | ✅ Safe |
| Phone Auth | 10K/month | 3K/month | ✅ Safe |
| Storage (images) | 5 GB | 0 GB | ✅ Not Used |
| Analytics | Unlimited | Unlimited | ✅ Free |

**Total Cost**: ✅ **$0/month**

**Scalability**: Free tier supports up to ~5,000 users

---

## Timeline Summary

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Phase 1: Auth | 2 weeks | Working authentication |
| Phase 2: Question Bank | 1 week | Question bank in Firestore |
| Phase 3: Assessment | 1 week | Initial assessment flow |
| Phase 4: Adaptive Questions | 1 week | Daily practice with limits |
| Phase 5: Snap & Solve | 1 week | Updated snap flow |
| Phase 6: Progress | 1 week | Progress dashboard |
| Phase 7: Testing | 1 week | Production-ready app |

**Total**: ~8 weeks (2 months)

---

## Next Steps

1. ✅ Finalize adaptive algorithm with product team
2. ✅ Get initial question bank from product team
3. Create Firebase project
4. Start Phase 1 implementation

---

## Open Questions (For Product Team)

1. **Adaptive Algorithm**: 
   - Simple (0-100 scale)?
   - IRT-based?
   - Custom algorithm?

2. **Question Bank**:
   - How many questions initially?
   - What subjects/chapters?
   - Difficulty distribution?

3. **Pro Tier Pricing** (Future):
   - Monthly: ₹299?
   - Yearly: ₹2,499?
   - Lifetime: ₹4,999?

Let me know when you have answers and we can proceed!
