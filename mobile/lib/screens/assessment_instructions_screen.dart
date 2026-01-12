/// Assessment Instructions Screen
/// Shows instructions before starting the initial assessment
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_header.dart';
import '../widgets/priya_avatar.dart';
import '../widgets/buttons/gradient_button.dart';
import '../widgets/buttons/icon_button.dart';
import 'assessment_question_screen.dart';

class AssessmentInstructionsScreen extends StatelessWidget {
  const AssessmentInstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            // Header with back button, lightbulb icon, and title
            _buildHeader(context),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // Priya Ma'am instruction card
                    _buildPriyaCard(),
                    const SizedBox(height: 24),
                    // Important Guidelines section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Important Guidelines',
                            style: AppTextStyles.headerSmall.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildGuidelineCard(
                            icon: Icons.timer,
                            title: '45 minutes, one sitting',
                            description: 'Complete all 30 questions without pausing',
                          ),
                          const SizedBox(height: 12),
                          _buildGuidelineCard(
                            icon: Icons.check_circle,
                            title: 'Think before submitting',
                            description: 'Can\'t skip or go back to previous questions',
                          ),
                          const SizedBox(height: 12),
                          _buildGuidelineCard(
                            icon: Icons.bar_chart,
                            title: 'Balanced assessment',
                            description: 'Questions across Physics, Chemistry, and Maths',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Start Assessment button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GradientButton(
                        text: 'Start Assessment',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AssessmentQuestionScreen(),
                            ),
                          );
                        },
                        size: GradientButtonSize.large,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Footer text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMedium,
                          ),
                          children: [
                            const TextSpan(text: 'Once started, '),
                            TextSpan(
                              text: 'complete all 30 questions',
                              style: TextStyle(
                                color: AppColors.primaryPurple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: ' in one sitting'),
                          ],
                        ),
                      ),
                    ),
                    // Bottom padding to account for Android navigation bar
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return AppHeader(
      leading: AppIconButton.back(
        onPressed: () => Navigator.of(context).pop(),
        color: Colors.white,
      ),
      centerContent: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.lightbulb,
          color: Color(0xFFFFD700),
          size: 32,
        ),
      ),
      title: Text(
        'Before You Begin',
        style: AppTextStyles.headerWhite.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Tips for best results',
          style: AppTextStyles.bodyWhite.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      showGradient: true,
      gradient: AppColors.ctaGradient,
    );
  }

  Widget _buildPriyaCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.priyaCardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE9D5FF),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            PriyaAvatar(size: 48),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Priya Ma\'am',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryPurple,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.auto_awesome,
                        color: AppColors.primaryPurple,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reserve 45 minutes! You\'ll answer questions one at a time—can\'t skip or go back. Think carefully and do your best. You\'ve got this! 💜',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: const Color(0xFF6B21A8),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidelineCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primaryPurple,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
