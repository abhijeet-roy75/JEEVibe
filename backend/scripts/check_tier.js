const { db } = require('./src/config/firebase');

async function check() {
  const doc = await db.collection('tier_config').doc('active').get();
  const config = doc.data();
  
  console.log('Free tier config:');
  console.log('  chapter_practice_daily_limit:', config.free.chapter_practice_daily_limit);
  console.log('  chapter_practice_per_chapter:', config.free.chapter_practice_per_chapter);
  console.log('  chapter_practice_weekly_per_subject:', config.free.chapter_practice_weekly_per_subject);
}

check().then(() => process.exit(0)).catch(err => {
  console.error(err);
  process.exit(1);
});
