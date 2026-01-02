# Firebase Setup for Node.js Backend

## Overview
This guide explains how to connect the Node.js backend to Firebase (Firestore and Storage) for the JEEVibe application.

## Prerequisites
1. Firebase project already created (used by mobile app)
2. Firebase Admin SDK service account key
3. Node.js backend running

## Step 1: Install Firebase Admin SDK

```bash
cd backend
npm install firebase-admin
```

## Step 2: Get Firebase Service Account Key

### Option A: Download from Firebase Console (Recommended for Development)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click **Project Settings** (gear icon)
4. Go to **Service Accounts** tab
5. Click **Generate New Private Key**
6. Download the JSON file
7. **IMPORTANT**: Rename it to `serviceAccountKey.json`
8. Place it in `backend/` directory
9. **Add to .gitignore** (already should be there)

### Option B: Use Environment Variables (Recommended for Production)

Instead of downloading the key file, you can use environment variables:

1. Open the downloaded service account JSON
2. Extract these values:
   - `project_id`
   - `private_key`
   - `client_email`
3. Add to `.env` file (see Step 3)

## Step 3: Update .env File

Add Firebase configuration to `backend/.env`:

```env
# Existing variables
PORT=3000
OPENAI_API_KEY=your_openai_key

# Firebase Configuration
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com

# OR use service account file path (for development)
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
```

**Note**: If using `FIREBASE_SERVICE_ACCOUNT_PATH`, the private key variables are not needed.

## Step 4: Create Firebase Initialization Module

Create `backend/src/config/firebase.js`:

```javascript
const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK
function initializeFirebase() {
  try {
    // Check if already initialized
    if (admin.apps.length > 0) {
      console.log('✅ Firebase Admin already initialized');
      return admin.app();
    }

    // Option 1: Use service account file (development)
    if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
      const serviceAccount = require(path.resolve(process.env.FIREBASE_SERVICE_ACCOUNT_PATH));
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        storageBucket: `${process.env.FIREBASE_PROJECT_ID}.appspot.com`
      });
      console.log('✅ Firebase Admin initialized with service account file');
    }
    // Option 2: Use environment variables (production)
    else if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_PRIVATE_KEY) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: process.env.FIREBASE_PROJECT_ID,
          privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
          clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        }),
        storageBucket: `${process.env.FIREBASE_PROJECT_ID}.appspot.com`
      });
      console.log('✅ Firebase Admin initialized with environment variables');
    }
    else {
      throw new Error('Firebase configuration not found. Set FIREBASE_SERVICE_ACCOUNT_PATH or FIREBASE_PROJECT_ID in .env');
    }

    return admin.app();
  } catch (error) {
    console.error('❌ Firebase initialization error:', error);
    throw error;
  }
}

// Initialize on module load
const app = initializeFirebase();

// Export Firestore and Storage instances
const db = admin.firestore();
const storage = admin.storage();

module.exports = {
  admin,
  db,
  storage,
  app
};
```

## Step 5: Update .gitignore

Ensure `backend/.gitignore` includes:

```
# Firebase
serviceAccountKey.json
*.json
!package*.json

# Environment
.env
.env.local
```

## Step 6: Update index.js to Initialize Firebase

Modify `backend/src/index.js`:

```javascript
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const solveRouter = require('./routes/solve');

// Initialize Firebase (must be before routes)
const { db, storage } = require('./config/firebase');
console.log('🔥 Firebase connected');

// ... rest of your code
```

## Step 7: Test Firebase Connection

Create `backend/src/routes/test-firebase.js` (temporary test route):

```javascript
const express = require('express');
const router = express.Router();
const { db, storage } = require('../config/firebase');

// Test Firestore connection
router.get('/test/firestore', async (req, res) => {
  try {
    const testDoc = await db.collection('test').doc('connection').get();
    res.json({ 
      success: true, 
      message: 'Firestore connected successfully',
      data: testDoc.exists ? testDoc.data() : { message: 'Test document does not exist (this is OK)' }
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

// Test Storage connection
router.get('/test/storage', async (req, res) => {
  try {
    const bucket = storage.bucket();
    const [files] = await bucket.getFiles({ maxResults: 1 });
    res.json({ 
      success: true, 
      message: 'Storage connected successfully',
      fileCount: files.length
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

module.exports = router;
```

