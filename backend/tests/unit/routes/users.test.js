const request = require('supertest');
const express = require('express');

// Mock auth middleware
jest.mock('../../../src/middleware/auth', () => ({
  authenticateUser: jest.fn((req, res, next) => {
    req.userId = 'test-user-123';
    req.id = 'request-id-123';
    next();
  }),
}));

// Mock Firebase config BEFORE requiring the router
jest.mock('../../../src/config/firebase', () => ({
  db: {
    collection: jest.fn(),
  },
  admin: {
    firestore: jest.fn(() => ({
      FieldValue: {
        serverTimestamp: jest.fn(() => 'TIMESTAMP'),
        delete: jest.fn(() => 'DELETE'),
      },
    })),
    FieldValue: {
      serverTimestamp: jest.fn(() => 'TIMESTAMP'),
      delete: jest.fn(() => 'DELETE'),
    },
  },
}));

// Mock cache
jest.mock('../../../src/utils/cache', () => ({
  delCache: jest.fn(),
  CacheKeys: {
    userProfile: jest.fn((userId) => `user:${userId}`),
  },
}));

// Mock retry utility
jest.mock('../../../src/utils/firestoreRetry', () => ({
  retryFirestoreOperation: jest.fn((operation) => operation())
}));

// Mock logger
jest.mock('../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const usersRouter = require('../../../src/routes/users');
const { delCache } = require('../../../src/utils/cache');
const { admin } = require('../../../src/config/firebase');

describe('POST /api/users/fcm-token', () => {
  let app;
  let mockUpdate;
  let mockDoc;
  let mockCollection;

  beforeEach(() => {
    // Setup Express app
    app = express();
    app.use(express.json());
    app.use('/api/users', usersRouter);

    // Setup Firestore mocks
    mockUpdate = jest.fn().mockResolvedValue();
    mockDoc = jest.fn(() => ({ update: mockUpdate }));
    mockCollection = jest.fn(() => ({ doc: mockDoc }));

    const { db } = require('../../../src/config/firebase');
    db.collection = mockCollection;

    // Clear all mocks
    jest.clearAllMocks();
  });

  describe('Success Cases', () => {
    test('should save FCM token successfully', async () => {
      const fcmToken = 'test-fcm-token-12345';

      const response = await request(app)
        .post('/api/users/fcm-token')
        .send({ fcm_token: fcmToken })
        .expect(200);

      // Verify response
      expect(response.body).toEqual({
        success: true,
        message: 'FCM token saved',
        requestId: 'request-id-123',
      });

      // Verify Firestore was called correctly
      expect(mockCollection).toHaveBeenCalledWith('users');
      expect(mockDoc).toHaveBeenCalledWith('test-user-123');
      expect(mockUpdate).toHaveBeenCalledWith({
        fcm_token: fcmToken,
        fcm_token_updated_at: 'TIMESTAMP',
      });

      // Verify cache was invalidated
      expect(delCache).toHaveBeenCalledWith('user:test-user-123');
    });

    test('should clear FCM token when null is provided', async () => {
      const response = await request(app)
        .post('/api/users/fcm-token')
        .send({ fcm_token: null })
        .expect(200);

      // Verify response
      expect(response.body).toEqual({
        success: true,
        message: 'FCM token cleared',
        requestId: 'request-id-123',
      });

      // Verify Firestore was called with delete marker
      expect(mockUpdate).toHaveBeenCalledWith({
        fcm_token: 'DELETE',
        fcm_token_updated_at: 'TIMESTAMP',
      });

      // Verify cache was invalidated
      expect(delCache).toHaveBeenCalledWith('user:test-user-123');
    });

    test('should clear FCM token when empty string is provided', async () => {
      const response = await request(app)
        .post('/api/users/fcm-token')
        .send({ fcm_token: '' })
        .expect(200);

      // Verify response
      expect(response.body).toEqual({
        success: true,
        message: 'FCM token cleared',
        requestId: 'request-id-123',
      });

      // Verify Firestore was called with delete marker
      expect(mockUpdate).toHaveBeenCalledWith({
        fcm_token: 'DELETE',
        fcm_token_updated_at: 'TIMESTAMP',
      });
    });

    test('should update timestamp when token is saved', async () => {
      await request(app)
        .post('/api/users/fcm-token')
        .send({ fcm_token: 'new-token' })
        .expect(200);

      const updateCall = mockUpdate.mock.calls[0][0];
      expect(updateCall).toHaveProperty('fcm_token_updated_at');
      expect(updateCall.fcm_token_updated_at).toBe('TIMESTAMP');
    });
  });

  describe('Error Cases', () => {
    test('should handle Firestore errors gracefully', async () => {
      mockUpdate.mockRejectedValueOnce(new Error('Firestore error'));

      const response = await request(app)
        .post('/api/users/fcm-token')
        .send({ fcm_token: 'test-token' })
        .expect(500);

      expect(response.body.success).toBe(false);
    });

    test('should require authentication', async () => {
      // Create app without auth middleware
      const unauthApp = express();
      unauthApp.use(express.json());
      unauthApp.use('/api/users', usersRouter);

      const response = await request(unauthApp)
        .post('/api/users/fcm-token')
        .send({ fcm_token: 'test-token' })
        .expect(401);

      expect(mockUpdate).not.toHaveBeenCalled();
    });
  });

  describe('Edge Cases', () => {
    test('should handle missing fcm_token field', async () => {
      const response = await request(app)
        .post('/api/users/fcm-token')
        .send({})
        .expect(200);

      // Should treat as clear when undefined
      expect(response.body.message).toBe('FCM token cleared');
    });

    test('should handle very long FCM tokens', async () => {
      const longToken = 'a'.repeat(1000);

      await request(app)
        .post('/api/users/fcm-token')
        .send({ fcm_token: longToken })
        .expect(200);

      expect(mockUpdate).toHaveBeenCalledWith({
        fcm_token: longToken,
        fcm_token_updated_at: 'TIMESTAMP',
      });
    });

    test('should invalidate cache even if update fails', async () => {
      // Note: In the actual implementation, cache is invalidated before update
      // so this test verifies that behavior
      mockUpdate.mockRejectedValueOnce(new Error('Update failed'));

      await request(app)
        .post('/api/users/fcm-token')
        .send({ fcm_token: 'test-token' })
        .catch(() => {});

      // Cache should still be invalidated
      expect(delCache).toHaveBeenCalledWith('user:test-user-123');
    });
  });

  describe('Request ID Tracking', () => {
    test('should include request ID in response', async () => {
      const response = await request(app)
        .post('/api/users/fcm-token')
        .send({ fcm_token: 'test-token' })
        .expect(200);

      expect(response.body.requestId).toBe('request-id-123');
    });
  });
});
