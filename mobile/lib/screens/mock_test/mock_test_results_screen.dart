/// Mock Test Results Screen
/// Shows test results with score, percentile, and subject breakdown

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/subject_icon_widget.dart';
import '../../models/mock_test_models.dart';
import '../../services/api_service.dart';
import '../../services/firebase/auth_service.dart';
import 'mock_test_review_screen.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.result != null) {
      _result = widget.result;
    } else {
      _loadResults();
    }
  }

  Future<void> _loadResults() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = context.read<AuthService>();
      final token = await authService.getIdToken();
      if (token == null) throw Exception('Authentication required');

      final data = await ApiService.getMockTestResults(
        authToken: token,
        testId: widget.testId,
      );

      if (mounted) {
        setState(() {
          _result = MockTestResult.fromJson(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _buildErrorView()
                        : _result != null
                            ? _buildResultsView()
                            : const Center(child: Text('No results')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: AppColors.ctaGradient,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).popUntil(
              (route) => route.isFirst || route.settings.name == '/mock-tests',
            ),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.ctaGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Your Score',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.score}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 64,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'out of ${result.maxScore}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Time: ${result.formattedTime}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentileCard(MockTestResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.trending_up,
                color: AppColors.success,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                '${result.percentile.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
              const Text(
                '%ile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'NTA Percentile (based on JEE Main 2026 data)',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.only(bottom: 16),
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
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MockTestReviewScreen(testId: widget.testId),
                ),
              );
            },
            icon: const Icon(Icons.visibility),
            label: const Text('Review Answers'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).popUntil(
              (route) => route.isFirst,
            ),
            icon: const Icon(Icons.home),
            label: const Text('Back to Home'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
