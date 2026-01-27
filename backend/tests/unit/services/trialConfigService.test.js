/**
 * Unit tests for Trial Config Service
 * Tests configuration caching and fallback behavior
 */

const {
  getTrialConfig,
  areTrialsEnabled,
  getTrialDurationDays,
  getTrialTierId,
  invalidateCache,
  DEFAULT_TRIAL_CONFIG
} = require('../../../src/services/trialConfigService');

// Mock dependencies
jest.mock('../../../src/config/firebase', () => ({
  db: {
    collection: jest.fn()
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

const { db } = require('../../../src/config/firebase');

describe('TrialConfigService', () => {
  beforeEach(() => {
    // Clear all mocks
    jest.clearAllMocks();
    // Invalidate cache before each test
    invalidateCache();
  });

  describe('getTrialConfig', () => {
    it('should return config from Firestore when document exists', async () => {
      const mockConfig = {
        enabled: true,
        trial_tier_id: 'pro',
        duration_days: 30,
        version: '1.0.0'
      };

      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            exists: true,
            data: () => mockConfig
          })
        })
      });

      const config = await getTrialConfig();

      expect(config).toEqual(mockConfig);
      expect(db.collection).toHaveBeenCalledWith('trial_config');
    });

    it('should return default config when Firestore document does not exist', async () => {
      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            exists: false
          })
        })
      });

      const config = await getTrialConfig();

      expect(config).toEqual(DEFAULT_TRIAL_CONFIG);
    });

    it('should return default config when Firestore throws error', async () => {
      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockRejectedValue(new Error('Firestore error'))
        })
      });

      const config = await getTrialConfig();

      expect(config).toEqual(DEFAULT_TRIAL_CONFIG);
    });

    it('should cache config and not fetch again within TTL', async () => {
      const mockConfig = {
        enabled: true,
        trial_tier_id: 'pro',
        duration_days: 30
      };

      const mockGet = jest.fn().mockResolvedValue({
        exists: true,
        data: () => mockConfig
      });

      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: mockGet
        })
      });

      // First call - should fetch from Firestore
      await getTrialConfig();
      expect(mockGet).toHaveBeenCalledTimes(1);

      // Second call - should use cache
      await getTrialConfig();
      expect(mockGet).toHaveBeenCalledTimes(1); // Still 1, not 2
    });

    it('should invalidate cache when requested', async () => {
      const mockConfig = {
        enabled: true,
        trial_tier_id: 'pro',
        duration_days: 30
      };

      const mockGet = jest.fn().mockResolvedValue({
        exists: true,
        data: () => mockConfig
      });

      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: mockGet
        })
      });

      // First call
      await getTrialConfig();
      expect(mockGet).toHaveBeenCalledTimes(1);

      // Invalidate cache
      invalidateCache();

      // Second call - should fetch again
      await getTrialConfig();
      expect(mockGet).toHaveBeenCalledTimes(2);
    });
  });

  describe('areTrialsEnabled', () => {
    it('should return true when trials are enabled', async () => {
      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            exists: true,
            data: () => ({ enabled: true })
          })
        })
      });

      const enabled = await areTrialsEnabled();
      expect(enabled).toBe(true);
    });

    it('should return false when trials are disabled', async () => {
      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            exists: true,
            data: () => ({ enabled: false })
          })
        })
      });

      const enabled = await areTrialsEnabled();
      expect(enabled).toBe(false);
    });

    it('should return default value when config fetch fails', async () => {
      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockRejectedValue(new Error('Firestore error'))
        })
      });

      const enabled = await areTrialsEnabled();
      expect(enabled).toBe(DEFAULT_TRIAL_CONFIG.enabled);
    });
  });

  describe('getTrialDurationDays', () => {
    it('should return configured duration', async () => {
      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            exists: true,
            data: () => ({ duration_days: 45 })
          })
        })
      });

      const duration = await getTrialDurationDays();
      expect(duration).toBe(45);
    });

    it('should return default duration when not configured', async () => {
      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            exists: true,
            data: () => ({})
          })
        })
      });

      const duration = await getTrialDurationDays();
      expect(duration).toBe(30); // Default value
    });
  });

  describe('getTrialTierId', () => {
    it('should return configured tier ID', async () => {
      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            exists: true,
            data: () => ({ trial_tier_id: 'ultra' })
          })
        })
      });

      const tierId = await getTrialTierId();
      expect(tierId).toBe('ultra');
    });

    it('should return default tier ID when not configured', async () => {
      db.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            exists: true,
            data: () => ({})
          })
        })
      });

      const tierId = await getTrialTierId();
      expect(tierId).toBe('pro'); // Default value
    });
  });
});
