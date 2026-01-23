/// SubjectFilterBar - Reusable subject filter component
///
/// A compact horizontal filter bar for filtering by subject (Physics, Chemistry, Maths).
/// Matches the Analytics tab design with gradient selection.
///
/// Example:
/// ```dart
/// SubjectFilterBar(
///   selectedSubject: 'Physics',
///   onSubjectChanged: (subject) => setState(() => _selectedSubject = subject),
/// )
/// ```
library;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SubjectFilterBar extends StatelessWidget {
  /// Currently selected subject ('Physics', 'Chemistry', or 'Mathematics')
  final String selectedSubject;

  /// Callback when a subject is selected
  final ValueChanged<String> onSubjectChanged;

  /// Optional counts per subject (not displayed in new design, kept for compatibility)
  final Map<String, int>? counts;

  /// Whether to show counts (kept for compatibility, not used in new design)
  final bool showCounts;

  /// Padding around the filter bar
  final EdgeInsets padding;

  const SubjectFilterBar({
    super.key,
    required this.selectedSubject,
    required this.onSubjectChanged,
    this.counts,
    this.showCounts = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  // Subject definitions with colors matching Analytics tab
  static const List<_SubjectDef> _subjects = [
    _SubjectDef('Physics', 'physics', Icons.bolt, AppColors.infoBlue),
    _SubjectDef('Chemistry', 'chemistry', Icons.science, AppColors.successGreen),
    _SubjectDef('Maths', 'mathematics', Icons.calculate, AppColors.primaryPurple),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      child: Row(
        children: _subjects.map((subject) {
          final isSelected = _isSubjectSelected(subject.value);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _SubjectFilterChip(
              label: subject.label,
              value: subject.value,
              icon: subject.icon,
              color: subject.color,
              isSelected: isSelected,
              onTap: () => onSubjectChanged(subject.value == 'mathematics' ? 'Mathematics' : subject.label),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isSubjectSelected(String value) {
    final selected = selectedSubject.toLowerCase();
    if (value == 'mathematics') {
      return selected == 'mathematics' || selected == 'maths' || selected == 'math';
    }
    return selected == value;
  }
}

class _SubjectDef {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SubjectDef(this.label, this.value, this.icon, this.color);
}

class _SubjectFilterChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubjectFilterChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.ctaGradient : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.borderDefault,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
