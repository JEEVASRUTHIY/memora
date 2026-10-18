import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:memora/data/models/link_model.dart';
import 'package:memora/data/models/user_model.dart';
import 'package:memora/core/constants/app_constants.dart';

/// Firestore access for the [links] collection.
/// Firestore transactions for caregiver linking in Firebase Spark mode.
class LinkRepository {
  final FirebaseFirestore _db;

  LinkRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AppConstants.colLinks);

    CollectionReference<Map<String, dynamic>> get _mirrors =>
      _db.collection(AppConstants.colCaregiverLinks);

  Future<Map<String, dynamic>> requestLink(
      String patientId, UserModel caregiver) async {
    final codeRef = _db.collection('patientCodes').doc(patientId);
    final primaryRef = _db.collection('patientPrimary').doc(patientId);
    final linkRef = _col.doc('${patientId}_${caregiver.uid}');
    final mirrorRef = _mirrors.doc(caregiver.uid).collection('patients').doc(patientId);

    try {
      final codeSnap = await codeRef.get();
      if (!codeSnap.exists) throw StateError('Patient ID not found.');
      if (caregiver.role != AppConstants.roleCaregiver) {
        throw StateError('Only caregiver accounts can link to a patient.');
      }
      final linkSnap = await linkRef.get();
      final existing = linkSnap.data();
      if (existing != null &&
          ![AppConstants.linkStatusRejected, AppConstants.linkStatusRemoved]
              .contains(existing['status'])) {
        throw StateError('Already linked.');
      }

      final primarySnap = await primaryRef.get();
      final isPrimary = !primarySnap.exists;
      final role = isPrimary
          ? AppConstants.linkRolePrimary
          : AppConstants.linkRoleSecondary;
      final status = isPrimary
          ? AppConstants.linkStatusActive
          : AppConstants.linkStatusPending;
      final batch = _db.batch();
      if (isPrimary) {
        batch.set(primaryRef, {'caregiverUid': caregiver.uid});
      }
      batch.set(linkRef, {
        'patientId': patientId,
        'caregiverUid': caregiver.uid,
        'caregiverName': caregiver.name,
        'role': role,
        'status': status,
        'requestedBy': 'caregiver',
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(mirrorRef, {
        'patientId': patientId,
        'role': role,
        'status': status,
      });
      await batch.commit();
      return {'linkId': linkRef.id, 'role': role, 'status': status};
    } on FirebaseException catch (error) {
      debugPrint(
        '[LinkRepository] Firestore paths patientCodes/$patientId, '
        'patientPrimary/$patientId, links/${patientId}_${caregiver.uid}, '
        'caregiverLinks/${caregiver.uid}/patients/$patientId; '
        'code=${error.code}; error=$error',
      );
      if (error.code == 'already-exists') {
        throw StateError('Already linked.');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addBackupCaregiver({
    required String patientId,
    required String email,
    required String primaryUid,
  }) async {
    final patientRef = _db.collection(AppConstants.colPatients).doc(patientId);
    final emailRef = _db.collection(AppConstants.colEmailIndex).doc(email.trim().toLowerCase());
    final primaryRef = _db.collection(AppConstants.colUsers).doc(primaryUid);

    return _db.runTransaction((transaction) async {
      final patientSnap = await transaction.get(patientRef);
      final emailSnap = await transaction.get(emailRef);
      final primarySnap = await transaction.get(primaryRef);
      if (!patientSnap.exists || patientSnap.data()!['primaryCaregiverUid'] != primaryUid) {
        throw StateError('Only the primary caregiver can add a backup.');
      }
      if (!primarySnap.exists || primarySnap.data()!['role'] != AppConstants.roleCaregiver) {
        throw StateError('Your caregiver profile could not be found.');
      }
      if (!emailSnap.exists) {
        throw StateError('No caregiver account uses that email. Share the invite instead.');
      }
      final indexed = emailSnap.data()!;
      if (indexed['role'] != AppConstants.roleCaregiver) {
        throw StateError('That account is not a caregiver. Share the invite instead.');
      }
      final caregiverUid = indexed['uid'] as String;
      if (caregiverUid == primaryUid) throw StateError('You are already the primary caregiver.');
      final count = (patientSnap.data()!['secondaryCount'] as num?)?.toInt() ?? 0;
      if (count >= 3) throw StateError('This patient already has three backup caregivers.');

      final linkRef = _col.doc('${patientId}_$caregiverUid');
      final mirrorRef = _mirrors.doc(caregiverUid).collection('patients').doc(patientId);
      final linkSnap = await transaction.get(linkRef);
      final existing = linkSnap.data();
      if (existing != null &&
          ![AppConstants.linkStatusRejected, AppConstants.linkStatusRemoved]
              .contains(existing['status'])) {
        throw StateError('This caregiver is already linked or awaiting approval.');
      }
      transaction.set(linkRef, {
        'patientId': patientId,
        'caregiverUid': caregiverUid,
        'caregiverName': indexed['name'] as String? ?? '',
        'role': AppConstants.linkRoleSecondary,
        'status': AppConstants.linkStatusActive,
        'requestedBy': 'primary',
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(mirrorRef, {
        'patientId': patientId,
        'role': AppConstants.linkRoleSecondary,
        'status': AppConstants.linkStatusActive,
      });
      transaction.update(patientRef, {'secondaryCount': count + 1});
      return {'linkId': linkRef.id, 'status': AppConstants.linkStatusActive};
    });
  }

  /// Primary only: approve or reject a pending link.
  Future<Map<String, dynamic>> respondToLink(
      String linkId, bool approve, String primaryUid) async {
    final linkRef = _col.doc(linkId);
    return _db.runTransaction((transaction) async {
      final linkSnap = await transaction.get(linkRef);
      if (!linkSnap.exists) throw StateError('Link request not found.');
      final link = linkSnap.data()!;
      final patientId = link['patientId'] as String;
      final patientRef = _db.collection(AppConstants.colPatients).doc(patientId);
      final patientSnap = await transaction.get(patientRef);
      final patient = patientSnap.data()!;
      if (patient['primaryCaregiverUid'] != primaryUid ||
          link['status'] != AppConstants.linkStatusPending) {
        throw StateError('Only the primary caregiver can respond to this request.');
      }
      final count = (patient['secondaryCount'] as num?)?.toInt() ?? 0;
      transaction.update(linkRef, {
        'status': approve ? AppConstants.linkStatusActive : AppConstants.linkStatusRejected,
        'respondedAt': FieldValue.serverTimestamp(),
      });
      final caregiverUid = link['caregiverUid'] as String;
      final mirrorRef = _mirrors.doc(caregiverUid).collection('patients').doc(patientId);
      if (approve) {
        transaction.set(mirrorRef, {
          'patientId': patientId,
          'role': AppConstants.linkRoleSecondary,
          'status': AppConstants.linkStatusActive,
        });
      } else {
        transaction.delete(mirrorRef);
        transaction.update(patientRef, {'secondaryCount': count - 1});
      }
      return {'linkId': linkId, 'status': approve ? 'active' : 'rejected'};
    });
  }

  /// Primary only: remove an active/pending secondary link.
  Future<void> removeSecondary(String linkId, String primaryUid) async {
    await _db.runTransaction((transaction) async {
      final linkRef = _col.doc(linkId);
      final linkSnap = await transaction.get(linkRef);
      if (!linkSnap.exists) throw StateError('Link not found.');
      final link = linkSnap.data()!;
      final patientId = link['patientId'] as String;
      final patientRef = _db.collection(AppConstants.colPatients).doc(patientId);
      final patientSnap = await transaction.get(patientRef);
      final patient = patientSnap.data()!;
      if (patient['primaryCaregiverUid'] != primaryUid ||
          link['role'] != AppConstants.linkRoleSecondary ||
          ![AppConstants.linkStatusPending, AppConstants.linkStatusActive]
              .contains(link['status'])) {
        throw StateError('Only the primary caregiver can remove a backup.');
      }
      final count = (patient['secondaryCount'] as num?)?.toInt() ?? 0;
      transaction.update(linkRef, {
        'status': AppConstants.linkStatusRemoved,
        'respondedAt': FieldValue.serverTimestamp(),
      });
      transaction.delete(
        _mirrors.doc(link['caregiverUid'] as String).collection('patients').doc(patientId),
      );
      transaction.update(patientRef, {'secondaryCount': count - 1});
    });
  }

  // ── Read helpers ──────────────────────────────────────────────────────────

  /// All non-removed links for a caregiver (active + pending).
  Stream<List<LinkModel>> watchLinksForCaregiver(String caregiverUid) {
    return _mirrors.doc(caregiverUid).collection('patients').snapshots().map(
      (snapshot) => snapshot.docs
          .where((doc) => [
                AppConstants.linkStatusActive,
                AppConstants.linkStatusPending,
              ].contains(doc.data()['status']))
          .map((doc) => LinkModel.fromMap({
                ...doc.data(),
                'caregiverUid': caregiverUid,
                'caregiverName': '',
                'requestedBy': 'caregiver',
              }, doc.id))
          .toList(),
    );
  }

  /// All active+pending links for a patient (used by patient UI).
  Stream<List<LinkModel>> watchLinksForPatient(String patientId) {
    return _col
        .where('patientId', isEqualTo: patientId)
        .where('status', whereIn: [
          AppConstants.linkStatusActive,
          AppConstants.linkStatusPending,
        ])
        .snapshots()
        .map((s) => s.docs.map((d) => LinkModel.fromMap(d.data(), d.id)).toList());
  }

  /// All pending secondary links for a patient (shown to primary caregiver).
  Stream<List<LinkModel>> watchPendingLinksForPatient(String patientId) {
    return _col
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: AppConstants.linkStatusPending)
        .snapshots()
        .map((s) => s.docs.map((d) => LinkModel.fromMap(d.data(), d.id)).toList());
  }

  /// Returns the caller's active primary link (if any).
  Future<LinkModel?> getActivePrimaryLink(String caregiverUid) async {
    final snap = await _col
        .where('caregiverUid', isEqualTo: caregiverUid)
        .where('role', isEqualTo: AppConstants.linkRolePrimary)
        .where('status', isEqualTo: AppConstants.linkStatusActive)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return LinkModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  /// Returns all active secondary links for a patient.
  Future<List<LinkModel>> getActiveSecondaries(String patientId) async {
    final snap = await _col
        .where('patientId', isEqualTo: patientId)
        .where('role', isEqualTo: AppConstants.linkRoleSecondary)
        .where('status', isEqualTo: AppConstants.linkStatusActive)
        .get();
    return snap.docs.map((d) => LinkModel.fromMap(d.data(), d.id)).toList();
  }

  /// Returns the active primary link FOR a patient (used by ReminderService).
  Future<LinkModel?> getPrimaryLinkForPatient(String patientId) async {
    final snap = await _col
        .where('patientId', isEqualTo: patientId)
        .where('role', isEqualTo: AppConstants.linkRolePrimary)
        .where('status', isEqualTo: AppConstants.linkStatusActive)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return LinkModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  /// Looks up a caregiver's UserModel by UID (convenience).
  Future<UserModel?> getCaregiverUser(String uid) async {
    final doc = await _db.collection(AppConstants.colUsers).doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }
}
