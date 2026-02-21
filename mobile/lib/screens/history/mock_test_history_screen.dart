// Mock Test History Screen
// Shows list of completed JEE Main simulations with results

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';
import '../../models/mock_test_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../providers/offline_provider_conditional.dart';
import '../../widgets/offline/offline_banner.dart';
import '../../widgets/responsive_layout.dart';
import '../mock_test/mock_test_home_screen.dart';
import '../mock_test/mock_test_results_screen.dart';

class MockTestHistoryScreen extends StatefulWidget {
  const MockTestHistoryScreen({super.key});

  @override
  State<MockTestHistoryScreen> createState() => _MockTestHistoryScreenState();
}

class _MockTestHistoryScreenState extends State<MockTestHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<MockTestHistoryItem> _tests = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTestHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTestHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _tests.clear();
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

      final response = await ApiService.getMockTestHistory(
        authToken: authToken,
      );

      // Parse tests
      final testsList = response['tests'] as List? ?? [];
      final tests = testsList
          .map((t) => MockTestHistoryItem.fromJson(t as Map<String, dynamic>))
          .where((t) => t.isCompleted) // Only show completed tests
          .toList();

      setState(() {
        _tests.addAll(tests);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadTestHistory();
  }

  void _navigateToResults(MockTestHistoryItem test) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MockTestResultsScreen(
          testId: test.testId,
        ),
      ),
    );
  }

  void _navigateToMockTestHome() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MockTestHomeScreen(),
      ),
    ).then((_) => _loadTestHistory());
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
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isDesktopViewport(context) ? 900 : double.infinity,
          ),
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withAlpha(100), width: 1.5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: null, // Disabled - feature coming soon
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Coming Soon',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
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

    if (_tests.isEmpty) {
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
            itemCount: _tests.length,
            itemBuilder: (context, index) {
              return _buildTestCard(_tests[index], index);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading simulation history...',
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
              _errorMessage ?? 'Failed to load simulation history',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadTestHistory,
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
                Icons.assignment_outlined,
                size: 40,
                color: AppColors.primary.withAlpha(180),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No simulations completed yet',
              style: AppTextStyles.headerMedium.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first JEE Main simulation to see your results here',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard(MockTestHistoryItem test, int index) {
    final scoreColor = _getScoreColor(test.score ?? 0, test.maxScore ?? 300);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _navigateToResults(test),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Test icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.assignment,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Test info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            test.templateName,
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(test.completedAt),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Score
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: scoreColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${test.score ?? 0}/${test.maxScore ?? 300}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: scoreColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (test.percentile != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${test.percentile!.toStringAsFixed(1)}%ile',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary.withAlpha(150),
                    ),
                  ],
                ),

                // Subject breakdown
                if (test.subjectScores != null && test.subjectScores!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildSubjectChip('P', test.subjectScores!['Physics']),
                      const SizedBox(width: 8),
                      _buildSubjectChip('C', test.subjectScores!['Chemistry']),
                      const SizedBox(width: 8),
                      _buildSubjectChip('M', test.subjectScores!['Mathematics']),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectChip(String label, SubjectScore? score) {
    final subjectScore = score?.score ?? 0;
    final total = score?.total ?? 30;
    final maxMarks = total * 4; // 4 marks per question

    Color bgColor;
    Color textColor;
    switch (label) {
      case 'P':
        bgColor = const Color(0xFFE3F2FD); // Light blue
        textColor = const Color(0xFF1976D2); // Blue
        break;
      case 'C':
        bgColor = const Color(0xFFFFF3E0); // Light orange
        textColor = const Color(0xFFE65100); // Orange
        break;
      case 'M':
        bgColor = const Color(0xFFE8F5E9); // Light green
        textColor = const Color(0xFF388E3C); // Green
        break;
      default:
        bgColor = AppColors.cardLightPurple;
        textColor = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $subjectScore/$maxMarks',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Color _getScoreColor(int score, int maxScore) {
    final percent = maxScore > 0 ? (score / maxScore) * 100 : 0;
    if (percent >= 70) return AppColors.success;
    if (percent >= 40) return AppColors.warning;
    return AppColors.error;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final testDate = DateTime(date.year, date.month, date.day);

    if (testDate == today) {
      return 'Today';
    } else if (testDate == yesterday) {
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
