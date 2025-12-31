/// Assessment Intro Screen - New Home Page/Dashboard
/// Shows Initial Assessment prompt, Daily Practice (locked), and Snap & Solve
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_header.dart';
import '../widgets/priya_avatar.dart';
import '../services/storage_service.dart';
import '../services/firebase/firestore_user_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/api_service.dart';
import '../models/user_profile.dart';
import '../models/assessment_response.dart';
import '../models/snap_data_model.dart';
import '../widgets/subject_icon_widget.dart';
import '../providers/app_state_provider.dart';
import '../utils/text_preprocessor.dart';
import 'profile/profile_view_screen.dart';
import 'assessment_instructions_screen.dart';
import 'camera_screen.dart';
import 'daily_quiz_loading_screen.dart';
import 'home_screen.dart';
import 'solution_review_screen.dart';
import 'all_solutions_screen.dart';

class AssessmentIntroScreen extends StatefulWidget {
  const AssessmentIntroScreen({super.key});

  @override
  State<AssessmentIntroScreen> createState() => _AssessmentIntroScreenState();
}

class _AssessmentIntroScreenState extends State<AssessmentIntroScreen> {
  UserProfile? _userProfile;
  String _assessmentStatus = 'not_started';
  bool _isLoading = true;
  AssessmentData? _assessmentData;
  int _remainingSnaps = 5;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final storageService = StorageService();
      final status = await storageService.getAssessmentStatus();
      
      final user = FirebaseAuth.instance.currentUser;
      UserProfile? profile;
      AssessmentData? assessmentData;
      
      // Get remaining snap count from provider
      int remainingSnaps = 5;
      try {
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        // Ensure provider is initialized
        if (!appState.isInitialized) {
          await appState.initialize();
        }
        remainingSnaps = appState.snapsRemaining.clamp(0, 5);
      } catch (e) {
        debugPrint('Error getting snap count: $e');
      }
      
