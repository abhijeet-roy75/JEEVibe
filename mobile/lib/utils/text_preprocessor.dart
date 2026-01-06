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

    // First, protect delimited LaTeX blocks: \(...\) and \[...\]
    final latexPattern = RegExp(r'\\([\(\)\[\]])(.*?)\\([\(\)\[\]])');
    result = result.replaceAllMapped(latexPattern, (match) {
      final fullMatch = match.group(0)!;
      final placeholder = '___LATEX_BLOCK_${blocks.length}___';
      blocks.add(fullMatch);
      return placeholder;
    });

    // Also protect individual LaTeX commands with arguments (like \sqrt{3}, \frac{a}{b})
    // Match: \command{...} including nested braces
    final commandPattern = RegExp(r'\\[a-zA-Z]+\{[^}]*\}');
    result = result.replaceAllMapped(commandPattern, (match) {
      final fullMatch = match.group(0)!;
      final placeholder = '___LATEX_BLOCK_${blocks.length}___';
      blocks.add(fullMatch);
      return placeholder;
    });

    // Protect LaTeX subscripts and superscripts: _{\alpha}, ^{2}
    final scriptPattern = RegExp(r'[_^]\{[^}]*\}');
    result = result.replaceAllMapped(scriptPattern, (match) {
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
    
    // Fix "and" concatenations ONLY in specific contexts
    // Match patterns like "paramagneticwiththree" where "and" appears after common suffixes
    // or before common prefixes, but NOT in the middle of normal words like "understanding"
    // This is intentionally removed as it was breaking words like "understanding"
    // The more specific patterns in _fixAndPatterns() handle the actual concatenation cases
    
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
    
    // "WordandWord" -> "Word and Word" (only when both sides start with capital)
    // This pattern is safe because it only matches cases like "PhysicsandChemistry"
    // and won't match normal words like "understanding"
    result = result.replaceAllMapped(
      RegExp(r'([A-Z][a-z]+)(and)([A-Z])'),
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
    cleaned = cleaned.replaceAll(RegExp(r'[_\^]\{?([^}\s]+)\}?'), r'$1');
    
    // Convert LaTeX commands to plain text (e.g., \tan -> tan)
    cleaned = cleaned.replaceAllMapped(RegExp(r'\\([a-zA-Z]+)'), (match) {
      final cmd = match.group(1)!;
      // Keep common math function names
      const keep = {'sin', 'cos', 'tan', 'cot', 'sec', 'csc', 'log', 'ln', 'exp', 'theta', 'alpha', 'beta', 'pi'};
      if (keep.contains(cmd.toLowerCase())) return cmd;
      return ''; // Strip unknown commands
    });
    
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
  
  /// Preprocess step content specifically
  /// Handles common issues in step descriptions like concatenated words
  static String preprocessStepContent(String stepText) {
    if (stepText.isEmpty) return stepText;
    
    String result = stepText;
    
    // Fix "Step1:", "Step2:", etc. -> "Step 1:", "Step 2:"
    result = result.replaceAllMapped(
      RegExp(r'Step(\d+):', caseSensitive: false),
      (match) => 'Step ${match.group(1)}:',
    );
    
    // Fix missing space after colon: "Title:Description" -> "Title: Description"
    result = result.replaceAllMapped(
      RegExp(r':([A-Z])'),
      (match) => ': ${match.group(1)}',
    );
    
    // Fix chemistry compound names that are concatenated
    // Pattern: "3,3-dimethylhex" -> "3,3-dimethyl hex"
    // Add space before "hex", "but", "pent", "prop", "meth", "eth"
    final hydrocarbon = ['hex', 'hept', 'oct', 'non', 'dec', 'but', 'pent', 'prop', 'meth', 'eth'];
    for (final prefix in hydrocarbon) {
      // Match when prefix follows another word without space
      result = result.replaceAllMapped(
        RegExp('([a-z])($prefix)', caseSensitive: false),
        (match) {
          final before = match.group(1)!;
          final compound = match.group(2)!;
          // Don't add space if it's part of a word like "method"
          if (compound == 'meth' && result.contains('${match.group(0)}od')) {
            return match.group(0)!;
          }
          return '$before $compound';
        },
      );
    }
    
    // Fix concatenated chemistry terms
    // "ynecarbon" -> "yne carbon", "enethere" -> "ene there"
    result = result.replaceAllMapped(
      RegExp(r'(yne|ene|ane)(carbon|there|are|is|have|has)', caseSensitive: false),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    
    // Apply general spacing fixes
    result = addSpacesToText(result);
    
    // Normalize whitespace
    result = normalizeWhitespace(result);
    
    return result;
  }
  
  /// Extract clean title from step content (for step card titles)
  /// Removes LaTeX and extracts meaningful title
  static String extractStepTitle(String stepContent, {int maxLength = 40}) {
    if (stepContent.isEmpty) return stepContent;
    
    String cleaned = stepContent;
    
    // Remove LaTeX delimiters and content for title
    cleaned = cleaned.replaceAll(RegExp(r'\\\(.*?\\\)'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\\\[.*?\\\]'), ' ');
    
    // Remove LaTeX commands
    cleaned = cleaned.replaceAll(RegExp(r'\\[a-zA-Z]+\{?[^}]*\}?'), '');
    
    // Check if step starts with "Step N:" pattern
    final stepPattern = RegExp(r'^Step\s+\d+[:\-]\s*(.+?)(?:\.|,|$)', caseSensitive: false);
    final match = stepPattern.firstMatch(cleaned);
    if (match != null && match.group(1) != null) {
      String title = match.group(1)!.trim();
      // Limit length
      if (title.length > maxLength) {
        title = '${title.substring(0, maxLength - 3)}...';
      }
      return title;
    }
    
    // Check for colon-based title: "Title: description"
    final colonIndex = cleaned.indexOf(':');
    if (colonIndex > 0 && colonIndex < 50) {
      String title = cleaned.substring(0, colonIndex).trim();
      // Remove "Step N" prefix if present
      title = title.replaceAll(RegExp(r'^Step\s+\d+', caseSensitive: false), '').trim();
      if (title.isNotEmpty && title.length <= maxLength) {
        return title;
      }
    }
    
    // Fallback: use first few words
    final words = cleaned.split(RegExp(r'\s+'));
    if (words.isNotEmpty) {
      String title = '';
      for (int i = 0; i < words.length && i < 5 && title.length < maxLength; i++) {
        if (title.isNotEmpty) title += ' ';
        title += words[i];
      }
      if (title.length > maxLength) {
        title = '${title.substring(0, maxLength - 3)}...';
      }
      return title.trim();
    }
    
    return stepContent.substring(0, maxLength.clamp(0, stepContent.length));
  }
}

