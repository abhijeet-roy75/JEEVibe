# JEEVibe Product & Database Design - Summary of Changes

## Product Vision Update

### Original Vision (V1):
- Primary: Snap & Solve (take photo, get AI solution)
- Secondary: Practice questions from AI

### **New Vision (V2):**
- **Primary**: Adaptive Learning Platform with Question Bank
- **Secondary**: Snap & Solve for custom questions

---

## Key Product Features

### 1. Initial Assessment (NEW)
**When**: After user registration  
**What**: 30 questions (10 each: Physics, Chemistry, Math)  
**Why**: Determine student's current level  
**Output**: Ability score + Level classification (beginner/intermediate/advanced)

### 2. Daily Adaptive Questions (NEW - PRIMARY FEATURE)
**What**: Personalized questions from curated question bank  
**How**: Adaptive difficulty based on user's performance  
**Limits**:
- Free: 10 questions/day
- Pro: Unlimited

**Question Bank Size**: 1000+ questions per subject (3000+ total)

### 3. Snap & Solve (EXISTING - SECONDARY FEATURE)
**What**: Upload custom questions, get AI solutions + 3 practice questions  
**Storage**: **Local only** (not cloud)  
**Limits**:
- Free: 5 snaps/day
- Pro: 20 snaps/day

---

## Major Database Changes

### ✅ What's NEW:

1. **Initial Assessment Collection**
   - Stores 30-question assessment results
   - Calculates ability scores per subject
   - Determines initial level

2. **Daily Practice Collection**
   - Tracks daily adaptive question attempts
   - Enforces tier-based limits
   - Stores performance per day

3. **User Progress Tracking**
   - Ability scores (IRT theta: -3 to +3)
   - Level classification per subject
   - Weekly progress snapshots
   - Weak/strong area identification

4. **Adaptive Algorithm State**
   - Current ability estimates
   - Next question pool
   - Recent question history (avoid repetition)

5. **Tier-Based Limits**
   - Free vs Pro tier configuration
   - Separate limits for adaptive questions and snaps

### 🔄 What CHANGED:

1. **Snap & Solve**
   - Images stored **locally** (not Firebase Storage)
   - Saves storage costs
   - Faster processing
   - Only metadata in Firestore

2. **Question Bank**
   - Enhanced with adaptive metadata
   - IRT calibration parameters
   - Tier restrictions (free vs pro questions)

3. **User Profile**
   - Added ability scores
   - Added level classification
   - Added tier information

### ❌ What's REMOVED:

1. **Firebase Storage** - Not needed (local storage only)
2. **Image compression/upload** - Not needed
3. **Cloud image URLs** - Not needed
4. **Data migration** - Starting fresh

---

## Storage Strategy

### Images (Snap & Solve):
```
✅ Store locally on device
❌ Do NOT upload to cloud
```

**Why?**
- ✅ Free (no storage costs)
- ✅ Fast (no upload time)
- ✅ Privacy (stays on device)
- ✅ Offline access
- ❌ Can't sync across devices (acceptable tradeoff)

**Implementation**:
```dart
// Save to app's documents directory
final directory = await getApplicationDocumentsDirectory();
final imagePath = '${directory.path}/snaps/${timestamp}.jpg';
await File(imagePath).writeAsBytes(imageBytes);

// Store path in Firestore (not the image)
await firestore.collection('snapHistory').doc(snapId).set({
  'localImagePath': imagePath,
  'questionText': ocrText,
  'solution': aiSolution,
  // ... other metadata
});
```

---

## Adaptive Learning Algorithm

### Simplified Approach (No Complex IRT):

**User Ability**: Simple score from 0 to 100
- 0-33: Beginner
- 34-66: Intermediate
- 67-100: Advanced

**Question Selection**:
1. Start with user's current ability level
2. Select questions near that difficulty
3. If user gets it right → slightly harder next time
4. If user gets it wrong → slightly easier next time

**Example**:
```
User ability: 50 (Intermediate)
→ Select question with difficulty 45-55
→ User gets it right
→ New ability: 52
→ Next question difficulty: 50-60
```

**No need for complex IRT** (can add later if needed)

---

## Tier System

### Free Tier:
- ✅ Initial assessment (30 questions)
- ✅ Daily adaptive questions (10/day)
- ✅ Snap & Solve (5/day)
- ✅ Full question bank access
- ✅ Basic progress tracking
- ✅ Basic analytics

