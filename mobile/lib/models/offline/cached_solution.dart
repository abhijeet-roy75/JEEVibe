// Cached Solution Model for Isar Database
//
// Stores snap solutions for offline viewing.

import 'package:isar/isar.dart';

part 'cached_solution.g.dart';

@collection
class CachedSolution {
  Id id = Isar.autoIncrement;

  /// Unique solution/snap ID from backend
  @Index(unique: true)
  late String solutionId;

  /// User ID who owns this solution
  @Index()
  late String userId;

  /// The question text (extracted from image)
  late String question;

  /// Topic/chapter name
  late String topic;

  /// Subject (physics, chemistry, maths)
  @Index()
  late String subject;

  /// Original timestamp when solution was created
  late DateTime timestamp;

  /// Full solution data as JSON string
  /// Contains: approach, steps, finalAnswer, priyaMaamTip
  late String solutionDataJson;

  /// Local file path to cached image (if cached)
  String? localImagePath;

  /// Original Firebase Storage URL
  String? originalImageUrl;

  /// Language of the solution (en, hi)
  String? language;

  /// When this solution was cached locally
  @Index()
  late DateTime cachedAt;

  /// When this cache entry expires (for cleanup)
  late DateTime expiresAt;

  /// Whether the image has been cached locally
  bool isImageCached = false;

  /// Last time this solution was accessed (for LRU eviction)
  DateTime? lastAccessedAt;
}

@collection
class CachedQuiz {
  Id id = Isar.autoIncrement;

  /// Unique quiz ID
  @Index(unique: true)
  late String quizId;

  /// User ID who this quiz is for
  @Index()
  late String userId;

  /// Full quiz data as JSON string (DailyQuiz serialized)
  late String quizDataJson;

  /// When this quiz was cached
  late DateTime cachedAt;

  /// When this quiz expires (7 days max)
  late DateTime expiresAt;

  /// Whether this quiz has been started/used
  bool isUsed = false;

  /// Subject of the quiz
  @Index()
  late String subject;
}

@collection
class CachedAnalytics {
  Id id = Isar.autoIncrement;

  /// User ID
  @Index(unique: true)
  late String userId;

  /// Full analytics overview as JSON string
  late String analyticsDataJson;

  /// When this was cached
  late DateTime cachedAt;

  /// When this cache entry expires (24 hours typically)
  late DateTime expiresAt;
}

@collection
class SyncStatus {
  Id id = Isar.autoIncrement;

  /// User ID
  @Index(unique: true)
  late String userId;

  /// Last successful sync time
  DateTime? lastSyncAt;

  /// Last sync attempt time
  DateTime? lastSyncAttemptAt;

  /// Whether initial sync has completed
  bool initialSyncComplete = false;

  /// Number of pending offline actions to sync
  int pendingActionsCount = 0;

  /// Current sync state
  @enumerated
  SyncState syncState = SyncState.idle;

  /// Error message if last sync failed
  String? lastSyncError;
}

/// Sync state enum
enum SyncState {
  idle,
  syncing,
  error,
  completed,
}

@collection
class OfflineAction {
  Id id = Isar.autoIncrement;

  /// User ID
  @Index()
  late String userId;

  /// Type of action (e.g., 'quiz_answer', 'quiz_complete')
  late String actionType;

  /// Action data as JSON
  late String actionDataJson;

  /// When this action was queued
  late DateTime queuedAt;

  /// Number of retry attempts
  int retryCount = 0;

  /// Whether this action has been synced
  bool isSynced = false;
}
