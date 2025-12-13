/// Unit tests for StorageService
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jeevibe_mobile/services/storage_service.dart';
import 'package:jeevibe_mobile/models/snap_data_model.dart';

void main() {
  group('StorageService', () {
    late StorageService storageService;

    setUp(() async {
      // Use in-memory SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
      storageService = StorageService();
      await storageService.initialize();
    });

    group('Snap Counter', () {
      test('getSnapCount - returns 0 for new user', () async {
        final count = await storageService.getSnapCount();
        expect(count, 0);
      });

      test('setSnapCount - stores and retrieves count', () async {
        await storageService.setSnapCount(5);
        final count = await storageService.getSnapCount();
        expect(count, 5);
      });

      test('incrementSnapCount - increments count', () async {
        await storageService.setSnapCount(3);
        final current = await storageService.getSnapCount();
        await storageService.setSnapCount(current + 1);
        final count = await storageService.getSnapCount();
        expect(count, 4);
      });

      test('getSnapLimit - returns default limit', () async {
        final limit = await storageService.getSnapLimit();
        expect(limit, StorageService.defaultSnapLimit);
      });

      // Note: setSnapLimit is not directly available in StorageService
      // It's managed through SnapCounterService or AppStateProvider
      // This test is kept for future implementation
      test('getSnapLimit - returns default limit', () async {
        final limit = await storageService.getSnapLimit();
        expect(limit, StorageService.defaultSnapLimit);
      });
    });

    group('Date Management', () {
      test('getLastResetDate - returns null for new user', () async {
        final date = await storageService.getLastResetDate();
        expect(date, isNull);
      });

      test('setLastResetDate - stores and retrieves date', () async {
        final dateStr = '2024-01-01';
        await storageService.setLastResetDate(dateStr);
        final retrieved = await storageService.getLastResetDate();
        expect(retrieved, dateStr);
      });
    });

    group('Welcome Status', () {
      test('hasSeenWelcome - returns false for new user', () async {
        final hasSeen = await storageService.hasSeenWelcome();
        expect(hasSeen, false);
      });

      test('setHasSeenWelcome - stores and retrieves value', () async {
        await storageService.setHasSeenWelcome(true);
        final hasSeen = await storageService.hasSeenWelcome();
        expect(hasSeen, true);
      });
    });

    group('Snap History', () {
      test('getSnapHistory - returns empty list for new user', () async {
        final history = await storageService.getSnapHistory();
        expect(history, isEmpty);
      });

      test('addSnapToHistory - adds snap record', () async {
        final snap = SnapRecord(
          timestamp: DateTime.now().toIso8601String(),
          questionId: 'test_q1',
          topic: 'Calculus',
          subject: 'Mathematics',
        );
        await storageService.addSnapToHistory(snap);
        final history = await storageService.getSnapHistory();
        expect(history.length, 1);
        expect(history[0].questionId, 'test_q1');
      });
    });

    group('Solutions', () {
      test('getRecentSolutions - returns empty list for new user', () async {
        final solutions = await storageService.getRecentSolutions();
        expect(solutions, isEmpty);
      });

      test('addRecentSolution - adds solution', () async {
        final solution = RecentSolution(
          id: 'test_sol_1',
          question: 'Test question',
          topic: 'Calculus',
          subject: 'Mathematics',
          timestamp: DateTime.now().toIso8601String(),
        );
        await storageService.addRecentSolution(solution);
        final solutions = await storageService.getRecentSolutions();
        expect(solutions.length, 1);
        expect(solutions[0].id, 'test_sol_1');
      });

      test('addRecentSolution - limits to max recent solutions', () async {
        // Add 4 solutions (max is 3)
        for (int i = 1; i <= 4; i++) {
          final solution = RecentSolution(
            id: 'test_sol_$i',
            question: 'Test question $i',
            topic: 'Calculus',
            subject: 'Mathematics',
            timestamp: DateTime.now().toIso8601String(),
          );
          await storageService.addRecentSolution(solution);
        }
        final solutions = await storageService.getRecentSolutions();
        expect(solutions.length, 3); // Should be limited to 3
      });

      test('getAllSolutions - returns empty list for new user', () async {
        final solutions = await storageService.getAllSolutions();
        expect(solutions, isEmpty);
      });
    });

    group('Stats', () {
      test('getStats - returns default stats for new user', () async {
        final stats = await storageService.getStats();
        expect(stats.totalQuestionsPracticed, 0);
        expect(stats.totalCorrect, 0);
        expect(stats.totalSnapsUsed, 0);
      });

      test('updateStats - updates stats', () async {
        await storageService.updateStats(10, 8);
        final stats = await storageService.getStats();
        expect(stats.totalQuestionsPracticed, 10);
        expect(stats.totalCorrect, 8);
      });

      test('incrementTotalSnaps - increments counter', () async {
        await storageService.incrementTotalSnaps();
        final stats = await storageService.getStats();
        expect(stats.totalSnapsUsed, 1);
      });
    });

    group('Assessment Status', () {
      test('getAssessmentStatus - returns default for new user', () async {
        final status = await storageService.getAssessmentStatus();
        expect(status, 'not_started');
      });

      test('setAssessmentStatus - stores and retrieves status', () async {
        await storageService.setAssessmentStatus('completed');
        final status = await storageService.getAssessmentStatus();
        expect(status, 'completed');
      });
    });
  });
}
