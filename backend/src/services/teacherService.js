/**
 * Teacher Service
 *
 * Handles CRUD operations for coaching class teachers and student associations.
 *
 * Features:
 * - Teacher account management (create, read, update, deactivate)
 * - Student-to-teacher association management
 * - Batch operations for bulk imports
 */

const { db, admin } = require('../config/firebase');
const { retryFirestoreOperation } = require('../utils/firestoreRetry');
const logger = require('../utils/logger');

// ============================================================================
// TEACHER CRUD OPERATIONS
// ============================================================================

/**
 * Create a new teacher account
 *
 * @param {Object} teacherData - Teacher information
 * @param {string} teacherData.email - Teacher email (unique)
 * @param {string} teacherData.phone_number - Teacher phone (E.164 format)
 * @param {string} teacherData.first_name - First name
 * @param {string} teacherData.last_name - Last name
 * @param {string} teacherData.coaching_institute_name - Institute name
 * @param {string} teacherData.coaching_institute_location - Institute location
 * @param {string} createdByAdmin - Admin email who created this teacher
 * @returns {Promise<Object>} Created teacher document
 */
async function createTeacher(teacherData, createdByAdmin) {
  try {
    // Validate required fields
    if (!teacherData.email || !teacherData.phone_number || !teacherData.first_name) {
      throw new Error('Missing required fields: email, phone_number, first_name');
    }

    // Validate email format
    const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
    if (!emailRegex.test(teacherData.email)) {
      throw new Error('Invalid email format');
    }

    // Validate phone format (E.164: +91XXXXXXXXXX or +1XXXXXXXXXX for testing)
    const phoneRegex = /^\+(?:91\d{10}|1\d{10})$/;
    if (!phoneRegex.test(teacherData.phone_number)) {
      throw new Error('Invalid phone format (must be +91XXXXXXXXXX or +1XXXXXXXXXX)');
    }

    // Check if teacher with this email already exists
    const existingTeacher = await getTeacherByEmail(teacherData.email);
    if (existingTeacher) {
      throw new Error(`Teacher with email ${teacherData.email} already exists`);
    }

    // Create teacher document
    const teacherRef = db.collection('teachers').doc();
    const teacherId = teacherRef.id;

    const newTeacher = {
      teacher_id: teacherId,
      email: teacherData.email.toLowerCase(),
      phone_number: teacherData.phone_number,
      first_name: teacherData.first_name,
      last_name: teacherData.last_name || '',
      coaching_institute_name: teacherData.coaching_institute_name || '',
      coaching_institute_location: teacherData.coaching_institute_location || '',
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
      created_by: createdByAdmin,
      last_login_at: null,
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    };

    await retryFirestoreOperation(async () => {
      await teacherRef.set(newTeacher);
    });

    logger.info('Teacher created', {
      teacherId,
      email: teacherData.email,
      createdBy: createdByAdmin,
      institute: teacherData.coaching_institute_name
    });

    return {
      ...newTeacher,
      created_at: new Date(),
      updated_at: new Date()
    };
  } catch (error) {
    logger.error('Error creating teacher', {
      email: teacherData.email,
      error: error.message
    });
    throw error;
  }
}

/**
 * Get teacher by ID
 *
 * @param {string} teacherId - Teacher document ID
 * @returns {Promise<Object|null>} Teacher document or null
 */
async function getTeacherById(teacherId) {
  try {
    const teacherDoc = await retryFirestoreOperation(async () => {
      return await db.collection('teachers').doc(teacherId).get();
    });

    if (!teacherDoc.exists) {
      return null;
    }

    return {
      id: teacherDoc.id,
      ...teacherDoc.data()
    };
  } catch (error) {
    logger.error('Error getting teacher by ID', {
      teacherId,
      error: error.message
    });
    throw error;
  }
}

/**
 * Get teacher by email
 *
 * @param {string} email - Teacher email
 * @returns {Promise<Object|null>} Teacher document or null
 */
async function getTeacherByEmail(email) {
  try {
    const teachersSnapshot = await retryFirestoreOperation(async () => {
      return await db.collection('teachers')
        .where('email', '==', email.toLowerCase())
        .limit(1)
        .get();
    });

    if (teachersSnapshot.empty) {
      return null;
    }

    const teacherDoc = teachersSnapshot.docs[0];
    return {
      id: teacherDoc.id,
      ...teacherDoc.data()
    };
  } catch (error) {
    logger.error('Error getting teacher by email', {
      email,
      error: error.message
    });
    throw error;
  }
}

/**
 * Update teacher profile
 *
 * @param {string} teacherId - Teacher ID
 * @param {Object} updates - Fields to update
 * @returns {Promise<Object>} Updated teacher document
 */
