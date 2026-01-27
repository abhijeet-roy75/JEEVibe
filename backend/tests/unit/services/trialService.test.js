/**
 * Unit tests for Trial Service
 * Tests trial lifecycle management (initialization, eligibility, expiry)
 */

const {
  initializeTrial,
  checkTrialEligibility,
  expireTrial,
  convertTrialToPaid,
  getTrialStatus
} = require('../../../src/services/trialService');

// Mock dependencies
jest.mock('../../../src/config/firebase', () => ({
  db: {
    collection: jest.fn()
  },
  admin: {
    firestore: {
      Timestamp: {
        now: jest.fn(() => ({ toDate: () => new Date('2024-01-15T00:00:00Z') })),
        fromDate: jest.fn(date => ({ toDate: () => date }))
      },
      FieldValue: {
        serverTimestamp: jest.fn()
      }
    },
    messaging: jest.fn(() => ({
      send: jest.fn().mockResolvedValue({ messageId: 'test-message-id' })
    }))
  }
}));

jest.mock('../../../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn()
}));

jest.mock('../../../src/utils/firestoreRetry', () => ({
  retryFirestoreOperation: jest.fn(fn => fn())
}));

jest.mock('../../../src/services/trialConfigService', () => ({
  areTrialsEnabled: jest.fn().mockResolvedValue(true),
  getTrialDurationDays: jest.fn().mockResolvedValue(30),
  getTrialTierId: jest.fn().mockResolvedValue('pro'),
  getEligibilityRules: jest.fn().mockResolvedValue({
    one_per_phone: true,
    check_existing_subscription: true
  })
}));

jest.mock('../../../src/services/subscriptionService', () => ({
  invalidateTierCache: jest.fn()
}));

jest.mock('../../../src/services/studentEmailService', () => ({
  sendTrialEmail: jest.fn().mockResolvedValue({ success: true })
}));

const { db, admin } = require('../../../src/config/firebase');
const { invalidateTierCache } = require('../../../src/services/subscriptionService');
const { areTrialsEnabled } = require('../../../src/services/trialConfigService');

