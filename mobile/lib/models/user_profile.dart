import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String phoneNumber;
  final bool profileCompleted;

  // Basic Profile (Screen 1 - Required)
  final String? firstName;
  final String? lastName;
  final String? targetYear;

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
    this.targetYear,
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
      'targetYear': targetYear,
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
    return UserProfile(
      uid: uid,
      phoneNumber: map['phoneNumber'] ?? '',
      profileCompleted: map['profileCompleted'] ?? false,
      firstName: map['firstName'],
      lastName: map['lastName'],
      targetYear: map['targetYear'],
      email: map['email'],
      state: map['state'],
      targetExam: map['targetExam'],
      dreamBranch: map['dreamBranch'],
      studySetup: List<String>.from(map['studySetup'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastActive: (map['lastActive'] as Timestamp).toDate(),
    );
  }
}
