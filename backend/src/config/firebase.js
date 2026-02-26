const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin SDK
function initializeFirebase() {
  try {
    // Check if already initialized
    if (admin.apps.length > 0) {
      console.log('✅ Firebase Admin already initialized');
      return admin.app();
    }

    // TEST ENVIRONMENT: Use test project (no real Firebase connection)
    if (process.env.NODE_ENV === 'test') {
      console.log('🧪 Test environment detected - using mock Firebase configuration');
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: 'test-project',
          privateKey: '-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC\n-----END PRIVATE KEY-----\n',
          clientEmail: 'test@test-project.iam.gserviceaccount.com',
        }),
        storageBucket: 'test-project.firebasestorage.app'
      });
      console.log('✅ Firebase Admin initialized in TEST mode');
      return admin.app();
    }

    // Option 1: Use service account file (development/local only)
    // Skip file check on Vercel/Render/serverless (no file system access)
    const isVercel = process.env.VERCEL === '1' || process.env.VERCEL_ENV;
    const isRender = process.env.RENDER === 'true' || process.env.RENDER_SERVICE_ID;
    const isProduction = process.env.NODE_ENV === 'production' && !process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    
    if (!isVercel && !isRender && !isProduction) {
      const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './serviceAccountKey.json';
      const resolvedPath = path.resolve(serviceAccountPath);
      
      if (fs.existsSync(resolvedPath)) {
        try {
          const serviceAccount = require(resolvedPath);
          // Try new Firebase Storage format first, fallback to legacy format
          const projectId = serviceAccount.project_id || process.env.FIREBASE_PROJECT_ID || 'jeevibe';
          const storageBucket = `${projectId}.firebasestorage.app`; // New format (preferred)
          // Fallback: `${projectId}.appspot.com` (legacy format)
          
          admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
            storageBucket: storageBucket
          });
          console.log('✅ Firebase Admin initialized with service account file:', resolvedPath);
          return admin.app();
        } catch (fileError) {
          console.error('❌ Error reading service account file:', fileError.message);
          // Fall through to try environment variables
        }
      }
    } else if (isVercel) {
      console.log('🌐 Vercel environment detected - using environment variables only');
    } else if (isRender) {
      console.log('🌐 Render.com environment detected - using environment variables only');
    }
    
    // Option 2: Use environment variables (production)
    if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_PRIVATE_KEY) {
      // Clean and parse private key
      let privateKey = process.env.FIREBASE_PRIVATE_KEY.trim();
      
      // Remove surrounding quotes (single or double) if present
      if ((privateKey.startsWith('"') && privateKey.endsWith('"')) ||
          (privateKey.startsWith("'") && privateKey.endsWith("'"))) {
        privateKey = privateKey.slice(1, -1);
      }
      
      // Replace escaped newlines with actual newlines
      // Handle both \\n (double escaped) and \n (single escaped)
      privateKey = privateKey.replace(/\\n/g, '\n');
      
      // Validate private key format
      if (!privateKey.includes('BEGIN PRIVATE KEY')) {
        throw new Error('Invalid private key format: missing BEGIN PRIVATE KEY marker');
      }
      
      if (!process.env.FIREBASE_CLIENT_EMAIL) {
        throw new Error('FIREBASE_CLIENT_EMAIL is required when using environment variables');
      }
      
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: process.env.FIREBASE_PROJECT_ID,
          privateKey: privateKey,
          clientEmail: process.env.FIREBASE_CLIENT_EMAIL.trim(),
        }),
        storageBucket: `${process.env.FIREBASE_PROJECT_ID}.firebasestorage.app`
      });
      console.log('✅ Firebase Admin initialized with environment variables');
      return admin.app();
    }
    
    throw new Error('Firebase configuration not found. Set FIREBASE_SERVICE_ACCOUNT_PATH or provide FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY, and FIREBASE_CLIENT_EMAIL in .env');
  } catch (error) {
    console.error('❌ Firebase initialization error:', error);
    console.error('Error details:', error.stack);
    throw error;
  }
}

// Initialize on module load
const app = initializeFirebase();

// Export Firestore and Storage instances
const db = admin.firestore();
const storage = admin.storage();
const FieldValue = admin.firestore.FieldValue;

module.exports = {
  admin,
  db,
  storage,
  app,
  FieldValue
};