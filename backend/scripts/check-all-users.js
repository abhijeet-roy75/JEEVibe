/**
 * Check all users in database for profile data integrity
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function checkAllUsers() {
  try {
    console.log('========== Checking All Users ==========\n');

    const usersSnapshot = await db.collection('users').get();

    if (usersSnapshot.empty) {
      console.log('❌ No users found in database');
      process.exit(0);
    }

    console.log(`📊 Total users: ${usersSnapshot.size}\n`);

    const issues = [];
    let validUsers = 0;

    usersSnapshot.docs.forEach((doc, index) => {
      const userId = doc.id;
      const userData = doc.data();
      const userIssues = [];

      // Check essential fields
      if (!userData.phoneNumber) {
        userIssues.push('Missing phoneNumber');
      }

      if (!userData.firstName && !userData.displayName) {
        userIssues.push('Missing firstName/displayName');
      }

      // Check JEE target exam date consistency
      if (userData.jeeTargetExamDate) {
        // If has jeeTargetExamDate, should have currentClass
        if (!userData.currentClass) {
          userIssues.push('Has jeeTargetExamDate but missing currentClass');
        }

        // Check if currentClass is string (not number)
        if (userData.currentClass && typeof userData.currentClass === 'number') {
          userIssues.push(`currentClass is number (${userData.currentClass}), should be string`);
        }
      }

      // Check subscription tier
      if (!userData.subscriptionTier) {
        userIssues.push('Missing subscriptionTier');
      }

      if (userIssues.length === 0) {
        validUsers++;
      } else {
        issues.push({
          userId,
          phoneNumber: userData.phoneNumber || 'N/A',
          name: userData.firstName || userData.displayName || 'N/A',
          issues: userIssues
        });
      }

      // Show progress every 10 users
      if ((index + 1) % 10 === 0) {
        console.log(`Checked ${index + 1}/${usersSnapshot.size} users...`);
      }
    });

    console.log('\n========== Summary ==========');
    console.log(`✅ Valid users: ${validUsers}`);
    console.log(`⚠️  Users with issues: ${issues.length}\n`);

    if (issues.length > 0) {
      console.log('========== Users with Issues ==========\n');
      issues.forEach((item, index) => {
        console.log(`${index + 1}. User ID: ${item.userId}`);
        console.log(`   Phone: ${item.phoneNumber}`);
        console.log(`   Name: ${item.name}`);
        console.log(`   Issues:`);
        item.issues.forEach(issue => {
          console.log(`     - ${issue}`);
        });
        console.log('');
      });
    }

    console.log('✅ Check complete!');
    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkAllUsers();
