/**
 * Check if a user has a trial
 * Usage: node scripts/check-user-trial.js <userId>
 */

const { db } = require('../src/config/firebase');

async function checkUserTrial(userId) {
  if (!userId) {
    console.error('Usage: node scripts/check-user-trial.js <userId>');
    process.exit(1);
  }

  try {
    console.log(`Checking trial for user: ${userId}\n`);

    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      console.log('❌ User not found');
      process.exit(1);
    }

    const userData = userDoc.data();

    console.log('👤 User Info:');
    console.log(`   Name: ${userData.displayName || userData.name || 'N/A'}`);
    console.log(`   Email: ${userData.email || 'N/A'}`);
    console.log(`   Phone: ${userData.phoneNumber || 'N/A'}`);
    console.log(`   Created: ${userData.createdAt?.toDate?.()?.toISOString() || 'N/A'}`);

    if (userData.trial) {
      const now = new Date();
      const endsAt = userData.trial.ends_at?.toDate ? userData.trial.ends_at.toDate() : new Date(userData.trial.ends_at);
      const daysRemaining = Math.ceil((endsAt - now) / (1000 * 60 * 60 * 24));

      console.log('\n✅ Trial Status:');
      console.log(`   Tier: ${userData.trial.tier_id?.toUpperCase() || 'PRO'}`);
      console.log(`   Active: ${userData.trial.is_active ? '✅ Yes' : '❌ No'}`);
      console.log(`   Started: ${userData.trial.started_at?.toDate?.()?.toISOString() || 'N/A'}`);
      console.log(`   Ends: ${endsAt.toISOString()}`);
      console.log(`   Days Remaining: ${daysRemaining} days`);
      console.log(`   Converted to Paid: ${userData.trial.converted_to_paid ? 'Yes' : 'No'}`);

      if (userData.trial.notifications_sent && Object.keys(userData.trial.notifications_sent).length > 0) {
        console.log('\n📧 Notifications Sent:');
        Object.entries(userData.trial.notifications_sent).forEach(([key, value]) => {
          console.log(`   ${key}: ${value.sent_at?.toDate?.()?.toISOString() || 'N/A'} (${value.channels?.join(', ')})`);
        });
      }
    } else {
      console.log('\n❌ No trial found for this user');
    }

    // Check subscription status
    if (userData.subscription) {
      console.log('\n💳 Subscription:');
      Object.entries(userData.subscription).forEach(([subId, sub]) => {
        const endDate = sub.end_date?.toDate ? sub.end_date.toDate() : new Date(sub.end_date);
        const isActive = endDate > new Date();
        console.log(`   ${subId}: ${sub.tier_id?.toUpperCase()} (${isActive ? '✅ Active' : '❌ Expired'})`);
      });
    }

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

const userId = process.argv[2];
checkUserTrial(userId);
