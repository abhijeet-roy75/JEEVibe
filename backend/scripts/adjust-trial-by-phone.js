/**
 * Adjust trial days by phone number (combines lookup + adjust)
 *
 * Usage: node scripts/adjust-trial-by-phone.js <phoneNumber> <daysRemaining>
 * Example: node scripts/adjust-trial-by-phone.js +17035319704 2
 */

const { db, admin } = require('../src/config/firebase');

async function adjustTrialByPhone(phoneNumber, daysRemaining) {
  if (!phoneNumber || daysRemaining === undefined) {
    console.error('Usage: node scripts/adjust-trial-by-phone.js <phoneNumber> <daysRemaining>');
    console.error('Example: node scripts/adjust-trial-by-phone.js +17035319704 2');
    process.exit(1);
  }

  const days = parseInt(daysRemaining);
  if (isNaN(days) || days < 0 || days > 90) {
    console.error('Days must be a number between 0 and 90');
    process.exit(1);
  }

  try {
    console.log(`\n🔍 Looking up user: ${phoneNumber}`);

    // Find user by phone
    const usersSnapshot = await db.collection('users')
      .where('phoneNumber', '==', phoneNumber)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.log('❌ User not found');
      process.exit(1);
    }

    const userDoc = usersSnapshot.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();

    console.log(`✅ Found user: ${userId}`);
    console.log(`   Name: ${userData.firstName} ${userData.lastName || ''}`);
    console.log(`   Email: ${userData.email}`);

    if (!userData.trial) {
      console.log('❌ User does not have a trial');
      process.exit(1);
    }

    console.log(`\n⏰ Adjusting trial to ${days} days remaining...\n`);

    // Calculate new end date
    const now = new Date();
    const newEndsAt = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);
    const endsAtTimestamp = admin.firestore.Timestamp.fromDate(newEndsAt);

    // Update trial
    await db.collection('users').doc(userId).update({
      'trial.ends_at': endsAtTimestamp,
      'trial.is_active': days > 0,
      updated_at: admin.firestore.Timestamp.now()
    });

    console.log('✅ Trial adjusted successfully!');
    console.log(`   Days remaining: ${days} days`);
    console.log(`   New end date: ${newEndsAt.toISOString()}`);
    console.log(`   Trial active: ${days > 0}`);

    // Show notification stage
    console.log('\n📱 Notification Stage:');
    if (days <= 0) {
      console.log('   🔴 EXPIRED - Trial expired dialog should show');
    } else if (days <= 2) {
      console.log('   🔴 CRITICAL - Red banner with "Last day" or "2 days left"');
    } else if (days <= 5) {
      console.log('   🟠 URGENT - Orange banner should appear on home screen');
    } else if (days <= 23) {
      console.log('   🔵 ACTIVE - No banner (not urgent yet)');
    } else {
      console.log('   ✅ NEW - Trial just started');
    }

    // Show what notifications would be sent
    console.log('\n📧 Expected Notifications (when backend service runs):');
    if (days === 23) console.log('   ✉️  Week 1 email');
    if (days === 5) console.log('   ✉️  5-day urgency email + push');
    if (days === 2) console.log('   ✉️  2-day urgency email + push');
    if (days === 0) console.log('   ✉️  Trial expired email + push + dialog');

    console.log('\n💡 Hot reload your app to see the changes!');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

const [phoneNumber, daysRemaining] = process.argv.slice(2);
adjustTrialByPhone(phoneNumber, daysRemaining);
