/// Chapter Practice Result Screen
/// Shows practice completion summary with performance breakdown
/// Similar to DailyQuizResultScreen - navigates to separate review screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chapter_practice_models.dart';
import '../../providers/chapter_practice_provider.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'package:jeevibe_mobile/theme/app_platform_sizing.dart';
import '../../widgets/priya_avatar.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/buttons/secondary_button.dart';
import '../main_navigation_screen.dart';
import '../subscription/paywall_screen.dart';
import 'chapter_practice_review_screen.dart';

class ChapterPracticeResultScreen extends StatelessWidget {
  final PracticeSessionSummary? summary;
  final List<PracticeQuestionResult>? results;
  final ChapterPracticeSession? session;

  const ChapterPracticeResultScreen({
    super.key,
    this.summary,
    this.results,
    this.session,
  });

  // Computed values from either summary or provider results
  int get _totalQuestions =>
      summary?.totalQuestions ?? results?.length ?? session?.totalQuestions ?? 0;

  int get _correctCount =>
      summary?.correctCount ?? results?.where((r) => r.isCorrect).length ?? 0;

  int get _wrongCount => _totalQuestions - _correctCount;

  double get _accuracy {
    if (_totalQuestions == 0) return 0.0;
    return _correctCount / _totalQuestions;
  }

  String get _chapterName =>
      summary?.chapterName ?? session?.chapterName ?? 'Chapter';

  String get _subject => summary?.subject ?? session?.subject ?? '';

  String _getEncouragingMessage() {
    final percentage = _accuracy * 100;
    if (percentage >= 80) {
      return 'Outstanding performance! You have a strong grasp of $_chapterName. Keep up the excellent work!';
    } else if (percentage >= 60) {
      return 'Good job! You\'re building a solid understanding of $_chapterName. Review the wrong answers to improve further.';
    } else if (percentage >= 40) {
      return 'Nice effort! Focus on reviewing the solutions for the questions you got wrong. Practice will help you improve!';
    } else {
      return 'Every practice session makes you stronger! Review the solutions carefully and try practicing again. You\'ll get better!';
    }
  }

  /// Get performance tier based on accuracy
  String _getPerformanceTier() {
    final scoreOutOf10 = _accuracy * 10;
    if (scoreOutOf10 >= 9) return 'excellent';
    if (scoreOutOf10 >= 7) return 'good';
    if (scoreOutOf10 >= 5) return 'average';
    if (scoreOutOf10 >= 3) return 'struggling';
    return 'tough_day';
  }

  /// Get header title based on performance tier
  String _getHeaderTitle() {
    switch (_getPerformanceTier()) {
      case 'excellent':
        return 'Outstanding!';
      case 'good':
        return 'Well Done!';
      case 'average':
        return 'Practice Complete!';
      case 'struggling':
        return 'Practice Complete';
      case 'tough_day':
        return 'Practice Complete';
      default:
        return 'Practice Complete';
    }
  }

