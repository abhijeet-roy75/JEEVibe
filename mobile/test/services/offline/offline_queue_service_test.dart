// Unit tests for OfflineQueueService
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/services/offline/offline_queue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineQueueService', () {
    late OfflineQueueService service;

    setUp(() {
      service = OfflineQueueService();
    });

    group('singleton pattern', () {
      test('should return same instance', () {
        final instance1 = OfflineQueueService();
        final instance2 = OfflineQueueService();

        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('action type constants', () {
      test('should have quiz_answer action type', () {
        expect(OfflineQueueService.actionQuizAnswer, 'quiz_answer');
      });

      test('should have quiz_complete action type', () {
        expect(OfflineQueueService.actionQuizComplete, 'quiz_complete');
      });

      test('should have quiz_start action type', () {
        expect(OfflineQueueService.actionQuizStart, 'quiz_start');
      });
    });
  });

  group('SyncActionsResult', () {
    test('should calculate total correctly', () {
      final result = SyncActionsResult(synced: 5, failed: 2);

      expect(result.total, 7);
    });

    test('should indicate hasFailures when failed > 0', () {
      final result = SyncActionsResult(synced: 5, failed: 2);

      expect(result.hasFailures, isTrue);
    });

    test('should indicate no failures when failed = 0', () {
      final result = SyncActionsResult(synced: 5, failed: 0);

      expect(result.hasFailures, isFalse);
    });

    test('should handle all synced scenario', () {
      final result = SyncActionsResult(synced: 10, failed: 0);

      expect(result.synced, 10);
      expect(result.failed, 0);
      expect(result.total, 10);
      expect(result.hasFailures, isFalse);
    });

    test('should handle all failed scenario', () {
      final result = SyncActionsResult(synced: 0, failed: 5);

      expect(result.synced, 0);
      expect(result.failed, 5);
      expect(result.total, 5);
      expect(result.hasFailures, isTrue);
    });

    test('should handle empty scenario', () {
      final result = SyncActionsResult(synced: 0, failed: 0);

      expect(result.synced, 0);
      expect(result.failed, 0);
      expect(result.total, 0);
      expect(result.hasFailures, isFalse);
    });
  });
}
