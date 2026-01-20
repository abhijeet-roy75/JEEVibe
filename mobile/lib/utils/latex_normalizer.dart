/// JEEVibe LaTeX Normalizer
///
/// Fixes common LaTeX issues before rendering:
/// - Incomplete commands
/// - Unbalanced braces
/// - Missing arguments
/// - Chemistry notation conversion
/// - mhchem to standard LaTeX conversion
///
/// This ensures flutter_math_fork receives valid LaTeX

class LaTeXNormalizer {
  /// Normalize LaTeX string for rendering
  /// This should be called on LaTeX content BEFORE passing to flutter_math_fork
  static String normalize(String latex) {
    if (latex.isEmpty) return latex;

    String result = latex;

    // Step 1: Fix truncated commands (e.g., "rac" -> "\frac")
    result = _fixTruncatedCommands(result);

    // Step 2: Balance braces
    result = _balanceBraces(result);

    // Step 3: Fix empty groups
    result = _fixEmptyGroups(result);

    // Step 4: Convert mhchem to standard LaTeX
    result = _convertMhchem(result);

    // Step 5: Fix common typos
    result = _fixCommonTypos(result);

    // Step 6: Remove invalid sequences
    result = _removeInvalidSequences(result);

    return result;
  }

  /// Fix commands that got truncated (likely from faulty preprocessing)
  static String _fixTruncatedCommands(String latex) {
    String result = latex;

    // Map of truncated command -> full command
    final truncatedCommands = {
      // Fractions
      'rac{': '\\frac{',
      'dfrac{': '\\dfrac{',
      'tfrac{': '\\tfrac{',
      // Square roots
      'sqrt{': '\\sqrt{',
      'sqrt[': '\\sqrt[',
      // Text/mathrm
      'mathrm{': '\\mathrm{',
      'mathbf{': '\\mathbf{',
      'mathit{': '\\mathit{',
      'text{': '\\text{',
      'textbf{': '\\textbf{',
      'textit{': '\\textit{',
      // Trig functions
      'sin': '\\sin',
      'cos': '\\cos',
      'tan': '\\tan',
      'cot': '\\cot',
      'sec': '\\sec',
      'csc': '\\csc',
      'arcsin': '\\arcsin',
      'arccos': '\\arccos',
      'arctan': '\\arctan',
      // Log functions
      'log': '\\log',
      'ln': '\\ln',
      'exp': '\\exp',
      // Limits and calculus
      'lim': '\\lim',
      'sum': '\\sum',
      'prod': '\\prod',
      'int': '\\int',
      // Greek letters
      'alpha': '\\alpha',
      'beta': '\\beta',
      'gamma': '\\gamma',
      'delta': '\\delta',
      'epsilon': '\\epsilon',
      'theta': '\\theta',
      'lambda': '\\lambda',
      'mu': '\\mu',
      'pi': '\\pi',
      'sigma': '\\sigma',
      'omega': '\\omega',
      // Operators
      'times': '\\times',
      'div': '\\div',
      'cdot': '\\cdot',
      'pm': '\\pm',
      'mp': '\\mp',
      'infty': '\\infty',
      'partial': '\\partial',
      'nabla': '\\nabla',
      // Comparisons
      'leq': '\\leq',
      'geq': '\\geq',
      'neq': '\\neq',
      'approx': '\\approx',
      'equiv': '\\equiv',
      // Arrows
      'rightarrow': '\\rightarrow',
      'leftarrow': '\\leftarrow',
      'Rightarrow': '\\Rightarrow',
      'Leftarrow': '\\Leftarrow',
      // Vectors
      'vec{': '\\vec{',
      'hat{': '\\hat{',
      'bar{': '\\bar{',
      'overline{': '\\overline{',
    };

    // Only fix if the command appears WITHOUT a preceding backslash
    for (final entry in truncatedCommands.entries) {
      final truncated = entry.key;
      final full = entry.value;

      // Escape special regex characters in the truncated string
      final escapedTruncated = truncated.replaceAllMapped(
        RegExp(r'([\[\]{}().+*?^$|\\])'),
        (m) => '\\${m.group(1)}',
      );

      // Pattern: word boundary or start, then the truncated command
      // But NOT preceded by backslash
      final pattern = RegExp('(?<!\\\\)\\b$escapedTruncated');
      result = result.replaceAll(pattern, full);
    }

    return result;
  }

  /// Balance braces by adding missing closing braces
  static String _balanceBraces(String latex) {
    int openCount = 0;
    int closeCount = 0;

    // Count braces (ignoring escaped ones)
    for (int i = 0; i < latex.length; i++) {
      if (latex[i] == '{') {
        // Check if escaped
        if (i == 0 || latex[i - 1] != '\\') {
          openCount++;
        }
      } else if (latex[i] == '}') {
        if (i == 0 || latex[i - 1] != '\\') {
          closeCount++;
        }
      }
    }

    // Add missing closing braces
    if (openCount > closeCount) {
      return latex + ('}' * (openCount - closeCount));
    }

    // If more closing than opening, that's harder to fix
    // Just remove excess closing braces from the end
    if (closeCount > openCount) {
      String result = latex;
      int excess = closeCount - openCount;
      while (excess > 0 && result.endsWith('}')) {
        result = result.substring(0, result.length - 1);
        excess--;
      }
      return result;
    }

    return latex;
  }