  void _goHome(BuildContext context) {
    // Reset provider state
    final provider =
        Provider.of<ChapterPracticeProvider>(context, listen: false);
    provider.reset();

    // Navigate to main home screen with bottom navigation
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  void _practiceAgain(BuildContext context) {
    // Reset provider and go back to home to restart practice
    final provider =
        Provider.of<ChapterPracticeProvider>(context, listen: false);
    provider.reset();

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _reviewQuestions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterPracticeReviewScreen(
          summary: summary,
          results: results,
          session: session,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _goHome(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(
          children: [
            // Header
            _buildHeader(context),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewPadding.bottom + 16,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Summary cards
                    _buildSummaryCards(),
                    const SizedBox(height: 16),
                    // Priya Ma'am message
                    _buildPriyaMaamMessage(),
                    const SizedBox(height: 16),
                    // Upgrade prompt for Free tier users (5 questions limit)
                    _buildUpgradePromptIfNeeded(context),
                    const SizedBox(height: 24),
                    // Action buttons
                    _buildActionButtons(context),
                    const SizedBox(height: 16),
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              // Title
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => _goHome(context),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          _getHeaderTitle(),
                          style: AppTextStyles.headerWhite.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _chapterName,
                          style: AppTextStyles.bodyWhite.copyWith(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the close button
                ],
              ),
              const SizedBox(height: 16),
              // Score circle
              Container(
                width: PlatformSizing.spacing(100),
                height: PlatformSizing.spacing(100),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${(_accuracy * 100).toInt()}%',
                    style: AppTextStyles.headerWhite.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Subject badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _subject,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total',
                '$_totalQuestions',
                AppColors.primaryPurple,
                Icons.quiz_outlined,
              ),
            ),
            SizedBox(width: PlatformSizing.spacing(12)),
            Expanded(
              child: _buildSummaryCard(
                'Correct',
                '$_correctCount',
                AppColors.successGreen,
                Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Wrong',
                '$_wrongCount',
                AppColors.errorRed,
                Icons.cancel_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: PlatformSizing.spacing(12),
        horizontal: PlatformSizing.spacing(12),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: PlatformSizing.iconSize(24)),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.headerMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMedium,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriyaMaamMessage() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: PlatformSizing.spacing(16)),
      padding: EdgeInsets.all(PlatformSizing.spacing(16)),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
      ),
      child: Row(
        children: [
          PriyaAvatar(size: PlatformSizing.spacing(56)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Priya Ma\'am',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getEncouragingMessage(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMedium,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradePromptIfNeeded(BuildContext context) {
    // Check if user is on Free tier and hit the 5-question limit
    final subscriptionService = SubscriptionService();
    final isFree = subscriptionService.isFree;

    // Only show upgrade prompt if:
    // 1. User is on Free tier
    // 2. User completed exactly 5 questions (the Free tier limit)
    if (!isFree || _totalQuestions != 5) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9333EA).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Want More Practice?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'You completed 5 questions (Free tier limit). Upgrade to Pro for 15 questions per chapter and practice unlimited chapters daily!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // Benefits list
            ...[
              ('📚', '15 questions per chapter (3x more practice)'),
              ('🚀', 'Practice unlimited chapters daily'),
              ('📊', 'Full analytics & progress tracking'),
            ].map((benefit) => Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    benefit.$1,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      benefit.$2,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
            // Upgrade button
            PrimaryButton(
              text: 'Upgrade to Pro',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PaywallScreen(
                      featureName: 'Chapter Practice',
                      limitReachedMessage: 'You\'ve completed 5 questions. Upgrade for 15 questions per chapter!',
                    ),
                  ),
                );
              },
              backgroundColor: Colors.white,
              height: PlatformSizing.buttonHeight(48),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Review All Questions button (primary action - like daily quiz)
          _buildActionButton(
            icon: Icons.rate_review,
            iconColor: Colors.white,
            label: 'Review Questions ($_totalQuestions)',
            backgroundColor: AppColors.primaryPurple,
            onTap: () => _reviewQuestions(context),
          ),
          const SizedBox(height: 12),
          // Back to Dashboard button (standard GradientButton)
          GradientButton(
            text: 'Back to Dashboard',
            onPressed: () => _goHome(context),
            size: GradientButtonSize.large,
          ),
          const SizedBox(height: 12),
          // Practice Again button (secondary)
          SecondaryButton(
            text: 'Practice Again',
            onPressed: () => _practiceAgain(context),
            icon: Icons.refresh,
            height: PlatformSizing.buttonHeight(56),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color backgroundColor,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    final effectiveTextColor = textColor ?? Colors.white;
    return Container(
      width: double.infinity,
      height: PlatformSizing.buttonHeight(56),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: iconColor, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: effectiveTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.chevron_right, color: effectiveTextColor, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
