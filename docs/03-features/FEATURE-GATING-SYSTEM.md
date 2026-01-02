# Feature Gating System - Free vs Premium

## Overview

Centralized system to control which features are available in Free vs Pro tiers, making it easy to:
- Add new premium features without code changes
- A/B test different feature combinations
- Gradually roll out features to tiers
- Handle feature access consistently across mobile + backend

---

## Feature Categorization

### By Feature Type

| Feature | Free Tier | Trial | Pro Tier | Location |
|---------|-----------|-------|----------|----------|
| **Core Features** |
| Take Snaps | 5/day | Unlimited | Unlimited | Mobile + Backend |
| Daily Quizzes | 1/day (10 questions) | Unlimited | Unlimited | Mobile + Backend |
| Basic Solutions | ✅ Full access | ✅ Full access | ✅ Full access | Mobile |
| View Theta Score | ✅ Basic | ✅ Full | ✅ Full | Mobile |
| Profile Management | ✅ Full access | ✅ Full access | ✅ Full access | Mobile |
| **Premium Features** |
| Detailed Step-by-Step Solutions | ❌ | ✅ | ✅ | Mobile |
| Personal Doubt Library | ❌ | ✅ | ✅ | Mobile + Backend |
| Performance Analytics | ❌ Basic | ✅ Full | ✅ Full | Mobile |
| Subject-wise Breakdown | ❌ | ✅ | ✅ | Mobile |
| Chapter-wise Trends | ❌ | ✅ | ✅ | Mobile |
| Weak Areas Identification | ❌ | ✅ | ✅ | Mobile + Backend |
| Smart Study Recommendations | ❌ | ✅ | ✅ | Mobile + Backend |
| Predicted JEE Rank | ❌ | ✅ | ✅ | Mobile |
| Question History Export | ❌ | ✅ | ✅ | Mobile |
| Ad-free Experience | ❌ (future) | ✅ | ✅ | Mobile |

---

## Implementation Approach

### 1. Centralized Feature Registry

**File**: `backend/src/config/features.js`

**Purpose**: Single source of truth for all feature flags