      if (user != null) {
        final firestoreService = FirestoreUserService();
        profile = await firestoreService.getUserProfile(user.uid);
        
        // If assessment is completed, fetch results
        if (status == 'completed') {
          try {
            final authService = Provider.of<AuthService>(context, listen: false);
            final token = await authService.getIdToken();
            
            if (token != null) {
              final result = await ApiService.getAssessmentResults(
                authToken: token,
                userId: user.uid,
              );
              
              if (result.success && result.data != null) {
                assessmentData = result.data;
                // Debug: Print subject accuracy data
                debugPrint('Assessment Data - subjectAccuracy: ${assessmentData?.subjectAccuracy}');
                debugPrint('Physics: ${assessmentData?.subjectAccuracy['physics']}');
                debugPrint('Chemistry: ${assessmentData?.subjectAccuracy['chemistry']}');
                debugPrint('Mathematics: ${assessmentData?.subjectAccuracy['mathematics']}');
              }
            }
          } catch (e) {
            debugPrint('Error fetching assessment results: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _assessmentStatus = status;
          _userProfile = profile;
          _assessmentData = assessmentData;
          _remainingSnaps = remainingSnaps;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading assessment intro data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    return DateFormat('EEEE, MMM d').format(now);
  }

  String _getUserName() {
    if (_userProfile?.firstName != null) {
      return _userProfile!.firstName!;
    }
    return 'Student';
  }

  bool get _isFirstTime => _assessmentStatus == 'not_started';
  bool get _isAssessmentPending => _assessmentStatus == 'in_progress';
  bool get _isAssessmentCompleted => _assessmentStatus == 'completed';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            // Header with logo, title, profile
            _buildHeader(),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Show results if completed, otherwise show assessment card
                    if (_isAssessmentCompleted && _assessmentData != null) ...[
                      _buildPriyaMessageCard(),
                      const SizedBox(height: 16),
                      _buildResultsCard(),
                    ] else
                      _buildAssessmentCard(),
                    const SizedBox(height: 16),
                    // Daily Practice Card (Locked)
                    _buildDailyPracticeCard(),
                    const SizedBox(height: 24),
                    // Snap & Solve Card
                    _buildSnapSolveCard(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppHeader(
      showGradient: true,
      gradient: const LinearGradient(
        colors: [Color(0xFF9333EA), Color(0xFFEC4899)], // Purple to pink
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Image.asset(
              'assets/images/JEEVibeLogo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
      title: Text(
        'Hi ${_getUserName()}! 👋',
        style: AppTextStyles.headerWhite.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          _getFormattedDate(),
          style: AppTextStyles.bodyWhite.copyWith(
            fontSize: 14,
            color: Colors.white.withOpacity(0.9),
          ),
          textAlign: TextAlign.center,
        ),
      ),
      trailing: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileViewScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white24,
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildAssessmentCard() {
    final isPending = _isAssessmentPending;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPending ? const Color(0xFFFFF8E1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isPending
              ? Border.all(color: const Color(0xFFFFB800), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Priya's avatar and title
            Row(
              children: [
                // Priya Ma'am avatar
                PriyaAvatar(size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPending ? 'Complete Your Assessment' : 'Initial Assessment',
                        style: AppTextStyles.headerSmall.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isPending)
                        Text(
                          'Ready when you are!',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textLight,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Priya Ma'am message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isPending ? Colors.white.withOpacity(0.7) : AppColors.cardLightPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isPending
                    ? 'Ready to discover your strengths? Complete the assessment in 45 minutes and I\'ll create a personalized study plan that focuses on what matters most for your JEE success. I\'m here to help you succeed! 💜'
                    : 'Hi! I\'m Priya Ma\'am. Let me discover your strengths and growth areas so I can create your perfect study plan.',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.primaryPurple,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Assessment details chips - fit on one line
            Row(
              children: [
                Expanded(
                  child: _buildDetailChip('✏️ 30 questions', isPending: isPending),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildDetailChip('⏱️ 45 minutes', isPending: isPending),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildDetailChip('📚 All subjects', isPending: isPending),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Get Started button
            Container(
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
                  onTap: () async {
                    // Set status to in_progress when user clicks Get Started
                    final storageService = StorageService();
                    await storageService.setAssessmentStatus('in_progress');
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AssessmentInstructionsScreen(),
                      ),
                    ).then((_) {
                      // Reload data when returning from instructions
                      _loadData();
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Get Started',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(String text, {bool isPending = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isPending ? Colors.white.withOpacity(0.8) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textMedium,
          fontSize: 11,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDailyPracticeCard() {
    final isUnlocked = _isAssessmentCompleted;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.ctaGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.gps_fixed,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Practice',
                        style: AppTextStyles.headerSmall.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isUnlocked
                            ? 'Personalized practice questions tailored for you'
                            : '🔒 Complete assessment to unlock personalized practice',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDetailChip('✏️ 10 questions'),
                _buildDetailChip('⏱️ ~15 min'),
                _buildDetailChip('📚 Mixed subjects'),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: isUnlocked ? AppColors.ctaGradient : null,
                color: isUnlocked ? null : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isUnlocked ? AppShadows.buttonShadow : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isUnlocked ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DailyQuizLoadingScreen(),
                      ),
                    );
                  } : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Start Practice',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: isUnlocked ? Colors.white : Colors.grey.shade600,
                            fontSize: 16,
                            fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          color: isUnlocked ? Colors.white : Colors.grey.shade600,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapSolveCard() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.ctaGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Snap & Solve',
                            style: AppTextStyles.headerSmall.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${appState.snapsRemaining} snaps remaining',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Stuck on a problem? Just snap a photo and get instant step-by-step solutions!',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 12),
                // View History link
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AllSolutionsScreen(),
                      ),
                    ).then((_) => _loadData());
                  },
                  child: Text(
                    'View History',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primaryPurple,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomeScreen(),
                            settings: const RouteSettings(name: '/snap_home'),
                          ),
                        ).then((_) => _loadData());
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Take a Photo',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildPriyaMessageCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar and title row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PriyaAvatar(size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Great Job, ${_getUserName()}! 🎉',
                        style: AppTextStyles.headerSmall.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assessment Complete',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textLight,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Message bubble
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF), // Light purple
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "I've analyzed your strengths and areas for improvement. Let's build on this with daily adaptive practice tailored for you!",
                style: AppTextStyles.bodyMedium.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.textMedium,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    // Extract accuracy values with proper type handling
    final physicsData = _assessmentData!.subjectAccuracy['physics'] as Map<String, dynamic>?;
    final chemistryData = _assessmentData!.subjectAccuracy['chemistry'] as Map<String, dynamic>?;
    final mathematicsData = _assessmentData!.subjectAccuracy['mathematics'] as Map<String, dynamic>?;
    
    final physicsAccuracy = _extractAccuracy(physicsData);
    final chemistryAccuracy = _extractAccuracy(chemistryData);
    final mathematicsAccuracy = _extractAccuracy(mathematicsData);
    
    // Debug logging
    debugPrint('Subject Accuracy Data:');
    debugPrint('  Physics: $physicsData -> $physicsAccuracy');
    debugPrint('  Chemistry: $chemistryData -> $chemistryAccuracy');
    debugPrint('  Mathematics: $mathematicsData -> $mathematicsAccuracy');
    debugPrint('  Full subjectAccuracy map: ${_assessmentData!.subjectAccuracy}');
    
    // Print theta scores per subject
    debugPrint('\n=== THETA SCORES PER SUBJECT ===');
    final thetaBySubject = _assessmentData!.thetaBySubject;
    if (thetaBySubject.isNotEmpty) {
      final physicsTheta = thetaBySubject['physics'];
      final chemistryTheta = thetaBySubject['chemistry'];
      final mathematicsTheta = thetaBySubject['mathematics'];
      
      debugPrint('Physics Theta: ${physicsTheta?['theta'] ?? 'N/A'} (Percentile: ${physicsTheta?['percentile'] ?? 'N/A'})');
      debugPrint('Chemistry Theta: ${chemistryTheta?['theta'] ?? 'N/A'} (Percentile: ${chemistryTheta?['percentile'] ?? 'N/A'})');
      debugPrint('Mathematics Theta: ${mathematicsTheta?['theta'] ?? 'N/A'} (Percentile: ${mathematicsTheta?['percentile'] ?? 'N/A'})');
      debugPrint('Overall Theta: ${_assessmentData!.overallTheta} (Percentile: ${_assessmentData!.overallPercentile})');
      debugPrint('================================\n');
    } else {
      debugPrint('No theta data available');
      debugPrint('================================\n');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and icon
            Row(
              children: [
                const Icon(
                  Icons.bar_chart,
                  size: 24,
                  color: AppColors.primaryPurple,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Assessment Results',
                  style: AppTextStyles.headerSmall.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Subject Results
            _buildSubjectResult('Physics', physicsAccuracy, AppColors.primaryPurple),
            const SizedBox(height: 12),
            _buildSubjectResult('Chemistry', chemistryAccuracy, const Color(0xFF4CAF50)),
            const SizedBox(height: 12),
            _buildSubjectResult('Mathematics', mathematicsAccuracy, const Color(0xFF2196F3)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectResult(String subject, int? accuracy, Color color) {
    final accuracyValue = accuracy ?? 0;
    final displayAccuracy = accuracy != null ? '$accuracy%' : 'N/A';
    
    // Determine feedback text and progress bar color based on thresholds
    String feedbackText;
    Color progressColor;
    
    if (accuracy == null || accuracyValue == 0) {
      feedbackText = 'Not assessed';
      progressColor = Colors.grey;
    } else if (accuracyValue < 70) {
      feedbackText = 'Needs more practice';
      progressColor = const Color(0xFFFF9800); // Orange
    } else if (accuracyValue <= 85) {
      feedbackText = 'Good progress';
      progressColor = const Color(0xFF2196F3); // Blue
    } else {
      feedbackText = 'Strong performance';
      progressColor = const Color(0xFF4CAF50); // Green
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subject name and percentage row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
              Text(
                subject,
                style: AppTextStyles.headerSmall.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              displayAccuracy,
              style: AppTextStyles.headerSmall.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: accuracyValue / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
        // Feedback text
        Text(
          feedbackText,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textLight,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
  
  int? _extractAccuracy(Map<String, dynamic>? data) {
    if (data == null) return null;
    
    final accuracy = data['accuracy'];
    if (accuracy == null) return null;
    
    if (accuracy is int) {
      return accuracy;
    } else if (accuracy is num) {
      return accuracy.toInt();
    }
    
    return null;
  }

  Widget _buildFloatingSnapButton() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppColors.ctaGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                    // Refresh data when returning
                    _loadData();
                  },
                  borderRadius: BorderRadius.circular(32),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
            // Notification badge with snap count
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${appState.snapsRemaining}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