async function updateTeacher(teacherId, updates) {
  try {
    // Don't allow updating certain fields
    const restrictedFields = ['teacher_id', 'email', 'created_at', 'created_by', 'student_ids', 'total_students'];
    restrictedFields.forEach(field => {
      if (updates[field] !== undefined) {
        delete updates[field];
      }
    });

    if (Object.keys(updates).length === 0) {
      throw new Error('No valid fields to update');
    }

    const teacherRef = db.collection('teachers').doc(teacherId);

    // Check if teacher exists
    const teacherDoc = await teacherRef.get();
    if (!teacherDoc.exists) {
      throw new Error('Teacher not found');
    }

    // Add updated timestamp
    updates.updated_at = admin.firestore.FieldValue.serverTimestamp();

    await retryFirestoreOperation(async () => {
      await teacherRef.update(updates);
    });

    logger.info('Teacher updated', {
      teacherId,
      updatedFields: Object.keys(updates)
    });

    // Return updated document
    const updatedDoc = await teacherRef.get();
    return {
      id: updatedDoc.id,
      ...updatedDoc.data()
    };
  } catch (error) {
    logger.error('Error updating teacher', {
      teacherId,
      error: error.message
    });
    throw error;
  }
}

/**
 * Deactivate teacher (soft delete)
 *
 * @param {string} teacherId - Teacher ID
 * @returns {Promise<void>}
 */