```javascript
/**
 * Feature Registry
 *
 * Defines all features and their availability per tier.
 *
 * Feature Structure:
 * - id: Unique feature identifier
 * - name: Human-readable name
 * - description: What this feature does
 * - tiers: Which tiers have access
 * - type: 'usage_limit' | 'feature_flag' | 'ui_enhancement'
 * - enforcement: 'client' | 'server' | 'both'
 */

const FEATURES = {
  // Usage-limited features
  DAILY_SNAPS: {
    id: 'daily_snaps',
    name: 'Daily Snaps',
    description: 'Number of snaps allowed per day',
    type: 'usage_limit',
    enforcement: 'both',
    limits: {
      free: 5,
      trial: 999999,
      pro: 999999,
    },
    reset_frequency: 'daily', // Reset at midnight IST
  },

  DAILY_QUIZ_QUESTIONS: {
    id: 'daily_quiz_questions',
    name: 'Daily Quiz Questions',
    description: 'Number of quiz questions allowed per day',
    type: 'usage_limit',
    enforcement: 'both',
    limits: {
      free: 10,
      trial: 999999,
      pro: 999999,
    },
    reset_frequency: 'daily',
  },

  // Feature flags (binary: enabled/disabled)
  DETAILED_SOLUTIONS: {
    id: 'detailed_solutions',
    name: 'Detailed Step-by-Step Solutions',
    description: 'Show full solution breakdowns with images and explanations',
    type: 'feature_flag',
    enforcement: 'client',
    enabled_tiers: ['trial', 'pro'],
  },

  DOUBT_LIBRARY: {
    id: 'doubt_library',
    name: 'Personal Doubt Library',
    description: 'Save and organize questions for later review',
    type: 'feature_flag',
    enforcement: 'both',
    enabled_tiers: ['trial', 'pro'],
  },

  PERFORMANCE_ANALYTICS: {
    id: 'performance_analytics',
    name: 'Performance Analytics Dashboard',
    description: 'View detailed performance metrics and trends',
    type: 'feature_flag',
    enforcement: 'client',
    enabled_tiers: ['trial', 'pro'],
    sub_features: {
      BASIC_STATS: {
        id: 'basic_stats',
        name: 'Basic Statistics',
        description: 'Overall theta, accuracy, questions solved',
        enabled_tiers: ['free', 'trial', 'pro'],
      },
      SUBJECT_BREAKDOWN: {
        id: 'subject_breakdown',
        name: 'Subject-wise Breakdown',
        description: 'Performance by Physics/Chemistry/Math',
        enabled_tiers: ['trial', 'pro'],
      },
      CHAPTER_TRENDS: {
        id: 'chapter_trends',
        name: 'Chapter-wise Trends',
        description: 'Performance over time by chapter',
        enabled_tiers: ['trial', 'pro'],
      },
      WEAK_AREAS: {
        id: 'weak_areas',
        name: 'Weak Areas Identification',
        description: 'AI-identified topics needing improvement',
        enabled_tiers: ['trial', 'pro'],
      },
    },
  },

  STUDY_RECOMMENDATIONS: {
    id: 'study_recommendations',
    name: 'Smart Study Recommendations',
    description: 'AI-powered personalized study suggestions',
    type: 'feature_flag',
    enforcement: 'both',
    enabled_tiers: ['trial', 'pro'],
  },

  PREDICTED_RANK: {
    id: 'predicted_rank',
    name: 'Predicted JEE Rank',
    description: 'Estimated JEE rank based on current performance',
    type: 'feature_flag',
    enforcement: 'client',
    enabled_tiers: ['trial', 'pro'],
  },

  QUESTION_HISTORY_EXPORT: {
    id: 'question_history_export',
    name: 'Question History Export',
    description: 'Export solved questions to PDF/CSV',
    type: 'feature_flag',
    enforcement: 'client',
    enabled_tiers: ['trial', 'pro'],
  },

  AD_FREE_EXPERIENCE: {
    id: 'ad_free_experience',
    name: 'Ad-free Experience',
    description: 'No ads in the app',
    type: 'feature_flag',
    enforcement: 'client',
    enabled_tiers: ['trial', 'pro'],
    // Future: When we add ads to free tier
  },
};

/**
 * Helper function to check if a feature is enabled for a tier
 */
function isFeatureEnabled(featureId, tier) {
  const feature = FEATURES[featureId];
  if (!feature) {
    throw new Error(`Unknown feature: ${featureId}`);
  }

  if (feature.type === 'usage_limit') {
    return feature.limits[tier] > 0;
  }

  if (feature.type === 'feature_flag') {
    return feature.enabled_tiers.includes(tier);
  }

  return false;
}

/**
 * Get usage limit for a feature and tier
 */
function getFeatureLimit(featureId, tier) {
  const feature = FEATURES[featureId];
  if (!feature || feature.type !== 'usage_limit') {
    throw new Error(`Feature ${featureId} is not a usage-limited feature`);
  }

  return feature.limits[tier];
}

/**
 * Get all enabled features for a tier
 */
function getEnabledFeatures(tier) {
  const enabled = {};

  Object.keys(FEATURES).forEach(featureId => {
    const feature = FEATURES[featureId];

    if (feature.type === 'usage_limit') {
      enabled[featureId] = {
        enabled: feature.limits[tier] > 0,
        limit: feature.limits[tier],
      };
    } else if (feature.type === 'feature_flag') {
      enabled[featureId] = {
        enabled: feature.enabled_tiers.includes(tier),
      };
    }

    // Handle sub-features
    if (feature.sub_features) {
      enabled[featureId].sub_features = {};
      Object.keys(feature.sub_features).forEach(subId => {
        const subFeature = feature.sub_features[subId];
        enabled[featureId].sub_features[subId] = {
          enabled: subFeature.enabled_tiers.includes(tier),
        };
      });
    }
  });

  return enabled;
}

module.exports = {
  FEATURES,
  isFeatureEnabled,
  getFeatureLimit,
  getEnabledFeatures,
};
```

---

### 2. Backend API Enhancement

