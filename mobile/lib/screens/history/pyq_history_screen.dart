/// PYQ History Screen
/// Placeholder screen for upcoming Previous Year Questions history feature

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class PyqHistoryScreen extends StatelessWidget {
  const PyqHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withAlpha(25),
                    AppColors.secondary.withAlpha(25),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_edu_outlined,
                size: 48,
                color: AppColors.primary.withAlpha(180),
              ),
            ),
            const SizedBox(height: 32),

            // Title
            Text(
              'Previous Year Questions',
              style: AppTextStyles.headerLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Coming soon badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Coming Soon',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Description
            Text(
              'Practice with actual JEE questions from previous years. Track your performance across different years and topics.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Feature preview
            _buildFeaturePreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePreview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderDefault,
        ),
      ),
      child: Column(
        children: [
          Text(
            'What to expect:',
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.calendar_today_outlined, 'JEE 2015-2024 questions'),
          const SizedBox(height: 12),
          _buildFeatureItem(Icons.filter_list_outlined, 'Filter by year & subject'),
          const SizedBox(height: 12),
          _buildFeatureItem(Icons.auto_graph_outlined, 'Track year-wise accuracy'),
          const SizedBox(height: 12),
          _buildFeatureItem(Icons.lightbulb_outlined, 'Detailed solutions'),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
