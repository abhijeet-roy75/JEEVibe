/// HTML Text Parser
/// Parses basic HTML tags (<strong>, <bold>, <b>, <i>, <em>) and converts to TextSpan
import 'package:flutter/material.dart';

class HtmlTextParser {
  /// Parse HTML text and return a RichText widget
  static Widget parse(String htmlText, TextStyle baseStyle) {
    final spans = _parseHtml(htmlText, baseStyle);
    
    if (spans.length == 1 && spans[0] is TextSpan) {
      final textSpan = spans[0] as TextSpan;
      if (textSpan.style == baseStyle && textSpan.children == null) {
        // No HTML tags found, return simple Text widget
        return Text(textSpan.text ?? '', style: baseStyle);
      }
    }
    
    return RichText(
      text: TextSpan(children: spans),
      softWrap: true,
    );
  }

  /// Parse HTML and return list of TextSpan widgets
  /// Handles basic tags: <strong>, <bold>, <b>, <i>, <em>, <u>, <sub>, <sup>
  static List<InlineSpan> _parseHtml(String html, TextStyle baseStyle) {
    // Check if HTML contains any tags
    if (!html.contains('<') || !html.contains('>')) {
      return [TextSpan(text: html, style: baseStyle)];
    }
    
    final spans = <InlineSpan>[];
    int lastIndex = 0;
    
    // Pattern to match opening and closing tags: <tag>content</tag>
    // Use non-greedy matching and handle nested tags
    final tagPattern = RegExp(
      r'<(strong|bold|b|i|em|u|sub|sup)>(.*?)</\1>',
      caseSensitive: false,
      dotAll: true,
    );
    
    final matches = tagPattern.allMatches(html).toList();
    
    // If no matches, return plain text
    if (matches.isEmpty) {
      // Try to clean up any malformed tags
      final cleaned = html
          .replaceAll(RegExp(r'<(strong|bold|b|i|em|u|sub|sup)>', caseSensitive: false), '')
          .replaceAll(RegExp(r'</(strong|bold|b|i|em|u|sub|sup)>', caseSensitive: false), '');
      return [TextSpan(text: cleaned, style: baseStyle)];
    }
    
    // Process matches in order
    for (final match in matches) {
      // Add text before the tag
      if (match.start > lastIndex) {
        final beforeText = html.substring(lastIndex, match.start);
        if (beforeText.isNotEmpty) {
          spans.add(TextSpan(text: beforeText, style: baseStyle));
        }
      }
      
      // Add styled content
      final tag = match.group(1)!.toLowerCase();
      final content = match.group(2) ?? '';
      
      // Handle subscript and superscript with baseline offset
      if (tag == 'sub' || tag == 'sup') {
        final fontSize = (baseStyle.fontSize ?? 14) * 0.75;
        final tagStyle = baseStyle.copyWith(fontSize: fontSize);
        
        // Use WidgetSpan for proper baseline positioning
        spans.add(WidgetSpan(
          child: Transform.translate(
            offset: Offset(0, tag == 'sub' ? fontSize * 0.3 : -fontSize * 0.3),
            child: DefaultTextStyle(
              style: tagStyle,
              child: Text(content),
            ),
          ),
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
        ));
      } else {
        final tagStyle = _getTagStyle(tag, baseStyle);
        // Recursively parse nested tags in content
        final nestedSpans = _parseHtml(content, tagStyle);
        spans.addAll(nestedSpans);
      }
      
      lastIndex = match.end;
    }
    
    // Add remaining text after last tag
    if (lastIndex < html.length) {
      final remaining = html.substring(lastIndex);
      if (remaining.isNotEmpty) {
        spans.add(TextSpan(text: remaining, style: baseStyle));
      }
    }
    
    return spans.isEmpty ? [TextSpan(text: html, style: baseStyle)] : spans;
  }

  /// Get TextStyle for HTML tag
  static TextStyle _getTagStyle(String tag, TextStyle baseStyle) {
    switch (tag.toLowerCase()) {
      case 'strong':
      case 'bold':
      case 'b':
        return baseStyle.copyWith(fontWeight: FontWeight.bold);
      case 'i':
      case 'em':
        return baseStyle.copyWith(fontStyle: FontStyle.italic);
      case 'u':
        return baseStyle.copyWith(decoration: TextDecoration.underline);
      case 'sub':
        // Subscript: smaller font size, baseline shift down
        return baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 14) * 0.7,
        );
      case 'sup':
        // Superscript: smaller font size, baseline shift up
        return baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 14) * 0.7,
        );
      default:
        return baseStyle;
    }
  }
}

class _TagInfo {
  final String tag;
  final int start;
  final int end;

  _TagInfo({
    required this.tag,
    required this.start,
    required this.end,
  });
}
