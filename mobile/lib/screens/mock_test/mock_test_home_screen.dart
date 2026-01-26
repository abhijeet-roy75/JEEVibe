/// Mock Test Home Screen
/// Shows available mock tests and usage

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../providers/mock_test_provider.dart';
import '../../models/mock_test_models.dart';
import 'mock_test_screen.dart';
import 'mock_test_instructions_screen.dart';

class MockTestHomeScreen extends StatefulWidget {
  const MockTestHomeScreen({super.key});

  @override
  State<MockTestHomeScreen> createState() => _MockTestHomeScreenState();
}

class _MockTestHomeScreenState extends State<MockTestHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Defer loading to after the first frame to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<MockTestProvider>();
    // Check for active test first before loading templates
    // This ensures we show "Resume Test" if there's an active test
    await provider.checkForActiveTest();
    await provider.loadTemplates();
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
            _buildUsageCard(),
            Expanded(
              child: _buildTemplatesList(),
            ),
          ],
        ),
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(
            children: [
              // Back button with semi-transparent background
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
              // Centered title
              Expanded(
                child: Text(
                  'JEE Main Simulations',
                  style: AppTextStyles.headerWhite.copyWith(
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Balance spacer (same width as back button)
              const SizedBox(width: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsageCard() {
    return Consumer<MockTestProvider>(
      builder: (context, provider, _) {
        final usage = provider.usage;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.ctaGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Usage',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      usage?.hasUnlimited == true
                          ? 'Unlimited tests'
                          : '${usage?.used ?? 0} / ${usage?.limit ?? 1} tests used',
                      style: AppTextStyles.headerSmall.copyWith(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (usage != null && !usage.hasUnlimited)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${usage.remaining} left',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTemplatesList() {
    return Consumer<MockTestProvider>(
      builder: (context, provider, _) {
        // Show loading while checking for active test or loading templates
        if (provider.isLoadingActiveTest || provider.isLoadingTemplates) {
          return const Center(child: CircularProgressIndicator());
        }

        // Check for active test first
        if (provider.hasActiveTest) {
          return _buildActiveTestCard(provider.activeSession!);
        }

        if (provider.templates.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 64,
                  color: AppColors.textLight.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No mock tests available',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadTemplates(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.templates.length,
            itemBuilder: (context, index) {
              return _buildTemplateCard(provider.templates[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildActiveTestCard(MockTestSession session) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.warning.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.pending_actions,
                  size: 48,
                  color: AppColors.warning,
                ),
                const SizedBox(height: 16),
                Text(
                  'Test in Progress',
                  style: AppTextStyles.headerSmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  session.templateName,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${session.answeredCount}/${session.totalQuestions} answered',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Time remaining: ${_formatTime(session.timeRemainingSeconds)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  text: 'Resume Test',
                  onPressed: () => _resumeTest(session),
                  leadingIcon: Icons.play_arrow,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _showAbandonDialog(session),
                  child: Text(
                    'Abandon Test',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAbandonDialog(MockTestSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon Test?'),
        content: const Text(
          'Are you sure you want to abandon this test? Your progress will be lost and this test will not be counted in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _abandonTest(session);
            },
            child: Text(
              'Abandon',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abandonTest(MockTestSession session) async {
    try {
      final provider = context.read<MockTestProvider>();
      await provider.abandonTest();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test abandoned'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildTemplateCard(MockTestTemplate template) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showStartTestDialog(template),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Test icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Test info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (template.completed)
                        Row(
                          children: [
                            Text(
                              '${template.questionCount} Questions',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                color: AppColors.textTertiary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(
                              'Completed',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          '${template.questionCount} Questions | ${template.formattedDuration}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary.withValues(alpha: 0.5),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m ${secs}s';
  }

  void _showStartTestDialog(MockTestTemplate template) {
    final provider = context.read<MockTestProvider>();

    if (!provider.canStartNewTest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Monthly limit reached. Upgrade to take more tests.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Navigate to instructions screen (which handles starting the test)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MockTestInstructionsScreen(template: template),
      ),
    );
  }

  void _resumeTest(MockTestSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MockTestScreen(),
      ),
    );
  }
}
