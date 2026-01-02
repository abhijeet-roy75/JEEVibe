/// All Solutions Screen - Shows all snap history with metrics and filters
library;

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/storage_service.dart';
import '../models/snap_data_model.dart';
import '../widgets/app_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'solution_review_screen.dart';
import '../widgets/subject_icon_widget.dart';
import '../utils/text_preprocessor.dart';
import 'home_screen.dart';

class AllSolutionsScreen extends StatefulWidget {
  const AllSolutionsScreen({super.key});

  @override
  State<AllSolutionsScreen> createState() => _AllSolutionsScreenState();
}

class _AllSolutionsScreenState extends State<AllSolutionsScreen> {
  List<RecentSolution> _allSolutions = [];
  List<RecentSolution> _filteredSolutions = [];
  bool _isLoading = true;
  String _selectedSubject = 'All';
  Map<String, int> _stats = {
    'All': 0,
    'Physics': 0,
    'Chemistry': 0,
    'Math': 0,
  };

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
      // Get ALL solutions from history
      final solutions = await storage.getAllSolutions();
      
      setState(() {
        _allSolutions = solutions;
        _calculateStats();
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

  void _calculateStats() {
    int physics = 0;
    int chemistry = 0;
    int math = 0;

    for (var s in _allSolutions) {
      final subject = s.subject.toLowerCase();
      if (subject.contains('phys')) {
        physics++;
      } else if (subject.contains('chem')) {
        chemistry++;
      } else if (subject.contains('math')) {
        math++;
      }
    }

    _stats = {
      'All': _allSolutions.length,
      'Physics': physics,
      'Chemistry': chemistry,
      'Math': math,
    };
  }

  void _filterSolutions() {
    if (_selectedSubject == 'All') {
      _filteredSolutions = List.from(_allSolutions);
    } else {
      _filteredSolutions = _allSolutions.where((s) {
        final subject = s.subject.toLowerCase();
        if (_selectedSubject == 'Physics') return subject.contains('phys');
        if (_selectedSubject == 'Chemistry') return subject.contains('chem');
        if (_selectedSubject == 'Math') return subject.contains('math');
        return false;
      }).toList();
    }
  }

  void _onFilterChanged(String subject) {
    setState(() {
      _selectedSubject = subject;
      _filterSolutions();
    });
  }

  Future<String> _resolveImageUrl(String url) async {
    if (url.startsWith('gs://')) {
      try {
        return await FirebaseStorage.instance.refFromURL(url).getDownloadURL();
      } catch (e) {
        debugPrint('Error resolving gs:// URL: $e');
        return url;
      }
    }
    return url;
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
      padding: const EdgeInsets.all(24),
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
        height: 56,
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
                  'Back to Snap and Solve',
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
                      child: CircularProgressIndicator(color: AppColors.primaryPurple),
                    )
                  : Column(
                      children: [
                        _buildMetricsSection(),
                        // Redundant filter bar removed as metrics now act as filters
                        Expanded(
                          child: _filteredSolutions.isEmpty
                              ? _buildEmptyState()
                              : _buildSolutionsList(),
                        ),
                      ],
                    ),
            ),
            if (!_isLoading) _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsSection() {
    if (_allSolutions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.priyaCardGradient,
          borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
          boxShadow: AppShadows.cardShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMetricItem('Total', 'All', _stats['All']!, SubjectIconWidget.getIcon('all'), SubjectIconWidget.getColor('all')),
            _buildMetricItem('Physics', 'Physics', _stats['Physics']!, SubjectIconWidget.getIcon('phys'), SubjectIconWidget.getColor('phys')),
            _buildMetricItem('Chemistry', 'Chemistry', _stats['Chemistry']!, SubjectIconWidget.getIcon('chem'), SubjectIconWidget.getColor('chem')),
            _buildMetricItem('Math', 'Math', _stats['Math']!, SubjectIconWidget.getIcon('math'), SubjectIconWidget.getColor('math')),
          ],
        ),
      ),
    );
  }

  // Helper colors for metrics if standard ones are not enough
  Color get warningAmberColor => const Color(0xFFF59E0B);
  Color get successGreenColor => const Color(0xFF10B981);

  Widget _buildMetricItem(String label, String subjectKey, int count, IconData icon, Color color) {
    final bool isSelected = _selectedSubject == subjectKey;
    
    return GestureDetector(
      onTap: () => _onFilterChanged(subjectKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: isSelected ? null : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: AppTextStyles.headerSmall.copyWith(
                fontSize: 16,
                color: isSelected ? color : AppColors.textDark,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 10, 
                color: isSelected ? color : AppColors.textMedium,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        itemCount: _filteredSolutions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final solution = _filteredSolutions[index];
          return _buildSolutionCard(solution);
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
                      Text(
                        TextPreprocessor.addSpacesToText(solution.getPreviewText()),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMedium,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
      return SubjectIconWidget(subject: solution.subject, size: 24);
    }

    return FutureBuilder<String>(
      future: _resolveImageUrl(solution.imageUrl!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryPurple),
              ),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              snapshot.data!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => SubjectIconWidget(subject: solution.subject, size: 20),
            ),
          ),
        );
      },
    );
  }
}
