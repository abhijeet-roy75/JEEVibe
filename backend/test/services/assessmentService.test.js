/**
 * Unit tests for Assessment Service
 * Tests the critical backend logic for processing assessments
 */

const { processInitialAssessment, validateAssessmentResponses, groupResponsesByChapter } = require('../../src/services/assessmentService');

describe('AssessmentService', () => {
  describe('validateAssessmentResponses', () => {
    it('should validate correct responses', () => {
      const responses = Array.from({ length: 30 }, (_, i) => ({
        question_id: `q${i}`,
        student_answer: `answer${i}`,
        time_taken_seconds: 60,
      }));

      const result = validateAssessmentResponses(responses);

      expect(result.valid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    it('should reject responses with wrong length', () => {
      const responses = [
        { question_id: 'q1', student_answer: 'a', time_taken_seconds: 60 },
      ];

      const result = validateAssessmentResponses(responses);

      expect(result.valid).toBe(false);
      expect(result.errors).toContain('Expected 30 responses, got 1');
    });

    it('should reject responses with missing question_id', () => {
      const responses = Array.from({ length: 30 }, (_, i) => ({
        student_answer: `answer${i}`,
        time_taken_seconds: 60,
      }));

      const result = validateAssessmentResponses(responses);

      expect(result.valid).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
    });

    it('should reject responses with duplicate question_ids', () => {
      const responses = Array.from({ length: 30 }, (_, i) => ({
        question_id: i < 2 ? 'duplicate' : `q${i}`,
        student_answer: `answer${i}`,
        time_taken_seconds: 60,
      }));

      const result = validateAssessmentResponses(responses);

      expect(result.valid).toBe(false);
      expect(result.errors.some(e => e.includes('Duplicate'))).toBe(true);
    });

    it('should reject responses with missing student_answer', () => {
      const responses = Array.from({ length: 30 }, (_, i) => ({
        question_id: `q${i}`,
        // missing student_answer
        time_taken_seconds: 60,
      }));

      const result = validateAssessmentResponses(responses);

      expect(result.valid).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
    });

    it('should reject non-array responses', () => {
      const result = validateAssessmentResponses({});

      expect(result.valid).toBe(false);
      expect(result.errors).toContain('Responses must be an array');
    });
  });

  describe('groupResponsesByChapter', () => {
    it('should group responses by chapter correctly', () => {
      const responses = [
        { question_id: 'q1', subject: 'physics', chapter: 'mechanics', is_correct: true },
        { question_id: 'q2', subject: 'physics', chapter: 'mechanics', is_correct: false },
        { question_id: 'q3', subject: 'chemistry', chapter: 'organic', is_correct: true },
        { question_id: 'q4', subject: 'mathematics', chapter: 'calculus', is_correct: true },
      ];

      const groups = groupResponsesByChapter(responses);

      expect(Object.keys(groups)).toHaveLength(3);
      expect(groups['physics_mechanics']).toHaveLength(2);
      expect(groups['chemistry_organic']).toHaveLength(1);
      expect(groups['mathematics_calculus']).toHaveLength(1);
    });

    it('should skip responses with missing subject or chapter', () => {
      const responses = [
        { question_id: 'q1', subject: 'physics', chapter: 'mechanics', is_correct: true },
        { question_id: 'q2', subject: null, chapter: 'mechanics', is_correct: false },
        { question_id: 'q3', subject: 'chemistry', chapter: null, is_correct: true },
      ];

      const groups = groupResponsesByChapter(responses);

      expect(Object.keys(groups)).toHaveLength(1);
      expect(groups['physics_mechanics']).toHaveLength(1);
    });

    it('should handle empty responses array', () => {
      const groups = groupResponsesByChapter([]);

      expect(Object.keys(groups)).toHaveLength(0);
    });

    it('should generate valid chapter keys', () => {
      const responses = [
        { question_id: 'q1', subject: 'Physics', chapter: 'Mechanics', is_correct: true },
      ];

      const groups = groupResponsesByChapter(responses);

      // Should be lowercase
      expect(groups['physics_mechanics']).toBeDefined();
    });
  });

  describe('Integration: processInitialAssessment', () => {
    // Note: These are integration tests that require Firebase setup
    // They should be run with proper mocks or in a test environment

    it('should reject invalid input - missing userId', async () => {
      await expect(
        processInitialAssessment(null, [])
      ).rejects.toThrow('Invalid input: userId and enrichedResponses array required');
    });

    it('should reject invalid input - not array', async () => {
      await expect(
        processInitialAssessment('user123', {})
      ).rejects.toThrow('Invalid input: userId and enrichedResponses array required');
    });

    it('should reject invalid input - wrong number of responses', async () => {
      const responses = [{ question_id: 'q1', is_correct: true, subject: 'physics', chapter: 'mechanics' }];

      await expect(
        processInitialAssessment('user123', responses)
      ).rejects.toThrow('Expected 30 responses, got 1');
    });

    it('should reject responses with missing chapter/subject', async () => {
      const responses = Array.from({ length: 30 }, (_, i) => ({
        question_id: `q${i}`,
        student_answer: `answer${i}`,
        correct_answer: `answer${i}`,
        is_correct: true,
        time_taken_seconds: 60,
        // missing subject and chapter
      }));

      await expect(
        processInitialAssessment('user123', responses)
      ).rejects.toThrow();
    });
  });

  describe('Edge Cases', () => {
    it('should handle responses with zero time_taken_seconds', () => {
      const responses = Array.from({ length: 30 }, (_, i) => ({
        question_id: `q${i}`,
        student_answer: `answer${i}`,
        time_taken_seconds: 0, // Zero time
      }));

      const result = validateAssessmentResponses(responses);
      expect(result.valid).toBe(true);
    });

    it('should handle responses with very long time_taken_seconds', () => {
      const responses = Array.from({ length: 30 }, (_, i) => ({
        question_id: `q${i}`,
        student_answer: `answer${i}`,
        time_taken_seconds: 10000, // Very long time
      }));

      const result = validateAssessmentResponses(responses);
      expect(result.valid).toBe(true);
    });

    it('should handle special characters in answers', () => {
      const responses = Array.from({ length: 30 }, (_, i) => ({
        question_id: `q${i}`,
        student_answer: '<script>alert("xss")</script>', // XSS attempt
        time_taken_seconds: 60,
      }));

      const result = validateAssessmentResponses(responses);
      expect(result.valid).toBe(true); // Should accept but sanitize later
    });
  });
});

describe('Assessment Validation Rules', () => {
  describe('Question ID Format', () => {
    it('should accept alphanumeric question IDs', () => {
      const responses = Array.from({ length: 30 }, (_, i) => ({
        question_id: `question_${i}`,
        student_answer: 'answer',
        time_taken_seconds: 60,
      }));

      const result = validateAssessmentResponses(responses);
      expect(result.valid).toBe(true);
    });

    it('should accept UUID-style question IDs', () => {
      const responses = Array.from({ length: 30 }, (_, i) => ({
        question_id: `550e8400-e29b-41d4-a716-44665544000${i}`,
        student_answer: 'answer',
        time_taken_seconds: 60,
      }));

      const result = validateAssessmentResponses(responses);
      expect(result.valid).toBe(true);
    });
  });

  describe('Answer Format', () => {
    it('should accept empty string answers', () => {
      const responses = Array.from({ length: 30 }, (_, i) => ({
        question_id: `q${i}`,
        student_answer: '', // Empty answer
        time_taken_seconds: 60,
      }));

      const result = validateAssessmentResponses(responses);
      expect(result.valid).toBe(true);
    });

    it('should accept numerical answers as strings', () => {
      const responses = Array.from({ length: 30 }, (_, i) => ({
        question_id: `q${i}`,
        student_answer: '42',
        time_taken_seconds: 60,
      }));

      const result = validateAssessmentResponses(responses);
      expect(result.valid).toBe(true);
    });
  });
});
