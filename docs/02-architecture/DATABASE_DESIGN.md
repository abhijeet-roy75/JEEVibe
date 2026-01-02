# JEEVibe Database Design - Firebase

## Overview

This document outlines the complete database schema for JEEVibe using **Firebase** (Firestore + Firebase Authentication). The design supports:

- User authentication (phone + OTP + PIN)
- Student profile management with dropdowns
- Question bank storage (hierarchical by subject/chapter)
- User statistics and progress tracking
- Snap history and solution tracking
- Quiz/practice performance over time

---

## Why Firebase?

> [!IMPORTANT]
> **Recommendation: Firebase is the best choice for JEEVibe**

### Advantages:
1. ✅ **Built-in Phone Authentication** - Native OTP support for India and US
2. ✅ **Real-time Database** - Firestore provides real-time sync
3. ✅ **Scalability** - Auto-scales with user growth
4. ✅ **Offline Support** - Works offline, syncs when online
5. ✅ **Security Rules** - Row-level security built-in
6. ✅ **Free Tier** - Generous free tier for development/testing
7. ✅ **Flutter Integration** - Excellent Flutter SDK support
8. ✅ **Global CDN** - Fast in India and worldwide

### Firebase Services We'll Use:
- **Firebase Authentication** - Phone auth with OTP
- **Cloud Firestore** - NoSQL database for all data
- **Firebase Storage** - For storing question images (future)
- **Firebase Analytics** - Track user engagement (optional)

---

## Database Schema

### 1. Authentication Layer (Firebase Auth)

Firebase Authentication handles:
- Phone number verification
- OTP generation and validation
- User session management
- UID generation (unique user identifier)

**Custom Claims** (stored in Firebase Auth):
```json
{
  "phoneNumber": "+919876543210",
  "uid": "firebase_generated_uid",
  "customClaims": {
    "isPro": false,
    "role": "student"
  }
}
```

---

### 2. Firestore Collections

#### Collection: `users`
**Document ID**: Firebase Auth UID

```javascript
{
  // Basic Info
  "uid": "firebase_auth_uid",
  "phoneNumber": "+919876543210",
  "phoneCountryCode": "+91",
  "pin": "hashed_pin_value", // bcrypt hash
  "createdAt": Timestamp,
  "lastLoginAt": Timestamp,
  
  // Profile - Basic
  "firstName": "Rahul",
  "lastName": "Sharma",
  "email": "rahul@example.com", // optional
  "dateOfBirth": "2006-05-15", // YYYY-MM-DD
  "gender": "Male", // Male, Female, Other, Prefer not to say
  
  // Profile - Academic
  "currentClass": "12", // 11, 12, Dropper
  "targetExam": "JEE Main + Advanced", // See dropdown values below
  "targetYear": "2025", // 2025, 2026, 2027, 2028
  "schoolName": "Delhi Public School",
  "city": "Mumbai",
  "state": "Maharashtra",
  
  // Profile - Advanced
  "coachingInstitute": "FIITJEE", // Optional, see dropdown values
  "coachingBranch": "Kalu Sarai, Delhi", // Optional
  "studyMode": "Coaching + Self-study", // See dropdown values
  "preferredLanguage": "English", // English, Hindi, Bilingual
  "weakSubjects": ["Physics", "Mathematics"], // Array of subjects
  "strongSubjects": ["Chemistry"], // Array of subjects
  
  // Subscription
  "isPro": false,
  "proExpiryDate": null, // Timestamp or null
  "proStartDate": null,
  
  // Settings
  "notificationsEnabled": true,
  "dailyGoalSnaps": 5,
  "profileCompleted": true, // true after profile setup
  
  // Metadata
  "appVersion": "1.0.0",
  "platform": "iOS", // iOS, Android
  "deviceInfo": "iPhone 14 Pro"
}
```

---

#### Collection: `userStats`
**Document ID**: Firebase Auth UID