**Modify**: `GET /api/subscriptions/status`

**Add feature flags to response**:

```javascript
// backend/src/routes/subscriptions.js

const { getEnabledFeatures, getFeatureLimit } = require('../config/features');

router.get('/status', authenticateUser, async (req, res) => {
  const userId = req.user.uid;

  try {
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();

    const tier = userData.subscription_tier || 'free';

    // Get all enabled features for this tier
    const enabledFeatures = getEnabledFeatures(tier);

    // Calculate usage limits
    const dailySnapLimit = getFeatureLimit('DAILY_SNAPS', tier);
    const dailyQuizLimit = getFeatureLimit('DAILY_QUIZ_QUESTIONS', tier);

    // Check if usage needs reset (new day)
    const lastReset = userData.last_usage_reset?.toDate();
    const now = new Date();
    let snapsUsed = userData.daily_snaps_count || 0;
    let questionsUsed = userData.daily_questions_count || 0;

    if (!lastReset || !isSameDay(lastReset, now)) {
      // Reset counters
      snapsUsed = 0;
      questionsUsed = 0;
      await userDoc.ref.update({
        daily_snaps_count: 0,
        daily_questions_count: 0,
        last_usage_reset: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    res.json({
      subscription_tier: tier,
      trial_active: tier === 'trial',
      trial_days_remaining: tier === 'trial'
        ? Math.ceil((userData.trial_end_date.toDate() - now) / 86400000)
        : null,

      // Usage limits
      daily_limits: {
        snaps: {
          limit: dailySnapLimit,
          used: snapsUsed,
          remaining: Math.max(0, dailySnapLimit - snapsUsed),
          unlimited: dailySnapLimit >= 999999,
          resets_at: getNextMidnightIST(),
        },
        questions: {
          limit: dailyQuizLimit,
          used: questionsUsed,
          remaining: Math.max(0, dailyQuizLimit - questionsUsed),
          unlimited: dailyQuizLimit >= 999999,
          resets_at: getNextMidnightIST(),
        },
      },

      // Feature flags (NEW)
      features: {
        // Core features
        daily_snaps: enabledFeatures.DAILY_SNAPS,
        daily_quiz_questions: enabledFeatures.DAILY_QUIZ_QUESTIONS,

        // Premium features
        detailed_solutions: enabledFeatures.DETAILED_SOLUTIONS.enabled,
        doubt_library: enabledFeatures.DOUBT_LIBRARY.enabled,
        study_recommendations: enabledFeatures.STUDY_RECOMMENDATIONS.enabled,
        predicted_rank: enabledFeatures.PREDICTED_RANK.enabled,
        question_history_export: enabledFeatures.QUESTION_HISTORY_EXPORT.enabled,

        // Analytics sub-features
        analytics: {
          basic_stats: enabledFeatures.PERFORMANCE_ANALYTICS.sub_features.BASIC_STATS.enabled,
          subject_breakdown: enabledFeatures.PERFORMANCE_ANALYTICS.sub_features.SUBJECT_BREAKDOWN.enabled,
          chapter_trends: enabledFeatures.PERFORMANCE_ANALYTICS.sub_features.CHAPTER_TRENDS.enabled,
          weak_areas: enabledFeatures.PERFORMANCE_ANALYTICS.sub_features.WEAK_AREAS.enabled,
        },
      },
    });
  } catch (error) {
    logger.error('Error fetching subscription status', { error, userId });
    res.status(500).json({ error: 'Failed to fetch subscription status' });
  }
});
```

---

### 3. Mobile Feature Service

**File**: `mobile/lib/services/feature_service.dart` (NEW)

**Purpose**: Client-side feature flag management

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'subscription_service.dart';

/// Feature Service
///
/// Manages feature flags and gating logic.
/// Syncs with backend, caches locally for offline support.
class FeatureService {
  static const String _cacheKey = 'feature_flags_cache';
  static const Duration _cacheTTL = Duration(hours: 24);

  final SubscriptionService _subscriptionService;

  FeatureService(this._subscriptionService);

