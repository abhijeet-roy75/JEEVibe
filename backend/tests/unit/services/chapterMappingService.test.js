/**
 * Chapter Mapping Service Tests
 *
 * Tests the chapter key to display name mapping service.
 * Ensures that chapter keys are used exactly as they appear in the database
 * (e.g., chemistry_p_block_elements, not chemistry_pblock_elements).
 */

// Create mock Firestore
const mockGet = jest.fn();
const mockSelect = jest.fn(() => mockFirestore);
const mockWhere = jest.fn(() => mockFirestore);
const mockCollection = jest.fn(() => mockFirestore);

const mockFirestore = {
  collection: mockCollection,
  where: mockWhere,
  select: mockSelect,
  get: mockGet,
};

// Mock Firebase Admin
jest.mock('firebase-admin', () => ({
  firestore: jest.fn(() => mockFirestore),
  apps: [],
  app: jest.fn(),
}));

// Mock the Firebase config
jest.mock('../../../src/config/firebase', () => ({
  initializeFirebase: jest.fn(),
  db: mockFirestore,
}));

const { initializeMappings, getDatabaseNames } = require('../../../src/services/chapterMappingService');

describe('Chapter Mapping Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();

    // Reset cache by requiring fresh module
    jest.resetModules();
  });

  describe('initializeMappings', () => {
    it('should fetch chapter mappings from questions collection', async () => {
      const mockQuestions = [
        {
          data: () => ({
            subject: 'Physics',
            chapter: 'Laws of Motion',
            chapter_key: 'physics_laws_of_motion'
          })
        },
        {
          data: () => ({
            subject: 'Chemistry',
            chapter: 'p-Block Elements',
            chapter_key: 'chemistry_p_block_elements' // With hyphen
          })
        },
        {
          data: () => ({
            subject: 'Mathematics',
            chapter: 'Conic Sections (Parabola)',
            chapter_key: 'mathematics_conic_sections_parabola'
          })
        }
      ];

      mockGet.mockResolvedValue({
        size: mockQuestions.length,
        forEach: (callback) => mockQuestions.forEach(callback)
      });

      const { initializeMappings } = require('../../../src/services/chapterMappingService');
      const mappings = await initializeMappings();

      // Should have called Firestore with correct query
      expect(mockCollection).toHaveBeenCalledWith('questions');
      expect(mockWhere).toHaveBeenCalledWith('active', '==', true);
      expect(mockSelect).toHaveBeenCalledWith('subject', 'chapter', 'chapter_key');

      // Should return mappings
      expect(mappings).toBeInstanceOf(Map);
      expect(mappings.size).toBe(3);

      // Should preserve exact chapter_key from database
      expect(mappings.get('physics_laws_of_motion')).toEqual({
        subject: 'Physics',
        chapter: 'Laws of Motion'
      });

      expect(mappings.get('chemistry_p_block_elements')).toEqual({
        subject: 'Chemistry',
        chapter: 'p-Block Elements'
      });
    });

    it('should use actual chapter_key from database, not regenerate it', async () => {
      const mockQuestions = [
        {
          data: () => ({
            subject: 'Chemistry',
            chapter: 'p-Block Elements',
            chapter_key: 'chemistry_p_block_elements' // Correct key
          })
        }
      ];

      mockGet.mockResolvedValue({
        size: 1,
        forEach: (callback) => mockQuestions.forEach(callback)
      });

      const { initializeMappings } = require('../../../src/services/chapterMappingService');
      const mappings = await initializeMappings();

      // The bug we fixed: service was generating 'chemistry_pblock_elements'
      // Now it should use the actual key from database: 'chemistry_p_block_elements'
      expect(mappings.has('chemistry_p_block_elements')).toBe(true);
      expect(mappings.has('chemistry_pblock_elements')).toBe(false);
    });

    it('should skip questions without required fields', async () => {
      const mockQuestions = [
        {
          data: () => ({
            subject: 'Physics',
            chapter: 'Kinematics',
            chapter_key: 'physics_kinematics'
          })
        },
        {
          data: () => ({
            subject: 'Chemistry',
            // Missing chapter
            chapter_key: 'chemistry_unknown'
          })
        },
        {
          data: () => ({
            // Missing subject
            chapter: 'Unknown',
            chapter_key: 'unknown_chapter'
          })
        },
        {
          data: () => ({
            subject: 'Mathematics',
            chapter: 'Algebra',
            // Missing chapter_key
          })
        }
      ];

      mockGet.mockResolvedValue({
        size: 4,
        forEach: (callback) => mockQuestions.forEach(callback)
      });

      const { initializeMappings } = require('../../../src/services/chapterMappingService');
      const mappings = await initializeMappings();

      // Should only include the valid question
      expect(mappings.size).toBe(1);
      expect(mappings.has('physics_kinematics')).toBe(true);
    });

    it('should not create duplicate entries for same chapter_key', async () => {
      const mockQuestions = [
        {
          data: () => ({
            subject: 'Physics',
            chapter: 'Laws of Motion',
            chapter_key: 'physics_laws_of_motion'
          })
        },
        {
          data: () => ({
            subject: 'Physics',
            chapter: 'Laws of Motion',
            chapter_key: 'physics_laws_of_motion'
          })
        },
        {
          data: () => ({
            subject: 'Physics',
            chapter: 'Laws of Motion',
            chapter_key: 'physics_laws_of_motion'
          })
        }
      ];

      mockGet.mockResolvedValue({
        size: 3,
        forEach: (callback) => mockQuestions.forEach(callback)
      });

      const { initializeMappings } = require('../../../src/services/chapterMappingService');
      const mappings = await initializeMappings();

      // Should only have one entry
      expect(mappings.size).toBe(1);
      expect(mappings.get('physics_laws_of_motion')).toEqual({
        subject: 'Physics',
        chapter: 'Laws of Motion'
      });
    });

    it('should cache mappings and not refetch within TTL', async () => {
      const mockQuestions = [
        {
          data: () => ({
            subject: 'Physics',
            chapter: 'Kinematics',
            chapter_key: 'physics_kinematics'
          })
        }
      ];

      mockGet.mockResolvedValue({
        size: 1,
        forEach: (callback) => mockQuestions.forEach(callback)
      });

      const { initializeMappings } = require('../../../src/services/chapterMappingService');

      // First call
      await initializeMappings();
      expect(mockGet).toHaveBeenCalledTimes(1);

      // Second call (should use cache)
      await initializeMappings();
      expect(mockGet).toHaveBeenCalledTimes(1); // Still 1, not 2
    });
  });

  describe('getDatabaseNames', () => {
    it('should return mapping for valid chapter key', async () => {
      const mockQuestions = [
        {
          data: () => ({
            subject: 'Physics',
            chapter: 'Laws of Motion',
            chapter_key: 'physics_laws_of_motion'
          })
        }
      ];

      mockGet.mockResolvedValue({
        size: 1,
        forEach: (callback) => mockQuestions.forEach(callback)
      });

      const { getDatabaseNames } = require('../../../src/services/chapterMappingService');
      const result = await getDatabaseNames('physics_laws_of_motion');

      expect(result).toEqual({
        subject: 'Physics',
        chapter: 'Laws of Motion'
      });
    });

    it('should return null for invalid chapter key', async () => {
      mockGet.mockResolvedValue({
        size: 0,
        forEach: () => {}
      });

      const { getDatabaseNames } = require('../../../src/services/chapterMappingService');
      const result = await getDatabaseNames('invalid_chapter_key');

      expect(result).toBeNull();
    });

    it('should handle chemistry p-block chapter correctly', async () => {
      const mockQuestions = [
        {
          data: () => ({
            subject: 'Chemistry',
            chapter: 'p-Block Elements',
            chapter_key: 'chemistry_p_block_elements'
          })
        }
      ];

      mockGet.mockResolvedValue({
        size: 1,
        forEach: (callback) => mockQuestions.forEach(callback)
      });

      const { getDatabaseNames } = require('../../../src/services/chapterMappingService');

      // Should work with correct key
      const result = await getDatabaseNames('chemistry_p_block_elements');
      expect(result).toEqual({
        subject: 'Chemistry',
        chapter: 'p-Block Elements'
      });

      // Should NOT work with incorrect key (the bug we fixed)
      const badResult = await getDatabaseNames('chemistry_pblock_elements');
      expect(badResult).toBeNull();
    });
  });

  describe('Error handling', () => {
    it('should throw error when database query fails', async () => {
      mockGet.mockRejectedValue(new Error('Database connection failed'));

      const { initializeMappings } = require('../../../src/services/chapterMappingService');

      await expect(initializeMappings()).rejects.toThrow('Database connection failed');
    });
  });
});
