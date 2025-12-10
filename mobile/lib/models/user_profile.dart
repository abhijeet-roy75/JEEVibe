import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String phoneNumber;
  final bool profileCompleted;
  
  // Basic Profile
  final String? firstName;
  final String? lastName;
  final String? email;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? currentClass;
  final String? targetExam;
  final String? targetYear;

  // Advanced Profile
  final String? schoolName;
  final String? city;
  final String? state;
  final String? coachingInstitute;
  final String? coachingBranch;
  final String? studyMode;
  final String? preferredLanguage;
  final List<String> weakSubjects;
  final List<String> strongSubjects;

  // Metadata
  final DateTime createdAt;
  final DateTime lastActive;

  UserProfile({
    required this.uid,
    required this.phoneNumber,
    this.profileCompleted = false,
    this.firstName,
    this.lastName,
    this.email,
    this.dateOfBirth,
    this.gender,
    this.currentClass,
    this.targetExam,
    this.targetYear,
    this.schoolName,
    this.city,
    this.state,
    this.coachingInstitute,
    this.coachingBranch,
    this.studyMode,
    this.preferredLanguage,
    this.weakSubjects = const [],
    this.strongSubjects = const [],
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
      'email': email,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'gender': gender,
      'currentClass': currentClass,
      'targetExam': targetExam,
      'targetYear': targetYear,
      'schoolName': schoolName,
      'city': city,
      'state': state,
      'coachingInstitute': coachingInstitute,
      'coachingBranch': coachingBranch,
      'studyMode': studyMode,
      'preferredLanguage': preferredLanguage,
      'weakSubjects': weakSubjects,
      'strongSubjects': strongSubjects,
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
      email: map['email'],
      dateOfBirth: map['dateOfBirth'] != null 
          ? (map['dateOfBirth'] as Timestamp).toDate() 
          : null,
      gender: map['gender'],
      currentClass: map['currentClass'],
      targetExam: map['targetExam'],
      targetYear: map['targetYear'],
      schoolName: map['schoolName'],
      city: map['city'],
      state: map['state'],
      coachingInstitute: map['coachingInstitute'],
      coachingBranch: map['coachingBranch'],
      studyMode: map['studyMode'],
      preferredLanguage: map['preferredLanguage'],
      weakSubjects: List<String>.from(map['weakSubjects'] ?? []),
      strongSubjects: List<String>.from(map['strongSubjects'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastActive: (map['lastActive'] as Timestamp).toDate(),
    );
  }
}
