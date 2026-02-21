/// Daily Quiz History Screen
/// Shows list of completed daily quizzes with pagination and tier-based filtering
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';
import '../../services/subscription_service.dart';
import '../../models/quiz_history.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../providers/offline_provider_conditional.dart';
import '../../widgets/offline/offline_banner.dart';
import '../../models/subscription_models.dart';
import '../daily_quiz_review_screen.dart';
import '../daily_quiz_loading_screen.dart';
import '../subscription/paywall_screen.dart';
import '../main_navigation_screen.dart';
import '../../widgets/responsive_layout.dart';

class DailyQuizHistoryScreen extends StatefulWidget {
  const DailyQuizHistoryScreen({super.key});

  @override
  State<DailyQuizHistoryScreen> createState() => _DailyQuizHistoryScreenState();
}

class _DailyQuizHistoryScreenState extends State<DailyQuizHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<DailyQuizHistoryItem> _quizzes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _offset = 0;
  static const int _limit = 20;
  int? _historyDaysLimit;
  bool _isUnlimited = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadQuizHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreQuizzes();
    }
  }

  Future<void> _loadQuizHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _quizzes.clear();
      _offset = 0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Please sign in to view history');
      }

      final authToken = await user.getIdToken();
      if (authToken == null) {
        throw Exception('Authentication failed');
      }

      // Get tier limits for history filtering
      final subscriptionService =
          Provider.of<SubscriptionService>(context, listen: false);
      _historyDaysLimit =
          subscriptionService.status?.limits.solutionHistoryDays ?? 7;
      _isUnlimited = _historyDaysLimit == -1;

      final response = await ApiService.getDailyQuizHistory(
        authToken: authToken,
        limit: _limit,
        offset: 0,
        days: _isUnlimited ? null : _historyDaysLimit,
      );

      final historyResponse = DailyQuizHistoryResponse.fromJson(response);

      setState(() {
        _quizzes.addAll(historyResponse.quizzes);
        _hasMore = historyResponse.hasMore;
        _offset = _limit;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreQuizzes() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final authToken = await user.getIdToken();
      if (authToken == null) return;

      final response = await ApiService.getDailyQuizHistory(
        authToken: authToken,
        limit: _limit,
        offset: _offset,
        days: _isUnlimited ? null : _historyDaysLimit,
      );

      final historyResponse = DailyQuizHistoryResponse.fromJson(response);

      setState(() {
        _quizzes.addAll(historyResponse.quizzes);
        _hasMore = historyResponse.hasMore;
        _offset += _limit;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadQuizHistory();
  }

  void _navigateToQuizReview(DailyQuizHistoryItem quiz) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final authToken = await user.getIdToken();
      if (authToken == null) return;

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DailyQuizReviewScreen(
            quizId: quiz.quizId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load quiz: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final offlineProvider = Provider.of<OfflineProvider>(context);
    final isOffline = offlineProvider.isOffline;

    return Column(
      children: [
        // Offline banner
        if (isOffline) const OfflineBanner(),

        // Content
        Expanded(
          child: _buildContent(isOffline),
        ),

        // Fixed footer with CTA button
        if (!_isLoading) _buildFooter(),
      ],
    );
  }

  Widget _buildFooter() {
    final subscriptionService =
        Provider.of<SubscriptionService>(context, listen: false);
    final quizUsage = subscriptionService.getUsageInfo(UsageType.dailyQuiz);

    final isLimitReached = quizUsage != null &&
        !quizUsage.isUnlimited &&
        quizUsage.remaining <= 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        8 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          gradient: isLimitReached ? null : AppColors.ctaGradient,
          color: isLimitReached ? Colors.white : null,
          borderRadius: BorderRadius.circular(12),
          border: isLimitReached
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
          boxShadow: isLimitReached ? null : AppShadows.buttonShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (isLimitReached) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PaywallScreen(
                      featureName: 'Daily Quiz',
                      usageType: UsageType.dailyQuiz,
                      limitReachedMessage:
                          "You've used your free daily quizzes. Upgrade for more!",
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DailyQuizLoadingScreen(),
                  ),
                ).then((_) => _loadQuizHistory());
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isLimitReached ? Icons.workspace_premium_rounded : Icons.quiz,
                  color: isLimitReached ? AppColors.primary : Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  isLimitReached ? 'Upgrade for More Quizzes' : 'Start New Quiz',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isLimitReached ? AppColors.primary : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isOffline) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_quizzes.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: isOffline ? () async {} : _onRefresh,
      color: AppColors.primary,
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isDesktopViewport(context) ? 900 : double.infinity,
          ),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _quizzes.length + (_hasMore ? 1 : 0) + (_showUpgradeBanner ? 1 : 0),
            itemBuilder: (context, index) {
              // Show loading indicator at bottom
              if (index == _quizzes.length && _hasMore) {
                return _buildLoadingMoreIndicator();
              }

              // Show upgrade banner if applicable
              if (index == _quizzes.length + (_hasMore ? 1 : 0) && _showUpgradeBanner) {
                return _buildUpgradeBanner();
              }

              return _buildQuizCard(_quizzes[index], index);
            },
          ),
        ),
      ),
    );
  }

  bool get _showUpgradeBanner {
    // Don't show upgrade banner for Ultra tier (highest tier, 365 days history)
    final subscriptionService =
        Provider.of<SubscriptionService>(context, listen: false);
    final isUltra = subscriptionService.status?.subscription.isUltra ?? false;

    return !_isUnlimited && !_hasMore && _quizzes.isNotEmpty && !isUltra;
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading quiz history...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error.withAlpha(180),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: AppTextStyles.headerMedium.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Failed to load quiz history',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadQuizHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.quiz_outlined,
                size: 40,
                color: AppColors.primary.withAlpha(180),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No quizzes completed yet',
              style: AppTextStyles.headerMedium.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first Daily Quiz to see your history here',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _navigateToHome,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Take your first quiz'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCard(DailyQuizHistoryItem quiz, int index) {
    final accuracyColor = _getAccuracyColor(quiz.accuracy);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _navigateToQuizReview(quiz),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Quiz number badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '#${quiz.quizNumber}',
                      style: AppTextStyles.headerSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Quiz info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quiz ${quiz.quizNumber}',
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(quiz.completedAt),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Score and accuracy
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accuracyColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        quiz.accuracyPercent,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: accuracyColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quiz.scoreDisplay,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary.withAlpha(150),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildUpgradeBanner() {
    return Container(
      margin: EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withAlpha(25),
            AppColors.secondary.withAlpha(25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withAlpha(50),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Viewing last $_historyDaysLimit days',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PaywallScreen(
                      featureName: 'Extended History',
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Text('Unlock more history'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    final percent = accuracy * 100;
    if (percent >= 80) return AppColors.success;
    if (percent >= 60) return AppColors.warning;
    return AppColors.error;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final quizDate = DateTime(date.year, date.month, date.day);

    if (quizDate == today) {
      return 'Today';
    } else if (quizDate == yesterday) {
      return 'Yesterday';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}';
    }
  }
}
