/// Daily Limit Screen - Matches design: 14 Daily Snaps Reached without PRO push.png
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../providers/app_state_provider.dart';
import '../widgets/priya_avatar.dart';
import '../widgets/app_header.dart';

class DailyLimitScreen extends StatefulWidget {
  const DailyLimitScreen({super.key});

  @override
  State<DailyLimitScreen> createState() => _DailyLimitScreenState();
}

class _DailyLimitScreenState extends State<DailyLimitScreen> {
  String _resetCountdown = '';

  @override
  void initState() {
    super.initState();
    _updateCountdown();
  }

  Future<void> _updateCountdown() async {
    if (!mounted) return;
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final countdown = await appState.getResetCountdownText();
    if (mounted) {
      setState(() {
        _resetCountdown = countdown;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.space24),
                    _buildCompletionCard(),
                    const SizedBox(height: AppSpacing.space24),
                    _buildResetCard(),
                    const SizedBox(height: AppSpacing.space24),
                    _buildPriyaMaamCard(),
                    const SizedBox(height: AppSpacing.space32),
                    _buildBackButton(),
                    const SizedBox(height: AppSpacing.space32),
                  ],
                ),
              ),
            ),
            _buildBottomBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppHeaderWithIcon(
      icon: Icons.check_circle,
      title: 'Amazing Work Today!',
      subtitle: 'You\'ve completed all 5 snaps for today',
      iconColor: AppColors.successGreen,
      iconSize: 48, // Reduced from 64
      // Use default bottomPadding (16) for consistency
    );
  }

  Widget _buildCompletionCard() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final stats = appState.stats;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: AppShadows.cardShadow,
          ),
          child: Column(
            children: [
              // Snaps remaining
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.track_changes,
                    color: AppColors.primaryPurple,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${appState.snapsRemaining}/${appState.snapLimit} snaps remaining',
                    style: AppTextStyles.headerSmall.copyWith(
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              Text(
                'You\'ve made excellent progress today!',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Stats grid
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Questions',
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${stats.totalQuestionsPracticed}',
                            style: AppTextStyles.headerLarge.copyWith(
                              fontSize: 32,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.successBackground,
                        borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                        border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Accuracy',
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            stats.getAccuracyString(),
                            style: AppTextStyles.headerLarge.copyWith(
                              fontSize: 32,
                              color: AppColors.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Top Subject
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warningBackground,
                  borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                  border: Border.all(color: AppColors.warningAmber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.trending_up,
                      color: AppColors.warningAmber,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Top Subject',
                      style: AppTextStyles.labelMedium,
                    ),
                    const Spacer(),
                    Text(
                      'Physics',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.warningAmber,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Topics Improved
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.successBackground.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                  border: Border.all(color: AppColors.successGreen.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Topics You Improved Today',
                      style: AppTextStyles.labelMedium,
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTopicChip('Mechanics'),
                          const SizedBox(width: 8),
                          _buildTopicChip('Calculus'),
                          const SizedBox(width: 8),
                          _buildTopicChip('Organic Chemistry'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopicChip(String topic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppRadius.radiusRound),
        border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
      ),
      child: Text(
        topic,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.successGreen,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  String _getPriyaMaamMessage(String accuracy) {
    return 'Fantastic dedication! You completed all 5 snaps today with $accuracy accuracy. Take a well-deserved break and come back tomorrow refreshed and ready to learn more! 🎉';
  }

  Widget _buildResetCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.infoBackground.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(color: AppColors.infoBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.infoBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your snaps reset in',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _resetCountdown.isNotEmpty ? _resetCountdown : 'Calculating...',
                  style: AppTextStyles.headerLarge.copyWith(
                    color: AppColors.infoBlue,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tomorrow at 12:00 AM',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.infoBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriyaMaamCard() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final stats = appState.stats;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.priyaCardGradient,
            borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
            border: Border.all(color: const Color(0xFFE9D5FF), width: 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PriyaAvatar(size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Priya Ma\'am',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFF9333EA),
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getPriyaMaamMessage(stats.getAccuracyString()),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: const Color(0xFF6B21A8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppColors.ctaGradient,
        borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
        boxShadow: AppShadows.buttonShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.home, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  'Back to Home',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        gradient: AppColors.ctaGradient,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Day Complete! ⭐',
              style: AppTextStyles.labelMedium.copyWith(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
