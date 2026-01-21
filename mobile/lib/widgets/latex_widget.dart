/// JEEVibe LaTeX Widget
///
/// A robust LaTeX rendering widget that handles:
/// - Mixed text and LaTeX content
/// - Multiple delimiter formats ($, $$, \(, \[)
/// - Malformed LaTeX with graceful fallback
/// - Unicode symbol conversion when rendering fails
///
/// Architecture:
/// 1. Parse input using state-machine parser (latex_parser.dart)
/// 2. Normalize LaTeX content (latex_normalizer.dart)
/// 3. Render using flutter_math_fork
/// 4. Fall back to Unicode text (latex_to_text.dart) if rendering fails

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../config/content_config.dart';
import '../utils/latex_parser.dart';
import '../utils/latex_normalizer.dart';
import '../utils/latex_to_text.dart';

class LaTeXWidget extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  final FontWeight? latexWeight;
  final bool allowWrapping;

  const LaTeXWidget({
    super.key,
    required this.text,
    this.textStyle,
    this.latexWeight,
    this.allowWrapping = false,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final style = textStyle ?? const TextStyle(fontSize: 14);
    return _renderContent(text, style);
  }

  Widget _renderContent(String input, TextStyle style) {
    // Step 1: Quick check - if no LaTeX markers at all, return plain text
    if (!LaTeXParser.containsLatex(input)) {
      return Text(input, style: style);
    }

    // Step 2: Parse the input into segments using the state-machine parser
    final segments = LaTeXParser.parse(input);

    // Step 3: If only one segment that's LaTeX, render as pure LaTeX
    if (segments.length == 1 && segments.first.isLatex) {
      return _renderPureLatex(segments.first.content, style, segments.first.isDisplayMode);
    }

    // Step 4: If no LaTeX segments found (parser couldn't extract), try legacy approach
    if (segments.isEmpty || segments.every((s) => !s.isLatex)) {
      // Check if there are unwrapped LaTeX commands
      if (_hasUnwrappedLatexCommands(input)) {
        // Wrap the entire content and try again
        final wrappedSegments = LaTeXParser.parse('\\($input\\)');
        if (wrappedSegments.isNotEmpty && wrappedSegments.any((s) => s.isLatex)) {
          return _renderMixedContent(wrappedSegments, style);
        }
      }
      return Text(input, style: style);
    }

    // Step 5: Render mixed content
    return _renderMixedContent(segments, style);
  }

  /// Check if text has LaTeX commands without delimiters
  bool _hasUnwrappedLatexCommands(String input) {
    return input.contains('\\frac') ||
           input.contains('\\mathrm') ||
           input.contains('\\sqrt') ||
           input.contains('\\times') ||
           input.contains('\\div') ||
           input.contains('\\alpha') ||
           input.contains('\\beta') ||
           input.contains('\\theta') ||
           input.contains('\\lambda') ||
           input.contains('\\pi') ||
           input.contains('\\sin') ||
           input.contains('\\cos') ||
           input.contains('\\tan') ||
           input.contains('\\log') ||
           input.contains('\\sum') ||
           input.contains('\\int') ||
           input.contains('\\begin{') ||
           input.contains('_{') ||
           input.contains('^{');
  }

  /// Render pure LaTeX content (no surrounding text)
  Widget _renderPureLatex(String latex, TextStyle style, bool isDisplayMode) {
    final boldStyle = style.copyWith(
      fontWeight: latexWeight ?? ContentConfig.latexFontWeight,
    );

    // Normalize the LaTeX to fix common issues
    final normalizedLatex = LaTeXNormalizer.normalize(latex);

    // If wrapping is allowed or content is very long, use text fallback
    if (allowWrapping || normalizedLatex.length > 200) {
      return _renderTextFallback(latex, boldStyle);
    }

    // Check if LaTeX is likely to render successfully
    if (!LaTeXNormalizer.isLikelyValid(normalizedLatex)) {
      debugPrint('[LaTeX] Invalid LaTeX detected, using fallback');
      return _renderTextFallback(latex, boldStyle);
    }

    // Try to render with flutter_math_fork
    try {
      return LayoutBuilder(
        builder: (context, constraints) {
          try {
            final mathWidget = Math.tex(
              normalizedLatex,
              mathStyle: isDisplayMode ? MathStyle.display : MathStyle.text,
              textStyle: boldStyle,
              onErrorFallback: (error) {
                debugPrint('[LaTeX] Math.tex render error: $error');
                return _buildTextWidget(LaTeXToText.convert(latex), boldStyle);
              },
            );

            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: mathWidget,
              ),
            );
          } catch (e) {
            debugPrint('[LaTeX] Layout error: $e');
            return _renderTextFallback(latex, boldStyle);
          }
        },
      );
    } catch (e) {
      debugPrint('[LaTeX] Render error: $e');
      return _renderTextFallback(latex, boldStyle);
    }
  }

  /// Render mixed content (text and LaTeX segments)
  Widget _renderMixedContent(List<ParsedSegment> segments, TextStyle style) {
    final spans = <InlineSpan>[];
    final boldStyle = style.copyWith(
      fontWeight: latexWeight ?? ContentConfig.latexFontWeight,
    );

    for (final segment in segments) {
      if (!segment.isLatex) {
        // Plain text segment
        if (segment.content.isNotEmpty) {
          spans.add(TextSpan(text: segment.content, style: style));
        }
      } else {
        // LaTeX segment
        final normalizedLatex = LaTeXNormalizer.normalize(segment.content);

        // For short, valid LaTeX, try to render with flutter_math_fork
        if (normalizedLatex.length <= 150 && LaTeXNormalizer.isLikelyValid(normalizedLatex)) {
          try {
            final mathWidget = Math.tex(
              normalizedLatex,
              mathStyle: segment.isDisplayMode ? MathStyle.display : MathStyle.text,
              textStyle: boldStyle,
              onErrorFallback: (error) {
                debugPrint('[LaTeX] Mixed content error: $error');
                return _buildTextWidget(LaTeXToText.convert(segment.content), boldStyle);
              },
            );

            spans.add(WidgetSpan(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: mathWidget,
                ),
              ),
              alignment: PlaceholderAlignment.middle,
            ));
          } catch (e) {
            debugPrint('[LaTeX] Mixed content render error: $e');
            // Fall back to text
            final convertedText = LaTeXToText.convert(segment.content);
            if (convertedText.isNotEmpty) {
              spans.add(TextSpan(text: convertedText, style: boldStyle));
            }
          }
        } else {
          // Long or invalid LaTeX - use text conversion
          final convertedText = LaTeXToText.convert(segment.content);
          if (convertedText.isNotEmpty) {
            spans.add(TextSpan(text: convertedText, style: boldStyle));
          }
        }
      }
    }

    if (spans.isEmpty) {
      return Text(
        text,
        style: style,
        softWrap: true,
        overflow: TextOverflow.visible,
      );
    }

    return RichText(
      text: TextSpan(children: spans),
      softWrap: true,
      overflow: TextOverflow.visible,
      textAlign: TextAlign.left,
    );
  }

  /// Render text fallback using LaTeXToText converter
  Widget _renderTextFallback(String latex, TextStyle style) {
    final converted = LaTeXToText.convert(latex);

    if (converted.isNotEmpty && converted.trim().isNotEmpty) {
      return Text(
        converted,
        style: style,
        softWrap: true,
        overflow: TextOverflow.visible,
      );
    }

    // Last resort: show original with basic cleanup
    final lastResort = latex
        .replaceAll(RegExp(r'\\\(|\\\)|\\\[|\\\]'), '')
        .replaceAll(RegExp(r'\$\$?'), '')
        .replaceAll(RegExp(r'[{}]'), '')
        .replaceAll(RegExp(r'\\[a-zA-Z]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return Text(
      lastResort.isEmpty ? latex : lastResort,
      style: style,
      softWrap: true,
      overflow: TextOverflow.visible,
    );
  }

  /// Build a simple text widget
  Widget _buildTextWidget(String text, TextStyle style) {
    return Text(
      text.isEmpty ? ' ' : text,
      style: style,
      softWrap: true,
      overflow: TextOverflow.visible,
    );
  }
}