```javascript
{
  "uid": "firebase_auth_uid",
  "updatedAt": Timestamp,
  
  // Snap Statistics
  "totalSnapsUsed": 150,
  "snapsToday": 3,
  "lastSnapDate": Timestamp,
  "currentStreak": 7, // days
  "longestStreak": 15,
  
  // Practice Statistics
  "totalQuestionsPracticed": 450,
  "totalCorrect": 320,
  "totalIncorrect": 130,
  "overallAccuracy": 71.1, // percentage
  
  // Subject-wise Stats
  "subjectStats": {
    "Physics": {
      "questionsPracticed": 150,
      "correct": 100,
      "incorrect": 50,
      "accuracy": 66.7,
      "timeSpent": 7200, // seconds
      "lastPracticed": Timestamp
    },
    "Chemistry": {
      "questionsPracticed": 150,
      "correct": 120,
      "incorrect": 30,
      "accuracy": 80.0,
      "timeSpent": 6000,
      "lastPracticed": Timestamp
    },
    "Mathematics": {
      "questionsPracticed": 150,
      "correct": 100,
      "incorrect": 50,
      "accuracy": 66.7,
      "timeSpent": 8400,
      "lastPracticed": Timestamp
    }
  },
  
  // Chapter-wise Stats (nested)
  "chapterStats": {
    "Physics_Laws_of_Motion": {
      "questionsPracticed": 25,
      "correct": 18,
      "incorrect": 7,
      "accuracy": 72.0,
      "avgDifficulty": 1.2, // IRT difficulty
      "lastPracticed": Timestamp
    }
    // ... more chapters
  },
  
  // Difficulty-wise Stats
  "difficultyStats": {
    "easy": { "practiced": 200, "correct": 180, "accuracy": 90.0 },
    "medium": { "practiced": 180, "correct": 110, "accuracy": 61.1 },
    "hard": { "practiced": 70, "correct": 30, "accuracy": 42.9 }
  },
  
  // Time-based Stats
  "avgTimePerQuestion": 95, // seconds
  "totalStudyTime": 21600, // seconds (6 hours)
  
  // Achievements
  "badges": ["first_snap", "week_streak", "100_questions"],
  "level": 5,
  "xp": 1250
}
```

---

#### Collection: `snapHistory`
**Subcollection under**: `users/{uid}/snapHistory`
**Document ID**: Auto-generated

```javascript
{
  "snapId": "auto_generated_id",
  "uid": "firebase_auth_uid",
  "timestamp": Timestamp,
  "date": "2024-12-07", // YYYY-MM-DD for easy querying
  
  // Question Info
  "questionId": "PHY_LOM_E_001", // If from question bank
  "questionText": "A body of mass 5 kg...",
  "questionImageUrl": "gs://bucket/snaps/snap_123.jpg", // Firebase Storage URL
  
  // Classification
  "subject": "Physics",
  "chapter": "Laws of Motion",
  "topic": "Newton's Second Law",
  "difficulty": "easy",
  
  // Solution
  "solutionText": "Using Newton's second law...",
  "solutionSteps": [...], // Array of solution steps
  
  // Follow-up Quiz
  "quizCompleted": true,
  "quizScore": 2, // out of 3
  "quizQuestions": [...], // Array of quiz questions
  "quizAnswers": [...], // User's answers
  
  // Metadata
  "processingTime": 3.5, // seconds
  "ocrConfidence": 0.95,
  "aiModel": "gpt-4-vision"
}
```

---

#### Collection: `dailySnapCounter`
**Subcollection under**: `users/{uid}/dailySnapCounter`
**Document ID**: Date string (YYYY-MM-DD)

```javascript
{
  "date": "2024-12-07",
  "snapsUsed": 3,
  "snapLimit": 5,
  "snapsRemaining": 2,
  "resetAt": Timestamp, // Midnight IST
  "snapIds": ["snap_1", "snap_2", "snap_3"] // References to snapHistory
}
```

---

#### Collection: `recentSolutions`
**Subcollection under**: `users/{uid}/recentSolutions`
**Document ID**: Auto-generated (limited to 3 most recent)

```javascript
{
  "id": "auto_generated_id",
  "snapId": "reference_to_snap_history",
  "timestamp": Timestamp,
  "questionPreview": "A body of mass 5 kg is at rest...",
  "subject": "Physics",
  "topic": "Newton's Second Law",
  "thumbnailUrl": "gs://bucket/thumbnails/snap_123_thumb.jpg"
}
```

---

#### Collection: `practiceHistory`
**Subcollection under**: `users/{uid}/practiceHistory`
**Document ID**: Auto-generated

```javascript
{
  "sessionId": "auto_generated_id",
  "uid": "firebase_auth_uid",
  "timestamp": Timestamp,
  "date": "2024-12-07",
  
  // Session Info
  "sessionType": "followup_quiz", // followup_quiz, practice_mode, mock_test
  "subject": "Physics",
  "chapter": "Laws of Motion",
  
  // Performance
  "totalQuestions": 3,
  "correctAnswers": 2,
  "incorrectAnswers": 1,
  "skippedAnswers": 0,
  "accuracy": 66.7,
  
  // Timing
  "totalTime": 180, // seconds
  "avgTimePerQuestion": 60,
  
  // Questions
  "questions": [
    {
      "questionId": "PHY_LOM_E_001",
      "userAnswer": "B",
      "correctAnswer": "B",
      "isCorrect": true,
      "timeTaken": 45,
      "difficulty": "easy"
    }
    // ... more questions
  ],
  
  // Source
  "sourceSnapId": "snap_123" // If from follow-up quiz
}
```

