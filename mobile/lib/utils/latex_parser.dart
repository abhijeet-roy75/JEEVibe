/// JEEVibe LaTeX Parser
///
/// A robust, state-machine based LaTeX parser that handles:
/// - Mixed text and LaTeX content
/// - Nested delimiters
/// - Malformed LaTeX gracefully
/// - Multiple delimiter formats ($...$, $$...$$, \(...\), \[...\])
///
/// This replaces the regex-based approach which was fragile and prone to errors.

/// Represents a segment of parsed content
class ParsedSegment {
  final String content;
  final bool isLatex;
  final bool isDisplayMode; // true for display math ($$, \[), false for inline (\(, $)

  const ParsedSegment({
    required this.content,
    required this.isLatex,
    this.isDisplayMode = false,
  });

  @override
  String toString() => 'ParsedSegment(isLatex: $isLatex, display: $isDisplayMode, content: "${content.length > 50 ? content.substring(0, 50) + "..." : content}")';
}

/// State machine based LaTeX parser
class LaTeXParser {
  /// Parse text into segments of plain text and LaTeX
  /// Returns a list of ParsedSegment objects
  static List<ParsedSegment> parse(String input) {
    if (input.isEmpty) return [];

    // First, normalize the input
    String normalized = _normalizeInput(input);

    final segments = <ParsedSegment>[];
    final buffer = StringBuffer();
    int i = 0;

    while (i < normalized.length) {
      // Check for LaTeX delimiters at current position
      final delimiterResult = _checkDelimiter(normalized, i);

      if (delimiterResult != null) {
        // Found a LaTeX block
        // First, add any buffered plain text
        if (buffer.isNotEmpty) {
          segments.add(ParsedSegment(
            content: buffer.toString(),
            isLatex: false,
          ));
          buffer.clear();
        }

        // Add the LaTeX segment
        segments.add(ParsedSegment(
          content: delimiterResult.content,
          isLatex: true,
          isDisplayMode: delimiterResult.isDisplayMode,
        ));

        i = delimiterResult.endIndex;
      } else {
        // Plain text character
        buffer.write(normalized[i]);
        i++;
      }
    }

    // Add any remaining plain text
    if (buffer.isNotEmpty) {
      segments.add(ParsedSegment(
        content: buffer.toString(),
        isLatex: false,
      ));
    }

    // Post-process: merge adjacent text segments
    return _mergeAdjacentTextSegments(segments);
  }

  /// Normalize input by fixing common issues
  static String _normalizeInput(String input) {
    String result = input;

    // Clean up corrupted LATEX_BLOCK placeholders from bad data imports
    // These are placeholders that were never restored - show visual indicator
    // Matches both __LATEX_BLOCK_X__ (2 underscores) and ___LATEX_BLOCK_X___ (3 underscores)
    result = result.replaceAll(
      RegExp(r'_{2,3}LATEX_BLOCK_\d+_{2,3}'),
      '[formula]',
    );

    // Replace newlines with spaces (LaTeX doesn't handle raw newlines)
    result = result.replaceAll('\n', ' ');
    result = result.replaceAll('\r', ' ');

    // Fix double-escaped backslashes that should be single
    // But be careful not to break \\  (line break in LaTeX)
    // Only fix clearly wrong patterns like \\\\frac -> \\frac
    result = result.replaceAll(RegExp(r'\\\\\\\\([a-zA-Z])'), r'\\$1');

    // Normalize consecutive delimiters: \)\( -> just continue LaTeX
    // This merges: \(\mathrm{Cr}\)\(^{2+}\) into \(\mathrm{Cr}^{2+}\)
    result = _mergeConsecutiveLatexBlocks(result);

    return result;
  }

  /// Merge consecutive LaTeX blocks that are adjacent
  /// \(\mathrm{Cr}\)\(^{2+}\) -> \(\mathrm{Cr}^{2+}\)
  static String _mergeConsecutiveLatexBlocks(String input) {
    String result = input;

    // Merge \)\( patterns (inline math)
    // Keep doing this until no more changes (handles multiple consecutive blocks)
    int iterations = 0;
    while (iterations < 20) {
      final before = result;
      // Match: \) followed by optional whitespace followed by \(
      result = result.replaceAll(RegExp(r'\\\)\s*\\\('), ' ');
      if (result == before) break;
      iterations++;
    }

    // Merge \]\[ patterns (display math) - less common but handle it
    iterations = 0;
    while (iterations < 10) {
      final before = result;
      result = result.replaceAll(RegExp(r'\\\]\s*\\\['), ' ');
      if (result == before) break;
      iterations++;
    }

    // Also handle $$ $$ merge
    result = result.replaceAll(RegExp(r'\$\$\s*\$\$'), ' ');

    // Handle $ $ merge for inline
    // Be careful: $a$ $b$ should become $a b$ but $$a$$ should not change
    // Pattern: $ (not preceded by $) followed by non-$ content followed by $ then whitespace then $ (not $$)
    // Use negative lookbehind (?<!\$) to avoid matching inside $$...$$
    iterations = 0;
    while (iterations < 20) {
      final before = result;
      result = result.replaceAllMapped(
        RegExp(r'(?<!\$)\$([^\$]+)\$(\s*)\$(?!\$)'),
        (m) => '\$${m.group(1)} ',
      );
      if (result == before) break;
      iterations++;
    }

    return result;
  }