  /// Get current feature flags
  ///
  /// Returns cached flags if available and fresh, otherwise fetches from backend.
  Future<FeatureFlags> getFeatureFlags({bool forceRefresh = false}) async {
    // Try cache first
    if (!forceRefresh) {
      final cached = await _getCachedFlags();
      if (cached != null) {
        return cached;
      }
    }

    try {
      // Fetch subscription status (includes feature flags)
      final status = await _subscriptionService.getSubscriptionStatus(forceRefresh: true);
      final flags = FeatureFlags.fromSubscriptionStatus(status);

      // Cache for offline support
      await _cacheFlags(flags);

      return flags;
    } catch (e) {
      // Network error - use cached if available
      final cached = await _getCachedFlags();
      if (cached != null) {
        return cached;
      }

      // No cache, no network - default to free tier (safe default)
      return FeatureFlags.defaultFree();
    }
  }

  /// Check if a specific feature is enabled
  Future<bool> isFeatureEnabled(String featureId) async {
    final flags = await getFeatureFlags();
    return flags.isEnabled(featureId);
  }

  /// Check if user can perform an action (with usage limit check)
  ///
  /// Returns {canUse, reason} where reason explains why if blocked.
  Future<FeatureCheckResult> canUseFeature(String featureId) async {
    final flags = await getFeatureFlags();

    switch (featureId) {
      case 'daily_snaps':
        if (flags.dailySnapsUnlimited) {
          return FeatureCheckResult(canUse: true);
        }
        if (flags.dailySnapsRemaining > 0) {
          return FeatureCheckResult(canUse: true);
        }
        return FeatureCheckResult(
          canUse: false,
          reason: 'Daily snap limit reached (${flags.dailySnapsLimit}/day)',
          blockedUntil: flags.usageResetsAt,
        );

      case 'daily_quiz_questions':
        if (flags.dailyQuestionsUnlimited) {
          return FeatureCheckResult(canUse: true);
        }
        if (flags.dailyQuestionsRemaining > 0) {
          return FeatureCheckResult(canUse: true);
        }
        return FeatureCheckResult(
          canUse: false,
          reason: 'Daily quiz limit reached (${flags.dailyQuestionsLimit}/day)',
          blockedUntil: flags.usageResetsAt,
        );

      case 'detailed_solutions':
        if (flags.detailedSolutions) {
          return FeatureCheckResult(canUse: true);
        }
        return FeatureCheckResult(
          canUse: false,
          reason: 'Upgrade to Pro for detailed step-by-step solutions',
          requiresUpgrade: true,
        );

      case 'doubt_library':
        if (flags.doubtLibrary) {
          return FeatureCheckResult(canUse: true);
        }
        return FeatureCheckResult(
          canUse: false,
          reason: 'Upgrade to Pro to save questions to your doubt library',
          requiresUpgrade: true,
        );

      case 'performance_analytics':
        if (flags.analytics.subjectBreakdown) {
          return FeatureCheckResult(canUse: true);
        }
        return FeatureCheckResult(
          canUse: false,
          reason: 'Upgrade to Pro for detailed performance analytics',
          requiresUpgrade: true,
        );

      default:
        // Unknown feature - default to blocked
        return FeatureCheckResult(
          canUse: false,
          reason: 'Feature not available',
        );
    }
  }

  /// Cache flags locally
  Future<void> _cacheFlags(FeatureFlags flags) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = {
      'flags': flags.toJson(),
      'cached_at': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_cacheKey, jsonEncode(cache));
  }

  /// Get cached flags (if not expired)
  Future<FeatureFlags?> _getCachedFlags() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheStr = prefs.getString(_cacheKey);

    if (cacheStr == null) return null;

    final cache = jsonDecode(cacheStr);
    final cachedAt = DateTime.parse(cache['cached_at']);

    // Check if expired
    if (DateTime.now().difference(cachedAt) > _cacheTTL) {
      return null;
    }

    return FeatureFlags.fromJson(cache['flags']);
  }
}

/// Feature Flags Model
class FeatureFlags {
  // Usage limits
  final int dailySnapsLimit;
  final int dailySnapsUsed;
  final int dailySnapsRemaining;
  final bool dailySnapsUnlimited;

