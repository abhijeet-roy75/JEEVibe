/// Mock Test Results Screen
/// Shows test results with score, percentile, and subject breakdown

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/subject_icon_widget.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/responsive_layout.dart';
import '../../models/mock_test_models.dart';
import '../../services/api_service.dart';
import '../../services/firebase/auth_service.dart';
import '../../providers/mock_test_provider.dart';
import 'mock_test_review_screen.dart';
import '../main_navigation_screen.dart';

class MockTestResultsScreen extends StatefulWidget {
  final String testId;
  final MockTestResult? result;

  const MockTestResultsScreen({
    super.key,
    required this.testId,
    this.result,
  });

  @override
  State<MockTestResultsScreen> createState() => _MockTestResultsScreenState();
}

class _MockTestResultsScreenState extends State<MockTestResultsScreen> {
  MockTestResult? _result;
  bool _isLoading = false;
  String? _error;

  // Flag to track if widget is disposed
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    if (widget.result != null) {
      _result = widget.result;
    } else {
      _loadResults();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadResults() async {
    if (_isDisposed) return;

    if (!_isDisposed && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final authService = context.read<AuthService>();
      final token = await authService.getIdToken();
      if (token == null) throw Exception('Authentication required');

      final data = await ApiService.getMockTestResults(
        authToken: token,
        testId: widget.testId,
      );

      if (_isDisposed || !mounted) return;

      setState(() {
        _result = MockTestResult.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      if (_isDisposed || !mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // Header - Full width
          _buildHeader(),
          // Content - Constrained on desktop
          Expanded(
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isDesktopViewport(context) ? 900 : double.infinity,
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _buildErrorView()
                        : _result != null
                            ? _buildResultsView()
                            : const Center(child: Text('No results')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.ctaGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  // Reset provider before navigating away
                  final mockTestProvider = context.read<MockTestProvider>();
                  mockTestProvider.reset();

                  Navigator.of(context).popUntil(
                    (route) => route.isFirst || route.settings.name == '/mock-tests',
                  );
                },
              ),
              const Expanded(
                child: Text(
                  'Test Results',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48), // Balance the close button
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'An error occurred',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadResults,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    final result = _result!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Score card
          _buildScoreCard(result),
          const SizedBox(height: 16),
          // Percentile card
          _buildPercentileCard(result),
          const SizedBox(height: 16),
          // Stats row
          _buildStatsRow(result),
          const SizedBox(height: 16),
          // Subject breakdown
          _buildSubjectBreakdown(result),
          const SizedBox(height: 24),
          // Actions
          _buildActions(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildScoreCard(MockTestResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.ctaGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Score section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Score',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${result.score}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        '/ ${result.maxScore}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      result.formattedTime,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Accuracy badge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '${_parseAccuracy(result.accuracy)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Accuracy',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentileCard(MockTestResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withOpacity(0.1),
            AppColors.success.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.success.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.trending_up,
              color: AppColors.success,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      result.percentile.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                        height: 1.0,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 2, left: 4),
                      child: Text(
                        'Percentile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'NTA Percentile (JEE Main 2026)',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(MockTestResult result) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Correct',
            result.correct.toString(),
            Colors.green,
            Icons.check_circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Incorrect',
            result.incorrect.toString(),
            Colors.red,
            Icons.cancel,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Skipped',
            result.unattempted.toString(),
            Colors.grey,
            Icons.remove_circle,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _parseAccuracy(String accuracy) {
    try {
      final value = double.parse(accuracy);
      return value.toStringAsFixed(1);
    } catch (e) {
      return accuracy;
    }
  }

  Widget _buildSubjectBreakdown(MockTestResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subject Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...['Physics', 'Chemistry', 'Mathematics'].map((subject) {
            final score = result.subjectScores[subject];
            if (score == null) return const SizedBox.shrink();
            return _buildSubjectRow(subject, score);
          }),
        ],
      ),
    );
  }

  Widget _buildSubjectRow(String subject, SubjectScore score) {
    Color color;
    switch (subject) {
      case 'Physics':
        color = AppColors.subjectPhysics;
        break;
      case 'Chemistry':
        color = AppColors.subjectChemistry;
        break;
      case 'Mathematics':
        color = AppColors.subjectMathematics;
        break;
      default:
        color = AppColors.primary;
    }

    final maxScore = score.total * 4; // 4 marks per question

    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              SubjectIconWidget(
                subject: subject,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${score.correct}/${score.total} correct',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${score.score}/$maxScore',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: maxScore > 0 ? score.score / maxScore : 0,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final result = _result!;
    return Column(
      children: [
        // Review Questions button (primary action - solid purple)
        _buildActionButton(
          icon: Icons.rate_review,
          iconColor: Colors.white,
          label: 'Review Questions',
          backgroundColor: AppColors.primaryPurple,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MockTestReviewScreen(testId: widget.testId),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // Back to Dashboard button (secondary action - gradient)
        GradientButton(
          text: 'Back to Dashboard',
          leadingIcon: Icons.home,
          size: GradientButtonSize.large,
          onPressed: () {
            // Reset provider before navigating away
            final mockTestProvider = context.read<MockTestProvider>();
            mockTestProvider.reset();

            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
              (route) => false,
            );
          },
        ),
      ],
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
      height: 56,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: effectiveTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
