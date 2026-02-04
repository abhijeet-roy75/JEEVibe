/**
 * Teacher Routes
 *
 * API endpoints for teacher management and student associations.
 *
 * Admin Endpoints (require authenticateAdmin):
 * - POST   /api/teachers - Create teacher
 * - GET    /api/teachers - List teachers
 * - GET    /api/teachers/:teacherId - Get teacher details
 * - PATCH  /api/teachers/:teacherId - Update teacher
 * - DELETE /api/teachers/:teacherId - Deactivate teacher
 * - POST   /api/teachers/:teacherId/students - Add students to teacher
 * - DELETE /api/teachers/:teacherId/students/:studentId - Remove student
 * - GET    /api/teachers/:teacherId/students - Get teacher's students
 *
 * Teacher Portal Endpoints (require authenticateTeacher) - FUTURE:
 * - GET /api/teachers/me - Current teacher profile
 * - GET /api/teachers/me/students - My students
 * - GET /api/teachers/me/reports - My weekly reports
 */

const express = require('express');
const { body, param, query, validationResult } = require('express-validator');
const router = express.Router();
const { authenticateAdmin } = require('../middleware/adminAuth');
const { authenticateTeacher } = require('../middleware/teacherAuth');
const teacherService = require('../services/teacherService');
const logger = require('../utils/logger');
const { ApiError } = require('../middleware/errorHandler');

// ============================================================================
// ADMIN ENDPOINTS - Teacher Management
// ============================================================================

/**
 * POST /api/teachers
 * Create a new teacher (admin only)
 */
