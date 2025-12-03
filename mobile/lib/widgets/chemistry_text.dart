import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'latex_widget.dart';

/// Specialized widget for chemistry formulas
/// Handles H₂O, CO₂, chemical equations, etc. with proper LaTeX rendering
/// and bold formatting for visual emphasis
class ChemistryText extends StatelessWidget {
  final String formula;
  final TextStyle? textStyle;
  final double fontSize;
  final FontWeight? latexWeight; // Optional custom weight for chemistry formulas

  const ChemistryText(
    this.formula, {
    Key? key,
    this.textStyle,
    this.fontSize = 16,
    this.latexWeight, // Defaults to FontWeight.w600 if not specified
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final style = textStyle ??
        TextStyle(fontSize: fontSize, color: Colors.black87);

    // Make chemistry formulas semi-bold (stands out)
    final boldStyle = style.copyWith(
      fontWeight: latexWeight ?? FontWeight.w600,
    );

    // If formula is empty, return empty widget
    if (formula.isEmpty) {
      return const SizedBox.shrink();
    }

    // Check if this is mixed content (text + LaTeX) - if so, use LaTeXWidget instead
    final trimmed = formula.trim();
    final hasInlineLaTeX = trimmed.contains('\\(') || trimmed.contains('\\[');
    final hasLaTeXCommands = trimmed.contains(r'\mathrm') || trimmed.contains(r'_{') || trimmed.contains(r'^{');
    final isMixedContent = hasInlineLaTeX || (hasLaTeXCommands && trimmed.length > 100); // Long text with LaTeX = mixed
    
    // If it's mixed content, delegate to LaTeXWidget for proper handling
    if (isMixedContent) {
      try {
        return LaTeXWidget(
          text: formula,
          textStyle: textStyle,
          latexWeight: latexWeight,
        );
      } catch (e) {
        debugPrint('Error in LaTeXWidget for chemistry: $e');
        // Fallback to plain text if LaTeXWidget fails
        return Text(
          formula,
          style: textStyle,
        );
      }
    }

    // Check if formula already has LaTeX delimiters
    final hasDelimiters = (trimmed.startsWith('\\(') && trimmed.endsWith('\\)')) ||
                          (trimmed.startsWith('\\[') && trimmed.endsWith('\\]'));

    try {
      String processedFormula;
      
      if (hasDelimiters) {
        // Extract content from delimiters
        String content = trimmed;
        if (content.startsWith('\\(') && content.endsWith('\\)')) {
          content = content.substring(2, content.length - 2);
        } else if (content.startsWith('\\[') && content.endsWith('\\]')) {
          content = content.substring(2, content.length - 2);
        }
        // Remove any nested delimiters that might cause parser errors
        content = _removeNestedDelimiters(content);
        // Clean up common chemistry LaTeX patterns
        processedFormula = _preprocessChemistry(content);
      } else {
        // No delimiters - wrap in LaTeX delimiters and preprocess
        processedFormula = _preprocessChemistry(formula);
        // Wrap in inline LaTeX delimiters
        processedFormula = '\\(' + processedFormula + '\\)';
      }

      // Validate that we don't have empty subscripts/superscripts
      processedFormula = processedFormula.replaceAll(RegExp(r'_\{\}'), '');
      processedFormula = processedFormula.replaceAll(RegExp(r'\^\{\}'), '');
      // Remove any stray delimiters that might have been introduced
      // Math.tex() doesn't need delimiters, so remove all of them
      processedFormula = processedFormula.replaceAll(RegExp(r'\\\(|\\\)|\\\[|\\\]'), '');
      // Remove any stray delimiters that might have been introduced
      processedFormula = processedFormula.replaceAll(RegExp(r'\\[\(\[\)\]]'), '');

      // Wrap in FittedBox to scale down if too wide, preventing overflow
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: double.infinity,
          ),
          child: Math.tex(
            processedFormula,
            textStyle: boldStyle, // Bold for chemistry
            mathStyle: MathStyle.text,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Chemistry LaTeX parsing error: $e for: $formula');
      // Fallback: Show original text with Unicode conversion
      try {
        return Text(
          _convertToUnicode(formula),
          style: boldStyle, // Bold fallback too
        );
      } catch (e2) {
        // Ultimate fallback: show original text
        debugPrint('Unicode conversion also failed: $e2');
        return Text(
          formula,
          style: boldStyle,
        );
      }
    }
  }

  /// Preprocess chemistry formulas for better rendering
  String _preprocessChemistry(String formula) {
    String processed = formula.trim();

    // Remove existing LaTeX delimiters if present (we'll add them back)
    // Use multiple replaceAll calls to avoid regex character class issues
    processed = processed.replaceFirst(RegExp(r'^\\\('), ''); // Remove \( at start
    processed = processed.replaceFirst(RegExp(r'^\\\['), ''); // Remove \[ at start
    processed = processed.replaceFirst(RegExp(r'\\\)\s*$'), ''); // Remove \) at end
    processed = processed.replaceFirst(RegExp(r'\\\]\s*$'), ''); // Remove \] at end
    processed = processed.trim();

    // If already has LaTeX commands, return as-is (but validate)
    if (processed.contains(r'\mathrm') || processed.contains(r'_{') || processed.contains(r'^{')) {
      // Validate and fix empty groups
      processed = processed.replaceAll(RegExp(r'_\{\}'), '');
      processed = processed.replaceAll(RegExp(r'\^\{\}'), '');
      return processed;
    }

    // Ensure \mathrm is used for chemical elements
    // Pattern: Element followed by optional subscript/superscript
    // Be careful not to match numbers that are already in subscripts
    processed = processed.replaceAllMapped(
      RegExp(r'([A-Z][a-z]?)(?<!\\mathrm\{)(\d+)(?![_^])'),
      (match) {
        String element = match.group(1)!;
        String number = match.group(2)!;
        return r'\mathrm{' + element + r'}_{' + number + r'}';
      },
    );
    
    // Handle elements without subscripts
    processed = processed.replaceAllMapped(
      RegExp(r'(?<!\\mathrm\{)([A-Z][a-z]?)(?![_^{}\d])'),
      (match) {
        String element = match.group(1)!;
        return r'\mathrm{' + element + r'}';
      },
    );

    // Handle charges: +, -, 2+, 3-, etc.
    processed = processed.replaceAllMapped(
      RegExp(r'(\d+)([+-])(?=\s|$|,|\))'),
      (match) => '^{${match.group(1)}${match.group(2)}}',
    );
    processed = processed.replaceAllMapped(
      RegExp(r'(?<!\d)([+-])(?=\s|$|,|\))'),
      (match) => '^{${match.group(1)}}',
    );

    // Handle parentheses with subscripts: (NH4)2
    processed = processed.replaceAllMapped(
      RegExp(r'\)(\d+)'),
      (match) => ')_{${match.group(1)}}',
    );

    return processed;
  }

  /// Convert to Unicode subscripts/superscripts as fallback
  String _convertToUnicode(String formula) {
    String result = formula;

    // Remove LaTeX commands
    result = result
        .replaceAll(r'\mathrm{', '')
        .replaceAll(r'}', '')
        .replaceAll(r'\(', '')
        .replaceAll(r'\)', '');

    // Subscripts
    const subscripts = {
      '0': '₀',
      '1': '₁',
      '2': '₂',
      '3': '₃',
      '4': '₄',
      '5': '₅',
      '6': '₆',
      '7': '₇',
      '8': '₈',
      '9': '₉',
    };

    // Superscripts
    const superscripts = {
      '0': '⁰',
      '1': '¹',
      '2': '²',
      '3': '³',
      '4': '⁴',
      '5': '⁵',
      '6': '⁶',
      '7': '⁷',
      '8': '⁸',
      '9': '⁹',
      '+': '⁺',
      '-': '⁻',
    };

    // Simple pattern: element followed by digit becomes subscript
    result = result.replaceAllMapped(
      RegExp(r'([A-Z][a-z]?)_?(\d+)'),
      (match) {
        String element = match.group(1)!;
        String number = match.group(2)!;
        String converted = number
            .split('')
            .map((d) => subscripts[d] ?? d)
            .join();
        return element + converted;
      },
    );

    // Handle charges
    result = result.replaceAllMapped(
      RegExp(r'\^(\d+)([+-])'),
      (match) {
        String number = match.group(1)!;
        String sign = match.group(2)!;
        String convertedNumber = number
            .split('')
            .map((d) => superscripts[d] ?? d)
            .join();
        return superscripts[sign] ?? sign;
      },
    );

    return result;
  }
  
  /// Remove nested LaTeX delimiters from content
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
}

