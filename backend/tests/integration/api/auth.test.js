/**
 * Integration Tests for Auth API Endpoints
 *
 * Tests:
 * - POST /api/auth/session - Create a new session
 * - GET /api/auth/session - Get current session info
 * - POST /api/auth/logout - Clear active session
 * - GET /api/auth/devices - Returns 501 (not implemented)
 * - DELETE /api/auth/devices/:deviceId - Returns 501 (not implemented)
 */

const request = require('supertest');

// Mock multer to prevent "argument handler must be a function" error
jest.mock('multer', () => {
  const multer = () => ({
    single: () => (req, res, next) => next(),
    array: () => (req, res, next) => next(),
    fields: () => (req, res, next) => next(),
    none: () => (req, res, next) => next(),
    any: () => (req, res, next) => next(),
  });
  multer.memoryStorage = () => ({});
  return multer;
});

// Mock user data
let mockUserId = 'test-user-id';
let mockUserExists = true;
let mockUserData = {
  auth: {},
};

// Track updates for assertions
let lastUpdate = null;

// Mock get function
const mockGet = jest.fn(() => Promise.resolve({
  exists: mockUserExists,
  data: () => mockUserData,
}));

// Mock update function
const mockUpdate = jest.fn((data) => {
  lastUpdate = data;
  return Promise.resolve();
});

// Mock Firebase
jest.mock('../../../src/config/firebase', () => {
  return {
    db: {
      collection: jest.fn(() => ({
        doc: jest.fn(() => ({
          get: mockGet,
          update: mockUpdate,
        })),
      })),
    },
    admin: {
      auth: jest.fn(() => ({
        verifyIdToken: jest.fn(() => Promise.resolve({ uid: mockUserId })),
      })),
      firestore: {
        FieldValue: {
          serverTimestamp: jest.fn(() => ({ _serverTimestamp: true })),
          delete: jest.fn(() => ({ _delete: true })),
        },
      },
    },
  };
});

// Mock firestoreRetry
jest.mock('../../../src/utils/firestoreRetry', () => ({
  retryFirestoreOperation: jest.fn((fn) => fn()),
}));

// Mock auth middleware
jest.mock('../../../src/middleware/auth', () => ({
  authenticateToken: (req, res, next) => {
    req.user = { uid: mockUserId };
    next();
  },
  authenticateUser: (req, res, next) => {
    req.userId = mockUserId;
    next();
  },
}));

// Mock logger
jest.mock('../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

// Import app after mocks
const app = require('../../../src/index');

describe('Auth API', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockUserId = 'test-user-id';
    mockUserExists = true;
    mockUserData = { auth: {} };
    lastUpdate = null;

    // Reset mock implementations
    mockGet.mockImplementation(() => Promise.resolve({
      exists: mockUserExists,
      data: () => mockUserData,
    }));
    mockUpdate.mockImplementation((data) => {
      lastUpdate = data;
      return Promise.resolve();
    });
  });

  // ============================================================================
  // POST /api/auth/session
  // ============================================================================
  describe('POST /api/auth/session', () => {
    test('creates session and returns token', async () => {
      const response = await request(app)
        .post('/api/auth/session')
        .set('Authorization', 'Bearer test-token')
        .send({
          deviceId: 'device-123',
          deviceName: 'iPhone 14',
        });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.sessionToken).toMatch(/^sess_[a-f0-9]{64}$/);
      expect(response.body.data.message).toBe('Session created successfully');
    });

    test('returns 400 if deviceId is missing', async () => {
      const response = await request(app)
        .post('/api/auth/session')
        .set('Authorization', 'Bearer test-token')
        .send({
          deviceName: 'iPhone 14',
          // deviceId is missing
        });

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('deviceId is required');
    });

    test('returns 404 if user profile not found (Firestore NOT_FOUND)', async () => {
      mockUpdate.mockRejectedValueOnce({ code: 5, message: 'NOT_FOUND' });

      const response = await request(app)
        .post('/api/auth/session')
        .set('Authorization', 'Bearer test-token')
        .send({
          deviceId: 'device-123',
        });

      expect(response.status).toBe(404);
      expect(response.body.error).toContain('User profile not found');
    });

    test('stores session data with correct fields', async () => {
      await request(app)
        .post('/api/auth/session')
        .set('Authorization', 'Bearer test-token')
        .set('X-Forwarded-For', '203.0.113.50')
        .send({
          deviceId: 'my-device',
          deviceName: 'Pixel 8',
        });

      expect(lastUpdate).toBeTruthy();
      const sessionData = lastUpdate['auth.active_session'];
      expect(sessionData.device_id).toBe('my-device');
      expect(sessionData.device_name).toBe('Pixel 8');
      expect(sessionData.token).toMatch(/^sess_/);
    });
  });

  // ============================================================================
  // GET /api/auth/session
  // ============================================================================
  describe('GET /api/auth/session', () => {
    test('returns session info when session exists', async () => {
      const createdAt = new Date('2024-01-15T10:00:00Z');
      const lastActive = new Date('2024-01-15T12:30:00Z');

      mockUserData = {
        auth: {
          active_session: {
            token: 'sess_secret_token',
            device_id: 'device-abc',
            device_name: 'Samsung Galaxy',
            created_at: { toDate: () => createdAt },
            last_active_at: { toDate: () => lastActive },
            ip_address: '192.168.1.100',
          },
        },
      };

      const response = await request(app)
        .get('/api/auth/session')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.session).toMatchObject({
        device_id: 'device-abc',
        device_name: 'Samsung Galaxy',
        ip_address: '192.168.1.100',
      });
      // Token should NOT be returned
      expect(response.body.data.session.token).toBeUndefined();
    });

    test('returns 404 if no active session', async () => {
      mockUserData = { auth: {} };

      const response = await request(app)
        .get('/api/auth/session')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(404);
      expect(response.body.success).toBe(false);
      expect(response.body.code).toBe('NO_ACTIVE_SESSION');
    });

    test('returns 404 if user does not exist', async () => {
      mockUserExists = false;

      const response = await request(app)
        .get('/api/auth/session')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(404);
    });
  });

  // ============================================================================
  // POST /api/auth/logout
  // ============================================================================
  describe('POST /api/auth/logout', () => {
    test('clears session and returns success', async () => {
      const response = await request(app)
        .post('/api/auth/logout')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Logged out successfully');
    });

    test('returns success even if clearing fails (graceful degradation)', async () => {
      mockUpdate.mockRejectedValueOnce(new Error('Firestore error'));

      const response = await request(app)
        .post('/api/auth/logout')
        .set('Authorization', 'Bearer test-token');

      // Should still return success so client can proceed with local cleanup
      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.warning).toBeDefined();
    });
  });

  // ============================================================================
  // GET /api/auth/devices (P1 - Not Implemented)
  // ============================================================================
  describe('GET /api/auth/devices', () => {
    test('returns 501 not implemented', async () => {
      const response = await request(app)
        .get('/api/auth/devices')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(501);
      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('not yet implemented');
    });
  });

  // ============================================================================
  // DELETE /api/auth/devices/:deviceId (P1 - Not Implemented)
  // ============================================================================
  describe('DELETE /api/auth/devices/:deviceId', () => {
    test('returns 501 not implemented', async () => {
      const response = await request(app)
        .delete('/api/auth/devices/device-123')
        .set('Authorization', 'Bearer test-token');

      expect(response.status).toBe(501);
      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('not yet implemented');
    });
  });
});
