/// All Solutions Screen - Shows all snap history with metrics and filters
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../services/offline/sync_service.dart';
import '../models/snap_data_model.dart';
import '../providers/offline_provider.dart';
import '../widgets/app_header.dart';
import '../widgets/offline/offline_banner.dart';
import '../widgets/offline/cached_image_widget.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'solution_review_screen.dart';
import '../widgets/subject_icon_widget.dart';
import '../widgets/subject_filter_bar.dart';
import '../widgets/latex_widget.dart';
import '../utils/text_preprocessor.dart';
import 'home_screen.dart';

class AllSolutionsScreen extends StatefulWidget {
  final bool isInHistoryTab;

  const AllSolutionsScreen({
    super.key,
    this.isInHistoryTab = false,
  });

  @override
  State<AllSolutionsScreen> createState() => _AllSolutionsScreenState();
}

class _AllSolutionsScreenState extends State<AllSolutionsScreen> {
  List<RecentSolution> _allSolutions = [];
  List<RecentSolution> _filteredSolutions = [];
  bool _isLoading = true;
  String _selectedSubject = 'Physics';

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
      final offlineProvider = Provider.of<OfflineProvider>(context, listen: false);

      // If offline and have cached solutions, load from cache
      if (offlineProvider.isOffline && offlineProvider.offlineEnabled) {
        final cachedSolutions = await offlineProvider.getCachedSolutions();
        if (cachedSolutions.isNotEmpty) {
          final syncService = SyncService();
          final solutions = cachedSolutions
              .map((cached) => syncService.convertToRecentSolution(cached))
              .toList();
          setState(() {
            _allSolutions = solutions;
            _filterSolutions();
            _isLoading = false;
          });
          return;
        }
      }

      // Get ALL solutions from history (online mode or no cache)
      final solutions = await storage.getAllSolutions();

      setState(() {
        _allSolutions = solutions;
        _filterSolutions();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading solutions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterSolutions() {
    _filteredSolutions = _allSolutions.where((s) {
      final subject = s.subject.toLowerCase();
      if (_selectedSubject == 'Physics') return subject.contains('phys');
      if (_selectedSubject == 'Chemistry') return subject.contains('chem');
      if (_selectedSubject == 'Mathematics' || _selectedSubject == 'Maths') {
        return subject.contains('math');
      }
      return false;
    }).toList();
  }

  void _onFilterChanged(String subject) {
    setState(() {
      _selectedSubject = subject;
      _filterSolutions();
    });
  }

  Widget _buildHeader() {
    final subtitle = _isLoading
        ? 'Loading...'
        : _allSolutions.isEmpty
            ? 'No snaps found'
            : '${_allSolutions.length} snap${_allSolutions.length == 1 ? '' : 's'} in history';

    return AppHeaderWithIcon(
      leadingIcon: Icons.arrow_back,
      icon: Icons.camera_alt,
      title: 'Snap & Solve History',
      subtitle: subtitle,
      iconColor: AppColors.primaryPurple,
      iconSize: 36,
      onClose: () {
        bool found = false;
        Navigator.of(context).popUntil((route) {
          if (route.settings.name == '/snap_home') {
            found = true;
            return true;
          }
          return route.isFirst;
        });
        
        if (!found) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => HomeScreen(),
              settings: const RouteSettings(name: '/snap_home'),
            ),
          );
        }
      },
      gradient: AppColors.ctaGradient,
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
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          gradient: AppColors.ctaGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.buttonShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              bool found = false;
              Navigator.of(context).popUntil((route) {
                if (route.settings.name == '/snap_home') {
                  found = true;
                  return true;
                }
                return route.isFirst;
              });
              
              if (!found) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(),
                    settings: const RouteSettings(name: '/snap_home'),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  widget.isInHistoryTab ? 'Go to Snap & Solve' : 'Back to Snap & Solve',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    // When embedded in History tab, return just the content (no Scaffold)
    // to avoid gesture conflicts with TabBarView
    final content = Container(
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: Column(
        children: [
          if (!widget.isInHistoryTab) const OfflineBanner(),
          if (!widget.isInHistoryTab) _buildHeader(),
          // Filter bar outside of scrollable content to avoid gesture conflicts
          if (!_isLoading && _allSolutions.isNotEmpty) _buildMetricsSection(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryPurple),
                  )
                : _filteredSolutions.isEmpty
                    ? _buildEmptyState()
                    : _buildSolutionsList(),
          ),
          if (!_isLoading) _buildFooter(),
        ],
      ),
    );

    // When used as a tab in History, return content directly (no Scaffold wrapper)
    if (widget.isInHistoryTab) {
      return content;
    }

    // When used standalone, wrap in Scaffold
    return Scaffold(body: content);
  }

  Widget _buildMetricsSection() {
    if (_allSolutions.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      child: _buildMetricsSectionContent(),
    );
  }

  /// Inner metrics content without outer padding - used by both _buildMetricsSection
  /// and _buildSolutionsWithMetrics for layout flexibility
  Widget _buildMetricsSectionContent() {
    if (_allSolutions.isEmpty) return const SizedBox.shrink();

    return SubjectFilterBar(
      selectedSubject: _selectedSubject,
      onSubjectChanged: _onFilterChanged,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              color: AppColors.textGray.withValues(alpha: 0.5),
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
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        itemCount: _filteredSolutions.length,
        itemBuilder: (context, index) {
          final solution = _filteredSolutions[index];
          return Padding(
            padding: EdgeInsets.only(bottom: index < _filteredSolutions.length - 1 ? 12 : 0),
            child: _buildSolutionCard(solution),
          );
        },
      ),
    );
  }

  Widget _buildSolutionCard(RecentSolution solution) {
    return Container(
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
                  allSolutions: _filteredSolutions,
                  initialIndex: _filteredSolutions.indexOf(solution),
                ),
              ),
            ).then((_) {
              // Refresh list when returning from solution review
              _loadSolutions();
            });
          },
          borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Thumbnail or Icon
                _buildThumbnail(solution),
                const SizedBox(width: 12),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              solution.subject,
                              style: AppTextStyles.headerSmall.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            solution.getTimeAgo(),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textGray,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Use LaTeXWidget to properly render LaTeX/mathematical notation
                      SizedBox(
                        height: 34, // Approximate height for 2 lines (17px per line)
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: LaTeXWidget(
                              text: TextPreprocessor.addSpacesToText(solution.getPreviewText()),
                              textStyle: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textMedium,
                                height: 1.3,
                                fontSize: 13, // Slightly smaller for preview
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Topic Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          solution.topic.isNotEmpty ? solution.topic : 'General',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textGray,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(RecentSolution solution) {
    if (solution.imageUrl == null) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: SubjectIconWidget(subject: solution.subject, size: 24),
        ),
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: OfflineAwareImage(
        imageUrl: solution.imageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
      ),
    );
  }
}