  final int dailyQuestionsLimit;
  final int dailyQuestionsUsed;
  final int dailyQuestionsRemaining;
  final bool dailyQuestionsUnlimited;

  final DateTime usageResetsAt;

  // Feature flags
  final bool detailedSolutions;
  final bool doubtLibrary;
  final bool studyRecommendations;
  final bool predictedRank;
  final bool questionHistoryExport;

  // Analytics sub-features
  final AnalyticsFeatures analytics;

  FeatureFlags({
    required this.dailySnapsLimit,
    required this.dailySnapsUsed,
    required this.dailySnapsRemaining,
    required this.dailySnapsUnlimited,
    required this.dailyQuestionsLimit,
    required this.dailyQuestionsUsed,
    required this.dailyQuestionsRemaining,
    required this.dailyQuestionsUnlimited,
    required this.usageResetsAt,
    required this.detailedSolutions,
    required this.doubtLibrary,
    required this.studyRecommendations,
    required this.predictedRank,
    required this.questionHistoryExport,
    required this.analytics,
  });

  /// Create from subscription status response
  factory FeatureFlags.fromSubscriptionStatus(SubscriptionStatus status) {
    return FeatureFlags(
      dailySnapsLimit: status.dailyLimits.snaps.limit,
      dailySnapsUsed: status.dailyLimits.snaps.used,
      dailySnapsRemaining: status.dailyLimits.snaps.remaining,
      dailySnapsUnlimited: status.dailyLimits.snaps.unlimited,
      dailyQuestionsLimit: status.dailyLimits.questions.limit,
      dailyQuestionsUsed: status.dailyLimits.questions.used,
      dailyQuestionsRemaining: status.dailyLimits.questions.remaining,
      dailyQuestionsUnlimited: status.dailyLimits.questions.unlimited,
      usageResetsAt: status.dailyLimits.snaps.resetsAt,
      detailedSolutions: status.features.detailedSolutions,
      doubtLibrary: status.features.doubtLibrary,
      studyRecommendations: status.features.studyRecommendations,
      predictedRank: status.features.predictedRank,
      questionHistoryExport: status.features.questionHistoryExport,
      analytics: status.features.analytics,
    );
  }

  /// Default free tier flags (safe default for offline/error cases)
  factory FeatureFlags.defaultFree() {
    return FeatureFlags(
      dailySnapsLimit: 5,
      dailySnapsUsed: 0,
      dailySnapsRemaining: 5,
      dailySnapsUnlimited: false,
      dailyQuestionsLimit: 10,
      dailyQuestionsUsed: 0,
      dailyQuestionsRemaining: 10,
      dailyQuestionsUnlimited: false,
      usageResetsAt: DateTime.now().add(const Duration(hours: 24)),
      detailedSolutions: false,
      doubtLibrary: false,
      studyRecommendations: false,
      predictedRank: false,
      questionHistoryExport: false,
      analytics: AnalyticsFeatures(
        basicStats: true, // Basic stats always available
        subjectBreakdown: false,
        chapterTrends: false,
        weakAreas: false,
      ),
    );
  }

  /// Check if a feature is enabled by ID
  bool isEnabled(String featureId) {
    switch (featureId) {
      case 'detailed_solutions':
        return detailedSolutions;
      case 'doubt_library':
        return doubtLibrary;
      case 'study_recommendations':
        return studyRecommendations;
      case 'predicted_rank':
        return predictedRank;
      case 'question_history_export':
        return questionHistoryExport;
      case 'analytics_subject_breakdown':
        return analytics.subjectBreakdown;
      case 'analytics_chapter_trends':
        return analytics.chapterTrends;
      case 'analytics_weak_areas':
        return analytics.weakAreas;
      default:
        return false;
    }
  }