  /// Fix empty groups that cause parser errors
  static String _fixEmptyGroups(String latex) {
    String result = latex;

    // Remove empty subscripts: _{} -> nothing
    result = result.replaceAll(RegExp(r'_\{\s*\}'), '');

    // Remove empty superscripts: ^{} -> nothing
    result = result.replaceAll(RegExp(r'\^\{\s*\}'), '');

    // Fix _{} that have content but look empty due to only spaces
    result = result.replaceAll(RegExp(r'_\{\s+\}'), '');
    result = result.replaceAll(RegExp(r'\^\{\s+\}'), '');

    return result;
  }

  /// Convert mhchem syntax to standard LaTeX
  static String _convertMhchem(String latex) {
    // Pattern: \ce{...}
    final cePattern = RegExp(r'\\ce\{([^}]+)\}');

    return latex.replaceAllMapped(cePattern, (match) {
      final content = match.group(1)!;
      return _convertChemicalFormula(content);
    });
  }

  /// Convert a chemical formula to standard LaTeX
  static String _convertChemicalFormula(String formula) {
    String result = formula;

    // Convert arrows
    result = result.replaceAll('<->', '\\leftrightarrow ');
    result = result.replaceAll('<=>', '\\rightleftharpoons ');
    result = result.replaceAll('->', '\\rightarrow ');
    result = result.replaceAll('<-', '\\leftarrow ');

    // Convert subscripts: H2O -> H_{2}O
    result = result.replaceAllMapped(
      RegExp(r'([A-Za-z])(\d+)'),
      (m) => '${m.group(1)}_{${m.group(2)}}',
    );

    // Convert charges: Fe2+ -> Fe^{2+}
    result = result.replaceAllMapped(
      RegExp(r'(\d*)([+-])(?=\s|$|\)|,)'),
      (m) {
        final num = m.group(1) ?? '';
        final sign = m.group(2)!;
        return '^{$num$sign}';
      },
    );

    // Wrap element symbols in \mathrm{}
    result = result.replaceAllMapped(
      RegExp(r'\b([A-Z][a-z]?)(?=_|\^|\s|$|\)|,)'),
      (m) => '\\mathrm{${m.group(1)}}',
    );

    return result;
  }

  /// Fix common typos in LaTeX
  static String _fixCommonTypos(String latex) {
    String result = latex;

    // ext{} -> \text{} (common OCR error)
    result = result.replaceAll(RegExp(r'\bext\{'), '\\text{');

    // athrm{} -> \mathrm{} (common OCR error)
    result = result.replaceAll(RegExp(r'\bathrm\{'), '\\mathrm{');

    // imes -> \times (common OCR error)
    result = result.replaceAll(RegExp(r'\bimes\b'), '\\times');

    // \\ inside inline math often means someone intended something else
    // But be careful - \\ is valid for line breaks in matrices

    return result;
  }

  /// Remove sequences that will cause parser errors
  static String _removeInvalidSequences(String latex) {
    String result = latex;

    // Remove any remaining delimiter pairs that shouldn't be inside math
    // (the parser already removes outer delimiters, so inner ones are errors)
    result = result.replaceAll(RegExp(r'\\\('), '');
    result = result.replaceAll(RegExp(r'\\\)'), '');
    result = result.replaceAll(RegExp(r'\\\['), '');
    result = result.replaceAll(RegExp(r'\\\]'), '');

    // Remove double backslashes that aren't part of commands
    // (but keep \\ for line breaks)
    // This is tricky - for now, leave \\ alone

    // Remove trailing incomplete commands
    result = result.replaceAll(RegExp(r'\\[a-zA-Z]+\s*$'), '');

    // Clean up multiple spaces
    result = result.replaceAll(RegExp(r'\s+'), ' ');

    return result.trim();
  }

  /// Check if LaTeX is likely to render successfully
  /// Returns true if LaTeX looks valid, false if it needs fallback
  static bool isLikelyValid(String latex) {
    if (latex.isEmpty) return false;

    // Check for unbalanced braces
    int braceCount = 0;
    for (int i = 0; i < latex.length; i++) {
      if (latex[i] == '{' && (i == 0 || latex[i - 1] != '\\')) {
        braceCount++;
      } else if (latex[i] == '}' && (i == 0 || latex[i - 1] != '\\')) {
        braceCount--;
      }
      if (braceCount < 0) return false; // More closing than opening
    }
    if (braceCount != 0) return false; // Unbalanced

    // Check for common invalid patterns
    if (latex.contains('\\\\\\')) return false; // Too many backslashes
    if (latex.contains('{{{}}}')) return false; // Empty nested groups
    if (RegExp(r'\\[a-z]+\{$').hasMatch(latex)) return false; // Incomplete command at end

    return true;
  }
}
