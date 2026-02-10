require('dotenv').config();
const { db } = require('../src/config/firebase');

async function getUserData() {
  const userId = 'ZlCLBTKAFoTCSHBApO7PFXGQxZH3';

  const userDoc = await db.collection('users').doc(userId).get();

  if (!userDoc.exists) {
    console.log('User not found');
    process.exit(1);
  }

  const userData = userDoc.data();

  console.log('USER DATA:');
  console.log('==========');
  console.log('Name:', userData.firstName || userData.first_name);
  console.log('Phone:', userData.phone);
  console.log('Overall theta:', userData.overall_theta);
  console.log('Overall percentile:', userData.overall_percentile);
  console.log('');
  console.log('Subject accuracy:', JSON.stringify(userData.subject_accuracy, null, 2));
  console.log('');

  // Check theta_by_chapter for history
  console.log('THETA BY CHAPTER (first 3):');
  const thetaByChapter = userData.theta_by_chapter || {};
  Object.entries(thetaByChapter).slice(0, 3).forEach(([key, data]) => {
    console.log(key + ':', {
      theta: data.theta,
      percentile: data.percentile,
      attempts: data.attempts,
      accuracy: data.accuracy
    });
  });

  console.log('');
  console.log('CHECKING SNAPSHOTS:');

  // Check theta_snapshots collection
  const snapshotsDoc = await db.collection('theta_snapshots').doc(userId).get();
  console.log('Snapshots doc exists:', snapshotsDoc.exists);

  if (snapshotsDoc.exists) {
    const dailySnaps = await db.collection('theta_snapshots').doc(userId).collection('daily')
      .orderBy('captured_at', 'desc')
      .limit(5)
      .get();

    console.log('Daily snapshots count:', dailySnaps.size);

    if (dailySnaps.size > 0) {
      console.log('\nLast 5 snapshots:');
      dailySnaps.docs.forEach(doc => {
        const snap = doc.data();
        const date = snap.captured_at?.toDate?.()?.toISOString?.()?.split('T')[0] || 'N/A';
        console.log({
          date,
          theta: snap.overall_theta,
          percentile: snap.overall_percentile,
          hasSubjectAccuracy: snap.subject_accuracy ? true : false
        });
      });
    }
  }

  process.exit(0);
}

getUserData().catch(err => {
  console.error(err);
  process.exit(1);
});
