/// Chapter Practice History Screen
/// Shows list of completed chapter practice sessions with subject filters
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';
import '../../services/subscription_service.dart';
import '../../models/chapter_practice_history.dart';
import '../../models/chapter_practice_models.dart';
import '../../models/daily_quiz_question.dart' show SolutionStep;
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../providers/offline_provider.dart';
import '../../widgets/offline/offline_banner.dart';
import '../../widgets/subject_icon_widget.dart';
import '../../widgets/subject_filter_bar.dart';
import '../chapter_practice/chapter_practice_review_screen.dart';
import '../chapter_list_screen.dart';
import '../subscription/paywall_screen.dart';

class ChapterPracticeHistoryScreen extends StatefulWidget {
  const ChapterPracticeHistoryScreen({super.key});

  @override
  State<ChapterPracticeHistoryScreen> createState() =>
      _ChapterPracticeHistoryScreenState();
}

class _ChapterPracticeHistoryScreenState
    extends State<ChapterPracticeHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<ChapterPracticeHistoryItem> _allSessions = []; // All loaded sessions
  List<ChapterPracticeHistoryItem> _filteredSessions = []; // Filtered for display
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _offset = 0;
  static const int _limit = 50; // Increased limit to load more for counts
  int? _historyDaysLimit;
  bool _isUnlimited = false;
  String _selectedSubject = 'Physics';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPracticeHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreSessions();
    }
  }

  Future<void> _loadPracticeHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _allSessions.clear();
      _filteredSessions = [];
      _offset = 0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Please sign in to view history');
      }

      final authToken = await user.getIdToken();
      if (authToken == null) {
        throw Exception('Authentication failed');
      }

      // Get tier limits for history filtering
      final subscriptionService =
          Provider.of<SubscriptionService>(context, listen: false);
      _historyDaysLimit =
          subscriptionService.status?.limits.solutionHistoryDays ?? 7;
      _isUnlimited = _historyDaysLimit == -1;

      final apiService = ApiService();
      // Fetch ALL sessions (no subject filter) to calculate counts
      final response = await apiService.getChapterPracticeHistory(
        authToken,
        limit: _limit,
        offset: 0,
        days: _isUnlimited ? null : _historyDaysLimit,
        subject: null, // No subject filter - get all for counts
      );

      final historyResponse = ChapterPracticeHistoryResponse.fromJson(response);

      setState(() {
        _allSessions.addAll(historyResponse.sessions);
        _hasMore = historyResponse.hasMore;
        _offset = _limit;
        _filterSessions();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _filterSessions() {
    _filteredSessions = _allSessions.where((session) {
      final subject = session.subject.toLowerCase();
      if (_selectedSubject == 'Physics') return subject.contains('phys');
      if (_selectedSubject == 'Chemistry') return subject.contains('chem');
      if (_selectedSubject == 'Mathematics') return subject.contains('math');
      return false;
    }).toList();
  }

  Future<void> _loadMoreSessions() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final authToken = await user.getIdToken();
      if (authToken == null) return;

      final apiService = ApiService();
      // Fetch more sessions (no subject filter) to add to all sessions
      final response = await apiService.getChapterPracticeHistory(
        authToken,
        limit: _limit,
        offset: _offset,
        days: _isUnlimited ? null : _historyDaysLimit,
        subject: null, // No filter - get all
      );

      final historyResponse = ChapterPracticeHistoryResponse.fromJson(response);

      setState(() {
        _allSessions.addAll(historyResponse.sessions);
        _hasMore = historyResponse.hasMore;
        _offset += _limit;
        _filterSessions();
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadPracticeHistory();
  }

  void _onSubjectFilterChanged(String subject) {
    if (_selectedSubject != subject) {
      setState(() {
        _selectedSubject = subject;
        _filterSessions();
      });
    }
  }

  void _navigateToSessionReview(ChapterPracticeHistoryItem session) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final authToken = await user.getIdToken();
      if (authToken == null) return;

      if (!mounted) return;

      // Fetch session details
      final apiService = ApiService();
      final response = await apiService.getChapterPracticeSession(
        session.sessionId,
        authToken,
      );

      if (!mounted) return;

      // The API returns { success: true, session: {..., questions: [...]} }
      final sessionJson = response['session'] as Map<String, dynamic>?;
      if (sessionJson == null) {
        throw Exception('Session data not found');
      }

      // Parse session object
      final sessionObj = ChapterPracticeSession.fromJson(sessionJson);

      // Build results from questions in the session
      final questions = sessionJson['questions'] as List<dynamic>? ?? [];
      final results = questions.map((q) {
        final questionMap = q as Map<String, dynamic>;

        // Handle correct_answer - could be String or Map
        String correctAnswer = '';
        final rawCorrectAnswer = questionMap['correct_answer'];
        if (rawCorrectAnswer is String) {
          correctAnswer = rawCorrectAnswer;
        } else if (rawCorrectAnswer is Map) {
          correctAnswer = rawCorrectAnswer['option_id']?.toString() ??
                          rawCorrectAnswer['value']?.toString() ?? '';
        }

        // Handle student_answer - could be String or Map
        String studentAnswer = '';
        final rawStudentAnswer = questionMap['student_answer'];
        if (rawStudentAnswer is String) {
          studentAnswer = rawStudentAnswer;
        } else if (rawStudentAnswer is Map) {
          studentAnswer = rawStudentAnswer['option_id']?.toString() ??
                          rawStudentAnswer['value']?.toString() ?? '';
        }

        return PracticeQuestionResult(
          questionId: questionMap['question_id']?.toString() ?? '',
          position: questionMap['position'] ?? 0,
          questionText: questionMap['question_text']?.toString() ?? '',
          questionTextHtml: questionMap['question_text_html']?.toString(),
          options: _parseOptions(questionMap['options']),
          studentAnswer: studentAnswer,
          correctAnswer: correctAnswer,
          isCorrect: questionMap['is_correct'] ?? false,
          timeTakenSeconds: questionMap['time_taken_seconds'] ?? 0,
          solutionText: questionMap['solution_text']?.toString(),
          solutionSteps: _parseSolutionSteps(questionMap['solution_steps']),
          keyInsight: questionMap['key_insight']?.toString(),
          distractorAnalysis: questionMap['distractor_analysis'] != null
              ? Map<String, String>.from(questionMap['distractor_analysis'] as Map)
              : null,
          commonMistakes: questionMap['common_mistakes'] != null
              ? List<String>.from(questionMap['common_mistakes'] as List)
              : null,
          explanation: questionMap['explanation']?.toString(),
          difficulty: questionMap['difficulty']?.toString(),
        );
      }).toList();

      if (!mounted) return;

      // Navigate to review screen with parsed data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChapterPracticeReviewScreen(
            summary: null, // Summary not returned by this API
            results: results,
            session: sessionObj,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to load session: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  List<PracticeOption> _parseOptions(dynamic rawOptions) {
    if (rawOptions == null || rawOptions is! List) return [];
    return rawOptions
        .where((o) => o != null && o is Map<String, dynamic>)
        .map((o) => PracticeOption.fromJson(o as Map<String, dynamic>))
        .toList();
  }

  List<SolutionStep> _parseSolutionSteps(dynamic rawSteps) {
    if (rawSteps == null || rawSteps is! List) return [];
    return rawSteps
        .where((s) => s != null && s is Map<String, dynamic>)
        .map((s) => SolutionStep.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final offlineProvider = Provider.of<OfflineProvider>(context);
    final isOffline = offlineProvider.isOffline;

    return Column(
      children: [
        // Offline banner
        if (isOffline) const OfflineBanner(),

        // Subject filter chips
        _buildSubjectFilters(),

        // Content
        Expanded(
          child: _buildContent(isOffline),
        ),

        // Fixed footer with CTA button
        if (!_isLoading) _buildFooter(),
      ],
    );
  }

  Widget _buildFooter() {
    final subscriptionService =
        Provider.of<SubscriptionService>(context, listen: false);
    final hasChapterPractice = subscriptionService.isChapterPracticeEnabled;

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
          gradient: hasChapterPractice ? AppColors.ctaGradient : null,
          color: hasChapterPractice ? null : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: hasChapterPractice
              ? null
              : Border.all(color: AppColors.primary, width: 1.5),
          boxShadow: hasChapterPractice ? AppShadows.buttonShadow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (hasChapterPractice) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChapterListScreen(),
                  ),
                ).then((_) => _loadPracticeHistory());
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PaywallScreen(
                      featureName: 'Chapter Practice',
                      limitReachedMessage: 'Practice any chapter with Pro!',
                    ),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasChapterPractice
                      ? Icons.menu_book_outlined
                      : Icons.workspace_premium_rounded,
                  color: hasChapterPractice ? Colors.white : AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  hasChapterPractice
                      ? 'Start Chapter Practice'
                      : 'Upgrade to Practice Any Chapter',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: hasChapterPractice ? Colors.white : AppColors.primary,
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

  Widget _buildSubjectFilters() {
    return SubjectFilterBar(
      selectedSubject: _selectedSubject,
      onSubjectChanged: _onSubjectFilterChanged,
    );
  }

  Widget _buildContent(bool isOffline) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_filteredSessions.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: isOffline ? () async {} : _onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _filteredSessions.length + (_hasMore ? 1 : 0) + (_showUpgradeBanner ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at bottom
          if (index == _filteredSessions.length && _hasMore) {
            return _buildLoadingMoreIndicator();
          }

          // Show upgrade banner at bottom if applicable
          if (index == _filteredSessions.length + (_hasMore ? 1 : 0) &&
              _showUpgradeBanner) {
            return _buildUpgradeBanner();
          }

          return _buildSessionCard(_filteredSessions[index]);
        },
      ),
    );
  }

  bool get _showUpgradeBanner {
    // Don't show upgrade banner for Ultra tier (highest tier, 365 days history)
    final subscriptionService =
        Provider.of<SubscriptionService>(context, listen: false);
    final isUltra = subscriptionService.status?.subscription.isUltra ?? false;

    return !_isUnlimited && !_hasMore && _filteredSessions.isNotEmpty && !isUltra;
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading practice history...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error.withAlpha(180),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style:
                  AppTextStyles.headerMedium.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Failed to load practice history',
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPracticeHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final subscriptionService =
        Provider.of<SubscriptionService>(context, listen: false);
    final hasChapterPractice = subscriptionService.isChapterPracticeEnabled;

    final message = 'No $_selectedSubject chapters practiced yet';

    // Subtitle guides user to use the fixed footer button
    final subtitleText = hasChapterPractice
        ? 'Start practicing any chapter to see your history here'
        : 'Practice your Focus Chapters from the Home tab to see your history here';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_outlined,
                size: 40,
                color: AppColors.primary.withAlpha(180),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style:
                  AppTextStyles.headerMedium.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              subtitleText,
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            // CTA button is in the fixed footer below
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(ChapterPracticeHistoryItem session) {
    final accuracyColor = _getAccuracyColor(session.accuracy);
    final subjectColor = _getSubjectColor(session.subject);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _navigateToSessionReview(session),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Subject icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: subjectColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: SubjectIconWidget(
                      subject: session.subject,
                      size: 24,
                      customColor: subjectColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Session info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.chapterName,
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: subjectColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              session.subjectDisplay,
                              style: AppTextStyles.caption.copyWith(
                                color: subjectColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(session.completedAt),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Score and accuracy
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accuracyColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        session.accuracyPercent,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: accuracyColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.scoreDisplay,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary.withAlpha(150),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildUpgradeBanner() {
    return Container(
      margin: EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withAlpha(25),
            AppColors.secondary.withAlpha(25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withAlpha(50),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Viewing last $_historyDaysLimit days',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PaywallScreen(
                      featureName: 'Extended History',
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Text('Unlock more history'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    final percent = accuracy * 100;
    if (percent >= 80) return AppColors.success;
    if (percent >= 60) return AppColors.warning;
    return AppColors.error;
  }

  Color _getSubjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'physics':
        return AppColors.subjectPhysics;
      case 'chemistry':
        return AppColors.subjectChemistry;
      case 'mathematics':
        return AppColors.subjectMathematics;
      default:
        return AppColors.primary;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sessionDate = DateTime(date.year, date.month, date.day);

    if (sessionDate == today) {
      return 'Today';
    } else if (sessionDate == yesterday) {
      return 'Yesterday';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}';
    }
  }
}