---

### 3. Question Bank Collections

#### Collection: `questionBank`
**Document ID**: Subject name (e.g., "Physics")

```javascript
{
  "subject": "Physics",
  "totalQuestions": 5000,
  "lastUpdated": Timestamp,
  "version": "1.0",
  
  // Metadata
  "chapters": [
    {
      "chapterId": "laws_of_motion",
      "chapterName": "Laws of Motion",
      "unit": "Unit 3",
      "questionCount": 150,
      "difficultyDistribution": {
        "easy": 50,
        "medium": 70,
        "hard": 30
      }
    }
    // ... more chapters
  ]
}
```

#### Subcollection: `questionBank/{subject}/questions`
**Document ID**: Question ID (e.g., "PHY_LOM_E_001")

```javascript
{
  // From your JSON structure
  "question_id": "PHY_LOM_E_001",
  "subject": "Physics",
  "chapter": "Laws of Motion",
  "unit": "Unit 3",
  "sub_topics": ["Newton's First Law", "Inertia"],
  
  // Difficulty
  "difficulty": "easy", // easy, medium, hard
  "difficulty_irt": 0.5, // IRT difficulty score
  "priority": "HIGH", // HIGH, MEDIUM, LOW
  
  // Question
  "question_type": "mcq_single", // mcq_single, mcq_multiple, numerical, integer
  "question_text": "A body of mass 5 kg is at rest...",
  "question_text_html": "A body of mass 5 kg is at rest...",
  "question_latex": null,
  
  // Options (for MCQ)
  "options": [
    {
      "option_id": "A",
      "text": "2 m/s²",
      "html": "2 m/s<sup>2</sup>"
    }
    // ... more options
  ],
  
  // Answer
  "correct_answer": "B",
  "correct_answer_text": "4 m/s²",
  "correct_answer_exact": null,
  "correct_answer_unit": "m/s²",
  "answer_type": "single_choice",
  "answer_range": null,
  
  // Solution
  "solution_text": "Using Newton's second law: F = ma...",
  "solution_steps": [
    {
      "step_number": 1,
      "description": "Apply Newton's second law",
      "formula": "F = ma",
      "calculation": null,
      "explanation": "The net force on a body equals...",
      "result": null
    }
    // ... more steps
  ],
  
  // Metadata
  "concepts_tested": ["Newton's Second Law", "Force and acceleration relationship"],
  "time_estimate": 60, // seconds
  "weightage_marks": 4,
  "jee_year_similar": "2020",
  "jee_pattern": "Direct application of F=ma",
  
  // Creation/Validation
  "created_date": Timestamp,
  "created_by": "claude_ai",
  "validated_by": null,
  "validation_status": "pending", // pending, validated, rejected
  "validation_date": null,
  "validation_notes": null,
  
  // Additional Metadata
  "metadata": {
    "formula_used": "F = ma",
    "common_mistakes": ["Dividing m by F instead of F by m"],
    "hint": "Use Newton's second law directly",
    "key_insight": "Fundamental application of F=ma on smooth surface",
    "elimination_strategy": "Option A is too small for 20N force..."
  },
  
  // Usage Statistics (updated from user interactions)
  "usage_stats": {
    "times_shown": 1250,
    "times_correct": 890,
    "times_incorrect": 360,
    "avg_time_taken": 58, // seconds
    "accuracy_rate": 71.2, // percentage
    "last_shown": Timestamp
  },
  
  // Tags
  "tags": ["newtons_second_law", "acceleration", "basic_mechanics", "smooth_surface"],
  
  // Distractor Analysis (for MCQ)
  "distractor_analysis": {
    "A": "Students might incorrectly calculate 10/5...",
    "C": "Confusion between mass value and acceleration",
    "D": "Using wrong formula or inverting..."
  },
  
  // Alternate Answers
  "alternate_correct_answers": ["4", "4.0"]
}
```

---

### 4. Lookup/Reference Collections

#### Collection: `lookupValues`
**Document ID**: Category name