router.post('/',
  authenticateAdmin,
  [
    body('email').isEmail().normalizeEmail(),
    body('phone_number').matches(/^\+(?:91\d{10}|1\d{10})$/),
    body('first_name').notEmpty().trim(),
    body('last_name').optional().trim(),
    body('coaching_institute_name').optional().trim(),
    body('coaching_institute_location').optional().trim()
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          error: 'Validation failed',
          details: errors.array(),
          requestId: req.id
        });
      }

      const teacher = await teacherService.createTeacher(
        req.body,
        req.userEmail
      );

      res.status(201).json({
        success: true,
        data: teacher,
        requestId: req.id
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * GET /api/teachers
 * List all teachers with pagination and filtering (admin only)
 */
router.get('/',
  authenticateAdmin,
  [
    query('filter').optional().isIn(['all', 'active', 'inactive']),
    query('search').optional().trim(),
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
    query('offset').optional().isInt({ min: 0 }).toInt()
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          error: 'Validation failed',
          details: errors.array(),
          requestId: req.id
        });
      }

      const result = await teacherService.listTeachers({
        filter: req.query.filter || 'all',
        search: req.query.search || '',
        limit: parseInt(req.query.limit || '50'),
        offset: parseInt(req.query.offset || '0')
      });

      res.json({
        success: true,
        data: result,
        requestId: req.id
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * GET /api/teachers/:teacherId
 * Get teacher details (admin only)
 */
router.get('/:teacherId',
  authenticateAdmin,
  [
    param('teacherId').notEmpty()
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          error: 'Validation failed',
          details: errors.array(),
          requestId: req.id
        });
      }

      const teacher = await teacherService.getTeacherById(req.params.teacherId);

      if (!teacher) {
        throw new ApiError(404, 'Teacher not found');
      }

      res.json({
        success: true,
        data: teacher,
        requestId: req.id
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * PATCH /api/teachers/:teacherId
 * Update teacher profile (admin only)
 */
router.patch('/:teacherId',
  authenticateAdmin,
  [
    param('teacherId').notEmpty(),
    body('first_name').optional().trim(),
    body('last_name').optional().trim(),
    body('phone_number').optional().matches(/^\+91\d{10}$/),
    body('coaching_institute_name').optional().trim(),
    body('coaching_institute_location').optional().trim(),
    body('is_active').optional().isBoolean(),
    body('email_preferences').optional().isObject()
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          error: 'Validation failed',
          details: errors.array(),
          requestId: req.id
        });
      }

      const teacher = await teacherService.updateTeacher(
        req.params.teacherId,
        req.body
      );

      res.json({
        success: true,
        data: teacher,
        message: 'Teacher updated successfully',
        requestId: req.id
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * DELETE /api/teachers/:teacherId
 * Deactivate teacher (admin only)
 */
router.delete('/:teacherId',
  authenticateAdmin,
  [
    param('teacherId').notEmpty()
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          error: 'Validation failed',
          details: errors.array(),
          requestId: req.id
        });
      }

      await teacherService.deactivateTeacher(req.params.teacherId);

      res.json({
        success: true,
        message: 'Teacher deactivated successfully',
        requestId: req.id
      });
    } catch (error) {
      next(error);
    }
  }
);

// ============================================================================
// ADMIN ENDPOINTS - Student Association
// ============================================================================

/**
 * POST /api/teachers/:teacherId/students
 * Add students to teacher (admin only)
 */
router.post('/:teacherId/students',
  authenticateAdmin,
  [
    param('teacherId').notEmpty(),
    body('student_ids').isArray({ min: 1 }),
    body('student_ids.*').notEmpty()
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          error: 'Validation failed',
          details: errors.array(),
          requestId: req.id
        });
      }

      const result = await teacherService.addStudentsToTeacher(
        req.params.teacherId,
        req.body.student_ids
      );

      res.json({
        success: true,
        data: result,
        message: `Added ${result.added} students successfully`,
        requestId: req.id
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * DELETE /api/teachers/:teacherId/students/:studentId
 * Remove student from teacher (admin only)
 */
router.delete('/:teacherId/students/:studentId',
  authenticateAdmin,
  [
    param('teacherId').notEmpty(),
    param('studentId').notEmpty()
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          error: 'Validation failed',
          details: errors.array(),
          requestId: req.id
        });
      }

      await teacherService.removeStudentFromTeacher(
        req.params.teacherId,
        req.params.studentId
      );

      res.json({
        success: true,
        message: 'Student removed from teacher successfully',
        requestId: req.id
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * GET /api/teachers/:teacherId/students
 * Get teacher's students (admin only)
 */
router.get('/:teacherId/students',
  authenticateAdmin,
  [
    param('teacherId').notEmpty(),
    query('filter').optional().isIn(['all', 'active', 'inactive']),
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
    query('offset').optional().isInt({ min: 0 }).toInt()
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          error: 'Validation failed',
          details: errors.array(),
          requestId: req.id
        });
      }

      const result = await teacherService.getTeacherStudents(
        req.params.teacherId,
        {
          filter: req.query.filter || 'all',
          limit: parseInt(req.query.limit || '50'),
          offset: parseInt(req.query.offset || '0')
        }
      );

      res.json({
        success: true,
        data: result,
        requestId: req.id
      });
    } catch (error) {
      next(error);
    }
  }
);

// ============================================================================
// TEACHER PORTAL ENDPOINTS (FUTURE)
// ============================================================================

/**
 * GET /api/teachers/me
 * Get current teacher profile (teacher auth)
 *
 * FUTURE: Implement when teacher portal is ready
 */
router.get('/me',
  authenticateTeacher,
  async (req, res, next) => {
    try {
      const teacher = await teacherService.getTeacherById(req.teacherId);

      if (!teacher) {
        throw new ApiError(404, 'Teacher profile not found');
      }

      res.json({
        success: true,
        data: teacher,
        requestId: req.id
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * GET /api/teachers/me/students
 * Get current teacher's students (teacher auth)
 *
 * FUTURE: Implement when teacher portal is ready
 */
router.get('/me/students',
  authenticateTeacher,
  [
    query('filter').optional().isIn(['all', 'active', 'inactive']),
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
    query('offset').optional().isInt({ min: 0 }).toInt()
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          error: 'Validation failed',
          details: errors.array(),
          requestId: req.id
        });
      }

      const result = await teacherService.getTeacherStudents(
        req.teacherId,
        {
          filter: req.query.filter || 'all',
          limit: parseInt(req.query.limit || '50'),
          offset: parseInt(req.query.offset || '0')
        }
      );

      res.json({
        success: true,
        data: result,
        requestId: req.id
      });
    } catch (error) {
      next(error);
    }
  }
);

module.exports = router;
