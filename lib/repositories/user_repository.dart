import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Fetches user profile from Firestore by [userId].
  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Saves or updates the user profile directly in Firestore.
  Future<void> saveUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.userId).set(
            user.toJson(),
            SetOptions(merge: true),
          );
    } catch (e) {
      rethrow;
    }
  }

  /// Returns a real-time stream of the user's data.
  Stream<UserModel?> watchUser(String userId) {
    return _usersCollection.doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserModel.fromJson(snapshot.data()!);
      }
      return null;
    });
  }

  /// Updates specific fields on the user document (e.g. FCM token).
  Future<void> updateFields(String userId, Map<String, dynamic> fields) async {
    try {
      await _usersCollection.doc(userId).update(fields);
    } catch (e) {
      rethrow;
    }
  }
}
