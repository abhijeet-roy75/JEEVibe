/**
 * Tests for Chapter Key Formatter Utility
 * Created: 2026-02-13
 */

const {
  formatChapterKey,
  chapterKeyToDisplayName,
  extractSubjectFromChapterKey,
  normalizeSubjectName,
  isValidChapterKey
} = require('../../../src/utils/chapterKeyFormatter');

describe('Chapter Key Formatter', () => {
  describe('formatChapterKey()', () => {
    it('should format basic chapter keys correctly', () => {
      expect(formatChapterKey('Physics', 'Laws of Motion')).toBe('physics_laws_of_motion');
      expect(formatChapterKey('Chemistry', 'Chemical Bonding')).toBe('physics_chemical_bonding');
      expect(formatChapterKey('Mathematics', 'Complex Numbers')).toBe('mathematics_complex_numbers');
    });

    it('should normalize subject variations', () => {
      expect(formatChapterKey('Math', 'Algebra')).toBe('mathematics_algebra');
      expect(formatChapterKey('Maths', 'Algebra')).toBe('mathematics_algebra');
    });

    it('should remove special characters from chapter names', () => {
      expect(formatChapterKey('Physics', 'Law\'s of Motion')).toBe('physics_laws_of_motion');
      expect(formatChapterKey('Chemistry', 'S-Block Elements')).toBe('chemistry_s_block_elements');
    });

    it('should apply chapter name normalizations', () => {
      expect(formatChapterKey('Physics', 'Law of Motion')).toBe('physics_laws_of_motion');
      expect(formatChapterKey('Physics', 'Newton Law')).toBe('physics_laws_of_motion');
      expect(formatChapterKey('Chemistry', 'Atomic Structure')).toBe('chemistry_structure_of_atom');
    });

    it('should handle lowercase inputs', () => {
      expect(formatChapterKey('physics', 'laws of motion')).toBe('physics_laws_of_motion');
    });

    it('should handle extra whitespace', () => {
      expect(formatChapterKey('  Physics  ', '  Laws  of   Motion  ')).toBe('physics_laws_of_motion');
    });

    it('should handle subject already in key format', () => {
      // Should extract subject portion
      expect(formatChapterKey('physics_laws_of_motion', 'Kinematics')).toBe('physics_kinematics');
    });
  });

  describe('chapterKeyToDisplayName()', () => {
    it('should convert chapter key to display name', () => {
      expect(chapterKeyToDisplayName('physics_laws_of_motion')).toBe('Laws Of Motion');
      expect(chapterKeyToDisplayName('chemistry_chemical_bonding')).toBe('Chemical Bonding');
      expect(chapterKeyToDisplayName('mathematics_complex_numbers')).toBe('Complex Numbers');
    });

    it('should remove subject prefix', () => {
      expect(chapterKeyToDisplayName('physics_laws_of_motion')).toBe('Laws Of Motion');
      expect(chapterKeyToDisplayName('maths_algebra')).toBe('Algebra');
    });

    it('should capitalize words correctly', () => {
      expect(chapterKeyToDisplayName('physics_shm')).toBe('Shm');
      expect(chapterKeyToDisplayName('mathematics_3d_geometry')).toBe('3d Geometry');
    });
  });

  describe('extractSubjectFromChapterKey()', () => {
    it('should extract subject from valid chapter keys', () => {
      expect(extractSubjectFromChapterKey('physics_laws_of_motion')).toBe('physics');
      expect(extractSubjectFromChapterKey('chemistry_chemical_bonding')).toBe('chemistry');
      expect(extractSubjectFromChapterKey('mathematics_complex_numbers')).toBe('mathematics');
    });

    it('should return "unknown" for invalid keys', () => {
      expect(extractSubjectFromChapterKey('invalid_key')).toBe('unknown');
      expect(extractSubjectFromChapterKey('biology_genetics')).toBe('unknown');
    });
  });

  describe('normalizeSubjectName()', () => {
    it('should normalize subject names', () => {
      expect(normalizeSubjectName('Math')).toBe('mathematics');
      expect(normalizeSubjectName('Maths')).toBe('mathematics');
      expect(normalizeSubjectName('Physics')).toBe('physics');
      expect(normalizeSubjectName('Chemistry')).toBe('chemistry');
    });

    it('should handle case insensitivity', () => {
      expect(normalizeSubjectName('MATH')).toBe('mathematics');
      expect(normalizeSubjectName('physics')).toBe('physics');
    });

    it('should return original for unknown subjects', () => {
      expect(normalizeSubjectName('Biology')).toBe('Biology');
    });
  });

  describe('isValidChapterKey()', () => {
    it('should validate correct chapter keys', () => {
      expect(isValidChapterKey('physics_laws_of_motion')).toBe(true);
      expect(isValidChapterKey('chemistry_chemical_bonding')).toBe(true);
      expect(isValidChapterKey('mathematics_complex_numbers')).toBe(true);
    });

    it('should reject invalid chapter keys', () => {
      expect(isValidChapterKey('invalid')).toBe(false);
      expect(isValidChapterKey('biology_genetics')).toBe(false);
      expect(isValidChapterKey('')).toBe(false);
      expect(isValidChapterKey(null)).toBe(false);
      expect(isValidChapterKey(undefined)).toBe(false);
    });

    it('should reject keys without underscore', () => {
      expect(isValidChapterKey('physics')).toBe(false);
    });
  });
});
