/// Chapter List Screen - 24-Month Countdown Timeline
/// Shows all chapters with lock/unlock status based on JEE countdown
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analytics_data.dart';
import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../services/firebase/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:jeevibe_mobile/theme/app_platform_sizing.dart';
import '../widgets/subject_icon_widget.dart';
import '../widgets/app_header.dart';
import 'assessment_intro_screen.dart';
import 'chapter_practice/chapter_practice_loading_screen.dart';

class ChapterListScreen extends StatefulWidget {
  const ChapterListScreen({super.key});

  @override
  State<ChapterListScreen> createState() => _ChapterListScreenState();

  /// Static method to refresh unlock data - called when navigating back to this screen
  static void refreshIfNeeded(BuildContext context) {
    final state = context.findAncestorStateOfType<_ChapterListScreenState>();
    state?._loadUnlockData();
  }
}

class _ChapterListScreenState extends State<ChapterListScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  String? _authToken;

  // Chapter unlock data from countdown timeline
  Map<String, dynamic>? _unlockData;
  Set<String> _unlockedChapterKeys = {};
  List<String> _fullChapterOrder = []; // All chapters in unlock order
  int _currentMonth = 0;
  int _monthsUntilExam = 0;
  bool _isLoadingUnlockData = true;

  // Chapter mastery data per subject
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
    WidgetsBinding.instance.addObserver(this);
    _initData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh unlock data when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _loadUnlockData();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getIdToken();

    if (!mounted) return;

    if (token == null) {
      setState(() {
        _errorState['physics'] = 'Authentication required';
        _isLoadingUnlockData = false;
      });
      return;
    }

    setState(() {
      _authToken = token;
    });

    // Load unlock data first (needed to show lock states)
    await _loadUnlockData();

    // Then load first subject's chapters
    _loadChaptersForSubject(_subjects[0]);
  }

  Future<void> _loadUnlockData() async {
    if (_authToken == null) return;

    try {
      final unlockData = await ApiService.getUnlockedChapters(
        authToken: _authToken!,
      );

      if (mounted) {
        final unlockedList = unlockData['unlockedChapters'] as List? ?? [];
        debugPrint('📊 ChapterListScreen: Received ${unlockedList.length} unlocked chapters');
        if (unlockedList.isNotEmpty) {
          debugPrint('📊 First 3 unlocked keys: ${unlockedList.take(3).join(", ")}');
        }

        setState(() {
          _unlockData = unlockData;
          _unlockedChapterKeys = Set<String>.from(unlockedList);
          _fullChapterOrder = List<String>.from(
            unlockData['fullChapterOrder'] as List? ?? []
          );
          _currentMonth = unlockData['currentMonth'] as int? ?? 0;
          _monthsUntilExam = unlockData['monthsUntilExam'] as int? ?? 0;
          _isLoadingUnlockData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUnlockData = false;
          // Default to all unlocked on error
          _unlockedChapterKeys = {};
        });
      }
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final subject = _subjects[_tabController.index];
      if (!_chaptersCache.containsKey(subject)) {
        _loadChaptersForSubject(subject);
      }
    }
  }

  Future<void> _loadChaptersForSubject(String subject) async {
    if (_authToken == null) return;
    if (_loadingState[subject] == true) return;

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
        // Debug: Log first few chapter keys from mastery data
        if (chapters.isNotEmpty) {
          debugPrint('📚 Chapter mastery data ($subject): ${chapters.take(3).map((c) => c.chapterKey).join(", ")}');
        }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Standard gradient header
          AppHeader(
            leading: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  // Trigger home screen refresh when going back
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (context.mounted) {
                      try {
                        AssessmentIntroScreen.refreshIfNeeded(context);
                      } catch (e) {
                        // Ignore if home screen is not in widget tree
                      }
                    }
                  });
                },
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ),
            title: Text(
              'All Chapters',
              style: AppTextStyles.headerWhite.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: !_isLoadingUnlockData && _monthsUntilExam > 0
                ? Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$_monthsUntilExam months to JEE',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock_open,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_unlockedChapterKeys.length}/${_fullChapterOrder.isNotEmpty ? _fullChapterOrder.length : 66} unlocked',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
            bottomPadding: 16,
          ),
          // Subject Tabs
          Container(
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
                tabs: const [
                  Tab(text: 'Physics'),
                  Tab(text: 'Chemistry'),
                  Tab(text: 'Mathematics'),
                ],
              ),
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _subjects.map((subject) {
                return _buildSubjectChapterList(subject);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectChapterList(String subject) {
    final isLoading = _loadingState[subject] ?? false;
    final error = _errorState[subject];
    final chapters = _chaptersCache[subject];

    if (isLoading || _isLoadingUnlockData) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
                error,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _loadChaptersForSubject(subject),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (chapters == null || chapters.isEmpty) {
      return Center(
        child: Text(
          'No chapters available',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    // Sort chapters by unlock order
    final sortedChapters = _sortChaptersByUnlockOrder(chapters);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedChapters.length,
      itemBuilder: (context, index) {
        final chapter = sortedChapters[index];
        final chapterKey = chapter.chapterKey;
        final isUnlocked = _unlockedChapterKeys.contains(chapterKey);

        // Debug: Log first few chapters to compare keys
        if (index < 3) {
          debugPrint('🔍 Chapter #$index: key="$chapterKey" (${chapter.chapterName}), isUnlocked=$isUnlocked');
          if (!isUnlocked && _unlockedChapterKeys.isNotEmpty) {
            // Check if any unlocked key is similar
            final similar = _unlockedChapterKeys.where((k) => k.contains(chapterKey) || chapterKey.contains(k)).toList();
            if (similar.isNotEmpty) {
              debugPrint('   ⚠️  Found similar keys: ${similar.take(3).join(", ")}');
            }
          }
        }

        return _buildChapterCard(chapter, isUnlocked);
      },
    );
  }

  /// Sort chapters by unlock order from the schedule
  /// Unlocked chapters first (in unlock order), then locked chapters (in future unlock order)
  List<ChapterMastery> _sortChaptersByUnlockOrder(List<ChapterMastery> chapters) {
    if (_fullChapterOrder.isEmpty) {
      // Fallback: no sorting if we don't have the order
      return chapters;
    }

    // Create a map of chapter_key -> unlock position (lower = unlocks earlier)
    final Map<String, int> unlockPosition = {};
    for (int i = 0; i < _fullChapterOrder.length; i++) {
      unlockPosition[_fullChapterOrder[i]] = i;
    }

    // Sort chapters by unlock position
    final sortedChapters = List<ChapterMastery>.from(chapters);
    sortedChapters.sort((a, b) {
      final posA = unlockPosition[a.chapterKey] ?? 999999;
      final posB = unlockPosition[b.chapterKey] ?? 999999;
      return posA.compareTo(posB);
    });

    return sortedChapters;
  }

  Widget _buildChapterCard(ChapterMastery chapter, bool isUnlocked) {
    // Get subject from chapter key (format: "physics_laws_of_motion")
    final subject = chapter.chapterKey.split('_')[0];

    return Container(
      margin: EdgeInsets.only(bottom: PlatformSizing.spacing(12)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
        border: Border.all(
          color: isUnlocked ? AppColors.borderDefault : AppColors.textTertiary.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isUnlocked ? () {
            // Navigate to chapter practice (existing flow)
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ChapterPracticeLoadingScreen(
                  chapterKey: chapter.chapterKey,
                  chapterName: chapter.chapterName,
                  subject: subject,
                ),
              ),
            );
          } : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Lock/Unlock Icon
                Container(
                  width: PlatformSizing.spacing(40),
                  height: PlatformSizing.spacing(40),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.textTertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(PlatformSizing.radius(8)),
                  ),
                  child: Icon(
                    isUnlocked ? Icons.lock_open : Icons.lock,
                    color: isUnlocked ? AppColors.success : AppColors.textTertiary,
                    size: PlatformSizing.iconSize(20),
                  ),
                ),
                const SizedBox(width: 12),
                // Chapter Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.chapterName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isUnlocked ? AppColors.textPrimary : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isUnlocked) ...[
                        // Show accuracy for unlocked chapters
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: _getAccuracyColor(chapter.accuracy),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              chapter.total > 0
                                  ? '${chapter.correct}/${chapter.total} correct'
                                  : 'No attempts yet',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: chapter.total > 0
                                    ? _getAccuracyColor(chapter.accuracy)
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (chapter.total > 0) ...[
                              const SizedBox(width: 12),
                              Text(
                                '${chapter.accuracy.toInt()}%',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: _getAccuracyColor(chapter.accuracy),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ] else ...[
                        // Show lock message for locked chapters
                        Text(
                          'Unlocks as you progress',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Arrow icon for unlocked chapters
                if (isUnlocked)
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 70) return AppColors.success;
    if (accuracy >= 40) return AppColors.warning;
    return AppColors.error;
  }
}
