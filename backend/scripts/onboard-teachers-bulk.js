/**
 * Bulk Teacher Onboarding Script
 *
 * Imports teachers from a CSV file and creates teacher accounts in Firestore.
 * Optionally creates Firebase Auth accounts with auto-generated passwords.
 *
 * Usage:
 *   node scripts/onboard-teachers-bulk.js teachers.csv [--dry-run] [--skip-auth]
 *
 * CSV Format:
 *   email,phone,first_name,last_name,institute_name,institute_location
 *   teacher@example.com,+919876543210,Priya,Sharma,Elite IIT Academy,Delhi
 *
 * Options:
 *   --dry-run    Show what would be created without making changes
 *   --skip-auth  Skip Firebase Auth account creation (only create Firestore documents)
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '../serviceAccountKey.json');
const serviceAccount = require(serviceAccountPath);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

/**
 * Parse CSV file
 */
function parseCSV(filePath) {
  const fileContent = fs.readFileSync(filePath, 'utf-8');
  const lines = fileContent.trim().split('\n');

  if (lines.length < 2) {
    throw new Error('CSV file must have header row and at least one data row');
  }

  const headers = lines[0].split(',').map(h => h.trim());

  // Validate headers
  const requiredHeaders = ['email', 'phone', 'first_name'];
  const missingHeaders = requiredHeaders.filter(h => !headers.includes(h));
  if (missingHeaders.length > 0) {
    throw new Error(`Missing required CSV headers: ${missingHeaders.join(', ')}`);
  }

  const teachers = [];
  for (let i = 1; i < lines.length; i++) {
    const values = lines[i].split(',').map(v => v.trim());
    if (values.length !== headers.length) {
      console.warn(`⚠️  Skipping line ${i + 1}: column count mismatch`);
      continue;
    }

    const teacher = {};
    headers.forEach((header, index) => {
      teacher[header] = values[index];
    });

    // Validate required fields
    if (!teacher.email || !teacher.phone || !teacher.first_name) {
      console.warn(`⚠️  Skipping line ${i + 1}: missing required fields`);
      continue;
    }

    // Validate email format
    const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
    if (!emailRegex.test(teacher.email)) {
      console.warn(`⚠️  Skipping line ${i + 1}: invalid email format (${teacher.email})`);
      continue;
    }

    // Validate phone format (India +91 or US +1 for testing)
    const phoneRegex = /^\+(?:91\d{10}|1\d{10})$/;
    if (!phoneRegex.test(teacher.phone)) {
      console.warn(`⚠️  Skipping line ${i + 1}: invalid phone format (${teacher.phone}) - must be +91XXXXXXXXXX or +1XXXXXXXXXX`);
      continue;
    }

    teachers.push(teacher);
  }

  return teachers;
}

/**
 * Generate random password
 */
function generatePassword() {
  return crypto.randomBytes(8).toString('hex'); // 16 character password
}

/**
 * Check if teacher already exists
 */
async function teacherExists(email) {
  const snapshot = await db.collection('teachers')
    .where('email', '==', email.toLowerCase())
    .limit(1)
    .get();

  return !snapshot.empty;
}

/**
 * Create Firebase Auth account for teacher
 */
async function createAuthAccount(email, password) {
  try {
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      emailVerified: false
    });
    return { success: true, uid: userRecord.uid };
  } catch (error) {
    if (error.code === 'auth/email-already-exists') {
      // Get existing user
      const userRecord = await admin.auth().getUserByEmail(email);
      return { success: true, uid: userRecord.uid, existing: true };
    }
    return { success: false, error: error.message };
  }
}

/**
 * Create teacher document in Firestore
 */
async function createTeacherDocument(teacher, createdBy) {
  const teacherRef = db.collection('teachers').doc();
  const teacherId = teacherRef.id;

  const teacherData = {
    teacher_id: teacherId,
    email: teacher.email.toLowerCase(),
    phone_number: teacher.phone,
    first_name: teacher.first_name,
    last_name: teacher.last_name || '',
    coaching_institute_name: teacher.institute_name || '',
    coaching_institute_location: teacher.institute_location || '',
    role: 'teacher',
    is_active: true,
    student_ids: [],
    total_students: 0,
    email_preferences: {
      weekly_class_report: true,
      student_alerts: true,
      product_updates: false
    },
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    created_by: createdBy,
    last_login_at: null,
    updated_at: admin.firestore.FieldValue.serverTimestamp()
  };

  await teacherRef.set(teacherData);
  return teacherId;
}

