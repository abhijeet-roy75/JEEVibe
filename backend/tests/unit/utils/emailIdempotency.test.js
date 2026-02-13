/**
 * Tests for Email Idempotency Utility
 * Created: 2026-02-13
 */

const {
  checkEmailSent,
  markEmailSent,
  clearEmailSent,
  generateIdempotencyKey,
  EMAIL_SENT_TTL
} = require('../../../src/utils/emailIdempotency');

// Mock cache
jest.mock('../../../src/utils/cache', () => ({
  get: jest.fn(),
  set: jest.fn(),
  del: jest.fn()
}));

const cache = require('../../../src/utils/cache');

describe('Email Idempotency', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('checkEmailSent()', () => {
    it('should return true if email was sent', async () => {
      const idempotencyKey = 'welcome:user123';
      cache.get.mockReturnValue('2026-02-13T10:00:00.000Z');

      const result = await checkEmailSent(idempotencyKey);

      expect(result).toBe(true);
      expect(cache.get).toHaveBeenCalledWith(`email:sent:${idempotencyKey}`);
    });

    it('should return false if email was not sent', async () => {
      const idempotencyKey = 'welcome:user123';
      cache.get.mockReturnValue(null);

      const result = await checkEmailSent(idempotencyKey);

      expect(result).toBe(false);
      expect(cache.get).toHaveBeenCalledWith(`email:sent:${idempotencyKey}`);
    });

    it('should return false on error (fail-safe)', async () => {
      const idempotencyKey = 'welcome:user123';
      cache.get.mockImplementation(() => {
        throw new Error('Cache error');
      });

      const result = await checkEmailSent(idempotencyKey);

      expect(result).toBe(false);
    });
  });

  describe('markEmailSent()', () => {
    it('should mark email as sent with default TTL', async () => {
      const idempotencyKey = 'welcome:user123';

      await markEmailSent(idempotencyKey);

      expect(cache.set).toHaveBeenCalledWith(
        `email:sent:${idempotencyKey}`,
        expect.any(String), // ISO timestamp
        EMAIL_SENT_TTL
      );
    });

    it('should mark email as sent with custom TTL', async () => {
      const idempotencyKey = 'welcome:user123';
      const customTTL = 3600; // 1 hour

      await markEmailSent(idempotencyKey, customTTL);

      expect(cache.set).toHaveBeenCalledWith(
        `email:sent:${idempotencyKey}`,
        expect.any(String),
        customTTL
      );
    });

    it('should not throw on error', async () => {
      const idempotencyKey = 'welcome:user123';
      cache.set.mockImplementation(() => {
        throw new Error('Cache error');
      });

      await expect(markEmailSent(idempotencyKey)).resolves.not.toThrow();
    });
  });

  describe('clearEmailSent()', () => {
    it('should clear email sent status', async () => {
      const idempotencyKey = 'welcome:user123';

      await clearEmailSent(idempotencyKey);

      expect(cache.del).toHaveBeenCalledWith(`email:sent:${idempotencyKey}`);
    });

    it('should not throw on error', async () => {
      const idempotencyKey = 'welcome:user123';
      cache.del.mockImplementation(() => {
        throw new Error('Cache error');
      });

      await expect(clearEmailSent(idempotencyKey)).resolves.not.toThrow();
    });
  });

  describe('generateIdempotencyKey()', () => {
    it('should generate key without suffix', () => {
      const key = generateIdempotencyKey('welcome', 'user123');

      expect(key).toBe('welcome:user123');
    });

    it('should generate key with suffix', () => {
      const key = generateIdempotencyKey('daily_progress', 'user123', '2026-02-13');

      expect(key).toBe('daily_progress:user123:2026-02-13');
    });
  });

  describe('Integration: Prevent duplicate sends', () => {
    it('should prevent duplicate email on retry', async () => {
      const idempotencyKey = 'welcome:user123';

      // First check - not sent
      cache.get.mockReturnValueOnce(null);
      expect(await checkEmailSent(idempotencyKey)).toBe(false);

      // Mark as sent
      await markEmailSent(idempotencyKey);
      expect(cache.set).toHaveBeenCalled();

      // Second check - already sent
      cache.get.mockReturnValueOnce('2026-02-13T10:00:00.000Z');
      expect(await checkEmailSent(idempotencyKey)).toBe(true);
    });
  });
});