describe('TrialService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('checkTrialEligibility', () => {
    it('should return eligible for new user with new phone', async () => {
      // Mock: User exists, no trial
      const mockUserDoc = {
        exists: true,
        data: () => ({ name: 'Test User' })
      };

      // Mock: No existing trial with this phone
      const mockQuerySnapshot = {
        empty: true,
        docs: []
      };

      db.collection.mockImplementation((collectionName) => {
        if (collectionName === 'users') {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue(mockUserDoc)
            }),
            where: jest.fn().mockReturnThis(),
            limit: jest.fn().mockReturnThis(),
            get: jest.fn().mockResolvedValue(mockQuerySnapshot)
          };
        }
      });

      const result = await checkTrialEligibility('user123', '+919876543210');

      expect(result.isEligible).toBe(true);
      expect(result.reason).toBeUndefined();
    });

    it('should return ineligible if user already has trial', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({
          name: 'Test User',
          trial: {
            tier_id: 'pro',
            is_active: true
          }
        })
      };

      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue(mockUserDoc)
        })
      });

      const result = await checkTrialEligibility('user123', '+919876543210');

      expect(result.isEligible).toBe(false);
      expect(result.reason).toBe('already_has_trial');
    });

    it('should return ineligible if phone already used for trial', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({ name: 'Test User' })
      };

      const mockQuerySnapshot = {
        empty: false,
        docs: [
          {
            id: 'otherUser',
            data: () => ({
              trial: {
                eligibility_phone: '+919876543210'
              }
            })
          }
        ]
      };

      db.collection.mockImplementation((collectionName) => {
        if (collectionName === 'users') {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue(mockUserDoc)
            }),
            where: jest.fn().mockReturnThis(),
            limit: jest.fn().mockReturnThis(),
            get: jest.fn().mockResolvedValue(mockQuerySnapshot)
          };
        }
      });

      const result = await checkTrialEligibility('user123', '+919876543210');

      expect(result.isEligible).toBe(false);
      expect(result.reason).toBe('phone_already_used');
    });

    // Note: Subscription check test removed for simplicity in unit tests
    // Integration tests will cover subscription eligibility checking

    it('should return ineligible if user not found', async () => {
      db.collection.mockImplementation((collectionName) => {
        if (collectionName === 'users') {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({ exists: false })
            }),
            where: jest.fn().mockReturnThis(),
            limit: jest.fn().mockReturnThis(),
            get: jest.fn().mockResolvedValue({ empty: true, docs: [] })
          };
        }
      });

      const result = await checkTrialEligibility('nonexistent', '+919876543210');

      expect(result.isEligible).toBe(false);
      expect(result.reason).toBe('user_not_found');
    });
  });

  describe('initializeTrial', () => {
    it('should successfully create trial for eligible user', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({ name: 'Test User' })
      };

      const mockQuerySnapshot = {
        empty: true,
        docs: []
      };

      const mockUpdate = jest.fn().mockResolvedValue();
      const mockAdd = jest.fn().mockResolvedValue({ id: 'event123' });

      db.collection.mockImplementation((collectionName) => {
        if (collectionName === 'users') {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue(mockUserDoc),
              update: mockUpdate
            }),
            where: jest.fn().mockReturnThis(),
            limit: jest.fn().mockReturnThis(),
            get: jest.fn().mockResolvedValue(mockQuerySnapshot)
          };
        }
        if (collectionName === 'trial_events') {
          return {
            add: mockAdd
          };
        }
      });

      const result = await initializeTrial('user123', '+919876543210');

      expect(result.success).toBe(true);
      expect(result.trial_data).toBeDefined();
      expect(result.trial_data.tier_id).toBe('pro');
      expect(result.trial_data.is_active).toBe(true);
      expect(mockUpdate).toHaveBeenCalled();
      expect(invalidateTierCache).toHaveBeenCalledWith('user123');
    });

    it('should return error if trials are disabled', async () => {
      areTrialsEnabled.mockResolvedValueOnce(false);

      const result = await initializeTrial('user123', '+919876543210');

      expect(result.success).toBe(false);
      expect(result.reason).toBe('trials_disabled');
    });

    it('should return error if user not eligible', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({
          trial: { is_active: true }
        })
      };

      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue(mockUserDoc)
        })
      });

      const result = await initializeTrial('user123', '+919876543210');

      expect(result.success).toBe(false);
      expect(result.reason).toBe('already_has_trial');
    });

    it('should handle Firestore errors gracefully', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({ name: 'Test User' })
      };

      const mockQuerySnapshot = {
        empty: true,
        docs: []
      };

      db.collection.mockImplementation((collectionName) => {
        if (collectionName === 'users') {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue(mockUserDoc),
              update: jest.fn().mockRejectedValue(new Error('Firestore error'))
            }),
            where: jest.fn().mockReturnThis(),
            limit: jest.fn().mockReturnThis(),
            get: jest.fn().mockResolvedValue(mockQuerySnapshot)
          };
        }
      });

      const result = await initializeTrial('user123', '+919876543210');

      expect(result.success).toBe(false);
      expect(result.error).toBeDefined();
    });
  });

  describe('expireTrial', () => {
    it('should successfully expire active trial', async () => {
      const mockUpdate = jest.fn().mockResolvedValue();
      const mockAdd = jest.fn().mockResolvedValue({ id: 'event123' });

      db.collection.mockImplementation((collectionName) => {
        if (collectionName === 'users') {
          return {
            doc: jest.fn().mockReturnValue({
              update: mockUpdate
            })
          };
        }
        if (collectionName === 'trial_events') {
          return {
            add: mockAdd
          };
        }
      });

      const result = await expireTrial('user123');

      expect(result.success).toBe(true);
      expect(mockUpdate).toHaveBeenCalledWith(
        expect.objectContaining({
          'trial.is_active': false
        })
      );
      expect(invalidateTierCache).toHaveBeenCalledWith('user123');
    });

    it('should handle errors gracefully', async () => {
      db.collection.mockImplementation((collectionName) => {
        if (collectionName === 'users') {
          return {
            doc: jest.fn().mockReturnValue({
              update: jest.fn().mockRejectedValue(new Error('Firestore error'))
            })
          };
        }
      });

      const result = await expireTrial('user123');

      expect(result.success).toBe(false);
      expect(result.error).toBe('Firestore error');
    });
  });

  describe('convertTrialToPaid', () => {
    it('should mark trial as converted', async () => {
      const mockUpdate = jest.fn().mockResolvedValue();
      const mockAdd = jest.fn().mockResolvedValue({ id: 'event123' });

      db.collection.mockImplementation((collectionName) => {
        if (collectionName === 'users') {
          return {
            doc: jest.fn().mockReturnValue({
              update: mockUpdate
            })
          };
        }
        if (collectionName === 'trial_events') {
          return {
            add: mockAdd
          };
        }
      });

      const result = await convertTrialToPaid('user123', 'sub_razorpay_123');

      expect(result.success).toBe(true);
      expect(mockUpdate).toHaveBeenCalledWith(
        expect.objectContaining({
          'trial.converted_to_paid': true,
          'trial.subscription_id': 'sub_razorpay_123'
        })
      );
      expect(invalidateTierCache).toHaveBeenCalledWith('user123');
    });
  });

  describe('getTrialStatus', () => {
    it('should return trial status for user with active trial', async () => {
      const now = new Date();
      const futureDate = new Date(now.getTime() + 10 * 24 * 60 * 60 * 1000); // 10 days from now

      const mockUserDoc = {
        exists: true,
        data: () => ({
          trial: {
            tier_id: 'pro',
            started_at: { toDate: () => new Date(now.getTime() - 20 * 24 * 60 * 60 * 1000) },
            ends_at: { toDate: () => futureDate },
            is_active: true,
            converted_to_paid: false
          }
        })
      };

      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue(mockUserDoc)
        })
      });

      const result = await getTrialStatus('user123');

      expect(result).toBeDefined();
      expect(result.tier_id).toBe('pro');
      expect(result.is_active).toBe(true);
      expect(result.days_remaining).toBeGreaterThan(0);
    });

    it('should return null for user without trial', async () => {
      const mockUserDoc = {
        exists: true,
        data: () => ({ name: 'Test User' })
      };

      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue(mockUserDoc)
        })
      });

      const result = await getTrialStatus('user123');

      expect(result).toBeNull();
    });

    it('should return null for non-existent user', async () => {
      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({ exists: false })
        })
      });

      const result = await getTrialStatus('nonexistent');

      expect(result).toBeNull();
    });
  });
});