async function deactivateTeacher(teacherId) {
  try {
    const teacherRef = db.collection('teachers').doc(teacherId);

    // Check if teacher exists
    const teacherDoc = await teacherRef.get();
    if (!teacherDoc.exists) {
      throw new Error('Teacher not found');
    }

    await retryFirestoreOperation(async () => {
      await teacherRef.update({
        is_active: false,
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    logger.info('Teacher deactivated', { teacherId });
  } catch (error) {
    logger.error('Error deactivating teacher', {
      teacherId,
      error: error.message
    });
    throw error;
  }
}

/**
 * List teachers with pagination and filtering
 *
 * @param {Object} options - Query options
 * @param {string} options.filter - Filter: 'all', 'active', 'inactive'
 * @param {string} options.search - Search term (email, name, institute)
 * @param {number} options.limit - Results per page (default 50)
 * @param {number} options.offset - Offset for pagination (default 0)
 * @returns {Promise<Object>} { teachers: [], total: number }
 */
async function listTeachers({ filter = 'all', search = '', limit = 50, offset = 0 }) {
  try {
    let query = db.collection('teachers');

    // Apply active filter
    if (filter === 'active') {
      query = query.where('is_active', '==', true);
    } else if (filter === 'inactive') {
      query = query.where('is_active', '==', false);
    }

    // Get all matching documents (we'll filter search in-memory)
    const snapshot = await retryFirestoreOperation(async () => {
      return await query.get();
    });

    let teachers = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    // Apply search filter (in-memory)
    if (search) {
      const searchLower = search.toLowerCase();
      teachers = teachers.filter(teacher => {
        const emailMatch = teacher.email?.toLowerCase().includes(searchLower);
        const nameMatch = `${teacher.first_name} ${teacher.last_name}`.toLowerCase().includes(searchLower);
        const instituteMatch = teacher.coaching_institute_name?.toLowerCase().includes(searchLower);
        return emailMatch || nameMatch || instituteMatch;
      });
    }

    const total = teachers.length;

    // Apply pagination
    teachers = teachers.slice(offset, offset + limit);

    return {
      teachers,
      total,
      limit,
      offset
    };
  } catch (error) {
    logger.error('Error listing teachers', {
      filter,
      search,
      error: error.message
    });
    throw error;
  }
}

// ============================================================================
// STUDENT ASSOCIATION MANAGEMENT
// ============================================================================

/**
 * Add students to a teacher (bulk operation)
 *
 * @param {string} teacherId - Teacher ID
 * @param {string[]} studentIds - Array of student user IDs
 * @returns {Promise<Object>} { added: number, errors: [] }
 */
async function addStudentsToTeacher(teacherId, studentIds) {
  try {
    if (!Array.isArray(studentIds) || studentIds.length === 0) {
      throw new Error('studentIds must be a non-empty array');
    }

    // Get teacher document
    const teacher = await getTeacherById(teacherId);
    if (!teacher) {
      throw new Error('Teacher not found');
    }

    if (!teacher.is_active) {
      throw new Error('Cannot add students to inactive teacher');
    }

    let added = 0;
    const errors = [];

    // Process in batches of 500 (Firestore limit)
    const batchSize = 500;
    for (let i = 0; i < studentIds.length; i += batchSize) {
      const batch = db.batch();
      const batchStudentIds = studentIds.slice(i, i + batchSize);

      for (const studentId of batchStudentIds) {
        try {
          // Get student document
          const studentRef = db.collection('users').doc(studentId);
          const studentDoc = await studentRef.get();

          if (!studentDoc.exists) {
            errors.push({ studentId, error: 'Student not found' });
            continue;
          }

          // Update student with teacher association
          batch.update(studentRef, {
            teacher_id: teacherId,
            coaching_institute_name: teacher.coaching_institute_name,
            updated_at: admin.firestore.FieldValue.serverTimestamp()
          });

          added++;
        } catch (err) {
          errors.push({ studentId, error: err.message });
        }
      }

      // Commit batch
      await batch.commit();
    }

    // Update teacher's student list
    const teacherRef = db.collection('teachers').doc(teacherId);
    const currentStudentIds = teacher.student_ids || [];
    const newStudentIds = [...new Set([...currentStudentIds, ...studentIds.filter(id =>
      !errors.some(e => e.studentId === id)
    )])];

    await retryFirestoreOperation(async () => {
      await teacherRef.update({
        student_ids: newStudentIds,
        total_students: newStudentIds.length,
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    logger.info('Students added to teacher', {
      teacherId,
      added,
      errors: errors.length,
      totalStudents: newStudentIds.length
    });

    return { added, errors };
  } catch (error) {
    logger.error('Error adding students to teacher', {
      teacherId,
      error: error.message
    });
    throw error;
  }
}

/**
 * Remove a student from a teacher
 *
 * @param {string} teacherId - Teacher ID
 * @param {string} studentId - Student user ID
 * @returns {Promise<void>}
 */
async function removeStudentFromTeacher(teacherId, studentId) {
  try {
    // Get teacher
    const teacher = await getTeacherById(teacherId);
    if (!teacher) {
      throw new Error('Teacher not found');
    }

    // Remove teacher_id from student
    const studentRef = db.collection('users').doc(studentId);
    await retryFirestoreOperation(async () => {
      await studentRef.update({
        teacher_id: admin.firestore.FieldValue.delete(),
        coaching_institute_name: admin.firestore.FieldValue.delete(),
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    // Update teacher's student list
    const teacherRef = db.collection('teachers').doc(teacherId);
    const updatedStudentIds = (teacher.student_ids || []).filter(id => id !== studentId);

    await retryFirestoreOperation(async () => {
      await teacherRef.update({
        student_ids: updatedStudentIds,
        total_students: updatedStudentIds.length,
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    logger.info('Student removed from teacher', {
      teacherId,
      studentId,
      remainingStudents: updatedStudentIds.length
    });
  } catch (error) {
    logger.error('Error removing student from teacher', {
      teacherId,
      studentId,
      error: error.message
    });
    throw error;
  }
}

/**
 * Get all students for a teacher
 *
 * @param {string} teacherId - Teacher ID
 * @param {Object} options - Query options
 * @param {number} options.limit - Results per page
 * @param {number} options.offset - Offset for pagination
 * @param {string} options.filter - Filter: 'all', 'active', 'inactive'
 * @returns {Promise<Object>} { students: [], total: number }
 */
async function getTeacherStudents(teacherId, { limit = 50, offset = 0, filter = 'all' } = {}) {
  try {
    // Get teacher to verify it exists
    const teacher = await getTeacherById(teacherId);
    if (!teacher) {
      throw new Error('Teacher not found');
    }

    // Query students with teacher_id
    let query = db.collection('users')
      .where('teacher_id', '==', teacherId);

    const snapshot = await retryFirestoreOperation(async () => {
      return await query.get();
    });

    let students = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    // Apply active filter based on lastActive
    if (filter === 'active') {
      const weekAgo = new Date();
      weekAgo.setDate(weekAgo.getDate() - 7);
      students = students.filter(s => {
        const lastActive = s.lastActive?.toDate?.() || s.lastActive;
        return lastActive && new Date(lastActive) > weekAgo;
      });
    } else if (filter === 'inactive') {
      const weekAgo = new Date();
      weekAgo.setDate(weekAgo.getDate() - 7);
      students = students.filter(s => {
        const lastActive = s.lastActive?.toDate?.() || s.lastActive;
        return !lastActive || new Date(lastActive) <= weekAgo;
      });
    }

    const total = students.length;

    // Apply pagination
    students = students.slice(offset, offset + limit);

    return {
      students,
      total,
      limit,
      offset
    };
  } catch (error) {
    logger.error('Error getting teacher students', {
      teacherId,
      error: error.message
    });
    throw error;
  }
}

module.exports = {
  createTeacher,
  getTeacherById,
  getTeacherByEmail,
  updateTeacher,
  deactivateTeacher,
  listTeachers,
  addStudentsToTeacher,
  removeStudentFromTeacher,
  getTeacherStudents
};
