/// Chemistry Formula Formatter - Converts to Unicode subscripts/superscripts
library;

class ChemistryFormatter {
  // Unicode subscript characters
  static const Map<String, String> _subscripts = {
    '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
    '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
    '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
    'a': 'ₐ', 'e': 'ₑ', 'h': 'ₕ', 'i': 'ᵢ', 'j': 'ⱼ',
    'k': 'ₖ', 'l': 'ₗ', 'm': 'ₘ', 'n': 'ₙ', 'o': 'ₒ',
    'p': 'ₚ', 'r': 'ᵣ', 's': 'ₛ', 't': 'ₜ', 'u': 'ᵤ',
    'v': 'ᵥ', 'x': 'ₓ',
  };

  // Unicode superscript characters
  static const Map<String, String> _superscripts = {
    '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
    '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
    '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
    'n': 'ⁿ', 'i': 'ⁱ',
  };

  /// Converts common chemistry formulas to Unicode format
  /// Examples:
  /// - H2O → H₂O
  /// - CO2 → CO₂
  /// - H2SO4 → H₂SO₄
  /// - Ca2+ → Ca²⁺
  /// - SO4^2- → SO₄²⁻
  static String formatFormula(String formula) {
    if (formula.isEmpty) return formula;

    String result = formula;

    // Pattern 1: Numbers after elements (e.g., H2O, CO2, CH4)
    // Replace numbers that come after uppercase/lowercase letters
    result = result.replaceAllMapped(
      RegExp(r'([A-Za-z])(\d+)'),
      (match) {
        final letter = match.group(1)!;
        final number = match.group(2)!;
        return letter + _toSubscript(number);
      },
    );

    // Pattern 2: Ionic charges with ^ notation (e.g., Ca^2+, SO4^2-)
    // Replace ^number+ or ^number-
    result = result.replaceAllMapped(
      RegExp(r'\^(\d+)([+-])'),
      (match) {
        final number = match.group(1)!;
        final sign = match.group(2)!;
        return _toSuperscript(number) + _toSuperscript(sign);
      },
    );

    // Pattern 3: Ionic charges without ^ (e.g., Ca2+, Fe3+)
    // Only apply if at the end or followed by space/comma
    result = result.replaceAllMapped(
      RegExp(r'([A-Za-z])(\d+)([+-])(?=\s|,|$)'),
      (match) {
        final element = match.group(1)!;
        final number = match.group(2)!;
        final sign = match.group(3)!;
        return element + _toSuperscript(number) + _toSuperscript(sign);
      },
    );

    // Pattern 4: Parentheses with subscripts (e.g., (NH4)2 → (NH₄)₂)
    result = result.replaceAllMapped(
      RegExp(r'\(([^)]+)\)(\d+)'),
      (match) {
        final inside = match.group(1)!;
        final number = match.group(2)!;
        final formattedInside = formatFormula(inside); // Recursive
        return '($formattedInside)${_toSubscript(number)}';
      },
    );

    return result;
  }

  /// Converts a string of digits/symbols to subscripts
  static String _toSubscript(String text) {
    return text.split('').map((char) => _subscripts[char] ?? char).join();
  }

  /// Converts a string of digits/symbols to superscripts
  static String _toSuperscript(String text) {
    return text.split('').map((char) => _superscripts[char] ?? char).join();
  }

  /// Converts subscript Unicode back to normal text (for editing)
  static String fromSubscript(String text) {
    String result = text;
    _subscripts.forEach((normal, unicode) {
      result = result.replaceAll(unicode, normal);
    });
    return result;
  }

  /// Converts superscript Unicode back to normal text (for editing)
  static String fromSuperscript(String text) {
    String result = text;
    _superscripts.forEach((normal, unicode) {
      result = result.replaceAll(unicode, normal);
    });
    return result;
  }

  /// Auto-detect and format chemistry formulas in a text
  /// Useful for processing recognized question text
  static String autoFormatChemistry(String text) {
    // Common chemistry patterns to auto-format
    final patterns = [
      // Water-like molecules
      r'\bH2O\b',
      r'\bCO2\b',
      r'\bO2\b',
      r'\bN2\b',
      r'\bCl2\b',
      r'\bH2\b',
      
      // Acids
      r'\bH2SO4\b',
      r'\bHCl\b',
      r'\bHNO3\b',
      r'\bH3PO4\b',
      r'\bCH3COOH\b',
      
      // Bases
      r'\bNaOH\b',
      r'\bKOH\b',
      r'\bCa\(OH\)2\b',
      r'\bNH4OH\b',
      
      // Salts and compounds
      r'\bNaCl\b',
      r'\bCaCO3\b',
      r'\bNaHCO3\b',
      r'\bCH4\b',
      r'\bC2H5OH\b',
      r'\bC6H12O6\b',
      
      // Ions with charges
      r'\bNa\+\b',
      r'\bK\+\b',
      r'\bCa2\+\b',
      r'\bMg2\+\b',
      r'\bAl3\+\b',
      r'\bCl-\b',
      r'\bSO42-\b',
      r'\bNO3-\b',
      r'\bCO32-\b',
      r'\bPO43-\b',
    ];

    String result = text;
    
    for (final pattern in patterns) {
      result = result.replaceAllMapped(
        RegExp(pattern),
        (match) => formatFormula(match.group(0)!),
      );
    }

    return result;
  }

  /// Check if a string contains chemistry notation
  static bool hasChemistryNotation(String text) {
    // Check for common patterns
    return RegExp(r'[A-Z][a-z]?\d+|[A-Z][a-z]?[2-9]\+|SO4|NO3|CO3|PO4').hasMatch(text);
  }
}

// Example usage:
// ChemistryFormatter.formatFormula('H2O') → 'H₂O'
// ChemistryFormatter.formatFormula('Ca2+') → 'Ca²⁺'
// ChemistryFormatter.formatFormula('H2SO4') → 'H₂SO₄'
// ChemistryFormatter.formatFormula('(NH4)2SO4') → '(NH₄)₂SO₄'
// ChemistryFormatter.autoFormatChemistry('The reaction is H2 + O2 -> H2O') → 'The reaction is H₂ + O₂ -> H₂O'

