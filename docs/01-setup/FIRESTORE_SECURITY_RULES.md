# Firestore Security Rules Configuration

## Overview

These security rules implement our hybrid architecture:
- **Backend API**: All writes go through backend (Admin SDK bypasses rules)
- **Direct Reads**: Mobile app can read directly from Firestore for performance

## Rules Summary

### ✅ Allowed (Mobile App)

1. **Users Collection** (`/users/{userId}`)
   - ✅ Read: Users can read their own profile
   - ❌ Write: Disabled (must use backend API)

2. **Assessment Questions** (`/initial_assessment_questions/{questionId}`)
   - ✅ Read: Authenticated users can read questions
   - ❌ Write: Disabled (backend only)

3. **Assessment Responses** (`/assessment_responses/{userId}/responses/{responseId}`)
   - ✅ Read: Users can read their own responses
   - ❌ Write: Disabled (backend only)

4. **Quizzes** (`/quizzes/{userId}/quizzes/{quizId}`)
   - ✅ Read: Users can read their own quiz history
   - ❌ Write: Disabled (backend only)

5. **Student Responses** (`/student_responses/{userId}/responses/{responseId}`)
   - ✅ Read: Users can read their own question responses
   - ❌ Write: Disabled (backend only)

6. **Questions** (`/questions/{questionId}`)
   - ✅ Read: Authenticated users can read questions
   - ❌ Write: Disabled (backend only)

### ❌ Denied (Backend Only)

1. **System Events** (`/system_events/{eventId}`)
   - ❌ No client access (backend only)

2. **All Other Collections**
   - ❌ Default deny all

## How It Works

### Backend Writes (Admin SDK)
- Backend uses Firebase Admin SDK with service account
- Admin SDK **bypasses all security rules**
- Backend can read/write to any collection
- This is by design - backend has full access

### Mobile App Reads
- Mobile app uses Firebase Client SDK
- Must be authenticated (Firebase Auth)
- Can only read their own data (UID matches document ID)
- Cannot write directly (rules block it)

### Mobile App Writes
- Mobile app **cannot write directly**
- Must call backend API endpoints
- Backend validates and writes using Admin SDK

## Deployment

### Option 1: Firebase Console (Recommended)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (jeevibe)
3. Go to **Firestore Database** → **Rules** tab
4. Copy contents of `firestore.rules` file
5. Paste into the rules editor
6. Click **Publish**

### Option 2: Firebase CLI

```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in project (if not already done)
cd /Users/abhijeetroy/Documents/JEEVibe
firebase init firestore

# Deploy rules
firebase deploy --only firestore:rules
```

## Testing Rules

### Test 1: User can read own profile
```javascript
// In mobile app (authenticated as user_123)
const userDoc = await firestore.collection('users').doc('user_123').get();
// ✅ Should succeed
```

### Test 2: User cannot read other user's profile
```javascript
// In mobile app (authenticated as user_123)
const otherDoc = await firestore.collection('users').doc('user_456').get();
// ❌ Should fail with permission denied
```

### Test 3: User cannot write to users collection
```javascript
// In mobile app (authenticated as user_123)
await firestore.collection('users').doc('user_123').update({name: 'Test'});
// ❌ Should fail with permission denied
```

### Test 4: User can read assessment questions
```javascript
// In mobile app (authenticated)
const question = await firestore.collection('initial_assessment_questions')
  .doc('ASSESS_PHY_MECH_001').get();
// ✅ Should succeed
```

## Security Considerations

1. **Backend Validation**: Even though backend can write anything, always validate:
   - User authentication (verify JWT token)
   - User authorization (user can only update their own data)
   - Data validation (schema, types, constraints)

2. **Rate Limiting**: Implement rate limiting on backend APIs to prevent abuse

3. **Audit Logging**: Log all writes in backend for security auditing

4. **Regular Reviews**: Review security rules quarterly as new features are added

## Updating Rules

When adding new collections:

1. Add rules to `firestore.rules` file
2. Test locally using Firebase Emulator (optional)
3. Deploy to Firebase Console
4. Test in production with real users
5. Monitor Firebase Console → Firestore → Usage for errors

## Common Patterns

### Pattern 1: User-Owned Data
```javascript
match /collection/{userId}/subcollection/{docId} {
  allow read: if isOwner(userId);
  allow write: if false;  // Backend only
}
```

### Pattern 2: Public Read, Backend Write
```javascript
match /collection/{docId} {
  allow read: if isAuthenticated();
  allow write: if false;  // Backend only
}
```

### Pattern 3: Backend Only
```javascript
match /collection/{docId} {
  allow read, write: if false;  // Backend only
}
```

## Troubleshooting

### Error: "Missing or insufficient permissions"
- Check user is authenticated: `request.auth != null`
- Check user owns the document: `request.auth.uid == userId`
- Verify rules are deployed: Check Firebase Console

### Error: "Permission denied" on write
- Expected behavior - writes must go through backend API
- Update mobile app to use backend API instead of direct Firestore writes

### Rules not updating
- Clear browser cache
- Wait 1-2 minutes for propagation
- Check Firebase Console → Rules tab to verify deployment
