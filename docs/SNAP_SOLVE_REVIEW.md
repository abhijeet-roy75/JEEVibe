# Snap & Solve Implementation Review

## Current Implementation Summary

### ✅ What's Already Built:

The Snap & Solve feature is **fully functional** with the following components:

#### 1. **Camera Screen** (`camera_screen.dart`)
- ✅ Camera capture and gallery selection
- ✅ Image cropping
- ✅ Snap counter display (shows X/5 snaps)
- ✅ Quick tips UI
- ✅ Priya Ma'am card
- ✅ Navigation to photo review

**Key Features**:
- Uses `AppStateProvider` to check snap limits
- Shows remaining snaps in bottom bar
- Processes images through cropping flow

#### 2. **Solution Screen** (`solution_screen.dart`)
- ✅ Displays OCR-recognized question
- ✅ Shows step-by-step solution with LaTeX rendering
- ✅ Final answer display
- ✅ Priya Ma'am tip
- ✅ Practice section (3 follow-up questions)
- ✅ Action buttons (snap another, back to dashboard)

**Key Features**:
- Increments snap counter on successful solution
- Saves solution to `RecentSolution` (local storage)
- Checks if user can take another snap
- Navigates to daily limit screen if limit reached

#### 3. **API Service** (`api_service.dart`)
- ✅ Image upload to backend
- ✅ OCR + AI solution generation
- ✅ Follow-up question generation
- ✅ Error handling

**Backend**: `https://jeevibe.onrender.com`

#### 4. **Snap Counter Service** (`snap_counter_service.dart`)
- ✅ Daily snap counting (5/day limit)
- ✅ Automatic midnight reset
- ✅ Snap history tracking
- ✅ Remaining snaps calculation

**Storage**: Uses `SharedPreferences` (local only)

#### 5. **Data Models** (`snap_data_model.dart`)
- ✅ `SnapRecord` - Individual snap record
- ✅ `RecentSolution` - Solution for home screen display
- ✅ `UserStats` - Aggregated statistics
- ✅ `PracticeSessionResult` - Quiz results

---

## What Needs Firebase Integration

### 1. **Image Storage** (Currently: Not Stored)

**Current**: Images are passed through the flow but not persisted
**Needed**: Store images locally (not cloud, per your requirement)

```dart
// Add to snap counter increment
Future<void> saveImageLocally(File imageFile, String snapId) async {
  final directory = await getApplicationDocumentsDirectory();
  final imagePath = '${directory.path}/snaps/$snapId.jpg';
  await imageFile.copy(imagePath);
  return imagePath;
}
```

### 2. **Snap History** (Currently: Local Only)

**Current**: Stored in `SharedPreferences`
**Needed**: Store in Firestore

**Firestore Collection**: `users/{uid}/snapHistory/{snapId}`

```javascript
{
  "snapId": "snap_1234567890",
  "timestamp": Timestamp,
  "date": "2024-12-07",
  
  // Image (local path, not cloud)
  "localImagePath": "/path/to/snap.jpg",
  
  // Question
  "questionText": "A body of mass 5 kg...",
  "subject": "Physics",
  "topic": "Newton's Second Law",
  "chapter": "Laws of Motion",
  
  // Solution
  "solutionText": "Using Newton's second law...",
  "solutionSteps": [...],
  "finalAnswer": "4 m/s²",
  "priyaMaamTip": "...",
  
  // Practice questions (3 AI-generated)
  "practiceQuestions": [...],
  "practiceCompleted": false,
  "practiceScore": 0
}
```

### 3. **Daily Snap Counter** (Currently: Local Only)

**Current**: Stored in `SharedPreferences`
**Needed**: Store in Firestore

**Firestore Collection**: `users/{uid}/dailySnapCounter/{date}`

```javascript
{
  "date": "2024-12-07",
  "snapsUsed": 3,
  "snapLimit": 5,
  "snapsRemaining": 2,
  "resetAt": Timestamp,
  "snapIds": ["snap_1", "snap_2", "snap_3"]
}
```

### 4. **Recent Solutions** (Currently: Local Only)

**Current**: Stored in `SharedPreferences` (max 3)
**Needed**: Store in Firestore

**Firestore Collection**: `users/{uid}/recentSolutions/{id}`

```javascript
{
  "id": "snap_1234567890",
  "snapId": "snap_1234567890",  // Reference to snapHistory
  "timestamp": Timestamp,
  "questionPreview": "A body of mass 5 kg is at rest...",
  "subject": "Physics",
  "topic": "Newton's Second Law"
}
```

