import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Widget to render LaTeX text with proper math rendering
/// 
/// This widget expects text with LaTeX wrapped in \(...\) for inline math
/// or \[...\] for display math. All mathematical and chemical notation
/// MUST be explicitly wrapped in these delimiters.
/// 
/// Chemical equations should use mhchem syntax: \ce{H2O -> H+ + OH-}
/// Note: flutter_math_fork may not fully support mhchem, so we use
/// \mathrm{} as a fallback for chemical formulas.
class LaTeXWidget extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  final FontWeight? latexWeight; // Optional custom weight for LaTeX content

  const LaTeXWidget({
    super.key,
    required this.text,
    this.textStyle,
    this.latexWeight, // Defaults to FontWeight.w600 if not specified
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    // Parse text and render LaTeX blocks
    return _parseAndRender(text, textStyle ?? const TextStyle(fontSize: 14));
  }

  Widget _parseAndRender(String input, TextStyle style) {
    // 1. Preprocessing - handle newlines and problematic characters
    // Preserve all spaces - don't remove them
    String processedInput = input;
    
    // Remove or escape newlines that could break LaTeX parsing
    // Replace actual newline characters with spaces (LaTeX doesn't handle raw newlines well)
    processedInput = processedInput.replaceAll('\n', ' ');
    processedInput = processedInput.replaceAll('\r', ' ');
    // Handle escaped newlines
    processedInput = processedInput.replaceAll(r'\n', ' ');
    processedInput = processedInput.replaceAll(r'\\n', ' ');
    
    // Remove other problematic control characters that LaTeX might interpret
    processedInput = processedInput.replaceAll(RegExp(r'\\[a-zA-Z]+\s*$'), ''); // Remove trailing LaTeX commands without arguments
    
    // 2. Convert dollar sign delimiters to \( \) format for consistency
    // Support both $...$ (inline) and $$...$$ (display) syntax
    try {
      processedInput = _convertDollarDelimiters(processedInput);
    } catch (e) {
      debugPrint('Error converting dollar delimiters: $e');
      // Continue with original input if conversion fails
    }
    
    // 3. Clean nested LaTeX delimiters (remove inner delimiters if outer ones exist)
    // This prevents "Can't use function '\(' in math mode" errors
    // Note: _cleanNestedDelimiters is now a no-op, nested delimiters are handled in _removeNestedDelimiters
    processedInput = _cleanNestedDelimiters(processedInput);
    
    // 4. Simple delimiter detection (use escaped backslashes, not raw strings)
    final hasInlineLaTeX = processedInput.contains('\\(');
    final hasDisplayLaTeX = processedInput.contains('\\[');
    
    // 5. No LaTeX? Return plain text (Unicode symbols will render natively)
    // This is optimal for simple symbols like H₂O, 90°, π per guidelines
    if (!hasInlineLaTeX && !hasDisplayLaTeX) {
      return Text(processedInput, style: style);
    }
    
    // 6. Check if entire text is pure LaTeX (wrapped in delimiters)
    final trimmed = processedInput.trim();
    if (trimmed.startsWith('\\(') && trimmed.endsWith('\\)')) {
      // Pure inline LaTeX - extract content and remove any nested delimiters
      String content = trimmed.substring(2, trimmed.length - 2);
      content = _removeNestedDelimiters(content);
      return _renderPureLaTeX(content, style, true);
    } else if (trimmed.startsWith('\\[') && trimmed.endsWith('\\]')) {
      // Pure display LaTeX - extract content and remove any nested delimiters
      String content = trimmed.substring(2, trimmed.length - 2);
      content = _removeNestedDelimiters(content);
      return _renderPureLaTeX(content, style, false);
    }
    
    // 7. Mixed content - parse and render inline spans
    return _renderMixedContent(processedInput, style);
  }
  
  /// Convert dollar sign delimiters ($...$ and $$...$$) to \( \) and \[ \] format
  /// Also fixes common typos like ext{} -> \mathrm{}
  String _convertDollarDelimiters(String input) {
    try {
      String converted = input;
      
      // Fix common typos: ext{} -> \mathrm{}
      converted = converted.replaceAll(RegExp(r'\bext\{([^}]+)\}'), r'\\mathrm{$1}');
      
      // Convert $$...$$ (display math) to \[...\]
      // Use a more robust pattern that handles nested content
      // Match $$...$$ but not $$$...$$$ (which would be invalid anyway)
      converted = converted.replaceAllMapped(
        RegExp(r'\$\$([^$]+?)\$\$'),
        (match) {
          if (match.groupCount >= 1 && match.group(1) != null) {
            return '\\[' + match.group(1)! + '\\]';
          }
          return match.group(0)!;
        },
      );
      
      // Convert $...$ (inline math) to \(...\)
      // Be careful not to match $$...$$, so we check for non-$ before and after
      // Pattern: $ not preceded by $, then content (non-greedy), then $ not followed by $
      // Also handle cases where $ might be at start/end of string
      converted = converted.replaceAllMapped(
        RegExp(r'(?<!\$)\$([^$\n]+?)\$(?!\$)'),
        (match) {
          if (match.groupCount >= 1 && match.group(1) != null) {
            String content = match.group(1)!.trim();
            if (content.isNotEmpty) {
              return '\\(' + content + '\\)';
            }
          }
          return match.group(0)!; // Return original if empty or invalid
        },
      );
      
      return converted;
    } catch (e) {
      debugPrint('Error in _convertDollarDelimiters: $e');
      return input; // Return original on error
    }
  }
  
  /// Clean nested LaTeX delimiters to prevent parser errors
  String _cleanNestedDelimiters(String input) {
    // This function is called before delimiter conversion, so we don't need to handle
    // nested delimiters here. The _removeNestedDelimiters function handles that after
    // conversion. This function can be simplified or removed, but keeping it for now
    // to avoid breaking changes.
    return input;
  }
  
  /// Remove nested LaTeX delimiters from content (for pure LaTeX mode)
  /// This removes ALL \( \) and \[ \] pairs from the content since Math.tex() doesn't need them
  String _removeNestedDelimiters(String content) {
    // Remove any nested \( \) or \[ \] from the content
    // Math.tex() expects raw LaTeX without delimiters
    String cleaned = content;
    // Remove all \( \) pairs (can be nested, so do it multiple times)
    int iterations = 0;
    while (cleaned.contains('\\(') && cleaned.contains('\\)') && iterations < 10) {
      cleaned = cleaned.replaceAll(RegExp(r'\\\(([^)]*)\\\)'), r'$1');
      iterations++;
    }
    // Remove all \[ \] pairs (can be nested, so do it multiple times)
    iterations = 0;
    while (cleaned.contains('\\[') && cleaned.contains('\\]') && iterations < 10) {
      cleaned = cleaned.replaceAll(RegExp(r'\\\[([^\]]*)\\\]'), r'$1');
      iterations++;
    }
    return cleaned;
  }

  Widget _renderPureLaTeX(String latex, TextStyle style, bool isInline) {
    try {
      // Remove any remaining nested delimiters
      String cleanedLatex = _removeNestedDelimiters(latex);
      
      // Remove problematic characters that break LaTeX parsing
      // Remove newlines and other control characters FIRST
      cleanedLatex = cleanedLatex.replaceAll('\n', ' ');
      cleanedLatex = cleanedLatex.replaceAll('\r', ' ');
      cleanedLatex = cleanedLatex.replaceAll('\t', ' ');
      
      // Remove undefined control sequences that might cause errors
      // This includes things like \n, \t, etc. that aren't valid LaTeX
      // Pattern: \ followed by a single letter that's not part of a valid LaTeX command
      cleanedLatex = cleanedLatex.replaceAll(RegExp(r'\\([ntrbfv])(?![a-zA-Z])'), ' '); // Replace \n, \t, \r, etc. with space (but not if followed by letter)
      
      // Remove any standalone backslashes that aren't part of commands
      cleanedLatex = cleanedLatex.replaceAll(RegExp(r'\\(?![a-zA-Z\(\)\[\]])'), '');
      
      // Preprocess mhchem syntax: \ce{...} -> convert to \mathrm{} format
      // Since flutter_math_fork may not support mhchem, we convert it
      String processedLatex = _processMhchemSyntax(cleanedLatex);
      
      // Validate LaTeX - remove empty groups that cause parser errors
      processedLatex = processedLatex.replaceAll(RegExp(r'_\{\}'), '');
      processedLatex = processedLatex.replaceAll(RegExp(r'\^\{\}'), '');
      
      // Remove any stray LaTeX delimiters that might have been missed
      // Math.tex() doesn't need delimiters, so remove all of them
      processedLatex = processedLatex.replaceAll(RegExp(r'\\\(|\\\)|\\\[|\\\]'), '');
      
      // Final cleanup: remove any remaining problematic patterns
      processedLatex = processedLatex.trim();
      
      // If after cleaning, we have nothing or just whitespace, return plain text
      if (processedLatex.isEmpty || processedLatex.trim().isEmpty) {
        return _renderFallbackText(latex, style);
      }
      
      // Apply bold formatting to LaTeX content (FontWeight.w600 by default)
      final boldStyle = style.copyWith(
        fontWeight: latexWeight ?? FontWeight.w600,
      );
      
      // Wrap in FittedBox to scale down if too wide, preventing overflow
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: double.infinity,
          ),
          child: Math.tex(
            processedLatex,
            mathStyle: isInline ? MathStyle.text : MathStyle.display,
            textStyle: boldStyle,
          ),
        ),
      );
    } catch (e) {
      debugPrint('LaTeX parsing error: $e for: $latex');
      // Never show "Parser Error" to users - always fallback to cleaned text
      return _renderFallbackText(latex, style);
    }
  }
  
  /// Render fallback text when LaTeX parsing fails
  /// This ensures users never see "Parser Error" messages
  Widget _renderFallbackText(String originalLatex, TextStyle style) {
    final boldStyle = style.copyWith(
      fontWeight: latexWeight ?? FontWeight.w600,
    );
    
    // Aggressive cleaning to make text readable
    String displayText = originalLatex
        .replaceAll('\n', ' ') // Remove newlines
        .replaceAll('\r', ' ') // Remove carriage returns
        .replaceAll('\t', ' ') // Remove tabs
        .replaceAll(RegExp(r'\\n'), ' ') // Remove escaped newlines
        .replaceAll(RegExp(r'\\([ntrbfv])(?![a-zA-Z])'), ' ') // Remove control sequences like \n, \t
        .replaceAll(RegExp(r'\\mathrm\{([^}]+)\}'), r'$1') // Remove \mathrm{}
        .replaceAll(RegExp(r'\\[()\[\]]'), '') // Remove LaTeX delimiters
        .replaceAll(RegExp(r'_{([^}]+)}'), r'$1') // Simplify subscripts
        .replaceAll(RegExp(r'\^{([^}]+)}'), r'$1') // Simplify superscripts
        .replaceAll(RegExp(r'\\[a-zA-Z]+\{?[^}]*\}?'), '') // Remove LaTeX commands with optional braces
        .replaceAll(RegExp(r'[{}]'), '') // Remove braces
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
    
    // If displayText is empty or just whitespace, show a cleaned version of original
    if (displayText.isEmpty || displayText.trim().isEmpty) {
      displayText = originalLatex
          .replaceAll(RegExp(r'\\[()\[\]]'), '')
          .replaceAll(RegExp(r'\\[a-zA-Z]+'), '')
          .replaceAll(RegExp(r'[{}]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
    
    // Final check - if still empty, show a generic message
    if (displayText.isEmpty || displayText.trim().isEmpty) {
      return const SizedBox.shrink(); // Don't show anything if we can't extract readable text
    }
    
    return Text(displayText, style: boldStyle);
  }

  /// Process mhchem syntax (\ce{...}) and convert to \mathrm{} format
  /// This converts mhchem commands to LaTeX that flutter_math_fork can render
  /// Examples:
  /// - \ce{H2O} -> \mathrm{H}_{2}\mathrm{O}
  /// - \ce{H+} -> \mathrm{H}^{+}
  /// - \ce{H2O -> H+ + OH-} -> \mathrm{H}_{2}\mathrm{O} \rightarrow \mathrm{H}^{+} + \mathrm{OH}^{-}
  String _processMhchemSyntax(String latex) {
    // Pattern to match \ce{...} blocks
    final cePattern = RegExp(r'\\ce\{([^}]+)\}');
    
    return latex.replaceAllMapped(cePattern, (match) {
      final content = match.group(1)!;
      
      // Split by arrows first to handle reactions
      final arrowPattern = RegExp(r'\s*(<=>|<=|=>|->|<-)\s*');
      final parts = content.split(arrowPattern);
      final arrows = arrowPattern.allMatches(content).map((m) => m.group(1)!).toList();
      
      final convertedParts = <String>[];
      for (int i = 0; i < parts.length; i++) {
        final part = parts[i].trim();
        if (part.isEmpty) continue;
        
        // Check if this part is an arrow
        if (i > 0 && (i - 1) < arrows.length) {
          final arrow = arrows[i - 1];
          String arrowLatex;
          switch (arrow) {
            case '<=>':
              arrowLatex = r'\rightleftharpoons';
              break;
            case '<=':
            case '<-':
              arrowLatex = r'\leftarrow';
              break;
            case '=>':
              arrowLatex = r'\Rightarrow';
              break;
            case '->':
            default:
              arrowLatex = r'\rightarrow';
          }
          convertedParts.add(arrowLatex);
        }
        
        // Convert chemical formula part
        if (part.isNotEmpty) {
          String formula = part;
          
          // Handle charges: 2+, 3-, +, -
          formula = formula.replaceAllMapped(
            RegExp(r'(\d+)([+-])(?=\s|$|,|\))'),
            (m) => '^{${m.group(1)}${m.group(2)}}',
          );
          formula = formula.replaceAllMapped(
            RegExp(r'(?<!\d)([+-])(?=\s|$|,|\))'),
            (m) => '^{${m.group(1)}}',
          );
          
          // Handle subscripts: numbers after letters
          formula = formula.replaceAllMapped(
            RegExp(r'([A-Za-z]+)(\d+)'),
            (m) {
              final letters = m.group(1)!;
              final number = m.group(2)!;
              // Split multi-letter elements and add subscript to last letter
              if (letters.length > 1) {
                return letters.substring(0, letters.length - 1) + 
                       '${letters[letters.length - 1]}_{$number}';
              }
              return '${letters}_{$number}';
            },
          );
          
          // Handle parentheses with subscripts: (NH4)2
          formula = formula.replaceAllMapped(
            RegExp(r'\)(\d+)'),
            (m) => ')_{${m.group(1)}}',
          );
          
          // Wrap in \mathrm{}
          convertedParts.add(r'\mathrm{' + formula + '}');
        }
      }
      
      return convertedParts.join(' ');
    });
  }

  Widget _renderMixedContent(String input, TextStyle style) {
    final spans = <InlineSpan>[];
    int lastIndex = 0;
    
    // Find all \(...\) and \[...\] blocks
    final inlinePattern = RegExp(r'\\\((.+?)\\\)');
    final displayPattern = RegExp(r'\\\[(.+?)\\\]');
    
    // Combine and sort all matches by position
    final allMatches = <_Match>[];
    
    for (final match in inlinePattern.allMatches(input)) {
      allMatches.add(_Match(match.start, match.end, match.group(1)!, true));
    }
    
    for (final match in displayPattern.allMatches(input)) {
      allMatches.add(_Match(match.start, match.end, match.group(1)!, false));
    }
    
    // Sort by start position
    allMatches.sort((a, b) => a.start.compareTo(b.start));
    
    // Build spans
    for (final match in allMatches) {
      // Add text before LaTeX
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: input.substring(lastIndex, match.start),
          style: style,
        ));
      }
      
      // Add LaTeX widget with bold formatting
      try {
        // Clean up problematic characters first
        String processedContent = match.content;
        processedContent = processedContent.replaceAll('\n', ' ');
        processedContent = processedContent.replaceAll('\r', ' ');
        processedContent = processedContent.replaceAll(RegExp(r'\\n'), ' ');
        processedContent = processedContent.replaceAll(RegExp(r'\\([ntrbfv])'), ' '); // Replace \n, \t, etc.
        
        // Preprocess mhchem syntax before rendering
        processedContent = _processMhchemSyntax(processedContent);
        
        // Validate LaTeX - remove empty groups that cause parser errors
        processedContent = processedContent.replaceAll(RegExp(r'_\{\}'), '');
        processedContent = processedContent.replaceAll(RegExp(r'\^\{\}'), '');
        
        // Apply bold formatting to LaTeX content (FontWeight.w600 by default)
        final boldStyle = style.copyWith(
          fontWeight: latexWeight ?? FontWeight.w600,
        );
        
        // Wrap Math widget to handle overflow - use FittedBox to scale down
        final mathWidget = FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400), // Prevent extreme overflow
            child: Math.tex(
              processedContent,
              mathStyle: match.isInline ? MathStyle.text : MathStyle.display,
              textStyle: boldStyle,
            ),
          ),
        );
        
        spans.add(WidgetSpan(
          child: mathWidget,
          alignment: PlaceholderAlignment.middle,
        ));
      } catch (e) {
        debugPrint('LaTeX parsing error: $e for: ${match.content}');
        // Fallback: show content as plain text (not red, just normal)
        // Clean up LaTeX commands for better readability
        String displayText = match.content
            .replaceAll('\n', ' ') // Remove newlines
            .replaceAll('\r', ' ') // Remove carriage returns
            .replaceAll(RegExp(r'\\n'), ' ') // Remove escaped newlines
            .replaceAll(RegExp(r'\\([ntrbfv])'), ' ') // Remove control sequences
            .replaceAll(RegExp(r'\\mathrm\{([^}]+)\}'), r'$1') // Remove \mathrm{}
            .replaceAll(RegExp(r'\\[()\[\]]'), '') // Remove LaTeX delimiters
            .replaceAll(RegExp(r'_{([^}]+)}'), r'$1') // Simplify subscripts
            .replaceAll(RegExp(r'\^{([^}]+)}'), r'$1') // Simplify superscripts
            .replaceAll(RegExp(r'\\[a-zA-Z]+'), ''); // Remove other LaTeX commands
        
        final boldStyle = style.copyWith(
          fontWeight: latexWeight ?? FontWeight.w600,
        );
        spans.add(TextSpan(
          text: displayText.isEmpty ? match.content : displayText,
          style: boldStyle,
        ));
      }
      
      lastIndex = match.end;
    }
    
    // Add remaining text
    if (lastIndex < input.length) {
      spans.add(TextSpan(
        text: input.substring(lastIndex),
        style: style,
      ));
    }
    
    // If no LaTeX was found (shouldn't happen), return plain text
    if (spans.isEmpty) {
      return Text(input, style: style);
    }
    
    return RichText(
      text: TextSpan(children: spans),
      softWrap: true,
      overflow: TextOverflow.clip,
      textAlign: TextAlign.left,
    );
  }
}

class _Match {
  final int start;
  final int end;
  final String content;
  final bool isInline;
  
  _Match(this.start, this.end, this.content, this.isInline);
}