Add to `index.js`:
```javascript
const testFirebaseRouter = require('./routes/test-firebase');
app.use('/api', testFirebaseRouter);
```

Test:
```bash
curl http://localhost:3000/api/test/firestore
curl http://localhost:3000/api/test/storage
```

## Step 8: Usage Examples

### Firestore Example

```javascript
const { db } = require('./config/firebase');

// Read user profile
async function getUserProfile(userId) {
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    throw new Error('User not found');
  }
  return userDoc.data();
}

// Update user profile
async function updateUserProfile(userId, data) {
  await db.collection('users').doc(userId).update(data);
}

// Create assessment response
async function saveAssessmentResponse(userId, response) {
  const responseRef = db.collection('assessment_responses')
    .doc(userId)
    .collection('responses')
    .doc();
  
  await responseRef.set({
    ...response,
    created_at: admin.firestore.FieldValue.serverTimestamp()
  });
  
  return responseRef.id;
}
```

### Storage Example

```javascript
const { storage } = require('./config/firebase');

// Upload image to Storage
async function uploadQuestionImage(questionId, imageBuffer, contentType = 'image/svg+xml') {
  const bucket = storage.bucket();
  const file = bucket.file(`questions/initial_assessment/${questionId}.svg`);
  
  await file.save(imageBuffer, {
    metadata: {
      contentType: contentType,
    },
  });
  
  // Make file publicly accessible (or use signed URLs)
  await file.makePublic();
  
  // Get public URL
  const publicUrl = `https://storage.googleapis.com/${bucket.name}/${file.name}`;
  return publicUrl;
}

// Get download URL (for private files)
async function getImageUrl(questionId) {
  const bucket = storage.bucket();
  const file = bucket.file(`questions/initial_assessment/${questionId}.svg`);
  
  const [url] = await file.getSignedUrl({
    action: 'read',
    expires: '03-09-2025', // Expiration date
  });
  
  return url;
}
```

## Step 9: Security Best Practices

1. **Never commit service account key to Git**
   - Already in .gitignore
   - Use environment variables in production

2. **Use Firebase Security Rules**
   - Backend has admin privileges (bypasses rules)
   - Rules protect direct client access

3. **Service Account Permissions**
   - Service account has full access (by design)
   - Limit who can access the backend server
   - Use Firebase App Check for additional protection

4. **Environment Variables**
   - Use secrets management in production (AWS Secrets Manager, etc.)
   - Rotate keys periodically

## Step 10: Verify Setup

1. **Check Firebase Console**
   - Go to Firebase Console → Project Settings
   - Verify service account exists

2. **Test Connection**
   - Run test routes (Step 7)
   - Check server logs for Firebase initialization message

3. **Test Read/Write**
   - Try reading from Firestore
   - Try writing to Firestore
   - Check Firebase Console to verify data

## Troubleshooting

### Error: "Could not load the default credentials"
- **Solution**: Ensure service account key file exists and path is correct
- Check `.env` file has correct `FIREBASE_SERVICE_ACCOUNT_PATH`

### Error: "Permission denied"
- **Solution**: Verify service account has proper permissions in Firebase Console
- Check IAM roles in Google Cloud Console

### Error: "Storage bucket not found"
- **Solution**: Ensure storage bucket name matches project ID
- Check Firebase Console → Storage for bucket name

### Error: "Firebase already initialized"
- **Solution**: This is OK - Firebase Admin can only be initialized once
- The code checks for existing initialization

## Next Steps

After Firebase is connected:
1. Create Firestore service modules (`services/firestoreService.js`)
2. Create Storage service modules (`services/storageService.js`)
3. Implement user profile API endpoints
4. Implement assessment processing
5. Update Firestore security rules

## Resources

- [Firebase Admin SDK Documentation](https://firebase.google.com/docs/admin/setup)
- [Firestore Admin SDK](https://googleapis.dev/nodejs/firestore/latest/)
- [Firebase Storage Admin SDK](https://googleapis.dev/nodejs/storage/latest/)
