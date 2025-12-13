/// All Solutions Screen - Shows all solutions for today
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/snap_data_model.dart';
import '../widgets/app_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'solution_review_screen.dart';

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
      // Get all solutions (not filtered by date) as fallback
      final allSolutions = await storage.getAllSolutions();
      
      // Get solutions for today
      var solutions = await storage.getAllSolutionsForToday();
      
      // If no solutions for today but we have solutions, show all (might be a date issue)
      if (solutions.isEmpty && allSolutions.isNotEmpty) {
        solutions = allSolutions;
      }
      
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
            ? 'No solutions found' 
            : '${_allSolutions.length} solution${_allSolutions.length == 1 ? '' : 's'} for today';
    
    return AppHeaderWithIcon(
      icon: Icons.history,
      title: 'All Solutions',
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
              'No solutions today',
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
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
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
          borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject badge - make it flexible to prevent overflow
                Flexible(
                  flex: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getSubjectColor(solution.subject).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.radiusRound),
                      border: Border.all(
                        color: _getSubjectColor(solution.subject).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      solution.subject,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: _getSubjectColor(solution.subject),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Question preview
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        solution.getPreviewText(),
                        style: AppTextStyles.bodyLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.label_outline,
                            size: 14,
                            color: AppColors.textGray,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              solution.topic,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textGray,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.textGray,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            solution.getTimeAgo(),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textGray,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Arrow icon
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textGray,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getSubjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'physics':
        return AppColors.primaryPurple;
      case 'chemistry':
        return Colors.orange;
      case 'mathematics':
      case 'math':
        return Colors.blue;
      default:
        return AppColors.primaryPurple;
    }
  }
}