/**
 * Main onboarding function
 */
async function onboardTeachers() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0].startsWith('--')) {
    console.error('❌ Error: CSV file path required');
    console.log('\nUsage: node scripts/onboard-teachers-bulk.js <csv-file> [--dry-run] [--skip-auth]');
    process.exit(1);
  }

  const csvFile = args[0];
  const isDryRun = args.includes('--dry-run');
  const skipAuth = args.includes('--skip-auth');

  console.log('🔍 Starting teacher onboarding');
  console.log(`CSV File: ${csvFile}`);
  console.log(`Mode: ${isDryRun ? 'DRY RUN (no changes will be made)' : 'LIVE'}`);
  console.log(`Auth Creation: ${skipAuth ? 'SKIP' : 'ENABLED'}`);
  console.log('---\n');

  try {
    // Parse CSV
    if (!fs.existsSync(csvFile)) {
      throw new Error(`CSV file not found: ${csvFile}`);
    }

    const teachers = parseCSV(csvFile);
    console.log(`📊 Parsed ${teachers.length} valid teachers from CSV\n`);

    if (teachers.length === 0) {
      console.log('⚠️  No valid teachers found in CSV. Exiting.');
      process.exit(0);
    }

    let created = 0;
    let skipped = 0;
    let errors = 0;
    const passwords = {}; // Store generated passwords for display

    // Process in batches of 500
    const batchSize = 500;
    let batch = db.batch();
    let operationsInBatch = 0;

    for (let i = 0; i < teachers.length; i++) {
      const teacher = teachers[i];
      console.log(`\n[${i + 1}/${teachers.length}] Processing ${teacher.email}...`);

      try {
        // Check if already exists
        const exists = await teacherExists(teacher.email);
        if (exists) {
          console.log(`  ⏭️  Already exists, skipping`);
          skipped++;
          continue;
        }

        if (!isDryRun) {
          // Create Firebase Auth account (if not skipped)
          let authUid = null;
          if (!skipAuth) {
            const password = generatePassword();
            const authResult = await createAuthAccount(teacher.email, password);

            if (!authResult.success) {
              console.log(`  ❌ Auth creation failed: ${authResult.error}`);
              errors++;
              continue;
            }

            authUid = authResult.uid;
            if (authResult.existing) {
              console.log(`  ✅ Auth account already exists (UID: ${authUid})`);
            } else {
              console.log(`  ✅ Auth account created (UID: ${authUid})`);
              passwords[teacher.email] = password;
            }
          }

          // Create Firestore document
          const teacherId = await createTeacherDocument(teacher, 'bulk-import-script');
          console.log(`  ✅ Teacher document created (ID: ${teacherId})`);

          created++;

          // Log progress every 10 teachers
          if (created % 10 === 0) {
            console.log(`\n📈 Progress: ${created} teachers created so far`);
          }
        } else {
          console.log(`  [DRY RUN] Would create teacher: ${teacher.first_name} ${teacher.last_name}`);
          console.log(`    Email: ${teacher.email}`);
          console.log(`    Phone: ${teacher.phone}`);
          console.log(`    Institute: ${teacher.institute_name || 'N/A'}`);
          created++;
        }
      } catch (error) {
        console.log(`  ❌ Error: ${error.message}`);
        errors++;
      }
    }

    // Summary
    console.log('\n📋 Onboarding Summary:');
    console.log('---');
    console.log(`Total teachers in CSV: ${teachers.length}`);
    console.log(`Already existed (skipped): ${skipped}`);
    console.log(`Newly created: ${created}`);
    console.log(`Errors: ${errors}`);

    // Display passwords if any were generated
    if (!isDryRun && !skipAuth && Object.keys(passwords).length > 0) {
      console.log('\n🔐 Generated Passwords (SAVE THESE SECURELY):');
      console.log('---');
      Object.entries(passwords).forEach(([email, password]) => {
        console.log(`${email}: ${password}`);
      });
      console.log('\n⚠️  IMPORTANT: Send these credentials to teachers via secure channel');
      console.log('   Teachers should change their passwords after first login');
    }

    if (isDryRun) {
      console.log('\n💡 Run without --dry-run to apply changes');
    } else if (created > 0) {
      console.log('\n✅ Onboarding completed successfully!');
    }

  } catch (error) {
    console.error('\n❌ Onboarding failed:', error.message);
    process.exit(1);
  }
}

// Run onboarding
onboardTeachers()
  .then(() => {
    console.log('\n✨ Script finished');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Script crashed:', error);
    process.exit(1);
  });
