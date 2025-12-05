/// Home Screen - Matches design: 3 Home Screen.png
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'camera_screen.dart';
import 'daily_limit_screen.dart';
import 'solution_review_screen.dart';
import 'all_solutions_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../providers/app_state_provider.dart';
import '../widgets/app_header.dart';
import '../models/snap_data_model.dart';
import '../services/storage_service.dart';
import '../utils/text_preprocessor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _resetCountdown = '';

  @override
  void initState() {
    super.initState();
    _checkAndReset();
    _updateCountdown();
  }

  Future<void> _checkAndReset() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    await appState.checkAndResetIfNeeded();
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
      extendBodyBehindAppBar: true,
      appBar: null, // Explicitly remove system app bar
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            // Fixed header at top (AppHeader has SafeArea built-in)
            _buildHeader(),
            // Scrollable content below header
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final appState = Provider.of<AppStateProvider>(context, listen: false);
                  await appState.refresh();
                  await _updateCountdown();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.space16), // Add spacing after header
                      _buildSnapCounterCard(),
                      const SizedBox(height: AppSpacing.space24),
                      _buildMainCTA(),
                      const SizedBox(height: AppSpacing.space32),
                      _buildRecentSolutions(),
                      const SizedBox(height: AppSpacing.space32),
                      _buildTodayProgress(),
                      const SizedBox(height: AppSpacing.space32),
                      _buildCongratulationsCard(),
                      const SizedBox(height: AppSpacing.space40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCongratulationsCard() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        // Only show when all 5 snaps are used
        if (appState.snapsUsed < appState.snapLimit) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: AppSpacing.screenPadding,
          child: Container(
            padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6EE7B7), Color(0xFF10B981)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
                  boxShadow: [
                    BoxShadow(
                  color: AppColors.successGreen.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.track_changes,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  'Amazing Work Today!',
                  style: AppTextStyles.headerMedium.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'ve completed all 5 snaps. Come back tomorrow for more learning!',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return AppHeader(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.home,
          color: Colors.white,
          size: 24,
        ),
      ),
      title: Text(
        'JEEVibe Snap and Solve',
        style: AppTextStyles.headerWhite.copyWith(fontSize: 20), // Consistent with other headers
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      showGradient: true, // Ensure gradient is shown
      // Use default padding (24 top, 16 bottom) - AppHeader has SafeArea built-in
    );
  }

  Widget _buildSnapCounterCard() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final isComplete = appState.snapsUsed >= appState.snapLimit;
        final remaining = appState.snapsRemaining;

        return Padding(
          padding: AppSpacing.screenPadding,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: AppShadows.cardShadowElevated,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Camera Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.cardLightPurple,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: AppColors.primaryPurple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Snaps Today
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Snaps Today',
                            style: AppTextStyles.headerSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Free daily limit',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    // Counter
                    Text(
                      '${appState.snapsUsed}/${appState.snapLimit}',
                      style: AppTextStyles.headerLarge.copyWith(
                        fontSize: 32,
                        color: isComplete ? AppColors.successGreen : AppColors.primaryPurple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Progress Bar
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: appState.snapsUsed / appState.snapLimit,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isComplete 
                            ? const LinearGradient(
                                colors: [AppColors.successGreen, AppColors.successGreenLight],
                              )
                            : AppColors.ctaGradient,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Reset time and remaining
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _resetCountdown.isNotEmpty ? _resetCountdown : 'Resets at midnight',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textLight,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      isComplete 
                          ? 'All complete! 🎉'
                          : '$remaining remaining',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isComplete ? AppColors.successGreen : AppColors.primaryPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainCTA() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final canSnap = appState.canTakeSnap;

        return Padding(
          padding: AppSpacing.screenPadding,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: canSnap ? AppColors.ctaGradient : null,
              color: canSnap ? null : AppColors.borderGray,
              borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
              boxShadow: canSnap ? AppShadows.buttonShadow : [],
            ),
                child: Material(
              color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                  if (canSnap) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const CameraScreen(),
                        ),
                      );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const DailyLimitScreen(),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
                child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(
                        canSnap ? Icons.camera_alt : Icons.lock,
                        color: canSnap ? Colors.white : AppColors.textGray,
                        size: 24,
                      ),
                          const SizedBox(width: 12),
                          Text(
                        canSnap ? 'Snap Your Question' : 'Snap Your Question',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: canSnap ? Colors.white : AppColors.textGray,
                          fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        );
      },
    );
  }

  Widget _buildRecentSolutions() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final solutions = appState.recentSolutions;

        return Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Snaps', style: AppTextStyles.headerMedium),
                  if (solutions.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AllSolutionsScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'View All',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (solutions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: AppColors.textGray.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No solutions yet',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Snap your first question to get started!',
                          style: AppTextStyles.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...solutions.map((solution) => _buildSolutionCard(solution)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSolutionCard(RecentSolution solution) {
    final BuildContext context = this.context;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // Get all solutions for today to enable navigation
            final storage = StorageService();
            final allSolutions = await storage.getAllSolutionsForToday();
            if (allSolutions.isEmpty) {
              // Fallback: use recent solutions if today's list is empty
              final appState = Provider.of<AppStateProvider>(context, listen: false);
              final recentSolutions = appState.recentSolutions;
              if (recentSolutions.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SolutionReviewScreen(
                      allSolutions: recentSolutions,
                      initialIndex: recentSolutions.indexOf(solution),
                    ),
                  ),
                );
              }
            } else {
              final index = allSolutions.indexWhere((s) => s.id == solution.id);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SolutionReviewScreen(
                    allSolutions: allSolutions,
                    initialIndex: index >= 0 ? index : 0,
                  ),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.infoBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: AppColors.infoBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            solution.subject,
                            style: AppTextStyles.labelMedium,
                          ),
                          Text(
                            solution.getTimeAgo(),
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textGray,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  TextPreprocessor.addSpacesToText(solution.getPreviewText()),
                  style: AppTextStyles.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.successBackground,
                        borderRadius: BorderRadius.circular(AppRadius.radiusRound),
                      ),
                      child: Text(
                        'Practice: 2/3',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.successGreen,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        solution.topic,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayProgress() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final stats = appState.stats;

        return Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Today's Progress", style: AppTextStyles.headerMedium),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardLightPurple.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
                  border: Border.all(color: AppColors.primaryPurple.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      Icons.description_outlined,
                      '${stats.totalQuestionsPracticed}',
                      'Questions',
                      AppColors.primaryPurple,
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: AppColors.borderGray,
                    ),
                    _buildStatItem(
                      Icons.show_chart,
                      stats.getAccuracyString(),
                      'Accuracy',
                      AppColors.successGreen,
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: AppColors.borderGray,
                    ),
                    _buildStatItem(
                      Icons.camera_alt_outlined,
                      '${appState.snapsUsed}',
                      'Snaps Used',
                      AppColors.infoBlue,
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

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.headerLarge.copyWith(
            color: color,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textMedium,
          ),
        ),
      ],
    );
  }
}
