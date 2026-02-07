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
import '../widgets/subject_icon_widget.dart';

class ChapterListScreen extends StatefulWidget {
  const ChapterListScreen({super.key});

  @override
  State<ChapterListScreen> createState() => _ChapterListScreenState();
}

class _ChapterListScreenState extends State<ChapterListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _authToken;

  // Chapter unlock data from countdown timeline
  Map<String, dynamic>? _unlockData;
  Set<String> _unlockedChapterKeys = {};
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
    _initData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
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
        setState(() {
          _unlockData = unlockData;
          _unlockedChapterKeys = Set<String>.from(
            unlockData['unlockedChapters'] as List? ?? []
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
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'All Chapters',
          style: AppTextStyles.heading2.copyWith(color: AppColors.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // JEE Countdown Info
              if (!_isLoadingUnlockData && _monthsUntilExam > 0)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: AppColors.accentBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_monthsUntilExam months to JEE',
                            style: AppTextStyles.bodyText.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${_unlockedChapterKeys.length}/63 unlocked',
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.accentGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              // Subject Tabs
              TabBar(
                controller: _tabController,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primaryPurple,
                indicatorWeight: 3,
                labelStyle: AppTextStyles.bodyText.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Physics'),
                  Tab(text: 'Chemistry'),
                  Tab(text: 'Mathematics'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _subjects.map((subject) {
          return _buildSubjectChapterList(subject);
        }).toList(),
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
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
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
                color: AppColors.errorRed,
              ),
              const SizedBox(height: 16),
              Text(
                error,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _loadChaptersForSubject(subject),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
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
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        final chapterKey = chapter.chapterKey;
        final isUnlocked = _unlockedChapterKeys.contains(chapterKey);

        return _buildChapterCard(chapter, isUnlocked);
      },
    );
  }

  Widget _buildChapterCard(ChapterMastery chapter, bool isUnlocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked ? AppColors.borderColor : AppColors.textTertiary.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isUnlocked ? () {
            // Navigate to chapter practice (existing flow)
            Navigator.of(context).pushNamed(
              '/chapter-practice-loading',
              arguments: {
                'chapterKey': chapter.chapterKey,
                'chapterName': chapter.chapterName,
                'subject': chapter.subject,
              },
            );
          } : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Lock/Unlock Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? AppColors.accentGreen.withOpacity(0.1)
                        : AppColors.textTertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isUnlocked ? Icons.lock_open : Icons.lock,
                    color: isUnlocked ? AppColors.accentGreen : AppColors.textTertiary,
                    size: 20,
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
                        style: AppTextStyles.bodyText.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isUnlocked ? AppColors.textPrimary : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isUnlocked) ...[
                        // Show mastery for unlocked chapters
                        Row(
                          children: [
                            Icon(
                              Icons.analytics,
                              size: 14,
                              color: _getMasteryColor(chapter.masteryLevel),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${chapter.masteryLevel}% mastery',
                              style: AppTextStyles.caption.copyWith(
                                color: _getMasteryColor(chapter.masteryLevel),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${chapter.questionsAnswered} questions',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Show lock message for locked chapters
                        Text(
                          'Unlocks as you progress',
                          style: AppTextStyles.caption.copyWith(
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

  Color _getMasteryColor(int masteryLevel) {
    if (masteryLevel >= 80) return AppColors.accentGreen;
    if (masteryLevel >= 50) return AppColors.accentOrange;
    return AppColors.errorRed;
  }
}