### 5. **User Stats** (Currently: Local Only)

**Current**: Stored in `SharedPreferences`
**Needed**: Store in Firestore

**Firestore Collection**: `userStats/{uid}`

```javascript
{
  "totalSnapsUsed": 45,
  "snapStats": {
    "totalSnaps": 45,
    "practiceQuestionsAttempted": 120,
    "practiceAccuracy": 65.0
  }
  // ... other stats
}
```

---

## Firebase Integration Plan

### Phase 1: Create Firebase Services

**File**: `lib/services/firebase/firestore_snap_service.dart`

```dart
class FirestoreSnapService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Save snap to Firestore
  Future<void> saveSnap({
    required String uid,
    required String snapId,
    required String localImagePath,
    required Solution solution,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('snapHistory')
        .doc(snapId)
        .set({
      'snapId': snapId,
      'timestamp': FieldValue.serverTimestamp(),
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'localImagePath': localImagePath,
      'questionText': solution.recognizedQuestion,
      'subject': solution.subject,
      'topic': solution.topic,
      'solutionText': solution.solution.approach,
      'solutionSteps': solution.solution.steps,
      'finalAnswer': solution.solution.finalAnswer,
      'priyaMaamTip': solution.solution.priyaMaamTip,
      // ... more fields
    });
  }
  
  // Increment daily snap counter
  Future<void> incrementSnapCounter(String uid) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('dailySnapCounter')
        .doc(today);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      
      if (!snapshot.exists) {
        transaction.set(docRef, {
          'date': today,
          'snapsUsed': 1,
          'snapLimit': 5,
          'snapsRemaining': 4,
          'resetAt': Timestamp.fromDate(
            DateTime.now().add(Duration(days: 1)).copyWith(
              hour: 0, minute: 0, second: 0, millisecond: 0
            )
          ),
          'snapIds': [],
        });
      } else {
        final currentCount = snapshot.data()?['snapsUsed'] ?? 0;
        transaction.update(docRef, {
          'snapsUsed': currentCount + 1,
          'snapsRemaining': 5 - (currentCount + 1),
        });
      }
    });
  }
  
  // Check if user can take snap
  Future<bool> canTakeSnap(String uid) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('dailySnapCounter')
        .doc(today)
        .get();
    
    if (!doc.exists) return true;  // First snap of the day
    
    final snapsUsed = doc.data()?['snapsUsed'] ?? 0;
    final snapLimit = doc.data()?['snapLimit'] ?? 5;
    
    return snapsUsed < snapLimit;
  }
}
```

### Phase 2: Update Existing Services

**File**: `lib/services/snap_counter_service.dart`

```dart
class SnapCounterService {
  final StorageService _storage = StorageService();
  final FirestoreSnapService _firestoreSnap = FirestoreSnapService();
  
  // Update incrementSnap to use Firestore
  Future<void> incrementSnap(String uid, String questionId, String topic, {String? subject}) async {
    // Check Firestore limit
    final canSnap = await _firestoreSnap.canTakeSnap(uid);
    if (!canSnap) {
      throw Exception('Daily snap limit reached');
    }
    
    // Increment in Firestore
    await _firestoreSnap.incrementSnapCounter(uid);
    
    // Also update local storage (for offline)
    final current = await getSnapsUsed();
    await _storage.setSnapCount(current + 1);
    
    // Add to history
    final snapRecord = SnapRecord(
      timestamp: DateTime.now().toIso8601String(),
      questionId: questionId,
      topic: topic,
      subject: subject,
    );
    await _storage.addSnapToHistory(snapRecord);
  }
  
  // Update getSnapsUsed to check Firestore first
  Future<int> getSnapsUsed(String uid) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('dailySnapCounter')
          .doc(today)
          .get();
      
      if (doc.exists) {
        return doc.data()?['snapsUsed'] ?? 0;
      }
      return 0;
    } catch (e) {
      // Fallback to local storage if offline
      return await _storage.getSnapCount();
    }
  }
}
```

### Phase 3: Update Solution Screen

**File**: `lib/screens/solution_screen.dart`

