import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String phoneNumber;
  final bool profileCompleted;

  // Basic Profile (Screen 1 - Required)
  final String? firstName;
  final String? lastName;
  final String? currentClass; // "11", "12", or "Other"
  final bool? isEnrolledInCoaching; // true if student attends coaching classes

  // Optional Profile (Screen 2)
  final String? email;
  final String? state;
  final String? targetExam; // "JEE Main" or "JEE Main + Advanced"
  final String? dreamBranch;
  final List<String> studySetup; // ["Self-study", "Online coaching", "Offline coaching", "School only"]

  // Metadata
  final DateTime createdAt;
  final DateTime lastActive;

  UserProfile({
    required this.uid,
    required this.phoneNumber,
    this.profileCompleted = false,
    this.firstName,
    this.lastName,
    this.currentClass,
    this.isEnrolledInCoaching,
    this.email,
    this.state,
    this.targetExam,
    this.dreamBranch,
    this.studySetup = const [],
    required this.createdAt,
    required this.lastActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'profileCompleted': profileCompleted,
      'firstName': firstName,
      'lastName': lastName,
      'currentClass': currentClass,
      'isEnrolledInCoaching': isEnrolledInCoaching,
      'email': email,
      'state': state,
      'targetExam': targetExam,
      'dreamBranch': dreamBranch,
      'studySetup': studySetup,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': Timestamp.fromDate(lastActive),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    // Helper to safely parse timestamps, using current time as fallback
    DateTime parseTimestamp(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is Timestamp) return value.toDate();
      // Handle case where it might already be a DateTime (shouldn't happen, but defensive)
      if (value is DateTime) return value;
      return fallback;
    }

    final now = DateTime.now();

    return UserProfile(
      uid: uid,
      phoneNumber: map['phoneNumber'] ?? '',
      profileCompleted: map['profileCompleted'] ?? false,
      firstName: map['firstName'],
      lastName: map['lastName'],
      currentClass: map['currentClass'],
      isEnrolledInCoaching: map['isEnrolledInCoaching'],
      email: map['email'],
      state: map['state'],
      targetExam: map['targetExam'],
      dreamBranch: map['dreamBranch'],
      studySetup: List<String>.from(map['studySetup'] ?? []),
      createdAt: parseTimestamp(map['createdAt'], now),
      lastActive: parseTimestamp(map['lastActive'], now),
    );
  }
}
