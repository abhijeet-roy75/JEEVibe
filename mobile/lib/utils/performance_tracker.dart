/// Performance tracking utility for measuring operation timing
/// Helps identify bottlenecks in snap-and-solve and other flows
import 'package:flutter/foundation.dart';

class PerformanceTracker {
  final String operationName;
  final Map<String, DateTime> _stepTimestamps = {};
  final Map<String, Duration> _stepDurations = {};
  DateTime? _startTime;
  DateTime? _endTime;

  PerformanceTracker(this.operationName);

  /// Start tracking the operation
  void start() {
    _startTime = DateTime.now();
    _stepTimestamps['start'] = _startTime!;
    _log('⏱️  Started: $operationName');
  }

  /// Mark a step in the operation
  void step(String stepName) {
    final now = DateTime.now();
    _stepTimestamps[stepName] = now;

    // Calculate duration since last step
    final steps = _stepTimestamps.keys.toList();
    if (steps.length > 1) {
      final previousStep = steps[steps.length - 2];
      final previousTime = _stepTimestamps[previousStep]!;
      final duration = now.difference(previousTime);
      _stepDurations[stepName] = duration;
      _log('  ├─ $stepName: ${duration.inMilliseconds}ms');
    }
  }

  /// End tracking and print summary
  void end() {
    _endTime = DateTime.now();
    if (_startTime != null) {
      final totalDuration = _endTime!.difference(_startTime!);
      _log('✅ Completed: $operationName in ${totalDuration.inMilliseconds}ms');
      _printSummary();
    }
  }

  /// Get total duration
  Duration? getTotalDuration() {
    if (_startTime != null && _endTime != null) {
      return _endTime!.difference(_startTime!);
    }
    return null;
  }

  /// Print detailed summary
  void _printSummary() {
    if (!kDebugMode) return;

    final totalDuration = getTotalDuration();
    if (totalDuration == null) return;

    debugPrint('\n════════════════════════════════════════════');
    debugPrint('📊 Performance Summary: $operationName');
    debugPrint('════════════════════════════════════════════');
    debugPrint('Total Time: ${totalDuration.inMilliseconds}ms (${totalDuration.inSeconds}s)');
    debugPrint('');
    debugPrint('Step Breakdown:');

    final steps = _stepTimestamps.keys.toList();
    for (var i = 1; i < steps.length; i++) {
      final stepName = steps[i];
      final duration = _stepDurations[stepName];
      if (duration != null) {
        final percentage = (duration.inMilliseconds / totalDuration.inMilliseconds * 100).toStringAsFixed(1);
        final bar = _generateBar(duration.inMilliseconds, totalDuration.inMilliseconds);
        debugPrint('  $bar $stepName: ${duration.inMilliseconds}ms ($percentage%)');
      }
    }

    debugPrint('════════════════════════════════════════════\n');

    // Warn about slow operations
    _warnSlowOperations(totalDuration);
  }

  /// Generate visual bar for duration
  String _generateBar(int durationMs, int totalMs) {
    final barLength = 20;
    final filled = ((durationMs / totalMs) * barLength).round();
    final empty = barLength - filled;
    return '[${'█' * filled}${'░' * empty}]';
  }

  /// Warn about operations taking too long
  void _warnSlowOperations(Duration totalDuration) {
    // Check individual steps
    _stepDurations.forEach((step, duration) {
      if (duration.inSeconds > 10) {
        _log('⚠️  WARNING: "$step" took ${duration.inSeconds}s - possible bottleneck!');
      }
    });

    // Check total time
    if (totalDuration.inSeconds > 30) {
      _log('⚠️  WARNING: Total operation took ${totalDuration.inSeconds}s - exceeds target of 30s');
    }
  }

  /// Log message in debug mode only
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[PerformanceTracker] $message');
    }
  }

  /// Create a tracker that also sends metrics to analytics
  factory PerformanceTracker.withAnalytics(
    String operationName, {
    Function(String, Duration)? onComplete,
  }) {
    return _AnalyticsPerformanceTracker(operationName, onComplete: onComplete);
  }
}

/// Performance tracker that sends metrics to analytics
class _AnalyticsPerformanceTracker extends PerformanceTracker {
  final Function(String, Duration)? onComplete;

  _AnalyticsPerformanceTracker(
    String operationName, {
    this.onComplete,
  }) : super(operationName);

  @override
  void end() {
    super.end();

    // Send to analytics
    final duration = getTotalDuration();
    if (duration != null && onComplete != null) {
      onComplete!(operationName, duration);
    }
  }
}
