/// Subscription Models
///
/// Data models for the tier/subscription system.

// Usage type enum for tracking different feature usages
enum UsageType {
  snapSolve,
  dailyQuiz,
  aiTutor,
}

// Subscription tier enum
enum SubscriptionTier {
  free,
  pro,
  ultra,
}

// Subscription source enum
enum SubscriptionSource {
  defaultTier,
  override,
  subscription,
  trial,
}

/// Model for tier limits
class TierLimits {
  final int snapSolveDaily;
  final int dailyQuizDaily;
  final int solutionHistoryDays;
  final bool aiTutorEnabled;
  final int aiTutorMessagesDaily;
  final int chapterPracticePerChapter;
  final int mockTestsMonthly;
  final int pyqYearsAccess;
  final bool offlineEnabled;
  final int offlineSolutionsLimit;

  TierLimits({
    required this.snapSolveDaily,
    required this.dailyQuizDaily,
    required this.solutionHistoryDays,
    required this.aiTutorEnabled,
    required this.aiTutorMessagesDaily,
    required this.chapterPracticePerChapter,
    required this.mockTestsMonthly,
    required this.pyqYearsAccess,
    required this.offlineEnabled,
    required this.offlineSolutionsLimit,
  });

  factory TierLimits.fromJson(Map<String, dynamic> json) {
    return TierLimits(
      snapSolveDaily: json['snap_solve_daily'] ?? 5,
      dailyQuizDaily: json['daily_quiz_daily'] ?? 1,
      solutionHistoryDays: json['solution_history_days'] ?? 7,
      aiTutorEnabled: json['ai_tutor_enabled'] ?? false,
      aiTutorMessagesDaily: json['ai_tutor_messages_daily'] ?? 0,
      chapterPracticePerChapter: json['chapter_practice_per_chapter'] ?? 5,
      mockTestsMonthly: json['mock_tests_monthly'] ?? 1,
      pyqYearsAccess: json['pyq_years_access'] ?? 2,
      offlineEnabled: json['offline_enabled'] ?? false,
      offlineSolutionsLimit: json['offline_solutions_limit'] ?? 0,
    );
  }

  /// Check if a limit is unlimited (-1 means unlimited)
  static bool isUnlimited(int value) => value == -1;
}

/// Model for tier features
class TierFeatures {
  final String analyticsAccess; // 'basic' or 'full'

  TierFeatures({required this.analyticsAccess});

  factory TierFeatures.fromJson(Map<String, dynamic> json) {
    return TierFeatures(
      analyticsAccess: json['analytics_access'] ?? 'basic',
    );
  }

  bool get hasFullAnalytics => analyticsAccess == 'full';
}

/// Model for usage info (for a single usage type)
class UsageInfo {
  final int used;
  final int limit;
  final int remaining;
  final bool isUnlimited;
  final String? resetsAt;

  UsageInfo({
    required this.used,
    required this.limit,
    required this.remaining,
    required this.isUnlimited,
    this.resetsAt,
  });

  factory UsageInfo.fromJson(Map<String, dynamic> json) {
    return UsageInfo(
      used: json['used'] ?? 0,
      limit: json['limit'] ?? 0,
      remaining: json['remaining'] ?? 0,
      isUnlimited: json['is_unlimited'] ?? false,
      resetsAt: json['resets_at'],
    );
  }

  /// Get percentage used (0.0 to 1.0)
  double get percentageUsed {
    if (isUnlimited) return 0.0;
    if (limit <= 0) return 1.0;
    return (used / limit).clamp(0.0, 1.0);
  }

  /// Check if limit is reached
  bool get isLimitReached => !isUnlimited && remaining <= 0;
}

/// Model for all usage data
class AllUsage {
  final UsageInfo snapSolve;
  final UsageInfo dailyQuiz;
  final UsageInfo aiTutor;

  AllUsage({
    required this.snapSolve,
    required this.dailyQuiz,
    required this.aiTutor,
  });

  factory AllUsage.fromJson(Map<String, dynamic> json) {
    return AllUsage(
      snapSolve: UsageInfo.fromJson(json['snap_solve'] ?? {}),
      dailyQuiz: UsageInfo.fromJson(json['daily_quiz'] ?? {}),
      aiTutor: UsageInfo.fromJson(json['ai_tutor'] ?? {}),
    );
  }

  /// Get usage info for a specific type
  UsageInfo getUsage(UsageType type) {
    switch (type) {
      case UsageType.snapSolve:
        return snapSolve;
      case UsageType.dailyQuiz:
        return dailyQuiz;
      case UsageType.aiTutor:
        return aiTutor;
    }
  }
}

/// Model for subscription info
class SubscriptionInfo {
  final SubscriptionTier tier;
  final String tierDisplayName;
  final SubscriptionSource source;
  final String? expiresAt;
  final String? overrideType;
  final String? overrideReason;
  final String? subscriptionId;
  final String? planType;