```dart
Future<void> _incrementSnapAndSaveSolution(Solution solution) async {
  try {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    if (uid == null) {
      // User not authenticated, use local storage only
      // ... existing local storage logic
      return;
    }
    
    final snapId = 'snap_${DateTime.now().millisecondsSinceEpoch}';
    
    // Save image locally
    String? localImagePath;
    if (widget.imageFile != null) {
      final directory = await getApplicationDocumentsDirectory();
      localImagePath = '${directory.path}/snaps/$snapId.jpg';
      await widget.imageFile!.copy(localImagePath);
    }
    
    // Save to Firestore
    await FirestoreSnapService().saveSnap(
      uid: uid,
      snapId: snapId,
      localImagePath: localImagePath ?? '',
      solution: solution,
    );
    
    // Increment counter
    await appState.incrementSnap(uid, snapId, solution.topic, subject: solution.subject);
    
    // Also save to local storage (for offline)
    final recentSolution = RecentSolution(
      id: snapId,
      question: solution.recognizedQuestion,
      topic: solution.topic,
      subject: solution.subject,
      timestamp: DateTime.now().toIso8601String(),
      solutionData: {...},
    );
    await appState.addRecentSolution(recentSolution);
    
  } catch (e) {
    debugPrint('Error saving solution: $e');
  }
}
```

### Phase 4: Update App State Provider

**File**: `lib/providers/app_state_provider.dart`

```dart
class AppStateProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final SnapCounterService _snapCounter = SnapCounterService();
  final FirestoreSnapService _firestoreSnap = FirestoreSnapService();
  
  String? _uid;  // Add user ID
  
  // Update initialize to get user ID
  Future<void> initialize() async {
    _uid = FirebaseAuth.instance.currentUser?.uid;
    
    if (_uid != null) {
      // Load from Firestore
      await _loadFromFirestore();
    } else {
      // Load from local storage
      await _loadFromLocalStorage();
    }
    
    _isInitialized = true;
    notifyListeners();
  }
  
  // Load snap count from Firestore
  Future<void> _loadFromFirestore() async {
    if (_uid == null) return;
    
    try {
      _snapsUsed = await _snapCounter.getSnapsUsed(_uid!);
      // ... load other data from Firestore
    } catch (e) {
      // Fallback to local storage
      await _loadFromLocalStorage();
    }
  }
}
```

---

## Migration Strategy

### Option 1: Dual Storage (Recommended)

**Approach**: Write to both Firestore and local storage

**Pros**:
- ✅ Works offline
- ✅ Faster reads (local cache)
- ✅ Firestore as backup

**Cons**:
- ⚠️ More complex code
- ⚠️ Need to sync

**Implementation**:
```dart
// Write to both
await _firestoreSnap.saveSnap(...);  // Cloud
await _storage.addSnapToHistory(...); // Local

// Read from Firestore first, fallback to local
try {
  return await _firestoreSnap.getSnaps(uid);
} catch (e) {
  return await _storage.getSnapHistory();
}
```

### Option 2: Firestore Only

**Approach**: Use Firestore with offline persistence

**Pros**:
- ✅ Simpler code
- ✅ Firestore handles offline automatically

**Cons**:
- ⚠️ Slower reads (network)
- ⚠️ Requires internet for first load

**Implementation**:
```dart
// Enable offline persistence
FirebaseFirestore.instance.settings = Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

**Recommendation**: Use **Option 1** (Dual Storage) for better offline experience.

---

## Summary of Changes Needed

### New Files to Create:
1. ✅ `lib/services/firebase/firestore_snap_service.dart` - Firestore operations
2. ✅ `lib/services/firebase/auth_service.dart` - Firebase Auth (for UID)

### Files to Update:
1. ✅ `lib/services/snap_counter_service.dart` - Add Firestore integration
2. ✅ `lib/screens/solution_screen.dart` - Save to Firestore + local
3. ✅ `lib/providers/app_state_provider.dart` - Load from Firestore
4. ✅ `lib/screens/camera_screen.dart` - Check Firestore limits

### No Changes Needed:
1. ✅ `lib/services/api_service.dart` - Backend API stays the same
2. ✅ `lib/models/snap_data_model.dart` - Models stay the same
3. ✅ UI screens - No UI changes needed

---

## Testing Checklist

- [ ] User can take snap (with auth)
- [ ] Snap counter increments in Firestore
- [ ] Image saved locally (not cloud)
- [ ] Solution saved to Firestore
- [ ] Recent solutions show on home screen
- [ ] Daily limit enforced (5 snaps)
- [ ] Works offline (reads from local cache)
- [ ] Syncs to Firestore when online
- [ ] Midnight reset works
- [ ] User without auth falls back to local storage

---

## Next Steps

1. ✅ Review this document
2. Create Firebase services layer
3. Update existing services to use Firestore
4. Test snap flow end-to-end
5. Test offline mode
6. Test limit enforcement

Ready to proceed with implementation?
