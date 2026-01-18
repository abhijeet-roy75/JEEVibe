import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/subscription_models.dart';
import '../screens/subscription/paywall_screen.dart';
import 'api_service.dart';

/// Subscription Service
///
/// Manages subscription status, usage limits, and feature gating.
/// Provides methods to check access before using features.
class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // Cache
  SubscriptionStatus? _cachedStatus;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Error state
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Current status
  SubscriptionStatus? get status => _cachedStatus;
  SubscriptionTier get currentTier =>
      _cachedStatus?.subscription.tier ?? SubscriptionTier.free;
  bool get isFree => currentTier == SubscriptionTier.free;
  bool get isPro => currentTier == SubscriptionTier.pro;
  bool get isUltra => currentTier == SubscriptionTier.ultra;
  bool get isPaid => isPro || isUltra;

  /// Check if cache is valid
  bool get _isCacheValid {
    if (_cachedStatus == null || _lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheDuration;
  }

  /// Fetch subscription status from API
  Future<SubscriptionStatus?> fetchStatus(String authToken,
      {bool forceRefresh = false}) async {
    // Return cached if valid and not forcing refresh
    if (_isCacheValid && !forceRefresh) {
      return _cachedStatus;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/subscriptions/status'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _cachedStatus = SubscriptionStatus.fromJson(data['data']);
          _lastFetchTime = DateTime.now();
          _errorMessage = null;
        } else {
          _errorMessage = data['error'] ?? 'Failed to fetch subscription status';
        }
      } else {
        _errorMessage = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Network error: ${e.toString()}';
      // Don't clear cache on network error - use stale data
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return _cachedStatus;
  }

  /// Check if user can use a feature (without blocking)
  /// Returns true if they can use it, false if limit reached
  bool canUse(UsageType type) {
    if (_cachedStatus == null) return true; // Optimistic - allow if no data
    return _cachedStatus!.canUse(type);
  }

  /// Get remaining uses for a feature
  int getRemainingUses(UsageType type) {
    if (_cachedStatus == null) return -1; // Assume unlimited if no data
    return _cachedStatus!.getRemainingUses(type);
  }

  /// Get usage info for a feature
  UsageInfo? getUsageInfo(UsageType type) {
    return _cachedStatus?.usage.getUsage(type);
  }

  /// Check and show paywall if needed
  /// Returns true if user can proceed, false if blocked
  Future<bool> gatekeepFeature(
    BuildContext context,
    UsageType type,
    String featureName,
    String authToken,
  ) async {
    // Force refresh status to get latest usage counts
    await fetchStatus(authToken, forceRefresh: true);

    if (_cachedStatus == null) {
      // Allow if we couldn't fetch - backend will handle the check
      return true;
    }

    if (canUse(type)) {
      return true;
    }

    // Navigate directly to paywall instead of showing dialog
    if (context.mounted) {
      await _navigateToPaywall(context, type, featureName);
    }
    return false;
  }

  /// Navigate to paywall screen with context about which limit was reached
  Future<void> _navigateToPaywall(
    BuildContext context,
    UsageType type,
    String featureName,
  ) async {
    final tier = currentTier;

    // Determine the appropriate message for the paywall
    String? limitMessage;
    if (tier == SubscriptionTier.free) {
      limitMessage = 'You\'ve used your free daily $featureName. Upgrade for more!';
    } else {
      limitMessage = 'You\'ve reached your daily $featureName limit.';
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaywallScreen(
          limitReachedMessage: limitMessage,
          featureName: featureName,
        ),
      ),
    );
  }

  /// Update local usage after successful action
  /// This provides immediate feedback without waiting for API refresh
  void updateLocalUsage(UsageType type) {
    if (_cachedStatus == null) return;

    // Create updated usage info
    final currentUsage = _cachedStatus!.usage.getUsage(type);
    if (currentUsage.isUnlimited) return;

    // We can't directly modify the immutable models, so just invalidate cache
    // This forces a refresh on next check
    _lastFetchTime = null;
  }

  /// Clear cached status (on logout)
  void clearCache() {
    _cachedStatus = null;
    _lastFetchTime = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Fetch available plans
  Future<List<PurchasablePlan>> fetchPlans() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/subscriptions/plans'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final plans = (data['data']['plans'] as List<dynamic>)
              .map((p) => PurchasablePlan.fromJson(p))
              .toList();
          return plans;
        }
      }
    } catch (e) {
      debugPrint('Error fetching plans: $e');
    }
    return [];
  }

  /// Check if user has full analytics access
  bool get hasFullAnalytics {
    return _cachedStatus?.features.hasFullAnalytics ?? false;
  }

  /// Get analytics access level
  String get analyticsAccessLevel {
    return _cachedStatus?.features.analyticsAccess ?? 'basic';
  }

  /// Check if AI tutor is enabled
  bool get isAiTutorEnabled {
    return _cachedStatus?.limits.aiTutorEnabled ?? false;
  }

  /// Check if chapter practice is enabled (Pro/Ultra only)
  bool get isChapterPracticeEnabled {
    return _cachedStatus?.limits.chapterPracticeEnabled ?? false;
  }

  /// Check if offline mode is enabled
  bool get isOfflineEnabled {
    return _cachedStatus?.limits.offlineEnabled ?? false;
  }

  // ============================================================================
  // Weekly Chapter Practice Limits (for free tier)
  // ============================================================================

  /// Check if a subject is locked for chapter practice (free tier weekly limit)
  bool isSubjectLocked(String subject) {
    if (_cachedStatus == null) return false;
    // Pro/Ultra have no weekly limits
    if (isPaid) return false;

    final weeklyUsage = _cachedStatus!.chapterPracticeWeekly;
    if (weeklyUsage == null) return false;

    return weeklyUsage.getBySubject(subject).isLocked;
  }

  /// Get unlock info for a subject (for UI display)
  SubjectPracticeUsage? getSubjectUnlockInfo(String subject) {
    return _cachedStatus?.chapterPracticeWeekly?.getBySubject(subject);
  }

  /// Check if any subject has a weekly limit lock (for showing upgrade button)
  bool get hasAnySubjectLocked {
    if (_cachedStatus == null) return false;
    if (isPaid) return false;
    return _cachedStatus!.chapterPracticeWeekly?.anyLocked ?? false;
  }

  /// Get weekly chapter practice usage data
  ChapterPracticeWeeklyUsage? get chapterPracticeWeeklyUsage {
    return _cachedStatus?.chapterPracticeWeekly;
  }
}
