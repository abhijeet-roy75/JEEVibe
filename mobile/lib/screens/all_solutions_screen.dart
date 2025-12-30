/// All Solutions Screen - Shows all solutions for today
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/snap_data_model.dart';
import '../widgets/app_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'solution_review_screen.dart';
import '../widgets/subject_icon_widget.dart';

class AllSolutionsScreen extends StatefulWidget {
  const AllSolutionsScreen({super.key});

  @override
  State<AllSolutionsScreen> createState() => _AllSolutionsScreenState();
}

class _AllSolutionsScreenState extends State<AllSolutionsScreen> {
  List<RecentSolution> _allSolutions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSolutions();
  }

  Future<void> _loadSolutions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final storage = StorageService();
      // Get ALL solutions from history (not just today)
      final solutions = await storage.getAllSolutions();
      
      setState(() {
        _allSolutions = solutions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading solutions: $e');
      setState(() {
        _isLoading = false;
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
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _allSolutions.isEmpty
                      ? _buildEmptyState()
                      : _buildSolutionsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final subtitle = _isLoading 
        ? 'Loading...'
        : _allSolutions.isEmpty 
            ? 'No snaps found' 
            : '${_allSolutions.length} snap${_allSolutions.length == 1 ? '' : 's'} in history';
    
    return AppHeaderWithIcon(
      icon: Icons.history,
      title: 'Snap & Solve History',
      subtitle: subtitle,
      iconColor: AppColors.primaryPurple,
      iconSize: 40,
      onClose: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.textGray.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No snaps yet',
              style: AppTextStyles.headerMedium.copyWith(
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start snapping questions to see them here!',
              style: AppTextStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolutionsList() {
    return RefreshIndicator(
      onRefresh: _loadSolutions,
      child: ListView.builder(
        padding: AppSpacing.screenPadding,
        itemCount: _allSolutions.length,
        itemBuilder: (context, index) {
          final solution = _allSolutions[index];
          return _buildSolutionCard(solution);
        },
      ),
    );
  }

  Widget _buildSolutionCard(RecentSolution solution) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SolutionReviewScreen(
                  allSolutions: _allSolutions,
                  initialIndex: _allSolutions.indexOf(solution),
                ),
              ),
            ).then((_) {
              // Refresh list when returning from solution review
              _loadSolutions();
            });
          },
          borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SubjectIconWidget(subject: solution.subject, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            solution.subject,
                            style: AppTextStyles.headerSmall.copyWith(fontSize: 16),
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
                  solution.getPreviewText(),
                  style: AppTextStyles.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Topic capsule/badge
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.cardLightPurple.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(AppRadius.radiusRound),
                          border: Border.all(
                            color: AppColors.primaryPurple.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          solution.topic,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
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
}

