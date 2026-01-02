# Testing Guide - Assessment API

## Quick Start

### Option 1: Automated Test Script (Recommended)

1. **Install axios** (if not already installed):
   ```bash
   cd backend
   npm install axios
   ```

2. **Run the test script**:
   ```bash
   npm run test:api
   ```

   This will:
   - Create/get a test user
   - Test all endpoints
   - Show results

   **Note:** The script uses a custom token which may not work for full authentication. For complete testing, you'll need a real Firebase ID token (see Option 2).

---

### Option 2: Manual Testing with curl

#### Prerequisites

You need a **Firebase ID token**. Get one from:

1. **Flutter App** (easiest):
   ```dart
   User? user = FirebaseAuth.instance.currentUser;
   String? token = await user?.getIdToken();
   print('Token: $token');
   ```

2. **Firebase Console**:
   - Go to Authentication → Users
   - Create a test user
   - Use Firebase Admin SDK or REST API to get token

3. **Test Script** (creates user, but you still need ID token):
   ```bash
   node scripts/test-assessment-api.js
   ```

---

## Manual Testing Steps

### 1. Test Get Questions

```bash
curl -X GET "http://localhost:3000/api/assessment/questions" \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json" | jq
```

**Expected Response:**
```json
{
  "success": true,
  "count": 30,
  "questions": [
    {
      "question_id": "ASSESS_PHY_MECH_001",
      "subject": "Physics",
      "chapter": "Mechanics",
      "question_text": "...",
      "options": ["A", "B", "C", "D"],
      "difficulty": "medium",
      "image_url": null
    }
    // ... 29 more
  ]
}
```

**What to check:**
- ✅ Returns 30 questions
- ✅ No `correct_answer` or `solution_text` fields (sanitized)
- ✅ Questions are randomized (same user gets same order)
- ✅ Without token → 401 error

---

### 2. Test Submit Assessment

First, get the questions (step 1) and note the `question_id` values.

Then submit responses:

```bash
curl -X POST "http://localhost:3000/api/assessment/submit" \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "responses": [
      {
        "question_id": "ASSESS_PHY_MECH_001",
        "student_answer": "A",
        "time_taken_seconds": 95
      },
      {
        "question_id": "ASSESS_PHY_MECH_002",
        "student_answer": "B",
        "time_taken_seconds": 120
      }
      // ... add all 30 question responses
    ]
  }' | jq
```

**Expected Response:**
```json
{
  "success": true,
  "assessment": {
    "status": "completed",
    "completed_at": "2025-01-10T10:30:00Z",
    "time_taken_seconds": 2700
  },
  "theta_by_chapter": {
    "physics_mechanics": {
      "theta": -0.5,
      "percentile": 30.85,
      "confidence_SE": 0.35,
      "attempts": 4,
      "accuracy": 0.50
    },
    "chemistry_organic": {
      "theta": 0.2,
      "percentile": 57.93,
      "confidence_SE": 0.28,
      "attempts": 3,
      "accuracy": 0.67
    }
    // ... more chapters
  },
  "overall_theta": 0.2,
  "overall_percentile": 57.93,
  "chapters_explored": 10,
  "chapters_confident": 8,
  "subject_balance": {
    "physics": 0.35,
    "chemistry": 0.30,
    "mathematics": 0.35
  }
}
```

**What to check:**
- ✅ Theta values are between -3.0 and +3.0
- ✅ Percentiles are between 0 and 100
- ✅ All 30 responses are processed
- ✅ User document updated in Firestore
- ✅ Responses saved in subcollection
- ✅ Cannot submit twice (400 error if already completed)

---

### 3. Test Get Results

```bash
curl -X GET "http://localhost:3000/api/assessment/results/YOUR_USER_ID" \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json" | jq
```

**Expected Response:**
```json
{
  "success": true,
  "assessment": {
    "status": "completed",
    "completed_at": "2025-01-10T10:30:00Z"
  },
  "theta_by_chapter": { ... },
  "overall_theta": 0.2,
  "overall_percentile": 57.93,
  "chapters_explored": 10,
  "chapters_confident": 8,
  "subject_balance": { ... }
}
```

**What to check:**
- ✅ Returns same data as submit response
- ✅ Cannot access other user's results (403 error)
- ✅ Returns 400 if assessment not completed

---

## Testing with Postman

1. **Create a new request**
2. **Set URL**: `http://localhost:3000/api/assessment/questions`
3. **Add Header**:
   - Key: `Authorization`
   - Value: `Bearer YOUR_FIREBASE_ID_TOKEN`
4. **Send request**

---

## Testing with Flutter App

### Get Token
```dart
import 'package:firebase_auth/firebase_auth.dart';

Future<String?> getAuthToken() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    return await user.getIdToken();
  }
  return null;
}
```

### Call API
```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> testAssessmentAPI() async {
  String? token = await getAuthToken();
  if (token == null) {
    print('User not logged in');
    return;
  }
  
  // Get questions
  final response = await http.get(
    Uri.parse('http://localhost:3000/api/assessment/questions'),
    headers: {
      'Authorization': 'Bearer $token',
    },
  );
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print('Questions: ${data['count']}');
  }
}
```

---

## Common Issues

### 1. "Authentication failed"
- **Cause**: Invalid or expired token
- **Fix**: Get a fresh token from Firebase Auth

### 2. "Assessment already completed"
- **Cause**: User already submitted assessment
- **Fix**: Create a new test user or delete the assessment status in Firestore

### 3. "Question not found"
- **Cause**: Questions not populated
- **Fix**: Run `npm run populate:assessment`

### 4. "Index required"
- **Cause**: Firestore indexes not created
- **Fix**: Create indexes as per `FIRESTORE_INDEXES.md`

### 5. "Cannot access other user's results"
- **Cause**: Security check working correctly
- **Fix**: Use the same userId as the authenticated user

---

## Verification Checklist

After testing, verify in Firebase Console:

- [ ] **Firestore → `users` collection**: User document has `theta_by_chapter` field
- [ ] **Firestore → `assessment_responses/{userId}/responses`**: 30 response documents
- [ ] **Firestore → `users/{userId}`**: `assessment.status` = "completed"
- [ ] **No errors in backend logs**

---

## Next Steps

Once testing is complete:
1. ✅ Deploy to Render.com
2. ✅ Update Flutter app to use production URL
3. ✅ Test with real users
4. ✅ Monitor logs and errors