  Map<String, dynamic> toJson() => {
    'dailySnapsLimit': dailySnapsLimit,
    'dailySnapsUsed': dailySnapsUsed,
    'dailySnapsRemaining': dailySnapsRemaining,
    'dailySnapsUnlimited': dailySnapsUnlimited,
    'dailyQuestionsLimit': dailyQuestionsLimit,
    'dailyQuestionsUsed': dailyQuestionsUsed,
    'dailyQuestionsRemaining': dailyQuestionsRemaining,
    'dailyQuestionsUnlimited': dailyQuestionsUnlimited,
    'usageResetsAt': usageResetsAt.toIso8601String(),
    'detailedSolutions': detailedSolutions,
    'doubtLibrary': doubtLibrary,
    'studyRecommendations': studyRecommendations,
    'predictedRank': predictedRank,
    'questionHistoryExport': questionHistoryExport,
    'analytics': analytics.toJson(),
  };

  factory FeatureFlags.fromJson(Map<String, dynamic> json) => FeatureFlags(
    dailySnapsLimit: json['dailySnapsLimit'],
    dailySnapsUsed: json['dailySnapsUsed'],
    dailySnapsRemaining: json['dailySnapsRemaining'],
    dailySnapsUnlimited: json['dailySnapsUnlimited'],
    dailyQuestionsLimit: json['dailyQuestionsLimit'],
    dailyQuestionsUsed: json['dailyQuestionsUsed'],
    dailyQuestionsRemaining: json['dailyQuestionsRemaining'],
    dailyQuestionsUnlimited: json['dailyQuestionsUnlimited'],
    usageResetsAt: DateTime.parse(json['usageResetsAt']),
    detailedSolutions: json['detailedSolutions'],
    doubtLibrary: json['doubtLibrary'],
    studyRecommendations: json['studyRecommendations'],
    predictedRank: json['predictedRank'],
    questionHistoryExport: json['questionHistoryExport'],
    analytics: AnalyticsFeatures.fromJson(json['analytics']),
  );
}

class AnalyticsFeatures {
  final bool basicStats;
  final bool subjectBreakdown;
  final bool chapterTrends;
  final bool weakAreas;

  AnalyticsFeatures({
    required this.basicStats,
    required this.subjectBreakdown,
    required this.chapterTrends,
    required this.weakAreas,
  });

  Map<String, dynamic> toJson() => {
    'basicStats': basicStats,
    'subjectBreakdown': subjectBreakdown,
    'chapterTrends': chapterTrends,
    'weakAreas': weakAreas,
  };

  factory AnalyticsFeatures.fromJson(Map<String, dynamic> json) => AnalyticsFeatures(
    basicStats: json['basicStats'],
    subjectBreakdown: json['subjectBreakdown'],
    chapterTrends: json['chapterTrends'],
    weakAreas: json['weakAreas'],
  );
}

class FeatureCheckResult {
  final bool canUse;
  final String? reason;
  final DateTime? blockedUntil;
  final bool requiresUpgrade;

  FeatureCheckResult({
    required this.canUse,
    this.reason,
    this.blockedUntil,
    this.requiresUpgrade = false,
  });
}
```

---

### 4. UI Usage Examples

#### Example 1: Snap Camera - Check Daily Limit

```dart
// mobile/lib/screens/snap/snap_camera_screen.dart

class SnapCameraScreen extends StatelessWidget {
  final FeatureService _featureService = FeatureService(SubscriptionService());

  Future<void> _takeSnap() async {
    // Check if user can take snap
    final check = await _featureService.canUseFeature('daily_snaps');

    if (!check.canUse) {
      // Show paywall or limit reached dialog
      if (check.requiresUpgrade) {
        _showPaywall(context, trigger: 'daily_snap_limit');
      } else {
        _showLimitReachedDialog(
          context,
          message: check.reason!,
          resetsAt: check.blockedUntil!,
        );
      }
      return;
    }

    // Proceed with snap...
    final snapResult = await _captureAndProcessSnap();

    // Backend will increment counter server-side
  }
}
```

#### Example 2: Solution Screen - Show Detailed Steps

```dart
// mobile/lib/screens/solution/solution_screen.dart

