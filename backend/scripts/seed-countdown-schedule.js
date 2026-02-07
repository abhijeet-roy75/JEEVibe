/**
 * Seed the 24-month countdown unlock schedule to Firestore
 * Loads pre-formatted JSON directly (no transformation needed)
 * Run with: node backend/scripts/seed-countdown-schedule.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

// Load the pre-formatted 24-month schedule JSON
const scheduleFilePath = path.join(__dirname, '../../docs/10-calendar/countdown_24month_schedule_CORRECTED.json');

async function seedSchedule() {
  try {
    console.log(`📂 Loading schedule from: ${scheduleFilePath}`);

    if (!fs.existsSync(scheduleFilePath)) {
      throw new Error(`Schedule file not found at: ${scheduleFilePath}`);
    }

    const scheduleData = JSON.parse(fs.readFileSync(scheduleFilePath, 'utf8'));
    console.log(`✅ JSON loaded successfully`);

    // Validate structure
    if (!scheduleData.timeline) {
      throw new Error('Invalid JSON: missing timeline object');
    }

    console.log(`📊 Found ${Object.keys(scheduleData.timeline).length} months in timeline`);

    // Validate that we have months 1-24 (all must exist, even if empty)
    for (let i = 1; i <= 24; i++) {
      if (!scheduleData.timeline[`month_${i}`]) {
        throw new Error(`Missing month_${i} in timeline data`);
      }

      // Validate each month has all three subjects (can be empty arrays)
      const monthData = scheduleData.timeline[`month_${i}`];
      ['physics', 'chemistry', 'mathematics'].forEach(subject => {
        if (!Array.isArray(monthData[subject])) {
          throw new Error(`Month ${i} missing ${subject} array`);
        }
      });
    }

    console.log('✅ Schedule structure validated');

    // Count total chapters per subject (for logging)
    const chapterCounts = { physics: 0, chemistry: 0, mathematics: 0 };
    const uniqueChapters = { physics: new Set(), chemistry: new Set(), mathematics: new Set() };

    for (let i = 1; i <= 24; i++) {
      const monthData = scheduleData.timeline[`month_${i}`];

      ['physics', 'chemistry', 'mathematics'].forEach(subject => {
        if (monthData[subject] && monthData[subject].length > 0) {
          chapterCounts[subject] += monthData[subject].length;
          monthData[subject].forEach(ch => uniqueChapters[subject].add(ch));
        }
      });
    }

    // Prepare Firestore document
    const firestoreSchedule = {
      version: 'v1_countdown',
      type: 'countdown_24month',
      active: true,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      jee_dates: {
        session_1: { start: '2027-01-20', end: '2027-01-30' },
        session_2: { start: '2027-04-01', end: '2027-04-15' }
      },
      timeline: scheduleData.timeline
    };

    // Write to Firestore
    await db.collection('unlock_schedules').doc('v1_countdown').set(firestoreSchedule);

    console.log('\n✅ Successfully seeded countdown schedule to Firestore');
    console.log('   📍 Collection: unlock_schedules');
    console.log('   📄 Document: v1_countdown');
    console.log('   🔢 Version:', firestoreSchedule.version);
    console.log('   📅 Type:', firestoreSchedule.type);
    console.log('   📆 Months:', Object.keys(scheduleData.timeline).length);
    console.log('\n📚 Chapter Statistics:');
    console.log('   Physics:');
    console.log(`     - Total occurrences: ${chapterCounts.physics}`);
    console.log(`     - Unique chapters: ${uniqueChapters.physics.size}`);
    console.log('   Chemistry:');
    console.log(`     - Total occurrences: ${chapterCounts.chemistry}`);
    console.log(`     - Unique chapters: ${uniqueChapters.chemistry.size}`);
    console.log('   Mathematics:');
    console.log(`     - Total occurrences: ${chapterCounts.mathematics}`);
    console.log(`     - Unique chapters: ${uniqueChapters.mathematics.size}`);
    console.log(`\n🎯 Total unique chapters: ${uniqueChapters.physics.size + uniqueChapters.chemistry.size + uniqueChapters.mathematics.size}`);

  } catch (error) {
    console.error('\n❌ Error seeding schedule:', error.message);
    console.error(error.stack);
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

seedSchedule();
