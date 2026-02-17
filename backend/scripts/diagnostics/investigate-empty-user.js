/**
 * Investigate empty user record in admin dashboard
 */

const { db } = require('../src/config/firebase');

async function investigateEmptyUser() {
  console.log('🔍 Investigating user with empty data...\n');

  try {
    // Get all users and find ones with missing data
    const usersSnapshot = await db.collection('users').get();

    console.log(`Total users in database: ${usersSnapshot.size}\n`);

    const problematicUsers = [];

    usersSnapshot.forEach(doc => {
      const userData = doc.data();
      const userId = doc.id;

      // Check for missing critical fields
      const hasMissingData = !userData.firstName && !userData.first_name &&
                             !userData.lastName && !userData.last_name &&
                             !userData.email;

      if (hasMissingData) {
        problematicUsers.push({
          userId,
          data: userData
        });
      }
    });

    console.log(`Found ${problematicUsers.length} user(s) with missing name/email data\n`);

    if (problematicUsers.length > 0) {
      problematicUsers.forEach((user, index) => {
        console.log(`\n${'='.repeat(60)}`);
        console.log(`User ${index + 1}: ${user.userId}`);
        console.log('='.repeat(60));

        console.log('\nRaw user data:');
        console.log(JSON.stringify(user.data, null, 2));

        // Check what fields exist
        console.log('\nFields present:');
        Object.keys(user.data).forEach(key => {
          const value = user.data[key];
          if (value && typeof value !== 'object') {
            console.log(`  ${key}: ${value}`);
          } else if (value && typeof value === 'object') {
            console.log(`  ${key}: [object]`);
          }
        });

        // Analyze the issue
        console.log('\nDiagnosis:');
        if (!user.data.phone && !user.data.email) {
          console.log('  ❌ No contact information (phone/email)');
        }
        if (!user.data.createdAt) {
          console.log('  ❌ No creation timestamp');
        } else {
          const createdAt = user.data.createdAt.toDate ? user.data.createdAt.toDate() : new Date(user.data.createdAt);
          console.log(`  ✓ Created: ${createdAt.toISOString()}`);
        }
        if (!user.data.lastActive) {
          console.log('  ❌ No last active timestamp');
        } else {
          const lastActive = user.data.lastActive.toDate ? user.data.lastActive.toDate() : new Date(user.data.lastActive);
          console.log(`  ✓ Last active: ${lastActive.toISOString()}`);
        }
        if (!user.data.assessment || user.data.assessment.status !== 'completed') {
          console.log('  ⚠️  Assessment not completed');
        }

        console.log('\nRecommended action:');
        if (!user.data.phone && !user.data.email && user.data.total_questions_solved === 0) {
          console.log('  → DELETE: Likely a test/incomplete signup with no activity');
        } else if (user.data.phone) {
          console.log('  → INVESTIGATE: Has phone number, might be legitimate user');
        } else {
          console.log('  → REVIEW: Check if this is a test account or corrupt data');
        }
      });
    }

    // Summary
    console.log('\n\n' + '='.repeat(60));
    console.log('SUMMARY');
    console.log('='.repeat(60));

    if (problematicUsers.length === 0) {
      console.log('✅ No users with missing name/email found');
      console.log('   The empty row in admin dashboard might be a display issue');
    } else {
      console.log(`⚠️  Found ${problematicUsers.length} user(s) with incomplete data`);
      console.log('\nOptions:');
      console.log('1. Delete test/incomplete users (if no activity)');
      console.log('2. Add data validation to prevent incomplete records');
      console.log('3. Filter out incomplete users from admin dashboard display');
    }

    console.log('\n✅ Investigation complete\n');

  } catch (error) {
    console.error('❌ Investigation failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  }

  process.exit(0);
}

// Run investigation
investigateEmptyUser();
