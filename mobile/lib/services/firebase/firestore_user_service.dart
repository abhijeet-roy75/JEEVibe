import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';

class FirestoreUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  // Create or Update User Profile
  Future<void> saveUserProfile(UserProfile profile) async {
    await _firestore
        .collection(_collection)
        .doc(profile.uid)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  // Get User Profile
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore.collection(_collection).doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserProfile.fromMap(doc.data()!, uid);
    }
    return null;
  }

  // Check if Profile Exists
  Future<bool> profileExists(String uid) async {
    final doc = await _firestore.collection(_collection).doc(uid).get();
    return doc.exists;
  }
  
  // Update Last Active
  Future<void> updateLastActive(String uid) async {
    await _firestore
        .collection(_collection)
        .doc(uid)
        .update({'lastActive': FieldValue.serverTimestamp()});
  }
  
  // Complete Profile
  Future<void> markProfileCompleted(String uid) async {
     await _firestore
        .collection(_collection)
        .doc(uid)
        .update({'profileCompleted': true});
  }
}