class SolutionScreen extends StatelessWidget {
  final FeatureService _featureService = FeatureService(SubscriptionService());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FeatureFlags>(
      future: _featureService.getFeatureFlags(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }

        final flags = snapshot.data!;

        return Column(
          children: [
            // Basic solution (always shown)
            _buildBasicSolution(),

            // Detailed solution (Pro only)
            if (flags.detailedSolutions)
              _buildDetailedStepByStep()
            else
              _buildUpgradePrompt(
                feature: 'Detailed Step-by-Step Solutions',
                description: 'Get complete explanations with images and formulas',
              ),
          ],
        );
      },
    );
  }

  Widget _buildUpgradePrompt({required String feature, required String description}) {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryPurple.withOpacity(0.1), AppColors.accentBlue.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_outline, color: AppColors.primaryPurple, size: 32),
          SizedBox(height: 8),
          Text(
            feature,
            style: AppTextStyles.headingSmall.copyWith(color: AppColors.primaryPurple),
          ),
          SizedBox(height: 4),
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _showPaywall(context, trigger: 'detailed_solutions'),
            child: Text('Upgrade to Pro →'),
          ),
        ],
      ),
    );
  }
}
```

#### Example 3: Analytics Screen - Conditional Rendering

```dart
// mobile/lib/screens/analytics/analytics_screen.dart