```javascript
// Document: "targetExams"
{
  "category": "targetExams",
  "values": [
    { "id": "jee_main", "label": "JEE Main", "order": 1 },
    { "id": "jee_main_advanced", "label": "JEE Main + Advanced", "order": 2 },
    { "id": "jee_advanced", "label": "JEE Advanced", "order": 3 },
    { "id": "bitsat", "label": "BITSAT", "order": 4 },
    { "id": "wbjee", "label": "WBJEE", "order": 5 },
    { "id": "mhtcet", "label": "MHT CET", "order": 6 },
    { "id": "kcet", "label": "KCET", "order": 7 },
    { "id": "other", "label": "Other", "order": 8 }
  ],
  "lastUpdated": Timestamp
}

// Document: "currentClass"
{
  "category": "currentClass",
  "values": [
    { "id": "11", "label": "Class 11", "order": 1 },
    { "id": "12", "label": "Class 12", "order": 2 },
    { "id": "dropper", "label": "Dropper (12th Pass)", "order": 3 }
  ],
  "lastUpdated": Timestamp
}

// Document: "targetYears"
{
  "category": "targetYears",
  "values": [
    { "id": "2025", "label": "2025", "order": 1 },
    { "id": "2026", "label": "2026", "order": 2 },
    { "id": "2027", "label": "2027", "order": 3 },
    { "id": "2028", "label": "2028", "order": 4 }
  ],
  "lastUpdated": Timestamp
}

// Document: "coachingInstitutes"
{
  "category": "coachingInstitutes",
  "values": [
    { "id": "none", "label": "No Coaching", "order": 1 },
    { "id": "fiitjee", "label": "FIITJEE", "order": 2 },
    { "id": "allen", "label": "Allen", "order": 3 },
    { "id": "resonance", "label": "Resonance", "order": 4 },
    { "id": "aakash", "label": "Aakash", "order": 5 },
    { "id": "vibrant", "label": "Vibrant Academy", "order": 6 },
    { "id": "pw", "label": "Physics Wallah", "order": 7 },
    { "id": "unacademy", "label": "Unacademy", "order": 8 },
    { "id": "vedantu", "label": "Vedantu", "order": 9 },
    { "id": "other", "label": "Other", "order": 10 }
  ],
  "lastUpdated": Timestamp
}

// Document: "studyModes"
{
  "category": "studyModes",
  "values": [
    { "id": "self_study", "label": "Self-study only", "order": 1 },
    { "id": "coaching_only", "label": "Coaching only", "order": 2 },
    { "id": "coaching_self", "label": "Coaching + Self-study", "order": 3 },
    { "id": "online_only", "label": "Online classes only", "order": 4 },
    { "id": "hybrid", "label": "Hybrid (Online + Offline)", "order": 5 }
  ],
  "lastUpdated": Timestamp
}

// Document: "indianStates"
{
  "category": "indianStates",
  "values": [
    { "id": "andhra_pradesh", "label": "Andhra Pradesh", "order": 1 },
    { "id": "delhi", "label": "Delhi", "order": 2 },
    { "id": "maharashtra", "label": "Maharashtra", "order": 3 },
    { "id": "karnataka", "label": "Karnataka", "order": 4 },
    // ... all Indian states
  ],
  "lastUpdated": Timestamp
}

// Document: "subjects"
{
  "category": "subjects",
  "values": [
    { "id": "physics", "label": "Physics", "order": 1 },
    { "id": "chemistry", "label": "Chemistry", "order": 2 },
    { "id": "mathematics", "label": "Mathematics", "order": 3 }
  ],
  "lastUpdated": Timestamp
}

// Document: "languages"
{
  "category": "languages",
  "values": [
    { "id": "english", "label": "English", "order": 1 },
    { "id": "hindi", "label": "Hindi", "order": 2 },
    { "id": "bilingual", "label": "Bilingual (English + Hindi)", "order": 3 }
  ],
  "lastUpdated": Timestamp
}
```

---

## Migration Strategy

### Phase 1: Move Existing Local Data to Firebase

Current local storage (SharedPreferences) → Firebase:

| Local Storage Key | Firebase Location |
|------------------|-------------------|
| `snap_count` | `users/{uid}/dailySnapCounter/{date}/snapsUsed` |
| `snap_history` | `users/{uid}/snapHistory/{snapId}` |
| `recent_solutions` | `users/{uid}/recentSolutions/{id}` |
| `total_questions_practiced` | `userStats/{uid}/totalQuestionsPracticed` |
| `total_correct` | `userStats/{uid}/totalCorrect` |
| `has_seen_welcome` | `users/{uid}/profileCompleted` |

