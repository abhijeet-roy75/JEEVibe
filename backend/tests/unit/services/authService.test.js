/**
 * Unit Tests for Auth Service - Session Management
 *
 * Tests:
 * - generateSecureToken: format and uniqueness
 * - createSession: creates session with correct data, replaces existing session
 * - validateSession: validates tokens, handles expired/invalid sessions
 * - updateLastActive: debounced updates
 * - clearSession: removes active session
 * - getSessionInfo: returns session info without token
 */

// Mock data storage
let mockUserData = {};
let mockUserExists = true;

// Create mock functions that can be configured per test
const mockGet = jest.fn(() => Promise.resolve({
  exists: mockUserExists,
  data: () => mockUserData,
}));

const mockUpdate = jest.fn((data) => {
  if (data['auth.active_session']) {
    mockUserData.auth = { ...mockUserData.auth, active_session: data['auth.active_session'] };
  }
  if (data['auth.active_session.last_active_at']) {
    if (mockUserData.auth?.active_session) {
      mockUserData.auth.active_session.last_active_at = data['auth.active_session.last_active_at'];
    }
  }
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
          set: mockUpdate, // Use same mock for set() method
        })),
      })),
    },
    admin: {
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

// Mock logger
jest.mock('../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const {
  generateSecureToken,
  createSession,
  validateSession,
  updateLastActive,
  clearSession,
  getSessionInfo,
  SESSION_MAX_AGE_DAYS
} = require('../../../src/services/authService');

const { db, admin } = require('../../../src/config/firebase');

describe('authService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Reset mock user data
    mockUserData = {
      auth: {},
    };
    mockUserExists = true;

    // Reset mock implementations
    mockGet.mockImplementation(() => Promise.resolve({
      exists: mockUserExists,
      data: () => mockUserData,
    }));
    mockUpdate.mockImplementation((data) => {
      if (data['auth.active_session']) {
        mockUserData.auth = { ...mockUserData.auth, active_session: data['auth.active_session'] };
      }
      return Promise.resolve();
    });
  });

  describe('generateSecureToken', () => {
    test('generates token with correct format (sess_ prefix)', () => {
      const token = generateSecureToken();

      expect(token).toMatch(/^sess_[a-f0-9]{64}$/);
    });

    test('generates unique tokens on each call', () => {
      const token1 = generateSecureToken();
      const token2 = generateSecureToken();
      const token3 = generateSecureToken();

      expect(token1).not.toBe(token2);
      expect(token2).not.toBe(token3);
      expect(token1).not.toBe(token3);
    });

    test('token has correct length (5 prefix + 64 hex chars)', () => {
      const token = generateSecureToken();

      expect(token.length).toBe(69); // "sess_" (5) + 64 hex chars
    });
  });

  describe('createSession', () => {
    test('creates session and returns token', async () => {
      const userId = 'test-user-123';
      const deviceInfo = {
        deviceId: 'device-abc',
        deviceName: 'iPhone 14 Pro',
        ipAddress: '192.168.1.1',
      };

      const token = await createSession(userId, deviceInfo);

      expect(token).toMatch(/^sess_[a-f0-9]{64}$/);
    });

    test('calls Firestore update with correct session data', async () => {
      const userId = 'test-user-123';
      const deviceInfo = {
        deviceId: 'device-abc',
        deviceName: 'Test Device',
        ipAddress: '10.0.0.1',
      };

      await createSession(userId, deviceInfo);

      expect(db.collection).toHaveBeenCalledWith('users');
      expect(mockUpdate).toHaveBeenCalledWith({
        auth: {
          active_session: expect.objectContaining({
            token: expect.stringMatching(/^sess_/),
            device_id: 'device-abc',
            device_name: 'Test Device',
            ip_address: '10.0.0.1',
          }),
        },
      }, { merge: true });
    });

    test('uses "Unknown Device" when deviceName not provided', async () => {
      await createSession('user-123', { deviceId: 'device-1' });

      expect(mockUpdate).toHaveBeenCalledWith({
        auth: {
          active_session: expect.objectContaining({
            device_name: 'Unknown Device',
          }),
        },
      }, { merge: true });
    });

    test('logs session creation', async () => {
      const logger = require('../../../src/utils/logger');

      await createSession('user-123', {
        deviceId: 'device-1',
        deviceName: 'My Phone',
      });

      expect(logger.info).toHaveBeenCalledWith('Session created', {
        userId: 'user-123',
        deviceId: 'device-1',
        deviceName: 'My Phone',
      });
    });
  });

  describe('validateSession', () => {
    test('returns valid=true for matching active session', async () => {
      const sessionToken = 'sess_abc123';
      mockUserData = {
        auth: {
          active_session: {
            token: sessionToken,
            device_id: 'device-1',
            created_at: {
              toDate: () => new Date(), // Just created
            },
          },
        },
      };

      const result = await validateSession('user-123', sessionToken);

      expect(result.valid).toBe(true);
      expect(result.session).toBeDefined();
      expect(result.session.token).toBe(sessionToken);
    });

    test('returns USER_NOT_FOUND for non-existent user', async () => {
      mockUserExists = false;

      const result = await validateSession('non-existent', 'sess_abc');

      expect(result.valid).toBe(false);
      expect(result.code).toBe('USER_NOT_FOUND');
      expect(result.message).toBe('User not found');
    });

    test('returns NO_ACTIVE_SESSION when no session exists', async () => {
      mockUserData = {
        auth: {},
      };

      const result = await validateSession('user-123', 'sess_abc');

      expect(result.valid).toBe(false);
      expect(result.code).toBe('NO_ACTIVE_SESSION');
      expect(result.message).toContain('No active session');
    });

    test('returns SESSION_EXPIRED for token mismatch (logged in elsewhere)', async () => {
      mockUserData = {
        auth: {
          active_session: {
            token: 'sess_different_token',
            device_id: 'device-2',
            created_at: { toDate: () => new Date() },
          },
        },
      };

      const result = await validateSession('user-123', 'sess_old_token');

      expect(result.valid).toBe(false);
      expect(result.code).toBe('SESSION_EXPIRED');
      expect(result.message).toContain('another device');
    });

    test('returns SESSION_EXPIRED_AGE for sessions older than 30 days', async () => {
      const oldDate = new Date();
      oldDate.setDate(oldDate.getDate() - 31); // 31 days ago

      mockUserData = {
        auth: {
          active_session: {
            token: 'sess_old',
            device_id: 'device-1',
            created_at: { toDate: () => oldDate },
          },
        },
      };

      const result = await validateSession('user-123', 'sess_old');

      expect(result.valid).toBe(false);
      expect(result.code).toBe('SESSION_EXPIRED_AGE');
      expect(result.message).toContain('expired');
    });

    test('returns valid for session created exactly 29 days ago', async () => {
      const date29DaysAgo = new Date();
      date29DaysAgo.setDate(date29DaysAgo.getDate() - 29);

      mockUserData = {
        auth: {
          active_session: {
            token: 'sess_still_valid',
            device_id: 'device-1',
            created_at: { toDate: () => date29DaysAgo },
          },
        },
      };

      const result = await validateSession('user-123', 'sess_still_valid');

      expect(result.valid).toBe(true);
    });
  });

  describe('updateLastActive', () => {
    test('updates last_active_at when older than debounce threshold', async () => {
      const oldDate = new Date();
      oldDate.setMinutes(oldDate.getMinutes() - 10); // 10 minutes ago

      const session = {
        last_active_at: { toDate: () => oldDate },
      };

      await updateLastActive('user-123', session);

      expect(mockUpdate).toHaveBeenCalledWith({
        auth: {
          active_session: {
            last_active_at: expect.anything(),
          },
        },
      }, { merge: true });
    });

    test('does not update when last_active_at is recent (within debounce)', async () => {
      const recentDate = new Date();
      recentDate.setMinutes(recentDate.getMinutes() - 2); // 2 minutes ago

      const session = {
        last_active_at: { toDate: () => recentDate },
      };

      await updateLastActive('user-123', session);

      expect(mockUpdate).not.toHaveBeenCalled();
    });

    test('updates when last_active_at is missing', async () => {
      const session = {
        last_active_at: null,
      };

      await updateLastActive('user-123', session);

      expect(mockUpdate).toHaveBeenCalled();
    });

    test('handles errors gracefully (non-critical)', async () => {
      const logger = require('../../../src/utils/logger');
      mockUpdate.mockRejectedValueOnce(new Error('Network error'));

      const session = {
        last_active_at: null,
      };

      // Should not throw
      await updateLastActive('user-123', session);

      expect(logger.warn).toHaveBeenCalledWith('Failed to update last_active_at', expect.anything());
    });
  });

  describe('clearSession', () => {
    test('removes active session from user document', async () => {
      await clearSession('user-123');

      expect(db.collection).toHaveBeenCalledWith('users');
      expect(mockUpdate).toHaveBeenCalledWith({
        auth: {
          active_session: expect.anything(),
        },
      }, { merge: true });
    });

    test('logs session clear (logout)', async () => {
      const logger = require('../../../src/utils/logger');

      await clearSession('user-123');

      expect(logger.info).toHaveBeenCalledWith('Session cleared (logout)', {
        userId: 'user-123',
      });
    });
  });

  describe('getSessionInfo', () => {
    test('returns session info without token', async () => {
      const createdAt = new Date('2024-01-01T10:00:00Z');
      const lastActive = new Date('2024-01-01T12:00:00Z');

      mockUserData = {
        auth: {
          active_session: {
            token: 'sess_secret_token',
            device_id: 'device-123',
            device_name: 'Test Phone',
            created_at: { toDate: () => createdAt },
            last_active_at: { toDate: () => lastActive },
            ip_address: '192.168.1.1',
          },
        },
      };

      const result = await getSessionInfo('user-123');

      expect(result).toEqual({
        device_id: 'device-123',
        device_name: 'Test Phone',
        created_at: createdAt,
        last_active_at: lastActive,
        ip_address: '192.168.1.1',
      });
      // Token should NOT be in the response
      expect(result.token).toBeUndefined();
    });

    test('returns null for non-existent user', async () => {
      mockUserExists = false;

      const result = await getSessionInfo('non-existent');

      expect(result).toBeNull();
    });

    test('returns null when no active session', async () => {
      mockUserData = {
        auth: {},
      };

      const result = await getSessionInfo('user-123');

      expect(result).toBeNull();
    });

    test('handles timestamps that are already Date objects', async () => {
      const createdAt = new Date('2024-01-01T10:00:00Z');

      mockUserData = {
        auth: {
          active_session: {
            token: 'sess_token',
            device_id: 'device-1',
            device_name: 'Device',
            created_at: createdAt, // Already a Date, no toDate()
            last_active_at: createdAt,
            ip_address: null,
          },
        },
      };

      const result = await getSessionInfo('user-123');

      expect(result.created_at).toEqual(createdAt);
    });
  });

  describe('SESSION_MAX_AGE_DAYS', () => {
    test('is set to 30 days', () => {
      expect(SESSION_MAX_AGE_DAYS).toBe(30);
    });
  });
});
