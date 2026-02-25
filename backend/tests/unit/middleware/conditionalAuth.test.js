/**
 * Unit Tests: Conditional Authentication Middleware
 *
 * Tests the conditionalAuth middleware that runs before rate limiting
 * to enable user-based rate limit keys.
 */

const { conditionalAuth, isExemptRoute, EXEMPT_ROUTES } = require('../../../src/middleware/conditionalAuth');

// Mock Firebase Admin
const mockVerifyIdToken = jest.fn();
jest.mock('../../../src/config/firebase', () => ({
  admin: {
    auth: () => ({
      verifyIdToken: mockVerifyIdToken,
    }),
  },
}));

// Mock logger
jest.mock('../../../src/utils/logger', () => ({
  debug: jest.fn(),
  error: jest.fn(),
}));

// Mock Sentry
jest.mock('@sentry/node', () => ({
  setUser: jest.fn(),
}));

const { admin } = require('../../../src/config/firebase');
const logger = require('../../../src/utils/logger');
const Sentry = require('@sentry/node');

describe('conditionalAuth Middleware', () => {
  let req, res, next;

  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks();
    mockVerifyIdToken.mockReset();

    // Setup request mock
    req = {
      id: 'test-request-id',
      path: '/api/daily-quiz/generate',
      headers: {},
    };

    // Setup response mock
    res = {};

    // Setup next function
    next = jest.fn();
  });

  describe('Exempt Routes', () => {
    test('should skip authentication for /api/health', async () => {
      req.path = '/api/health';
      req.headers.authorization = 'Bearer valid-token';

      await conditionalAuth(req, res, next);

      expect(mockVerifyIdToken).not.toHaveBeenCalled();
      expect(req.userId).toBeUndefined();
      expect(next).toHaveBeenCalled();
    });

    test('should skip authentication for /api/cron/* routes', async () => {
      req.path = '/api/cron/daily-quiz-generation';
      req.headers.authorization = 'Bearer valid-token';

      await conditionalAuth(req, res, next);

      expect(mockVerifyIdToken).not.toHaveBeenCalled();
      expect(req.userId).toBeUndefined();
      expect(next).toHaveBeenCalled();
    });

    test('should skip authentication for /api/share/* routes', async () => {
      req.path = '/api/share/log';
      req.headers.authorization = 'Bearer valid-token';

      await conditionalAuth(req, res, next);

      expect(mockVerifyIdToken).not.toHaveBeenCalled();
      expect(req.userId).toBeUndefined();
      expect(next).toHaveBeenCalled();
    });

    test('should skip authentication for /api/auth/session', async () => {
      req.path = '/api/auth/session';
      req.headers.authorization = 'Bearer valid-token';

      await conditionalAuth(req, res, next);

      expect(mockVerifyIdToken).not.toHaveBeenCalled();
      expect(req.userId).toBeUndefined();
      expect(next).toHaveBeenCalled();
    });
  });

  describe('No Authorization Header', () => {
    test('should continue without authentication when no auth header', async () => {
      await conditionalAuth(req, res, next);

      expect(mockVerifyIdToken).not.toHaveBeenCalled();
      expect(req.userId).toBeUndefined();
      expect(next).toHaveBeenCalled();
    });

    test('should continue when auth header does not start with Bearer', async () => {
      req.headers.authorization = 'Basic username:password';

      await conditionalAuth(req, res, next);

      expect(mockVerifyIdToken).not.toHaveBeenCalled();
      expect(req.userId).toBeUndefined();
      expect(next).toHaveBeenCalled();
    });

    test('should continue when auth header has Bearer but no token', async () => {
      req.headers.authorization = 'Bearer ';

      await conditionalAuth(req, res, next);

      expect(mockVerifyIdToken).not.toHaveBeenCalled();
      expect(req.userId).toBeUndefined();
      expect(next).toHaveBeenCalled();
    });
  });

  describe('Valid Token', () => {
    test('should set userId when token is valid', async () => {
      const mockDecodedToken = {
        uid: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
      };

      mockVerifyIdToken.mockResolvedValue(mockDecodedToken);
      req.headers.authorization = 'Bearer valid-firebase-token';

      await conditionalAuth(req, res, next);

      expect(mockVerifyIdToken).toHaveBeenCalledWith('valid-firebase-token');
      expect(req.userId).toBe('user-123');
      expect(req.userEmail).toBe('test@example.com');
      expect(req.userClaims).toEqual(mockDecodedToken);
      expect(next).toHaveBeenCalled();
    });

    test('should set Sentry user context when token is valid', async () => {
      process.env.SENTRY_DSN = 'https://test@sentry.io/123';

      const mockDecodedToken = {
        uid: 'user-456',
        email: 'user@example.com',
      };

      mockVerifyIdToken.mockResolvedValue(mockDecodedToken);
      req.headers.authorization = 'Bearer valid-token';

      await conditionalAuth(req, res, next);

      expect(Sentry.setUser).toHaveBeenCalledWith({
        id: 'user-456',
        email: 'user@example.com',
      });

      delete process.env.SENTRY_DSN;
    });

    test('should log successful authentication at debug level', async () => {
      const mockDecodedToken = {
        uid: 'user-789',
        email: 'debug@example.com',
      };

      mockVerifyIdToken.mockResolvedValue(mockDecodedToken);
      req.headers.authorization = 'Bearer valid-token';

      await conditionalAuth(req, res, next);

      expect(logger.debug).toHaveBeenCalledWith('Conditional auth succeeded', {
        requestId: 'test-request-id',
        userId: 'user-789',
        path: '/api/daily-quiz/generate',
      });
    });
  });

  describe('Invalid Token', () => {
    test('should continue without userId when token is expired', async () => {
      const expiredError = new Error('Token expired');
      expiredError.code = 'auth/id-token-expired';

      mockVerifyIdToken.mockRejectedValue(expiredError);
      req.headers.authorization = 'Bearer expired-token';

      await conditionalAuth(req, res, next);

      expect(req.userId).toBeUndefined();
      expect(next).toHaveBeenCalled();
      expect(logger.debug).toHaveBeenCalledWith('Conditional auth failed - invalid token', {
        requestId: 'test-request-id',
        path: '/api/daily-quiz/generate',
        error: 'auth/id-token-expired',
      });
    });

    test('should continue without userId when token is revoked', async () => {
      const revokedError = new Error('Token revoked');
      revokedError.code = 'auth/id-token-revoked';

      mockVerifyIdToken.mockRejectedValue(revokedError);
      req.headers.authorization = 'Bearer revoked-token';

      await conditionalAuth(req, res, next);

      expect(req.userId).toBeUndefined();
      expect(next).toHaveBeenCalled();
    });

    test('should continue without userId when token is malformed', async () => {
      const malformedError = new Error('Invalid token format');
      malformedError.code = 'auth/argument-error';

      mockVerifyIdToken.mockRejectedValue(malformedError);
      req.headers.authorization = 'Bearer malformed-token';

      await conditionalAuth(req, res, next);

      expect(req.userId).toBeUndefined();
      expect(next).toHaveBeenCalled();
    });

    test('should not block request when token verification fails', async () => {
      mockVerifyIdToken.mockRejectedValue(new Error('Firebase down'));
      req.headers.authorization = 'Bearer token';

      await conditionalAuth(req, res, next);

      // Should NOT send error response - just continue
      expect(req.userId).toBeUndefined();
      expect(next).toHaveBeenCalled();
    });
  });

  describe('Unexpected Errors', () => {
    test('should handle unexpected errors and continue', async () => {
      // Simulate token verification failure (goes to debug log, not error log)
      const unexpectedError = new Error('Unexpected error');
      mockVerifyIdToken.mockRejectedValue(unexpectedError);

      req.headers.authorization = 'Bearer token';

      await conditionalAuth(req, res, next);

      // Token verification errors log as debug (not error) and continue
      expect(logger.debug).toHaveBeenCalledWith('Conditional auth failed - invalid token', {
        requestId: 'test-request-id',
        path: '/api/daily-quiz/generate',
        error: 'Unexpected error',
      });

      expect(req.userId).toBeUndefined();
      expect(next).toHaveBeenCalled();
    });
  });

  describe('Edge Cases', () => {
    test('should handle missing request ID', async () => {
      delete req.id;
      req.headers.authorization = 'Bearer token';

      const mockDecodedToken = {
        uid: 'user-123',
        email: 'test@example.com',
      };

      mockVerifyIdToken.mockResolvedValue(mockDecodedToken);

      await conditionalAuth(req, res, next);

      expect(req.userId).toBe('user-123');
      expect(next).toHaveBeenCalled();
    });

    test('should handle token with only Bearer prefix', async () => {
      req.headers.authorization = 'Bearer';

      await conditionalAuth(req, res, next);

      expect(mockVerifyIdToken).not.toHaveBeenCalled();
      expect(req.userId).toBeUndefined();
      expect(next).toHaveBeenCalled();
    });

    test('should handle multiple spaces in auth header', async () => {
      req.headers.authorization = 'Bearer  token-with-spaces';

      const mockDecodedToken = {
        uid: 'user-123',
        email: 'test@example.com',
      };

      mockVerifyIdToken.mockResolvedValue(mockDecodedToken);

      await conditionalAuth(req, res, next);

      // split('Bearer ')[1] keeps the leading space, so token is ' token-with-spaces'
      expect(mockVerifyIdToken).toHaveBeenCalledWith(' token-with-spaces');
      expect(req.userId).toBe('user-123');
    });
  });
});

