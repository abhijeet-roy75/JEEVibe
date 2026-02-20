/// Mock Test Home Screen
/// Shows available mock tests and usage

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_platform_sizing.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/responsive_layout.dart';
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
            // Header - Full width
            _buildHeader(),
            // Content - Constrained on desktop
            Expanded(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isDesktopViewport(context) ? 900 : double.infinity,
                  ),
                  child: Column(
                    children: [
                      _buildUsageCard(),
                      Expanded(
                        child: _buildTemplatesList(),
                      ),
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

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.ctaGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(PlatformSizing.spacing(20), PlatformSizing.spacing(16), PlatformSizing.spacing(20), PlatformSizing.spacing(20)),
          child: Row(
            children: [
              // Back button with semi-transparent background
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.all(PlatformSizing.spacing(8)),
                  constraints: const BoxConstraints(),
                ),
              ),
              // Centered title
              Expanded(
                child: Text(
                  'JEE Main Simulations',
                  style: AppTextStyles.headerWhite.copyWith(
                    fontSize: PlatformSizing.fontSize(20),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Balance spacer (same width as back button)
              SizedBox(width: PlatformSizing.spacing(36)),
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
          margin: EdgeInsets.fromLTRB(PlatformSizing.spacing(16), PlatformSizing.spacing(16), PlatformSizing.spacing(16), PlatformSizing.spacing(8)),
          padding: EdgeInsets.all(PlatformSizing.spacing(16)),
          decoration: BoxDecoration(
            gradient: AppColors.ctaGradient,
            borderRadius: BorderRadius.circular(PlatformSizing.radius(16)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: PlatformSizing.spacing(12),
                offset: Offset(PlatformSizing.spacing(0), PlatformSizing.spacing(4)),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(PlatformSizing.spacing(12)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
                ),
                child: Icon(
                  Icons.assignment,
                  color: AppColors.primary,
                  size: PlatformSizing.iconSize(24),
                ),
              ),
              SizedBox(width: PlatformSizing.spacing(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Usage',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: PlatformSizing.fontSize(13),
                      ),
                    ),
                    SizedBox(height: PlatformSizing.spacing(4)),
                    Text(
                      usage?.hasUnlimited == true
                          ? 'Unlimited tests'
                          : '${usage?.used ?? 0} / ${usage?.limit ?? 1} tests used',
                      style: AppTextStyles.headerSmall.copyWith(
                        fontSize: PlatformSizing.fontSize(16),
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (usage != null && !usage.hasUnlimited)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(PlatformSizing.radius(20)),
                  ),
                  child: Text(
                    '${usage.remaining} left',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: PlatformSizing.fontSize(13),
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
                  size: PlatformSizing.iconSize(64),
                  color: AppColors.textLight.withOpacity(0.5),
                ),
                SizedBox(height: PlatformSizing.spacing(16)),
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
            padding: EdgeInsets.all(PlatformSizing.spacing(16)),
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
      padding: EdgeInsets.all(PlatformSizing.spacing(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(PlatformSizing.spacing(24)),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(PlatformSizing.radius(16)),
              border: Border.all(
                color: AppColors.warning.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.pending_actions,
                  size: PlatformSizing.iconSize(48),
                  color: AppColors.warning,
                ),
                SizedBox(height: PlatformSizing.spacing(16)),
                Text(
                  'Test in Progress',
                  style: AppTextStyles.headerSmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
                SizedBox(height: PlatformSizing.spacing(8)),
                Text(
                  session.templateName,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: PlatformSizing.spacing(8)),
                Text(
                  '${session.answeredCount}/${session.totalQuestions} answered',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: PlatformSizing.spacing(8)),
                Text(
                  'Time remaining: ${_formatTime(session.timeRemainingSeconds)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: PlatformSizing.spacing(24)),
                GradientButton(
                  text: 'Resume Test',
                  onPressed: () => _resumeTest(session),
                  leadingIcon: Icons.play_arrow,
                ),
                SizedBox(height: PlatformSizing.spacing(12)),
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
      margin: EdgeInsets.only(bottom: PlatformSizing.spacing(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: PlatformSizing.spacing(10),
            offset: Offset(PlatformSizing.spacing(0), PlatformSizing.spacing(4)),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showStartTestDialog(template),
          borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
          child: Padding(
            padding: EdgeInsets.all(PlatformSizing.spacing(16)),
            child: Row(
              children: [
                // Test icon
                Container(
                  width: PlatformSizing.spacing(44),
                  height: PlatformSizing.spacing(44),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(PlatformSizing.radius(10)),
                  ),
                  child: Icon(
                    Icons.assignment,
                    color: AppColors.primary,
                    size: PlatformSizing.iconSize(22),
                  ),
                ),
                SizedBox(width: PlatformSizing.spacing(14)),
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
                      SizedBox(height: PlatformSizing.spacing(4)),
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
                              margin: EdgeInsets.symmetric(horizontal: PlatformSizing.spacing(6)),
                              width: PlatformSizing.spacing(3),
                              height: PlatformSizing.spacing(3),
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
                  size: PlatformSizing.iconSize(24),
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