### Pro Tier:
- ✅ Everything in Free
- ✅ Unlimited daily adaptive questions
- ✅ Snap & Solve (20/day)
- ✅ Advanced analytics
- ✅ Detailed progress reports
- ✅ Priority support

**Pricing** (TBD):
- Monthly: ₹299/month (~$3.50)
- Yearly: ₹2,499/year (~$30) - Save 30%

---

## Updated Cost Estimate

### Firebase Costs (1000 active users):

| Resource | Free Limit | Usage | Cost |
|----------|-----------|-------|------|
| Firestore Reads | 50K/day | 40K/day | ✅ Free |
| Firestore Writes | 20K/day | 18K/day | ✅ Free |
| Firestore Storage | 1 GB | 800 MB | ✅ Free |
| Phone Auth | 10K/month | 3K/month | ✅ Free |
| Storage (images) | 5 GB | **0 GB** | ✅ **Free** |
| Analytics | Unlimited | Unlimited | ✅ Free |

**Total Cost**: ✅ **$0/month** (within free tier!)

**Scalability**:
- Free tier supports up to ~5,000 users
- After that: ~$20-30/month for 10,000 users

---

## Implementation Priority

### Phase 1: Core Authentication (Week 1-2)
- [ ] Firebase setup
- [ ] Phone auth + OTP
- [ ] PIN lock (local encrypted)
- [ ] Profile setup (6 screens)

### Phase 2: Question Bank (Week 2-3)
- [ ] Upload question bank to Firestore
- [ ] Create question fetching service
- [ ] Implement offline caching

### Phase 3: Initial Assessment (Week 3-4)
- [ ] Assessment screen
- [ ] Question selection logic
- [ ] Ability calculation
- [ ] Results screen

### Phase 4: Daily Adaptive Questions (Week 4-5)
- [ ] Daily practice screen
- [ ] Adaptive question selection
- [ ] Progress tracking
- [ ] Tier limit enforcement

### Phase 5: Snap & Solve (Week 5-6)
- [ ] Update existing snap flow
- [ ] Local image storage
- [ ] Integrate with Firestore
- [ ] Daily limit enforcement

### Phase 6: Progress & Analytics (Week 6-7)
- [ ] Progress dashboard
- [ ] Weak/strong areas
- [ ] Performance graphs
- [ ] Recommendations

**Total Timeline**: ~7 weeks (1.5-2 months)

---

## Questions for Confirmation

### 1. Adaptive Algorithm Complexity
**Question**: Should we use simple ability scoring (0-100) or full IRT?

**Options**:
- **Simple** (0-100 scale): Easier to implement, good enough for MVP
- **IRT** (Item Response Theory): More accurate, but complex

**Recommendation**: Start simple, add IRT later if needed

### 2. Initial Assessment
**Question**: Should assessment be mandatory or optional?

**Options**:
- **Mandatory**: Better personalization, but adds friction
- **Optional**: Smoother onboarding, but less personalized

**Recommendation**: Mandatory (skip button available, but encouraged)

### 3. Question Bank Size
**Question**: Start with 1000 questions per subject or fewer?

**Options**:
- **1000/subject**: Full experience, but more work to curate
- **300/subject**: Faster to launch, expand later

**Recommendation**: Start with 300, expand to 1000 over time

### 4. Offline Mode
**Question**: How much to cache offline?

**Options**:
- **All questions**: ~10 MB, works fully offline
- **Recent questions only**: ~2 MB, partial offline support

**Recommendation**: Cache all questions (10 MB is acceptable)

### 5. Pro Tier Launch
**Question**: Launch with Pro tier from day 1 or add later?

**Options**:
- **Day 1**: Revenue from start, but adds complexity
- **Later**: Simpler MVP, add when user base grows

**Recommendation**: Add later (after 1000+ users)

---

## Next Steps

1. ✅ Review DATABASE_DESIGN_V2.md
2. ✅ Confirm adaptive learning approach
3. ✅ Answer the 5 questions above
4. Create Firebase project
5. Start Phase 1 implementation

---

## Summary

### What Changed:
- ✅ Product focus: Adaptive learning (not just snap & solve)
- ✅ New features: Initial assessment + daily adaptive questions
- ✅ Storage: Local images (not cloud)
- ✅ Cost: $0/month (within free tier)
- ✅ Timeline: ~7 weeks for full implementation

### What Stayed the Same:
- ✅ Firebase as database
- ✅ Phone auth + OTP
- ✅ PIN lock (local encrypted)
- ✅ Question bank structure
- ✅ Snap & Solve feature (now secondary)

Ready to proceed? Let me know your thoughts!
