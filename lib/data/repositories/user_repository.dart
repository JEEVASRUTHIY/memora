import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:memora/data/models/user_model.dart';
import 'package:memora/data/models/patient_profile.dart';
import 'package:memora/core/constants/app_constants.dart';
import 'dart:math';

/// Low-level Firestore access for the [users] collection.
class UserRepository {
  final FirebaseFirestore _db;

  UserRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AppConstants.colUsers);

    CollectionReference<Map<String, dynamic>> get _patients =>
      _db.collection(AppConstants.colPatients);

    CollectionReference<Map<String, dynamic>> get _emailIndex =>
      _db.collection(AppConstants.colEmailIndex);

      CollectionReference<Map<String, dynamic>> get _patientCodes =>
        _db.collection('patientCodes');

  /// Fetch a single user by UID (returns null if missing).
  Future<UserModel?> getUser(String uid) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  /// Real-time stream of user profile.
  Stream<UserModel?> watchUser(String uid) {
    return _col.doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return UserModel.fromMap(snap.data()!, snap.id);
    });
  }

  Stream<PatientProfile?> watchPatientProfile(String? patientId) {
    if (patientId == null || patientId.isEmpty) return Stream.value(null);
    return _patients.doc(patientId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return PatientProfile.fromMap(snap.data()!, snap.id);
    });
  }

  Stream<PatientProfile?> watchOrCreatePatientProfile({
    required String uid,
    required String? patientId,
  }) async* {
    if (patientId == null || patientId.isEmpty) {
      yield null;
      return;
    }
    try {
      await _patients.doc(patientId).set({
        'ownerUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      yield* watchPatientProfile(patientId);
    } on FirebaseException catch (error) {
      debugPrint(
        '[UserRepository] Firestore path patients/$patientId; '
        'code=${error.code}; error=$error',
      );
      rethrow;
    }
  }

  /// Create the user document (called once at registration).
  Future<void> createUser(UserModel user) async {
    await _col.doc(user.uid).set(user.toMap());
  }

  Future<UserModel> createPatientRegistration({
    required UserModel user,
  }) async {
    final emailRef = _emailIndex.doc(user.email.trim().toLowerCase());
    final userRef = _col.doc(user.uid);
    final rng = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    for (var attempt = 0; attempt < 20; attempt++) {
      final patientId = List.generate(
        AppConstants.patientIdLength,
        (_) => chars[rng.nextInt(chars.length)],
      ).join();
      final patientRef = _patients.doc(patientId);

      final createdAt = FieldValue.serverTimestamp();
      final registeredUser = user.copyWith(patientId: patientId);
      final batch = _db.batch();
      batch.set(userRef, {
        ...registeredUser.toMap(),
        'createdAt': createdAt,
      });
      batch.set(patientRef, {
        'ownerUid': user.uid,
        'createdAt': createdAt,
      });
      batch.set(_patientCodes.doc(patientId), {
        'ownerUid': user.uid,
      });
      batch.set(emailRef, {
        'uid': user.uid,
      });
      try {
        await batch.commit();
        return registeredUser;
      } on FirebaseException catch (error) {
        debugPrint(
          '[UserRepository] Firestore paths users/${user.uid}, '
          'patients/$patientId, emailIndex/${user.email.trim().toLowerCase()}; '
          'code=${error.code}; error=$error',
        );
        if (error.code != 'permission-denied') rethrow;
      }
    }
    throw StateError('Could not create a unique patient ID. Please try again.');
  }

  Future<void> ensurePatientCode({
    required String uid,
    required String patientId,
  }) async {
    final codeRef = _patientCodes.doc(patientId);
    try {
      await _db.runTransaction((transaction) async {
        final code = await transaction.get(codeRef);
        if (!code.exists) {
          transaction.set(codeRef, {'ownerUid': uid});
        }
      });
    } on FirebaseException catch (error) {
      debugPrint(
        '[UserRepository] Firestore path patientCodes/$patientId; '
        'code=${error.code}; error=$error',
      );
      if (error.code != 'already-exists') rethrow;
    }
  }

  Future<String> createPatientProfile({
    required String uid,
    required String? existingPatientId,
    required String name,
    required int age,
    required String details,
    required String timezone,
  }) async {
    final userRef = _col.doc(uid);
    final rng = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    for (var attempt = 0; attempt < 20; attempt++) {
      final patientId = existingPatientId ?? List.generate(
        AppConstants.patientIdLength,
        (_) => chars[rng.nextInt(chars.length)],
      ).join();
      final patientRef = _patients.doc(patientId);
      try {
        await _db.runTransaction((transaction) async {
          final patient = await transaction.get(patientRef);
          if (patient.exists) throw StateError('Patient ID is already in use.');
          transaction.set(patientRef, {
            'ownerUid': uid,
            'name': name.trim(),
            'age': age,
            'details': details.trim(),
            'timezone': timezone,
            'primaryCaregiverUid': null,
            'secondaryCount': 0,
            'createdAt': Timestamp.now(),
          });
          transaction.set(userRef, {
            'patientId': patientId,
            'name': name.trim(),
          }, SetOptions(merge: true));
        });
        return patientId;
      } on StateError {
        if (existingPatientId != null) rethrow;
      }
    }
    throw StateError('Could not create a unique patient ID. Please try again.');
  }

  Future<void> createCaregiverRegistration(UserModel user) async {
    final batch = _db.batch();
    batch.set(_col.doc(user.uid), user.toMap());
    batch.set(_emailIndex.doc(user.email.trim().toLowerCase()), {
      'uid': user.uid,
      'role': user.role,
      'name': user.name,
    });
    await batch.commit();
  }

  Future<void> setOnboardingDone(String uid) => updateUser(uid, {
        'onboardingDone': true,
      });

  /// Merge-update a user document (safe for partial updates).
  Future<void> updateUser(String uid, Map<String, dynamic> fields) async {
    await _col.doc(uid).set(fields, SetOptions(merge: true));
  }

  /// Adds an FCM token to the user's fcmTokens array (no duplicates).
  Future<void> addFcmToken(String uid, String token) async {
    if (token.isEmpty) return;
    try {
      await _col.doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        await _col.doc(uid).set({
          'fcmTokens': [token],
        }, SetOptions(merge: true));
      } else {
        debugPrint('[UserRepository] addFcmToken error: $e');
      }
    } catch (e) {
      debugPrint('[UserRepository] addFcmToken unexpected error: $e');
    }
  }

  /// Removes an FCM token from the user's fcmTokens array (called on logout).
  Future<void> removeFcmToken(String uid, String token) async {
    if (token.isEmpty) return;
    try {
      await _col.doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    } catch (e) {
      debugPrint('[UserRepository] removeFcmToken error: $e');
    }
  }

  /// Look up a patient by their short patientId (e.g. "AB12CD34").
  Future<UserModel?> getUserByPatientId(String patientId) async {
    final query = await _col
        .where('patientId', isEqualTo: patientId)
        .where('role', isEqualTo: AppConstants.rolePatient)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return UserModel.fromMap(doc.data(), doc.id);
  }

  /// Checks whether a patientId string is already taken.
  Future<bool> isPatientIdTaken(String patientId) async {
    final snapshot = await _col
        .where('patientId', isEqualTo: patientId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}
