/// Subject Progress Widget
/// Reusable widget for displaying subject progress bars
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class SubjectProgressWidget extends StatelessWidget {
  final Map<String, dynamic> subjects;

  const SubjectProgressWidget({
    super.key,
    required this.subjects,
  });

  Color _getSubjectColor(String subject) {
    switch (subject) {
      case 'Physics':
        return AppColors.infoBlue;
      case 'Chemistry':
        return AppColors.successGreen;
      case 'Mathematics':
        return AppColors.primaryPurple;
      default:
        return AppColors.textMedium;
    }
  }

  Widget _getSubjectIcon(String subject) {
    IconData icon;
    Color color;
    
    switch (subject) {
      case 'Physics':
        icon = Icons.bolt;
        color = AppColors.warningAmber;
        break;
      case 'Chemistry':
        icon = Icons.science;
        color = AppColors.successGreen;
        break;
      case 'Mathematics':
        icon = Icons.calculate;
        color = AppColors.textLight;
        break;
      default:
        icon = Icons.book;
        color = AppColors.textMedium;
    }
    
    return Icon(icon, color: color, size: 24);
  }

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book, color: AppColors.successGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Subject Progress',
                    style: AppTextStyles.headerSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // View All button removed
            ],
          ),
          const SizedBox(height: 16),
          ...['Physics', 'Chemistry', 'Mathematics'].map((subject) {
            final subjectData = subjects[subject.toLowerCase()] as Map<String, dynamic>?;
            if (subjectData == null) return const SizedBox.shrink();
            
            final percentile = (subjectData['current_percentile'] ?? subjectData['percentile'] ?? 0) as num;
            final progressValue = percentile / 100;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  _getSubjectIcon(subject),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject == 'Mathematics' ? 'Maths' : subject,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: AppColors.borderGray,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getSubjectColor(subject),
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${percentile.toInt()}%',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

