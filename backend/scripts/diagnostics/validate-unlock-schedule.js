/**
 * Validate Unlock Schedule Against Questions Database
 *
 * Checks that every chapter key in the 24-month unlock schedule
 * actually exists in the questions database.
 *
 * This prevents issues like:
 * - Invalid chapter keys in schedule (e.g., physics_emi_ac_circuits)
 * - Typos in chapter keys
 * - Chapters that don't have any questions
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function validateUnlockSchedule() {
  console.log('🔍 VALIDATING UNLOCK SCHEDULE AGAINST QUESTIONS DATABASE');
  console.log('='.repeat(80));
  console.log('');

  // 1. Get all active chapter keys from questions database
  console.log('📚 Loading all active chapters from questions database...');
  const questionsSnap = await db.collection('questions')
    .where('active', '==', true)
    .select('chapter_key', 'subject')
    .get();

  const dbChapterKeys = new Set();
  const dbChaptersBySubject = {
    physics: new Set(),
    chemistry: new Set(),
    mathematics: new Set()
  };

  questionsSnap.docs.forEach(doc => {
    const data = doc.data();
    const key = data.chapter_key;
    const subject = data.subject?.toLowerCase();

    if (key) {
      dbChapterKeys.add(key);
      if (subject === 'physics') dbChaptersBySubject.physics.add(key);
      else if (subject === 'chemistry') dbChaptersBySubject.chemistry.add(key);
      else if (subject === 'mathematics' || subject === 'maths') dbChaptersBySubject.mathematics.add(key);
    }
  });

  console.log('   Total unique chapter keys in database:', dbChapterKeys.size);
  console.log('   Physics:', dbChaptersBySubject.physics.size);
  console.log('   Chemistry:', dbChaptersBySubject.chemistry.size);
  console.log('   Mathematics:', dbChaptersBySubject.mathematics.size);
  console.log('');

  // 2. Get unlock schedule
  console.log('📅 Loading unlock schedule...');
  const scheduleSnap = await db.collection('unlock_schedules')
    .where('type', '==', 'countdown_24month')
    .where('active', '==', true)
    .limit(1)
    .get();

  if (scheduleSnap.empty) {
    console.error('❌ No active unlock schedule found');
    process.exit(1);
  }

  const schedule = scheduleSnap.docs[0].data();
  console.log('   Schedule type:', schedule.type);
  console.log('   Total months:', schedule.total_months);
  console.log('');

  // 3. Validate each month
  console.log('🔍 VALIDATING ALL 24 MONTHS:');
  console.log('─'.repeat(80));
  console.log('');

  let totalIssues = 0;
  const allScheduleKeys = new Set();
  const issuesByMonth = {};

  for (let m = 1; m <= 24; m++) {
    const monthKey = `month_${m}`;
    const monthData = schedule.timeline[monthKey];

    if (!monthData) {
      console.log(`Month ${m}: ⚠️  Missing month data`);
      totalIssues++;
      continue;
    }

    const monthIssues = [];

    // Check each subject
    ['physics', 'chemistry', 'mathematics'].forEach(subject => {
      const chapters = monthData[subject] || [];

      if (!Array.isArray(chapters)) {
        monthIssues.push(`${subject}: Not an array`);
        totalIssues++;
        return;
      }

      chapters.forEach(chapterKey => {
        allScheduleKeys.add(chapterKey);

        // Check if chapter exists in database
        if (!dbChapterKeys.has(chapterKey)) {
          monthIssues.push(`${subject}: "${chapterKey}" NOT FOUND in database`);
          totalIssues++;
        }
      });
    });

    // Print month summary
    const totalChapters = (monthData.physics?.length || 0) +
                         (monthData.chemistry?.length || 0) +
                         (monthData.mathematics?.length || 0);

    if (monthIssues.length > 0) {
      console.log(`Month ${m.toString().padStart(2)}: ❌ ${monthIssues.length} issue(s) - ${totalChapters} chapters total`);
      monthIssues.forEach(issue => console.log(`          ${issue}`));
      issuesByMonth[m] = monthIssues;
    } else if (totalChapters === 0) {
      console.log(`Month ${m.toString().padStart(2)}: ⚪ No chapters (revision/buffer month)`);
    } else {
      console.log(`Month ${m.toString().padStart(2)}: ✅ Valid - ${totalChapters} chapters`);
    }
  }

  console.log('');
  console.log('─'.repeat(80));
  console.log('');

  // 4. Check for chapters in database but not in schedule
  const chaptersNotInSchedule = Array.from(dbChapterKeys).filter(k => !allScheduleKeys.has(k));

  if (chaptersNotInSchedule.length > 0) {
    console.log('⚠️  CHAPTERS IN DATABASE BUT NOT IN UNLOCK SCHEDULE:');
    console.log('   (These chapters will never be unlocked for students)');
    console.log('');

    const bySubject = {
      physics: chaptersNotInSchedule.filter(k => k.startsWith('physics_')),
      chemistry: chaptersNotInSchedule.filter(k => k.startsWith('chemistry_')),
      mathematics: chaptersNotInSchedule.filter(k => k.startsWith('mathematics_') || k.startsWith('maths_'))
    };

    Object.entries(bySubject).forEach(([subject, chapters]) => {
      if (chapters.length > 0) {
        console.log(`   ${subject.charAt(0).toUpperCase() + subject.slice(1)} (${chapters.length}):`);
        chapters.forEach(k => console.log(`     - ${k}`));
      }
    });
    console.log('');
  }

  // 5. Summary
  console.log('='.repeat(80));
  console.log('📊 VALIDATION SUMMARY:');
  console.log('='.repeat(80));
  console.log('');
  console.log('Total chapters in database:', dbChapterKeys.size);
  console.log('Total chapters in schedule:', allScheduleKeys.size);
  console.log('Chapters in database but not in schedule:', chaptersNotInSchedule.length);
  console.log('');

  if (totalIssues === 0 && chaptersNotInSchedule.length === 0) {
    console.log('🎉 VALIDATION PASSED!');
    console.log('   All chapters in the unlock schedule exist in the database.');
    console.log('   All database chapters are included in the unlock schedule.');
  } else {
    console.log('❌ VALIDATION ISSUES FOUND:');
    console.log(`   - ${totalIssues} invalid chapter keys in schedule`);
    console.log(`   - ${chaptersNotInSchedule.length} database chapters not in schedule`);
    console.log('');
    console.log('Please fix these issues to ensure proper chapter unlocking.');
  }

  process.exit(totalIssues > 0 ? 1 : 0);
}

validateUnlockSchedule().catch(error => {
  console.error('❌ Error:', error);
  process.exit(1);
});