  /// Check if there's a LaTeX delimiter at the current position
  /// Returns null if no delimiter found, otherwise returns the parsed result
  static _DelimiterResult? _checkDelimiter(String input, int startIndex) {
    // Check for display math delimiters first (longer patterns)

    // Check for $$ (display math)
    if (_startsWith(input, startIndex, '\$\$')) {
      return _extractDisplayDollar(input, startIndex);
    }

    // Check for \[ (display math)
    if (_startsWith(input, startIndex, '\\[')) {
      return _extractBracketMath(input, startIndex, isDisplay: true);
    }

    // Check for \( (inline math)
    if (_startsWith(input, startIndex, '\\(')) {
      return _extractBracketMath(input, startIndex, isDisplay: false);
    }

    // Check for single $ (inline math) - must not be $$
    if (_startsWith(input, startIndex, '\$') && !_startsWith(input, startIndex, '\$\$')) {
      return _extractInlineDollar(input, startIndex);
    }

    return null;
  }

  /// Extract $$...$$ display math
  static _DelimiterResult? _extractDisplayDollar(String input, int startIndex) {
    // Find closing $$
    int searchStart = startIndex + 2;
    int endIndex = input.indexOf('\$\$', searchStart);

    if (endIndex == -1) {
      // No closing delimiter - treat rest as LaTeX (graceful degradation)
      return _DelimiterResult(
        content: input.substring(startIndex + 2),
        endIndex: input.length,
        isDisplayMode: true,
      );
    }

    return _DelimiterResult(
      content: input.substring(startIndex + 2, endIndex),
      endIndex: endIndex + 2,
      isDisplayMode: true,
    );
  }

  /// Extract $...$ inline math
  static _DelimiterResult? _extractInlineDollar(String input, int startIndex) {
    // Find closing $ (but not $$)
    int searchStart = startIndex + 1;

    for (int i = searchStart; i < input.length; i++) {
      if (input[i] == '\$') {
        // Check it's not $$ (part of display math)
        if (i + 1 < input.length && input[i + 1] == '\$') {
          // This is $$, skip
          continue;
        }
        // Found closing $
        return _DelimiterResult(
          content: input.substring(startIndex + 1, i),
          endIndex: i + 1,
          isDisplayMode: false,
        );
      }
      // Skip escaped characters
      if (input[i] == '\\' && i + 1 < input.length) {
        i++; // Skip next char
      }
    }

    // No closing delimiter found - return null to treat as plain text
    return null;
  }

  /// Extract \(...\) or \[...\] math
  static _DelimiterResult? _extractBracketMath(String input, int startIndex, {required bool isDisplay}) {
    final openDelim = isDisplay ? '\\[' : '\\(';
    final closeDelim = isDisplay ? '\\]' : '\\)';

    int searchStart = startIndex + 2;
    int depth = 1; // Track nested delimiters

    for (int i = searchStart; i < input.length - 1; i++) {
      // Check for closing delimiter
      if (input.substring(i, i + 2) == closeDelim) {
        depth--;
        if (depth == 0) {
          return _DelimiterResult(
            content: input.substring(startIndex + 2, i),
            endIndex: i + 2,
            isDisplayMode: isDisplay,
          );
        }
      }
      // Check for nested opening delimiter
      if (input.substring(i, i + 2) == openDelim) {
        depth++;
      }
      // Skip escaped characters
      if (input[i] == '\\') {
        // Check if it's a delimiter or just a command
        if (i + 1 < input.length) {
          final next = input[i + 1];
          if (next != '(' && next != ')' && next != '[' && next != ']') {
            // It's a LaTeX command, continue normally
          }
        }
      }
    }

    // No closing delimiter - treat rest as LaTeX (graceful degradation)
    return _DelimiterResult(
      content: input.substring(startIndex + 2),
      endIndex: input.length,
      isDisplayMode: isDisplay,
    );
  }

  /// Helper to check if string starts with pattern at index
  static bool _startsWith(String input, int index, String pattern) {
    if (index + pattern.length > input.length) return false;
    return input.substring(index, index + pattern.length) == pattern;
  }

