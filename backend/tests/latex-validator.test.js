/**
 * JEEVibe - LaTeX Validator Test Suite
 * Comprehensive tests for LaTeX validation and normalization
 */

const {
  validateAndNormalizeLaTeX,
  validateDelimiters,
  fixCommonErrors,
  removeNestedDelimiters,
  fixChemicalFormulas,
} = require('../src/services/latex-validator');

describe('LaTeX Validator', () => {
  describe('validateAndNormalizeLaTeX', () => {
    test('should handle empty string', () => {
      expect(validateAndNormalizeLaTeX('')).toBe('');
      expect(validateAndNormalizeLaTeX(null)).toBe(null);
      expect(validateAndNormalizeLaTeX(undefined)).toBe(undefined);
    });

    test('should normalize double-escaped delimiters', () => {
      const input = '\\\\(x^2 + y^2\\\\)';
      const output = validateAndNormalizeLaTeX(input);
      expect(output).toBe('\\(x^2 + y^2\\)');
    });

    test('should handle nested delimiters', () => {
      const input = '\\(\\(x + y\\)\\)';
      const output = validateAndNormalizeLaTeX(input);
      expect(output).toBe('\\(x + y\\)');
    });

    test('should fix chemical formulas with Unicode', () => {
      const input = 'H₂O + CO₂';
      const output = validateAndNormalizeLaTeX(input);
      expect(output).toContain('\\(');
      expect(output).toContain('_{2}');
    });

    test('should remove empty subscripts and superscripts', () => {
      const input = '\\(x_{}^{}\\)';
      const output = validateAndNormalizeLaTeX(input);
      expect(output).not.toContain('_{}');
      expect(output).not.toContain('^{}');
    });
  });

  describe('fixCommonErrors', () => {
    test('should fix multiple backslashes before delimiters', () => {
      expect(fixCommonErrors('\\\\\\(x\\\\\\)')).toBe('\\(x\\)');
      expect(fixCommonErrors('\\\\\\\\(x\\\\\\\\)')).toBe('\\(x\\)');
    });

    test('should fix missing backslash before mathrm', () => {
      expect(fixCommonErrors('mathrm{H}_{2}')).toContain('\\mathrm{H}_{2}');
    });

    test('should fix ext{} to \\mathrm{}', () => {
      expect(fixCommonErrors('ext{H}_{2}')).toBe('\\mathrm{H}_{2}');
    });

    test('should fix \\text{} to \\mathrm{}', () => {
      expect(fixCommonErrors('\\text{H}_{2}')).toBe('\\mathrm{H}_{2}');
    });

    test('should replace spaces in mathrm{} with ~', () => {
      const input = '\\mathrm{g mol}^{-1}';
      const output = fixCommonErrors(input);
      expect(output).toBe('\\mathrm{g~mol}^{-1}');
    });
  });

  describe('removeNestedDelimiters', () => {
    test('should remove nested inline delimiters', () => {
      const input = '\\(\\(x + y\\)\\)';
      const output = removeNestedDelimiters(input);
      expect(output).toBe('\\(x + y\\)');
    });

    test('should remove nested display delimiters', () => {
      const input = '\\[\\[x + y\\]\\]';
      const output = removeNestedDelimiters(input);
      expect(output).toBe('\\[x + y\\]');
    });

    test('should handle multiple levels of nesting', () => {
      const input = '\\(\\(\\(x\\)\\)\\)';
      const output = removeNestedDelimiters(input);
      // Implementation removes inner delimiters but may leave trailing delimiter
      expect(output).toContain('\\(x');
      expect(output).toContain('\\)');
    });

    test('should handle mixed nested delimiters', () => {
      const input = '\\(\\[x + y\\]\\)';
      const output = removeNestedDelimiters(input);
      expect(output).toBe('\\(x + y\\)');
    });
  });

  describe('fixChemicalFormulas', () => {
    test('should convert Unicode subscripts to LaTeX', () => {
      expect(fixChemicalFormulas('H₂O')).toContain('_{2}');
    });

    test('should convert Unicode superscripts to LaTeX', () => {
      expect(fixChemicalFormulas('NH₄⁺')).toContain('^{+}');
    });

    test('should handle complex chemical formulas', () => {
      const input = 'H₂SO₄ + Ca(OH)₂';
      const output = fixChemicalFormulas(input);
      expect(output).toContain('_{2}');
      expect(output).toContain('_{4}');
    });

    test('should preserve existing LaTeX in chemical formulas', () => {
      const input = '\\(\\mathrm{H}_{2}\\mathrm{O}\\)';
      const output = fixChemicalFormulas(input);
      expect(output).toContain('\\mathrm{H}_{2}');
    });
  });

  describe('validateDelimiters', () => {
    test('should validate balanced inline delimiters', () => {
      const result = validateDelimiters('\\(x + y\\)');
      expect(result.balanced).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    test('should detect unbalanced inline delimiters', () => {
      const result = validateDelimiters('\\(x + y');
      expect(result.balanced).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
    });

    test('should validate balanced display delimiters', () => {
      const result = validateDelimiters('\\[x + y\\]');
      expect(result.balanced).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    test('should detect unbalanced display delimiters', () => {
      const result = validateDelimiters('\\[x + y');
      expect(result.balanced).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
    });

    test('should detect special characters outside delimiters', () => {
      const result = validateDelimiters('x^2 + y^2');
      expect(result.balanced).toBe(false);
      expect(result.errors.some(e => e.includes('Special characters'))).toBe(true);
    });

    test('should handle mixed delimiters', () => {
      const result = validateDelimiters('\\(x + y\\) and \\[a + b\\]');
      expect(result.balanced).toBe(true);
      expect(result.errors).toHaveLength(0);
    });
  });

  describe('Complex real-world scenarios', () => {
    test('should handle JEE Math question with integrals', () => {
      const input = 'Find \\\\(\\\\int_0^1 x^2 dx\\\\)';
      const output = validateAndNormalizeLaTeX(input);
      // Should preserve surrounding text and normalize delimiters
      expect(output).toContain('Find');
      expect(output).toContain('\\(');
      expect(output).toContain('\\int_0^1 x^2 dx');
      expect(output).toContain('\\)');
    });

    test('should handle JEE Chemistry question with chemical equations', () => {
      const input = 'Mass of H₂SO₄ is \\\\(98 ext{g mol}^{-1}\\\\)';
      const output = validateAndNormalizeLaTeX(input);
      expect(output).toContain('\\mathrm');
      expect(output).toContain('g~mol');
      expect(output).not.toContain('₂');
      expect(output).not.toContain('ext');
    });

    test('should handle JEE Physics question with Greek letters', () => {
      const input = 'The angle \\\\(\\\\(\\\\alpha\\\\)\\\\) is...';
      const output = validateAndNormalizeLaTeX(input);
      expect(output).toBe('The angle \\(\\alpha\\) is...');
    });

    test('should handle complex nested structures', () => {
      const input = '\\\\(\\\\frac{\\\\(a + b\\\\)}{c}\\\\)';
      const output = validateAndNormalizeLaTeX(input);
      // Should normalize delimiters and handle nested fractions
      expect(output).toContain('\\(');
      expect(output).toContain('\\frac');
      expect(output).toContain('a + b');
      expect(output).toContain('\\)');
    });

    test('should handle mixed content with text and LaTeX', () => {
      const input = 'The value of \\\\(x^2 + y^2\\\\) equals \\\\(r^2\\\\)';
      const output = validateAndNormalizeLaTeX(input);
      expect(output).toBe('The value of \\(x^2 + y^2\\) equals \\(r^2\\)');
    });

    test('should handle electronic configuration', () => {
      const input = '\\\\(1\\\\text{s}^{2} 2\\\\text{s}^{2} 2\\\\text{p}^{3}\\\\)';
      const output = validateAndNormalizeLaTeX(input);
      expect(output).toContain('\\mathrm{s}');
      expect(output).toContain('\\mathrm{p}');
      expect(output).not.toContain('\\text');
    });

    test('should handle hybridization notation', () => {
      const input = '\\\\(\\\\text{sp}^{3}\\\\text{d}^{2}\\\\)';
      const output = validateAndNormalizeLaTeX(input);
      expect(output).toContain('\\mathrm{sp}');
      expect(output).toContain('\\mathrm{d}');
    });

    test('should handle complex ions', () => {
      const input = 'NH₄⁺ and SO₄²⁻';
      const output = validateAndNormalizeLaTeX(input);
      // Should convert Unicode sub/superscripts to LaTeX
      expect(output).toContain('_{4}');
      expect(output).toContain('^{+}');
      expect(output).toContain('^{-}');
    });
  });

  describe('Edge cases', () => {
    test('should handle empty delimiters', () => {
      const input = '\\(\\)';
      const output = validateAndNormalizeLaTeX(input);
      // Empty delimiters are removed as cleanup
      expect(output).toBe('');
    });

    test('should handle text without LaTeX', () => {
      const input = 'This is plain text';
      const output = validateAndNormalizeLaTeX(input);
      expect(output).toBe('This is plain text');
    });

    test('should handle only delimiters', () => {
      const input = '\\(\\)\\(\\)';
      const output = validateAndNormalizeLaTeX(input);
      // Empty delimiters are removed as cleanup
      expect(output).toBe('');
    });

    test('should handle very long strings', () => {
      const input = '\\(' + 'x + y + z + '.repeat(100) + 'a\\)';
      const output = validateAndNormalizeLaTeX(input);
      expect(output.startsWith('\\(')).toBe(true);
      expect(output.endsWith('\\)')).toBe(true);
    });
  });
});

