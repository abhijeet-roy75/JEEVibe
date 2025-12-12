const express = require('express');
const router = express.Router();
const { db, storage } = require('../config/firebase');

// Test Firestore connection
router.get('/test/firestore', async (req, res) => {
  try {
    // Test 1: Verify we can access the users collection
    const usersRef = db.collection('users');
    
    // Test 2: Try to get a count of documents (or at least verify collection is accessible)
    const snapshot = await usersRef.limit(1).get();
    
    // Test 3: Try to read a specific document (if it exists)
    const testDoc = await usersRef.doc('connection').get();
    
    // Get total count (optional - might be expensive for large collections)
    const allDocs = await usersRef.limit(10).get();
    const sampleUserIds = allDocs.docs.map(doc => doc.id);
    
    res.json({ 
      success: true, 
      message: 'Firestore connected successfully',
      data: {
        collection: 'users',
        collectionAccessible: true,
        documentCount: allDocs.size,
        sampleDocumentIds: sampleUserIds,
        testDocumentExists: testDoc.exists,
        testDocumentData: testDoc.exists ? testDoc.data() : null
      }
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: error.message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
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