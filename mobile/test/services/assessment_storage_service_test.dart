/// Unit tests for Assessment Storage Service
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jeevibe_mobile/services/assessment_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssessmentStorageService', () {
    late AssessmentStorageService service;

    setUp(() async {
      // Reset SharedPreferences mock with empty values before each test
      SharedPreferences.setMockInitialValues({});
      service = AssessmentStorageService();
      // Reset singleton's cached prefs to force it to get fresh SharedPreferences instance
      service.resetForTesting();
      await service.initialize();
    });

    group('saveAssessmentState', () {
      test('should save and load state correctly', () async {
        // Arrange
        final responses = {0: 'answer1', 1: 'answer2', 2: 'answer3'};
        final currentIndex = 1;
        final remainingSeconds = 2700;
        final startTime = DateTime.now();
        final questionStartTimes = {
          0: DateTime.now().subtract(const Duration(minutes: 5)),
          1: DateTime.now().subtract(const Duration(minutes: 2)),
        };

        // Act
        final saved = await service.saveAssessmentState(
          responses: responses,
          currentIndex: currentIndex,
          remainingSeconds: remainingSeconds,
          startTime: startTime,
          questionStartTimes: questionStartTimes,
        );

        // Assert
        expect(saved, isTrue);

        final loaded = await service.loadAssessmentState();
        expect(loaded, isNotNull);
        expect(loaded!.currentIndex, currentIndex);
        expect(loaded.remainingSeconds, remainingSeconds);
        expect(loaded.responses.length, responses.length);
        expect(loaded.responses[0], 'answer1');
      });

      test('should reject invalid currentIndex', () async {
        // Arrange
        final responses = {0: 'answer1'};
        final startTime = DateTime.now();

        // Act & Assert
        final saved1 = await service.saveAssessmentState(
          responses: responses,
          currentIndex: -1, // Invalid
          remainingSeconds: 2700,
          startTime: startTime,
          questionStartTimes: {},
        );
        expect(saved1, isFalse);

        final saved2 = await service.saveAssessmentState(
          responses: responses,
          currentIndex: 30, // Invalid (must be 0-29)
          remainingSeconds: 2700,
          startTime: startTime,
          questionStartTimes: {},
        );
        expect(saved2, isFalse);
      });

      test('should reject future startTime', () async {
        // Arrange
        final responses = {0: 'answer1'};
        final futureTime = DateTime.now().add(const Duration(hours: 1));

        // Act
        final saved = await service.saveAssessmentState(
          responses: responses,
          currentIndex: 0,
          remainingSeconds: 2700,
          startTime: futureTime,
          questionStartTimes: {},
        );

        // Assert
        expect(saved, isFalse);
      });

      test('should reject invalid response keys', () async {
        // Arrange
        final responses = {-1: 'invalid', 30: 'invalid'}; // Invalid keys
        final startTime = DateTime.now();

        // Act
        final saved = await service.saveAssessmentState(
          responses: responses,
          currentIndex: 0,
          remainingSeconds: 2700,
          startTime: startTime,
          questionStartTimes: {},
        );

        // Assert
        expect(saved, isFalse);
      });

      test('should warn but allow suspicious remainingSeconds', () async {
        // Arrange - very negative time (10 hours overtime)
        final responses = {0: 'answer1'};
        final startTime = DateTime.now();

        // Act
        final saved = await service.saveAssessmentState(
          responses: responses,
          currentIndex: 0,
          remainingSeconds: -40000, // Very negative
          startTime: startTime,
          questionStartTimes: {},
        );

        // Assert - should still save with warning (code only warns, doesn't fail validation)
        expect(saved, isTrue);
      });
    });

    group('loadAssessmentState', () {
      test('should return null if no state exists', () async {
        // Act
        final loaded = await service.loadAssessmentState();

        // Assert
        expect(loaded, isNull);
      });

      test('should return null if state is expired', () async {
        // Arrange - save state with old timestamp
        final prefs = await SharedPreferences.getInstance();
        final expired = DateTime.now().subtract(const Duration(days: 2));
        await prefs.setString('jeevibe_assessment_last_saved_at', expired.toIso8601String());
        await prefs.setString('jeevibe_assessment_responses', '{}');

        // Act
        final loaded = await service.loadAssessmentState();

        // Assert
        expect(loaded, isNull);
      });

      test('should load state within expiration period', () async {
        // Arrange
        final responses = {0: 'answer1'};
        final currentIndex = 0;
        final remainingSeconds = 2700;
        final startTime = DateTime.now();
        final questionStartTimes = {0: DateTime.now()};

        await service.saveAssessmentState(
          responses: responses,
          currentIndex: currentIndex,
          remainingSeconds: remainingSeconds,
          startTime: startTime,
          questionStartTimes: questionStartTimes,
        );

        // Act
        final loaded = await service.loadAssessmentState();

        // Assert
        expect(loaded, isNotNull);
        expect(loaded!.responses, isNotEmpty);
      });
    });

    group('clearAssessmentState', () {
      test('should clear all stored state', () async {
        // Arrange
        await service.saveAssessmentState(
          responses: {0: 'answer1'},
          currentIndex: 0,
          remainingSeconds: 2700,
          startTime: DateTime.now(),
          questionStartTimes: {},
        );

        // Act
        await service.clearAssessmentState();

        // Assert
        final loaded = await service.loadAssessmentState();
        expect(loaded, isNull);
      });
    });

    group('hasSavedAssessmentState', () {
      test('should return false when no state exists', () async {
        // Act
        final has = await service.hasSavedAssessmentState();

        // Assert
        expect(has, isFalse);
      });

      test('should return true when state exists', () async {
        // Arrange
        await service.saveAssessmentState(
          responses: {0: 'answer1'},
          currentIndex: 0,
          remainingSeconds: 2700,
          startTime: DateTime.now(),
          questionStartTimes: {},
        );

        // Act
        final has = await service.hasSavedAssessmentState();

        // Assert
        expect(has, isTrue);
      });
    });

    group('isStateExpired', () {
      test('should return true if no timestamp exists', () async {
        // Act
        final expired = await service.isStateExpired();

        // Assert
        expect(expired, isTrue);
      });

      test('should return true if state is older than 24 hours', () async {
        // Arrange
        final prefs = await SharedPreferences.getInstance();
        final old = DateTime.now().subtract(const Duration(hours: 25));
        await prefs.setString('jeevibe_assessment_last_saved_at', old.toIso8601String());

        // Act
        final expired = await service.isStateExpired();

        // Assert
        expect(expired, isTrue);
      });

      test('should return false if state is within 24 hours', () async {
        // Arrange
        await service.saveAssessmentState(
          responses: {0: 'answer1'},
          currentIndex: 0,
          remainingSeconds: 2700,
          startTime: DateTime.now(),
          questionStartTimes: {},
        );

        // Act
        final expired = await service.isStateExpired();

        // Assert
        expect(expired, isFalse);
      });
    });
  });
}
