/**
 * Student-Teacher Association Script
 *
 * Associates students with teachers from a CSV mapping file.
 * Updates both student documents (adds teacher_id) and teacher documents (adds to student_ids array).
 *
 * Usage:
 *   node scripts/associate-students-to-teacher.js mapping.csv [--dry-run] [--force]
 *
 * CSV Format:
 *   student_phone,teacher_email
 *   +919998887770,teacher@example.com
 *   +919998887771,teacher@example.com
 *
 * Options:
 *   --dry-run  Show what would be updated without making changes
 *   --force    Override existing teacher assignments (default: warn and skip)
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

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
  if (!headers.includes('student_phone') || !headers.includes('teacher_email')) {
    throw new Error('CSV must have headers: student_phone,teacher_email');
  }

  const mappings = [];
  for (let i = 1; i < lines.length; i++) {
    const values = lines[i].split(',').map(v => v.trim());
    if (values.length !== headers.length) {
      console.warn(`⚠️  Skipping line ${i + 1}: column count mismatch`);
      continue;
    }

    const mapping = {};
    headers.forEach((header, index) => {
      mapping[header] = values[index];
    });

    // Validate required fields
    if (!mapping.student_phone || !mapping.teacher_email) {
      console.warn(`⚠️  Skipping line ${i + 1}: missing required fields`);
      continue;
    }

    // Validate phone format
    const phoneRegex = /^\+91\d{10}$/;
    if (!phoneRegex.test(mapping.student_phone)) {
      console.warn(`⚠️  Skipping line ${i + 1}: invalid phone format (${mapping.student_phone})`);
      continue;
    }

    // Validate email format
    const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
    if (!emailRegex.test(mapping.teacher_email)) {
      console.warn(`⚠️  Skipping line ${i + 1}: invalid email format (${mapping.teacher_email})`);
      continue;
    }

    mappings.push(mapping);
  }

  return mappings;
}

/**
 * Find teacher by email
 */
async function findTeacherByEmail(email) {
  const snapshot = await db.collection('teachers')
    .where('email', '==', email.toLowerCase())
    .limit(1)
    .get();

  if (snapshot.empty) {
    return null;
  }

  const doc = snapshot.docs[0];
  return { id: doc.id, ...doc.data() };
}

/**
 * Find student by phone number
 */
async function findStudentByPhone(phoneNumber) {
  const snapshot = await db.collection('users')
    .where('phoneNumber', '==', phoneNumber)
    .limit(1)
    .get();

  if (snapshot.empty) {
    return null;
  }

  const doc = snapshot.docs[0];
  return { id: doc.id, ...doc.data() };
}

/**
 * Associate students with teachers
 */
