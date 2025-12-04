/// JEEVibe Text Preprocessing Utility
/// Centralized text preprocessing for consistent handling of:
/// - Word spacing fixes (concatenated words)
/// - LaTeX delimiter validation
/// - Common pattern fixes (Statement I/II, Option(A), etc.)
/// Single source of truth for text normalization across all screens

class TextPreprocessor {
  /// Add spaces between words that are concatenated
  /// Examples:
  /// - "paramagneticwiththree" -> "paramagnetic with three"
  /// - "(A)and(C)only" -> "(A) and (C) only"
  /// - "StatementI" -> "Statement I"
  /// 
  /// IMPORTANT: This function should NOT modify LaTeX content inside delimiters
  static String addSpacesToText(String text) {
    if (text.isEmpty) return text;
    
    // First, check if this is pure LaTeX (wrapped in delimiters) - if so, don't add spaces
    final trimmed = text.trim();
    if (_isPureLaTeX(trimmed)) {
      return text; // Don't modify pure LaTeX
    }
    
    String result = text;
    
    // Protect LaTeX content inside delimiters - extract and restore later
    final latexBlocks = <String>[];
    result = _protectLatexBlocks(result, latexBlocks);
    
    // CRITICAL: Fix common concatenated chemistry/physics terms FIRST
    result = _fixCommonTerms(result);
    
    // Add space before capital letters that follow lowercase letters or numbers
    result = result.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    
    // Add space before numbers that follow letters
    result = result.replaceAllMapped(
      RegExp(r'([a-zA-Z])(\d)'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    
    // Add space after numbers that are followed by letters
    result = result.replaceAllMapped(
      RegExp(r'(\d)([A-Za-z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    
    // Fix common patterns like "StatementI" -> "Statement I", "StatementII" -> "Statement II"
    result = _fixStatementPatterns(result);
    
    // Fix "and" patterns like "(A)and(C)only" -> "(A) and (C) only"
    result = _fixAndPatterns(result);
    
    // Fix "only" patterns like "(C)only" -> "(C) only"
    result = result.replaceAllMapped(
      RegExp(r'(\([A-Z]\))(only)', caseSensitive: false),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    result = result.replaceAllMapped(
      RegExp(r'([\)])(only)', caseSensitive: false),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    
    // Clean up multiple spaces
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    
    // Restore protected LaTeX blocks
    result = _restoreLatexBlocks(result, latexBlocks);
    
    return result.trim();
  }
  
  /// Check if text is pure LaTeX (entirely wrapped in delimiters)
  static bool _isPureLaTeX(String text) {
    return (text.startsWith('\\(') && text.endsWith('\\)')) ||
           (text.startsWith('\\[') && text.endsWith('\\]'));
  }
  
  /// Protect LaTeX blocks by replacing them with placeholders
  static String _protectLatexBlocks(String text, List<String> blocks) {
    String result = text;
    
    // Match \(...\) and \[...\] blocks
    final latexPattern = RegExp(r'\\([\(\)\[\]])(.*?)\\([\(\)\[\]])');
    result = result.replaceAllMapped(latexPattern, (match) {
      final fullMatch = match.group(0)!;
      final placeholder = '___LATEX_BLOCK_${blocks.length}___';
      blocks.add(fullMatch);
      return placeholder;
    });
    
    return result;
  }
  
  /// Restore LaTeX blocks from placeholders
  static String _restoreLatexBlocks(String text, List<String> blocks) {
    String result = text;
    for (int i = 0; i < blocks.length; i++) {
      result = result.replaceAll('___LATEX_BLOCK_${i}___', blocks[i]);
    }
    return result;
  }
  
  /// Fix common concatenated chemistry/physics terms
  static String _fixCommonTerms(String text) {
    String result = text;
    
    // Fix concatenated patterns like "paramagneticwiththreeunpairedelectrons"
    // Strategy: Insert spaces before common words when they appear concatenated
    
    // paramagnetic/diamagnetic + with
    result = result.replaceAllMapped(
      RegExp(r'paramagnetic(with)', caseSensitive: false),
      (match) => 'paramagnetic ${match.group(1)}',
    );
    result = result.replaceAllMapped(
      RegExp(r'diamagnetic(with)', caseSensitive: false),
      (match) => 'diamagnetic ${match.group(1)}',
    );
    
    // with + number words
    result = result.replaceAllMapped(
      RegExp(r'(with)(three|two|four|one|no|zero|five|six|seven|eight|nine|ten)', caseSensitive: false),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    
    // number words + unpaired
    result = result.replaceAllMapped(
      RegExp(r'(three|two|four|one|no|zero|five|six|seven|eight|nine|ten)(unpaired)', caseSensitive: false),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    
    // unpaired + electron
    result = result.replaceAllMapped(
      RegExp(r'(unpaired)(electron)', caseSensitive: false),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    
    // Fix "and" concatenations
    result = result.replaceAllMapped(
      RegExp(r'([a-z])(and)([a-z])', caseSensitive: false),
      (match) => '${match.group(1)} ${match.group(2)} ${match.group(3)}',
    );
    
    return result;
  }
  
  /// Fix Statement patterns
  static String _fixStatementPatterns(String text) {
    String result = text;
    
    // "Statements" or "Statement" followed by (A), (B), etc.
    // Handle: "Statements(A)" -> "Statements (A)"
    result = result.replaceAllMapped(
      RegExp(r'(Statements?)\(([A-Z])\)', caseSensitive: false),
      (match) => '${match.group(1)} (${match.group(2)})',
    );
    
    // "StatementI" -> "Statement I", "StatementII" -> "Statement II"
    result = result.replaceAllMapped(
      RegExp(r'Statement([IVX]+)', caseSensitive: false),
      (match) => 'Statement ${match.group(1)}',
    );
    
    // "Option(A)" -> "Option (A)"
    result = result.replaceAllMapped(
      RegExp(r'Option\(([A-Z])\)', caseSensitive: false),
      (match) => 'Option (${match.group(1)})',
    );
    
    return result;
  }
  
  /// Fix "and" patterns
  static String _fixAndPatterns(String text) {
    String result = text;
    
    // "(A)and(C)" -> "(A) and (C)"
    result = result.replaceAllMapped(
      RegExp(r'(\([A-Z]\))(and)(\([A-Z]\))', caseSensitive: false),
      (match) => '${match.group(1)} ${match.group(2)} ${match.group(3)}',
    );
    
    // ")and(" -> ") and ("
    result = result.replaceAllMapped(
      RegExp(r'([\)])(and)([\(])', caseSensitive: false),
      (match) => '${match.group(1)} ${match.group(2)} ${match.group(3)}',
    );
    
    // "WordandWord" -> "Word and Word"
    result = result.replaceAllMapped(
      RegExp(r'([A-Z][a-z]+)(and)([A-Z])', caseSensitive: false),
      (match) => '${match.group(1)} ${match.group(2)} ${match.group(3)}',
    );
    
    // ")and" or "and(" -> ") and" or "and ("
    result = result.replaceAllMapped(
      RegExp(r'(\))(and)', caseSensitive: false),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    result = result.replaceAllMapped(
      RegExp(r'(and)(\()', caseSensitive: false),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    
    return result;
  }
  
  /// Validate LaTeX delimiters in text
  /// Returns true if delimiters are balanced
  static bool validateLatexDelimiters(String text) {
    if (text.isEmpty) return true;
    
    // Count inline delimiters
    final openInline = '\\('.allMatches(text).length;
    final closeInline = '\\)'.allMatches(text).length;
    
    // Count display delimiters
    final openDisplay = '\\['.allMatches(text).length;
    final closeDisplay = '\\]'.allMatches(text).length;
    
    return openInline == closeInline && openDisplay == closeDisplay;
  }
  
  /// Clean LaTeX delimiters from text (for fallback display)
  /// Removes LaTeX commands and leaves readable text
  static String cleanLatexForFallback(String text) {
    String cleaned = text;
    
    // Remove LaTeX delimiters
    cleaned = cleaned.replaceAll(RegExp(r'\\[\(\[\)\]]'), '');
    
    // Remove \mathrm{} and keep content
    cleaned = cleaned.replaceAll(RegExp(r'\\mathrm\{([^}]+)\}'), r'$1');
    
    // Remove subscripts/superscripts but keep content
    cleaned = cleaned.replaceAll(RegExp(r'[_\^]\{([^}]+)\}'), r'$1');
    
    // Remove standalone LaTeX commands
    cleaned = cleaned.replaceAll(RegExp(r'\\[a-zA-Z]+\{?[^}]*\}?'), '');
    
    // Remove braces
    cleaned = cleaned.replaceAll(RegExp(r'[{}]'), '');
    
    // Clean up whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleaned;
  }
  
  /// Detect if text contains chemical formulas
  /// Heuristic: looks for patterns like H2O, CO2, NH4+, etc.
  static bool containsChemicalFormulas(String text) {
    // Pattern: Capital letter + optional lowercase + digit(s)
    final chemicalPattern = RegExp(r'\b[A-Z][a-z]?\d+\b');
    
    // Pattern: Chemical formulas with charges: NH4+, SO4(2-)
    final chargePattern = RegExp(r'\b[A-Z][a-z]?\d*\s*[+-]\b');
    
    return chemicalPattern.hasMatch(text) || chargePattern.hasMatch(text);
  }
  
  /// Normalize whitespace (remove extra spaces, newlines, etc.)
  static String normalizeWhitespace(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')  // Multiple spaces -> single space
        .replaceAll(RegExp(r'\n+'), ' ')  // Newlines -> space
        .trim();
  }
}