### Migration Script:
```dart
Future<void> migrateLocalDataToFirebase(String uid) async {
  // 1. Get all local data
  final snapHistory = await StorageService().getSnapHistory();
  final recentSolutions = await StorageService().getRecentSolutions();
  final stats = await StorageService().getStats();
  
  // 2. Upload to Firebase
  final batch = FirebaseFirestore.instance.batch();
  
  // Migrate snap history
  for (var snap in snapHistory) {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('snapHistory')
        .doc();
    batch.set(docRef, snap.toJson());
  }
  
  // Migrate stats
  final statsRef = FirebaseFirestore.instance
      .collection('userStats')
      .doc(uid);
  batch.set(statsRef, stats.toJson());
  
  // Commit batch
  await batch.commit();
  
  // 3. Clear local storage (optional - keep as backup initially)
  // await StorageService().clearAllData();
}
```

---

## Security Rules (Firestore)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(uid) {
      return isAuthenticated() && request.auth.uid == uid;
    }
    
    // Users collection
    match /users/{uid} {
      allow read: if isOwner(uid);
      allow create: if isAuthenticated() && request.auth.uid == uid;
      allow update: if isOwner(uid);
      allow delete: if false; // Never allow deletion
      
      // Subcollections
      match /snapHistory/{snapId} {
        allow read, write: if isOwner(uid);
      }
      
      match /recentSolutions/{solutionId} {
        allow read, write: if isOwner(uid);
      }
      
      match /dailySnapCounter/{date} {
        allow read, write: if isOwner(uid);
      }
      
      match /practiceHistory/{sessionId} {
        allow read, write: if isOwner(uid);
      }
    }
    
    // User stats
    match /userStats/{uid} {
      allow read: if isOwner(uid);
      allow write: if isOwner(uid);
    }
    
    // Question bank - read-only for all authenticated users
    match /questionBank/{subject} {
      allow read: if isAuthenticated();
      allow write: if false; // Only admins via backend
      
      match /questions/{questionId} {
        allow read: if isAuthenticated();
        allow write: if false;
      }
    }
    
    // Lookup values - read-only for all
    match /lookupValues/{category} {
      allow read: if true; // Public read
      allow write: if false; // Only admins
    }
  }
}
```

---

## Indexing Strategy

### Composite Indexes (create in Firebase Console):

```javascript
// 1. Snap history by date
Collection: users/{uid}/snapHistory
Fields: date (Ascending), timestamp (Descending)

// 2. Practice history by subject and date
Collection: users/{uid}/practiceHistory
Fields: subject (Ascending), date (Descending)

// 3. Questions by subject, chapter, difficulty
Collection: questionBank/{subject}/questions
Fields: chapter (Ascending), difficulty (Ascending), difficulty_irt (Ascending)

// 4. Questions by tags
Collection: questionBank/{subject}/questions
Fields: tags (Array), difficulty (Ascending)
```

---

## API Integration Points

### Backend → Firebase:
- Store AI-generated solutions in `snapHistory`
- Update question `usage_stats` after each attempt
- Create practice sessions in `practiceHistory`

### Flutter App → Firebase:
- Real-time listeners for user stats
- Fetch questions from question bank
- Update user profile
- Track snap counter

---

## Data Retention & Privacy

- **User Data**: Retained as long as account is active
- **Snap History**: Retained for 1 year (configurable)
- **Practice History**: Retained for 2 years
- **Question Bank**: Permanent
- **Deletion**: User can request account deletion (GDPR compliant)

---

## Cost Estimation (Firebase Free Tier)

| Resource | Free Tier Limit | Estimated Usage (1000 users) |
|----------|----------------|------------------------------|
| Firestore Reads | 50K/day | ~30K/day ✅ |
| Firestore Writes | 20K/day | ~15K/day ✅ |
| Storage | 1 GB | ~500 MB ✅ |
| Phone Auth | 10K verifications/month | ~3K/month ✅ |

**Conclusion**: Free tier sufficient for initial launch and testing.

---

## Next Steps

1. ✅ Review and approve this database design
2. Set up Firebase project
3. Configure Firebase Authentication (Phone)
4. Create Firestore collections and indexes
5. Implement security rules
6. Add Firebase SDK to Flutter app
7. Build authentication screens
8. Build profile setup screens
9. Migrate existing local data
10. Upload question bank JSON to Firestore

---

## Questions for Review

1. **PIN Storage**: Should we store PIN locally (encrypted) for quick unlock, or always require Firebase auth?
2. **Offline Mode**: Should we cache question bank locally for offline practice?
3. **Image Storage**: Should we store snap images in Firebase Storage or just keep metadata?
4. **Analytics**: Should we enable Firebase Analytics from day 1?
5. **Question Bank Updates**: How will we update question bank? Manual upload or automated sync?
