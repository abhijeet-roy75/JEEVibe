/// SubjectFilterBar - Reusable subject filter component
///
/// A compact horizontal filter bar for filtering by subject (All, Physics, Chemistry, Math).
/// Shows icons and optional counts for each subject.
///
/// Example:
/// ```dart
/// SubjectFilterBar(
///   selectedSubject: 'All',
///   onSubjectChanged: (subject) => setState(() => _selectedSubject = subject),
///   counts: {'All': 50, 'Physics': 20, 'Chemistry': 15, 'Mathematics': 15},
/// )
/// ```
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'subject_icon_widget.dart';

class SubjectFilterBar extends StatelessWidget {
  /// Currently selected subject
  final String selectedSubject;

  /// Callback when a subject is selected
  final ValueChanged<String> onSubjectChanged;

  /// Optional counts per subject. Keys should match subject names.
  /// If null, counts will not be displayed.
  final Map<String, int>? counts;

  /// Whether to show counts (only works if counts is provided)
  final bool showCounts;

  /// Padding around the filter bar
  final EdgeInsets padding;

  const SubjectFilterBar({
    super.key,
    required this.selectedSubject,
    required this.onSubjectChanged,
    this.counts,
    this.showCounts = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  static const List<String> _subjects = ['All', 'Physics', 'Chemistry', 'Mathematics'];

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();

    return Container(
      padding: padding,
      // Use RawGestureDetector to claim horizontal drags before TabBarView
      child: RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          // Claim horizontal drag gestures with high priority
          HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
            () => HorizontalDragGestureRecognizer(),
            (HorizontalDragGestureRecognizer instance) {
              instance
                ..onStart = (_) {} // Claim the gesture
                ..onUpdate = (details) {
                  // Manually scroll the SingleChildScrollView
                  scrollController.jumpTo(
                    (scrollController.offset - details.delta.dx).clamp(
                      0.0,
                      scrollController.position.maxScrollExtent,
                    ),
                  );
                }
                ..onEnd = (_) {};
            },
          ),
        },
        child: SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(), // Disable default scroll, we handle it manually
          child: Row(
            children: _subjects.map((subject) {
              final isSelected = selectedSubject == subject ||
                  (selectedSubject == 'Math' && subject == 'Mathematics');
              final count = _getCount(subject);
              final hasCount = counts != null && showCounts;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _SubjectFilterChip(
                  subject: subject,
                  isSelected: isSelected,
                  count: hasCount ? count : null,
                  onTap: () => onSubjectChanged(subject),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  int _getCount(String subject) {
    if (counts == null) return 0;

    // Try exact match first
    if (counts!.containsKey(subject)) {
      return counts![subject]!;
    }

    // Handle 'Math' vs 'Mathematics' mismatch
    if (subject == 'Mathematics' && counts!.containsKey('Math')) {
      return counts!['Math']!;
    }
    if (subject == 'Math' && counts!.containsKey('Mathematics')) {
      return counts!['Mathematics']!;
    }

    return 0;
  }
}

class _SubjectFilterChip extends StatelessWidget {
  final String subject;
  final bool isSelected;
  final int? count;
  final VoidCallback onTap;

  const _SubjectFilterChip({
    required this.subject,
    required this.isSelected,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subjectColor = SubjectIconWidget.getColor(subject);
    final subjectIcon = SubjectIconWidget.getIcon(subject);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? subjectColor.withAlpha(25) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? subjectColor : AppColors.borderDefault,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subject icon
            Icon(
              subjectIcon,
              size: 16,
              color: isSelected ? subjectColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),

            // Subject label
            Text(
              _getDisplayLabel(subject),
              style: TextStyle(
                color: isSelected ? subjectColor : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),

            // Count badge (if provided)
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? subjectColor.withAlpha(40)
                      : AppColors.textSecondary.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? subjectColor : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getDisplayLabel(String subject) {
    // Shorten "Mathematics" to "Math" for compact display
    if (subject == 'Mathematics') return 'Math';
    return subject;
  }
}
