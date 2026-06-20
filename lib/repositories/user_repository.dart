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

  /// Links a caregiver and a patient atomically using a Firestore transaction.
  Future<void> linkPatient({
    required String caregiverId,
    required String patientId,
  }) async {
    final caregiverRef = _usersCollection.doc(caregiverId);
    final patientRef = _usersCollection.doc(patientId);

    try {
      await _firestore.runTransaction((transaction) async {
        final caregiverDoc = await transaction.get(caregiverRef);
        final patientDoc = await transaction.get(patientRef);

        if (!caregiverDoc.exists) {
          throw Exception("Caregiver user with ID $caregiverId does not exist");
        }
        if (!patientDoc.exists) {
          throw Exception("Patient user with ID $patientId does not exist");
        }

        final caregiverData = caregiverDoc.data()!;
        final patientData = patientDoc.data()!;

        if (caregiverData['role'] != 'Caregiver') {
          throw Exception("User with ID $caregiverId is not a Caregiver");
        }
        if (patientData['role'] != 'Patient') {
          throw Exception("User with ID $patientId is not a Patient");
        }

        if (caregiverData['linkedPatientId'] != null && caregiverData['linkedPatientId'] != patientId) {
          throw Exception("Caregiver is already linked to another patient");
        }
        if (patientData['linkedCaregiverId'] != null && patientData['linkedCaregiverId'] != caregiverId) {
          throw Exception("Patient is already linked to another caregiver");
        }

        transaction.update(caregiverRef, {'linkedPatientId': patientId});
        transaction.update(patientRef, {'linkedCaregiverId': caregiverId});
      });
    } catch (e) {
      rethrow;
    }
  }
}
