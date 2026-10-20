import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memora/data/models/medicine_refill_model.dart';

/// All Firestore operations for patient medicine refills, prescription schedules, and bills.
class RefillRepository {
  final FirebaseFirestore _db;

  RefillRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _refills(String patientId) =>
      _db.collection('patients').doc(patientId).collection('refills');

  String newRefillId(String patientId) => _refills(patientId).doc().id;

  /// Watch all refill schedules for a patient, ordered by upcoming due date.
  Stream<List<MedicineRefillModel>> watchRefills(String patientId) {
    return _refills(patientId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((d) => MedicineRefillModel.fromMap(d.data(), d.id))
              .toList();
          list.sort((a, b) => a.refillDueDate.compareTo(b.refillDueDate));
          return list;
        });
  }

  /// Create a new refill schedule.
  Future<void> createRefill(String patientId, MedicineRefillModel refill) {
    return _refills(patientId).doc(refill.id).set(refill.toMap());
  }

  /// Update an existing refill schedule.
  Future<void> updateRefill(String patientId, MedicineRefillModel refill) {
    return _refills(patientId).doc(refill.id).update(refill.toMap());
  }

  /// Delete a refill schedule.
  Future<void> deleteRefill(String patientId, String refillId) {
    return _refills(patientId).doc(refillId).delete();
  }

  /// Mark refill as ordered (e.g. prescription called into pharmacy).
  Future<void> markOrdered(String patientId, String refillId) {
    return _refills(patientId).doc(refillId).update({
      'status': 'ordered',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Ask caregiver to buy the medication (sets status to 'caregiver_requested' with timestamp).
  Future<void> askCaregiverToBuy(String patientId, String refillId) {
    return _refills(patientId).doc(refillId).update({
      'status': 'caregiver_requested',
      'caregiverRequestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mark refill as bought/refilled, replenish remaining tablets, and advance to next due date.
  Future<void> markBought(String patientId, MedicineRefillModel refill, {int? replenishedTablets}) {
    final now = DateTime.now();
    final newCount = replenishedTablets ?? refill.totalTabletsInPack;

    if (refill.recurrence == 'none') {
      return _refills(patientId).doc(refill.id).update({
        'status': 'refilled',
        'remainingTablets': newCount,
        'lastRefilledAt': Timestamp.fromDate(now),
        'caregiverRequestedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Advance to next due date with safe month length clamping
    final nextDue = refill.computeNextDueDate();
    return _refills(patientId).doc(refill.id).update({
      'refillDueDate': Timestamp.fromDate(nextDue),
      'status': 'active',
      'remainingTablets': newCount,
      'lastRefilledAt': Timestamp.fromDate(now),
      'caregiverRequestedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mark refill as completed and automatically advance to next cycle if recurring.
  Future<void> markRefilled(String patientId, MedicineRefillModel refill, {int? replenishedTablets}) {
    return markBought(patientId, refill, replenishedTablets: replenishedTablets);
  }

  /// Toggle pause/active state for a refill schedule.
  Future<void> togglePause(String patientId, String refillId, bool isCurrentlyPaused) {
    return _refills(patientId).doc(refillId).update({
      'status': isCurrentlyPaused ? 'active' : 'paused',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