  SubscriptionInfo({
    required this.tier,
    required this.tierDisplayName,
    required this.source,
    this.expiresAt,
    this.overrideType,
    this.overrideReason,
    this.subscriptionId,
    this.planType,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      tier: _parseTier(json['tier']),
      tierDisplayName: json['tier_display_name'] ?? 'Free',
      source: _parseSource(json['source']),
      expiresAt: json['expires_at'],
      overrideType: json['override']?['type'],
      overrideReason: json['override']?['reason'],
      subscriptionId: json['subscription_id'],
      planType: json['plan_type'],
    );
  }

  static SubscriptionTier _parseTier(String? tier) {
    switch (tier) {
      case 'pro':
        return SubscriptionTier.pro;
      case 'ultra':
        return SubscriptionTier.ultra;
      default:
        return SubscriptionTier.free;
    }
  }

  static SubscriptionSource _parseSource(String? source) {
    switch (source) {
      case 'override':
        return SubscriptionSource.override;
      case 'subscription':
        return SubscriptionSource.subscription;
      case 'trial':
        return SubscriptionSource.trial;
      default:
        return SubscriptionSource.defaultTier;
    }
  }

  bool get isFree => tier == SubscriptionTier.free;
  bool get isPro => tier == SubscriptionTier.pro;
  bool get isUltra => tier == SubscriptionTier.ultra;
  bool get isPaid => isPro || isUltra;
  bool get isBetaTester => source == SubscriptionSource.override;
}

/// Full subscription status model
class SubscriptionStatus {
  final SubscriptionInfo subscription;
  final TierLimits limits;
  final TierFeatures features;
  final AllUsage usage;

  SubscriptionStatus({
    required this.subscription,
    required this.limits,
    required this.features,
    required this.usage,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      subscription: SubscriptionInfo.fromJson(json['subscription'] ?? {}),
      limits: TierLimits.fromJson(json['limits'] ?? {}),
      features: TierFeatures.fromJson(json['features'] ?? {}),
      usage: AllUsage.fromJson(json['usage'] ?? {}),
    );
  }

  /// Check if user can use a feature
  bool canUse(UsageType type) {
    return !usage.getUsage(type).isLimitReached;
  }

  /// Get remaining uses for a feature
  int getRemainingUses(UsageType type) {
    final usageInfo = usage.getUsage(type);
    if (usageInfo.isUnlimited) return -1;
    return usageInfo.remaining;
  }
}

/// Model for upgrade prompt
class UpgradePrompt {
  final String message;
  final String ctaText;
  final String currentTier;

  UpgradePrompt({
    required this.message,
    required this.ctaText,
    required this.currentTier,
  });

  factory UpgradePrompt.fromJson(Map<String, dynamic> json) {
    return UpgradePrompt(
      message: json['message'] ?? '',
      ctaText: json['cta_text'] ?? 'Upgrade',
      currentTier: json['current_tier'] ?? 'free',
    );
  }
}

/// Model for pricing option
class PricingOption {
  final String price;
  final String perMonth;
  final int durationDays;
  final int? savingsPercent;
  final String? badge;

  PricingOption({
    required this.price,
    required this.perMonth,
    required this.durationDays,
    this.savingsPercent,
    this.badge,
  });

  factory PricingOption.fromJson(Map<String, dynamic> json) {
    return PricingOption(
      price: json['price'] ?? '0',
      perMonth: json['per_month'] ?? '0',
      durationDays: json['duration_days'] ?? 30,
      savingsPercent: json['savings_percent'],
      badge: json['badge'],
    );
  }
}

/// Model for a purchasable plan
class PurchasablePlan {
  final String tierId;
  final String displayName;
  final List<PlanFeature> features;
  final PricingOption monthly;
  final PricingOption quarterly;
  final PricingOption annual;

  PurchasablePlan({
    required this.tierId,
    required this.displayName,
    required this.features,
    required this.monthly,
    required this.quarterly,
    required this.annual,
  });

  factory PurchasablePlan.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'] ?? {};
    return PurchasablePlan(
      tierId: json['tier_id'] ?? '',
      displayName: json['display_name'] ?? '',
      features: (json['features'] as List<dynamic>?)
              ?.map((f) => PlanFeature.fromJson(f))
              .toList() ??
          [],
      monthly: PricingOption.fromJson(pricing['monthly'] ?? {}),
      quarterly: PricingOption.fromJson(pricing['quarterly'] ?? {}),
      annual: PricingOption.fromJson(pricing['annual'] ?? {}),
    );
  }
}

/// Model for a plan feature
class PlanFeature {
  final String name;
  final String value;

  PlanFeature({required this.name, required this.value});

  factory PlanFeature.fromJson(Map<String, dynamic> json) {
    return PlanFeature(
      name: json['name'] ?? '',
      value: json['value'] ?? '',
    );
  }
}
