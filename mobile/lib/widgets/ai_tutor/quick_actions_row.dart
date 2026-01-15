/// AI Tutor Quick Actions Row Widget
/// Displays quick action chips above the input bar
import 'package:flutter/material.dart';
import '../../models/ai_tutor_models.dart';
import '../../theme/app_colors.dart';

class QuickActionsRow extends StatelessWidget {
  final List<QuickAction> actions;
  final Function(QuickAction) onActionTap;
  final bool isLoading;

  const QuickActionsRow({
    super.key,
    required this.actions,
    required this.onActionTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: actions.map((action) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _QuickActionChip(
                action: action,
                onTap: isLoading ? null : () => onActionTap(action),
                isLoading: isLoading,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final QuickAction action;
  final VoidCallback? onTap;
  final bool isLoading;

  const _QuickActionChip({
    required this.action,
    required this.onTap,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLoading
                  ? AppColors.borderLight
                  : AppColors.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            action.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isLoading ? AppColors.textDisabled : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