async function associateStudents() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0].startsWith('--')) {
    console.error('❌ Error: CSV file path required');
    console.log('\nUsage: node scripts/associate-students-to-teacher.js <csv-file> [--dry-run] [--force]');
    process.exit(1);
  }

  const csvFile = args[0];
  const isDryRun = args.includes('--dry-run');
  const force = args.includes('--force');

  console.log('🔍 Starting student-teacher association');
  console.log(`CSV File: ${csvFile}`);
  console.log(`Mode: ${isDryRun ? 'DRY RUN (no changes will be made)' : 'LIVE'}`);
  console.log(`Force Override: ${force ? 'YES' : 'NO'}`);
  console.log('---\n');

  try {
    // Parse CSV
    if (!fs.existsSync(csvFile)) {
      throw new Error(`CSV file not found: ${csvFile}`);
    }

    const mappings = parseCSV(csvFile);
    console.log(`📊 Parsed ${mappings.length} valid mappings from CSV\n`);

    if (mappings.length === 0) {
      console.log('⚠️  No valid mappings found in CSV. Exiting.');
      process.exit(0);
    }

    let associated = 0;
    let skipped = 0;
    let errors = 0;

    // Group mappings by teacher for efficient batch updates
    const teacherMap = new Map();

    for (let i = 0; i < mappings.length; i++) {
      const mapping = mappings[i];
      console.log(`\n[${i + 1}/${mappings.length}] Processing ${mapping.student_phone} → ${mapping.teacher_email}...`);

      try {
        // Find teacher
        const teacher = await findTeacherByEmail(mapping.teacher_email);
        if (!teacher) {
          console.log(`  ❌ Teacher not found: ${mapping.teacher_email}`);
          errors++;
          continue;
        }

        if (!teacher.is_active) {
          console.log(`  ❌ Teacher inactive: ${mapping.teacher_email}`);
          errors++;
          continue;
        }

        // Find student
        const student = await findStudentByPhone(mapping.student_phone);
        if (!student) {
          console.log(`  ❌ Student not found: ${mapping.student_phone}`);
          errors++;
          continue;
        }

        // Check if student already has a teacher
        if (student.teacher_id && !force) {
          const existingTeacher = await db.collection('teachers').doc(student.teacher_id).get();
          const existingEmail = existingTeacher.exists ? existingTeacher.data().email : 'unknown';
          console.log(`  ⚠️  Student already assigned to ${existingEmail}, skipping (use --force to override)`);
          skipped++;
          continue;
        }

        if (!isDryRun) {
          // Update student document
          await db.collection('users').doc(student.id).update({
            teacher_id: teacher.id,
            coaching_institute_name: teacher.coaching_institute_name || '',
            updated_at: admin.firestore.FieldValue.serverTimestamp()
          });

          // Track for teacher update
          if (!teacherMap.has(teacher.id)) {
            teacherMap.set(teacher.id, {
              teacher: teacher,
              studentIds: [...(teacher.student_ids || [])]
            });
          }

          const teacherData = teacherMap.get(teacher.id);
          if (!teacherData.studentIds.includes(student.id)) {
            teacherData.studentIds.push(student.id);
          }

          console.log(`  ✅ Associated student ${student.firstName || 'N/A'} (${student.id})`);
          console.log(`     Teacher: ${teacher.first_name} ${teacher.last_name} (${teacher.coaching_institute_name})`);
          associated++;
        } else {
          console.log(`  [DRY RUN] Would associate:`);
          console.log(`    Student: ${student.firstName || 'N/A'} (${mapping.student_phone})`);
          console.log(`    Teacher: ${teacher.first_name} ${teacher.last_name} (${mapping.teacher_email})`);
          console.log(`    Institute: ${teacher.coaching_institute_name || 'N/A'}`);
          associated++;
        }

        // Log progress every 10 students
        if (associated % 10 === 0) {
          console.log(`\n📈 Progress: ${associated} students associated so far`);
        }
      } catch (error) {
        console.log(`  ❌ Error: ${error.message}`);
        errors++;
      }
    }

    // Update teacher documents with student lists (batch operation)
    if (!isDryRun && teacherMap.size > 0) {
      console.log(`\n\n📝 Updating ${teacherMap.size} teacher documents...`);

      for (const [teacherId, data] of teacherMap.entries()) {
        try {
          await db.collection('teachers').doc(teacherId).update({
            student_ids: data.studentIds,
            total_students: data.studentIds.length,
            updated_at: admin.firestore.FieldValue.serverTimestamp()
          });
          console.log(`  ✅ Updated teacher ${data.teacher.email} (${data.studentIds.length} students)`);
        } catch (error) {
          console.log(`  ❌ Error updating teacher ${data.teacher.email}: ${error.message}`);
        }
      }
    }

    // Summary
    console.log('\n📋 Association Summary:');
    console.log('---');
    console.log(`Total mappings in CSV: ${mappings.length}`);
    console.log(`Successfully associated: ${associated}`);
    console.log(`Skipped (already assigned): ${skipped}`);
    console.log(`Errors: ${errors}`);
    console.log(`Teachers updated: ${teacherMap.size}`);

    if (isDryRun) {
      console.log('\n💡 Run without --dry-run to apply changes');
    } else if (associated > 0) {
      console.log('\n✅ Association completed successfully!');
    }

  } catch (error) {
    console.error('\n❌ Association failed:', error.message);
    process.exit(1);
  }
}

// Run association
associateStudents()
  .then(() => {
    console.log('\n✨ Script finished');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Script crashed:', error);
    process.exit(1);
  });
