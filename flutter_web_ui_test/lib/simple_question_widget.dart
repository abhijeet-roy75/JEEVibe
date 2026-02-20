import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class SimpleQuestionWidget extends StatefulWidget {
  final Map<String, dynamic> question;

  const SimpleQuestionWidget({super.key, required this.question});

  @override
  State<SimpleQuestionWidget> createState() => _SimpleQuestionWidgetState();
}

class _SimpleQuestionWidgetState extends State<SimpleQuestionWidget> {
  String? selectedAnswer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF9333EA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.question['subject'] ?? 'Physics',
              style: const TextStyle(
                color: Color(0xFF9333EA),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Question text with LaTeX
          _buildQuestionText(widget.question['question_text']),

          const SizedBox(height: 24),

          // Options
          ...((widget.question['options'] as Map).entries.map((entry) {
            return _buildOption(entry.key, entry.value);
          }).toList()),

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: selectedAnswer != null ? () {} : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9333EA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Submit Answer'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionText(String text) {
    // Simple LaTeX parser - splits on \( and \)
    final parts = <InlineSpan>[];
    final regex = RegExp(r'\\\((.*?)\\\)');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Add text before LaTeX
      if (match.start > lastEnd) {
        parts.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      // Add LaTeX
      try {
        parts.add(WidgetSpan(
          child: Math.tex(
            match.group(1) ?? '',
            textStyle: const TextStyle(fontSize: 18),
          ),
          alignment: PlaceholderAlignment.middle,
        ));
      } catch (e) {
        parts.add(TextSpan(text: match.group(1) ?? ''));
      }

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      parts.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        children: parts,
        style: const TextStyle(fontSize: 18, color: Colors.black87),
      ),
    );
  }

  Widget _buildOption(String id, String text) {
    final isSelected = selectedAnswer == id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => selectedAnswer = id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF9333EA).withOpacity(0.1)
                : Colors.white,
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF9333EA)
                  : const Color(0xFFE5E7EB),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Option letter circle
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF9333EA).withOpacity(0.2)
                      : const Color(0xFFE5E7EB).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    id,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF9333EA)
                          : Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Option text with LaTeX
              Expanded(child: _buildOptionText(text)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionText(String text) {
    // Simple LaTeX parser for options
    final regex = RegExp(r'\\\((.*?)\\\)');
    final match = regex.firstMatch(text);

    if (match != null) {
      try {
        return Math.tex(
          match.group(1) ?? '',
          textStyle: const TextStyle(fontSize: 16),
        );
      } catch (e) {
        return Text(text, style: const TextStyle(fontSize: 16));
      }
    }

    return Text(text, style: const TextStyle(fontSize: 16));
  }
}
