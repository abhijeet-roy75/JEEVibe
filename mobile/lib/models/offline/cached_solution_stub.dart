// Stub models for offline functionality on Web
// These are not functional on web, just type stubs

/// Sync state enum
enum SyncState {
  idle,
  syncing,
  error,
  completed,
}

/// Stub for CachedSolution (not functional on web)
class CachedSolution {
  final String solutionId;
  final String userId;
  final String question;
  final String topic;
  final String subject;
  final DateTime timestamp;
  final String solutionDataJson;
  final String? localImagePath;
  final String? originalImageUrl;
  final String? language;
  final DateTime cachedAt;
  final DateTime expiresAt;
  final bool isImageCached;
  final DateTime? lastAccessedAt;

  CachedSolution({
    required this.solutionId,
    required this.userId,
    required this.question,
    required this.topic,
    required this.subject,
    required this.timestamp,
    required this.solutionDataJson,
    this.localImagePath,
    this.originalImageUrl,
    this.language,
    required this.cachedAt,
    required this.expiresAt,
    this.isImageCached = false,
    this.lastAccessedAt,
  });
}

/// Stub for CachedQuiz (not functional on web)
class CachedQuiz {
  final String quizId;
  final String userId;
  final String quizDataJson;
  final DateTime cachedAt;
  final DateTime expiresAt;
  final bool isUsed;
  final String subject;

  CachedQuiz({
    required this.quizId,
    required this.userId,
    required this.quizDataJson,
    required this.cachedAt,
    required this.expiresAt,
    this.isUsed = false,
    required this.subject,
  });
}

/// Stub for CachedAnalytics (not functional on web)
class CachedAnalytics {
  final String userId;
  final String analyticsDataJson;
  final DateTime cachedAt;
  final DateTime expiresAt;

  CachedAnalytics({
    required this.userId,
    required this.analyticsDataJson,
    required this.cachedAt,
    required this.expiresAt,
  });
}

/// Stub for SyncStatus (not functional on web)
class SyncStatus {
  final String userId;
  DateTime? lastSyncAt;
  DateTime? lastSyncAttemptAt;
  bool initialSyncComplete;
  int pendingActionsCount;
  SyncState syncState;
  String? lastSyncError;

  SyncStatus({
    required this.userId,
    this.lastSyncAt,
    this.lastSyncAttemptAt,
    this.initialSyncComplete = false,
    this.pendingActionsCount = 0,
    this.syncState = SyncState.idle,
    this.lastSyncError,
  });
}

/// Stub for OfflineAction (not functional on web)
class OfflineAction {
  final String userId;
  final String actionType;
  final String actionDataJson;
  final DateTime queuedAt;
  int retryCount;
  bool isSynced;

  OfflineAction({
    required this.userId,
    required this.actionType,
    required this.actionDataJson,
    required this.queuedAt,
    this.retryCount = 0,
    this.isSynced = false,
  });
}