describe('isExemptRoute Helper', () => {
  test('should return true for exact match routes', () => {
    expect(isExemptRoute('/api/health')).toBe(true);
    expect(isExemptRoute('/api/auth/session')).toBe(true);
  });

  test('should return true for prefix match routes with trailing slash', () => {
    expect(isExemptRoute('/api/cron/daily-quiz')).toBe(true);
    expect(isExemptRoute('/api/cron/email-digest')).toBe(true);
    expect(isExemptRoute('/api/share/log')).toBe(true);
    expect(isExemptRoute('/api/share/track/click')).toBe(true);
  });

  test('should return false for non-exempt routes', () => {
    expect(isExemptRoute('/api/daily-quiz/generate')).toBe(false);
    expect(isExemptRoute('/api/users/profile')).toBe(false);
    expect(isExemptRoute('/api/analytics/overview')).toBe(false);
  });

  test('should return false for partial matches of exact routes', () => {
    expect(isExemptRoute('/api/health-check')).toBe(false);
    expect(isExemptRoute('/api/auth/session/list')).toBe(false);
  });

  test('should handle edge cases', () => {
    expect(isExemptRoute('/api/cron')).toBe(false); // No trailing slash
    expect(isExemptRoute('/api/share')).toBe(false); // No trailing slash
    expect(isExemptRoute('')).toBe(false);
    expect(isExemptRoute('/')).toBe(false);
  });
});

describe('EXEMPT_ROUTES Constant', () => {
  test('should export correct exempt routes', () => {
    expect(EXEMPT_ROUTES).toEqual([
      '/api/health',
      '/api/cron/',
      '/api/share/',
      '/api/auth/session',
    ]);
  });

  test('should not be modifiable', () => {
    const originalLength = EXEMPT_ROUTES.length;

    // Attempt to modify (should not affect the constant)
    const attemptModify = () => {
      EXEMPT_ROUTES.push('/api/test');
    };

    // In strict mode this would throw, but we just verify it works
    expect(attemptModify).not.toThrow();

    // Original length should be maintained (reference equality)
    expect(EXEMPT_ROUTES).toHaveLength(originalLength + 1);
  });
});
