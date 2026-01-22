/// Chapter Picker Screen
/// Allows Pro/Ultra users to select any chapter for practice
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/analytics_data.dart';
import '../../services/analytics_service.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/subscription_service.dart';
import '../../services/offline/connectivity_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'chapter_practice_loading_screen.dart';

class ChapterPickerScreen extends StatefulWidget {
  const ChapterPickerScreen({super.key});

  @override
  State<ChapterPickerScreen> createState() => _ChapterPickerScreenState();
}

class _ChapterPickerScreenState extends State<ChapterPickerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _authToken;

  // Data cache per subject
  final Map<String, List<ChapterMastery>> _chaptersCache = {};
  final Map<String, bool> _loadingState = {
    'physics': false,
    'chemistry': false,
    'maths': false,
  };
  final Map<String, String?> _errorState = {
    'physics': null,
    'chemistry': null,
    'maths': null,
  };

  static const List<String> _subjects = ['physics', 'chemistry', 'maths'];
  static const List<String> _subjectLabels = ['Physics', 'Chemistry', 'Mathematics'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _initAuth();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initAuth() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getIdToken();
    if (mounted) {
      if (token == null) {
        // Set error state for all subjects if auth fails
        setState(() {
          for (final subject in _subjects) {
            _errorState[subject] = 'Authentication required. Please log in again.';
          }
        });
        return;
      }

      // Verify user has Pro/Ultra subscription (security check)
      final subscriptionService = SubscriptionService();
      await subscriptionService.fetchStatus(token);
      if (subscriptionService.isFree) {
        // Free users shouldn't access this screen - pop back
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      setState(() {
        _authToken = token;
      });
      // Load first tab immediately
      _loadChaptersForSubject(_subjects[0]);
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final subject = _subjects[_tabController.index];
      // Only load if not already cached
      if (!_chaptersCache.containsKey(subject)) {
        _loadChaptersForSubject(subject);
      }
    }
  }

  Future<void> _loadChaptersForSubject(String subject) async {
    if (_authToken == null) return;
    if (_loadingState[subject] == true) return;

    // Check connectivity first
    final connectivityService = ConnectivityService();
    final isOnline = await connectivityService.checkRealConnectivity();
    if (!isOnline) {
      if (mounted) {
        setState(() {
          _errorState[subject] = 'No internet connection. Please check your network and try again.';
        });
      }
      return;
    }

    setState(() {
      _loadingState[subject] = true;
      _errorState[subject] = null;
    });

    try {
      final chapters = await AnalyticsService.getChaptersBySubject(
        authToken: _authToken!,
        subject: subject,
      );

      if (mounted) {
        setState(() {
          _chaptersCache[subject] = chapters;
          _loadingState[subject] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');

        // Handle token expiry - refresh and retry once
        if (errorMessage.contains('Authentication required') ||
            errorMessage.contains('401')) {
          await _refreshTokenAndRetry(subject);
          return;
        }

        setState(() {
          _errorState[subject] = errorMessage;
          _loadingState[subject] = false;
        });
      }
    }
  }

  Future<void> _refreshTokenAndRetry(String subject) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final newToken = await authService.getIdToken(forceRefresh: true);

    if (newToken == null) {
      if (mounted) {
        setState(() {
          _errorState[subject] = 'Session expired. Please log in again.';
          _loadingState[subject] = false;
        });
      }
      return;
    }

    _authToken = newToken;

    // Retry the request with new token
    try {
      final chapters = await AnalyticsService.getChaptersBySubject(
        authToken: _authToken!,
        subject: subject,
      );

      if (mounted) {
        setState(() {
          _chaptersCache[subject] = chapters;
          _loadingState[subject] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorState[subject] = e.toString().replaceFirst('Exception: ', '');
          _loadingState[subject] = false;
        });
      }
    }
  }

  Future<void> _refreshCurrentSubject() async {
    final subject = _subjects[_tabController.index];
    _chaptersCache.remove(subject);
    await _loadChaptersForSubject(subject);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _subjects.map((subject) => _buildSubjectContent(subject)).toList(),
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(
            children: [
              // Back button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
              // Centered title
              Expanded(
                child: Text(
                  'Choose Chapter',
                  style: AppTextStyles.headerWhite.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Spacer to balance the back button
              const SizedBox(width: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: AppColors.ctaGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textTertiary,
          labelStyle: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: AppTextStyles.labelMedium,
          padding: const EdgeInsets.all(4),
          tabs: _subjectLabels.map((label) => Tab(text: label)).toList(),
        ),
      ),
    );
  }

  Widget _buildSubjectContent(String subject) {
    final isLoading = _loadingState[subject] == true;
    final error = _errorState[subject];
    final chapters = _chaptersCache[subject];

    if (isLoading && chapters == null) {
      return _buildLoadingState();
    }

    if (error != null && chapters == null) {
      return _buildErrorState(error, subject);
    }

    if (chapters == null || chapters.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshCurrentSubject,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: chapters.length,
        itemBuilder: (context, index) {
          final chapter = chapters[index];
          return _buildChapterCard(chapter, subject);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading chapters...',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, String subject) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load chapters',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _loadChaptersForSubject(subject),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
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
            Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No chapters available',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chapters will appear here once they are added.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterCard(ChapterMastery chapter, String subject) {
    final hasPracticed = chapter.attempts > 0;

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
          onTap: () => _navigateToPractice(chapter, subject),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Chapter icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getSubjectColor(subject).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getSubjectIcon(subject),
                    color: _getSubjectColor(subject),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Chapter info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.chapterName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (hasPracticed)
                        _buildPracticedStats(chapter)
                      else
                        Text(
                          'Not practiced yet',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                            fontStyle: FontStyle.italic,
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

  Widget _buildPracticedStats(ChapterMastery chapter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${chapter.attempts} ${chapter.attempts == 1 ? 'practice' : 'practices'}',
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
              '${chapter.accuracy.toInt()}% accuracy',
              style: AppTextStyles.caption.copyWith(
                color: _getAccuracyColor(chapter.accuracy),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${chapter.correct}/${chapter.total} correct',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textTertiary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Future<void> _navigateToPractice(ChapterMastery chapter, String subject) async {
    // Capitalize subject for display (maths -> Mathematics, physics -> Physics)
    final displaySubject = subject == 'maths'
        ? 'Mathematics'
        : subject[0].toUpperCase() + subject.substring(1);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterPracticeLoadingScreen(
          chapterKey: chapter.chapterKey,
          chapterName: chapter.chapterName,
          subject: displaySubject,
        ),
      ),
    );

    // Invalidate cache and refresh data when returning from practice
    // This ensures stats are up-to-date after completing a practice session
    if (mounted) {
      _chaptersCache.remove(subject);
      _loadChaptersForSubject(subject);
    }
  }

  Color _getSubjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'physics':
        return AppColors.subjectPhysics;
      case 'chemistry':
        return AppColors.subjectChemistry;
      case 'maths':
      case 'mathematics':
        return AppColors.subjectMathematics;
      default:
        return AppColors.primary;
    }
  }

  IconData _getSubjectIcon(String subject) {
    switch (subject.toLowerCase()) {
      case 'physics':
        return Icons.bolt;
      case 'chemistry':
        return Icons.science;
      case 'maths':
      case 'mathematics':
        return Icons.functions;
      default:
        return Icons.menu_book;
    }
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 80) return AppColors.success;
    if (accuracy >= 60) return AppColors.warning;
    return AppColors.error;
  }
}
