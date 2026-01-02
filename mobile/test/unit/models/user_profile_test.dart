/// Unit tests for UserProfile model
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jeevibe_mobile/models/user_profile.dart';

void main() {
  group('UserProfile Model', () {
    test('toMap - creates correct map with all fields', () {
      final profile = UserProfile(
        uid: 'test_user_123',
        phoneNumber: '+1234567890',
        firstName: 'Test',
        lastName: 'User',
        email: 'test@example.com',
        targetYear: '2026',
        state: 'Maharashtra',
        targetExam: 'JEE Main + Advanced',
        dreamBranch: 'Computer Science',
        studySetup: ['Self-study', 'Online coaching'],
        profileCompleted: true,
        createdAt: DateTime(2024, 1, 1),
        lastActive: DateTime(2024, 1, 2),
      );

      final map = profile.toMap();

      expect(map['uid'], 'test_user_123');
      expect(map['phoneNumber'], '+1234567890');
      expect(map['firstName'], 'Test');
      expect(map['lastName'], 'User');
      expect(map['email'], 'test@example.com');
      expect(map['targetYear'], '2026');
      expect(map['state'], 'Maharashtra');
      expect(map['targetExam'], 'JEE Main + Advanced');
      expect(map['dreamBranch'], 'Computer Science');
      expect(map['studySetup'], ['Self-study', 'Online coaching']);
      expect(map['profileCompleted'], true);
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['lastActive'], isA<Timestamp>());
    });

    test('toMap - handles minimal profile (only required fields)', () {
      final profile = UserProfile(
        uid: 'test_user_123',
        phoneNumber: '+1234567890',
        createdAt: DateTime(2024, 1, 1),
        lastActive: DateTime(2024, 1, 2),
      );

      final map = profile.toMap();

      expect(map['uid'], 'test_user_123');
      expect(map['phoneNumber'], '+1234567890');
      expect(map['firstName'], isNull);
      expect(map['lastName'], isNull);
      expect(map['email'], isNull);
      expect(map['targetYear'], isNull);
      expect(map['state'], isNull);
      expect(map['targetExam'], isNull);
      expect(map['dreamBranch'], isNull);
      expect(map['studySetup'], isEmpty);
      expect(map['profileCompleted'], false);
    });

    test('fromMap - parses valid map with all fields', () {
      final map = {
        'phoneNumber': '+1234567890',
        'firstName': 'Test',
        'lastName': 'User',
        'email': 'test@example.com',
        'targetYear': '2026',
        'state': 'Maharashtra',
        'targetExam': 'JEE Main + Advanced',
        'dreamBranch': 'Computer Science',
        'studySetup': ['Self-study', 'Online coaching'],
        'profileCompleted': true,
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'lastActive': Timestamp.fromDate(DateTime(2024, 1, 2)),
      };

      final profile = UserProfile.fromMap(map, 'test_user_123');

      expect(profile.uid, 'test_user_123');
      expect(profile.phoneNumber, '+1234567890');
      expect(profile.firstName, 'Test');
      expect(profile.lastName, 'User');
      expect(profile.email, 'test@example.com');
      expect(profile.targetYear, '2026');
      expect(profile.state, 'Maharashtra');
      expect(profile.targetExam, 'JEE Main + Advanced');
      expect(profile.dreamBranch, 'Computer Science');
      expect(profile.studySetup, ['Self-study', 'Online coaching']);
      expect(profile.profileCompleted, true);
    });

    test('fromMap - handles missing optional fields', () {
      final map = {
        'phoneNumber': '+1234567890',
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'lastActive': Timestamp.fromDate(DateTime(2024, 1, 2)),
      };

      final profile = UserProfile.fromMap(map, 'test_user_123');

      expect(profile.uid, 'test_user_123');
      expect(profile.phoneNumber, '+1234567890');
      expect(profile.firstName, isNull);
      expect(profile.lastName, isNull);
      expect(profile.email, isNull);
      expect(profile.targetYear, isNull);
      expect(profile.state, isNull);
      expect(profile.targetExam, isNull);
      expect(profile.dreamBranch, isNull);
      expect(profile.studySetup, isEmpty);
      expect(profile.profileCompleted, false);
    });

    test('fromMap - handles empty studySetup array', () {
      final map = {
        'phoneNumber': '+1234567890',
        'studySetup': [],
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'lastActive': Timestamp.fromDate(DateTime(2024, 1, 2)),
      };

      final profile = UserProfile.fromMap(map, 'test_user_123');

      expect(profile.studySetup, isEmpty);
    });

    test('fromMap - handles null studySetup (defaults to empty array)', () {
      final map = {
        'phoneNumber': '+1234567890',
        'studySetup': null,
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'lastActive': Timestamp.fromDate(DateTime(2024, 1, 2)),
      };

      final profile = UserProfile.fromMap(map, 'test_user_123');

      expect(profile.studySetup, isEmpty);
    });

    test('fromMap - handles multiple studySetup options', () {
      final map = {
        'phoneNumber': '+1234567890',
        'studySetup': ['Self-study', 'Online coaching', 'Offline coaching', 'School only'],
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'lastActive': Timestamp.fromDate(DateTime(2024, 1, 2)),
      };

      final profile = UserProfile.fromMap(map, 'test_user_123');

      expect(profile.studySetup.length, 4);
      expect(profile.studySetup, containsAll(['Self-study', 'Online coaching', 'Offline coaching', 'School only']));
    });

    test('fromMap - validates targetExam values', () {
      final map1 = {
        'phoneNumber': '+1234567890',
        'targetExam': 'JEE Main',
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'lastActive': Timestamp.fromDate(DateTime(2024, 1, 2)),
      };

      final profile1 = UserProfile.fromMap(map1, 'test_user_123');
      expect(profile1.targetExam, 'JEE Main');

      final map2 = {
        'phoneNumber': '+1234567890',
        'targetExam': 'JEE Main + Advanced',
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'lastActive': Timestamp.fromDate(DateTime(2024, 1, 2)),
      };

      final profile2 = UserProfile.fromMap(map2, 'test_user_123');
      expect(profile2.targetExam, 'JEE Main + Advanced');
    });
  });
}
