/// Unit tests for UserProfile model
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jeevibe_mobile/models/user_profile.dart';

void main() {
  group('UserProfile Model', () {
    test('toMap - creates correct map', () {
      final profile = UserProfile(
        uid: 'test_user_123',
        phoneNumber: '+1234567890',
        firstName: 'Test',
        lastName: 'User',
        email: 'test@example.com',
        profileCompleted: true,
        weakSubjects: ['Physics'],
        strongSubjects: ['Mathematics'],
        createdAt: DateTime(2024, 1, 1),
        lastActive: DateTime(2024, 1, 2),
      );

      final map = profile.toMap();

      expect(map['uid'], 'test_user_123');
      expect(map['phoneNumber'], '+1234567890');
      expect(map['firstName'], 'Test');
      expect(map['lastName'], 'User');
      expect(map['email'], 'test@example.com');
      expect(map['profileCompleted'], true);
      expect(map['weakSubjects'], ['Physics']);
      expect(map['strongSubjects'], ['Mathematics']);
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['lastActive'], isA<Timestamp>());
    });

    test('fromMap - parses valid map', () {
      final map = {
        'phoneNumber': '+1234567890',
        'firstName': 'Test',
        'lastName': 'User',
        'email': 'test@example.com',
        'profileCompleted': true,
        'weakSubjects': ['Physics'],
        'strongSubjects': ['Mathematics'],
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'lastActive': Timestamp.fromDate(DateTime(2024, 1, 2)),
      };

      final profile = UserProfile.fromMap(map, 'test_user_123');

      expect(profile.uid, 'test_user_123');
      expect(profile.phoneNumber, '+1234567890');
      expect(profile.firstName, 'Test');
      expect(profile.lastName, 'User');
      expect(profile.email, 'test@example.com');
      expect(profile.profileCompleted, true);
      expect(profile.weakSubjects, ['Physics']);
      expect(profile.strongSubjects, ['Mathematics']);
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
      expect(profile.profileCompleted, false);
      expect(profile.weakSubjects, isEmpty);
      expect(profile.strongSubjects, isEmpty);
    });

    test('fromMap - handles dateOfBirth', () {
      final map = {
        'phoneNumber': '+1234567890',
        'dateOfBirth': Timestamp.fromDate(DateTime(2000, 1, 1)),
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'lastActive': Timestamp.fromDate(DateTime(2024, 1, 2)),
      };

      final profile = UserProfile.fromMap(map, 'test_user_123');

      expect(profile.dateOfBirth, isNotNull);
      expect(profile.dateOfBirth!.year, 2000);
    });

    test('fromMap - handles null dateOfBirth', () {
      final map = {
        'phoneNumber': '+1234567890',
        'dateOfBirth': null,
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'lastActive': Timestamp.fromDate(DateTime(2024, 1, 2)),
      };

      final profile = UserProfile.fromMap(map, 'test_user_123');

      expect(profile.dateOfBirth, isNull);
    });
  });
}

