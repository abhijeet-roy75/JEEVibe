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
    // 1. Minimal preprocessing - only handle newlines
    String processedInput = input
        .replaceAll(r'\n', '\n')        // Literal \n → newline
        .replaceAll(r'\\n', '\n');      // Escaped \n → newline
    
    // 2. Simple delimiter detection (use escaped backslashes, not raw strings)
    final hasInlineLaTeX = processedInput.contains('\\(');
    final hasDisplayLaTeX = processedInput.contains('\\[');
    
    // 3. No LaTeX? Return plain text (Unicode symbols will render natively)
    // This is optimal for simple symbols like H₂O, 90°, π per guidelines
    if (!hasInlineLaTeX && !hasDisplayLaTeX) {
      return Text(processedInput, style: style);
    }
    
    // 4. Check if entire text is pure LaTeX (wrapped in delimiters)
    final trimmed = processedInput.trim();
    if (trimmed.startsWith('\\(') && trimmed.endsWith('\\)')) {
      // Pure inline LaTeX
      return _renderPureLaTeX(trimmed.substring(2, trimmed.length - 2), style, true);
    } else if (trimmed.startsWith('\\[') && trimmed.endsWith('\\]')) {
      // Pure display LaTeX
      return _renderPureLaTeX(trimmed.substring(2, trimmed.length - 2), style, false);
    }
    
    // 5. Mixed content - parse and render inline spans
    return _renderMixedContent(processedInput, style);
  }

  Widget _renderPureLaTeX(String latex, TextStyle style, bool isInline) {
    try {
      // Preprocess mhchem syntax: \ce{...} -> convert to \mathrm{} format
      // Since flutter_math_fork may not support mhchem, we convert it
      String processedLatex = _processMhchemSyntax(latex);
      
      // Validate LaTeX - remove empty groups that cause parser errors
      processedLatex = processedLatex.replaceAll(RegExp(r'_\{\}'), '');
      processedLatex = processedLatex.replaceAll(RegExp(r'\^\{\}'), '');
      
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
      // Fallback: show original content as plain text (not red, just normal)
      // This way users can still read the content even if LaTeX fails
      final boldStyle = style.copyWith(
        fontWeight: latexWeight ?? FontWeight.w600,
      );
      // Clean up LaTeX commands for display
      String displayText = latex
          .replaceAll(RegExp(r'\\mathrm\{([^}]+)\}'), r'$1') // Remove \mathrm{}
          .replaceAll(RegExp(r'\\[()\[\]]'), '') // Remove LaTeX delimiters
          .replaceAll(RegExp(r'_{([^}]+)}'), r'$1') // Simplify subscripts
          .replaceAll(RegExp(r'\^{([^}]+)}'), r'$1'); // Simplify superscripts
      return Text(displayText.isEmpty ? latex : displayText, style: boldStyle);
    }
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
        // Preprocess mhchem syntax before rendering
        String processedContent = _processMhchemSyntax(match.content);
        
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
            .replaceAll(RegExp(r'\\mathrm\{([^}]+)\}'), r'$1') // Remove \mathrm{}
            .replaceAll(RegExp(r'\\[()\[\]]'), '') // Remove LaTeX delimiters
            .replaceAll(RegExp(r'_{([^}]+)}'), r'$1') // Simplify subscripts
            .replaceAll(RegExp(r'\^{([^}]+)}'), r'$1'); // Simplify superscripts
        
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
      overflow: TextOverflow.visible,
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
