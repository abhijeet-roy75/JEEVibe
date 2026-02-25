/**
 * Integration Tests: Rate Limiting with Authentication
 *
 * Tests the full middleware chain:
 * conditionalAuth → rate limiter → route handler
 *
 * Verifies that:
 * 1. Authenticated requests use user-based rate limiting (100 req/15min)
 * 2. Unauthenticated requests use IP-based rate limiting (20 req/15min)
 * 3. Multiple users on same IP don't share limits
 */

const request = require('supertest');
const express = require('express');
const { conditionalAuth } = require('../../src/middleware/conditionalAuth');
const { apiLimiter } = require('../../src/middleware/rateLimiter');

// Mock Firebase Admin
const mockVerifyIdToken = jest.fn();
jest.mock('../../src/config/firebase', () => ({
  admin: {
    auth: () => ({
      verifyIdToken: mockVerifyIdToken,
    }),
  },
  db: {},
  storage: {},
}));

// Mock logger to reduce test output
jest.mock('../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  debug: jest.fn(),
  error: jest.fn(),
}));

// Mock Sentry
jest.mock('@sentry/node', () => ({
  setUser: jest.fn(),
}));

const { admin } = require('../../src/config/firebase');

describe('Rate Limiting Integration Tests', () => {
  let app;

  beforeEach(() => {
    jest.clearAllMocks();

    // Create test Express app with middleware chain
    app = express();

    // Simulate production middleware order (AFTER fix)
    app.use((req, res, next) => {
      req.id = 'test-request-id';
      next();
    });

    // Apply conditional auth BEFORE rate limiting
    app.use(conditionalAuth);

    // Apply rate limiting AFTER conditional auth
    app.use(apiLimiter);

    // Test route
    app.get('/api/test', (req, res) => {
      res.json({
        success: true,
        userId: req.userId || null,
        message: 'Test endpoint',
      });
    });

    // Health check (exempt from rate limiting)
    app.get('/api/health', (req, res) => {
      res.json({ success: true, status: 'healthy' });
    });
  });

  describe('Authenticated User Rate Limiting', () => {
    test('authenticated user should get 100 req/15min limit', async () => {
      const userId = 'user-123';
      const token = 'valid-token-123';

      // Mock token verification
      mockVerifyIdToken.mockResolvedValue({
        uid: userId,
        email: 'test@example.com',
      });

      // Make 25 requests (well under 100 limit, over 20 IP limit)
      const requests = [];
      for (let i = 0; i < 25; i++) {
        requests.push(
          request(app)
            .get('/api/test')
            .set('Authorization', `Bearer ${token}`)
        );
      }

      const responses = await Promise.all(requests);

      // All should succeed (authenticated limit is 100)
      const successCount = responses.filter(r => r.status === 200).length;
      expect(successCount).toBe(25);

      // Verify userId was set
      expect(responses[0].body.userId).toBe(userId);
    });

    test('multiple authenticated users on same IP should have separate limits', async () => {
      const user1Token = 'token-user1';
      const user2Token = 'token-user2';
      const user3Token = 'token-user3';

      // Mock token verification for 3 different users
      mockVerifyIdToken.mockImplementation((token) => {
        if (token === user1Token) {
          return Promise.resolve({ uid: 'user-1', email: 'user1@example.com' });
        } else if (token === user2Token) {
          return Promise.resolve({ uid: 'user-2', email: 'user2@example.com' });
        } else if (token === user3Token) {
          return Promise.resolve({ uid: 'user-3', email: 'user3@example.com' });
        }
        return Promise.reject(new Error('Invalid token'));
      });

      // Each user makes 25 requests from SAME IP (simulated by same supertest agent)
      // Total: 75 requests from 1 IP (would exceed 20/15min IP limit)
      const user1Requests = Array(25).fill().map(() =>
        request(app).get('/api/test').set('Authorization', `Bearer ${user1Token}`)
      );

      const user2Requests = Array(25).fill().map(() =>
        request(app).get('/api/test').set('Authorization', `Bearer ${user2Token}`)
      );

      const user3Requests = Array(25).fill().map(() =>
        request(app).get('/api/test').set('Authorization', `Bearer ${user3Token}`)
      );

      const allResponses = await Promise.all([
        ...user1Requests,
        ...user2Requests,
        ...user3Requests,
      ]);

      // All should succeed (each user has 100/15min limit)
      const successCount = allResponses.filter(r => r.status === 200).length;
      expect(successCount).toBe(75);

      // If IP-based limiting was used, would only get 20 successes
      expect(successCount).toBeGreaterThan(20);
    });

    test('authenticated user should be rate limited after 100 requests', async () => {
      const userId = 'heavy-user';
      const token = 'valid-token-heavy';

      mockVerifyIdToken.mockResolvedValue({
        uid: userId,
        email: 'heavy@example.com',
      });

      // Make 105 requests (exceeds 100 limit)
      const requests = [];
      for (let i = 0; i < 105; i++) {
        requests.push(
          request(app)
            .get('/api/test')
            .set('Authorization', `Bearer ${token}`)
        );
      }

      const responses = await Promise.all(requests);

      // First 100 should succeed
      const successCount = responses.filter(r => r.status === 200).length;
      expect(successCount).toBe(100);

      // Remaining should be rate limited (429)
      const rateLimitedCount = responses.filter(r => r.status === 429).length;
      expect(rateLimitedCount).toBe(5);

      // Error message should mention account (not IP)
      const rateLimitedResponse = responses.find(r => r.status === 429);
      expect(rateLimitedResponse.body.error).toContain('account');
      expect(rateLimitedResponse.body.error).not.toContain('IP');
    });
  });

  describe('Unauthenticated/Anonymous Rate Limiting', () => {
    test('unauthenticated requests should get 20 req/15min IP limit', async () => {
      // Make 25 requests without auth header
      const requests = [];
      for (let i = 0; i < 25; i++) {
        requests.push(request(app).get('/api/test'));
      }

      const responses = await Promise.all(requests);

      // First 20 should succeed
      const successCount = responses.filter(r => r.status === 200).length;
      expect(successCount).toBe(20);

      // Remaining should be rate limited
      const rateLimitedCount = responses.filter(r => r.status === 429).length;
      expect(rateLimitedCount).toBe(5);

      // Error message should mention IP (not account)
      const rateLimitedResponse = responses.find(r => r.status === 429);
      expect(rateLimitedResponse.body.error).toContain('IP');
      expect(rateLimitedResponse.body.error).not.toContain('account');
    });

    test('invalid token should fallback to IP-based limiting', async () => {
      // Mock token verification to fail
      mockVerifyIdToken.mockRejectedValue(
        new Error('Invalid token')
      );

      // Make 25 requests with invalid token
      const requests = [];
      for (let i = 0; i < 25; i++) {
        requests.push(
          request(app)
            .get('/api/test')
            .set('Authorization', 'Bearer invalid-token')
        );
      }

      const responses = await Promise.all(requests);

      // Should use IP limit (20), not user limit (100)
      const successCount = responses.filter(r => r.status === 200).length;
      expect(successCount).toBe(20);

      const rateLimitedCount = responses.filter(r => r.status === 429).length;
      expect(rateLimitedCount).toBe(5);
    });
  });

  describe('Exempt Routes', () => {
    test('health check should not be rate limited', async () => {
      // Make 150 requests (exceeds both limits)
      const requests = [];
      for (let i = 0; i < 150; i++) {
        requests.push(request(app).get('/api/health'));
      }

      const responses = await Promise.all(requests);

      // ALL should succeed (health check exempt from rate limiting)
      const successCount = responses.filter(r => r.status === 200).length;
      expect(successCount).toBe(150);
    });
  });

  describe('Rate Limit Headers', () => {
    test('should return rate limit headers in response', async () => {
      const response = await request(app).get('/api/test');

      expect(response.headers).toHaveProperty('ratelimit-limit');
      expect(response.headers).toHaveProperty('ratelimit-remaining');
      expect(response.headers).toHaveProperty('ratelimit-reset');
    });

    test('authenticated user should see 100 limit in headers', async () => {
      mockVerifyIdToken.mockResolvedValue({
        uid: 'user-456',
        email: 'test@example.com',
      });

      const response = await request(app)
        .get('/api/test')
        .set('Authorization', 'Bearer valid-token');

      expect(response.headers['ratelimit-limit']).toBe('100');
    });

    test('unauthenticated user should see 20 limit in headers', async () => {
      const response = await request(app).get('/api/test');

      expect(response.headers['ratelimit-limit']).toBe('20');
    });
  });

  describe('Real-World Scenarios', () => {
    test('school WiFi scenario: 5 students, 1 IP, each makes 15 requests', async () => {
      // Simulate school WiFi: 5 students on same network
      const students = [
        { token: 'token-student1', uid: 'student-1' },
        { token: 'token-student2', uid: 'student-2' },
        { token: 'token-student3', uid: 'student-3' },
        { token: 'token-student4', uid: 'student-4' },
        { token: 'token-student5', uid: 'student-5' },
      ];

      // Mock token verification
      mockVerifyIdToken.mockImplementation((token) => {
        const student = students.find(s => s.token === token);
        if (student) {
          return Promise.resolve({
            uid: student.uid,
            email: `${student.uid}@school.edu`,
          });
        }
        return Promise.reject(new Error('Invalid token'));
      });

      // Each student makes 15 requests (total 75)
      const allRequests = [];
      for (const student of students) {
        for (let i = 0; i < 15; i++) {
          allRequests.push(
            request(app)
              .get('/api/test')
              .set('Authorization', `Bearer ${student.token}`)
          );
        }
      }

      const responses = await Promise.all(allRequests);

      // ALL should succeed (user-based limiting, not IP-based)
      const successCount = responses.filter(r => r.status === 200).length;
      expect(successCount).toBe(75);

      // Verify different userIds
      const userIds = new Set(responses.map(r => r.body.userId));
      expect(userIds.size).toBe(5);

      // OLD BEHAVIOR (broken): Would only get 20 successes (IP limit)
      // NEW BEHAVIOR (fixed): Get all 75 successes (user limits)
      expect(successCount).toBeGreaterThan(20);
    });

    test('VPN scenario: same exit node IP, multiple users', async () => {
      // Simulate VPN exit node: 10 users sharing 1 IP
      const vpnUsers = Array(10).fill().map((_, i) => ({
        token: `token-vpn-user${i}`,
        uid: `vpn-user-${i}`,
      }));

      mockVerifyIdToken.mockImplementation((token) => {
        const user = vpnUsers.find(u => u.token === token);
        if (user) {
          return Promise.resolve({
            uid: user.uid,
            email: `${user.uid}@vpn.com`,
          });
        }
        return Promise.reject(new Error('Invalid token'));
      });

      // Each user makes 5 requests (total 50)
      const allRequests = [];
      for (const user of vpnUsers) {
        for (let i = 0; i < 5; i++) {
          allRequests.push(
            request(app)
              .get('/api/test')
              .set('Authorization', `Bearer ${user.token}`)
          );
        }
      }

      const responses = await Promise.all(allRequests);

      // ALL should succeed (50 < 100 per user)
      const successCount = responses.filter(r => r.status === 200).length;
      expect(successCount).toBe(50);

      // OLD BEHAVIOR: Would only get 20 successes
      // NEW BEHAVIOR: All 50 succeed
      expect(successCount).toBeGreaterThan(20);
    });
  });
});