class AnalyticsScreen extends StatelessWidget {
  final FeatureService _featureService = FeatureService(SubscriptionService());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FeatureFlags>(
      future: _featureService.getFeatureFlags(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();

        final flags = snapshot.data!;

        return ListView(
          children: [
            // Basic stats (always available)
            if (flags.analytics.basicStats)
              _buildBasicStatsCard(),

            // Subject breakdown (Pro only)
            if (flags.analytics.subjectBreakdown)
              _buildSubjectBreakdownCard()
            else
              _buildLockedCard(
                title: 'Subject-wise Breakdown',
                description: 'See your performance in Physics, Chemistry, and Math',
              ),

            // Chapter trends (Pro only)
            if (flags.analytics.chapterTrends)
              _buildChapterTrendsCard()
            else
              _buildLockedCard(
                title: 'Chapter-wise Trends',
                description: 'Track improvement over time by chapter',
              ),

            // Weak areas (Pro only)
            if (flags.analytics.weakAreas)
              _buildWeakAreasCard()
            else
              _buildLockedCard(
                title: 'Weak Areas Identification',
                description: 'AI identifies topics you need to focus on',
              ),

            // Predicted rank (Pro only)
            if (flags.predictedRank)
              _buildPredictedRankCard()
            else
              _buildLockedCard(
                title: 'Predicted JEE Rank',
                description: 'See your estimated rank based on current performance',
              ),
          ],
        );
      },
    );
  }

  Widget _buildLockedCard({required String title, required String description}) {
    return Card(
      margin: EdgeInsets.all(16),
      child: InkWell(
        onTap: () => _showPaywall(context, trigger: 'performance_analytics'),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: AppColors.textLight, size: 48),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.headingSmall),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap to unlock with Pro',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: AppColors.primaryPurple, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Adding New Features

### Step 1: Add to Feature Registry

```javascript
// backend/src/config/features.js

PERSONALIZED_STUDY_PLAN: {
  id: 'personalized_study_plan',
  name: 'Personalized Study Plan',
  description: 'AI-generated weekly study plan based on your performance',
  type: 'feature_flag',
  enforcement: 'both',
  enabled_tiers: ['pro'], // Only Pro for now
},
```

### Step 2: Update Backend Response

```javascript
// backend/src/routes/subscriptions.js

features: {
  // ... existing features ...
  personalized_study_plan: enabledFeatures.PERSONALIZED_STUDY_PLAN.enabled,
},
```

### Step 3: Update Mobile Model

```dart
// mobile/lib/services/feature_service.dart

class FeatureFlags {
  // ... existing fields ...
  final bool personalizedStudyPlan;

  FeatureFlags({
    // ... existing params ...
    required this.personalizedStudyPlan,
  });

  factory FeatureFlags.fromSubscriptionStatus(SubscriptionStatus status) {
    return FeatureFlags(
      // ... existing fields ...
      personalizedStudyPlan: status.features.personalizedStudyPlan,
    );
  }
}
```

### Step 4: Use in UI

```dart
if (flags.personalizedStudyPlan) {
  _showStudyPlanButton();
} else {
  _showLockedFeature('Personalized Study Plan');
}
```

**That's it!** New feature is gated across the entire app.

---

## A/B Testing Features

### Use Case: Test if "Predicted Rank" increases conversions

**Step 1: Add A/B test flag to user profile**

```javascript
// users/{userId}
{
  ab_tests: {
    predicted_rank_test: 'variant_a' | 'variant_b' | 'control',
  },
}
```

**Step 2: Modify feature check**

```javascript
// backend/src/config/features.js

function isFeatureEnabled(featureId, tier, abTests = {}) {
  const feature = FEATURES[featureId];

  // Special case: A/B test for predicted rank
  if (featureId === 'PREDICTED_RANK' && abTests.predicted_rank_test) {
    if (abTests.predicted_rank_test === 'variant_a') {
      // Show predicted rank to free users (test if it drives conversions)
      return true;
    }
    if (abTests.predicted_rank_test === 'variant_b') {
      // Show to trial users only
      return tier === 'trial';
    }
    // Control group: default behavior (Pro only)
  }

  return feature.enabled_tiers.includes(tier);
}
```

**Step 3: Track conversion by variant**

```javascript
// paywall_events
{
  event_type: 'payment_completed',
  ab_test_variant: 'variant_a',
  // ...
}
```

**Step 4: Analyze results**

```sql
-- Conversion rate by variant
SELECT
  ab_test_variant,
  COUNT(*) as users,
  SUM(CASE WHEN converted_to_pro THEN 1 ELSE 0 END) as conversions,
  (conversions / users * 100) as conversion_rate
FROM users
WHERE ab_tests.predicted_rank_test IS NOT NULL
GROUP BY ab_test_variant;
```

---

## Feature Rollout Strategy

### Gradual Rollout Example

**Scenario**: Launch "Study Recommendations" to 10% of users first

**Step 1: Add rollout percentage**

```javascript
STUDY_RECOMMENDATIONS: {
  // ... existing config ...
  rollout_percentage: 10, // Only 10% of Pro users
},
```

**Step 2: Check rollout in feature service**

```javascript
function isFeatureEnabled(featureId, tier, userId) {
  const feature = FEATURES[featureId];

  // Check tier eligibility first
  if (!feature.enabled_tiers.includes(tier)) {
    return false;
  }

  // Check rollout percentage
  if (feature.rollout_percentage && feature.rollout_percentage < 100) {
    // Deterministic: same user always gets same result
    const userHash = hashString(userId);
    const userBucket = userHash % 100; // 0-99

    if (userBucket >= feature.rollout_percentage) {
      return false; // User not in rollout group
    }
  }

  return true;
}
```

**Step 3: Increase rollout gradually**

```
Week 1: 10% → Monitor for bugs
Week 2: 25% → Check performance metrics
Week 3: 50% → Verify backend can handle load
Week 4: 100% → Full rollout
```

---

## Summary

### Key Benefits

1. **Single Source of Truth**: All features defined in one place
2. **Easy to Modify**: Change tier availability without code changes
3. **Consistent Enforcement**: Same logic on client and server
4. **Offline Support**: Cached feature flags work offline (24h)
5. **A/B Testing**: Built-in support for experimentation
6. **Gradual Rollout**: Roll out features incrementally

### Feature Flow

```
User opens app
     ↓
Mobile calls GET /api/subscriptions/status
     ↓
Backend checks user tier
     ↓
Backend returns enabled features from registry
     ↓
Mobile caches flags locally
     ↓
UI conditionally renders based on flags
     ↓
User tries to use feature
     ↓
Mobile checks flag (fast, cached)
     ↓
Backend validates again (security)
     ↓
Feature allowed or paywall shown
```

### Next Steps

1. Implement feature registry in backend
2. Update subscription status endpoint
3. Create FeatureService in mobile
4. Add feature checks to existing UI components
5. Test with different tiers (free, trial, pro)

---

**Last Updated**: 2026-01-02
**Status**: Ready for Implementation