  /// Merge adjacent text segments
  static List<ParsedSegment> _mergeAdjacentTextSegments(List<ParsedSegment> segments) {
    if (segments.length <= 1) return segments;

    final merged = <ParsedSegment>[];
    ParsedSegment? pendingText;

    for (final segment in segments) {
      if (!segment.isLatex) {
        // Text segment
        if (pendingText != null) {
          // Merge with previous text
          pendingText = ParsedSegment(
            content: pendingText.content + segment.content,
            isLatex: false,
          );
        } else {
          pendingText = segment;
        }
      } else {
        // LaTeX segment
        if (pendingText != null) {
          merged.add(pendingText);
          pendingText = null;
        }
        merged.add(segment);
      }
    }

    // Don't forget pending text
    if (pendingText != null) {
      merged.add(pendingText);
    }

    return merged;
  }

  /// Check if text contains any LaTeX that needs processing
  static bool containsLatex(String text) {
    // Check for delimiters
    if (text.contains('\$') ||
        text.contains('\\(') ||
        text.contains('\\[')) {
      return true;
    }

    // Check for common LaTeX commands
    if (text.contains('\\frac') ||
        text.contains('\\mathrm') ||
        text.contains('\\sqrt') ||
        text.contains('\\sum') ||
        text.contains('\\int') ||
        text.contains('\\alpha') ||
        text.contains('\\beta') ||
        text.contains('\\theta') ||
        text.contains('\\lambda') ||
        text.contains('\\times') ||
        text.contains('\\div') ||
        text.contains('\\equiv') ||
        text.contains('\\infty') ||
        text.contains('\\cup') ||
        text.contains('\\cap') ||
        text.contains('\\gamma') ||
        text.contains('\\delta') ||
        text.contains('\\Delta') ||  // uppercase Delta
        text.contains('\\omega') ||
        text.contains('\\Omega') ||  // uppercase Omega
        text.contains('\\pi') ||
        text.contains('\\sigma') ||
        text.contains('\\mu') ||
        text.contains('\\vec') ||
        text.contains('\\hat') ||
        text.contains('\\cos') ||
        text.contains('\\sin') ||
        text.contains('\\tan') ||
        text.contains('\\log') ||
        text.contains('\\lim') ||
        text.contains('\\left') ||
        text.contains('\\right') ||
        text.contains('\\to') ||  // arrow
        text.contains('\\rightarrow') ||
        text.contains('\\leftarrow') ||
        text.contains('\\Rightarrow') ||
        text.contains('\\rightleftharpoons') ||  // equilibrium
        text.contains('\\xrightarrow') ||  // reaction arrow
        text.contains('\\geq') ||  // >=
        text.contains('\\leq') ||  // <=
        text.contains('\\neq') ||  // !=
        text.contains('\\%') ||  // escaped percent
        text.contains('\\cdot') ||
        text.contains('\\ldots') ||  // ellipsis
        text.contains('\\dots') ||
        text.contains('\\gcd') ||  // greatest common divisor
        text.contains('\\{') ||  // escaped braces
        text.contains('\\}') ||
        text.contains('\\ce')) {  // mhchem chemistry notation
      return true;
    }

    // Check for braced subscripts/superscripts: _{...} or ^{...}
    if (text.contains('_{') || text.contains('^{')) {
      return true;
    }

    // Check for simple subscripts: _n where n is alphanumeric (common in chemistry/physics)
    // e.g., H_2O, x_1, PF_5
    if (RegExp(r'_[a-zA-Z0-9]').hasMatch(text)) {
      return true;
    }

    // Check for simple superscripts: ^n where n is alphanumeric
    // e.g., x^2, e^x, sp^3
    if (RegExp(r'\^[a-zA-Z0-9]').hasMatch(text)) {
      return true;
    }

    return false;
  }

  /// Quick check if entire text is pure LaTeX (no mixed content)
  static bool isPureLatex(String text) {
    final trimmed = text.trim();
    return (trimmed.startsWith('\$\$') && trimmed.endsWith('\$\$')) ||
           (trimmed.startsWith('\$') && trimmed.endsWith('\$') &&
            !trimmed.startsWith('\$\$')) ||
           (trimmed.startsWith('\\(') && trimmed.endsWith('\\)')) ||
           (trimmed.startsWith('\\[') && trimmed.endsWith('\\]'));
  }
}

/// Result of delimiter extraction
class _DelimiterResult {
  final String content;
  final int endIndex;
  final bool isDisplayMode;

  _DelimiterResult({
    required this.content,
    required this.endIndex,
    required this.isDisplayMode,
  });
}
