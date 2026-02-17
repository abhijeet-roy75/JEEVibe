/**
 * Migration Script: Add jeeTargetExamDate to Existing Users
 *
 * Maps currentClass to jeeTargetExamDate:
 * - Class 11 → Next year's January (e.g., 2027-01)
 * - Class 12 → Smart Jan vs April based on current month
 * - Other/Missing → null (all chapters unlocked)
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

/**
 * Determines target exam date based on currentClass
 */
function calculateTargetExamDate(currentClass) {
  const now = new Date();
  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth() + 1; // 1-12

  if (!currentClass || currentClass === 'Other') {
    // No target date - all chapters unlocked
    return null;
  }

  if (currentClass === '11') {
    // Class 11 students → target next year's January
    const targetYear = currentYear + 1;
    return `${targetYear}-01`;
  }

  if (currentClass === '12') {
    // Class 12 students → smart Jan vs April based on current month
    const nextYear = currentYear + 1;

    if (currentMonth >= 1 && currentMonth <= 3) {
      // Jan-Mar: Target April of current year
      return `${currentYear}-04`;
    } else if (currentMonth >= 4 && currentMonth <= 6) {
      // Apr-Jun: Target January of next year
      return `${nextYear}-01`;
    } else {
      // Jul-Dec: Target April of next year
      return `${nextYear}-04`;
    }
  }

  // Fallback
  return null;
}

/**
 * Main migration function
 */
async function migrateUsers() {
  console.log('Starting migration of existing users...\n');

  try {
    const usersSnapshot = await db.collection('users').get();
    console.log(`Total users found: ${usersSnapshot.size}\n`);

    let migrated = 0;
    let skipped = 0;
    let errors = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();

      // Skip if already has jeeTargetExamDate
      if (userData.jeeTargetExamDate) {
        console.log(`✓ SKIP: ${userId} - Already has jeeTargetExamDate: ${userData.jeeTargetExamDate}`);
        skipped++;
        continue;
      }

      const currentClass = userData.currentClass;
      const targetExamDate = calculateTargetExamDate(currentClass);

      try {
        await db.collection('users').doc(userId).update({
          jeeTargetExamDate: targetExamDate,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        console.log(`✓ MIGRATED: ${userId}`);
        console.log(`  - currentClass: ${currentClass || 'none'}`);
        console.log(`  - jeeTargetExamDate: ${targetExamDate || 'null (all chapters unlocked)'}\n`);

        migrated++;
      } catch (error) {
        console.error(`✗ ERROR migrating ${userId}:`, error.message);
        errors++;
      }
    }

    console.log('\n=== Migration Summary ===');
    console.log(`Total users: ${usersSnapshot.size}`);
    console.log(`Migrated: ${migrated}`);
    console.log(`Skipped (already had target date): ${skipped}`);
    console.log(`Errors: ${errors}`);
    console.log('========================\n');

    if (errors > 0) {
      process.exit(1);
    } else {
      console.log('✓ Migration completed successfully!');
      process.exit(0);
    }

  } catch (error) {
    console.error('Fatal error during migration:', error);
    process.exit(1);
  }
}

// Run migration
migrateUsers();
